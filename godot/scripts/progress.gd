extends Node
## Autoload "Progress": save data that tracks unlocks across episodes.
## Skills (with the form picked by Loob at unlock), amulets and the equipped one, episodes completed, the Loob
## path. A later season carries over the Loob path and the amulets (new_season()).

const SAVE_VERSION := 1

var save_path: String = "user://balete_save.json"
var season: int = 1
var episodes_done: Array = []
var loob_path: String = "unset" # "protective" | "aggressive" | "unset"
var skills: Dictionary = {} # skill id -> {"variant": String, "episode": int}
var amulets: Array = []
var equipped: String = ""


func _ready() -> void:
	load_game()


func reset() -> void:
	season = 1
	episodes_done = []
	loob_path = "unset"
	skills = {}
	amulets = []
	equipped = ""


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"season": season,
		"episodes_done": episodes_done,
		"loob_path": loob_path,
		"skills": skills,
		"amulets": amulets,
		"equipped": equipped,
	}


## Loads a save dictionary, upgrading older layouts. Anything unreadable is ignored (defaults stay).
func from_dict(d: Dictionary) -> bool:
	d = _migrate(d)
	if int(d.get("version", 0)) != SAVE_VERSION:
		return false
	season = int(d.get("season", 1))
	episodes_done = []
	for n in d.get("episodes_done", []):
		episodes_done.append(int(n)) # JSON hands numbers back as floats
	loob_path = String(d.get("loob_path", "unset"))
	skills = {}
	var saved_skills: Dictionary = d.get("skills", {})
	for id in saved_skills:
		var entry: Dictionary = saved_skills[id]
		skills[String(id)] = {"variant": String(entry.get("variant", "base")), "episode": int(entry.get("episode", 1))}
	amulets = d.get("amulets", [])
	equipped = String(d.get("equipped", ""))
	if not amulets.has(equipped):
		equipped = ""
	return true


func _migrate(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	if not out.has("version"):
		# Version 0 kept a flat list of unlocked skill ids.
		var migrated := {}
		for id in out.get("unlocked", []):
			migrated[String(id)] = {"variant": "base", "episode": 1}
		out["skills"] = out.get("skills", migrated)
		out["version"] = 1
	return out


func save_game() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dict()))
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return from_dict(parsed)
	return false


## A story beat unlocks a watch power. The Loob score right now decides its form.
func unlock_skill(id: String, loob: int, episode: int) -> String:
	var variant := Skills.variant_for(id, loob)
	skills[id] = {"variant": variant, "episode": episode}
	save_game()
	return variant


func has_skill(id: String) -> bool:
	return skills.has(id)


func grant_amulet(id: String) -> void:
	if not amulets.has(id) and not Amulets.def(id).is_empty():
		amulets.append(id)
		save_game()


## One amulet at a time: equipping swaps the previous one out.
func equip(id: String) -> bool:
	if id != "" and not amulets.has(id):
		return false
	equipped = id
	save_game()
	return true


func equipped_mods() -> Dictionary:
	return Amulets.mods(equipped) if equipped != "" else {}


func complete_episode(episode: int, loob: int) -> void:
	if not episodes_done.has(episode):
		episodes_done.append(episode)
	loob_path = "aggressive" if loob >= Skills.loob_threshold() else "protective"
	save_game()


## Skills a battle starts with: Episode 1 teaches the watch mid-fight, later episodes carry what is unlocked.
func battle_skills(episode: int) -> Array:
	var out: Array = []
	if episode <= 1:
		return out
	for id in skills:
		if int(Skills.def(id).get("episode", 99)) <= episode:
			out.append({"id": id, "variant": String(skills[id]["variant"])})
	return out


## A later season: skills and episode progress start over; the Loob path and the amulets carry over.
func new_season() -> void:
	season += 1
	episodes_done = []
	skills = {}
	save_game()
