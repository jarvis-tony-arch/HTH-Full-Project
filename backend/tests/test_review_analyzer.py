"""Unit tests per analyser function, plus golden tests on real collected data.

Unit-test inputs below are short test sentences written for the tests (not
shown to users). Golden tests use real reviews the app collected on the
emulator (tests/data/*.json), kept as-is.
"""
import json
from datetime import date
from pathlib import Path

import pytest

from app.services import review_analyzer as ra

DATA = Path(__file__).parent / "data"
TODAY = date(2026, 11, 27)


def R(text, rating=5, platform="flipkart", date_raw="", verified=True, rid="", helpful=0, title=""):
    return {"text": text, "title": title, "rating": rating, "date_raw": date_raw, "verified": verified,
            "id": rid, "helpful": helpful}


def clean(reviews, platform="flipkart"):
    out, _ = ra.clean_reviews([{"platform": platform, "reviews": reviews}], "2026-11-27T10:00:00")
    return out


# ─── dates ────────────────────────────────────────────────────────────
@pytest.mark.parametrize("raw,expected,prec", [
    ("Reviewed in India on 3 August 2021", date(2021, 8, 3), "day"),
    ("24 Nov 2026", date(2026, 11, 24), "day"),
    ("2026-11-23", date(2026, 11, 23), "day"),
    ("Today", TODAY, "day"),
    ("1 day ago", date(2026, 11, 26), "day"),
    ("· 1 month ago", date(2026, 10, 28), "month"),
    ("Mar, 2024", date(2024, 3, 15), "month"),
    ("", None, ""),
])
def test_parse_review_date(raw, expected, prec):
    assert ra.parse_review_date(raw, TODAY) == (expected, prec)


# ─── cleaning ─────────────────────────────────────────────────────────
def test_clean_keeps_different_buyers_with_same_short_text():
    rs = clean([R("Nice", rid="a"), R("Nice", rid="b"), R("Nice", rid="a")])
    assert len(rs) == 2  # same id twice is a repeat; different ids are different buyers


def test_clean_strips_boilerplate_and_normalises_hinglish():
    rs = clean([R("Product bahut accha hai, mera order time pe aaya READ MORE", rating=5)])
    assert "READ MORE" not in rs[0]["text"]
    assert rs[0]["hinglish"] is True
    assert "my" in rs[0]["en"]


def test_cross_posted_review_counted_once():
    text = "Sound is very clear and the battery easily lasts two full days of use"
    out, stats = ra.clean_reviews([
        {"platform": "amazon", "reviews": [R(text)]},
        {"platform": "flipkart", "reviews": [R(text)]},
    ])
    assert len(out) == 1 and stats["cross_posted"] == 1


# ─── aspects ──────────────────────────────────────────────────────────
def test_aspect_sentiment_splits_positive_and_negative():
    rs = clean([
        R("The sound quality is excellent", 5),
        R("Battery died after a few weeks, very disappointed", 1),
        R("Size is too small, the fit is terrible", 2),
        R("Worth the price, great value for money", 5),
    ])
    a = ra.aspect_sentiment(rs)
    assert a["quality"]["positive"] >= 1
    assert a["durability"]["negative"] == 1
    assert a["size_fit"]["negative"] == 1
    assert a["value"]["positive"] == 1
    assert a["delivery"]["mentions"] == 0


def test_but_splits_mixed_review_into_two_opinions():
    rs = clean([R("Sound quality is great but the packaging was damaged", 3)])
    a = ra.aspect_sentiment(rs)
    assert a["quality"]["positive"] == 1 and a["delivery"]["negative"] == 1


# ─── not as shown ─────────────────────────────────────────────────────
@pytest.mark.parametrize("text,kind", [
    ("Colour is totally different from what was shown", "colour"),
    ("In the given picture the color looks bright but in real it looks much faded", "colour"),
    ("Fabric is very thin, almost see through", "material"),
    ("Not the same as shown in the picture at all", "looks"),
    ("Received a fake product, not original", "fake"),
    ("Size chart is wrong, runs very small", "size"),
])
def test_not_as_shown_types(text, kind):
    r = ra.not_as_shown(clean([R(text, 2)]))
    assert kind in [t["type"] for t in r["types"]]


@pytest.mark.parametrize("text", [
    "Colour is exactly as shown, lovely",
    "Original product, not fake, sealed box",
    "Looks premium and fits well",
])
def test_not_as_shown_ignores_positive_mentions(text):
    assert ra.not_as_shown(clean([R(text, 5)]))["count"] == 0


# ─── trust ────────────────────────────────────────────────────────────
def test_trust_flags_generic_and_duplicates():
    generic = [R("Nice product", 5, rid=f"g{i}") for i in range(12)]
    dup = [R("This is the best earphone I have ever used in my whole life", 5, rid=f"d{i}") for i in range(4)]
    normal = [R(f"Decent sound for the price, bass is ok and calls are clear number {i}", 4, rid=f"n{i}") for i in range(8)]
    t = ra.trust_signals(clean(generic + dup + normal))
    kinds = {f["signal"] for f in t["flags"]}
    assert {"generic", "duplicates"} <= kinds
    assert t["score"] < 75


def test_trust_burst_detection():
    burst = [R(f"Good earbuds, works fine overall number {i}", 5, date_raw="2026-11-20", rid=f"b{i}") for i in range(10)]
    spread = [R(f"Okay product, sound is fine overall number {i}", 4, date_raw=f"2026-{m:02d}-10", rid=f"s{i}")
              for i, m in enumerate(range(1, 11))]
    t = ra.trust_signals(clean(burst + spread))
    assert any(f["signal"] == "burst" for f in t["flags"])


def test_trust_high_for_ordinary_reviews():
    rs = clean([R(f"The sound is clear, calls are good, battery lasts about {d} hours", 4, rid=str(d)) for d in range(20, 40)])
    assert ra.trust_signals(rs)["level"] == "high"


# ─── trend ────────────────────────────────────────────────────────────
def test_trend_worse():
    old = [R(f"Great quality product, works perfectly {i}", 5, date_raw="2026-03-10", rid=f"o{i}") for i in range(10)]
    new = [R(f"Poor quality, stopped working {i}", 1, date_raw="2026-11-20", rid=f"n{i}") for i in range(10)]
    t = ra.trend(clean(old + new), "2026-11-27")
    assert t["status"] == "worse"


def test_trend_unknown_without_enough_dates():
    t = ra.trend(clean([R("ok", 4)]), "2026-11-27")
    assert t["status"] == "unknown"


# ─── cross-platform ───────────────────────────────────────────────────
def test_cross_platform_gap_and_cheapest():
    a = [R(f"Excellent sound and quality, really happy {i}", 5, platform="amazon", rid=f"a{i}") for i in range(10)]
    f = [R(f"Received a fake product, poor quality {i}", 1, platform="flipkart", rid=f"f{i}") for i in range(10)]
    out, _ = ra.clean_reviews([{"platform": "amazon", "reviews": a}, {"platform": "flipkart", "reviews": f}])
    sources = [{"platform": "amazon", "meta": {"rating": 4.4, "price": 999}},
               {"platform": "flipkart", "meta": {"rating": 3.2, "price": 899}}]
    xp = ra.cross_platform(out, sources, [], None, {}, {})
    assert xp["gap"]["high"] == "Amazon" and xp["gap"]["low"] == "Flipkart"
    assert any("fake" in w for w in xp["gap"]["likely_reasons"])
    assert xp["cheapest"]["platform"] == "flipkart"


def test_independent_not_set_up_is_reported_not_invented():
    xp = ra.cross_platform([], [], [], {"youtube": {"configured": False}, "reddit": {"configured": False}}, {}, {})
    assert xp["independent"]["available"] is False
    assert "set up" in xp["independent"]["text"]


# ─── size, verdict, confidence ────────────────────────────────────────
def test_size_advice_runs_small():
    rs = clean([R(f"Runs small, order one size up {i}", 3, rid=str(i)) for i in range(6)], platform="myntra")
    adv = ra.size_advice(rs, {"title": "Men Slim Fit T-shirt", "platform": "myntra"})
    assert "size up" in adv["advice"]


def test_size_advice_skipped_for_electronics():
    assert ra.size_advice([], {"title": "boAt Airdopes 141", "platform": "amazon"}) is None


def test_too_few_reviews_gives_no_verdict():
    r = ra.analyze_reviews({"product": {"title": "x"}, "sources": [{"platform": "amazon", "reviews": [R("Good", 5)]}]})
    assert r["verdict"]["label"] == "Not enough reviews"
    assert r["quotes"] == []


# ─── golden tests on real collected data ──────────────────────────────
GOLDEN = {
    "flipkart_ACCHGG7NBBMK5GGJ.json": {"label": "Good buy", "min_reviews": 60, "trust_flag": "generic"},
    "myntra_1753418.json": {"label": "Good buy", "min_reviews": 100, "size": True},
}


@pytest.mark.parametrize("name,expect", GOLDEN.items())
def test_golden(name, expect):
    path = DATA / name
    if not path.exists():
        pytest.skip(f"{name} not collected")
    r = ra.analyze_reviews(json.loads(path.read_text(encoding="utf-8")))
    assert r["verdict"]["label"] == expect["label"]
    assert r["reviews_analysed"] >= expect["min_reviews"]
    assert r["verdict"]["reasons"]
    if "trust_flag" in expect:
        assert expect["trust_flag"] in {f["signal"] for f in r["trust"]["flags"]}
    if expect.get("size"):
        assert r["size_advice"] is not None
    # Every quote is a real excerpt of a collected review.
    raw = json.loads(path.read_text(encoding="utf-8"))
    texts = " ".join(f"{x.get('title') or ''}. {x.get('text') or ''}" for s in raw["sources"] for x in s["reviews"])
    texts = " ".join(texts.split())
    for q in r["quotes"]:
        assert q["text"].rstrip("…")[:40] in texts
