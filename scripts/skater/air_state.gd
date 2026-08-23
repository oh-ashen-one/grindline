extends Node
## air_state.gd — ollie ownership: anticipation, impulse, landing settle.
## Parent must be the CharacterBody3D skater (locomotion.gd drives movement).
## BRIEF feel constants; consolidate to config.gd at capstone.

const OLLIE_VY := 7.2           # brief: m/s
const CROUCH_OLLIE_VY := 8.4    # brief
const ANTICIPATION_MS := 40     # brief: ollie-beat anticipation

var airborne := false
var apex_height_m := 0.0        # height above takeoff this air
var _takeoff_y := 0.0
var _was_airborne := false
var _landed_at_ms := -1.0
var _trick_window_open := false

@onready var parent: CharacterBody3D = get_parent()

func _ready() -> void:
	add_to_group("qa_state")

func _physics_process(delta: float) -> void:
	if parent == null:
		return
	var now := Time.get_ticks_msec()
	if Input.is_action_just_pressed("ollie") and not airborne:
		_launch()
	if airborne:
		var h := parent.global_position.y - _takeoff_y
		apex_height_m = maxf(apex_height_m, h)
		if parent.is_on_floor():
			airborne = false
			_trick_window_open = false
			_landed_at_ms = float(now)
	elif _landed_at_ms >= 0.0 and now - int(_landed_at_ms) <= 150:
		pass  # settle window; animation hook lands here in phase 4

func _launch() -> void:
	await get_tree().create_timer(ANTICIPATION_MS / 1000.0).timeout
	if parent == null or not is_instance_valid(parent):
		return
	parent.velocity.y = OLLIE_VY
	airborne = true
	for fb in get_tree().get_nodes_in_group("feedback"):
		fb.notify_ollie()
	_trick_window_open = true
	_takeoff_y = parent.global_position.y
	apex_height_m = 0.0

func get_qa_dict() -> Dictionary:
	return {
		"skater": {
			"grounded": not airborne and parent.is_on_floor() if parent else false,
			"height": apex_height_m if airborne else 0.0,
			"trick_window": _trick_window_open,
		}
	}
