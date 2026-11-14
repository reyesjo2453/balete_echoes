class_name ExploreMap
extends Control
## A walkable 2.5D map: pixel-art sprites standing in a small lit 3D diorama, seen from a high tilted camera that
## follows Teo (the HD-2D look). It replaces the hub menu for a hub beat that has a "map" (data/maps.json).
##
## Walk: arrow keys / WASD / d-pad / left stick in any direction, or tap / click the floor.
## Talk: walk up to someone and press SPACE / E / controller A, or tap their name tag (Teo walks over first).
## Leave: the exit tag unlocks once `need` people have been heard.
##
## Tags are Buttons named Hub_<option index> and HubGo, the same names as the hub menu, so saves, tests and the hub
## flow work the same in both. The 3D world renders at half resolution and is scaled up without smoothing, so
## sprites, textures and edges all share one chunky pixel grid; a tilt-shift blur and a vignette sit on top.

signal picked(index: int)

const SPEED := 3.1 # metres a second
const REACH := 1.45 # how close Teo must be to talk
const RADIUS := 0.24
const FRAME_TIME := 0.14
const TEO_H := 1.75
const SHRINK := 2 # the 3D view renders at 1/SHRINK resolution
const CAM_OFFSET := Vector3(0, 4.4, 10.8) # default; a map can set "cam": [height, distance]
const LOOK_Y := 1.15 # the camera looks at a point this high above the floor near Teo
const DOWN := 0
const SIDE := 1
const UP := 2

static var _maps: Dictionary = {}

var beat: Dictionary
var heard: Dictionary
var need: int = 0
var test_fast := false
var teo_pos := Vector2(-1, -1) # x, z on the floor

var _map: Dictionary
var _options: Array
var _vp: SubViewport
var _view: TextureRect
var _cam: Camera3D
var _cam_target := Vector3.ZERO
var _teo: Sprite3D
var _teo_shadow: Sprite3D
var _dir := DOWN
var _flip := false
var _frame := 0
var _frame_t := 0.0
var _moving := false
var _target := Vector2(-1, -1) # where a tap or tag sent Teo
var _pending := -2 # what to do on arrival: an option index, -1 leave, -2 nothing
var _stuck_t := 0.0
var _solids: Array[Rect2] = []
var _tags: Array[Button] = []
var _go: Button
var _hint: Label
var _count: Label
var _done := false
var _t := 0.0
var _npcs: Array = [] # [{"node", "frames", "ghost", "phase"}]
## Enemies you can see on the map (an option with "roam"): they drift about their patch, come for Teo when he is
## close, and touching one starts its fight (picked.emit(option)). Walk around them to avoid the fight.
var _roamers: Array = [] # [{"node", "shadow", "pos", "target", "area": Rect2, "speed", "chase", "index", "alert"}]
const TOUCH := 0.75
var _lights: Array = [] # [{"light", "base", "phase"}]
var _size := Vector2(2, 2)
var _water: StandardMaterial3D
var _cam_offset := CAM_OFFSET
## Stage mode: the map is a set for a scene (scripts/dialogue.gd plays the lines on top). No tags, no HUD, no
## walking from the player: the scene's steps move the cast with act() and the camera follows the stage focus.
var stage_mode := false
var _cast: Dictionary = {} # id -> {"node", "shadow", "pos", "target", "speed", "frames", "name", "bob"}
var _focus := Vector2(-1, -1)
var _marker: Label
var _speaker := ""
## A fixed camera (battle): position and the point it looks at. Empty = follow.
var fixed_cam: Array = []


## The map with this id from data/maps.json ({} when there is none).
static func map_def(id: String) -> Dictionary:
	if _maps.is_empty():
		var f := FileAccess.open("res://data/maps.json", FileAccess.READ)
		if f != null:
			var data: Variant = JSON.parse_string(f.get_as_text())
			if data is Dictionary:
				_maps = data
	return _maps.get(id, {})


func setup(p_beat: Dictionary, p_heard: Dictionary, p_need: int, start: Vector2) -> void:
	beat = p_beat
	heard = p_heard
	need = p_need
	_options = beat.get("options", [])
	_map = map_def(String(beat.get("map", "")))
	var sz: Array = _map.get("size", [12, 8])
	_size = Vector2(float(sz[0]), float(sz[1]))
	var spawn: Array = _map.get("spawn", [1.5, _size.y - 1.5])
	teo_pos = start if start.x >= 0.0 else Vector2(float(spawn[0]), float(spawn[1]))
	if _map.has("cam"):
		_cam_offset = Vector3(0, float(_map["cam"][0]), float(_map["cam"][1]))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.size = Vector2i(1280 / SHRINK, 720 / SHRINK)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_vp)
	_view = TextureRect.new()
	_view.name = "View"
	_view.texture = _vp.get_texture()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.material = _post_material()
	add_child(_view)

	_build_world()
	if stage_mode:
		_build_marker()
	else:
		_build_tags()
		_build_hud()
	_cam_target = _follow_point()
	_update(0.0)


# --- the diorama ---------------------------------------------------------------------------------------------------

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(String(_map.get("bg", "06070c")))
	var amb: Array = _map.get("ambient", ["404050", 0.6])
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(String(amb[0]))
	env.ambient_light_energy = float(amb[1])
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)

	_cam = Camera3D.new()
	_cam.fov = 30.0
	_cam.near = 0.5
	_cam.far = 60.0
	_vp.add_child(_cam)

	var w := _size.x
	var d := _size.y
	var wall_h := float(_map.get("wall_h", 3.2))
	# Floors: one under the whole room by default, or a list of {"rect": [x0, z0, x1, z1], "tex", "y"} pieces (banks
	# of a creek). The default floor runs on past the front of the room (under the camera), so its edge never shows.
	var floor_m := float(_map.get("floor_m", 2.0))
	var floors: Array = _map.get("floors", [{"rect": [-4.0, 0.0, w + 4.0, d + 6.0], "tex": _map.get("floor", "")}])
	for f in floors:
		var r: Array = f["rect"]
		var fw := float(r[2]) - float(r[0])
		var fdp := float(r[3]) - float(r[1])
		var fl := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(fw, fdp)
		fl.mesh = pm
		fl.position = Vector3(float(r[0]) + fw * 0.5, float(f.get("y", 0.0)), float(r[1]) + fdp * 0.5)
		fl.material_override = _surface(String(f.get("tex", "")), Vector3(fw / floor_m, fdp / floor_m, 1))
		if f.has("tint"):
			(fl.material_override as StandardMaterial3D).albedo_color = Color(String(f["tint"]))
		_vp.add_child(fl)
	if _map.has("water"):
		var wd: Dictionary = _map["water"]
		var r: Array = wd["rect"]
		var ww := float(r[2]) - float(r[0])
		var wdp := float(r[3]) - float(r[1])
		var wi := MeshInstance3D.new()
		wi.name = "Water"
		var wpm := PlaneMesh.new()
		wpm.size = Vector2(ww, wdp)
		wi.mesh = wpm
		wi.position = Vector3(float(r[0]) + ww * 0.5, float(wd.get("y", -0.7)), float(r[1]) + wdp * 0.5)
		_water = _surface("tex_water", Vector3(ww / 2.0, wdp / 2.0, 1))
		_water.albedo_color = Color(String(wd.get("tint", "ffffff")))
		_water.roughness = 0.12
		_water.metallic = 0.35
		_water.metallic_specular = 0.9
		if wd.has("glow"):
			_water.emission_enabled = true
			_water.emission = Color(String(wd["glow"]))
			_water.emission_energy_multiplier = 1.0
		wi.material_override = _water
		_vp.add_child(wi)
	# walls
	var wm: Array = _map.get("wall_m", [2.0, 3.0])
	var walls: Array = _map.get("walls", ["back", "left", "right"])
	var wall_tex := String(_map.get("wall", ""))
	var vrep := wall_h / float(wm[1])
	if walls.has("back"):
		_wall(Vector3(w * 0.5, wall_h * 0.5, 0), Vector2(w, wall_h), 0.0, _surface(wall_tex, Vector3(w / float(wm[0]), vrep, 1), true))
	if walls.has("left"):
		_wall(Vector3(0, wall_h * 0.5, d * 0.5), Vector2(d, wall_h), PI * 0.5, _surface(wall_tex, Vector3(d / float(wm[0]), vrep, 1), true))
	if walls.has("right"):
		_wall(Vector3(w, wall_h * 0.5, d * 0.5), Vector2(d, wall_h), -PI * 0.5, _surface(wall_tex, Vector3(d / float(wm[0]), vrep, 1), true))
	for b in _map.get("boxes", []):
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var bs: Array = b["size"]
		bm.size = Vector3(float(bs[0]), float(bs[1]), float(bs[2]))
		mi.mesh = bm
		var ba: Array = b["at"]
		mi.position = Vector3(float(ba[0]), float(ba[1]), float(ba[2]))
		mi.material_override = _surface(String(b.get("tex", "")), Vector3(maxf(1.0, bm.size.x), 1, 1))
		_vp.add_child(mi)
	for q in _map.get("quads", []):
		var qa: Array = q["at"]
		var qs: Array = q["size"]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(String(q.get("color", "000000")))
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_wall(Vector3(float(qa[0]), float(qa[1]), float(qa[2])), Vector2(float(qs[0]), float(qs[1])), PI * 0.5 if String(q.get("face", "z")) == "x" else 0.0, mat)
	for s in _map.get("solids", []):
		_solids.append(Rect2(float(s[0]), float(s[1]), float(s[2]) - float(s[0]), float(s[3]) - float(s[1])))

	for p in _map.get("props", []):
		var at: Array = p["at"]
		var spr := _sprite(String(p["s"]), float(p.get("h", 1.0)), false)
		if spr == null:
			continue
		spr.position = Vector3(float(at[0]), float(p.get("y", 0.0)), float(at[1]))
		spr.flip_h = bool(p.get("flip", false))
		_vp.add_child(spr)
		if not p.has("y"):
			_vp.add_child(_blob(Vector2(float(at[0]), float(at[1])), float(p.get("solid", [0.8, 0.5])[0]) * 1.1))
		if p.has("solid"):
			var so: Array = p["solid"]
			_solids.append(Rect2(float(at[0]) - float(so[0]) * 0.5, float(at[1]) - float(so[1]) * 0.5, float(so[0]), float(so[1])))

	# People: those you can talk to, then the ones who only sit there.
	for i in _options.size():
		var ro: Dictionary = _options[i]
		if ro.has("roam") and not heard.has(i) and not stage_mode:
			_add_roamer(ro["roam"], i)
	for o in _options:
		if o.has("roam"):
			continue
		if o.has("sprite") and o.has("at"):
			_add_npc(String(o["sprite"]), o.get("sprite_at", o["at"]), float(o.get("h", 1.35)), false)
	for e in beat.get("extras", []):
		if not Story.cond_ok(e):
			continue # e.g. "unless": "andoy_sent": a ghost who has been sent home is gone
		_add_npc(String(e["sprite"]), e["at"], float(e.get("h", 1.35)), bool(e.get("ghost", false)))

	for l in _map.get("lights", []):
		var la: Array = l["at"]
		var ol := OmniLight3D.new()
		ol.position = Vector3(float(la[0]), float(la[1]), float(la[2]))
		ol.light_color = Color(String(l.get("color", "ffffff")))
		ol.light_energy = float(l.get("energy", 1.0))
		ol.omni_range = float(l.get("range", 5.0))
		ol.omni_attenuation = 1.2
		_vp.add_child(ol)
		if l.get("flicker", false):
			_lights.append({"light": ol, "base": ol.light_energy, "phase": randf() * 10.0})
	for fpos in _map.get("flames", []):
		var g := Sprite3D.new()
		g.texture = _radial(Color(1.0, 0.75, 0.4, 0.85), Color(1.0, 0.5, 0.2, 0.0))
		g.pixel_size = 0.35 / 64.0
		g.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		g.shaded = false
		g.transparent = true
		g.no_depth_test = false
		var gm := StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.albedo_texture = g.texture
		gm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		gm.vertex_color_use_as_albedo = true
		g.material_override = gm
		g.position = Vector3(float(fpos[0]), float(fpos[1]), float(fpos[2]))
		_vp.add_child(g)
	if _map.get("dust", false) and DisplayServer.get_name() != "headless":
		_vp.add_child(_dust(w, d))

	var strip: Texture2D = _tex("teo_walk")
	_teo = Sprite3D.new()
	_teo.name = "Teo"
	_teo.texture = strip
	_teo.hframes = 12
	if strip != null:
		_teo.pixel_size = TEO_H / float(strip.get_height())
		_teo.offset = Vector2(0, strip.get_height() * 0.5)
	_teo.material_override = _sprite_material(strip, false)
	_vp.add_child(_teo)
	_teo_shadow = _blob(teo_pos, 0.75)
	_vp.add_child(_teo_shadow)


func _wall(pos: Vector3, sz: Vector2, yaw: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = sz
	mi.mesh = qm
	mi.position = pos
	mi.rotation.y = yaw
	mi.material_override = mat
	_vp.add_child(mi)


func _tex(name: String) -> Texture2D:
	var path := "res://assets/explore/%s.png" % name
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _surface(tex_name: String, uv: Vector3, _is_wall: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(tex_name)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_scale = uv
	m.roughness = 0.85
	if m.albedo_texture == null:
		m.albedo_color = Color(0.3, 0.3, 0.32)
	return m


## Pixel sprites are lit from every side (wrap lighting): a candle behind a person still warms them, as in a painted
## diorama, instead of leaving a black cut-out.
const SPRITE_SHADER := "
shader_type spatial;
render_mode cull_disabled%s;
uniform sampler2D tex : source_color, filter_nearest;
uniform float alpha = 1.0;
uniform float fill = 0.2; // sprites never sink to a black cut-out in a dark corner
uniform float flash = 0.0; // a hit: the whole sprite blinks white
void fragment() {
	vec4 c = texture(tex, UV) * COLOR;
	%s
	ALBEDO = mix(c.rgb, vec3(1.0), flash);
	EMISSION = mix(c.rgb * fill, vec3(1.0), flash);
	%s
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
void light() {
	DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR * (0.55 + 0.45 * abs(dot(NORMAL, LIGHT))) / PI;
}
"
static var _shaders: Dictionary = {}


func _sprite_material(tex: Texture2D, ghost: bool) -> ShaderMaterial:
	if not _shaders.has(ghost):
		var sh := Shader.new()
		if ghost:
			sh.code = SPRITE_SHADER % [", blend_add, depth_draw_never, unshaded", "", "ALPHA = c.a * alpha;"]
		else:
			sh.code = SPRITE_SHADER % ["", "if (c.a < 0.5) { discard; }", ""]
		_shaders[ghost] = sh
	var m := ShaderMaterial.new()
	m.shader = _shaders[ghost]
	m.set_shader_parameter("tex", tex)
	return m


func _sprite(name: String, h: float, ghost: bool) -> Sprite3D:
	var tex := _tex(name)
	if tex == null:
		return null
	var s := Sprite3D.new()
	s.name = "Spr_" + name
	s.texture = tex
	s.pixel_size = h / float(tex.get_height())
	s.offset = Vector2(0, tex.get_height() * 0.5)
	s.material_override = _sprite_material(tex, ghost)
	return s


func _add_npc(name: String, at: Array, h: float, ghost: bool) -> void:
	var s := _sprite(name, h, ghost)
	if s == null:
		return
	s.name = "Npc_" + name
	s.position = Vector3(float(at[0]), 0.0, float(at[1]))
	_vp.add_child(s)
	if not ghost:
		_vp.add_child(_blob(Vector2(float(at[0]), float(at[1])), 0.8))
		_solids.append(Rect2(float(at[0]) - 0.3, float(at[1]) - 0.25, 0.6, 0.5))
	var frames: Array[Texture2D] = [s.texture]
	var b := _tex(name + "_b")
	if b != null:
		frames.append(b)
	_npcs.append({"node": s, "frames": frames, "ghost": ghost, "phase": float(at[0]) * 1.7})


func _add_roamer(r: Dictionary, index: int) -> void:
	var s := _sprite(String(r.get("sprite", "mag_idle")), float(r.get("h", 1.6)), bool(r.get("ghost", true)))
	if s == null:
		return
	s.name = "Roamer_%d" % index
	var a: Array = r.get("area", [0, 0, 2, 2])
	var area := Rect2(float(a[0]), float(a[1]), float(a[2]) - float(a[0]), float(a[3]) - float(a[1]))
	var at := area.get_center()
	s.position = Vector3(at.x, 0.0, at.y)
	_vp.add_child(s)
	var sh := _blob(at, 0.7)
	_vp.add_child(sh)
	var frames: Array[Texture2D] = [s.texture]
	var b := _tex(String(r.get("sprite", "mag_idle")) + "_b")
	if b != null:
		frames.append(b)
	var bang := Label3D.new()
	bang.text = "!"
	bang.font = Fonts.label()
	bang.font_size = 96
	bang.pixel_size = 0.006
	bang.modulate = Color("ff5a4a")
	bang.outline_size = 18
	bang.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bang.no_depth_test = true
	bang.position = Vector3(0, float(r.get("h", 1.6)) + 0.35, 0)
	bang.visible = false
	s.add_child(bang)
	_roamers.append({"node": s, "shadow": sh, "pos": at, "target": at, "area": area, "frames": frames,
		"speed": float(r.get("speed", 0.6)), "chase": float(r.get("chase", 2.6)), "index": index, "bang": bang,
		"wait": 0.0, "ghost": bool(r.get("ghost", true)), "phase": at.x})


## Where a roaming enemy is (tests and the encounter flash).
func roamer_pos(index: int) -> Vector2:
	for r in _roamers:
		if int(r["index"]) == index:
			return r["pos"]
	return Vector2(-99, -99)


func _roam(delta: float) -> void:
	for r in _roamers:
		var pos: Vector2 = r["pos"]
		var area: Rect2 = r["area"]
		var to_teo := teo_pos - pos
		var hunting := to_teo.length() < float(r["chase"])
		(r["bang"] as Label3D).visible = hunting
		var goal: Vector2 = r["target"]
		var speed: float = r["speed"]
		if hunting:
			goal = teo_pos
			speed *= 1.9
		elif pos.distance_to(goal) < 0.1:
			r["wait"] = float(r["wait"]) - delta
			if float(r["wait"]) <= 0.0:
				r["target"] = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
				r["wait"] = randf_range(0.6, 1.8)
		var step := (goal - pos).limit_length(speed * delta)
		pos += step
		r["pos"] = pos
		var s: Sprite3D = r["node"]
		s.position = Vector3(pos.x, 0.06 + sin(_t * 1.3 + float(r["phase"])) * 0.05, pos.y)
		if absf(step.x) > 0.001:
			s.flip_h = step.x < 0.0
		var frames: Array = r["frames"]
		if frames.size() > 1:
			s.texture = frames[int(_t * 1.6) % 2]
			(s.material_override as ShaderMaterial).set_shader_parameter("tex", s.texture)
		if bool(r["ghost"]):
			(s.material_override as ShaderMaterial).set_shader_parameter("alpha", 0.6 + sin(_t * 2.1) * 0.12)
		(r["shadow"] as Sprite3D).position = Vector3(pos.x, 0.012, pos.y)
		if not _done and teo_pos.distance_to(pos) < TOUCH:
			_done = true
			_encounter(int(r["index"]))
			return


## The old games' battle flash: the screen blinks twice and then the fight begins.
func _encounter(index: int) -> void:
	if test_fast:
		picked.emit(index)
		return
	Sfx.play("hit-thud")
	var f := ColorRect.new()
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f.color = Color(1, 1, 1, 0)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(f)
	var tw := create_tween()
	for i in 2:
		tw.tween_property(f, "color:a", 0.85, 0.08)
		tw.tween_property(f, "color:a", 0.0, 0.12)
	tw.tween_property(f, "color", Color(0, 0, 0, 1), 0.25)
	tw.tween_callback(func() -> void: picked.emit(index))


func _radial(inner: Color, outer: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, inner)
	g.set_color(1, outer)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


## A soft dark ellipse on the floor under someone, so they stand on it instead of floating over it.
func _blob(at: Vector2, w: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = _radial(Color(0, 0, 0, 0.5), Color(0, 0, 0, 0))
	s.pixel_size = w / 64.0
	s.scale = Vector3(1, 0.45, 1)
	s.rotation.x = -PI * 0.5
	s.shaded = false
	s.transparent = true
	s.position = Vector3(at.x, 0.012, at.y)
	return s


func _dust(w: float, d: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 60
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(w * 0.5, 1.3, d * 0.5)
	p.position = Vector3(w * 0.5, 1.5, d * 0.5)
	p.direction = Vector3(0.3, 1, 0)
	p.spread = 60.0
	p.gravity = Vector3(0, -0.02, 0)
	p.initial_velocity_min = 0.03
	p.initial_velocity_max = 0.1
	var qm := QuadMesh.new()
	qm.size = Vector2(0.035, 0.035)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.85, 0.6, 0.35)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = m
	p.mesh = qm
	return p


## Tilt-shift: the top and bottom of the frame blur like a photographed miniature; a vignette and a slight lift of
## the darks keep the night readable.
func _post_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "
shader_type canvas_item;
uniform float focus = 0.56;
uniform float band = 0.2;
uniform float blur = 3.0;
void fragment() {
	float d = clamp((abs(UV.y - focus) - band) / (1.0 - band), 0.0, 1.0);
	vec2 px = TEXTURE_PIXEL_SIZE * blur * d;
	vec4 c = texture(TEXTURE, UV) * 0.2;
	c += texture(TEXTURE, UV + vec2(px.x, 0.0)) * 0.1;
	c += texture(TEXTURE, UV - vec2(px.x, 0.0)) * 0.1;
	c += texture(TEXTURE, UV + vec2(0.0, px.y)) * 0.1;
	c += texture(TEXTURE, UV - vec2(0.0, px.y)) * 0.1;
	c += texture(TEXTURE, UV + px) * 0.1;
	c += texture(TEXTURE, UV - px) * 0.1;
	c += texture(TEXTURE, UV + vec2(px.x, -px.y)) * 0.1;
	c += texture(TEXTURE, UV + vec2(-px.x, px.y)) * 0.1;
	float v = smoothstep(0.95, 0.35, length((UV - vec2(0.5)) * vec2(1.25, 1.0)));
	c.rgb = c.rgb * mix(0.55, 1.0, v) + vec3(0.012, 0.012, 0.025);
	COLOR = vec4(c.rgb, 1.0);
}
"
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


# --- tags and HUD --------------------------------------------------------------------------------------------------

func _build_tags() -> void:
	for i in _options.size():
		var o: Dictionary = _options[i]
		var b := _tag("Hub_%d" % i)
		b.text = ("HEARD:  " if heard.has(i) else "") + String(o.get("short", o.get("label", o.get("scene", ""))))
		b.disabled = heard.has(i)
		b.visible = not o.has("roam") # an enemy on the map has no name tag: you see it coming
		var idx := i
		b.pressed.connect(func() -> void: _walk_to(_point(o.get("at", [0, 0])), idx))
		_tags.append(b)
	_go = _tag("HubGo")
	_go.text = String(beat.get("leave", "MOVE ON"))
	_go.disabled = heard.size() < need
	_go.pressed.connect(func() -> void: _walk_to(_exit_point(), -1))


func _point(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


func _exit_point() -> Vector2:
	return _point(_map.get("exit", {}).get("at", [_size.x - 1.0, _size.y - 1.0]))


func _tag(node_name: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.add_theme_font_override("font", Fonts.label())
	b.add_theme_font_size_override("font_size", 16)
	b.custom_minimum_size = Vector2(0, 34)
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(Retro.BOTTOM, 0.55 if st == "disabled" else 0.92) # the retro window blue
		box.border_color = Retro.EDGE if st != "disabled" else Color(1, 1, 1, 0.25)
		box.set_border_width_all(2)
		box.set_corner_radius_all(6)
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.content_margin_top = 3
		box.content_margin_bottom = 3
		b.add_theme_stylebox_override(st, box)
	b.add_theme_color_override("font_color", Color("f2efe4"))
	b.add_theme_color_override("font_hover_color", Retro.NAME)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))
	add_child(b)
	return b


func _build_hud() -> void:
	var top := VBoxContainer.new()
	top.position = Vector2(34, 22)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var title := Label.new()
	title.text = String(beat.get("title", ""))
	title.add_theme_font_override("font", Fonts.display())
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("e8c872"))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 8)
	top.add_child(title)
	_count = Label.new()
	_count.add_theme_font_override("font", Fonts.label())
	_count.add_theme_font_size_override("font_size", 18)
	_count.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_count.add_theme_constant_override("outline_size", 6)
	top.add_child(_count)
	_hint = Label.new()
	_hint.add_theme_font_override("font", Fonts.label_medium())
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -34
	_hint.offset_bottom = -8
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	var left := maxi(0, need - heard.size())
	var goal := String(beat.get("goal", ""))
	if left > 0:
		_count.text = "%s   (talk to %d more before you can leave)" % [goal, left]
	else:
		_count.text = "%s   You can leave when you're ready." % goal


# --- moving and talking --------------------------------------------------------------------------------------------

func _walk_to(p: Vector2, then: int) -> void:
	if _done:
		return
	if then == -1 and heard.size() < need:
		return
	_target = p
	_pending = then
	_stuck_t = 0.0
	if test_fast:
		teo_pos = p + Vector2(0, 0.9)
		_arrive()


func _arrive() -> void:
	_target = Vector2(-1, -1)
	var then := _pending
	_pending = -2
	if then == -2:
		return
	if then >= 0 and heard.has(then):
		return
	_done = true
	picked.emit(then)


## The option (or the exit, -1) Teo is standing at, or -2 when nothing is in reach.
func nearest() -> int:
	var best := -2
	var best_d := REACH
	for i in _options.size():
		if heard.has(i) or _options[i].has("roam"):
			continue
		var d := teo_pos.distance_to(_point(_options[i].get("at", [-99, -99])))
		if d < best_d:
			best_d = d
			best = i
	if heard.size() >= need and teo_pos.distance_to(_exit_point()) < best_d:
		best = -1
	return best


func _blocked(p: Vector2) -> bool:
	if p.x < RADIUS + 0.2 or p.x > _size.x - RADIUS - 0.2 or p.y < 0.35 or p.y > _size.y - 0.25:
		return true
	for r in _solids:
		if r.grow(RADIUS).has_point(p):
			return true
	return false


## Moves Teo by `v`, sliding along whatever blocks him. Returns how far he actually went.
func _move(v: Vector2) -> float:
	var start := teo_pos
	var nx := teo_pos + Vector2(v.x, 0)
	if not _blocked(nx):
		teo_pos = nx
	var nz := teo_pos + Vector2(0, v.y)
	if not _blocked(nz):
		teo_pos = nz
	return teo_pos.distance_to(start)


func _face(v: Vector2) -> void:
	if absf(v.x) > absf(v.y) * 0.8:
		_dir = SIDE
		_flip = v.x < 0.0
	else:
		_dir = DOWN if v.y > 0.0 else UP


func _gui_input(event: InputEvent) -> void:
	if _done or stage_mode:
		return
	var at := Vector2(-1, -1)
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		at = mouse.position
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed:
		at = touch.position
	if at.x >= 0.0:
		var p := floor_at(at)
		if p.x > -90.0:
			_walk_to(p, -2)
		accept_event()


## The floor point under a screen position (control coordinates), or (-99, -99) when it misses the floor.
func floor_at(screen: Vector2) -> Vector2:
	var s := size if size.x > 0.0 else Vector2(1280, 720)
	var vp := screen / s * Vector2(_vp.size)
	var o := _cam.project_ray_origin(vp)
	var n := _cam.project_ray_normal(vp)
	if absf(n.y) < 0.0001:
		return Vector2(-99, -99)
	var t := -o.y / n.y
	if t <= 0.0:
		return Vector2(-99, -99)
	var hit := o + n * t
	return Vector2(clampf(hit.x, 0.0, _size.x), clampf(hit.z, 0.0, _size.y))


func _unhandled_input(event: InputEvent) -> void:
	if _done or stage_mode or not is_visible_in_tree():
		return
	var talk := event.is_action_pressed("ui_accept")
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_E:
		talk = true
	var pad := event as InputEventJoypadButton
	if pad != null and pad.pressed and pad.button_index == JOY_BUTTON_A:
		talk = true
	if talk:
		var n := nearest()
		if n != -2:
			_pending = n
			_arrive()
			get_viewport().set_input_as_handled()


func _input_vector() -> Vector2:
	var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_physical_key_pressed(KEY_A):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		v.y += 1.0
	return v.limit_length(1.0)


func _process(delta: float) -> void:
	_t += delta
	_moving = false
	if stage_mode:
		_stage_walk(delta)
	elif not _done:
		_roam(delta)
		var v := _input_vector()
		if v.length() > 0.2:
			_target = Vector2(-1, -1)
			_pending = -2
			_face(v)
			_moving = _move(v * SPEED * delta) > 0.0005
		elif _target.x >= 0.0:
			var to := _target - teo_pos
			var close := REACH * 0.7 if _pending >= 0 or _pending == -1 else 0.06
			if to.length() <= close:
				_arrive()
			else:
				var step := to.normalized() * minf(SPEED * delta, to.length())
				_face(step)
				var went := _move(step)
				_moving = went > 0.0005
				_stuck_t = _stuck_t + delta if went < SPEED * delta * 0.25 else 0.0
				if _stuck_t > 0.35:
					# Blocked (a table in the way): close enough counts, otherwise give up.
					if to.length() <= REACH and _pending != -2:
						_arrive()
					else:
						_target = Vector2(-1, -1)
						_pending = -2
	_update(delta)


func _follow_point() -> Vector3:
	if stage_mode and _focus.x >= 0.0:
		var fcx: Array = _map.get("cam_x", [_size.x * 0.5, _size.x * 0.5])
		var fcz: Array = _map.get("cam_z", [_size.y * 0.3, _size.y * 0.62])
		return Vector3(clampf(_focus.x, float(fcx[0]), float(fcx[1])), LOOK_Y, clampf(_focus.y - 0.6, float(fcz[0]), float(fcz[1])))
	var cx: Array = _map.get("cam_x", [_size.x * 0.5, _size.x * 0.5])
	var x := clampf(teo_pos.x, float(cx[0]), float(cx[1]))
	var cz: Array = _map.get("cam_z", [_size.y * 0.3, _size.y * 0.62])
	var z := clampf(teo_pos.y - 0.6, float(cz[0]), float(cz[1]))
	return Vector3(x, LOOK_Y, z)


func _update(delta: float) -> void:
	if _moving:
		_frame_t += delta
		if _frame_t >= FRAME_TIME:
			_frame_t = 0.0
			_frame = (_frame + 1) % 4
	else:
		_frame = 1
		_frame_t = FRAME_TIME * 0.5
	_teo.frame = _dir * 4 + _frame
	_teo.flip_h = _dir == SIDE and _flip
	_teo.position = Vector3(teo_pos.x, 0.0, teo_pos.y)
	_teo_shadow.position = Vector3(teo_pos.x, 0.012, teo_pos.y)

	if fixed_cam.size() == 2:
		_cam.position = fixed_cam[0]
		_cam.look_at(fixed_cam[1], Vector3.UP)
	else:
		var want := _follow_point()
		_cam_target = want if delta == 0.0 else _cam_target.lerp(want, minf(1.0, delta * (2.2 if stage_mode else 4.0)))
		_cam.position = _cam_target + _cam_offset
		_cam.look_at(_cam_target, Vector3.UP)

	for n in _npcs:
		var s: Sprite3D = n["node"]
		var ph: float = n["phase"]
		var frames: Array = n["frames"]
		if frames.size() > 1:
			s.texture = frames[int(_t * 0.9 + ph) % 2]
			(s.material_override as ShaderMaterial).set_shader_parameter("tex", s.texture)
		if n["ghost"]:
			s.position.y = 0.06 + sin(_t * 1.3 + ph) * 0.05
			(s.material_override as ShaderMaterial).set_shader_parameter("alpha", 0.55 + sin(_t * 2.1 + ph) * 0.12)
	if _water != null:
		_water.uv1_offset = Vector3(_t * 0.035, sin(_t * 0.4) * 0.02, 0) # the creek creeps toward the pump
	for l in _lights:
		var ol: OmniLight3D = l["light"]
		var ph2: float = l["phase"]
		ol.light_energy = float(l["base"]) * (0.88 + 0.08 * sin(_t * 9.0 + ph2) + 0.05 * sin(_t * 23.0 + ph2 * 2.0))

	if stage_mode:
		_update_cast()
		return
	_place_tags()
	var near := nearest()
	for i in _tags.size():
		_tags[i].modulate = Color(1, 1, 1, 1.0 if i == near else (0.45 if heard.has(i) else 0.8))
	_go.modulate = Color(1, 1, 1, 1.0 if near == -1 else 0.8)
	if near >= 0:
		_hint.text = "SPACE / A  talk to %s      ARROWS / WASD  walk" % String(_options[near].get("short", "them"))
	elif near == -1:
		_hint.text = "SPACE / A  %s      ARROWS / WASD  walk" % String(beat.get("leave", "leave")).to_lower()
	else:
		_hint.text = "ARROWS / WASD  walk      SPACE / A  talk      or tap where to go"


## Tags float over the person (or the place) they belong to.
func _place_tags() -> void:
	var s := size if size.x > 0.0 else Vector2(1280, 720)
	var k := s / Vector2(_vp.size)
	for i in _tags.size():
		var o: Dictionary = _options[i]
		var a := _point(o.get("at", [0, 0]))
		var p := _cam.unproject_position(Vector3(a.x, float(o.get("tag_h", 1.9)), a.y)) * k
		var b := _tags[i]
		b.reset_size()
		b.position = _on_screen(p - Vector2(b.size.x * 0.5, b.size.y), b.size, s)
	var e := _exit_point()
	var ep := _cam.unproject_position(Vector3(e.x, float(_map.get("exit", {}).get("label_y", 2.2)), e.y)) * k
	_go.reset_size()
	_go.position = _on_screen(ep - Vector2(_go.size.x * 0.5, _go.size.y), _go.size, s)


## Keeps a tag inside the screen, so someone at the edge of the view still shows their name.
func _on_screen(p: Vector2, sz: Vector2, s: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 8.0, s.x - sz.x - 8.0), clampf(p.y, 140.0, s.y - sz.y - 44.0))


# --- stage mode: the cast acts a scene ---------------------------------------------------------------------------

## Sets the stage for a scene: who stands where (data: the flow beat's "stage"), and where the camera looks.
## cast: {id: {"sprite", "at": [x, z], "h", "name" (the speaker name that lights the marker), "hidden", "flip"}}.
## "teo" is Teo himself (his walk sheet); "teo": {"at": [x, z]} places him.
func set_stage(stage: Dictionary) -> void:
	var cast: Dictionary = stage.get("cast", {})
	for id in cast:
		var c: Dictionary = cast[id]
		if String(id) == "teo":
			_cast["teo"] = {"name": "Teo", "pos": teo_pos}
			if c.has("face"):
				_set_teo_face(String(c["face"]))
			if c.get("hidden", false):
				hide_teo()
			continue
		var s := _sprite(String(c.get("sprite", id)), float(c.get("h", 1.4)), bool(c.get("ghost", false)))
		if s == null:
			continue
		s.name = "Cast_" + String(id)
		var at: Vector2 = _point(c.get("at", [0, 0]))
		s.position = Vector3(at.x, 0.0, at.y)
		s.flip_h = bool(c.get("flip", false))
		_vp.add_child(s)
		var sh := _blob(at, 0.8)
		_vp.add_child(sh)
		var frames: Array[Texture2D] = [s.texture]
		var b := _tex(String(c.get("sprite", id)) + "_b")
		if b != null:
			frames.append(b)
		var hidden := bool(c.get("hidden", false))
		s.visible = not hidden
		sh.visible = not hidden
		_cast[id] = {"node": s, "shadow": sh, "pos": at, "target": at, "speed": float(c.get("speed", 1.5)),
			"frames": frames, "name": String(c.get("name", "")), "ghost": bool(c.get("ghost", false)), "phase": at.x, "bob": bool(c.get("bob", true)), "y": float(c.get("y", 0.0))}
	if stage.has("focus"):
		_focus = _point(stage["focus"])
	_cam_target = _follow_point()
	_update(0.0)


## One step's stage directions (a story step's "act" list):
##   {"who": id, "walk": [x, z]}   walks there (Teo with his walk cycle, the others glide with a step bob)
##   {"who": id, "at": [x, z]}     appears there at once (and becomes visible)
##   {"who": id, "face": "left" | "right" | "down" | "up"}
##   {"who": id, "hide": true}     leaves the stage
##   {"who": id, "sprite": name}   changes pose (another sprite, same height; its "_b" frame breathes if there is one)
##   {"focus": [x, z]}             the camera eases to look there
##   {"water": y, "secs": s}       the water level slides to y (the 1998 rewind drains the parlor)
func act(directions: Array) -> void:
	for d in directions:
		if d.has("focus"):
			_focus = _point(d["focus"])
		if d.has("water"):
			var wn := _vp.get_node_or_null("Water") as Node3D
			if wn != null:
				var secs := 0.01 if test_fast else float(d.get("secs", 3.0))
				create_tween().tween_property(wn, "position:y", float(d["water"]), secs).set_trans(Tween.TRANS_SINE)
		var who := String(d.get("who", ""))
		if who == "":
			continue
		if who == "teo":
			if d.has("at"):
				teo_pos = _point(d["at"])
				_teo.visible = true
				_teo_shadow.visible = true
			if d.has("walk"):
				_target = _point(d["walk"])
				_pending = -2
			if d.has("face"):
				_set_teo_face(String(d["face"]))
			if d.get("hide", false):
				_teo.visible = false
				_teo_shadow.visible = false
			continue
		if not _cast.has(who):
			continue
		var c: Dictionary = _cast[who]
		var node: Sprite3D = c["node"]
		if d.has("at"):
			c["pos"] = _point(d["at"])
			c["target"] = c["pos"]
			node.visible = true
			(c["shadow"] as Sprite3D).visible = true
		if d.has("walk"):
			c["target"] = _point(d["walk"])
			node.visible = true
			(c["shadow"] as Sprite3D).visible = true
		if d.has("face"):
			node.flip_h = String(d["face"]) == "left"
		if d.has("sprite"):
			var tex := _tex(String(d["sprite"]))
			if tex != null:
				var h := node.pixel_size * node.texture.get_height()
				node.texture = tex
				node.pixel_size = h / float(tex.get_height())
				node.offset = Vector2(0, tex.get_height() * 0.5)
				(node.material_override as ShaderMaterial).set_shader_parameter("tex", tex)
				var frames: Array[Texture2D] = [tex]
				var b := _tex(String(d["sprite"]) + "_b")
				if b != null:
					frames.append(b)
				c["frames"] = frames
		if d.get("hide", false):
			node.visible = false
			(c["shadow"] as Sprite3D).visible = false


func _set_teo_face(f: String) -> void:
	match f:
		"left":
			_dir = SIDE
			_flip = true
		"right":
			_dir = SIDE
			_flip = false
		"up":
			_dir = UP
		_:
			_dir = DOWN


## Who is talking: the marker bobs over their head (empty hides it).
func set_speaker(speaker: String) -> void:
	_speaker = speaker


## True while anyone on stage is still walking.
func busy() -> bool:
	if _target.x >= 0.0:
		return true
	for id in _cast:
		var c: Dictionary = _cast[id]
		if c.has("target") and (c["target"] as Vector2).distance_to(c["pos"]) > 0.03:
			return true
	return false


## Moves a battle or story sprite that the caller made and owns (it lives in this map's 3D world).
func add_node(n: Node3D) -> void:
	_vp.add_child(n)


func blob(at: Vector2, w: float) -> Sprite3D:
	var b := _blob(at, w)
	_vp.add_child(b)
	return b


func sprite(name: String, h: float, ghost: bool = false) -> Sprite3D:
	return _sprite(name, h, ghost)


func camera() -> Camera3D:
	return _cam


func view_size() -> Vector2:
	return Vector2(_vp.size)


func hide_teo() -> void:
	_teo.visible = false
	_teo_shadow.visible = false


func _stage_walk(delta: float) -> void:
	if _target.x >= 0.0:
		var to := _target - teo_pos
		if to.length() <= 0.04 or test_fast:
			teo_pos = _target
			_target = Vector2(-1, -1)
		else:
			var step := to.normalized() * minf(SPEED * 0.75 * delta, to.length())
			_face(step)
			teo_pos += step # the director walks him through anything
			_moving = true
	if _cast.has("teo"):
		_cast["teo"]["pos"] = teo_pos
	for id in _cast:
		if String(id) == "teo":
			continue
		var c: Dictionary = _cast[id]
		var pos: Vector2 = c["pos"]
		var tgt: Vector2 = c["target"]
		var to2 := tgt - pos
		if to2.length() > 0.03 and not test_fast:
			var st := to2.normalized() * minf(float(c["speed"]) * delta, to2.length())
			c["pos"] = pos + st
			if absf(st.x) > 0.001:
				(c["node"] as Sprite3D).flip_h = st.x < 0.0
			c["walking"] = true
		else:
			c["pos"] = tgt
			c["walking"] = false


func _build_marker() -> void:
	_marker = Label.new()
	_marker.name = "SpeakerMarker"
	_marker.text = "v"
	_marker.add_theme_font_override("font", Fonts.display())
	_marker.add_theme_font_size_override("font_size", 30)
	_marker.add_theme_color_override("font_color", Color("e8c872"))
	_marker.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_marker.add_theme_constant_override("outline_size", 8)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.visible = false
	add_child(_marker)


func _update_cast() -> void:
	var k := (size if size.x > 0.0 else Vector2(1280, 720)) / Vector2(_vp.size)
	var mark_at := Vector3.ZERO
	var marked := false
	for id in _cast:
		var c: Dictionary = _cast[id]
		var pos: Vector2 = c["pos"]
		if String(id) == "teo":
			if _speaker == "Teo" and _teo.visible:
				mark_at = Vector3(pos.x, TEO_H + 0.25, pos.y)
				marked = true
			continue
		var s: Sprite3D = c["node"]
		var bob := absf(sin(_t * 9.0)) * 0.06 if c.get("walking", false) and c.get("bob", true) else 0.0
		var base_y: float = c.get("y", 0.0)
		s.position = Vector3(pos.x, bob + base_y, pos.y)
		(c["shadow"] as Sprite3D).position = Vector3(pos.x, 0.012 + base_y, pos.y)
		var frames: Array = c["frames"]
		if frames.size() > 1:
			s.texture = frames[int(_t * 0.9 + float(c["phase"])) % 2]
			(s.material_override as ShaderMaterial).set_shader_parameter("tex", s.texture)
		if c["ghost"]:
			s.position.y = base_y + 0.06 + sin(_t * 1.3 + float(c["phase"])) * 0.05
		if _speaker != "" and String(c["name"]) == _speaker and s.visible:
			mark_at = Vector3(pos.x, s.pixel_size * s.texture.get_height() + 0.25, pos.y)
			marked = true
	if _marker != null:
		_marker.visible = marked
		if marked:
			var p := _cam.unproject_position(mark_at) * k
			_marker.reset_size()
			_marker.position = p - Vector2(_marker.size.x * 0.5, _marker.size.y - sin(_t * 5.0) * 4.0)
