import json
from functools import lru_cache
from pathlib import Path

from fastapi import APIRouter

from app.schemas import (AnalyzeReviewsRequest, AnalyzeReviewsResponse, MatchRequest, MatchResponse,
                         OpinionsRequest, OpinionsResponse)
from app.services.review_analyzer import analyze_reviews
from app.services.opinions_service import independent_opinions
from app.services.product_matcher import match_products, search_query

router = APIRouter()

_SELECTORS = Path(__file__).resolve().parent.parent / "data" / "review_selectors.json"


@lru_cache(maxsize=1)
def _selectors() -> dict:
    return json.loads(_SELECTORS.read_text(encoding="utf-8"))


@router.get("/review-selectors")
def review_selectors():
    """Page selectors the app uses to read reviews on the phone. Bumping
    "version" here lets a layout change be fixed without a new APK."""
    return _selectors()


@router.post("/search-query")
def make_search_query(product: dict):
    """Short store-search query for a product (brand + model words)."""
    return {"query": search_query(product)}


@router.post("/match-products", response_model=MatchResponse)
def match(request: MatchRequest):
    """Which of these listings on other shops are the same product?"""
    product = request.product.model_dump()
    cands = [c.model_dump() for c in request.candidates if c.title and c.url]
    out = match_products(product, cands)
    return {**out, "query": search_query(product)}


@router.post("/independent-opinions", response_model=OpinionsResponse)
def opinions(request: OpinionsRequest):
    """YouTube + Reddit through their official APIs (keys in env vars)."""
    return independent_opinions(request.query)


@router.post("/analyze-reviews", response_model=AnalyzeReviewsResponse)
def analyze(request: AnalyzeReviewsRequest):
    """Verdict, aspects, "not as shown", trust, trend and cross-shop comparison
    for the reviews the phone collected. Sync def: runs in a worker thread."""
    return analyze_reviews(request.model_dump())
