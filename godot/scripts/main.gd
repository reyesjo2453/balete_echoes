extends Control
## Episode flow driver: title -> the beats in data/episode1_flow.json (cards, comic scenes with QTEs and
## choices, the wake hub, turn-based fights) -> end card.
## Every beat starts with a checkpoint (Story.checkpoint), so the title can offer "Continue: Chapter N" and resume
## at the start of that beat after a short "Previously on Balete".

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
var _beats: Array = [] # the flow, flattened: {"beat", "act"}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer = Control.new()
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	_apply_safe_area()
	_build_rotate_overlay()
	for act in Story.flow.get("acts", []):
		for beat in act["beats"]:
			_beats.append({"beat": beat, "act": int(act["number"])})
	if _url_param("auto") != "":
		Dialogue.auto_play = 2.2 # review links: lines advance on their own
	if _url_param("panel") != "":
		_view_panel(_url_param("panel"))
		return
	if _url_param("map") != "":
		_view_map(_url_param("map"))
		return
	if _url_param("fight") != "":
		_running = true
		await _run_stage_fight({"enemy": _url_param("fight")}) # review link: ?fight=magbabalot
		_show_title()
		return
	if _url_param("scene") != "":
		var staged := {}
		for b in _beats:
			if String(b["beat"].get("type", "")) == "scene" and String(b["beat"].get("id", "")) == _url_param("scene"):
				staged = b["beat"].get("stage", {})
			if String(b["beat"].get("type", "")) == "hub" and b["beat"].has("map"):
				var opts: Array = b["beat"].get("options", [])
				for i in opts.size():
					if String(opts[i].get("scene", "")) == _url_param("scene"):
						staged = _hub_stage(b["beat"], i) # a talk in a hub: on its map, Teo standing by them
		_play(_url_param("scene"), staged) # review link: ?scene=<scene id> plays one scene on its own (acted, if staged)
		return
	_show_title()


## Review links for the web build: index.html?panel=<panel id> shows just that panel (and its clip, if it has one);
## index.html?map=<hub id> (wake, estero) opens that walkable hub on its own. Talking ends the visit.
## index.html?scene=<scene id> plays one scene (with its choices) on its own.
func _url_param(name: String) -> String:
	if not OS.has_feature("web"):
		return OS.get_environment("BALETE_" + name.to_upper())
	var q := String(JavaScriptBridge.eval("location.search", true))
	for part in q.trim_prefix("?").split("&"):
		if part.begins_with(name + "="):
			return part.trim_prefix(name + "=").uri_decode()
	return ""


func _view_map(hub_id: String) -> void:
	for b in _beats:
		var beat: Dictionary = b["beat"]
		if String(beat.get("type", "")) == "hub" and String(beat.get("id", "")) == hub_id and beat.has("map"):
			var m := ExploreMap.new()
			m.name = "MapViewer"
			var at := _url_param("at").split(",")
			m.setup(beat, {}, int(beat.get("need", 0)), Vector2(float(at[0]), float(at[1])) if at.size() == 2 else Vector2(-1, -1))
			_layer.add_child(m)
			var walk := _url_param("walk").split(",")
			if walk.size() == 2: # &walk=x,z: Teo walks there by himself (for checking the walk cycle)
				m._walk_to(Vector2(float(walk[0]), float(walk[1])), -2)
			return


func _view_panel(id: String) -> void:
	var d := Dialogue.new()
	d.name = "PanelViewer"
	_layer.add_child(d)
	d.play([{"kind": "narr", "speaker": "", "text": "%s%s" % [id, "  (clip)" if Art.clip(id) != null else ""], "panel": id}])


## Going to the background (a phone call, another tab, closing the window) writes the checkpoint to disk again.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST]:
		if _running:
			Story.write_run()


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
	var saved := Story.peek_run()
	var resume: Button = null
	if not saved.is_empty():
		resume = Button.new()
		resume.name = "ContinueButton"
		resume.text = "CONTINUE: " + Story.chapter_label(int(saved.get("chapter", 0)))
		resume.custom_minimum_size = Vector2(420, 78)
		resume.add_theme_font_override("font", Fonts.display())
		resume.add_theme_font_size_override("font_size", 34)
		resume.pressed.connect(_continue_game)
		col.add_child(_centered(resume))
	var start := Button.new()
	start.name = "StartButton"
	start.text = "START" if resume == null else "START OVER"
	start.custom_minimum_size = Vector2(300, 78 if resume == null else 60)
	start.add_theme_font_override("font", Fonts.display())
	start.add_theme_font_size_override("font_size", 34 if resume == null else 26)
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
	col.add_child(_big("Music: Scott Buckley ('Aphelion', 'Undertow'), CC-BY 4.0, scottbuckley.com.au  ·  Emma_MA ('Determined Pursuit'), public domain", Fonts.body(), 13, Color(1, 1, 1, 0.4)))
	col.add_child(_big("Episode 1 panels made with OpenArt (GPT Image 2.5), Starter plan; not cleared for commercial release", Fonts.body(), 13, Color(1, 1, 1, 0.4)))
	var build := _big(Story.build_label(), Fonts.label_medium(), 14, Color(1, 1, 1, 0.45))
	build.name = "BuildLabel"
	build.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	build.offset_left = -240
	build.offset_top = -34
	build.offset_right = -16
	build.offset_bottom = -10
	build.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_title.add_child(build)
	if resume != null:
		resume.grab_focus()
	else:
		start.grab_focus()
	Sfx.cue("title")


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
	Story.reset()
	Story.clear_run()
	await _run_from(0, [])


## Resume at the last checkpoint: the saved state, a skippable recap, then the beat that was starting.
func _continue_game() -> void:
	if _running:
		return
	if not Story.load_run():
		await _start_game()
		return
	_running = true
	var lines := Story.recap_lines(6)
	if not lines.is_empty():
		Sfx.cue("wake")
		await _card("PREVIOUSLY ON BALETE", lines, 4.0 + 2.6 * lines.size())
	await _run_from(Story.run_beat, Story.run_heard)


func _run_from(start: int, heard: Array) -> void:
	_running = true
	_clear()
	for i in range(maxi(0, start), _beats.size()):
		var beat: Dictionary = _beats[i]["beat"]
		if not Story.cond_ok(beat):
			continue
		if beat.has("chapter"):
			Story.chapter = int(beat["chapter"])
		var resume_heard: Array = heard if i == start else []
		Story.checkpoint(i, resume_heard)
		if beat.has("music"):
			Sfx.cue(String(beat["music"]))
		await _play_beat(beat, int(_beats[i]["act"]), i, resume_heard)
	Story.clear_run() # the episode is over: nothing left to continue
	_show_end()
	_running = false


## One beat of the Episode 1 flow (data/episode1_flow.json): a card, a chapter card, a scene, a hub, a fight.
func _play_beat(beat: Dictionary, act: int, index: int = -1, heard: Array = []) -> void:
	match String(beat.get("type", "")):
		"card":
			await _card(String(beat.get("big", "")), beat.get("lines", []), float(beat.get("hold", 4.0)))
		"act_card":
			await _act_card(act, int(beat.get("chapter", 0)))
		"chapter":
			await _card("CHAPTER %d" % int(beat.get("chapter", 0)), [String(beat.get("title", "")), "Episode 1: %s" % _episode_title()], 2.6)
		"scene":
			await _play(String(beat["id"]), beat.get("stage", {}))
		"hub":
			await _run_hub(beat, index, heard)
		"fight":
			await _run_fight(beat)


func _episode_title() -> String:
	return String(Story.structure.get("episodes", {}).get("1", {}).get("title", ""))


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


func _act_card(n: int, chapter: int = 0) -> void:
	var ep: Dictionary = Story.structure.get("episodes", {}).get("1", {})
	var acts: Array = ep.get("acts", [])
	if n < 1 or n > acts.size():
		return
	var act: Dictionary = acts[n - 1]
	var lines: Array = ["Episode 1: %s" % String(ep.get("title", ""))]
	if chapter > 0:
		lines.push_front("Chapter %d" % chapter)
	await _card("ACT %d: %s" % [n, String(act["title"]).to_upper()], lines, 2.4)


## The hub (the wake): talk to people in any order. `need` of them must be heard before the player can move on;
## the rest are optional. Each option is a scene; a heard one is marked and cannot be picked again.
signal _hub_pick(index: int)
var _room_pos := Vector2(-1, -1) # where Teo stood on a walkable map, so he comes back to the same spot after a talk


func _run_hub(beat: Dictionary, index: int = -1, already: Array = []) -> void:
	_room_pos = Vector2(-1, -1)
	var options: Array = beat.get("options", [])
	var need := mini(int(beat.get("need", options.size())), options.size())
	var heard := {}
	for h in already:
		if int(h) >= 0 and int(h) < options.size():
			heard[int(h)] = true
	while true:
		if index >= 0:
			Story.checkpoint(index, heard.keys()) # each return to the hub is a checkpoint too
		_clear()
		if beat.has("map"):
			# A walkable map (the wake): Teo walks to people instead of picking them from a list.
			var room := ExploreMap.new()
			room.test_fast = test_fast
			room.setup(beat, heard, need, _room_pos)
			room.picked.connect(func(i: int) -> void:
				_room_pos = room.teo_pos
				_hub_pick.emit(i))
			_layer.add_child(room)
			var walked: int = await _hub_pick
			if walked < 0:
				if heard.size() >= need:
					break
				continue
			heard[walked] = true
			await _play(String(options[walked]["scene"]), _hub_stage(beat, walked))
			if options[walked].has("fight"):
				await _run_stage_fight(options[walked]["fight"])
				if options[walked].has("after"):
					await _play(String(options[walked]["after"]))
			if heard.size() == options.size() and not beat.has("map"):
				break
			continue
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


func _play(scene_id: String, stage: Dictionary = {}) -> void:
	var steps := Story.scene(scene_id)
	if steps.is_empty():
		return
	_clear()
	var d := Dialogue.new()
	if stage.has("map"):
		# Acted in the map: the cast walks and talks; comic panels cut in only where a step carries one.
		var room_set := ExploreMap.new()
		room_set.stage_mode = true
		room_set.test_fast = test_fast
		var teo_at: Array = stage.get("cast", {}).get("teo", {}).get("at", [-1, -1])
		room_set.setup({"map": stage["map"]}, {}, 0, Vector2(float(teo_at[0]), float(teo_at[1])))
		_layer.add_child(room_set)
		room_set.set_stage(stage)
		if not stage.get("cast", {}).has("teo"):
			room_set.hide_teo()
		d.stage = room_set
	_layer.add_child(d)
	d.play(steps)
	await d.finished
	d.queue_free()
	Story.flags["seen_" + scene_id] = true # the recap reads these


func _run_fight(beat: Dictionary = {}) -> void:
	_clear()
	var fight := Combat.new()
	fight.fast = test_fast
	fight.enemy_id = String(beat.get("enemy", "aswang"))
	fight.episode = int(beat.get("episode", 1))
	fight.fight_id = String(beat.get("fight_id", "")) # empty: ep<episode>_<enemy> picks the background
	fight.carry_wounds = bool(beat.get("carry_wounds", false))
	var party: Array = beat.get("party", [])
	for id in party:
		fight.party_override.append(String(id))
	_layer.add_child(fight)
	fight.begin()
	var won: bool = await fight.finished
	fight.queue_free()
	if won:
		await get_tree().create_timer(0.05 if test_fast else 0.3).timeout


## A talk in a walkable hub plays where it happens: the same map, Teo where he stopped, everyone at their places,
## and the camera between Teo and the one he is talking to. Text boxes run over it (retro JRPG style).
func _hub_stage(beat: Dictionary, walked: int) -> Dictionary:
	var options: Array = beat.get("options", [])
	var o: Dictionary = options[walked]
	var target: Array = o.get("at", [0, 0])
	var teo_at := _room_pos if _room_pos.x >= 0.0 else Vector2(float(target[0]), float(target[1]) + 0.9)
	var cast := {"teo": {"at": [teo_at.x, teo_at.y]}}
	for i in options.size():
		var oi: Dictionary = options[i]
		if oi.has("sprite") and oi.has("at") and not oi.has("roam"):
			cast["o%d" % i] = {"sprite": oi["sprite"], "at": oi.get("sprite_at", oi["at"]), "h": oi.get("h", 1.35),
				"name": String(oi.get("speaker", oi.get("short", "")))}
	var extras: Array = beat.get("extras", [])
	for i in extras.size():
		var e: Dictionary = extras[i]
		if Story.cond_ok(e):
			cast["x%d" % i] = {"sprite": e["sprite"], "at": e["at"], "h": e.get("h", 1.35), "ghost": e.get("ghost", false),
				"name": String(e.get("speaker", ""))}
	if o.has("roam"):
		# Walked into an enemy on the map: it is right there in front of Teo.
		var r: Dictionary = o["roam"]
		var foe := teo_at + Vector2(-1.1, -0.2)
		target = [foe.x, foe.y]
		cast["foe"] = {"sprite": r.get("sprite", ""), "at": target, "h": r.get("h", 1.6), "ghost": r.get("ghost", true),
			"name": String(o.get("speaker", o.get("short", "")))}
	var tv := Vector2(float(target[0]), float(target[1]))
	if absf(teo_at.x - tv.x) < 0.9:
		# Stand beside them, not in front: the camera looks from the front, and Teo would hide who he talks to.
		teo_at = Vector2(tv.x + (1.0 if teo_at.x >= tv.x else -1.0), tv.y + 0.35)
		cast["teo"] = {"at": [teo_at.x, teo_at.y]}
	cast["teo"]["face"] = "left" if tv.x < teo_at.x - 0.3 else ("right" if tv.x > teo_at.x + 0.3 else "up")
	var mid := (teo_at + tv) * 0.5
	return {"map": beat["map"], "cast": cast, "focus": [mid.x, mid.y + 0.6]}


## A retro side-view fight on the map itself (scripts/stage_battle.gd): {"enemy", "map", "at"}.
func _run_stage_fight(def: Dictionary) -> bool:
	_clear()
	var fight := StageBattle.new()
	fight.fast = test_fast
	fight.demo = _url_param("demo") != ""
	fight.setup(def)
	_layer.add_child(fight)
	var won: bool = await fight.finished
	fight.queue_free()
	return won


func _show_end() -> void:
	Progress.complete_episode(1, Story.loob) # the save remembers what was unlocked and the Loob path
	Sfx.cue("title", 3.0)
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
