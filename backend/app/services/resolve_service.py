"""
Resolve service: turns a user's own words into a clear fix.

Pipeline (see PIVOT_PLAN.md, Step 2):
  1. section + company detection     -> detect_company()
  2. entity extraction               -> extract_details()
  3. issue classification            -> classify_issues()  (reuses nlp_service)
  4. entitlement engine (travel)     -> entitlements_for()
  5. escalation engine               -> build_steps()
  6. urgency                         -> detect_urgency()
  7. complaint email                 -> write_complaint()
  8. clarification                   -> resolve()

Every contact, rule and rupee amount comes from data/knowledge_base.json,
which stores the official source for each one. Nothing here invents values:
when the knowledge base has null, the step is marked unverified and the app
shows "Check the official page".
"""
import json
import re
from difflib import SequenceMatcher
from pathlib import Path

from app.services.nlp_service import (
    analyze as nlp_analyze,
    is_hinglish,
    normalize_hinglish,
    nlp_spacy,
)

KB_PATH = Path(__file__).resolve().parent.parent / "data" / "knowledge_base.json"
with open(KB_PATH, encoding="utf-8") as _f:
    KB = json.load(_f)

COMPANIES = KB["companies"]
ISSUES = KB["issues"]
SOURCES = KB["sources"]
AUTHORITIES = KB["authorities"]
RULES = KB["rules"]
LADDERS = KB["ladders"]

CHECK_OFFICIAL = "Check the official page"
CLARIFY_THRESHOLD = 0.6

# ─── 1. Section + company detection ───────────────────

FLIGHT_CODES = {
    c["flight_code"].lower(): cid
    for cid, c in COMPANIES.items() if c.get("flight_code")
}

FLIGHT_WORDS = r"\b(flight|flights|airline|airport|plane|boarding|board|check[- ]?in|baggage|luggage|udaan|fly|flew)\b"
TRAIN_WORDS = r"\b(train|trains|railway|railways|irctc|tdr|rail|station|coach|berth|tatkal)\b"
SHOPPING_WORDS = (
    r"\b(order|ordered|delivery|delivered|parcel|package|product|item|refund|return|"
    r"exchange|size|fit|kurta|shirt|jeans|dress|saree|shoes|cod|seller|cart)\b"
)


def _norm(text: str) -> str:
    return re.sub(r"\s+", " ", text.lower()).strip()


def _fuzzy_hit(word: str, alias: str) -> bool:
    # Only fuzzy-match longer words, so "ai" or "fk" never match by accident.
    if len(alias) < 5 or len(word) < 5 or " " in alias:
        return False
    return SequenceMatcher(None, word, alias).ratio() >= 0.84


def detect_company(text: str, section_hint=None, company_hint=None) -> dict:
    """Return {section, company, company_confidence, section_confidence, matched}."""
    low = _norm(text)

    if company_hint and company_hint in COMPANIES:
        c = COMPANIES[company_hint]
        return {
            "section": c["section"], "company": company_hint,
            "company_confidence": 1.0, "section_confidence": 1.0,
            "matched": [f"you picked {c['name']}"],
        }

    best = (None, 0.0, None)  # (company_id, confidence, matched text)

    # Exact alias match (multi-word aliases first)
    for cid, c in COMPANIES.items():
        for alias in sorted(c["aliases"], key=len, reverse=True):
            if len(alias) <= 3:
                continue  # short codes handled below with digits
            if re.search(r"\b" + re.escape(alias) + r"\b", low):
                conf = 0.95 if cid != "indian_railways" else 0.85
                if conf > best[1]:
                    best = (cid, conf, alias)
                break

    # Flight number like "6E 2134", "AI 101", "SG-8169"
    m = re.search(r"\b(6e|ai|qp|sg)\s?-?\s?(\d{2,4})\b", low)
    if m and FLIGHT_CODES.get(m.group(1)):
        cid = FLIGHT_CODES[m.group(1)]
        if best[1] < 0.9:
            best = (cid, 0.9, m.group(0))

    # Misspellings ("flipcart", "myntraa", "indgo")
    if best[0] is None:
        words = re.findall(r"[a-z]+", low)
        for cid, c in COMPANIES.items():
            for alias in c["aliases"]:
                hit = next((w for w in words if _fuzzy_hit(w, alias)), None)
                if hit:
                    best = (cid, 0.75, hit)
                    break
            if best[0]:
                break

    company, conf, matched_word = best
    matched = [matched_word] if matched_word else []

    # Section
    if company:
        section = COMPANIES[company]["section"]
        section_conf = conf
    elif section_hint in KB["sections"]:
        section, section_conf = section_hint, 1.0
    else:
        travel = re.search(FLIGHT_WORDS, low) or re.search(TRAIN_WORDS, low)
        shop = re.search(SHOPPING_WORDS, low)
        if travel and not shop:
            section, section_conf = "travel", 0.8
            matched.append(travel.group(0))
        elif shop and not travel:
            section, section_conf = "shopping", 0.8
            matched.append(shop.group(0))
        else:
            section, section_conf = None, 0.0

    if section_hint in KB["sections"] and section != section_hint and not company:
        section, section_conf = section_hint, 1.0

    # Train is a single company: infer it from train words
    if not company and section == "travel" and re.search(TRAIN_WORDS, low):
        company, conf = "indian_railways", 0.85
        matched.append(re.search(TRAIN_WORDS, low).group(0))

    return {
        "section": section,
        "company": company,
        "company_confidence": round(conf, 2),
        "section_confidence": round(section_conf, 2),
        "matched": matched,
    }


# ─── 2. Entity extraction ──────────────────────────────

WORD_NUMBERS = {
    "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
    "eight": 8, "nine": 9, "ten": 10, "twelve": 12, "fifteen": 15, "twenty": 20,
    "ek": 1, "do": 2, "teen": 3, "char": 4, "chaar": 4, "paanch": 5, "panch": 5,
    "chhe": 6, "saat": 7, "aath": 8, "nau": 9, "das": 10,
}


def _num(s: str):
    s = s.strip().lower().replace(",", "")
    if s in WORD_NUMBERS:
        return WORD_NUMBERS[s]
    try:
        v = float(s)
        return int(v) if v.is_integer() else v
    except ValueError:
        return None


NUM = r"(\d+(?:\.\d+)?|" + "|".join(WORD_NUMBERS) + r")"


def extract_details(text: str) -> dict:
    """Pull out IDs, amounts, times and other details. Missing ones are left out."""
    low = _norm(text)
    d = {}

    # Order ID: "order id 403-1234567-1234567", "OD12345678901", "order #45821"
    m = re.search(r"\b(\d{3}-\d{7}-\d{7})\b", text)  # Amazon format
    if not m:
        m = re.search(r"\b(OD\d{10,20})\b", text, re.I)  # Flipkart format
    if not m:
        m = re.search(r"order\s*(?:id|no\.?|number|#)?\s*[:#-]?\s*#?([A-Z0-9-]{5,24})\b", text, re.I)
        if m and not re.search(r"\d", m.group(1)):
            m = None
    if not m:
        m = re.search(r"#([A-Z0-9-]{4,20})\b", text, re.I)
    if m:
        d["order_id"] = m.group(1).upper()

    # Amount: ₹2,499 / Rs. 2499 / INR 500 / 2499 rupees / "2499 ka"
    m = re.search(r"(?:₹|rs\.?|inr|rupees?)\s*([\d,]+(?:\.\d{1,2})?)", low)
    if not m:
        m = re.search(r"\b([\d,]{2,9}(?:\.\d{1,2})?)\s*(?:rs\.?|rupees?|rupaye|rupay|inr|/-|ka\b|ki\b|ke\b)", low)
    if m:
        amt = _num(m.group(1))
        if amt and amt >= 10:
            d["amount"] = amt

    # Duration waiting: "10 din se", "2 weeks", "a month"
    m = re.search(NUM + r"\s*(din|days?|dino)\b", low)
    if m and _num(m.group(1)) is not None:
        d["days_waiting"] = _num(m.group(1))
    else:
        m = re.search(NUM + r"\s*(hafte|hafta|weeks?)\b", low)
        if m and _num(m.group(1)) is not None:
            d["days_waiting"] = _num(m.group(1)) * 7
        else:
            m = re.search(NUM + r"\s*(mahine|mahina|months?)\b", low)
            if m and _num(m.group(1)) is not None:
                d["days_waiting"] = _num(m.group(1)) * 30
            elif re.search(r"\b(a|one|ek)\s+(week|hafta)\b", low):
                d["days_waiting"] = 7
            elif re.search(r"\b(a|one|ek)\s+(month|mahina)\b", low):
                d["days_waiting"] = 30

    # Delay: "7 ghante late", "delayed by 5 hrs", "late by 3 hours", "4.5 hours delay"
    hour_unit = r"(ghante|ghanta|ghante|hours?|hrs?|hr|h)\b"
    m = (re.search(r"(?:delayed|late|delay)\s*(?:by|of)?\s*" + NUM + r"\s*" + hour_unit, low)
         or re.search(NUM + r"\s*" + hour_unit + r"\s*(?:se\s*)?(?:late|delay|delayed|der)", low)
         or re.search(NUM + r"\s*" + hour_unit + r"[^.]{0,25}\b(?:late|delay|delayed)\b", low))
    if m and _num(m.group(1)) is not None:
        d["delay_hours"] = _num(m.group(1))

    # Notice before cancellation: "cancelled 2 hours before", "1 din pehle bataya"
    m = re.search(NUM + r"\s*(ghante|hours?|hrs?|din|days?|weeks?|hafte)\s*(before|pehle|prior)", low)
    if m and _num(m.group(1)) is not None and re.search(r"cancel", low):
        n, unit = _num(m.group(1)), m.group(2)
        mult = 1 if unit.startswith(("ghante", "hour", "hr")) else (168 if unit.startswith(("week", "hafte")) else 24)
        d["notice_hours"] = n * mult
    elif re.search(r"\b(last minute|at the airport|airport pe|airport par|no notice|without notice|bina bataye)\b", low) and "cancel" in low:
        d["notice_hours"] = 0

    # Flight length: "2 hour flight", "1.5 ghante ki flight"
    m = re.search(NUM + r"\s*(?:ghante|hours?|hrs?|hr)\s*(?:ki|ka|long)?\s*flight", low)
    if m and _num(m.group(1)) is not None:
        d["block_hours"] = _num(m.group(1))

    # Departure time: "9 pm flight", "21:30 departure", "raat 11 baje"
    m = re.search(r"\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b", low)
    if m:
        h = int(m.group(1)) % 12 + (12 if m.group(3) == "pm" else 0)
        d["departure_hour"] = h
    else:
        m = re.search(r"\b([01]?\d|2[0-3]):([0-5]\d)\b", low)
        if m:
            d["departure_hour"] = int(m.group(1))
        elif re.search(r"\braat\s*(\d{1,2})\s*baje", low):
            h = int(re.search(r"\braat\s*(\d{1,2})\s*baje", low).group(1))
            d["departure_hour"] = h + 12 if 6 <= h <= 11 else h % 12

    # PNRs, flight and train numbers
    m = re.search(r"pnr\s*(?:no\.?|number|is|:|-)?\s*([0-9]{10})\b", low)
    if m:
        d["train_pnr"] = m.group(1)
    else:
        m = re.search(r"\b([0-9]{10})\b", low)
        if m and re.search(TRAIN_WORDS, low):
            d["train_pnr"] = m.group(1)
    m = re.search(r"pnr\s*(?:no\.?|number|is|:|-)?\s*([a-z0-9]{6})\b", low)
    if m and "train_pnr" not in d and re.search(r"[a-z]", m.group(1)):
        d["airline_pnr"] = m.group(1).upper()
    m = re.search(r"\b(6e|ai|qp|sg)\s?-?\s?(\d{2,4})\b", low)
    if m:
        d["flight_number"] = f"{m.group(1).upper()} {m.group(2)}"
    m = re.search(r"train\s*(?:no\.?|number|#)?\s*[:#-]?\s*(\d{5})\b", low) or re.search(r"\b(\d{5})\s*(?:express|exp|mail|rajdhani|shatabdi|vande)", low)
    if m:
        d["train_number"] = m.group(1)

    # Has the train left?
    if re.search(r"(abhi|still|yet).{0,20}(nahi|nhi|not|na).{0,10}(nikli|nikla|chali|left|departed|depart|aayi|aai|aaya)"
                 r"|(not|hasn'?t|has not|didn'?t|yet to)\s*(left|depart|departed|started)"
                 r"|(train|gaadi).{0,25}(nahi|nhi)\s*(nikli|chali|aayi|aai)"
                 r"|still at (the )?(station|platform)|abhi platform pe|leaving soon|nikalne wali", low):
        d["train_departed"] = False
    elif re.search(r"(already|pehle hi)\s*(left|departed|nikal)|train\s*(nikal|chali)\s*gayi|has (left|departed)", low):
        d["train_departed"] = True

    # Food refused (supports the meals entitlement in the complaint)
    if re.search(r"(khana|food|meal|meals|snacks?|water|paani|refreshments?).{0,25}(nahi|nhi|not|no)\b"
                 r"|\b(no|nahi|nhi|without)\s*(food|meal|meals|khana|refreshments?|water|paani)", low):
        d["meals_refused"] = True

    # Payment mode
    m = re.search(r"\b(upi|gpay|google pay|phonepe|phone pe|paytm|bhim|credit card|debit card|card|net ?banking|cod|cash on delivery)\b", low)
    if m:
        d["payment_method"] = m.group(1).upper() if m.group(1) in ("upi", "cod") else m.group(1).title()

    # Dates (simple dd/mm/yyyy, then spaCy dates that name a day or month)
    taken = {str(v).lower() for v in d.values()}
    m = re.search(r"(?<![\d-])(\d{1,2}[/.]\d{1,2}(?:[/.]\d{2,4})?)(?![\d-])", text)
    if m:
        d["date"] = m.group(1)
    else:
        month_or_day = (r"\b(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec|january|february|march|april|"
                        r"june|july|august|september|october|november|december|monday|tuesday|wednesday|"
                        r"thursday|friday|saturday|sunday|yesterday|today|kal|aaj)\b")
        doc = nlp_spacy(text)
        for ent in doc.ents:
            if (ent.label_ == "DATE" and ent.text.lower() not in taken
                    and re.search(month_or_day, ent.text, re.I)):
                d["date"] = ent.text
                break

    return d


# ─── 3. Issue classification ───────────────────────────

# One clear mapping from the existing NLP intents to the new issue slugs.
INTENT_TO_ISSUE = {
    "delivery_issue": "late_delivery",
    "order_status": "late_delivery",
    "refund_request": "refund_delay",
    "wrong_item": "wrong_or_damaged_item",
    "damaged_item": "wrong_or_damaged_item",
    "duplicate_payment": "payment_deducted_no_order",
    "payment_failure": "payment_deducted_no_order",
    "unauthorized_payment": "payment_deducted_no_order",
}

# Extra cue patterns: where keyword lists alone are too loose or too strict.
ISSUE_PATTERNS = {
    "size_or_fit_return": r"\b(size|fit|fitting|tight|loose|chota|chhota|bada|too (small|big|large|short|long))\b",
    "return_rejected": r"\breturn\b.{0,30}\b(reject|rejected|denied|refused|cancel|cancelled|nahi le|nhi le|not accept)",
    "payment_deducted_no_order": r"(deduct|debit|kat|cut).{0,40}(no order|order (not|nahi|nhi)|not placed|place nahi|nahi hua|nhi hua|failed)|"
                                 r"(no order|order (not|nahi|nhi) (placed|hua|bana)).{0,40}(deduct|debit|kat)",
    "flight_delay": r"\b(delay|delayed|late|der)\b",
    "flight_cancellation": r"\bcancel",
    "denied_boarding": r"(denied boarding|offload|overbook|not allowed to board|board (nahi|nhi) (karne|karne diya)|boarding (nahi|nhi|denied|refused))",
    "baggage_issue": r"\b(baggage|luggage|bag|suitcase|saman|samaan)\b",
    "train_late_not_travelled": r"\b(late|delay|delayed|der)\b",
    "train_cancelled": r"\b(cancel|cancelled|canceled|radd)\b",
}


def _keyword_hits(issue_id: str, low: str) -> list:
    hits = [k for k in ISSUES[issue_id]["keywords"] if k in low]
    pat = ISSUE_PATTERNS.get(issue_id)
    if pat:
        m = re.search(pat, low)
        if m and m.group(0).strip() not in hits:
            hits.append(m.group(0).strip())
    return hits


def _quote(text: str, fragment: str) -> str:
    """Find the user's own words around a matched fragment, to quote back."""
    low = text.lower()
    i = low.find(fragment.lower())
    if i < 0:
        return fragment
    start = max(0, low.rfind(" ", 0, max(0, i - 12)) + 1)
    end = low.find(" ", min(len(text), i + len(fragment) + 12))
    end = len(text) if end < 0 else end
    return text[start:end].strip(" ,.!?")


def classify_issues(text: str, section: str, mode: str, issue_hint=None) -> list:
    """Return [{issue_type, confidence, matched}] for issues in this section."""
    if issue_hint and issue_hint in ISSUES:
        return [{"issue_type": issue_hint, "confidence": 1.0, "matched": [ISSUES[issue_hint]["title"].lower()]}]

    raw_low = _norm(text)
    normalized = normalize_hinglish(text) if is_hinglish(text) else raw_low
    low = raw_low + " || " + normalized

    allowed = [i for i in KB["sections"][section]["issues"]] if section else list(ISSUES)
    if mode == "train":
        allowed = [i for i in allowed if ISSUES[i].get("mode") == "train"]
    elif mode == "flight":
        allowed = [i for i in allowed if ISSUES[i].get("mode") == "flight"]

    scores = {}

    # a) Existing NLP pipeline (Hinglish normalization + multi-issue intents)
    if section in (None, "shopping"):
        nlp = nlp_analyze(normalized)
        for it in nlp["issues"]:
            slug = INTENT_TO_ISSUE.get(it["intent"])
            if slug in allowed:
                prev = scores.get(slug, {"confidence": 0, "matched": []})
                prev["confidence"] = max(prev["confidence"], it["confidence"])
                prev["matched"].append(it["display"].lower())
                scores[slug] = prev

    # b) Knowledge-base keywords and cue patterns
    for slug in allowed:
        hits = _keyword_hits(slug, low)
        if hits:
            conf = min(0.6 + 0.12 * len(hits), 0.95)
            prev = scores.get(slug, {"confidence": 0, "matched": []})
            prev["confidence"] = max(prev["confidence"], conf)
            prev["matched"] = hits + [m for m in prev["matched"] if m not in hits]
            scores[slug] = prev

    # c) Resolve overlaps so one cause isn't reported twice
    if "size_or_fit_return" in scores and "wrong_or_damaged_item" in scores:
        if not re.search(r"(damag|broken|toota|tuta|defect|kharab|torn|phata|wrong|galat|different)", low):
            scores.pop("wrong_or_damaged_item")
    if "return_rejected" in scores and "refund_delay" in scores:
        if not re.search(r"refund.{0,30}(not|nahi|nhi|pending|delay|kab)|(not|nahi|nhi).{0,15}refund", low):
            scores.pop("refund_delay")
    if "payment_deducted_no_order" in scores and "refund_delay" in scores:
        if not re.search(r"\b(refund|return)\b", raw_low):
            scores.pop("refund_delay")
    if "payment_deducted_no_order" in scores and "late_delivery" in scores:
        if re.search(r"(no order|not placed|order (nahi|nhi) (hua|bana|placed))", low):
            scores.pop("late_delivery")
    if "size_or_fit_return" in scores and "late_delivery" in scores:
        if not re.search(r"(late|delay|not (arrived|delivered)|nahi aaya|nhi aaya|nahi aya|nhi aya)", raw_low):
            scores.pop("late_delivery")
    if mode == "flight" and "flight_cancellation" in scores and "flight_delay" in scores:
        if not re.search(r"\d+\s*(ghante|hours?|hrs?)", raw_low):
            scores.pop("flight_delay")
    if mode == "train" and "train_cancelled" in scores and "train_late_not_travelled" in scores:
        scores.pop("train_late_not_travelled")

    found = [
        {"issue_type": k, "confidence": round(v["confidence"], 2), "matched": v["matched"]}
        for k, v in scores.items()
    ]
    found.sort(key=lambda x: x["confidence"], reverse=True)
    return found


# ─── 4. Entitlement engine ─────────────────────────────

def _src(source_id: str) -> str:
    return SOURCES[source_id]["url"]


def _ent(text, status="owed", basis="", source_id=None):
    return {
        "text": text,
        "status": status,  # owed | maybe | not_owed | info
        "basis": basis,
        "source_url": _src(source_id) if source_id else None,
    }


def _fmt_inr(n) -> str:
    return "₹{:,}".format(int(n))


def entitlements_for(issue_type: str, details: dict, company_id=None) -> tuple:
    """Return (entitlements, urgent_action or None)."""
    ents, urgent = [], None
    dg = RULES["dgca_flight"]
    rr = RULES["railway_refund"]
    h = details.get("delay_hours")
    block = details.get("block_hours")
    dep = details.get("departure_hour")
    car = "DGCA CAR Section 3 Series M Part IV"

    if issue_type == "flight_delay":
        dl = dg["delay"]
        if h is not None:
            # Meals: find the threshold for this flight length; if unknown, use the strictest (4h)
            if block is not None:
                th = next(t for t in dl["meals_thresholds"]
                          if block <= t.get("block_time_max_hours", 99)
                          and block > t.get("block_time_min_exclusive_hours", -1))
                need = th["delay_at_least_hours"]
                if h >= need:
                    ents.append(_ent("You were owed free meals and refreshments while you waited",
                                     "owed", f"{car}, para {th['para']}: delay of {need}+ hours on a flight of this length", "dgca_car_m4"))
                else:
                    ents.append(_ent(f"Free meals start after a {need}-hour delay for a flight this long",
                                     "not_owed", f"{car}, para {th['para']}", "dgca_car_m4"))
            elif h >= 4:
                ents.append(_ent("You were owed free meals and refreshments while you waited",
                                 "owed", f"{car}, para 3.4.1: delays of 4+ hours qualify for any flight length", "dgca_car_m4"))
            elif h >= 2:
                ents.append(_ent("You may have been owed free meals (after 2 hours for short flights, 3 hours for medium ones)",
                                 "maybe", f"{car}, para 3.4.1", "dgca_car_m4"))
            if details.get("meals_refused") and any(e["status"] in ("owed", "maybe") for e in ents):
                ents.append(_ent("You said you weren't given food. Mention this in your complaint",
                                 "info", f"{car}, para 3.8.1(a)", "dgca_car_m4"))

            if h > dl["refund_or_alternate"]["delay_more_than_hours"]:
                ents.append(_ent("You can ask for another flight within 6 hours, or a full refund",
                                 "owed", f"{car}, para 3.4.2 (domestic flights delayed more than 6 hours)", "dgca_car_m4"))

            night = dep is not None and (dep >= 20 or dep < 3)
            if h > dl["hotel"]["delay_more_than_hours"] or (night and h > dl["hotel"]["night_departure_delay_more_than_hours"]):
                ents.append(_ent("You can ask for a free hotel stay, including transport",
                                 "owed", f"{car}, para 3.4.3", "dgca_car_m4"))
            elif h > 6 and dep is None:
                ents.append(_ent("If your flight was due to leave between 8 PM and 3 AM, you can also ask for a free hotel stay",
                                 "maybe", f"{car}, para 3.4.3", "dgca_car_m4"))
        else:
            ents.append(_ent("Free meals after 2 to 4 hours (depends on flight length); refund or another flight after 6 hours; hotel after 24 hours",
                             "maybe", f"{car}, paras 3.4.1-3.4.3. Tell us how many hours late it was.", "dgca_car_m4"))
        ents.append(_ent("A delay by itself doesn't qualify for cash compensation",
                         "not_owed", f"{car}, para 3.7.1: cash compensation only for denied boarding and cancellation", "dgca_car_m4"))
        ents.append(_ent("None of this applies if the delay was caused by weather, air traffic control or other events outside the airline's control",
                         "info", f"{car}, paras 1.4, 1.5, 3.4.4", "dgca_car_m4"))

    elif issue_type == "flight_cancellation":
        cn = dg["cancellation"]
        n = details.get("notice_hours")
        tiers = cn["compensation_by_block_time"]

        def comp_line():
            if block is not None:
                t = next(t for t in tiers if block <= t.get("block_time_max_hours", 99)
                         and block > t.get("block_time_min_exclusive_hours", -1))
                return f"You can ask for a full refund plus up to {_fmt_inr(t['amount_inr'])} compensation (or your one-way basic fare plus fuel charge, if that's less), or another flight"
            return ("You can ask for a full refund plus compensation of up to ₹5,000, ₹7,500 or ₹10,000 "
                    "depending on flight length (capped at your one-way basic fare plus fuel charge), or another flight")

        if n is not None and n < 24:
            ents.append(_ent(comp_line(), "owed", f"{car}, para 3.3.2: told less than 24 hours before", "dgca_car_m4"))
        elif n is not None and n < 336:
            ents.append(_ent("You can choose another flight or a full refund", "owed",
                             f"{car}, para 3.3.1: told between 24 hours and 2 weeks before", "dgca_car_m4"))
            ents.append(_ent("Cash compensation doesn't apply when you were told 24+ hours before", "not_owed",
                             f"{car}, para 3.3.2", "dgca_car_m4"))
        elif n is not None:
            ents.append(_ent("You can choose another flight or a full refund", "owed",
                             f"{car}, para 3.3.1: told 2+ weeks before", "dgca_car_m4"))
        else:
            ents.append(_ent("You can always choose another flight or a full refund", "owed", f"{car}, para 3.3.1", "dgca_car_m4"))
            ents.append(_ent("If you were told less than 24 hours before: " + comp_line()[0].lower() + comp_line()[1:],
                             "maybe", f"{car}, para 3.3.2", "dgca_car_m4"))
        ents.append(_ent("Free meals and refreshments while you wait at the airport for the new flight",
                         "maybe", f"{car}, para 3.3.2 with 3.8.1(a)", "dgca_car_m4"))
        ents.append(_ent("No compensation if you didn't give a phone or email when booking, or for weather or other events outside the airline's control",
                         "info", f"{car}, paras 3.3.3, 3.3.4", "dgca_car_m4"))

    elif issue_type == "denied_boarding":
        db = dg["denied_boarding"]
        ents.append(_ent("Nothing is owed if they put you on a flight leaving within 1 hour", "info", f"{car}, para 3.2.2", "dgca_car_m4"))
        ents.append(_ent(f"New flight within 24 hours: {db['alternate_within_24h']['percent_of_fare']}% of your one-way basic fare plus fuel charge, up to {_fmt_inr(db['alternate_within_24h']['cap_inr'])}",
                         "maybe", f"{car}, para 3.2.2(a)", "dgca_car_m4"))
        ents.append(_ent(f"New flight after 24 hours: {db['alternate_after_24h']['percent_of_fare']}% of your one-way basic fare plus fuel charge, up to {_fmt_inr(db['alternate_after_24h']['cap_inr'])}",
                         "maybe", f"{car}, para 3.2.2(b)", "dgca_car_m4"))
        ents.append(_ent(f"No new flight wanted: full refund plus {db['no_alternate_opted']['percent_of_fare']}% of your one-way basic fare plus fuel charge, up to {_fmt_inr(db['no_alternate_opted']['cap_inr'])}",
                         "maybe", f"{car}, para 3.2.2(c)", "dgca_car_m4"))

    elif issue_type == "baggage_issue":
        ents.append(_ent("We couldn't verify baggage compensation limits today. Check the airline's official page",
                         "info", "Not covered by DGCA CAR Series M Part IV", None))

    elif issue_type == "train_late_not_travelled":
        tl = rr["train_late"]
        cl = "Indian Railways refund rules (w.e.f. 12 Nov 2015), clause 6"
        departed = details.get("train_departed")
        if h is not None and h <= tl["late_more_than_hours"]:
            ents.append(_ent("The full-refund rule only applies when the train is more than 3 hours late",
                             "not_owed", cl, "irctc_refund_rules_2015"))
        elif departed is True:
            ents.append(_ent("The rules give no refund if the TDR is filed after the train actually leaves",
                             "not_owed", cl, "irctc_refund_rules_2015"))
        else:
            ents.append(_ent("Full refund of your fare, with no cancellation charge", "owed" if h else "maybe",
                             cl + ": train more than 3 hours late and you don't travel", "irctc_refund_rules_2015"))
            urgent = ("File your TDR now, before the train departs, or you lose the full refund."
                      if departed is False or departed is None else None)
            ents.append(_ent("E-ticket: file a TDR online before the train actually departs. Counter ticket: hand it in before the train departs",
                             "info", cl, "irctc_refund_rules_2015"))

    elif issue_type == "train_cancelled":
        cl = "Indian Railways refund rules (w.e.f. 12 Nov 2015), clause 5"
        ents.append(_ent("E-ticket: full refund comes back automatically to the account you paid from. No TDR needed",
                         "owed", cl, "irctc_refund_rules_2015"))
        ents.append(_ent("Counter ticket: cancel it at a reservation counter within 72 hours of the scheduled departure for a full refund",
                         "owed", cl, "irctc_refund_rules_2015"))

    elif issue_type == "payment_deducted_no_order":
        rb = RULES["rbi_failed_transactions"]
        upi = next(c for c in rb["cases"] if c["id"] == "upi_merchant")
        ents.append(_ent("Failed UPI payment to a shop or app: the money must come back within 5 days (T + 5)",
                         "owed", "RBI circular dated 20 Sep 2019 (TAT for failed transactions)", "rbi_tat_2019"))
        ents.append(_ent("After that, the bank owes you ₹100 for every extra day, paid automatically",
                         "owed", "RBI circular dated 20 Sep 2019, para 5", "rbi_tat_2019"))
        dw = details.get("days_waiting")
        if dw is not None and dw > upi["auto_reversal_days"]:
            late = dw - upi["auto_reversal_days"]
            urgent = f"It's been about {dw} days. That's past the 5-day limit, so raise a dispute in your bank or UPI app today."
            ents.append(_ent(f"About {late} days past the limit means about {_fmt_inr(late * rb['compensation_per_day_inr'])} compensation (₹100 × {late} days), if you paid by UPI",
                             "maybe", "RBI circular dated 20 Sep 2019", "rbi_tat_2019"))
        if company_id == "indian_railways":
            ents.append(_ent(RULES["railway_refund"]["booking_failed_money_debited"], "owed",
                             "IRCTC refund rules", "irctc_refund_rules_2015"))

    if issue_type in ("refund_delay", "late_delivery", "wrong_or_damaged_item",
                      "size_or_fit_return", "return_rejected", "payment_deducted_no_order"):
        eg = RULES["ecommerce_grievance"]
        if issue_type == "size_or_fit_return" and company_id:
            win = ISSUES["size_or_fit_return"].get("return_window_days", {}).get(company_id)
            if win:
                ents.append(_ent(f"{COMPANIES[company_id]['name']} allows returns within {win['days']} days for {win['category']}",
                                 "info", COMPANIES[company_id]["name"] + " returns policy", win["source"]))
            else:
                ents.append(_ent("Check the return window on your order page. We couldn't verify it for this store",
                                 "info", "", None))
        ents.append(_ent(f"The store's Grievance Officer must reply within {eg['acknowledge_within_hours']} hours and fix your complaint within one month",
                         "owed", eg["name"], eg["source"]))

    return ents, urgent


# ─── 5. Escalation engine ──────────────────────────────

CONTACT_LABELS = {
    "help_url": ("url", "Open help page"),
    "customer_care_phone": ("phone", "Call customer care"),
    "customer_care_email": ("email", "Email customer care"),
    "grievance_officer_email": ("email", "Email the Grievance Officer"),
    "grievance_officer_phone": ("phone", "Call the Grievance Officer"),
    "nodal_officer_email": ("email", "Email the Nodal Officer"),
    "nodal_officer_phone": ("phone", "Call the Nodal Officer"),
    "appellate_authority_email": ("email", "Email the Appellate Authority"),
}


def _company_contacts(company_id, fields):
    """Return a list of contacts; unverified (null) fields become a 'check official page' link."""
    c = COMPANIES.get(company_id) if company_id else None
    out = []
    for f in fields:
        kind, label = CONTACT_LABELS[f]
        val = c.get(f) if c else None
        if val:
            # "0124-4973838 / 0124-6173838" -> first number for the button, all shown in text
            out.append({"kind": kind, "label": label, "value": val, "verified": True,
                        "source_url": c.get("source_url")})
    if not out:
        fallback = (c or {}).get("grievance_url") or (c or {}).get("help_url")
        out.append({"kind": "url" if fallback else "none",
                    "label": CHECK_OFFICIAL, "value": fallback, "verified": False,
                    "source_url": (c or {}).get("source_url")})
    return out


BUTTON_LABELS = {
    "nch": "Open Consumer Helpline",
    "edaakhil": "Open e-Daakhil",
    "airsewa": "Open AirSewa",
    "railmadad": "Open RailMadad",
    "irctc_tdr": "File TDR on IRCTC",
    "rbi_ombudsman": "Open RBI complaint site",
}


def _authority_contacts(auth_id):
    a = AUTHORITIES[auth_id]
    src = _src(a["source"])
    out = []
    url_contact = None
    if a.get("url"):
        url_contact = {"kind": "url", "label": BUTTON_LABELS.get(auth_id, f"Open {a['name']}"),
                       "value": a["url"], "verified": True, "source_url": src}
    # For TDR the website is the action; for helplines the phone call is.
    if url_contact and auth_id == "irctc_tdr":
        out.append(url_contact)
        url_contact = None
    if a.get("phone"):
        out.append({"kind": "phone", "label": f"Call {a['phone']}", "value": a["phone"], "verified": True, "source_url": src})
    if url_contact:
        out.append(url_contact)
    if a.get("whatsapp"):
        out.append({"kind": "whatsapp", "label": "WhatsApp", "value": a["whatsapp"], "verified": True, "source_url": src})
    return out


def _ladder_steps(ladder_id, company_id):
    steps = []
    for lv in LADDERS[ladder_id]:
        ct = lv["contact"]
        if ct["type"] == "company":
            contacts = _company_contacts(company_id, ct["fields"])
        elif ct["type"] == "url":
            contacts = _company_contacts(company_id, [ct["field"]])
        elif ct["type"] == "authority":
            contacts = _authority_contacts(ct["id"])
            if ct.get("alt_authority"):
                contacts += _authority_contacts(ct["alt_authority"])
        else:
            contacts = [{"kind": "none", "label": "Use your bank or UPI app", "value": None, "verified": True, "source_url": None}]

        # Appellate authority: skip if the airline hasn't published one
        if lv.get("skip_if_missing") and not any(c["verified"] for c in contacts):
            continue

        verified = all(c["verified"] for c in contacts[:1])
        steps.append({
            "level": len(steps) + 1,
            "id": lv["id"],
            "title": lv["title"],
            "instructions": lv["instructions"],
            "channel": lv["channel"],
            "contact": contacts[0],
            "other_contacts": contacts[1:],
            "verified": verified,
            "deadline_hours": lv["wait_hours_before_next"],
            "deadline_basis": lv["wait_basis"],
            "acknowledge_hours": lv.get("acknowledge_within_hours"),
        })
    return steps


CONTACTED_CUES = [
    # (pattern, ladder step id that is already done)
    (r"\b(appellate)\b", "appellate_authority"),
    (r"\b(nodal)\b", "nodal_officer"),
    (r"\b(grievance officer|grievance)\b", "grievance_officer"),
    (r"(customer care|customer service|called|call kiya|call kia|phone kiya|spoke to|baat ki|complaint (raised|kiya|kia|ki|registered|daali)|raised (a )?(complaint|ticket)|ticket (number|no|raised)|chat kiya|emailed|mail kiya)", "customer_care"),
    (r"(app (me|mein|pe|par)|in the app|through the app|help section|raised .* in app|request (raised|daali|dali))", "in_app"),
]


def build_steps(issue_type, ladder_id, company_id, details, text):
    """Pick the starting level and give each level a deadline."""
    steps = _ladder_steps(ladder_id, company_id)
    low = _norm(text)
    ids = [s["id"] for s in steps]
    start_idx, reason = 0, None

    done = None
    for pat, step_id in CONTACTED_CUES:
        if re.search(pat, low):
            if step_id == "customer_care" and "airline_care" in ids:
                step_id = "airline_care"
            if step_id in ids:
                done = step_id
                break

    hours_waiting = (details.get("days_waiting") or 0) * 24
    no_reply = re.search(r"(no (reply|response|answer)|not (replied|responding|answering)|koi (jawab|reply|response) (nahi|nhi)|ignore|reply nahi|jawab nahi)", low)

    if done:
        di = ids.index(done)
        wait = steps[di]["deadline_hours"] or 0
        if (no_reply or hours_waiting >= wait) and di + 1 < len(steps):
            start_idx = di + 1
            why = "they haven't replied" if no_reply else f"it's been about {details.get('days_waiting')} days"
            reason = f"You already tried \"{steps[di]['title'].lower()}\" and {why}, so we've moved you to the next step."
        else:
            start_idx = di
            reason = f"You already tried \"{steps[di]['title'].lower()}\". Give them until the deadline before moving on."
    elif ladder_id == "shopping" and hours_waiting >= 96 and issue_type in ("refund_delay", "late_delivery", "return_rejected"):
        # In-app (48h) + customer care (48h) defaults already passed
        start_idx = ids.index("customer_care")
        reason = (f"You've been waiting about {details.get('days_waiting')} days, so start with customer care "
                  "and quote the order. If they don't fix it in 48 hours, go to the Grievance Officer.")

    for i, s in enumerate(steps):
        s["is_current"] = i == start_idx
        s["is_done"] = i < start_idx

    return steps, steps[start_idx]["level"], reason


# ─── 6. Urgency ────────────────────────────────────────

def detect_urgency(text, details, issue_type, urgent_action) -> tuple:
    low = _norm(text)
    reasons = []
    score = 0
    cues = [
        (r"(money|amount|paise?|paisa|rupees?).{0,12}(deducted|debited|kat|cut)|\bdebited\b", "money has left your account", 2),
        (r"\b(again|phir se|dobara|baar baar|twice|second time)\b", "this has happened more than once", 1),
        (r"(no (reply|response)|not responding|koi jawab nahi|reply nahi|ignor)", "they aren't replying", 1),
        (r"\b(urgent|asap|immediately|turant|jaldi|emergency)\b", "you said it's urgent", 2),
        (r"(train leaving|nikalne wali|leaving soon|abhi nikli nahi|not left yet)", "your train hasn't left yet", 2),
    ]
    for pat, why, w in cues:
        if re.search(pat, low):
            score += w
            reasons.append(why)
    amt = details.get("amount")
    if amt and amt >= 5000:
        score += 2
        reasons.append(f"the amount is large ({_fmt_inr(amt)})")
    elif amt and amt >= 1000:
        score += 1
        reasons.append(f"the amount is {_fmt_inr(amt)}")
    if (details.get("days_waiting") or 0) >= 10:
        score += 1
        reasons.append(f"you've waited {details['days_waiting']} days")
    if urgent_action:
        score += 3
    level = "high" if score >= 3 else ("medium" if score >= 1 else "low")
    return level, reasons


# ─── 7. Complaint email ────────────────────────────────

def _summary(issue_type, company_name, d):
    cn = company_name or "the company"
    h = d.get("delay_hours")
    s = {
        "refund_delay": f"Your {cn} refund hasn't arrived" + (f" after {d['days_waiting']} days" if d.get("days_waiting") else ""),
        "late_delivery": (f"Your {cn} order hasn't arrived after {d['days_waiting']} days" if d.get("days_waiting")
                          else f"Your {cn} order is late"),
        "wrong_or_damaged_item": f"Your {cn} order came wrong or damaged",
        "size_or_fit_return": f"Your {cn} clothes don't fit and need a return or exchange",
        "return_rejected": f"{cn} rejected your return",
        "payment_deducted_no_order": "Money was taken but no order was placed" + (f" on {cn}" if company_name else ""),
        "flight_delay": f"Your {cn} flight was {h:g} hours late" if h else f"Your {cn} flight was delayed",
        "flight_cancellation": f"Your {cn} flight was cancelled",
        "denied_boarding": f"{cn} didn't let you board",
        "baggage_issue": f"Your bag on {cn} was lost, delayed or damaged",
        "train_late_not_travelled": f"Your train is running {h:g} hours late" if h else "Your train is running late",
        "train_cancelled": "Your train was cancelled",
    }
    return s.get(issue_type, ISSUES[issue_type]["summary"])


FACT_LINES = {
    "refund_delay": "I am writing to complain that the refund for my order has not been credited to me.",
    "late_delivery": "I am writing to complain that my order has not been delivered.",
    "wrong_or_damaged_item": "I am writing to complain that the item I received is wrong or damaged.",
    "size_or_fit_return": "I am writing to request a return or exchange because the clothing I received does not fit.",
    "return_rejected": "I am writing to complain that my return request has been rejected.",
    "payment_deducted_no_order": "I am writing to complain that money was deducted from my account but no order was placed.",
    "flight_delay": "I am writing to complain about the delay of my flight.",
    "flight_cancellation": "I am writing to complain about the cancellation of my flight.",
    "denied_boarding": "I am writing to complain that I was denied boarding despite holding a confirmed ticket and reporting on time.",
    "baggage_issue": "I am writing to complain that my checked baggage was lost, delayed or damaged.",
    "train_late_not_travelled": "I am writing regarding my refund, as my train was running more than three hours late and I did not travel.",
    "train_cancelled": "I am writing regarding the refund for my train ticket, as the train was cancelled.",
}

ASKS = {
    "refund_delay": "Please credit the full refund to my original payment method immediately and confirm the date.",
    "late_delivery": "Please deliver the order immediately or cancel it and refund me in full.",
    "wrong_or_damaged_item": "Please arrange a pickup and a replacement or a full refund.",
    "size_or_fit_return": "Please arrange a pickup and an exchange for the correct size or a full refund.",
    "return_rejected": "Please review the rejection and accept my return, or explain the specific reason in writing.",
    "payment_deducted_no_order": "Please reverse the deducted amount to my account immediately.",
    "flight_delay": "Please provide the facilities and refund or alternate flight I am entitled to.",
    "flight_cancellation": "Please provide the refund, alternate flight and compensation I am entitled to.",
    "denied_boarding": "Please pay the compensation I am entitled to.",
    "baggage_issue": "Please trace and return my baggage or compensate me for the loss or damage.",
    "train_late_not_travelled": "Please process the full refund of my fare.",
    "train_cancelled": "Please process the full refund of my fare.",
}


def write_complaint(issue_type, company_id, details, step, entitlements, all_steps):
    company = COMPANIES.get(company_id) if company_id else None
    cname = company["name"] if company else "[Company name]"
    d = details

    # Who to send it to: email at the current step, else the first email later on
    to = None
    for s in [step] + [x for x in all_steps if x["level"] > step["level"]]:
        for c in [s["contact"]] + s["other_contacts"]:
            if c["kind"] == "email" and c["verified"]:
                to = c["value"]
                break
        if to:
            break

    ref_bits = []
    if d.get("order_id"):
        ref_bits.append(f"Order {d['order_id']}")
    if d.get("airline_pnr"):
        ref_bits.append(f"PNR {d['airline_pnr']}")
    if d.get("train_pnr"):
        ref_bits.append(f"PNR {d['train_pnr']}")
    if d.get("flight_number"):
        ref_bits.append(f"Flight {d['flight_number']}")
    if d.get("train_number"):
        ref_bits.append(f"Train {d['train_number']}")
    ref = ", ".join(ref_bits)

    subject = f"Complaint: {ISSUES[issue_type]['title']}" + (f" ({ref})" if ref else "")

    lines = [f"Dear {cname} team,", "", FACT_LINES[issue_type], ""]
    details_lines = []
    mode = ISSUES[issue_type].get("mode")
    if mode == "flight":
        details_lines.append(f"- Flight number: {d.get('flight_number', '[Flight number]')}")
        details_lines.append(f"- PNR / booking reference: {d.get('airline_pnr', '[PNR]')}")
        details_lines.append(f"- Date of travel: {d.get('date', '[Date of travel]')}")
        if d.get("delay_hours"):
            details_lines.append(f"- Length of delay: about {d['delay_hours']:g} hours")
        if d.get("meals_refused"):
            details_lines.append("- No meals or refreshments were provided while I waited")
    elif mode == "train":
        details_lines.append(f"- PNR: {d.get('train_pnr', '[10-digit PNR]')}")
        details_lines.append(f"- Train number: {d.get('train_number', '[Train number]')}")
        details_lines.append(f"- Date of journey: {d.get('date', '[Date of journey]')}")
        if d.get("delay_hours"):
            details_lines.append(f"- The train was running about {d['delay_hours']:g} hours late")
    else:
        details_lines.append(f"- Order ID: {d.get('order_id', '[Order ID]')}")
        if d.get("amount"):
            details_lines.append(f"- Amount: {_fmt_inr(d['amount'])}")
        else:
            details_lines.append("- Amount: [Amount]")
        if d.get("payment_method"):
            details_lines.append(f"- Payment method: {d['payment_method']}")
        if d.get("days_waiting"):
            details_lines.append(f"- I have been waiting for about {d['days_waiting']} days")
        if d.get("date"):
            details_lines.append(f"- Date: {d['date']}")
    lines += ["Details:"] + details_lines + [""]

    # Earlier contact
    if step["level"] > 1:
        lines += ["I have already raised this with your team ([Ticket / complaint number]) but it has not been resolved.", ""]

    # From the grievance-officer / nodal level onwards, cite the rule and deadline
    if step["id"] in ("grievance_officer", "nch", "edaakhil") and ISSUES[issue_type]["section"] == "shopping":
        eg = RULES["ecommerce_grievance"]
        lines += [f"Under the {eg['name']}, the Grievance Officer must acknowledge this complaint within "
                  f"{eg['acknowledge_within_hours']} hours and resolve it within one month of receipt.", ""]
    if mode == "flight" and step["id"] in ("nodal_officer", "appellate_authority", "airsewa", "nch", "edaakhil"):
        owed = [e for e in entitlements if e["status"] == "owed" and e.get("basis", "").startswith("DGCA")]
        lines.append("Under DGCA Civil Aviation Requirements, Section 3, Series M, Part IV (Rev. 4, 2023), I am entitled to:")
        lines += [f"- {e['text']} ({e['basis'].split(', ', 1)[-1]})" for e in owed] or ["- the facilities set out in that CAR"]
        lines.append("")
    if issue_type == "payment_deducted_no_order":
        lines += ["Under the RBI circular on Turn Around Time for failed transactions (20 September 2019), a failed UPI "
                  "merchant payment must be reversed within T + 5 days, with compensation of ₹100 per day of delay after that.", ""]
    if mode == "train" and issue_type == "train_late_not_travelled":
        lines += ["Under the Indian Railways refund rules (w.e.f. 12 November 2015, clause 6), a full refund is due "
                  "when a train runs more than three hours late and the passenger does not travel.", ""]

    lines += [ASKS[issue_type], "",
              "I request a written reply with a complaint reference number.", "",
              "Regards,", "[Your name]", "[Your phone number]", "[Your registered email]"]

    return {"to": to, "subject": subject, "body": "\n".join(lines)}


# ─── 8. Main entry ─────────────────────────────────────

def _xai(text, issue_type, found, comp, details):
    reasons = []
    title = ISSUES[issue_type]["title"].lower()
    if found["confidence"] >= 1.0:
        reasons.append(f"You told us the problem is: {title}")
    else:
        quoted = [_quote(text, m) for m in found["matched"][:2] if m]
        if quoted:
            reasons.append(f"You wrote \"{quoted[0]}\", so this looks like: {title}")
    if comp["company"] and comp["matched"]:
        m0 = comp["matched"][0]
        if m0.startswith("you picked"):
            reasons.append(f"You picked {COMPANIES[comp['company']]['name']}")
        else:
            reasons.append(f"You mentioned \"{m0}\", so we picked {COMPANIES[comp['company']]['name']}")
    labels = {
        "order_id": "order ID", "amount": "amount", "days_waiting": "days waiting",
        "delay_hours": "hours late", "airline_pnr": "PNR", "train_pnr": "PNR",
        "flight_number": "flight", "train_number": "train", "notice_hours": "notice given (hours)",
        "block_hours": "flight length (hours)", "departure_hour": "departure hour",
    }
    got = [f"{labels[k]}: {details[k]}" for k in labels if k in details]
    if got:
        reasons.append("We found these details: " + ", ".join(got))
    reasons.append(f"We're {int(found['confidence'] * 100)}% sure about this")
    return reasons


def _clarify_options(kind, section=None, issues=None):
    if kind == "section":
        return [
            {"label": "A shopping order", "section": "shopping", "company": None, "issue_type": None},
            {"label": "A flight", "section": "travel", "company": None, "issue_type": None},
            {"label": "A train", "section": "travel", "company": "indian_railways", "issue_type": None},
        ]
    if kind == "company":
        comps = KB["sections"][section]["companies"]
        # All companies in the section (5), so nobody is left without their option.
        return [{"label": COMPANIES[c]["name"], "section": section, "company": c, "issue_type": None} for c in comps]
    if kind == "issue":
        ids = issues or KB["sections"][section]["issues"]
        return [{"label": ISSUES[i]["title"], "section": section, "company": None, "issue_type": i} for i in ids][:4]
    return []


def resolve(text: str, section=None, company=None, issue_type=None) -> dict:
    text = (text or "").strip()
    comp = detect_company(text, section, company)
    sec = comp["section"]
    cid = comp["company"]
    mode = COMPANIES[cid].get("mode") if cid else None
    if issue_type in ISSUES and not sec:
        sec = ISSUES[issue_type]["section"]
    if not mode and sec == "travel":
        low = _norm(text)
        mode = "train" if re.search(TRAIN_WORDS, low) else ("flight" if re.search(FLIGHT_WORDS, low) else None)

    base = {
        "section": sec,
        "company": cid,
        "company_name": COMPANIES[cid]["name"] if cid else None,
        "company_confidence": comp["company_confidence"],
        "needs_clarification": False,
        "clarification_question": None,
        "clarification_options": [],
        "issues": [],
    }

    if not sec:
        base.update(needs_clarification=True,
                    clarification_question="What is your problem about?",
                    clarification_options=_clarify_options("section"))
        return base

    found = classify_issues(text, sec, mode, issue_type)
    if not found or found[0]["confidence"] < CLARIFY_THRESHOLD:
        base.update(needs_clarification=True,
                    clarification_question="What went wrong?",
                    clarification_options=_clarify_options("issue", sec, [f["issue_type"] for f in found] or None))
        return base

    if not cid:
        # A train issue implies Indian Railways; otherwise ask which company.
        if all(ISSUES[f["issue_type"]].get("mode") == "train" for f in found):
            cid = "indian_railways"
            base.update(company=cid, company_name=COMPANIES[cid]["name"], company_confidence=0.85)
        else:
            q = "Which airline was it, or was it a train?" if sec == "travel" else "Which app or website did you buy from?"
            base.update(needs_clarification=True, clarification_question=q,
                        clarification_options=_clarify_options("company", sec))
            # Still return the issues so the app can show them after the answer.

    details = extract_details(text)
    for f in found:
        it = f["issue_type"]
        ents, urgent = entitlements_for(it, details, cid)
        ladder = ISSUES[it]["ladder"]
        steps, start_level, start_reason = build_steps(it, ladder, cid, details, text)
        alt_steps = []
        if it == "payment_deducted_no_order":
            alt_steps, _, _ = build_steps(it, "bank", cid, details, "")
        current = next(s for s in steps if s["level"] == start_level)
        urgency, urgency_reasons = detect_urgency(text, details, it, urgent)
        xai = _xai(text, it, f, comp, details)
        if start_reason:
            xai.append(start_reason)
        if urgency_reasons:
            xai.append("Marked " + urgency + " priority because " + ", ".join(urgency_reasons))
        base["issues"].append({
            "issue_type": it,
            "title": ISSUES[it]["title"],
            "summary": _summary(it, COMPANIES[cid]["name"] if cid else None, details),
            "confidence": f["confidence"],
            "xai_reasons": xai,
            "entities": {k: str(v) for k, v in details.items()},
            "urgency": urgency,
            "entitlements": ents,
            "urgent_action": urgent,
            "start_level": start_level,
            "start_reason": start_reason,
            "steps": steps,
            "alternate_steps": alt_steps,
            "complaint": write_complaint(it, cid, details, current, ents, steps),
        })
    return base


def sections_overview() -> dict:
    out = []
    for sid, s in KB["sections"].items():
        out.append({
            "id": sid,
            "title": s["title"],
            "subtitle": s["subtitle"],
            "examples": s["examples"],
            "companies": [
                {"id": c, "name": COMPANIES[c]["name"], "initial": COMPANIES[c]["name"][0]}
                for c in s["companies"]
            ],
            "issues": [{"id": i, "title": ISSUES[i]["title"]} for i in s["issues"]],
        })
    return {"sections": out, "last_verified": KB["meta"]["last_verified"]}
