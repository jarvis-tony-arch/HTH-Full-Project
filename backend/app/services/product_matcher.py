"""Is this listing the same product? (entity resolution across shops)

Light enough for Render's free tier: regex + TF-IDF on character n-grams,
no neural models. Every decision comes with plain-English reasons.

Scores (0..1) are combined from:
  brand      exact brand match, or a look-alike brand (likely a copy)
  model      model numbers / codes, normalised ("Airdopes141" == "Airdopes 141")
  specs      capacity, size, wattage etc. that both titles mention
  title      TF-IDF cosine on char 3-5 grams (tolerates spelling and
             transliteration differences) + word overlap
"""
from __future__ import annotations

import re
from difflib import SequenceMatcher

from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

MATCH = "match"
POSSIBLE = "possible"
NO_MATCH = "no_match"

# Words that describe the listing, not the product.
_NOISE = {
    "new", "launch", "launched", "latest", "with", "and", "for", "the", "of", "in", "up", "to",
    "upto", "buy", "online", "best", "price", "india", "pack", "combo", "edition", "official",
    "original", "genuine", "free", "offer", "sale", "deal", "hot", "bestseller", "sponsored",
}
_COLOURS = {
    "black", "white", "blue", "red", "green", "grey", "gray", "silver", "gold", "pink", "purple",
    "yellow", "orange", "brown", "beige", "navy", "maroon", "olive", "teal", "cream", "charcoal",
    "khaki", "mustard", "lavender", "peach", "multicolor", "multicolour",
}
_GENERATION = re.compile(r"\b(gen|generation|mark|mk|series|version|v)\s*\.?\s*(\d+)\b", re.I)
_SPEC = re.compile(
    r"\b(\d+(?:\.\d+)?)\s*(gb|tb|mah|ml|l|ltr|litre|liter|kg|g|gm|w|watt|hz|inch|in|cm|mm|hours?|hrs?|h|jars?)\b",
    re.I,
)
_SPEC_UNIT = {"jar": "jars", "ltr": "l", "litre": "l", "liter": "l", "gm": "g", "watt": "w", "in": "inch",
              "hour": "h", "hours": "h", "hr": "h", "hrs": "h"}
# Sizes for clothes / shoes
_SIZE = re.compile(r"\b(xxs|xs|s|m|l|xl|xxl|xxxl|[2-5]xl|uk\s?\d{1,2}|size\s?\d{1,2})\b", re.I)


def normalise(text: str) -> str:
    t = (text or "").lower()
    t = t.replace("™", " ").replace("®", " ").replace("&", " and ")
    t = re.sub(r"[^a-z0-9.+\s-]", " ", t)
    t = re.sub(r"(?<=[a-z])-(?=\d)|(?<=\d)-(?=[a-z])", "", t)  # "pa-0098" -> "pa0098"
    return re.sub(r"\s+", " ", t).strip()


def words(text: str) -> list[str]:
    return [w for w in normalise(text).replace("-", " ").split() if w not in _NOISE]


# Words that turn one model into another: "iPhone 15" vs "iPhone 15 Plus".
_QUALIFIERS = {"pro", "plus", "ultra", "fe", "lite", "max", "mini", "neo", "prime", "elite", "edge", "air", "anc", "ace"}
# A number followed by one of these is a spec, not a model number ("10 length settings").
_NOT_MODEL_NEXT = {"min", "mins", "minutes", "length", "settings", "setting", "hours", "hrs", "hour", "mics", "mic",
                   "jars", "jar", "speed", "speeds", "months", "month", "years", "year", "yrs", "pack", "pcs", "pieces",
                   "days", "modes", "mode", "drivers", "combs", "comb", "attachments", "in", "x", "inch", "cm", "mm",
                   "nits", "rpm", "litre", "liters", "l", "kg", "ml", "w", "watt", "percent", "off"}
_ACCESSORY = re.compile(
    r"\b(case|cover|back cover|flip cover|screen guard|tempered glass|screen protector|protector|skin|pouch|"
    r"charger|charging cable|cable|adapter|strap|band for|replacement|spare|back panel|housing|full panel|"
    r"display combo|digitizer|battery for|compatible with|for (?:apple|samsung|oneplus|redmi|xiaomi|vivo|oppo|realme|iphone))\b",
    re.I)
_BUNDLE = re.compile(r"\b(with protect\+?|applecare|combo|pack of \d+|bundle|with (?:case|cover|charger))", re.I)


def model_zone(text: str) -> str:
    """The part of a title that names the product: before the first
    "(", "|", ",", ":", " - " or " with ". Marketing text comes after."""
    t = (text or "").replace("™", " ").replace("®", " ")
    return re.split(r"\(|\||,|:|;| - | – |\bwith\b|\bfeaturing\b", t, maxsplit=1, flags=re.I)[0]


def qualifiers(text: str) -> set[str]:
    z = normalise(model_zone(text)).replace("+", " plus ").replace("-", " ")
    out: set[str] = set()
    for t in z.split():
        if t in _QUALIFIERS:
            out.add(t)
            continue
        m = re.fullmatch(r"(pro|ultra|max|lite|mini|plus|fe|neo)(\d+)", t)
        if m:
            out.add(m.group(1))
            continue
        m = re.fullmatch(r"\d{1,3}([a-z])", t)  # "16e", "6r", "13s", "4i" ("5g" is the network)
        if m and m.group(1) not in {"g", "k", "w", "h", "l", "v", "a", "m"}:
            out.add("sfx_" + m.group(1))
            continue
        m = re.fullmatch(r"[a-z]{1,3}\d{1,3}([a-z])", t)  # "T5x", "A15s"
        if m and m.group(1) not in {"g", "k", "w", "h"}:
            out.add("sfx_" + m.group(1))
    return out


def is_accessory(text: str) -> bool:
    return bool(_ACCESSORY.search(text or ""))


def model_codes(text: str) -> set[str]:
    """Things that look like model numbers, in one canonical form.

    "boAt Airdopes 141 Gen 2 (PA0098)" -> {"airdopes141", "141", "gen2", "pa0098"}
    """
    t = normalise(text)
    codes: set[str] = set()
    for m in _GENERATION.finditer(t):
        codes.add(f"gen{m.group(2)}")
    t_wo_specs = _SPEC.sub(" ", _NETWORK.sub(" ", _GENERATION.sub(" ", t)))
    t_wo_specs = re.sub(r"\b(pro|ultra|max|lite|mini|plus|neo)(\d+)\b", r"\1 \2", t_wo_specs)
    toks = t_wo_specs.replace("-", " ").replace("/", " ").split()
    for i, w in enumerate(toks):
        nxt = toks[i + 1] if i + 1 < len(toks) else ""
        prev = toks[i - 1] if i > 0 else ""
        glue_ok = bool(re.fullmatch(r"[a-z]{2,}", prev)) and prev not in _NOISE | _NOT_MODEL_NEXT
        if re.fullmatch(r"[a-z]+\d+[a-z0-9]*|\d+[a-z]+[a-z0-9]*", w) and len(w) >= 2:
            codes.add(w)
            m = re.fullmatch(r"(\d{2,5})([a-z]{1,3})", w)  # "16e", "520bt" -> also "16", "520"
            if m:
                codes.add(m.group(1))
                if glue_ok:
                    codes.add(prev + m.group(1))
        elif re.fullmatch(r"\d{1,5}", w) and nxt not in _NOT_MODEL_NEXT:
            if len(w) >= 2:
                codes.add(w)
            if glue_ok:
                codes.add(prev + w)  # "airdopes 141" -> "airdopes141"
    # glued forms: "airdopes141" also implies "141"
    for c in list(codes):
        m = re.fullmatch(r"([a-z]{3,})(\d{2,5})", c)
        if m:
            codes.add(m.group(2))
    return codes


_NETWORK = re.compile(r"\b[2345]g\b")  # "5G" phones, not 5 grams


def specs(text: str) -> dict[str, set[str]]:
    """{"gb": {"12", "256"}, "w": {"750"}} — a set, since phones list RAM and storage."""
    out: dict[str, set[str]] = {}
    for num, unit in _SPEC.findall(_NETWORK.sub(" ", normalise(text))):
        u = _SPEC_UNIT.get(unit.lower(), unit.lower())
        out.setdefault(u, set()).add(num.rstrip("0").rstrip(".") if "." in num else num)
    return out


def colours(text: str) -> set[str]:
    return {w for w in words(text) if w in _COLOURS}


# Same maker, different spellings on different shops.
_BRAND_ALIASES = {"mi": "xiaomi", "xiaomi": "xiaomi", "1+": "oneplus", "one plus": "oneplus", "boat": "boat",
                  "hp": "hp", "hewlett packard": "hp", "lg electronics": "lg", "samsung electronics": "samsung"}


def canon_brand(b: str) -> str:
    return _BRAND_ALIASES.get(b, b)


def brand_of(item: dict) -> str:
    b = normalise(item.get("brand") or "")
    b = re.sub(r"^(visit the|brand)\s+", "", b).replace(" store", "").strip()
    if b:
        return b
    w = words(item.get("title") or "")
    return w[0] if w else ""


def _brand_score(a: dict, b: dict) -> tuple[float, str | None, bool]:
    """(score, reason, conflict)."""
    ba, bb = canon_brand(brand_of(a)), canon_brand(brand_of(b))
    if not ba or not bb:
        return 0.5, None, False
    title_b = normalise(b.get("title") or "")
    if ba == bb or (ba in title_b.split()[:4]):
        return 1.0, f"Same brand ({a.get('brand') or ba})", False
    ratio = SequenceMatcher(None, ba, bb).ratio()
    if ratio >= 0.6:
        return 0.0, f"Look-alike brand \"{b.get('brand') or bb}\" instead of \"{a.get('brand') or ba}\": could be a copy", True
    return 0.0, f"Different brand ({b.get('brand') or bb})", True


def _model_score(a: dict, b: dict) -> tuple[float, str | None, bool]:
    qa, qb = qualifiers(a.get("title") or ""), qualifiers(b.get("title") or "")
    both_have_codes = bool(model_codes(model_zone(a.get("title") or ""))) and bool(model_codes(model_zone(b.get("title") or "")))
    if qa != qb and both_have_codes:
        def nice(q):
            return ", ".join(sorted(x[4:].upper() if x.startswith("sfx_") else x.title() for x in q)) or "plain"
        return 0.0, f"Different version ({nice(qa)} vs {nice(qb)})", True
    za = " ".join(filter(None, [model_zone(a.get("title") or ""), a.get("model")]))
    zb = " ".join(filter(None, [model_zone(b.get("title") or ""), b.get("model")]))
    ca, cb = model_codes(za), model_codes(zb)
    if not ca or not cb:
        # Some titles put the model code at the end ("... | BT3325").
        ca = ca or model_codes(" ".join(filter(None, [a.get("title"), a.get("model")])))
        cb = cb or model_codes(" ".join(filter(None, [b.get("title"), b.get("model")])))
    if not ca or not cb:
        return 0.5, None, False
    shared = ca & cb
    ga = {c for c in ca if c.startswith("gen")}
    gb = {c for c in cb if c.startswith("gen")}
    if ga and gb and not (ga & gb):
        return 0.0, f"Different generation ({', '.join(sorted(ga))} vs {', '.join(sorted(gb))})", True
    nums_a = {c for c in ca if c.isdigit()}
    nums_b = {c for c in cb if c.isdigit()}
    if nums_a and nums_b and not (nums_a & nums_b):
        return 0.0, f"Different model number ({'/'.join(sorted(nums_a))} vs {'/'.join(sorted(nums_b))})", True
    # Same series letters, different number: "S24" vs "S23", "Airdopes141" vs "Airdopes131".
    def series(codes):
        out = {}
        for c in codes:
            m = re.fullmatch(r"([a-z]+)(\d+)", c)
            if m and not c.startswith("gen"):
                out.setdefault(m.group(1), set()).add(m.group(2))
        return out
    sa, sb = series(ca), series(cb)
    for prefix in set(sa) & set(sb):
        if not (sa[prefix] & sb[prefix]):
            return 0.0, f"Different model ({prefix.upper()}{'/'.join(sorted(sa[prefix]))} vs {prefix.upper()}{'/'.join(sorted(sb[prefix]))})", True
    if ga and not gb or gb and not ga:
        # "Airdopes 141" vs "Airdopes 141 Gen 2" are different products.
        if shared:
            return 0.4, "One listing is a newer generation", False
    long_shared = [c for c in shared if not c.isdigit() and not c.startswith("gen")]
    if long_shared:
        return 1.0, f"Same model ({sorted(long_shared, key=len)[-1].upper()})", False
    if shared:
        return 0.8, f"Same model number ({sorted(shared, key=len)[-1].upper()})", False
    return 0.3, None, False


def _spec_score(a: dict, b: dict) -> tuple[float, list[str], bool]:
    sa, sb = specs(a.get("title") or ""), specs(b.get("title") or "")
    common = set(sa) & set(sb)
    if not common:
        return 0.5, [], False
    def agree(u):
        if u == "gb":
            # Phones list RAM and storage: compare the biggest (storage) and,
            # when both list RAM, the smallest too.
            xa, xb = sorted(sa[u], key=float), sorted(sb[u], key=float)
            if xa[-1] != xb[-1]:
                return False
            if len(xa) > 1 and len(xb) > 1 and xa[0] != xb[0]:
                return False
            return True
        return bool(sa[u] & sb[u])
    same = [u for u in common if agree(u)]
    diff = [u for u in common if not agree(u)]
    fmt = lambda vals, u: "/".join(sorted(vals, key=lambda v: float(v))) + u
    reasons = []
    if same:
        reasons.append("Same " + ", ".join(fmt(sa[u] & sb[u] or sa[u], u) for u in sorted(same)))
    if diff:
        reasons.append("Different " + ", ".join(f"{fmt(sa[u], u)} vs {fmt(sb[u], u)}" for u in sorted(diff)))
    # Battery hours differ a lot between listings of the same item, so they
    # never count as a hard conflict.
    hard = [u for u in diff if u not in {"h"}]
    return len(same) / len(common), reasons, bool(hard)


def title_similarity(titles_a: list[str], titles_b: list[str]) -> list[float]:
    """TF-IDF char n-gram cosine, a with each b."""
    docs = [" ".join(words(t)) for t in titles_a + titles_b]
    if not any(docs):
        return [0.0] * len(titles_b)
    vec = TfidfVectorizer(analyzer="char_wb", ngram_range=(3, 5), sublinear_tf=True)
    m = vec.fit_transform(docs)
    sims = cosine_similarity(m[: len(titles_a)], m[len(titles_a):])
    return [float(x) for x in sims.max(axis=0)]


def _token_overlap(a: str, b: str) -> float:
    wa, wb = set(words(a)) - _COLOURS, set(words(b)) - _COLOURS
    if not wa or not wb:
        return 0.0
    return len(wa & wb) / min(len(wa), len(wb))


def score_pair(product: dict, cand: dict, tfidf: float) -> dict:
    reasons: list[str] = []
    bscore, breason, bconf = _brand_score(product, cand)
    mscore, mreason, mconf = _model_score(product, cand)
    sscore, sreasons, sconf = _spec_score(product, cand)
    overlap = _token_overlap(product.get("title") or "", cand.get("title") or "")
    tscore = 0.6 * tfidf + 0.4 * overlap

    score = 0.30 * bscore + 0.30 * mscore + 0.10 * sscore + 0.30 * tscore
    for r in [breason, mreason, *sreasons]:
        if r:
            reasons.append(r)
    reasons.append(f"Titles {round(tscore * 100)}% similar")
    ca, cb = colours(product.get("title") or ""), colours(cand.get("title") or "")
    if ca and cb and not (ca & cb):
        reasons.append("Different colour (same product, other variant)")

    acc = is_accessory(cand.get("title") or "") and not is_accessory(product.get("title") or "")
    if acc:
        reasons.insert(0, "Looks like an accessory or spare part, not the product itself")
    bundle = bool(_BUNDLE.search(cand.get("title") or "")) != bool(_BUNDLE.search(product.get("title") or ""))
    if bundle:
        reasons.append("Sold as a bundle or with an extra plan")

    conflict = bconf or mconf or sconf or acc
    if conflict:
        decision = NO_MATCH
        score = min(score, 0.35)
    elif score >= 0.75 and bscore == 1.0 and mscore >= 0.8:
        decision = MATCH
    elif bscore == 1.0 and mscore == 0.5 and sscore == 1.0 and tscore >= 0.65:
        # No model number on either listing: same brand, same specs, very similar title.
        decision = MATCH
    elif score >= 0.55:
        decision = POSSIBLE
    else:
        decision = NO_MATCH
    if bundle and decision == MATCH:
        decision = POSSIBLE  # same product, different package: ask the user
    return {
        "decision": decision,
        "confidence": round(score, 3),
        "reasons": reasons,
        "parts": {"brand": round(bscore, 2), "model": round(mscore, 2), "specs": round(sscore, 2),
                  "title": round(tscore, 2)},
    }


def match_products(product: dict, candidates: list[dict]) -> dict:
    """product/candidates: {platform, title, brand?, model?, price?, rating?, url}."""
    if not candidates:
        return {"results": [], "summary": "Couldn't find this exact product elsewhere"}
    titles_a = [t for t in [product.get("title"), " ".join(filter(None, [product.get("brand"), product.get("model")]))] if t]
    sims = title_similarity(titles_a, [c.get("title") or "" for c in candidates])
    results = []
    for cand, sim in zip(candidates, sims):
        r = score_pair(product, cand, sim)
        results.append({**r, "candidate": cand})
    results.sort(key=lambda r: (r["decision"] != MATCH, r["decision"] != POSSIBLE, -r["confidence"]))
    # One best listing per platform per decision is enough for the app.
    best: dict[tuple[str, str], dict] = {}
    for r in results:
        key = (r["candidate"].get("platform", ""), r["decision"])
        best.setdefault(key, r)
    kept = [r for r in results if best.get((r["candidate"].get("platform", ""), r["decision"])) is r]
    n_match = sum(r["decision"] == MATCH for r in kept)
    summary = (f"Found on {n_match} other shop{'s' if n_match != 1 else ''}" if n_match
               else "Couldn't find this exact product elsewhere")
    return {"results": kept, "summary": summary}


def search_query(product: dict, max_words: int = 6) -> str:
    """Short query for store search boxes: brand + model-ish words."""
    brand = brand_of(product)
    ws = [w for w in words(product.get("title") or "") if w not in _COLOURS and not re.fullmatch(r"\d{4}", w)]
    if brand and ws and ws[0] == brand:
        ws = ws[1:]
    keep: list[str] = []
    unit = r"(h|hrs?|hours?|mah|gb|tb|w|watt|mm|ml|l|kg|g)"
    for i, w in enumerate(ws):
        if len(keep) >= max_words:
            break
        nxt = ws[i + 1] if i + 1 < len(ws) else ""
        # Stop at specs ("48h", "50 hours"); keep model numbers ("141", "gen 2").
        if re.fullmatch(r"\d+(\.\d+)?" + unit, w) or (re.fullmatch(r"[\d.]+", w) and re.fullmatch(unit, nxt)):
            break
        keep.append(w)
    return " ".join(([brand] if brand else []) + keep)
