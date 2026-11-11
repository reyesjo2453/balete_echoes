extends Node
## Autoload "Story": run state and story data. The state is small on purpose:
##   utang   borrowed time. Every second the watch borrows is written against the family. While Teo carries the
##           watch, what he borrows greys his hair (age_stage), and the endings read it.
##   loob    resolve, from the big choices (decides whether watch powers take a protective or aggressive form).
##   bonds   how close Teo is to each person (Kardo, Lola Ising, ...). Decides who stands with him later.
##   flags   what happened, for scenes to answer. remembered: "<who> will remember that".

signal consequence(text: String)

var utang: int = 0
var borrowed: int = 0 # the part of the utang Teo borrowed himself (it ages him)
var loob: int = 0
var bonds: Dictionary = {}
var parries: int = 0
var perfects: int = 0
var misses: int = 0 # missed QTEs and missed parries (shown on the end card)
var deaths: int = 0 # fatal misses: the watch turned back
var injury: int = 0 # HP the next fight starts without (a failed QTE)
var remembered: Array = [] # {"who", "what"}
var flags: Dictionary = {}
var chapter: int = 0 # 0 = the cold open (prologue), then the chapter cards in the flow

## Mid-episode save: a checkpoint is the full story state at the start of a beat (a card, scene, hub or fight).
## Continuing resumes at that beat; quitting mid-fight therefore restarts the fight with the same injuries.
const RUN_VERSION := 1
var run_path: String = "user://balete_run.json"
var run_beat: int = -1
var run_heard: Array = []
var _checkpoint: Dictionary = {}

## Borrowed time at which Teo's hair greys a little more (stage 1 is the first white streak).
const AGE_STEPS := [2, 6, 10, 15]

var structure: Dictionary = {}
var pending_banners: Array = []
var flow: Dictionary = {}
var enemy_defs: Dictionary = {}
var _episode: Dictionary = {}


func _ready() -> void:
	_episode = _load_json("res://data/episode1.json")
	structure = _load_json("res://data/structure.json")
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
	utang = 0
	borrowed = 0
	loob = 0
	bonds = {}
	parries = 0
	perfects = 0
	misses = 0
	deaths = 0
	injury = 0
	remembered = []
	pending_banners = []
	flags = {}
	chapter = 0


## Everything a resume needs to rebuild the story so far.
func snapshot() -> Dictionary:
	return {
		"utang": utang, "borrowed": borrowed, "loob": loob, "bonds": bonds.duplicate(true),
		"parries": parries, "perfects": perfects, "misses": misses, "deaths": deaths, "injury": injury,
		"remembered": remembered.duplicate(true), "flags": flags.duplicate(true), "chapter": chapter,
	}


func restore(d: Dictionary) -> void:
	reset()
	utang = int(d.get("utang", 0))
	borrowed = int(d.get("borrowed", 0))
	loob = int(d.get("loob", 0))
	parries = int(d.get("parries", 0))
	perfects = int(d.get("perfects", 0))
	misses = int(d.get("misses", 0))
	deaths = int(d.get("deaths", 0))
	injury = int(d.get("injury", 0))
	chapter = int(d.get("chapter", 0))
	var b: Dictionary = d.get("bonds", {})
	for who in b:
		bonds[String(who)] = int(b[who])
	for r in d.get("remembered", []):
		remembered.append({"who": String(r.get("who", "")), "what": String(r.get("what", ""))})
	var f: Dictionary = d.get("flags", {})
	for k in f:
		var v: Variant = f[k]
		flags[String(k)] = int(v) if (v is float and is_equal_approx(v, roundf(v))) else v # JSON hands ints back as floats


## Records the state at the start of beat `beat` (and, inside a hub, which options were already heard) and saves it.
func checkpoint(beat: int, heard: Array = []) -> void:
	run_beat = beat
	run_heard = heard.duplicate()
	_checkpoint = {"version": RUN_VERSION, "beat": beat, "heard": run_heard, "chapter": chapter,
		"state": snapshot(), "saved_at": int(Time.get_unix_time_from_system())}
	write_run()


## Writes the last checkpoint to disk (also called when the app goes to the background or closes).
func write_run() -> bool:
	if _checkpoint.is_empty():
		return false
	var file := FileAccess.open(run_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_checkpoint))
	file.close()
	return true


## The saved checkpoint, or {} if there is none (or it cannot be read).
func peek_run() -> Dictionary:
	if not FileAccess.file_exists(run_path):
		return {}
	var file := FileAccess.open(run_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and int(parsed.get("version", 0)) == RUN_VERSION and int(parsed.get("beat", -1)) >= 0:
		return parsed
	return {}


func has_run() -> bool:
	return not peek_run().is_empty()


## Loads the checkpoint into the story state. False if there is nothing to continue.
func load_run() -> bool:
	var d := peek_run()
	if d.is_empty():
		return false
	restore(d.get("state", {}))
	run_beat = int(d["beat"])
	run_heard = []
	for h in d.get("heard", []):
		run_heard.append(int(h))
	_checkpoint = d
	return true


func clear_run() -> void:
	_checkpoint = {}
	run_beat = -1
	run_heard = []
	if FileAccess.file_exists(run_path):
		DirAccess.remove_absolute(run_path)


func chapter_label(n: int) -> String:
	return "PROLOGUE" if n <= 0 else "CHAPTER %d" % n


## "Previously on Balete": the recap lines (flow "recap") whose flags this run has set, the latest `limit` of them.
func recap_lines(limit: int = 6) -> Array:
	var out: Array = []
	for entry in flow.get("recap", []):
		if cond_ok(entry):
			out.append(String(entry.get("text", "")))
	return out.slice(maxi(0, out.size() - limit))


## A banner to show as soon as the next story screen is up (used when no screen is open to show it).
func queue_banner(text: String) -> void:
	pending_banners.append(text)


## Telltale-style memory: "<who> will remember that."
func remember(who: String, what: String) -> void:
	for r in remembered:
		if String(r["who"]) == who and String(r["what"]) == what:
			return
	remembered.append({"who": who, "what": what})
	consequence.emit("%s will remember that." % who)


func bond(who: String) -> int:
	return int(bonds.get(who, 0))


## 0 = untouched, 1 = the first white streak ... 4 = Lolo Pido's hair.
func age_stage() -> int:
	var stage := 0
	for step in AGE_STEPS:
		if borrowed >= int(step):
			stage += 1
	return stage


## How grey Teo's portrait is (0..1).
func age_amount() -> float:
	return clampf(float(age_stage()) / float(AGE_STEPS.size()), 0.0, 1.0) * 0.85


## Strip glyphs the web fonts do not have (they would show as boxes) from story text.
func clean(text: String) -> String:
	return text.replace("₱", "P").replace("▸", ">").replace("●", "*").replace("○", "o")


## Steps of a story scene (data/episode1.json, generated by tools/build_episode1.py).
func scene(id: String) -> Array:
	var all: Dictionary = _episode.get("scenes", {})
	if all.has(id):
		return all[id]
	push_warning("Unknown story scene: " + id)
	return []


## Borrowed time. While Teo carries the watch, borrowing greys his hair, and the game says so.
func add_utang(amount: int, message: String = "") -> void:
	utang = maxi(0, utang + amount)
	var before := age_stage()
	if amount > 0 and flags.get("bearer_teo", false):
		borrowed += amount
	if message != "":
		consequence.emit(message)
	if age_stage() > before:
		consequence.emit("Borrowed time leaves a mark: more white in Teo's hair.")


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


## Data-driven consequences: flags, loob, bond {who: n}, utang, injury, remember {who, what}, banner.
func apply_effects(fx: Dictionary) -> void:
	loob += int(fx.get("loob", 0))
	var b: Dictionary = fx.get("bond", {})
	for who in b:
		bonds[who] = bond(String(who)) + int(b[who])
	injury = clampi(injury + int(fx.get("injury", 0)), 0, 40)
	if fx.has("utang"):
		add_utang(int(fx["utang"]))
	for f in fx.get("flags", []):
		flags[String(f)] = true
	if fx.has("remember"):
		var r: Dictionary = fx["remember"]
		remember(String(r.get("who", "")), String(r.get("what", "")))
	if fx.has("banner"):
		consequence.emit(String(fx["banner"]))


## Outcome of a choice: its effects, and choice_<id> = the option picked (1-based).
func apply_choice(id: String, index: int, _expired: bool, choice: Dictionary = {}) -> void:
	var list: Array = choice.get("effects", [])
	if list.is_empty():
		return
	var picked := index if index >= 0 and index < list.size() else 0
	flags["choice_" + id] = picked + 1
	apply_effects(list[picked])


## Outcome of a story QTE: sets <id>_ok or <id>_miss so later steps can answer it, then applies its effects.
func apply_qte(id: String, ok: bool, q: Dictionary = {}) -> void:
	flags[id + ("_ok" if ok else "_miss")] = true
	if not ok:
		misses += 1
	var fx: Dictionary = q.get("ok" if ok else "miss", {})
	if not fx.is_empty():
		apply_effects(fx)


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
