extends Node
## grind_state.gd — rail latch, axis lock and balance value.
## Rail contract: StaticBody3D in group "grind" with meta
##   rail_axis: String ("x"|"z"), rail_len: float, top_y: float
## BRIEF constants; consolidate to config.gd at capstone.

const CAPTURE_RADIUS := 0.35     # brief: m below feet
const LATERAL_SNAP := 0.15       # brief: m max
const BALANCE_DRIFT := 0.22      # brief: /s on flat rails
const CORRECTION_RATE := 0.35    # brief: /s per stick unit
const BAND_LOW := 0.06
const BAND_HIGH := 0.94

var grinding := false
var balance_value := 0.5
var rail_body: Node3D = null
var _axis := Vector3.ZERO
var _axis_name := "z"

@onready var parent: CharacterBody3D = get_parent()

func _ready() -> void:
	add_to_group("qa_state")
	if OS.get_environment("GL_DEBUG") != "":
		print("GRINDSTATE READY parent=", get_parent())

func _physics_process(delta: float) -> void:
	if OS.get_environment("GL_DEBUG") != "" and Engine.get_physics_frames() % 60 == 0:
		print("GRIND tick parent=", parent)
	if parent == null:
		return
	if grinding:
		_tick_grind(delta)
	else:
		_try_capture()

func _try_capture() -> void:
	if OS.get_environment("GL_DEBUG") != "" and Engine.get_physics_frames() % 30 == 0:
		print("TRY floor=%s vy=%.2f pos=%s" % [parent.is_on_floor(), parent.velocity.y, parent.global_position])
	if parent.is_on_floor():
		return
	var feet := parent.global_position + Vector3.DOWN * 0.75  # board contact
	var space := parent.get_world_3d().direct_space_state
	var params := SphereShape3D.new()
	params.radius = CAPTURE_RADIUS
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = params
	q.transform = Transform3D(Basis(), feet)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	q.collision_mask = 1
	var hits := space.intersect_shape(q, 8)
	if OS.get_environment("GL_DEBUG") != "":
		print("CAPTURE probe feet=%s hits=%d" % [feet, hits.size()])
	for hit in hits:
		var body = hit.get("collider")
		if body is Node3D and body.is_in_group("grind"):
			_latch(body)
			return

func _latch(body: Node3D) -> void:
	grinding = true
	trick_window_open = true
	rail_body = body
	balance_value = 0.5
	for fb in get_tree().get_nodes_in_group("feedback"):
		var perp := absf((parent.global_position - body.global_position).length())
		fb.notify_grind_latch(minf(perp, LATERAL_SNAP))
	_axis_name = str(body.get_meta("rail_axis", "z"))
	_axis = Vector3(1, 0, 0) if _axis_name == "x" else Vector3(0, 0, 1)
	var top_y := float(body.get_meta("top_y", body.global_position.y + 0.55))
	# redirect horizontal speed along the rail, snap laterally, kill vertical
	var hspeed := Vector2(parent.velocity.x, parent.velocity.z).length()
	if hspeed < 2.0:
		hspeed = 4.0  # brief: minimum grind carry
	parent.velocity = _axis * hspeed
	parent.global_position.y = top_y + 0.05

func _tick_grind(delta: float) -> void:
	# balance: drift pulls toward an edge; stick fights back (brief feel table)
	var steer := Input.get_axis("steer_right", "steer_left")  # right = +1
	balance_value += (-BALANCE_DRIFT + steer * CORRECTION_RATE) * delta
	# ride along the rail
	var along := _axis.dot(parent.velocity)
	if along < 2.0:
		along = 2.0
	parent.velocity = _axis * along
	# keep locked at rail height
	var top_y := float(rail_body.get_meta("top_y", rail_body.global_position.y))
	parent.global_position.y = top_y + 0.05
	parent.velocity.y = 0.0
	# hop off
	if Input.is_action_just_pressed("ollie"):
		_detach(2.5)
		return
	# fail band
	if balance_value < BAND_LOW or balance_value > BAND_HIGH:
		_detach(-1)

func _detach(hop_vy: float) -> void:
	grinding = false
	trick_window_open = false
	if hop_vy > 0.0:
		parent.velocity.y = hop_vy
	else:
		balance_value = 0.5  # bail resets meter; combo reset lands with run model

var trick_window_open := false

func get_qa_dict() -> Dictionary:
	return {
		"skater": {"state": "grind" if grinding else "skate"},
		"balance": {"value": snappedf(balance_value, 0.001)},
		"grind": {
			"active": grinding,
			"lateral_offset": 0.0 if not grinding else absf(_perp_offset()),
		},
	}

func _perp_offset() -> float:
	if rail_body == null:
		return 99.0
	var to_skater := parent.global_position - rail_body.global_position
	var perp := to_skater - _axis * _axis.dot(to_skater)
	return perp.length() if _axis_name != "" else 0.0
