class_name SpecialGauge
extends Control
## The input for a party special, one kind per fighter (Teo's prayers are arrows, in stage_battle.gd):
##   "charge"  Kardo's KONTRA. HOLD (Space / A / touch), let go in the green. Held into the red it OVERCHARGES (more
##             damage, and he takes the shock); held at the top too long the breaker TRIPS.
##   "rhythm"  Lola's ORASYON. Notes slide in to the ring; TAP on each beat. Scored PERFECT / GOOD / MISS.
##   "wind"    TAP fast to wind the crown backward before the time runs out (kept for later watch powers).
##   "react"   the watch's REWIND, offered the moment a blow lands: HOLD to take it back before the window closes.
## finished(result) carries {"value": 0..1, ...} per mode. Tests set `auto` (plays itself) and `fast` (no waiting).

signal finished(result: Dictionary)

const CHARGE_SECS := 1.25 # empty to full while held
const CLEAN := 0.6 # the green starts here
const OVER := 0.88 # the red starts here
const TRIP_SECS := 0.45 # held at the very top this long: the breaker trips
const BEAT := 0.46
const RHYTHM := [0.0, 1.0, 2.0, 2.5, 3.0, 4.0] # in beats: a pasyon cadence, with one quick pair
const LEAD := 1.1 # the first note's travel time
const PERFECT_WIN := 0.08
const GOOD_WIN := 0.17
const WIND_SECS := 2.6
const WIND_GOAL := 10
const REACT_SECS := 1.6 # how long REWIND? stays open
const REACT_HOLD := 0.35 # held this long, the watch turns back

var mode := "charge"
var title := ""
var sub := ""
var accent := Color("5ad8ff")
var auto := false
var fast := false
var auto_charge := 0.75 # where the autoplay lets go of KONTRA
var auto_rhythm := 1.0 # share of notes the autoplay hits
var auto_react := true # whether the autoplay takes REWIND
var clean_at := CLEAN # KONTRA's green and red move down as the line heats up
var over_at := OVER
var held := 0.0

var active := false
var t := 0.0
var value := 0.0
var holding := false
var pressed_once := false
var over_t := 0.0
var notes: Array = [] # {"at": seconds, "grade": ""}
var perfect := 0
var good := 0
var taps := 0
var _pops: Array = [] # {"text", "t", "color"}
var _auto_next := 0.0

const BOX := Rect2(330, 170, 620, 230)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func start(p_mode: String, p_title: String, p_sub: String, p_accent: Color) -> void:
	mode = p_mode
	title = p_title
	sub = p_sub
	accent = p_accent
	t = 0.0
	value = 0.0
	holding = false
	pressed_once = false
	over_t = 0.0
	perfect = 0
	good = 0
	taps = 0
	held = 0.0
	_pops.clear()
	notes.clear()
	for b in RHYTHM:
		notes.append({"at": LEAD + float(b) * BEAT, "grade": ""})
	_auto_next = 0.25
	visible = true
	active = true
	if fast:
		_finish_auto.call_deferred()
	queue_redraw()


## Tests: the result the autoplay would reach, at once.
func _finish_auto() -> void:
	match mode:
		"charge":
			value = auto_charge
			_end({"value": value, "zone": zone(value, clean_at, over_at), "tripped": false})
		"rhythm":
			var hit := int(round(auto_rhythm * notes.size()))
			perfect = hit
			_end(_rhythm_result())
		"react":
			_end({"ok": auto_react})
		_:
			taps = WIND_GOAL
			_end({"value": 1.0, "taps": taps})


static func zone(v: float, clean: float = CLEAN, over: float = OVER) -> String:
	if v >= over:
		return "over"
	if v >= clean:
		return "clean"
	return "weak"


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	for p in _pops:
		p["t"] = float(p["t"]) + delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return float(p["t"]) < 0.7)
	if auto:
		_autoplay()
	match mode:
		"charge":
			if holding:
				value = minf(1.0, value + delta / CHARGE_SECS)
				if value >= 1.0:
					over_t += delta
					if over_t >= TRIP_SECS:
						Sfx.play("stagger-break")
						_end({"value": 1.0, "zone": "trip", "tripped": true})
						return
			elif not pressed_once and t > 4.0:
				_end({"value": 0.0, "zone": "weak", "tripped": false})
				return
		"rhythm":
			for n in notes:
				if String(n["grade"]) == "" and t - float(n["at"]) > GOOD_WIN:
					n["grade"] = "miss"
					_pop("MISS", Color("ff8a7a"))
			if t > float(notes[-1]["at"]) + 0.45:
				_end(_rhythm_result())
				return
		"react":
			if holding:
				held += delta
				if held >= REACT_HOLD:
					_end({"ok": true})
					return
			if t >= REACT_SECS:
				_end({"ok": false})
				return
		"wind":
			if t >= WIND_SECS:
				_end({"value": minf(1.0, float(taps) / WIND_GOAL), "taps": taps})
				return
	queue_redraw()


func _autoplay() -> void:
	match mode:
		"charge":
			if not pressed_once and t > 0.35:
				_press(true)
			elif holding and value >= auto_charge:
				_press(false)
		"rhythm":
			for i in notes.size():
				var n: Dictionary = notes[i]
				if String(n["grade"]) == "" and t >= float(n["at"]) and float(i) < auto_rhythm * notes.size():
					_press(true)
		"wind":
			if t >= _auto_next:
				_auto_next = t + 0.2
				_press(true)
		"react":
			if auto_react and not holding and t > 0.4:
				_press(true)


func _rhythm_result() -> Dictionary:
	var n := notes.size()
	return {"value": (float(perfect) + 0.6 * float(good)) / n, "perfect": perfect, "good": good, "notes": n}


func _press(down: bool) -> void:
	if not active:
		return
	match mode:
		"charge":
			if down and not pressed_once:
				pressed_once = true
				holding = true
				Sfx.play("hit-thud-metal")
			elif not down and holding:
				holding = false
				_end({"value": value, "zone": zone(value, clean_at, over_at), "tripped": false})
		"rhythm":
			if not down:
				return
			var best: Dictionary = {}
			for n in notes:
				if String(n["grade"]) == "" and absf(t - float(n["at"])) <= GOOD_WIN:
					best = n
					break
			if best.is_empty():
				return
			if absf(t - float(best["at"])) <= PERFECT_WIN or auto:
				best["grade"] = "perfect"
				perfect += 1
				_pop("PERFECT", Color("ffe08a"))
				Sfx.play("extra-chime")
			else:
				best["grade"] = "good"
				good += 1
				_pop("GOOD", Color("9ad7ff"))
				Sfx.play("ui-select")
		"react":
			holding = down
			if down:
				Sfx.play("ui-select")
			else:
				held = 0.0
		"wind":
			if not down:
				return
			taps += 1
			Sfx.play("ui-select")
			if taps >= WIND_GOAL:
				_end({"value": 1.0, "taps": taps})


func _pop(text: String, color: Color) -> void:
	_pops.append({"text": text, "t": 0.0, "color": color})


func _end(result: Dictionary) -> void:
	if not active:
		return
	active = false
	visible = false
	finished.emit.call_deferred(result)


func _input(event: InputEvent) -> void:
	if not active or auto:
		return
	var down := -1
	if event.is_action_pressed("ui_accept") and not event.is_echo():
		down = 1
	elif event.is_action_released("ui_accept"):
		down = 0
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		down = 1 if mb.pressed else 0
	var touch := event as InputEventScreenTouch
	if touch != null:
		down = 1 if touch.pressed else 0
	if down >= 0:
		_press(down == 1)
		get_viewport().set_input_as_handled()


# --- drawing --------------------------------------------------------------------------------------------------------

func _draw() -> void:
	if not active:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25))
	draw_rect(BOX, Retro.BOTTOM)
	draw_rect(Rect2(BOX.position, Vector2(BOX.size.x, BOX.size.y * 0.5)), Color(Retro.TOP, 0.6))
	draw_rect(BOX, Retro.EDGE, false, 3.0)
	var f := Fonts.display()
	var l := Fonts.label_medium()
	draw_string(f, BOX.position + Vector2(0, 44), title, HORIZONTAL_ALIGNMENT_CENTER, BOX.size.x, 32, accent)
	draw_string(l, BOX.position + Vector2(0, 74), sub, HORIZONTAL_ALIGNMENT_CENTER, BOX.size.x, 17, Color(1, 1, 1, 0.75))
	match mode:
		"charge":
			_draw_charge(l)
		"rhythm":
			_draw_rhythm(l)
		"react":
			_draw_react(l)
		_:
			_draw_wind(l)
	for p in _pops:
		var k := float(p["t"]) / 0.7
		var c: Color = p["color"]
		c.a = 1.0 - k
		draw_string(f, Vector2(BOX.position.x, BOX.position.y + 108 - 24 * k), String(p["text"]), HORIZONTAL_ALIGNMENT_CENTER, BOX.size.x, 30, c)


func _draw_charge(l: Font) -> void:
	var bar := Rect2(BOX.position.x + 40, BOX.position.y + 110, BOX.size.x - 80, 34)
	draw_rect(bar, Color(0, 0, 0, 0.6))
	var zones := [[0.0, clean_at, Color("3a5a8a")], [clean_at, over_at, Color("3fbf6a")], [over_at, 1.0, Color("e0503c")]]
	for z in zones:
		var r := Rect2(bar.position.x + bar.size.x * float(z[0]), bar.position.y + 26, bar.size.x * (float(z[1]) - float(z[0])), 8)
		draw_rect(r, z[2])
	var fill := Rect2(bar.position, Vector2(bar.size.x * value, 26))
	var col := Color("5ad8ff") if value < over_at else Color("ffffff").lerp(Color("e0503c"), 0.5 + 0.5 * sin(t * 30.0))
	draw_rect(fill, col)
	if value >= 1.0:
		draw_rect(bar.grow(4), Color("ff4030", 0.5 + 0.5 * sin(t * 40.0)), false, 3.0)
	draw_rect(bar, Retro.EDGE, false, 2.0)
	var labels := [["WEAK", clean_at * 0.5], ["CLEAN", (clean_at + over_at) * 0.5], ["OVER", (over_at + 1.0) * 0.5]]
	for lb in labels:
		draw_string(l, Vector2(bar.position.x + bar.size.x * float(lb[1]) - 60, bar.position.y + 58), String(lb[0]), HORIZONTAL_ALIGNMENT_CENTER, 120, 15, Color(1, 1, 1, 0.7))
	var how := "HOLD  SPACE / A / TOUCH ... and let go in the green" if not pressed_once else ("LET GO!" if value >= over_at else "charging...")
	draw_string(l, Vector2(BOX.position.x, BOX.end.y - 18), how, HORIZONTAL_ALIGNMENT_CENTER, BOX.size.x, 17, Color("ffe08a"))


func _draw_rhythm(l: Font) -> void:
	var y := BOX.position.y + 140.0
	var hit_x := BOX.position.x + 110.0
	var speed := (BOX.size.x - 160.0) / LEAD # pixels per second
	draw_line(Vector2(BOX.position.x + 40, y), Vector2(BOX.end.x - 30, y), Color(1, 1, 1, 0.25), 2.0)
	var pulse := 0.0
	for n in notes:
		var dt := absf(t - float(n["at"]))
		pulse = maxf(pulse, 1.0 - dt / 0.12)
	draw_arc(Vector2(hit_x, y), 26.0 + 4.0 * pulse, 0, TAU, 32, Color("ffe08a"), 3.0)
	for n in notes:
		var g := String(n["grade"])
		if g == "perfect" or g == "good":
			continue
		var x := hit_x + (float(n["at"]) - t) * speed
		if x > BOX.end.x - 20 or x < BOX.position.x + 20:
			continue
		var c := Color("ff8a7a", 0.5) if g == "miss" else Color("ffd27a")
		draw_circle(Vector2(x, y), 15.0, c)
		draw_arc(Vector2(x, y), 15.0, 0, TAU, 20, Color(0.2, 0.1, 0.0), 2.0)
	draw_string(l, Vector2(BOX.position.x, BOX.end.y - 18), "TAP  SPACE / A / TOUCH  as each bead reaches the ring", HORIZONTAL_ALIGNMENT_CENTER, BOX.size.x, 17, Color("ffe08a"))


func _draw_wind(l: Font) -> void:
	var c := Vector2(BOX.position.x + BOX.size.x * 0.5, BOX.position.y + 136)
	var r := 40.0
	draw_circle(c, r, Color(0.0, 0.25, 0.22, 0.9))
	draw_arc(c, r, 0, TAU, 40, Color("00ffcc"), 3.0)
	for i in 12:
		var a := TAU * i / 12.0
		draw_line(c + Vector2.from_angle(a) * (r - 7), c + Vector2.from_angle(a) * (r - 2), Color("00ffcc"), 2.0)
	var k := minf(1.0, float(taps) / WIND_GOAL)
	draw_arc(c, r + 10, -PI * 0.5, -PI * 0.5 - TAU * k, 40, Color("ffe08a"), 6.0) # wound back, anticlockwise
	draw_line(c, c + Vector2.from_angle(-PI * 0.5 - TAU * k) * (r - 8), Color.WHITE, 3.0)
	var left := maxf(0.0, WIND_SECS - t) / WIND_SECS
	var bar := Rect2(BOX.position.x + 60, BOX.end.y - 50, BOX.size.x - 120, 8)
	draw_rect(bar, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)), Color("00ffcc"))
	draw_string(l, Vector2(BOX.position.x, BOX.end.y - 16), "TAP FAST: wind the crown back  (%d / %d)" % [taps, WIND_GOAL], HORIZONTAL_ALIGNMENT_CENTER, BOX.size.x, 17, Color("ffe08a"))


func _draw_react(l: Font) -> void:
	var c := Vector2(BOX.position.x + BOX.size.x * 0.5, BOX.position.y + 138)
	var r := 38.0
	var k := minf(1.0, held / REACT_HOLD)
	draw_circle(c, r, Color(0.0, 0.25, 0.22, 0.9))
	draw_arc(c, r, 0, TAU, 40, Color("00ffcc"), 3.0)
	if k > 0.0:
		draw_arc(c, r + 9, -PI * 0.5, -PI * 0.5 - TAU * k, 40, Color("ffe08a"), 7.0) # the hands run backward
	var spin := -t * 9.0 * (1.0 + 3.0 * k)
	draw_line(c, c + Vector2.from_angle(spin) * (r - 8), Color.WHITE, 3.0)
	draw_line(c, c + Vector2.from_angle(spin * 0.1) * (r - 16), Color.WHITE, 4.0)
	var left := maxf(0.0, REACT_SECS - t) / REACT_SECS
	var bar := Rect2(BOX.position.x + 60, BOX.end.y - 46, BOX.size.x - 120, 8)
	draw_rect(bar, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)), Color("00ffcc"))
	draw_string(l, Vector2(BOX.position.x, BOX.end.y - 14), "HOLD  SPACE / A / TOUCH  to take it back", HORIZONTAL_ALIGNMENT_CENTER, BOX.size.x, 17, Color("ffe08a"))
