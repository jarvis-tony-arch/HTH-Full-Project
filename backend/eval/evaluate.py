"""Evaluation for the report. Uses only real reviews the app collected
(tests/data/*.json); nothing here is generated.

1. Sentiment vs. star-derived labels (4-5 stars = positive, 1-2 = negative,
   3 skipped). A weak label, but an honest one available without annotators.
2. Aspects and "not as shown": needs human labels. This script writes
   eval/labelling_sheet.csv (real reviews, empty label columns). Once people
   fill it in and save it as eval/labels.csv, re-run to get P/R/F1.

Run from backend/:  venv\Scripts\python -m eval.evaluate
"""
import csv
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from app.services import review_analyzer as ra  # noqa: E402

DATA = ROOT / "tests" / "data"
OUT = ROOT / "eval"


def prf(tp, fp, fn):
    p = tp / (tp + fp) if tp + fp else 0.0
    r = tp / (tp + fn) if tp + fn else 0.0
    f = 2 * p * r / (p + r) if p + r else 0.0
    return round(p, 3), round(r, 3), round(f, 3)


def load_reviews():
    out = []
    for f in sorted(DATA.glob("*.json")):
        payload = json.loads(f.read_text(encoding="utf-8"))
        rs, _ = ra.clean_reviews(payload.get("sources") or [], payload.get("collected_at"))
        for i, r in enumerate(rs):
            r["uid"] = f"{f.stem}:{i}"
        out += rs
    return out


def sentiment_eval(reviews):
    rows = [(r, "pos" if r["rating"] >= 4 else "neg") for r in reviews if r["rating"] and r["rating"] != 3]
    res = {}
    for name, fn in [("VADER + Hinglish lexicon", lambda r: r["compound"])]:
        stats = {}
        for cls in ("pos", "neg"):
            tp = fp = fn_ = 0
            for r, gold in rows:
                c = fn(r)
                pred = "pos" if c >= 0.05 else "neg" if c <= -0.05 else "neutral"
                tp += pred == cls and gold == cls
                fp += pred == cls and gold != cls
                fn_ += pred != cls and gold == cls
            stats[cls] = prf(tp, fp, fn_)
        res[name] = stats
    return len(rows), res


def write_sheet(reviews, n=300):
    path = OUT / "labelling_sheet.csv"
    with path.open("w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["uid", "platform", "rating", "text", "sentiment(pos/neg/neutral)",
                    "aspects(; separated: " + ",".join(ra.ASPECTS) + ")",
                    "not_as_shown(none or ; separated: " + ",".join(ra.NOT_AS_SHOWN) + ")"])
        for r in reviews[:n]:
            w.writerow([r["uid"], r["platform"], r["rating"], r["text"], "", "", ""])
    return path


def labelled_eval(reviews):
    path = OUT / "labels.csv"
    if not path.exists():
        return None
    by_id = {r["uid"]: r for r in reviews}
    rows = [row for row in csv.DictReader(path.open(encoding="utf-8")) if row["uid"] in by_id]
    gold_col_a = next(c for c in rows[0] if c.startswith("aspects"))
    gold_col_n = next(c for c in rows[0] if c.startswith("not_as_shown"))
    out = {"n": len(rows), "aspects": {}, "not_as_shown": {}}
    for a in ra.ASPECTS:
        tp = fp = fn = 0
        for row in rows:
            gold = a in {x.strip() for x in row[gold_col_a].split(";") if x.strip()}
            pred = bool(ra.aspect_sentiment([by_id[row["uid"]]])[a]["mentions"])
            tp += pred and gold; fp += pred and not gold; fn += gold and not pred
        out["aspects"][a] = prf(tp, fp, fn)
    for t in ra.NOT_AS_SHOWN:
        tp = fp = fn = 0
        for row in rows:
            gold = t in {x.strip() for x in row[gold_col_n].split(";") if x.strip()}
            pred = t in [x["type"] for x in ra.not_as_shown([by_id[row["uid"]]])["types"]]
            tp += pred and gold; fp += pred and not gold; fn += gold and not pred
        out["not_as_shown"][t] = prf(tp, fp, fn)
    return out


if __name__ == "__main__":
    reviews = load_reviews()
    n, s = sentiment_eval(reviews)
    print(f"Real reviews loaded: {len(reviews)} from {len(list(DATA.glob('*.json')))} products")
    print(f"\nSentiment vs star labels ({n} reviews with 1-2 or 4-5 stars):")
    for name, st in s.items():
        for cls, (p, r, f) in st.items():
            print(f"  {name:28s} {cls}: P={p} R={r} F1={f}")
    print(f"\nLabelling sheet: {write_sheet(reviews)}")
    lab = labelled_eval(reviews)
    if lab is None:
        print("No eval/labels.csv yet: aspect and 'not as shown' metrics need human labels.")
    else:
        print(f"\nHuman-labelled reviews: {lab['n']}")
        for k in ("aspects", "not_as_shown"):
            for name, (p, r, f) in lab[k].items():
                print(f"  {k:13s} {name:14s} P={p} R={r} F1={f}")
