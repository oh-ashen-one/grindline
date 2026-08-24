extends Node3D
## layout_builder.gd — THE LEDGEWORKS park builder + measured asset adapter.
## Law 16: every piece loads by manifest id; missing files degrade to gray
## hulls sized by targetSizeMeters and flag degraded mode. Never blocks play.

const MANIFEST_PATH := "res://assets/asset-manifest.json"

# Deterministic layout (BRIEF content grammar): central plaza, mid ring,
# outer ring, grind lines. Positions in meters, degrees around Y.
const LAYOUT := [
	# id, pos, rot_y_deg
	["k-floor-concrete", Vector3(0, 0, 0), 0],
	["k-floor-concrete", Vector3(-4, 0, -4), 0],
	["k-floor-concrete", Vector3(4, 0, -4), 180],
	["k-floor-concrete", Vector3(-4, 0, 4), 0],
	["k-floor-concrete", Vector3(4, 0, 4), 180],
	["park-funbox", Vector3(0, 0, 0), 0],
	["park-quarter_pipe", Vector3(0, 0, 18), 180],
	["park-quarter_pipe", Vector3(8, 0, -14), 0],
	["park-bank", Vector3(-10, 0, 6), 90],
	["park-kicker", Vector3(-3.5, 1.05, 0), 270],
	["park-spine", Vector3(9, 0, 7), 0],
	["park-ledge", Vector3(-6.5, 0.5, -2), 0],
	["park-rail", Vector3(0, 0.55, -6), 90],
	["k-half-pipe", Vector3(13, 0, -2), 270],
	["k-steps", Vector3(-9, 0, -8), 45],
	["k-pallet", Vector3(-2.5, 0, 5.5), 15],
	["k-obstacle-box", Vector3(6, 0, -6.5), 20],
	["prop-cone", Vector3(-4.5, 0, 2.2), 0],
	["prop-cone", Vector3(7.5, 0, 2.8), 0],
	["prop-box-large", Vector3(-11, 0, 0), 30],
	["prop-box-small", Vector3(-11.8, 0, 1.2), 75],
	["prop-machine", Vector3(-12, 0, 10), 270],
	["prop-warning-traffic", Vector3(11, 0, 3), 0],
]

var loaded := 0
var missing := 0
var degraded := false
var _registry: Dictionary = {}

func _ready() -> void:
	add_to_group("qa_state")
	build()

func build() -> void:
	_load_registry()
	for entry: Array in LAYOUT:
		var node := instantiate_asset(String(entry[0]))
		if node != null:
			node.position = entry[1]
			node.rotation.y = deg_to_rad(float(entry[2]))
			add_child(node)

func _load_registry() -> void:
	if not _registry.is_empty():
		return
	var txt := FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("assets"):
		return
	var hidden_raw := OS.get_environment("ADAPTER_HIDE")
	var hidden: PackedStringArray = hidden_raw.split(",") if hidden_raw != "" else PackedStringArray()
	for a: Dictionary in parsed["assets"]:
		_registry[String(a["id"])] = a
	for hid in hidden:
		_registry.erase(String(hid))

func instantiate_asset(id: String) -> Node3D:
	var a: Dictionary = _registry.get(id, {})
	if a.is_empty():
		degraded = true
		missing += 1
		return _hull(Vector3(0.5, 0.5, 0.5))
	var res_path: String = "res://" + String(a.get("path", "")).trim_prefix("assets/")
	var full := "res://assets/" + String(a.get("path", "")).trim_prefix("assets/")
	res_path = full
	if not ResourceLoader.exists(res_path):
		degraded = true
		missing += 1
		var size: Array = a.get("targetSizeMeters", [0.5, 0.5, 0.5])
		return _hull(Vector3(size[0], size[1], size[2]))
	if res_path.ends_with(".glb"):
		var packed: PackedScene = load(res_path)
		if packed == null:
			degraded = true
			missing += 1
			return _hull(Vector3.ONE)
		loaded += 1
		var inst := packed.instantiate()
		inst.name = "Asset_" + id
		if id.begins_with("park-") and not id in ["park-rail", "park-warehouse_wall"]:
			var tex: Texture2D = load("res://assets/textures/Concrete034/Concrete034_1K-JPG_Color.jpg")
			var nrm: Texture2D = load("res://assets/textures/Concrete034/Concrete034_1K-JPG_NormalGL.jpg")
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = tex
			mat.normal_enabled = true
			mat.normal_texture = nrm
			mat.albedo_color = Color(0.62, 0.60, 0.57)
			mat.roughness = 0.93
			mat.uv1_scale = Vector3(2.5, 2.5, 2.5)
			for mi in inst.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_override = mat
		return inst
	loaded += 1  # textures/audio verified present via ResourceLoader check
	return null

func _hull(size: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size.max(Vector3(0.05, 0.05, 0.05))
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.52)
	mesh.material = mat
	return mi

func clip_report() -> Dictionary:
	print("CLIPREPORT called on ", name, " scene=", get_tree().current_scene.name if get_tree() else "none")
	var out := {"idle": false, "run": false, "jump": false, "roll": false}
	var scene := get_tree().current_scene if get_tree() else null
	var skater := scene.find_child("Skater", true, false) if scene else null
	var visual := skater.get_node_or_null("Visual") if skater else null
	if OS.get_environment("GL_DEBUG") != "":
		print("CLIP skater=%s visual=%s" % [skater, visual])
		if visual != null:
			for c in visual.get_children():
				print("  child: ", c.name, " (", c.get_class(), ")")
	if visual == null:
		return out
	for ap: AnimationPlayer in visual.find_children("*", "AnimationPlayer", true, false):
		for anim_name in ap.get_animation_list():
			var lower := String(anim_name).to_lower()
			for key: String in out.keys():
				if lower.contains(key):
					out[key] = true
	return out

func get_qa_dict() -> Dictionary:
	return {"adapter": {"loaded": loaded, "missing": missing, "degraded": degraded}}
