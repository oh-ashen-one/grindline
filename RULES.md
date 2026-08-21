# BUILDER RULES (GRINDLINE loop)

You are the builder agent for GRINDLINE. Each iteration you work ONE story
from scripts/ralph/prd.json. Memory between iterations is ONLY:
prd.json, progress.txt, git history, LAST_VERIFY.txt, BRIEF.md, this file.

## Hard rules

1. Write code ONLY inside `game/` and only in the story's `allowedFiles`.
   Never write to `tools/`, `scripts/`, `BRIEF.md`, `RULES.md`, `prd.json`,
   or any file with `test` in its path.
2. Acceptance tests are the spec. They live in `game/sim/tests/` and are
   manager-authored. NEVER edit, move, or "fix" a test to make it pass.
   If a test seems wrong, the story fails — say so in progress.txt.
3. All gameplay constants come from BRIEF.md's feel table. Put them in
   `game/scripts/config.gd` as named consts; never magic-number gameplay.
4. No placeholders: no TODO, no `pass  # later`, no empty bodies that a test
   could pass around. A trick that isn't implemented must not be listed.
5. Additive-only on shared modules (`config.gd`, autoloads): you may add;
   removing or renaming an existing public symbol breaks siblings and will
   be rejected by review gates.
6. Files stay under ~300 lines; split into a new file when growing past it.
7. GDScript 4.x syntax only (Godot 4.7). No @onready var typos, no Python-isms.
   Common traps: `class_name` once per file; signals connect via
   `signal_name.connect(callable)`; `move_and_slide()` takes no args;
   physics deltas from `get_physics_process_delta_time()`.
8. Every sim test scene prints measured numbers before quitting:
   `SIM RESULT {"pass": true, ...metrics}` then `get_tree().quit(0/1)`.
9. If LAST_VERIFY.txt exists, your FIRST job is fixing exactly that failure.
10. After finishing a story's files, echo the story's VERIFY line verbatim.

## Style

- Godot conventions: snake_case files, PascalCase classes, nodes renamed in
  scenes not code where possible.
- UI follows BRIEF.md HUD section — chunky, skewed, hard shadows, ALL-CAPS.
- Comments only where a constant's provenance matters ("brief: ollie impulse").
