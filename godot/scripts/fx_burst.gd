class_name FxBurst
extends Control
## A one-shot drawn effect (no art needed): spark burst, slash arc, parry ring, or a clock face spinning backward.
## It plays itself and frees itself. Position it with `center` in its parent's coordinates.

var mode: String = "spark"
var color: Color = Color("fff3b0")
var strength: float = 1.0
var center: Vector2 = Vector2.ZERO
var angle: float = 0.0 # slash direction
var _t: float = 0.0
var _life: float = 0.35
var _rays: Array = []


static func play(parent: Control, p_mode: String, p_center: Vector2, p_color: Color, p_strength: float = 1.0, p_angle: float = 0.0) -> FxBurst:
	var fx := FxBurst.new()
	fx.mode = p_mode
	fx.center = p_center
	fx.color = p_color
	fx.strength = p_strength
	fx.angle = p_angle
	parent.add_child(fx)
	return fx


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	match mode:
		"spark":
			_life = 0.35
			var count := int(8.0 + 8.0 * strength)
			for i in count:
				_rays.append({"a": randf() * TAU, "len": randf_range(30.0, 70.0) * strength, "w": randf_range(2.0, 4.0)})
		"slash":
			_life = 0.22
		"ring":
			_life = 0.45
		"clock":
			_life = 0.9


func _process(delta: float) -> void:
	_t += delta
	if _t >= _life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / _life, 0.0, 1.0)
	var fade := Color(color, 1.0 - k)
	match mode:
		"spark":
			for r in _rays:
				var d: float = float(r["len"]) * k
				var from := center + Vector2(cos(r["a"]), sin(r["a"])) * (d * 0.35)
				var to := center + Vector2(cos(r["a"]), sin(r["a"])) * d
				draw_line(from, to, fade, float(r["w"]) * (1.0 - k) + 0.5, true)
			draw_circle(center, 14.0 * strength * (1.0 - k), Color(1, 1, 1, 0.8 * (1.0 - k)))
		"slash":
			var dir := Vector2(cos(angle), sin(angle))
			var normal := Vector2(-dir.y, dir.x)
			var reach := 90.0 * strength
			var pts := PackedVector2Array()
			for i in 12:
				var u := float(i) / 11.0
				var along := lerpf(-reach, reach, u) * minf(1.0, k * 2.5)
				var bow := sin(u * PI) * 24.0
				pts.append(center + dir * along + normal * bow)
			draw_polyline(pts, fade, 7.0 * (1.0 - k) + 1.0, true)
			draw_polyline(pts, Color(1, 1, 1, 0.9 * (1.0 - k)), 2.0, true)
		"ring":
			draw_arc(center, 20.0 + 90.0 * k * strength, 0.0, TAU, 40, fade, 6.0 * (1.0 - k) + 1.0, true)
			draw_arc(center, 10.0 + 55.0 * k * strength, 0.0, TAU, 32, Color(1, 1, 1, 0.8 * (1.0 - k)), 2.0, true)
		"clock":
			# The watch turning back: a clock face whose hands spin the wrong way.
			var alpha := sin(k * PI)
			var face := Color(color, alpha)
			draw_arc(center, 70.0, 0.0, TAU, 48, face, 5.0, true)
			for i in 12:
				var a := TAU * float(i) / 12.0
				draw_line(center + Vector2(cos(a), sin(a)) * 60.0, center + Vector2(cos(a), sin(a)) * 68.0, face, 3.0, true)
			var minute := -TAU * 3.0 * k
			draw_line(center, center + Vector2(sin(minute), -cos(minute)) * 58.0, face, 4.0, true)
			draw_line(center, center + Vector2(sin(minute / 12.0), -cos(minute / 12.0)) * 38.0, face, 6.0, true)
