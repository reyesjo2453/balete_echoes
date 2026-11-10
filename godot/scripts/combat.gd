class_name Combat
extends Control
## Turn-based fight with a timed parry on the enemy's turn (the combat of the Godot port).
##
## Renzo's turn: Slash / Guard / Tea / Watch. The Aswang's turn: it telegraphs an attack, then a ring closes
## on a target: press in the glowing zone to parry (perfect = no damage, a counter, and a stagger; good = most
## of the damage blocked). Three perfect parries stagger it: Renzo's next Slash lands double.
## The parry is taught in order (guided, assisted, then free), exactly like the story QTEs.

signal finished(victory: bool)
signal command_chosen(cmd: String)

const MAX_HP := 100
const ENEMY_MAX_HP := 140
const TEA_HEAL := 30
const STAGGER_TO_BREAK := 3

const ATTACKS := {
	"claw": {"name": "Claw", "telegraph": "The Aswang rakes the air, claws low.", "rings": 1, "seconds": 1.5, "damage": 18},
	"lunge": {"name": "Lunge", "telegraph": "The Aswang coils, every rib showing... and LUNGES.", "rings": 1, "seconds": 1.0, "damage": 28},
	"flurry": {"name": "Flurry", "telegraph": "It whirls into a blur of claws. Three strikes, one breath.", "rings": 3, "seconds": 0.9, "damage": 9},
}

const LESSON := "The Aswang is about to strike. Watch the big ring close on the white circle. When it glows green, press SPACE (A button) or TAP to PARRY."

var hp: int = MAX_HP
var enemy_hp: int = ENEMY_MAX_HP
var stagger: int = 0
var stunned: bool = false
var guarding: bool = false
var teas: int = 2
var watch_used: bool = false
var enemy_turns: int = 0
var hp_before_enemy: int = MAX_HP
var rng := RandomNumberGenerator.new()

var _log: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _enemy_bar: ProgressBar
var _stagger_label: Label
var _enemy_card: TextureRect
var _cmd_box: HBoxContainer
var _buttons: Dictionary = {}
var _ring: TimingRing
var _dim: ColorRect
var _flash: ColorRect
var _over_box: VBoxContainer
var _tea_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rng.randomize()
	_build()
	_refresh()


func begin() -> void:
	Sfx.bgm("determined-pursuit")
	_say("Rusted iron screams overhead. The Aswang drops into the alley, and the lamps die.")
	await _wait(1.6)
	_run()


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
	bg.modulate = Color(0.45, 0.45, 0.5)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Enemy card (right)
	var enemy_panel := PanelContainer.new()
	enemy_panel.add_theme_stylebox_override("panel", _box(Color(0.04, 0.05, 0.09, 0.9), Color("c8452e"), 3, 6))
	enemy_panel.position = Vector2(700, 96)
	enemy_panel.custom_minimum_size = Vector2(520, 0)
	add_child(enemy_panel)
	var ecol := VBoxContainer.new()
	ecol.add_theme_constant_override("separation", 8)
	var em := _margin(enemy_panel, 14, 14)
	em.add_child(ecol)
	_enemy_card = TextureRect.new()
	_enemy_card.texture = Art.panel("ep1_13_aswang_fire_escape")
	_enemy_card.custom_minimum_size = Vector2(490, 270)
	_enemy_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_enemy_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ecol.add_child(_enemy_card)
	var ename := Label.new()
	ename.text = "CORRUPTED ASWANG"
	ename.add_theme_font_override("font", Fonts.label())
	ename.add_theme_font_size_override("font_size", 20)
	ename.add_theme_color_override("font_color", Color("ff7a6a"))
	ecol.add_child(ename)
	_enemy_bar = _bar(Color("c8452e"), ENEMY_MAX_HP)
	ecol.add_child(_enemy_bar)
	_stagger_label = Label.new()
	_stagger_label.add_theme_font_override("font", Fonts.label_medium())
	_stagger_label.add_theme_font_size_override("font_size", 16)
	_stagger_label.add_theme_color_override("font_color", Color("ffd27a"))
	ecol.add_child(_stagger_label)

	# Renzo card (left)
	var player_panel := PanelContainer.new()
	player_panel.add_theme_stylebox_override("panel", _box(Color(0.04, 0.055, 0.1, 0.92), Color("c9a24a"), 3, 6))
	player_panel.position = Vector2(48, 330)
	player_panel.custom_minimum_size = Vector2(500, 0)
	add_child(player_panel)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 16)
	_margin(player_panel, 14, 14).add_child(prow)
	var portrait := TextureRect.new()
	portrait.texture = Art.portrait("renzo")
	portrait.custom_minimum_size = Vector2(120, 120)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	prow.add_child(portrait)
	var pcol := VBoxContainer.new()
	pcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pcol.add_theme_constant_override("separation", 6)
	prow.add_child(pcol)
	var pname := Label.new()
	pname.text = "RENZO"
	pname.add_theme_font_override("font", Fonts.label())
	pname.add_theme_font_size_override("font_size", 22)
	pname.add_theme_color_override("font_color", Color("c9a24a"))
	pcol.add_child(pname)
	_hp_bar = _bar(Color("5dc46f"), MAX_HP)
	pcol.add_child(_hp_bar)
	_hp_label = Label.new()
	_hp_label.add_theme_font_override("font", Fonts.label_medium())
	_hp_label.add_theme_font_size_override("font_size", 17)
	pcol.add_child(_hp_label)
	_tea_label = Label.new()
	_tea_label.add_theme_font_override("font", Fonts.label_medium())
	_tea_label.add_theme_font_size_override("font_size", 15)
	_tea_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	pcol.add_child(_tea_label)

	# Caption (what is happening)
	var cap := PanelContainer.new()
	var cap_style := _box(Color("f4e7a6"), Color("14110a"), 3, 4)
	cap_style.shadow_color = Color("14110a")
	cap_style.shadow_size = 1
	cap_style.shadow_offset = Vector2(6, 6)
	cap.add_theme_stylebox_override("panel", cap_style)
	cap.position = Vector2(40, 30)
	cap.custom_minimum_size = Vector2(600, 0)
	add_child(cap)
	_log = Label.new()
	_log.add_theme_font_override("font", Fonts.label())
	_log.add_theme_font_size_override("font_size", 21)
	_log.add_theme_color_override("font_color", Color("17130a"))
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_margin(cap, 16, 11).add_child(_log)

	# Commands (bottom)
	_cmd_box = HBoxContainer.new()
	_cmd_box.add_theme_constant_override("separation", 14)
	_cmd_box.position = Vector2(48, 596)
	add_child(_cmd_box)
	for def in [["slash", "SLASH"], ["guard", "GUARD"], ["tea", "TEA"], ["watch", "WATCH"]]:
		var b := Button.new()
		b.text = def[1]
		b.custom_minimum_size = Vector2(200, 84)
		b.add_theme_font_override("font", Fonts.display())
		b.add_theme_font_size_override("font_size", 28)
		var cmd: String = def[0]
		b.pressed.connect(func() -> void: command_chosen.emit(cmd))
		_cmd_box.add_child(b)
		_buttons[cmd] = b

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

	_over_box = VBoxContainer.new()
	_over_box.position = Vector2(380, 300)
	_over_box.custom_minimum_size = Vector2(520, 0)
	_over_box.add_theme_constant_override("separation", 12)
	_over_box.visible = false
	add_child(_over_box)


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
	parent.add_child(m)
	return m


func _bar(color: Color, max_value: int) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = max_value
	b.value = max_value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 18)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(1, 1, 1, 0.12)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bgs)
	return b


# --- Turn flow ----------------------------------------------------------------------------------

func _run() -> void:
	while true:
		await _player_turn()
		if enemy_hp <= 0:
			await _victory()
			return
		await _enemy_turn()
		if hp <= 0:
			await _defeat()


func _player_turn() -> void:
	guarding = false
	_say("YOUR TURN." + ("  The Aswang is STAGGERED. Hit it now!" if stunned else ""))
	_set_commands(true)
	var cmd: String = await command_chosen
	_set_commands(false)
	match cmd:
		"slash":
			var dmg := rng.randi_range(18, 24)
			if stunned:
				dmg *= 2
				stunned = false
			Sfx.play("slash-knife")
			_damage_enemy(dmg)
			_say("Renzo's balisong flashes: %d damage." % dmg)
		"guard":
			guarding = true
			Sfx.play("command-enter")
			_say("Renzo braces behind his jacket. Incoming damage halved.")
		"tea":
			teas -= 1
			hp = mini(MAX_HP, hp + TEA_HEAL)
			Sfx.play("heal-chime")
			_float_text("+%d HP" % TEA_HEAL, Vector2(300, 330), Color("7dff9a"))
			_say("Lola's tea, still warm in the flask. +%d HP." % TEA_HEAL)
		"watch":
			watch_used = true
			hp = maxi(hp, hp_before_enemy)
			Story.add_utang(2, "The watch turns back. Time stutters. +2 utang")
			Sfx.play("command-exit")
			_flash.modulate = Color("00ffcc")
			_flash.modulate.a = 0.45
			create_tween().tween_property(_flash, "modulate:a", 0.0, 0.5)
			_say("The watch turns back: the last blow never landed.")
	_refresh()
	await _wait(1.0)


func _pick_attack() -> Dictionary:
	enemy_turns += 1
	if enemy_turns <= 2:
		return ATTACKS["claw"]
	var keys := ["claw", "lunge", "flurry"]
	return ATTACKS[keys[rng.randi_range(0, keys.size() - 1)]]


func _enemy_turn() -> void:
	hp_before_enemy = hp
	var atk := _pick_attack()
	_say(String(atk["telegraph"]))
	await _wait(1.0)
	var level := "free"
	var lesson := ""
	var seconds := float(atk["seconds"])
	if enemy_turns == 1:
		level = "guided"
		lesson = LESSON
		seconds = 2.8
	elif enemy_turns == 2:
		level = "assisted"
		seconds = 1.8
	for i in int(atk["rings"]):
		_dim.visible = true
		_ring.start("PARRY!", seconds, level, lesson)
		var grade: String = await _ring.finished
		_dim.visible = false
		_ring.visible = false
		_resolve_parry(atk, grade)
		_refresh()
		if hp <= 0:
			return
		await _wait(0.35)
	guarding = false


func _resolve_parry(atk: Dictionary, grade: String) -> void:
	var dmg: int = atk["damage"]
	var factor := 0.5 if guarding else 1.0
	match grade:
		"perfect":
			Story.parries += 1
			Story.perfects += 1
			Sfx.play("dodge-swish-1")
			_float_text("PERFECT PARRY!", Vector2(520, 300), Color("7dff9a"))
			_damage_enemy(10)
			stagger += 1
			if stagger >= STAGGER_TO_BREAK:
				stagger = 0
				stunned = true
				Sfx.play("stagger-break-3tone")
				_float_text("STAGGERED!", Vector2(760, 90), Color("ffd27a"))
				_say("The Aswang's guard breaks. Its next wound will cut deep.")
			else:
				_say("Parried! Renzo turns the claw aside and cuts back.")
		"good":
			Story.parries += 1
			var taken := int(round(dmg * 0.4 * factor))
			Sfx.play("dodge-swish-9")
			_damage_player(taken)
			_say("Half-blocked. %d damage." % taken)
		_:
			var taken := int(round(dmg * factor))
			_damage_player(taken)
			_say("The %s lands: %d damage." % [String(atk["name"]).to_lower(), taken])


func _damage_player(n: int) -> void:
	hp = maxi(0, hp - n)
	Sfx.play("hit-thud")
	_float_text("-%d" % n, Vector2(300, 360), Color("ff7a6a"))
	_shake()


func _damage_enemy(n: int) -> void:
	enemy_hp = maxi(0, enemy_hp - n)
	_float_text("-%d" % n, Vector2(900, 200), Color("fff3b0"))
	var tw := create_tween()
	tw.tween_property(_enemy_card, "modulate", Color(1, 0.5, 0.5), 0.06)
	tw.tween_property(_enemy_card, "modulate", Color.WHITE, 0.15)
	_refresh()


func _victory() -> void:
	_say("The Aswang comes apart into thick, oily smoke. Rain washes the alley clean of it.")
	Sfx.play("stagger-break")
	await _wait(2.4)
	finished.emit(true)


func _defeat() -> void:
	_say("Renzo's knees hit the wet asphalt. The alley tilts.")
	_dim.visible = true
	await _wait(1.2)
	for c in _over_box.get_children():
		c.queue_free()
	var lbl := Label.new()
	lbl.text = "The watch is warm against your ribs."
	lbl.add_theme_font_override("font", Fonts.label())
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_box.add_child(lbl)
	var b := Button.new()
	b.text = "TURN THE WATCH BACK  (+2 UTANG)"
	b.custom_minimum_size = Vector2(520, 64)
	b.add_theme_font_override("font", Fonts.display())
	b.add_theme_font_size_override("font_size", 24)
	_over_box.add_child(b)
	_over_box.visible = true
	b.grab_focus()
	await b.pressed
	_over_box.visible = false
	_dim.visible = false
	Story.add_utang(2, "The watch turns back. +2 utang")
	hp = MAX_HP
	stagger = 0
	_refresh()
	_say("Time stutters. Renzo is on his feet again, and the Aswang is still here.")
	await _wait(1.2)


# --- UI helpers ---------------------------------------------------------------------------------

func _set_commands(on: bool) -> void:
	_buttons["tea"].disabled = teas <= 0
	_buttons["watch"].disabled = watch_used or hp >= hp_before_enemy
	var first: Button = null
	for cmd in _buttons:
		var b: Button = _buttons[cmd]
		if not on:
			b.disabled = true
		elif first == null and not b.disabled:
			first = b
	if on and first != null:
		first.grab_focus()


func _refresh() -> void:
	_hp_bar.value = hp
	_hp_label.text = "HP  %d / %d" % [hp, MAX_HP]
	_enemy_bar.value = enemy_hp
	_stagger_label.text = "STAGGER  " + "●".repeat(stagger) + "○".repeat(STAGGER_TO_BREAK - stagger) + ("   (BROKEN: next hit x2)" if stunned else "")
	_tea_label.text = "Tea x%d    Watch %s" % [teas, "spent" if watch_used else "ready"]


func _say(text: String) -> void:
	_log.text = text


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


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
