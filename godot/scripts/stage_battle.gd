class_name StageBattle
extends Control
## A retro side-view battle fought on the walkable map itself (the HD-2D street), in the manner of the 16-bit JRPGs:
## the enemy on the left, the party on the right, blue windows along the bottom, and time bars (ATB) that fill
## in real time. Time stops while a menu is open (the "wait" setting), so nobody is rushed into a choice.
##
## Teo's commands:
##   BALISONG  a quick cut. Below 30% HP it can turn into a desperation move (BALISONG IKOT: three cuts).
##   HATID     his signature: pick a prayer, then enter its arrows before the bar runs out (keys, d-pad or the
##             on-screen arrows). Prayers hurt spirits badly; a wrong arrow fizzles the prayer. UWI KA NA, prayed
##             while the spirit is below a third of its strength, sends it home instead of scattering it.
##   SALABAT   Lola's ginger tea: heals; two flasks.
##   GUARD     halves the next hit.
## The enemy (data/stage_enemies.json) has an ordinary attack, parried on the timing ring, and a signature move with
## a tell a turn ahead: Mang Andoy's TAWAG (the call) can only be dodged, and if it lands Teo answers and loses his
## next turn. Any prayer landed during the tell drowns the call out. Heard Mang Isko in the street? The tell says so.
##
## Tests set `fast`: the fight then plays itself at speed (sensible picks, rings and prayers entered correctly).

signal finished(won: bool)

const PX := 1.75 / 64.0 # metres per sprite pixel: one pixel grid for everyone on the stage
const TEO_HP := 110
const TEO_SPEED := 10.0
const ATB_RATE := 0.034 # time bar filled per second per point of speed
const DESPERATE := 0.3
const PRAYERS := [
	{"id": "paalam", "name": "PAALAM", "gloss": "Farewell", "keys": ["left", "right", "up"], "seconds": 3.6, "power": 24},
	{"id": "uwi", "name": "UWI KA NA", "gloss": "Go home", "keys": ["up", "down", "left", "right", "up"], "seconds": 4.6, "power": 34},
]
const TEO_AT := Vector2(13.6, 6.7)
const FOE_AT := Vector2(9.2, 6.7)

static var _defs: Dictionary = {}

var fast := false
## Plays itself at normal speed (review recordings: BALETE_DEMO=1 / ?demo=1 with ?fight=).
var demo := false
var enemy_id := "magbabalot"
var map_id := ""
var def: Dictionary = {}

var teo_hp := TEO_HP
var foe_hp := 1
var foe_max := 1
var teo_atb := 0.0
var foe_atb := 0.0
var salabat := 2
var guarding := false
var spellbound := false
var charging := false
var foe_turns := 0
var outcome := "" # "sent" | "scattered" | "fell"
var interrupts := 0
var _acting := false
var _over := false
var _menu_open := false

var _map: ExploreMap
var _teo: Sprite3D
var _foe: Sprite3D
var _foe_light: OmniLight3D
var _t := 0.0
var _ring: TimingRing
var _msg_panel: PanelContainer
var _msg: Label
var _cmd_panel: PanelContainer
var _cmd_box: VBoxContainer
var _foe_name: Label
var _foe_bar: ProgressBar
var _teo_hp_label: Label
var _teo_atb_bar: ProgressBar
var _teo_status: Label
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


## {"enemy": id, "map": map id (default: the enemy's own)}.
func setup(p: Dictionary) -> void:
	enemy_id = String(p.get("enemy", enemy_id))
	def = enemy_def(enemy_id)
	map_id = String(p.get("map", def.get("map", "hidalgo")))
	foe_max = int(def.get("hp", 120))
	foe_hp = foe_max


func _ready() -> void:
	if def.is_empty():
		setup({})
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_stage()
	_build_hud()
	Sfx.cue("battle")
	_begin()


func _begin() -> void:
	_acting = true
	_say(String(def.get("opening", "")))
	await _wait(1.6)
	_say("")
	_acting = false


# --- the stage ---------------------------------------------------------------------------------------------------

func _build_stage() -> void:
	_map = ExploreMap.new()
	_map.stage_mode = true
	_map.test_fast = fast
	_map.setup({"map": map_id}, {}, 0, TEO_AT)
	_map.fixed_cam = [Vector3(11.4, 3.0, 17.2), Vector3(11.4, 1.5, 6.0)]
	add_child(_map)
	_map.hide_teo()
	_teo = _make_sprite("teob_ready", false)
	_teo.position = Vector3(TEO_AT.x, 0, TEO_AT.y)
	_map.add_node(_teo)
	_map.blob(TEO_AT, 0.9)
	_foe = _make_sprite(_art("idle"), true)
	_foe.position = Vector3(FOE_AT.x, 0.1, FOE_AT.y)
	_map.add_node(_foe)
	_foe_light = OmniLight3D.new()
	_foe_light.light_color = Color("9fc4ff")
	_foe_light.light_energy = 1.2
	_foe_light.omni_range = 4.0
	_foe_light.position = Vector3(FOE_AT.x, 1.4, FOE_AT.y + 0.8)
	_map.add_node(_foe_light)


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
	if tex == null:
		return
	s.texture = tex
	s.offset = Vector2(0, tex.get_height() * 0.5)
	(s.material_override as ShaderMaterial).set_shader_parameter("tex", tex)


func _process(delta: float) -> void:
	_t += delta
	# The spirit breathes and bobs; it reddens while it charges its call.
	if _foe != null and not _over:
		var idle := _foe.texture == _tex(_art("idle")) or _foe.texture == _tex(_art("idle_b"))
		if idle:
			_pose(_foe, _art("idle" if int(_t * 1.6) % 2 == 0 else "idle_b"))
		_foe.position.y = 0.12 + sin(_t * 1.4) * 0.07
		_foe_light.light_color = Color("ff4050") if charging else Color("9fc4ff")
		_foe_light.light_energy = (1.6 + sin(_t * 8.0) * 0.4) if charging else 1.2
	if _seq_active:
		_seq_t -= delta
		_seq_bar.value = maxf(0.0, _seq_t / _seq_total) * 100.0
		if _seq_t <= 0.0:
			_end_sequence(false)
	if _acting or _over or _menu_open:
		return
	var speed := 20.0 if fast else 1.0
	teo_atb = minf(1.0, teo_atb + delta * TEO_SPEED * ATB_RATE * speed)
	foe_atb = minf(1.0, foe_atb + delta * float(def.get("speed", 8)) * ATB_RATE * speed)
	_teo_atb_bar.value = teo_atb * 100.0
	if teo_atb >= 1.0:
		_acting = true
		_teo_turn()
	elif foe_atb >= 1.0:
		_acting = true
		_foe_turn()


# --- Teo's turn --------------------------------------------------------------------------------------------------

func _teo_turn() -> void:
	if spellbound:
		spellbound = false
		_teo_status.text = ""
		_say("Teo is still answering the call. He can't move!")
		await _wait(1.1)
		_end_turn(true)
		return
	var cmd := await _choose()
	match cmd:
		"attack":
			await _attack()
		"salabat":
			salabat -= 1
			var heal := mini(38, TEO_HP - teo_hp)
			teo_hp += heal
			Sfx.play("heal-chime")
			_say("Lola's salabat, still warm. Teo recovers %d." % heal)
			_number("+%d" % heal, _teo_head(), Color("7dff9a"))
			await _wait(0.8)
		"guard":
			guarding = true
			_pose(_teo, "teob_guard")
			_say("Teo braces.")
			await _wait(0.6)
		_:
			if cmd.begins_with("pray_"):
				await _pray(cmd.trim_prefix("pray_"))
	if not _over:
		_end_turn(true)


func _end_turn(teo: bool) -> void:
	if teo:
		teo_atb = 0.0
		_teo_atb_bar.value = 0.0
		if not guarding:
			_pose(_teo, "teob_ready")
	else:
		foe_atb = 0.0
	_refresh()
	_acting = false


## Opens the command window and waits for a pick (or picks for the test autoplay).
func _choose() -> String:
	if demo:
		_show_menu("main")
		await _wait(0.8)
		_cmd_panel.visible = false
	if fast or demo:
		await get_tree().process_frame
		if charging:
			return "pray_paalam" # drown out the call
		if float(foe_hp) / foe_max <= float(def.get("send_home", {}).get("below", 0.0)):
			return "pray_uwi"
		if teo_hp < 40 and salabat > 0:
			return "salabat"
		return "attack"
	_show_menu("main")
	_menu_open = true
	var cmd: String = await _command
	_menu_open = false
	_cmd_panel.visible = false
	return cmd


func _show_menu(mode: String) -> void:
	for c in _cmd_box.get_children():
		c.queue_free()
	_cmd_panel.visible = true
	var first: Button = null
	if mode == "main":
		first = _cmd_button("attack", "BALISONG")
		_cmd_button("hatid", "HATID  >")
		_cmd_button("salabat", "SALABAT  x%d" % salabat, salabat > 0)
		_cmd_button("guard", "GUARD")
	else:
		for p in PRAYERS:
			var b := _cmd_button("pray_" + String(p["id"]), "%s  (%s)" % [p["name"], p["gloss"]])
			if first == null:
				first = b
		_cmd_button("back", "<  BACK")
	if first != null:
		first.grab_focus()


func _cmd_button(id: String, text: String, enabled: bool = true) -> Button:
	var b := Button.new()
	b.name = "Cmd_" + id
	b.text = text
	b.disabled = not enabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(300, 46)
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
			_show_menu("hatid")
		elif id == "back":
			_show_menu("main")
		else:
			_command.emit(id))
	_cmd_box.add_child(b)
	if id == "attack" or (_cmd_box.get_child_count() == 1):
		b.grab_focus()
	return b


func _attack() -> void:
	var desperate := float(teo_hp) / TEO_HP < DESPERATE and (fast or randf() < 0.35)
	if desperate:
		_banner("BALISONG IKOT", "Desperation move!")
		Sfx.play("stagger-break-3tone")
		await _wait(0.5)
		for i in 3:
			await _lunge(0.18)
			_hurt_foe(12 + randi() % 4, true)
			await _wait(0.12)
	else:
		_say("")
		await _lunge(0.22)
		_hurt_foe(10 + randi() % 5, false)
	await _wait(0.35)
	await _step_back()


func _lunge(seconds: float) -> void:
	_pose(_teo, "teob_slash")
	var tw := create_tween()
	tw.tween_property(_teo, "position:x", FOE_AT.x + 1.25, seconds * (0.2 if fast else 1.0)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	Sfx.play("slash-knife")


func _step_back() -> void:
	_pose(_teo, "teob_ready")
	var tw := create_tween()
	tw.tween_property(_teo, "position:x", TEO_AT.x, 0.05 if fast else 0.28)
	await tw.finished


func _hurt_foe(dmg: int, heavy: bool) -> void:
	foe_hp = maxi(0, foe_hp - dmg)
	_number(str(dmg), _foe_head(), Color("ffffff"), heavy)
	_pose(_foe, _art("hurt"))
	var tw := create_tween()
	tw.tween_property(_foe, "position:x", FOE_AT.x - 0.35, 0.06)
	tw.tween_property(_foe, "position:x", FOE_AT.x, 0.2)
	tw.tween_callback(func() -> void:
		if not _over:
			_pose(_foe, _art("tell") if charging else _art("idle")))
	if heavy:
		_shake(8.0)
	_refresh()
	if foe_hp <= 0:
		_win("scattered")


# --- Hatid: the prayer input ---------------------------------------------------------------------------------------

func _pray(id: String) -> void:
	var p: Dictionary = {}
	for q in PRAYERS:
		if String(q["id"]) == id:
			p = q
	if p.is_empty():
		return
	_pose(_teo, "teob_pray")
	_banner(String(p["name"]), "Hatid: %s. Enter the prayer!" % p["gloss"])
	var ok: bool = await _sequence(p)
	if not ok:
		_pose(_teo, "teob_hurt")
		_say("The words tangle in Teo's mouth. The prayer fizzles.")
		Sfx.play("command-exit")
		await _wait(0.9)
		return
	_pose(_teo, "teob_burst")
	Sfx.play("extra-chime")
	_flash_color(Color(1.0, 0.92, 0.6), 0.55)
	FxBurst.play(self, "ring", _foe_head() + Vector2(0, 60), Color("ffe08a"), 1.6)
	FxBurst.play(self, "spark", _foe_head() + Vector2(0, 60), Color("fff3b0"), 1.4)
	await _wait(0.25)
	var sh: Dictionary = def.get("send_home", {})
	var low := float(foe_hp) / foe_max <= float(sh.get("below", 0.0))
	if id == String(sh.get("prayer", "")) and low:
		_win("sent")
		return
	var power := int(p["power"]) * (3 if bool(def.get("spirit", false)) else 2) / 2
	if charging:
		charging = false
		interrupts += 1
		foe_atb = 0.0
		_say("The prayer drowns out the call! Mang Andoy chokes on Teo's name.")
		_number("INTERRUPTED!", _foe_head() + Vector2(0, -40), Color("ffe08a"), true)
	_hurt_foe(power, true)
	if not _over and id == String(sh.get("prayer", "")) and not low:
		_say("He isn't ready to go. Weaken him first, then pray UWI KA NA.")
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
	if _menu_open and event.is_action_pressed("ui_cancel"):
		_show_menu("main")
		get_viewport().set_input_as_handled()


# --- the enemy's turn --------------------------------------------------------------------------------------------

func _foe_turn() -> void:
	foe_turns += 1
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
		await _wait(1.6)
	else:
		await _claw(def.get("attacks", {}).values()[0])
	if not _over:
		_end_turn(false)


func _claw(a: Dictionary) -> void:
	_say(String(a.get("text", "")))
	_banner(String(a.get("name", "")), "")
	await _wait(0.6)
	_pose(_foe, _art("claw"))
	var grade := await _ring_grade("PARRY!", float(a.get("seconds", 1.3)))
	var dmg := int(a.get("damage", 12))
	var tw := create_tween()
	tw.tween_property(_foe, "position:x", TEO_AT.x - 1.4, 0.05 if fast else 0.16)
	await tw.finished
	if grade == "perfect":
		Story.perfects += 1
		Story.parries += 1
		Sfx.play("dodge-swish-1")
		_pose(_teo, "teob_guard")
		_number("PERFECT PARRY!", _teo_head(), Color("7dff9a"), true)
		await _wait(0.3)
		_say("A gap in his guard! Teo counters.")
		await _step_back_foe()
		await _lunge(0.14)
		_hurt_foe(14, true)
		await _wait(0.25)
		await _step_back()
		return
	if grade == "good":
		Story.parries += 1
		dmg = dmg / 2
	else:
		Story.misses += 1
	if guarding:
		dmg = dmg / 2
	_hurt_teo(dmg, grade == "miss")
	await _wait(0.4)
	await _step_back_foe()


func _step_back_foe() -> void:
	var tw := create_tween()
	tw.tween_property(_foe, "position:x", FOE_AT.x, 0.05 if fast else 0.3)
	await tw.finished
	if not _over:
		_pose(_foe, _art("idle"))


func _special(sp: Dictionary) -> void:
	_tip.visible = false
	_pose(_foe, _art("wail"))
	_banner(String(sp.get("name", "")), String(sp.get("gloss", "")))
	_say(String(sp.get("text", "")))
	Sfx.play("boss-growl-08")
	_shake(6.0)
	await _wait(0.7)
	var grade := await _ring_grade("DODGE!", float(sp.get("seconds", 1.0)))
	if grade != "miss":
		Sfx.play("dodge-swish-9")
		_number("DODGED!", _teo_head(), Color("9ad7ff"), true)
		_say("Teo doesn't answer. The call goes past him into the dark.")
	else:
		Story.misses += 1
		_hurt_teo(int(sp.get("damage", 20)), true)
		spellbound = true
		_teo_status.text = "SPELLBOUND"
		_say("Teo hears Lola and turns to answer. He's spellbound: he'll lose his next turn.")
	await _wait(0.9)
	if not _over:
		_pose(_foe, _art("idle"))


func _ring_grade(prompt: String, seconds: float) -> String:
	if fast:
		await get_tree().process_frame
		return "good"
	_ring.start(prompt, seconds, "assisted")
	if demo:
		get_tree().create_timer(seconds * 0.82).timeout.connect(_ring.press)
	var g: String = await _ring.finished
	_ring.visible = false
	return g


func _hurt_teo(dmg: int, heavy: bool) -> void:
	guarding = false
	teo_hp = maxi(0, teo_hp - dmg)
	Sfx.play("hit-thud")
	_pose(_teo, "teob_hurt")
	_number(str(dmg), _teo_head(), Color("ff8a7a"), heavy)
	_flash_color(Color(1, 0.2, 0.2), 0.25)
	if heavy:
		_shake(10.0)
	_refresh()
	if teo_hp <= 0:
		_lose()


# --- endings -----------------------------------------------------------------------------------------------------

func _win(how: String) -> void:
	if _over:
		return
	_over = true
	outcome = how
	_cmd_panel.visible = false
	_tip.visible = false
	_pose(_teo, "teob_win")
	if how == "sent":
		Story.apply_effects(def.get("send_home", {}).get("fx", {}))
		_pose(_foe, _art("calm"))
		_banner("SENT HOME", "Uwi ka na. Mang Andoy's fare is paid.")
		Sfx.cue("wake")
	else:
		Story.apply_effects(def.get("scatter_fx", {}))
		_banner("VICTORY", "Mang Andoy comes apart. Scattered, not sent.")
	await _wait(1.2)
	_pose(_foe, _art("fade"))
	var tw := create_tween()
	tw.tween_property(_foe, "position:y", 1.2, 1.4 if not fast else 0.05)
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
	_pose(_teo, "teob_down")
	_banner("TEO FALLS", "")
	await _wait(1.0)
	_end_box.visible = true
	(_end_box.get_child(1) as Button).grab_focus()


func _retry() -> void:
	_end_box.visible = false
	teo_hp = TEO_HP
	foe_hp = foe_max
	teo_atb = 0.0
	foe_atb = 0.0
	foe_turns = 0
	charging = false
	spellbound = false
	guarding = false
	salabat = 2
	_teo_status.text = ""
	_over = false
	_pose(_teo, "teob_ready")
	_pose(_foe, _art("idle"))
	_refresh()
	_begin()


# --- HUD -----------------------------------------------------------------------------------------------------------

## The 16-bit window: a deep blue gradient with a light double edge.
func _window() -> PanelContainer:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.07, 0.11, 0.38, 0.93)
	st.border_color = Color(0.86, 0.88, 0.95)
	st.set_border_width_all(3)
	st.set_corner_radius_all(7)
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 4
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", st)
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
	b.custom_minimum_size = Vector2(w, 14)
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
	_msg_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
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

	# Bottom left: the enemy, with a strength bar that marks where it can be sent home.
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
	_foe_bar = _bar(Color("9fc4ff"), 420)
	_foe_bar.max_value = foe_max
	fcol.add_child(_foe_bar)
	var sh: Dictionary = def.get("send_home", {})
	if not sh.is_empty():
		var mark := ColorRect.new()
		mark.color = Color("ffe08a")
		mark.size = Vector2(3, 22)
		mark.position = Vector2(420.0 * float(sh.get("below", 0.3)) - 1.0, -4)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_foe_bar.add_child(mark)
		var note := _label(Fonts.label_medium(), 15, Color("ffe08a"))
		note.text = "Below the gold line: pray UWI KA NA to send him home"
		fcol.add_child(note)

	# Bottom right: the party (Teo alone tonight): name, HP and the time bar.
	var party := _window()
	party.position = Vector2(510, 560)
	party.custom_minimum_size = Vector2(746, 138)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	party.add_child(row)
	var name_l := _label(Fonts.label(), 26)
	name_l.text = "TEO"
	name_l.custom_minimum_size = Vector2(90, 0)
	row.add_child(name_l)
	_teo_hp_label = _label(Fonts.label(), 26)
	_teo_hp_label.custom_minimum_size = Vector2(170, 0)
	row.add_child(_teo_hp_label)
	var atb_col := VBoxContainer.new()
	var atb_l := _label(Fonts.label_medium(), 14, Color(1, 1, 1, 0.6))
	atb_l.text = "TIME"
	atb_col.add_child(atb_l)
	_teo_atb_bar = _bar(Color("ffd27a"), 220)
	atb_col.add_child(_teo_atb_bar)
	row.add_child(atb_col)
	_teo_status = _label(Fonts.label(), 18, Color("ff8aa0"))
	row.add_child(_teo_status)

	# The command window opens between the fighters on Teo's turn.
	_cmd_panel = _window()
	_cmd_panel.position = Vector2(470, 352) # between the fighters, over neither
	_cmd_panel.custom_minimum_size = Vector2(340, 0)
	_cmd_box = VBoxContainer.new()
	_cmd_panel.add_child(_cmd_box)
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

	_end_box = VBoxContainer.new()
	_end_box.position = Vector2(490, 300)
	_end_box.add_theme_constant_override("separation", 12)
	_end_box.visible = false
	add_child(_end_box)
	var fell := _label(Fonts.body_italic(), 20)
	fell.text = "Teo falls under the balete. The call goes on."
	_end_box.add_child(fell)
	var again := Button.new()
	again.name = "RetryButton"
	again.text = "TRY AGAIN"
	again.custom_minimum_size = Vector2(300, 64)
	again.add_theme_font_override("font", Fonts.display())
	again.add_theme_font_size_override("font_size", 28)
	again.pressed.connect(_retry)
	_end_box.add_child(again)
	_refresh()


func _refresh() -> void:
	_teo_hp_label.text = "%d / %d" % [teo_hp, TEO_HP]
	_teo_hp_label.add_theme_color_override("font_color", Color("ff8a7a") if float(teo_hp) / TEO_HP < DESPERATE else Color("f2efe4"))
	_foe_bar.value = foe_hp


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


func _teo_head() -> Vector2:
	return _screen(_teo.position + Vector3(0, 1.9, 0))


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
