class_name Amulets
extends RefCounted
## Anting-anting (data/amulets.json): folk amulets, one equipped at a time, each with a perk and a small cost.

static var _data: Dictionary = {}


static func _load() -> Dictionary:
	if _data.is_empty():
		var file := FileAccess.open("res://data/amulets.json", FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data


static func all() -> Array:
	return _load().get("amulets", [])


static func def(id: String) -> Dictionary:
	for a in all():
		if a["id"] == id:
			return a
	return {}


## The amulets offered at a story choice (Episode 2: two to pick from).
static func choice_for(episode: int) -> Array:
	var out: Array = []
	for a in all():
		if int(a.get("choice_episode", 0)) == episode:
			out.append(a)
	return out


## Perk and cost merged into one modifier table (numbers add, multipliers multiply).
static func mods(id: String) -> Dictionary:
	var d := def(id)
	var out := {}
	if d.is_empty():
		return out
	for part in [d.get("perk", {}), d.get("cost", {})]:
		for k in part:
			if k.ends_with("_mult"):
				out[k] = float(out.get(k, 1.0)) * float(part[k])
			else:
				out[k] = float(out.get(k, 0.0)) + float(part[k])
	return out
