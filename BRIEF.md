# GRINDLINE — Design Bible

**One-line vision:** a PS2-era Tony Hawk homage — chunky low-poly skater in a
gritty concrete playground, huge combo numbers popping off the screen, punk
energy, every trick on a six-button controller.

This is an ORIGINAL homage. No THPS names, logos, characters, or audio.
The vibe is the steal: low-poly, flat colors, sunset fog, skate-punk HUD.

## Art direction (PS2 / early-2000s low-poly)

- **Geometry**: visibly faceted low-poly. Props 100–1500 tris. Chunky shapes,
  no bevels, no PBR, no normal maps, no SSAO, no glow.
- **Materials**: one shared colormap texture per kit (Kenney mini-skate style),
  flat albedo colors elsewhere. `roughness=1.0`, `metallic=0`, no specular pop.
- **Palette** (the whole game lives in these):
  - concrete gray `#9A9A94` / dark asphalt `#5C5C58`
  - safety yellow `#E8C547` (curbs, line paint, hazard stripes)
  - spray orange `#E8783C` and spray teal `#3FA7A0` (graffiti accents, UI)
  - sky: sunset gradient apricot `#F2B279` → dusty rose `#C96B6B` → dusk blue `#4A4E69`
  - fog color `#C98D6B`, density tuned so the far end of a map melts into sunset
- **Lighting**: one DirectionalLight (warm, ~45°, shadows on), ambient from sky
  gradient. No realtime GI anything.
- **Characters**: mini-skate boy/girl base; skins = palette swaps on the
  colormap regions (shirt/pants/board/hat). Chibi proportions are correct —
  do not "fix" them toward realism.

## Feel table (constants are law — tune here, not ad hoc)

| Constant | Value |
|---|---|
| push accel | 6.0 m/s² |
| max flat speed | 11.0 m/s |
| tuck max speed | 14.0 m/s |
| turn rate @ speed | 2.4 rad/s (scaled down at high speed to 1.6) |
| friction (rolling) | 0.35 m/s² |
| brake decel | 12.0 m/s² |
| ollie impulse | 5.2 m/s (board stat multiplies) |
| ollie coyote time | 0.12 s |
| landing angle tolerance | 42° from upright |
| grind snap radius | 1.1 m |
| grind speed | entry speed × 1.05, min 6 m/s |
| manual balance decay | 0.55/s, input corrects ±1.8/s |
| combo window | until clean landing or bail |
| multiplier cap | ×20 |
| bail lockout | 1.1 s |

## Trick list (launch set)

Ollie, Kickflip, Heelflip, Pop Shuvit, Frontside 180, Backside 180,
360 Flip, Impossible, Nose Grab, Tail Grab, Melon, Indy, Manual, Nose Manual,
50-50 Grind, Boardslide, Lipslide, 5-0 Grind, Nosegrind, Crooked Grind.

## Modes

1. **FREE SKATE** — no timer, roam, session score resets on map change.
2. **SCORE ATTACK** — 120 s, banked score = final score, rank D/C/B/A/S by thresholds per map.
3. **TRICK LIST** — land the listed 10 tricks anywhere in the map; checklist persists.
4. **CAREER** — per-map objective sets; completing objectives unlocks boards + skins + maps.

## Content

- **Maps (3)**: WAREHOUSE (indoor wood ramps, rails, boxes), PLAZA (concrete
  stairs, hubbas, benches, fountain), THE BOWL (bowl + half-pipe air lines).
- **Boards (6)**: each = deck color scheme + stats {ollie, flipSpeed, grindSpeed}
  within ±15% of neutral. Stats MUST measurably change physics.
- **Skins (6)**: palette swaps, 2 unlocked from start, rest via career.

## Audio direction

- Rolling loop (concrete noise), pitch 0.8→1.3 mapped to speed.
- Ollie pop (short knock), grind scrape loop, land thud, bail crash, UI clicks,
  score chime rising with multiplier tier.
- Music: lo-fi punk/skate-rock loops, one per map + menu track. Guitar-forward,
  140–170 BPM feel. CC0/public-domain only.

## HUD / UI (THPS-homage, original skin)

- Score: HUGE heavy-italic numerals top-left, cream white with black outline.
- Combo callout center-bottom: "KICKFLIP + HEELFLIP + GRIND … ×6" in spray
  orange, slight rotation wobble on add.
- Timer top-center; balance meters as angled bars under player when active.
- Trick-list checklist panel right side in TRICK LIST mode.
- Menus: big skewed slab panels, safety-yellow highlights on dark asphalt,
  ALL-CAPS condensed type, hard drop shadows (no blur), pulsing "PRESS ANY KEY".
- Font: a free condensed display face (e.g. Bungee/Anton class) — staged CC0/OFL.

## What NOT to do (slop list)

- No realistic PBR shading, no bloom/HDR/glow, no glassmorphism, no rounded-corner
  pastel mobile UI, no Inter/Roboto, no purple gradients.
- No photoreal skater, no motion-capture smoothness — snappy 12–15 keyframe poses OK.
- No empty maps: every map has ≥6 grindable rails/ledges and ≥3 launch ramps.
- No silent grinding, no floaty jumps without squash-and-stretch landings.
