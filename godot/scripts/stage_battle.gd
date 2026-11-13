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
const PRAYERS := [
	{"id": "paalam", "name": "PAALAM", "gloss": "Farewell", "keys": ["left", "right", "up"], "seconds": 3.6, "power": 24},
	{"id": "uwi", "name": "UWI KA NA", "gloss": "Go home", "keys": ["up", "down", "left", "right", "up"], "seconds": 4.6, "power": 34},
	# HATID II: the long prayer. Lolo Pido knows it; Teo earns it with Loob (HATID2_LOOB). It sends home from higher up.
	{"id": "tawid", "name": "TAWID", "gloss": "Cross over", "keys": ["up", "up", "left", "right", "down", "left", "up"], "seconds": 5.6, "power": 46, "tier": 2},
]
const HATID2_LOOB := 2
const TAWID_REACH := 0.15 # TAWID sends a spirit home this much above the gold line
const MEMBERS := {
	"teo": {"name": "TEO", "hp": 110, "speed": 10, "art": "teob", "cmds": ["attack", "hatid", "watch", "item", "guard"],
		"attack": "BALISONG", "desperation": "BALISONG IKOT", "item": "SALABAT", "item_text": "Lola's salabat, still warm.",
		"guard": "GUARD", "hit": [10, 14], "heal": 38},
	"pido": {"name": "LOLO PIDO", "hp": 130, "speed": 9, "art": "pidob", "cmds": ["attack", "hatid", "watch", "item", "guard"],
		"attack": "SUNDANG", "desperation": "SUNDANG IKOT", "item": "SALABAT", "item_text": "Ising's salabat, from the thermos on the stairs.",
		"guard": "GUARD", "hit": [13, 17], "heal": 40},
	"kardo": {"name": "KARDO", "hp": 125, "speed": 7, "art": "kardob", "cmds": ["attack", "wire", "discharge", "item", "guard"],
		"attack": "WRENCH", "desperation": "", "item": "COFFEE", "item_text": "3-in-1 coffee, mostly sugar.",
		"guard": "COVER", "hit": [9, 12], "heal": 34},
	"ising": {"name": "LOLA ISING", "hp": 90, "speed": 8, "art": "lolab", "cmds": ["attack", "orasyon", "item", "guard"],
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
var watch_uses := 0
var pido_watch := 1 # Lolo Pido's own rewind, once a fight (1998: the watch is his)
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
var auto_wind := 1.0
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
	foe_max = int(def.get("hp", 120))
	foe_hp = foe_max
	party.clear()
	for id in party_ids:
		var u := Unit.new()
		u.id = String(id)
		u.d = MEMBERS.get(u.id, MEMBERS["teo"])
		u.max_hp = int(u.d["hp"])
		u.hp = u.max_hp
		party.append(u)
	if not party.is_empty() and Story.injury > 0:
		var lead: Unit = party[0]
		lead.hp = maxi(20, lead.max_hp - Story.injury) # hurt going in (a failed QTE, or the last wave)
	awakened = Story.flags.get("watch_awake", false)
	watch_uses = 1 if awakened else 0
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
		m.atb = minf(1.0, m.atb + delta * float(m.d["speed"]) * ATB_RATE * speed)
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
		"watch":
			await _rewind(u)
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
		return "orasyon" if hurt or charging or (_spirit() and foe_turns % 2 == 1) else "attack"
	if charging and cmds.has("hatid") and interrupt.has("prayer"):
		return "pray_paalam"
	if charging and cmds.has("discharge") and interrupt.has("discharge") and wired > 0:
		return "discharge"
	var sh: Dictionary = def.get("send_home", {})
	if cmds.has("hatid") and not sh.is_empty() and float(foe_hp) / foe_max <= float(sh.get("below", 0.0)):
		return "pray_" + String(sh.get("prayer", "uwi"))
	if cmds.has("hatid") and not sh.is_empty() and hatid2(u) and float(foe_hp) / foe_max <= float(sh.get("below", 0.0)) + TAWID_REACH:
		return "pray_tawid"
	if _usable(u, "watch") and float(u.hp) / u.max_hp < 0.4 and not _last_hits.is_empty():
		return "watch"
	if float(u.hp) / u.max_hp < 0.35 and u.items > 0:
		return "item"
	if cmds.has("wire"):
		return "wire" if wired < 2 else "discharge"
	if cmds.has("hatid") and _spirit() and foe_turns % 2 == 1:
		return "pray_paalam"
	return "attack"


func _usable(u: Unit, cmd: String) -> bool:
	match cmd:
		"item":
			return u.items > 0
		"watch":
			return pido_watch > 0 if u.id == "pido" else (awakened and watch_uses > 0)
		"discharge":
			return wired > 0
		"wire":
			return wired < MAX_WIRES
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
					b = _cmd_button(u, "hatid", "HATID  >")
				"watch":
					if u.id == "pido":
						b = _cmd_button(u, "watch", "WATCH: REWIND  x%d" % pido_watch, _usable(u, "watch"))
					elif awakened:
						b = _cmd_button(u, "watch", "WATCH: REWIND  x%d" % watch_uses, _usable(u, "watch"))
				"orasyon":
					b = _cmd_button(u, "orasyon", "ORASYON")
				"item":
					b = _cmd_button(u, "item", "%s  x%d" % [u.d["item"], u.items], _usable(u, "item"))
				"guard":
					b = _cmd_button(u, "guard", String(u.d["guard"]))
				"wire":
					b = _cmd_button(u, "wire", "WIRE  (%d/%d)" % [wired, MAX_WIRES], _usable(u, "wire"))
				"discharge":
					b = _cmd_button(u, "discharge", "KONTRA", _usable(u, "discharge"))
			if b != null and first == null:
				first = b
	else:
		for p in PRAYERS:
			var b: Button
			if int(p.get("tier", 1)) == 2 and not hatid2(u):
				b = _cmd_button(u, "pray_" + String(p["id"]), "HATID II  (needs Loob %d)" % HATID2_LOOB, false)
			else:
				b = _cmd_button(u, "pray_" + String(p["id"]), "%s  (%s)" % [p["name"], p["gloss"]])
			if first == null:
				first = b
		_cmd_button(u, "back", "<  BACK")
	if first != null:
		first.grab_focus()


## HATID II (TAWID): Lolo Pido has always known it; Teo finds it once his Loob is high enough.
func hatid2(u: Unit) -> bool:
	return u.id == "pido" or Story.loob >= HATID2_LOOB


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


func _lunge(u: Unit, seconds: float) -> void:
	_pose(u.node, u.art("slash"))
	var tw := create_tween()
	tw.tween_property(u.node, "position:x", _foe_at.x + 1.25, seconds * (0.2 if fast else 1.0)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	Sfx.play("hit-thud-metal" if u.id == "kardo" else "slash-knife")


func _step_back(u: Unit) -> void:
	_pose(u.node, u.art("ready"))
	var tw := create_tween()
	tw.tween_property(u.node, "position:x", u.home.x, 0.05 if fast else 0.28)
	await tw.finished


func _hurt_foe(dmg: int, heavy: bool) -> void:
	if _over:
		return
	foe_hp = maxi(foe_floor, foe_hp - dmg)
	_number(str(dmg), _foe_head(), Color("ffffff"), heavy)
	_pose(_foe, _art("hurt"))
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
	wired = mini(MAX_WIRES, wired + 1)
	await _wait(0.3)
	_hurt_foe(6, false)
	_say("Kardo clamps a wire on it. Circuit: %d / %d." % [wired, MAX_WIRES])
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
	var r := await _gauge_play("charge", "KONTRA", "%d WIRE%s ON IT. HOLD, AND LET GO IN THE GREEN" % [stacks, "" if stacks == 1 else "S"], Color("5ad8ff"))
	last_kontra = r
	var z := String(r.get("zone", "weak"))
	var v := float(r.get("value", 0.0))
	var mult := 1.0
	var shock := 0
	var sub := "%d WIRE%s LIGHT UP" % [stacks, "" if stacks == 1 else "S"]
	match z:
		"weak":
			mult = 0.45 + 0.55 * v / SpecialGauge.CLEAN
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


## The watch: whatever the enemy did on its last turn is taken back, as far as the crown is wound (SpecialGauge "wind").
## Wound all the way, every blow is undone and whatever it was charging is forgotten. Teo's watch writes the time down
## (utang); in 1998 the watch is Lolo Pido's, once a fight.
func _rewind(u: Unit) -> void:
	if u.id == "pido":
		pido_watch -= 1
	else:
		watch_uses -= 1
	rewinds += 1
	_pose(u.node, u.art("wind"))
	var r := await _gauge_play("wind", "REWIND", "TAP FAST: WIND THE CROWN BACKWARD", Color("00ffcc"))
	last_wind = r
	var k := float(r.get("value", 0.0))
	await _cut_in(u.id, "REWIND", "THE WATCH TURNS BACK" if k >= 1.0 else "THE HANDS SLIP BACK %d%%" % int(k * 100), Color("00ffcc"), false)
	_pose(u.node, u.art("burst"))
	_flash_color(Color("00ffcc"), 0.45)
	FxBurst.play(self, "clock", _head(u) + Vector2(0, 60), Color("00ffcc"))
	Sfx.play("command-exit")
	var back := 0
	for v in party:
		var m: Unit = v
		var lost := int(round(int(_last_hits.get(m.id, 0)) * k))
		if lost > 0:
			m.hp = mini(m.max_hp, m.hp + lost)
			back += lost
			_number("+%d" % lost, _head(m), Color("00ffcc"))
		if k >= 0.5:
			m.spellbound = false
			m.status.text = ""
	_last_hits.clear()
	if charging and k >= 1.0:
		_interrupt("Time stutters. It forgets what it was about to do.")
	if u.id != "pido":
		Story.add_utang(1, "The watch turns back. Time stutters. +1 utang")
	if k >= 1.0:
		_say("The hands turn backward: %d HP of the last blows never landed." % back)
	else:
		_say("The crown slips. Only part of it comes back: %d HP." % back)
	_refresh()
	await _wait(0.9)


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
	if not _over:
		_say("Lola prays the way her lola did, every word on the beat. Even the folding chairs seem to listen." if full else "Lola prays. The room gets a little warmer.")
	_refresh()
	await _wait(0.8)


## Plays one special's input and returns its result (SpecialGauge).
func _gauge_play(mode: String, title: String, sub: String, accent: Color) -> Dictionary:
	_gauge.auto = fast or demo
	_gauge.fast = fast
	_gauge.auto_charge = auto_charge
	_gauge.auto_rhythm = auto_rhythm
	_gauge.start(mode, title, sub, accent)
	if fast and mode == "wind":
		_gauge.taps = int(round(auto_wind * SpecialGauge.WIND_GOAL))
	var r: Dictionary = await _gauge.finished
	if fast and mode == "wind":
		r = {"value": auto_wind, "taps": int(round(auto_wind * SpecialGauge.WIND_GOAL))}
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
		_pose(_foe, _art("claw"))
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
			Sfx.play("dodge-swish-1")
			_pose(t.node, t.art("guard"))
			_number("PERFECT PARRY!", _head(t), Color("7dff9a"), true)
			await _wait(0.3)
			_say("A gap in its guard! %s counters." % String(t.d["name"]).capitalize())
			await _step_back_foe()
			await _lunge(t, 0.14)
			_hurt_foe(int(t.d["hit"][1]) + 3, true)
			await _wait(0.25)
			await _step_back(t)
			continue
		else:
			if grade == "good":
				Story.parries += 1
				dmg = dmg / 2
			else:
				Story.misses += 1
			_hurt_member(t, dmg, grade == "miss")
		await _wait(0.3)
		await _step_back_foe()


func _step_back_foe() -> void:
	var tw := create_tween()
	tw.tween_property(_foe, "position:x", _foe_at.x, 0.05 if fast else 0.3)
	await tw.finished
	if not _over:
		_pose(_foe, _art("idle"))


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
	if demo:
		get_tree().create_timer(seconds * 0.82).timeout.connect(_ring.press)
	var g: String = await _ring.finished
	_ring.visible = false
	return g


func _hurt_member(u: Unit, dmg: int, heavy: bool) -> void:
	if u.guarding:
		dmg = dmg / 2
	u.guarding = false
	u.hp = maxi(0, u.hp - dmg)
	_last_hits[u.id] = int(_last_hits.get(u.id, 0)) + dmg
	Sfx.play("hit-thud")
	_pose(u.node, u.art("down") if u.hp <= 0 else u.art("hurt"))
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
		_lose()


# --- the watch wakes ------------------------------------------------------------------------------------------------

func _check_awakening() -> void:
	if awakened or not bool(def.get("awakens", false)) or not _has("teo") or _over:
		return
	if float(foe_hp) / foe_max > float(def.get("awaken_below", 0.55)):
		return
	awakened = true
	watch_uses = 1
	foe_floor = 0
	Story.flags["watch_awake"] = true
	Progress.unlock_skill("rewind", Story.loob, 1)
	_waking = true
	await _cut_in("teo", "THE WATCH AWAKENS", "NEW: WATCH (REWIND x1)", Color("00ffcc"), false)
	_flash_color(Color.WHITE, 0.7)
	var teo := unit("teo")
	FxBurst.play(self, "ring", _head(teo) + Vector2(0, 60), Color("00ffcc"), 1.6)
	FxBurst.play(self, "clock", _head(teo) + Vector2(0, 30), Color("00ffcc"))
	_shake(12.0)
	Sfx.play("stagger-break-3tone")
	Story.consequence.emit("THE WATCH AWAKENS. New: WATCH (Rewind x1)")
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
	watch_uses = 1 if awakened else 0
	pido_watch = 1
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
	if _has("kardo") and _wire_label != null:
		_wire_label.text = "WIRES ON IT: %d / %d" % [wired, MAX_WIRES] if wired > 0 else "No wires on it yet"
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
