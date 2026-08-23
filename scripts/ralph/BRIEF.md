# grindline — production brief

## Product fantasy

You are a street skater alone in a dusk-lit industrial plaza called THE LEDGEWORKS.
Two minutes on the clock. You push hard, pop ollies over loading docks, lock into
50-50s on handrails and balance there while the multiplier climbs, flip the board
off kickers, manual across plank platforms to link lines. Every landed trick feeds
the combo; one bad landing wipes it all. The fantasy is the THPS2 loop: loud,
fast, score-chasing mastery of one dense park you learn by heart.

The 60-second demo: push twice, ollie the funbox, land in a 50-50 down the flat
rail, balance meter trembling, hop off into a manual, revert, roll away as
SPARKS +850 x6 fills the screen and the crowd-hype sting hits.
Signature image: silhouette of the skater grinding the high rail against a burnt-
orange dusk sky between warehouse walls. Signature sound: the metal scrape that
keeps ringing while the balance holds.

Original title, original park, original skater names. THPS mechanics are fair
game; no Tony Hawk, Activision, pro-skater likenesses, level rips or soundtrack.

## Product shell

- boot: engine boots straight into the title state; branded GRINDLINE card,
  animated progress bar fed by real import steps; 10 s per-asset timeout drops
  to manifest fallbacks and never blocks.
- menu: PLAY (skater select), SETTINGS, HOW TO PLAY, QUIT. Keyboard, gamepad and
  touch navigable; focus ring always visible; select_004/back_004 stingers.
- play: full run loop below. Pause via Esc/Start at any moment.
- pause: overlay panel, RESUME / RESTART RUN / SETTINGS / QUIT TO MENU. Timer
  and physics freeze; music ducks to minus 12 dB.
- failure: run timer expiry ends the run; bail never ends the run, only the combo.
- restart: instant re-seed from the same park layout, scores cleared, clock reset.
- settings: music volume, SFX volume, camera nudge invert; sliders 0..100;
  persist immediately to user://grindline_save.json.
- persistence: top-10 high-score table (name, score, best combo), selected
  skater, settings. Corrupt file quarantined as grindline_save.corrupt then
  defaults recreated. No gameplay blocking on disk I/O.

## Reference contract

- reference-01 factory-kit mood image: steal the prop palette (rust orange,
  safety yellow, steel gray) and density rhythm for THE LEDGEWORKS dressing;
  measure color separation in the look-lock frame; evidence traversal.
  Never copy the preview layout as a map.
- reference-02 ambientCG Concrete034 preview: surface truth bar for skate
  surfaces — value range, stain density; evidence title backdrop ground.
- reference-03 mini-skate pack preview: silhouette language and material
  separation for ramp/rail geometry; evidence primary-action framing.
All three staged and SHA-pinned in quality/references/; mechanisms learned,
never layouts copied.

## Visual system

Palette roles (sRGB hex, exact floats live in game/scripts/ui/theme.gd):
- sky dusk gradient: #2a1a33 to #e8683a (HDRI industrial_sunset_puresky drives
  the sky itself; UI gradient only echoes it)
- concrete floor: tex-concrete tinted #9b978f
- asphalt apron: tex-asphalt tinted #565656
- safety yellow accents (ledges, kicker tops): #f0a51e
- rust/rusted metal props: #b04a1f
- steel rails/coping: #cfd2d6 metallic
- wood planks/platforms: #7a5230
- HUD ink: near-black #14100e on warm paper #f5ead8 chips; combo numbers white
  with 3 px hard offset shadow in #14100e
Material thesis: flat-shaded low-poly meshes, colormap-style separation
(Kenney kit) plus three PBR hero surfaces (concrete, asphalt, brick) so the
world reads toy-clean but grounded. Lighting: DirectionalLight key at sunset
angle (pitch minus 22 deg), energy 1.2, warm #ffd9a8; sky HDRI fill; subtle
fog #d98d55 from 45 m to 120 m for depth stacking. No bloom, no glow.
Silhouette rules: skater reads against sky when airborne (dark ink outline via
rim light energy 0.35 cool #ffb27a); obstacles keep 2-value read at 20 m.
Environment density: large silhouettes (warehouse walls, machines, hoppers)
punctuated with small clutter (cones, boxes, pallets); never uniform grids.
UI type: Bebas Neue everywhere, ALL-CAPS, chunky skewed chips, hard shadows,
no gradients, no rounded glass. Redundant cues: score changes animate numerals
AND flash the chip border; balance meter drains color AND wobbles an arrow.
Forbidden defaults: Godot gray UI, purple gradients, rounded glass panels,
Comic-style outlines on HUD.

## Scale and camera

- metres-per-unit: Godot default, 1 unit = 1 m.
- skater hero height 1.75 m (Kenney chibi imported at scale 2.263).
- obstacle sizes: ledges 0.5 m, funbox top 1.0 m, quarter pipe deck 2.95 m,
  high rail 0.85 m, low rail 0.55 m.
- follow cam: distance 5.2 m, height 2.1 m, FOV base 62 deg.
- damping: position lerp 8.0/s exponential; rotation follows velocity heading
  with 6.0/s damping.
- look-ahead: 2.2 m along horizontal velocity.
- speed response: FOV kicks +10 deg at 10 m/s, +16 deg at 13 m/s (lerped 3/s).
- trauma shake: add trauma 0.6 on bail, 0.15 on hard landing; decay 1.4/s;
  offset = trauma^2 * 0.4 m noise.
- manual nudge: right stick / arrow keys offset camera yaw up to 25 deg,
  spring-back 2/s when released; invert setting honored.
- aspect targets: 16:9 primary 1280x720; portrait 390x844 verified for HUD
  safe areas; occlusion rule: if a warehouse wall blocks the skater for more
  than 1.5 s the camera pulls to wall-hug offset (min distance 2.6 m).

## Feel constants

All constants live in game/scripts/config.gd as named consts; tests assert
the exact values below.
- input latency budget: under 100 ms motion-to-photon; steer sampled every
  physics tick (60 Hz).
- push acceleration: 6.5 m/s^2 while pushing anim plays; max push speed 11 m/s.
- downhill gravity assist: 4.0 m/s^2 along slope when crouch-pumping banks.
- base gravity: 18.0 m/s^2 arcade-tuned (not 9.81).
- ollie impulse: 7.2 m/s vertical; crouched ollie 8.4 m/s.
- air control: steer torque 3.5 rad/s; trick window stays open until landing.
- grind latch: capture radius 0.35 m below feet, lateral snap 0.15 m max.
- balance meter: starts 0.5 center; decay rate 0.22/s scaled by rail steepness;
  input correction 0.35/s per stick unit; fail outside 0.06..0.94.
- manual balance: same meter, tighter fail band 0.10..0.90.
- reverts: 300 ms window after landing a quarter pipe to reverse stance and
  keep combo alive.
- bail recovery: control locked 900 ms, respawn at last safe ground point.
- hitstop: 60 ms freeze on special-trick landings only.
- spawn/read windows: run timer 120.0 s; S-K-A-T-E letters awarded per
  objective; hidden stat points spin slowly in fixed spots.
- special meter: charges 100 pts per landed trick set, unlocks specials at
  100; specials are 2 named tricks (LEDGEWALKER, DUSK FLIP).

## Asset manifest contract

Law 16: every shipping asset is pinned in assets/asset-manifest.json with
license, sha256, measured size and budgets; human view in ASSET-MANIFEST.md.
Characters: Kenney Mini Skate boy/girl GLBs (29 clips each incl. skate set),
imported at 2.263x; roster = 4 selectable skaters built from the two rigs x
two palette variants sharing one deep animation rig; stats differ per skater
(push accel, balance stability, air control). Board: Kenney skateboard GLB.
Park: authored Blender street pieces (quarter pipe, bank, funbox, ledge, rail,
kicker, spine, warehouse wall) plus Kenney Mini Skate bowls/half-pipe/floors/
obstacles/steps dressed with Kenney Factory props. Surfaces: five ambientCG
PBR sets. Sky: Poly Haven industrial_sunset_puresky 1k HDR. Audio: Kenney
impact/interface/jingles plus Zander Noriega "Fight Them Until We Can't"
(CC-BY-3.0, attribution recorded) as the run music loop. Font: Bebas Neue OFL.
Fallbacks per manifest entry; missing media degrades, never halts.

## Action beat sheets

- ollie-beat (contract): anticipation 40 ms crouch pose sample, launch at t0,
  response 120 ms board snap under feet, settle 90 ms. Channels: state
  (grounded false), motion (vy 7.2), visual (board snap + dust puff 8
  particles), audio (ui-click layer plus soft thud sfx-bail-thud at 30 percent
  volume), HUD (trick name popup queued).
- grind-beat: contact 60 ms spark burst (16 sparks), scrape loop starts,
  balance meter appears after 200 ms, settle 150 ms meter fade-in complete.
  State: grind id, rail axis locked, multiplier pending.
- bail-beat: contact 80 ms impact freeze frame, tumble clip 500 ms, camera
  trauma 0.6, HUD combo-lost banner 320 ms slide-out, multiplier reset.

## Content grammar

Reusable pieces: floor tiles (concrete/asphalt/wood), transition pieces
(quarter pipe, half-pipe, bowls), street pieces (banks, funbox, spine,
ledges, steps, platforms), grind pieces (3 rail heights, curve, slope),
clutter props (crates, cones, pallets, machines, hoppers, pipes).
Legal combinations: any grind piece may butt against any bank/floor; quarter
pipes face inward toward the plaza; rails always parallel or perpendicular
to primary axes. Forbidden patterns: floating props without ground contact,
grind lines ending inside walls, transitions steeper than 90 degrees,
props blocking spawn or respawn points.
Difficulty curve: central plaza flat-line tricks, mid ring ledges and low
rails, outer ring high rail, bowl and quarter pipes; deterministic seeds
(seed 3 canonical) fix prop positions and AI skater paths.
AI fairness: 2 AI skaters ride scripted loops, never interfere physically
with the player line, exist for life and worst-case perf states.

## Performance and resilience

Target tier (contract performanceTiers.target): Mac Studio Apple Silicon,
1280x720, worst scene = full park, all props, 2 AI skaters, grind particles,
music plus SFX: p95 frame under 16.9 ms over 30 s, draw calls 220 max,
active objects 900, particles 400, pixel ratio 1.0, resident assets 350 MB.
Preserve: input feel, combo timer accuracy, balance readability.
Degradation order: particle rates halve, AI drop to 1, shadow resolution
halves, far props cull at 35 m. Pools: sparks 160, dust 80, score popups 24,
AI skaters 2; pool exhaustion recycles oldest, never allocates at runtime.
Missing media: per-manifest fallbacks (gray hull, flat color, silence);
degraded-mode wrench icon shows in HUD corner. Recovery: any script error in
a run dumps LAST_VERIFY context and returns to menu without crashing.

## Input and accessibility matrix

Keyboard-first (1280x720): WASD/arrows steer and push, Space ollie, J flips,
K grabs, L manuals/grind modifiers, Shift crouch/pump/pump-banks, Esc pause.
First action: hold W to push within 2 s of run start; prompt chip bottom-left
uses Kenney keyboard glyphs at 48 px minimum.
Gamepad: left stick steer, RT or A push/ollie family, X flips, Y grabs,
B manuals, LB grind modifier, Start pause; glyph prompts 64 px; first action
tilt stick or press A.
Touch portrait (390x844): left virtual stick zone, right tap ollie, swipe
modifiers, pause button top-right within safe insets; targets 96 px; probe
asserts no occluded critical HUD and all targets above minimum size.
Redundant cues: every audio cue has visual twin (sparks, banners, meters);
every timed window also readable from animation state, not sound alone.
Occlusion case: wall-hug camera keeps skater visible (contract scale section).

## Canonical evidence set

Deterministic captures driven by the sim bridge (seed, preset camera, exact
viewport, JSON assertions printed before quit):
- title (seed 1): menu after boot; wordmark, press-start prompt, skater idle.
- traversal (seed 3): push across plaza at 8 m/s past funbox; grounded delta
  under 0.05 m, speed readout matches sim truth, no pop-in within 40 m.
- primary-action (seed 3): ollie onto high rail, 50-50 held 1.0 s; grind state
  true, balance meter visible, sparks active, combo incremented.
- failure (seed 3): failed landing bail mid-combo; tumble clip, banner,
  multiplier back to 1.
- mobile (seed 3): traversal state at 390x844 with touch overlay; safe areas,
  target sizes, zero occlusion of critical widgets.
- worst-performance (seed 7): full-dress park, both AI skaters, particles;
  p95 and draw-call budgets printed from metrics().
- ship-title-flow (seed 1): boot-menu-run-pause-restart chain under 3 s per
  transition, settings persist.

## Structure

Godot 4 project rooted at repo root (project.godot beside this file's repo).
Modules stay small: scripts/config.gd (all feel constants), scripts/sim/
(ground probe truth), scripts/skater/ (state machine, tricks), scripts/run/
(run_state autoload model), scripts/park/ (layout builder from data),
scripts/ui/ (HUD theme and widgets), sim/sim_bridge.tscn (QA transport).
Each story emits at most two source files; asset adapters, gameplay,
effects, camera/input, UI and orchestration stay separate files.

## Honest limitations

Build proof: godot --headless --import parse gate runs on macOS here.
Runtime proof: headless sim bridge executes real gameplay logic and renders
offscreen screenshots on this Studio; what it proves is logic, metrics and
framing, not final GPU thermals.
Unproven here: physical touch-device play (verified only via viewport
emulation), console gamepad rumble, online anything (none shipped).
Human-feel proof: law 12 playtest checklist for Hari at phase 7; camera feel
and difficulty tuning are judgment calls the harness cannot grade.
Long-run proof: 30 s worst-scene soak is asserted; overnight memory-leak
soak is not part of the gate.
