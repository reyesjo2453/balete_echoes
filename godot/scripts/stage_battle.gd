class_name StageBattle
extends Control
## A retro side-view battle fought on the walkable map itself (HD-2D), in the manner of the 16-bit JRPGs: the enemy on
## the left, the party (one to three) on the right, blue windows along the bottom, and time bars (ATB) that fill in
## real time. Time stops while a menu is open (the "wait" setting), so nobody is rushed into a choice.
##
## The party (MEMBERS):
##   Teo     BALISONG, HATID (prayers), SALABAT, GUARD, and WATCH (Rewind) once the watch has woken.
##   Lolo Pido (1998)  SUNDANG, HATID, SALABAT, GUARD.
##   Kardo   WRENCH, WIRE (clamp a wire on it, up to three), KONTRA (light every wire at once: hold, let go in the green;
##           the red overcharges, and shocks him), COFFEE, COVER.
##   Lola Ising (guest)  ABANIKO, ORASYON (tap on the beat: heals, breaks spells, hurts spirits), HILOT, ROSARY.
## WATCH: REWIND, Teo's once it wakes, Lolo Pido's in 1998: tap to wind the crown back and undo the enemy's last turn.
## HATID II (TAWID): a seven-arrow prayer that sends a spirit home from higher up; Pido knows it, Teo earns it by Loob.
## HATID: pick a prayer, then enter its arrows before the bar runs out (keys, d-pad or the on-screen arrows). Prayers hurt
## spirits badly; a wrong arrow fizzles it; entered with half the time left it is SWIFT (+35%). UWI KA NA, prayed while a
## spirit is below its send-home line, sends it home instead of scattering it.
## Low on HP, the blade can turn into a desperation move (three cuts).
##
## Enemies (data/stage_enemies.json): ordinary attacks, parried on the timing ring (or only dodged: water, nets), with one
## to three rings; and a signature move with a tell one enemy turn ahead, which some commands interrupt (a prayer for
## spirits, a discharge for machines, any heavy hit for beasts). Fights can be survived instead of won (survive_turns),
## can wake the watch (awakens), and can carry the lead's wounds into the next wave (carry_wounds).
##
## Tests set `fast`: the fight then plays itself at speed (sensible picks, rings and prayers entered correctly).

signal finished(won: bool)

const PX := 1.75 / 64.0 # metres per sprite pixel: one pixel grid for everyone on the stage
const ATB_RATE := 0.034 # time bar filled per second per point of speed
const DESPERATE := 0.3
const SWIFT := 0.5 # a prayer entered with at least this share of its time left is SWIFT (x1.35)
const MAX_WIRES := 3
const WATCH_MAX := 3 # REWINDs the watch can hold (one to start; a perfect parry winds one more)
const STAGGER_MULT := 1.5 # damage multiplier while the enemy is STAGGERED
const CANDLES := {"teo": 4, "pido": 5} # prayers burn candles: one each, TAWID two. Lit fresh every fight.
const HEAT_STEP := 0.1 # each KONTRA heats the line: the green and red start this much lower (cools a step a turn)
## Summons (TAWAG): a sundô who went before answers, once a fight. Lola calls on her own; Teo, from Episode 2, speaks
## a name Sol reads off the watch's heartwood, and that costs utang na loob (Story.gratitude).
const ANCESTORS := [
	{"id": "pido", "name": "PIDO DIMACULANGAN", "short": "LOLO PIDO", "art": "pidob", "model": "summon_pido", "move": "SUNDANG NG ORAS",
		"power": 38, "heal": 28, "lola": "Pido. The boy needs you. One more minute, mahal.",
		"teo": "Pido Dimaculangan. Your fare is paid. Stay one more minute."},
]
const PRAYERS := [
	{"id": "paalam", "name": "PAALAM", "gloss": "Farewell", "keys": ["left", "right", "up"], "seconds": 3.6, "power": 24},
	{"id": "uwi", "name": "UWI KA NA", "gloss": "Go home", "keys": ["up", "down", "left", "right", "up"], "seconds": 4.6, "power": 34},
	# HATID II: the long prayer. Lolo Pido knows it; Teo earns it with Loob (HATID2_LOOB). It sends home from higher up.
	{"id": "tawid", "name": "TAWID", "gloss": "Cross over", "keys": ["up", "up", "left", "right", "down", "left", "up"], "seconds": 5.6, "power": 46, "tier": 2},
]
const HATID2_LOOB := 2
const TAWID_REACH := 0.15 # TAWID sends a spirit home this much above the gold line
const MEMBERS := {
	"teo": {"name": "TEO", "hp": 110, "speed": 10, "art": "teob", "cmds": ["attack", "hatid", "item", "guard"],
		"attack": "BALISONG", "desperation": "BALISONG IKOT", "item": "SALABAT", "item_text": "Lola's salabat, still warm.",
		"guard": "GUARD", "hit": [10, 14], "heal": 38},
	"pido": {"name": "LOLO PIDO", "hp": 130, "speed": 9, "art": "pidob", "cmds": ["attack", "hatid", "item", "guard"],
		"attack": "SUNDANG", "desperation": "SUNDANG IKOT", "item": "SALABAT", "item_text": "Ising's salabat, from the thermos on the stairs.",
		"guard": "GUARD", "hit": [13, 17], "heal": 40},
	"kardo": {"name": "KARDO", "hp": 125, "speed": 7, "art": "kardob", "cmds": ["attack", "wire", "discharge", "item", "guard"],
		"attack": "WRENCH", "desperation": "", "item": "COFFEE", "item_text": "3-in-1 coffee, mostly sugar.",
		"guard": "COVER", "hit": [9, 12], "heal": 34},
	"ising": {"name": "LOLA ISING", "hp": 90, "speed": 8, "art": "lolab", "cmds": ["attack", "orasyon", "tawag", "item", "guard"],
		"attack": "ABANIKO", "desperation": "", "item": "HILOT", "item_text": "Lola's hilot. It hurts in the good way.",
		"guard": "ROSARY", "hit": [7, 10], "heal": 30},
}
const LESSON := "Watch the big ring close on the white circle. When it glows, press SPACE (A button) or TAP to PARRY."
const DODGE_LESSON := "You cannot parry this one. Press SPACE (A) or TAP when the ring glows to DODGE."

static var _defs: Dictionary = {}
static var _scales: Dictionary = {}

## One fighter on the party side.
class Unit:
	var id := ""
	var d: Dictionary = {}
	var hp := 100
	var max_hp := 100
	var atb := 0.0
	var items := 2
	var guarding := false
	var spellbound := false
	var tired := false # Lola after an ORASYON: she sits down for a turn
	var haste := 1.0 # the time bar fills this much faster (Teo, once the watch wakes in a fight: borrowed time)
	var moving := false # a lunge or knockback owns the sprite's scale: no breathing
	var mods: Dictionary = {}
	var node: Sprite3D
	var home := Vector2.ZERO
	var hp_label: Label
	var atb_bar: ProgressBar
	var status: Label
	var name_label: Label

	func alive() -> bool:
		return hp > 0

	func art(pose: String) -> String:
		return "%s_%s" % [String(d.get("art", "teob")), pose]


var fast := false
## Plays itself at normal speed (review recordings: BALETE_DEMO=1 / ?demo=1 with ?fight=).
var demo := false
var enemy_id := "magbabalot"
var map_id := ""
var def: Dictionary = {}
var party_ids: Array = ["teo"]
var carry_wounds := false

var party: Array = [] # [Unit]
var foe_hp := 1
var foe_max := 1
var foe_atb := 0.0
var foe_floor := 0 # the enemy cannot drop below this (a tide; the watch must wake first)
var charging := false
var foe_turns := 0
var wired := 0
var awakened := false
var watch_charge := 0 # REWINDs ready (see _offer_rewind)
var episode := 1 # levels and perks earned before this episode apply (scripts/levels.gd)
var candles := 0
var heat := 0
var heat_peak := 0
var summoned := false
var summons := 0
var tired_turns := 0
var _pending_loss := false
var _pending_scripted_awaken := false
## Tests: the next this-many rings are missed even in fast mode (to reach REWIND), and whether REWIND is taken.
var test_miss := 0
var auto_react := true
var overcharges := 0
var trips := 0
var orasyons := 0
var rewinds := 0
var last_kontra: Dictionary = {}
var last_orasyon: Dictionary = {}
var last_wind: Dictionary = {}
## Tests: where the autoplay lets go of KONTRA (0..1; >= SpecialGauge.OVER overcharges), and how many beads it hits.
var auto_charge := 0.75
var auto_rhythm := 1.0
var _gauge: SpecialGauge
var outcome := "" # "sent" | "scattered" | "outlasted" | "fled" | "fell"
var interrupts := 0
var swift_prayers := 0
var cut_ins := 0 # how many special-move cut-ins played (tests)
var dual_cut_ins := 0 # how many dual-portrait team-combo cut-ins played (tests)
var _last_hits: Dictionary = {} # unit id -> damage taken in the enemy's last turn (what Rewind gives back)
var _acting := false
var _over := false
var _menu_open := false
var _waking := false # the watch-awakening / phase-shift sequence holds time still
var _checking_gates := false
var _phase := 1
var _phase2 := false
var _phase3 := false
var _foe_dmg_mult := 1.0
var _foe_floats := false
var _foe_glow := "9fc4ff"
var stagger := 0
var stagger_max := 0
var staggered := false
var staggers := 0
var combos_used := 0
var wire_jolts := 0
var _amulet: Dictionary = {}
var _actor: Unit = null

var _map: ExploreMap
var _foe: Sprite3D
var _foe_shadow: Sprite3D
var _wings: Sprite3D # the aswang's flight strip (<art>_fly.png, docs/ART_REQUESTS.md #4); null until the art exists
var wingbeats := 0 # downstrokes while airborne (tests)
var _wings_out := false # shown: floating, taking off, or fleeing over the roofs
var _flap_t := 0.0
var _last_flap := -1
var _foe_light: OmniLight3D
var _fill_light: OmniLight3D
var _foe_at := Vector2(9.2, 6.7)
var _foe_moving := false
var _charge_fx_t := 0.0
var _perfects_at_start := 0
var tally := "" # the after-fight line: perfect parries, rewinds, what is left
var _t := 0.0
var _ring: TimingRing
var _msg_panel: PanelContainer
var _msg: Label
var _cmd_panel: PanelContainer
var _cmd_title: Label
var _cmd_box: VBoxContainer
var _foe_name: Label
var _foe_bar: ProgressBar
var _stagger_bar: ProgressBar
var _stagger_label: Label
var _stagger_row: HBoxContainer
var _wire_label: Label
var _res_label: Label
var _tip: Label
var _flash: ColorRect
var _seq_panel: PanelContainer
var _seq_row: HBoxContainer
var _seq_bar: ProgressBar
var _seq_title: Label
var _pad: HBoxContainer
var _seq_keys: Array = []
var _seq_at := 0
var _seq_t := 0.0
var _seq_total := 0.0
var _seq_active := false
var _end_box: VBoxContainer
var _end_text: Label
var bystander_reactions := 0
var _bystander_specs: Array = []
var _bystander_cd := 0.0
var _bystander_barks_used := {}
var _bystander_retreated := {}
var last_bystander_anims := {} # bystander id -> the last reaction it played (tests)
const BRAVE_AT := 0.4 # the brave tito finds his voice below this share of the foe's health

signal _command(cmd: String)
signal _seq_done(ok: bool)


static func _sprite_scales() -> Dictionary:
	if _scales.is_empty():
		var f := FileAccess.open("res://data/sprite_scales.json", FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_scales = d
	return _scales


func _px_for(tex_name: String) -> float:
	return PX / maxf(1.0, float(_sprite_scales().get(tex_name, 1.0)))


static func enemy_def(id: String) -> Dictionary:
	if _defs.is_empty():
		var f := FileAccess.open("res://data/stage_enemies.json", FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_defs = d
	return _defs.get(id, {})


## {"enemy": id, "map": map id (default: the enemy's own), "party": [member ids], "carry_wounds": bool}.
func setup(p: Dictionary) -> void:
	enemy_id = String(p.get("enemy", enemy_id))
	def = enemy_def(enemy_id)
	map_id = String(p.get("map", def.get("map", "hidalgo")))
	var ids: Array = p.get("party", def.get("party", ["teo"]))
	party_ids = ids.duplicate() if not ids.is_empty() else ["teo"]
	carry_wounds = bool(p.get("carry_wounds", false))
	episode = int(p.get("episode", episode))
	_amulet = Progress.equipped_mods()
	_perfects_at_start = Story.perfects
	foe_max = int(def.get("hp", 120))
	foe_hp = foe_max
	stagger_max = int(def.get("stagger", 0))
	stagger = 0
	staggered = false
	staggers = 0
	_checking_gates = false
	_pending_scripted_awaken = false
	_phase = 1
	_phase2 = false
	_phase3 = false
	_foe_dmg_mult = 1.0
	_foe_floats = bool(def.get("floats", _spirit()))
	_foe_glow = String(def.get("glow", "9fc4ff"))
	party.clear()
	for id in party_ids:
		var u := Unit.new()
		u.id = String(id)
		u.d = MEMBERS.get(u.id, MEMBERS["teo"]).duplicate(true)
		u.mods = Levels.mods(u.id, episode)
		u.d["speed"] = int(u.d["speed"]) + int(u.mods.get("speed", 0))
		var hit: Array = u.d["hit"]
		u.d["hit"] = [int(hit[0]) + int(u.mods.get("hit", 0)), int(hit[1]) + int(u.mods.get("hit", 0))]
		if u.id == "teo" and Story.flags.get("heartwood_read", false):
			(u.d["cmds"] as Array).insert(2, "tawag") # Episode 2+: Sol reads the names off the heartwood
		u.max_hp = int(u.d["hp"]) + int(u.mods.get("hp", 0))
		if u.id == "teo" and _amulet.has("max_hp_mult"):
			u.max_hp = maxi(40, int(round(u.max_hp * float(_amulet["max_hp_mult"]))))
		u.hp = u.max_hp
		party.append(u)
	if not party.is_empty() and Story.injury > 0:
		var lead: Unit = party[0]
		lead.hp = maxi(20, lead.max_hp - Story.injury) # hurt going in (a failed QTE, or the last wave)
	awakened = Story.flags.get("watch_awake", false)
	watch_charge = 1 if (awakened or _has("pido")) else 0
	candles = _fresh_candles()
	var flee_hp := int(ceil(float(foe_max) * float(def.get("flee_below", 0.0)))) if def.has("flee_below") else 0
	if bool(def.get("scripted_death_awaken", false)) and not awakened and _has("teo"):
		foe_floor = maxi(flee_hp + 1, int(ceil(float(foe_max) * 0.65)))
	elif int(def.get("survive_turns", 0)) > 0 or (bool(def.get("awakens", false)) and not awakened and _has("teo")):
		foe_floor = 1
	else:
		foe_floor = 0


func unit(id: String) -> Unit:
	for u in party:
		if (u as Unit).id == id:
			return u
	return null


func _has(id: String) -> bool:
	return party_ids.has(id)


func _ready() -> void:
	if def.is_empty():
		setup({})
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_stage()
	_build_hud()
	Sfx.cue(String(def.get("music", "battle")))
	_begin()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _begin() -> void:
	_acting = true
	var lead: Unit = party[0]
	if lead.hp < lead.max_hp and Story.injury > 0:
		Story.consequence.emit("Hurt going in: %s starts the fight at %d HP" % [String(lead.d["name"]).capitalize(), lead.hp])
	_say(String(def.get("opening", "")))
	_react_bystanders("opening", true)
	await _wait(1.6)
	_say("")
	_acting = false


# --- the stage ---------------------------------------------------------------------------------------------------

## Where everyone stands, and where the camera looks from, on this map ("battle" in data/maps.json).
func _placement() -> Dictionary:
	var b: Dictionary = ExploreMap.map_def(map_id).get("battle", {})
	if b.is_empty():
		b = {"party": [13.6, 6.7], "foe": [9.2, 6.7], "cam": [[11.4, 3.0, 17.2], [11.4, 1.5, 6.0]]}
	return b


func _build_stage() -> void:
	var b := _placement()
	var pa: Array = b["party"]
	var fa: Array = b["foe"]
	var cam: Array = b["cam"]
	_foe_at = Vector2(float(fa[0]), float(fa[1]))
	var lead_at := Vector2(float(pa[0]), float(pa[1]))
	_map = ExploreMap.new()
	_map.stage_mode = true
	_map.test_fast = fast
	_map.setup({"map": map_id}, {}, 0, lead_at)
	_map.fixed_cam = [Vector3(float(cam[0][0]), float(cam[0][1]), float(cam[0][2])), Vector3(float(cam[1][0]), float(cam[1][1]), float(cam[1][2]))]
	add_child(_map)
	_map.hide_teo()
	# The lead in front, the others behind and in front of him, a step further back from the enemy.
	var slots := [Vector2.ZERO, Vector2(1.7, -0.75), Vector2(1.8, 0.85)]
	for i in party.size():
		var u: Unit = party[i]
		u.home = lead_at + slots[mini(i, 2)]
		u.node = _make_sprite(u.art("ready"), false)
		u.node.position = Vector3(u.home.x, 0, u.home.y)
		_map.add_node(u.node)
		_map.blob(u.home, 0.9)
	_foe = _make_sprite(_art("idle"), _spirit())
	_foe.position = Vector3(_foe_at.x, _hover_y(), _foe_at.y)
	_map.add_node(_foe)
	_build_wings()
	_foe_shadow = _map.blob(_foe_at, 1.4)
	# A soft fill on the party, so they read on the darkest maps (the creek at night).
	var fill := OmniLight3D.new()
	fill.light_color = Color(String(b.get("fill", "ffe2b8")))
	fill.light_energy = float(b.get("fill_energy", 0.9))
	fill.omni_range = 4.5
	fill.position = Vector3(lead_at.x + 0.8, 2.2, lead_at.y + 1.6)
	_map.add_node(fill)
	_fill_light = fill
	_foe_light = OmniLight3D.new()
	_foe_light.light_color = Color(_foe_glow)
	_foe_light.light_energy = 1.2
	_foe_light.omni_range = 4.0
	_foe_light.position = Vector3(_foe_at.x, 1.4, _foe_at.y + 0.8)
	_map.add_node(_foe_light)
	_init_bystanders()


func _spirit() -> bool:
	return bool(def.get("spirit", false))


func _floats() -> bool:
	return _foe_floats


func _hover_y() -> float:
	if not _floats():
		return 0.0
	return 0.14 if _spirit() else 0.42


func _art(pose: String) -> String:
	return "%s_%s" % [String(def.get("art", "mag")), pose]


func _make_sprite(tex_name: String, ghost: bool) -> Sprite3D:
	var s := Sprite3D.new()
	var tex := _tex(tex_name)
	s.texture = tex
	s.pixel_size = _px_for(tex_name)
	s.material_override = _map._sprite_material(tex, ghost)
	if tex != null:
		s.offset = Vector2(0, tex.get_height() * 0.5)
	return s


func _tex(n: String) -> Texture2D:
	var p := "res://assets/explore/%s.png" % n
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


func _pose(s: Sprite3D, tex_name: String) -> void:
	var resolved := tex_name
	var tex := _tex(resolved)
	if tex == null:
		resolved = tex_name + "_1"
		tex = _tex(resolved)
	if tex == null or s == null:
		return
	if s.texture == tex:
		return
	s.texture = tex
	s.pixel_size = _px_for(resolved)
	s.offset = Vector2(0, tex.get_height() * 0.5)
	(s.material_override as ShaderMaterial).set_shader_parameter("tex", tex)


## Plays numbered frames (<base>_1, <base>_2, ...) if present on disk, or holds <base> cleanly.
func _pose_frames(s: Sprite3D, base_name: String, fps: float = 10.0) -> void:
	var frames: Array = []
	for i in range(1, 9):
		var frame_name := "%s_%d" % [base_name, i]
		var t := _tex(frame_name)
		if t == null:
			break
		frames.append({"name": frame_name, "tex": t})
	if frames.is_empty():
		_pose(s, base_name)
		return
	var step := 0.02 if fast else (1.0 / maxf(1.0, fps))
	for item in frames:
		if s == null or not is_instance_valid(s) or _over:
			return
		var t: Texture2D = item["tex"]
		s.texture = t
		s.pixel_size = _px_for(String(item["name"]))
		s.offset = Vector2(0, t.get_height() * 0.5)
		(s.material_override as ShaderMaterial).set_shader_parameter("tex", t)
		await _wait(step)


func _process(delta: float) -> void:
	_t += delta
	if _bystander_cd > 0.0:
		_bystander_cd = maxf(0.0, _bystander_cd - delta)
	if _foe != null and not _over:
		var idle := _foe.texture == _tex(_art("idle")) or _foe.texture == _tex(_art("idle_b"))
		if idle and not _foe_moving:
			var idle_hz := 2.4 if (_floats() and not _spirit()) else 1.6
			_pose(_foe, _art("idle" if int(_t * idle_hz) % 2 == 0 else "idle_b"))
		if not _foe_moving:
			if _floats():
				var bob_rate := 1.5 if _spirit() else 2.3
				var bob_amp := 0.07 if _spirit() else 0.11
				_foe.position.y = _hover_y() + sin(_t * bob_rate) * bob_amp
			else:
				_foe.position.y = 0.0
		if _foe_shadow != null:
			var h_fac := clampf(1.0 - maxf(0.0, _foe.position.y) * 0.45, 0.35, 1.0)
			_foe_shadow.position = Vector3(_foe.position.x, 0.012, _foe.position.z)
			_foe_shadow.scale = Vector3(h_fac, 0.45 * h_fac, 1.0)
		_foe_light.position = Vector3(_foe.position.x, _foe.position.y + 1.4, _foe.position.z + 0.8)
		_foe_light.light_color = Color("ff4050") if charging else Color(_foe_glow)
		_foe_light.light_energy = (1.7 + sin(_t * 8.0) * 0.45) if charging else (1.45 + float(_phase - 1) * 0.2)
		if charging and not fast and not _waking:
			_charge_fx_t -= delta
			if _charge_fx_t <= 0.0:
				_charge_fx_t = 0.85
				FxBurst.play(self, "lightning" if _phase >= 3 else "spark", _foe_head() + Vector2(randf_range(-18, 18), randf_range(26, 62)), Color("e866ff") if _phase >= 3 else Color("ff7a5a"), 0.72)
	_tick_wings(delta)
	_breathe()
	if _seq_active:
		_seq_t -= delta
		_seq_bar.value = maxf(0.0, _seq_t / _seq_total) * 100.0
		if _seq_t <= 0.0:
			_end_sequence(false)
	if _acting or _over or _menu_open or _waking:
		return
	var speed := 20.0 if fast else 1.0
	var ready: Unit = null
	for u in party:
		var m: Unit = u
		if not m.alive():
			continue
		m.atb = minf(1.0, m.atb + delta * float(m.d["speed"]) * m.haste * ATB_RATE * speed)
		m.atb_bar.value = m.atb * 100.0
		if m.atb >= 1.0 and ready == null:
			ready = m
	foe_atb = minf(1.0, foe_atb + delta * _foe_speed() * ATB_RATE * speed)
	if staggered and _stagger_bar != null:
		_stagger_bar.value = float(stagger_max) * (1.0 - foe_atb)
	if ready != null:
		_acting = true
		_member_turn(ready)
	elif foe_atb >= 1.0:
		_acting = true
		_foe_turn()


# --- the party's turns -----------------------------------------------------------------------------------------------

func _member_turn(u: Unit) -> void:
	_actor = u
	u.guarding = false
	if u.spellbound:
		u.spellbound = false
		u.status.text = ""
		_say("%s is still answering the call. He can't move!" % String(u.d["name"]).capitalize())
		await _wait(1.1)
		_end_turn(u)
		return
	if u.tired:
		u.tired = false
		u.status.text = ""
		tired_turns += 1
		_pose(u.node, u.art("down"))
		_say("Lola sits down on a folding chair. \"Wait lang, apo. My knees.\"")
		await _wait(1.1)
		_end_turn(u)
		return
	if u.id == "kardo" and heat > 0:
		heat -= 1 # the line cools while he does something else
	if u.id == "teo" and Story.age_stage() >= 1 and not fast:
		Sfx.watch_tick()
	u.name_label.add_theme_color_override("font_color", Retro.NAME)
	_map.battle_cam_shot(u.home - Vector2(0.45, 0.0), Vector3(0.45, -0.22, -0.65), 27.6, 0.42, 5.5, 0.0)
	var cmd := await _choose(u)
	_map.battle_cam_reset()
	u.name_label.add_theme_color_override("font_color", Retro.TEXT)
	match cmd:
		"attack":
			await _attack(u)
		"item":
			u.items -= 1
			var heal := mini(int(u.d["heal"]), u.max_hp - u.hp)
			u.hp += heal
			Sfx.play("heal-chime")
			_say("%s %s recovers %d." % [String(u.d["item_text"]), String(u.d["name"]).capitalize(), heal])
			_number("+%d" % heal, _head(u), Color("7dff9a"))
			await _wait(0.8)
		"guard":
			u.guarding = true
			_pose(u.node, u.art("guard"))
			_say("%s braces." % String(u.d["name"]).capitalize())
			await _wait(0.6)
		"wire":
			await _wire(u)
		"discharge":
			await _discharge(u)
		"tawag":
			await _summon(u)
		"orasyon":
			await _orasyon(u)
		"combo_kuryente":
			await _combo_kuryente(u)
		"combo_dalawa":
			await _combo_dalawa(u)
		_:
			if cmd.begins_with("pray_"):
				await _pray(u, cmd.trim_prefix("pray_"))
	if not _over:
		_end_turn(u)


func _end_turn(u: Unit) -> void:
	u.atb = 0.0
	u.atb_bar.value = 0.0
	if not u.guarding and u.alive():
		_pose(u.node, u.art("ready"))
	_map.battle_cam_reset()
	_refresh()
	_acting = false


## Opens the command window and waits for a pick (or picks for the test autoplay).
func _choose(u: Unit) -> String:
	if demo:
		_show_menu(u, "main")
		await _wait(0.8)
		_cmd_panel.visible = false
	if fast or demo:
		await get_tree().process_frame
		return _auto_pick(u)
	_show_menu(u, "main")
	_menu_open = true
	var cmd: String = await _command
	_menu_open = false
	_cmd_panel.visible = false
	return cmd


func _auto_pick(u: Unit) -> String:
	var cmds: Array = u.d["cmds"]
	var interrupt: Array = _active_special().get("interrupt", ["prayer"])
	if cmds.has("orasyon"):
		var hurt := false
		for v in party:
			hurt = hurt or ((v as Unit).alive() and (float((v as Unit).hp) / (v as Unit).max_hp < 0.7 or (v as Unit).spellbound))
		if orasyons == 0:
			return "orasyon"
		if _usable(u, "tawag") and (charging or float(foe_hp) / foe_max < 0.6):
			return "tawag"
		return "orasyon" if hurt or charging or (_spirit() and foe_turns % 2 == 1) else "attack"
	if _usable(u, "combo_kuryente") and (charging or float(foe_hp) / foe_max < 0.65):
		return "combo_kuryente"
	if _usable(u, "combo_dalawa") and (charging or float(foe_hp) / foe_max < 0.65):
		return "combo_dalawa"
	if charging and cmds.has("hatid") and interrupt.has("prayer") and _can_pray("paalam"):
		return "pray_paalam"
	if charging and cmds.has("discharge") and interrupt.has("discharge") and wired > 0:
		return "discharge"
	if _usable(u, "tawag") and (charging or float(foe_hp) / foe_max < 0.6):
		return "tawag"
	var sh: Dictionary = def.get("send_home", {})
	if cmds.has("hatid") and not sh.is_empty() and float(foe_hp) / foe_max <= float(sh.get("below", 0.0)) and _can_pray(String(sh.get("prayer", "uwi"))):
		return "pray_" + String(sh.get("prayer", "uwi"))
	if cmds.has("hatid") and not sh.is_empty() and hatid2(u) and _can_pray("tawid") and float(foe_hp) / foe_max <= float(sh.get("below", 0.0)) + TAWID_REACH:
		return "pray_tawid"
	if float(u.hp) / u.max_hp < 0.35 and u.items > 0:
		return "item"
	if cmds.has("wire"):
		return "wire" if wired < mini(2, _max_wires()) else "discharge"
	if cmds.has("hatid") and _spirit() and foe_turns % 2 == 1 and candles > 2:
		return "pray_paalam"
	return "attack"


func _partner_ready(id: String) -> bool:
	var p := unit(id)
	return p != null and p.alive() and not p.spellbound


func _usable(u: Unit, cmd: String) -> bool:
	match cmd:
		"item":
			return u.items > 0
		"hatid":
			return candles > 0
		"combo":
			return Story.gratitude > 0 and (_partner_ready("kardo") or _partner_ready("ising"))
		"combo_kuryente":
			return u.id == "teo" and Story.gratitude > 0 and _partner_ready("kardo")
		"combo_dalawa":
			return u.id == "teo" and Story.gratitude > 0 and _partner_ready("ising")
		"tawag":
			return not summoned and (u.id == "ising" or Story.gratitude > 0)
		"discharge":
			return wired > 0
		"wire":
			return wired < _max_wires()
	return true


func _show_menu(u: Unit, mode: String) -> void:
	for c in _cmd_box.get_children():
		c.queue_free()
	_cmd_panel.visible = true
	_cmd_title.text = String(u.d["name"])
	var first: Button = null
	if mode == "main":
		for cmd in u.d["cmds"]:
			var c := String(cmd)
			var b: Button = null
			match c:
				"attack":
					b = _cmd_button(u, "attack", String(u.d["attack"]))
				"hatid":
					b = _cmd_button(u, "hatid", "HATID  >   candles %d" % candles if candles > 0 else "HATID   no candles left", _usable(u, "hatid"))
				"tawag":
					b = _cmd_button(u, "tawag", "TAWAG  (call the sundô)" if not summoned else "TAWAG  (answered)", _usable(u, "tawag"))
				"orasyon":
					b = _cmd_button(u, "orasyon", "ORASYON")
				"item":
					b = _cmd_button(u, "item", "%s  x%d" % [u.d["item"], u.items], _usable(u, "item"))
				"guard":
					b = _cmd_button(u, "guard", String(u.d["guard"]))
				"wire":
					b = _cmd_button(u, "wire", "WIRE  (%d/%d)" % [wired, _max_wires()], _usable(u, "wire"))
				"discharge":
					b = _cmd_button(u, "discharge", "KONTRA" + ("   line hot x%d" % heat if heat > 0 else ""), _usable(u, "discharge"))
			if b != null and first == null:
				first = b
		if u.id == "teo" and (_partner_ready("kardo") or _partner_ready("ising")):
			var cb := _cmd_button(u, "combo", "TEAM COMBO  >   utang na loob %d" % Story.gratitude if Story.gratitude > 0 else "TEAM COMBO  (needs utang na loob)", _usable(u, "combo"))
			if first == null:
				first = cb
	elif mode == "combo":
		if _partner_ready("kardo"):
			var b := _cmd_button(u, "combo_kuryente", "HATID SA KURYENTE  (Teo+Kardo)  1 utang na loob", _usable(u, "combo_kuryente"))
			if first == null:
				first = b
		if _partner_ready("ising"):
			var b := _cmd_button(u, "combo_dalawa", "DASAL NG DALAWA  (Teo+Lola)  1 utang na loob", _usable(u, "combo_dalawa"))
			if first == null:
				first = b
		_cmd_button(u, "back", "<  BACK")
	else:
		for p in PRAYERS:
			var b: Button
			if int(p.get("tier", 1)) == 2 and not hatid2(u):
				b = _cmd_button(u, "pray_" + String(p["id"]), "HATID II  (needs Loob %d)" % HATID2_LOOB, false)
			else:
				var cost := _candle_cost(String(p["id"]))
				b = _cmd_button(u, "pray_" + String(p["id"]), "%s  (%s)  %s" % [p["name"], p["gloss"], "|".repeat(cost)], _can_pray(String(p["id"])))
			if first == null:
				first = b
		_cmd_button(u, "back", "<  BACK")
	if first != null:
		first.grab_focus()


## HATID II (TAWID): Lolo Pido has always known it; Teo finds it once his Loob is high enough.
func hatid2(u: Unit) -> bool:
	return u.id == "pido" or Story.loob >= HATID2_LOOB


## Candles for this fight: the most any praying member brings (Lolo Pido five, Teo four, more with KANDILA).
func _fresh_candles() -> int:
	var n := 0
	for v in party:
		var m: Unit = v
		if CANDLES.has(m.id):
			n = maxi(n, int(CANDLES[m.id]) + int(m.mods.get("candles", 0)))
	return n


func _candle_cost(id: String) -> int:
	for q in PRAYERS:
		if String(q["id"]) == id:
			return 2 if int(q.get("tier", 1)) == 2 else 1
	return 1


func _can_pray(id: String) -> bool:
	return candles >= _candle_cost(id)


func _max_wires() -> int:
	var k := unit("kardo")
	return MAX_WIRES + (int(k.mods.get("wires", 0)) if k != null else 0)


func _cmd_button(u: Unit, id: String, text: String, enabled: bool = true) -> Button:
	var b := Button.new()
	b.name = "Cmd_" + id
	b.text = text
	b.disabled = not enabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(300, 44)
	b.add_theme_font_override("font", Fonts.label())
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color("f2efe4"))
	b.add_theme_color_override("font_focus_color", Color("ffe08a"))
	b.add_theme_color_override("font_hover_color", Color("ffe08a"))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	var clear := StyleBoxFlat.new()
	clear.bg_color = Color(0, 0, 0, 0)
	clear.content_margin_left = 30
	var hi := clear.duplicate() as StyleBoxFlat
	hi.bg_color = Color(1, 1, 1, 0.12)
	hi.set_corner_radius_all(4)
	for st in ["normal", "disabled", "pressed"]:
		b.add_theme_stylebox_override(st, clear)
	b.add_theme_stylebox_override("hover", hi)
	b.add_theme_stylebox_override("focus", hi)
	b.focus_entered.connect(func() -> void:
		if b.is_visible_in_tree() and not b.disabled and not fast:
			Sfx.ui_move())
	b.mouse_entered.connect(func() -> void:
		if b.is_visible_in_tree() and not b.disabled and not fast and not b.has_focus():
			Sfx.ui_move())
	b.pressed.connect(func() -> void:
		Sfx.play("command-enter")
		if id == "hatid":
			_show_menu(u, "hatid")
		elif id == "combo":
			_show_menu(u, "combo")
		elif id == "back":
			_show_menu(u, "main")
		else:
			_command.emit(id))
	_cmd_box.add_child(b)
	return b


func _attack(u: Unit) -> void:
	var desp := String(u.d.get("desperation", ""))
	var desperate := desp != "" and float(u.hp) / u.max_hp < DESPERATE and (fast or randf() < 0.35)
	var hit: Array = u.d["hit"]
	if desperate:
		_banner(desp, "Desperation move!")
		Sfx.play("stagger-break-3tone")
		await _cut_in(u.id, desp, "DESPERATION MOVE", Color("ff6a4a"), false, "determined" if u.id == "teo" else "tense")
		for i in 3:
			if _over or _waking:
				break
			var roll := -2.2 if i == 2 else (1.4 if i == 0 else -1.2)
			var fov := 22.8 if i == 2 else (25.2 - float(i) * 0.8)
			_map.battle_cam_shot(_foe_at + Vector2(0.7, 0.0), Vector3(-0.9 + float(i) * 0.3, -0.55, -1.4 - float(i) * 0.25), fov, 0.8, 10.5, roll)
			await _lunge(u, 0.16, true)
			_hurt_foe(int(hit[0]) + 2 + randi() % 4, i == 2, {"stagger_pct": 0.10})
			await _wait(0.11)
	else:
		_say("")
		await _lunge(u, 0.22, false)
		_hurt_foe(int(hit[0]) + randi() % (int(hit[1]) - int(hit[0]) + 1), false, {"stagger_pct": 0.12})
	await _wait(0.35)
	await _step_back(u)


## The attack, animated the HD-2D way: anticipation crouch, a low-arc dash with afterimages and 3D camera swoop,
## and a squash/slash burst on impact; _step_back brings them home.
func _lunge(u: Unit, seconds: float, aerial: bool = false) -> void:
	u.moving = true
	if not aerial:
		_map.battle_cam_shot(_foe_at + Vector2(0.85, 0.0), Vector3(-0.75, -0.45, -1.25), 25.0, 0.65, 8.5, 1.4)
	var k := 0.2 if fast else 1.0
	var wind := create_tween()
	wind.tween_property(u.node, "position:x", u.home.x + 0.3, 0.09 * k).set_trans(Tween.TRANS_SINE)
	wind.parallel().tween_property(u.node, "scale", Vector3(1.12, 0.88, 1.0), 0.09 * k)
	wind.parallel().tween_property(u.node, "rotation_degrees:z", -6.0, 0.09 * k)
	await wind.finished
	_pose_frames(u.node, u.art("slash"), 14.0)
	var tw := create_tween()
	tw.tween_property(u.node, "position:x", _foe_at.x + 1.25, seconds * k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(u.node, "scale", Vector3(1.16, 0.9, 1.0), seconds * k * 0.5)
	tw.parallel().tween_property(u.node, "rotation_degrees:z", 5.0, seconds * k * 0.6)
	var peak := 0.42 if aerial else 0.22
	tw.parallel().tween_property(u.node, "position:y", peak, seconds * k * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(u.node, "position:y", 0.0, seconds * k * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if not fast:
		for n in 3:
			get_tree().create_timer(seconds * (0.15 + 0.22 * n)).timeout.connect(func() -> void: _afterimage(u.node))
	await tw.finished
	var land := create_tween()
	land.tween_property(u.node, "scale", Vector3(0.94, 1.06, 1.0), 0.05 * k)
	land.parallel().tween_property(u.node, "rotation_degrees:z", 0.0, 0.05 * k)
	land.tween_property(u.node, "scale", Vector3.ONE, 0.08 * k)
	if not fast:
		var hit_pt := _foe_head() + Vector2(18, 42)
		FxBurst.play(self, "cross_slash" if aerial else "slash", hit_pt, Color("ffd88a") if aerial else Color.WHITE, 1.15 if aerial else 0.9, randf_range(-0.4, 0.4))
		FxBurst.play(self, "spark", hit_pt, Color("fff3b0"), 1.0 if aerial else 0.7)
	Sfx.play("hit-thud-metal" if u.id == "kardo" else "slash-knife")


func _step_back(u: Unit) -> void:
	_pose(u.node, u.art("ready"))
	_map.battle_cam_reset()
	var tw := create_tween()
	tw.tween_property(u.node, "position:x", u.home.x, 0.05 if fast else 0.28)
	tw.parallel().tween_property(u.node, "position:y", 0.0, 0.05 if fast else 0.2)
	tw.parallel().tween_property(u.node, "rotation_degrees:z", 0.0, 0.05 if fast else 0.2)
	tw.parallel().tween_property(u.node, "scale", Vector3.ONE, 0.05 if fast else 0.2)
	await tw.finished
	u.moving = false


## Brief impact freeze (hitstop) for weighty strikes, parries, and discharges.
func _hitstop(secs: float = 0.05) -> void:
	if fast or Engine.time_scale < 0.9 or not is_inside_tree():
		return
	Engine.time_scale = 0.07
	await get_tree().create_timer(secs, true, false, true).timeout
	if is_inside_tree():
		Engine.time_scale = 1.0


# --- The aswang's wings -------------------------------------------------------------------------------------------------
# A flying aswang needs to be seen flying. Its sprites already carry folded wings, so nothing is drawn on top: while
# airborne it moves to a wingbeat (a sharp downstroke lifts it, and throws dust off the floor), and it takes off with
# a crouch and a gust. When Antigravity's flight strip lands (<art>_fly.png: 4 full-body frames, wings spread through a
# beat; docs/ART_REQUESTS.md #4), that strip plays instead of the idle pose while it hovers.

func _has_wings() -> bool:
	return bool(def.get("wings", false))


func _build_wings() -> void:
	if not _has_wings() or _foe == null:
		return
	var tex: Texture2D = _tex(_art("fly"))
	if tex == null:
		return # the wingbeat is in the motion until the art exists
	_wings = Sprite3D.new()
	_wings.texture = tex
	_wings.hframes = 4
	_wings.pixel_size = _foe.pixel_size
	_wings.offset = Vector2(0, tex.get_height() * 0.5)
	_wings.material_override = _map._sprite_material(tex, false)
	_wings.visible = false
	_map.add_node(_wings)


## Airborne, it moves to a wingbeat: a quick downstroke lifts it, a slower upstroke lets it sink, and each downstroke
## blows dust off the floor. With the flight strip, the frames follow the same beat (folded into a dive).
func _tick_wings(delta: float) -> void:
	if not _has_wings() or _foe == null or not is_instance_valid(_foe):
		return
	var airborne := _wings_out or (_floats() and not _over)
	var idle := _foe.texture == _tex(_art("idle")) or _foe.texture == _tex(_art("idle_b"))
	var show_strip := _wings != null and airborne and idle and not _foe_moving
	if _wings != null:
		_wings.visible = show_strip
		_foe.visible = not show_strip
		_wings.position = _foe.position
		_wings.flip_h = _foe.flip_h
	if not airborne:
		return
	_flap_t += delta * (3.4 if _wings_out else 2.3)
	var ph := fposmod(_flap_t / TAU, 1.0)
	var fr: int = [0, 1, 2, 1][int(ph * 4.0) % 4]
	if _wings != null:
		_wings.frame = 3 if _foe_moving else fr
	if fr == 2 and _last_flap != 2:
		wingbeats += 1
		if not fast and not _foe_moving: # the downstroke throws dust off the floor
			FxBurst.play(self, "ring", _screen(Vector3(_foe.position.x, 0.05, _foe.position.z)), Color(0.75, 0.68, 0.6), 0.55)
	_last_flap = fr
	if not _foe_moving and _floats() and not _over:
		# asymmetric beat: up fast on the downstroke (first 35%), a slow sink after
		var lift := sin(ph / 0.35 * PI * 0.5) if ph < 0.35 else cos((ph - 0.35) / 0.65 * PI * 0.5)
		_foe.position.y = _hover_y() + lift * 0.16 - 0.04


## Crouch, a spring, and a gust off the floor as the wings open: it's airborne.
func _take_off() -> void:
	if not _has_wings() or _foe == null:
		return
	_wings_out = true
	if fast:
		return
	var crouch := create_tween()
	crouch.tween_property(_foe, "scale", Vector3(1.15, 0.8, 1.0), 0.16).set_trans(Tween.TRANS_SINE)
	crouch.tween_property(_foe, "scale", Vector3(0.9, 1.15, 1.0), 0.08)
	crouch.tween_property(_foe, "scale", Vector3.ONE, 0.12)
	await crouch.finished
	Sfx.play("air-whoosh")
	FxBurst.play(self, "shockwave", _screen(Vector3(_foe.position.x, 0.1, _foe.position.z)), Color(0.75, 0.7, 0.65), 1.4)
	FxBurst.play(self, "ring", _screen(Vector3(_foe.position.x, 0.05, _foe.position.z)), Color(0.75, 0.68, 0.6), 1.2)
	_shake(6.0)
	await _wait(0.15)
	if not _over:
		_wings_out = false # once it hovers, the hover's wingbeat takes over


# --- Special-move choreography: wind-up, travel, payoff ----------------------------------------------------------------
# Every special plays in three beats so it lands: the user gathers (camera in, crouch, light pulled in), something
# travels (a dash, a wire, a thread of prayer), and the payoff hits hard (hitstop, zoom punch, knockback, shake).

## Wind-up: push in on the user, crouch, and let light gather on them.
func _gather_up(u: Unit, pose: String, col: Color, secs: float = 0.45) -> void:
	_pose(u.node, u.art(pose))
	_map.battle_cam_shot(u.home, Vector3(0.5, -0.3, -0.95), 21.5, 0.82, 9.0, 0.0)
	if fast:
		return
	_flash_color(Color(0.0, 0.0, 0.02), 0.35)
	_gather(u.node.position + Vector3(0, 1.0, 0), col, secs + 0.1)
	Sfx.play("command-exit-riser")
	var tw := create_tween()
	tw.tween_property(u.node, "scale", Vector3(1.1, 0.86, 1.0), secs * 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(u.node, "scale", Vector3(0.95, 1.08, 1.0), secs * 0.3)
	tw.tween_property(u.node, "scale", Vector3.ONE, secs * 0.25)
	await _wait(secs)


## Motes of light pulled in toward a point (the charge before a special).
func _gather(at: Vector3, col: Color, secs: float) -> void:
	if fast:
		return
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.mesh = q
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = 1.3
	p.gravity = Vector3.ZERO
	p.radial_accel_min = -10.0
	p.radial_accel_max = -6.0
	p.initial_velocity_max = 0.3
	p.amount = 42
	p.lifetime = 0.45
	p.color = col
	p.position = at
	_map.add_node(p)
	get_tree().create_timer(secs).timeout.connect(_stop_emitting.bind(p))
	get_tree().create_timer(secs + 0.6).timeout.connect(_free_if_valid.bind(p))


## A ribbon of light drawn from a to b, then fading: a wire's current (jag > 0: it crackles) or a thread of prayer.
func _ribbon(a: Vector3, b: Vector3, col: Color, secs: float, jag: float = 0.0, width: float = 1.0) -> void:
	if fast:
		return
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	mi.material_override = m
	_map.add_node(mi)
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void: _draw_ribbon(im, a, b, col, k, jag, width), 0.0, 1.0, secs)
	tw.tween_callback(mi.queue_free)


func _draw_ribbon(im: ImmediateMesh, a: Vector3, b: Vector3, col: Color, k: float, jag: float, width: float) -> void:
	im.clear_surfaces()
	var cam := _map.camera()
	var fwd := -cam.global_transform.basis.z if cam != null else Vector3.FORWARD
	var reach := clampf(k * 3.0, 0.0, 1.0) # it draws itself on fast, then holds and fades
	var fade := 1.0 - clampf((k - 0.55) / 0.45, 0.0, 1.0)
	var n := 16
	var pts: Array[Vector3] = []
	for i in n + 1:
		var p := a.lerp(b, float(i) / float(n) * reach)
		if jag > 0.0 and i > 0 and i < n:
			p += Vector3(0.0, randf_range(-jag, jag), randf_range(-jag, jag))
		pts.append(p)
	for layer in [[0.16 * width, Color(col, 0.6 * fade)], [0.045 * width, Color(1, 1, 1, 0.95 * fade)]]:
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in pts.size():
			var d := (pts[mini(i + 1, n)] - pts[maxi(i - 1, 0)]).normalized()
			var w := d.cross(fwd).normalized() * float(layer[0])
			if w.length() < 0.001:
				w = Vector3(float(layer[0]), 0, 0)
			im.surface_set_color(layer[1])
			im.surface_add_vertex(pts[i] + w)
			im.surface_set_color(layer[1])
			im.surface_add_vertex(pts[i] - w)
		im.surface_end()


## The payoff: freeze on contact, punch the camera in, knock the foe back, shake.
func _impact(heavy: bool = true) -> void:
	if fast or _foe == null or not is_instance_valid(_foe):
		return
	_hitstop(0.12 if heavy else 0.07)
	_shake(14.0 if heavy else 9.0)
	_map.battle_cam_shot(_foe_at, Vector3(0.4, -0.4, -1.15), 19.0, 0.9, 14.0, randf_range(-3.0, 3.0))
	var x0 := _foe.position.x
	var kb := create_tween()
	kb.tween_property(_foe, "position:x", x0 - (0.6 if heavy else 0.35), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	kb.tween_property(_foe, "position:x", x0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _stop_emitting(p: CPUParticles3D) -> void:
	if is_instance_valid(p):
		p.emitting = false


func _free_if_valid(n: Node) -> void:
	if is_instance_valid(n):
		n.queue_free()


func _foe_mid() -> Vector3:
	return _foe.position + Vector3(0, 1.5, 0) if _foe != null else Vector3(_foe_at.x, 1.5, _foe_at.y)


## A fading copy of the sprite where it was a moment ago (dashes, the rewind).
func _afterimage(s: Sprite3D) -> void:
	if s == null or not is_instance_valid(s) or s.texture == null:
		return
	var g := _make_sprite("", true)
	g.texture = s.texture
	g.offset = s.offset
	g.scale = s.scale
	g.position = s.position + Vector3(0, 0, -0.02)
	var mat := g.material_override as ShaderMaterial
	mat.set_shader_parameter("tex", s.texture)
	_map.add_node(g)
	var tw := create_tween()
	tw.tween_method(func(a: float) -> void: mat.set_shader_parameter("alpha", a), 0.45, 0.0, 0.25)
	tw.tween_callback(g.queue_free)


## A hit: the sprite blinks white.
func _blink(s: Sprite3D) -> void:
	if s == null or not is_instance_valid(s):
		return
	var mat := s.material_override as ShaderMaterial
	var tw := create_tween()
	tw.tween_method(func(f: float) -> void: mat.set_shader_parameter("flash", f), 0.9, 0.0, 0.05 if fast else 0.22)


## Everyone standing breathes: a slow squash and stretch, out of step with each other. Floating spirits bob instead.
func _breathe() -> void:
	if _over and outcome != "":
		return
	var i := 0
	for v in party:
		var m: Unit = v
		i += 1
		if m.node == null or m.moving:
			continue
		var b := 0.0 if not m.alive() else sin(_t * 2.3 + float(i) * 1.7) * 0.016
		m.node.scale = Vector3(1.0 - b * 0.6, 1.0 + b, 1.0)
	if _foe != null and not _foe_moving:
		if not _floats():
			var fb := sin(_t * (3.2 if charging else 1.8)) * (0.03 if charging else 0.018)
			_foe.scale = Vector3(1.0 - fb * 0.6, 1.0 + fb, 1.0)
		elif not _spirit():
			var wb := sin(_t * 4.4) * 0.025
			_foe.scale = Vector3(1.0 + wb * 0.5, 1.0 - wb * 0.4, 1.0)
			_foe.rotation_degrees.z = sin(_t * 2.2) * 1.8


func _next_gate_hp() -> int:
	var gates: Array[int] = []
	if not awakened and bool(def.get("awakens", false)) and not bool(def.get("scripted_death_awaken", false)) and _has("teo"):
		gates.append(maxi(1, int(floor(float(foe_max) * float(def.get("awaken_below", 0.55))))))
	if _phase < 2 and def.has("phase2"):
		gates.append(maxi(1, int(floor(float(foe_max) * float(def["phase2"].get("below", 0.5))))))
	if _phase < 3 and def.has("phase3"):
		gates.append(maxi(1, int(floor(float(foe_max) * float(def["phase3"].get("below", 0.25))))))
	var best := 0
	for g in gates:
		if foe_hp > g and g > best:
			best = g
	return best


func _has_pending_gate() -> bool:
	if _over or foe_hp <= 0:
		return false
	if not awakened and bool(def.get("awakens", false)) and not bool(def.get("scripted_death_awaken", false)) and _has("teo"):
		return true
	if _phase < 2 and def.has("phase2"):
		return true
	if _phase < 3 and def.has("phase3"):
		return true
	return false


func _add_stagger_pct(pct: float) -> void:
	if stagger_max <= 0 or staggered or _over or pct <= 0.0:
		return
	var gain := maxi(1, int(round(float(stagger_max) * pct)))
	stagger = mini(stagger_max, stagger + gain)
	if stagger >= stagger_max:
		_enter_stagger()
	else:
		_refresh()


func _enter_stagger() -> void:
	if stagger_max <= 0 or staggered or _over:
		return
	stagger = stagger_max
	staggered = true
	staggers += 1
	charging = false
	foe_atb = 0.0
	_tip.visible = false
	_pose(_foe, _art("hurt"))
	_number("STAGGERED! 1.5x", _foe_head() + Vector2(0, -40), Color("00ffcc"), true)
	_react_bystanders("awe", false)
	if not fast:
		Sfx.play("stagger-break-3tone")
		_map.battle_cam_shot(_foe_at, Vector3(0.55, -0.55, -1.65), 22.8, 0.85, 10.0, -2.5)
		FxBurst.play(self, "shockwave", _foe_head() + Vector2(0, 46), Color("00ffcc"), 1.55)
		_hitstop(0.08)
		_shake(11.0)
		if _foe != null and is_instance_valid(_foe):
			var stw := create_tween()
			stw.tween_property(_foe, "rotation_degrees:z", -8.0, 0.08)
			stw.parallel().tween_property(_foe, "scale", Vector3(1.08, 0.86, 1.0), 0.08)
			stw.tween_interval(0.35)
			stw.tween_property(_foe, "rotation_degrees:z", 0.0, 0.25)
			stw.parallel().tween_property(_foe, "scale", Vector3.ONE, 0.25)
	_refresh()


func _hurt_foe(dmg: int, heavy: bool, opts: Dictionary = {}) -> void:
	if _over:
		return
	var mult_applied := staggered and not bool(opts.get("no_stagger_mult", false))
	var final_dmg := int(round(float(dmg) * STAGGER_MULT)) if mult_applied else dmg
	var floor_now := foe_floor
	if _has_pending_gate():
		floor_now = maxi(floor_now, 1)
	var flee_hp := 0
	if def.has("flee_below") and awakened and not _has_pending_gate():
		flee_hp = maxi(1, int(ceil(float(foe_max) * float(def["flee_below"]))))
		floor_now = maxi(floor_now, flee_hp)
	var gate := _next_gate_hp()
	var next_hp := maxi(floor_now, foe_hp - final_dmg)
	if gate > 0 and next_hp < gate:
		next_hp = gate
	var sh: Dictionary = def.get("send_home", {})
	if not sh.is_empty() and staggered and not bool(opts.get("from_send_home", false)) and foe_hp > 1:
		next_hp = maxi(1, next_hp)
	var dealt := foe_hp - next_hp
	foe_hp = next_hp
	var heavy_interrupted := false
	if heavy and charging and _active_special().get("interrupt", ["prayer"]).has("heavy") and final_dmg >= 20:
		heavy_interrupted = true
		_interrupt("The blow knocks it off balance!")
	if stagger_max > 0 and not staggered and not heavy_interrupted and not bool(opts.get("no_stagger_build", false)):
		var spct := float(opts.get("stagger_pct", 0.0))
		if heavy and final_dmg >= 20 and not _spirit() and enemy_id in ["aswang", "aswang_finale"]:
			spct = maxf(spct, 0.35)
		if spct > 0.0:
			_add_stagger_pct(spct)
	_number(str(dealt if dealt > 0 else final_dmg), _foe_head(), Color("00ffcc") if mult_applied else Color("ffffff"), heavy or mult_applied)
	_pose(_foe, _art("hurt"))
	_blink(_foe)
	_hitstop(0.06 if heavy else 0.032)
	var tw := create_tween()
	tw.tween_property(_foe, "position:x", _foe_at.x - (0.48 if heavy else 0.35), 0.06)
	tw.parallel().tween_property(_foe, "rotation_degrees:z", 7.0 if heavy else 4.0, 0.06)
	tw.tween_property(_foe, "position:x", _foe_at.x, 0.22)
	tw.parallel().tween_property(_foe, "rotation_degrees:z", 0.0, 0.22)
	tw.tween_callback(func() -> void:
		if not _over:
			_pose(_foe, _art("tell") if charging else _art("idle")))
	if heavy:
		_shake(9.0)
		if not fast:
			FxBurst.play(self, "spark", _foe_head() + Vector2(0, 46), Color("ffe08a"), 1.25)
	if bool(def.get("scripted_death_awaken", false)) and not awakened and foe_hp <= foe_floor and dealt == 0:
		_say("It shrugs the blade off — skin like wet iron! Brace yourself!")
	_refresh()
	if flee_hp > 0 and foe_hp <= flee_hp:
		_win("fled")
	elif foe_hp <= 0:
		_win("scattered")


func _interrupt(text: String) -> void:
	charging = false
	interrupts += 1
	foe_atb = 0.0
	_tip.visible = false
	_say(text)
	if stagger_max > 0:
		if not staggered:
			_enter_stagger()
		else:
			_react_bystanders("awe", false)
			_refresh()
		return
	_number("STAGGERED!", _foe_head() + Vector2(0, -40), Color("ffe08a"), true)
	_react_bystanders("awe", false)
	if not fast:
		_map.battle_cam_shot(_foe_at, Vector3(0.55, -0.55, -1.65), 22.8, 0.85, 10.0, -2.5)
		FxBurst.play(self, "shockwave", _foe_head() + Vector2(0, 46), Color("ffe08a"), 1.45)
		_hitstop(0.08)
		_shake(11.0)
		if _foe != null and is_instance_valid(_foe):
			var stw := create_tween()
			stw.tween_property(_foe, "rotation_degrees:z", -8.0, 0.08)
			stw.parallel().tween_property(_foe, "scale", Vector3(1.08, 0.86, 1.0), 0.08)
			stw.tween_interval(0.35)
			stw.tween_property(_foe, "rotation_degrees:z", 0.0, 0.25)
			stw.parallel().tween_property(_foe, "scale", Vector3.ONE, 0.25)


## Kardo clamps a wire on it: a little damage now, and one more wire for the discharge.
func _wire(u: Unit) -> void:
	_pose(u.node, u.art("pray"))
	_map.battle_cam_shot(_foe_at + Vector2(0.8, 0.0), Vector3(-0.6, -0.35, -1.0), 25.8, 0.55, 7.5, 0.8)
	Sfx.play("hit-thud-metal")
	wired = mini(_max_wires(), wired + 1)
	if not fast:
		FxBurst.play(self, "lightning", _foe_head() + Vector2(0, 48), Color("5ad8ff"), 0.9)
	await _wait(0.3)
	_hurt_foe(6, false, {"stagger_pct": 0.15})
	_say("Kardo clips an alligator lead onto its hide. \"Free Meralco, gago.\" Circuit: %d / %d." % [wired, _max_wires()])
	await _wait(0.6)


## KONTRA: every wire lights at once, on Kardo's hold-and-release (SpecialGauge "charge"). The more wires, the bigger
## the hit. Let go in the green: a clean circuit. In the red: OVERCHARGE, half again the damage, and the current comes
## back up the wire into Kardo. Held at the top too long, the breaker trips: a weak hit, and the full shock.
## It also shorts a machine's charge.
func _discharge(u: Unit) -> void:
	var stacks := wired
	wired = 0
	_pose(u.node, u.art("charge"))
	_map.battle_cam_shot(u.home, Vector3(0.55, -0.35, -1.0), 25.5, 0.65, 6.5, -1.2)
	Sfx.play("hit-thud-metal")
	var hot := "" if heat == 0 else ("   THE LINE IS HOT: THE RED COMES SOONER" if heat == 1 else "   THE LINE IS VERY HOT")
	var r := await _gauge_play("charge", "KONTRA", "%d WIRE%s ON IT. HOLD, AND LET GO IN THE GREEN%s" % [stacks, "" if stacks == 1 else "S", hot], Color("5ad8ff"))
	heat = mini(2, heat + 1)
	heat_peak = maxi(heat_peak, heat)
	last_kontra = r
	var z := String(r.get("zone", "weak"))
	var v := float(r.get("value", 0.0))
	var mult := 1.0
	var shock := 0
	var sub := "%d WIRE%s LIGHT UP" % [stacks, "" if stacks == 1 else "S"]
	match z:
		"weak":
			mult = 0.45 + 0.55 * v / maxf(0.1, SpecialGauge.CLEAN - HEAT_STEP * (heat - 1))
			sub = "LET GO TOO SOON"
		"over":
			mult = 1.5
			shock = 8 + 4 * stacks
			overcharges += 1
			sub = "OVERCHARGE!"
		"trip":
			mult = 0.5
			shock = 16
			trips += 1
			sub = "THE BREAKER TRIPS"
	var k_expr := "shock" if z == "over" else ("smirk" if z == "clean" else "tense")
	await _cut_in(u.id, "KONTRA" + ("!!" if z == "over" else ""), sub, Color("5ad8ff") if z != "over" else Color("ff6a4a"), false, k_expr)
	# Wind-up: Kardo throws the switch, current crawls up his arms. Travel: every clamped wire lights, one after the
	# other, from his hands to the thing. Payoff: the burst.
	await _gather_up(u, "charge", Color("8fe3ff"), 0.35)
	_pose(u.node, u.art("burst"))
	Sfx.play("stagger-break")
	for i in maxi(1, stacks):
		var off := Vector3(0, 0.25 * float(i) - 0.25, 0.12 * float(i))
		_ribbon(u.node.position + Vector3(0, 1.1, 0), _foe_mid() + off, Color("5ad8ff") if z != "over" else Color("ff9a6a"), 0.75, 0.22, 0.9)
		await _wait(0.07)
	_map.battle_cam_shot(_foe_at, Vector3(0.65, -0.5, -1.55), 23.4, 0.8, 9.5, 2.0 if z == "over" else 1.0)
	_flash_color(Color("5ad8ff") if z != "over" else Color.WHITE, 0.5 if z != "over" else 0.75)
	if not fast:
		FxBurst.play(self, "lightning", _foe_head() + Vector2(0, 54), Color("8fe3ff"), 1.5 if z != "over" else 2.1)
		FxBurst.play(self, "shockwave" if z == "over" else "spark", _foe_head() + Vector2(0, 56), Color("aef0ff"), 1.5 if z != "over" else 2.0)
	if z != "weak" and z != "trip":
		_impact(stacks >= 2 or z == "over")
	if charging and _active_special().get("interrupt", []).has("discharge") and z != "trip":
		_interrupt("The current shorts it out mid-charge!")
	elif z in ["clean", "over"]:
		_react_bystanders("awe", false)
	var k_stagger := 0.10 if z == "trip" else (0.28 + 0.10 * float(stacks)) * (1.25 if enemy_id == "hiraya_hound" else 1.0) * (1.2 if z == "over" else 1.0)
	_hurt_foe(int(round((14 + 16 * stacks) * mult)), stacks >= 2 or z == "over", {"stagger_pct": k_stagger})
	shock = int(round(shock * float(u.mods.get("shock", 1.0))))
	if shock > 0 and not _over:
		await _wait(0.35)
		_pose(u.node, u.art("shock"))
		_map.battle_cam_shot(u.home, Vector3(0.5, -0.4, -1.1), 25.0, 0.7, 9.0, -1.8)
		Sfx.play("stagger-break-3tone")
		if not fast:
			FxBurst.play(self, "lightning", _head(u) + Vector2(0, 50), Color("aef0ff"), 1.3)
		u.hp = maxi(1, u.hp - shock) # the shock never drops him: he has done this before
		_number(str(shock), _head(u), Color("8fe3ff"), true)
		_shake(7.0)
		_refresh()
	match z:
		"over":
			_say("Current kicks straight back up the line. Kardo's hair stands straight up. \"Ayos lang. Amoy sinigang yung buhok ko, pero ayos lang.\"")
		"trip":
			_say("Somewhere a breaker blows with a wet pop. Kardo sits down hard, smoking slightly. \"Warranty's definitely void.\"")
		"weak":
			_say("Kardo lets go too early. \"Bitin—\" The wires spit sparks across the floor.")
		_:
			_say("Kardo snaps the switch: %d wire%s light up. \"Illegal jumper, special delivery.\"" % [stacks, "" if stacks == 1 else "s"])
	await _wait(0.9 if shock > 0 else 0.7)


## Lola's ORASYON (SpecialGauge "rhythm"): the old prayer, beat by beat. How well it is kept decides how much: it heals
## everyone and breaks a spell, hurts a spirit, and kept perfectly it stops a charging spell cold.
func _orasyon(u: Unit) -> void:
	orasyons += 1
	_pose(u.node, u.art("pray"))
	_map.battle_cam_shot(u.home, Vector3(0.5, -0.35, -1.05), 25.4, 0.65, 6.0, 0.0)
	_banner("ORASYON", "Keep the beat of the old prayer")
	var r := await _gauge_play("rhythm", "ORASYON", "THE OLD PRAYER. KEEP ITS BEAT", Color("ffd27a"))
	last_orasyon = r
	var score := float(r.get("value", 0.0))
	var full := int(r.get("perfect", 0)) == int(r.get("notes", 6))
	if score < 0.2:
		_pose(u.node, u.art("hurt"))
		_say("Lola loses the beat. \"Ay, my memory. Again, apo, again.\"")
		await _wait(0.9)
		return
	await _cut_in(u.id, "ORASYON" + ("!" if full else ""), "EVERY BEAT KEPT" if full else "%d OF %d BEATS" % [int(r.get("perfect", 0)) + int(r.get("good", 0)), int(r.get("notes", 6))], Color("ffd27a"), false, "determined" if full else "tense")
	# Wind-up: the rosary turns in her hands and the room's light leans toward her. Then a shaft of it comes down on
	# the thing (a spirit feels it), and warmth spreads back over the party.
	await _gather_up(u, "pray", Color("ffe08a"), 0.5)
	_pose(u.node, u.art("burst"))
	Sfx.play("heal-chime")
	_flash_color(Color(1.0, 0.92, 0.6), 0.4)
	if not fast:
		FxBurst.play(self, "prayer_motes", _head(u) + Vector2(0, 50), Color("ffe08a"), 1.4)
		FxBurst.play(self, "ring", _head(u) + Vector2(0, 60), Color("ffe08a"), 1.4)
	if _spirit() and not fast:
		_ribbon(_foe.position + Vector3(0, 9.0, 0), _foe.position + Vector3(0, 0.1, 0), Color("ffe08a"), 0.9, 0.0, 3.2 if full else 2.0)
		await _wait(0.2)
		FxBurst.play(self, "ring", _screen(_foe.position + Vector3(0, 0.1, 0)), Color("ffe08a"), 2.0 if full else 1.4)
		_impact(full)
	var heal := int(round(10 + 22 * score))
	for v in party:
		var m: Unit = v
		if not m.alive():
			continue
		var h := mini(heal, m.max_hp - m.hp)
		m.hp += h
		m.spellbound = false
		m.status.text = ""
		if h > 0:
			_number("+%d" % h, _head(m), Color("7dff9a"))
	if charging and full:
		_interrupt("Every word lands on the beat. Whatever it was gathering scatters.")
	else:
		_react_bystanders("awe", false)
	if _spirit():
		_hurt_foe(int(round(8 + 18 * score)), full, {"stagger_pct": 0.35 if full else 0.22})
	u.tired = true
	u.status.text = "TIRED"
	if not _over:
		_say("Lola prays the way her lola did, every word on the beat. Even the folding chairs seem to listen." if full else "Lola prays. The room gets a little warmer.")
	_refresh()
	await _wait(0.8)


## TEAM COMBO (Teo + Kardo): "Hatid sa Kuryente" — a prayer carried down Kardo's wire. Costs 1 utang na loob.
func _combo_kuryente(u: Unit) -> void:
	var k := unit("kardo")
	if k == null or not k.alive():
		return
	Story.gratitude = maxi(0, Story.gratitude - 1)
	combos_used += 1
	_pose(u.node, u.art("pray"))
	_pose(k.node, k.art("guard"))
	_map.battle_cam_shot(u.home, Vector3(0.7, -0.35, -1.1), 25.0, 0.7, 7.0, 0.0)
	await _cut_in_dual("teo", "kardo", "HATID SA KURYENTE", "TEO + KARDO: PRAYER DOWN THE WIRE", Color("5ad8ff"), "determined", "smirk")
	# Kardo stakes the line and throws the current into Teo's blade; Teo, lit like a filament, leaps along the wire
	# and brings both down on it at once.
	_gather(u.node.position + Vector3(0, 1.0, 0), Color("ffe08a"), 0.5)
	await _gather_up(k, "charge", Color("8fe3ff"), 0.4)
	_pose(k.node, k.art("burst"))
	Sfx.play("hit-thud-metal")
	_ribbon(k.node.position + Vector3(0, 1.1, 0), u.node.position + Vector3(0, 1.2, 0), Color("5ad8ff"), 0.6, 0.18)
	await _wait(0.25)
	_pose(u.node, u.art("aura"))
	_ribbon(u.node.position + Vector3(0, 1.2, 0), _foe_mid(), Color("5ad8ff"), 0.8, 0.25, 1.3)
	_ribbon(u.node.position + Vector3(0, 1.4, 0), _foe_mid() + Vector3(0, 0.3, 0), Color("ffe08a"), 0.8, 0.0)
	await _lunge(u, 0.2, true)
	_map.battle_cam_shot(_foe_at, Vector3(-0.7, -0.55, -1.65), 23.0, 0.85, 9.5, 2.0)
	Sfx.play("stagger-break-3tone")
	_flash_color(Color("5ad8ff"), 0.55)
	if not fast:
		FxBurst.play(self, "cross_slash", _foe_head() + Vector2(0, 48), Color("bfefff"), 1.9)
		FxBurst.play(self, "lightning", _foe_head() + Vector2(0, 50), Color("5ad8ff"), 2.0)
		FxBurst.play(self, "prayer_motes", _foe_head() + Vector2(0, 50), Color("ffe08a"), 1.5)
		FxBurst.play(self, "shockwave", _foe_head() + Vector2(0, 50), Color("5ad8ff"), 1.6)
	_impact(true)
	_react_bystanders("awe", true)
	var dmg := (42 + wired * 12) * (135 if _spirit() else 100) / 100
	wired = 0
	var interrupt: Array = _active_special().get("interrupt", [])
	if charging and (interrupt.has("prayer") or interrupt.has("discharge")):
		_interrupt("Prayer and current meet in the chassis — the charge collapses!")
	_say("\"Hawakan mo, Kardo!\" Teo's prayer rides the copper line straight into it.")
	_hurt_foe(dmg, true, {"stagger_pct": 0.45})
	k.atb = 0.0
	k.atb_bar.value = 0.0
	_pose(k.node, k.art("ready"))
	_refresh()
	await _wait(0.4)
	await _step_back(u)
	await _wait(0.5)


## TEAM COMBO (Teo + Lola): "Dasal ng Dalawa" — prayers in unison: heals the party, hurts spirits, and can send home.
func _combo_dalawa(u: Unit) -> void:
	var lola := unit("ising")
	if lola == null or not lola.alive():
		return
	Story.gratitude = maxi(0, Story.gratitude - 1)
	combos_used += 1
	_pose(u.node, u.art("pray"))
	_pose(lola.node, lola.art("pray"))
	_map.battle_cam_shot(u.home, Vector3(0.65, -0.35, -1.1), 25.0, 0.7, 7.0, 0.0)
	await _cut_in_dual("teo", "ising", "DASAL NG DALAWA", "TEO + LOLA ISING: TWO VOICES, ONE PRAYER", Color("ffe08a"), "tense", "determined")
	# Both kneel; their two threads of prayer braid into one over the room, and a column of light comes down on it.
	_gather(lola.node.position + Vector3(0, 1.0, 0), Color("ffe08a"), 0.6)
	await _gather_up(u, "pray", Color("ffe08a"), 0.5)
	var over := Vector3((u.node.position.x + _foe.position.x) * 0.5 if _foe != null else _foe_at.x, 4.2, u.node.position.z)
	_ribbon(u.node.position + Vector3(0, 1.4, 0), over, Color("ffe08a"), 0.7)
	_ribbon(lola.node.position + Vector3(0, 1.3, 0), over, Color("fff3b0"), 0.7)
	await _wait(0.3)
	_map.battle_cam_shot(_foe_at, Vector3(0.55, -0.5, -1.5), 23.6, 0.8, 8.5, -1.5)
	Sfx.play("heal-chime")
	if not fast:
		_ribbon(_foe.position + Vector3(0, 10.0, 0), _foe.position + Vector3(0, 0.1, 0), Color("ffe08a"), 1.0, 0.0, 3.6)
	await _wait(0.18)
	_flash_color(Color("ffe08a"), 0.55)
	if not fast:
		FxBurst.play(self, "prayer_motes", _foe_head() + Vector2(0, 50), Color("ffe08a"), 1.8)
		FxBurst.play(self, "ring", _foe_head() + Vector2(0, 50), Color("ffe08a"), 1.8)
		for v in party:
			if (v as Unit).alive():
				FxBurst.play(self, "prayer_motes", _head(v) + Vector2(0, 40), Color("7dff9a"), 1.1)
	_impact(true)
	_react_bystanders("awe", true)
	for v in party:
		var m: Unit = v
		if m.alive():
			m.spellbound = false
			m.status.text = ""
			var h := mini(32, m.max_hp - m.hp)
			m.hp += h
			if h > 0:
				_number("+%d" % h, _head(m), Color("7dff9a"))
	var interrupt: Array = _active_special().get("interrupt", [])
	if charging and interrupt.has("prayer"):
		_interrupt("Two voices answer at once — the call breaks!")
	_say("Lola's beads and Teo's voice land on the same breath.")
	var sh: Dictionary = def.get("send_home", {})
	var dmg := 34 * (145 if _spirit() else 100) / 100
	if not sh.is_empty() and float(foe_hp) / foe_max <= float(sh.get("below", 0.0)) + TAWID_REACH:
		foe_hp = 0
		_refresh()
		_say(String(def.get("sent_text", "Uwi ka na.")))
		await _wait(1.0)
		_win("sent")
	else:
		_hurt_foe(dmg, true, {"stagger_pct": 0.45})
		_refresh()
		await _wait(1.0)
	lola.atb = 0.0
	lola.atb_bar.value = 0.0
	_pose(lola.node, lola.art("ready"))


## TAWAG: a sundô who went before answers. The painted boat (the hatid panel) fills the screen and the name is said;
## then the ancestor's ghost crosses the stage and strikes: a heavy hit (heavier on spirits), it stops a charge, and
## the party is healed. Once a fight. Lola calls on her own; Teo spends one utang na loob.
func _summon(u: Unit) -> void:
	summoned = true
	summons += 1
	var anc: Dictionary = ANCESTORS[0]
	if u.id != "ising":
		Story.gratitude = maxi(0, Story.gratitude - 1)
	_pose(u.node, u.art("pray"))
	_map.battle_cam_shot(u.home, Vector3(0.55, -0.35, -1.05), 25.0, 0.7, 6.0, 0.0)
	_say(String(anc["lola" if u.id == "ising" else "teo"]))
	await _wait(1.3)
	await _summon_card(anc, u)
	# Back in the room the instant his blade lands: the hit, felt here.
	_map.battle_cam_shot(_foe_at + Vector2(0.8, 0.0), Vector3(-0.9, -0.6, -1.7), 22.8, 0.85, 9.5, 2.2)
	_hitstop(0.12)
	Sfx.play("slash-knife")
	Sfx.play("stagger-break-3tone")
	_flash_color(Color.WHITE, 0.7)
	if not fast:
		FxBurst.play(self, "cross_slash", _foe_head() + Vector2(0, 54), Color("e8f4ff"), 1.8)
		FxBurst.play(self, "shockwave", _foe_head() + Vector2(0, 60), Color("e8f4ff"), 1.8)
	_shake(12.0)
	if charging:
		_interrupt("The old sundô's blade cuts the call in half.")
	var power := int(anc["power"]) * (3 if _spirit() else 2) / 2
	if def.has("send_home"):
		power = mini(power, foe_hp - 1) # a sundô never scatters a soul that can still go home: that is left to Teo
	_hurt_foe(power, true, {"stagger_pct": 0.35})
	for v in party:
		var m: Unit = v
		if m.alive():
			var h := mini(int(anc["heal"]), m.max_hp - m.hp)
			m.hp += h
			if h > 0:
				_number("+%d" % h, _head(m), Color("7dff9a"))
	_refresh()
	if not _over:
		_say("%s lowers the sundang, nods once at Teo, and is gone." % String(anc["short"]).capitalize())
	_react_bystanders("awe", true)
	await _wait(0.9)


## The full-screen summon, as cinematic pixel art (scripts/pixel_cg.gd): six cuts, ~15 s (see _tawag_shot).
func _summon_card(anc: Dictionary, u: Unit) -> void:
	cut_ins += 1
	Sfx.play("extra-chime")
	var cg := PixelCG.new()
	cg.fast = fast
	add_child(cg)
	await cg.play(_tawag_shot(anc, u))
	cg.queue_free()


## TAWAG as an FF7-style summon (~15 s, six cuts; skippable once it has been seen, PixelCG.can_skip):
## the candle gutters, the river, the boat out of the fog, the leap, the cut, and going home.
func _tawag_shot(anc: Dictionary, u: Unit) -> Dictionary:
	var model := String(anc.get("model", "summon_" + String(anc["id"])))
	var art := String(def.get("art", "lberto"))
	var foe_idle := "res://assets/explore/%s_idle.png" % art
	var foe_hurt := "res://assets/explore/%s_hurt.png" % art
	var foe := [0.0, 0.0, 17.0]
	return {"id": "tawag_" + String(anc["id"]), "cuts": [
		{ # 1. The call: Lola's candle, close. It gutters, and everything goes to black water.
			"dur": 2.2, "in": "fade", "props": ["candle"], "candle_out": 1.75, "particles": ["wisps"],
			"sfx": [[0.1, "extra-chime"], [1.7, "air-whoosh"]],
			"cam": [{"t": 0.0, "pos": [0.45, 0.95, 1.7], "look": [0.0, 0.85, 0.0], "fov": 34},
				{"t": 2.2, "pos": [0.2, 0.93, 1.05], "look": [0.0, 0.9, 0.0], "fov": 30}],
			"titles": [{"t0": 0.3, "t1": 2.0, "who": "LOLA ISING CALLS ON THE SUNDÔ BEFORE HER" if u.id == "ising" else "TEO SPEAKS A NAME FROM THE HEARTWOOD", "name": "", "move": ""}],
		},
		{ # 2. The river: low over black water, a lantern growing out of the fog.
			"dur": 2.4, "in": "wipe", "fog": 9, "particles": ["wisps"],
			"model": model, "scale": 3.0, "move": [{"t": 0.0, "pos": [0, 0, -30]}, {"t": 2.4, "pos": [0, 0, -16]}],
			"lantern": [{"t": 0.0, "e": 3.5}], "wake": [0.0, 2.4],
			"cam": [{"t": 0.0, "pos": [0.0, 0.5, 10.0], "look": [0.0, 1.6, -20.0], "fov": 42},
				{"t": 2.4, "pos": [0.0, 0.7, 5.0], "look": [0.0, 2.2, -16.0], "fov": 38}],
		},
		{ # 3. The boat cuts past; crane up to him standing in a column of light. His name.
			"dur": 3.0, "in": "cut", "model": model, "scale": 3.0, "fog": 5,
			"move": [{"t": 0.0, "pos": [0, 0, -7]}, {"t": 1.3, "pos": [0, 0, 0]}], "wake": [0.0, 1.3],
			"pillar": [1.2, 3.0], "particles": ["embers", "wisps"], "sfx": [[1.2, "stagger-break"]],
			"cam": [{"t": 0.0, "pos": [4.5, 0.7, 5.0], "look": [0.0, 1.4, -2.0], "fov": 44},
				{"t": 1.2, "pos": [7.0, 1.6, -1.0], "look": [0.0, 3.0, 0.0], "fov": 40},
				{"t": 3.0, "pos": [9.0, 7.0, 9.0], "look": [0.0, 5.0, 0.0], "fov": 34}],
			"titles": [{"t0": 1.5, "t1": 2.95, "who": "THE SUNDÔ ANSWERS", "name": String(anc["name"]), "move": "TAWAG:  " + String(anc["move"])}],
		},
		{ # 4. The leap: the thing he came for waits on the far bank. He jumps, sundang high.
			"dur": 2.8, "in": "cut", "model": model, "scale": 3.0, "fog": 4, "particles": ["wisps"],
			"move": [{"t": 0.0, "pos": [0, 0, 0]}, {"t": 0.8, "pos": [0, 0, 0]}, {"t": 1.6, "pos": [0, 6, 8]}, {"t": 2.6, "pos": [0, 2.5, 13]}],
			"nodes": {"SwordArm": [{"t": 0.0, "rot": [0, 0, 0]}, {"t": 1.4, "rot": [0, 0, 30]}, {"t": 2.6, "rot": [0, 0, 42]}]},
			"sprites": [{"path": foe_idle, "h": 5.0, "at": foe}],
			"sfx": [[0.8, "air-whoosh"], [0.9, "dodge-swish-9"]],
			"cam": [{"t": 0.0, "pos": [-10.0, 3.0, 5.0], "look": [0.0, 4.0, 5.0], "fov": 42},
				{"t": 1.6, "pos": [-13.0, 9.0, 11.0], "look": [0.0, 8.0, 9.0], "fov": 40},
				{"t": 2.8, "pos": [-5.0, 5.0, 24.0], "look": [0.0, 5.5, 14.0], "fov": 38}],
		},
		{ # 5. The cut: slow motion into the stroke, a freeze on contact, white.
			"dur": 2.2, "in": "cut", "model": model, "scale": 3.0, "slowmo": [0.0, 0.5, 0.35],
			"move": [{"t": 0.0, "pos": [0, 2.5, 13]}, {"t": 0.4, "pos": [0, 0, 14.3]}],
			"nodes": {"SwordArm": [{"t": 0.0, "rot": [0, 0, 42]}, {"t": 0.33, "rot": [0, 0, -125]}]},
			"sprites": [{"path": foe_idle, "h": 5.0, "at": foe, "swap": [[0.35, foe_hurt]], "hit": 0.35}],
			"slash": [{"t": 0.22, "at": [0.0, 4.0, 16.0], "size": 9.0, "rot": -35, "color": "bfe4ff"}],
			"shock": [{"t": 0.36, "at": [0.0, 0.06, 16.5], "size": 16.0}],
			"hitstop": [{"t": 0.35, "dur": 0.2}], "shake": [{"t": 0.35, "amp": 16.0, "dur": 0.7}], "flash": 0.36,
			"sfx": [[0.2, "slash-knife"], [0.35, "stagger-break-3tone"], [0.4, "hit-thud"]],
			"cam": [{"t": 0.0, "pos": [8.0, 3.0, 11.0], "look": [0.0, 4.0, 16.0], "fov": 40},
				{"t": 2.2, "pos": [10.0, 2.2, 9.0], "look": [0.0, 3.5, 16.0], "fov": 46}],
		},
		{ # 6. Going home: back on the boat, drifting into the fog. One nod for Teo. The lantern goes out.
			"dur": 2.4, "in": "fade", "model": model, "scale": 3.0, "fog": 8, "particles": ["wisps"],
			"move": [{"t": 0.0, "pos": [0, 0, -2]}, {"t": 2.4, "pos": [0, 0, -11]}],
			"nodes": {"SwordArm": [{"t": 0.0, "rot": [0, 0, -100]}],
				"Body": [{"t": 0.0, "pos": [0, 0.32, 0.4], "rot": [0, 0, 0]}, {"t": 0.7, "pos": [0, 0.32, 0.4], "rot": [0, 0, 0]},
				{"t": 1.0, "pos": [0, 0.32, 0.4], "rot": [14, 0, 0]}, {"t": 1.4, "pos": [0, 0.32, 0.4], "rot": [0, 0, 0]}]},
			"lantern": [{"t": 0.0, "e": 2.2}, {"t": 1.4, "e": 2.0}, {"t": 2.3, "e": 0.0}],
			"cam": [{"t": 0.0, "pos": [0.0, 3.0, 12.0], "look": [0.0, 3.5, -4.0], "fov": 38},
				{"t": 2.4, "pos": [0.0, 2.4, 9.0], "look": [0.0, 3.0, -8.0], "fov": 34}],
		},
	]}


## Plays one special's input and returns its result (SpecialGauge).
func _gauge_play(mode: String, title: String, sub: String, accent: Color) -> Dictionary:
	_gauge.auto = fast or demo
	_gauge.fast = fast
	_gauge.auto_charge = auto_charge
	_gauge.auto_rhythm = auto_rhythm
	_gauge.auto_react = auto_react
	_gauge.clean_at = SpecialGauge.CLEAN - HEAT_STEP * heat
	_gauge.over_at = SpecialGauge.OVER - HEAT_STEP * heat
	_gauge.start(mode, title, sub, accent)
	var r: Dictionary = await _gauge.finished
	return r


# --- Hatid: the prayer input ---------------------------------------------------------------------------------------

func _pray(u: Unit, id: String) -> void:
	var p: Dictionary = {}
	for q in PRAYERS:
		if String(q["id"]) == id:
			p = q
	if p.is_empty():
		return
	var tier2 := int(p.get("tier", 1)) == 2
	candles = maxi(0, candles - _candle_cost(id)) # lit whether or not the words come out right
	_refresh()
	_pose(u.node, u.art("aura" if tier2 else "pray"))
	_map.battle_cam_shot(u.home, Vector3(0.55, -0.35, -1.0), 25.5, 0.6, 6.5, 0.0)
	_banner(String(p["name"]), ("HATID II: %s. The long prayer!" if tier2 else "Hatid: %s. Enter the prayer!") % p["gloss"])
	var ok: bool = await _sequence(p)
	var swift := ok and _seq_t >= _seq_total * SWIFT
	if not ok:
		_pose(u.node, u.art("hurt"))
		_say("The words tangle. The prayer fizzles.")
		Sfx.play("command-exit")
		await _wait(0.9)
		return
	if swift:
		swift_prayers += 1
	await _cut_in(u.id, String(p["name"]) + ("+" if swift else ""),
		"SWIFT PRAYER: POWER UP!" if swift else ("HATID II: " if tier2 else "HATID: ") + String(p["gloss"]).to_upper(), Color("ffd27a"), false, "determined" if (swift or tier2) else "tense")
	# Wind-up: the prayer gathers on the watch. Travel: a lit thread runs from the watch to the foe and Teo follows it
	# in. Payoff: a downward cut along the thread, a freeze, the ring of light.
	await _gather_up(u, "aura", Color("ffe08a"), 0.5 if tier2 else 0.4)
	Sfx.play("extra-chime")
	_ribbon(u.node.position + Vector3(0, 1.3, 0), _foe_mid(), Color("ffe08a"), 0.8, 0.0, 1.4 if tier2 else 1.0)
	await _wait(0.22)
	await _lunge(u, 0.22, true)
	_pose(u.node, u.art("aura" if tier2 else "burst"))
	_flash_color(Color(1.0, 0.92, 0.6), 0.55)
	if not fast:
		FxBurst.play(self, "slash", _foe_head() + Vector2(10, 40), Color("fff3b0"), 1.6, PI * 0.5)
		FxBurst.play(self, "prayer_motes", _foe_head() + Vector2(0, 56), Color("ffe08a"), 1.6 if tier2 else 1.25)
		FxBurst.play(self, "ring", _foe_head() + Vector2(0, 60), Color("ffe08a"), 1.6)
		FxBurst.play(self, "spark", _foe_head() + Vector2(0, 60), Color("fff3b0"), 1.4)
	_impact(true)
	await _wait(0.25)
	var sh: Dictionary = def.get("send_home", {})
	var reach := TAWID_REACH if tier2 else 0.0
	var low := not sh.is_empty() and float(foe_hp) / foe_max <= float(sh.get("below", 0.0)) + reach
	if (id == String(sh.get("prayer", "")) or tier2) and low and foe_floor == 0:
		await _step_back(u)
		_win("sent")
		return
	var power := int(p["power"]) * (3 if _spirit() else 2) / 2
	if swift:
		power = int(round(power * 1.35))
	if charging and _active_special().get("interrupt", ["prayer"]).has("prayer"):
		_interrupt(String(_active_special().get("interrupted", "The prayer drowns it out!")))
	var pray_stagger := (0.45 if (swift or tier2) else 0.35) * (1.0 if _spirit() else 0.6)
	_hurt_foe(power, true, {"stagger_pct": pray_stagger})
	_react_bystanders("awe", false)
	await _wait(0.35)
	await _step_back(u)
	if not _over and id == String(sh.get("prayer", "")) and not low:
		_say("Not ready to go. Weaken it first, then pray UWI KA NA.")
	await _wait(0.45)


func _sequence(p: Dictionary) -> bool:
	_seq_keys = p["keys"]
	_seq_at = 0
	_seq_total = float(p["seconds"])
	_seq_t = _seq_total
	_seq_title.text = "%s  ·  %s" % [p["name"], p["gloss"]]
	for c in _seq_row.get_children():
		c.queue_free()
	for k in _seq_keys:
		var a := ArrowKey.new()
		a.dir = String(k)
		a.custom_minimum_size = Vector2(64, 64)
		_seq_row.add_child(a)
	_seq_panel.visible = true
	_pad.visible = true
	_seq_active = true
	if fast:
		for k in _seq_keys:
			_seq_input(String(k))
	elif demo:
		for k in _seq_keys:
			await get_tree().create_timer(0.45).timeout
			_seq_input(String(k))
	var ok: bool = await _seq_done
	return ok


func _seq_input(dir: String) -> void:
	if not _seq_active:
		return
	var cells := _seq_row.get_children()
	if dir == String(_seq_keys[_seq_at]):
		(cells[_seq_at] as ArrowKey).state = 1
		(cells[_seq_at] as ArrowKey).queue_redraw()
		Sfx.play("ui-select")
		_seq_at += 1
		if _seq_at >= _seq_keys.size():
			_end_sequence(true)
	else:
		(cells[_seq_at] as ArrowKey).state = 2
		(cells[_seq_at] as ArrowKey).queue_redraw()
		_end_sequence(false)


func _end_sequence(ok: bool) -> void:
	if not _seq_active:
		return
	_seq_active = false
	_seq_panel.visible = false
	_pad.visible = false
	_seq_done.emit.call_deferred(ok)


func _unhandled_input(event: InputEvent) -> void:
	if _seq_active:
		var dir := ""
		if event.is_action_pressed("ui_left"):
			dir = "left"
		elif event.is_action_pressed("ui_right"):
			dir = "right"
		elif event.is_action_pressed("ui_up"):
			dir = "up"
		elif event.is_action_pressed("ui_down"):
			dir = "down"
		var key := event as InputEventKey
		if key != null and key.pressed and not key.echo:
			match key.physical_keycode:
				KEY_A:
					dir = "left"
				KEY_D:
					dir = "right"
				KEY_W:
					dir = "up"
				KEY_S:
					dir = "down"
		if dir != "":
			_seq_input(dir)
			get_viewport().set_input_as_handled()
		return
	if _menu_open and event.is_action_pressed("ui_cancel") and _actor != null:
		_show_menu(_actor, "main")
		get_viewport().set_input_as_handled()


# --- the enemy's turn --------------------------------------------------------------------------------------------

func _active_attacks() -> Array:
	if _phase >= 3 and def.has("phase3") and def["phase3"].has("attacks"):
		return (def["phase3"]["attacks"] as Dictionary).values()
	if _phase >= 2 and def.has("phase2") and def["phase2"].has("attacks"):
		return (def["phase2"]["attacks"] as Dictionary).values()
	return (def.get("attacks", {}) as Dictionary).values()


func _active_special() -> Dictionary:
	if _phase >= 3 and def.has("phase3") and def["phase3"].has("special"):
		return def["phase3"]["special"] as Dictionary
	if _phase >= 2 and def.has("phase2") and def["phase2"].has("special"):
		return def["phase2"]["special"] as Dictionary
	return def.get("special", {}) as Dictionary


func _foe_every(sp: Dictionary) -> int:
	if _phase >= 3 and def.has("phase3"):
		return int(def["phase3"].get("every", def.get("phase2", {}).get("every", sp.get("every", 3))))
	if _phase >= 2 and def.has("phase2"):
		return int(def["phase2"].get("every", sp.get("every", 3)))
	return int(sp.get("every", 3))


func _foe_turn() -> void:
	foe_turns += 1
	_last_hits.clear()
	if staggered:
		staggered = false
		stagger = 0
		_refresh()
	if bool(def.get("scripted_death_awaken", false)) and not awakened and _has("teo") and foe_turns >= 2:
		await _scripted_ambush_kill()
		foe_atb = 0.0
		_refresh()
		_acting = false
		return
	var sp := _active_special()
	if charging:
		charging = false
		await _special(sp)
	elif not sp.is_empty() and foe_turns % _foe_every(sp) == 0:
		charging = true
		_pose(_foe, _art("tell"))
		Sfx.play("boss-growl-02")
		Sfx.phase_shift()
		_map.battle_cam_focus(_foe_at, 26.8, 0.5)
		_banner("!", String(sp.get("tell", "")))
		_react_bystanders("tell", true)
		if Story.flags.get(String(def.get("tip_flag", "")), false):
			_tip.text = String(def.get("tip", ""))
			_tip.visible = true
		elif def.has("hint"):
			_tip.text = String(def["hint"])
			_tip.visible = true
		await _wait(1.6)
		_map.battle_cam_reset()
	else:
		if wired >= 2 and int(def.get("survive_turns", 0)) == 0:
			wire_jolts += 1
			Sfx.play("stagger-break")
			FxBurst.play(self, "spark", _foe_head() + Vector2(0, 40), Color("8fe3ff"), 1.0)
			_say("Kardo's clamped wires bite back mid-swing!")
			_hurt_foe(4, false, {"no_stagger_mult": true, "no_stagger_build": true})
			if _over:
				return
			await _wait(0.45)
		var attacks := _active_attacks()
		var a: Dictionary = attacks[(foe_turns - 1) % attacks.size()] if fast else attacks[randi() % attacks.size()]
		await _strike(a)
	if _over:
		return
	var survive := int(def.get("survive_turns", 0))
	if survive > 0:
		if foe_turns >= survive:
			_win("outlasted")
			return
		_say("Hold on. More are rising. (%d)" % (survive - foe_turns))
		await _wait(0.8)
	foe_atb = 0.0
	_refresh()
	_acting = false


func _scripted_ambush_kill() -> void:
	var teo := unit("teo")
	if teo == null or _over:
		return
	_tip.visible = false
	charging = false
	_foe_moving = true
	_pose(_foe, _art("wail"))
	_map.battle_cam_shot(_foe_at, Vector3(0.75, -0.65, -1.7), 23.2, 0.85, 8.5, -2.5)
	Sfx.play("boss-growl-08")
	await _cut_in_tex(_foe_portrait(), "SAKMAL", "NO ESCAPE IN THE DARK", Color("ff3848"), true)
	_banner("SAKMAL", "The aswang drops from your blind side!")
	_say("It hooks the rusted catwalk overhead and drops straight onto Teo's chest!")
	await _wait(0.55)
	await _foe_lunge(teo, {"anim": "swoop"}, "swoop", false)
	_foe_impact_fx(teo, "swoop", true)
	var lethal := maxi(teo.hp, 48)
	_hurt_member(teo, lethal, true, false)
	if _pending_scripted_awaken:
		_pending_scripted_awaken = false
		await _trigger_scripted_death_awakening()
	await _step_back_foe()


func _target() -> Unit:
	var alive: Array = []
	for u in party:
		if (u as Unit).alive():
			alive.append(u)
	if alive.is_empty():
		return null
	return alive[0] if fast else alive[randi() % alive.size()]


func _foe_anim_kind(a: Dictionary) -> String:
	var explicit := String(a.get("anim", ""))
	if explicit != "":
		return explicit
	var nm := String(a.get("name", "")).to_lower()
	if nm.contains("spark") or nm.contains("burst") or enemy_id == "hiraya_hound":
		return "spark"
	if _floats() or nm.contains("lunge") or nm.contains("swoop") or nm.contains("dive") or nm.contains("pounce"):
		return "swoop"
	if bool(a.get("dodge", false)):
		return "sweep"
	return "slash"


## An ordinary attack: one to three rings, each on someone in the party. PARRY halves it (a perfect parry opens a
## counter); a dodge-only attack (water, a net) is avoided whole or not at all. Every ring features full HD-2D enemy motion.
func _strike(a: Dictionary) -> void:
	_say(String(a.get("text", "")))
	await _wait(0.45)
	_banner(String(a.get("name", "")), "")
	var dodge := bool(a.get("dodge", false))
	var rings := int(a.get("rings", 1))
	var kind := _foe_anim_kind(a)
	for i in rings:
		var t := _target()
		if t == null or _over:
			return
		while true: # once more for every blow the watch takes back
			_foe_moving = true
			_pose(_foe, _art("claw"))
			_map.battle_cam_shot(t.home - Vector2(0.8, 0.0), Vector3(0.65, -0.35, -1.1), 25.8, 0.55, 7.5, -1.2)
			_windup(float(a.get("seconds", 1.3)), a)
			var grade := await _ring_grade("DODGE!" if dodge else "PARRY!", float(a.get("seconds", 1.3)), dodge)
			var dmg := int(round(float(a.get("damage", 12)) * _foe_dmg_mult))
			await _foe_lunge(t, a, kind, dodge and grade != "miss")
			if dodge and grade != "miss":
				Story.parries += 1
				Sfx.play("dodge-swish-9")
				if not fast:
					_dodge_evade(t)
					FxBurst.play(self, "ring", _head(t) + Vector2(0, 38), Color("9ad7ff"), 0.95)
				_number("DODGED!", _head(t), Color("9ad7ff"), true)
				_add_stagger_pct(0.12)
			elif grade == "perfect":
				Story.perfects += 1
				Story.parries += 1
				_charge_watch(1 + int(_amulet.get("energy_per_perfect", 0)))
				Sfx.play("dodge-swish-1")
				_pose(t.node, t.art("guard"))
				_hitstop(0.055)
				if not fast:
					FxBurst.play(self, "ring", _head(t) + Vector2(0, 40), Color("7dff9a"), 1.25)
					FxBurst.play(self, "spark", _head(t) + Vector2(0, 44), Color("b8ffd0"), 1.0)
				_foe_stagger_recoil()
				_number("PERFECT PARRY!", _head(t), Color("7dff9a"), true)
				_add_stagger_pct(0.30)
				_react_bystanders("awe", false)
				if t.id == "teo" and int(_amulet.get("heal_on_perfect", 0)) > 0 and t.alive():
					var ah := mini(int(_amulet["heal_on_perfect"]), t.max_hp - t.hp)
					t.hp += ah
					if ah > 0:
						_number("+%d" % ah, _head(t) + Vector2(0, -32), Color("7dff9a"))
				await _wait(0.28)
				_say("A gap in its guard! %s counters." % String(t.d["name"]).capitalize())
				await _step_back_foe()
				await _lunge(t, 0.14, true)
				var cbonus := int(_amulet.get("counter_bonus", 0)) if t.id == "teo" else 0
				_hurt_foe(int(t.d["hit"][1]) + 3 + int(t.mods.get("hit", 0)) + cbonus, true, {"stagger_pct": 0.12})
				await _wait(0.25)
				await _step_back(t)
				break
			elif grade == "good":
				Story.parries += 1
				_foe_impact_fx(t, kind, false)
				_hurt_member(t, dmg / 2, false)
				if _pending_scripted_awaken:
					_pending_scripted_awaken = false
					await _trigger_scripted_death_awakening()
					await _step_back_foe()
					return
				_add_stagger_pct(0.10)
			else:
				Story.misses += 1
				_foe_impact_fx(t, kind, true)
				var before := t.hp
				_hurt_member(t, dmg, true, true)
				if _pending_scripted_awaken:
					_pending_scripted_awaken = false
					await _trigger_scripted_death_awakening()
					await _step_back_foe()
					return
				if await _offer_rewind({t: before - t.hp}):
					continue
				if _pending_loss:
					_lose()
					return
			if i < rings - 1:
				await _foe_combo_reposition(t)
			else:
				await _wait(0.28)
				await _step_back_foe()
			break


## The enemy coils back, drops low or rises onto its wings while the ring closes.
func _windup(seconds: float, a: Dictionary = {}) -> void:
	if _foe == null or not is_instance_valid(_foe):
		return
	_foe_moving = true
	var kind := _foe_anim_kind(a)
	var k := 0.06 if fast else clampf(seconds * 0.65, 0.18, 0.85)
	var base_y := _hover_y()
	var rise := base_y + (0.28 if kind == "swoop" else (0.08 if _floats() else -0.02))
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_foe, "position:x", _foe_at.x - 0.55, k).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_foe, "position:y", rise, k).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_foe, "scale", Vector3(1.13, 0.87, 1.0), k)
	tw.tween_property(_foe, "rotation_degrees:z", 8.0, k)


## Enemy HD-2D dash/dive toward target with arc height, tilt, squash-and-stretch, afterimages, and camera punch.
func _foe_lunge(t: Unit, _a: Dictionary, kind: String, whiffed: bool) -> void:
	if _foe == null or not is_instance_valid(_foe):
		return
	_foe_moving = true
	var dur := 0.04 if fast else (0.19 if kind == "swoop" else 0.16)
	var dest_x := t.home.x - (1.0 if whiffed else 1.35)
	var land_y := _hover_y() + (0.14 if kind == "swoop" and _floats() else 0.0)
	var peak := maxf(_foe.position.y, land_y) + (0.48 if kind == "swoop" else 0.22)
	if not fast:
		_map.battle_cam_shot(t.home - Vector2(0.55, 0.0), Vector3(0.85, -0.42, -1.25), 24.4, 0.72, 9.5, -2.0)
		Sfx.play("air-whoosh" if kind == "swoop" else "boss-growl-02")
		for n in 3:
			get_tree().create_timer(dur * (0.12 + 0.26 * n)).timeout.connect(func() -> void: _afterimage(_foe))
	var tw := create_tween()
	tw.tween_property(_foe, "position:x", dest_x, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_foe, "scale", Vector3(1.18, 0.88, 1.0), dur * 0.5)
	tw.parallel().tween_property(_foe, "rotation_degrees:z", -9.0, dur * 0.65)
	tw.parallel().tween_property(_foe, "position:y", peak, dur * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_foe, "position:y", land_y, dur * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	var snap := create_tween()
	snap.tween_property(_foe, "scale", Vector3(0.92, 1.08, 1.0), 0.02 if fast else 0.05)
	snap.parallel().tween_property(_foe, "rotation_degrees:z", 0.0, 0.02 if fast else 0.06)
	snap.tween_property(_foe, "scale", Vector3.ONE, 0.02 if fast else 0.07)


func _foe_impact_fx(t: Unit, kind: String, heavy: bool) -> void:
	if fast:
		return
	var at := _head(t) + Vector2(-8, 42)
	match kind:
		"spark":
			FxBurst.play(self, "lightning", at, Color("ff6aff") if _phase >= 3 else Color("ff9e5a"), 1.3 if heavy else 0.9)
			FxBurst.play(self, "spark", at, Color("ffd27a"), 1.1 if heavy else 0.75)
		"sweep":
			FxBurst.play(self, "shockwave" if heavy else "ring", at, Color("7fd0c0"), 1.25 if heavy else 0.9)
		"swoop":
			FxBurst.play(self, "cross_slash" if heavy else "slash", at, Color("ff7a6a"), 1.25 if heavy else 0.95, -0.35)
			FxBurst.play(self, "spark", at, Color("ffe08a"), 1.0 if heavy else 0.7)
		_:
			FxBurst.play(self, "slash", at, Color("ff9888"), 1.15 if heavy else 0.85, 0.3)
			FxBurst.play(self, "spark", at, Color("ffd27a"), 0.85)


func _dodge_evade(t: Unit) -> void:
	if t == null or t.node == null:
		return
	t.moving = true
	_pose(t.node, t.art("guard"))
	var tw := create_tween()
	tw.tween_property(t.node, "position:x", t.home.x + 0.45, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(t.node, "position:y", 0.28, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(t.node, "position:x", t.home.x, 0.18).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(t.node, "position:y", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		t.moving = false
		if t.alive() and not _over:
			_pose(t.node, t.art("ready")))


func _foe_stagger_recoil() -> void:
	if _foe == null or not is_instance_valid(_foe):
		return
	_pose(_foe, _art("hurt"))
	var st := create_tween().set_parallel(true)
	st.tween_property(_foe, "position:x", _foe.position.x - 0.5, 0.04 if fast else 0.09)
	st.tween_property(_foe, "rotation_degrees:z", 12.0, 0.04 if fast else 0.09)
	st.tween_property(_foe, "scale", Vector3(1.12, 0.88, 1.0), 0.04 if fast else 0.09)


func _foe_combo_reposition(t: Unit) -> void:
	if _foe == null or not is_instance_valid(_foe):
		return
	var mid_x := lerpf(_foe_at.x, t.home.x - 1.4, 0.35)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_foe, "position:x", mid_x, 0.03 if fast else 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_foe, "position:y", _hover_y() + 0.18, 0.03 if fast else 0.11)
	tw.tween_property(_foe, "rotation_degrees:z", 5.0, 0.03 if fast else 0.11)
	await tw.finished


func _step_back_foe() -> void:
	_map.battle_cam_reset()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_foe, "position:x", _foe_at.x, 0.04 if fast else 0.28).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_foe, "position:y", _hover_y(), 0.04 if fast else 0.24).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_foe, "rotation_degrees:z", 0.0, 0.04 if fast else 0.22)
	tw.tween_property(_foe, "scale", Vector3.ONE, 0.04 if fast else 0.22)
	await tw.finished
	_foe_moving = false
	if not _over:
		_pose(_foe, _art("tell") if charging else _art("idle"))


## The line under the victory banner: how cleanly it went, and what is left for the next one.
func _tally() -> String:
	var bits: Array = ["PERFECT PARRIES %d" % (Story.perfects - _perfects_at_start)]
	if staggers > 0:
		bits.append("STAGGERS %d" % staggers)
	if rewinds > 0:
		bits.append("REWINDS %d" % rewinds)
	if _fresh_candles() > 0:
		bits.append("CANDLES LEFT %d" % candles)
	if overcharges > 0:
		bits.append("OVERCHARGES %d" % overcharges)
	return "   ·   ".join(bits)


## Who carries the watch in this fight: Lolo Pido in 1998, Teo once it has woken. Null: no REWIND.
func _bearer() -> Unit:
	var pido := unit("pido")
	if pido != null and pido.alive():
		return pido
	var teo := unit("teo")
	if teo != null and awakened and teo.alive():
		return teo
	if teo != null and awakened and _pending_loss:
		return teo # it ticks for him even as he falls
	return null


func _rewind_ready() -> bool:
	return watch_charge > 0 and (unit("pido") != null or (unit("teo") != null and awakened))


## A perfect parry winds the watch: more REWIND charges, up to WATCH_MAX.
func _charge_watch(amount: int = 1) -> void:
	if (unit("pido") != null or (unit("teo") != null and awakened)) and watch_charge < WATCH_MAX:
		var gain := mini(amount, WATCH_MAX - watch_charge)
		watch_charge += gain
		_number("REWIND +%d" % gain, _foe_head() + Vector2(0, -70), Color("00ffcc"))
		_refresh()


## REWIND, as a reaction: a blow has just landed; the moment freezes and the watch offers to take it back. HOLD, and
## the blow plays backward (the HP returns, the fallen stand) and the same ring comes again. Teo's watch writes it
## down (+1 utang); in 1998 it is Lolo Pido's to spend. `lost`: {Unit: HP that blow took}.
func _offer_rewind(lost: Dictionary) -> bool:
	var total := 0
	for u in lost:
		total += int(lost[u])
	var b := _bearer()
	if total <= 0 or b == null or watch_charge <= 0:
		return false
	var first: bool = not Story.flags.get("rewind_taught", false)
	Story.flags["rewind_taught"] = true
	if not fast:
		Sfx.watch_tick()
	_pose(b.node, b.art("wind") if b.id == "pido" else b.art("pray"))
	var r := await _gauge_play("react", "REWIND?", ("Missed it? The watch can take that blow back. HOLD before the light runs out." if first else "TAKE IT BACK  (x%d left)" % watch_charge), Color("00ffcc"))
	if not bool(r.get("ok", false)):
		_pose(b.node, b.art("ready") if b.alive() else b.art("down"))
		return false
	watch_charge -= 1
	rewinds += 1
	_pending_loss = false
	Sfx.play("command-exit")
	_flash_color(Color("00ffcc"), 0.45)
	FxBurst.play(self, "clock", _head(b) + Vector2(0, 60), Color("00ffcc"))
	_say("The hands run backward. The blow unhappens.")
	# The blow plays backward: the enemy slides back to where it stood, the HP climbs back up.
	var tw := create_tween()
	tw.tween_property(_foe, "position:x", _foe_at.x, 0.05 if fast else 0.45).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_foe, "position:y", _hover_y(), 0.05 if fast else 0.45).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_foe, "rotation_degrees:z", 0.0, 0.05 if fast else 0.35)
	tw.parallel().tween_property(_foe, "scale", Vector3.ONE, 0.05 if fast else 0.35)
	for u in lost:
		var m: Unit = u
		var back := int(lost[u])
		_number("-%d" % back, _head(m), Color("00ffcc"), true)
		var from := m.hp
		tw.parallel().tween_method(func(v: float) -> void:
			m.hp = int(round(v))
			m.hp_label.text = "%d / %d" % [m.hp, m.max_hp], float(from), float(from + back), 0.05 if fast else 0.45)
		_last_hits[m.id] = maxi(0, int(_last_hits.get(m.id, 0)) - back)
	await tw.finished
	_foe_moving = false
	for u in lost:
		var m: Unit = u
		m.hp = mini(m.max_hp, m.hp)
		if m.status.text == "DOWN":
			m.status.text = ""
		_pose(m.node, m.art("ready"))
	_pose(_foe, _art("idle"))
	if b.id != "pido":
		Story.add_utang(1, "The watch takes the blow back. +1 utang")
	_refresh()
	await _wait(0.35)
	return true


## The signature move. Its effect: "spellbound" (the hit one loses a turn), "all" (one ring, everyone is hit), or none.
func _special(sp: Dictionary) -> void:
	_tip.visible = false
	_foe_moving = true
	_pose(_foe, _art("wail"))
	var accent := Color("e866ff") if _phase >= 3 else Color("ff4a5a")
	_map.battle_cam_shot(_foe_at, Vector3(0.75, -0.65, -1.7), 23.2, 0.85, 8.5, -2.5)
	Sfx.play("boss-growl-08")
	var coil := create_tween().set_parallel(true)
	coil.tween_property(_foe, "position:y", _hover_y() + 0.32, 0.04 if fast else 0.28).set_trans(Tween.TRANS_SINE)
	coil.tween_property(_foe, "scale", Vector3(1.14, 0.88, 1.0), 0.04 if fast else 0.25)
	await _cut_in_tex(_foe_portrait(), String(sp.get("name", "")), String(sp.get("gloss", "")), accent, true)
	_banner(String(sp.get("name", "")), String(sp.get("gloss", "")))
	_say(String(sp.get("text", "")))
	if not fast:
		FxBurst.play(self, "lightning" if String(sp.get("anim", "")) == "spark" else "shockwave", _foe_head() + Vector2(0, 50), accent, 1.65)
	_shake(6.0)
	await _wait(0.45)
	_map.battle_cam_reset()
	var effect := String(sp.get("effect", "spellbound"))
	var targets: Array = []
	if effect == "all":
		for u in party:
			if (u as Unit).alive():
				targets.append(u)
	else:
		var t := _target()
		if t != null:
			targets.append(t)
	var dodge := bool(sp.get("dodge", true))
	var sp_kind := String(sp.get("anim", "swoop" if (not dodge or _floats()) else "sweep"))
	var grade := await _ring_grade("DODGE!" if dodge else "PARRY!", float(sp.get("seconds", 1.0)), dodge)
	while true:
		var anchor: Unit = targets[0] if not targets.is_empty() else null
		if anchor != null:
			_pose(_foe, _art("claw"))
			var target_x := 11.2 if effect == "all" else (anchor.home.x - 1.45)
			if not fast:
				for n in 3:
					get_tree().create_timer(0.05 * n).timeout.connect(func() -> void: _afterimage(_foe))
			var rush := create_tween()
			rush.tween_property(_foe, "position:x", target_x, 0.04 if fast else 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			rush.parallel().tween_property(_foe, "rotation_degrees:z", -10.0, 0.04 if fast else 0.16)
			rush.parallel().tween_property(_foe, "position:y", _hover_y() + 0.55, 0.02 if fast else 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			rush.tween_property(_foe, "position:y", _hover_y(), 0.02 if fast else 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			await rush.finished
		if grade != "miss":
			break
		var before := {}
		for t in targets:
			before[t] = (t as Unit).hp
		Story.misses += 1
		for t in targets:
			_foe_impact_fx(t, sp_kind, true)
			_hurt_member(t, int(round(float(sp.get("damage", 20)) * _foe_dmg_mult)), true, true)
		if _pending_scripted_awaken:
			_pending_scripted_awaken = false
			await _trigger_scripted_death_awakening()
			await _step_back_foe()
			return
		var lost := {}
		for t in targets:
			lost[t] = int(before[t]) - (t as Unit).hp
		if not await _offer_rewind(lost):
			if _pending_loss:
				_lose()
				return
			for t in targets:
				var u: Unit = t
				if effect == "spellbound" and u.alive():
					u.spellbound = true
					u.status.text = "SPELLBOUND"
			_say(String(sp.get("hit", "")))
			await _wait(0.75)
			await _step_back_foe()
			return
		_pose(_foe, _art("wail"))
		grade = await _ring_grade("DODGE!" if dodge else "PARRY!", float(sp.get("seconds", 1.0)), dodge)
	if grade != "miss" and dodge:
		Sfx.play("dodge-swish-9")
		for t in targets:
			if not fast:
				_dodge_evade(t)
			_number("DODGED!", _head(t), Color("9ad7ff"), true)
		_add_stagger_pct(0.12)
		_say(String(sp.get("dodged", "Out of the way, just in time.")))
	elif grade == "perfect" and not dodge:
		Story.perfects += 1
		Story.parries += 1
		_charge_watch(1 + int(_amulet.get("energy_per_perfect", 0)))
		Sfx.play("dodge-swish-1")
		_hitstop(0.055)
		for t in targets:
			_pose((t as Unit).node, (t as Unit).art("guard"))
			if not fast:
				FxBurst.play(self, "ring", _head(t) + Vector2(0, 42), Color("7dff9a"), 1.35)
			_number("PARRIED!", _head(t), Color("7dff9a"), true)
		_foe_stagger_recoil()
		_add_stagger_pct(0.30)
		_say(String(sp.get("dodged", "Turned aside cleanly!")))
	else:
		Story.misses += 1
		for t in targets:
			var u: Unit = t
			var dmg := int(round(float(sp.get("damage", 20)) * _foe_dmg_mult))
			if grade == "good":
				dmg = dmg / 2
			_foe_impact_fx(u, sp_kind, grade != "good")
			_hurt_member(u, dmg, true)
			if effect == "spellbound" and u.alive():
				u.spellbound = true
				u.status.text = "SPELLBOUND"
		if _pending_scripted_awaken:
			_pending_scripted_awaken = false
			await _trigger_scripted_death_awakening()
			await _step_back_foe()
			return
		if grade == "good":
			_add_stagger_pct(0.10)
		_say(String(sp.get("hit", "")))
	await _wait(0.75)
	await _step_back_foe()


func _foe_portrait() -> Texture2D:
	var p := String(def.get("portrait", ""))
	var tex := Art.portrait(p) if p != "" else null
	return tex if tex != null else _tex(_art("wail"))


func _ring_grade(prompt: String, seconds: float, dodge: bool = false) -> String:
	if fast:
		await get_tree().process_frame
		if test_miss > 0:
			test_miss -= 1
			return "miss"
		return "good"
	var level := "assisted"
	var lesson := ""
	if dodge and not Story.flags.get("dodge_taught", false):
		lesson = DODGE_LESSON
		Story.flags["dodge_taught"] = true
	elif not dodge and not Story.flags.get("parry_taught", false):
		level = "guided"
		lesson = LESSON
		Story.flags["parry_taught"] = true
	var zone_bonus := 0.0 if dodge else float(_amulet.get("parry_zone", 0.0))
	_ring.start(prompt, seconds, level, lesson, zone_bonus)
	if demo and test_miss > 0 and level != "guided":
		test_miss -= 1 # review recordings (?miss=1): let this one land, to show REWIND
	elif demo:
		get_tree().create_timer(seconds * 0.82).timeout.connect(_ring.press)
	var g: String = await _ring.finished
	_ring.visible = false
	return g


func _hurt_member(u: Unit, dmg: int, heavy: bool, undoable: bool = false) -> void:
	if u.id == "teo" and _amulet.has("damage_taken_mult"):
		dmg = maxi(1, int(round(dmg * float(_amulet["damage_taken_mult"]))))
	if u.guarding:
		dmg = dmg / 2
	u.guarding = false
	u.hp = maxi(0, u.hp - dmg)
	_last_hits[u.id] = int(_last_hits.get(u.id, 0)) + dmg
	Sfx.play("hit-thud")
	_pose(u.node, u.art("down") if u.hp <= 0 else u.art("hurt"))
	_blink(u.node)
	if not u.moving:
		var kb := create_tween()
		kb.tween_property(u.node, "position:x", u.home.x + (0.45 if heavy else 0.25), 0.05 if fast else 0.07)
		kb.parallel().tween_property(u.node, "rotation_degrees:z", -7.0 if heavy else -4.0, 0.05 if fast else 0.07)
		kb.tween_property(u.node, "position:x", u.home.x, 0.05 if fast else 0.3).set_trans(Tween.TRANS_SINE)
		kb.parallel().tween_property(u.node, "rotation_degrees:z", 0.0, 0.05 if fast else 0.3)
	_number(str(dmg), _head(u), Color("ff8a7a"), heavy)
	_flash_color(Color(1, 0.2, 0.2), 0.25)
	if heavy:
		if not fast:
			FxBurst.play(self, "cross_slash", _head(u) + Vector2(0, 40), Color("ff6a4a"), 0.95, 0.3)
		_shake(10.0)
	if heavy or u.hp <= 0:
		_react_bystanders("hurt", false)
	_refresh()
	if u.hp <= 0:
		u.atb = 0.0
		u.status.text = "DOWN"
	var anyone := false
	for v in party:
		anyone = anyone or (v as Unit).alive()
	if not anyone:
		if bool(def.get("scripted_death_awaken", false)) and not awakened and _has("teo"):
			_pending_scripted_awaken = true
		elif undoable and _rewind_ready():
			_pending_loss = true # the watch may still take it back (_offer_rewind)
		else:
			_lose()


# --- the watch wakes & boss phase gates -------------------------------------------------------------------------------

func _check_gates() -> void:
	if _checking_gates or _waking or _over or foe_hp <= 0:
		return
	_checking_gates = true
	if not awakened and bool(def.get("awakens", false)) and not bool(def.get("scripted_death_awaken", false)) and _has("teo"):
		if float(foe_hp) / float(foe_max) <= float(def.get("awaken_below", 0.55)) + 0.0001:
			await _run_awakening(false)
	if not _over and foe_hp > 0:
		var ratio := float(foe_hp) / float(foe_max)
		if _phase < 2 and def.has("phase2"):
			var p2: Dictionary = def["phase2"]
			if ratio <= float(p2.get("below", 0.5)) + 0.0001:
				await _enter_phase(2, p2)
		if _phase < 3 and def.has("phase3") and not _over and foe_hp > 0:
			var p3: Dictionary = def["phase3"]
			if ratio <= float(p3.get("below", 0.25)) + 0.0001:
				await _enter_phase(3, p3)
	_checking_gates = false


func _trigger_scripted_death_awakening() -> void:
	if awakened or _over:
		return
	var bearer := unit("teo")
	if bearer == null:
		return
	_waking = true
	_pose(bearer.node, bearer.art("down"))
	_banner("TEO FALLS", "Everything tilts, and goes black.")
	_say("Cold water fills his boots. Everything in his chest goes quiet. Then — against his ribs — the watch ticks once.")
	_flash_color(Color("ff2a3a"), 0.75)
	if not fast:
		Sfx.cue("silence", 0.15)
	_map.battle_cam_shot(bearer.home, Vector3(0.6, -0.35, -1.2), 24.0, 0.75, 7.5, -2.2)
	await _wait(0.75)
	await _run_awakening(true)


func _run_awakening(from_death: bool = false) -> void:
	if awakened or (not bool(def.get("awakens", false)) and not bool(def.get("scripted_death_awaken", false))) or not _has("teo") or _over:
		return
	awakened = true
	watch_charge = maxi(watch_charge, 1)
	foe_floor = 0
	Story.flags["watch_awake"] = true
	Progress.unlock_skill("rewind", Story.loob, 1)
	_waking = true
	var bearer := unit("teo")
	_map.battle_cam_shot(bearer.home, Vector3(0.7, -0.5, -1.55), 23.2, 0.82, 8.0, 1.8)
	await _cut_in("teo", "THE WATCH AWAKENS", "NEW: REWIND. MISS A PARRY? HOLD TO TAKE IT BACK", Color("00ffcc"), false, "determined")
	bearer.haste = 1.5 # borrowed time: for the rest of this fight his time bar runs fast
	if from_death:
		bearer.mods["hit"] = int(bearer.mods.get("hit", 0)) + 5
		var h: Array = bearer.d["hit"]
		bearer.d["hit"] = [int(h[0]) + 5, int(h[1]) + 5]
		bearer.atb = 0.85
		if not fast:
			Sfx.cue(String(def.get("music", "battle")))
	_flash_color(Color.WHITE, 0.7)
	FxBurst.play(self, "ring", _head(bearer) + Vector2(0, 60), Color("00ffcc"), 1.6)
	FxBurst.play(self, "clock", _head(bearer) + Vector2(0, 30), Color("00ffcc"))
	_shake(12.0)
	Sfx.play("stagger-break-3tone")
	Story.consequence.emit("THE WATCH AWAKENS. New: REWIND. When a blow lands, HOLD to take it back. Perfect parries wind it.")
	for u in party:
		var m: Unit = u
		m.hp = m.max_hp
		m.status.text = ""
		_pose(m.node, m.art("ready"))
	bearer.status.text = "HASTE"
	Story.add_utang(2, "The watch borrows its first seconds for you: +2 utang")
	if from_death:
		_say("The watch hands snap backward! Teo gasps upright — one lock of hair bone-white, borrowed time burning in his veins!")
		if def.has("flee_below"):
			_banner("THE WATCH AWAKENS", "Turn the tables! Drive it back until it breaks!")
	else:
		_say("Something clicks in Teo's pocket. The hands turn backward, and every wound of this fight unwinds. The watch has awakened.")
	_react_bystanders("awakening", true)
	_refresh()
	await _wait(2.2)
	_map.battle_cam_reset()
	_waking = false


func _foe_speed() -> float:
	if _phase >= 3 and def.has("phase3"):
		return float(def["phase3"].get("speed", def.get("phase2", {}).get("speed", def.get("speed", 8))))
	if _phase >= 2 and def.has("phase2"):
		return float(def["phase2"].get("speed", def.get("speed", 8)))
	return float(def.get("speed", 8))


func _enter_phase(num: int, p: Dictionary) -> void:
	_phase = num
	_phase2 = num >= 2
	_phase3 = num >= 3
	stagger = 0
	staggered = false
	_waking = true
	_foe_dmg_mult = float(p.get("damage_mult", _foe_dmg_mult))
	if p.has("glow"):
		_foe_glow = String(p["glow"])
	var accent := Color(String(p.get("accent", "e866ff" if num >= 3 else "ff4a5a")))
	var will_float := bool(p.get("floats", _foe_floats))
	var lifted := will_float and not _foe_floats
	_foe_floats = will_float
	_map.battle_cam_shot(_foe_at, Vector3(0.85, -0.65, -1.75), 22.4 if num >= 3 else 22.8, 0.9, 8.8, -2.8 if num >= 3 else -2.5)
	if not fast:
		Sfx.phase_shift()
	_pose(_foe, _art("wail"))
	if lifted and _foe != null and is_instance_valid(_foe):
		_foe_moving = true
		await _take_off()
		var rise_tw := create_tween()
		rise_tw.tween_property(_foe, "position:y", _hover_y() + 0.36, 0.04 if fast else 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rise_tw.tween_property(_foe, "position:y", _hover_y(), 0.03 if fast else 0.2).set_trans(Tween.TRANS_SINE)
	await _cut_in_tex(_foe_portrait(), String(p.get("title", "PHASE %d" % num)), String(p.get("sub", "")), accent, true)
	_flash_color(accent, 0.55 if num >= 3 else 0.5)
	if not fast:
		var burst_pt := _foe_head() + Vector2(0, 56)
		FxBurst.play(self, "shockwave", burst_pt, accent, 1.9 if num >= 3 else 1.8)
		if String(p.get("fx", "")) == "lightning" or num >= 3:
			FxBurst.play(self, "lightning", burst_pt, accent, 2.0)
	if p.has("mood_light") and _fill_light != null:
		_fill_light.light_color = Color(String(p["mood_light"]))
		_fill_light.light_energy = float(p.get("mood_energy", _fill_light.light_energy))
	_shake(12.0 if num >= 3 else 10.0)
	Sfx.play("boss-growl-08")
	_say(String(p.get("text", "")))
	_react_bystanders("phase%d" % num, true)
	_refresh()
	await _wait(1.4)
	_foe_moving = false
	if not _over:
		_pose(_foe, _art("tell") if charging else _art("idle"))
	_map.battle_cam_reset()
	_waking = false


# --- endings -----------------------------------------------------------------------------------------------------

func _win(how: String) -> void:
	if _over:
		return
	_over = true
	outcome = how
	charging = false
	_cmd_panel.visible = false
	_tip.visible = false
	Story.flags["parry_taught"] = true
	Story.injury = 0
	if carry_wounds:
		var lead: Unit = party[0]
		Story.injury = lead.max_hp - lead.hp # the next wave starts where this one left off
	for u in party:
		if (u as Unit).alive():
			_pose((u as Unit).node, (u as Unit).art("win" if how != "outlasted" else "down"))
			if how != "outlasted":
				var m: Unit = u
				m.moving = true
				var hop := create_tween()
				hop.tween_property(m.node, "position:y", 0.35, 0.05 if fast else 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
				hop.tween_property(m.node, "position:y", 0.0, 0.05 if fast else 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	match how:
		"sent":
			Story.apply_effects(def.get("send_home", {}).get("fx", {}))
			_pose(_foe, _art("calm"))
			_banner("SENT HOME", String(def.get("sent_text", "Uwi ka na.")))
			if not fast:
				Sfx.sent_home()
			Sfx.cue("wake")
		"outlasted":
			_banner("HELD ON", String(def.get("victory", "")))
		"fled":
			Story.apply_effects(def.get("flee_fx", {}))
			_pose(_foe, _art("wail"))
			_banner("IT ESCAPES!", String(def.get("flee_text", "The beast breaks away into the night.")))
			if not fast:
				Sfx.play("boss-growl-08")
		_:
			Story.apply_effects(def.get("scatter_fx", {}))
			_banner("VICTORY", String(def.get("victory", "")))
	tally = _tally()
	_tip.text = tally
	_tip.visible = tally != ""
	_react_bystanders("win_" + how, true)
	await _wait(1.6)
	if how == "fled":
		await _take_off()
		var ftw := create_tween()
		ftw.tween_property(_foe, "position:x", _foe_at.x - 4.2, 0.65 if not fast else 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		ftw.parallel().tween_property(_foe, "position:y", 2.8, 0.65 if not fast else 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ftw.parallel().tween_method(func(a: float) -> void:
			(_foe.material_override as ShaderMaterial).set_shader_parameter("alpha", a), 1.0, 0.0, 0.65 if not fast else 0.05)
		_foe_light.visible = false
		if _foe_shadow != null:
			_foe_shadow.visible = false
		await ftw.finished
	elif how != "outlasted":
		_pose(_foe, _art("fade"))
		var tw := create_tween()
		tw.tween_property(_foe, "position:y", 1.2 if _spirit() else 0.0, 1.4 if not fast else 0.05)
		tw.parallel().tween_method(func(a: float) -> void:
			(_foe.material_override as ShaderMaterial).set_shader_parameter("alpha", a), 1.0, 0.0, 1.4 if not fast else 0.05)
		_foe_light.visible = false
		if _foe_shadow != null:
			_foe_shadow.visible = false
		await tw.finished
	await _wait(1.2)
	finished.emit(true)


func _lose() -> void:
	if _over:
		return
	_over = true
	outcome = "fell"
	Story.deaths += 1
	_cmd_panel.visible = false
	_seq_active = false
	if _gauge != null and _gauge.active:
		_gauge.active = false
		_gauge.visible = false
	_seq_panel.visible = false
	_pad.visible = false
	var lead: Unit = party[0]
	_banner("%s FALLS" % String(lead.d["name"]), "")
	_end_text.text = String(def.get("fell_text", "Everything tilts, and goes quiet."))
	await _wait(1.0)
	_end_box.visible = true
	(_end_box.get_child(1) as Button).grab_focus()


func _retry() -> void:
	_end_box.visible = false
	for u in party:
		var m: Unit = u
		m.hp = m.max_hp
		m.atb = 0.0
		m.items = 2
		m.guarding = false
		m.spellbound = false
		m.status.text = ""
		_pose(m.node, m.art("ready"))
	foe_hp = foe_max
	foe_atb = 0.0
	foe_turns = 0
	wired = 0
	charging = false
	stagger = 0
	staggered = false
	staggers = 0
	_checking_gates = false
	_pending_scripted_awaken = false
	_waking = false
	_phase = 1
	_phase2 = false
	_phase3 = false
	_foe_dmg_mult = 1.0
	_foe_floats = bool(def.get("floats", _spirit()))
	_foe_glow = String(def.get("glow", "9fc4ff"))
	_foe_moving = false
	_foe.position = Vector3(_foe_at.x, _hover_y(), _foe_at.y)
	_foe.rotation_degrees = Vector3.ZERO
	_foe.scale = Vector3.ONE
	(_foe.material_override as ShaderMaterial).set_shader_parameter("alpha", 1.0)
	if _foe_shadow != null:
		_foe_shadow.visible = true
	_foe_light.visible = true
	watch_charge = 1 if (awakened or _has("pido")) else 0
	candles = _fresh_candles()
	var flee_hp := int(ceil(float(foe_max) * float(def.get("flee_below", 0.0)))) if def.has("flee_below") else 0
	if bool(def.get("scripted_death_awaken", false)) and not awakened and _has("teo"):
		foe_floor = maxi(flee_hp + 1, int(ceil(float(foe_max) * 0.65)))
	elif int(def.get("survive_turns", 0)) > 0 or (bool(def.get("awakens", false)) and not awakened and _has("teo")):
		foe_floor = 1
	else:
		foe_floor = 0
	heat = 0
	summoned = false
	_pending_loss = false
	_bystander_cd = 0.0
	_bystander_barks_used.clear()
	_bystander_retreated.clear()
	last_bystander_anims.clear()
	for v in party:
		(v as Unit).tired = false
	_last_hits.clear()
	_over = false
	_pose(_foe, _art("idle"))
	_refresh()
	_begin()


# --- HUD -----------------------------------------------------------------------------------------------------------

func _window() -> PanelContainer:
	var p := Retro.window(16, 10)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(p)
	return p


func _label(font: Font, px: int, color: Color = Color("f2efe4")) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bar(color: Color, w: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, 12)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _build_hud() -> void:
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	# Top: the move name, as the old games showed it.
	_msg_panel = _window()
	_msg_panel.position = Vector2(340, 18)
	_msg_panel.custom_minimum_size = Vector2(600, 0)
	_msg = _label(Fonts.label(), 22)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg_panel.add_child(_msg)
	_msg_panel.visible = false

	_tip = _label(Fonts.body_italic(), 19, Color("ffe08a"))
	_tip.position = Vector2(340, 118)
	_tip.size = Vector2(600, 60)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.visible = false
	add_child(_tip)

	# Bottom left: the enemy, with a strength bar (and the line where it can be sent home).
	var foe_win := Retro.window(16, 7)
	foe_win.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(foe_win)
	foe_win.position = Vector2(24, 538)
	foe_win.custom_minimum_size = Vector2(470, 160)
	var fcol := VBoxContainer.new()
	fcol.add_theme_constant_override("separation", 2)
	foe_win.add_child(fcol)
	var fhead := HBoxContainer.new()
	fhead.add_theme_constant_override("separation", 10)
	fcol.add_child(fhead)
	_foe_name = _label(Fonts.label(), 20)
	_foe_name.text = String(def.get("name", "?"))
	_foe_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fhead.add_child(_foe_name)
	var kind := _label(Fonts.label_medium(), 13, Color(1, 1, 1, 0.65))
	kind.text = String(def.get("kind", ""))
	kind.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fhead.add_child(kind)
	_foe_bar = _bar(Color(String(def.get("bar", "9fc4ff"))), 420)
	_foe_bar.custom_minimum_size.y = 10
	_foe_bar.max_value = foe_max
	fcol.add_child(_foe_bar)
	_stagger_row = HBoxContainer.new()
	_stagger_row.name = "StaggerRow"
	_stagger_row.add_theme_constant_override("separation", 10)
	_stagger_row.visible = stagger_max > 0
	fcol.add_child(_stagger_row)
	_stagger_bar = _bar(Color("ffb84d"), 270)
	_stagger_bar.name = "StaggerBar"
	_stagger_bar.custom_minimum_size = Vector2(270, 7)
	_stagger_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stagger_bar.max_value = maxi(1, stagger_max)
	_stagger_row.add_child(_stagger_bar)
	_stagger_label = _label(Fonts.label_medium(), 12, Color("ffb84d"))
	_stagger_label.name = "StaggerLabel"
	_stagger_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stagger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stagger_row.add_child(_stagger_label)
	var sh: Dictionary = def.get("send_home", {})
	var note := _label(Fonts.label_medium(), 13, Color("ffe08a"))
	if not sh.is_empty():
		var mark := ColorRect.new()
		mark.color = Color("ffe08a")
		mark.size = Vector2(3, 18)
		mark.position = Vector2(420.0 * float(sh.get("below", 0.3)) - 1.0, -4)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_foe_bar.add_child(mark)
		note.text = "Below the gold line: pray UWI KA NA to send it home"
	elif int(def.get("survive_turns", 0)) > 0:
		note.text = "It cannot be beaten. Hold on for %d turns." % int(def["survive_turns"])
	elif _has("kardo"):
		note.add_theme_color_override("font_color", Color("8fe3ff"))
		note.text = "No wires on it yet"
	else:
		note.visible = false
	fcol.add_child(note)
	_wire_label = note

	# Bottom right: the party, one row each: name, HP, time bar, status.
	var pwin := _window()
	pwin.position = Vector2(510, 560)
	pwin.custom_minimum_size = Vector2(746, 138)
	var pcol := VBoxContainer.new()
	pcol.add_theme_constant_override("separation", 2 if party.size() > 2 else 8)
	pwin.add_child(pcol)
	var px := 26 if party.size() == 1 else (22 if party.size() == 2 else 19)
	for u in party:
		var m: Unit = u
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 22)
		pcol.add_child(row)
		m.name_label = _label(Fonts.label(), px)
		m.name_label.text = String(m.d["name"])
		m.name_label.custom_minimum_size = Vector2(170, 0)
		row.add_child(m.name_label)
		m.hp_label = _label(Fonts.label(), px)
		m.hp_label.custom_minimum_size = Vector2(150, 0)
		row.add_child(m.hp_label)
		var atb_col := VBoxContainer.new()
		atb_col.alignment = BoxContainer.ALIGNMENT_CENTER
		if party.size() == 1:
			var atb_l := _label(Fonts.label_medium(), 14, Color(1, 1, 1, 0.6))
			atb_l.text = "TIME"
			atb_col.add_child(atb_l)
		m.atb_bar = _bar(Color("ffd27a"), 220)
		atb_col.add_child(m.atb_bar)
		row.add_child(atb_col)
		m.status = _label(Fonts.label(), 17, Color("ff8aa0"))
		row.add_child(m.status)

	# What the party has left: REWINDs on the watch, candles for prayers, the dead's thanks.
	_res_label = _label(Fonts.label_medium(), 17, Color("8fffe6"))
	_res_label.position = Vector2(520, 528)
	_res_label.size = Vector2(730, 26)
	_res_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_res_label)

	# The command window opens between the fighters on a turn.
	_cmd_panel = _window()
	_cmd_panel.position = Vector2(470, 300)
	_cmd_panel.custom_minimum_size = Vector2(340, 0)
	var ccol := VBoxContainer.new()
	_cmd_panel.add_child(ccol)
	_cmd_title = _label(Fonts.label_medium(), 16, Retro.NAME)
	ccol.add_child(_cmd_title)
	_cmd_box = VBoxContainer.new()
	ccol.add_child(_cmd_box)
	_cmd_panel.visible = false

	# The prayer: arrows to enter before the bar runs out, and on-screen arrows for touch.
	_seq_panel = _window()
	_seq_panel.position = Vector2(390, 200)
	_seq_panel.custom_minimum_size = Vector2(500, 0)
	var scol := VBoxContainer.new()
	scol.add_theme_constant_override("separation", 10)
	_seq_panel.add_child(scol)
	_seq_title = _label(Fonts.display(), 30, Color("ffe08a"))
	_seq_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scol.add_child(_seq_title)
	_seq_row = HBoxContainer.new()
	_seq_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_seq_row.add_theme_constant_override("separation", 10)
	scol.add_child(_seq_row)
	_seq_bar = _bar(Color("ffe08a"), 460)
	scol.add_child(_seq_bar)
	var how := _label(Fonts.label_medium(), 15, Color(1, 1, 1, 0.7))
	how.text = "ARROWS / WASD / D-PAD, or tap the arrows"
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scol.add_child(how)
	_seq_panel.visible = false
	_pad = HBoxContainer.new()
	_pad.position = Vector2(420, 596) # over the bottom windows, clear of the fighters
	_pad.add_theme_constant_override("separation", 18)
	for d in ["left", "up", "down", "right"]:
		var b := Button.new()
		b.name = "Pad_" + d
		b.custom_minimum_size = Vector2(92, 92)
		b.focus_mode = Control.FOCUS_NONE
		var a := ArrowKey.new()
		a.dir = d
		a.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		a.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(a)
		var dd: String = d
		b.pressed.connect(func() -> void: _seq_input(dd))
		_pad.add_child(b)
	_pad.visible = false
	add_child(_pad)

	_ring = TimingRing.new()
	add_child(_ring)
	_gauge = SpecialGauge.new()
	add_child(_gauge)

	_end_box = VBoxContainer.new()
	_end_box.position = Vector2(490, 300)
	_end_box.add_theme_constant_override("separation", 12)
	_end_box.visible = false
	add_child(_end_box)
	_end_text = _label(Fonts.body_italic(), 20)
	_end_box.add_child(_end_text)
	var again := Button.new()
	again.name = "RetryButton"
	again.text = "TRY AGAIN"
	again.custom_minimum_size = Vector2(300, 64)
	again.add_theme_font_override("font", Fonts.display())
	again.add_theme_font_size_override("font_size", 28)
	Retro.style_button(again, 28)
	again.pressed.connect(_retry)
	_end_box.add_child(again)
	_refresh()


func _refresh() -> void:
	for u in party:
		var m: Unit = u
		m.hp_label.text = "%d / %d" % [m.hp, m.max_hp]
		m.hp_label.add_theme_color_override("font_color", Color("ff8a7a") if float(m.hp) / m.max_hp < DESPERATE else Color("f2efe4"))
	_foe_bar.value = foe_hp
	if _stagger_row != null:
		_stagger_row.visible = stagger_max > 0
		if stagger_max > 0:
			_stagger_bar.max_value = stagger_max
			_stagger_bar.value = float(stagger_max) * (1.0 - foe_atb) if staggered else float(stagger)
			var fill := _stagger_bar.get_theme_stylebox("fill") as StyleBoxFlat
			if fill != null:
				fill.bg_color = Color("00ffcc") if staggered else Color("ffb84d")
			if staggered:
				_stagger_label.text = "STAGGERED! 1.5x"
				_stagger_label.add_theme_color_override("font_color", Color("00ffcc"))
			else:
				var pct := int(round(100.0 * float(stagger) / float(stagger_max)))
				_stagger_label.text = "STAGGER %d%%" % pct
				_stagger_label.add_theme_color_override("font_color", Color("ffb84d"))
	if _res_label != null:
		var bits: Array = []
		if _rewind_ready() or awakened or _has("pido"):
			bits.append("REWIND x%d" % watch_charge)
		if _fresh_candles() > 0:
			bits.append("CANDLES %d" % candles)
		if Story.gratitude > 0 or _has("ising"):
			bits.append("UTANG NA LOOB %d" % Story.gratitude)
		if Story.utang > 0:
			bits.append("UTANG %d%s" % [Story.utang, " · WHITE STREAK" if Story.age_stage() > 0 else ""])
		_res_label.text = "     ".join(bits)
	if _has("kardo") and _wire_label != null:
		_wire_label.text = "WIRES ON IT: %d / %d" % [wired, _max_wires()] if wired > 0 else "No wires on it yet"
	if not _over and foe_hp < foe_max:
		_check_gates.call_deferred()


## A special move's cut-in, as the 16-bit games did it: the action freezes, a band sweeps across the screen, the
## fighter's portrait slides in big, and the move is named. Enemies come from the left, the party from the right.
func _cut_in(portrait: String, title: String, sub: String, accent: Color, from_left: bool, expr: String = "") -> void:
	await _cut_in_tex(Art.portrait(portrait, expr) if portrait != "" else null, title, sub, accent, from_left)


func _cut_in_dual(portrait_a: String, portrait_b: String, title: String, sub: String, accent: Color, expr_a: String = "", expr_b: String = "") -> void:
	var ta := Art.portrait(portrait_a, expr_a) if portrait_a != "" else null
	var tb := Art.portrait(portrait_b, expr_b) if portrait_b != "" else null
	await _cut_in_tex(ta, title, sub, accent, false, tb)


func _cut_in_tex(tex: Texture2D, title: String, sub: String, accent: Color, from_left: bool, tex2: Texture2D = null) -> void:
	cut_ins += 1
	if tex2 != null:
		dual_cut_ins += 1
	if fast:
		return
	var dual := tex2 != null
	var view := size if size.x > 0.0 else Vector2(1280, 720)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var band := Control.new()
	band.position = Vector2(-60, view.y * 0.5 - 110)
	band.size = Vector2(view.x + 120, 220)
	band.pivot_offset = band.size * 0.5
	band.rotation = deg_to_rad(-4.0 if from_left else 4.0)
	band.scale = Vector2(1, 0)
	root.add_child(band)
	var fill := TextureRect.new()
	fill.texture = Retro.gradient()
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	band.add_child(fill)
	for y in [0.0, 214.0]:
		var edge := ColorRect.new()
		edge.color = accent
		edge.position = Vector2(0, y)
		edge.size = Vector2(band.size.x, 6)
		band.add_child(edge)
	var psize := 228.0 if dual else 264.0
	var pic_x := 90.0 if from_left else band.size.x - 80.0 - psize
	var pic2: TextureRect = null
	var split_line: ColorRect = null
	var pic2_x := pic_x - 196.0
	if dual:
		split_line = ColorRect.new()
		split_line.color = accent
		split_line.position = Vector2(pic_x - 10.0, 10.0)
		split_line.size = Vector2(4.0, 200.0)
		split_line.modulate.a = 0.0
		band.add_child(split_line)
		pic2 = TextureRect.new()
		pic2.texture = tex2
		pic2.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic2.size = Vector2(psize, psize)
		pic2.flip_h = not from_left
		pic2.position = Vector2(pic2_x + 560.0, -56)
		band.add_child(pic2)
	var pic := TextureRect.new()
	pic.texture = tex
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size = Vector2(psize, psize)
	pic.flip_h = not from_left # busts face right; the party stands on the right and faces left
	pic.position = Vector2(pic_x + (-500.0 if from_left else 500.0), -20 if dual else -44)
	band.add_child(pic)
	var name_l := Retro.label(Fonts.display(), 54 if dual else 66, Color.WHITE)
	name_l.add_theme_constant_override("outline_size", 10)
	name_l.text = title
	name_l.size = Vector2(band.size.x - (660.0 if dual else 520.0), 90)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if from_left else HORIZONTAL_ALIGNMENT_RIGHT
	var text_x := 380.0 if from_left else (110.0 if dual else 140.0)
	name_l.position = Vector2(text_x + (300.0 if from_left else -300.0), 44)
	name_l.modulate.a = 0.0
	band.add_child(name_l)
	var sub_l := Retro.label(Fonts.label(), 24 if dual else 26, accent)
	sub_l.text = sub
	sub_l.size = name_l.size
	sub_l.horizontal_alignment = name_l.horizontal_alignment
	sub_l.position = Vector2(text_x, 134)
	sub_l.modulate.a = 0.0
	band.add_child(sub_l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dim, "color:a", 0.45, 0.12)
	tw.tween_property(band, "scale:y", 1.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pic, "position:x", pic_x, 0.26).set_delay(0.06).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if pic2 != null:
		tw.tween_property(pic2, "position:x", pic2_x, 0.26).set_delay(0.11).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if split_line != null:
		tw.tween_property(split_line, "modulate:a", 0.85, 0.18).set_delay(0.14)
	tw.tween_property(name_l, "position:x", text_x, 0.24).set_delay(0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(name_l, "modulate:a", 1.0, 0.16).set_delay(0.12)
	tw.tween_property(sub_l, "modulate:a", 1.0, 0.2).set_delay(0.3)
	await tw.finished
	_flash_color(accent, 0.25)
	await get_tree().create_timer(0.75).timeout
	var out := create_tween().set_parallel(true)
	out.tween_property(band, "scale:y", 0.0, 0.14)
	out.tween_property(dim, "color:a", 0.0, 0.16)
	out.tween_property(pic, "modulate:a", 0.0, 0.12)
	if pic2 != null:
		out.tween_property(pic2, "modulate:a", 0.0, 0.12)
	if split_line != null:
		out.tween_property(split_line, "modulate:a", 0.0, 0.12)
	await out.finished
	root.queue_free()


func _say(text: String) -> void:
	_msg.text = text
	_msg_panel.visible = text != ""


func _banner(title: String, sub: String) -> void:
	_say(title if sub == "" else "%s   %s" % [title, sub])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(0.02 if fast else seconds).timeout


func _screen(world: Vector3) -> Vector2:
	var k := (size if size.x > 0.0 else Vector2(1280, 720)) / _map.view_size()
	return _map.camera().unproject_position(world) * k


func _head(u: Unit) -> Vector2:
	return _screen(u.node.position + Vector3(0, 1.9, 0))


func _foe_head() -> Vector2:
	return _screen(_foe.position + Vector3(0, 2.4, 0))


func _number(text: String, at: Vector2, color: Color, big: bool = false) -> void:
	var l := _label(Fonts.display(), 44 if big else 34, color)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.text = text
	add_child(l)
	l.reset_size()
	l.position = at - Vector2(l.size.x * 0.5, 0)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 46, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tw.tween_callback(l.queue_free)


func _flash_color(c: Color, a: float) -> void:
	_flash.color = Color(c.r, c.g, c.b, a)
	create_tween().tween_property(_flash, "color:a", 0.0, 0.35)


func _shake(amount: float) -> void:
	var tw := create_tween()
	for i in 5:
		tw.tween_property(_map, "position", Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), 0.03)
	tw.tween_property(_map, "position", Vector2.ZERO, 0.04)


func _init_bystanders() -> void:
	_bystander_specs.clear()
	match enemy_id:
		"magbabalot":
			_bystander_specs = [
				{"id": "isko", "temper": "devout", "sprite": "balut", "at": [8.1, 3.4], "h": 1.4},
				{"id": "rudy", "temper": "filmer", "sprite": "trike", "at": [15.2, 4.9], "h": 1.5, "flip": true},
			]
			if not Story.flags.get("nonoy_warned", false):
				_bystander_specs.append({"id": "nonoy", "temper": "scared", "sprite": "kid", "at": [16.4, 3.6], "h": 1.15, "flip": true})
			else:
				_bystander_specs.append({"id": "domeng", "temper": "brave", "sprite": "domeng", "at": [12.4, 3.3], "h": 1.35})
		"ligaw_berto":
			_bystander_specs = [
				{"id": "nena", "temper": "devout", "sprite": "nena", "at": [8.4, 3.1], "h": 1.35},
				{"id": "domeng", "temper": "brave", "sprite": "domeng", "at": [4.2, 3.2], "h": 1.35},
				{"id": "cards_a", "temper": "scared", "sprite": "cards_a", "at": [5.5, 4.1], "h": 1.3},
			]
		"unsent", "aswang":
			_bystander_specs = [
				{"id": "tess", "temper": "scared", "sprite": "tess", "at": [11.7, 2.7], "h": 1.25},
				{"id": "celso", "temper": "filmer", "sprite": "celso", "at": [10.2, 5.0], "h": 1.65},
			]
			if not Story.flags.get("van_schedule", false):
				_bystander_specs.append({"id": "guard", "temper": "brave", "sprite": "guard", "at": [16.1, 6.7], "h": 1.65, "flip": true})
		"lunod", "lunod_tide":
			_bystander_specs = [
				{"id": "y_ising", "temper": "devout", "sprite": "ising", "at": [14.3, 2.7], "y": 0.6, "h": 1.25, "flip": true},
				{"id": "y_kardo", "temper": "brave", "sprite": "kardo", "at": [13.9, 3.4], "y": 0.35, "h": 1.65, "flip": true},
			]
	if not _bystander_specs.is_empty():
		_map.spawn_bystanders(_bystander_specs)


func _has_bystander(id: String) -> bool:
	for b in _bystander_specs:
		if String(b.get("id", "")) == id:
			return true
	return false


## How a crowd really takes a supernatural fight in Manila: nobody cheers. They freeze, then cross themselves and pray,
## pull back behind the chairs, or hold a phone up. One brave tito finds his voice only once it is clearly being won.
## Each bystander has a temper (devout | scared | filmer | brave); the event picks what each one does.
func _react_bystanders(event: String, force: bool = false) -> void:
	if _map == null or _bystander_specs.is_empty():
		return
	if event == "cheer":
		event = "awe"
	if not force and _bystander_cd > 0.0:
		return
	_bystander_cd = 0.05 if fast else 2.2
	bystander_reactions += 1
	var winning := foe_max > 0 and float(foe_hp) / float(foe_max) < BRAVE_AT
	for idx in _bystander_specs.size():
		var spec: Dictionary = _bystander_specs[idx]
		var bid := String(spec["id"])
		var r := _bystander_reaction(String(spec.get("temper", "scared")), event, winning)
		_map.bystander_react(bid, r[0], r[1], idx > 0)
		if r[2] and not _bystander_retreated.has(bid):
			_bystander_retreated[bid] = true
			_map.bystander_retreat(bid, _foe_at, 0.8)
		last_bystander_anims[bid] = r[0]
	var bark := {}
	if event == "awe" and winning:
		bark = _bystander_bark_for("brave")
	if bark.is_empty():
		bark = _bystander_bark_for(event)
	if not bark.is_empty():
		var bkey := "%s:%s" % [event, String(bark["id"])]
		if not _bystander_barks_used.has(bkey):
			_bystander_barks_used[bkey] = true
			_map.bystander_bark(String(bark["id"]), String(bark["text"]), Color(String(bark.get("color", "f2efe4"))))


## [anim, emote, backs away] for one temper and one event.
func _bystander_reaction(temper: String, event: String, winning: bool) -> Array:
	match event:
		"opening", "phase2", "phase3":
			match temper:
				"devout": return ["pray", "pray", false]
				"scared": return ["cower", "!", true]
				"filmer": return ["film", "!", false]
				_: return ["gasp", "!", false]
		"tell":
			match temper:
				"devout": return ["pray", "pray", false]
				"scared": return ["cower", "sweat", false]
				"filmer": return ["film", "sweat", false]
				_: return ["shout", "!", false]
		"awakening":
			return ["gasp", "!", false]
		"hurt":
			match temper:
				"devout": return ["pray", "sweat", false]
				"scared": return ["cower", "sweat", true]
				_: return ["flinch", "sweat", false]
		"awe": # a special lands: awe and fear, not applause
			match temper:
				"devout": return ["pray", "pray", false]
				"scared": return ["peek", "!", false]
				"filmer": return ["film", "!", false]
				_: return ["shout", "!", false] if winning else ["gasp", "!", false]
		"win_sent":
			return ["pray", "pray", false] if temper == "devout" else ["slump", "...", false]
		"win_fled":
			return ["gasp", "!", false]
		"win_scattered", "win_outlasted":
			if enemy_id == "magbabalot":
				return ["slump", "...", false]
			return ["pray", "pray", false] if temper == "devout" else ["nod", "...", false]
	return ["flinch", "!", false]


func _bystander_bark_for(event: String) -> Dictionary:
	match enemy_id:
		"magbabalot":
			match event:
				"opening":
					if _has_bystander("nonoy"):
						return {"id": "nonoy", "text": "Kuya Teo! Watch his basket!", "color": "ffe08a"}
					return {"id": "isko", "text": "Hold your ground, Teo!" if Story.flags.get("heard_isko", false) else "Don't answer him, bata!", "color": "ffe08a"}
				"tell":
					return {"id": "isko", "text": "He's calling! Pray a Hatid NOW!" if Story.flags.get("heard_isko", false) else "Cover your ears—don't answer!", "color": "ffb48a"}
				"awe":
					return {"id": "rudy", "text": "Susmaryosep... nakuha ko ba 'yon sa video?!", "color": "8fe3ff"}
				"brave":
					if _has_bystander("domeng"):
						return {"id": "domeng", "text": "Sige, iho! Tapusin mo na!", "color": "7dff9a"}
				"hurt":
					return {"id": "isko", "text": "Step back, Teo!", "color": "ff8a7a"}
				"win_sent":
					return {"id": "isko", "text": "Salamat, Teo. Andoy can go home.", "color": "7dff9a"}
				"win_scattered":
					return {"id": "isko", "text": "Scattered to smoke... pahinga na, pare.", "color": "d2cde8"}
		"ligaw_berto":
			match event:
				"opening":
					return {"id": "nena", "text": "Berto! Step away from the casket!" if Story.flags.get("promise_berto", false) else "Lord have mercy—lock the street door!", "color": "ffe08a"}
				"tell":
					return {"id": "domeng", "text": "The river's coming up his throat!", "color": "8fe3ff"}
				"phase2":
					return {"id": "nena", "text": "Lola Ising, look at his eyes!", "color": "ff8a7a"}
				"awe":
					return {"id": "nena", "text": "Diyos ko po... Santa Maria, Ina ng Diyos...", "color": "ffe08a"}
				"brave":
					return {"id": "domeng", "text": "Sige, Lola Ising! Keep praying—it's working!", "color": "7dff9a"}
				"hurt":
					return {"id": "nena", "text": "Watch the chairs!", "color": "ff8a7a"}
				"win_sent", "win_scattered":
					return {"id": "nena", "text": "Berto... he's breathing again.", "color": "7dff9a"}
		"unsent", "aswang":
			match event:
				"opening":
					if _has_bystander("guard"):
						return {"id": "guard", "text": "What the hell IS that—?!", "color": "ffb48a"}
					if Story.flags.get("heard_tess", false):
						return {"id": "tess", "text": "Teo! Keep clear of the pump!", "color": "ffe08a"}
					return {"id": "celso", "text": "Hold the line, kid!", "color": "8fe3ff"}
				"tell":
					return {"id": "tess", "text": "It's coiling—hit it hard!" if enemy_id == "aswang" else "They're pulling toward the creek!", "color": "ffb48a"}
				"awakening":
					return {"id": "celso", "text": "That watch... the rain just stopped!", "color": "00ffcc"}
				"phase2":
					return {"id": "tess", "text": "It's airborne—its ear tag is sparking red!", "color": "ff8a7a"}
				"phase3":
					return {"id": "celso", "text": "That Hiraya tag's overloading—finish it now!", "color": "e866ff"}
				"awe":
					return {"id": "celso", "text": "Diyos ko... is this even recording?!", "color": "8fe3ff"}
				"brave":
					if _has_bystander("guard"):
						return {"id": "guard", "text": "Sige, bata! Tapusin mo!", "color": "7dff9a"}
				"hurt":
					return {"id": "tess", "text": "Teo, get away from the bank!", "color": "ff8a7a"}
				"win_fled":
					return {"id": "celso", "text": "It bolted over the roof! Still wounded—call Kardo, NOW!", "color": "ffcf8a"}
				"win_sent", "win_scattered":
					return {"id": "celso", "text": "I'm calling Kardo's morgue line. Go!", "color": "8fe3ff"}
		"lunod", "lunod_tide":
			match event:
				"opening":
					return {"id": "y_ising", "text": "Pido! Get up the stairs!", "color": "ffe08a"}
				"tell":
					return {"id": "y_kardo", "text": "Tatay, the whole river's leaning on the door!", "color": "8fe3ff"}
				"hurt":
					return {"id": "y_ising", "text": "Pido! Hold on!", "color": "ff8a7a"}
				"awe":
					return {"id": "y_ising", "text": "Panginoon, ingatan Mo siya...", "color": "ffe08a"}
				"brave":
					return {"id": "y_kardo", "text": "Right there, Tay!", "color": "7dff9a"}
				"win_scattered", "win_outlasted":
					return {"id": "y_ising", "text": "There are still more under the boards...", "color": "d2cde8"}
	return {}


## An arrow drawn as a shape (the web fonts carry no arrow glyphs). state: 0 waiting, 1 entered, 2 wrong.
class ArrowKey extends Control:
	var dir := "up"
	var state := 0

	func _draw() -> void:
		var s := size
		var c := s * 0.5
		var r := minf(s.x, s.y) * 0.34
		var bg := Color(0, 0, 0, 0.35) if state == 0 else (Color("3c8f4f") if state == 1 else Color("a03030"))
		draw_rect(Rect2(Vector2(4, 4), s - Vector2(8, 8)), bg)
		var pts := PackedVector2Array([Vector2(0, -r), Vector2(r * 0.9, r * 0.2), Vector2(r * 0.35, r * 0.2), Vector2(r * 0.35, r), Vector2(-r * 0.35, r), Vector2(-r * 0.35, r * 0.2), Vector2(-r * 0.9, r * 0.2)])
		var ang := {"up": 0.0, "right": PI * 0.5, "down": PI, "left": -PI * 0.5}[dir] as float
		var out := PackedVector2Array()
		for p in pts:
			out.append(c + p.rotated(ang))
		draw_colored_polygon(out, Color("ffe08a") if state == 0 else Color.WHITE)
