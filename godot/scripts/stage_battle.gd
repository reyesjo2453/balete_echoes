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
const CANDLES := {"teo": 4, "pido": 5} # prayers burn candles: one each, TAWID two. Lit fresh every fight.
const HEAT_STEP := 0.1 # each KONTRA heats the line: the green and red start this much lower (cools a step a turn)
## Summons (TAWAG): a sundô who went before answers, once a fight. Lola calls on her own; Teo, from Episode 2, speaks
## a name Sol reads off the watch's heartwood, and that costs utang na loob (Story.gratitude).
const ANCESTORS := [
	{"id": "pido", "name": "PIDO DIMACULANGAN", "short": "LOLO PIDO", "art": "pidob", "move": "SUNDANG NG ORAS",
		"power": 32, "heal": 24, "lola": "Pido. The boy needs you. One more minute, mahal.",
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
var outcome := "" # "sent" | "scattered" | "outlasted" | "fell"
var interrupts := 0
var swift_prayers := 0
var cut_ins := 0 # how many special-move cut-ins played (tests)
var _last_hits: Dictionary = {} # unit id -> damage taken in the enemy's last turn (what Rewind gives back)
var _acting := false
var _over := false
var _menu_open := false
var _waking := false # the watch-awakening sequence holds time still
var _actor: Unit = null

var _map: ExploreMap
var _foe: Sprite3D
var _foe_light: OmniLight3D
var _foe_at := Vector2(9.2, 6.7)
var _foe_moving := false
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

signal _command(cmd: String)
signal _seq_done(ok: bool)


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
	_perfects_at_start = Story.perfects
	foe_max = int(def.get("hp", 120))
	foe_hp = foe_max
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
		u.hp = u.max_hp
		party.append(u)
	if not party.is_empty() and Story.injury > 0:
		var lead: Unit = party[0]
		lead.hp = maxi(20, lead.max_hp - Story.injury) # hurt going in (a failed QTE, or the last wave)
	awakened = Story.flags.get("watch_awake", false)
	watch_charge = 1 if (awakened or _has("pido")) else 0
	candles = _fresh_candles()
	foe_floor = 1 if (int(def.get("survive_turns", 0)) > 0 or (bool(def.get("awakens", false)) and not awakened and _has("teo"))) else 0


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


func _begin() -> void:
	_acting = true
	var lead: Unit = party[0]
	if lead.hp < lead.max_hp and Story.injury > 0:
		Story.consequence.emit("Hurt going in: %s starts the fight at %d HP" % [String(lead.d["name"]).capitalize(), lead.hp])
	_say(String(def.get("opening", "")))
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
	_foe.position = Vector3(_foe_at.x, 0.1 if _floats() else 0.0, _foe_at.y)
	_map.add_node(_foe)
	if not _floats():
		_map.blob(_foe_at, 1.4)
	# A soft fill on the party, so they read on the darkest maps (the creek at night).
	var fill := OmniLight3D.new()
	fill.light_color = Color(String(b.get("fill", "ffe2b8")))
	fill.light_energy = float(b.get("fill_energy", 0.9))
	fill.omni_range = 4.5
	fill.position = Vector3(lead_at.x + 0.8, 2.2, lead_at.y + 1.6)
	_map.add_node(fill)
	_foe_light = OmniLight3D.new()
	_foe_light.light_color = Color(String(def.get("glow", "9fc4ff")))
	_foe_light.light_energy = 1.2
	_foe_light.omni_range = 4.0
	_foe_light.position = Vector3(_foe_at.x, 1.4, _foe_at.y + 0.8)
	_map.add_node(_foe_light)


func _spirit() -> bool:
	return bool(def.get("spirit", false))


func _floats() -> bool:
	return bool(def.get("floats", _spirit()))


func _art(pose: String) -> String:
	return "%s_%s" % [String(def.get("art", "mag")), pose]


func _make_sprite(tex_name: String, ghost: bool) -> Sprite3D:
	var s := Sprite3D.new()
	var tex := _tex(tex_name)
	s.texture = tex
	s.pixel_size = PX
	s.material_override = _map._sprite_material(tex, ghost)
	if tex != null:
		s.offset = Vector2(0, tex.get_height() * 0.5)
	return s


func _tex(n: String) -> Texture2D:
	var p := "res://assets/explore/%s.png" % n
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


func _pose(s: Sprite3D, tex_name: String) -> void:
	var tex := _tex(tex_name)
	if tex == null or s == null:
		return
	s.texture = tex
	s.offset = Vector2(0, tex.get_height() * 0.5)
	(s.material_override as ShaderMaterial).set_shader_parameter("tex", tex)


func _process(delta: float) -> void:
	_t += delta
	if _foe != null and not _over:
		var idle := _foe.texture == _tex(_art("idle")) or _foe.texture == _tex(_art("idle_b"))
		if idle:
			_pose(_foe, _art("idle" if int(_t * 1.6) % 2 == 0 else "idle_b"))
		if _floats():
			_foe.position.y = 0.12 + sin(_t * 1.4) * 0.07
		_foe_light.light_color = Color("ff4050") if charging else Color(String(def.get("glow", "9fc4ff")))
		_foe_light.light_energy = (1.6 + sin(_t * 8.0) * 0.4) if charging else 1.2
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
	foe_atb = minf(1.0, foe_atb + delta * float(def.get("speed", 8)) * ATB_RATE * speed)
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
	u.name_label.add_theme_color_override("font_color", Retro.NAME)
	var cmd := await _choose(u)
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
	var interrupt: Array = def.get("special", {}).get("interrupt", ["prayer"])
	if cmds.has("orasyon"):
		var hurt := false
		for v in party:
			hurt = hurt or ((v as Unit).alive() and (float((v as Unit).hp) / (v as Unit).max_hp < 0.7 or (v as Unit).spellbound))
		if orasyons == 0:
			return "orasyon"
		if _usable(u, "tawag") and (charging or float(foe_hp) / foe_max < 0.6):
			return "tawag"
		return "orasyon" if hurt or charging or (_spirit() and foe_turns % 2 == 1) else "attack"
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


func _usable(u: Unit, cmd: String) -> bool:
	match cmd:
		"item":
			return u.items > 0
		"hatid":
			return candles > 0
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
	b.pressed.connect(func() -> void:
		Sfx.play("command-enter")
		if id == "hatid":
			_show_menu(u, "hatid")
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
		await _cut_in(u.id, desp, "DESPERATION MOVE", Color("ff6a4a"), false)
		for i in 3:
			await _lunge(u, 0.18)
			_hurt_foe(int(hit[0]) + 2 + randi() % 4, true)
			await _wait(0.12)
	else:
		_say("")
		await _lunge(u, 0.22)
		_hurt_foe(int(hit[0]) + randi() % (int(hit[1]) - int(hit[0]) + 1), false)
	await _wait(0.35)
	await _step_back(u)


## The attack, animated the 16-bit way: a crouch back (anticipation), a stretched dash with afterimages, a squash on
## the hit; _step_back brings them home.
func _lunge(u: Unit, seconds: float) -> void:
	u.moving = true
	var k := 0.2 if fast else 1.0
	var wind := create_tween()
	wind.tween_property(u.node, "position:x", u.home.x + 0.3, 0.09 * k).set_trans(Tween.TRANS_SINE)
	wind.parallel().tween_property(u.node, "scale", Vector3(1.1, 0.9, 1.0), 0.09 * k)
	await wind.finished
	_pose(u.node, u.art("slash"))
	var tw := create_tween()
	tw.tween_property(u.node, "position:x", _foe_at.x + 1.25, seconds * k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(u.node, "scale", Vector3(1.14, 0.92, 1.0), seconds * k * 0.5)
	if not fast:
		for n in 3:
			get_tree().create_timer(seconds * (0.15 + 0.22 * n)).timeout.connect(func() -> void: _afterimage(u.node))
	await tw.finished
	var land := create_tween()
	land.tween_property(u.node, "scale", Vector3(0.94, 1.06, 1.0), 0.05 * k)
	land.tween_property(u.node, "scale", Vector3.ONE, 0.08 * k)
	Sfx.play("hit-thud-metal" if u.id == "kardo" else "slash-knife")


func _step_back(u: Unit) -> void:
	_pose(u.node, u.art("ready"))
	var tw := create_tween()
	tw.tween_property(u.node, "position:x", u.home.x, 0.05 if fast else 0.28)
	tw.parallel().tween_property(u.node, "scale", Vector3.ONE, 0.05 if fast else 0.2)
	await tw.finished
	u.moving = false


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
	if _foe != null and not _floats() and not _foe_moving:
		var fb := sin(_t * (3.2 if charging else 1.8)) * (0.03 if charging else 0.018)
		_foe.scale = Vector3(1.0 - fb * 0.6, 1.0 + fb, 1.0)


func _hurt_foe(dmg: int, heavy: bool) -> void:
	if _over:
		return
	foe_hp = maxi(foe_floor, foe_hp - dmg)
	_number(str(dmg), _foe_head(), Color("ffffff"), heavy)
	_pose(_foe, _art("hurt"))
	_blink(_foe)
	var tw := create_tween()
	tw.tween_property(_foe, "position:x", _foe_at.x - 0.35, 0.06)
	tw.tween_property(_foe, "position:x", _foe_at.x, 0.2)
	tw.tween_callback(func() -> void:
		if not _over:
			_pose(_foe, _art("tell") if charging else _art("idle")))
	if heavy:
		_shake(8.0)
		if charging and def.get("special", {}).get("interrupt", ["prayer"]).has("heavy") and dmg >= 20:
			_interrupt("The blow knocks it off balance!")
	_refresh()
	if foe_hp <= 0:
		_win("scattered")


func _interrupt(text: String) -> void:
	charging = false
	interrupts += 1
	foe_atb = 0.0
	_tip.visible = false
	_say(text)
	_number("INTERRUPTED!", _foe_head() + Vector2(0, -40), Color("ffe08a"), true)


## Kardo clamps a wire on it: a little damage now, and one more wire for the discharge.
func _wire(u: Unit) -> void:
	_pose(u.node, u.art("pray"))
	Sfx.play("hit-thud-metal")
	wired = mini(_max_wires(), wired + 1)
	await _wait(0.3)
	_hurt_foe(6, false)
	_say("Kardo clamps a wire on it. Circuit: %d / %d." % [wired, _max_wires()])
	await _wait(0.6)


## KONTRA: every wire lights at once, on Kardo's hold-and-release (SpecialGauge "charge"). The more wires, the bigger
## the hit. Let go in the green: a clean circuit. In the red: OVERCHARGE, half again the damage, and the current comes
## back up the wire into Kardo. Held at the top too long, the breaker trips: a weak hit, and the full shock.
## It also shorts a machine's charge.
func _discharge(u: Unit) -> void:
	var stacks := wired
	wired = 0
	_pose(u.node, u.art("charge"))
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
	await _cut_in(u.id, "KONTRA" + ("!!" if z == "over" else ""), sub, Color("5ad8ff") if z != "over" else Color("ff6a4a"), false)
	_pose(u.node, u.art("burst"))
	Sfx.play("stagger-break")
	_flash_color(Color("5ad8ff") if z != "over" else Color.WHITE, 0.5 if z != "over" else 0.75)
	FxBurst.play(self, "spark", _foe_head() + Vector2(0, 60), Color("aef0ff"), 1.6 if z != "over" else 2.2)
	if charging and def.get("special", {}).get("interrupt", []).has("discharge") and z != "trip":
		_interrupt("The current shorts it out mid-charge!")
	_hurt_foe(int(round((14 + 16 * stacks) * mult)), stacks >= 2 or z == "over")
	shock = int(round(shock * float(u.mods.get("shock", 1.0))))
	if shock > 0 and not _over:
		await _wait(0.35)
		_pose(u.node, u.art("shock"))
		Sfx.play("stagger-break-3tone")
		FxBurst.play(self, "spark", _head(u) + Vector2(0, 50), Color("aef0ff"), 1.2)
		u.hp = maxi(1, u.hp - shock) # the shock never drops him: he has done this before
		_number(str(shock), _head(u), Color("8fe3ff"), true)
		_shake(7.0)
		_refresh()
	match z:
		"over":
			_say("The current comes back up the wire. Kardo's hair stands straight up. \"I'm fine. I'm fine. I can taste colours.\"")
		"trip":
			_say("Somewhere a breaker trips with a bang. Kardo sits down hard, smoking a little.")
		"weak":
			_say("Kardo lets go too soon. The wires spit, and only some of it reaches.")
		_:
			_say("Kardo closes the circuit: %d wire%s light up." % [stacks, "" if stacks == 1 else "s"])
	await _wait(0.9 if shock > 0 else 0.7)


## Lola's ORASYON (SpecialGauge "rhythm"): the old prayer, beat by beat. How well it is kept decides how much: it heals
## everyone and breaks a spell, hurts a spirit, and kept perfectly it stops a charging spell cold.
func _orasyon(u: Unit) -> void:
	orasyons += 1
	_pose(u.node, u.art("pray"))
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
	await _cut_in(u.id, "ORASYON" + ("!" if full else ""), "EVERY BEAT KEPT" if full else "%d OF %d BEATS" % [int(r.get("perfect", 0)) + int(r.get("good", 0)), int(r.get("notes", 6))], Color("ffd27a"), false)
	_pose(u.node, u.art("burst"))
	Sfx.play("heal-chime")
	_flash_color(Color(1.0, 0.92, 0.6), 0.4)
	FxBurst.play(self, "ring", _head(u) + Vector2(0, 60), Color("ffe08a"), 1.4)
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
	if _spirit():
		_hurt_foe(int(round(8 + 18 * score)), full)
	if charging and full:
		_interrupt("Every word lands on the beat. Whatever it was gathering scatters.")
	u.tired = true
	u.status.text = "TIRED"
	if not _over:
		_say("Lola prays the way her lola did, every word on the beat. Even the folding chairs seem to listen." if full else "Lola prays. The room gets a little warmer.")
	_refresh()
	await _wait(0.8)


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
	_say(String(anc["lola" if u.id == "ising" else "teo"]))
	await _wait(1.3)
	await _summon_card(anc, u)
	var lead: Unit = party[0]
	var g := _make_sprite(String(anc["art"]) + "_ready", true)
	g.position = Vector3(lead.home.x + 0.9, 0.0, lead.home.y - 0.5)
	_map.add_node(g)
	var mat := g.material_override as ShaderMaterial
	var tw := create_tween()
	tw.tween_method(func(a: float) -> void: mat.set_shader_parameter("alpha", a), 0.0, 0.85, 0.05 if fast else 0.6)
	await tw.finished
	_pose(g, String(anc["art"]) + "_slash")
	(g.material_override as ShaderMaterial).set_shader_parameter("alpha", 0.85)
	var go := create_tween()
	go.tween_property(g, "position:x", _foe_at.x + 1.2, 0.05 if fast else 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await go.finished
	Sfx.play("slash-knife")
	Sfx.play("stagger-break-3tone")
	_flash_color(Color.WHITE, 0.7)
	FxBurst.play(self, "ring", _foe_head() + Vector2(0, 60), Color("e8f4ff"), 2.0)
	_shake(12.0)
	if charging:
		_interrupt("The old sundô's blade cuts the call in half.")
	var power := int(anc["power"]) * (3 if _spirit() else 2) / 2
	if def.has("send_home"):
		power = mini(power, foe_hp - 1) # a sundô never scatters a soul that can still go home: that is left to Teo
	_hurt_foe(power, true)
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
	var out := create_tween()
	out.tween_method(func(a: float) -> void: mat.set_shader_parameter("alpha", a), 0.85, 0.0, 0.05 if fast else 0.9)
	await out.finished
	g.queue_free()
	await _wait(0.5)


## The full-screen call: the ferry's painting, the ancestor's whole name, and who called.
func _summon_card(anc: Dictionary, u: Unit) -> void:
	cut_ins += 1
	var card := Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a = 0.0
	add_child(card)
	var back := ColorRect.new()
	back.color = Color(0.01, 0.02, 0.05)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(back)
	var art := TextureRect.new()
	art.texture = Art.panel("ep1_33_hatid_boat")
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.modulate = Color(0.75, 0.85, 1.0)
	card.add_child(art)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.position = Vector2(0, 470)
	shade.size = Vector2(1280, 250)
	card.add_child(shade)
	var who := _label(Fonts.label_medium(), 20, Color(1, 1, 1, 0.8))
	who.text = ("LOLA ISING CALLS ON THE SUNDÔ BEFORE HER" if u.id == "ising" else "TEO SPEAKS A NAME FROM THE HEARTWOOD")
	who.position = Vector2(0, 500)
	who.size = Vector2(1280, 30)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(who)
	var name_l := _label(Fonts.display(), 64, Color("e8f4ff"))
	name_l.text = String(anc["name"])
	name_l.position = Vector2(0, 535)
	name_l.size = Vector2(1280, 80)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_l)
	var move := _label(Fonts.label(), 26, Color("ffe08a"))
	move.text = "TAWAG:  " + String(anc["move"])
	move.position = Vector2(0, 625)
	move.size = Vector2(1280, 40)
	move.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(move)
	Sfx.play("extra-chime")
	var tw := create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.05 if fast else 0.6)
	tw.parallel().tween_property(art, "scale", Vector2(1.06, 1.06), 0.05 if fast else 2.6)
	tw.tween_interval(0.05 if fast else 1.8)
	tw.tween_property(card, "modulate:a", 0.0, 0.05 if fast else 0.5)
	await tw.finished
	card.queue_free()


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
		"SWIFT PRAYER: POWER UP!" if swift else ("HATID II: " if tier2 else "HATID: ") + String(p["gloss"]).to_upper(), Color("ffd27a"), false)
	_pose(u.node, u.art("aura" if tier2 else "burst"))
	Sfx.play("extra-chime")
	_flash_color(Color(1.0, 0.92, 0.6), 0.55)
	FxBurst.play(self, "ring", _foe_head() + Vector2(0, 60), Color("ffe08a"), 1.6)
	FxBurst.play(self, "spark", _foe_head() + Vector2(0, 60), Color("fff3b0"), 1.4)
	await _wait(0.25)
	var sh: Dictionary = def.get("send_home", {})
	var reach := TAWID_REACH if tier2 else 0.0
	var low := not sh.is_empty() and float(foe_hp) / foe_max <= float(sh.get("below", 0.0)) + reach
	if (id == String(sh.get("prayer", "")) or tier2) and low and foe_floor == 0:
		_win("sent")
		return
	var power := int(p["power"]) * (3 if _spirit() else 2) / 2
	if swift:
		power = int(round(power * 1.35))
	if charging and def.get("special", {}).get("interrupt", ["prayer"]).has("prayer"):
		_interrupt(String(def.get("special", {}).get("interrupted", "The prayer drowns it out!")))
	_hurt_foe(power, true)
	if not _over and id == String(sh.get("prayer", "")) and not low:
		_say("Not ready to go. Weaken it first, then pray UWI KA NA.")
	await _wait(0.7)


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

func _foe_turn() -> void:
	foe_turns += 1
	_last_hits.clear()
	var sp: Dictionary = def.get("special", {})
	if charging:
		charging = false
		await _special(sp)
	elif not sp.is_empty() and foe_turns % int(sp.get("every", 3)) == 0:
		charging = true
		_pose(_foe, _art("tell"))
		Sfx.play("boss-growl-02")
		_banner("!", String(sp.get("tell", "")))
		if Story.flags.get(String(def.get("tip_flag", "")), false):
			_tip.text = String(def.get("tip", ""))
			_tip.visible = true
		elif def.has("hint"):
			_tip.text = String(def["hint"])
			_tip.visible = true
		await _wait(1.6)
	else:
		var attacks: Array = def.get("attacks", {}).values()
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


func _target() -> Unit:
	var alive: Array = []
	for u in party:
		if (u as Unit).alive():
			alive.append(u)
	if alive.is_empty():
		return null
	return alive[0] if fast else alive[randi() % alive.size()]


## An ordinary attack: one to three rings, each on someone in the party. PARRY halves it (a perfect parry opens a
## counter); a dodge-only attack (water, a net) is avoided whole or not at all.
func _strike(a: Dictionary) -> void:
	_say(String(a.get("text", "")))
	await _wait(0.5)
	_banner(String(a.get("name", "")), "")
	var dodge := bool(a.get("dodge", false))
	for i in int(a.get("rings", 1)):
		var t := _target()
		if t == null or _over:
			return
		while true: # once more for every blow the watch takes back
			_pose(_foe, _art("claw"))
			_windup(float(a.get("seconds", 1.3)))
			var grade := await _ring_grade("DODGE!" if dodge else "PARRY!", float(a.get("seconds", 1.3)), dodge)
			var dmg := int(a.get("damage", 12))
			var tw := create_tween()
			tw.tween_property(_foe, "position:x", t.home.x - 1.4, 0.05 if fast else 0.16)
			await tw.finished
			if dodge and grade != "miss":
				Story.parries += 1
				Sfx.play("dodge-swish-9")
				_number("DODGED!", _head(t), Color("9ad7ff"), true)
			elif grade == "perfect":
				Story.perfects += 1
				Story.parries += 1
				_charge_watch()
				Sfx.play("dodge-swish-1")
				_pose(t.node, t.art("guard"))
				_number("PERFECT PARRY!", _head(t), Color("7dff9a"), true)
				await _wait(0.3)
				_say("A gap in its guard! %s counters." % String(t.d["name"]).capitalize())
				await _step_back_foe()
				await _lunge(t, 0.14)
				_hurt_foe(int(t.d["hit"][1]) + 3 + int(t.mods.get("hit", 0)), true)
				await _wait(0.25)
				await _step_back(t)
				break
			elif grade == "good":
				Story.parries += 1
				_hurt_member(t, dmg / 2, false)
			else:
				Story.misses += 1
				var before := t.hp
				_hurt_member(t, dmg, true, true)
				if await _offer_rewind({t: before - t.hp}):
					continue
				if _pending_loss:
					_lose()
					return
			await _wait(0.3)
			await _step_back_foe()
			break


## The enemy draws back while the ring closes: the attack reads on its body too, and lands when the ring does.
func _windup(seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(_foe, "position:x", _foe_at.x - 0.45, (0.05 if fast else seconds * 0.8)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _step_back_foe() -> void:
	var tw := create_tween()
	tw.tween_property(_foe, "position:x", _foe_at.x, 0.05 if fast else 0.3)
	await tw.finished
	if not _over:
		_pose(_foe, _art("idle"))


## The line under the victory banner: how cleanly it went, and what is left for the next one.
func _tally() -> String:
	var bits: Array = ["PERFECT PARRIES %d" % (Story.perfects - _perfects_at_start)]
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


## A perfect parry winds the watch: one more REWIND, up to WATCH_MAX.
func _charge_watch() -> void:
	if (unit("pido") != null or (unit("teo") != null and awakened)) and watch_charge < WATCH_MAX:
		watch_charge += 1
		_number("REWIND +1", _foe_head() + Vector2(0, -70), Color("00ffcc"))
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
	_pose(_foe, _art("wail"))
	Sfx.play("boss-growl-08")
	await _cut_in_tex(_foe_portrait(), String(sp.get("name", "")), String(sp.get("gloss", "")), Color("ff4a5a"), true)
	_banner(String(sp.get("name", "")), String(sp.get("gloss", "")))
	_say(String(sp.get("text", "")))
	_shake(6.0)
	await _wait(0.5)
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
	var grade := await _ring_grade("DODGE!" if dodge else "PARRY!", float(sp.get("seconds", 1.0)), dodge)
	while grade == "miss":
		var before := {}
		for t in targets:
			before[t] = (t as Unit).hp
		Story.misses += 1
		for t in targets:
			_hurt_member(t, int(sp.get("damage", 20)), true, true)
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
			await _wait(0.9)
			if not _over:
				_pose(_foe, _art("idle"))
			return
		_pose(_foe, _art("wail"))
		grade = await _ring_grade("DODGE!" if dodge else "PARRY!", float(sp.get("seconds", 1.0)), dodge)
	if grade != "miss" and dodge:
		Sfx.play("dodge-swish-9")
		for t in targets:
			_number("DODGED!", _head(t), Color("9ad7ff"), true)
		_say(String(sp.get("dodged", "Out of the way, just in time.")))
	else:
		Story.misses += 1
		for t in targets:
			var u: Unit = t
			var dmg := int(sp.get("damage", 20))
			if grade == "good":
				dmg = dmg / 2
			_hurt_member(u, dmg, true)
			if effect == "spellbound" and u.alive():
				u.spellbound = true
				u.status.text = "SPELLBOUND"
		_say(String(sp.get("hit", "")))
	await _wait(0.9)
	if not _over:
		_pose(_foe, _art("idle"))


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
	_ring.start(prompt, seconds, level, lesson)
	if demo and test_miss > 0 and level != "guided":
		test_miss -= 1 # review recordings (?miss=1): let this one land, to show REWIND
	elif demo:
		get_tree().create_timer(seconds * 0.82).timeout.connect(_ring.press)
	var g: String = await _ring.finished
	_ring.visible = false
	return g


func _hurt_member(u: Unit, dmg: int, heavy: bool, undoable: bool = false) -> void:
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
		kb.tween_property(u.node, "position:x", u.home.x, 0.05 if fast else 0.3).set_trans(Tween.TRANS_SINE)
	_number(str(dmg), _head(u), Color("ff8a7a"), heavy)
	_flash_color(Color(1, 0.2, 0.2), 0.25)
	if heavy:
		_shake(10.0)
	_refresh()
	if u.hp <= 0:
		u.atb = 0.0
		u.status.text = "DOWN"
	var anyone := false
	for v in party:
		anyone = anyone or (v as Unit).alive()
	if not anyone:
		if undoable and _rewind_ready():
			_pending_loss = true # the watch may still take it back (_offer_rewind)
		else:
			_lose()


# --- the watch wakes ------------------------------------------------------------------------------------------------

func _check_awakening() -> void:
	if awakened or not bool(def.get("awakens", false)) or not _has("teo") or _over:
		return
	if float(foe_hp) / foe_max > float(def.get("awaken_below", 0.55)):
		return
	awakened = true
	watch_charge = maxi(watch_charge, 1)
	foe_floor = 0
	Story.flags["watch_awake"] = true
	Progress.unlock_skill("rewind", Story.loob, 1)
	_waking = true
	await _cut_in("teo", "THE WATCH AWAKENS", "NEW: REWIND. MISS A PARRY? HOLD TO TAKE IT BACK", Color("00ffcc"), false)
	var bearer := unit("teo")
	bearer.haste = 1.5 # borrowed time: for the rest of this fight his time bar runs fast
	bearer.status.text = "HASTE"
	_flash_color(Color.WHITE, 0.7)
	var teo := unit("teo")
	FxBurst.play(self, "ring", _head(teo) + Vector2(0, 60), Color("00ffcc"), 1.6)
	FxBurst.play(self, "clock", _head(teo) + Vector2(0, 30), Color("00ffcc"))
	_shake(12.0)
	Sfx.play("stagger-break-3tone")
	Story.consequence.emit("THE WATCH AWAKENS. New: REWIND. When a blow lands, HOLD to take it back. Perfect parries wind it.")
	for u in party:
		(u as Unit).hp = (u as Unit).max_hp
	Story.add_utang(2, "The watch borrows its first seconds for you: +2 utang")
	_say("Something clicks in Teo's pocket. The hands turn backward, and every wound of this fight unwinds. The watch has awakened.")
	_refresh()
	await _wait(2.2)
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
			Sfx.cue("wake")
		"outlasted":
			_banner("HELD ON", String(def.get("victory", "")))
		_:
			Story.apply_effects(def.get("scatter_fx", {}))
			_banner("VICTORY", String(def.get("victory", "")))
	tally = _tally()
	_tip.text = tally
	_tip.visible = tally != ""
	await _wait(1.6)
	if how != "outlasted":
		_pose(_foe, _art("fade"))
		var tw := create_tween()
		tw.tween_property(_foe, "position:y", 1.2 if _spirit() else 0.0, 1.4 if not fast else 0.05)
		tw.parallel().tween_method(func(a: float) -> void:
			(_foe.material_override as ShaderMaterial).set_shader_parameter("alpha", a), 1.0, 0.0, 1.4 if not fast else 0.05)
		_foe_light.visible = false
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
	watch_charge = 1 if (awakened or _has("pido")) else 0
	candles = _fresh_candles()
	heat = 0
	summoned = false
	_pending_loss = false
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
	var foe_win := _window()
	foe_win.position = Vector2(24, 560)
	foe_win.custom_minimum_size = Vector2(470, 138)
	var fcol := VBoxContainer.new()
	fcol.add_theme_constant_override("separation", 4)
	foe_win.add_child(fcol)
	_foe_name = _label(Fonts.label(), 24)
	_foe_name.text = String(def.get("name", "?"))
	fcol.add_child(_foe_name)
	var kind := _label(Fonts.label_medium(), 16, Color(1, 1, 1, 0.65))
	kind.text = String(def.get("kind", ""))
	fcol.add_child(kind)
	_foe_bar = _bar(Color(String(def.get("bar", "9fc4ff"))), 420)
	_foe_bar.custom_minimum_size.y = 14
	_foe_bar.max_value = foe_max
	fcol.add_child(_foe_bar)
	var sh: Dictionary = def.get("send_home", {})
	var note := _label(Fonts.label_medium(), 15, Color("ffe08a"))
	if not sh.is_empty():
		var mark := ColorRect.new()
		mark.color = Color("ffe08a")
		mark.size = Vector2(3, 22)
		mark.position = Vector2(420.0 * float(sh.get("below", 0.3)) - 1.0, -4)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_foe_bar.add_child(mark)
		note.text = "Below the gold line: pray UWI KA NA to send it home"
	elif int(def.get("survive_turns", 0)) > 0:
		note.text = "It cannot be beaten. Hold on for %d turns." % int(def["survive_turns"])
	fcol.add_child(note)
	_wire_label = note if not sh.is_empty() or int(def.get("survive_turns", 0)) > 0 else _label(Fonts.label_medium(), 15, Color("8fe3ff"))
	if _wire_label != note:
		fcol.add_child(_wire_label)

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
	if _res_label != null:
		var bits: Array = []
		if _rewind_ready() or awakened or _has("pido"):
			bits.append("REWIND x%d" % watch_charge)
		if _fresh_candles() > 0:
			bits.append("CANDLES %d" % candles)
		if Story.gratitude > 0 or _has("ising"):
			bits.append("UTANG NA LOOB %d" % Story.gratitude)
		_res_label.text = "     ".join(bits)
	if _has("kardo") and _wire_label != null:
		_wire_label.text = "WIRES ON IT: %d / %d" % [wired, _max_wires()] if wired > 0 else "No wires on it yet"
	if not _over and foe_hp < foe_max:
		_check_awakening.call_deferred()


## A special move's cut-in, as the 16-bit games did it: the action freezes, a band sweeps across the screen, the
## fighter's portrait slides in big, and the move is named. Enemies come from the left, the party from the right.
func _cut_in(portrait: String, title: String, sub: String, accent: Color, from_left: bool) -> void:
	await _cut_in_tex(Art.portrait(portrait) if portrait != "" else null, title, sub, accent, from_left)


func _cut_in_tex(tex: Texture2D, title: String, sub: String, accent: Color, from_left: bool) -> void:
	cut_ins += 1
	if fast:
		return
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
	var pic := TextureRect.new()
	pic.texture = tex
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size = Vector2(264, 264)
	pic.flip_h = not from_left # busts face right; the party stands on the right and faces left
	var pic_x := 90.0 if from_left else band.size.x - 90.0 - 264.0
	pic.position = Vector2(pic_x + (-500.0 if from_left else 500.0), -44)
	band.add_child(pic)
	var name_l := Retro.label(Fonts.display(), 66, Color.WHITE)
	name_l.add_theme_constant_override("outline_size", 10)
	name_l.text = title
	name_l.size = Vector2(band.size.x - 520, 90)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if from_left else HORIZONTAL_ALIGNMENT_RIGHT
	var text_x := 380.0 if from_left else 140.0
	name_l.position = Vector2(text_x + (300.0 if from_left else -300.0), 44)
	name_l.modulate.a = 0.0
	band.add_child(name_l)
	var sub_l := Retro.label(Fonts.label(), 26, accent)
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
