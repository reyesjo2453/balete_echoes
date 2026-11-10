extends Node
## Autoload "Story": run state (utang, Loob, money), story data and the effect rules for choices and QTEs.
## Port of the web build's DispatchState plus the effect callbacks in Episode1Script.ts.

signal consequence(text: String)

var utang: int = 10
var loob: int = 0
var money: int = 150
var parries: int = 0
var perfects: int = 0
var flags: Dictionary = {}

var _episode: Dictionary = {}
var _opening: Dictionary = {}


func _ready() -> void:
	_episode = _load_json("res://data/episode1.json")
	_opening = _load_json("res://data/slice_opening.json")
	_add_wasd()


func reset() -> void:
	utang = 10
	loob = 0
	money = 150
	parries = 0
	perfects = 0
	flags = {}


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
				consequence.emit("₱200 gone. The sacristan forgets what he heard.")
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
				add_utang(1, "Flooded plug: ten minutes lost, +1 utang")
		"candles_steady":
			flags["sacristan_heard"] = not ok


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
