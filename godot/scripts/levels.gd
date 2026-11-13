class_name Levels
extends RefCounted
## Growth without grinding: the party levels up once, at the end of each case (the CASE CLOSED screen), and each
## member picks one of two upgrades. An episode's fights use the levels earned before it, so replaying Episode 1
## after finishing it plays the same.
##
## GROWTH: what every level adds. PERKS[id][n]: the pair offered at the end of episode n+1 (the last pair repeats).
## A perk's "mods": hp (max HP), hit (blade damage), parry (wider parry window), candles (+ a fight), wires (Kardo's
## most), shock (KONTRA's shock x this), speed.

const GROWTH := {
	"teo": {"hp": 12, "hit": 2},
	"kardo": {"hp": 14, "hit": 2},
	"sol": {"hp": 10, "hit": 1},
}
const PERKS := {
	"teo": [
		[{"id": "tibay", "name": "TIBAY", "text": "Toughness: +15 max HP", "mods": {"hp": 15}},
		 {"id": "linaw", "name": "LINAW", "text": "Clear sight: a wider parry window", "mods": {"parry": 0.05}}],
		[{"id": "kandila", "name": "KANDILA", "text": "One more candle each fight", "mods": {"candles": 1}},
		 {"id": "talim", "name": "TALIM", "text": "A keener blade: +3 damage", "mods": {"hit": 3}}],
	],
	"kardo": [
		[{"id": "kapal", "name": "MAKAPAL", "text": "Thick skin: +18 max HP", "mods": {"hp": 18}},
		 {"id": "kawad", "name": "DAGDAG KAWAD", "text": "A fourth wire for KONTRA", "mods": {"wires": 1}}],
		[{"id": "ground", "name": "GROUNDED", "text": "KONTRA's shock is halved", "mods": {"shock": 0.5}},
		 {"id": "bilis", "name": "BILIS", "text": "Quicker hands: +1 speed", "mods": {"speed": 1}}],
	],
	"sol": [
		[{"id": "tibay", "name": "TIBAY", "text": "+14 max HP", "mods": {"hp": 14}},
		 {"id": "linaw", "name": "LINAW", "text": "A wider parry window", "mods": {"parry": 0.05}}],
	],
}


## Who levels up at the end of an episode: the standing party (Kardo has fought beside Teo since Episode 1).
static func roster(episode: int) -> Array:
	var out := ["teo", "kardo"]
	if episode >= 2:
		out.append("sol")
	return out


## The level a member fights at in `episode`: one more for every case closed before it.
static func level(id: String, episode: int) -> int:
	var lv := 1
	for n in Progress.episodes_done:
		if int(n) < episode and roster(int(n)).has(id):
			lv += 1
	return lv


## The pair of upgrades offered to `id` when episode `episode` ends.
static func choices(id: String, episode: int) -> Array:
	var list: Array = PERKS.get(id, [])
	if list.is_empty():
		return []
	return list[mini(episode - 1, list.size() - 1)]


## Every stat change `id` carries into `episode`: levels plus the perks picked before it.
static func mods(id: String, episode: int) -> Dictionary:
	var out := {"hp": 0, "hit": 0, "parry": 0.0, "candles": 0, "wires": 0, "shock": 1.0, "speed": 0}
	var lv := level(id, episode)
	var g: Dictionary = GROWTH.get(id, {})
	out["hp"] = int(g.get("hp", 0)) * (lv - 1)
	out["hit"] = int(g.get("hit", 0)) * (lv - 1)
	for ep in Progress.perks:
		if int(ep) >= episode:
			continue
		var picked: Dictionary = Progress.perks[ep]
		if not picked.has(id):
			continue
		for perk in choices(id, int(ep)):
			if String(perk["id"]) != String(picked[id]):
				continue
			var m: Dictionary = perk["mods"]
			for k in m:
				if k == "shock":
					out["shock"] = float(out["shock"]) * float(m[k])
				elif k == "parry":
					out["parry"] = float(out["parry"]) + float(m[k])
				else:
					out[k] = int(out[k]) + int(m[k])
	return out
