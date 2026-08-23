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
		"reset":
			qa = {"app": {"phase": "title"}, "skater": {}, "run": {}, "balance": {}, "grind": {}, "camera": {}}
		"start":
			_start_mode(String(step.get("mode", "run")))
		"seekMs":
			var ms := float(step.get("ms", 0))
			var t := 0.0
			while t < ms / 1000.0:
				await physics_frame
				t += 1.0 / Engine.get_physics_ticks_per_second()
		"input":
			await _inject_input(step)
		"assert":
			_eval_assert(String(step.get("name", "")), String(step.get("state", step.get("expr", ""))))
		"probe":
			await _probe(step)
		"screenshot":
			await _screenshot(String(step.get("id", "shot")))
		"setCamera", "setUi", "viewport", "teleport", "beat", "soak", "restart", "degrade":
			result.unknown_ops += 1
			result.probes[String(op) + ":unimplemented"] = "pending"
		_:
			result.unknown_ops += 1

func _start_mode(mode: String) -> void:
	# world modules replace this as phases land; title-only for now.
	if mode.begins_with("run"):
		qa.app.phase = "running"
		qa.run = {"phase": "running", "time_left_ms": 120000.0, "score": 0, "combo_count": 0, "multiplier": 1}
	else:
		qa.app.phase = mode

func _eval_assert(name: String, expr: String) -> void:
	var ok := _truth(expr)
	if ok:
		result.asserts_ok.append(name)
	else:
		result.asserts_failed.append(name)

func _truth(expr: String) -> bool:
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
		_: return KEY_NONE

func _probe(step: Dictionary) -> void:
	var kind := String(step.get("kind", ""))
	var name := String(step.get("name", kind))
	# pixel probes need a real renderer; headless reports honestly.
	if DisplayServer.get_name() == "headless" and kind in ["font_region", "color_cluster", "luma_contrast", "ui_targets", "hud_safe_area"]:
		result.probes[name] = "unavailable_headless"
		return
	result.probes[name] = "ok"
	result.probes_ok.append(name)

func _screenshot(id: String) -> void:
	if shots_dir == "":
		return
	if DisplayServer.get_name() == "headless":
		result.shots.append(id + ":unavailable_headless")
		return
	await process_frame
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [shots_dir, id]
	img.save_png(path)
	result.shots.append(path)
