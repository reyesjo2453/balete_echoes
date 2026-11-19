class_name PixelCG
extends Control
## Cinematic pixel art made from 3D CG (docs/HD2D_TECH.md). A small 3D world is rendered into a 320x180 viewport with
## stepped (toon) lighting, ink outlines and a limited palette, then scaled up without smoothing over the battle or
## map. The camera can crane, orbit and push in freely and it still reads as pixel art. Works on both render tiers;
## on HIGH (Forward+) it adds depth of field and glow.
##
## A shot is data:
##   {"model": id (Blockouts), "scale": 3.0, "duration": 4.5,
##    "cam": [{"t": 0.0, "pos": [x, y, z], "look": [x, y, z], "fov": 40}, ...]   (eased between keys)
##    "rise": [t0, t1, from_y]       the model rises from below into place
##    "pillar": [t0, t1]             a column of light where it stands
##    "particles": ["embers", "wisps"]
##    "flash": t                     a white flash at t
##    "titles": [{"t0", "t1", "who", "name", "move"}]}
## await play(shot). With fast = true it returns at once (tests).

signal done

const W := 320
const H := 180

var fast := false
var shot: Dictionary = {}
var placeholder := false # the model is a blockout: a corner tag says so

var _vp: SubViewport
var _view: TextureRect
var _cam: Camera3D
var _we: WorldEnvironment
var _model: Node3D
var _pillar: MeshInstance3D
var _ring: MeshInstance3D
var _parts: Array = []
var _titles: Control
var _flash: ColorRect
var _dim: ColorRect
var _t := 0.0
var _flashed := false
var _running := false


static func toon_shader() -> Shader:
	var sh := Shader.new()
	sh.code = "
shader_type spatial;
render_mode cull_back, depth_draw_always;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_nearest;
uniform bool use_tex = false;
uniform vec4 glow : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.65, 0.85, 1.0, 1.0);
uniform float rim = 0.9;
void fragment() {
	vec4 c = albedo;
	if (use_tex) { c *= texture(tex, UV); }
	ALBEDO = c.rgb;
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = glow.rgb + rim_color.rgb * step(0.62, f) * rim * 0.6;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
void light() {
	float nl = dot(NORMAL, LIGHT);
	float band = nl > 0.55 ? 1.0 : (nl > 0.05 ? 0.55 : 0.15);
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
}
"
	return sh


static func outline_shader() -> Shader:
	var sh := Shader.new()
	sh.code = "
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_always;
uniform vec4 color : source_color = vec4(0.03, 0.03, 0.07, 1.0);
uniform float width = 0.03;
void vertex() { VERTEX += NORMAL * width; }
void fragment() { ALBEDO = color.rgb; }
"
	return sh


static var _toon_sh: Shader
static var _line_sh: Shader


## The toon material every PixelCG model uses (with its ink outline as a second pass).
static func toon(col: Color, tex: Texture2D = null, glow: Color = Color.BLACK) -> ShaderMaterial:
	if _toon_sh == null:
		_toon_sh = toon_shader()
		_line_sh = outline_shader()
	var m := ShaderMaterial.new()
	m.shader = _toon_sh
	m.set_shader_parameter("albedo", col)
	m.set_shader_parameter("glow", Color(glow.r, glow.g, glow.b, 1.0))
	if tex != null:
		m.set_shader_parameter("tex", tex)
		m.set_shader_parameter("use_tex", true)
	var line := ShaderMaterial.new()
	line.shader = _line_sh
	m.next_pass = line
	return m


## The upscale: posterize (or snap to a palette texture, if one is supplied) and a soft vignette. Nearest filtering
## does the pixel look; this keeps the colours in a limited set the way hand-made pixel art is.
static func post_material(palette: Texture2D) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "
shader_type canvas_item;
uniform sampler2D palette : filter_nearest;
uniform bool use_palette = false;
uniform int palette_size = 1;
uniform float levels = 10.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (use_palette) {
		vec3 best = c.rgb;
		float bd = 9.0;
		for (int i = 0; i < 64; i++) {
			if (i >= palette_size) { break; }
			vec3 p = texture(palette, vec2((float(i) + 0.5) / float(palette_size), 0.5)).rgb;
			float d = distance(c.rgb, p);
			if (d < bd) { bd = d; best = p; }
		}
		c.rgb = best;
	} else {
		c.rgb = floor(c.rgb * levels + 0.5) / levels;
	}
	COLOR = c;
}
"
	var m := ShaderMaterial.new()
	m.shader = sh
	if palette != null:
		m.set_shader_parameter("palette", palette)
		m.set_shader_parameter("palette_size", palette.get_width())
		m.set_shader_parameter("use_palette", true)
	return m


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func play(p_shot: Dictionary) -> void:
	shot = p_shot
	if fast:
		await get_tree().process_frame
		done.emit()
		return
	_build()
	_running = true
	_t = 0.0
	_step(0.0)
	await done


func _build() -> void:
	clip_contents = true
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.01, 0.04, 0.0)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.size = Vector2i(W, H)
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_view = TextureRect.new()
	_view.texture = _vp.get_texture()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pal_path := String(shot.get("palette", "res://assets/vfx/palette_hatid.png"))
	_view.material = post_material(load(pal_path) as Texture2D if ResourceLoader.exists(pal_path) else null)
	add_child(_view)
	_layout_view(Vector2.ZERO)

	# The summon cuts to its own place: night over Magwayen's river. An opaque world keeps glow, depth of field and
	# additive light correct on both renderers (Forward+ loses a transparent viewport's alpha under glow and DOF).
	var env := Environment.new()
	var sky_m := ProceduralSkyMaterial.new()
	sky_m.sky_top_color = Color(0.02, 0.03, 0.08)
	sky_m.sky_horizon_color = Color(0.08, 0.14, 0.24)
	sky_m.ground_horizon_color = Color(0.05, 0.09, 0.16)
	sky_m.ground_bottom_color = Color(0.01, 0.01, 0.03)
	sky_m.sky_curve = 0.12
	sky_m.sun_angle_max = 6.0 # the key light shows as a small moon, not a floodlight
	sky_m.sun_curve = 0.3
	var sky := Sky.new()
	sky.sky_material = sky_m
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.22, 0.38)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_we = WorldEnvironment.new()
	_we.environment = env
	if RenderTier.high():
		env.glow_enabled = true
		env.glow_intensity = 0.8
		env.glow_bloom = 0.1
		var ca := CameraAttributesPractical.new()
		ca.dof_blur_near_enabled = true
		ca.dof_blur_near_distance = 3.0
		ca.dof_blur_near_transition = 2.0
		ca.dof_blur_far_enabled = true
		ca.dof_blur_far_distance = 14.0
		ca.dof_blur_far_transition = 8.0
		ca.dof_blur_amount = 0.09
		_we.camera_attributes = ca
	_vp.add_child(_we)

	_cam = Camera3D.new()
	_cam.near = 0.2
	_cam.far = 80.0
	_vp.add_child(_cam)

	var key := DirectionalLight3D.new() # moonlight from the front left
	key.light_color = Color(0.75, 0.82, 1.0)
	key.light_energy = 0.9
	key.rotation_degrees = Vector3(-35, -30, 0)
	_vp.add_child(key)
	var back := DirectionalLight3D.new() # a cold rim from behind
	back.light_color = Color(0.5, 0.75, 1.0)
	back.light_energy = 1.4
	back.rotation_degrees = Vector3(-20, 160, 0)
	back.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY # one moon in the sky is enough
	_vp.add_child(back)

	var id := String(shot.get("model", ""))
	placeholder = Blockouts.is_placeholder(id)
	var river := MeshInstance3D.new() # the dark river the ferry crosses
	var rp := PlaneMesh.new()
	rp.size = Vector2(160, 160)
	river.mesh = rp
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(0.03, 0.06, 0.11)
	river.material_override = rm
	_vp.add_child(river)
	_model = Blockouts.model(id)
	_model.scale = Vector3.ONE * float(shot.get("scale", 1.0))
	_vp.add_child(_model)

	if shot.has("pillar"):
		_pillar = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.6
		cyl.bottom_radius = 1.2
		cyl.height = 40.0
		_pillar.mesh = cyl
		_pillar.material_override = _beam_material(Color(0.6, 0.8, 1.0))
		_pillar.position = Vector3(0, 20.0, 0)
		_vp.add_child(_pillar)
		_ring = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(7, 7)
		_ring.mesh = pm
		_ring.material_override = _ring_material(Color(0.7, 0.9, 1.0))
		_ring.position = Vector3(0, 0.05, 0)
		_vp.add_child(_ring)
	for kind in shot.get("particles", []):
		var p := _particles(String(kind))
		_vp.add_child(p)
		_parts.append(p)

	_titles = Control.new()
	_titles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_titles)
	for i in shot.get("titles", []).size():
		_titles.add_child(_title_card(shot["titles"][i]))

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	if placeholder:
		var tag := Placeholder.tag("3D model: %s (docs/ART_REQUESTS.md)" % id)
		tag.position = Vector2(14, 8)
		add_child(tag)


func _process(delta: float) -> void:
	if not _running:
		return
	_t += delta
	_step(delta)
	if _t >= float(shot.get("duration", 4.0)):
		_running = false
		var out := create_tween()
		out.tween_property(self, "modulate:a", 0.0, 0.25)
		await out.finished
		done.emit()


func _step(_delta: float) -> void:
	var dur := float(shot.get("duration", 4.0))
	# Dim the battle behind, then let it back in at the end.
	_dim.color.a = 0.0
	modulate.a = clampf(_t / 0.3, 0.0, 1.0) if _running else modulate.a
	# The model rises into place.
	var rise: Array = shot.get("rise", [])
	if rise.size() == 3:
		var k := _ease(clampf((_t - float(rise[0])) / maxf(0.01, float(rise[1]) - float(rise[0])), 0.0, 1.0))
		_model.position.y = lerpf(float(rise[2]), 0.0, k)
	_model.rotation.y = sin(_t * 0.8) * 0.06
	var body := _model.find_child("Body", true, false) as Node3D
	if body != null:
		body.position.y = 0.32 + sin(_t * 2.2) * 0.03 # a ghost never quite stands still
	var lamp := _model.find_child("LanternLight", true, false) as OmniLight3D
	if lamp != null:
		lamp.light_energy = 2.0 + sin(_t * 17.0) * 0.25 + sin(_t * 7.0) * 0.2
	if _pillar != null:
		var pl: Array = shot["pillar"]
		var a := clampf((_t - float(pl[0])) / 0.4, 0.0, 1.0) * clampf((float(pl[1]) - _t) / 0.6, 0.0, 1.0)
		(_pillar.material_override as ShaderMaterial).set_shader_parameter("strength", a)
		(_pillar.material_override as ShaderMaterial).set_shader_parameter("time", _t)
		(_ring.material_override as ShaderMaterial).set_shader_parameter("strength", a)
		_ring.rotation.y = _t * 0.6
	for t in _titles.get_children():
		var c := t as Control
		var t0 := float(c.get_meta("t0"))
		var t1 := float(c.get_meta("t1"))
		c.modulate.a = clampf((_t - t0) / 0.3, 0.0, 1.0) * clampf((t1 - _t) / 0.3, 0.0, 1.0)
	if shot.has("flash") and not _flashed and _t >= float(shot["flash"]):
		_flashed = true
		_flash.color.a = 0.9
		create_tween().tween_property(_flash, "color:a", 0.0, 0.35)
	_camera()


## Eased camera keys, then the pixel snap: the camera moves in whole texels at the focus distance, and the leftover
## fraction slides the whole upscaled image, so motion is smooth but the pixel grid never swims over the model.
func _camera() -> void:
	var keys: Array = shot.get("cam", [])
	if keys.is_empty():
		return
	var a: Dictionary = keys[0]
	var b: Dictionary = keys[0]
	for i in keys.size():
		if float(keys[i]["t"]) <= _t:
			a = keys[i]
			b = keys[mini(i + 1, keys.size() - 1)]
	var span := maxf(0.001, float(b["t"]) - float(a["t"]))
	var k := _ease(clampf((_t - float(a["t"])) / span, 0.0, 1.0)) if a != b else 0.0
	var pos := _v3(a["pos"]).lerp(_v3(b["pos"]), k)
	var look := _v3(a["look"]).lerp(_v3(b["look"]), k)
	_cam.fov = lerpf(float(a.get("fov", 40.0)), float(b.get("fov", 40.0)), k)
	_cam.position = pos
	_cam.look_at(look, Vector3.UP)
	var dist := pos.distance_to(look)
	var texel := 2.0 * dist * tan(deg_to_rad(_cam.fov) * 0.5) / float(H)
	var right := _cam.global_transform.basis.x
	var up := _cam.global_transform.basis.y
	var rx := pos.dot(right) / texel
	var ry := pos.dot(up) / texel
	var fx := rx - roundf(rx)
	var fy := ry - roundf(ry)
	_cam.position = pos - right * fx * texel - up * fy * texel
	_layout_view(Vector2(-fx, fy))
	if _we.camera_attributes is CameraAttributesPractical:
		var ca := _we.camera_attributes as CameraAttributesPractical
		ca.dof_blur_far_distance = dist + 3.0
		ca.dof_blur_near_distance = maxf(0.5, dist - 4.0)


## The upscaled image, one texel larger on every side so a sub-texel slide never shows an edge.
func _layout_view(frac: Vector2) -> void:
	var s := size if size.x > 0.0 else Vector2(1280, 720)
	var px := s / Vector2(W, H)
	_view.position = -px + frac * px
	_view.size = s + px * 2.0


func _title_card(d: Dictionary) -> Control:
	var box := Control.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_meta("t0", float(d.get("t0", 0.0)))
	box.set_meta("t1", float(d.get("t1", 1.0)))
	box.modulate.a = 0.0
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.position = Vector2(0, 500)
	shade.size = Vector2(1280, 190)
	box.add_child(shade)
	var rows := [[String(d.get("who", "")), Fonts.label_medium(), 20, Color(1, 1, 1, 0.8), 515.0],
		[String(d.get("name", "")), Fonts.display(), 60, Color("e8f4ff"), 548.0],
		[String(d.get("move", "")), Fonts.label(), 26, Color("ffe08a"), 630.0]]
	for r in rows:
		var l := Label.new()
		l.text = r[0]
		l.add_theme_font_override("font", r[1])
		l.add_theme_font_size_override("font_size", r[2])
		l.add_theme_color_override("font_color", r[3])
		l.position = Vector2(0, r[4])
		l.size = Vector2(1280, 70)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	return box


func _beam_material(col: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 color : source_color;
uniform float strength = 0.0;
uniform float time = 0.0;
void fragment() {
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	float bands = 0.75 + 0.25 * step(0.5, fract(UV.y * 6.0 - time * 0.8));
	float rise = smoothstep(0.0, 0.95, UV.y); // a cylinder's side runs UV.y 0 at the top to 1 at the base: bright below
	ALBEDO = color.rgb * strength * (1.0 - edge * 0.7) * bands * rise * 0.85;
}
"
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("color", col)
	return m


func _ring_material(col: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 color : source_color;
uniform float strength = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ring = step(0.78, r) * step(r, 0.86) + step(0.52, r) * step(r, 0.55) * step(0.5, fract(atan(p.y, p.x) * 3.0));
	ALBEDO = color.rgb * ring * strength;
}
"
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("color", col)
	return m


## Particles at 320x180 become one- and two-pixel sparks: exactly the pixel-art look.
func _particles(kind: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.mesh = q
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3.ZERO
	match kind:
		"embers":
			q.size = Vector2(0.08, 0.08)
			p.amount = 90
			p.lifetime = 2.6
			p.emission_box_extents = Vector3(2.6, 0.2, 2.6)
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 2.6
			p.color = Color(1.0, 0.62, 0.25)
			p.position = Vector3(0, 0.2, 0)
		_: # "wisps": slow spirit lights
			q.size = Vector2(0.1, 0.1)
			p.amount = 36
			p.lifetime = 4.0
			p.emission_box_extents = Vector3(3.5, 2.5, 3.5)
			p.initial_velocity_min = 0.2
			p.initial_velocity_max = 0.6
			p.color = Color(0.6, 0.85, 1.0)
			p.position = Vector3(0, 3.0, 0)
	return p


static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)
