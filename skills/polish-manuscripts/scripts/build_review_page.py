#!/usr/bin/env python3
"""Fill the review-page template from a JSON spec.

Usage: build_review_page.py SPEC.json OUT.html

SPEC.json:
{
  "title": "Short Page Name",
  "eyebrow": "paper.tex · review of 2026-10-25",
  "lede": "What was read, which commit line numbers refer to, how to respond.",
  "plan_blurb": "(optional) one or two sentences on session ordering",
  "groups": [{"id": "T", "name": "Section titles", "blurb": "The question asked"}],
  "items": [{"id": "T1", "g": "T", "p": "high|med|low", "t": "title",
             "b": "finding", "s": "suggestion", "r": [":212"], "rel": ["O7"]}]
}

Text fields in items may use `backticks` for code spans. Any inconsistency in
the spec is an error: the page is the user's record of decisions, so a missing
group or a dangling cross-reference must be fixed rather than rendered.
"""
import html
import json
import sys
from pathlib import Path

TEMPLATE = Path(__file__).resolve().parent.parent / "assets" / "review-page.html"
DEFAULT_PLAN = ("Accepted items are grouped into editing sessions, each run in a fresh "
                "context. Click an item ID to jump to it; a check mark means it is done.")
PRIORITIES = {"high", "med", "low"}
ITEM_KEYS = {"id", "g", "p", "t", "b", "s", "r", "rel"}


def fail(msg):
    sys.exit(f"build_review_page: {msg}")


def check(spec):
    for key in ("title", "eyebrow", "lede", "groups", "items"):
        if key not in spec:
            fail(f"spec is missing {key!r}")
    gids = [g["id"] for g in spec["groups"]]
    if len(set(gids)) != len(gids):
        fail(f"duplicate group ids: {gids}")
    ids = [it["id"] for it in spec["items"]]
    dups = {i for i in ids if ids.count(i) > 1}
    if dups:
        fail(f"duplicate item ids: {sorted(dups)}")
    known = set(ids)
    for it in spec["items"]:
        extra = set(it) - ITEM_KEYS
        if extra:
            fail(f"{it['id']}: unknown keys {sorted(extra)}")
        for key in ("g", "p", "t"):
            if key not in it:
                fail(f"{it['id']}: missing {key!r}")
        if it["g"] not in gids:
            fail(f"{it['id']}: group {it['g']!r} is not in groups")
        if it["p"] not in PRIORITIES:
            fail(f"{it['id']}: priority {it['p']!r} is not one of {sorted(PRIORITIES)}")
        missing = [r for r in it.get("rel", []) if r not in known]
        if missing:
            fail(f"{it['id']}: related items {missing} do not exist")
    empty = [g for g in gids if not any(it["g"] == g for it in spec["items"])]
    if empty:
        fail(f"groups with no items: {empty}")


def js(value):
    # Safe inside <script>: no literal "</" can close the element early.
    return json.dumps(value, ensure_ascii=False, indent=1).replace("</", "<\\/")


def main():
    if len(sys.argv) != 3:
        fail("usage: build_review_page.py SPEC.json OUT.html")
    spec = json.loads(Path(sys.argv[1]).read_text())
    check(spec)
    page = TEMPLATE.read_text()
    subs = {
        "__TITLE__": html.escape(spec["title"]),
        "__EYEBROW__": html.escape(spec["eyebrow"]),
        "__LEDE__": html.escape(spec["lede"]),
        "__PLAN_BLURB__": html.escape(spec.get("plan_blurb") or DEFAULT_PLAN),
        "__GROUPS__": js(spec["groups"]),
        "__ITEMS__": js(spec["items"]),
    }
    for key, val in subs.items():
        if key not in page:
            fail(f"template has no {key} placeholder")
        page = page.replace(key, val)
    Path(sys.argv[2]).write_text(page)
    print(f"wrote {sys.argv[2]}: {len(spec['groups'])} groups, {len(spec['items'])} items")


if __name__ == "__main__":
    main()
