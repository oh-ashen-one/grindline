# GRINDLINE

THPS-style arcade skate game — Godot 4.7, macOS, built by ox-alpha in
autonomous loops. Playable: menu, push/carve/ollie/grind, dismount (F),
board-carry idle, city skyline, golden-hour grade.

## Resume work (fresh session)
Read **MEGA-PROMPT.md** — it is the full handoff: visual-overhaul targets
(THPS 1+2 PS5 reference), every open issue with root causes, the hard-won
technical trap list, and the verify loop. Then:

    python3 ../0x-alpha-gaming-loop/reference/ox/status.py   # story board
    bash ../0x-alpha-gaming-loop/reference/ox/verify_story.sh US-xxx

## Run it
    godot --path .          # W push, A/D steer, Space ollie, F dismount

## State snapshot
- 15/15 core stories + US-107 menu-flow green; visual overhaul in progress
- Open regressions (debug plans in scripts/ralph/progress.txt): ollie apex,
  grind latch vs new trimesh bodies
- Open visual queue: hero resculpt (tall/skinny PS1 vibe), park density,
  window-texture verification on skyline towers
- Judge is mechanical: tests_staged/*.sh — keep them green, never edit a
  test to pass
