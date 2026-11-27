"""Matching on real listing titles (tests/data/match_pairs.json).

Wrongly merging two different products is the costly mistake (wrong
reviews in the verdict), so precision must be 1.0. Missing a real match
only means fewer reviews, so recall is reported and kept high.
"""
import json
from pathlib import Path

from app.services.product_matcher import MATCH, match_products

PAIRS = json.loads((Path(__file__).parent / "data" / "match_pairs.json").read_text(encoding="utf-8"))


def decisions():
    out = []
    for g in PAIRS["groups"]:
        ref = {**g["ref"], "platform": "ref"}
        for title, brand, label in g["cands"]:
            r = match_products(ref, [{"title": title, "brand": brand, "platform": "x", "url": "u"}])["results"][0]
            out.append((g["ref"]["title"], title, label, r))
    return out


def test_real_titles_precision_and_recall():
    tp = fp = fn = tn = 0
    wrong = []
    for ref, title, label, r in decisions():
        pred = r["decision"] == MATCH
        tp += pred and label == 1
        fp += pred and label == 0
        fn += (not pred) and label == 1
        tn += (not pred) and label == 0
        if pred != bool(label):
            wrong.append(f"{'FP' if pred else 'FN'} {r['decision']} {r['confidence']}: {ref[:45]} <> {title[:60]} | {r['reasons']}")
    p = tp / (tp + fp) if tp + fp else 1.0
    rc = tp / (tp + fn) if tp + fn else 1.0
    print(f"\nreal titles: n={tp + fp + fn + tn} TP={tp} FP={fp} FN={fn} TN={tn} precision={p:.2f} recall={rc:.2f}")
    print("\n".join(wrong))
    assert fp == 0, wrong
    assert rc >= 0.85, wrong
