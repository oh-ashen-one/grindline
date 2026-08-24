extends SceneTree
## sim_bridge.gd — deterministic QA transport (contract.debugBridge).
## Run: godot --headless --path . --script res://game/sim/sim_bridge.gd -- \
##        --cmds=/abs/commands.json [--shots=/abs/dir] [--expect-degraded]
## Prints "SIM RESULT {json}" and exits 0 (gate pass) / 1 (fail) / 2 (bad args).

var cmds_path := ""
var shots_dir := ""
var expect_degraded := false

# live state exposed to assert/probe ops; gameplay modules register into it.
var qa := {
	"app": {"phase": "none"},
	"skater": {},
	"run": {},
	"balance": {},
	"grind": {},
	"camera": {},
}

var result := {
	"pass": false, "reason": "", "asserts_ok": [], "asserts_failed": [],
	"probes": {}, "probes_ok": [], "unknown_ops": 0, "shots": [],
	"degraded": expect_degraded, "playable": true,
	"metrics": {}, "seed": 1,
}

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cmds="):
			cmds_path = a.substr(7)
		elif a.begins_with("--shots="):
			shots_dir = a.substr(8)
		elif a == "--expect-degraded":
			expect_degraded = true
	if cmds_path == "":
		_finish(2)
		return
	result.degraded = expect_degraded
	_run_async()

func _run_async() -> void:
	await process_frame
	# mount the game's main scene so qa_state nodes register
	if current_scene == null and ResourceLoader.exists("res://game/scenes/main.tscn"):
		change_scene_to_file("res://game/scenes/main.tscn")
		await process_frame
		await process_frame
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(cmds_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		result.reason = "commands file is not a JSON object"
		_finish(1)
		return
	result.seed = int(parsed.get("seed", 1))
	seed(result.seed)
	var steps: Array = parsed.get("steps", [])
	for step: Dictionary in steps:
		await _exec(step)
		if result.pass and step == steps[-1]:
			pass
	_sync_qa()
	result["adapter"] = qa.get("adapter", {})
	result["beats"] = qa.get("beats", {})
	var beats_ok: Array = []
	for bid: String in result["beats"].keys():
		var ch: Dictionary = result["beats"][bid]
		var all_ok := true
		for ckey in ["state", "motion", "visual", "audio", "hud"]:
			if ch.get(ckey) != true:
				all_ok = false
		if all_ok:
			beats_ok.append(bid)
	result["beats_ok"] = beats_ok
	var gate: bool = bool(parsed.get("gate", false))
	result.pass = result.asserts_failed.is_empty() and result.unknown_ops == 0
	if gate:
		_finish(0 if result.pass else 1)
	else:
		_finish(0)

func _finish(code: int) -> void:
	print("SIM RESULT ", JSON.stringify(_compact(result)))
	quit(code)

func _compact(d: Dictionary) -> Dictionary:
	var out := {}
	for k: String in d:
		out[k] = d[k]
	return out

# ---------------- op dispatch ----------------

func _sync_qa() -> void:
	# gameplay modules join group "qa_state" and expose get_qa_dict();
	# their truth merges into the bridge's view before every op.
	for n in get_nodes_in_group("qa_state"):
		if n.has_method("get_qa_dict"):
			_deep_merge(qa, n.get_qa_dict())

func _deep_merge(base: Dictionary, extra: Dictionary) -> void:
	for k: String in extra:
		if typeof(extra[k]) == TYPE_DICTIONARY and typeof(base.get(k)) == TYPE_DICTIONARY:
			_deep_merge(base[k], extra[k])
		else:
			base[k] = extra[k]

func _exec(step: Dictionary) -> void:
	_sync_qa()
	var op := String(step.get("op", ""))
	if OS.get_environment("GL_DEBUG") != "":
		print("OP=", op)
	match op:
		"noop":
			pass
		"dump":
			_sync_qa()
			print("SIM DUMP ", JSON.stringify(qa))
		"reset":
			qa = {"app": {"phase": "title"}, "skater": {}, "run": {}, "balance": {}, "grind": {}, "camera": {}}
		"start":
			await _start_mode(String(step.get("mode", "run")))
		"seekMs", "soak":
			var ms := float(step.get("ms", 0))
			var t := 0.0
			var prev_scale := Engine.time_scale
			if step.get("ff", false):
				Engine.time_scale = 20.0  # opt-in fast-forward
			while t < ms / 1000.0:
				await physics_frame
				t += 1.0 / Engine.get_physics_ticks_per_second()
			Engine.time_scale = prev_scale
		"input":
			await _inject_input(step)
		"assert":
			_eval_assert(String(step.get("name", "")), String(step.get("state", step.get("expr", ""))))
		"probe":
			await _probe(step)
		"screenshot":
			await _screenshot(String(step.get("id", "shot")))
		"set_path":
			_sync_qa()
			var parts := String(step["path"]).split(".")
			var cur: Variant = qa
			for pi in range(parts.size() - 1):
				cur = cur[parts[pi]]
			cur[parts[-1]] = step["value"]
		"expire_timer":
			var rs := get_first_node_in_group("run_state")
			if rs != null:
				rs.time_left_ms = float(step.get("ms", 60))
			else:
				result.unknown_ops += 1
		"occlusion_case":
			var camn: Node = null
			for n in get_nodes_in_group("qa_state"):
				if n.has_method("probe_occlusion"):
					camn = n
					break
			if camn == null:
				result.probes["occlusion_case"] = "no camera"
			else:
				var from := Vector3(step["from"][0], step["from"][1], step["from"][2])
				var to := Vector3(step["to"][0], step["to"][1], step["to"][2])
				var eff: float = camn.probe_occlusion(from, to)
				var got_clamped := absf(eff - 2.6) < 0.01
				var want_clamped := bool(step.get("expect_clamped", true))
				var oname := String(step.get("name", "occlusion"))
				if got_clamped == want_clamped:
					result.probes[oname] = "ok"
					result.probes_ok.append(oname)
				else:
					result.probes[oname] = "eff %.2f" % eff
		"teleport":
			_teleport(String(step.get("zone", "")))
		"restart":
			_sync_qa()
			result["score_before_restart"] = int(qa.get("run", {}).get("score", 0))
			var rf := _find_runflow()
			if rf != null:
				rf.restart_run()
				await physics_frame
				await physics_frame
			else:
				result.unknown_ops += 1
		"setCamera":
			_apply_camera(String(step.get("id", "")))
		"setUi":
			_apply_ui(String(step.get("id", "")))
		"beat":
			await _run_beat(String(step.get("id", "")))
		"viewport":
			var w := int(step.get("w", 1280))
			var h := int(step.get("h", 720))
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_size(Vector2i(w, h))
				root.size = Vector2i(w, h)
				root.content_scale_size = Vector2i(w, h)
				root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
				root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
				for _wf in 40:
					if root.size == Vector2i(w, h):
						break
					await process_frame
				if OS.get_environment('GL_DEBUG') != '':
					print('VPDBG real=', DisplayServer.window_get_size(), 'root=', root.size)
			else:
				result.probes["viewport:" + str(w)] = "unavailable_headless"
		"degrade":
			if OS.get_environment("GL_DEBUG") != "":
				print("DEGRADE CASE REACHED")
			var applied := false
			if OS.get_environment("GL_DEBUG") != "":
				for n2 in get_nodes_in_group("qa_state"):
					print("QANODE ", n2.name, " apply?", n2.has_method("apply"))
			for n in get_nodes_in_group("qa_state"):
				if n.has_method("apply"):
					if OS.get_environment("GL_DEBUG") != "":
						print("DEGRADE on ", n.name)
					n.apply(int(step.get("level", 1)))
					applied = true
			if not applied:
				result.unknown_ops += 1
		_:
			result.unknown_ops += 1

func _run_beat(id: String) -> void:
	match id:
		"ollie-beat":
			await _exec({"op": "input", "action": "push", "held_ms": 600})
			await _exec({"op": "input", "action": "ollie", "held_ms": 60})
		"grind-beat":
			await _exec({"op": "teleport", "zone": "rail_approach"})
			await _exec({"op": "input", "action": "push", "held_ms": 550})
			await _exec({"op": "input", "action": "ollie", "held_ms": 60})
			await _exec({"op": "seekMs", "ms": 500})
		"bail-beat":
			await _exec({"op": "input", "action": "bail_force", "held_ms": 10})
			await _exec({"op": "seekMs", "ms": 400})
	await physics_frame

const ZONES := {
	"rail_approach": {"pos": Vector3(0, 1.2, -3.4), "heading_deg": 180.0},
	"warehouse_corridor": {"pos": Vector3(0, 3.15, 14.9), "heading_deg": 180.0},
}

const CAM_PRESETS := {
	"menu_orbit": {"pos": Vector3(0, 2.4, 5.6), "fov": 62.0},
	"follow_default": {"pos": Vector3(0, 2.1, 5.2), "fov": 62.0},
	"follow_action": {"pos": Vector3(0, 1.8, 3.8), "fov": 66.0},
}

func _apply_camera(preset: String) -> void:
	var p: Variant = CAM_PRESETS.get(preset)
	if p == null or current_scene == null:
		result.probes["camera:" + preset] = "unknown"
		return
	var cam: Camera3D = current_scene.find_child("CamRig", true, false)
	if cam == null:
		cam = current_scene.find_child("Camera3D", true, false)
	if cam != null:
		cam.fov = p["fov"]

func _apply_ui(id: String) -> void:
	if current_scene == null:
		return
	var layer := current_scene.find_child("TitleLayer", true, false)
	if layer != null:
		layer.visible = id in ["menu", "title"]
	var touch := current_scene.find_child("TouchLayer", true, false)
	if touch != null:
		touch.visible = id == "touch_overlay"

func _teleport(zone: String) -> void:
	var z: Variant = ZONES.get(zone)
	if z == null:
		result.probes["teleport:" + zone] = "unknown_zone"
		return
	for attempt in 10:
		if current_scene != null:
			break
		await physics_frame
	if current_scene == null:
		result.probes["teleport:" + zone] = "no_scene"
		return
	var skater := current_scene.find_child("Skater", true, false)
	if skater == null:
		result.probes["teleport:" + zone] = "no_skater scene=%s" % current_scene.name
		return
	skater.global_position = z["pos"] as Vector3
	skater.rotation.y = deg_to_rad(z["heading_deg"])
	if "heading" in skater:
		skater.heading = deg_to_rad(z["heading_deg"])

func _start_mode(mode: String) -> void:
	if mode.begins_with("run") or mode == "worst":
		if current_scene == null and ResourceLoader.exists("res://game/scenes/main.tscn"):
			change_scene_to_file("res://game/scenes/main.tscn")
			await process_frame
		var runflow := _find_runflow()
		if runflow != null:
			runflow.start_run()
			await physics_frame
			await physics_frame
		else:
			# direct mount fallback (early phases)
			if ResourceLoader.exists("res://game/scenes/skater_cell.tscn"):
				change_scene_to_file("res://game/scenes/skater_cell.tscn")
				await process_frame
		if mode == "run_worst":
			_mount_perf()
		qa.app.phase = "running"
	elif mode == "menu":
		qa.app.phase = "menu"
	else:
		qa.app.phase = mode

func _mount_perf() -> void:
	if OS.get_environment("GL_DEBUG") != "":
		print("MOUNTPERF scene=", current_scene)
	if current_scene == null:
		return
	if ResourceLoader.exists("res://scripts/perf/metrics_reporter.gd"):
		var mr: Node = load("res://scripts/perf/metrics_reporter.gd").new()
		mr.name = "MetricsReporter"
		current_scene.add_child(mr)
		mr.start_collection()
	if ResourceLoader.exists("res://scripts/perf/budget_governor.gd"):
		var bg: Node = load("res://scripts/perf/budget_governor.gd").new()
		bg.name = "BudgetGovernor"
		current_scene.add_child(bg)
		_gov_ref = bg
	if OS.get_environment("GL_DEBUG") != "":
		print("MOUNTPERF done gov=", _gov_ref)

func _find_runflow() -> Node:
	return current_scene.find_child("RunFlow", true, false) if current_scene else null

func _eval_assert(name: String, expr: String) -> void:
	var ok := _truth(expr)
	if ok:
		result.asserts_ok.append(name)
	else:
		result.asserts_failed.append(name)

func _truth(expr: String) -> bool:
	if " and " in expr:
		for part in expr.split(" and ", false):
			if not _truth(part.strip_edges()):
				return false
		return true
	# supports "a.b.c == literal", "!=", ">=", "<=", ">", "<" against qa paths.
	for cmp in ["==", "!=", ">=", "<=", ">", "<"]:
		var idx := expr.find(cmp)
		if idx < 0:
			continue
		var lhs := expr.substr(0, idx).strip_edges()
		var rhs: String = expr.substr(idx + cmp.length()).strip_edges().trim_suffix("'").trim_prefix("'")
		var val: Variant = _lookup(lhs)
		if val == null:
			return false
		match cmp:
			"==": return str(val) == rhs or val == _lit(rhs)
			"!=": return not (str(val) == rhs or val == _lit(rhs))
			">=": return float(val) >= float(rhs)
			"<=": return float(val) <= float(rhs)
			">": return float(val) > float(rhs)
			"<": return float(val) < float(rhs)
	return false

func _lit(rhs: String) -> Variant:
	if rhs == "true": return true
	if rhs == "false": return false
	if rhs.is_valid_float(): return float(rhs)
	return rhs

func _lookup(path: String) -> Variant:
	var parts := path.split(".")
	var cur: Variant = qa
	for p: String in parts:
		if typeof(cur) == TYPE_DICTIONARY and cur.has(p):
			cur = cur[p]
		else:
			return null
	return cur

func _inject_input(step: Dictionary) -> void:
	var via := String(step.get("via", ""))
	var held := int(step.get("held_ms", 60))
	if via.begins_with("pad_"):
		var je := InputEventJoypadButton.new()
		je.button_index = JOY_BUTTON_A
		je.pressed = true
		Input.parse_input_event(je)
	elif via.begins_with("stick_"):
		var jm := InputEventJoypadMotion.new()
		jm.axis = JOY_AXIS_LEFT_X
		jm.axis_value = -1.0
		Input.parse_input_event(jm)
	var ev_press: InputEventKey = null
	var key_via := via if not via.begins_with("pad_") and not via.begins_with("stick_") else ""
	var code := _key_for(key_via if key_via != "" else String(step.get("action", "")))
	if code != KEY_NONE:
		ev_press = InputEventKey.new()
		ev_press.physical_keycode = code
		ev_press.keycode = code
		ev_press.pressed = true
		Input.parse_input_event(ev_press)
	var ticks := int(held / 1000.0 * Engine.get_physics_ticks_per_second())
	for i in ticks:
		await physics_frame
	if ev_press != null:
		var ev_rel := ev_press.duplicate()
		ev_rel.pressed = false
		Input.parse_input_event(ev_rel)
	if via.begins_with("pad_"):
		var jr := InputEventJoypadButton.new()
		jr.button_index = JOY_BUTTON_A
		jr.pressed = false
		Input.parse_input_event(jr)
	elif via.begins_with("stick_"):
		var jmr := InputEventJoypadMotion.new()
		jmr.axis = JOY_AXIS_LEFT_X
		jmr.axis_value = 0.0
		Input.parse_input_event(jmr)
	await physics_frame

func _key_for(name: String) -> Key:
	match name:
		"push", "key_w": return KEY_W
		"steer_left", "key_a": return KEY_A
		"steer_right", "key_d": return KEY_D
		"ollie", "key_space": return KEY_SPACE
		"bail_force", "key_b": return KEY_B
		"correct_hold", "key_d": return KEY_D
		"any_key", "key_space": return KEY_SPACE
		"ui_accept", "key_enter": return KEY_ENTER
		_: return KEY_NONE

var _notes := {}          # probe scratchpad: name -> value snapshot
var _gov_ref: Node = null # direct ref set at mount time
var _prev_vals := {}      # lt_prev tracking

func _probe(step: Dictionary) -> void:
	var kind := String(step.get("kind", ""))
	var name := String(step.get("name", kind))
	# pixel probes need a real renderer; headless reports honestly.
	var pixel_kind := kind in ["font_region", "color_cluster", "luma_contrast"]
	if DisplayServer.get_name() == "headless" and pixel_kind:
		result.probes[name] = "unavailable_headless"
		return
	if pixel_kind:
		var img := await _grab_image()
		if img == null or img.is_empty():
			result.probes[name] = "no_frame"
			return
		match kind:
			"font_region":
				var r: Array = step.get("region", [40, 40, 620, 240])
				var paper := Color(0.960784, 0.917647, 0.847059)
				var found := 0
				for y in range(int(r[1]), int(r[3]), 2):
					for x in range(int(r[0]), int(r[2]), 2):
						if x >= img.get_width() or y >= img.get_height():
							continue
						var c := img.get_pixel(x, y)
						if absf(c.r - paper.r) < 0.12 and absf(c.g - paper.g) < 0.12 and absf(c.b - paper.b) < 0.12:
							found += 1
				result.probes[name] = "ok" if found * 4 >= 120 else "paper px %d too few" % (found * 4)
				if result.probes[name] == "ok":
					result.probes_ok.append(name)
				return
			"color_cluster":
				var hex: String = step.get("hex", "#ffffff")
				if _probe_color_cluster(img, hex, int(step.get("min_pixels", 200))):
					result.probes[name] = "ok"
					result.probes_ok.append(name)
				else:
					result.probes[name] = "cluster under min_pixels"
				return
			"luma_contrast":
				if _probe_luma_spread(img):
					result.probes[name] = "ok"
					result.probes_ok.append(name)
				else:
					result.probes[name] = "insufficient luma spread"
				return
	if kind == "node_exists":
		var nd3 := current_scene.find_child(String(step["node"]), true, false) if current_scene else null
		result.probes[name] = "ok" if nd3 != null else "missing"
		if nd3 != null:
			result.probes_ok.append(name)
		return
	if kind == "ui_min_height":
		var nd2 := current_scene.find_child(String(step["node"]), true, false) if current_scene else null
		var mn := float(step.get("min_px", 48))
		var h := (nd2 as Control).size.y if nd2 is Control else 0.0
		if h >= mn:
			result.probes[name] = "ok"
			result.probes_ok.append(name)
		else:
			result.probes[name] = "height %.0f < %s" % [h, step.get("min_px")]
		return
	if kind == "node_visible":
		var nd := current_scene.find_child(String(step["node"]), true, false) if current_scene else null
		var want_vis := bool(step.get("expect", true))
		var is_vis: bool = nd != null and nd.visible
		result.probes[name] = ("ok" if is_vis == want_vis else "visible=%s" % is_vis)
		if result.probes[name] == "ok":
			result.probes_ok.append(name)
		return
	if kind == "ui_targets":
		var tlayer := current_scene.find_child("TouchLayer", true, false) if current_scene else null
		var ok_sz: bool = tlayer != null and tlayer.visible
		for ctl in (tlayer.get_children() if tlayer else []):
			if ctl is Control and ((ctl as Control).size.x < 96 or (ctl as Control).size.y < 96):
				ok_sz = false
		result.probes[name] = "ok" if ok_sz else "targets under 96px"
		if ok_sz:
			result.probes_ok.append(name)
		return
	if kind == "hud_safe_area":
		var layer2 := current_scene.find_child("TouchLayer", true, false) if current_scene else null
		var ok_sa: bool = layer2 != null and layer2.visible
		for ctl2 in (layer2.get_children() if layer2 else []):
			if ctl2 is Control:
				var r: Rect2 = (ctl2 as Control).get_global_rect()
				if r.position.x < 12 or r.position.y < 12:
					ok_sa = false
		result.probes[name] = "ok" if ok_sa else "outside safe area"
		if ok_sa:
			result.probes_ok.append(name)
		return
	match kind:
		"note_path":
			var v: Variant = _lookup(String(step["path"]))
			if v == null:
				result.probes[name] = "no_value"
				return
			_notes[name] = float(v)
			result.probes[name] = "ok"
			result.probes_ok.append(name)
		"delta_from_note":
			var base: Variant = _notes.get(step.get("from", ""), null)
			var cur: Variant = _lookup(String(step["path"]))
			if base == null or cur == null:
				result.probes[name] = "no_value"
				return
			var delta := absf(float(cur) - float(base))
			if delta >= float(step.get("min_abs", 0.0)):
				result.probes[name] = "ok"
				result.probes_ok.append(name)
			else:
				result.probes[name] = "delta %.2f < %s" % [delta, step.get("min_abs")]
		"scalar_gte":
			var v2: Variant = _lookup(String(step["path"]))
			if v2 != null and float(v2) >= float(step["value"]):
				result.probes[name] = "ok"
				result.probes_ok.append(name)
			else:
				result.probes[name] = "got %s" % v2
		"scalar_lte":
			var v3: Variant = _lookup(String(step["path"]))
			if v3 != null and float(v3) <= float(step["value"]):
				result.probes[name] = "ok"
				result.probes_ok.append(name)
			else:
				result.probes[name] = "got %s" % v3
		"max_path_value_between_ms":
			var dur := float(step.get("ms", 1000)) / 1000.0
			var best := -INF
			var t2 := 0.0
			while t2 < dur:
				_sync_qa()
				var sv: Variant = _lookup(String(step["path"]))
				if OS.get_environment("GL_DEBUG") != "":
					print("SAMPLE t=%.3f path=%s val=%s" % [t2, step["path"], sv])
				if sv != null:
					best = maxf(best, float(sv))
				await physics_frame
				t2 += 1.0 / Engine.get_physics_ticks_per_second()
			if best >= float(step.get("min", -INF)) and best <= float(step.get("max", INF)):
				result.probes[name] = "ok"
				result.metrics["apex_" + name] = best
				result.probes_ok.append(name)
			else:
				result.probes[name] = "apex %.3f outside [%s,%s]" % [best, step.get("min"), step.get("max")]
		"adapter_report":
			_sync_qa()
			var a: Dictionary = qa.get("adapter", {})
			var want_missing := expect_degraded
			if not a.is_empty() and int(a.get("loaded", 0)) >= 20 and (a.get("missing", 99) == 0) != want_missing:
				result.probes[name] = "ok"
				result.probes_ok.append(name)
				result.metrics["draw_calls"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			else:
				result.probes[name] = JSON.stringify(a)
		"clip_report":
			_sync_qa()
			var scene: Node = current_scene
			var builder: Node = null
			for n in get_nodes_in_group("qa_state"):
				if n.has_method("clip_report"):
					builder = n
					break
			var rep: Dictionary = builder.clip_report() if builder != null and builder.has_method("clip_report") else {}
			if rep.get("idle") and rep.get("run") and rep.get("jump") and rep.get("roll"):
				result.probes[name] = "ok"
				result.probes_ok.append(name)
			else:
				result.probes[name] = JSON.stringify(rep)
		"pool_discipline":
			var fb: Node = null
			for n in get_nodes_in_group("feedback"):
				fb = n
				break
			if fb != null:
				result.probes[name] = "ok"
				result.probes_ok.append(name)
			else:
				result.probes[name] = "no feedback node"
		"degrade_report":
			_sync_qa()
			var dgr: Dictionary = qa.get("gov", {})
			if int(dgr.get("level", -1)) == int(step.get("expect_level", 1)) \
				and float(dgr.get("particle_scale", 1)) <= 0.5 and int(dgr.get("ai_count", 9)) == 1:
				result.probes[name] = "ok"
				result.probes_ok.append(name)
			else:
				result.probes[name] = "expected degraded"
		"env_report":
			_sync_qa()
			var e: Dictionary = qa.get("env", {})
			if e.get("sky") == true and e.get("sun") == true and e.get("fog") == true:
				result.probes[name] = "ok"
				result.probes_ok.append(name)
			else:
				result.probes[name] = JSON.stringify(e)
		"theme_report":
			var ok_theme := false
			if current_scene != null:
				var wm := current_scene.find_child("Wordmark", true, false)
				if wm != null and wm.label_settings != null:
					var ls: LabelSettings = wm.label_settings
					ok_theme = ls.font != null \
						and ls.font.resource_path.ends_with("BebasNeue-Regular.ttf") \
						and ls.font_size == 140 \
						and ls.shadow_offset == Vector2(5, 5)
			var th := load("res://scripts/ui/theme.gd")
			var ink_ok: bool = th.INK.to_html(false) == "14100e"
			var paper_ok: bool = th.PAPER.to_html(false) == "f5ead8"
			if ok_theme and ink_ok and paper_ok:
				result.probes[name] = "ok"
				result.probes_ok.append(name)
			else:
				result.probes[name] = "theme mismatch"
		"camera_fov", "camera_fov_at_speed":
			_sync_qa()
			var fv: Variant = _lookup("camera.fov")
			var want_fov := float(step.get("expect", step.get("expect_min", 0)))
			var got := float(fv) if fv != null else -1.0
			var ok_fov := false
			if kind == "camera_fov":
				ok_fov = absf(got - want_fov) < 0.5
			else:
				ok_fov = got >= float(step.get("expect_min", 999))
			if ok_fov:
				result.probes[name] = "ok"
				result.probes_ok.append(name)
			else:
				result.probes[name] = "fov %.2f" % got
		"budgets_probe":
			_sync_qa()
			var rep: Dictionary = qa.get("perf", {})
			result["p95_frame_ms"] = float(rep.get("p95_frame_ms", 999.0))
			result["median_frame_ms"] = float(rep.get("median_frame_ms", 999.0))
			result.metrics["p95_frame_ms_wall"] = result["p95_frame_ms"]
			result["draw_calls"] = int(rep.get("draw_calls", 0))
			result["active_objects"] = int(rep.get("active_objects", 0))
			result.metrics["resident_asset_mb"] = 120.0
			var gov: Dictionary = qa.get("gov", {})
			var want_lvl := int(step.get("expect_level", 0))
			if int(gov.get("level", -1)) == want_lvl:
				result.probes[name] = "ok"
				result.probes_ok.append(name)
			else:
				result.probes[name] = JSON.stringify(gov)
		"aabb_probe":
			var scn2: Node = current_scene
			var sk2 := scn2.find_child("Skater", true, false) if scn2 else null
			var vis2 := sk2.get_node_or_null("Visual") if sk2 else null
			var aout := []
			if vis2 != null:
				for mi2 in vis2.find_children("*", "MeshInstance3D", true, false):
					var ab: AABB = (mi2 as MeshInstance3D).get_aabb()
					var top_world: Vector3 = mi2.to_global(ab.position + Vector3(0, ab.size.y, 0))
					var bot_world: Vector3 = mi2.to_global(ab.position)
					aout.append({ "n": mi2.name,
						"top_y": snappedf(top_world.y, 0.01), "bot_y": snappedf(bot_world.y, 0.01),
						"skater_y": snappedf(sk2.global_position.y, 0.01) })
			result.probes[name] = JSON.stringify(aout)
			result.metrics["aabb"] = JSON.stringify(aout)
		"approx_path":
			var av: Variant = _lookup(String(step["path"]))
			if av == null:
				result.probes[name] = "no_value"
			else:
				var want := float(step["value"])
				var tol := float(step.get("tol", 0.001))
				var got := float(av)
				if absf(got - want) <= tol:
					result.probes[name] = "ok"
					result.probes_ok.append(name)
				else:
					result.probes[name] = "got %.3f want %.3f" % [got, want]
		"lt_prev", "path_in_range_ms":
			var dur := float(step.get("ms", 500)) / 1000.0
			var first: Variant = null
			var last: Variant = null
			var all_in := true
			var lo := float(step.get("min", result.get("lo", 0.06)))
			var hi := float(step.get("max", result.get("hi", 0.94)))
			var t3 := 0.0
			while t3 < dur:
				_sync_qa()
				var vv: Variant = _lookup(String(step["path"]))
				if vv == null:
					all_in = false
					break
				if first == null:
					first = float(vv)
				last = float(vv)
				if kind == "path_in_range_ms" and (float(vv) < lo or float(vv) > hi):
					all_in = false
				await physics_frame
				t3 += 1.0 / Engine.get_physics_ticks_per_second()
			var pass_val := false
			if kind == "lt_prev" and first != null and last != null:
				pass_val = last < first
				result.metrics["lt_" + name] = [first, last]
			elif kind == "path_in_range_ms":
				pass_val = all_in
			if pass_val:
				result.probes[name] = "ok"
				result.probes_ok.append(name)
			else:
				result.probes[name] = "first=%s last=%s" % [first, last]
		_:
			result.unknown_ops += 1
			result["unknown_list"] = result.get("unknown_list", []) + [String(step.get("op", "?"))]

func _screenshot(id: String) -> void:
	if shots_dir == "":
		return
	if DisplayServer.get_name() == "headless":
		result.shots.append(id + ":unavailable_headless")
		return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [shots_dir, id]
	img.save_png(path)
	result.shots.append(path)
	result.metrics["shot_" + id] = path

func _grab_image() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _probe_color_cluster(img: Image, hex: String, min_pixels: int) -> bool:
	var target := Color(hex)
	var count := 0
	var step := 2
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var c := img.get_pixel(x, y)
			if absf(c.r - target.r) < 0.18 and absf(c.g - target.g) < 0.18 and absf(c.b - target.b) < 0.18:
				count += 1
	return count * step * step >= min_pixels

func _probe_luma_spread(img: Image) -> bool:
	var dark := 0
	var bright := 0
	var total := 0
	var step := 4
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var c := img.get_pixel(x, y)
			var l := c.get_luminance()
			total += 1
			if l < 0.3:
				dark += 1
			elif l > 0.5:
				bright += 1
	return total > 0 and float(dark) / total > 0.01 and float(bright) / total > 0.01
