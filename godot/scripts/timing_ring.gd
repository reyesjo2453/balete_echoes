class_name TimingRing
extends Control
## A ring closes on a fixed target. Press accept (Space / Enter / A button), click or tap while the ring
## is inside the glowing zone. Used for story QTEs and for the parry on the enemy's turn.
##
## Levels (the episode teaches in this order, with less hand-holding each time):
##   guided   - lesson card, early or late presses just reset the ring (no penalty)
##   assisted - key cap and ring, a miss counts
##   free     - ring and a small key cap only

signal finished(grade: String) # "perfect" | "good" | "miss"

const PERFECT := 0.12
const GRACE := 0.2
const ARM_MS := 200
const TARGET_R := 48.0
const RING_R := 118.0

var prompt: String = "PARRY!"
var level: String = "assisted"
var seconds: float = 1.6
var lesson: String = ""
var active: bool = false

var _t: float = 0.0
var _zone: float = 0.36
var _fails: int = 0
var _pause: float = 0.0
var _in_zone: bool = false
var _feedback: String = ""
var _armed_at: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	set_process(false)


func start(p_prompt: String, p_seconds: float, p_level: String = "assisted", p_lesson: String = "", p_zone_bonus: float = 0.0) -> void:
	prompt = p_prompt
	seconds = maxf(0.2, p_seconds)
	level = p_level
	lesson = p_lesson
	_zone = (0.5 if level == "guided" else (0.36 if level == "assisted" else 0.3)) + p_zone_bonus
	_zone = clampf(_zone, 0.12, 0.8)
	_t = 0.0
	_fails = 0
	_pause = 0.0
	_in_zone = false
	_feedback = ""
	_armed_at = Time.get_ticks_msec()
	active = true
	visible = true
	set_process(true)
	Sfx.play("command-enter")
	queue_redraw()


func current_k() -> float:
	return maxf(0.0, 1.0 - _t / seconds)


func zone_k() -> float:
	if level == "guided":
		return minf(0.75, _zone + _fails * 0.08)
	return _zone


## Called by input, and directly by tests.
func press() -> void:
	if not active or _pause > 0.0:
		return
	if Time.get_ticks_msec() - _armed_at < ARM_MS:
		return
	var k := current_k()
	if k <= zone_k():
		_end("perfect" if k <= PERFECT else "good")
	elif level == "guided":
		_retry("Too early. Wait for the ring to glow, then tap.")
	else:
		_feedback = "TOO EARLY"
		_end("miss")


func _process(delta: float) -> void:
	if not active:
		return
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			_t = 0.0
			_in_zone = false
			_feedback = ""
		queue_redraw()
		return
	_t += delta
	var now_in := current_k() <= zone_k()
	if now_in != _in_zone:
		_in_zone = now_in
		if now_in:
			Sfx.play("ui-select")
	if _t >= seconds + GRACE:
		if level == "guided":
			_retry("Too slow. Here it comes again. Tap when the ring glows.")
		else:
			_feedback = "MISSED"
			_end("miss")
	queue_redraw()


func _retry(message: String) -> void:
	_fails += 1
	_feedback = message
	_pause = 0.8
	queue_redraw()


func _end(grade: String) -> void:
	active = false
	set_process(false)
	queue_redraw()
	finished.emit(grade)


func _input(event: InputEvent) -> void:
	if not active:
		return
	var pressed := event.is_action_pressed("ui_accept")
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed:
		pressed = true
	if pressed:
		press()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if not active:
		return
	var c := Vector2(size.x * 0.5, size.y * 0.42)
	var k := current_k()
	var in_zone := k <= zone_k()
	var col := Color("7dff9a") if in_zone else Color("ffb43a")
	var ring_r := TARGET_R + (RING_R - TARGET_R) * k
	draw_circle(c, TARGET_R, Color(col, 0.14))
	draw_arc(c, TARGET_R, 0.0, TAU, 48, col if in_zone else Color.WHITE, 5.0, true)
	draw_arc(c, maxf(ring_r, TARGET_R), 0.0, TAU, 72, col, 7.0, true)
	var font := Fonts.sfx()
	draw_string(font, c + Vector2(-70.0, 11.0), prompt, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 32, Color.WHITE)

	# Key cap
	var cap := Rect2(c + Vector2(-110.0, RING_R + 26.0), Vector2(220.0, 52.0))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f1e3b0")
	style.border_color = Color("17130a")
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	if level != "free":
		draw_style_box(style, cap)
		draw_string(Fonts.display(), cap.position + Vector2(0.0, 36.0), Story.accept_hint(), HORIZONTAL_ALIGNMENT_CENTER, cap.size.x, 22, Color("17130a"))
	else:
		draw_string(Fonts.label(), cap.position + Vector2(0.0, 34.0), Story.accept_hint(), HORIZONTAL_ALIGNMENT_CENTER, cap.size.x, 16, Color(1, 1, 1, 0.6))

	if level == "guided" and lesson != "":
		draw_multiline_string(Fonts.label(), Vector2(size.x * 0.5 - 300.0, c.y - RING_R - 70.0), lesson, HORIZONTAL_ALIGNMENT_CENTER, 600.0, 20, 3, Color("fff7d6"))
	if _feedback != "":
		var fcol := Color("ffd27a") if level == "guided" else Color("ff7a6a")
		draw_multiline_string(Fonts.label(), Vector2(size.x * 0.5 - 260.0, cap.position.y + 80.0), _feedback, HORIZONTAL_ALIGNMENT_CENTER, 520.0, 20, 3, fcol)
