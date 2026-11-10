class_name PartyData
extends RefCounted
## Party members, their command menus and team moves (data/party.json).

static var _data: Dictionary = {}


static func _load() -> Dictionary:
	if _data.is_empty():
		var file := FileAccess.open("res://data/party.json", FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data


static func member(id: String) -> Dictionary:
	return _load().get("members", {}).get(id, {})


## Who fights in a given episode (Renzo from the start, Dante from Episode 3).
static func party_for(episode: int) -> Array[String]:
	var out: Array[String] = []
	var members: Dictionary = _load().get("members", {})
	for id in members:
		if int(members[id].get("joins_episode", 1)) <= episode:
			out.append(id)
	return out


static func team_moves(episode: int) -> Array:
	var out: Array = []
	for t in _load().get("team_moves", []):
		if int(t.get("joins_episode", 1)) <= episode:
			out.append(t)
	return out
