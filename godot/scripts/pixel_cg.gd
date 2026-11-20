class_name PixelCG
extends Control
## Cinematic pixel art made from 3D CG (docs/HD2D_TECH.md). A small 3D world is rendered into a 320x180 viewport with
## stepped (toon) lighting, ink outlines and a limited palette, then scaled up without smoothing over the battle or
## map. The camera can crane, orbit and push in freely and it still reads as pixel art. Works on both render tiers;
## on HIGH (Forward+) it adds depth of field and glow.
##
## play() takes a SEQUENCE: {"id": "tawag_pido", "cuts": [cut, cut, ...]} (a single cut dictionary also works).
## The id makes it skippable once it has been watched (Progress.seen_cg). Every key of a cut is optional:
##   "dur": 2.5                       seconds (old single shots used "duration")
##   "in": "cut" | "flash" | "fade" | "wipe"      how this cut starts
##   "cam": [{"t", "pos": [x,y,z], "look": [x,y,z], "fov"}]          eased between keys, pixel-snapped
##   "model": id (Blockouts), "scale", "at": [x,y,z], "rot_y" (deg), "rise": [t0, t1, from_y],
##   "move": [{"t", "pos", "rot_y"}]   the model travels; "nodes": {"SwordArm": [{"t", "rot": [deg x,y,z]}]}
##   "lantern": [{"t", "e"}]          the model's LanternLight energy over time (dims as he leaves)
##   "sprites": [{"path", "h", "at", "move": [{"t","pos"}], "swap": [[t, path]], "hit": t, "flip"}]
##                                     pixel-art billboards (the real enemy sprite in the CG world)
##   "props": ["candle"], "candle_out": t      Lola's candle, and the moment it gutters
##   "fog": n                         drifting fog banks;  "wake": [t0, t1]  spray at the boat's prow
##   "pillar": [t0, t1], "particles": ["embers", "wisps"], "flash": t, "titles": [{"t0","t1","who","name","move"}]
##   "slash": [{"t", "at", "size", "rot", "color"}]   a crescent cut;  "shock": [{"t", "at", "size"}]  a ground ring
##   "hitstop": [{"t", "dur"}]        the picture freezes;  "shake": [{"t", "amp", "dur"}]  the camera jolts (px)
##   "slowmo": [t0, t1, factor]       time runs slower in this window;  "sfx": [[t, name]]  sound cues (Sfx)
## await play(seq). With fast = true it returns at once (tests).

signal done

const W := 320
const H := 180

var fast := false
var shot: Dictionary = {} # the current cut
var seq: Dictionary = {}
var placeholder := false # a model in the sequence is still a blockout: a corner tag says so
var skipped := false
var cuts_played := 0

var _cuts: Array = []
var _ci := -1
var _vp: SubViewport
var _view: TextureRect
var _cam: Camera3D
var _we: WorldEnvironment
var _stage: Node3D # everything that belongs to the current cut
var _model: Node3D
var _pillar: MeshInstance3D
var _ring: MeshInstance3D
var _parts: Array = []
var _wake: CPUParticles3D
var _sprites: Array = [] # [{node, spec}]
var _fx: Array = [] # [{node, t, kind, spec}]
var _fogs: Array = []
var _candle: Node3D
var _titles: Control
var _flash: ColorRect
var _dim: ColorRect
var _bars: Array = []
var _hint: Label
var _t := 0.0
var _hold := 0.0
var _shake_t := 0.0
var _shake_amp := 0.0
var _fired := {}
var _flashed := false
var _running := false
var _snap := Vector2.ZERO


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


func play(p_seq: Dictionary) -> void:
	seq = p_seq
	_cuts = p_seq.get("cuts", [p_seq])
	if fast:
		await get_tree().process_frame
		cuts_played = _cuts.size()
		done.emit()
		return
	_build()
	_running = true
	_next_cut()
	await done


## Skippable only once it has been seen to the end (the first viewing always plays: FF7 rules).
func can_skip() -> bool:
	return String(seq.get("id", "")) != "" and Progress.saw_cg(String(seq.get("id", "")))


func skip() -> void:
	if _running and can_skip():
		skipped = true
		_finish()


func _input(event: InputEvent) -> void:
	if not _running or not can_skip():
		return
	var hit := false
	if event is InputEventKey and event.pressed and not event.echo:
		hit = (event as InputEventKey).keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE, KEY_KP_ENTER]
	elif event is InputEventScreenTouch and event.pressed:
		hit = true
	elif event is InputEventMouseButton and event.pressed:
		hit = true
	if hit:
		get_viewport().set_input_as_handled()
		skip()


func _build() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP # the battle underneath gets no clicks while the summon plays
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 1.0)
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
	var pal_path := String(seq.get("palette", "res://assets/vfx/palette_hatid.png"))
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
	_cam.near = 0.1
	_cam.far = 90.0
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

	var river := MeshInstance3D.new() # the dark river the ferry crosses
	var rp := PlaneMesh.new()
	rp.size = Vector2(160, 160)
	river.mesh = rp
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(0.03, 0.06, 0.11)
	river.material_override = rm
	_vp.add_child(river)

	_titles = Control.new()
	_titles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_titles)
	for top in [true, false]: # letterbox: it's a film now
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.position = Vector2(0, 0 if top else 720 - 64)
		bar.size = Vector2(1280, 64)
		add_child(bar)
		_bars.append(bar)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	for c in _cuts:
		var mid := String((c as Dictionary).get("model", ""))
		if mid != "" and Blockouts.is_placeholder(mid):
			placeholder = true
			var tag := Placeholder.tag("3D model: %s (docs/ART_REQUESTS.md)" % mid)
			tag.position = Vector2(14, 72)
			add_child(tag)
			break
	if can_skip():
		_hint = Label.new()
		_hint.text = "TAP TO SKIP"
		_hint.add_theme_font_override("font", Fonts.label())
		_hint.add_theme_font_size_override("font_size", 16)
		_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		_hint.position = Vector2(1120, 680)
		_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_hint)


## Tears down the last cut's things and builds the next one.
func _next_cut() -> void:
	_ci += 1
	if _ci >= _cuts.size():
		Progress.mark_cg(String(seq.get("id", "")))
		_finish()
		return
	cuts_played = _ci + 1
	shot = _cuts[_ci]
	if _stage != null:
		_stage.queue_free()
	for c in _titles.get_children():
		c.queue_free()
	_stage = Node3D.new()
	_vp.add_child(_stage)
	_model = null
	_pillar = null
	_ring = null
	_wake = null
	_candle = null
	_parts.clear()
	_sprites.clear()
	_fx.clear()
	_fogs.clear()
	_fired.clear()
	_flashed = false
	_t = 0.0
	_hold = 0.0

	var id := String(shot.get("model", ""))
	if id != "":
		_model = Blockouts.model(id)
		_model.scale = Vector3.ONE * float(shot.get("scale", 1.0))
		_model.position = _v3(shot.get("at", [0, 0, 0]))
		_model.rotation_degrees.y = float(shot.get("rot_y", 0.0))
		_stage.add_child(_model)
	if shot.has("pillar"):
		_pillar = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.6
		cyl.bottom_radius = 1.2
		cyl.height = 40.0
		_pillar.mesh = cyl
		_pillar.material_override = _beam_material(Color(0.6, 0.8, 1.0))
		_pillar.position = _v3(shot.get("at", [0, 0, 0])) + Vector3(0, 20.0, 0)
		_stage.add_child(_pillar)
		_ring = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(7, 7)
		_ring.mesh = pm
		_ring.material_override = _ring_material(Color(0.7, 0.9, 1.0))
		_ring.position = _v3(shot.get("at", [0, 0, 0])) + Vector3(0, 0.05, 0)
		_stage.add_child(_ring)
	for kind in shot.get("particles", []):
		var p := _particles(String(kind))
		p.position += _v3(shot.get("at", [0, 0, 0]))
		_stage.add_child(p)
		_parts.append(p)
	if shot.has("wake") and _model != null:
		_wake = _particles("wake")
		_wake.position = Vector3(0, 0.2, 1.0)
		_wake.emitting = false
		_model.add_child(_wake)
	if (shot.get("props", []) as Array).has("candle"):
		_candle = _make_candle()
		_stage.add_child(_candle)
	for i in int(shot.get("fog", 0)):
		var f := _fog_bank(i)
		_stage.add_child(f)
		_fogs.append(f)
	for sp in shot.get("sprites", []):
		var node := _sprite(sp)
		if node != null:
			_stage.add_child(node)
			_sprites.append({"node": node, "spec": sp})
	for sl in shot.get("slash", []):
		var n := _slash_node(sl)
		n.visible = false
		_stage.add_child(n)
		_fx.append({"node": n, "t": float(sl.get("t", 0.0)), "kind": "slash", "spec": sl})
	for sk in shot.get("shock", []):
		var r := MeshInstance3D.new()
		var pm2 := PlaneMesh.new()
		pm2.size = Vector2(2, 2)
		r.mesh = pm2
		r.material_override = _ring_material(Color(sk.get("color", "e8f4ff")))
		r.position = _v3(sk.get("at", [0, 0.06, 0]))
		r.visible = false
		_stage.add_child(r)
		_fx.append({"node": r, "t": float(sk.get("t", 0.0)), "kind": "shock", "spec": sk})
	for i in shot.get("titles", []).size():
		_titles.add_child(_title_card(shot["titles"][i]))

	match String(shot.get("in", "cut")):
		"flash":
			_flash.color = Color(1, 1, 1, 1)
			create_tween().tween_property(_flash, "color:a", 0.0, 0.3)
		"fade":
			_flash.color = Color(0, 0, 0, 1)
			create_tween().tween_property(_flash, "color:a", 0.0, 0.45)
		"wipe":
			var w := ColorRect.new()
			w.color = Color.BLACK
			w.mouse_filter = Control.MOUSE_FILTER_IGNORE
			w.position = Vector2(0, 0)
			w.size = Vector2(1280, 720)
			add_child(w)
			move_child(w, _flash.get_index())
			var tw := create_tween()
			tw.tween_property(w, "position:x", 1300.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(w.queue_free)
	_step(0.0)


func _finish() -> void:
	if not _running:
		return
	_running = false
	var out := create_tween()
	out.tween_property(self, "modulate:a", 0.0, 0.05 if skipped else 0.3)
	await out.finished
	done.emit()


func _process(delta: float) -> void:
	if not _running:
		return
	if _shake_t > 0.0:
		_shake_t = maxf(0.0, _shake_t - delta)
	if _hold > 0.0: # hitstop: the picture freezes, the shake doesn't
		_hold -= delta
		_layout_view(_snap)
		return
	var rate := 1.0
	var sm: Array = shot.get("slowmo", [])
	if sm.size() == 3 and _t >= float(sm[0]) and _t < float(sm[1]):
		rate = float(sm[2])
	_t += delta * rate
	_step(delta)
	if _t >= float(shot.get("dur", shot.get("duration", 4.0))):
		_next_cut()


func _step(_delta: float) -> void:
	if _ci == 0:
		modulate.a = clampf(_t / 0.3, 0.0, 1.0) if _running else modulate.a
	for ev in shot.get("hitstop", []):
		var key := "hs%s" % str(ev.get("t", 0.0))
		if not _fired.has(key) and _t >= float(ev.get("t", 0.0)):
			_fired[key] = true
			_hold = float(ev.get("dur", 0.12))
	for ev in shot.get("sfx", []): # [[t, name], ...]
		var key := "fx%s%s" % [str(ev[0]), String(ev[1])]
		if not _fired.has(key) and _t >= float(ev[0]):
			_fired[key] = true
			Sfx.play(String(ev[1]))
	for ev in shot.get("shake", []):
		var key := "sh%s" % str(ev.get("t", 0.0))
		if not _fired.has(key) and _t >= float(ev.get("t", 0.0)):
			_fired[key] = true
			_shake_amp = float(ev.get("amp", 8.0))
			_shake_t = float(ev.get("dur", 0.4))
	if _model != null:
		var rise: Array = shot.get("rise", [])
		var base := _v3(shot.get("at", [0, 0, 0]))
		var mv: Array = shot.get("move", [])
		if not mv.is_empty():
			var kd := _keyed(mv)
			base = _v3(kd[0].get("pos", [0, 0, 0])).lerp(_v3(kd[1].get("pos", [0, 0, 0])), kd[2])
			_model.rotation_degrees.y = lerpf(float(kd[0].get("rot_y", shot.get("rot_y", 0.0))), float(kd[1].get("rot_y", shot.get("rot_y", 0.0))), kd[2])
		else:
			_model.rotation_degrees.y = float(shot.get("rot_y", 0.0)) + sin(_t * 0.8) * 3.0
		if rise.size() == 3:
			var k := _ease(clampf((_t - float(rise[0])) / maxf(0.01, float(rise[1]) - float(rise[0])), 0.0, 1.0))
			base.y += lerpf(float(rise[2]), 0.0, k)
		_model.position = base
		var body := _model.find_child("Body", true, false) as Node3D
		if body != null and not (shot.get("nodes", {}) as Dictionary).has("Body"):
			body.position.y = 0.32 + sin(_t * 2.2) * 0.03 # a ghost never quite stands still
		var nodes: Dictionary = shot.get("nodes", {})
		for nm in nodes:
			var n := _model.find_child(String(nm), true, false) as Node3D
			if n == null:
				continue
			var kd := _keyed(nodes[nm])
			if kd[0].has("rot"):
				n.rotation_degrees = _v3(kd[0]["rot"]).lerp(_v3(kd[1].get("rot", kd[0]["rot"])), kd[2])
			if kd[0].has("pos"):
				n.position = _v3(kd[0]["pos"]).lerp(_v3(kd[1].get("pos", kd[0]["pos"])), kd[2])
		var lamp := _model.find_child("LanternLight", true, false) as OmniLight3D
		if lamp != null:
			var e := 2.0
			var lk: Array = shot.get("lantern", [])
			if not lk.is_empty():
				var kd := _keyed(lk)
				e = lerpf(float(kd[0].get("e", 2.0)), float(kd[1].get("e", 2.0)), kd[2])
			lamp.light_energy = maxf(0.0, e + (sin(_t * 17.0) * 0.25 + sin(_t * 7.0) * 0.2) * minf(1.0, e))
		if _wake != null:
			var wk: Array = shot["wake"]
			_wake.emitting = _t >= float(wk[0]) and _t < float(wk[1])
	if _pillar != null:
		var pl: Array = shot["pillar"]
		var a := clampf((_t - float(pl[0])) / 0.4, 0.0, 1.0) * clampf((float(pl[1]) - _t) / 0.6, 0.0, 1.0)
		(_pillar.material_override as ShaderMaterial).set_shader_parameter("strength", a)
		(_pillar.material_override as ShaderMaterial).set_shader_parameter("time", _t)
		(_ring.material_override as ShaderMaterial).set_shader_parameter("strength", a)
		_ring.rotation.y = _t * 0.6
	if _candle != null:
		var out_t := float(shot.get("candle_out", 99.0))
		var k := clampf((_t - out_t) / 0.5, 0.0, 1.0)
		var flame := _candle.get_node("Flame") as Node3D
		flame.scale = Vector3.ONE * (1.0 + sin(_t * 23.0) * 0.08 + sin(_t * 9.0) * 0.06) * (1.0 - k)
		flame.position.x = sin(_t * 5.0) * 0.01 + k * 0.03
		(_candle.get_node("Light") as OmniLight3D).light_energy = (2.4 + sin(_t * 19.0) * 0.3) * (1.0 - k)
	for i in _fogs.size():
		var f: Node3D = _fogs[i]
		f.position.x = float(f.get_meta("x0")) + _t * float(f.get_meta("v"))
	for s in _sprites:
		_step_sprite(s["node"], s["spec"])
	for e in _fx:
		var n: MeshInstance3D = e["node"]
		var lt := _t - float(e["t"])
		n.visible = lt >= 0.0 and lt < 0.6
		if not n.visible:
			continue
		var m := n.material_override as ShaderMaterial
		if e["kind"] == "slash":
			m.set_shader_parameter("progress", clampf(lt / 0.16, 0.0, 1.0))
			m.set_shader_parameter("fade", 1.0 - clampf((lt - 0.2) / 0.4, 0.0, 1.0))
		else:
			var sz := float(e["spec"].get("size", 6.0))
			n.scale = Vector3.ONE * lerpf(0.4, sz, _ease(clampf(lt / 0.5, 0.0, 1.0)))
			m.set_shader_parameter("strength", 1.0 - clampf(lt / 0.6, 0.0, 1.0))
	for t in _titles.get_children():
		var c := t as Control
		var t0 := float(c.get_meta("t0"))
		var t1 := float(c.get_meta("t1"))
		c.modulate.a = clampf((_t - t0) / 0.3, 0.0, 1.0) * clampf((t1 - _t) / 0.3, 0.0, 1.0)
	if shot.has("flash") and not _flashed and _t >= float(shot["flash"]):
		_flashed = true
		_flash.color = Color(1, 1, 1, 0.9)
		create_tween().tween_property(_flash, "color:a", 0.0, 0.35)
	_camera()


## [key_a, key_b, eased k] for a list of {"t": ...} keys at the current time.
func _keyed(keys: Array) -> Array:
	var a: Dictionary = keys[0]
	var b: Dictionary = keys[0]
	for i in keys.size():
		if float(keys[i]["t"]) <= _t:
			a = keys[i]
			b = keys[mini(i + 1, keys.size() - 1)]
	var span := maxf(0.001, float(b["t"]) - float(a["t"]))
	var k := _ease(clampf((_t - float(a["t"])) / span, 0.0, 1.0)) if a != b else 0.0
	return [a, b, k]


## Eased camera keys, then the pixel snap: the camera moves in whole texels at the focus distance, and the leftover
## fraction slides the whole upscaled image, so motion is smooth but the pixel grid never swims over the model.
func _camera() -> void:
	var keys: Array = shot.get("cam", [])
	if keys.is_empty():
		return
	var kd := _keyed(keys)
	var a: Dictionary = kd[0]
	var b: Dictionary = kd[1]
	var k: float = kd[2]
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
	_snap = Vector2(-fx, fy)
	_layout_view(_snap)
	if _we.camera_attributes is CameraAttributesPractical:
		var ca := _we.camera_attributes as CameraAttributesPractical
		ca.dof_blur_far_distance = dist + 3.0
		ca.dof_blur_near_distance = maxf(0.5, dist - 4.0)


## The upscaled image, one texel larger on every side so a sub-texel slide never shows an edge. A camera shake jolts
## it by whole screen texels, so the pixel art stays crisp while it shakes.
func _layout_view(frac: Vector2) -> void:
	var s := size if size.x > 0.0 else Vector2(1280, 720)
	var px := s / Vector2(W, H)
	var jolt := Vector2.ZERO
	if _shake_t > 0.0:
		var a := _shake_amp * minf(1.0, _shake_t * 3.0)
		jolt = Vector2(roundf(randf_range(-a, a) / px.x), roundf(randf_range(-a, a) / px.y)) * px
	_view.position = -px + frac * px + jolt
	_view.size = s + px * 2.0


func _step_sprite(n: Sprite3D, sp: Dictionary) -> void:
	var mv: Array = sp.get("move", [])
	if not mv.is_empty():
		var kd := _keyed(mv)
		n.position = _v3(kd[0]["pos"]).lerp(_v3(kd[1]["pos"]), kd[2])
	for sw in sp.get("swap", []):
		if _t >= float(sw[0]) and n.get_meta("tex_path", "") != String(sw[1]) and ResourceLoader.exists(String(sw[1])):
			var last := ""
			for s2 in sp.get("swap", []):
				if _t >= float(s2[0]):
					last = String(s2[1])
			if last != "" and n.get_meta("tex_path", "") != last and ResourceLoader.exists(last):
				n.texture = load(last)
				n.set_meta("tex_path", last)
	if sp.has("hit"):
		var lt := _t - float(sp["hit"])
		var hit_on := lt >= 0.0 and lt < 0.5
		n.modulate = Color(3, 3, 3) if hit_on and int(lt * 20.0) % 2 == 0 else Color.WHITE
		if hit_on:
			n.position.x += sin(lt * 90.0) * 0.12 * (1.0 - lt * 2.0)


func _sprite(sp: Dictionary) -> Sprite3D:
	var path := String(sp.get("path", ""))
	var tex: Texture2D = sp.get("tex", null)
	if tex == null:
		tex = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else Placeholder.texture("cg_sprite", Vector2i(32, 48))
	var s := Sprite3D.new()
	s.texture = tex
	s.set_meta("tex_path", path)
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.centered = true
	s.offset = Vector2(0, tex.get_height() * 0.5)
	s.pixel_size = float(sp.get("h", 3.0)) / float(maxi(1, tex.get_height()))
	s.flip_h = bool(sp.get("flip", false))
	s.position = _v3(sp.get("at", [0, 0, 0]))
	return s


## Lola's candle, close enough to fill the frame.
func _make_candle() -> Node3D:
	var root := Node3D.new()
	var wax := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.09
	c.bottom_radius = 0.1
	c.height = 0.9
	c.radial_segments = 10
	wax.mesh = c
	wax.material_override = toon(Color(0.92, 0.88, 0.76), null, Color(0.25, 0.15, 0.05))
	wax.position = Vector3(0, 0.45, 0)
	root.add_child(wax)
	var flame := MeshInstance3D.new()
	flame.name = "Flame"
	var sm := SphereMesh.new()
	sm.radius = 0.022
	sm.height = 0.075
	flame.mesh = sm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.82, 0.4)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.6, 0.2)
	fm.emission_energy_multiplier = 3.0
	flame.material_override = fm
	flame.position = Vector3(0, 0.94, 0)
	root.add_child(flame)
	var l := OmniLight3D.new()
	l.name = "Light"
	l.light_color = Color(1.0, 0.7, 0.35)
	l.omni_range = 5.0
	l.position = Vector3(0, 1.05, 0)
	root.add_child(l)
	return root


## A soft bank of river fog drifting across the frame.
func _fog_bank(i: int) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(16.0 + float(i % 3) * 6.0, 3.0 + float(i % 2) * 1.5)
	m.mesh = q
	var sh := Shader.new()
	sh.code = "
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform float alpha = 0.35;
void vertex() { MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]); }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = 1.0 - clamp(length(p * vec2(1.0, 1.6)), 0.0, 1.0);
	ALBEDO = vec3(0.55, 0.65, 0.8);
	ALPHA = d * d * alpha;
}
"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	m.material_override = mat
	var x0 := -14.0 + float((i * 37) % 28)
	m.position = Vector3(x0, 0.8 + float(i % 3) * 0.6, -4.0 - float((i * 13) % 22))
	m.set_meta("x0", x0)
	m.set_meta("v", 0.5 + float(i % 4) * 0.25)
	return m


## A crescent cut through the air: a billboard quad whose arc draws itself on (progress), then fades.
func _slash_node(sl: Dictionary) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	var sz := float(sl.get("size", 4.0))
	q.size = Vector2(sz, sz)
	m.mesh = q
	var sh := Shader.new()
	sh.code = "
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 color : source_color;
uniform float progress = 0.0;
uniform float fade = 1.0;
uniform float tilt = 0.0;
void vertex() { MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]); }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float c = cos(tilt); float s = sin(tilt);
	p = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
	float r = length(p);
	float ang = atan(p.y, p.x); // -pi..pi; the arc runs over the top half
	float along = clamp((ang + 0.2) / 3.5, 0.0, 1.0);
	float on = step(along, progress) * step(-0.2, ang) * step(ang, 3.3);
	float band = smoothstep(0.62, 0.8, r) * (1.0 - smoothstep(0.86, 0.96, r));
	float core = smoothstep(0.74, 0.8, r) * (1.0 - smoothstep(0.82, 0.86, r));
	ALBEDO = (color.rgb * band + vec3(1.0) * core) * on * fade * (0.4 + 0.6 * along);
}
"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("color", Color(sl.get("color", "bfe4ff")))
	mat.set_shader_parameter("tilt", deg_to_rad(float(sl.get("rot", 0.0))))
	m.material_override = mat
	m.position = _v3(sl.get("at", [0, 2, 0]))
	return m


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
		"wake": # spray thrown off the prow
			q.size = Vector2(0.07, 0.07)
			p.amount = 70
			p.lifetime = 0.9
			p.emission_box_extents = Vector3(0.35, 0.05, 0.1)
			p.direction = Vector3(0, 1, 0.4)
			p.spread = 55.0
			p.initial_velocity_min = 1.2
			p.initial_velocity_max = 2.4
			p.gravity = Vector3(0, -6.0, 0)
			p.color = Color(0.7, 0.85, 1.0)
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
