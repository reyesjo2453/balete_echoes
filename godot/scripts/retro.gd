class_name Retro
extends RefCounted
## The one 16-bit window look shared by dialogue, menus and battles: a deep blue gradient with a light edge,
## like the SNES role-playing games. Everything that talks to the player uses it, so the game reads as one style.

const TOP := Color(0.11, 0.17, 0.52, 0.95)
const BOTTOM := Color(0.03, 0.05, 0.2, 0.95)
const EDGE := Color(0.88, 0.9, 0.97)
const TEXT := Color("f4f2ea")
const NAME := Color("ffd27a")

static var _grad: GradientTexture2D


static func gradient() -> GradientTexture2D:
	if _grad == null:
		var g := Gradient.new()
		g.set_color(0, TOP)
		g.set_color(1, BOTTOM)
		_grad = GradientTexture2D.new()
		_grad.gradient = g
		_grad.fill_from = Vector2(0, 0)
		_grad.fill_to = Vector2(0, 1)
		_grad.width = 4
		_grad.height = 64
	return _grad


## A window stylebox. The gradient is drawn by a TextureRect inside (window()), so this one carries the edge.
static func style(margin_h: int = 18, margin_v: int = 12) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(BOTTOM.r, BOTTOM.g, BOTTOM.b, 0.0)
	st.border_color = EDGE
	st.set_border_width_all(3)
	st.set_corner_radius_all(4)
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 4
	st.content_margin_left = margin_h
	st.content_margin_right = margin_h
	st.content_margin_top = margin_v
	st.content_margin_bottom = margin_v
	return st


## A PanelContainer with the gradient behind its content. Add the content with add_child as usual.
static func window(margin_h: int = 18, margin_v: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(margin_h, margin_v))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The draw signal comes after the stylebox is drawn and before children, so the gradient sits inside the edge.
	p.draw.connect(func() -> void:
		p.draw_texture_rect(gradient(), Rect2(Vector2(3, 3), p.size - Vector2(6, 6)), false))
	return p


static func label(font: Font, px: int, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A menu option in a window: plain text on the blue gradient; the focused one lights up with a cursor edge.
## Every colour is set explicitly so no theme default (white on white, empty text) can blank an option out.
static func style_button(b: Button, px: int = 24) -> void:
	var edge := StyleBoxFlat.new()
	edge.bg_color = Color(1, 1, 1, 0.0)
	edge.border_color = EDGE
	edge.set_border_width_all(3)
	edge.set_corner_radius_all(4)
	var lit := StyleBoxFlat.new()
	lit.bg_color = Color(0.22, 0.32, 0.78, 0.97)
	lit.border_color = NAME
	lit.set_border_width_all(3)
	lit.set_corner_radius_all(4)
	lit.content_margin_left = 22
	lit.content_margin_right = 18
	lit.content_margin_top = 8
	lit.content_margin_bottom = 8
	var plain := StyleBoxFlat.new()
	plain.bg_color = BOTTOM
	plain.border_color = EDGE
	plain.set_border_width_all(3)
	plain.set_corner_radius_all(4)
	plain.content_margin_left = 22
	plain.content_margin_right = 18
	plain.content_margin_top = 8
	plain.content_margin_bottom = 8
	b.add_theme_stylebox_override("normal", plain)
	b.add_theme_stylebox_override("pressed", lit)
	b.add_theme_stylebox_override("hover", lit)
	b.add_theme_stylebox_override("focus", edge)
	b.add_theme_stylebox_override("hover_pressed", lit)
	b.add_theme_stylebox_override("disabled", plain)
	for c in ["font_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_font_size_override("font_size", px)
	# The focused option uses the lit look too (keyboard and pad players see where the cursor is).
	b.focus_entered.connect(func() -> void: b.add_theme_stylebox_override("normal", lit))
	b.focus_exited.connect(func() -> void: b.add_theme_stylebox_override("normal", plain))
