extends Control
## Episode flow driver: title -> the beats in data/episode1_flow.json (cards, comic scenes with QTEs and
## choices, the wake hub, turn-based fights) -> end card.
## Every beat starts with a checkpoint (Story.checkpoint), so the title can offer "Continue: Chapter N" and resume
## at the start of that beat after a short "Previously on Balete".

const INTRO_CLIP := "balete_intro"
const INTRO_DURATION := 36.0
const ATTRACT_IDLE := 24.0

var _title: Control
var _layer: Control
var _running := false
## Tests set this to run the whole episode without waiting on real time.
var test_fast: bool = false
## Tests set this false when asserting the title menu is shown on frame 3 without an opening movie.
var boot_intro: bool = true
var _rotate: CanvasLayer
var _rotate_dismissed := false
## Tests set this to pretend the window has another size (the real window is not resizable in headless runs).
var window_size_override: Vector2i = Vector2i.ZERO
var _card_active := false
var _card_skip := false
var _card_age := 0.0
var _intro_active := false
var _intro_skip := false
var _intro_age := 0.0
var _intro_sound_btn: Button = null
var _title_idle := 0.0
var _had_user_gesture := false
var _title_breath: Tween = null
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
			if String(b["beat"].get("type", "")) in ["hub", "transit"] and b["beat"].has("map"):
				var opts: Array = b["beat"].get("options", [])
				for i in opts.size():
					if String(opts[i].get("scene", "")) == _url_param("scene"):
						staged = _hub_stage(b["beat"], i) # a talk in a hub: on its map, Teo standing by them
		_play(_url_param("scene"), staged) # review link: ?scene=<scene id> plays one scene on its own (acted, if staged)
		return
	if _url_param("intro") != "":
		await _watch_intro()
		return
	if boot_intro and Story.peek_run().is_empty() and Art.clip(INTRO_CLIP) != null:
		await _watch_intro()
		return
	_show_title()


func _process(delta: float) -> void:
	if _title != null and not _running and not test_fast:
		var overlay_open := _title.find_child("ChapterOverlay", true, false) != null
		var rotate_blocking := _rotate != null and _rotate.visible
		if not overlay_open and not rotate_blocking and Art.clip(INTRO_CLIP) != null:
			_title_idle += delta
			if _title_idle >= ATTRACT_IDLE:
				_title_idle = 0.0
				_watch_intro()
		else:
			_title_idle = 0.0
	else:
		_title_idle = 0.0


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
		if String(beat.get("type", "")) in ["hub", "transit"] and String(beat.get("id", "")) == hub_id and beat.has("map"):
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


class _TitleMotes extends Control:
	var _pts: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in 26:
			_pts.append({
				"x": randf(),
				"y": randf(),
				"vy": randf_range(0.014, 0.036),
				"vx": randf_range(-0.006, 0.008),
				"r": randf_range(1.6, 3.6),
				"ph": randf() * TAU,
				"cyan": i % 3 == 0,
			})

	func _process(delta: float) -> void:
		for p in _pts:
			p["y"] -= float(p["vy"]) * delta
			p["x"] += (float(p["vx"]) + sin(float(p["ph"]) + float(p["y"]) * 9.0) * 0.004) * delta
			if float(p["y"]) < -0.04:
				p["y"] = 1.04
				p["x"] = randf()
		queue_redraw()

	func _draw() -> void:
		var sz := size
		if sz.x <= 0.0 or sz.y <= 0.0:
			return
		var now := Time.get_ticks_msec() * 0.001
		for p in _pts:
			var a := 0.25 + 0.45 * (0.5 + 0.5 * sin(now * 2.1 + float(p["ph"])))
			var col := Color(0.55, 0.88, 1.0, a * 0.8) if bool(p["cyan"]) else Color(0.95, 0.78, 0.42, a)
			var pos := Vector2(float(p["x"]) * sz.x, float(p["y"]) * sz.y)
			draw_circle(pos, float(p["r"]) * 2.2, Color(col.r, col.g, col.b, a * 0.16))
			draw_circle(pos, float(p["r"]), col)


func _show_title() -> void:
	_clear()
	_title = Control.new()
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.clip_contents = true
	_layer.add_child(_title)

	var bg_tex := Art.panel("title_keyart")
	if bg_tex == null:
		bg_tex = Art.panel("ep1_01_quiapo_dawn")
	var tex := TextureRect.new()
	tex.name = "TitleArt"
	tex.texture = bg_tex
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.pivot_offset = Vector2(640, 360)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(tex)
	var breath := tex.create_tween().set_loops()
	breath.tween_property(tex, "scale", Vector2(1.035, 1.035), 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breath.tween_property(tex, "scale", Vector2(1.0, 1.0), 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_title_breath = breath

	# Directional midnight scrim on the left so the emblem and command window read crisply without dulling the right half.
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.03, 0.08, 0.90))
	grad.set_offset(0, 0.0)
	grad.add_point(0.42, Color(0.02, 0.03, 0.08, 0.62))
	grad.set_color(2, Color(0.02, 0.03, 0.08, 0.08))
	grad.set_offset(2, 1.0)
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0, 0.5)
	gtex.fill_to = Vector2(1, 0.5)
	var scrim := TextureRect.new()
	scrim.texture = gtex
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(scrim)

	var motes := _TitleMotes.new()
	motes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	motes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.add_child(motes)

	var left_col := VBoxContainer.new()
	left_col.position = Vector2(56, 36)
	left_col.custom_minimum_size = Vector2(540, 0)
	left_col.add_theme_constant_override("separation", 4)
	left_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(left_col)

	var loc := _title_label("QUIAPO, MANILA  ·  1998 – 2026", Fonts.label_medium(), 14, Color("8fe3ff"))
	left_col.add_child(loc)

	var hero := _title_label("BALETE", Fonts.display(), 86, Color("e8c872"), 10)
	left_col.add_child(hero)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(420, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rule.color = Color(0.91, 0.78, 0.45, 0.72)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_col.add_child(rule)

	var sub := _title_label("ECHOES OF THE SUNKEN VEIL", Fonts.label(), 22, Color("f4f2ea"))
	left_col.add_child(sub)
	var ep := _title_label("EPISODE 1  ·  ANG LUMANG ORASAN", Fonts.label_medium(), 15, Color("ffd27a"))
	left_col.add_child(ep)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_col.add_child(gap)

	var menu_win := Retro.window(16, 12)
	menu_win.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left_col.add_child(menu_win)

	var btn_col := VBoxContainer.new()
	btn_col.add_theme_constant_override("separation", 7)
	btn_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_win.add_child(btn_col)

	var saved := Story.peek_run()
	var resume: Button = null
	if not saved.is_empty():
		resume = Button.new()
		resume.name = "ContinueButton"
		resume.text = "CONTINUE: " + Story.chapter_label(int(saved.get("chapter", 0)))
		resume.custom_minimum_size = Vector2(390, 44)
		Retro.style_button(resume, 20)
		resume.pressed.connect(_continue_game)
		btn_col.add_child(resume)

	var start := Button.new()
	start.name = "StartButton"
	start.text = "START" if resume == null else "START OVER"
	start.custom_minimum_size = Vector2(390, 44)
	Retro.style_button(start, 22)
	start.pressed.connect(_start_game)
	btn_col.add_child(start)

	var chapters := Button.new()
	chapters.name = "ChapterButton"
	chapters.text = "CHAPTER & FIGHT SELECT"
	chapters.custom_minimum_size = Vector2(390, 42)
	Retro.style_button(chapters, 18)
	chapters.pressed.connect(func() -> void: _open_chapter_select(chapters))
	btn_col.add_child(chapters)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 8)
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_col.add_child(bottom_row)

	var fs := Button.new()
	fs.name = "FullscreenButton"
	fs.text = "FULLSCREEN"
	fs.custom_minimum_size = Vector2(140, 38)
	Retro.style_button(fs, 14)
	fs.pressed.connect(_toggle_fullscreen)
	bottom_row.add_child(fs)

	var intro_btn := Button.new()
	intro_btn.name = "IntroButton"
	intro_btn.text = "WATCH INTRO"
	intro_btn.custom_minimum_size = Vector2(146, 38)
	Retro.style_button(intro_btn, 14)
	intro_btn.disabled = Art.clip(INTRO_CLIP) == null
	intro_btn.pressed.connect(_watch_intro)
	bottom_row.add_child(intro_btn)

	var ctrl_hint := _title_label("TAP · SPACE · A", Fonts.label_medium(), 12, Color(1, 1, 1, 0.56))
	ctrl_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom_row.add_child(ctrl_hint)

	var credits := _title_label("Music: Scott Buckley & Emma_MA  ·  Art: OpenArt & Antigravity (non-commercial prototype)", Fonts.body(), 12, Color(1, 1, 1, 0.48))
	credits.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	credits.offset_left = 24
	credits.offset_top = -30
	credits.offset_right = 920
	credits.offset_bottom = -10
	_title.add_child(credits)

	var build := _big(Story.build_label(), Fonts.label_medium(), 14, Color(1, 1, 1, 0.52))
	build.name = "BuildLabel"
	build.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	build.offset_left = -240
	build.offset_top = -32
	build.offset_right = -18
	build.offset_bottom = -10
	build.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	build.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(build)

	_title_idle = 0.0
	if resume != null:
		resume.grab_focus()
	else:
		start.grab_focus()
	Sfx.cue("title")


func _title_label(text: String, font: Font, px: int, color: Color, outline: int = 5) -> Label:
	var l := Retro.label(font, px, color)
	l.text = text
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.06, 0.92))
	return l


func _open_chapter_select(return_to: Button) -> void:
	if _running or _title == null or _title.find_child("ChapterOverlay", true, false) != null:
		return
	var overlay := ColorRect.new()
	overlay.name = "ChapterOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.01, 0.02, 0.06, 0.78)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_title.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var win := Retro.window(24, 20)
	win.custom_minimum_size = Vector2(960, 0)
	center.add_child(win)

	var root_col := VBoxContainer.new()
	root_col.add_theme_constant_override("separation", 12)
	root_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win.add_child(root_col)

	root_col.add_child(_title_label("CHAPTER & FIGHT SELECT", Fonts.display(), 32, Color("e8c872")))
	root_col.add_child(_title_label("Jump straight to any Act (no prologue required) or test Team Combo fights directly.", Fonts.body(), 16, Color("d2cde8")))

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_col.add_child(cols)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_child(left)
	left.add_child(_title_label("STORY CHAPTERS", Fonts.label(), 16, Color("8fe3ff")))

	var chapter_picks := [
		{"label": "Prologue · 3 Hunyo 1998 (Cold Open)", "beat": 0, "chapter": 0, "flags": []},
		{"label": "Act 1 · Hidalgo Street (Skip Prologue)", "beat": _find_beat_idx("act_card", "chapter", 1), "chapter": 1, "flags": []},
		{"label": "Act 1 Finale · Wake Ghost & Berto Boss", "beat": _find_beat_idx("scene", "id", "berto_ghost"), "chapter": 1, "flags": ["ghost_nod", "obet_out", "promise_berto"]},
		{"label": "Act 2 · Ang Sundô (Estero & Aswang)", "beat": _find_beat_idx("act_card", "chapter", 2), "chapter": 2, "flags": ["bearer_teo", "heard_tess", "salt_door"]},
		{"label": "Act 3 · Utang (Morgue & Finale)", "beat": _find_beat_idx("act_card", "chapter", 4), "chapter": 3, "flags": ["bearer_teo", "watch_awake", "has_white_streak", "salt_door", "went_home", "has_tag"], "gratitude": 1},
	]
	var first_btn: Button = null
	for p in chapter_picks:
		var b := Button.new()
		b.text = String(p["label"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(430, 48)
		Retro.style_button(b, 17)
		var spec: Dictionary = p
		b.pressed.connect(func() -> void:
			overlay.queue_free()
			await _start_from_chapter(int(spec["beat"]), int(spec["chapter"]), spec.get("flags", []), int(spec.get("gratitude", 0))))
		left.add_child(b)
		if first_btn == null:
			first_btn = b

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_child(right)
	right.add_child(_title_label("BOSS & TEAM COMBO SHOWCASE", Fonts.label(), 16, Color("ffd27a")))

	var fight_picks := [
		{"label": "1998 · Lolo Pido vs The Drowned", "enemy": "lunod", "party": ["pido"], "flags": [], "gratitude": 0},
		{"label": "Wake · Teo + Lola vs Mang Berto", "enemy": "ligaw_berto", "party": ["teo", "ising"], "flags": ["bearer_teo"], "gratitude": 1},
		{"label": "Estero · Teo vs Tagged Aswang", "enemy": "aswang", "party": ["teo"], "flags": ["bearer_teo"], "gratitude": 0},
		{"label": "Morgue · Teo + Kardo vs Hiraya Hound", "enemy": "hiraya_hound", "party": ["teo", "kardo"], "flags": ["bearer_teo", "watch_awake"], "gratitude": 1},
		{"label": "Parlor · Teo + Kardo vs Unchained Aswang", "enemy": "aswang_finale", "party": ["teo", "kardo"], "flags": ["bearer_teo", "watch_awake", "has_white_streak"], "gratitude": 1},
	]
	for fp in fight_picks:
		var fb := Button.new()
		fb.text = String(fp["label"])
		fb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		fb.custom_minimum_size = Vector2(430, 48)
		Retro.style_button(fb, 17)
		var fspec: Dictionary = fp
		fb.pressed.connect(func() -> void:
			overlay.queue_free()
			await _quick_fight(fspec))
		right.add_child(fb)

	var close := Button.new()
	close.name = "ChapterBackButton"
	close.text = "BACK TO TITLE"
	close.custom_minimum_size = Vector2(220, 46)
	Retro.style_button(close, 18)
	close.pressed.connect(func() -> void:
		overlay.queue_free()
		if is_instance_valid(return_to):
			return_to.grab_focus())
	root_col.add_child(_centered(close))
	if first_btn != null:
		first_btn.grab_focus()


func _find_beat_idx(kind: String, key: String, value: Variant) -> int:
	for i in _beats.size():
		var b: Dictionary = _beats[i]["beat"]
		if String(b.get("type", "")) != kind:
			continue
		if key == "" or (b.has(key) and ((value is int and int(b[key]) == int(value)) or str(b[key]) == str(value))):
			return i
	return 0


func _start_from_chapter(beat_idx: int, chapter_num: int, preset_flags: Array, preset_gratitude: int = 0) -> void:
	if _running:
		return
	Story.reset()
	Story.clear_run()
	Story.chapter = chapter_num
	Story.gratitude = preset_gratitude
	for fl in preset_flags:
		Story.flags[String(fl)] = true
	await _run_from(beat_idx, [])


func _quick_fight(spec: Dictionary) -> void:
	if _running:
		return
	_running = true
	Story.reset()
	Story.gratitude = int(spec.get("gratitude", 0))
	for fl in spec.get("flags", []):
		Story.flags[String(fl)] = true
	var def := {"enemy": String(spec["enemy"]), "party": spec.get("party", ["teo"])}
	await _run_stage_fight(def)
	_running = false
	_show_title()


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
	_intro_active = false
	_intro_skip = false
	_intro_sound_btn = null
	if _title_breath != null and _title_breath.is_valid():
		_title_breath.kill()
	_title_breath = null
	_title = null
	for c in _layer.get_children():
		c.queue_free()


func _watch_intro() -> void:
	if _running:
		return
	_running = true
	await _play_intro()
	_running = false
	_show_title()


## Full-screen Final Fantasy-style opening movie (assets/clips/balete_intro.ogv).
## Fades out any title BGM so the movie's own Aphelion + Quiapo SFX mix leads, and crossfades cleanly onto Title.
func _play_intro() -> void:
	var stream := Art.clip(INTRO_CLIP)
	if stream == null:
		return
	_clear()
	Sfx.cue(Sfx.SILENCE, 0.35)

	var root := Control.new()
	root.name = "IntroScreen"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(root)

	var back := ColorRect.new()
	back.color = Color(0.02, 0.03, 0.08)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(back)

	var aspect := AspectRatioContainer.new()
	aspect.ratio = 16.0 / 9.0
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aspect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(aspect)

	var video := VideoStreamPlayer.new()
	video.name = "IntroVideo"
	video.stream = stream
	video.expand = true
	video.loop = false
	video.volume_db = -80.0 if DisplayServer.get_name() == "headless" else 0.0
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aspect.add_child(video)

	var curtain := ColorRect.new()
	curtain.name = "IntroCurtain"
	curtain.color = Color(0.02, 0.03, 0.08, 1.0)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(curtain)

	var prog := ColorRect.new()
	prog.name = "IntroProgress"
	prog.color = Color(0.91, 0.78, 0.45, 0.55)
	prog.anchor_left = 0.0
	prog.anchor_right = 0.0
	prog.anchor_top = 1.0
	prog.anchor_bottom = 1.0
	prog.offset_left = 0.0
	prog.offset_top = -3.0
	prog.offset_right = 0.0
	prog.offset_bottom = 0.0
	prog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(prog)

	var skip_hud := Retro.window(10, 6)
	skip_hud.name = "IntroSkipHud"
	skip_hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_hud.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip_hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
	skip_hud.offset_left = -224
	skip_hud.offset_top = -102
	skip_hud.offset_right = -22
	skip_hud.offset_bottom = -20
	skip_hud.modulate = Color(1, 1, 1, 0.0)
	root.add_child(skip_hud)

	var skip_col := VBoxContainer.new()
	skip_col.add_theme_constant_override("separation", 2)
	skip_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_hud.add_child(skip_col)

	var skip_btn := Button.new()
	skip_btn.name = "IntroSkipButton"
	skip_btn.text = "SKIP INTRO  >>"
	skip_btn.custom_minimum_size = Vector2(174, 30)
	Retro.style_button(skip_btn, 14)
	skip_btn.pressed.connect(func() -> void:
		if _intro_active and _intro_age > 0.2:
			_intro_skip = true)
	skip_col.add_child(skip_btn)

	var skip_hint := _title_label("SPACE · ESC · TAP", Fonts.label_medium(), 10, Color(1, 1, 1, 0.65), 3)
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_col.add_child(skip_hint)

	if OS.has_feature("web") and not _had_user_gesture:
		var sound_btn := Button.new()
		sound_btn.name = "IntroSoundButton"
		sound_btn.text = "TAP FOR SOUND"
		sound_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		sound_btn.offset_left = 22
		sound_btn.offset_top = -62
		sound_btn.offset_right = 198
		sound_btn.offset_bottom = -20
		Retro.style_button(sound_btn, 14)
		sound_btn.pressed.connect(func() -> void:
			_had_user_gesture = true
			sound_btn.visible = false)
		root.add_child(sound_btn)
		_intro_sound_btn = sound_btn

	var finished := [false]
	video.finished.connect(func() -> void: finished[0] = true)
	video.play()

	if not test_fast:
		create_tween().tween_property(curtain, "color:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	else:
		curtain.color.a = 0.0

	_intro_active = true
	_intro_skip = false
	_intro_age = 0.0
	var hint_shown := false
	var hold := 0.05 if test_fast else INTRO_DURATION + 0.5
	while not finished[0] and not _intro_skip and _intro_age < hold:
		await get_tree().process_frame
		if not is_instance_valid(root):
			_intro_active = false
			return
		var dt := get_process_delta_time()
		_intro_age += dt
		var vp_w := maxf(root.size.x, 1280.0)
		prog.offset_right = vp_w * clampf(_intro_age / INTRO_DURATION, 0.0, 1.0)
		if not hint_shown and _intro_age > 0.5:
			hint_shown = true
			create_tween().tween_property(skip_hud, "modulate:a", 0.92, 0.35)
		if _intro_age >= 28.0 and skip_btn.text != "TO TITLE  >>":
			skip_btn.text = "TO TITLE  >>"
		if _intro_sound_btn != null and is_instance_valid(_intro_sound_btn) and _had_user_gesture:
			_intro_sound_btn.visible = false
		if not video.is_playing() and _intro_age > 1.0 and not test_fast:
			finished[0] = true

	_intro_active = false
	var out_dur := 0.04 if test_fast else 0.42
	var out := create_tween().set_parallel(true)
	out.tween_property(curtain, "color:a", 1.0, out_dur).set_trans(Tween.TRANS_SINE)
	out.tween_property(video, "volume_db", -40.0, out_dur)
	out.tween_property(skip_hud, "modulate:a", 0.0, out_dur * 0.6)
	await out.finished
	if is_instance_valid(video):
		video.stop()
	_intro_sound_btn = null
	if is_instance_valid(root):
		root.visible = false
		root.queue_free()


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


## One beat of the Episode 1 flow (data/episode1_flow.json): a card, a scene, a hub, a transit, a route, a fight.
func _play_beat(beat: Dictionary, _act: int, index: int = -1, heard: Array = []) -> void:
	match String(beat.get("type", "")):
		"card":
			await _card(String(beat.get("big", "")), beat.get("lines", []), float(beat.get("hold", 4.0)))
		"act_card", "chapter":
			# Story flows seamlessly without full-screen Act/Chapter title cards.
			return
		"scene":
			await _play(String(beat["id"]), beat.get("stage", {}))
		"hub", "transit":
			await _run_hub(beat, index, heard)
		"route":
			await _run_route(beat)
		"fight":
			await _run_fight(beat)


func _run_route(beat: Dictionary) -> void:
	_clear()
	var sm := SectorMap.new()
	sm.fast = test_fast
	sm.setup(beat)
	_layer.add_child(sm)
	await sm.finished


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
	if event is InputEventMouseMotion or event.is_pressed():
		_title_idle = 0.0
	if event.is_pressed() and (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey or event is InputEventJoypadButton):
		_had_user_gesture = true
	if _rotate != null and _rotate.visible and Story.is_accept(event):
		_rotate_dismissed = true
		_update_rotate()
		get_viewport().set_input_as_handled()
		return
	if _intro_active and _intro_age > 0.28:
		if _intro_sound_btn != null and is_instance_valid(_intro_sound_btn) and _intro_sound_btn.visible:
			var tap_pos := Vector2(-1, -1)
			if event is InputEventMouseButton and event.pressed:
				tap_pos = (event as InputEventMouseButton).position
			elif event is InputEventScreenTouch and event.pressed:
				tap_pos = (event as InputEventScreenTouch).position
			if tap_pos.x >= 0.0 and _intro_sound_btn.get_global_rect().has_point(tap_pos):
				return
		var key_ev := event as InputEventKey
		var pad_ev := event as InputEventJoypadButton
		var cancel_hit := event.is_action_pressed("ui_cancel") or (key_ev != null and key_ev.pressed and key_ev.keycode == KEY_ESCAPE) or (pad_ev != null and pad_ev.pressed and pad_ev.button_index in [JOY_BUTTON_B, JOY_BUTTON_START])
		if cancel_hit or Story.is_accept(event):
			_intro_skip = true
			Sfx.ui_confirm()
			get_viewport().set_input_as_handled()
		return
	# The first moments are ignored so the tap that started the card cannot also skip it.
	if _card_active and _card_age > 0.25 and Story.is_accept(event):
		_card_skip = true
		get_viewport().set_input_as_handled()


func _act_card(_n: int, _chapter: int = 0) -> void:
	# Kept for compatibility; in-game Act/Chapter interstitial cards are intentionally omitted for seamless pacing.
	return


## Non-blocking location toast shown briefly in the top-left when entering a new street or room.
func _show_location_toast(title: String, sub: String = "") -> void:
	var clean_title := title.strip_edges()
	if clean_title == "" or test_fast:
		return
	var toast := Retro.window(14, 9)
	toast.name = "LocationToast"
	toast.position = Vector2(26, 22)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.modulate = Color(1, 1, 1, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_child(col)
	var t_lbl := Label.new()
	t_lbl.text = clean_title.to_upper()
	t_lbl.add_theme_font_override("font", Fonts.display())
	t_lbl.add_theme_font_size_override("font_size", 20)
	t_lbl.add_theme_color_override("font_color", Color("f2d486"))
	t_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(t_lbl)
	if sub.strip_edges() != "":
		var s_lbl := Label.new()
		s_lbl.text = sub.strip_edges()
		s_lbl.add_theme_font_override("font", Fonts.body())
		s_lbl.add_theme_font_size_override("font_size", 14)
		s_lbl.add_theme_color_override("font_color", Color(0.86, 0.90, 0.96, 0.9))
		s_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(s_lbl)
	_layer.add_child(toast)
	var tw := toast.create_tween()
	tw.tween_property(toast, "modulate:a", 1.0, 0.35)
	tw.tween_interval(2.1)
	tw.tween_property(toast, "modulate:a", 0.0, 0.55)
	tw.tween_callback(toast.queue_free)


## The hub (the wake): talk to people in any order. `need` of them must be heard before the player can move on;
## the rest are optional. Each option is a scene; a heard one is marked and cannot be picked again.
signal _hub_pick(index: int)
var _room_pos := Vector2(-1, -1) # where Teo stood on a walkable map, so he comes back to the same spot after a talk


func _run_hub(beat: Dictionary, index: int = -1, already: Array = []) -> void:
	_room_pos = Vector2(-1, -1)
	var showed_toast := false
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
			if not showed_toast:
				showed_toast = true
				_show_location_toast(String(beat.get("title", "")), String(beat.get("prompt", "")))
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
	var enemy := String(beat.get("enemy", "aswang"))
	# Every Episode 1 fight is a retro side-view battle on the map where it happens (scripts/stage_battle.gd).
	var def := {"enemy": enemy, "carry_wounds": bool(beat.get("carry_wounds", false))}
	if beat.has("party"):
		def["party"] = beat["party"]
	await _run_stage_fight(def)


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
	if beat.has("companion"):
		var comp: Dictionary = beat["companion"]
		var cid := String(comp.get("id", "kardo"))
		var cx := clampf(teo_at.x - 1.0, 0.5, 16.5)
		if absf(cx - tv.x) < 0.7:
			cx = maxf(0.5, teo_at.x + 1.0)
		cast[cid] = {
			"sprite": String(comp.get("sprite", cid)),
			"at": [cx, teo_at.y + 0.2],
			"h": float(comp.get("h", 1.8)),
			"name": String(comp.get("name", cid.capitalize())),
			"flip": tv.x < cx,
		}
	var mid := (teo_at + tv) * 0.5
	return {"map": beat["map"], "cast": cast, "focus": [mid.x, mid.y + 0.6]}


## A retro side-view fight on the map itself (scripts/stage_battle.gd): {"enemy", "map", "at"}.
func _run_stage_fight(def: Dictionary) -> bool:
	_clear()
	var fight := StageBattle.new()
	fight.fast = test_fast
	fight.demo = _url_param("demo") != ""
	if _url_param("miss") != "":
		fight.test_miss = int(_url_param("miss"))
	fight.setup(def)
	_layer.add_child(fight)
	var won: bool = await fight.finished
	fight.queue_free()
	return won


func _show_end() -> void:
	Progress.complete_episode(1, Story.loob) # the save remembers what was unlocked and the Loob path
	Sfx.cue("title", 3.0)
	# CASE CLOSED: the party levels up and each picks an upgrade (scripts/case_closed.gd, scripts/levels.gd).
	_clear()
	var closed := CaseClosed.new()
	closed.episode = 1
	closed.fast = test_fast
	_layer.add_child(closed)
	await closed.finished
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
	col.add_child(_big("Kardo: %+d   Lola Ising: %+d   Resolve: %d   Utang na loob: %d" % [Story.bond("kardo"), Story.bond("ising"), Story.loob, Story.gratitude], Fonts.label(), 22, Color("aeb9ff")))
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
