# HTH review analyser: architecture

## Flow

```mermaid
flowchart TD
    A[Shopping app: Share → HTH] --> B[link_parser.dart<br/>extract URL, expand short link,<br/>ASIN / Flipkart pid / Myntra style ID]
    B --> C[On the phone: hidden web view<br/>PageReader + extract.js]
    S[(GET /review-selectors<br/>bundled fallback)] --> C
    C -->|sign-in or check page| U[Shown to the user<br/>"Sign in yourself, or Skip"]
    U --> C
    C --> D[Product identity + reviews<br/>shared shop]
    D --> E[Search other shops on the phone<br/>Amazon · Flipkart · Myntra · AJIO · Nykaa · Croma]
    E --> F[POST /match-products<br/>entity resolution + reasons]
    F -->|match| G[Read reviews on matched listing]
    F -->|possible| Q[Ask: 'Is this the same product?']
    Q -->|yes| G
    D --> H[POST /independent-opinions<br/>YouTube Data API · Reddit API]
    D & G & H --> I[POST /analyze-reviews]
    I --> R[Result screen<br/>verdict · photo meter · aspects · trust · shops · trend · size · why]
    R --> L[(History on the phone)]
```

Reviews are read **on the user's phone**, through the page the user's own browser session loads. The Render server never fetches shop pages. Sign-in pages and "are you human" checks are detected and handed to the user; the app never types into them, clicks them or solves them.

## Where things live

| Part | File |
|---|---|
| Share target, link parsing | `mobile/lib/features/reviews/share_listener.dart`, `link_parser.dart` |
| On-device reading | `page_reader.dart` (web view + JS channel), `mobile/assets/extract.js`, `collector.dart` |
| Selectors (fixable without a new APK) | `backend/app/data/review_selectors.json` → `GET /review-selectors`, copy in `mobile/assets/` |
| Cross-shop search + orchestration | `cross_platform.dart`, `analysis_job.dart` |
| Screens | `review_home.dart`, `analyse_screen.dart`, `result_screen.dart`, `settings_sheet.dart`, `rtheme.dart` |
| Product matching | `backend/app/services/product_matcher.py` → `POST /match-products` |
| YouTube / Reddit | `backend/app/services/opinions_service.py` → `POST /independent-opinions` |
| Review analysis | `backend/app/services/review_analyzer.py` → `POST /analyze-reviews` |
| Tests / evaluation / demo data | `backend/tests/`, `backend/eval/evaluate.py`, `backend/eval/build_demo.py`, `mobile/test/` |

The original `/analyze`, `/tickets`, `/resolve` and `/sections` endpoints are unchanged; the complaint helper is reached from "Got a problem after buying?" on Home.

## NLP techniques used

| Step | Technique | Where |
|---|---|---|
| Link understanding | Regex URL extraction, HTTP redirect following, URL pattern rules per shop | `link_parser.dart` |
| Review extraction | DOM selectors; text-sequence parsing for obfuscated pages (Flipkart); JSON-LD product data | `extract.js` |
| Cleaning | Boilerplate removal, id/text dedupe, cross-shop duplicate detection, relative date parsing ("3 days ago", "Mar, 2024") | `clean_reviews`, `parse_review_date` |
| Hinglish | Reused rule-based Hinglish → English normaliser + Hinglish opinion words added to the VADER lexicon (bakwas, badhiya, paisa vasool…) | `nlp_service.normalize_hinglish`, `review_analyzer._vader` |
| Aspect-based sentiment | 8 aspect keyword lexicons (incl. Hinglish), sentence split on punctuation and "but/lekin", VADER per sentence, star rating as tie-break for neutral sentences | `aspect_sentiment` |
| "Not as shown" | Pattern classifier for colour / size / material / looks / fake, with negation guards ("not fake") | `not_as_shown` |
| Review trust | Generic short 5★ share, TF-IDF (1-2 gram) cosine near-duplicates, sliding-window burst detection, unverified share, star–text sentiment mismatch | `trust_signals` |
| Trend | Last 60 days vs older: average stars and per-aspect negative share | `trend` |
| Product matching | Brand match + look-alike brand detection (SequenceMatcher), model-code normalisation ("Airdopes141" = "Airdopes 141"), generation/series conflicts, spec agreement (GB, W, mAh…), TF-IDF char 3-5-gram cosine + token overlap | `product_matcher.py` |
| Cross-shop comparison | Per-shop listing rating vs sample, gap ≥ 0.7★ with likely reasons (fake complaints, weaker aspects), cheapest confirmed listing, YouTube/Reddit sentiment vs shop sentiment | `cross_platform` |
| Verdict (XAI) | Weighted score from blended stars (shop histogram + sample), complaints, trust, aspects, trend; every deduction becomes a plain reason; real review excerpts as evidence | `star_basis`, `verdict`, `pick_quotes` |
| Confidence | Review count, number of shops, trust level, rating variance; below 15 reviews: no verdict | `confidence` |

No PyTorch or transformers on Render: everything above is regex, lexicons, VADER and scikit-learn.

## Evaluation (real data only)

Run from `backend/`: `venv\Scripts\python -m pytest tests -q` and `venv\Scripts\python -m eval.evaluate`.

| What | Data | Result |
|---|---|---|
| Unit tests per analyser function, matcher and endpoints' logic | written test sentences | 41 passed |
| Golden tests | 2 real products collected by the app (Myntra T-shirt 141 reviews, Flipkart earbuds 81) | verdicts, trust flag and size card as expected; every quote checked to be a real excerpt |
| Product matching | 10 labelled real listing-title pairs (5 same, 5 different: generation, storage, model number, look-alike brand) | precision 1.00, recall 1.00. Small set and the rules were tuned on it: a sanity check, not a measured accuracy |
| Review sentiment | 218 real reviews with 1-2★ or 4-5★, star rating as the label | positive F1 0.98, negative F1 0.84 (only ~20 negative reviews) |
| Aspects, "not as shown" | `eval/labelling_sheet.csv`: 234 real reviews with empty label columns | **not measured yet**: needs human labels. Fill it in, save as `eval/labels.csv`, re-run `eval.evaluate` |
| Transformer baseline | — | not done |

## Known limits

- Amazon's full review pages need sign-in; without it only the ~8 product-page reviews are available.
- AJIO, Nykaa and Croma: listings are matched and their rating/price shown, but their reviews aren't read yet. Reliance Digital search is disabled (selectors couldn't be verified).
- Shop layouts change; fix `review_selectors.json` and bump `version` (no new APK needed).
- Flipkart pages are slow on the emulator and sometimes time out; the app keeps going with what it has and says so.
