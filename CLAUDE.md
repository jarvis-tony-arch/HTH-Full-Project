# HTH Smart Customer Support Intelligence

B.Tech academic project. A multilingual, AI-powered customer support triage mobile app.

Key features: multi-issue decomposition (one message routed to several departments), Hinglish normalization, explainable AI (XAI) routing reasons, and confidence-aware human escalation.

## Stack and live infrastructure

- Mobile: Flutter (Dart), targeting Android. Code in `mobile/`.
- Backend: FastAPI on Python 3.11.9, deployed on Render. Code in `backend/`.
- Database: PostgreSQL on Neon (not Render).
- Monitoring: UptimeRobot pings the backend every 5 minutes to stop Render free-tier sleep.
- Backend URL: https://hth-backend-5q9g.onrender.com
- API docs: https://hth-backend-5q9g.onrender.com/docs

## Structure

- `backend/main.py`: FastAPI entry point
- `backend/app/database.py`: SQLAlchemy setup
- `backend/app/models.py`: DB tables
- `backend/app/schemas.py`: Pydantic request/response schemas
- `backend/app/routes/`: `analyze.py`, `tickets.py`
- `backend/app/services/`: `nlp_service.py`, `language_service.py`
- `backend/requirements.txt`, `backend/.python-version`
- `mobile/lib/services/api_service.dart`: points at the Render URL

`datasets/`, `ml/` and `saved_models/` are not in git (too large). They are copied in locally.

## Do not undo these fixes

1. `googletrans` is removed for good (httpx/h11 conflicts). Use `deep-translator`.
2. Python must stay 3.11.9 (`.python-version` plus a Render env var). Newer versions break spaCy.
3. On Render, `NLTK_DATA=/opt/render/nltk_data` and the build command downloads the corpora there.
4. `database.py` uses `pool_pre_ping=True` because Neon sleeps. Keep it.
5. `AnalyzeResponse` in `schemas.py` must match the JSON from `nlp_service.py` exactly (e.g. `intent`, not `issue`; `xai_reasons`, not `explanations`). Change both together or neither.
6. `AndroidManifest.xml` keeps the INTERNET permission and `android:usesCleartextTraffic="true"`.

## Local environment (Windows 11 laptop)

- Use PowerShell. Python 3.11.9 is installed (`py -3.11`).
- Backend venv lives at `backend/venv` and must be gitignored. Secrets (e.g. `DATABASE_URL`) go in `backend/.env`, never committed. Copy values from the Render dashboard.
- Run the backend locally with `uvicorn main:app --reload` from `backend/`.
- Flutter commands run from `mobile/`, not the repo root.
- Flutter Android builds should use JDK 17 (Android Studio's bundled `jbr`), not the system JDK 25.
- From the Android emulator, the local backend is `http://10.0.2.2:8000`. Leave `api_service.dart` on the Render URL unless asked.

## Working rules

- Prefer small, targeted edits over rewrites.
- Don't commit or push unless asked. Never commit `.env`, keystores, `google-services.json` or `local.properties`.
- After a backend change, check that `/docs` still loads and the analyze endpoint's response matches `AnalyzeResponse`.
