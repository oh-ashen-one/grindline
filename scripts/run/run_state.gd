extends Node
## run_state.gd — the run truth: timer, score, combo, multiplier.
## One authoritative model; HUD and persistence consume via get_qa_dict/signals.

const RUN_MS := 120000.0        # brief: 2-minute runs
const BASE_TRICK_POINTS := 100  # slice value; trick table lands in phase 4

var phase := "running"          # running | results
var time_left_ms := RUN_MS
var score := 0
var combo_count := 0
var multiplier := 1

var _skater: Node = null
var _air: Node = null
var _was_airborne := false

func _ready() -> void:
	add_to_group("qa_state")
	add_to_group("run_state")

func _physics_process(delta: float) -> void:
	if phase != "running":
		return
	time_left_ms = maxf(time_left_ms - delta * 1000.0, 0.0)
	if time_left_ms <= 0.0:
		phase = "results"
		return
	_track_landings()

func _track_landings() -> void:
	if _skater == null:
		_skater = get_tree().current_scene.find_child("Skater", true, false) if get_tree().current_scene else null
		if _skater == null:
			return
		_air = _skater.get_node_or_null("AirState")
	var airborne_now: bool = _air.airborne if _air else false
	if _was_airborne and not airborne_now:
		combo_count += 1
		score += BASE_TRICK_POINTS * multiplier
	_was_airborne = airborne_now
	if Input.is_action_just_pressed("bail_force"):
		multiplier = 1  # pending combo wiped; banked score stays

func beat_fired(_id: String) -> void:
	pass  # HUD hook lands with feedback-atoms UI story

func get_qa_dict() -> Dictionary:
	return {
		"run": {
			"phase": phase,
			"time_left_ms": snappedf(time_left_ms, 0.001),
			"score": score,
			"combo_count": combo_count,
			"multiplier": multiplier,
		}
	}
