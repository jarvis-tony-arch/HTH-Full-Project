from fastapi import APIRouter, HTTPException

from app.schemas import ResolveRequest, ResolveResponse, SectionsResponse
from app.services.resolve_service import resolve, sections_overview

router = APIRouter()


@router.get("/sections", response_model=SectionsResponse)
def get_sections():
    return sections_overview()


@router.post("/resolve", response_model=ResolveResponse)
def resolve_problem(request: ResolveRequest):
    text = (request.text or "").strip()
    if not text and not request.issue_type:
        raise HTTPException(status_code=422, detail="Please tell us what happened.")
    # Plain sync def: FastAPI runs it in a worker thread (spaCy work is CPU-bound).
    return resolve(text, request.section, request.company, request.issue_type)
