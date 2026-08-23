# PLAYTEST-CHECKLIST — GRINDLINE (Hari, law 12)

The gates are green; now prove it with your hands. "Works" is defined by
your first clicks, not our harness. ~5 minutes.

## Setup
- Open `build/grindline.app` (or run `godot --path .` from the repo).

## First click (the real final gate)
1. Launch → does the title appear with GRINDLINE wordmark and dusk park behind it?
2. Press any key/click → does something obvious happen (menu/phase change)?
3. Start a run → within 2 seconds, is holding W visibly pushing the skater?

## Controls table (must be discoverable on screen)
| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Push / steer | W / A-D | RT or A / left stick | left stick zone |
| Ollie | Space | A | right tap |
| Flip tricks | J | X | swipe up |
| Grabs | K | Y | swipe down |
| Manuals | L | B | hold both |
| Crouch/pump | Shift | LB/RB? | n/a |
| Pause | Esc | Start | pause chip |

## 2-minute run feel
4. Does the follow cam read well at speed (FOV kick, no wall clipping)?
5. Ollie onto the flat rail → does the grind latch feel forgiving?
6. Balance meter: can you hold a 50-50 for 3+ seconds with stick correction?
7. Bail: does the tumble + combo-lost banner read instantly?
8. Timer expiry: results screen appears; restart returns you cleanly?
9. Score banking: combo lands → score increases; bail mid-combo → multiplier resets.

## Sound & presentation
10. Music loop playing during runs? UI stingers on menu select/back?
11. Any programmer-art primitives anywhere? (There should be zero.)

## Known limitations (honest list)
- Headless-verified performance = logic-side truth; GPU feel needs this playtest.
- Touch portrait verified via viewport emulation only.
- One music track; more land in a content pass if wanted.

## Verdict
[ ] PASS — ship it        [ ] FAIL — notes below

Notes:
