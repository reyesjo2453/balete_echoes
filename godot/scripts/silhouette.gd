class_name Silhouette
extends Control
## Placeholder battle art: a flat silhouette with a rim light, until the art pass replaces it.

var kind: String = "renzo"
var rim: Color = Color("c9a24a")
var body: Color = Color(0.035, 0.04, 0.06)


func _init(p_kind: String = "renzo", p_rim: Color = Color("c9a24a")) -> void:
	kind = p_kind
	rim = p_rim
	custom_minimum_size = Vector2(220, 340)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = Vector2(110, 330)


func _p(x: float, y: float) -> Vector2:
	return Vector2(x * size.x, y * size.y)


func _poly(points: Array, color: Color) -> void:
	var pts := PackedVector2Array()
	for pt in points:
		pts.append(_p(pt[0], pt[1]))
	draw_colored_polygon(pts, color)


func _edge(points: Array, color: Color) -> void:
	var pts := PackedVector2Array()
	for pt in points:
		pts.append(_p(pt[0], pt[1]))
	draw_polyline(pts, color, 3.0, true)


func _draw() -> void:
	match kind:
		"aswang":
			_draw_aswang()
		"dante":
			_draw_dante()
		"hound":
			_draw_hound()
		"tiyanak":
			_draw_tiyanak()
		_:
			_draw_renzo()


func _draw_renzo() -> void:
	# Lean courier in a jacket, balisong low in the right hand.
	draw_circle(_p(0.5, 0.15), size.y * 0.075, body)
	_poly([[0.34, 0.24], [0.66, 0.24], [0.72, 0.58], [0.62, 0.6], [0.38, 0.6], [0.28, 0.58]], body)
	_poly([[0.38, 0.58], [0.5, 0.58], [0.48, 0.97], [0.36, 0.97]], body)
	_poly([[0.5, 0.58], [0.62, 0.58], [0.64, 0.97], [0.52, 0.97]], body)
	_poly([[0.66, 0.26], [0.78, 0.5], [0.74, 0.56], [0.62, 0.34]], body)
	_edge([[0.34, 0.24], [0.28, 0.58]], rim)
	_edge([[0.5, 0.075], [0.58, 0.1]], rim)
	draw_line(_p(0.76, 0.54), _p(0.86, 0.45), Color("d8d8e0"), 3.0, true)


func _draw_dante() -> void:
	# Heavyset mechanic in coveralls.
	draw_circle(_p(0.5, 0.17), size.y * 0.085, body)
	_poly([[0.26, 0.26], [0.74, 0.26], [0.82, 0.62], [0.7, 0.66], [0.3, 0.66], [0.18, 0.62]], body)
	_poly([[0.3, 0.64], [0.5, 0.64], [0.48, 0.97], [0.3, 0.97]], body)
	_poly([[0.5, 0.64], [0.7, 0.64], [0.7, 0.97], [0.52, 0.97]], body)
	_edge([[0.26, 0.26], [0.18, 0.62]], rim)


func _draw_aswang() -> void:
	# Hunched, too many ribs, arms that reach the ground, two red eyes.
	_poly([[0.3, 0.2], [0.62, 0.16], [0.78, 0.42], [0.7, 0.72], [0.56, 0.94], [0.4, 0.94], [0.26, 0.7], [0.2, 0.42]], body)
	_poly([[0.22, 0.4], [0.08, 0.64], [0.04, 0.98], [0.12, 0.98], [0.2, 0.7], [0.3, 0.52]], body)
	_poly([[0.72, 0.42], [0.88, 0.62], [0.96, 0.98], [0.88, 0.98], [0.78, 0.7], [0.66, 0.52]], body)
	draw_circle(_p(0.5, 0.2), size.y * 0.07, body)
	for i in 5:
		var y := 0.38 + float(i) * 0.07
		draw_line(_p(0.34, y), _p(0.66, y + 0.02), Color(rim, 0.55), 2.0, true)
	draw_circle(_p(0.44, 0.19), 7.0, Color("ff4a3a"))
	draw_circle(_p(0.58, 0.18), 7.0, Color("ff4a3a"))
	_edge([[0.3, 0.2], [0.2, 0.42], [0.26, 0.7]], rim)


func _draw_hound() -> void:
	# An Aevum security drone: a low armoured body, four piston legs, one red lens.
	_poly([[0.22, 0.42], [0.78, 0.42], [0.88, 0.62], [0.12, 0.62]], body)
	_poly([[0.3, 0.3], [0.7, 0.3], [0.78, 0.44], [0.22, 0.44]], body)
	for i in 4:
		var x := 0.2 + float(i) * 0.2
		draw_line(_p(x, 0.6), _p(x - 0.05 + float(i % 2) * 0.1, 0.96), body, 10.0, true)
	draw_circle(_p(0.5, 0.36), 16.0, Color("ff3b2e"))
	draw_circle(_p(0.5, 0.36), 7.0, Color("ffd0c8"))
	draw_line(_p(0.2, 0.3), _p(0.2, 0.18), body, 4.0, true)
	draw_circle(_p(0.2, 0.17), 5.0, Color("ff3b2e"))
	_edge([[0.22, 0.42], [0.12, 0.62]], rim)
	_edge([[0.3, 0.3], [0.7, 0.3]], rim)


func _draw_tiyanak() -> void:
	# A crouched baby-shape: oversized head, thin limbs, a swaddling cloth, wide pale eyes.
	draw_circle(_p(0.5, 0.44), size.y * 0.2, body)
	_poly([[0.3, 0.58], [0.7, 0.58], [0.78, 0.86], [0.22, 0.86]], body)
	draw_line(_p(0.25, 0.66), _p(0.1, 0.92), body, 8.0, true)
	draw_line(_p(0.75, 0.66), _p(0.9, 0.92), body, 8.0, true)
	draw_line(_p(0.36, 0.86), _p(0.32, 0.98), body, 8.0, true)
	draw_line(_p(0.64, 0.86), _p(0.68, 0.98), body, 8.0, true)
	draw_circle(_p(0.42, 0.42), 11.0, Color("f2efe4"))
	draw_circle(_p(0.58, 0.42), 11.0, Color("f2efe4"))
	draw_circle(_p(0.42, 0.42), 4.0, Color(0, 0, 0))
	draw_circle(_p(0.58, 0.42), 4.0, Color(0, 0, 0))
	draw_arc(_p(0.5, 0.5), 18.0, 0.2, PI - 0.2, 14, Color("ff4a3a"), 3.0, true)
	_edge([[0.3, 0.58], [0.22, 0.86]], rim)
