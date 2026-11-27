"""Independent opinions: YouTube and Reddit, through their official APIs only.

Keys live in backend environment variables (never in the app):
  YOUTUBE_API_KEY                         YouTube Data API v3 (free quota)
  REDDIT_CLIENT_ID, REDDIT_CLIENT_SECRET  Reddit "script"/app-only OAuth
If a key is missing, that source reports configured=False and returns
nothing. Nothing is ever made up.
"""
from __future__ import annotations

import base64
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

_UA = "HTH-review-analyser/1.0 (academic project)"
_TIMEOUT = 8
_cache: dict[str, tuple[float, dict]] = {}
_CACHE_SECONDS = 6 * 3600
_reddit_token: tuple[float, str] | None = None


def _get(url: str, headers: dict | None = None, data: bytes | None = None) -> dict:
    req = urllib.request.Request(url, data=data, headers={"User-Agent": _UA, **(headers or {})})
    with urllib.request.urlopen(req, timeout=_TIMEOUT) as r:  # noqa: S310 (fixed https hosts)
        return json.loads(r.read().decode("utf-8"))


def _short(text: str, n: int = 400) -> str:
    text = " ".join((text or "").split())
    return text if len(text) <= n else text[: n - 1].rsplit(" ", 1)[0] + "…"


# ─── YouTube ──────────────────────────────────────────────────────────
def youtube(query: str, max_videos: int = 4, comments_per_video: int = 15) -> dict:
    key = os.getenv("YOUTUBE_API_KEY")
    if not key:
        return {"configured": False, "items": []}
    base = "https://www.googleapis.com/youtube/v3"
    try:
        s = _get(f"{base}/search?" + urllib.parse.urlencode({
            "part": "snippet", "q": f"{query} review", "type": "video", "maxResults": max_videos,
            "regionCode": "IN", "relevanceLanguage": "en", "safeSearch": "moderate", "key": key,
        }))
    except (urllib.error.URLError, TimeoutError, ValueError) as e:
        return {"configured": True, "items": [], "error": f"YouTube search failed: {type(e).__name__}"}
    items = []
    for v in s.get("items", []):
        vid = (v.get("id") or {}).get("videoId")
        sn = v.get("snippet") or {}
        if not vid:
            continue
        comments: list[str] = []
        try:
            c = _get(f"{base}/commentThreads?" + urllib.parse.urlencode({
                "part": "snippet", "videoId": vid, "maxResults": comments_per_video,
                "order": "relevance", "textFormat": "plainText", "key": key,
            }))
            for t in c.get("items", []):
                top = ((t.get("snippet") or {}).get("topLevelComment") or {}).get("snippet") or {}
                if top.get("textDisplay"):
                    comments.append(_short(top["textDisplay"], 300))
        except (urllib.error.URLError, TimeoutError, ValueError):
            pass  # comments disabled on many videos
        items.append({
            "source": "youtube",
            "title": sn.get("title", ""),
            "text": _short(sn.get("description", "")),
            "channel": sn.get("channelTitle", ""),
            "published": (sn.get("publishedAt") or "")[:10],
            "url": f"https://www.youtube.com/watch?v={vid}",
            "comments": comments,
        })
    return {"configured": True, "items": items}


# ─── Reddit ───────────────────────────────────────────────────────────
def _reddit_auth() -> str | None:
    global _reddit_token
    cid, secret = os.getenv("REDDIT_CLIENT_ID"), os.getenv("REDDIT_CLIENT_SECRET")
    if not cid or not secret:
        return None
    if _reddit_token and _reddit_token[0] > time.time() + 60:
        return _reddit_token[1]
    auth = base64.b64encode(f"{cid}:{secret}".encode()).decode()
    tok = _get("https://www.reddit.com/api/v1/access_token",
               headers={"Authorization": f"Basic {auth}", "Content-Type": "application/x-www-form-urlencoded"},
               data=b"grant_type=client_credentials")
    _reddit_token = (time.time() + float(tok.get("expires_in", 3600)), tok["access_token"])
    return _reddit_token[1]


def reddit(query: str, max_posts: int = 5, comments_per_post: int = 10) -> dict:
    try:
        token = _reddit_auth()
    except (urllib.error.URLError, TimeoutError, ValueError, KeyError) as e:
        return {"configured": True, "items": [], "error": f"Reddit sign-in failed: {type(e).__name__}"}
    if not token:
        return {"configured": False, "items": []}
    h = {"Authorization": f"bearer {token}"}
    try:
        s = _get("https://oauth.reddit.com/search?" + urllib.parse.urlencode({
            "q": query, "limit": max_posts * 2, "sort": "relevance", "t": "year", "type": "link",
        }), headers=h)
    except (urllib.error.URLError, TimeoutError, ValueError) as e:
        return {"configured": True, "items": [], "error": f"Reddit search failed: {type(e).__name__}"}
    items = []
    q_words = {w.lower() for w in query.split() if len(w) > 2}
    for child in (s.get("data") or {}).get("children", []):
        d = child.get("data") or {}
        title = d.get("title", "")
        # Keep posts that actually name the product (most query words in the title or text).
        hay = f"{title} {d.get('selftext', '')}".lower()
        if q_words and sum(w in hay for w in q_words) < max(2, len(q_words) // 2):
            continue
        comments: list[str] = []
        try:
            c = _get(f"https://oauth.reddit.com/comments/{d['id']}?" + urllib.parse.urlencode(
                {"limit": comments_per_post, "sort": "top", "depth": 1}), headers=h)
            for ch in (c[1]["data"]["children"] if isinstance(c, list) and len(c) > 1 else []):
                body = (ch.get("data") or {}).get("body")
                if body and body not in ("[deleted]", "[removed]"):
                    comments.append(_short(body, 300))
        except (urllib.error.URLError, TimeoutError, ValueError, KeyError, TypeError):
            pass
        items.append({
            "source": "reddit",
            "title": title,
            "text": _short(d.get("selftext", "")),
            "channel": f"r/{d.get('subreddit', '')}",
            "published": time.strftime("%Y-%m-%d", time.gmtime(d.get("created_utc", 0))),
            "url": f"https://www.reddit.com{d.get('permalink', '')}",
            "comments": comments[:comments_per_post],
        })
        if len(items) >= max_posts:
            break
    return {"configured": True, "items": items}


def independent_opinions(query: str) -> dict:
    query = " ".join((query or "").split())[:120]
    if not query:
        return {"query": "", "youtube": {"configured": False, "items": []}, "reddit": {"configured": False, "items": []}}
    hit = _cache.get(query.lower())
    if hit and hit[0] > time.time():
        return hit[1]
    out = {"query": query, "youtube": youtube(query), "reddit": reddit(query)}
    if not out["youtube"].get("error") and not out["reddit"].get("error"):
        _cache[query.lower()] = (time.time() + _CACHE_SECONDS, out)
    return out
