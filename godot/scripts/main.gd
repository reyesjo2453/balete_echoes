extends Control
## Episode flow driver: title -> the beats in data/episode1_flow.json (cards, comic scenes with QTEs and
## choices, the wake hub, turn-based fights) -> end card.

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
	col.add_child(_big("EPISODE 1  ·  ANG LUMANG ORASAN", Fonts.label_medium(), 18, Color(1, 1, 1, 0.65)))
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


## One beat of the Episode 1 flow (data/episode1_flow.json): a card, a scene, the hub, a fight.
func _play_beat(beat: Dictionary, act: int) -> void:
	match String(beat.get("type", "")):
		"card":
			await _card(String(beat.get("big", "")), beat.get("lines", []), float(beat.get("hold", 4.0)))
		"act_card":
			await _act_card(act)
		"scene":
			await _play(String(beat["id"]))
		"hub":
			await _run_hub(beat)
		"fight":
			await _run_fight(beat)


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


func _act_card(n: int) -> void:
	var ep: Dictionary = Story.structure.get("episodes", {}).get("1", {})
	var acts: Array = ep.get("acts", [])
	if n < 1 or n > acts.size():
		return
	var act: Dictionary = acts[n - 1]
	await _card("ACT %d: %s" % [n, String(act["title"]).to_upper()], ["Episode 1: %s" % String(ep.get("title", ""))], 2.4)


## The hub (the wake): talk to people in any order. `need` of them must be heard before the player can move on;
## the rest are optional. Each option is a scene; a heard one is marked and cannot be picked again.
signal _hub_pick(index: int)


func _run_hub(beat: Dictionary) -> void:
	var options: Array = beat.get("options", [])
	var need := mini(int(beat.get("need", options.size())), options.size())
	var heard := {}
	while true:
		_clear()
		var back := ColorRect.new()
		back.color = Color(0.02, 0.03, 0.06)
		back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(back)
		var tex := TextureRect.new()
		tex.texture = Art.panel(String(beat.get("panel", "ep1_30_wake_night")))
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex.modulate = Color(0.3, 0.3, 0.36)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(tex)
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(center)
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(820, 0)
		col.add_theme_constant_override("separation", 10)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(col)
		col.add_child(_big(String(beat.get("title", "")), Fonts.display(), 54, Color("e8c872")))
		var prompt := _big(String(beat.get("prompt", "")), Fonts.body(), 22, Color(1, 1, 1, 0.85))
		prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(prompt)
		var first: Button = null
		for i in options.size():
			var o: Dictionary = options[i]
			var b := Button.new()
			b.name = "Hub_%d" % i
			b.text = ("HEARD:  " if heard.has(i) else "") + String(o.get("label", o.get("scene", "")))
			b.disabled = heard.has(i)
			b.custom_minimum_size = Vector2(820, 64)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_override("font", Fonts.label())
			b.add_theme_font_size_override("font_size", 22)
			var idx := i
			b.pressed.connect(func() -> void: _hub_pick.emit(idx))
			col.add_child(b)
			if first == null and not b.disabled:
				first = b
		var go := Button.new()
		go.name = "HubGo"
		go.text = String(beat.get("leave", "MOVE ON"))
		go.disabled = heard.size() < need
		go.custom_minimum_size = Vector2(380, 72)
		go.add_theme_font_override("font", Fonts.display())
		go.add_theme_font_size_override("font_size", 28)
		go.pressed.connect(func() -> void: _hub_pick.emit(-1))
		col.add_child(_centered(go))
		if heard.size() >= need:
			go.grab_focus()
		elif first != null:
			first.grab_focus()
		var pick: int = await _hub_pick
		if pick < 0:
			if heard.size() >= need:
				break
			continue
		heard[pick] = true
		await _play(String(options[pick]["scene"]))
		if heard.size() == options.size():
			break


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


func _run_fight(beat: Dictionary = {}) -> void:
	_clear()
	var fight := Combat.new()
	fight.fast = test_fast
	fight.enemy_id = String(beat.get("enemy", "aswang"))
	fight.episode = int(beat.get("episode", 1))
	var party: Array = beat.get("party", [])
	for id in party:
		fight.party_override.append(String(id))
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
	col.custom_minimum_size = Vector2(900, 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	center.add_child(col)
	col.add_child(_big("ABANGAN...", Fonts.display(), 64, Color("e8c872")))
	col.add_child(_big("END OF EPISODE 1: ANG LUMANG ORASAN", Fonts.label(), 22, Color(1, 1, 1, 0.75)))
	var greys := ["untouched", "one white streak", "greying", "grey", "white, like Lolo Pido's"]
	col.add_child(_big("Borrowed time (utang): %d      Teo's hair: %s" % [Story.utang, greys[Story.age_stage()]], Fonts.label(), 24, Color("ffb43a")))
	col.add_child(_big("Kardo: %+d   Lola Ising: %+d   Resolve: %d" % [Story.bond("kardo"), Story.bond("ising"), Story.loob], Fonts.label(), 22, Color("aeb9ff")))
	col.add_child(_big("Parries: %d   Perfect: %d   Missed beats: %d   Falls: %d" % [Story.parries, Story.perfects, Story.misses, Story.deaths], Fonts.label(), 22, Color("7dff9a")))
	for r in Story.remembered.slice(0, 6):
		var line := _big("%s will remember that %s." % [String(r["who"]), String(r["what"])], Fonts.body_italic(), 18, Color(1, 1, 1, 0.7))
		col.add_child(line)
	var ep: Dictionary = Story.structure.get("episodes", {}).get("1", {})
	var teaser := _big("NEXT TIME:  " + "  ".join(ep.get("next_time_on", [])), Fonts.body_italic(), 20, Color(1, 1, 1, 0.8))
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
