# HANDOFF — grindline (ox-alpha builder loop)

## Read in order
1. scripts/ralph/OX-ALPHA.md (contract) 2. RULES.md 3. BRIEF.md
4. scripts/ralph/prd.json (stories+passes) 5. progress.txt patterns
6. LAST_VERIFY.txt (current failure if any)

## State
- Phase 1 DONE (vertical slice). Next: phase 2 look lock.
- Author US-2xx mini-stories WITH their tests_staged specs first (law 15),
  then implement, verify_story.sh each, flip passes:true, commit.
- Q02 requires WINDOWED godot runs for pixel probes (headless reports
  unavailable_headless honestly). Use: godot --path . --script ... without
  --headless; png_check validates 1280x720.

## Commands
- pick: python3 ../0x-alpha-gaming-loop/reference/ox/status.py
- judge: bash ../0x-alpha-gaming-loop/reference/ox/verify_story.sh US-xxx
- gates: bash scripts/ralph/preflight_assets.sh . ;
  python3 scripts/ralph/quality/preflight_quality.py --root .
- commit format: feat: [US-xxx] title

## Warnings
- Do NOT relaunch cook_forever.sh tmux (spawns competing builders).
- Do not touch LM Studio/clipfarm. Assets are read-only for gameplay code.
