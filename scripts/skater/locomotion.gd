extends CharacterBody3D
## locomotion.gd — push, steer and friction for the grounded skater.
## Constants are BRIEF.md feel values; they consolidate into config.gd at the
## vertical-slice capstone.

const PUSH_ACCEL := 6.5          # brief: m/s^2 while pushing
const MAX_PUSH_SPEED := 11.0     # brief: m/s
const STEER_RATE := 3.5          # brief: rad/s at speed
const FRICTION_DECEL := 4.0      # brief: m/s^2 when idle on flat ground
const GRAVITY := 18.0            # brief: arcade gravity

var speed := 0.0
var heading := PI                # spawn facing -Z (away from spawn camera)

var _anim: AnimationPlayer
var _skel: Skeleton3D
var _holding := true          # board in hand until first push
var _bob_t := 0.0
var _hand_board: Node3D
var _foot_board: Node3D

var _bone_attach: BoneAttachment3D

func _ready() -> void:
	add_to_group("qa_state")
	var vis := get_node_or_null("Visual")
	if vis != null:
		_anim = vis.get_node_or_null("AnimationPlayer")
		if _anim == null:
			var players := vis.find_children("*", "AnimationPlayer", true, false)
			_anim = players[0] if players.size() > 0 else null
		_skel = vis.get_node_or_null("Skeleton3D")
		if _skel == null:
			var skels := vis.find_children("*", "Skeleton3D", true, false)
			_skel = skels[0] if skels.size() > 0 else null
	if OS.get_environment("GL_DEBUG") != "":
		print("ANIM found:", _anim, " clips:", _anim.get_animation_list() if _anim else [])
	if _anim != null:
		_anim.playback_default_blend_time = 0.2
	_hand_board = get_node_or_null("BoardHand")
	_foot_board = get_node_or_null("BoardVisual")
	for b in [_hand_board, _foot_board]:
		if b == null:
			continue
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.62, 0.45, 0.28)  # warm wood deck
		mat.roughness = 0.7
		for mi in b.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = mat
	_apply_holding_visibility()
	if _skel != null and _hand_board != null:
		_bone_attach = BoneAttachment3D.new()
		_bone_attach.name = "HandBoardAttach"
		_skel.add_child(_bone_attach)
		_bone_attach.bone_name = "Fist.R"
		_hand_board.reparent(_bone_attach)
		_hand_board.position = Vector3(0, -0.32, 0.1)
		_hand_board.rotation_degrees = Vector3(0, 0, 96)

func _apply_holding_visibility() -> void:
	if _hand_board != null:
		_hand_board.visible = _holding
	if _foot_board != null:
		_foot_board.visible = not _holding

func _drop_board() -> void:
	_holding = false
	_apply_holding_visibility()
	if _anim != null:
		_anim.play("Run", 0.2)

func _play_clip(name: String, speed := 1.0) -> void:
	if _anim == null:
		return
	var target := ""
	for a in _anim.get_animation_list():
		if String(a).to_lower().ends_with(name) or String(a).to_lower() == name:
			target = a
			break
	if target == "":
		if OS.get_environment("GL_DEBUG") != "":
			print("PLAYCLIP miss:", name)
		return
	if _anim.current_animation != target:
		_anim.play(target, 0.2)
		_anim.speed_scale = speed

func _physics_process(delta: float) -> void:
	var pushing := Input.is_action_pressed("push")
	var steer := Input.get_axis("steer_right", "steer_left")  # left = +1

	if pushing and _holding:
		_drop_board()
	if pushing:
		speed = minf(speed + PUSH_ACCEL * delta, MAX_PUSH_SPEED)
	else:
		speed = maxf(speed - FRICTION_DECEL * delta, 0.0)

	if speed > 0.1:
		heading += steer * STEER_RATE * delta * clampf(speed / 6.0, 0.4, 1.0)

	# animation state (slim hero: Idle / Run / Jump / Roll)
	if is_on_floor():
		if speed > 0.6 and not _holding:
			_play_clip("run", clampf(speed / 7.0, 0.8, 1.6))
		else:
			_play_clip("idle")

	var forward := Vector3(sin(heading), 0.0, cos(heading))
	# horizontal comes from locomotion; vertical belongs to air_state/gravity.
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y <= 0.0:
		velocity.y = -0.5  # stick to floor only when not launching
	# rising velocities pass through untouched (ollie impulse lives here)
	move_and_slide()

func get_qa_dict() -> Dictionary:
	return {
		"skater": {
			"speed": snappedf(speed, 0.01),
			"grounded": is_on_floor(),
			"height": global_position.y,
			"heading_deg": rad_to_deg(heading),
			"world_y": snappedf(global_position.y, 0.01),
			"floor_flag": is_on_floor(),
		}
	}
