"""10 labelled listing pairs (titles as shown on Indian stores, Nov 2026).

label 1 = same product (colour variants count as the same product),
label 0 = different product. Only a "match" decision counts as positive:
"possible" is shown to the user as a question, never merged silently.
"""
from app.services.product_matcher import MATCH, NO_MATCH, match_products, model_codes, search_query

PAIRS = [
    # (product, candidate, label)
    ({"title": "boAt Airdopes 141 Gen 2, 4 Mics ENx Tech,48H Battery,ASAP Charge,Low Latency,BT v5.4 Bluetooth", "brand": "boAt"},
     {"title": "boAt Airdopes 141 Gen 2 TWS Earbuds with 48H Battery, 4 Mics ENx (Active Black)", "brand": "boAt"}, 1),
    ({"title": "boAt 2026 Launch Airdopes 141, Up to 50 Hours Playtime, Quad Mic ENx Tech (Matte Charcoal)", "brand": "boAt", "model": "PA0098"},
     {"title": "boAt Airdopes 141 Gen 2, 4 Mics ENx Tech,48H Battery,ASAP Charge,Low Latency,BT v5.4 Bluetooth", "brand": "boAt"}, 0),
    ({"title": "boAt Airdopes 141 Gen 2, 4 Mics ENx Tech,48H Battery,ASAP Charge,Low Latency,BT v5.4 Bluetooth", "brand": "boAt"},
     {"title": "bAot Premium EarBuds with 60 Hours Playtime & Fast Charging, Deep Bass Bluetooth", "brand": "bAot"}, 0),
    ({"title": "boAt Airdopes 141 Gen 2, 4 Mics ENx Tech,48H Battery", "brand": "boAt"},
     {"title": "boAt Airdopes 131 Elite ANC Bluetooth Headset", "brand": "boAt"}, 0),
    ({"title": "boAt Airdopes 213 PA0028 TWS Earbuds with Environmental Noise Cancellation (IPX4 Sweat & Splash Resistant, Shadow Black)", "brand": "boAt"},
     {"title": "boAt Airdopes 213 TWS Earbuds, ENx Tech, 50H Playtime, IPX4 (Berry Blue)", "brand": "boAt"}, 1),
    ({"title": "Apple iPhone 15 (128 GB) - Black", "brand": "Apple"},
     {"title": "Apple iPhone 15 (Black, 128 GB)", "brand": "Apple"}, 1),
    ({"title": "Apple iPhone 15 (128 GB) - Black", "brand": "Apple"},
     {"title": "Apple iPhone 15 (Black, 256 GB)", "brand": "Apple"}, 0),
    ({"title": "Samsung Galaxy S24 Ultra 5G AI Smartphone (Titanium Gray, 12GB, 256GB Storage)", "brand": "Samsung"},
     {"title": "SAMSUNG Galaxy S24 Ultra 5G (Titanium Gray, 256 GB) (12 GB RAM)", "brand": "SAMSUNG"}, 1),
    ({"title": "Samsung Galaxy S24 5G (Onyx Black, 8GB, 256GB Storage)", "brand": "Samsung"},
     {"title": "Samsung Galaxy S23 5G (Phantom Black, 8GB, 256GB Storage)", "brand": "Samsung"}, 0),
    ({"title": "Prestige Iris 750 Watt Mixer Grinder with 3 Stainless Steel Jars (Black)", "brand": "Prestige"},
     {"title": "Prestige IRIS 750W Mixer Grinder, 3 Jars", "brand": "Prestige"}, 1),
]


def _decide(p, c):
    return match_products(p, [{**c, "platform": "x"}])["results"][0]


def test_precision_recall_on_labelled_pairs():
    tp = fp = fn = tn = 0
    for p, c, label in PAIRS:
        pred = _decide(p, c)["decision"] == MATCH
        tp += pred and label == 1
        fp += pred and label == 0
        fn += (not pred) and label == 1
        tn += (not pred) and label == 0
    precision = tp / (tp + fp) if tp + fp else 0
    recall = tp / (tp + fn) if tp + fn else 0
    print(f"\nmatching: TP={tp} FP={fp} FN={fn} TN={tn} precision={precision:.2f} recall={recall:.2f}")
    # Wrongly merging different products is the worse mistake.
    assert fp == 0
    assert recall >= 0.8


def test_lookalike_brand_is_flagged():
    p, c, _ = PAIRS[2]
    r = _decide(p, c)
    assert r["decision"] == NO_MATCH
    assert any("Look-alike" in x for x in r["reasons"])


def test_generation_difference_is_not_a_match():
    p, c, _ = PAIRS[1]
    assert _decide(p, c)["decision"] != MATCH


def test_storage_conflict_explained():
    p, c, _ = PAIRS[6]
    r = _decide(p, c)
    assert r["decision"] == NO_MATCH
    assert any("Different" in x and "gb" in x for x in r["reasons"])


def test_model_code_normalisation():
    assert "airdopes141" in model_codes("boAt Airdopes141")
    assert "airdopes141" in model_codes("boAt Airdopes 141")
    assert "pa0098" in model_codes("Model PA-0098")


def test_no_candidates_says_so():
    assert match_products({"title": "x"}, [])["summary"] == "Couldn't find this exact product elsewhere"


def test_search_query_drops_marketing_words():
    q = search_query({"title": "boAt 2026 Launch Airdopes 141, Up to 50 Hours Playtime", "brand": "boAt"})
    assert q.startswith("boat airdopes 141")
    assert "launch" not in q and "2026" not in q
