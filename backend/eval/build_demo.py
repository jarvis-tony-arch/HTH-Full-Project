"""Build the app's demo products from REAL collections (tests/data/*.json).

Each entry below points at reviews the app collected on a phone/emulator.
The analysis is produced by the real analyser, so demo mode shows exactly
what the live app would. Nothing is written by hand.

Run from backend/:  venv\Scripts\python -m eval.build_demo
"""
import json
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from app.services.review_analyzer import analyze_reviews  # noqa: E402

DATA = ROOT / "tests" / "data"
OUT = ROOT.parent / "mobile" / "assets" / "demo"

# file stem -> what this product shows in a demo (described from its real result)
DEMO = {
    "myntra_1753418": "Clothing with happy buyers and size feedback",
    "flipkart_ACCHGG7NBBMK5GGJ": "Earbuds: good overall, many one-word reviews",
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    index = []
    for stem, note in DEMO.items():
        payload = json.loads((DATA / f"{stem}.json").read_text(encoding="utf-8"))
        result = analyze_reviews(payload)
        (OUT / f"{stem}.json").write_text(json.dumps(result, ensure_ascii=False), encoding="utf-8")
        index.append({"id": stem, "file": f"assets/demo/{stem}.json", "note": note,
                      "collected": (payload.get("collected_at") or "")[:10],
                      "title": result["product"]["title"], "verdict": result["verdict"]["label"],
                      "color": result["verdict"]["color"], "image": result["product"].get("image", "")})
        print(f"{stem}: {result['verdict']['label']} ({result['reviews_analysed']} reviews)")
    (OUT / "index.json").write_text(json.dumps({"built": date.today().isoformat(), "products": index},
                                               ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
