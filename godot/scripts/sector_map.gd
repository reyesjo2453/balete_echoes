class_name SectorMap
extends Control
## Playable HD-2D Metro Manila overworld diorama (inspired by Final Fantasy Resonance):
## Teo walks (or rides Kardo's tricycle) through a stylized nocturnal miniature of Quiapo & the Pasig River,
## with visible outer Manila districts (LRT-1 viaduct, Quiapo Church, Binondo Arch, Intramuros, Makati skyline)
## across curfew barricades, inspectable side stops, mobile tap-to-walk, and Quick-Hop fast travel.

signal finished

const NODES := {
	"parlor": {"name": "DIMACULANGAN PARLOR", "sub": "24-Hour Wake", "at": Vector3(-10.2, 0.0, 2.2), "col": Color("d8c89e")},
	"hidalgo": {"name": "HIDALGO STREET", "sub": "Under the Balete", "at": Vector3(-4.2, 0.0, 0.8), "col": Color("b89674")},
	"quiapo_alley": {"name": "QUIAPO ALLEY", "sub": "Shuttered Shops", "at": Vector3(1.2, 0.0, -1.0), "col": Color("8e746a")},
	"estero": {"name": "ESTERO DE QUIAPO", "sub": "Sunken Creek", "at": Vector3(6.2, 0.0, -3.2), "col": Color("548692")},
	"pumphouse": {"name": "PUMPHOUSE", "sub": "Floodgate Station", "at": Vector3(10.6, 0.0, -5.0), "col": Color("647a84")},
	"service_alley": {"name": "SERVICE ALLEY", "sub": "Behind the Parlor", "at": Vector3(-0.4, 0.0, 4.2), "col": Color("7d746e")},
	"morgue": {"name": "QUIAPO MORGUE", "sub": "Basement Cold Room", "at": Vector3(7.4, 0.0, 4.8), "col": Color("688ca0")},
}

const EDGES := [
	["parlor", "hidalgo"],
	["hidalgo", "quiapo_alley"],
	["quiapo_alley", "estero"],
	["estero", "pumphouse"],
	["hidalgo", "service_alley"],
	["service_alley", "morgue"],
]

const SIDE_STOPS := [
	{
		"id": "plaza_candles",
		"name": "Plaza Miranda Candle Stall",
		"at": Vector3(-3.8, 0.0, -3.4),
		"lore": "Sampaguita and red vigil candles burn through the brownout. Someone pinned a handwritten prayer for the missing along the estero.",
	},
	{
		"id": "sari_sari",
		"name": "Night Sari-Sari Stall",
		"at": Vector3(-7.4, 0.0, 3.8),
		"lore": "A lone fluorescent tube hums over sachets and warm bottles. The pocket radio crackles with a late-night flood advisory for Quiapo.",
	},
	{
		"id": "quezon_bridge",
		"name": "Quezon Bridge Lookout",
		"at": Vector3(1.8, 0.0, 6.0),
		"lore": "Black Pasig water slides beneath the steel arches. Across the river, Intramuros's old walls sit in shadow while Makati's towers blink through the haze.",
	},
	{
		"id": "lrt_underpass",
		"name": "Carriedo LRT-1 Underpass",
		"at": Vector3(-10.8, 0.0, -2.2),
		"lore": "A late northbound train rumbles along the viaduct, shaking loose dust and faded posters. Amber curfew barricades seal off Avenida for the night.",
	},
	{
		"id": "estero_culvert",
		"name": "Estero Drainage Culvert",
		"at": Vector3(4.0, 0.0, -1.8),
		"lore": "A rusted Hiraya padlock hangs open on the iron grate. Cold creek air rises from beneath the wet asphalt.",
	},
]

const BOUNDS_MIN := Vector2(-12.2, -6.2)
const BOUNDS_MAX := Vector2(11.8, 6.4)
const WALK_SPEED := 4.6
const TRIKE_SPEED := 8.4

var beat: Dictionary = {}
var fast := false

var _from_id := "hidalgo"
var _to_id := "estero"
var _via: Array[String] = []
var _done := false
var _t := 0.0
var _fast_timer := 0.0

var _vp: SubViewport
var _cam: Camera3D
var _world: Node3D
var _teo: Sprite3D
var _teo_pos := Vector3(-4.2, 0.0, 0.8)
var _teo_dir := 0 # 0=down, 1=side, 2=up
var _teo_flip := false
var _teo_frame := 1
var _teo_frame_t := 0.0
var _trike_mode := false
var _trike_glow: OmniLight3D
var _tap_target := Vector3.ZERO
var _has_tap_target := false
var _tap_ring: MeshInstance3D

var _lrt_train: Node3D
var _dest_beacon: MeshInstance3D
var _dest_ring: MeshInstance3D
var _side_beacons: Dictionary = {}
var _visited_stops: Dictionary = {}
var _nearby_stop: Dictionary = {}
var _near_dest := false

var _banner: Label
var _sub: Label
var _prompt_box: PanelContainer
var _prompt_lbl: Label
var _lore_box: PanelContainer
var _lore_title: Label
var _lore_body: Label
var _trike_btn: Button
var _hop_btn: Button
var _label_layer: Control
var _world_labels: Array = [] # [{pos: Vector3, label: Label, color: Color}]
var _water_mat: ShaderMaterial


func setup(p_beat: Dictionary) -> void:
	beat = p_beat
	_from_id = String(beat.get("from", "hidalgo"))
	_to_id = String(beat.get("to", "estero"))
	_via.clear()
	for v in beat.get("via", []):
		var vid := String(v)
		if NODES.has(vid):
			_via.append(vid)
	if NODES.has(_from_id):
		_teo_pos = NODES[_from_id]["at"]
	else:
		_teo_pos = Vector3(-4.2, 0.0, 0.8)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0.025, 0.035, 0.065, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_3d_viewport()
	_build_hud()
	_update_camera(1.0)
	_update_world_labels()


func _build_3d_viewport() -> void:
	var svc := SubViewportContainer.new()
	svc.name = "OverworldView"
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)

	_vp = SubViewport.new()
	_vp.name = "OverworldVP"
	_vp.handle_input_locally = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.size = Vector2i(1280, 720)
	svc.add_child(_vp)

	_world = Node3D.new()
	_world.name = "ManilaWorld"
	_vp.add_child(_world)

	# Nocturnal Manila lighting & tilt-shift HD-2D atmosphere
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.045, 0.085)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.24, 0.30, 0.44)
	env.ambient_light_energy = 0.72
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.09, 0.16)
	env.fog_density = 0.016
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	we.environment = env
	_world.add_child(we)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.62, 0.74, 0.96)
	moon.light_energy = 0.85
	moon.rotation_degrees = Vector3(-48, -28, 0)
	moon.shadow_enabled = true
	_world.add_child(moon)

	_cam = Camera3D.new()
	_cam.name = "OverworldCam"
	_cam.fov = 34.0
	_cam.near = 0.2
	_cam.far = 120.0
	_cam.current = true
	_world.add_child(_cam)
	RenderTier.dress(env, we, {"fog": 0.014, "fog_color": "6a7898"})

	_build_manila_terrain()
	_build_playable_landmarks()
	_build_outer_manila_skyline()
	_build_side_stops()
	_build_teo_avatar()


func _mat(col: Color, rough: float = 0.88, emit: Color = Color.BLACK, emit_e: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if emit_e > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = emit_e
	return m


func _box_node(sz: Vector3, at: Vector3, mat: Material, rot_y: float = 0.0, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	mi.rotation_degrees.y = rot_y
	(parent if parent != null else _world).add_child(mi)
	return mi


func _build_manila_terrain() -> void:
	# Wet nocturnal asphalt ground plane
	var ground_m := _mat(Color(0.085, 0.095, 0.125), 0.42)
	_box_node(Vector3(56.0, 0.2, 42.0), Vector3(0.0, -0.1, 2.0), ground_m)

	# Pasig River & Estero de Quiapo animated water shader
	var wsh := Shader.new()
	wsh.code = """
shader_type spatial;
uniform float t = 0.0;
void fragment() {
	float w = sin(UV.x * 26.0 + t * 1.4) * 0.5 + cos(UV.y * 18.0 - t * 1.1) * 0.5;
	vec3 deep = vec3(0.035, 0.085, 0.135);
	vec3 glint = vec3(0.11, 0.23, 0.30);
	ALBEDO = mix(deep, glint, smoothstep(0.2, 0.95, w * 0.5 + 0.5));
	ROUGHNESS = 0.18;
	SPECULAR = 0.8;
}
"""
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = wsh

	# Pasig River curving across the south (z = 8.8)
	_box_node(Vector3(54.0, 0.06, 4.6), Vector3(0.0, 0.01, 9.0), _water_mat)
	# Estero de Quiapo creek running diagonally toward pumphouse
	_box_node(Vector3(14.0, 0.06, 1.35), Vector3(7.4, 0.015, -3.5), _water_mat, 22.0)

	# Lit Manila road network connecting all playable Quiapo nodes
	var road_m := _mat(Color(0.15, 0.165, 0.21), 0.35)
	var line_m := _mat(Color(0.85, 0.72, 0.36), 0.5, Color(0.9, 0.72, 0.3), 0.45)
	for e in EDGES:
		var a: Vector3 = NODES[e[0]]["at"]
		var b: Vector3 = NODES[e[1]]["at"]
		var mid := (a + b) * 0.5
		var delta := b - a
		var dist := delta.length()
		var yaw := rad_to_deg(atan2(delta.x, delta.z))
		_box_node(Vector3(1.55, 0.03, dist + 0.8), Vector3(mid.x, 0.015, mid.z), road_m, yaw)
		_box_node(Vector3(0.08, 0.035, dist), Vector3(mid.x, 0.02, mid.z), line_m, yaw)

	# Quezon Blvd north-south artery + Plaza Miranda apron + Quezon Bridge deck
	_box_node(Vector3(2.2, 0.03, 15.0), Vector3(-2.0, 0.014, 1.0), road_m)
	_box_node(Vector3(5.6, 0.035, 3.8), Vector3(-4.0, 0.016, -4.4), _mat(Color(0.19, 0.18, 0.22), 0.55))

	# Quezon Bridge over Pasig River
	var steel_m := _mat(Color(0.24, 0.28, 0.34), 0.5)
	_box_node(Vector3(2.4, 0.18, 5.4), Vector3(1.8, 0.14, 9.0), road_m)
	for sx in [-1.15, 1.15]:
		_box_node(Vector3(0.16, 0.95, 5.2), Vector3(1.8 + sx, 0.62, 9.0), steel_m)

	# Warm sodium streetlamps along the main Quiapo corridor
	var pole_m := _mat(Color(0.14, 0.16, 0.20), 0.7)
	var bulb_m := _mat(Color(1.0, 0.86, 0.54), 0.2, Color(1.0, 0.76, 0.36), 2.4)
	var lamp_pts := [
		Vector3(-9.2, 0, 1.2), Vector3(-5.0, 0, 1.6), Vector3(-1.8, 0, -0.4),
		Vector3(3.4, 0, -2.0), Vector3(8.2, 0, -4.2), Vector3(3.2, 0, 4.6),
		Vector3(-3.2, 0, -3.0), Vector3(1.8, 0, 6.6),
	]
	for lp in lamp_pts:
		_box_node(Vector3(0.08, 1.45, 0.08), lp + Vector3(0, 0.72, 0), pole_m)
		_box_node(Vector3(0.18, 0.12, 0.18), lp + Vector3(0, 1.46, 0), bulb_m)
		var l := OmniLight3D.new()
		l.position = lp + Vector3(0, 1.42, 0)
		l.light_color = Color(1.0, 0.78, 0.42)
		l.light_energy = 1.15
		l.omni_range = 4.6
		_world.add_child(l)

	# Glowing amber curfew / flood barricades at the playable Quiapo perimeter
	var bar_m := _mat(Color(0.86, 0.48, 0.14), 0.4, Color(1.0, 0.56, 0.14), 1.4)
	var barricades := [
		[Vector3(-12.6, 0.25, 1.8), 90.0],
		[Vector3(-12.6, 0.25, -2.2), 90.0],
		[Vector3(1.8, 0.25, 6.8), 0.0],
		[Vector3(-6.2, 0.25, 6.8), 0.0],
		[Vector3(12.2, 0.25, -4.8), 90.0],
	]
	for bd in barricades:
		_box_node(Vector3(2.2, 0.42, 0.22), bd[0], bar_m, bd[1])


func _build_playable_landmarks() -> void:
	var roof_m := _mat(Color(0.22, 0.16, 0.18), 0.8)
	var win_warm := _mat(Color(1.0, 0.86, 0.54), 0.2, Color(1.0, 0.76, 0.36), 1.6)
	var win_cold := _mat(Color(0.54, 0.88, 0.96), 0.2, Color(0.45, 0.85, 0.95), 1.4)

	for id in NODES:
		var info: Dictionary = NODES[id]
		var pos: Vector3 = info["at"]
		var col: Color = info["col"]
		var b_mat := _mat(col.darkened(0.42), 0.82)
		var is_dest: bool = (String(id) == _to_id)

		# Distinctive miniature building silhouette per Quiapo location
		var b_off := Vector3(0.0, 0.0, -1.1)
		match id:
			"parlor":
				_box_node(Vector3(2.4, 1.45, 1.6), pos + Vector3(-0.3, 0.72, -1.1), b_mat)
				_box_node(Vector3(2.55, 0.18, 1.75), pos + Vector3(-0.3, 1.52, -1.1), roof_m)
				_box_node(Vector3(0.7, 0.65, 0.08), pos + Vector3(-0.3, 0.42, -0.28), win_warm)
			"hidalgo":
				_box_node(Vector3(2.2, 1.25, 1.2), pos + Vector3(-0.6, 0.62, -1.2), b_mat)
				# Iconic Balete tree beside Hidalgo St
				_box_node(Vector3(0.35, 1.35, 0.35), pos + Vector3(1.1, 0.68, -0.8), _mat(Color(0.18, 0.14, 0.11)))
				_box_node(Vector3(1.65, 1.05, 1.55), pos + Vector3(1.1, 1.58, -0.8), _mat(Color(0.08, 0.18, 0.12), 0.92))
			"quiapo_alley":
				_box_node(Vector3(1.2, 1.15, 1.1), pos + Vector3(-0.7, 0.58, -1.1), b_mat)
				_box_node(Vector3(1.2, 1.35, 1.1), pos + Vector3(0.7, 0.68, -1.1), b_mat)
				_box_node(Vector3(2.5, 0.1, 0.5), pos + Vector3(0.0, 0.85, -0.45), _mat(Color(0.56, 0.18, 0.16)))
			"estero":
				_box_node(Vector3(2.0, 0.26, 0.9), pos + Vector3(0.0, 0.2, -0.4), _mat(Color(0.28, 0.24, 0.20)))
				_box_node(Vector3(1.5, 1.1, 1.1), pos + Vector3(-1.0, 0.55, -1.3), b_mat)
			"pumphouse":
				_box_node(Vector3(2.4, 1.7, 1.6), pos + Vector3(0.4, 0.85, -1.0), b_mat)
				_box_node(Vector3(0.32, 2.5, 0.32), pos + Vector3(1.3, 1.25, -1.5), _mat(Color(0.22, 0.26, 0.30)))
				_box_node(Vector3(0.9, 0.45, 0.08), pos + Vector3(0.4, 1.1, -0.18), win_cold)
			"service_alley":
				_box_node(Vector3(1.8, 1.1, 1.1), pos + Vector3(-0.4, 0.55, -1.0), b_mat)
				_box_node(Vector3(0.45, 0.55, 0.45), pos + Vector3(0.9, 0.28, -0.7), _mat(Color(0.20, 0.28, 0.22)))
			"morgue":
				_box_node(Vector3(2.5, 1.35, 1.7), pos + Vector3(0.3, 0.68, -1.1), b_mat)
				_box_node(Vector3(1.1, 0.42, 0.08), pos + Vector3(0.3, 0.72, -0.22), win_cold)

		# Ground pad marker + golden destination beacon
		var pad_col := Color("f2c864") if is_dest else Color(0.55, 0.72, 0.88)
		var pad_m := _mat(pad_col, 0.3, pad_col, 1.6 if is_dest else 0.45)
		var pad := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.78 if is_dest else 0.52
		cyl.bottom_radius = cyl.top_radius
		cyl.height = 0.04
		pad.mesh = cyl
		pad.material_override = pad_m
		pad.position = pos + Vector3(0, 0.035, 0)
		_world.add_child(pad)

		if is_dest:
			_dest_ring = pad
			var beam := MeshInstance3D.new()
			var bc := CylinderMesh.new()
			bc.top_radius = 0.14
			bc.bottom_radius = 0.32
			bc.height = 2.6
			beam.mesh = bc
			var bm := _mat(Color(1.0, 0.84, 0.38, 0.55), 0.2, Color(1.0, 0.82, 0.35), 2.2)
			bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			beam.material_override = bm
			beam.position = pos + Vector3(0, 1.35, 0)
			_world.add_child(beam)
			_dest_beacon = beam

		_register_world_label(pos + Vector3(0, 2.05, b_off.z * 0.4), String(info["name"]), Color("ffe28a") if is_dest else Color(0.84, 0.89, 0.96, 0.82))


func _build_outer_manila_skyline() -> void:
	# Quiapo Church (Minor Basilica) & Plaza Miranda north of Hidalgo
	var church_m := _mat(Color(0.52, 0.44, 0.36), 0.78)
	var dome_m := _mat(Color(0.36, 0.30, 0.28), 0.7)
	var church_pos := Vector3(-4.0, 0.0, -7.2)
	_box_node(Vector3(4.2, 2.2, 2.6), church_pos + Vector3(0, 1.1, 0), church_m)
	_box_node(Vector3(0.95, 3.4, 0.95), church_pos + Vector3(-1.7, 1.7, 0.7), church_m)
	_box_node(Vector3(0.95, 3.4, 0.95), church_pos + Vector3(1.7, 1.7, 0.7), church_m)
	_box_node(Vector3(1.7, 1.1, 1.7), church_pos + Vector3(0, 2.6, -0.2), dome_m)
	_register_world_label(church_pos + Vector3(0, 3.9, 0), "QUIAPO CHURCH · PLAZA MIRANDA", Color(0.82, 0.78, 0.68, 0.72))

	# LRT-1 Elevated Viaduct along Rizal Ave (west edge) + moving lit train
	var conc_m := _mat(Color(0.22, 0.24, 0.28), 0.85)
	_box_node(Vector3(1.5, 0.32, 34.0), Vector3(-14.6, 2.35, 0.0), conc_m)
	for z in range(-12, 14, 4):
		_box_node(Vector3(0.55, 2.35, 0.55), Vector3(-14.6, 1.17, float(z)), conc_m)
	_lrt_train = Node3D.new()
	_lrt_train.name = "LRT1Train"
	_lrt_train.position = Vector3(-14.6, 2.82, -8.0)
	_world.add_child(_lrt_train)
	var car_m := _mat(Color(0.72, 0.76, 0.82), 0.4)
	var car_win := _mat(Color(1.0, 0.90, 0.62), 0.2, Color(1.0, 0.86, 0.52), 2.2)
	for idx in 3:
		var z_off := float(idx - 1) * 2.4
		_box_node(Vector3(0.85, 0.62, 2.1), Vector3(0, 0, z_off), car_m, 0.0, _lrt_train)
		_box_node(Vector3(0.90, 0.22, 1.75), Vector3(0, 0.06, z_off), car_win, 0.0, _lrt_train)

	# Binondo Chinatown Arch (west beyond curfew barricade)
	var arch_m := _mat(Color(0.58, 0.14, 0.14), 0.7)
	var gold_m := _mat(Color(0.88, 0.68, 0.24), 0.4, Color(0.95, 0.74, 0.26), 0.7)
	_box_node(Vector3(0.32, 2.2, 0.32), Vector3(-17.4, 1.1, 1.0), arch_m)
	_box_node(Vector3(0.32, 2.2, 0.32), Vector3(-17.4, 1.1, 3.6), arch_m)
	_box_node(Vector3(0.55, 0.48, 3.4), Vector3(-17.4, 2.35, 2.3), gold_m)
	_register_world_label(Vector3(-17.4, 3.1, 2.3), "BINONDO (CURFEW)", Color(0.88, 0.62, 0.48, 0.68))

	# Intramuros stone walls across Pasig River (south)
	var wall_m := _mat(Color(0.24, 0.23, 0.21), 0.92)
	_box_node(Vector3(11.5, 1.45, 2.4), Vector3(-6.2, 0.72, 13.4), wall_m)
	_box_node(Vector3(2.2, 1.9, 2.2), Vector3(-1.2, 0.95, 13.2), wall_m)
	_register_world_label(Vector3(-6.2, 2.2, 13.2), "INTRAMUROS", Color(0.72, 0.76, 0.84, 0.68))

	# Distant Makati / BGC night skyline across Pasig River (southeast)
	var tower_m := _mat(Color(0.11, 0.14, 0.22), 0.5)
	var red_dot := _mat(Color(1.0, 0.22, 0.22), 0.2, Color(1.0, 0.2, 0.2), 2.5)
	var win_sky := _mat(Color(0.75, 0.86, 1.0), 0.2, Color(0.65, 0.80, 1.0), 0.95)
	var towers := [
		[Vector3(10.0, 0, 14.2), Vector3(1.8, 5.2, 1.8)],
		[Vector3(12.4, 0, 14.8), Vector3(2.0, 6.8, 1.9)],
		[Vector3(15.0, 0, 13.8), Vector3(1.7, 5.8, 1.7)],
		[Vector3(17.4, 0, 14.6), Vector3(2.1, 7.6, 2.0)],
		[Vector3(19.8, 0, 13.6), Vector3(1.6, 4.9, 1.6)],
	]
	for tw in towers:
		var tp: Vector3 = tw[0]
		var ts: Vector3 = tw[1]
		_box_node(ts, tp + Vector3(0, ts.y * 0.5, 0), tower_m)
		_box_node(Vector3(ts.x * 0.82, ts.y * 0.65, 0.08), tp + Vector3(0, ts.y * 0.55, -ts.z * 0.51), win_sky)
		_box_node(Vector3(0.16, 0.16, 0.16), tp + Vector3(0, ts.y + 0.12, 0), red_dot)
	_register_world_label(Vector3(14.5, 7.8, 14.2), "MAKATI SKYLINE", Color(0.68, 0.78, 0.92, 0.62))


func _build_side_stops() -> void:
	for s in SIDE_STOPS:
		var sid := String(s["id"])
		var pos: Vector3 = s["at"]
		var m := _mat(Color("66e0ff"), 0.25, Color("48c8f0"), 1.5)
		var b := _box_node(Vector3(0.32, 0.32, 0.32), pos + Vector3(0, 0.65, 0), m, 45.0)
		b.rotation_degrees.x = 35.0
		_side_beacons[sid] = b


func _build_teo_avatar() -> void:
	var strip_path := "res://assets/explore/teo_walk.png"
	var tex := load(strip_path) as Texture2D if ResourceLoader.exists(strip_path) else null
	var spr := Sprite3D.new()
	spr.name = "RouteTeo"
	if tex != null:
		spr.texture = tex
		spr.hframes = 12
		spr.frame = 1
		spr.pixel_size = 1.45 / float(tex.get_height())
		spr.offset = Vector2(0, tex.get_height() * 0.5)
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	spr.position = _teo_pos + Vector3(0, 0.04, 0)
	_world.add_child(spr)
	_teo = spr

	# Warm headlight glow for Tricycle boost mode
	_trike_glow = OmniLight3D.new()
	_trike_glow.name = "TrikeGlow"
	_trike_glow.light_color = Color(1.0, 0.86, 0.48)
	_trike_glow.light_energy = 0.0
	_trike_glow.omni_range = 4.2
	_trike_glow.position = Vector3(0, 0.7, 0.4)
	_teo.add_child(_trike_glow)

	# Tap-to-walk ground marker ring
	var rm := _mat(Color("ffe084"), 0.2, Color("f8c852"), 1.8)
	_tap_ring = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.38
	cyl.bottom_radius = 0.38
	cyl.height = 0.03
	_tap_ring.mesh = cyl
	_tap_ring.material_override = rm
	_tap_ring.visible = false
	_world.add_child(_tap_ring)


func _build_hud() -> void:
	_label_layer = Control.new()
	_label_layer.name = "WorldLabels"
	_label_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label_layer)

	# Top-left district & objective banner
	var top := Retro.window(16, 10)
	top.position = Vector2(24, 20)
	top.custom_minimum_size = Vector2(470, 0)
	add_child(top)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	top.add_child(col)
	_banner = Label.new()
	_banner.text = String(beat.get("title", "METRO MANILA · QUIAPO SECTOR")).to_upper()
	_banner.add_theme_font_override("font", Fonts.display())
	_banner.add_theme_font_size_override("font_size", 21)
	_banner.add_theme_color_override("font_color", Color("f4d482"))
	col.add_child(_banner)
	var dest_name := String(NODES.get(_to_id, {}).get("name", _to_id.to_upper()))
	_sub = Label.new()
	_sub.text = String(beat.get("line", "Head to %s · Explore Quiapo or Quick-Hop" % dest_name))
	_sub.add_theme_font_override("font", Fonts.body())
	_sub.add_theme_font_size_override("font_size", 14)
	_sub.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 0.92))
	col.add_child(_sub)

	# Top-right FF Resonance-style Quick-Hop & Tricycle toolbar
	var tools := HBoxContainer.new()
	tools.name = "OverworldTools"
	tools.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tools.offset_left = -430
	tools.offset_right = -24
	tools.offset_top = 20
	tools.offset_bottom = 64
	tools.alignment = BoxContainer.ALIGNMENT_END
	tools.add_theme_constant_override("separation", 10)
	add_child(tools)

	_trike_btn = Button.new()
	_trike_btn.name = "TrikeToggle"
	_trike_btn.text = "TRICYCLE: OFF"
	_trike_btn.custom_minimum_size = Vector2(155, 38)
	Retro.style_button(_trike_btn, 14)
	_trike_btn.pressed.connect(toggle_tricycle)
	tools.add_child(_trike_btn)

	_hop_btn = Button.new()
	_hop_btn.name = "QuickHopButton"
	_hop_btn.text = "QUICK-HOP: %s" % dest_name
	_hop_btn.custom_minimum_size = Vector2(230, 38)
	Retro.style_button(_hop_btn, 14)
	_hop_btn.pressed.connect(func() -> void: quick_hop(_to_id))
	tools.add_child(_hop_btn)

	# Bottom-center interaction prompt pill
	_prompt_box = Retro.window(16, 8)
	_prompt_box.name = "InteractPrompt"
	_prompt_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_box.offset_left = -240
	_prompt_box.offset_right = 240
	_prompt_box.offset_top = -108
	_prompt_box.offset_bottom = -64
	_prompt_box.visible = false
	add_child(_prompt_box)
	_prompt_lbl = Label.new()
	_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_lbl.add_theme_font_override("font", Fonts.label_medium())
	_prompt_lbl.add_theme_font_size_override("font_size", 16)
	_prompt_lbl.add_theme_color_override("font_color", Color("ffe496"))
	_prompt_box.add_child(_prompt_lbl)

	# Bottom lore pop-up card for inspectable side stops
	_lore_box = Retro.window(18, 12)
	_lore_box.name = "SideStopLore"
	_lore_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_lore_box.offset_left = -360
	_lore_box.offset_right = 360
	_lore_box.offset_top = -196
	_lore_box.offset_bottom = -72
	_lore_box.visible = false
	add_child(_lore_box)
	var lcol := VBoxContainer.new()
	lcol.add_theme_constant_override("separation", 4)
	_lore_box.add_child(lcol)
	_lore_title = Label.new()
	_lore_title.add_theme_font_override("font", Fonts.display())
	_lore_title.add_theme_font_size_override("font_size", 18)
	_lore_title.add_theme_color_override("font_color", Color("8ce8ff"))
	lcol.add_child(_lore_title)
	_lore_body = Label.new()
	_lore_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lore_body.add_theme_font_override("font", Fonts.body())
	_lore_body.add_theme_font_size_override("font_size", 15)
	_lore_body.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
	lcol.add_child(_lore_body)

	var hint := Label.new()
	hint.text = "WASD / Arrows / Tap ground to travel · Shift: Tricycle · E / Enter: Inspect"
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -34
	hint.offset_bottom = -10
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", Fonts.label_medium())
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.76, 0.82, 0.92, 0.78))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)


func _register_world_label(pos: Vector3, text: String, col: Color) -> void:
	_world_labels.append({"pos": pos, "text": text, "col": col, "label": null})


func toggle_tricycle() -> void:
	_trike_mode = not _trike_mode
	if _trike_btn != null:
		_trike_btn.text = "TRICYCLE: ON" if _trike_mode else "TRICYCLE: OFF"
	if _trike_glow != null:
		_trike_glow.light_energy = 1.6 if _trike_mode else 0.0
	if not fast:
		Sfx.ui_move()


func quick_hop(node_id: String) -> void:
	if _done or not NODES.has(node_id):
		return
	_teo_pos = NODES[node_id]["at"]
	_has_tap_target = false
	if _teo != null:
		_teo.position = _teo_pos + Vector3(0, 0.04, 0)
	if node_id == _to_id:
		_finish()


func inspect_side_stop(stop_id: String) -> bool:
	for s in SIDE_STOPS:
		if String(s["id"]) == stop_id:
			_visited_stops[stop_id] = true
			if _side_beacons.has(stop_id):
				var b: MeshInstance3D = _side_beacons[stop_id]
				b.material_override = _mat(Color(0.35, 0.45, 0.55), 0.7)
			if _lore_box != null:
				_lore_title.text = String(s["name"]).to_upper()
				_lore_body.text = String(s["lore"])
				_lore_box.visible = true
			if not fast:
				Sfx.ui_confirm()
			return true
	return false


func _finish() -> void:
	if _done:
		return
	_done = true
	if not fast:
		Sfx.ui_confirm()
	finished.emit()


func _process(delta: float) -> void:
	_t += delta
	if _water_mat != null:
		_water_mat.set_shader_parameter("t", _t)
	if _lrt_train != null:
		_lrt_train.position.z = fposmod(_t * 2.2 + 12.0, 28.0) - 14.0
	if _dest_beacon != null:
		_dest_beacon.position.y = 1.35 + sin(_t * 3.0) * 0.12
	for sid in _side_beacons:
		var b: MeshInstance3D = _side_beacons[sid]
		b.rotation_degrees.y = fmod(_t * 65.0, 360.0)
		b.position.y = 0.65 + sin(_t * 2.4 + b.position.x) * 0.08

	if _done:
		return
	if fast:
		quick_hop(_to_id)
		return

	_step_movement(delta)
	_check_proximity()
	_update_camera(clampf(delta * 5.0, 0.0, 1.0))
	_update_world_labels()


func _step_movement(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		move.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		move.y += 1.0

	if move.length_squared() > 0.01:
		_has_tap_target = false
		if _tap_ring != null:
			_tap_ring.visible = false
		if _lore_box != null and _lore_box.visible and move.length() > 0.5:
			_lore_box.visible = false
		move = move.normalized()
	elif _has_tap_target:
		var to_tap := Vector2(_tap_target.x - _teo_pos.x, _tap_target.z - _teo_pos.z)
		if to_tap.length() <= 0.22:
			_has_tap_target = false
			if _tap_ring != null:
				_tap_ring.visible = false
		else:
			move = to_tap.normalized()

	var spd := TRIKE_SPEED if (_trike_mode or Input.is_key_pressed(KEY_SHIFT)) else WALK_SPEED
	if move.length_squared() > 0.01:
		_teo_pos.x = clampf(_teo_pos.x + move.x * spd * delta, BOUNDS_MIN.x, BOUNDS_MAX.x)
		_teo_pos.z = clampf(_teo_pos.z + move.y * spd * delta, BOUNDS_MIN.y, BOUNDS_MAX.y)
		if absf(move.x) >= absf(move.y):
			_teo_dir = 1
			_teo_flip = move.x < 0.0
		else:
			_teo_dir = 2 if move.y < 0.0 else 0
			_teo_flip = false
		_teo_frame_t += delta * (12.0 if _trike_mode else 7.5)
		_teo_frame = int(_teo_frame_t) % 4
	else:
		_teo_frame = 1

	if _teo != null:
		_teo.position = _teo_pos + Vector3(0, 0.04, 0)
		_teo.frame = _teo_dir * 4 + _teo_frame
		_teo.flip_h = _teo_dir == 1 and _teo_flip


func _check_proximity() -> void:
	_nearby_stop = {}
	for s in SIDE_STOPS:
		var sp: Vector3 = s["at"]
		if _teo_pos.distance_to(sp) <= 1.55:
			_nearby_stop = s
			break

	var dest_pos: Vector3 = NODES.get(_to_id, {}).get("at", Vector3.ZERO)
	_near_dest = _teo_pos.distance_to(dest_pos) <= 1.45
	if _near_dest:
		_finish()
		return

	if _prompt_box != null:
		if not _nearby_stop.is_empty():
			_prompt_lbl.text = "[E / Tap] Inspect: %s" % String(_nearby_stop["name"])
			_prompt_box.visible = true
		else:
			_prompt_box.visible = false


func _update_camera(weight: float) -> void:
	if _cam == null:
		return
	var desired := _teo_pos + Vector3(0.0, 10.6, 11.8)
	_cam.position = _cam.position.lerp(desired, weight) if weight < 1.0 else desired
	_cam.look_at(_teo_pos + Vector3(0.0, 0.35, -0.4), Vector3.UP)


func _update_world_labels() -> void:
	if _cam == null or _label_layer == null:
		return
	var vp_size := size if size.x > 10.0 else Vector2(1280, 720)
	var scale_k := vp_size / Vector2(_vp.size)
	for entry in _world_labels:
		var lbl: Label = entry["label"]
		if lbl == null:
			lbl = Label.new()
			lbl.text = String(entry["text"])
			lbl.add_theme_font_override("font", Fonts.label_medium())
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", entry["col"])
			lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 0.94))
			lbl.add_theme_constant_override("outline_size", 4)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_label_layer.add_child(lbl)
			entry["label"] = lbl
		var p3: Vector3 = entry["pos"]
		if _cam.is_position_behind(p3):
			lbl.visible = false
			continue
		var p2 := _cam.unproject_position(p3) * scale_k
		lbl.visible = Rect2(Vector2(-80, -30), vp_size + Vector2(160, 60)).has_point(p2)
		lbl.position = p2 - Vector2(lbl.size.x * 0.5, lbl.size.y * 0.5)


func _gui_input(event: InputEvent) -> void:
	if _done or fast:
		return
	var tap_pos := Vector2(-1, -1)
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		tap_pos = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch and event.pressed:
		tap_pos = (event as InputEventScreenTouch).position
	if tap_pos.x >= 0.0 and _cam != null and _vp != null:
		if _lore_box != null and _lore_box.visible:
			_lore_box.visible = false
			accept_event()
			return
		var vp_size := size if size.x > 10.0 else Vector2(1280, 720)
		var vp_pt := tap_pos * (Vector2(_vp.size) / vp_size)
		var orig := _cam.project_ray_origin(vp_pt)
		var dir := _cam.project_ray_normal(vp_pt)
		if absf(dir.y) > 0.001:
			var hit_t := -orig.y / dir.y
			if hit_t > 0.0:
				var hit := orig + dir * hit_t
				hit.x = clampf(hit.x, BOUNDS_MIN.x, BOUNDS_MAX.x)
				hit.z = clampf(hit.z, BOUNDS_MIN.y, BOUNDS_MAX.y)
				hit.y = 0.0
				# If tapping near an inspectable side stop while already close, inspect it immediately
				if not _nearby_stop.is_empty() and hit.distance_to(_nearby_stop["at"]) <= 1.8:
					inspect_side_stop(String(_nearby_stop["id"]))
				else:
					_tap_target = hit
					_has_tap_target = true
					if _tap_ring != null:
						_tap_ring.position = hit + Vector3(0, 0.04, 0)
						_tap_ring.visible = true
				accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _done or fast:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_T:
			toggle_tricycle()
			get_viewport().set_input_as_handled()
		elif k == KEY_E or k == KEY_SPACE or k == KEY_ENTER:
			if _lore_box != null and _lore_box.visible:
				_lore_box.visible = false
			elif not _nearby_stop.is_empty():
				inspect_side_stop(String(_nearby_stop["id"]))
			get_viewport().set_input_as_handled()
