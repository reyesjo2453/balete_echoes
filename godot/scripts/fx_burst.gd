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
		"cross_slash":
			_life = 0.32
			for i in 8:
				_rays.append({"a": randf() * TAU, "len": randf_range(40.0, 95.0) * strength, "w": randf_range(2.0, 4.5)})
		"lightning":
			_life = 0.38
			for i in int(4 + 3 * strength):
				var pts := PackedVector2Array()
				var a := randf() * TAU
				var cur := Vector2.ZERO
				pts.append(cur)
				for s in 5:
					var step := randf_range(16.0, 32.0) * strength
					var jitter := a + randf_range(-0.65, 0.65)
					cur += Vector2(cos(jitter), sin(jitter)) * step
					pts.append(cur)
				_rays.append({"pts": pts, "w": randf_range(2.0, 4.0)})
		"prayer_motes":
			_life = 0.65
			for i in int(12 + 6 * strength):
				_rays.append({
					"x": randf_range(-56.0, 56.0) * strength,
					"y0": randf_range(-12.0, 32.0) * strength,
					"rise": randf_range(60.0, 130.0) * strength,
					"sz": randf_range(3.0, 6.5) * strength,
					"ph": randf() * TAU,
				})
		"shockwave":
			_life = 0.55
			for i in int(10 + 6 * strength):
				_rays.append({"a": randf() * TAU, "len": randf_range(70.0, 145.0) * strength, "w": randf_range(2.5, 5.0)})
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
			_draw_slash_arc(angle, k, fade, 90.0 * strength, 24.0)
		"cross_slash":
			var a1 := angle - 0.52
			var a2 := angle + 0.52
			_draw_slash_arc(a1, minf(1.0, k * 1.25), fade, 105.0 * strength, 26.0)
			if k > 0.14:
				var k2 := clampf((k - 0.14) / 0.86, 0.0, 1.0)
				_draw_slash_arc(a2, k2, Color(color, 1.0 - k2), 105.0 * strength, -26.0)
			for r in _rays:
				var d: float = float(r["len"]) * k
				var from := center + Vector2(cos(r["a"]), sin(r["a"])) * (d * 0.4)
				var to := center + Vector2(cos(r["a"]), sin(r["a"])) * d
				draw_line(from, to, Color(1, 1, 1, (1.0 - k) * 0.75), float(r["w"]) * (1.0 - k) + 0.5, true)
		"lightning":
			var flicker := 1.0 if int(_t * 36.0) % 2 == 0 else 0.55
			var bolt_col := Color(color, (1.0 - k) * flicker)
			var core_col := Color(1, 1, 1, (1.0 - k) * flicker)
			for r in _rays:
				var raw: PackedVector2Array = r["pts"]
				var pts := PackedVector2Array()
				for p in raw:
					pts.append(center + p * (0.45 + 0.75 * k))
				draw_polyline(pts, bolt_col, float(r["w"]) * (1.0 - k * 0.5) + 1.5, true)
				draw_polyline(pts, core_col, 1.5, true)
			draw_circle(center, 18.0 * strength * (1.0 - k), Color(color, 0.5 * (1.0 - k)))
		"prayer_motes":
			var halo_a := sin(k * PI) * 0.75
			draw_arc(center, (28.0 + 42.0 * k) * strength, 0.0, TAU, 36, Color(color, halo_a), 3.0, true)
			for r in _rays:
				var sway := sin(_t * 7.0 + float(r["ph"])) * 8.0
				var p := center + Vector2(float(r["x"]) + sway, float(r["y0"]) - float(r["rise"]) * k)
				var sz: float = float(r["sz"]) * sin(k * PI)
				if sz > 0.4:
					var diamond := PackedVector2Array([
						p + Vector2(0, -sz), p + Vector2(sz * 0.7, 0),
						p + Vector2(0, sz), p + Vector2(-sz * 0.7, 0)
					])
					draw_colored_polygon(diamond, Color(color, 0.9 * (1.0 - k)))
					draw_circle(p, sz * 0.35, Color(1, 1, 1, 0.85 * (1.0 - k)))
		"shockwave":
			var ease_k := 1.0 - pow(1.0 - k, 3.0)
			draw_arc(center, (24.0 + 135.0 * ease_k) * strength, 0.0, TAU, 48, fade, 9.0 * (1.0 - k) + 1.5, true)
			draw_arc(center, (14.0 + 95.0 * ease_k) * strength, 0.0, TAU, 40, Color(1, 1, 1, 0.85 * (1.0 - k)), 3.0, true)
			for r in _rays:
				var d: float = float(r["len"]) * ease_k
				var from := center + Vector2(cos(r["a"]), sin(r["a"])) * (d * 0.45)
				var to := center + Vector2(cos(r["a"]), sin(r["a"])) * d
				draw_line(from, to, fade, float(r["w"]) * (1.0 - k) + 0.5, true)
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


func _draw_slash_arc(p_angle: float, k: float, fade: Color, reach: float, bow_amt: float) -> void:
	var dir := Vector2(cos(p_angle), sin(p_angle))
	var normal := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array()
	for i in 12:
		var u := float(i) / 11.0
		var along := lerpf(-reach, reach, u) * minf(1.0, k * 2.5)
		var bow := sin(u * PI) * bow_amt
		pts.append(center + dir * along + normal * bow)
	draw_polyline(pts, fade, 7.0 * (1.0 - k) + 1.0, true)
	draw_polyline(pts, Color(1, 1, 1, 0.9 * (1.0 - k)), 2.0, true)
