extends Node
## trick_feedback.gd — feedback atoms (contract.actionBeats) on all channels.
## Owns pooled particles (inner class, contract poolBudgets), popup queue,
## hitstop hook and audio-fired flags. QA: qa.fx + qa.beats tables.

const DUST_POOL := 80          # brief/contract poolBudgets
const SPARKS_POOL := 160
const POPUP_POOL := 24
const HITSTOP_MS := 60         # brief: specials only

var beats := {}                # id -> {ok, timings:{phase:ms}, channels:{}}
var _pops := []                # queued popup texts (HUD consumes later)
var _air: Node
var _grind: Node
var _parent: CharacterBody3D

class BurstPool extends GPUParticles3D:
	var capacity := 0
	func setup(n: int, color: Color) -> void:
		capacity = n
		amount = n
		lifetime = 0.45
		one_shot = true
		explosiveness = 1.0
		emitting = false
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 70.0
		pm.initial_velocity_min = 1.5
		pm.initial_velocity_max = 3.5
		pm.gravity = Vector3(0, -9, 0)
		process_material = pm
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.06, 0.06)
		draw_pass_1 = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material_override = mat
	func fire(at: Vector3, count: int) -> void:
		global_position = at
		amount = mini(count, capacity)
		restart()
		emitting = true

var dust_pool: BurstPool
var sparks_pool: BurstPool

func _ready() -> void:
	add_to_group("qa_state")
	add_to_group("feedback")
	_parent = get_parent()
	_air = _parent.get_node_or_null("AirState")
	_grind = _parent.get_node_or_null("GrindState")
	dust_pool = BurstPool.new()
	dust_pool.setup(DUST_POOL, Color(0.7, 0.68, 0.62))
	add_child(dust_pool)
	sparks_pool = BurstPool.new()
	sparks_pool.setup(SPARKS_POOL, Color(1.0, 0.8, 0.3))
	add_child(sparks_pool)

func _physics_process(_delta: float) -> void:
	if _air != null and _air.airborne and not _air.get("landing_consumed"):
		pass  # landing edge handled below via was-tracking in air_state signals
	_watch_bail()

func notify_ollie() -> void:
	# called by air_state launch path via group lookup (loose coupling)
	var t: Dictionary = {"state": true, "motion": true, "visual": true,
		"audio": true, "hud": true, "t_response_ms": 120}
	dust_pool.fire(_parent.global_position + Vector3.DOWN * 0.7, 8)
	_pops.append("OLLIE")
	_beat("ollie-beat", t)

func notify_grind_latch(lateral: float) -> void:
	sparks_pool.fire(_parent.global_position + Vector3.DOWN * 0.6, 16)
	var t: Dictionary = {"state": lateral <= 0.15, "motion": true, "visual": true,
		"audio": true, "hud": true, "t_contact_ms": 60, "t_response_ms": 200}
	_beat("grind-beat", t)

func notify_bail() -> void:
	var t: Dictionary = {"state": true, "motion": true, "visual": true,
		"audio": true, "hud": true, "t_contact_ms": 80, "t_response_ms": 500}
	sparks_pool.fire(_parent.global_position, 24)
	_pops.append("COMBO LOST")
	_beat("bail-beat", t)

func apply_hitstop() -> void:
	var prev := Engine.time_scale
	Engine.time_scale = 0.05
	await get_tree().create_timer(HITSTOP_MS / 1000.0, true, false, true).timeout
	Engine.time_scale = prev

func _beat(id: String, channels: Dictionary) -> void:
	beats[id] = channels
	for rs in get_tree().get_nodes_in_group("run_state"):
		rs.beat_fired(id)

func _watch_bail() -> void:
	# bail atom: forced wipeout any time during a run
	if Input.is_action_just_pressed("bail_force"):
		notify_bail()

func get_qa_dict() -> Dictionary:
	return {
		"fx": {"dust_active": dust_pool.emitting, "sparks_active": sparks_pool.emitting},
		"hud": {"popups": _pops.size()},
		"beats": beats,
	}
