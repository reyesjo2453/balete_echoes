class_name Blockouts
## 3D models for the pixelized-CG cinematics (scripts/pixel_cg.gd). Each model has a slot:
## res://assets/models/<id>.glb. If the file is there it is used (its materials turned to the toon look); if not,
## a blockout is built here from simple shapes so the shot still plays. Blockouts are PLACEHOLDERS, listed in
## docs/ART_REQUESTS.md with the spec for the real model (Antigravity / Gemini, or any .glb).
##
## Conventions for every model: metres, Y up, origin at the feet, facing +Z (toward the camera's start), about 2 m tall
## for a person (the shot scales it up).


static func path(id: String) -> String:
	return "res://assets/models/%s.glb" % id


static func is_placeholder(id: String) -> bool:
	return not ResourceLoader.exists(path(id))


## The model `id` as a Node3D, ready to add to a PixelCG world.
static func model(id: String) -> Node3D:
	if not is_placeholder(id):
		var scene := load(path(id)) as PackedScene
		if scene != null:
			var n := scene.instantiate() as Node3D
			if n != null:
				_toonify(n)
				return n
	match id:
		"summon_pido":
			return _pido()
	var root := Node3D.new() # unknown id: a plain pillar, so the shot still has something to look at
	root.name = "blockout_" + id
	root.add_child(_mesh(_cyl(0.4, 0.4, 2.0), PixelCG.toon(Color(0.85, 0.1, 0.75)), Vector3(0, 1.0, 0)))
	return root


## A real model keeps its colours and textures but gets the toon light bands and the outline.
static func _toonify(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			var src := mi.mesh.surface_get_material(i) if mi.mesh != null else null
			var col := Color.WHITE
			var tex: Texture2D = null
			if src is BaseMaterial3D:
				col = (src as BaseMaterial3D).albedo_color
				tex = (src as BaseMaterial3D).albedo_texture
			mi.set_surface_override_material(i, PixelCG.toon(col, tex))
	for c in n.get_children():
		_toonify(c)


# --- Lolo Pido's ghost, called by TAWAG ------------------------------------------------------------------------------
# A sundô in his sixties: a long dark barong-like coat, a black panyo on the LEFT wrist, the old sundang in his right
# hand, a lantern in his left, standing on the prow of Magwayen's narrow boat. Spirit-blue, glowing at the edges.

static func _pido() -> Node3D:
	var root := Node3D.new()
	root.name = "blockout_summon_pido"
	var ghost := Color(0.55, 0.7, 0.95)
	var coat := PixelCG.toon(Color(0.16, 0.2, 0.32), null, ghost * 0.25)
	var skin := PixelCG.toon(Color(0.62, 0.68, 0.8), null, ghost * 0.3)
	var cloth := PixelCG.toon(Color(0.05, 0.05, 0.07))
	var steel := PixelCG.toon(Color(0.8, 0.86, 0.95), null, Color(0.6, 0.8, 1.0) * 0.6)
	var wood := PixelCG.toon(Color(0.24, 0.16, 0.1))
	var flame := PixelCG.toon(Color(1.0, 0.75, 0.35), null, Color(1.0, 0.6, 0.2) * 2.2)

	var body := Node3D.new()
	body.name = "Body"
	body.position = Vector3(0, 0.32, 0.4) # stands on the boat's prow
	root.add_child(body)
	body.add_child(_mesh(_cyl(0.22, 0.42, 1.05), coat, Vector3(0, 0.52, 0)))       # coat skirt
	body.add_child(_mesh(_cyl(0.26, 0.24, 0.55), coat, Vector3(0, 1.3, 0)))        # chest
	body.add_child(_mesh(_sphere(0.15), skin, Vector3(0, 1.72, 0.02)))             # head
	body.add_child(_mesh(_cyl(0.16, 0.14, 0.05), cloth, Vector3(0, 1.83, 0)))      # grey hair, combed back
	# Right arm raised with the sundang; left arm low with the lantern.
	# The sword arm pivots at the right shoulder (node "SwordArm"): the cinematic swings it for the cut.
	var sword_arm := Node3D.new()
	sword_arm.name = "SwordArm"
	sword_arm.position = Vector3(0.2, 1.55, 0.06)
	body.add_child(sword_arm)
	var r_arm := _mesh(_cyl(0.06, 0.07, 0.62), coat, Vector3(0.12, -0.13, 0.0))
	r_arm.rotation_degrees = Vector3(0, 0, 38)
	sword_arm.add_child(r_arm)
	var blade := _mesh(_box(Vector3(0.05, 0.85, 0.12)), steel, Vector3(0.42, 0.31, 0.04))
	blade.rotation_degrees = Vector3(0, 0, -12)
	sword_arm.add_child(blade)
	sword_arm.add_child(_mesh(_box(Vector3(0.07, 0.16, 0.07)), wood, Vector3(0.36, -0.09, 0.02)))   # hilt
	var l_arm := _mesh(_cyl(0.06, 0.07, 0.62), coat, Vector3(-0.3, 1.1, 0.08))
	l_arm.rotation_degrees = Vector3(0, 0, -14)
	body.add_child(l_arm)
	body.add_child(_mesh(_cyl(0.075, 0.075, 0.08), cloth, Vector3(-0.36, 0.84, 0.08)))      # the black panyo, left wrist
	var lantern := Node3D.new()
	lantern.name = "Lantern"
	lantern.position = Vector3(-0.4, 0.62, 0.14)
	body.add_child(lantern)
	lantern.add_child(_mesh(_box(Vector3(0.16, 0.2, 0.16)), wood, Vector3.ZERO))
	lantern.add_child(_mesh(_sphere(0.07), flame, Vector3.ZERO))
	var lamp := OmniLight3D.new()
	lamp.name = "LanternLight"
	lamp.light_color = Color(1.0, 0.7, 0.35)
	lamp.light_energy = 2.2
	lamp.omni_range = 4.0
	lantern.add_child(lamp)

	# Magwayen's narrow boat under him, prow toward the camera.
	var boat := Node3D.new()
	boat.name = "Boat"
	root.add_child(boat)
	boat.add_child(_mesh(_box(Vector3(0.9, 0.28, 3.4)), wood, Vector3(0, 0.14, -0.9)))
	var prow := _mesh(_box(Vector3(0.5, 0.5, 0.5)), wood, Vector3(0, 0.3, 0.85))
	prow.rotation_degrees = Vector3(45, 0, 0)
	boat.add_child(prow)
	boat.add_child(_mesh(_cyl(0.03, 0.03, 1.4), wood, Vector3(0.0, 0.9, -2.2)))           # the ferry pole
	return root


# --- shapes ----------------------------------------------------------------------------------------------------------

static func _mesh(m: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	return mi


static func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 10
	c.rings = 1
	return c


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 6
	return s


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
