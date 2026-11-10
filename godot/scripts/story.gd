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
var _episode: Dictionary = {}
var _opening: Dictionary = {}


func _ready() -> void:
	_episode = _load_json("res://data/episode1.json")
	_opening = _load_json("res://data/slice_opening.json")
	structure = _load_json("res://data/structure.json")
	_add_wasd()


## True on phones and tablets (a touch screen is present), so prompts say TAP instead of SPACE / A.
func is_touch() -> bool:
	return DisplayServer.is_touchscreen_available()


func accept_hint() -> String:
	return "TAP" if is_touch() else "SPACE / A / TAP"


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
	flags = {}


## Minutes on the clock now, with the time already lost to misses.
func clock(progress_minutes: float = 0.0) -> int:
	return START_CLOCK + minutes_lost + int(progress_minutes)


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


## Outcome of a timed choice. `index` is the picked option; `expired` is true if the timer ran out.
func apply_choice(id: String, index: int, expired: bool) -> void:
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
