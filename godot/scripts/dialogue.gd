class_name Dialogue
extends Control
## Plays a list of story steps (see data/*.json): a comic panel behind three different bars.
##   say   - spoken aloud: dark bar at the bottom, portrait and gold name tag
##   think - an inner voice (usually Teo's): violet rounded bar, italic text, "THINKING" tag
##   narr  - the story itself: yellow caption box at the top, no portrait
## Steps may carry a `choice` (timed only when `seconds` > 0) or a `qte` (guided / assisted / free). Emits `finished` after the last step.

signal finished

const CHARS_PER_SECOND := 38.0

var steps: Array = []
var _index: int = -1
var _typing: bool = false
var _chars: float = 0.0
var _label: Label = null
var _busy: bool = false # a choice or QTE is open
var _auto_wait: float = -1.0
var _panel_id: String = ""

var _fill: TextureRect
var _art: TextureRect
var _placeholder: Label
var _say_bar: PanelContainer
var _think_bar: PanelContainer
var _narr_bar: PanelContainer
var _flash: ColorRect
var _choice_box: VBoxContainer
var _choice_bar: ProgressBar
var _banner: PanelContainer
var _banner_label: Label
var _sfx_label: Label
var _hint: Label
var _ring: TimingRing
var _dim: ColorRect

var _say_portrait: TextureRect
var _say_name: Label
var _say_text: Label
var _think_portrait: TextureRect
var _think_name: Label
var _think_text: Label
var _narr_text: Label

var _choice_t: float = 0.0
var _choice_total: float = 0.0
var _choice_step: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	Story.consequence.connect(_notify)
	_flush_banners()


func play(p_steps: Array) -> void:
	steps = p_steps
	_index = -1
	_next()


func _build() -> void:
	var back := ColorRect.new()
	back.color = Color(0.02, 0.03, 0.06)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	_fill = _make_art_rect(Color(0.35, 0.35, 0.4))
	_art = _make_art_rect(Color.WHITE)

	_placeholder = Label.new()
	_placeholder.add_theme_font_override("font", Fonts.label())
	_placeholder.add_theme_font_size_override("font_size", 22)
	_placeholder.modulate = Color(1, 1, 1, 0.4)
	_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_placeholder)

	# Darken the bottom third so the bars read over any art.
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.0))
	grad.set_color(1, Color(0, 0, 0, 0.78))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0, 0.55)
	grad_tex.fill_to = Vector2(0, 1.0)
	grad_tex.width = 8
	grad_tex.height = 256
	var shade := TextureRect.new()
	shade.texture = grad_tex
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_narr_bar = _make_bar(_style(Color("f4e7a6"), Color("14110a"), 3, 4, true))
	_narr_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_narr_bar.position = Vector2(34, 34)
	_narr_bar.custom_minimum_size = Vector2(470, 0)
	var narr_margin := _margin(_narr_bar, 16, 11)
	_narr_text = _text_label(Fonts.label(), 21, Color("17130a"))
	narr_margin.add_child(_narr_text)

	_say_bar = _make_bar(_style(Color(0.04, 0.055, 0.1, 0.94), Color("e8e4d8"), 2, 6, false))
	_say_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_say_bar.offset_left = 28
	_say_bar.offset_right = -28
	_say_bar.offset_top = -176
	_say_bar.offset_bottom = -30
	var say_row := HBoxContainer.new()
	say_row.add_theme_constant_override("separation", 18)
	_margin(_say_bar, 16, 12).add_child(say_row)
	_say_portrait = _portrait_rect(Color("c9a24a"))
	say_row.add_child(_say_portrait)
	var say_col := VBoxContainer.new()
	say_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	say_row.add_child(say_col)
	_say_name = Label.new()
	_say_name.add_theme_font_override("font", Fonts.label())
	_say_name.add_theme_font_size_override("font_size", 19)
	_say_name.add_theme_color_override("font_color", Color("c9a24a"))
	say_col.add_child(_say_name)
	_say_text = _text_label(Fonts.body(), 25, Color("f2efe4"))
	say_col.add_child(_say_text)

	_think_bar = _make_bar(_style(Color(0.13, 0.12, 0.31, 0.95), Color("9aa6ff"), 2, 30, false))
	_think_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_think_bar.offset_left = 330
	_think_bar.offset_right = -28
	_think_bar.offset_top = -176
	_think_bar.offset_bottom = -30
	var think_row := HBoxContainer.new()
	think_row.add_theme_constant_override("separation", 18)
	_margin(_think_bar, 20, 12).add_child(think_row)
	_think_portrait = _portrait_rect(Color("9aa6ff"))
	think_row.add_child(_think_portrait)
	var think_col := VBoxContainer.new()
	think_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	think_row.add_child(think_col)
	_think_name = Label.new()
	_think_name.add_theme_font_override("font", Fonts.label())
	_think_name.add_theme_font_size_override("font_size", 17)
	_think_name.add_theme_color_override("font_color", Color("aeb9ff"))
	think_col.add_child(_think_name)
	_think_text = _text_label(Fonts.body_italic(), 25, Color("d9ddff"))
	think_col.add_child(_think_text)

	_choice_box = VBoxContainer.new()
	_choice_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_choice_box.position = Vector2(60, 250)
	_choice_box.custom_minimum_size = Vector2(620, 0)
	_choice_box.add_theme_constant_override("separation", 10)
	_choice_box.visible = false
	add_child(_choice_box)

	_choice_bar = ProgressBar.new()
	_choice_bar.show_percentage = false
	_choice_bar.custom_minimum_size = Vector2(620, 10)
	_choice_bar.max_value = 1.0

	_sfx_label = Label.new()
	_sfx_label.add_theme_font_override("font", Fonts.sfx())
	_sfx_label.add_theme_font_size_override("font_size", 120)
	_sfx_label.add_theme_color_override("font_color", Color("fff3b0"))
	_sfx_label.add_theme_color_override("font_outline_color", Color("7a2d00"))
	_sfx_label.add_theme_constant_override("outline_size", 14)
	_sfx_label.position = Vector2(700.0, 60.0)
	_sfx_label.visible = false
	_sfx_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sfx_label)

	_hint = Label.new()
	_hint.text = Story.accept_hint() + "  >"
	_hint.add_theme_font_override("font", Fonts.label_medium())
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.modulate = Color(1, 1, 1, 0.55)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -190
	_hint.offset_top = -26
	_hint.offset_right = -34
	_hint.offset_bottom = -6
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_dim = ColorRect.new()
	_dim.color = Color(0.2, 0.0, 0.0, 0.45)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)

	_ring = TimingRing.new()
	add_child(_ring)

	# Consequence note: a slim tag in the top-right corner, not a card in the middle of the art.
	var note_style := _style(Color(0.03, 0.04, 0.08, 0.82), Color("ffb43a"), 0, 3, false)
	note_style.border_width_left = 4
	_banner = _make_bar(note_style)
	_banner.custom_minimum_size = Vector2(0, 0)
	_banner.visible = false
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_label = Label.new()
	_banner_label.add_theme_font_override("font", Fonts.label_medium())
	_banner_label.add_theme_font_size_override("font_size", 16)
	_banner_label.add_theme_color_override("font_color", Color("ffe7b0"))
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_margin(_banner, 12, 6).add_child(_banner_label)

	_flash = ColorRect.new()
	_flash.color = Color.WHITE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate = Color(1, 1, 1, 0)
	add_child(_flash)

	_ring.finished.connect(_on_ring_finished)


func _make_art_rect(tint: Color) -> TextureRect:
	var r := TextureRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.modulate = tint
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _make_bar(style: StyleBoxFlat) -> PanelContainer:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", style)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.visible = false
	add_child(bar)
	return bar


func _margin(parent: Control, h: int, v: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", h)
	m.add_theme_constant_override("margin_right", h)
	m.add_theme_constant_override("margin_top", v)
	m.add_theme_constant_override("margin_bottom", v)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(m)
	return m


func _style(bg: Color, border: Color, border_w: int, radius: int, hard_shadow: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	if hard_shadow:
		s.shadow_color = Color("14110a")
		s.shadow_size = 1
		s.shadow_offset = Vector2(6, 6)
	return s


func _text_label(font: Font, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _portrait_rect(border: Color) -> TextureRect:
	var r := TextureRect.new()
	r.custom_minimum_size = Vector2(104, 104)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# --- Flow ---------------------------------------------------------------------------------------

func _next() -> void:
	_index += 1
	while _index < steps.size() and not Story.cond_ok(steps[_index]):
		_index += 1
	if _index >= steps.size():
		finished.emit()
		return
	_show(steps[_index])


func _show(step: Dictionary) -> void:
	var speaker: String = step.get("speaker", "")
	var text: String = Story.clean(step.get("text", ""))
	var wrapped := text.begins_with("*") and text.ends_with("*") and text.length() > 1
	if wrapped:
		text = text.substr(1, text.length() - 2)
	var kind: String = step.get("kind", "narr" if (wrapped or speaker == "") else "say")

	if step.has("fx"):
		Story.apply_effects(step["fx"])
	if step.has("music"):
		Sfx.cue(String(step["music"])) # a cue change mid-scene, or "silence" for a big beat
	_set_panel(step.get("panel", _panel_id))
	_say_bar.visible = kind == "say"
	_think_bar.visible = kind == "think"
	_narr_bar.visible = kind == "narr"

	match kind:
		"narr":
			_label = _narr_text
		"think":
			_label = _think_text
			_think_name.text = "...  %s · THINKING" % speaker.to_upper()
			_think_portrait.texture = Art.portrait(step.get("portrait", ""))
			_think_portrait.visible = _think_portrait.texture != null
			_age_portrait(_think_portrait, String(step.get("portrait", "")))
		_:
			_label = _say_text
			_say_name.text = speaker.to_upper()
			_say_portrait.texture = Art.portrait(step.get("portrait", ""))
			_say_portrait.visible = _say_portrait.texture != null
			_age_portrait(_say_portrait, String(step.get("portrait", "")))

	_label.text = text
	_label.visible_characters = 0
	_chars = 0.0
	_typing = true
	_auto_wait = -1.0
	_hint.visible = true

	if step.get("flash", false):
		var tw := create_tween()
		_flash.modulate = Color(1, 1, 1, 0.9)
		tw.tween_property(_flash, "modulate:a", 0.0, 0.45)
	if step.get("shake", false):
		_shake()
	var sfx_text: String = step.get("sfx", "")
	if sfx_text != "":
		_stamp_sfx(sfx_text)
		Sfx.play("hit-thud")
	else:
		_sfx_label.visible = false

	_busy = false
	if step.has("choice"):
		_start_choice(step)
	elif step.has("qte"):
		_start_qte(step)


## Borrowed time greys Teo's portrait, a little more at every stage (Story.age_amount). Others are untouched.
const AGE_SHADER := """
shader_type canvas_item;
uniform float grey : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 c = COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c.rgb, vec3(l), grey), c.a);
}
"""
static var _age_shader: Shader


func _age_portrait(rect: TextureRect, portrait_id: String) -> void:
	if _age_shader == null:
		_age_shader = Shader.new()
		_age_shader.code = AGE_SHADER
	var mat := rect.material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = _age_shader
		rect.material = mat
	mat.set_shader_parameter("grey", Story.age_amount() if portrait_id == "portrait_teo" else 0.0)


func _set_panel(id: String) -> void:
	if id == _panel_id and _art.texture != null:
		return
	_panel_id = id
	var tex := Art.panel(id) if id != "" else null
	_art.texture = tex
	_fill.texture = tex
	_placeholder.visible = tex == null and id != ""
	_placeholder.text = "[ art slot: %s ]" % id
	_placeholder.position = get_viewport_rect().size * Vector2(0.5, 0.35) - Vector2(160.0, 0.0)
	_art.modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(_art, "modulate:a", 1.0, 0.25)
	_drift(id, String(steps[_index].get("move", "")) if _index >= 0 and _index < steps.size() else "")


## A slow camera move on the panel (Ken Burns): a gentle push in, or a drift left or right, so a still picture
## breathes while the player reads. A step can ask for one with "move": push / pull / left / right / still;
## otherwise each panel picks its own from its name, so the same panel always moves the same way.
var _drift_tw: Tween = null
const DRIFT_SECONDS := 18.0


func _drift(id: String, move: String) -> void:
	if _drift_tw != null:
		_drift_tw.kill()
	var view := get_viewport_rect().size
	_art.pivot_offset = view * 0.5
	_art.position = Vector2.ZERO
	_art.scale = Vector2.ONE
	if id == "" or _art.texture == null or move == "still":
		return
	if move == "":
		move = ["push", "left", "right", "pull"][absi(id.hash()) % 4]
	var from_s := 1.06
	var to_s := 1.14
	var from_p := Vector2.ZERO
	var to_p := Vector2.ZERO
	match move:
		"pull":
			from_s = 1.14
			to_s = 1.05
		"left":
			from_s = 1.1
			to_s = 1.1
			from_p = Vector2(26, 0)
			to_p = Vector2(-26, -6)
		"right":
			from_s = 1.1
			to_s = 1.1
			from_p = Vector2(-26, 0)
			to_p = Vector2(26, -6)
	_art.scale = Vector2(from_s, from_s)
	_art.position = from_p
	_drift_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_drift_tw.tween_property(_art, "scale", Vector2(to_s, to_s), DRIFT_SECONDS)
	_drift_tw.tween_property(_art, "position", to_p, DRIFT_SECONDS)


func _process(delta: float) -> void:
	if _typing and _label != null:
		_chars += delta * CHARS_PER_SECOND
		var total := _label.text.length()
		_label.visible_characters = int(_chars)
		if int(_chars) >= total:
			_typing = false
			_label.visible_characters = -1
			var step: Dictionary = steps[_index]
			if step.has("autoAdvance") and not _busy:
				_auto_wait = float(step["autoAdvance"])
	if _auto_wait >= 0.0 and not _typing:
		_auto_wait -= delta
		if _auto_wait < 0.0:
			_auto_wait = -1.0
			_next()
	if _busy and _choice_box.visible and _choice_total > 0.0:
		_choice_t -= delta
		_choice_bar.value = maxf(0.0, _choice_t / _choice_total)
		if _choice_t <= 0.0:
			_settle_choice(int(_choice_step["choice"].get("default", 0)), true)


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		# Number keys pick a timed choice.
		var key := event as InputEventKey
		if key != null and key.pressed and not key.echo and _choice_box.visible:
			var n := key.keycode - KEY_1
			if n >= 0 and n < _choice_step["choice"]["options"].size():
				_settle_choice(n, false)
		return
	if Story.is_accept(event):
		get_viewport().set_input_as_handled()
		_advance()


## Mouse clicks land on this control first (it covers the screen), so clicking has to be handled here;
## touch, keys and the controller arrive through _unhandled_input. Repeats within 120 ms count once.
func _gui_input(event: InputEvent) -> void:
	if _busy:
		return
	if Story.is_accept(event):
		accept_event()
		_advance()


func _advance() -> void:
	_dismiss_note()
	if _typing and _label != null:
		_typing = false
		_label.visible_characters = -1
		return
	_next()


# --- Timed choices ------------------------------------------------------------------------------

func _start_choice(step: Dictionary) -> void:
	_busy = true
	_choice_step = step
	var choice: Dictionary = step["choice"]
	_choice_total = float(choice.get("seconds", 8.0))
	_choice_t = _choice_total
	if _choice_bar.get_parent() != null:
		_choice_box.remove_child(_choice_bar)
	for c in _choice_box.get_children():
		c.queue_free()
	var options: Array = choice["options"]
	var tones: Array = choice.get("tones", [])
	var first: Button = null
	for i in options.size():
		var b := Button.new()
		b.text = "%d.  %s" % [i + 1, Story.clean(String(options[i]))]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(620, 68)
		b.add_theme_font_override("font", Fonts.label())
		b.add_theme_font_size_override("font_size", 24)
		if i < tones.size():
			_add_tone_tag(b, String(tones[i]))
		var idx := i
		b.pressed.connect(func() -> void: _settle_choice(idx, false))
		_choice_box.add_child(b)
		if first == null:
			first = b
	_choice_bar.value = 1.0
	_choice_bar.visible = _choice_total > 0.0 # untimed choices show no timer
	_choice_box.add_child(_choice_bar)
	_choice_box.visible = true
	if first != null:
		first.grab_focus()


## How the line is said, as a small coloured tag on the right of the option ("ANGRY", "GENTLE").
const TONE_COLORS := {
	"angry": "e2553c", "defiant": "f08a3c", "cold": "8fb4d8", "suspicious": "c9b458", "focused": "e8d27a",
	"resolute": "ffb43a", "desperate": "e07aa0", "scared": "b49ae8", "worried": "a7a0e0", "guilty": "9a8fb0",
	"quiet": "a8b0b8", "calm": "7fc8b0", "gentle": "8ed49a", "warm": "f2b880",
}


func _add_tone_tag(b: Button, tone: String) -> void:
	var tag := Label.new()
	tag.name = "Tone"
	tag.text = tone.to_upper()
	tag.add_theme_font_override("font", Fonts.label())
	tag.add_theme_font_size_override("font_size", 15)
	tag.add_theme_color_override("font_color", Color(TONE_COLORS.get(tone, "d0d0d0")))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	tag.offset_left = -110.0
	tag.offset_right = -14.0
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_child(tag)
	b.add_theme_constant_override("h_separation", 0)
	b.text += "        " # keep the words clear of the tag
	b.custom_minimum_size.x = 700


func _settle_choice(index: int, expired: bool) -> void:
	if not _busy or not _choice_box.visible:
		return
	_choice_box.visible = false
	_busy = false
	var choice: Dictionary = _choice_step["choice"]
	_dismiss_note()
	Story.apply_choice(String(choice.get("id", "")), index, expired, choice)
	_next()


# --- QTE ----------------------------------------------------------------------------------------

func _start_qte(step: Dictionary) -> void:
	_busy = true
	var q: Dictionary = step["qte"]
	_dim.visible = true
	_hint.visible = false
	_ring.start(String(q.get("prompt", "!")), float(q.get("seconds", 2.0)), String(q.get("level", "assisted")), String(q.get("lesson", "")))


func _on_ring_finished(grade: String) -> void:
	if not _busy or _index < 0 or _index >= steps.size():
		return
	var q: Dictionary = steps[_index].get("qte", {})
	_dim.visible = false
	_ring.visible = false
	var ok := grade != "miss"
	if ok:
		Sfx.play("hit-thud")
		_flash.modulate = Color("ffb43a")
	else:
		Sfx.play("hit-thud-metal")
		_flash.modulate = Color("c8452e")
		_shake()
	_flash.modulate.a = 0.5
	create_tween().tween_property(_flash, "modulate:a", 0.0, 0.3)
	Story.apply_qte(String(q.get("id", "")), ok, q)
	_busy = false
	_next()


# --- Juice --------------------------------------------------------------------------------------

func _stamp_sfx(text: String) -> void:
	_sfx_label.text = text
	_sfx_label.position = Vector2(get_viewport_rect().size.x - 560.0, 60.0)
	_sfx_label.visible = true
	_sfx_label.scale = Vector2(0.3, 0.3)
	_sfx_label.rotation = -0.28
	var tw := create_tween()
	tw.tween_property(_sfx_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _shake() -> void:
	var tw := create_tween()
	for i in 6:
		var amp := 8.0 * (1.0 - float(i) / 6.0)
		tw.tween_property(self, "position", Vector2(randf_range(-amp, amp), randf_range(-amp, amp)), 0.04)
	tw.tween_property(self, "position", Vector2.ZERO, 0.04)


## Consequence note ("Kardo will remember that"). Notes queue and show one at a time in the top-right corner.
## Each fades by itself after a moment, and the player moving the story on clears it at once, so none lingers.
var _notes: Array = []
var _note_tw: Tween = null


func _notify(text: String) -> void:
	_notes.append(text)
	if not _banner.visible:
		_next_note()


func _next_note() -> void:
	if _note_tw != null:
		_note_tw.kill()
		_note_tw = null
	if _notes.is_empty():
		_banner.visible = false
		return
	_banner_label.text = String(_notes.pop_front()).to_upper()
	_banner.reset_size()
	_banner.position = Vector2(get_viewport_rect().size.x - _banner.size.x - 24.0, 24.0)
	_banner.visible = true
	_banner.modulate = Color(1, 1, 1, 0)
	_note_tw = create_tween()
	_note_tw.tween_property(_banner, "modulate:a", 1.0, 0.18)
	_note_tw.tween_interval(2.2)
	_note_tw.tween_property(_banner, "modulate:a", 0.0, 0.25)
	_note_tw.tween_callback(_next_note)


## The player moved on: drop the note on screen (the next queued one, if any, takes its place).
func _dismiss_note() -> void:
	if _banner.visible:
		_next_note()


## Notes queued while no screen was open (for example after a fight).
func _flush_banners() -> void:
	var queued: Array = Story.pending_banners.duplicate()
	Story.pending_banners.clear()
	for text in queued:
		_notify(String(text))
