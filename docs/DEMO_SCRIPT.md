# HTH demo script

Tested against the live backend `https://hth-backend-5q9g.onrender.com` on 2026-11-26. Every result below is copied from the live `/resolve` response.

## Before you start

- Open `https://hth-backend-5q9g.onrender.com/health` a minute before the demo. Render's free tier sleeps, so the first request can take 30–60 s (the app shows "Waking up the server…").
- Install `mobile/build/app/outputs/flutter-apk/app-release.apk`. It points at the Render URL.
- Any step tagged **Not verified** in the app is a contact we couldn't confirm on an official page. The full list is under `unverified` in `backend/app/data/knowledge_base.json`.

## 1. Messy Hinglish shopping, two issues

**Type:** `bhai flipkart se mixer mangaya tha 2499 ka, toota hua aaya. return kiya 12 din ho gaye, refund bhi nahi aaya abhi tak`

**Taps:** Home → **Shopping** → type or paste the message → **Get help**

**Point out:** One message, two cards: the damaged mixer and the missing refund.

**Live result** (0.63 s):

- Company: **Flipkart**
- **Your Flipkart order came wrong or damaged** (urgency: medium)
  - ✓ The store's Grievance Officer must reply within 48 hours and fix your complaint within one month _(basis: Consumer Protection (E-Commerce) Rules, 2020)_
  - Do this now: **Step 1: Ask in the app** → button "Open help page" (`https://www.flipkart.com/helpcentre`)
  - Complaint email to `grievance.officer@flipkart.com`, subject "Complaint: Wrong or damaged item"
- **Your Flipkart refund hasn't arrived after 12 days** (urgency: medium)
  - ✓ The store's Grievance Officer must reply within 48 hours and fix your complaint within one month _(basis: Consumer Protection (E-Commerce) Rules, 2020)_
  - Do this now: **Step 2: Contact customer care** → button "Open help page" (`https://www.flipkart.com/helpcentre`)
  - Why this step: You've been waiting about 12 days, so start with customer care and quote the order. If they don't fix it in 48 hours, go to the Grievance Officer.
  - Complaint email to `grievance.officer@flipkart.com`, subject "Complaint: Refund not received"

## 2. Myntra size/fit return

**Type:** `Myntra se jeans mangayi thi, size 32 hai par bahut tight hai, exchange karna hai`

**Taps:** Home → **Shopping** → type or paste the message → **Get help**

**Point out:** Size/fit is understood from Hinglish ("bahut tight").

**Live result** (0.82 s):

- Company: **Myntra**
- **Your Myntra clothes don't fit and need a return or exchange** (urgency: low)
  - ✓ The store's Grievance Officer must reply within 48 hours and fix your complaint within one month _(basis: Consumer Protection (E-Commerce) Rules, 2020)_
  - Do this now: **Step 1: Ask in the app** → button "Open help page" (`https://www.myntra.com/contactus`)
  - Complaint email to `customergrievance@myntra.com`, subject "Complaint: Clothes don't fit"

## 3. IndiGo flight delay

**Type:** `IndiGo flight 7 ghante late tha, khana bhi nahi diya`

**Taps:** Home → **Travel** → tap the first example → **Get help**

**Point out:** Rights come from DGCA CAR Section 3 Series M Part IV (Rev. 4, 2023). Tap any line to see the paragraph and open the official PDF.

**Live result** (0.62 s):

- Company: **IndiGo**
- **Your IndiGo flight was 7 hours late** (urgency: low)
  - ✓ You were owed free meals and refreshments while you waited _(basis: DGCA CAR Section 3 Series M Part IV, para 3.4.1: delays of 4+ hours qualify for any flight length)_
  - ✓ You can ask for another flight within 6 hours, or a full refund _(basis: DGCA CAR Section 3 Series M Part IV, para 3.4.2 (domestic flights delayed more than 6 hours))_
  - May apply: If your flight was due to leave between 8 PM and 3 AM, you can also ask for a free hotel stay _(basis: DGCA CAR Section 3 Series M Part IV, para 3.4.3)_
  - Do this now: **Step 1: Contact airline customer care** → button "Call customer care" (`0124-4973838 / 0124-6173838`)
  - Complaint email to `Customer.experience@goindigo.in`, subject "Complaint: Flight delayed"

## 4. Train late, not left yet

**Type:** `Mera train 4 ghante late chal raha hai, abhi tak nikli nahi, mujhe ab nahi jaana. PNR 4512367890`

**Taps:** Home → **Travel** → type or paste the message → **Get help**

**Point out:** The red urgent banner: no refund if the TDR is filed after the train actually leaves (IRCTC refund rules, clause 6).

**Live result** (0.6 s):

- Company: **Indian Railways (IRCTC)**
- **Your train is running 4 hours late** (urgency: high)
  - Urgent banner: "File your TDR now, before the train departs, or you lose the full refund."
  - ✓ Full refund of your fare, with no cancellation charge _(basis: Indian Railways refund rules (w.e.f. 12 Nov 2015), clause 6: train more than 3 hours late and you don't travel)_
  - Do this now: **Step 1: File a TDR on IRCTC (refund) or complain on RailMadad** → button "File TDR on IRCTC" (`https://www.irctc.co.in/nget/train-search`)
  - Complaint email to `(add the company email)`, subject "Complaint: Train late, didn't travel (PNR 4512367890)"

## 5. Vague message

**Type:** `kuch problem hai, help chahiye`

**Taps:** Home → **Shopping** → type the message → **Get help** → answer the question

**Point out:** Clarification: one simple question with big buttons instead of a wrong guess.

**Live result** (0.52 s):

- Question: **What is your problem about?**
- Options: *A shopping order*, *A flight*, *A train*
- Tap *A shopping order* → *What went wrong?* → *Refund not received* → pick the store → the fix appears.

## Also worth showing

- **Write my complaint**: an editable email. Anything we couldn't detect is left as a [placeholder], never made up. Send, Copy and Share buttons.
- **Didn't work? Show next step**: moves the case up the ladder. Shopping: store → Grievance Officer → National Consumer Helpline (1915) → e-Daakhil. Flights: airline → Nodal Officer → Appellate Authority → AirSewa → NCH → e-Daakhil.
- **My cases**: a countdown to each deadline, an evidence log (Copy, Call and Email are logged automatically), *Add a note or ticket number*, and *Mark as solved*.
- The **Company triage mode** link at the bottom of Home still opens the original app, and `/analyze` is unchanged.
