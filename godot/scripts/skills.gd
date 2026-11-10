class_name Skills
extends RefCounted
## Data-driven watch powers (data/skills.json). One new Skill per episode, unlocked by a story beat; each has a
## protective and an aggressive form, picked by the Loob score at unlock.

static var _data: Dictionary = {}


static func _load() -> Dictionary:
	if _data.is_empty():
		var file := FileAccess.open("res://data/skills.json", FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data


static func all() -> Array:
	return _load().get("skills", [])


static func def(id: String) -> Dictionary:
	for s in all():
		if s["id"] == id:
			return s
	return {}


static func loob_threshold() -> int:
	return int(_load().get("loob_threshold", 1))


## "base" while variants are off, otherwise "aggressive" at or above the Loob threshold, else "protective".
static func variant_for(skill_id: String, loob: int) -> String:
	var d := def(skill_id)
	if d.is_empty() or not bool(d.get("variants_enabled", false)):
		return "base"
	return "aggressive" if loob >= loob_threshold() else "protective"


static func effects(skill_id: String, variant: String) -> Array:
	var d := def(skill_id)
	if d.is_empty():
		return []
	var table: Dictionary = d.get("effects", {})
	return table.get(variant, table.get("base", []))


static func for_episode(episode: int) -> Array:
	var out: Array = []
	for s in all():
		if int(s["episode"]) == episode:
			out.append(s)
	return out
