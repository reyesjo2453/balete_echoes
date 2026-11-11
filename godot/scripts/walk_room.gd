class_name WalkRoom
extends Control
## A walkable side-view room (the wake): Teo walks left and right across a wide painted background and talks to
## people where they sit. It replaces the hub menu for a hub beat that has a "room".
##
## Walk: arrow keys, A/D or the d-pad / left stick; or tap / click anywhere on the floor.
## Talk: walk up to someone and press SPACE / E / controller A, or tap their name tag (Teo walks over first).
## Leave: the exit tag (the stairs) unlocks once `need` people have been heard.
##
## Each person's tag is a Button named Hub_<option index>, and the exit is HubGo, the same names as the hub menu,
## so saves, tests and the hub flow work the same in both.

signal picked(index: int)

const SPEED := 330.0
const REACH := 120.0 # how close Teo must be to talk
const FEET_Y := 706.0
const TEO_SCALE := 0.95
const NPC_FEET_Y := 628.0
const NPC_SCALE := 0.9
const FRAME_TIME := 0.13

var beat: Dictionary
var heard: Dictionary
var need: int = 0
var teo_x: float = 160.0
var test_fast := false

var _room: Dictionary
var _options: Array
var _world: Control
var _bg: TextureRect
var _teo: TextureRect
var _teo_shadow: Polygon2D
var _frames: Array[Texture2D] = []
var _frame_t := 0.0
var _frame := 1
var _facing := 1.0
var _target := -1.0 # where a tap or tag sent Teo (-1: no target)
var _pending := -2 # what to do on arrival: an option index, -1 leave, -2 nothing
var _tags: Array[Button] = []
var _go: Button
var _hint: Label
var _count: Label
var _room_w := 2160.0
var _done := false
var _t := 0.0
var _npcs: Array = [] # [{"rect", "base_y", "ghost"}]


func setup(p_beat: Dictionary, p_heard: Dictionary, p_need: int, start_x: float) -> void:
	beat = p_beat
	heard = p_heard
	need = p_need
	_room = beat.get("room", {})
	_options = beat.get("options", [])
	teo_x = start_x if start_x >= 0.0 else float(_room.get("teo_x", 160.0))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var back := ColorRect.new()
	back.color = Color(0.02, 0.03, 0.06)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	_world = Control.new()
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_world)
	_bg = TextureRect.new()
	_bg.texture = Art.room(String(_room.get("bg", "room")))
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _bg.texture != null:
		_room_w = 720.0 * _bg.texture.get_width() / float(_bg.texture.get_height())
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.size = Vector2(_room_w, 720)
	_world.add_child(_bg)
	_world.size = Vector2(_room_w, 720)

	# People who sit in the room: those you can talk to, then the ones who only watch.
	for i in _options.size():
		var o: Dictionary = _options[i]
		if o.has("sprite"):
			_add_npc(String(o["sprite"]), float(o.get("sprite_x", o.get("x", 0.0))), false)
	for e in _room.get("extras", []):
		_add_npc(String(e["sprite"]), float(e["x"]), bool(e.get("ghost", false)))

	for n in 4:
		var tex := Art.room("teo_walk_%d" % n)
		if tex != null:
			_frames.append(tex)
	_teo_shadow = _shadow(130.0)
	_world.add_child(_teo_shadow)
	_teo = TextureRect.new()
	_teo.name = "Teo"
	_teo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_teo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_teo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_teo.size = Vector2(260, 420) * TEO_SCALE
	_world.add_child(_teo)

	for i in _options.size():
		var o: Dictionary = _options[i]
		var b := _tag("Hub_%d" % i)
		b.text = ("HEARD:  " if heard.has(i) else "") + String(o.get("short", o.get("label", o.get("scene", ""))))
		b.disabled = heard.has(i)
		var idx := i
		b.pressed.connect(func() -> void: _walk_to(float(o.get("x", 0.0)), idx))
		_tags.append(b)
	_go = _tag("HubGo")
	_go.text = String(beat.get("leave", "MOVE ON"))
	_go.disabled = heard.size() < need
	_go.pressed.connect(func() -> void: _walk_to(float(_room.get("exit_x", _room_w - 120.0)), -1))

	_build_hud()
	_place_tags()
	_update(0.0)


func _add_npc(sprite: String, x: float, ghost: bool) -> void:
	var tex := Art.room(sprite)
	if tex == null:
		return
	var sh := _shadow(110.0)
	sh.position = Vector2(x, NPC_FEET_Y)
	_world.add_child(sh)
	var r := TextureRect.new()
	r.name = "Npc_" + sprite
	r.texture = tex
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = Vector2(tex.get_width(), tex.get_height()) * NPC_SCALE
	r.position = Vector2(x - r.size.x * 0.5, NPC_FEET_Y - r.size.y)
	r.pivot_offset = Vector2(r.size.x * 0.5, r.size.y)
	if ghost:
		r.modulate = Color(1, 1, 1, 0.72)
		sh.modulate = Color(1, 1, 1, 0.3)
	_world.add_child(r)
	_npcs.append({"rect": r, "base_y": r.position.y, "ghost": ghost, "phase": x * 0.01})


func _shadow(w: float) -> Polygon2D:
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		pts.append(Vector2(cos(a) * w * 0.5, sin(a) * w * 0.09))
	p.polygon = pts
	p.color = Color(0, 0, 0, 0.42)
	return p


func _tag(node_name: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.add_theme_font_override("font", Fonts.label())
	b.add_theme_font_size_override("font_size", 18)
	b.custom_minimum_size = Vector2(0, 40)
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.04, 0.05, 0.1, 0.55 if st == "disabled" else 0.86)
		box.border_color = Color("c9a24a") if st != "disabled" else Color(1, 1, 1, 0.25)
		box.set_border_width_all(2)
		box.set_corner_radius_all(6)
		box.content_margin_left = 14
		box.content_margin_right = 14
		box.content_margin_top = 4
		box.content_margin_bottom = 4
		b.add_theme_stylebox_override(st, box)
	b.add_theme_color_override("font_color", Color("f2efe4"))
	b.add_theme_color_override("font_hover_color", Color("e8c872"))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))
	_world.add_child(b)
	return b


## Tags float over the person (or the place) they belong to.
func _place_tags() -> void:
	for i in _tags.size():
		var o: Dictionary = _options[i]
		var b := _tags[i]
		b.reset_size()
		b.position = Vector2(float(o.get("x", 0.0)) - b.size.x * 0.5, float(o.get("tag_y", 250.0)))
	_go.reset_size()
	_go.position = Vector2(float(_room.get("exit_x", _room_w - 120.0)) - _go.size.x * 0.5, float(_room.get("exit_tag_y", 170.0)))


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
	_hint.text = "◀ ▶  walk      SPACE / A  talk      or tap where to go"
	_hint.add_theme_font_override("font", Fonts.label_medium())
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -34
	_hint.offset_bottom = -8
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	_refresh_count()


func _refresh_count() -> void:
	var left := maxi(0, need - heard.size())
	if left > 0:
		_count.text = "%s   (talk to %d more before you can leave)" % [String(beat.get("goal", "")), left]
	else:
		_count.text = "%s   You can go upstairs when you're ready." % String(beat.get("goal", ""))


func _walk_to(x: float, then: int) -> void:
	if _done:
		return
	if then == -1 and heard.size() < need:
		return
	_target = clampf(x, 60.0, _room_w - 60.0)
	_pending = then
	if test_fast:
		teo_x = _target
		_arrive()


func _arrive() -> void:
	_target = -1.0
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
		if heard.has(i):
			continue
		var d := absf(float(_options[i].get("x", 0.0)) - teo_x)
		if d < best_d:
			best_d = d
			best = i
	if heard.size() >= need and absf(float(_room.get("exit_x", _room_w - 120.0)) - teo_x) < REACH:
		best = -1
	return best


func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	var at := Vector2(-1, -1)
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		at = mouse.position
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed:
		at = touch.position
	if at.x >= 0.0:
		_walk_to(at.x - _world.position.x, -2)
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _done or not is_visible_in_tree():
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


func _process(delta: float) -> void:
	_t += delta
	if not _done:
		var axis := Input.get_axis("ui_left", "ui_right")
		if Input.is_physical_key_pressed(KEY_A):
			axis -= 1.0
		if Input.is_physical_key_pressed(KEY_D):
			axis += 1.0
		axis = clampf(axis, -1.0, 1.0)
		if absf(axis) > 0.2:
			_target = -1.0
			_pending = -2
			_step(axis * SPEED * delta, delta)
		elif _target >= 0.0:
			var dx := _target - teo_x
			if absf(dx) <= SPEED * delta:
				_step(dx, delta)
				_arrive()
			else:
				_step(signf(dx) * SPEED * delta, delta)
		else:
			_frame = 1
	_update(delta)


func _step(dx: float, delta: float) -> void:
	teo_x = clampf(teo_x + dx, 60.0, _room_w - 60.0)
	if absf(dx) > 0.01:
		_facing = signf(dx)
		_frame_t += delta
		if _frame_t >= FRAME_TIME:
			_frame_t = 0.0
			_frame = (_frame + 1) % 4


func _update(_delta: float) -> void:
	if _frames.size() == 4:
		_teo.texture = _frames[_frame]
	_teo.flip_h = _facing < 0.0
	_teo.position = Vector2(teo_x - _teo.size.x * 0.5, FEET_Y - _teo.size.y + (2.0 if _frame % 2 == 1 else 0.0))
	_teo_shadow.position = Vector2(teo_x, FEET_Y - 4.0)
	var view_w := size.x if size.x > 0.0 else 1280.0
	var cam := clampf(teo_x - view_w * 0.5, 0.0, maxf(0.0, _room_w - view_w))
	_world.position.x = -cam
	for n in _npcs:
		var r: TextureRect = n["rect"]
		var ph: float = n["phase"]
		if n["ghost"]:
			r.position.y = float(n["base_y"]) - 6.0 - sin(_t * 1.3 + ph) * 6.0
			r.modulate.a = 0.62 + sin(_t * 2.1 + ph) * 0.1
		else:
			r.scale = Vector2(1.0, 1.0 + sin(_t * 1.6 + ph) * 0.008) # breathing
	var near := nearest()
	for i in _tags.size():
		var b := _tags[i]
		b.modulate = Color(1, 1, 1, 1.0 if i == near else (0.5 if heard.has(i) else 0.82))
	_go.modulate = Color(1, 1, 1, 1.0 if near == -1 else 0.82)
	if near >= 0:
		_hint.text = "SPACE / A  talk to %s      ◀ ▶  walk" % String(_options[near].get("short", "them"))
	elif near == -1:
		_hint.text = "SPACE / A  %s      ◀ ▶  walk" % String(beat.get("leave", "leave")).to_lower()
	else:
		_hint.text = "◀ ▶  walk      SPACE / A  talk      or tap where to go"
