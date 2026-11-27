"""Guards against a real bug found on 2026-11-27: a patch turned regex
"\b" into a literal backspace character, silently disabling two patterns."""
from pathlib import Path

ROOTS = ["app", "tests", "eval", "../mobile/lib", "../mobile/assets"]


def test_no_control_characters_in_source():
    base = Path(__file__).resolve().parent.parent
    bad = []
    for root in ROOTS:
        for p in (base / root).rglob("*"):
            if p.is_file() and p.suffix in {".py", ".dart", ".js", ".json"}:
                for n, line in enumerate(p.read_text(encoding="utf-8", errors="ignore").split("\n"), 1):
                    if any(ord(c) < 32 and c not in "\t\r" for c in line):
                        bad.append(f"{p.relative_to(base)}:{n}")
    assert not bad, bad


def test_mobile_selector_copy_matches_backend():
    base = Path(__file__).resolve().parent.parent
    a = (base / "app/data/review_selectors.json").read_text(encoding="utf-8")
    b = (base / "../mobile/assets/review_selectors.json").read_text(encoding="utf-8")
    assert a == b, "Copy backend/app/data/review_selectors.json to mobile/assets/"
