#!/usr/bin/env python3
"""status.py — story board for ox-alpha loops (no LLM, no API).

Reads scripts/ralph/prd.json from the project root (or --prd path) and prints:
  - per-story state table
  - the NEXT story to build (same selection rule as qwen_iteration.py:
    lowest priority among unpassed, unblocked, dependency-satisfied stories)

Exit codes: 0 = next story available, 42 = all stories passed,
43 = remaining stories blocked/dependency-starved.
"""
import argparse
import json
import sys


def load(path):
    with open(path) as f:
        prd = json.load(f)
    return {s["id"]: s for s in prd["userStories"]}, prd


def eligible(story, stories):
    if story.get("passes") or story.get("blocked"):
        return False
    deps = story.get("blockedBy", [])
    return all(stories.get(d, {}).get("passes") for d in deps)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--prd", default="scripts/ralph/prd.json")
    args = ap.parse_args()

    try:
        stories, prd = load(args.prd)
    except FileNotFoundError:
        sys.exit(f"no prd at {args.prd}")

    rows = []
    for s in sorted(prd["userStories"], key=lambda x: (x.get("priority", 999), x["id"])):
        if s.get("passes"):
            state = "PASS"
        elif s.get("blocked"):
            state = "BLOCKED"
        elif not eligible(s, stories):
            state = "WAITING"
        else:
            state = "READY"
        rows.append((state, s["id"], s.get("priority"), s.get("title", "")))

    width = max(len(r[1]) for r in rows) if rows else 6
    for state, sid, prio, title in rows:
        print(f"{state:<8} {sid:<{width}} p{prio:<4} {title}")

    passed = sum(1 for r in rows if r[0] == "PASS")
    print(f"\n{passed}/{len(rows)} passed")

    ready = [r for r in rows if r[0] == "READY"]
    if ready:
        nxt = ready[0]
        story = stories[nxt[1]]
        print(f"\nNEXT: {nxt[1]} — {nxt[3]}")
        print(f"  verify: {story.get('verify', 'MISSING')}")
        allowed = story.get("allowedFiles", [])
        print(f"  allowedFiles: {', '.join(allowed) if allowed else '(unrestricted — tighten this story)'}")
        sys.exit(0)
    if passed == len(rows):
        print("\nALL STORIES PASSED")
        sys.exit(42)
    print("\nNO ELIGIBLE STORY — everything left is blocked or waiting on deps")
    sys.exit(43)


if __name__ == "__main__":
    main()
