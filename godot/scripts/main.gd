extends Control
## Vertical-slice flow: title -> 6 AM stakes -> the shop (teaches the timing ring) -> the Honda kick-start ->
## the rain courier run -> Dante's call -> the alley -> turn-based fight with a timed parry -> end card.

var _title: Control
var _layer: Control
var _running := false
## Tests set this to run the whole episode without waiting on real time.
var test_fast: bool = false
var _rotate: CanvasLayer
var _rotate_dismissed := false
## Tests set this to pretend the window has another size (the real window is not resizable in headless runs).
var window_size_override: Vector2i = Vector2i.ZERO
var _card_active := false
var _card_skip := false
var _card_age := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer = Control.new()
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	_apply_safe_area()
	_build_rotate_overlay()
	_show_title()


## Phones held upright get a "rotate" card (the game is designed for landscape).
func _build_rotate_overlay() -> void:
	_rotate = CanvasLayer.new()
	_rotate.layer = 100
	add_child(_rotate)
	var back := ColorRect.new()
	back.color = Color(0.02, 0.03, 0.06, 0.97)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rotate.add_child(back)
	var l := Label.new()
	l.text = "ROTATE YOUR PHONE\nfor a bigger view\n\nTap to play anyway"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Fonts.display())
	l.add_theme_font_size_override("font_size", 56)
	l.add_theme_color_override("font_color", Color("e8c872"))
	_rotate.add_child(l)
	get_viewport().size_changed.connect(_update_rotate)
	_update_rotate()


## Keep UI out from under a phone's notch or rounded corners (no-op where the whole window is safe).
func _apply_safe_area() -> void:
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0:
		return
	var vp := get_viewport_rect().size
	var kx := vp.x / float(win.x)
	var ky := vp.y / float(win.y)
	_layer.offset_left = clampf(float(safe.position.x) * kx, 0.0, 64.0)
	_layer.offset_top = clampf(float(safe.position.y) * ky, 0.0, 40.0)
	_layer.offset_right = -clampf(float(win.x - safe.end.x) * kx, 0.0, 64.0)
	_layer.offset_bottom = -clampf(float(win.y - safe.end.y) * ky, 0.0, 40.0)


func _window_size() -> Vector2i:
	return window_size_override if window_size_override != Vector2i.ZERO else DisplayServer.window_get_size()


## A tall narrow screen (a folded phone's cover display, a phone held upright) gets a suggestion to rotate,
## never a wall: one tap dismisses it and the game plays small but fully.
func _update_rotate() -> void:
	var win := _window_size()
	var portrait := win.y > win.x
	if not portrait:
		_rotate_dismissed = false
	_rotate.visible = Story.is_touch() and portrait and not _rotate_dismissed


func _toggle_fullscreen() -> void:
	var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _show_title() -> void:
	_clear()
	_title = Control.new()
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_title)
	var tex := TextureRect.new()
	tex.texture = Art.panel("ep1_01_quiapo_dawn")
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.modulate = Color(0.35, 0.35, 0.42)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(tex)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(800, 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)
	col.add_child(_big("BALETE", Fonts.display(), 120, Color("e8c872")))
	col.add_child(_big("ECHOES OF THE SUNKEN VEIL", Fonts.label(), 30, Color("f2d58a")))
	col.add_child(_big("EPISODE 1  ·  VERTICAL SLICE", Fonts.label_medium(), 18, Color(1, 1, 1, 0.65)))
	var start := Button.new()
	start.name = "StartButton"
	start.text = "START"
	start.custom_minimum_size = Vector2(300, 78)
	start.add_theme_font_override("font", Fonts.display())
	start.add_theme_font_size_override("font_size", 34)
	start.pressed.connect(_start_game)
	col.add_child(_centered(start))
	col.add_child(_big("TAP  ·  CLICK  ·  SPACE  ·  A BUTTON", Fonts.label_medium(), 16, Color(1, 1, 1, 0.6)))
	var fs := Button.new()
	fs.name = "FullscreenButton"
	fs.text = "FULLSCREEN"
	fs.custom_minimum_size = Vector2(200, 56)
	fs.add_theme_font_override("font", Fonts.label())
	fs.add_theme_font_size_override("font_size", 18)
	fs.pressed.connect(_toggle_fullscreen)
	col.add_child(_centered(fs))
	col.add_child(_big("'Aphelion' and 'Undertow' by Scott Buckley, CC-BY 4.0. www.scottbuckley.com.au", Fonts.body(), 13, Color(1, 1, 1, 0.4)))
	var build := _big(Story.build_label(), Fonts.label_medium(), 14, Color(1, 1, 1, 0.45))
	build.name = "BuildLabel"
	build.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	build.offset_left = -240
	build.offset_top = -34
	build.offset_right = -16
	build.offset_bottom = -10
	build.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_title.add_child(build)
	start.grab_focus()


## A control centred in its row (a container, so it never depends on the parent's size at build time).
func _centered(c: Control) -> CenterContainer:
	var h := CenterContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(c)
	return h


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
	for act in Story.flow.get("acts", []):
		for beat in act["beats"]:
			if Story.cond_ok(beat):
				await _play_beat(beat, int(act["number"]))
	_show_end()
	_running = false


## One beat of the Episode 1 flow (data/episode1_flow.json): a card, a scene, the board, a ride, a fight.
func _play_beat(beat: Dictionary, act: int) -> void:
	match String(beat.get("type", "")):
		"previously":
			await _previously_on()
		"act_card":
			await _act_card(act)
		"scene":
			await _play(String(beat["id"]))
		"board":
			await _run_board()
		"run":
			await _run_courier(beat)
		"fight":
			await _run_fight(beat)
		"settle":
			_settle_honda()


## Noon: the church parcel pays, then the Honda debt is paid, or Valdez's tow truck takes the bike.
func _settle_honda() -> void:
	Story.money += 2000
	Story.spend_time(60)
	if Story.money >= 3450:
		Story.money -= 3450
		Story.queue_banner("Honda Beat paid off (P3,450). Valdez's tow truck leaves empty.")
		Story.flags["honda_paid"] = true
	else:
		Story.add_utang(3)
		Story.queue_banner("Noon: Valdez's tow truck takes the Honda. Mang Domeng lends you his old bike. +3 utang")
		Story.flags["honda_towed"] = true


## A full-screen teleserye card: big title and small lines. It ends by itself, but a tap, click, Enter or
## controller A skips it right away (a hint says so once that works).
func _card(big: String, lines: Array, hold: float = 3.2) -> void:
	_clear()
	var card := Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(card)
	var back := ColorRect.new()
	back.color = Color(0.02, 0.03, 0.06)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(back)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(900, 0)
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)
	col.add_child(_big(big, Fonts.display(), 64, Color("e8c872")))
	for line in lines:
		var l := _big(String(line), Fonts.body(), 24, Color(1, 1, 1, 0.85))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
	var hint := _big(Story.continue_hint(), Fonts.label_medium(), 16, Color(1, 1, 1, 0.6))
	hint.name = "ContinueHint"
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -44
	hint.offset_bottom = -14
	hint.modulate = Color(1, 1, 1, 0)
	card.add_child(hint)
	col.modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(col, "modulate:a", 1.0, 0.6)
	_card_active = true
	_card_skip = false
	_card_age = 0.0
	var t := 0.0
	var hint_shown := false
	if test_fast:
		hold = 0.05
	while t < hold and not _card_skip:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		_card_age += dt
		if not hint_shown and _card_age > 0.4:
			hint_shown = true
			create_tween().tween_property(hint, "modulate:a", 1.0, 0.3)
	_card_active = false
	var out := create_tween()
	out.tween_property(col, "modulate:a", 0.0, 0.25)
	await out.finished
	card.queue_free()


func _input(event: InputEvent) -> void:
	if _rotate != null and _rotate.visible and Story.is_accept(event):
		_rotate_dismissed = true
		_update_rotate()
		get_viewport().set_input_as_handled()
		return
	# The first moments are ignored so the tap that started the card cannot also skip it.
	if _card_active and _card_age > 0.25 and Story.is_accept(event):
		_card_skip = true
		get_viewport().set_input_as_handled()


func _previously_on() -> void:
	var ep: Dictionary = Story.structure.get("episodes", {}).get("1", {})
	await _card("PREVIOUSLY ON BALETE", ep.get("previously_on", []), 5.5)


func _act_card(n: int) -> void:
	var ep: Dictionary = Story.structure.get("episodes", {}).get("1", {})
	var acts: Array = ep.get("acts", [])
	if n < 1 or n > acts.size():
		return
	var act: Dictionary = acts[n - 1]
	await _card("ACT %d: %s" % [n, String(act["title"]).to_upper()], ["Episode 1: %s" % String(ep.get("title", ""))], 2.4)


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


signal _board_go


## The corkboard: three jobs, a clock and a budget. The church parcel is required; the other two compete for time.
func _run_board() -> void:
	_clear()
	var back := ColorRect.new()
	back.color = Color(0.02, 0.03, 0.06)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(back)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(860, 0)
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)
	col.add_child(_big("THE CORKBOARD", Fonts.display(), 54, Color("e8c872")))
	var budget := 150
	var info := _big("", Fonts.label(), 22, Color("ffb43a"))
	info.name = "BoardInfo"
	col.add_child(info)
	var jobs := [
		{"id": "church", "title": "CHURCH UNDERCROFT PARCEL", "min": 60, "pay": 2000, "note": "dangerous. Required: the lender's note says so."},
		{"id": "avenida", "title": "AVENIDA TEXTILES", "min": 45, "pay": 800, "note": "safe."},
		{"id": "pandacan", "title": "PANDACAN COLD-STORAGE PARTS", "min": 90, "pay": 1500, "note": "risky. Something hums behind the depot."},
	]
	var buttons := {}
	var update := func() -> void:
		var used := 0
		var pay := 0
		for j in jobs:
			var b: Button = buttons[j["id"]]
			if b.button_pressed:
				used += int(j["min"])
				pay += int(j["pay"])
		for j in jobs:
			var b2: Button = buttons[j["id"]]
			if j["id"] != "church":
				b2.disabled = (not b2.button_pressed) and used + int(j["min"]) > budget
		info.text = "TIME BUDGET: %d / %d MIN     PAY: P%d     HONDA DEBT: P3,450" % [used, budget, pay + Story.money]
	for j in jobs:
		var b := Button.new()
		b.name = "Job_" + String(j["id"])
		b.toggle_mode = true
		b.text = "%s   %d min   P%d   %s" % [j["title"], j["min"], j["pay"], j["note"]]
		b.custom_minimum_size = Vector2(860, 64)
		b.add_theme_font_override("font", Fonts.label())
		b.add_theme_font_size_override("font_size", 19)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if j["id"] == "church":
			b.button_pressed = true
			b.disabled = true
		b.toggled.connect(func(_on: bool) -> void: update.call())
		col.add_child(b)
		buttons[j["id"]] = b
	update.call()
	var go := Button.new()
	go.name = "BoardGo"
	go.text = "OUT THE DOOR"
	go.custom_minimum_size = Vector2(320, 72)
	go.add_theme_font_override("font", Fonts.display())
	go.add_theme_font_size_override("font_size", 30)
	go.pressed.connect(func() -> void: _board_go.emit())
	col.add_child(_centered(go))
	go.grab_focus()
	await _board_go
	var avenida: Button = buttons["avenida"]
	var pandacan: Button = buttons["pandacan"]
	Story.flags["job_avenida"] = avenida.button_pressed
	Story.flags["job_pandacan"] = pandacan.button_pressed


func _run_courier(beat: Dictionary = {}) -> void:
	_clear()
	var run := CourierRun.new()
	if beat.has("seconds"):
		run.run_seconds = float(beat["seconds"])
	if beat.has("spawn"):
		run.spawn_min = float(beat["spawn"][0])
		run.spawn_max = float(beat["spawn"][1])
	if beat.has("route"):
		run.route_label = String(beat["route"])
	if beat.has("hazards"):
		run.hazards = beat["hazards"]
	_layer.add_child(run)
	var hits: int = await run.finished
	run.queue_free()
	Sfx.bgm("aphelion")
	if hits > 0:
		# Danger has a cost: Renzo starts the next fight weaker, and the ride ate into the noon deadline.
		Story.misses += hits
		Story.injury = mini(40, Story.injury + hits * 8)
		Story.lose_time(hits * 5)
		Story.queue_banner("Rough ride: %d hits. Renzo is bruised and %d minutes are gone." % [hits, hits * 5])
	await get_tree().create_timer(0.05 if test_fast else 0.4).timeout


func _run_fight(beat: Dictionary = {}) -> void:
	_clear()
	var fight := Combat.new()
	fight.fast = test_fast
	fight.enemy_id = String(beat.get("enemy", "aswang"))
	fight.episode = int(beat.get("episode", 1))
	_layer.add_child(fight)
	fight.begin()
	var won: bool = await fight.finished
	fight.queue_free()
	Sfx.bgm("aphelion")
	if won:
		await get_tree().create_timer(0.05 if test_fast else 0.3).timeout


func _show_end() -> void:
	Progress.complete_episode(1, Story.loob) # the save remembers what was unlocked and the Loob path
	_clear()
	var back := ColorRect.new()
	back.color = Color(0.02, 0.03, 0.06)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(back)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(860, 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	center.add_child(col)
	col.add_child(_big("END OF EPISODE 1", Fonts.display(), 64, Color("e8c872")))
	col.add_child(_big("Utang (family debt): %d      Loob (resolve): %d" % [Story.utang, Story.loob], Fonts.label(), 24, Color("ffb43a")))
	col.add_child(_big("Parries: %d   Perfect: %d   Missed beats: %d" % [Story.parries, Story.perfects, Story.misses], Fonts.label(), 24, Color("7dff9a")))
	col.add_child(_big("Time lost to misses: %d min   Falls (watch rewinds): %d" % [Story.minutes_lost, Story.deaths], Fonts.label(), 22, Color("ff9a8a")))
	var remembered := ", ".join(Story.remembered) if Story.remembered.size() > 0 else "nothing yet"
	col.add_child(_big("Lola will remember: %s" % remembered, Fonts.label(), 20, Color("aeb9ff")))
	var ep: Dictionary = Story.structure.get("episodes", {}).get("1", {})
	var teaser := _big("NEXT TIME ON BALETE:  " + "  ".join(ep.get("next_time_on", [])), Fonts.body_italic(), 20, Color(1, 1, 1, 0.8))
	teaser.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(teaser)
	var again := Button.new()
	again.name = "PlayAgainButton"
	again.text = "PLAY AGAIN"
	again.custom_minimum_size = Vector2(300, 74)
	again.add_theme_font_override("font", Fonts.display())
	again.add_theme_font_size_override("font_size", 30)
	again.pressed.connect(func() -> void:
		_running = false
		_show_title())
	col.add_child(_centered(again))
	again.grab_focus()
