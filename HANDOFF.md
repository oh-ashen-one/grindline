# HANDOFF — grindline (ox-alpha builder loop)

## Read in order
1. scripts/ralph/OX-ALPHA.md (contract) 2. RULES.md 3. BRIEF.md
4. scripts/ralph/prd.json (stories+passes flags) 5. progress.txt patterns
6. LAST_VERIFY.txt (current failure if any)

## State: 11/15 passed. Remaining: US-Q04 (feedback atoms), US-Q05
(camera/input/mobile/occlusion), US-Q06 (perf/resilience), US-Q07 (ship).

## Loop procedure per story (proven)
1. python3 ../0x-alpha-gaming-loop/reference/ox/status.py   # pick NEXT
2. implement ONLY allowedFiles (≤2); bridge ops may grow in game/sim/sim_bridge.gd
3. bash ../0x-alpha-gaming-loop/reference/ox/verify_story.sh US-xxx
4. pass -> flip passes:true in prd.json -> git commit "feat: [ID] title"
5. fail -> read LAST_VERIFY.txt, fix, retry (2-fail rule -> restructure story)

## Key architecture facts
- Bridge (game/sim/sim_bridge.gd, extends SceneTree): JSON cmds -> ops.
  Ops live: noop reset start seekMs/soak(time_scale 20x if >2s) input assert
  probe screenshot setCamera setUi teleport expire_timer restart set_path dump.
  Probes: env_report theme_report adapter_report clip_report degrade_report
  approx_path lt_prev path_in_range_ms max_path_value_between_ms scalar_gte/lte
  note_path delta_from_note color_cluster font_region luma_contrast.
  Pixel probes need WINDOWED run: tests_staged/lib.sh run_sim_gfx.
- Cell scene node graph: SkaterCell(root=layout_builder.gd ParkBuilder) >
  LightRig, MenuWorld? no - cell has FloorBody/Sun/CamRig/Skater(>
  Shape,Visual(glb),AirState,GrindState)/RailBody(group grind, meta
  rail_axis/top_y/rail_len)/RunState. Physics ownership: locomotion(horizontal
  +stick only when vy<=0), air_state(vy impulse after 40ms anticipation),
  grind_state(axis lock + balance value drift/correction), run_state(timer/
  score/combo/multiplier, watches AirState.airborne falling edge).
- main.tscn: app_flow.gd(phase machine) + RunFlow(run_flow.gd mounts/
  restarts skater_cell as RunInstance child) + TitleLayer UI + MenuWorld
  diorama (sky env, sun, floor, title skater+board, MenuCam).
- Registry: assets/asset-manifest.json (108 entries, sha256-pinned,
  importScale on characters). ParkBuilder hides ids via ADAPTER_HIDE env
  (comma list) -> gray hulls + degraded=true. NEVER block play on missing.
- Pixel truth: ACES tonemap shifts colors; probes calibrated to measured
  frames (QUALITY-LEDGER F-003). Title diorama gives font/sky clusters.

## Remaining work sketches
- Q04: beats table in contract already defines windows; implement
  trick_feedback.gd (popup queue, hitstop hook, dust/spark bursts via
  GPUParticles3D one_shot pools sized by contract poolBudgets) +
  sparks_pool.gd; bridge "beat" op replays scripted input and samples
  channels; assert within-window flags.
- Q05: follow_cam.gd spring/fov-kick/trauma per BRIEF constants;
  input_router.gd maps actions; touch overlay Control nodes 96px targets;
  occlusion ray from cam to skater -> wall-hug clamp 2.6m.
- Q06: budget_governor.gd degrade ladder levels; metrics_reporter.gd p95
  frame/draw calls/objects/particles over soak; worst_scene mode adds AI
  skater clones + max particles.
- Q07: tools/export_macos.sh (godot --headless --export-release macOS);
  PLAYTEST-CHECKLIST.md (law 12 first-click); regenerate all evidence;
  ATTRIBUTION complete; tag grindline-v1.

## Warnings
- Do NOT relaunch cook_forever tmux (competing builders).
- No LM Studio/clipfarm. tests_staged/* are manager-owned specs - never edit
  to make code pass; restructure the STORY instead (law 14).
- Godot traps: see scripts/ralph/GODOT_API.md; SceneTree script has NO
  get_tree(); find_child cannot return self; instanced GLB children need
  owned=false searches; queue_free is deferred.
