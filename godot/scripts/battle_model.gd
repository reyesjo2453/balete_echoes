class_name BattleModel
extends RefCounted
## Pure turn-based battle rules: no UI, no timers. The Combat screen drives it and the headless tests fuzz it.
##
## Rounds: every living unit acts once per round, fastest first. Enemies show an intent for their next turn
## (Slay the Spire style) so Guard versus Attack is a real choice. On an enemy turn the player parries with a
## timed ring: perfect = no damage, a stagger, a counter window and watch energy; good = most of it blocked;
## miss = full damage. Three perfect parries break the guard (the next hit lands double). Some attacks cannot be
## parried at all ("dodge": true): any hit in the zone avoids them, there is no counter, and Guard does not help.
## Action economy (Expedition 33 shape): attacks and perfect parries charge the watch; powers spend it.
## Kardo's mechanic is the circuit: WIRE adds a stack (up to 3), DISCHARGE spends them all at once.
##
## Progression hooks (all data-driven): watch Skills with a protective or aggressive form, a watch-energy meter
## fed by perfect parries, an equipped amulet's modifiers, and a party of one or two (plus team moves).

const STAGGER_TO_BREAK := 3
const WATCH_AWAKENS_AT := 0.55
const TEA_HEAL := 30
const MAX_ENERGY := 6
const MAX_WIRES := 3

const ATTACKS := {
	"claw": {"name": "Claw", "text": "The Aswang rakes the air, claws low.", "rings": 1, "seconds": 1.5, "damage": 18},
	"lunge": {"name": "Lunge", "text": "The Aswang coils, every rib showing... and LUNGES.", "rings": 1, "seconds": 1.0, "damage": 28},
	"flurry": {"name": "Flurry", "text": "It whirls into a blur of claws. Three strikes, one breath.", "rings": 3, "seconds": 0.9, "damage": 9},
}


class Unit:
	var id: String
	var display_name: String
	var is_ally: bool
	## HP never drops below this (the Episode 1 aswang holds at 1 until the watch has awakened).
	var floor_hp: int = 0
	var hp: int:
		set(v):
			hp = maxi(v, floor_hp)
	var max_hp: int
	var speed: int
	var guarding: bool = false
	var shield: int = 0
	var stagger: int = 0
	var stunned: bool = false
	var stalled: bool = false
	var wired: int = 0 # Kardo's circuit stacks on an enemy
	var intent: Dictionary = {}

	func _init(p_id: String, p_name: String, p_ally: bool, p_hp: int, p_speed: int) -> void:
		id = p_id
		display_name = p_name
		is_ally = p_ally
		hp = p_hp
		max_hp = p_hp
		speed = p_speed

	func alive() -> bool:
		return hp > 0


var allies: Array[Unit] = []
var enemies: Array[Unit] = []
var rng := RandomNumberGenerator.new()
var round_no: int = 0
var queue: Array[Unit] = []
var teas: int = 2
var enemy_turns: int = 0
var episode: int = 1
## Only the story fight lets the watch awaken (Episode 1 tutorial); other fights leave it asleep.
var awakening_enabled: bool = true
## The enemy's moves (data/enemies.json). The first key is the teaching attack.
var attack_table: Dictionary = ATTACKS

## Unlocked watch powers: {"id", "variant", "uses_left"} (uses_left -1 = unlimited).
var skills: Array = []
var energy: int = 0
var team_moves: Array = []
var mods: Dictionary = {} # equipped amulet modifiers
var parry_widen: float = 1.0 # set by Slow, consumed by the next parry
var counter_open_next: bool = false
var last_action: Dictionary = {}
var last_hit: int = 0

var _round_snapshot: Dictionary = {}
var _enemy_turn_snapshot: Dictionary = {}


func start() -> void:
	round_no = 0
	_new_round()
	for e in enemies:
		plan_intent(e)


func mod(key: String, default_value: float = 0.0) -> float:
	return float(mods.get(key, default_value))


## Episode 1's tutorial unlock: Skill appears mid-fight when the watch awakens.
var skill_unlocked: bool:
	get:
		return not skills.is_empty()


func energy_enabled() -> bool:
	for s in skills:
		if float(Skills.def(String(s["id"])).get("energy_cost", 0)) > 0.0:
			return true
	return not team_moves.is_empty()


func _living_by_speed() -> Array[Unit]:
	var all: Array[Unit] = []
	for u in allies:
		if u.alive():
			all.append(u)
	for u in enemies:
		if u.alive():
			all.append(u)
	all.sort_custom(func(a: Unit, b: Unit) -> bool: return a.speed > b.speed)
	return all


func _new_round() -> void:
	round_no += 1
	queue = _living_by_speed()
	_round_snapshot = _snapshot()


## The unit whose turn it is (skips the fallen, rolls into the next round when the queue empties).
func current() -> Unit:
	while true:
		while not queue.is_empty() and not queue[0].alive():
			queue.pop_front()
		if not queue.is_empty():
			return queue[0]
		if is_victory() or is_defeat():
			return null
		_new_round()
	return null


func end_turn() -> void:
	if not queue.is_empty():
		queue.pop_front()


## The next `count` turns, for the turn-order bar.
func preview(count: int) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in queue:
		if u.alive() and out.size() < count:
			out.append(u)
	var next_round := _living_by_speed()
	while out.size() < count and not next_round.is_empty():
		for u in next_round:
			if out.size() < count:
				out.append(u)
	return out


# --- Commands ------------------------------------------------------------------------------------

func commands_of(actor: Unit) -> Array:
	return PartyData.member(actor.id).get("commands", ["attack", "guard", "item"])


## What the player can do right now. Attack and Guard are always available, so a turn can never soft-lock.
func usable(actor: Unit) -> Array[String]:
	var out: Array[String] = []
	for c in commands_of(actor):
		match String(c):
			"attack", "guard":
				out.append(String(c))
			"item":
				if teas > 0:
					out.append("item")
			"skill":
				if not usable_skills().is_empty():
					out.append("skill")
			"wire":
				if _foe() != null and _foe().wired < MAX_WIRES:
					out.append("wire")
			"discharge":
				if _foe() != null and _foe().wired > 0:
					out.append("discharge")
	if not usable_team_moves().is_empty():
		out.append("team")
	return out


func usable_skills() -> Array:
	var out: Array = []
	for s in skills:
		if skill_usable(s):
			out.append(s)
	return out


func skill_usable(s: Dictionary) -> bool:
	var d := Skills.def(String(s["id"]))
	if energy < int(d.get("energy_cost", 0)):
		return false
	return int(s.get("uses_left", -1)) != 0


func usable_team_moves() -> Array:
	var out: Array = []
	for t in team_moves:
		var ok := energy >= int(t.get("energy_cost", 0))
		for id in t.get("members", []):
			var found := false
			for a in allies:
				if a.id == id and a.alive():
					found = true
			ok = ok and found
		if ok:
			out.append(t)
	return out


func attack_range(actor: Unit) -> Vector2i:
	return Vector2i(14, 20) if actor.id == "kardo" else Vector2i(18, 24)


func _foe() -> Unit:
	for e in enemies:
		if e.alive():
			return e
	return null


## Attacks charge the watch a little (only once the watch has powers that spend it).
func _charge(amount: int) -> void:
	if energy_enabled():
		energy = mini(MAX_ENERGY, energy + amount)


func attack(target: Unit, actor: Unit = null) -> int:
	var span := attack_range(actor) if actor != null else Vector2i(18, 24)
	var dmg := rng.randi_range(span.x, span.y)
	if target.stunned:
		dmg *= 2
		target.stunned = false
	target.hp = maxi(0, target.hp - dmg)
	last_hit = dmg
	last_action = {"cmd": "attack", "dmg": dmg}
	_charge(1)
	return dmg


func guard(actor: Unit) -> void:
	actor.guarding = true
	last_action = {"cmd": "guard"}


func use_tea(actor: Unit) -> int:
	if teas <= 0:
		return 0
	teas -= 1
	var before := actor.hp
	actor.hp = mini(actor.max_hp, actor.hp + TEA_HEAL)
	last_action = {"cmd": "item", "heal": actor.hp - before}
	return actor.hp - before


## Kardo: clamp a wire on the enemy. A small hit, and one more stack in the circuit.
func wire(_actor: Unit, target: Unit) -> int:
	target.wired = mini(MAX_WIRES, target.wired + 1)
	target.hp = maxi(0, target.hp - 4)
	last_action = {"cmd": "wire", "dmg": 4}
	return 4


## Kardo: close the circuit. Every stack hits and staggers; three stacks break its guard outright.
func discharge(_actor: Unit, target: Unit) -> int:
	var n := target.wired
	target.wired = 0
	var dmg := 6 + 10 * n
	if target.stunned:
		dmg *= 2
		target.stunned = false
	target.hp = maxi(0, target.hp - dmg)
	target.stagger += n
	if target.stagger >= STAGGER_TO_BREAK:
		target.stagger = 0
		target.stunned = true
	last_hit = dmg
	last_action = {"cmd": "discharge", "dmg": dmg}
	return dmg


## Team move (Bayanihan): every listed member strikes together.
func team_move(t: Dictionary, target: Unit) -> int:
	energy -= int(t.get("energy_cost", 0))
	var total := 0
	for id in t.get("members", []):
		for a in allies:
			if a.id == id and a.alive():
				var span := attack_range(a)
				total += int(round(float(rng.randi_range(span.x, span.y)) * float(t.get("mult", 1.5))))
	target.hp = maxi(0, target.hp - total)
	last_action = {"cmd": "team", "dmg": total}
	return total


## Use a watch power. Applies every effect of its current form (base, protective or aggressive).
func use_skill(skill_id: String, actor: Unit, target: Unit) -> Dictionary:
	var result := {"ok": false, "restored": 0, "damage": 0, "healed": 0, "shield": 0, "stalled": false, "utang": 0}
	for s in skills:
		if String(s["id"]) != skill_id or not skill_usable(s):
			continue
		var d := Skills.def(skill_id)
		energy -= int(d.get("energy_cost", 0))
		if int(s.get("uses_left", -1)) > 0:
			s["uses_left"] = int(s["uses_left"]) - 1
		result["ok"] = true
		result["utang"] = int(d.get("utang_cost", 0))
		for eff in Skills.effects(skill_id, String(s["variant"])):
			_apply_effect(eff, actor, target, result)
		break
	return result


func _apply_effect(eff: Dictionary, actor: Unit, target: Unit, result: Dictionary) -> void:
	match String(eff["type"]):
		"undo_last_blow":
			var saved: int = _enemy_turn_snapshot.get(actor.id, actor.hp)
			result["restored"] = int(result["restored"]) + maxi(0, saved - actor.hp)
			actor.hp = maxi(actor.hp, saved)
		"heal":
			var before := actor.hp
			actor.hp = mini(actor.max_hp, actor.hp + int(eff["amount"]))
			result["healed"] = int(result["healed"]) + actor.hp - before
		"replay_hit":
			var dmg := int(round(float(last_hit) * float(eff.get("mult", 1.0))))
			target.hp = maxi(0, target.hp - dmg)
			result["damage"] = int(result["damage"]) + dmg
		"widen_parry":
			parry_widen = maxf(parry_widen, float(eff["mult"]))
		"shield":
			for a in allies:
				if a.alive():
					a.shield += int(eff["amount"])
			result["shield"] = int(result["shield"]) + int(eff["amount"])
		"open_counter":
			counter_open_next = true
		"repeat_last":
			var mult := float(eff.get("mult", 1.0))
			match String(last_action.get("cmd", "")):
				"attack", "team", "discharge":
					var dmg2 := int(round(float(last_action.get("dmg", 0)) * mult))
					target.hp = maxi(0, target.hp - dmg2)
					result["damage"] = int(result["damage"]) + dmg2
				"guard":
					actor.guarding = true
				"item":
					var heal2 := int(round(float(last_action.get("heal", 0)) * mult))
					var before2 := actor.hp
					actor.hp = mini(actor.max_hp, actor.hp + heal2)
					result["healed"] = int(result["healed"]) + actor.hp - before2
		"stall_enemies":
			for e in enemies:
				if e.alive():
					e.stalled = true
			result["stalled"] = true
		"damage_all":
			for e in enemies:
				if e.alive():
					e.hp = maxi(0, e.hp - int(eff["amount"]))
			result["damage"] = int(result["damage"]) + int(eff["amount"])


## Start a battle with the watch powers carried in the save ({"id", "variant"} each).
func load_skills(list: Array) -> void:
	skills = []
	for item in list:
		var d := Skills.def(String(item["id"]))
		var uses := int(d.get("uses_per_fight", 0))
		skills.append({"id": item["id"], "variant": item["variant"], "uses_left": uses if uses > 0 else -1})


## Who the enemy strikes: a random living ally.
func pick_target() -> Unit:
	var alive: Array[Unit] = []
	for a in allies:
		if a.alive():
			alive.append(a)
	if alive.is_empty():
		return null
	return alive[rng.randi_range(0, alive.size() - 1)]


## Compatibility with Episode 1's single rewind.
func rewind(actor: Unit) -> int:
	var r := use_skill("rewind", actor, enemies[0])
	return int(r["restored"])


## The Episode 1 tutorial: the watch awakens at 55% enemy health and unlocks Rewind (one use).
func check_awakening() -> bool:
	if episode != 1 or not awakening_enabled or not skills.is_empty() or enemies.is_empty():
		return false
	var e := enemies[0]
	if float(e.hp) / float(e.max_hp) <= WATCH_AWAKENS_AT and e.alive():
		e.floor_hp = 0
		skills.append({"id": "rewind", "variant": Skills.variant_for("rewind", 0), "uses_left": 1})
		return true
	return false


# --- Enemy turns --------------------------------------------------------------------------------

func plan_intent(e: Unit) -> void:
	var pool: Array = attack_table.keys()
	var key: String = pool[0]
	if enemy_turns >= 2:
		key = pool[rng.randi_range(0, pool.size() - 1)]
	var attack_def: Dictionary = attack_table[key].duplicate()
	attack_def["key"] = key
	e.intent = attack_def


func begin_enemy_turn(e: Unit) -> void:
	enemy_turns += 1
	_enemy_turn_snapshot = {}
	for u in allies:
		_enemy_turn_snapshot[u.id] = u.hp
	# A stalled enemy (the finale power) loses this turn.
	if e.stalled:
		e.stalled = false
		e.intent = e.intent.duplicate()
		e.intent["skipped"] = true


## How forgiving the parry ring is: the first is a lesson, the second is assisted, then it is on your own.
func ring_level() -> String:
	if enemy_turns <= 1:
		return "guided"
	if enemy_turns == 2:
		return "assisted"
	return "free"


func ring_seconds(e: Unit) -> float:
	var base := float(e.intent["seconds"])
	match ring_level():
		"guided":
			base = 2.8
		"assisted":
			base = 1.8
	return base * parry_widen


## Extra parry-window width: the amulet's perk and Slow. The ring consumes it.
func zone_bonus() -> float:
	return mod("parry_zone") + (0.1 if parry_widen > 1.0 else 0.0)


func consume_parry_widen() -> void:
	parry_widen = 1.0


func first_ally_alive() -> Unit:
	for u in allies:
		if u.alive():
			return u
	return null


func resolve_strike(e: Unit, target: Unit, grade: String) -> Dictionary:
	var dmg: int = e.intent["damage"]
	var factor := (0.5 if target.guarding else 1.0) * mod("damage_taken_mult", 1.0)
	var out := {"grade": grade, "damage": 0, "stagger_break": false, "counter": false, "energy": 0, "healed": 0, "dodged": false}
	if bool(e.intent.get("dodge", false)):
		# Cannot be parried: a hit in the zone gets out of the way, a miss takes all of it, guard or not.
		if grade == "miss":
			out["damage"] = int(round(dmg * mod("damage_taken_mult", 1.0)))
		else:
			out["dodged"] = true
		var dealt0 := int(out["damage"])
		if target.shield > 0 and dealt0 > 0:
			var absorbed0 := mini(target.shield, dealt0)
			target.shield -= absorbed0
			dealt0 -= absorbed0
			out["damage"] = dealt0
		target.hp = maxi(0, target.hp - dealt0)
		return out
	match grade:
		"perfect":
			out["counter"] = true
			e.stagger += 1
			if e.stagger >= STAGGER_TO_BREAK:
				e.stagger = 0
				e.stunned = true
				out["stagger_break"] = true
			# Perfect parries earn watch energy (and a little health with the right amulet).
			var gain := 1 + int(mod("energy_per_perfect"))
			var before := energy
			energy = mini(MAX_ENERGY, energy + gain)
			out["energy"] = energy - before
			var heal := int(mod("heal_on_perfect"))
			if heal > 0:
				var hp_before := target.hp
				target.hp = mini(target.max_hp, target.hp + heal)
				out["healed"] = target.hp - hp_before
		"good":
			out["damage"] = int(round(dmg * 0.4 * factor))
		_:
			out["damage"] = int(round(dmg * factor))
	if counter_open_next and grade != "miss":
		out["counter"] = true
		counter_open_next = false
	var dealt := int(out["damage"])
	if target.shield > 0 and dealt > 0:
		var absorbed := mini(target.shield, dealt)
		target.shield -= absorbed
		dealt -= absorbed
		out["damage"] = dealt
	target.hp = maxi(0, target.hp - dealt)
	return out


func counter_hit(e: Unit, strong: bool) -> int:
	var dmg := (24 if strong else 8) + (int(mod("counter_bonus")) if strong else 0)
	e.hp = maxi(0, e.hp - dmg)
	return dmg


## Intent summary for the enemy card: what it will do, and what Guard saves.
func intent_text(e: Unit) -> String:
	if e.stalled:
		return "STALLED"
	var rings: int = e.intent["rings"]
	var dmg: int = e.intent["damage"]
	var name_text := String(e.intent["name"]).to_upper()
	if bool(e.intent.get("dodge", false)):
		name_text += " (DODGE)"
	if rings > 1:
		return "%s  %d x %d" % [name_text, rings, dmg]
	return "%s  %d" % [name_text, dmg]


func intent_guarded_text(e: Unit) -> String:
	if e.stalled:
		return "Time holds its breath"
	if bool(e.intent.get("dodge", false)):
		return "GUARD DOES NOT HELP: DODGE IT"
	var rings: int = e.intent["rings"]
	var dmg := int(round(float(e.intent["damage"]) * 0.5))
	if rings > 1:
		return "GUARD: %d x %d" % [rings, dmg]
	return "GUARD: %d" % dmg


# --- End of battle ------------------------------------------------------------------------------

func is_victory() -> bool:
	for e in enemies:
		if e.alive():
			return false
	return true


func is_defeat() -> bool:
	for a in allies:
		if a.alive():
			return false
	return true


func _snapshot() -> Dictionary:
	var s := {}
	for u in allies + enemies:
		s[u.id] = {"hp": u.hp, "stagger": u.stagger, "stunned": u.stunned, "wired": u.wired}
	return s


## A fatal miss: the watch turns back to the start of the round. Everyone returns to where they were.
func rewind_round() -> void:
	for u in allies + enemies:
		var s: Dictionary = _round_snapshot.get(u.id, {})
		u.hp = int(s.get("hp", u.max_hp))
		if u.is_ally:
			# The watch turns back to a better moment: never to a round Teo could only lose again.
			u.hp = maxi(u.hp, int(ceil(float(u.max_hp) * 0.6)))
		u.stagger = int(s.get("stagger", 0))
		u.stunned = bool(s.get("stunned", false))
		u.wired = int(s.get("wired", 0))
		u.guarding = false
		u.shield = 0
		u.stalled = false
	queue = _living_by_speed()
	for e in enemies:
		if e.alive() and e.intent.is_empty():
			plan_intent(e)
