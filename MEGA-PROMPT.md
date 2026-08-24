# GRINDLINE VISUAL OVERHAUL — MEGA PROMPT (feed this to a fresh session)

You are taking over GRINDLINE, a THPS-style skate game at `~/grindline`
(Godot 4.7, macOS). It plays: menu works, push/steer/ollie/grind physics
exist, F dismounts. The mechanics are done. **The look is not.** The player
says it "looks like ass" compared to reference footage. Your job is a
visual overhaul, 100x, to match THPS 1+2 (PS5) gameplay footage.

## THE REFERENCE (what "good" means)
THPS 1+2 PS5 4K gameplay (FA GAMEZ on YouTube, video id SeYSVq8Q_qA):
- Real-world street plaza: big concrete slabs with expansion joints, wet-ish
  variation, tram tracks, curbs, drains, planters, street lamps, palm trees,
  buildings with ARCHED WINDOWS and cornices, a "SAN FRANCISCO" sign
- Golden-hour haze: low warm sun, long soft shadows, atmospheric depth,
  desaturated warm grade — NOT flat cream fog
- Skater: slim realistic teen, baggy pants, tee, cap; rides SIDEWAYS with
  real push cycles (one foot pushes, one on board)
- Reference frames are staged at `quality/references/ref-thps-stance.png`
  and `ref-thps-plaza.png` — LOOK AT THEM FIRST with the Read tool.
- A PS1-era THPS image the owner also likes is described as: TALL SKINNY
  lanky skater, baggy pants, low-poly. Current hero is too short and stocky
  with a chibi head.

## CURRENT VISUAL FAILURES (player-verified, fix ALL)
1. **Floor lighting "seizure"**: shimmering/glitchy floor. Suspected causes:
   coplanar surfaces (check every floor/tile/pad for z-fighting), shadow-map
   crawl on the 48m plane from the sun (raise `shadow_blur`, set
   `shadow_max_distance`, consider `position_shadow` or a smaller PSSM split),
   and the normal map on the floor material shimmering at distance (try
   removing the normal map from the floor, keep albedo).
2. **Buildings look like rocks**: `scripts/park/layout_builder.gd` overrides
   materials for ids starting with "park-" — `park-skyline` is excluded now,
   but VERIFY in a screenshot that the window-lit emissive texture actually
   renders on every tower. If the window texture is not visible, the skyline
   GLB material export failed — rebuild it
   (`/tmp/grindline-assets/make_skyline.py` may be gone; rewrite: dark
   facade base color + emissive window-grid texture, 28 towers, ring
   55-130m, seeded, plus dark 900m ground pad at y=-0.6 and an emissive sun
   disc at (-260,-420,46) radius 22).
3. **Hero proportions**: still too short/stocky/chibi-headed. Target: tall
   (1.9m), skinny, small head, long thin limbs, baggy pants. The mesh-resculpt
   attempt (`/tmp/grindline-assets/reshape.py`) distorted the arms and was
   reverted — redo it CAREFULLY on
   `assets/models/characters/skater_slim_boy.glb` with per-bone-group
   weighted vertex blending (pivot = that bone's head_local, blend all group
   weights, never hard-dominant), then RENDER-CHECK in Blender from 3 angles
   before shipping. If vertex surgery keeps failing, alternative: scale
   bones in the armature EDIT mode (rest lengths) so the skin follows.
4. **Ride animation**: hero plays Run/Walk while riding — legs pump through
   the board. A proper sideways `ride` stance clip EXISTS in the hero GLB
   (authored, world-space delta method, verified in Blender render
   `/tmp/grindline-assets/ride_final.png` if it still exists). Wire riding
   to ALWAYS play `ride` (never Run/Walk) except during the push cycle.
5. **Push cycle**: a `push` clip exists (back leg lifts, reaches, kicks).
   Verify it plays while W is held and looks like the reference push
   (body over front foot, back leg sweeping). Exaggerate in Blender if subtle
   (the authoring script pattern is in this file's history — world-space
   rest-relative quaternion deltas, REPLACE bone rotation, never compound).
6. **Park density/quality**: the park is sparse white/gray. Add: colored
   cone variety, planters, benches, lamps (Kenney factory kit pieces already
   in `assets/props/`), quarter-pipe coping colors, painted grind lines,
   wall murals (simple colored quads), ramps with painted edges. Reference
   has ELEMENT-branded ramps — we CANNOT copy brands; use original paint.

## CRITICAL TECHNICAL TRAPS (learned in blood — do not re-learn)
- New GLB files are invisible to `ResourceLoader.exists()` until
  `godot --headless --path . --import` runs. ALWAYS import before testing.
- Blender 5.2 slotted actions: `action.fcurves` does not exist — iterate
  `action.layers[].strips[].channelbags[].fcurves`. Assigning an action to a
  rig requires ALSO setting `animation_data.action_slot = act.slots[0]` or
  nothing animates.
- Authoring poses: REPLACE the bone quaternion with
  `rest_q⁻¹ · world_R · rest_q` (rest-relative world delta). NEVER multiply
  onto the current posed rotation (compounds → 180° flips). Arms swing on
  the local Y axis, legs on X. Verify with a Blender RENDER from the side
  before exporting — the camera in render scripts must be aimed with a
  TRACK_TO constraint at (0,0,~1.0) or you render nothing.
- `Vector + tuple` and `Euler + Euler` raise in Blender Python; wrap tuples
  in Vector/Euler. `round(x, 2)` is GDScript-valid but `round(x,2)` with 2
  args fails in Blender-python contexts differently — check per file.
- GDScript 5.2-style strictness in this project: no inferred-from-Variant
  `:=`, `String.ends_with()` (not endswith), `strip_edges()` (not strip).
- Godot: `create_trimesh_collision()` returns void (adds a StaticBody child).
  `get_tree()` does not exist on SceneTree scripts. `find_child` cannot
  return the scene root itself. `queue_free` is deferred. New GLBs need
  import before `load()` works.
- The sim bridge is `game/sim/sim_bridge.gd` (SceneTree script):
  `godot --path . --script res://game/sim/sim_bridge.gd -- --cmds=x.json
  --shots=dir` (windowed for pixel probes; add `--headless` for logic-only).
  Ops: start/seekMs/soak/input/assert/probe/screenshot/teleport/beat/restart/
  expire_timer/dump. Pixel probes (font_region, color_cluster, luma_contrast,
  ui_targets, hud_safe_area, node_visible, ui_min_height, node_exists) need
  the windowed run.

## HOW TO WORK (the loop that got us here)
1. Pick ONE visual failure. Fix it. Capture a windowed screenshot via the
   sim bridge and LOOK AT IT with the Read tool. Iterate until it matches
   the reference frames. Only then move to the next failure.
2. After every green change: `git add -A && git commit -m "feat: ..."`.
3. Do not touch: `tests_staged/*` (manager-owned specs), LM Studio, clipfarm,
   any process you did not start. Other godot/opencode sessions may exist.
4. Known physics regressions to fix AFTER the look (debug plans in
   `scripts/ralph/progress.txt`): ollie apex collapsed to 0.12m (spec
   1.25-1.56; vy=7.2 gets eaten — trace per-frame velocity after
   air_state._launch), grind latch misses the new trimesh rail bodies
   (world-space top_y meta fallback is wrong).
5. The judge is mechanical: `bash tests_staged/<test>.sh` per story, full
   list in `scripts/ralph/prd.json`. Keep them green. `progress.txt` and
   this file are your memory; append what you learn.

## DEFINITION OF DONE FOR THIS OVERHAUL
Side-by-side: a fresh `shots/look_traversal.png` next to
`quality/references/ref-thps-plaza.png` shares the same lighting mood,
material richness, prop density, and skyline believability — and the hero
is tall/skinny, riding sideways with the board, pushing like the reference.
The player's bar is the video. Meet it, then exceed it with density.
