extends Control
## Vertical-slice flow: title -> 6 AM stakes -> the shop (teaches the timing ring) -> the Honda kick-start ->
## the rain courier run -> Dante's call -> the alley -> turn-based fight with a timed parry -> end card.

var _title: Control
var _layer: Control
var _running := false
var _rotate: CanvasLayer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer = Control.new()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_layer)
	_build_rotate_overlay()
	_show_title()


## Phones held upright get a "rotate" card (the game is designed for landscape).
func _build_rotate_overlay() -> void:
	_rotate = CanvasLayer.new()
	_rotate.layer = 100
	add_child(_rotate)
	var back := ColorRect.new()
	back.color = Color(0.02, 0.03, 0.06, 0.97)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rotate.add_child(back)
	var l := Label.new()
	l.text = "ROTATE YOUR PHONE\nBalete plays in landscape"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.add_theme_font_override("font", Fonts.display())
	l.add_theme_font_size_override("font_size", 64)
	l.add_theme_color_override("font_color", Color("e8c872"))
	_rotate.add_child(l)
	get_viewport().size_changed.connect(_update_rotate)
	_update_rotate()


func _update_rotate() -> void:
	var win := DisplayServer.window_get_size()
	_rotate.visible = Story.is_touch() and win.y > win.x


func _toggle_fullscreen() -> void:
	var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _show_title() -> void:
	_clear()
	_title = Control.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_title)
	var tex := TextureRect.new()
	tex.texture = Art.panel("ep1_01_quiapo_dawn")
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.modulate = Color(0.35, 0.35, 0.42)
	_title.add_child(tex)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.position = Vector2(240, 190)
	col.custom_minimum_size = Vector2(800, 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	_title.add_child(col)
	col.add_child(_big("BALETE", Fonts.display(), 128, Color("e8c872")))
	col.add_child(_big("ECHOES OF THE SUNKEN VEIL", Fonts.label(), 30, Color("f2d58a")))
	col.add_child(_big("EPISODE 1  ·  VERTICAL SLICE", Fonts.label_medium(), 18, Color(1, 1, 1, 0.65)))
	var start := Button.new()
	start.text = "START"
	start.custom_minimum_size = Vector2(300, 74)
	start.add_theme_font_override("font", Fonts.display())
	start.add_theme_font_size_override("font_size", 34)
	start.pressed.connect(_start_game)
	var holder := CenterContainer.new()
	holder.add_child(start)
	col.add_child(holder)
	col.add_child(_big("TAP  ·  CLICK  ·  SPACE  ·  A BUTTON", Fonts.label_medium(), 16, Color(1, 1, 1, 0.6)))
	var fs := Button.new()
	fs.text = "FULLSCREEN"
	fs.custom_minimum_size = Vector2(200, 56)
	fs.add_theme_font_override("font", Fonts.label())
	fs.add_theme_font_size_override("font_size", 18)
	fs.pressed.connect(_toggle_fullscreen)
	var fs_holder := CenterContainer.new()
	fs_holder.add_child(fs)
	col.add_child(fs_holder)
	col.add_child(_big("'Aphelion' and 'Undertow' by Scott Buckley, CC-BY 4.0. www.scottbuckley.com.au", Fonts.body(), 13, Color(1, 1, 1, 0.4)))
	start.grab_focus()


func _big(text: String, font: Font, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	return l


func _clear() -> void:
	for c in _layer.get_children():
		c.queue_free()


func _start_game() -> void:
	if _running:
		return
	_running = true
	Sfx.bgm("aphelion")
	Story.reset()
	_clear()
	await _play("stakes")
	await _play("shop_morning")
	await _play("step_out")
	await _run_courier()
	await _play("dante_call")
	await _play("alley_arrival")
	await _run_fight()
	await _play("after_fight")
	_show_end()
	_running = false


func _play(scene_id: String) -> void:
	var steps := Story.scene(scene_id)
	if steps.is_empty():
		return
	_clear()
	var d := Dialogue.new()
	_layer.add_child(d)
	d.play(steps)
	await d.finished
	d.queue_free()


func _run_courier() -> void:
	_clear()
	var run := CourierRun.new()
	_layer.add_child(run)
	var hits: int = await run.finished
	run.queue_free()
	if hits >= 3:
		Story.add_utang(1, "The tow truck got within a block of you: +1 utang")
	await get_tree().create_timer(0.4).timeout


func _run_fight() -> void:
	_clear()
	var fight := Combat.new()
	_layer.add_child(fight)
	fight.begin()
	var won: bool = await fight.finished
	fight.queue_free()
	if won:
		await get_tree().create_timer(0.3).timeout


func _show_end() -> void:
	_clear()
	var back := ColorRect.new()
	back.color = Color(0.02, 0.03, 0.06)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(back)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.position = Vector2(300, 150)
	col.custom_minimum_size = Vector2(680, 0)
	col.add_theme_constant_override("separation", 12)
	_layer.add_child(col)
	col.add_child(_big("END OF THE SLICE", Fonts.display(), 72, Color("e8c872")))
	col.add_child(_big("Utang (family debt): %d" % Story.utang, Fonts.label(), 26, Color("ffb43a")))
	col.add_child(_big("Loob (resolve): %d" % Story.loob, Fonts.label(), 26, Color("aeb9ff")))
	col.add_child(_big("Parries: %d   Perfect: %d" % [Story.parries, Story.perfects], Fonts.label(), 26, Color("7dff9a")))
	col.add_child(_big("Money: P%d" % Story.money, Fonts.label(), 22, Color(1, 1, 1, 0.7)))
	var again := Button.new()
	again.text = "PLAY AGAIN"
	again.custom_minimum_size = Vector2(300, 70)
	again.add_theme_font_override("font", Fonts.display())
	again.add_theme_font_size_override("font_size", 30)
	again.pressed.connect(func() -> void:
		_running = false
		_show_title())
	var holder := CenterContainer.new()
	holder.add_child(again)
	col.add_child(holder)
	again.grab_focus()
