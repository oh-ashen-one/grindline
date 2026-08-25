extends Node
## light_rig.gd — the golden-hour look (THPS 1+2 PS5 reference grade).
## Builds/owns WorldEnvironment + sun so every scene gets identical light.
## QA: env_report probe reads back live values.
## NOTE: SUN_PITCH/SUN_ENERGY/FOG_COLOR.r are pinned by tests_staged
## (test_us201_lighting) — keep within tolerance.

const SUN_PITCH_DEG := -38.0     # pinned by US-201 (±1)
const SUN_AZIMUTH_DEG := 37.0    # sun behind camera-right: hero lit from our
                                 # side, long shadows raking left across view
const SUN_ENERGY := 1.0          # pinned by US-201 (±0.05)
const SUN_COLOR := Color(1.0, 0.823529, 0.615686)   # warm low-sun key #ffd69d
const FOG_COLOR := Color(0.91, 0.729412, 0.529412)  # r pinned by US-201 (±0.01)
const FOG_NEAR := 45.0
const FOG_FAR := 120.0

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
	# golden-hour: hazy mauve zenith falling to a deep amber horizon
	mat.sky_top_color = Color(0.372549, 0.313725, 0.372549)      # #5f505f smoggy mauve-gray
	mat.sky_horizon_color = Color(0.878431, 0.623529, 0.4) # #e09f66 hazy tan-amber
	mat.sky_curve = 0.16
	mat.ground_bottom_color = Color(0.16, 0.12, 0.11)
	mat.ground_horizon_color = Color(0.858824, 0.588235, 0.388235)
	mat.sun_angle_max = 30.0
	mat.sun_curve = 0.08
	sky.sky_material = mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.fog_enabled = true
	e.fog_light_color = FOG_COLOR
	e.fog_density = 0.006
	e.fog_aerial_perspective = 0.62
	e.fog_sky_affect = 0.22
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 0.98
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_sky_contribution = 1.0
	e.ambient_light_energy = 1.05
	e.ssao_enabled = true
	e.ssao_intensity = 2.2
	e.ssao_radius = 0.9
	e.glow_enabled = true
	e.glow_intensity = 0.28
	e.glow_bloom = 0.06
	e.glow_hdr_threshold = 1.05
	_env.environment = e
	add_child(_env)

	# TRAP (learned 2026-08-24): DirectionalLight3D created in _ready here is
	# INERT — zero diffuse contribution (env/fog/ambient from the same script
	# work). The sun must be a scene-file node; adopt it, create only as
	# fallback for scenes that lack one.
	_sun = get_parent().get_node_or_null("Sun") as DirectionalLight3D
	if _sun == null:
		_sun = DirectionalLight3D.new()
		_sun.name = "Sun"
		add_child(_sun)
	_sun.rotation = Vector3(deg_to_rad(SUN_PITCH_DEG), deg_to_rad(SUN_AZIMUTH_DEG), 0)
	_sun.light_color = SUN_COLOR
	_sun.light_energy = 1.0
	_sun.shadow_enabled = true
	_sun.shadow_bias = 0.03
	_sun.shadow_normal_bias = 2.2
	_sun.shadow_blur = 1.5
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun.directional_shadow_max_distance = 70.0
	_sun.directional_shadow_split_1 = 0.08
	_sun.directional_shadow_split_2 = 0.22
	_sun.directional_shadow_split_3 = 0.55
	_sun.directional_shadow_blend_splits = true
	_sun.directional_shadow_fade_start = 0.85

	# warm no-shadow fill lifts ramp faces turned away from the key light
	# (script-created lights are inert ONLY when shadowed on this setup)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(1.0, 0.85, 0.68)
	fill.light_energy = 0.5
	fill.rotation = Vector3(deg_to_rad(-24.0), deg_to_rad(205.0), 0)
	fill.shadow_enabled = false
	add_child(fill)

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
