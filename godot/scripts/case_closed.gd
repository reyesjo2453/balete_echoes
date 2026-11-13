class_name CaseClosed
extends Control
## The end-of-case level-up (scripts/levels.gd): the classic fanfare, every standing party member a level up with what
## it adds, and a choice of two upgrades each. finished() once everyone has picked and CONTINUE is pressed.
## Tests set `fast`: the first upgrade is taken for everyone and it closes itself.

signal finished

var episode := 1
var fast := false
var picked: Dictionary = {} # member id -> perk id
var _continue: Button
var _rows: Dictionary = {} # member id -> [Button, Button]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.color = Color(0.02, 0.03, 0.08)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var col := VBoxContainer.new()
	col.position = Vector2(140, 34)
	col.custom_minimum_size = Vector2(1000, 0)
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	var title := _label(Fonts.display(), 58, Color("ffd27a"))
	title.text = "CASE CLOSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := _label(Fonts.label_medium(), 20, Color(1, 1, 1, 0.75))
	sub.text = "Everyone who stood with Teo comes out of it a little stronger. Choose one upgrade each."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var first: Button = null
	for id in Levels.roster(episode):
		var row := _member_row(String(id))
		col.add_child(row)
		if first == null:
			first = (_rows[id] as Array)[0]
	_continue = Button.new()
	_continue.name = "LevelContinue"
	_continue.text = "CONTINUE"
	_continue.custom_minimum_size = Vector2(300, 60)
	Retro.style_button(_continue, 26)
	_continue.disabled = true
	_continue.pressed.connect(func() -> void: finished.emit())
	var c := CenterContainer.new()
	c.add_child(_continue)
	col.add_child(c)
	Sfx.play("stagger-break-3tone")
	if fast:
		for id in _rows:
			_pick(String(id), 0)
		finished.emit.call_deferred()
	elif first != null:
		first.grab_focus.call_deferred()


func _member_row(id: String) -> Control:
	var win := Retro.window(18, 10)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	win.add_child(h)
	var face := TextureRect.new()
	face.texture = Art.portrait("portrait_" + id)
	face.custom_minimum_size = Vector2(96, 96)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(face)
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(330, 0)
	h.add_child(info)
	var d: Dictionary = StageBattle.MEMBERS.get(id, {})
	var lv := Levels.level(id, episode)
	var now := Levels.mods(id, episode)
	var g: Dictionary = Levels.GROWTH.get(id, {})
	var name_l := _label(Fonts.label(), 26, Retro.NAME)
	name_l.text = "%s     LV %d  >  %d" % [String(d.get("name", id.to_upper())), lv, lv + 1]
	info.add_child(name_l)
	var hp := int(d.get("hp", 100)) + int(now.get("hp", 0))
	var stats := _label(Fonts.label_medium(), 19)
	stats.text = "MAX HP %d > %d      DAMAGE +%d" % [hp, hp + int(g.get("hp", 0)), int(g.get("hit", 0))]
	info.add_child(stats)
	var picks := VBoxContainer.new()
	picks.add_theme_constant_override("separation", 6)
	h.add_child(picks)
	var buttons: Array = []
	var options := Levels.choices(id, episode)
	for i in options.size():
		var perk: Dictionary = options[i]
		var b := Button.new()
		b.name = "Perk_%s_%s" % [id, perk["id"]]
		b.text = "%s   %s" % [perk["name"], perk["text"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(480, 42)
		Retro.style_button(b, 19)
		var idx := i
		b.pressed.connect(func() -> void: _pick(id, idx))
		picks.add_child(b)
		buttons.append(b)
	_rows[id] = buttons
	return win


func _pick(id: String, idx: int) -> void:
	var options := Levels.choices(id, episode)
	if idx >= options.size():
		return
	picked[id] = String(options[idx]["id"])
	Progress.pick_perk(episode, id, picked[id])
	Sfx.play("heal-chime")
	var buttons: Array = _rows.get(id, [])
	for i in buttons.size():
		var b: Button = buttons[i]
		b.modulate = Color(1, 1, 1, 1.0 if i == idx else 0.4)
		b.text = ("> " if i == idx else "") + b.text.trim_prefix("> ")
	_continue.disabled = picked.size() < _rows.size()
	if not _continue.disabled and not fast:
		_continue.grab_focus()


func _label(font: Font, px: int, color: Color = Color("f2efe4")) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
