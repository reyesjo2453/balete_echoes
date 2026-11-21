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
		"sky_bolt":
			_life = 0.48
			for b in int(2 + strength):
				var pts := PackedVector2Array()
				var top_y := -420.0
				var segs := 10
				for i in segs + 1:
					var u := float(i) / float(segs)
					var x_off := 0.0 if (i == 0 or i == segs) else randf_range(-42.0, 42.0) * strength * (1.0 - u * 0.4)
					if b > 0:
						x_off += (float(b) - 1.0) * 34.0 * (1.0 - u)
					pts.append(Vector2(x_off, lerpf(top_y, 0.0, u)))
				_rays.append({"pts": pts, "w": (7.5 if b == 0 else 3.5) * strength})
		"pillar_beam":
			_life = 0.85
			for i in int(14 + 6 * strength):
				_rays.append({
					"x": randf_range(-62.0, 62.0) * strength,
					"y0": randf_range(-40.0, 30.0),
					"rise": randf_range(160.0, 340.0),
					"sz": randf_range(3.0, 7.0) * strength,
				})
		"holy_mandala":
			_life = 0.95
		"sun_sigil":
			_life = 0.85
		"crescent_cleave":
			_life = 0.42
			for i in 12:
				_rays.append({"a": angle + randf_range(-0.9, 0.9), "len": randf_range(60.0, 155.0) * strength, "w": randf_range(2.0, 4.5)})
		"plasma_cage":
			_life = 0.52
			for i in 6:
				_rays.append({"a": TAU * float(i) / 6.0, "jit": randf_range(-10.0, 10.0)})
		"x_break":
			_life = 0.62
			for i in 16:
				_rays.append({"a": randf() * TAU, "len": randf_range(90.0, 220.0) * strength, "w": randf_range(2.0, 5.0)})
		"starburst":
			_life = 0.68
			for i in 16:
				var long_ray := (i % 2 == 0)
				_rays.append({"a": TAU * float(i) / 16.0, "len": (240.0 if long_ray else 120.0) * strength, "w": (9.0 if long_ray else 4.0) * strength})
		"heal_curtain":
			_life = 0.85
			for i in 14:
				_rays.append({
					"x": randf_range(-52.0, 52.0) * strength,
					"y0": randf_range(-20.0, 38.0),
					"rise": randf_range(95.0, 185.0),
					"w": randf_range(2.0, 5.0),
					"ph": randf() * TAU,
				})


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
		"sky_bolt":
			var flicker := 1.0 if int(_t * 42.0) % 2 == 0 else 0.55
			var a_out := (1.0 - k) * flicker
			# Outer glow column
			var col_w := 44.0 * strength * (1.0 - k * 0.65)
			draw_rect(Rect2(center.x - col_w * 0.5, center.y - 460.0, col_w, 470.0), Color(color, 0.22 * a_out))
			for r in _rays:
				var raw: PackedVector2Array = r["pts"]
				var pts := PackedVector2Array()
				for p in raw:
					pts.append(center + p)
				draw_polyline(pts, Color(color, 0.9 * a_out), float(r["w"]) * (1.0 - k * 0.4) + 4.0, true)
				draw_polyline(pts, Color(1, 1, 1, a_out), maxf(2.0, float(r["w"]) * 0.4), true)
			# Ground discharge ellipse
			draw_arc(center + Vector2(0, 12), (24.0 + 120.0 * k) * strength, 0.0, TAU, 40, Color(color, a_out * 0.9), 6.0 * (1.0 - k) + 1.0, true)
			draw_circle(center, 34.0 * strength * (1.0 - k), Color(1, 1, 1, 0.92 * a_out))
		"pillar_beam":
			var env_a := sin(minf(1.0, k * 1.15) * PI)
			var bw := (88.0 + 30.0 * sin(k * PI)) * strength * (1.0 - maxf(0.0, k - 0.65) * 2.5)
			if bw > 2.0:
				draw_rect(Rect2(center.x - bw * 0.85, 0.0, bw * 1.7, center.y + 40.0), Color(color, 0.24 * env_a))
				draw_rect(Rect2(center.x - bw * 0.5, 0.0, bw, center.y + 35.0), Color(color, 0.58 * env_a))
				draw_rect(Rect2(center.x - bw * 0.2, 0.0, bw * 0.4, center.y + 30.0), Color(1, 1, 1, 0.92 * env_a))
			# Ground ripple rings
			for ri in 2:
				var rk := fposmod(k * 1.8 + float(ri) * 0.5, 1.0)
				draw_arc(center + Vector2(0, 24), (25.0 + 130.0 * rk) * strength, 0.0, TAU, 40, Color(color, (1.0 - rk) * env_a), 4.5, true)
			for r in _rays:
				var p := center + Vector2(float(r["x"]), float(r["y0"]) - float(r["rise"]) * k)
				var sz: float = float(r["sz"]) * env_a
				draw_circle(p, sz * 0.6, Color(1, 1, 1, 0.85 * env_a))
		"holy_mandala":
			var env_a := sin(k * PI)
			var rad := (65.0 + 95.0 * (1.0 - pow(1.0 - k, 2.0))) * strength
			var c_main := Color(color, 0.88 * env_a)
			var c_core := Color(1, 1, 1, 0.85 * env_a)
			draw_arc(center, rad, 0.0, TAU, 56, c_main, 4.5, true)
			draw_arc(center, rad * 0.78, 0.0, TAU, 48, c_core, 2.2, true)
			draw_arc(center, rad * 0.42, 0.0, TAU, 36, c_main, 3.0, true)
			# Counter-rotating 8-point sacred star
			var rot1 := k * 1.6
			var rot2 := -k * 2.1
			for s in 2:
				var pts := PackedVector2Array()
				var base_a := (rot1 if s == 0 else rot2) + float(s) * PI * 0.25
				for i in 5:
					var a := base_a + TAU * float(i % 4) / 4.0
					pts.append(center + Vector2(cos(a), sin(a)) * (rad * 0.88))
				draw_polyline(pts, c_main if s == 0 else c_core, 2.8, true)
			for i in 12:
				var a := rot1 * 0.5 + TAU * float(i) / 12.0
				draw_line(center + Vector2(cos(a), sin(a)) * (rad * 0.78), center + Vector2(cos(a), sin(a)) * rad, c_main, 2.5, true)
		"sun_sigil":
			var env_a := sin(k * PI)
			var rad := (58.0 + 78.0 * (1.0 - pow(1.0 - k, 2.5))) * strength
			var c_gold := Color(color, 0.92 * env_a)
			var c_wh := Color(1, 1, 1, 0.9 * env_a)
			draw_arc(center, rad, 0.0, TAU, 48, c_gold, 5.5, true)
			draw_arc(center, rad * 0.82, 0.0, TAU, 40, c_wh, 2.0, true)
			for i in 12:
				var a := -k * 1.2 + TAU * float(i) / 12.0
				var inner := rad * (0.64 if i % 3 == 0 else 0.76)
				draw_line(center + Vector2(cos(a), sin(a)) * inner, center + Vector2(cos(a), sin(a)) * (rad * 1.06), c_gold, 3.5 if i % 3 == 0 else 2.0, true)
			# Rewinding watch hands
			var ha := -TAU * 2.5 * k
			draw_line(center, center + Vector2(sin(ha), -cos(ha)) * (rad * 0.72), c_wh, 4.0, true)
			draw_line(center, center + Vector2(sin(ha * 0.25), -cos(ha * 0.25)) * (rad * 0.45), c_gold, 5.5, true)
		"crescent_cleave":
			var ease_k := 1.0 - pow(1.0 - k, 3.0)
			var a_out := 1.0 - k
			var dir := Vector2(cos(angle), sin(angle))
			var nrm := Vector2(-dir.y, dir.x)
			var reach := 175.0 * strength
			var travel := lerpf(-45.0, 65.0, ease_k) * strength
			var pts_out := PackedVector2Array()
			var pts_in := PackedVector2Array()
			for i in 16:
				var u := float(i) / 15.0
				var along := lerpf(-reach, reach, u)
				var bow_outer := sin(u * PI) * 68.0 * strength
				var bow_inner := sin(u * PI) * 30.0 * strength
				pts_out.append(center + dir * along + nrm * (bow_outer + travel))
				pts_in.append(center + dir * along + nrm * (bow_inner + travel))
			var poly := PackedVector2Array()
			for p in pts_out:
				poly.append(p)
			for i in range(pts_in.size() - 1, -1, -1):
				poly.append(pts_in[i])
			draw_colored_polygon(poly, Color(color, 0.72 * a_out))
			draw_polyline(pts_out, Color(1, 1, 1, 0.96 * a_out), 4.5 * a_out + 1.0, true)
			for r in _rays:
				var d: float = float(r["len"]) * ease_k
				draw_line(center + Vector2(cos(r["a"]), sin(r["a"])) * (d * 0.35), center + Vector2(cos(r["a"]), sin(r["a"])) * d, Color(color, a_out), float(r["w"]) * a_out + 0.5, true)
		"plasma_cage":
			var snap := 1.0 - pow(1.0 - minf(1.0, k * 2.0), 3.0)
			var a_out := 1.0 - maxf(0.0, k - 0.35) / 0.65
			var rad := lerpf(155.0, 56.0, snap) * strength
			var pts := PackedVector2Array()
			for r in _rays:
				var a := float(r["a"]) + k * 0.7
				var rr := rad + sin(_t * 48.0 + a * 3.0) * 8.0
				pts.append(center + Vector2(cos(a), sin(a)) * rr)
			pts.append(pts[0])
			draw_polyline(pts, Color(color, 0.85 * a_out), 6.0 * a_out + 1.5, true)
			draw_polyline(pts, Color(1, 1, 1, 0.95 * a_out), 2.2, true)
			for i in range(pts.size() - 1):
				draw_circle(pts[i], 7.0 * strength * a_out, Color(1, 1, 1, a_out))
				if i % 2 == 0:
					draw_line(pts[i], center, Color(color, 0.55 * a_out), 2.5, true)
		"x_break":
			var cut1 := clampf(k * 3.2, 0.0, 1.0)
			var cut2 := clampf((k - 0.16) * 3.2, 0.0, 1.0)
			var a_out := 1.0 - clampf((k - 0.45) / 0.55, 0.0, 1.0)
			var span := 240.0 * strength
			for idx in 2:
				var prog := cut1 if idx == 0 else cut2
				if prog <= 0.0:
					continue
				var ang := (-0.68 if idx == 0 else 0.68)
				var dv := Vector2(cos(ang), sin(ang))
				var p0 := center - dv * span
				var p1 := p0.lerp(center + dv * span, prog)
				draw_line(p0, p1, Color(color, 0.85 * a_out), 22.0 * a_out + 4.0, true)
				draw_line(p0, p1, Color(1, 1, 1, 0.98 * a_out), 7.0 * a_out + 1.5, true)
			if k > 0.35:
				var bk := clampf((k - 0.35) / 0.65, 0.0, 1.0)
				for r in _rays:
					var d := float(r["len"]) * bk
					draw_line(center + Vector2(cos(r["a"]), sin(r["a"])) * (d * 0.3), center + Vector2(cos(r["a"]), sin(r["a"])) * d, Color(1, 1, 1, (1.0 - bk) * 0.9), float(r["w"]) * (1.0 - bk) + 0.5, true)
		"starburst":
			var pop := 1.0 - pow(1.0 - minf(1.0, k * 2.6), 3.0)
			var a_out := 1.0 - clampf((k - 0.3) / 0.7, 0.0, 1.0)
			for r in _rays:
				var a := float(r["a"]) + k * 0.25
				var l := float(r["len"]) * pop
				var dv := Vector2(cos(a), sin(a))
				var nv := Vector2(-dv.y, dv.x) * (float(r["w"]) * a_out)
				var tri := PackedVector2Array([center - nv, center + dv * l, center + nv])
				draw_colored_polygon(tri, Color(color, 0.72 * a_out))
				draw_line(center, center + dv * (l * 0.82), Color(1, 1, 1, 0.92 * a_out), maxf(1.5, float(r["w"]) * 0.25), true)
			draw_circle(center, 46.0 * strength * pop * a_out, Color(1, 1, 1, 0.96 * a_out))
			draw_arc(center, (30.0 + 170.0 * k) * strength, 0.0, TAU, 48, Color(color, 0.8 * a_out), 5.0 * a_out + 1.0, true)
		"heal_curtain":
			var env_a := sin(k * PI)
			draw_arc(center + Vector2(0, 22), (38.0 + 28.0 * k) * strength, 0.0, TAU, 36, Color(color, 0.75 * env_a), 3.5, true)
			for r in _rays:
				var x := center.x + float(r["x"]) + sin(_t * 5.0 + float(r["ph"])) * 6.0
				var y_bot := center.y + float(r["y0"]) - float(r["rise"]) * k * 0.55
				var y_top := y_bot - 58.0 * env_a
				draw_line(Vector2(x, y_bot), Vector2(x, y_top), Color(color, 0.78 * env_a), float(r["w"]), true)
				draw_line(Vector2(x, y_bot), Vector2(x, y_top), Color(1, 1, 1, 0.7 * env_a), 1.5, true)


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
