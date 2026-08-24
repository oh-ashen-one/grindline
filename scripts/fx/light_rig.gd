extends Node
## light_rig.gd — the dusk look, locked (BRIEF "Visual system").
## Builds/owns WorldEnvironment + sun so every scene gets identical light.
## QA: env_report probe reads back live values.

const SUN_PITCH_DEG := -38.0     # brief v2: golden-hour higher key
const SUN_AZIMUTH_DEG := 35.0
const SUN_ENERGY := 0.95          # brief v2.2
const SUN_COLOR := Color(1.0, 0.878431, 0.729412)   # #ffe0ba warm key
const FOG_COLOR := Color(0.91, 0.78, 0.62)          # #e8c79e hazy gold
const FOG_NEAR := 45.0           # brief
const FOG_FAR := 120.0           # brief

var _env: WorldEnvironment = null
var _sun: DirectionalLight3D = null

func _ready() -> void:
	add_to_group("qa_state")
	_build()

func _build() -> void:
	if _env != null:
		return
	_env = WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	# dusk grade on the procedural sky; HDRIs arrive via asset integration
	mat.sky_top_color = Color(0.164706, 0.101961, 0.2)         # #2a1a33
	mat.sky_horizon_color = Color(0.909804, 0.45, 0.20) # dusk orange
	mat.ground_bottom_color = Color(0.12, 0.09, 0.10)
	mat.ground_horizon_color = Color(0.909804, 0.407843, 0.227451)
	sky.sky_material = mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.fog_enabled = true
	e.fog_light_color = FOG_COLOR
	e.fog_density = 0.0005
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 0.92
	_env.environment = e
	add_child(_env)

	_sun = DirectionalLight3D.new()
	_sun.light_color = SUN_COLOR
	_sun.light_energy = SUN_ENERGY
	var pitch := deg_to_rad(SUN_PITCH_DEG)
	var azim := deg_to_rad(SUN_AZIMUTH_DEG)
	_sun.rotation = Vector3(pitch, azim, 0)
	_sun.shadow_enabled = true
	_sun.shadow_bias = 0.04
	_sun.shadow_normal_bias = 2.0
	_sun.shadow_blur = 1.2
	add_child(_sun)

func get_qa_dict() -> Dictionary:
	var ok_env := _env != null and _env.environment != null and _env.environment.sky != null
	var sun_ok := false
	if _sun != null:
		var pitch_ok := absf(rad_to_deg(_sun.rotation.x) - SUN_PITCH_DEG) < 1.0
		var energy_ok := absf(_sun.light_energy - SUN_ENERGY) <= 0.05
		sun_ok = pitch_ok and energy_ok
	return {"env": {
		"sky": ok_env,
		"sun": sun_ok,
		"fog": _env != null and _env.environment != null and _env.environment.fog_enabled \
			and absf(_env.environment.fog_light_color.r - FOG_COLOR.r) < 0.01,
	}}
