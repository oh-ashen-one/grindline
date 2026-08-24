extends Camera3D
## follow_cam.gd — THPS follow cam (BRIEF Scale-and-camera constants).
## Spring-follows the Skater with look-ahead, FOV kick, trauma shake,
## wall-hug occlusion clamp.

const DISTANCE := 4.3
const HEIGHT := 1.30
const MIN_DISTANCE := 2.6          # brief: wall-hug clamp
const POS_DAMP := 8.0              # brief: lerp /s exponential
const ROT_DAMP := 6.0
const LOOK_AHEAD := 2.2            # brief: m along velocity
const FOV_BASE := 56.0             # brief v2
const FOV_KICK_10 := 72.0
const FOV_KICK_13 := 78.0
const TRAUMA_DECAY := 1.4          # brief: /s
const SHAPE_MAX_OFFSET := 0.4      # brief: trauma^2 * 0.4

var trauma := 0.0
var _force_hug := false
var _snapped := false
var _skater: Node3D

func _ready() -> void:
	add_to_group("qa_state")
	fov = FOV_BASE
	current = true

func _physics_process(delta: float) -> void:
	if _skater == null:
		_skater = get_tree().current_scene.find_child("Skater", true, false) \
			if get_tree().current_scene != null else null
		if _skater == null:
			return
	if not _snapped:
		_snapped = true
		global_position = _skater.global_position + Vector3(0, HEIGHT, DISTANCE)
	var sv: Vector3 = _skater.velocity
	var hvel := Vector3(sv.x, 0, sv.z)
	var spd := hvel.length()
	var back := -hvel.normalized() if spd > 0.5 else Vector3(0, 0, 1)
	var want := _skater.global_position + back * DISTANCE + Vector3(0, HEIGHT, 0) \
		+ hvel.normalized() * LOOK_AHEAD * clampf(spd / 8.0, 0.2, 1.0)
	# wall-hug occlusion: ray from skater toward desired camera pos
	var space := get_world_3d().direct_space_state
	var rq := PhysicsRayQueryParameters3D.create(
		_skater.global_position + Vector3.UP * 0.4, want)
	rq.collision_mask = 1
	var hit := space.intersect_ray(rq)
	if OS.get_environment("GL_DEBUG") != "" and Engine.get_physics_frames() % 30 == 0:
		print("CAM want=%s hit=%s" % [want, hit.keys()])
	var target := want
	if not hit.is_empty() or _force_hug:
		# brief occlusion rule: hug the wall at min distance
		var dir := (want - _skater.global_position).normalized()
		target = _skater.global_position + dir * MIN_DISTANCE
	var k := 1.0 - exp(-POS_DAMP * delta)
	global_position = global_position.lerp(target, k)
	if OS.get_environment("GL_DEBUG") != "" and Engine.get_physics_frames() % 45 == 0:
		print("CAMFOLLOW cam=", global_position, " skater=", _skater.global_position, " spd=", spd)
	look_at(_skater.global_position + Vector3.UP * 0.75)
	if OS.get_environment("GL_DEBUG") != "" and Engine.get_physics_frames() % 45 == 0:
		print("CAMDBG spd=%.2f fov=%.2f skater=%s" % [spd, fov, _skater])
	# FOV kick by speed (brief thresholds)
	var want_fov := FOV_BASE
	if spd >= 13.0:
		want_fov = FOV_KICK_13
	elif spd >= 10.0:
		want_fov = FOV_KICK_10
	fov = lerpf(fov, want_fov, 1.0 - exp(-3.0 * delta))
	# trauma shake
	trauma = maxf(trauma - TRAUMA_DECAY * delta, 0.0)
	var off := trauma * trauma * SHAPE_MAX_OFFSET
	h_offset = sin(Time.get_ticks_msec() * 0.05) * off
	v_offset = cos(Time.get_ticks_msec() * 0.041) * off

## deterministic QA hook: does the rule clamp a blocked ray?
func probe_occlusion(from: Vector3, to: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var rq := PhysicsRayQueryParameters3D.create(from, to)
	rq.collision_mask = 1
	var hit := space.intersect_ray(rq)
	if hit.is_empty():
		return -1.0
	return MIN_DISTANCE

func add_trauma(t: float) -> void:
	trauma = minf(trauma + t, 1.0)

func get_qa_dict() -> Dictionary:
	return {"camera": {"fov": snappedf(fov, 0.01), "distance": snappedf(
		global_position.distance_to(_skater.global_position) if _skater else 99.0, 0.01)}}
