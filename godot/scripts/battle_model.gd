class_name BattleModel
extends RefCounted
## Pure turn-based battle rules: no UI, no timers. The Combat screen drives it and the headless tests fuzz it.
##
## Rounds: every living unit acts once per round, fastest first. Enemies show an intent for their next
## turn (Slay the Spire style) so Guard versus Attack is a real choice. On an enemy turn the player parries
## with a timed ring: perfect = no damage, a stagger and a counter window; good = most of it blocked;
## miss = full damage. Three perfect parries break the guard (the next hit lands double).

const STAGGER_TO_BREAK := 3
const WATCH_AWAKENS_AT := 0.55
const TEA_HEAL := 30

const ATTACKS := {
	"claw": {"name": "Claw", "text": "The Aswang rakes the air, claws low.", "rings": 1, "seconds": 1.5, "damage": 18},
	"lunge": {"name": "Lunge", "text": "The Aswang coils, every rib showing... and LUNGES.", "rings": 1, "seconds": 1.0, "damage": 28},
	"flurry": {"name": "Flurry", "text": "It whirls into a blur of claws. Three strikes, one breath.", "rings": 3, "seconds": 0.9, "damage": 9},
}


class Unit:
	var id: String
	var display_name: String
	var is_ally: bool
	var hp: int
	var max_hp: int
	var speed: int
	var guarding: bool = false
	var stagger: int = 0
	var stunned: bool = false
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
var skill_unlocked: bool = false
var rewinds_left: int = 0
var enemy_turns: int = 0

var _round_snapshot: Dictionary = {}
var _enemy_turn_snapshot: Dictionary = {}


func start() -> void:
	round_no = 0
	_new_round()
	for e in enemies:
		plan_intent(e)


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


# --- Player options -----------------------------------------------------------------------------

## What the player can do right now. Attack and Guard are always available, so a turn can never soft-lock.
func usable(_actor: Unit) -> Array[String]:
	var out: Array[String] = ["attack", "guard"]
	if teas > 0:
		out.append("item")
	if skill_unlocked and rewinds_left > 0:
		out.append("skill")
	return out


func attack(target: Unit) -> int:
	var dmg := rng.randi_range(18, 24)
	if target.stunned:
		dmg *= 2
		target.stunned = false
	target.hp = maxi(0, target.hp - dmg)
	return dmg


func guard(actor: Unit) -> void:
	actor.guarding = true


func use_tea(actor: Unit) -> int:
	if teas <= 0:
		return 0
	teas -= 1
	var before := actor.hp
	actor.hp = mini(actor.max_hp, actor.hp + TEA_HEAL)
	return actor.hp - before


## The watch's first skill: undo the last enemy turn's damage. Returns the HP restored.
func rewind(actor: Unit) -> int:
	if not skill_unlocked or rewinds_left <= 0:
		return 0
	rewinds_left -= 1
	var saved: int = _enemy_turn_snapshot.get(actor.id, actor.hp)
	var restored := maxi(0, saved - actor.hp)
	actor.hp = maxi(actor.hp, saved)
	return restored


## True the moment the watch awakens (Episode 1's tutorial unlock: Skill, with one rewind).
func check_awakening() -> bool:
	if skill_unlocked or enemies.is_empty():
		return false
	var e := enemies[0]
	if float(e.hp) / float(e.max_hp) <= WATCH_AWAKENS_AT and e.alive():
		skill_unlocked = true
		rewinds_left = 1
		return true
	return false


# --- Enemy turns --------------------------------------------------------------------------------

func plan_intent(e: Unit) -> void:
	var key := "claw"
	if enemy_turns >= 2:
		var pool := ["claw", "lunge", "flurry"]
		key = pool[rng.randi_range(0, pool.size() - 1)]
	var attack_def: Dictionary = ATTACKS[key].duplicate()
	attack_def["key"] = key
	e.intent = attack_def


func begin_enemy_turn(_e: Unit) -> void:
	enemy_turns += 1
	_enemy_turn_snapshot = {}
	for u in allies:
		_enemy_turn_snapshot[u.id] = u.hp


## How forgiving the parry ring is: the first is a lesson, the second is assisted, then it is on your own.
func ring_level() -> String:
	if enemy_turns <= 1:
		return "guided"
	if enemy_turns == 2:
		return "assisted"
	return "free"


func ring_seconds(e: Unit) -> float:
	match ring_level():
		"guided":
			return 2.8
		"assisted":
			return 1.8
	return float(e.intent["seconds"])


func first_ally_alive() -> Unit:
	for u in allies:
		if u.alive():
			return u
	return null


func resolve_strike(e: Unit, target: Unit, grade: String) -> Dictionary:
	var dmg: int = e.intent["damage"]
	var factor := 0.5 if target.guarding else 1.0
	var out := {"grade": grade, "damage": 0, "stagger_break": false, "counter": false}
	match grade:
		"perfect":
			out["counter"] = true
			e.stagger += 1
			if e.stagger >= STAGGER_TO_BREAK:
				e.stagger = 0
				e.stunned = true
				out["stagger_break"] = true
		"good":
			out["damage"] = int(round(dmg * 0.4 * factor))
		_:
			out["damage"] = int(round(dmg * factor))
	target.hp = maxi(0, target.hp - int(out["damage"]))
	return out


func counter_hit(e: Unit, strong: bool) -> int:
	var dmg := 24 if strong else 8
	e.hp = maxi(0, e.hp - dmg)
	return dmg


## Intent summary for the enemy card: what it will do, and what Guard saves.
func intent_text(e: Unit) -> String:
	var rings: int = e.intent["rings"]
	var dmg: int = e.intent["damage"]
	var name_text := String(e.intent["name"]).to_upper()
	if rings > 1:
		return "%s  %d x %d" % [name_text, rings, dmg]
	return "%s  %d" % [name_text, dmg]


func intent_guarded_text(e: Unit) -> String:
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
		s[u.id] = {"hp": u.hp, "stagger": u.stagger, "stunned": u.stunned}
	return s


## A fatal miss: the watch turns back to the start of the round. Everyone returns to where they were.
func rewind_round() -> void:
	for u in allies + enemies:
		var s: Dictionary = _round_snapshot.get(u.id, {})
		u.hp = int(s.get("hp", u.max_hp))
		if u.is_ally:
			# The watch turns back to a better moment: never to a round Renzo could only lose again.
			u.hp = maxi(u.hp, int(ceil(float(u.max_hp) * 0.6)))
		u.stagger = int(s.get("stagger", 0))
		u.stunned = bool(s.get("stunned", false))
		u.guarding = false
	queue = _living_by_speed()
	for e in enemies:
		if e.alive() and e.intent.is_empty():
			plan_intent(e)
