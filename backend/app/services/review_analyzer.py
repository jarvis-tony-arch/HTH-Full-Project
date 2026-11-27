"""Review analysis for the "should I buy this?" screen.

Every step is a separate, explainable function (no black box, no PyTorch):

  clean_reviews          dedupe, strip boilerplate, Hinglish -> English, parse dates
  aspect_sentiment       8 aspects x (keyword lexicon incl. Hinglish) x VADER per sentence
  not_as_shown           reviews saying the item differs from photo/description
  trust_signals          generic 5-stars, near-duplicates, bursts, unverified, star/text mismatch
  trend                  last ~60 days vs older, per aspect
  cross_platform         ratings per shop, big gaps + likely reasons, cross-posted reviews,
                         cheapest confirmed listing, YouTube/Reddit vs shop reviews
  verdict                Good buy / Buy with caution / Avoid + reasons + real quotes
  size_advice            clothing only, when reviews support it
  confidence             says plainly when data is thin or mixed

Only text the shopper's phone collected is used. Nothing is invented: when
there isn't enough data a section says so instead of guessing.
"""
from __future__ import annotations

import re
from collections import Counter, defaultdict
from datetime import date, datetime, timedelta

from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer

from app.services.nlp_service import is_hinglish, normalize_hinglish

MIN_REVIEWS = 15
RECENT_DAYS = 60

_vader = SentimentIntensityAnalyzer()
# Hinglish / Indian-English opinion words VADER doesn't know.
_vader.lexicon.update({
    "bekar": -2.5, "bakwas": -3.0, "ghatiya": -3.0, "faltu": -2.0, "kharab": -2.5, "bekaar": -2.5,
    "ganda": -2.0, "wastage": -2.0, "pathetic": -3.0, "worst": -3.2, "duplicate": -2.0, "fake": -2.5,
    "badhiya": 2.5, "badiya": 2.5, "mast": 2.0, "accha": 2.0, "acha": 2.0, "achha": 2.0, "zabardast": 3.0,
    "shandar": 2.5, "sahi": 1.5, "paisa vasool": 3.0, "vfm": 2.0, "value-for-money": 2.0,
    "terrific": 3.0, "classy": 2.0, "delightful": 2.5, "worthless": -3.0, "steal": 1.5,
})

# ─── 1. Cleaning ──────────────────────────────────────────────────────
_BOILERPLATE = [
    r"\bread more\b", r"\bcertified buyer\b", r"\bverified purchase\b", r"\bthe media could not be loaded\.?",
    r"\breport abuse\b", r"\bhelpful\b\s*$", r"\.\.\.\s*more$", r"…\s*more$", r"\bpermalink\b",
]
_MONTHS = {m: i for i, m in enumerate(
    ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"], start=1)}


def clean_text(text: str) -> str:
    t = text or ""
    for p in _BOILERPLATE:
        t = re.sub(p, " ", t, flags=re.I)
    return re.sub(r"\s+", " ", t).strip()


def parse_review_date(raw: str, collected: date) -> tuple[date | None, str]:
    """(date, precision) precision is 'day', 'month' or ''."""
    s = (raw or "").strip().lower()
    if not s:
        return None, ""
    s = re.sub(r"^reviewed in [a-z ]+ on\s+", "", s).lstrip("· ").strip()
    if s in ("today", "just now"):
        return collected, "day"
    if s == "yesterday":
        return collected - timedelta(days=1), "day"
    m = re.match(r"(\d+|a|an)\s+(day|days|week|weeks|month|months|year|years)\s+ago", s)
    if m:
        n = 1 if m.group(1) in ("a", "an") else int(m.group(1))
        unit = m.group(2).rstrip("s")
        days = {"day": 1, "week": 7, "month": 30, "year": 365}[unit] * n
        return collected - timedelta(days=days), "day" if unit in ("day", "week") else "month"
    m = re.match(r"(\d{4})-(\d{2})-(\d{2})", s)
    if m:
        return date(int(m.group(1)), int(m.group(2)), int(m.group(3))), "day"
    m = re.match(r"(\d{1,2})(?:st|nd|rd|th)?\s+([a-z]{3})[a-z]*,?\s+(\d{4})", s)  # 3 August 2021 / 24 Nov 2026
    if m and m.group(2) in _MONTHS:
        try:
            return date(int(m.group(3)), _MONTHS[m.group(2)], int(m.group(1))), "day"
        except ValueError:
            return None, ""
    m = re.match(r"([a-z]{3})[a-z]*,?\s+(\d{4})", s)  # Mar, 2024
    if m and m.group(1) in _MONTHS:
        return date(int(m.group(2)), _MONTHS[m.group(1)], 15), "month"
    return None, ""


def _norm_key(text: str) -> str:
    return re.sub(r"[^a-z0-9 ]", "", (text or "").lower()).strip()


def clean_reviews(sources: list[dict], collected_at: str | None = None) -> tuple[list[dict], dict]:
    """Flatten sources into one list of clean reviews.

    Each review gets: text (original, for quotes), en (normalised English for
    analysis), hinglish flag, date/precision, words, compound sentiment.
    Exact duplicates within a shop are dropped; the same review cross-posted
    on several shops is kept once and counted.
    """
    try:
        collected = datetime.fromisoformat((collected_at or "")[:19]).date()
    except ValueError:
        collected = date.today()
    out: list[dict] = []
    seen_in_shop: set[tuple[str, str]] = set()
    seen_any: dict[str, dict] = {}
    cross_posted = 0
    dropped = 0
    for src in sources:
        platform = src.get("platform", "")
        for r in src.get("reviews") or []:
            title = clean_text(r.get("title") or "")
            text = clean_text(r.get("text") or "")
            if not text and not title:
                dropped += 1
                continue
            full = text if not title or title.lower() in text.lower() else f"{title}. {text}"
            key = _norm_key(full)
            # Many different buyers write just "Nice": only drop true repeats
            # (same review id, or same text + stars + date).
            rid = (r.get("id") or "").strip()
            shop_key = f"id:{rid}" if rid else f"{key}|{r.get('rating')}|{r.get('date_raw')}"
            if (platform, shop_key) in seen_in_shop:
                dropped += 1
                continue
            seen_in_shop.add((platform, shop_key))
            if len(key.split()) >= 8 and key in seen_any and seen_any[key]["platform"] != platform:
                cross_posted += 1
                seen_any[key].setdefault("also_on", []).append(platform)
                continue
            hing = is_hinglish(full)
            en = normalize_hinglish(full) if hing else full
            d, prec = parse_review_date(r.get("date_raw") or "", collected)
            try:
                rating = float(r.get("rating") or 0)
            except (TypeError, ValueError):
                rating = 0.0
            item = {
                "platform": platform,
                "title": title,
                "text": full,
                "en": en,
                "hinglish": hing,
                "rating": rating,
                "date": d,
                "date_precision": prec,
                "verified": r.get("verified"),
                "variant": r.get("variant") or "",
                "helpful": int(r.get("helpful") or 0),
                "words": len(re.findall(r"\w+", full)),
                "compound": _vader.polarity_scores(en)["compound"],
            }
            out.append(item)
            seen_any.setdefault(key, item)
    stats = {"collected_on": collected.isoformat(), "dropped_duplicates": dropped,
             "cross_posted": cross_posted, "hinglish": sum(r["hinglish"] for r in out)}
    return out, stats


# ─── 2. Aspect-based sentiment ────────────────────────────────────────
ASPECTS: dict[str, dict] = {
    "quality": {"label": "Quality", "words": [
        r"quality", r"build", r"sound", r"bass", r"performance", r"works?", r"working", r"finish(ing)?",
        r"stitch(ing)?", r"product is", r"overall", r"camera", r"display", r"battery backup", r"mic",
        r"call quality", r"connectivity", r"cheez", r"maal"]},
    "size_fit": {"label": "Size & fit", "words": [
        r"size", r"fit(s|ting)?", r"fitting", r"tight", r"loose", r"small", r"large", r"length", r"waist",
        r"chest", r"shoulder", r"runs (small|big|large)", r"chota", r"chhota", r"bada", r"oversized", r"comfortable"]},
    "colour_looks": {"label": "Colour & looks", "words": [
        r"colou?r", r"shade", r"looks?", r"design", r"style", r"stylish", r"print", r"picture", r"photo",
        r"image", r"rang", r"dikhne", r"appearance", r"beautiful", r"pretty", r"faded"]},
    "material": {"label": "Material", "words": [
        r"fabric", r"material", r"cloth", r"cotton", r"polyester", r"leather", r"plastic", r"thin", r"thick",
        r"soft", r"rough", r"transparent", r"see.?through", r"kapda", r"kapra"]},
    "durability": {"label": "Durability", "words": [
        r"durab\w*", r"lasts?", r"lasting", r"broke", r"broken", r"stopped working", r"after (a )?(few|\d+) (days?|weeks?|months?|washes?)",
        r"wash(es|ed)?", r"shrink\w*", r"tear", r"torn", r"damage\w*", r"long.?lasting", r"died", r"dead", r"toot", r"phat"]},
    "value": {"label": "Value for money", "words": [
        r"value for money", r"vfm", r"worth", r"price", r"money", r"cheap", r"expensive", r"costly", r"budget",
        r"paisa vasool", r"overpriced", r"at this price", r"affordable", r"deal"]},
    "delivery": {"label": "Delivery & packaging", "words": [
        r"deliver\w*", r"packag\w*", r"packing", r"box", r"courier", r"shipping", r"arrived", r"late",
        r"on time", r"fast delivery", r"seal(ed)?", r"parcel"]},
    "authenticity": {"label": "Genuine product & seller", "words": [
        r"fake", r"duplicate", r"original", r"genuine", r"first copy", r"counterfeit", r"seller", r"refurbished",
        r"used product", r"authentic", r"replica", r"warranty"]},
}
_ASPECT_RE = {k: re.compile(r"\b(" + "|".join(v["words"]) + r")\b", re.I) for k, v in ASPECTS.items()}
_SENT_SPLIT = re.compile(r"(?<=[.!?।])\s+|\n+|\s+(?:but|however|lekin|par)\s+", re.I)


def sentences(text: str) -> list[str]:
    return [s.strip() for s in _SENT_SPLIT.split(text or "") if s and len(s.strip()) > 2]


def _sentence_polarity(sent_en: str, rating: float) -> int:
    """+1 / -1 / 0. A neutral sentence takes the review's stars as a tie-break."""
    c = _vader.polarity_scores(sent_en)["compound"]
    if c >= 0.05:
        return 1
    if c <= -0.05:
        return -1
    if rating >= 4:
        return 1
    if 0 < rating <= 2:
        return -1
    return 0


def _quote(text: str, n: int = 160) -> str:
    t = " ".join((text or "").split())
    return t if len(t) <= n else t[: n - 1].rsplit(" ", 1)[0] + "…"


def aspect_sentiment(reviews: list[dict]) -> dict[str, dict]:
    out: dict[str, dict] = {}
    for key, spec in ASPECTS.items():
        pos = neg = 0
        quotes = {"positive": [], "negative": []}
        mentioned = 0
        for r in reviews:
            hit_sents = [s for s in sentences(r["en"]) if _ASPECT_RE[key].search(s)]
            if not hit_sents:
                continue
            mentioned += 1
            score = sum(_sentence_polarity(s, r["rating"]) for s in hit_sents)
            if score > 0:
                pos += 1
                bucket = "positive"
            elif score < 0:
                neg += 1
                bucket = "negative"
            else:
                continue
            # Quote the original words of the review (sentence-aligned when possible).
            orig = sentences(r["text"])
            q = next((s for s in orig if _ASPECT_RE[key].search(normalize_hinglish(s) if r["hinglish"] else s)), r["text"])
            quotes[bucket].append({"text": _quote(q), "rating": r["rating"], "platform": r["platform"],
                                   "helpful": r["helpful"]})
        for b in quotes:
            quotes[b] = sorted(quotes[b], key=lambda q: (-q["helpful"], len(q["text"])))[:3]
        rated = pos + neg
        out[key] = {
            "label": spec["label"],
            "mentions": mentioned,
            "positive": pos,
            "negative": neg,
            "positive_share": round(pos / rated, 3) if rated else None,
            "quotes": quotes,
        }
    return out


# ─── 3. "Not as shown" detector ───────────────────────────────────────
NOT_AS_SHOWN = {
    "colour": [
        r"colou?r\s+(is\s+|was\s+)?(totally\s+|completely\s+|bit\s+|little\s+)?(different|not\s+(the\s+)?same|mismatch\w*|faded|dull|off)",
        r"(different|wrong)\s+colou?r", r"colou?r\s+(does\s*n.?t|did\s*n.?t|not)\s+match",
        r"colou?r\s+not\s+as\s+(shown|in\s+(the\s+)?(picture|image|photo))", r"rang\s+(alag|different|halka)",
        r"in\s+(the\s+)?(given\s+)?(picture|image|photo|pic)\s+(the\s+)?colou?r\s+looks?",
        r"(in\s+real(ity)?|actual(ly)?)\b[^.]{0,30}\b(looks?|is)\s+(much\s+|very\s+|bit\s+)?(faded|dull|different|lighter|darker)",
    ],
    "size": [
        r"size\s+(chart\s+)?(is\s+|was\s+)?(wrong|incorrect|misleading|not\s+(accurate|correct|proper))",
        r"(runs|is|was|very|too)\s+(very\s+)?(small|tight)\s+(than|for)\s+(the\s+)?(size|chart)",
        r"size\s+(is\s+)?(too\s+|very\s+)?(small|big|large)\s+(than|from)", r"(chota|chhota|bada)\s+(hai|tha|size)",
        r"size\s+not\s+(as|same|matching)", r"not\s+(true|according)\s+to\s+size",
    ],
    "material": [
        r"(fabric|material|cloth|kapda|kapra)\s+(is\s+|was\s+|quality\s+is\s+)?(very\s+|too\s+|so\s+)?(thin|cheap|poor|bad|low|transparent|rough|pathetic|worst)",
        r"see.?through", r"(cheap|poor|low)\s+(quality\s+)?(fabric|material|plastic)",
        r"material\s+(is\s+)?not\s+(as\s+)?(described|mentioned|shown)",
    ],
    "looks": [
        r"looks?\s+(very\s+|so\s+)?cheap", r"not\s+(the\s+)?same\s+as\s+(shown|in\s+(the\s+)?(picture|image|photo|pic|ad))",
        r"(different|differs?)\s+from\s+(the\s+)?(picture|image|photo|pic|description|what\s+(is|was)\s+shown)",
        r"(picture|image|photo|pic)\s+(me|mein|is|was)?\s*(alag|different|misleading)", r"not\s+as\s+(shown|described|pictured|expected\s+from\s+(the\s+)?(picture|photo))",
        r"(misleading|fake)\s+(picture|image|photo|pics|images)", r"don.?t\s+buy\s+(the\s+product\s+)?(just\s+)?by\s+looking\s+(at\s+)?(the\s+)?picture",
        r"what\s+you\s+see\s+is\s+not\s+what\s+you\s+get",
    ],
    "fake": [
        r"(?<!not\s)(?<!no\s)\b(fake|duplicate|counterfeit|replica|first\s+copy)\b(?!\s+review)",
        r"not\s+(an?\s+)?(original|genuine|authentic)", r"(used|refurbished|old)\s+product\s+(delivered|received|sent)",
        r"(received|got|delivered)\s+(a\s+)?(used|refurbished|opened)",
    ],
}
_NAS_RE = {k: [re.compile(p, re.I) for p in v] for k, v in NOT_AS_SHOWN.items()}
NAS_LABELS = {"colour": "Colour different", "size": "Size not as listed", "material": "Material/fabric poorer",
              "looks": "Doesn't look like the photo", "fake": "Fake or used item"}


def not_as_shown(reviews: list[dict]) -> dict:
    by_type: dict[str, list[dict]] = defaultdict(list)
    flagged = set()
    for i, r in enumerate(reviews):
        hay = f"{r['text']} {r['en']}"
        for t, pats in _NAS_RE.items():
            if any(p.search(hay) for p in pats):
                by_type[t].append(r)
                flagged.add(i)
    n = len(reviews)
    types = []
    for t, rs in sorted(by_type.items(), key=lambda kv: -len(kv[1])):
        ex = sorted(rs, key=lambda r: (-r["helpful"], r["rating"]))[:3]
        types.append({"type": t, "label": NAS_LABELS[t], "count": len(rs),
                      "share": round(len(rs) / n, 3) if n else 0,
                      "examples": [{"text": _quote(r["text"]), "rating": r["rating"], "platform": r["platform"]} for r in ex]})
    share = round(len(flagged) / n, 3) if n else 0
    level = "high" if share >= 0.15 else "some" if share >= 0.06 else "low"
    return {"share": share, "count": len(flagged), "level": level, "types": types}


# ─── 4. Trust signals ─────────────────────────────────────────────────
_GENERIC = {"good", "nice", "nice product", "good product", "best", "super", "awesome", "excellent", "very good",
            "very nice", "osm", "wow", "superb", "great", "great product", "best product", "perfect", "amazing",
            "worth it", "value for money", "good quality", "loved it", "love it", "fine", "ok", "okay"}


def _generic(r: dict) -> bool:
    t = _norm_key(r["text"]).replace(" product", " product").strip()
    t2 = re.sub(r"\b(very|so|really|nice|good)\b\s*(?=\1)", "", t)
    return r["rating"] >= 5 and (r["words"] <= 4 or t in _GENERIC or t2 in _GENERIC)


def near_duplicates(reviews: list[dict], threshold: float = 0.9) -> list[tuple[int, int, float]]:
    idx = [i for i, r in enumerate(reviews) if r["words"] >= 6]
    if len(idx) < 2:
        return []
    vec = TfidfVectorizer(ngram_range=(1, 2), min_df=1, sublinear_tf=True)
    m = vec.fit_transform([reviews[i]["en"].lower() for i in idx])
    sims = cosine_similarity(m)
    pairs = []
    for a in range(len(idx)):
        for b in range(a + 1, len(idx)):
            if sims[a, b] >= threshold:
                pairs.append((idx[a], idx[b], float(sims[a, b])))
    return pairs


def review_bursts(reviews: list[dict], window_days: int = 3) -> dict | None:
    dated = sorted(r["date"] for r in reviews if r["date"] and r["date_precision"] == "day")
    if len(dated) < 12:
        return None
    span = (dated[-1] - dated[0]).days + 1
    best_n, best_start = 0, dated[0]
    j = 0
    for i, d in enumerate(dated):
        while d - dated[j] >= timedelta(days=window_days):
            j += 1
        if i - j + 1 > best_n:
            best_n, best_start = i - j + 1, dated[j]
    share = best_n / len(dated)
    expected = min(1.0, window_days / span) if span > 0 else 1.0
    return {"share": round(share, 3), "count": best_n, "start": best_start.isoformat(),
            "window_days": window_days, "suspicious": span >= 30 and share >= 0.25 and share >= 4 * expected}


def trust_signals(reviews: list[dict]) -> dict:
    n = len(reviews)
    if not n:
        return {"score": None, "level": "unknown", "flags": [], "signals": {}}
    flags: list[dict] = []
    penalty = 0.0

    generic = [r for r in reviews if _generic(r)]
    g_share = len(generic) / n
    if g_share >= 0.25:
        p = min(25, (g_share - 0.2) * 60)
        penalty += p
        flags.append({"signal": "generic", "severity": "high" if g_share >= 0.45 else "medium",
                      "text": f"{round(g_share * 100)}% are very short 5-star reviews like \"Good\" or \"Nice product\""})

    dup_pairs = near_duplicates(reviews)
    dup_ids = {i for a, b, _ in dup_pairs for i in (a, b)}
    d_share = len(dup_ids) / n
    if len(dup_ids) >= 3 and d_share >= 0.05:
        penalty += min(25, d_share * 120)
        ex = reviews[dup_pairs[0][0]]["text"]
        flags.append({"signal": "duplicates", "severity": "high" if d_share >= 0.12 else "medium",
                      "text": f"{len(dup_ids)} reviews are near copies of each other (e.g. \"{_quote(ex, 70)}\")"})

    burst = review_bursts(reviews)
    if burst and burst["suspicious"]:
        penalty += min(20, burst["share"] * 50)
        flags.append({"signal": "burst", "severity": "medium",
                      "text": f"{burst['count']} reviews ({round(burst['share'] * 100)}%) were posted within {burst['window_days']} days around {burst['start']}"})

    ver = [r for r in reviews if r["verified"] is not None]
    unverified_share = None
    if len(ver) >= 10:
        unverified_share = sum(1 for r in ver if not r["verified"]) / len(ver)
        if unverified_share >= 0.3:
            penalty += min(20, unverified_share * 30)
            flags.append({"signal": "unverified", "severity": "medium",
                          "text": f"{round(unverified_share * 100)}% are not marked as verified purchases"})

    long_enough = [r for r in reviews if r["words"] >= 5 and r["rating"]]
    mismatch = [r for r in long_enough if (r["rating"] >= 4 and r["compound"] <= -0.4) or (r["rating"] <= 2 and r["compound"] >= 0.5)]
    m_share = len(mismatch) / len(long_enough) if long_enough else 0
    if len(mismatch) >= 3 and m_share >= 0.08:
        penalty += min(15, m_share * 80)
        flags.append({"signal": "mismatch", "severity": "low",
                      "text": f"{len(mismatch)} reviews' stars don't match their words (e.g. {int(mismatch[0]['rating'])}★: \"{_quote(mismatch[0]['text'], 70)}\")"})

    score = max(0, round(100 - penalty))
    level = "high" if score >= 75 else "medium" if score >= 50 else "low"
    return {
        "score": score,
        "level": level,
        "flags": flags,
        "signals": {
            "generic_share": round(g_share, 3),
            "near_duplicate_share": round(d_share, 3),
            "burst": burst,
            "unverified_share": None if unverified_share is None else round(unverified_share, 3),
            "star_text_mismatch_share": round(m_share, 3),
        },
    }


# ─── 5. Trend ─────────────────────────────────────────────────────────
def trend(reviews: list[dict], collected_on: str) -> dict:
    today = date.fromisoformat(collected_on)
    cutoff = today - timedelta(days=RECENT_DAYS)
    recent = [r for r in reviews if r["date"] and r["date"] >= cutoff]
    older = [r for r in reviews if r["date"] and r["date"] < cutoff]
    if len(recent) < 8 or len(older) < 8:
        return {"status": "unknown", "text": "Not enough dated reviews to see a trend", "recent": len(recent), "older": len(older), "aspects": []}
    ra = sum(r["rating"] for r in recent) / len(recent)
    oa = sum(r["rating"] for r in older) / len(older)
    changes = []
    a_recent, a_older = aspect_sentiment(recent), aspect_sentiment(older)
    for k in ASPECTS:
        x, y = a_recent[k], a_older[k]
        if (x["positive"] + x["negative"]) >= 4 and (y["positive"] + y["negative"]) >= 4:
            neg_r = x["negative"] / (x["positive"] + x["negative"])
            neg_o = y["negative"] / (y["positive"] + y["negative"])
            if abs(neg_r - neg_o) >= 0.2:
                changes.append({"aspect": k, "label": ASPECTS[k]["label"], "recent_negative": round(neg_r, 2),
                                "older_negative": round(neg_o, 2),
                                "text": f"{ASPECTS[k]['label']} complaints have {'increased' if neg_r > neg_o else 'dropped'} recently"})
    delta = ra - oa
    status = "worse" if delta <= -0.4 or any(c["recent_negative"] > c["older_negative"] for c in changes) and delta < 0 else \
        "better" if delta >= 0.4 else "stable"
    text = {"worse": "Getting worse lately", "better": "Getting better lately", "stable": "Stable"}[status]
    return {"status": status, "text": text, "recent": len(recent), "older": len(older),
            "recent_rating": round(ra, 2), "older_rating": round(oa, 2), "aspects": changes}


# ─── 6. Cross-platform comparison ─────────────────────────────────────
PLATFORM_LABELS = {"amazon": "Amazon", "flipkart": "Flipkart", "myntra": "Myntra", "ajio": "AJIO", "nykaa": "Nykaa",
                   "croma": "Croma", "reliance": "Reliance Digital", "youtube": "YouTube", "reddit": "Reddit"}


def _avg(xs):
    xs = [x for x in xs if x]
    return round(sum(xs) / len(xs), 2) if xs else None


def cross_platform(reviews: list[dict], sources: list[dict], listings: list[dict], opinions: dict | None,
                   product: dict, nas_by_platform: dict[str, float]) -> dict:
    shops = []
    for s in sources:
        p = s.get("platform", "")
        meta = s.get("meta") or {}
        rs = [r for r in reviews if r["platform"] == p]
        shops.append({
            "platform": p, "label": PLATFORM_LABELS.get(p, p), "url": s.get("url") or meta.get("url"),
            "listing_rating": meta.get("rating"), "rating_count": meta.get("rating_count"),
            "sample_rating": _avg(r["rating"] for r in rs), "reviews_read": len(rs),
            "price": meta.get("price"), "not_as_shown_share": nas_by_platform.get(p), "confirmed": True,
            "source": "reviews",
        })
    for l in listings or []:
        p = l.get("platform", "")
        if any(s["platform"] == p for s in shops):
            continue
        shops.append({"platform": p, "label": PLATFORM_LABELS.get(p, p), "url": l.get("url"),
                      "listing_rating": l.get("rating"), "rating_count": l.get("rating_count"),
                      "sample_rating": None, "reviews_read": 0, "price": l.get("price"),
                      "not_as_shown_share": None, "confirmed": True, "source": "listing"})

    def rating_of(s):
        return s["listing_rating"] or s["sample_rating"]

    rated = [s for s in shops if rating_of(s)]
    gap = None
    if len(rated) >= 2:
        hi = max(rated, key=rating_of)
        lo = min(rated, key=rating_of)
        diff = round(rating_of(hi) - rating_of(lo), 2)
        if diff >= 0.7:
            why = []
            lo_rs = [r for r in reviews if r["platform"] == lo["platform"]]
            hi_rs = [r for r in reviews if r["platform"] == hi["platform"]]
            if lo_rs and hi_rs:
                fake_lo = sum(1 for r in lo_rs if any(p.search(r["text"]) for p in _NAS_RE["fake"])) / len(lo_rs)
                fake_hi = sum(1 for r in hi_rs if any(p.search(r["text"]) for p in _NAS_RE["fake"])) / len(hi_rs)
                if fake_lo - fake_hi >= 0.05:
                    why.append(f"more fake/used-item complaints on {lo['label']} ({round(fake_lo * 100)}% vs {round(fake_hi * 100)}%), so check the seller")
                a_lo, a_hi = aspect_sentiment(lo_rs), aspect_sentiment(hi_rs)
                for k in ASPECTS:
                    x, y = a_lo[k], a_hi[k]
                    if x["positive_share"] is not None and y["positive_share"] is not None and (x["positive"] + x["negative"]) >= 4:
                        if y["positive_share"] - x["positive_share"] >= 0.25:
                            why.append(f"{ASPECTS[k]['label'].lower()} complaints are more common on {lo['label']}")
            gap = {"high": hi["label"], "low": lo["label"], "high_rating": rating_of(hi), "low_rating": rating_of(lo),
                   "difference": diff,
                   "text": f"{rating_of(hi)}★ on {hi['label']} vs {rating_of(lo)}★ on {lo['label']}",
                   "likely_reasons": why[:3] or ["The reviews we read don't show a clear reason"]}

    # "Cheapest" only means something when at least two shops show a price.
    priced = [s for s in shops if s.get("price")]
    cheapest = None
    if len(priced) >= 2:
        low = min(s["price"] for s in priced)
        tied = [s for s in priced if s["price"] == low]
        cheapest = {**tied[0], "tied_with": [s["label"] for s in tied[1:]]}

    independent = _independent(opinions, reviews)
    return {"shops": shops, "gap": gap, "cheapest": cheapest, "independent": independent}


def _independent(opinions: dict | None, reviews: list[dict]) -> dict:
    if not opinions:
        return {"available": False, "text": "Independent opinions weren't checked", "sources": []}
    items, sources = [], []
    for src in ("youtube", "reddit"):
        o = opinions.get(src) or {}
        if not o.get("configured"):
            sources.append({"source": src, "label": PLATFORM_LABELS[src], "status": "not_set_up"})
            continue
        its = o.get("items") or []
        sources.append({"source": src, "label": PLATFORM_LABELS[src], "status": "ok" if its else "none_found",
                        "items": [{"title": i.get("title"), "url": i.get("url"), "channel": i.get("channel")} for i in its[:4]]})
        for i in its:
            for t in [i.get("title", ""), *(i.get("comments") or [])]:
                if t and len(t.split()) >= 3:
                    items.append(t)
    if not items:
        return {"available": False, "text": "No YouTube or Reddit opinions found" if any(s["status"] != "not_set_up" for s in sources)
                else "YouTube and Reddit aren't set up yet", "sources": sources}
    pol = [_vader.polarity_scores(normalize_hinglish(t))["compound"] for t in items]
    pos = sum(c >= 0.05 for c in pol)
    neg = sum(c <= -0.05 for c in pol)
    ind_share = pos / (pos + neg) if pos + neg else None
    shop_pol = [r["compound"] for r in reviews]
    sp, sn = sum(c >= 0.05 for c in shop_pol), sum(c <= -0.05 for c in shop_pol)
    shop_share = sp / (sp + sn) if sp + sn else None
    disagree = None
    if ind_share is not None and shop_share is not None and abs(ind_share - shop_share) >= 0.25:
        disagree = (f"Independent opinions are {'more negative' if ind_share < shop_share else 'more positive'} "
                    f"than shop reviews ({round(ind_share * 100)}% vs {round(shop_share * 100)}% positive)")
    return {"available": True, "positive_share": None if ind_share is None else round(ind_share, 3),
            "shop_positive_share": None if shop_share is None else round(shop_share, 3),
            "opinions_read": len(items), "disagreement": disagree, "sources": sources,
            "text": disagree or (f"Independent opinions mostly agree with shop reviews" if ind_share is not None else "")}


# ─── 7. Size advice (clothing) ────────────────────────────────────────
_SMALL = re.compile(r"\b(runs?\s+small|(too\s+|very\s+|bit\s+|little\s+)?(small|tight)\s+(for|than)|size\s+up|one\s+size\s+(up|bigger|larger)|order\s+(a\s+)?(bigger|larger)|chota|chhota|tight\s+fit(ting)?)\b", re.I)
_LARGE = re.compile(r"\b(runs?\s+(big|large)|(too\s+|very\s+)?(big|large|loose)\s+(for|than)|size\s+down|one\s+size\s+(down|smaller)|order\s+(a\s+)?smaller|bada|baggy|too\s+loose)\b", re.I)
_TRUE = re.compile(r"\b(true\s+to\s+size|perfect\s+fit|fits?\s+(perfectly|well|great)|size\s+is\s+(perfect|correct|accurate)|as\s+per\s+(the\s+)?size\s+chart|fitting\s+is\s+(perfect|good))\b", re.I)


def size_advice(reviews: list[dict], product: dict) -> dict | None:
    title = (product.get("title") or "").lower()
    clothing = product.get("platform") == "myntra" or re.search(
        r"\b(shirt|t-shirt|tshirt|kurta|kurti|dress|jeans|trouser|top|jacket|hoodie|shoe|sneaker|skirt|shorts|leggings|bra|track ?pants?|sweatshirt|blazer)s?\b", title)
    if not clothing:
        return None
    small = sum(1 for r in reviews if _SMALL.search(r["text"]) or _SMALL.search(r["en"]))
    large = sum(1 for r in reviews if _LARGE.search(r["text"]) or _LARGE.search(r["en"]))
    true = sum(1 for r in reviews if _TRUE.search(r["text"]))
    total = small + large + true
    fit_summary = product.get("fit_summary") or ""
    if total < 5:
        return {"advice": None, "text": "Not enough fit comments to give size advice", "small": small, "large": large,
                "true_to_size": true, "shop_summary": fit_summary or None}
    if small / total >= 0.6:
        text = "Most buyers say it runs small. Consider one size up."
    elif large / total >= 0.6:
        text = "Most buyers say it runs large. Consider one size down."
    elif true / total >= 0.6:
        text = "Most buyers say it's true to size."
    else:
        text = "Buyers are split on fit. Check the size chart."
    return {"advice": text, "text": text, "small": small, "large": large, "true_to_size": true,
            "shop_summary": fit_summary or None}


# ─── 8. Verdict + confidence ──────────────────────────────────────────
def pick_quotes(reviews: list[dict], k: int = 4) -> list[dict]:
    """Real excerpts: the most helpful substantial positive and negative reviews."""
    good = sorted([r for r in reviews if r["rating"] >= 4 and r["words"] >= 8], key=lambda r: (-r["helpful"], -r["words"]))
    bad = sorted([r for r in reviews if 0 < r["rating"] <= 2 and r["words"] >= 8], key=lambda r: (-r["helpful"], -r["words"]))
    picks, seen = [], set()
    for pool in (good[:2], bad[:2], good[2:4], bad[2:4]):
        for r in pool:
            if len(picks) >= k:
                break
            key = _norm_key(r["text"])[:60]
            if key in seen:
                continue
            seen.add(key)
            picks.append({"text": _quote(r["text"]), "rating": r["rating"], "platform": r["platform"],
                          "sentiment": "positive" if r["rating"] >= 4 else "negative"})
    return picks


def confidence(n: int, n_sources: int, trust: dict, aspects: dict, ratings: list[float]) -> dict:
    reasons = []
    if n < MIN_REVIEWS:
        return {"level": "none", "text": f"Only {n} reviews could be read, which isn't enough to judge this product.", "reasons": reasons}
    level = 2 if n >= 60 else 1 if n >= 30 else 0
    if n < 30:
        reasons.append(f"Based on only {n} reviews")
    if n_sources >= 2:
        level += 1
        reasons.append(f"Reviews from {n_sources} shops")
    if trust.get("level") == "low":
        level -= 1
        reasons.append("Many reviews look unreliable")
    if ratings:
        mean = sum(ratings) / len(ratings)
        var = sum((x - mean) ** 2 for x in ratings) / len(ratings)
        if var >= 2.0:
            level -= 1
            reasons.append("Buyers are strongly divided (many 5★ and many 1★)")
    lvl = "high" if level >= 3 else "medium" if level >= 1 else "low"
    text = {"high": "We're fairly confident in this result.",
            "medium": "Reasonably confident, but read the details.",
            "low": "Low confidence: signals are thin or mixed, so treat this as a hint."}[lvl]
    return {"level": lvl, "text": text, "reasons": reasons}


def star_basis(reviews: list[dict], sources: list[dict]) -> dict:
    """Stars to judge by. The shop's own overall rating + histogram cover far
    more buyers than the recent reviews we read, so blend them in."""
    ratings = [r["rating"] for r in reviews if r["rating"]]
    sample_avg = sum(ratings) / len(ratings) if ratings else None
    sample_low = sum(1 for x in ratings if x <= 2) / len(ratings) if ratings else None
    total_count, w_rating, w_low, w_low_n = 0, 0.0, 0.0, 0
    for s in sources:
        m = s.get("meta") or {}
        rating, count = m.get("rating"), m.get("rating_count") or 0
        if rating and count >= 50:
            total_count += count
            w_rating += float(rating) * count
            h = m.get("histogram") or {}
            if h:
                w_low += (float(h.get("1", 0)) + float(h.get("2", 0))) * count
                w_low_n += count
    listing_avg = w_rating / total_count if total_count else None
    listing_low = w_low / w_low_n if w_low_n else None
    avg = (0.5 * listing_avg + 0.5 * sample_avg) if listing_avg and sample_avg else listing_avg or sample_avg
    low = (0.5 * listing_low + 0.5 * sample_low) if listing_low is not None and sample_low is not None else         listing_low if listing_low is not None else sample_low
    return {"avg": avg, "low_share": low, "sample_avg": sample_avg, "listing_avg": listing_avg,
            "listing_count": total_count, "listing_low": listing_low}


def verdict(reviews: list[dict], aspects: dict, nas: dict, trust: dict, trnd: dict, xp: dict, conf: dict,
            stars: dict | None = None) -> dict:
    n = len(reviews)
    if conf["level"] == "none":
        return {"label": "Not enough reviews", "color": "grey", "score": None,
                "sentence": conf["text"], "reasons": []}
    stars = stars or star_basis(reviews, [])
    avg, low_share = stars["avg"], stars["low_share"] or 0
    score = (avg - 1) / 4 * 100  # 0..100 from stars
    reasons = []
    if stars["listing_avg"]:
        reasons.append(f"Rated {stars['listing_avg']:.1f}★ by {stars['listing_count']:,} buyers; "
                       f"{stars['sample_avg']:.1f}★ in the {n} recent reviews we read")
    else:
        reasons.append(f"Average {avg:.1f}★ across {n} reviews read")
    if low_share >= 0.15:
        reasons.append(f"{round(low_share * 100)}% of buyers gave 1–2★")
        score -= (low_share - 0.15) * 60

    score -= nas["share"] * 120
    if nas["share"] >= 0.06 and nas["types"]:
        reasons.append(f"{round(nas['share'] * 100)}% say it isn't like the photo or description (mostly: {nas['types'][0]['label'].lower()})")

    t = trust.get("score")
    if t is not None and t < 75:
        score -= (75 - t) * 0.5
        reasons.append(f"Review trust is {trust['level']} ({t}/100)")

    weak = [a for a in aspects.values() if a["positive_share"] is not None and (a["positive"] + a["negative"]) >= 5 and a["positive_share"] < 0.5]
    strong = [a for a in aspects.values() if a["positive_share"] is not None and (a["positive"] + a["negative"]) >= 5 and a["positive_share"] >= 0.75]
    for a in sorted(weak, key=lambda a: a["positive_share"])[:2]:
        score -= 6
        reasons.append(f"Buyers complain about {a['label'].lower()} ({round((1 - a['positive_share']) * 100)}% negative)")
    for a in sorted(strong, key=lambda a: -a["mentions"])[:2]:
        reasons.append(f"Buyers like the {a['label'].lower()} ({round(a['positive_share'] * 100)}% positive)")

    if trnd.get("status") == "worse":
        score -= 8
        reasons.append(trnd["aspects"][0]["text"] if trnd.get("aspects") else "Recent reviews are worse than older ones")
    if xp.get("gap"):
        reasons.append(f"Ratings differ between shops: {xp['gap']['text']}")
    ind = xp.get("independent") or {}
    if ind.get("disagreement"):
        reasons.append(ind["disagreement"])

    for f in trust.get("flags", [])[:2]:
        reasons.append(f["text"])

    score = max(0, min(100, round(score)))
    if score >= 68 and nas["share"] < 0.15 and trust.get("level") != "low":
        label, color = "Good buy", "green"
        sentence = ("Most buyers are happy and the reviews look genuine." if not trust.get("flags")
                    else "Most buyers are happy, though some reviews carry little detail.")
    elif score >= 45:
        label, color, sentence = "Buy with caution", "amber", "Mostly fine, but there are real complaints worth reading."
    else:
        label, color, sentence = "Avoid", "red", "Too many buyers report problems with this product."
    if label == "Good buy" and conf["level"] == "low":
        label, color, sentence = "Buy with caution", "amber", "Looks good, but there isn't much reliable data."
    return {"label": label, "color": color, "score": score, "sentence": sentence, "reasons": reasons}


# ─── Entry point ──────────────────────────────────────────────────────
def analyze_reviews(payload: dict) -> dict:
    product = payload.get("product") or {}
    sources = payload.get("sources") or []
    reviews, stats = clean_reviews(sources, payload.get("collected_at"))
    aspects = aspect_sentiment(reviews)
    nas = not_as_shown(reviews)
    nas_by_platform = {}
    for p in {r["platform"] for r in reviews}:
        rs = [r for r in reviews if r["platform"] == p]
        nas_by_platform[p] = not_as_shown(rs)["share"]
    trust = trust_signals(reviews)
    trnd = trend(reviews, stats["collected_on"])
    xp = cross_platform(reviews, sources, payload.get("listings") or [], payload.get("opinions"), product, nas_by_platform)
    n_sources = len({r["platform"] for r in reviews})
    conf = confidence(len(reviews), n_sources, trust, aspects, [r["rating"] for r in reviews if r["rating"]])
    stars = star_basis(reviews, sources)
    v = verdict(reviews, aspects, nas, trust, trnd, xp, conf, stars)
    notes = [s.get("note") for s in sources if s.get("note")]
    return {
        "product": {"title": product.get("title", ""), "brand": product.get("brand", ""),
                    "platform": product.get("platform", ""), "url": product.get("url", ""),
                    "image": product.get("image", ""), "price": product.get("price"),
                    "rating": product.get("rating"), "rating_count": product.get("rating_count")},
        "reviews_analysed": len(reviews),
        "stats": {**stats, "per_platform": dict(Counter(r["platform"] for r in reviews)), "notes": notes},
        "verdict": v,
        "confidence": conf,
        "not_as_shown": nas,
        "aspects": aspects,
        "trust": trust,
        "trend": trnd,
        "cross_platform": xp,
        "size_advice": size_advice(reviews, product),
        "quotes": pick_quotes(reviews) if conf["level"] != "none" else [],
    }
