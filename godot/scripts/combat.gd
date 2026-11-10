class_name Combat
extends Control
## Turn-based battle screen. Rules live in BattleModel; this draws them.
##
## Layout: party on the left (one or two members), enemies on the right, the turn-order bar on top, an enemy
## intent card, and a command menu built from the acting member's commands (Attack, Skill, Item, Guard; Dante
## also has Taser, and the party has team moves). Episode 1 is the tutorial: Skill is locked until the watch
## awakens mid-fight and then holds one rewind. On the enemy's turn a timed parry stays; a perfect parry opens a
## counter and earns watch energy. A fatal miss shows Renzo falling, then the watch turns the round back.

signal finished(victory: bool)
signal command_chosen(cmd: String)

const LESSON := "The Aswang is about to strike. Watch the big ring close on the white circle. When it glows green, press SPACE (A button) or TAP to PARRY."
const ENEMY_MAX_HP := 140
const RIM := {"renzo": "c9a24a", "dante": "5aa9c9"}

## Which episode this fight belongs to. Episode 1 is the tutorial (the watch awakens mid-fight).
var episode: int = 1
## Read skills, amulet and party from the save (Progress). Tests turn this off and set the model themselves.
var use_progress: bool = true
var model := BattleModel.new()
## Tests set this so the fight does not wait on real time.
var fast: bool = false
var aswang: BattleModel.Unit
var menu_mode: String = "main"

var _order_box: HBoxContainer
var _log: Label
var _intent_title: Label
var _intent_guard: Label
var _enemy_bar: ProgressBar
var _pips: Control
var _energy: Control
var _aswang_sil: Silhouette
var _cmd_box: HBoxContainer
var _ring: TimingRing
var _dim: ColorRect
var _flash: ColorRect
var _banner: PanelContainer
var _banner_label: Label
var _tag_label: Label
var _buttons: Dictionary = {}
var _hp_bars: Dictionary = {}
var _hp_labels: Dictionary = {}
var _sils: Dictionary = {}
var _actor: BattleModel.Unit


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_model()
	_build()
	_refresh()
	Story.consequence.connect(_notify)


func _setup_model() -> void:
	model.episode = episode
	if use_progress:
		if episode >= 2:
			model.mods = Progress.equipped_mods() # Episode 1 plays exactly as designed: no amulet yet
		model.load_skills(Progress.battle_skills(episode))
	var hp_mult := model.mod("max_hp_mult", 1.0)
	for id in PartyData.party_for(episode):
		var d := PartyData.member(id)
		var hp := int(round(float(d.get("hp", 100)) * hp_mult))
		var u := BattleModel.Unit.new(id, String(d.get("name", id)), true, hp, int(d.get("speed", 8)))
		if id == "renzo":
			u.hp = maxi(20, hp - Story.injury) # a rough ride means a weaker start
		model.allies.append(u)
	if model.allies.size() >= 2:
		model.team_moves = PartyData.team_moves(episode)
	aswang = BattleModel.Unit.new("aswang", "Aswang", false, ENEMY_MAX_HP, 8)
	model.enemies.append(aswang)
	model.rng.randomize()
	model.start()


func begin() -> void:
	Sfx.bgm("determined-pursuit")
	var renzo := _unit("renzo")
	if Story.injury > 0 and renzo != null:
		Story.consequence.emit("Rough ride: Renzo starts the fight at %d HP" % renzo.hp)
	_say("Rusted iron screams overhead. The Aswang drops into the alley, and the lamps die.")
	await _wait(1.6)
	_run()


func _unit(id: String) -> BattleModel.Unit:
	for a in model.allies:
		if a.id == id:
			return a
	return null


# --- Layout -------------------------------------------------------------------------------------

func _build() -> void:
	var back := ColorRect.new()
	back.color = Color(0.02, 0.03, 0.06)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	var bg := TextureRect.new()
	bg.texture = Art.panel("ep1_12_alley_delivery")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(0.4, 0.4, 0.46)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Turn-order bar (top centre)
	var top := CenterContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 10
	top.offset_bottom = 66
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_order_box = HBoxContainer.new()
	_order_box.add_theme_constant_override("separation", 8)
	_order_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_order_box)

	# Caption (what is happening)
	var cap := PanelContainer.new()
	var cap_style := _box(Color("f4e7a6"), Color("14110a"), 3, 4)
	cap_style.shadow_color = Color("14110a")
	cap_style.shadow_size = 1
	cap_style.shadow_offset = Vector2(6, 6)
	cap.add_theme_stylebox_override("panel", cap_style)
	cap.position = Vector2(36, 82)
	cap.custom_minimum_size = Vector2(560, 0)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cap)
	_log = Label.new()
	_log.add_theme_font_override("font", Fonts.label())
	_log.add_theme_font_size_override("font_size", 20)
	_log.add_theme_color_override("font_color", Color("17130a"))
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_margin(cap, 14, 9).add_child(_log)

	_build_party()
	_build_enemy()

	# Command menu (bottom centre)
	var menu_holder := CenterContainer.new()
	menu_holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	menu_holder.offset_top = -150
	menu_holder.offset_bottom = -8
	menu_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu_holder)
	var menu_col := VBoxContainer.new()
	menu_col.add_theme_constant_override("separation", 6)
	menu_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_holder.add_child(menu_col)
	_tag_label = Label.new()
	_tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag_label.add_theme_font_override("font", Fonts.label_medium())
	_tag_label.add_theme_font_size_override("font_size", 15)
	_tag_label.add_theme_color_override("font_color", Color("ffd27a"))
	menu_col.add_child(_tag_label)
	_cmd_box = HBoxContainer.new()
	_cmd_box.add_theme_constant_override("separation", 12)
	_cmd_box.mouse_filter = Control.MOUSE_FILTER_PASS
	menu_col.add_child(_cmd_box)

	_dim = ColorRect.new()
	_dim.color = Color(0.2, 0.0, 0.0, 0.5)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)

	_ring = TimingRing.new()
	add_child(_ring)

	_flash = ColorRect.new()
	_flash.color = Color.WHITE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate = Color(1, 1, 1, 0)
	add_child(_flash)

	_banner = PanelContainer.new()
	_banner.add_theme_stylebox_override("panel", _box(Color(0.04, 0.055, 0.1, 0.96), Color("ffb43a"), 2, 4))
	_banner.custom_minimum_size = Vector2(520, 0)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	add_child(_banner)
	_banner_label = Label.new()
	_banner_label.add_theme_font_override("font", Fonts.label())
	_banner_label.add_theme_font_size_override("font_size", 20)
	_banner_label.add_theme_color_override("font_color", Color("fff7d6"))
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_margin(_banner, 16, 10).add_child(_banner_label)


## One member keeps the Episode 1 layout; two members share the left half more tightly.
func _build_party() -> void:
	var n := model.allies.size()
	var panel_w := 420.0 if n == 1 else 205.0
	for i in n:
		var u: BattleModel.Unit = model.allies[i]
		var rim := Color(String(RIM.get(u.id, "c9a24a")))
		var sil_x := 150.0 if n == 1 else 70.0 + float(i) * 215.0
		var sil := Silhouette.new(u.id if u.id == "dante" else "renzo", rim)
		sil.position = Vector2(sil_x, 130)
		sil.size = Vector2(220, 340) if n == 1 else Vector2(190, 300)
		sil.pivot_offset = Vector2(sil.size.x * 0.5, sil.size.y - 10.0)
		add_child(sil)
		_sils[u.id] = sil
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _box(Color(0.04, 0.055, 0.1, 0.92), rim, 2, 6))
		panel.position = Vector2(40.0 + float(i) * (panel_w + 10.0), 470)
		panel.custom_minimum_size = Vector2(panel_w, 0)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(panel)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		_margin(panel, 12, 8).add_child(col)
		var name_label := Label.new()
		name_label.text = u.display_name.to_upper()
		name_label.add_theme_font_override("font", Fonts.label())
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", rim)
		col.add_child(name_label)
		var bar := _bar(Color("5dc46f"), u.max_hp)
		col.add_child(bar)
		_hp_bars[u.id] = bar
		var hp_label := Label.new()
		hp_label.add_theme_font_override("font", Fonts.label_medium())
		hp_label.add_theme_font_size_override("font_size", 16)
		col.add_child(hp_label)
		_hp_labels[u.id] = hp_label
		if i == 0 and model.energy_enabled():
			_energy = Control.new()
			_energy.custom_minimum_size = Vector2(0, 18)
			_energy.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_energy.draw.connect(_draw_energy)
			col.add_child(_energy)


func _build_enemy() -> void:
	_aswang_sil = Silhouette.new("aswang", Color("c8452e"))
	_aswang_sil.position = Vector2(860, 190)
	_aswang_sil.size = Vector2(300, 280)
	_aswang_sil.custom_minimum_size = Vector2(300, 280)
	_aswang_sil.pivot_offset = Vector2(150, 270)
	add_child(_aswang_sil)
	var intent := PanelContainer.new()
	intent.add_theme_stylebox_override("panel", _box(Color(0.1, 0.03, 0.03, 0.94), Color("c8452e"), 3, 6))
	intent.position = Vector2(820, 84)
	intent.custom_minimum_size = Vector2(380, 0)
	intent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(intent)
	var icol := VBoxContainer.new()
	icol.add_theme_constant_override("separation", 2)
	_margin(intent, 14, 8).add_child(icol)
	var next_label := Label.new()
	next_label.text = "NEXT ACTION"
	next_label.add_theme_font_override("font", Fonts.label_medium())
	next_label.add_theme_font_size_override("font_size", 13)
	next_label.add_theme_color_override("font_color", Color("ff9a8a"))
	icol.add_child(next_label)
	_intent_title = Label.new()
	_intent_title.add_theme_font_override("font", Fonts.display())
	_intent_title.add_theme_font_size_override("font_size", 34)
	_intent_title.add_theme_color_override("font_color", Color("fff3b0"))
	icol.add_child(_intent_title)
	_intent_guard = Label.new()
	_intent_guard.add_theme_font_override("font", Fonts.label())
	_intent_guard.add_theme_font_size_override("font_size", 16)
	_intent_guard.add_theme_color_override("font_color", Color("9fd0ff"))
	icol.add_child(_intent_guard)

	var epanel := PanelContainer.new()
	epanel.add_theme_stylebox_override("panel", _box(Color(0.04, 0.05, 0.09, 0.9), Color("c8452e"), 2, 6))
	epanel.position = Vector2(820, 470)
	epanel.custom_minimum_size = Vector2(380, 0)
	epanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(epanel)
	var ecol := VBoxContainer.new()
	ecol.add_theme_constant_override("separation", 4)
	_margin(epanel, 12, 8).add_child(ecol)
	var ename := Label.new()
	ename.text = "CORRUPTED ASWANG"
	ename.add_theme_font_override("font", Fonts.label())
	ename.add_theme_font_size_override("font_size", 18)
	ename.add_theme_color_override("font_color", Color("ff7a6a"))
	ecol.add_child(ename)
	_enemy_bar = _bar(Color("c8452e"), ENEMY_MAX_HP)
	ecol.add_child(_enemy_bar)
	_pips = Control.new()
	_pips.custom_minimum_size = Vector2(0, 18)
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips.draw.connect(_draw_pips)
	ecol.add_child(_pips)


func _box(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	return s


func _margin(parent: Control, h: int, v: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", h)
	m.add_theme_constant_override("margin_right", h)
	m.add_theme_constant_override("margin_top", v)
	m.add_theme_constant_override("margin_bottom", v)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(m)
	return m


func _bar(color: Color, max_value: int) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = max_value
	b.value = max_value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 16)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(1, 1, 1, 0.12)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bgs)
	return b


## Stagger pips are drawn shapes (no font glyphs, which the web fonts do not carry).
func _draw_pips() -> void:
	_pips.draw_string(Fonts.label_medium(), Vector2(0, 14), "STAGGER", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffd27a"))
	for i in BattleModel.STAGGER_TO_BREAK:
		var c := Vector2(100.0 + float(i) * 26.0, 9.0)
		if i < aswang.stagger:
			_pips.draw_circle(c, 8.0, Color("ffd27a"))
		else:
			_pips.draw_arc(c, 7.0, 0.0, TAU, 20, Color(1, 1, 1, 0.5), 2.0)
	if aswang.stunned:
		_pips.draw_string(Fonts.label(), Vector2(200, 14), "BROKEN: next hit x2", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ff9a8a"))


## The watch-energy meter: drawn pips that perfect parries fill.
func _draw_energy() -> void:
	_energy.draw_string(Fonts.label_medium(), Vector2(0, 14), "WATCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("00ffcc"))
	for i in BattleModel.MAX_ENERGY:
		var r := Rect2(66.0 + float(i) * 22.0, 3.0, 16.0, 12.0)
		if i < model.energy:
			_energy.draw_rect(r, Color("00ffcc"))
		else:
			_energy.draw_rect(r, Color(1, 1, 1, 0.5), false, 2.0)


# --- Battle flow --------------------------------------------------------------------------------

func _run() -> void:
	while true:
		var u := model.current()
		if u == null:
			break
		_refresh()
		if u.is_ally:
			await _ally_turn(u)
		else:
			await _enemy_turn(u)
		if model.is_victory():
			await _victory()
			return
		if model.is_defeat():
			await _defeat()
			continue
		model.end_turn()


func _ally_turn(u: BattleModel.Unit) -> void:
	_actor = u
	u.guarding = false
	_say("%s'S TURN." % u.display_name.to_upper() + ("  The Aswang's guard is broken. Hit it now!" if aswang.stunned else ""))
	var done := false
	while not done:
		_show_menu("main")
		var cmd: String = await command_chosen
		_clear_menu()
		match cmd:
			"attack":
				Sfx.play("slash-knife")
				var dmg := model.attack(aswang, u)
				_hit_enemy(dmg)
				_say("%s hits: %d damage." % [u.display_name, dmg])
				done = true
			"guard":
				model.guard(u)
				Sfx.play("command-enter")
				_say("%s braces. Incoming damage is halved." % u.display_name)
				done = true
			"taser":
				Sfx.play("stagger-break")
				var tdmg := model.taser(u, aswang)
				_hit_enemy(tdmg)
				_say("Dante's taser arcs: %d damage and the Aswang staggers." % tdmg)
				done = true
			"team":
				var moves := model.usable_team_moves()
				if not moves.is_empty():
					var t: Dictionary = moves[0]
					var total := model.team_move(t, aswang)
					Sfx.play("stagger-break-3tone")
					_hit_enemy(total)
					_say("%s! Renzo and Dante strike together: %d damage." % [String(t["name"]).to_upper(), total])
					done = true
			"item":
				_show_menu("item")
				var pick: String = await command_chosen
				_clear_menu()
				if pick == "tea":
					var healed := model.use_tea(u)
					Sfx.play("heal-chime")
					_float_text("+%d HP" % healed, _sil_pos(u) + Vector2(40, 40), Color("7dff9a"))
					_say("Lola's tea, still warm in the flask. +%d HP." % healed)
					done = true
			"skill":
				_show_menu("skill")
				var pick2: String = await command_chosen
				_clear_menu()
				if pick2.begins_with("skill:"):
					var sid := pick2.substr(6)
					var r := model.use_skill(sid, u, aswang)
					if bool(r["ok"]):
						_after_skill(sid, r)
						done = true
	_refresh()
	await _wait(0.9)
	if model.check_awakening():
		await _awakening()


func _after_skill(sid: String, r: Dictionary) -> void:
	var d := Skills.def(sid)
	var cost := int(r["utang"])
	if cost > 0:
		Story.add_utang(cost, "The watch turns back. Time stutters. +%d utang" % cost)
	_flash_color(Color("00ffcc"), 0.45)
	Sfx.play("command-exit")
	var parts: Array[String] = []
	if int(r["restored"]) > 0:
		parts.append("%d HP of the last blow never landed" % int(r["restored"]))
	if int(r["healed"]) > 0:
		parts.append("+%d HP" % int(r["healed"]))
	if int(r["damage"]) > 0:
		parts.append("%d damage" % int(r["damage"]))
	if int(r["shield"]) > 0:
		parts.append("+%d shield" % int(r["shield"]))
	if bool(r["stalled"]):
		parts.append("the Aswang is frozen in time")
	if int(r["damage"]) > 0:
		_hit_enemy(0)
	_say("%s: %s." % [String(d.get("name", sid)), ", ".join(parts) if not parts.is_empty() else "time bends"])


func _awakening() -> void:
	Progress.unlock_skill("rewind", Story.loob, 1)
	_flash_color(Color.WHITE, 0.7)
	Sfx.play("stagger-break-3tone")
	Story.consequence.emit("THE WATCH AWAKENS. New: SKILL (Rewind x1)")
	_say("Something clicks in Renzo's pocket. The hands tremble, then turn backward. The watch has awakened.")
	_refresh()
	await _wait(2.2)


func _enemy_turn(e: BattleModel.Unit) -> void:
	var was_stalled := e.stalled
	model.begin_enemy_turn(e)
	var intent: Dictionary = e.intent
	if was_stalled:
		_say("The Aswang is frozen in time. It loses its turn.")
		await _wait(1.0)
		model.plan_intent(e)
		_refresh()
		return
	var level := model.ring_level()
	var lesson := LESSON if level == "guided" else ""
	var seconds := model.ring_seconds(e)
	var bonus := model.zone_bonus()
	model.consume_parry_widen()
	var target := model.pick_target()
	_say(String(intent["text"]))
	await _wait(0.9)
	for i in int(intent["rings"]):
		if target == null or not target.alive() or not e.alive():
			break
		_dim.visible = true
		_ring.start("PARRY!", seconds, level, lesson, bonus)
		var grade: String = await _ring.finished
		_dim.visible = false
		_ring.visible = false
		var res := model.resolve_strike(e, target, grade)
		_show_strike(e, target, res)
		if bool(res["counter"]):
			await _counter(e)
		_refresh()
		await _wait(0.35)
	if target != null:
		target.guarding = false
	model.plan_intent(e)
	_refresh()


func _show_strike(e: BattleModel.Unit, target: BattleModel.Unit, res: Dictionary) -> void:
	var grade: String = res["grade"]
	if grade == "miss":
		Story.misses += 1
	else:
		Story.parries += 1
	if grade == "perfect":
		Story.perfects += 1
		Sfx.play("dodge-swish-1")
		_float_text("PERFECT PARRY!", Vector2(520, 330), Color("7dff9a"))
		if int(res["energy"]) > 0 and _energy != null:
			_float_text("+%d WATCH" % int(res["energy"]), Vector2(120, 430), Color("00ffcc"))
		_say("Parried! %s turns the claw aside." % target.display_name)
	elif grade == "good":
		Sfx.play("dodge-swish-9")
		_hurt(target, int(res["damage"]))
		_say("Half-blocked. %d damage." % int(res["damage"]))
	else:
		_hurt(target, int(res["damage"]))
		_say("The %s lands: %d damage." % [String(e.intent["name"]).to_lower(), int(res["damage"])])
	if bool(res["stagger_break"]):
		Sfx.play("stagger-break-3tone")
		_float_text("GUARD BROKEN!", Vector2(820, 150), Color("ffd27a"))


## A perfect parry opens a counter: one short ring. Land it for a heavy cut, miss it for a scratch.
func _counter(e: BattleModel.Unit) -> void:
	_say("A gap in its guard! COUNTER!")
	_dim.visible = true
	_ring.start("COUNTER!", 0.9, "free")
	var grade: String = await _ring.finished
	_dim.visible = false
	_ring.visible = false
	var strong := grade != "miss"
	var dmg := model.counter_hit(e, strong)
	Sfx.play("slash-knife")
	_hit_enemy(dmg)
	_say("%s counter: %d damage." % ["Clean" if strong else "Clumsy", dmg])


func _victory() -> void:
	_say("The Aswang comes apart into thick, oily smoke. Rain washes the alley clean of it.")
	Sfx.play("stagger-break")
	await _wait(2.4)
	finished.emit(true)


## A fatal miss: show the fall, then the watch turns the round back and everyone tries again.
func _defeat() -> void:
	Story.deaths += 1
	_say("Renzo's knees hit the wet asphalt. The alley tilts, and goes quiet.")
	var tw := create_tween()
	tw.set_parallel(true)
	for id in _sils:
		var sil: Silhouette = _sils[id]
		tw.tween_property(sil, "rotation", 1.3, 0.6)
		tw.tween_property(sil, "modulate:a", 0.25, 0.6)
	_dim.visible = true
	await _wait(1.8)
	_flash_color(Color("00ffcc"), 0.6)
	Sfx.play("command-exit")
	model.rewind_round()
	Story.add_utang(2, "The watch turns back. Renzo gets up again. +2 utang")
	var back := create_tween()
	back.set_parallel(true)
	for id in _sils:
		var sil2: Silhouette = _sils[id]
		back.tween_property(sil2, "rotation", 0.0, 0.4)
		back.tween_property(sil2, "modulate:a", 1.0, 0.4)
	_dim.visible = false
	_say("Time stutters. Renzo is on his feet again, and the Aswang is still here.")
	_refresh()
	await _wait(1.4)


# --- Menu ---------------------------------------------------------------------------------------

func _clear_menu() -> void:
	for c in _cmd_box.get_children():
		_cmd_box.remove_child(c)
		c.queue_free()
	_buttons.clear()


func _add_button(cmd: String, text: String, enabled: bool = true) -> Button:
	var b := Button.new()
	b.name = "Btn_" + cmd.replace(":", "_")
	b.text = text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(200, 74)
	b.add_theme_font_override("font", Fonts.display())
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(func() -> void: command_chosen.emit(cmd))
	_cmd_box.add_child(b)
	_buttons[cmd] = b
	return b


func _label_for(actor: BattleModel.Unit, cmd: String) -> String:
	var labels: Dictionary = PartyData.member(actor.id).get("labels", {})
	return String(labels.get(cmd, cmd.to_upper()))


func _show_menu(mode: String) -> void:
	menu_mode = mode
	_clear_menu()
	var actor := _actor if _actor != null else model.allies[0]
	var usable := model.usable(actor)
	match mode:
		"item":
			_tag_label.text = "ITEM"
			_add_button("tea", "TEA  x%d" % model.teas, model.teas > 0)
			_add_button("back", "BACK")
		"skill":
			_tag_label.text = "SKILL"
			for s in model.skills:
				var d := Skills.def(String(s["id"]))
				var left := int(s.get("uses_left", -1))
				var label := String(d.get("name", s["id"])).to_upper()
				label += "  x%d" % left if left >= 0 else "  (%d)" % int(d.get("energy_cost", 0))
				_add_button("skill:" + String(s["id"]), label, model.skill_usable(s))
			_add_button("back", "BACK")
		_:
			if episode == 1:
				_tag_label.text = "ONLY ATTACK, GUARD AND ITEM FOR NOW" if not model.skill_unlocked else "THE WATCH HAS AWAKENED"
			else:
				_tag_label.text = actor.display_name.to_upper()
			for c in model.commands_of(actor):
				var cmd := String(c)
				if cmd == "skill" and model.skills.is_empty():
					continue
				_add_button(cmd, _label_for(actor, cmd), usable.has(cmd))
			if not model.team_moves.is_empty():
				_add_button("team", "BAYANIHAN", usable.has("team"))
	for cmd in _buttons:
		var b: Button = _buttons[cmd]
		if not b.disabled:
			b.grab_focus()
			break


## The buttons a player can press right now (the tests check this is never empty).
func enabled_commands() -> Array[String]:
	var out: Array[String] = []
	for cmd in _buttons:
		var b: Button = _buttons[cmd]
		if not b.disabled and b.is_visible_in_tree():
			out.append(cmd)
	return out


# --- UI helpers ---------------------------------------------------------------------------------

func _sil_pos(u: BattleModel.Unit) -> Vector2:
	var sil: Silhouette = _sils.get(u.id)
	return sil.position if sil != null else Vector2(150, 130)


func _refresh() -> void:
	for u in model.allies:
		var bar: ProgressBar = _hp_bars[u.id]
		bar.value = u.hp
		var label: Label = _hp_labels[u.id]
		label.text = "HP  %d / %d" % [u.hp, u.max_hp] + ("   SHIELD %d" % u.shield if u.shield > 0 else "")
	_enemy_bar.value = aswang.hp
	if not aswang.intent.is_empty():
		_intent_title.text = model.intent_text(aswang)
		_intent_guard.text = model.intent_guarded_text(aswang)
	_pips.queue_redraw()
	if _energy != null:
		_energy.queue_redraw()
	_refresh_order()


func _refresh_order() -> void:
	for c in _order_box.get_children():
		_order_box.remove_child(c)
		c.queue_free()
	var turns := model.preview(7)
	for i in turns.size():
		var u: BattleModel.Unit = turns[i]
		var chip := PanelContainer.new()
		var style := _box(Color("c9a24a") if u.is_ally else Color("c8452e"), Color("f2efe4") if i == 0 else Color("14110a"), 3 if i == 0 else 1, 6)
		chip.add_theme_stylebox_override("panel", style)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := Label.new()
		l.text = u.display_name.substr(0, 1).to_upper()
		l.add_theme_font_override("font", Fonts.display())
		l.add_theme_font_size_override("font_size", 28 if i == 0 else 22)
		l.add_theme_color_override("font_color", Color("14110a"))
		l.custom_minimum_size = Vector2(44 if i == 0 else 34, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(l)
		_order_box.add_child(chip)


func _say(text: String) -> void:
	_log.text = text


func _wait(seconds: float) -> void:
	if fast:
		await get_tree().process_frame
		return
	await get_tree().create_timer(seconds).timeout


func _hit_enemy(dmg: int) -> void:
	if dmg > 0:
		_float_text("-%d" % dmg, _aswang_sil.position + Vector2(100, 40), Color("fff3b0"))
	var tw := create_tween()
	tw.tween_property(_aswang_sil, "modulate", Color(1.6, 0.6, 0.6), 0.06)
	tw.tween_property(_aswang_sil, "modulate", Color.WHITE, 0.15)
	_refresh()


func _hurt(u: BattleModel.Unit, dmg: int) -> void:
	if dmg > 0:
		Sfx.play("hit-thud")
		_float_text("-%d" % dmg, _sil_pos(u) + Vector2(60, 60), Color("ff7a6a"))
		_shake()


func _flash_color(color: Color, alpha: float) -> void:
	_flash.modulate = Color(color.r, color.g, color.b, alpha)
	create_tween().tween_property(_flash, "modulate:a", 0.0, 0.5)


func _float_text(text: String, pos: Vector2, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_override("font", Fonts.display())
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", pos.y - 60.0, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _shake() -> void:
	var tw := create_tween()
	for i in 6:
		var amp := 10.0 * (1.0 - float(i) / 6.0)
		tw.tween_property(self, "position", Vector2(randf_range(-amp, amp), randf_range(-amp, amp)), 0.04)
	tw.tween_property(self, "position", Vector2.ZERO, 0.04)


func _notify(text: String) -> void:
	_banner_label.text = text
	_banner.reset_size()
	_banner.position = Vector2((get_viewport_rect().size.x - _banner.size.x) * 0.5, 130.0)
	_banner.visible = true
	_banner.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.4)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void: _banner.visible = false)
