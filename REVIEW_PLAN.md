# HTH Review Analyser: build plan

Read `CLAUDE.md` first. Its "Do not undo these fixes" section still applies.

## Goal

Before buying, a shopper on Amazon, Flipkart or Myntra taps **Share → HTH** on a product. HTH fetches that product's reviews live, at that moment, and tells them in plain words whether the product really is what it looks like, what buyers actually say, and whether the reviews can be trusted.

Link only (via the share button). No screenshots, no circling.

The existing NLP engine (Hinglish normalization, multi-issue/multi-aspect decomposition, XAI reasons, confidence handling) is reused for review analysis. Keep the existing `/analyze`, `/tickets` and `/resolve` endpoints working; the complaint helper stays as a secondary "Got a problem after buying?" entry.

## Rules

- Work phase by phase. After each phase, summarise what changed and how to test it, then continue unless something broke.
- Small, focused edits. Commit a checkpoint before starting ("Before review analyser").
- **Never bypass CAPTCHAs, bot checks or logins.** If a page asks for sign-in or a check, show that page to the user in a visible in-app browser so they can deal with it themselves, then continue.
- Fetch reviews **on the user's phone** (the user's own browsing), not from the Render server.
- Render free tier has limited memory: keep backend models light (no PyTorch/transformers on Render). Heavier experiments can run offline for the report.
- Don't push or deploy without asking me.

---

## Phase 1: Share target + link handling (Flutter)

- Register HTH as an Android share target for text (`receive_sharing_intent`). The shared text from these apps contains a product URL plus extra words; extract the URL.
- Resolve short links (amzn.in, amzn.to, dl.flipkart.com, myntr.it etc.) by following redirects, then identify platform + product ID (Amazon ASIN, Flipkart pid, Myntra style ID).
- If the link isn't a supported product page, show a friendly message: "Share a product from Amazon, Flipkart or Myntra".

## Phase 2: Live review collection on the device

- Use `flutter_inappwebview` (headless first). Load the product's review pages and extract reviews with JavaScript in the page.
- For each review collect: text, title, star rating, date, verified-purchase flag, variant (size/colour) if shown, helpful votes, and the product's overall rating + rating distribution.
- Prefer "most recent" sort and collect up to ~100–150 reviews (a few pages), with a progress indicator ("Reading reviews… 64 found").
- Keep platform-specific selectors in a JSON config fetched from the backend (`GET /review-selectors`) with a bundled fallback, so a layout change can be fixed without rebuilding the app.
- If the headless load hits a sign-in page or a check, switch to a visible in-app browser with a short explanation; resume extraction once the reviews page loads.
- Timeout gracefully and analyse whatever was collected (minimum ~15 reviews, otherwise say there isn't enough data).

## Phase 2b: Find the same product on other platforms + independent sources

Reviews should come from everywhere the product exists, not only the shared platform.

- From the shared page, extract product identity: brand, model/style number, full title, key specs (capacity, size, colour, material), variant, price, main image URL.
- **Find candidate listings elsewhere:** search Amazon, Flipkart, Myntra, Ajio, Nykaa, Croma, Reliance Digital and the brand's site (platform search pages loaded in the on-device browser; optionally a web search API if a free/legit one is available; ask me before adding any paid API).
- **Product matching (entity resolution) in the backend** `POST /match-products`: score each candidate using brand match, model-number match (normalise "Airdopes141" vs "Airdopes 141"), spec agreement, and title similarity (TF-IDF cosine + token overlap; Hinglish/transliteration-tolerant). Return match / possible match / no match with confidence and XAI reasons. Only treat high-confidence matches as the same product; show possible matches to the user as "Is this the same product?" Never merge a low-confidence match silently.
- **Unbranded/generic products:** if no confident match, say "Couldn't find this exact product elsewhere" rather than guessing.
- Collect reviews from each confirmed match on-device (same method as Phase 2), in parallel, showing per-source progress ("Amazon ✓ 120 · Flipkart ✓ 85 · Croma… ").
- **Independent sources** (official APIs only, keys stored in backend env vars, never in the app):
  - YouTube Data API: search "<brand model> review", take top videos' titles, descriptions and top comments.
  - Reddit API: search relevant subreddits for the product name; take post text and top comments.
  - Mark these as "independent opinions" in the UI; they get their own section and are weighted separately from shopping-site reviews.
- Keep each source's data tagged with its platform so the analysis can compare platforms.
- Add 10 labelled product-pair examples (matches and non-matches) to tests and report matching precision/recall.

## Phase 3: Review analysis NLP (backend)

New service `backend/app/services/review_analyzer.py`, endpoint `POST /analyze-reviews` taking product meta + the review list. Each piece is its own function so it's easy to explain and test:

1. **Cleaning + language:** dedupe, strip boilerplate, reuse the Hinglish normalization.
2. **Aspect-based sentiment:** aspects: quality, size/fit, colour/looks, material/fabric, durability, value for money, delivery/packaging, authenticity/seller. Use aspect keyword lexicons (including Hinglish terms) + sentence-level sentiment (VADER/TextBlob-style, light) to give each aspect a positive/negative share and the number of mentions.
3. **"Not as shown" detector:** classify reviews claiming the product differs from the photo/description ("colour is different", "looks cheap", "not same as picture", "fabric is thin", "size chart wrong", "duplicate/fake"). Return the % of reviews making such claims, broken down by type (colour, size, material, fake), with example quotes.
4. **Review trust signals:** share of short generic 5-star reviews, near-duplicate texts (TF-IDF cosine similarity), bursts of reviews on the same few days, unverified share, and mismatch between star rating and review sentiment. Combine into a trust score with the reasons listed.
5. **Trend:** compare recent reviews (last ~60 days) with older ones per aspect: "Quality complaints have increased recently."
6. **Cross-platform comparison:** per-platform rating and aspect scores, flag big gaps ("4.4★ on Amazon vs 3.2★ on Flipkart") with likely reasons from the reviews (e.g. one seller with fake-product complaints), dedupe reviews cross-posted on several platforms, and show the lowest price among confirmed genuine listings. Compare independent opinions (YouTube/Reddit) with shopping-site reviews and highlight disagreements.
7. **Verdict:** overall score (e.g. Good buy / Buy with caution / Avoid) with XAI reasons and 3–5 real review quotes (short excerpts) as evidence. Size/fit advice for clothing ("Most buyers say it runs small, consider one size up") when the reviews support it.
8. Confidence: if few reviews or mixed signals, say so plainly instead of guessing.

Evaluation for the report:
- Build a labelled set of ~300 real-style reviews (English + Hinglish) for aspects, "not as shown" and sentiment. Report precision/recall/F1 for each component.
- Optionally compare the light production model with a transformer baseline run offline (not deployed).
- Unit tests for each function; golden tests for 3 saved products.

## Phase 4: App UI

Keep it very simple: share → one result screen.

- **Analysing screen:** "Reading reviews… 64 found" → "Checking what buyers say" → "Checking if reviews are genuine", with smooth ticks.
- **Result screen** (top to bottom):
  - product title + platform + overall verdict badge (green / amber / red) with one plain sentence
  - **"Is it like the photo?"** meter with the % of buyers saying it isn't, and the main reasons (colour, size, material)
  - aspect bars (quality, size/fit, colour, material, durability, value, delivery) with positive/negative split; tapping one shows real quotes
  - **"Can you trust these reviews?"** trust score with red flags listed
  - **"Across platforms"** card: where else it's sold, rating on each, biggest gap explained, cheapest genuine listing with an open button
  - **"Independent opinions"** card: YouTube and Reddit summary with links
  - trend line ("Getting worse lately" / "Stable")
  - clothing: size advice card when relevant
  - "Why this verdict?" expandable XAI section
  - share result button
- **History:** recently analysed products saved locally.
- Home screen: a short "How to use: open any product in Amazon, Flipkart or Myntra → tap Share → choose HTH" guide with an animation, a manual "Paste link" box, history, and a small entry to the complaint helper.
- Design: calm, premium, easy. Navy text on off-white, green/amber/red only for verdicts, one brand accent, rounded cards, Plus Jakarta Sans or Inter, dark mode. Animations ≤ 400ms: staggered card entry, animated meters and bars filling, count-up numbers, smooth transitions. Respect reduce-motion. Fix navigation so Android back works everywhere.

## Phase 5: Demo mode, build, docs

- **Demo mode** (settings toggle): 4 saved products with stored reviews (a good product, a "not as shown" clothing item, one with suspicious reviews, one getting worse recently) so the demo never depends on live pages.
- Rebuild the release APK.
- `docs/DEMO_SCRIPT.md`: live share demo + demo-mode fallback.
- `docs/ARCHITECTURE.md`: Mermaid diagram (share → on-device collection → backend NLP → result) and a table of NLP techniques used where.
- Ask me before pushing/deploying.

## Done when

Sharing a real branded product from Amazon, Flipkart or Myntra finds it on other platforms, combines their reviews with YouTube/Reddit opinions, and gives a clear verdict within ~40 seconds, demo mode works offline from live pages, evaluation numbers are in the docs, and the release APK runs on the emulator.
