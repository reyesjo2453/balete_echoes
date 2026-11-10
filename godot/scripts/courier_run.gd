class_name CourierRun
extends Control
## The rain courier run: Honda Beat down a flooded Quiapo street, three lanes, dodge potholes, puddles and
## jeepneys before the noon tow truck finds you. Up/Down (or d-pad, stick, tap top/bottom) changes lane.
## Drawn in code so it needs no art. Emits `finished(hits)` when the alley is reached.

signal finished(hits: int)

const LANES := 3
const RUN_SECONDS := 34.0
const PLAYER_X := 300.0
const SKY_TOP := Color("0b1220")
const SKY_BOTTOM := Color("2a2a30")

var hits: int = 0
var _progress: float = 0.0
var _lane: int = 1
var _lane_y: float = 0.0
var _scroll: float = 0.0
var _speed_mul: float = 1.0
var _slow_t: float = 0.0
var _spawn_t: float = 1.2
var _invuln: float = 0.0
var _flash: float = 0.0
var _shake: float = 0.0
var _obstacles: Array = [] # {x, lane, kind}
var _rain: Array = []
var _skyline: Array = []
var _rng := RandomNumberGenerator.new()
var _done: bool = false
var _hint_t: float = 6.0
var _swipe_start: Vector2 = Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.seed = 417
	var vp := get_viewport_rect().size
	for i in 140:
		_rain.append(Vector2(_rng.randf() * vp.x, _rng.randf() * vp.y))
	var x := 0.0
	while x < vp.x + 300.0:
		var w := _rng.randf_range(70.0, 170.0)
		_skyline.append(Rect2(x, 0.0, w, _rng.randf_range(120.0, 330.0)))
		x += w + _rng.randf_range(0.0, 24.0)
	_lane_y = _lane_center(_lane)
	Sfx.bgm("undertow")


func _lane_center(l: int) -> float:
	var vp := get_viewport_rect().size
	var top := vp.y * 0.56
	var lane_h := (vp.y - top - 40.0) / LANES
	return top + lane_h * (l + 0.5)


func _process(delta: float) -> void:
	if _done:
		return
	var vp := get_viewport_rect().size
	_hint_t = maxf(0.0, _hint_t - delta)
	_slow_t = maxf(0.0, _slow_t - delta)
	_speed_mul = 0.55 if _slow_t > 0.0 else 1.0
	_invuln = maxf(0.0, _invuln - delta)
	_flash = maxf(0.0, _flash - delta * 2.0)
	_shake = maxf(0.0, _shake - delta * 3.0)
	_progress += delta * _speed_mul / RUN_SECONDS
	var speed := 620.0 * _speed_mul
	_scroll += speed * delta
	_lane_y = lerpf(_lane_y, _lane_center(_lane), 1.0 - exp(-14.0 * delta))

	for i in _rain.size():
		var r: Vector2 = _rain[i]
		r.x -= 220.0 * delta
		r.y += 900.0 * delta
		if r.y > vp.y:
			r = Vector2(_rng.randf() * (vp.x + 200.0), -20.0)
		_rain[i] = r

	# Spawn obstacles ahead; none in the last stretch so the alley mouth is clear.
	_spawn_t -= delta
	if _spawn_t <= 0.0 and _progress < 0.92:
		_spawn_t = _rng.randf_range(0.85, 1.5)
		var kinds := ["pothole", "puddle", "jeepney"]
		_obstacles.append({"x": vp.x + 120.0, "lane": _rng.randi_range(0, LANES - 1), "kind": kinds[_rng.randi_range(0, 2)]})

	for o in _obstacles:
		o["x"] = float(o["x"]) - speed * delta
	for o in _obstacles:
		if _invuln <= 0.0 and int(o["lane"]) == _lane and absf(float(o["x"]) - PLAYER_X) < 64.0:
			_collide(String(o["kind"]))
			o["x"] = -999.0
	_obstacles = _obstacles.filter(func(o: Dictionary) -> bool: return float(o["x"]) > -140.0)

	if _progress >= 1.0:
		_done = true
		Sfx.play("command-exit")
		finished.emit(hits)
	queue_redraw()


func _collide(kind: String) -> void:
	match kind:
		"puddle":
			_slow_t = 1.1
			_flash = 0.4
			Sfx.play("footsteps-wet")
		"pothole":
			hits += 1
			_shake = 0.6
			_invuln = 0.8
			Sfx.play("hit-thud")
		"jeepney":
			hits += 1
			_shake = 1.0
			_slow_t = 1.4
			_invuln = 1.2
			Sfx.play("hit-thud-metal")


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("ui_up"):
		_lane = maxi(0, _lane - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_lane = mini(LANES - 1, _lane + 1)
		get_viewport().set_input_as_handled()
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		var mid := _lane_center(_lane)
		_lane = clampi(_lane + (-1 if mouse.position.y < mid else 1), 0, LANES - 1)


func _draw() -> void:
	var vp := get_viewport_rect().size
	var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake * 7.0
	# Sky
	var steps := 12
	for i in steps:
		var t := float(i) / float(steps)
		draw_rect(Rect2(0, vp.y * 0.6 * t, vp.x, vp.y * 0.6 / steps + 1.0), SKY_TOP.lerp(SKY_BOTTOM, t))
	# Skyline (parallax) with a few lit windows
	var horizon := vp.y * 0.56
	for rect: Rect2 in _skyline:
		var sx := fposmod(rect.position.x - _scroll * 0.12, vp.x + 300.0) - 150.0
		draw_rect(Rect2(sx, horizon - rect.size.y, rect.size.x, rect.size.y), Color("10141f"))
		for j in 5:
			var wx := sx + 10.0 + float(j) * (rect.size.x / 5.5)
			var wy := horizon - rect.size.y + 24.0 + float((int(rect.size.x) + j * 37) % int(rect.size.y - 40.0))
			draw_rect(Rect2(wx, wy, 8.0, 12.0), Color("ffb347", 0.55 if (j + int(rect.size.x)) % 3 == 0 else 0.12))
	# Road
	draw_rect(Rect2(0, horizon, vp.x, vp.y - horizon), Color("17191f"))
	draw_rect(Rect2(0, horizon, vp.x, 6), Color("2b2f3a"))
	var lane_h := (vp.y - horizon - 40.0) / LANES
	for l in range(1, LANES):
		var y := horizon + lane_h * l
		var dash := 70.0
		var gap := 60.0
		var x := -fposmod(_scroll, dash + gap)
		while x < vp.x:
			draw_rect(Rect2(x, y - 2.0, dash, 4.0), Color(0.9, 0.85, 0.6, 0.35))
			x += dash + gap
	# Obstacles
	for o in _obstacles:
		_draw_obstacle(String(o["kind"]), Vector2(float(o["x"]), _lane_center(int(o["lane"]))))
	# Honda + rider
	_draw_honda(Vector2(PLAYER_X, _lane_y) + off)
	# Rain
	for r: Vector2 in _rain:
		draw_line(r, r + Vector2(-9.0, 26.0), Color(0.7, 0.8, 1.0, 0.35), 1.5)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.6, 0.75, 1.0, _flash * 0.35))
	_draw_hud(vp)


func _draw_obstacle(kind: String, p: Vector2) -> void:
	match kind:
		"pothole":
			draw_colored_polygon(_ellipse(p, 46.0, 14.0), Color("0a0b0f"))
			draw_arc(p, 40.0, 0.0, TAU, 24, Color(0.4, 0.4, 0.45, 0.4), 2.0)
		"puddle":
			draw_colored_polygon(_ellipse(p, 78.0, 20.0), Color(0.25, 0.4, 0.6, 0.55))
			draw_colored_polygon(_ellipse(p + Vector2(-14, -4), 30.0, 6.0), Color(1, 1, 1, 0.18))
		"jeepney":
			draw_rect(Rect2(p + Vector2(-110, -62), Vector2(220, 78)), Color("b2402e"))
			draw_rect(Rect2(p + Vector2(-110, -70), Vector2(220, 14)), Color("e8c34a"))
			for i in 5:
				draw_rect(Rect2(p + Vector2(-98.0 + i * 40.0, -44), Vector2(30, 26)), Color("1a2230"))
			draw_circle(p + Vector2(-70, 16), 17.0, Color("0b0b0e"))
			draw_circle(p + Vector2(70, 16), 17.0, Color("0b0b0e"))
			draw_circle(p + Vector2(-112, -6), 5.0, Color("fff3b0"))


func _draw_honda(p: Vector2) -> void:
	var blink := _invuln > 0.0 and int(Time.get_ticks_msec() / 90.0) % 2 == 0
	if blink:
		return
	# Headlight cone
	draw_colored_polygon(PackedVector2Array([p + Vector2(40, -14), p + Vector2(260, -50), p + Vector2(260, 30)]), Color(1.0, 0.95, 0.7, 0.13))
	draw_circle(p + Vector2(-34, 22), 19.0, Color("0b0b0e"))
	draw_circle(p + Vector2(40, 22), 19.0, Color("0b0b0e"))
	draw_arc(p + Vector2(-34, 22), 19.0, 0.0, TAU, 20, Color("555a66"), 3.0)
	draw_arc(p + Vector2(40, 22), 19.0, 0.0, TAU, 20, Color("555a66"), 3.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-48, 4), p + Vector2(-6, -18), p + Vector2(44, -8), p + Vector2(48, 8), p + Vector2(-8, 16)]), Color("c9402e"))
	# Rider (Renzo): jacket and helmet
	draw_colored_polygon(PackedVector2Array([p + Vector2(-22, -14), p + Vector2(-6, -52), p + Vector2(14, -50), p + Vector2(10, -12)]), Color("3a4252"))
	draw_circle(p + Vector2(8, -62), 14.0, Color("20232b"))
	draw_circle(p + Vector2(15, -60), 6.0, Color(0.6, 0.8, 1.0, 0.55))
	draw_circle(p + Vector2(46, -4), 5.0, Color("fff3b0"))


func _draw_hud(vp: Vector2) -> void:
	var bar := Rect2(60.0, 40.0, vp.x - 120.0, 10.0)
	draw_rect(bar, Color(1, 1, 1, 0.12))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _progress, bar.size.y)), Color("c9a24a"))
	draw_circle(Vector2(bar.position.x + bar.size.x * _progress, bar.position.y + 5.0), 9.0, Color("ffb43a"))
	draw_string(Fonts.label(), Vector2(60, 28), "QUIAPO  ▸  THE ALLEY", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.8))
	# Time of day: 6:00 AM to the 12:00 noon tow
	var minutes := int(lerpf(6.0 * 60.0 + 12.0, 6.0 * 60.0 + 58.0, _progress))
	draw_string(Fonts.label(), Vector2(vp.x - 330.0, 28), "%02d:%02d  ·  TOW TRUCK AT 12:00" % [minutes / 60, minutes % 60], HORIZONTAL_ALIGNMENT_RIGHT, 270.0, 16, Color("ffb43a"))
	draw_string(Fonts.label(), Vector2(60, 76), "HITS: %d" % hits, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ff7a6a") if hits > 0 else Color(1, 1, 1, 0.6))
	if _hint_t > 0.0:
		draw_string(Fonts.display(), Vector2(0, vp.y - 36.0), ("TAP ABOVE OR BELOW THE BIKE  =  CHANGE LANE" if Story.is_touch() else "UP / DOWN  ·  D-PAD  =  CHANGE LANE"), HORIZONTAL_ALIGNMENT_CENTER, vp.x, 26, Color("fff7d6"))


func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
