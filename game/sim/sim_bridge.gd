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
	match op:
		"noop":
			pass
		"dump":
			_sync_qa()
			print("SIM DUMP ", JSON.stringify(qa))
		"reset":
			qa = {"app": {"phase": "title"}, "skater": {}, "run": {}, "balance": {}, "grind": {}, "camera": {}}
		"start":
			_start_mode(String(step.get("mode", "run")))
		"seekMs", "soak":
			var ms := float(step.get("ms", 0))
			var t := 0.0
			var prev_scale := Engine.time_scale
			if ms > 2000.0:
				Engine.time_scale = 20.0  # fast-forward; fixed timestep preserved
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
		"viewport", "beat", "degrade":
			result.unknown_ops += 1
			result.probes[String(op) + ":unimplemented"] = "pending"
		_:
			result.unknown_ops += 1

const ZONES := {
	"rail_approach": {"pos": Vector3(0, 1.2, -3.4), "heading_deg": 180.0},
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
		qa.app.phase = "running"
	elif mode == "menu":
		qa.app.phase = "menu"
	else:
		qa.app.phase = mode

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
	var ev_press: InputEventKey = null
	var code := _key_for(via if via != "" else String(step.get("action", "")))
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
	await physics_frame

func _key_for(name: String) -> Key:
	match name:
		"push", "key_w": return KEY_W
		"steer_left", "key_a": return KEY_A
		"steer_right", "key_d": return KEY_D
		"ollie", "key_space": return KEY_SPACE
		"bail_force", "key_b": return KEY_B
		"correct_hold", "key_d": return KEY_D
		_: return KEY_NONE

var _notes := {}          # probe scratchpad: name -> value snapshot
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
			if rep.get("idle") and rep.get("skate") and rep.get("skate-air") and rep.get("die"):
				result.probes[name] = "ok"
				result.probes_ok.append(name)
			else:
				result.probes[name] = JSON.stringify(rep)
		"degrade_report":
			_sync_qa()
			var dgr: Dictionary = qa.get("adapter", {})
			if bool(dgr.get("degraded", false)) == true:
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
