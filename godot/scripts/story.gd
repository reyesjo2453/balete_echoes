extends Node
## Autoload "Story": run state (utang, Loob, money), story data and the effect rules for choices and QTEs.
## Port of the web build's DispatchState plus the effect callbacks in Episode1Script.ts.

signal consequence(text: String)

var utang: int = 10
var loob: int = 0
var money: int = 150
var parries: int = 0
var perfects: int = 0
var misses: int = 0 # missed QTEs and missed parries (shown on the end card)
var deaths: int = 0 # fatal misses: the watch turned back
var minutes_lost: int = 0 # time lost to misses against the noon deadline
var injury: int = 0 # HP Renzo starts the fight without
var remembered: Array = [] # things Lola will remember
var flags: Dictionary = {}

const START_CLOCK := 362 # 6:02 AM
const DEADLINE := 720 # noon: the tow truck

var structure: Dictionary = {}
var pending_banners: Array = []
var trust: int = 0 # Dante's trust in Renzo
var elapsed_minutes: int = 0 # time spent on purpose (jobs, errands)
var flow: Dictionary = {}
var enemy_defs: Dictionary = {}
var _extra: Dictionary = {}
var _episode: Dictionary = {}
var _opening: Dictionary = {}


func _ready() -> void:
	_episode = _load_json("res://data/episode1.json")
	_opening = _load_json("res://data/slice_opening.json")
	structure = _load_json("res://data/structure.json")
	_extra = _load_json("res://data/episode1_extra.json")
	flow = _load_json("res://data/episode1_flow.json")
	enemy_defs = _load_json("res://data/enemies.json")
	_add_wasd()


## Tests set this to behave as a phone in headless runs.
var force_touch: bool = false


## True on phones and tablets (a touch screen is present), so prompts say TAP instead of SPACE / A.
func is_touch() -> bool:
	return force_touch or DisplayServer.is_touchscreen_available()


## The commit this build was made from (written by CI into data/build.json), shown on the title screen.
func build_label() -> String:
	var file := FileAccess.open("res://data/build.json", FileAccess.READ)
	if file == null:
		return "build dev"
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return "build %s" % String(parsed.get("commit", "dev"))
	return "build dev"


func accept_hint() -> String:
	return "TAP" if is_touch() else "SPACE / A / TAP"


## The hint shown once a timed card or wait can be skipped, matched to the device in hand.
func continue_hint() -> String:
	if is_touch():
		return "TAP TO CONTINUE"
	if not Input.get_connected_joypads().is_empty():
		return "PRESS A TO CONTINUE"
	return "CLICK OR PRESS ENTER TO CONTINUE"


var _last_accept_ms: int = -1000


## One definition of "the player said continue": tap, click, Enter/Space or controller A. A single physical
## tap often arrives as a touch event and an emulated mouse click, so repeats within 120 ms count once.
func is_accept(event: InputEvent) -> bool:
	var hit := event.is_action_pressed("ui_accept")
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		hit = true
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed:
		hit = true
	var pad := event as InputEventJoypadButton
	if pad != null and pad.pressed and pad.button_index == JOY_BUTTON_A:
		hit = true
	if not hit:
		return false
	var now := Time.get_ticks_msec()
	if now - _last_accept_ms < 120:
		return false
	_last_accept_ms = now
	return true


func reset() -> void:
	utang = 10
	loob = 0
	money = 150
	parries = 0
	perfects = 0
	misses = 0
	deaths = 0
	minutes_lost = 0
	injury = 0
	remembered = []
	pending_banners = []
	trust = 0
	elapsed_minutes = 0
	flags = {}


## Minutes on the clock now, with the time already lost to misses.
func clock(progress_minutes: float = 0.0) -> int:
	return START_CLOCK + minutes_lost + elapsed_minutes + int(progress_minutes)


## Time spent on purpose (a job, an errand): it moves the clock toward noon, but it is not a punishment.
func spend_time(minutes: int) -> void:
	elapsed_minutes += minutes


func clock_text(minutes: int) -> String:
	return "%02d:%02d" % [minutes / 60, minutes % 60]


## A banner to show as soon as the next story screen is up (used when no screen is open to show it).
func queue_banner(text: String) -> void:
	pending_banners.append(text)


func lose_time(minutes: int, message: String = "") -> void:
	minutes_lost += minutes
	if message != "":
		consequence.emit(message)


## Lola keeps count. The banner tells the player a miss has a cost later.
func lola_remembers(what: String) -> void:
	if not remembered.has(what):
		remembered.append(what)
	consequence.emit("Lola will remember that.")


## Strip glyphs the web fonts do not have (they would show as boxes) from story text.
func clean(text: String) -> String:
	return text.replace("₱", "P").replace("▸", ">").replace("●", "*").replace("○", "o")


## Steps of a story scene (see data/episode1.json and data/slice_opening.json).
func scene(id: String) -> Array:
	var from_extra: Dictionary = _extra.get("scenes", {})
	if from_extra.has(id):
		return from_extra[id]
	var from_episode: Dictionary = _episode.get("scenes", {})
	if from_episode.has(id):
		return from_episode[id]
	var from_opening: Dictionary = _opening.get("scenes", {})
	if from_opening.has(id):
		return from_opening[id]
	push_warning("Unknown story scene: " + id)
	return []


func add_utang(amount: int, message: String = "") -> void:
	utang = maxi(0, utang + amount)
	if message != "":
		consequence.emit(message)


## A step shows only if its `if` flag is set and its `unless` flag is not (so scenes can answer earlier choices).
func cond_ok(step: Dictionary) -> bool:
	if step.has("if"):
		var wanted: Variant = step["if"]
		var names: Array = wanted if wanted is Array else [wanted]
		for n in names:
			if not flags.get(String(n), false):
				return false
	if step.has("unless"):
		var banned: Variant = step["unless"]
		var names2: Array = banned if banned is Array else [banned]
		for n2 in names2:
			if flags.get(String(n2), false):
				return false
	return true


## Data-driven consequences: loob, utang, money, minutes (lost to a mistake), spend (time on purpose),
## trust (Dante), flags, remember (Lola will remember that), banner.
func apply_effects(fx: Dictionary) -> void:
	loob += int(fx.get("loob", 0))
	trust += int(fx.get("trust", 0))
	money = maxi(0, money + int(fx.get("money", 0)))
	injury = clampi(injury + int(fx.get("injury", 0)), 0, 40)
	if fx.has("spend"):
		spend_time(int(fx["spend"]))
	if fx.has("utang"):
		add_utang(int(fx["utang"]))
	if fx.has("minutes"):
		lose_time(int(fx["minutes"]))
	for f in fx.get("flags", []):
		flags[String(f)] = true
	if fx.has("remember"):
		lola_remembers(String(fx["remember"]))
	if fx.has("banner"):
		consequence.emit(String(fx["banner"]))


## Outcome of a timed choice. `index` is the picked option; `expired` is true if the timer ran out.
func apply_choice(id: String, index: int, expired: bool, choice: Dictionary = {}) -> void:
	if choice.has("effects"):
		var list: Array = choice["effects"]
		var picked := index if index >= 0 and index < list.size() else 0
		flags["choice_" + id] = picked + 1
		apply_effects(list[picked])
		return
	match id:
		"lola_silence":
			flags["pressed_lola"] = index == 0
			if expired:
				flags["hesitated"] = true
				add_utang(1, "Time ran out: +1 utang")
			elif index == 0:
				loob += 1
				consequence.emit("Lola will remember that. (Loob +1)")
			else:
				consequence.emit("Harmony kept. But you are blind to what's coming.")
		"sacristan":
			if index == 0 and not expired:
				money = maxi(0, money - 200)
				consequence.emit("P200 gone. The sacristan forgets what he heard.")
			elif flags.get("sacristan_heard", false):
				add_utang(1, "He heard it ticking. He'll tell the lender: +1 utang")
			else:
				consequence.emit("He didn't hear a thing. This time.")


## Outcome of a quick-time beat.
func apply_qte(id: String, ok: bool) -> void:
	match id:
		"tin_slip":
			pass # guided lesson: no penalty
		"honda_kick":
			if not ok:
				misses += 1
				lose_time(15, "Flooded plug: 15 minutes lost against the noon deadline")
		"gate_brace":
			if not ok:
				misses += 1
				injury = mini(40, injury + 10)
				consequence.emit("Thrown by the blast: Renzo starts the next fight 10 HP down")
		"candles_steady":
			flags["sacristan_heard"] = not ok
			if not ok:
				misses += 1
				lola_remembers("the sacristan heard the watch")


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing data file: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("Bad JSON in " + path)
	return {}


## WASD also drives the UI actions, next to the arrows, d-pad and left stick Godot already maps.
func _add_wasd() -> void:
	var pairs := {
		"ui_left": KEY_A,
		"ui_right": KEY_D,
		"ui_up": KEY_W,
		"ui_down": KEY_S,
	}
	for action in pairs:
		var ev := InputEventKey.new()
		ev.physical_keycode = pairs[action]
		InputMap.action_add_event(action, ev)
