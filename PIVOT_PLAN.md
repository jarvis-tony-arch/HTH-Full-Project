# HTH Pivot Plan: one-day build

Read `CLAUDE.md` first. Its "Do not undo these fixes" section still applies.

## Goal

Turn HTH into a simple app that helps ordinary people in India get their problems fixed. The app has two sections:

1. **Shopping:** online orders and clothing (Amazon, Flipkart, Myntra, Ajio, Meesho)
2. **Travel:** flights (IndiGo, Air India, Akasa Air, SpiceJet) and trains (Indian Railways / IRCTC)

The user describes the problem in their own words (English or Hinglish). The app works out what went wrong, tells them what they're entitled to, gives the exact next step and contact, writes the complaint for them, and keeps escalating with deadlines until it's fixed.

We can't force a company to reply, so the app makes sure the user is never stuck. Every level has a deadline. When it passes, the app moves the user to the next authority, ending with government bodies the company has to answer to.

The existing NLP engine (intent classification, multi-issue decomposition, Hinglish normalization, XAI reasons, confidence escalation) stays as the core. Extend it, don't rewrite it.

**This must be finished and demo-ready today.** Working and stable beats feature-rich. If something will take too long, tell me and suggest a simpler version.

## Rules

- Work through the steps in order. After each step, give me a 2–3 line summary and how to check it, then carry on unless something broke.
- Small, targeted edits. Keep the existing `/analyze` and `/tickets` endpoints and their response shapes working exactly as now.
- No new database tables today. The knowledge base is a JSON file; cases are stored on the phone.
- **Never invent a phone number, email, URL, rule or rupee amount.** Verify every one from an official source (company help/contact/grievance pages; dgca.gov.in, airsewa.gov.in, indianrailways.gov.in, irctc.co.in, consumerhelpline.gov.in, edaakhil.nic.in, rbi.org.in). Store the source URL with it. If you can't verify something, set it to null and the app shows "Check the official page". Give me a list of everything unverified at the end of Step 1.
- Don't commit or push unless I ask. Ask before deploying.

---

## Step 1: Knowledge base (about 1.5 hours)

Create `backend/app/data/knowledge_base.json` with two sections.

### Shopping

- Platforms: amazon, flipkart, myntra, ajio, meesho. Fields: name, help_url, customer_care_phone, customer_care_email, grievance_officer_email, grievance_url, source_url, last_verified.
- Issues: `refund_delay`, `late_delivery`, `wrong_or_damaged_item`, `size_or_fit_return` (clothing), `return_rejected`, `payment_deducted_no_order`.
- For each platform + issue: short in-app steps (menu path) and `expected_days` only if the official policy states it.
- Ladder: 1 In-app help → 2 Customer care → 3 Grievance officer (Consumer Protection (E-Commerce) Rules, 2020: must acknowledge within 48 hours and resolve within 1 month) → 4 National Consumer Helpline (1915 / consumerhelpline.gov.in) → 5 e-Daakhil.
- For `payment_deducted_no_order`, also add a bank route: "Raise a dispute in your bank or UPI app", citing RBI's failed-transaction rules (auto-reversal deadlines and ₹100/day compensation). Verify exact timelines from rbi.org.in.

### Travel

- Airlines: indigo, air_india, akasa_air, spicejet (same contact fields, plus `nodal_officer_email` and `appellate_authority_email` if published).
- Trains: indian_railways (RailMadad portal, 139 helpline, IRCTC TDR page).
- Issues: `flight_delay`, `flight_cancellation`, `denied_boarding`, `baggage_issue`, `train_late_not_travelled`, `train_cancelled`.
- **Entitlement rules** as structured data (not free text) so code can evaluate them, all verified from the current DGCA CAR Section 3 Series M Part IV and the Indian Railways refund rules. Check for any 2026 revisions. Expected shape, e.g.:
  - flight delay: meals threshold by flight length; refund-or-alternate threshold (6+ hours); hotel conditions (24+ hours, or 6+ hours for a 20:00–03:00 departure); note that a delay by itself doesn't give cash compensation
  - flight cancellation: compensation by block time and notice period
  - train late > 3 hours and not travelled: full refund **only if the TDR is filed before the train actually departs**
  - train cancelled: full refund rules and filing window
- Flight ladder: 1 Airline customer care → 2 Airline nodal officer → 3 Appellate authority (if the airline has one) → 4 AirSewa → 5 National Consumer Helpline → 6 e-Daakhil.
- Train ladder: 1 TDR on IRCTC (for refunds) or RailMadad / 139 (for complaints) → 2 National Consumer Helpline → 3 e-Daakhil.

Each ladder level has `wait_hours_before_next` taken from the rules where they exist (e.g. 48 hours for e-commerce grievance acknowledgement), otherwise a sensible default clearly marked as a default.

## Step 2: NLP resolve service (about 2.5 hours)

New file `backend/app/services/resolve_service.py` (small helper functions in the same file are fine):

1. **Section + company detection:** detect Shopping vs Travel and the company from names, misspellings and Hinglish ("flipkart pe", "indigo ki flight", "train late hai"). Return company, confidence and the matched words.
2. **Entity extraction:** spaCy + regex for order ID, amount (₹, Rs, "2499 ka"), durations ("10 din se", "2 weeks") → `days_waiting`, delay length ("7 ghante late", "delayed by 5 hrs") → `delay_hours`, airline PNR (6 characters), train PNR (10 digits), flight number (e.g. "6E 2134", "AI 101"), train number (5 digits), and dates.
3. **Issue classification:** reuse the existing pipeline (Hinglish normalization + multi-issue decomposition + intent). Map existing intents to the new issue slugs with one clear mapping dict; fall back to keyword matching from the knowledge base.
4. **Entitlement engine (travel):** compare `delay_hours`, notice period, time of day etc. with the rules and return plain-English entitlements: "You were owed free meals", "You can ask for a full refund", "This delay doesn't qualify for cash compensation". For trains, if the train hasn't left yet, return an **urgent** flag: "File your TDR now, before the train departs, or you lose the full refund."
5. **Escalation engine:** pick the starting level. If the official deadline has already passed, skip ahead and explain why. Every level gets a `deadline` the app can count down to.
6. **Urgency:** low / medium / high from cues ("money deducted", "again", "no response", "urgent", "train leaving") and amount size.
7. **Complaint email:** template + slot filling. Turns the user's casual or Hinglish text into a polite, formal English complaint with the extracted details. From the grievance-officer level onwards, the email cites the relevant rule and deadline. Use placeholders like `[Your name]` for missing details, never made-up values.
8. **Clarification:** if company or issue confidence is low, return `needs_clarification: true` with 2–4 simple options.

Every issue gets short, plain-English `xai_reasons` that quote what the user wrote.

## Step 3: API (about 45 minutes)

New router `backend/app/routes/resolve.py` and new schemas in `schemas.py` (don't change existing ones):

- `GET /sections`: sections with their companies
- `POST /resolve` with `{ text, section?, company? }` → `{ section, company, needs_clarification, clarification_options, issues: [ { issue_type, confidence, xai_reasons, entities, urgency, entitlements, urgent_action, start_level, steps: [ { level, title, instructions, channel, contact, verified, deadline_hours } ], complaint: { to, subject, body } } ] }`

The response JSON must match the Pydantic schema exactly. Test with 8 messages (shopping English, shopping Hinglish, clothing size return, multi-issue, flight delay, flight cancellation, train late, vague) and show me the outputs. Confirm `/analyze` still works.

## Step 4: Flutter app (about 3.5 hours)

**The most important requirement: the app must feel simple.** Someone who is stressed and not tech-savvy should get help in 3 taps or fewer. Big, clear text, plain words, one main action per screen, no jargon (say "Get your money back", not "Initiate escalation").

Keep the existing structure; add `lib/features/resolve/` and `lib/core/theme.dart`. Simple state (setState or Provider).

Packages: `google_fonts`, `flutter_animate`, `url_launcher`, `share_plus`, `shared_preferences`, `shimmer`.

Design: calm and friendly, Material 3, one brand colour with a soft accent per section (e.g. blue for Shopping, teal for Travel), rounded cards (radius 20), Plus Jakarta Sans or Inter, plenty of white space, large tap targets (≥ 48px), readable at large system font sizes. No trademarked logos: coloured circles with the company's initial.

Screens:

1. **Home:** friendly greeting and two large cards, **Shopping** ("Orders, clothes, refunds") and **Travel** ("Flights and trains"). Below that, "Your open cases" if any. A small text link at the bottom opens the old Company triage mode.
2. **Describe your problem:** after picking a section, show that section's companies as tappable chips (optional) and one big text box: "Tell us what happened, in your own words". Show 3 example chips for that section that fill the box when tapped. One big "Get help" button.
3. **Working on it:** short animated checklist (Understanding your problem ✓ → Checking your rights ✓ → Finding the fastest fix ✓), about 1.5s minimum. If the request takes over 3s, show "Waking up the server, this takes a few seconds the first time". 60s timeout with a friendly retry.
4. **Your fix** (results), one card per issue, top to bottom:
   - a one-line summary in plain words ("Your IndiGo flight was 7 hours late")
   - **urgent banner** if there's one (e.g. "File your TDR before the train leaves")
   - **"What you're entitled to"** as simple ticked lines
   - **"Do this now"**: only the current step, with one big action button (Call / Email / Open website / Copy). Later steps are collapsed under "If that doesn't work".
   - deadline countdown: "If they don't reply by Sat 6 PM, we'll show you the next step"
   - "Write my complaint" opens a bottom sheet with the ready email (editable) + Copy / Send email / Share
   - "Why are we suggesting this?" small expandable link with the XAI reasons and detected details as chips
   - "Didn't work? Show next step" button
   - "Not verified" tag on any unverified contact
5. **Clarification:** a simple question with big option buttons.
6. **My cases:** saved locally: company, problem, current step, deadline countdown, status. An **evidence log** per case (what was sent, when, any ticket number the user types in), because NCH, AirSewa and e-Daakhil ask for this. "Mark as solved" with a small celebration animation.

Animations: gentle and quick (≤ 400ms): staggered fade/slide on cards (flutter_animate), card press scale, smooth page and bottom-sheet transitions, shimmer while loading, tick animations on the checklist. Nothing that slows the user down. Respect reduce-motion settings.

## Step 5: Ship (about 1 hour)

1. Make sure `requirements.txt` has anything new and still works on Python 3.11.9. Ask me before deploying to Render; then hit `/resolve` on the live URL.
2. Point the app at the Render URL and build `flutter build apk --release`. Tell me where the APK is.
3. Write `docs/DEMO_SCRIPT.md` with 5 demo inputs tested against the live backend:
   - a messy Hinglish shopping message with two issues (refund + damaged item)
   - a Myntra size/fit return
   - "IndiGo flight 7 ghante late tha, khana bhi nahi diya"
   - a train running 4 hours late that hasn't left yet (shows the urgent TDR banner)
   - a vague message that triggers clarification

## Done when

Each demo input goes from the user's words to a clear next step and a ready complaint on the live backend, every contact and rule is verified or clearly marked, the old `/analyze` still works, and the release APK runs on the emulator.
