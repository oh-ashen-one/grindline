extends Node3D
## layout_builder.gd — THE LEDGEWORKS park builder + measured asset adapter.
## Law 16: every piece loads by manifest id; missing files degrade to gray
## hulls sized by targetSizeMeters and flag degraded mode. Never blocks play.

const MANIFEST_PATH := "res://assets/asset-manifest.json"

# Deterministic layout (BRIEF content grammar): central plaza, mid ring,
# outer ring, grind lines. Positions in meters, degrees around Y.
const LAYOUT := [
	# id, pos, rot_y_deg
	["park-skyline", Vector3(0, 0, 0), 0],
	["park-funbox", Vector3(3.2, 0, 0), 0],
	["park-quarter_pipe", Vector3(0, 0, 18), 180],
	["park-quarter_pipe", Vector3(8, 0, -14), 0],
	["park-bank", Vector3(-10, 0, 6), 90],
	["park-kicker", Vector3(-3.9, 1.05, 0), 270],
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
	# --- street fabric (THPS reference: tracks, curbs, drains) ---
	["street-tramtrack", Vector3(-14, 0, 0), 0],
	["street-tramtrack", Vector3(17, 0, -3), 0],
	["street-curb", Vector3(-12.2, 0, -8), 90],
	["street-curb", Vector3(-12.2, 0, 0), 90],
	["street-curb", Vector3(-12.2, 0, 8), 90],
	["street-curb", Vector3(-15.8, 0, -4), 90],
	["street-curb", Vector3(-15.8, 0, 4), 90],
	["street-curb", Vector3(20.5, 0, -10), 90],
	["street-curb", Vector3(20.5, 0, -2), 90],
	["street-curb", Vector3(14.3, 0, -6), 90],
	["street-drain", Vector3(-12.2, 0, -1), 90],
	["street-drain", Vector3(-12.2, 0, 4.5), 90],
	["street-drain", Vector3(16.9, 0, -9), 0],
	["street-drain", Vector3(-4.2, 0, 10), 15],
	["street-drain", Vector3(6.2, 0, -1), 80],
	# --- street furniture ---
	["street-lamp", Vector3(-11.2, 0, -8), 180],
	["street-lamp", Vector3(-11.2, 0, 8), 180],
	["street-lamp", Vector3(19.5, 0, -4), 0],
	["street-lamp", Vector3(19.5, 0, 10), 0],
	["street-lamp", Vector3(-18.5, 0, -14), 180],
	["street-lamp", Vector3(-18.5, 0, 14), 180],
	["street-palm", Vector3(-19, 0, -4), 15],
	["street-palm", Vector3(-19, 0, 3), 200],
	["street-palm", Vector3(20.5, 0, -14), 90],
	["street-palm", Vector3(20.5, 0, 16), 250],
	["street-palm", Vector3(11, 0, 21), 300],
	["street-planter", Vector3(-16, 0, -10), 10],
	["street-planter", Vector3(-16, 0, -8.6), 80],
	["street-planter", Vector3(14, 0, 6), 0],
	["street-planter", Vector3(15.3, 0, 6.4), 45],
	["street-bench", Vector3(-13.4, 0, -2), 90],
	["street-bench", Vector3(13, 0, 12), 200],
	# --- paint: coping, ledges, grind lines ---
	["paint-red", Vector3(0, 3.06, 16.08), 0, true],
	["paint-teal", Vector3(8, 3.06, -15.92), 0, true],
	["paint-yellow", Vector3(-6.5, 0.5, -2.22), 0, true],
	["paint-teal", Vector3(-1.4, 0.03, -6), 90],
	["paint-red", Vector3(1.4, 0.03, -6), 90],
	["paint-yellow", Vector3(0, 0.03, 12.2), 0],
	# --- murals ---
	["mural-panel", Vector3(0, 0, 7.92), 180],
	["mural-panel", Vector3(-3.08, 0, 11), 90],
	["mural-panel", Vector3(10, 0, -16), 0],
	["mural-panel", Vector3(-9, 0, 16.5), 180],
	# --- cone variety ---
	["cone-red", Vector3(5.5, 0, 4), 0],
	["cone-teal", Vector3(-3.8, 0, 8.5), 0],
	["prop-cone", Vector3(10, 0, -2), 0],
	["prop-cone", Vector3(-8, 0, 10), 0],
	# --- outer-ring density (existing kit, now placed) ---
	["prop-box-long", Vector3(10, 0, 14), 15],
	["prop-box-wide", Vector3(-14, 0, 12), 40],
	["prop-hopper-round", Vector3(16, 0, -16), 0],
	["prop-piston-round", Vector3(-16, 0, 18), 0],
	["prop-pipe-large-curve", Vector3(18, 0, 2), 90],
	["prop-structure-wall", Vector3(-18, 0, -18), 30],
	["prop-structure-yellow-high", Vector3(12, 0, 20), 0],
	["prop-machine-fortified", Vector3(-15, 0, -14), 200],
	["prop-door-wide-open", Vector3(-17.5, 0, -6), 90],
	["k-obstacle-middle", Vector3(3, 0, -10), 90],
	["k-rail-low", Vector3(-4, 0, 12), 15],
	["k-structure-platform", Vector3(16, 0, 8), 270],
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
	_add_bounds()
	for entry: Array in LAYOUT:
		var node := instantiate_asset(String(entry[0]))
		if node != null:
			node.rotation.y = deg_to_rad(float(entry[2]))
			add_child(node)
			node.position = entry[1]
			# auto-ground: drop piece so its lowest point sits 2cm below the
			# floor plane — exact coplanarity z-fights ("floor seizure").
			# Optional 4th field pins y (coping strips on ramp lips).
			if entry.size() < 4 or not bool(entry[3]):
				var aabb := _combined_aabb(node)
				if aabb.size.y > 0.0:
					node.position.y -= aabb.position.y
					node.position.y -= 0.02
			_add_collision(node, String(entry[0]))

func _add_collision(node: Node3D, id: String) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).get_mesh() == null:
			continue
		(mi as MeshInstance3D).create_trimesh_collision()
	var grindy := id in ["park-rail", "park-ledge", "k-rail-high", "k-rail-low",
		"k-rail-slope", "k-rail-curve", "park-funbox", "k-obstacle-middle"]
	if grindy:
		for body in node.find_children("*", "StaticBody3D", true, false):
			body.add_to_group("grind")
			body.set_meta("rail_axis", "x" if "rail" in id or "ledge" in id else "z")
			body.set_meta("rail_len", 4.0)
			body.set_meta("top_y", node.global_position.y + 0.05)
			body.set_meta("world", true)

func _combined_aabb(node: Node3D) -> AABB:
	var total := AABB(node.position, Vector3.ZERO)
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var ab: AABB = mi.global_transform * (mi as MeshInstance3D).get_aabb()
		if first:
			total = ab
			first = false
		else:
			total = total.merge(ab)
	return total

func _add_bounds() -> void:
	for i in 4:
		var body := StaticBody3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(48, 8, 1) if i < 2 else Vector3(1, 8, 48)  # z-walls thin in z, x-walls thin in x
		body.add_child(CollisionShape3D.new())
		body.get_child(0).shape = shape
		var off := 23.5
		body.position = Vector3(0, 4, off) if i == 0 else Vector3(0, 4, -off) if i == 1 \
			else Vector3(off, 4, 0) if i == 2 else Vector3(-off, 4, 0)
		body.name = "Bounds%d" % i
		add_child(body)

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
		if id == "park-skyline":
			# backdrop: keep out of the shadow depth pass (900m pad blows the
			# shadow map range -> everything reads occluded)
			for mi in inst.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if id.begins_with("park-") and not id in ["park-rail", "park-warehouse_wall", "park-skyline"]:
			var tex: Texture2D = load("res://assets/textures/Concrete034/Concrete034_1K-JPG_Color.jpg")
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = tex
			# no normal map here: high-frequency normals shimmer/crawl at
			# distance (temporal aliasing) — albedo carries the surface read
			mat.albedo_color = Color(0.62, 0.60, 0.57)
			mat.roughness = 0.93
			mat.uv1_scale = Vector3(2.5, 2.5, 2.5)
			for mi in inst.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_override = mat
		elif id.begins_with("prop-") or id.begins_with("k-"):
			# Kenney GLBs lost their colormap in export and render bone-white;
			# paint from a curated street palette (stable per id)
			var palette: Array[Color] = [
				Color(0.856, 0.647, 0.125),  # safety yellow
				Color(0.545, 0.235, 0.157),  # rust
				Color(0.176, 0.427, 0.427),  # teal
				Color(0.235, 0.278, 0.353),  # navy steel
				Color(0.541, 0.522, 0.494),  # warm gray
				Color(0.608, 0.298, 0.235),  # brick
				Color(0.302, 0.322, 0.302),  # olive drum
			]
			var c: Color = palette[absi(hash(id)) % palette.size()]
			var pm := StandardMaterial3D.new()
			pm.albedo_color = c
			pm.roughness = 0.72
			pm.metallic = 0.25 if c.get_luminance() < 0.3 else 0.0
			for mi in inst.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_override = pm
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
