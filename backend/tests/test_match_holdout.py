"""Held-out real pairs (tests/data/match_pairs_holdout.json).

The first, blind run on this set (before any rule changes) was:
n=37, precision 1.00, recall 0.25 (6 true matches were asked about
instead of matched). Rules were then improved; this set is no longer
blind, so new numbers here are optimistic too.
"""
import json
from pathlib import Path

from app.services.product_matcher import MATCH, match_products

DATA = json.loads((Path(__file__).parent / "data" / "match_pairs_holdout.json").read_text(encoding="utf-8"))


def test_holdout_no_wrong_merges():
    tp = fp = fn = tn = 0
    wrong = []
    for g in DATA["groups"]:
        for title, brand, label in g["cands"]:
            r = match_products({**g["ref"], "platform": "ref"},
                               [{"title": title, "brand": brand, "platform": "x", "url": "u"}])["results"][0]
            pred = r["decision"] == MATCH
            tp += pred and label == 1
            fp += pred and label == 0
            fn += (not pred) and label == 1
            tn += (not pred) and label == 0
            if pred != bool(label):
                wrong.append(f"{'FP' if pred else 'FN'} {r['decision']} {r['confidence']}: {g['ref']['title'][:40]} <> {title[:60]} | {r['reasons']}")
    print(f"\nholdout: n={tp + fp + fn + tn} TP={tp} FP={fp} FN={fn} TN={tn} "
          f"precision={tp / max(1, tp + fp):.2f} recall={tp / max(1, tp + fn):.2f}")
    print("\n".join(wrong))
    assert fp == 0, wrong
