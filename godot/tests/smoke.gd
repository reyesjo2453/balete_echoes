extends Node
## Headless smoke test, run in CI:  godot --headless --path godot res://tests/Smoke.tscn
## (A scene, not --script, so the Story and Sfx autoloads exist, exactly as in the real game.)
## Exercises the story data, the timing ring, a full dialogue run (QTEs and choices included),
## the turn-based combat rules and the courier run. Exits 1 on the first failed expectation.

var failures := 0
var story: Node = null


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failures += 1
		printerr("  FAIL ", what)


func _ready() -> void:
	print("== Balete smoke test ==")
	await get_tree().process_frame
	await _test_story()
	await _test_ring()
	await _test_dialogue()
	await _test_combat()
	await _test_courier()
	await _test_layout()
	print("== done, failures: %d ==" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _test_story() -> void:
	print("story data")
	story = get_tree().root.get_node_or_null("Story")
	_check(story != null, "Story autoload present")
	if story == null:
		return
	for id in ["stakes", "shop_morning", "step_out", "dante_call", "act1_hook", "alley_arrival", "after_fight", "envelope", "lola_silence", "tondo_safehouse", "cliffhanger"]:
		var steps: Array = story.scene(id)
		_check(steps.size() > 0, "scene '%s' has %d steps" % [id, steps.size()])
		for step in steps:
			if not (step is Dictionary and step.has("text")):
				_check(false, "scene '%s' step missing text" % id)
				break
	var acts: Array = story.structure.get("episodes", {}).get("1", {}).get("acts", [])
	_check(acts.size() == 3, "Episode 1 has 3 acts, each with a hook (%d)" % acts.size())
	var missing := {}
	for id in ["stakes", "shop_morning", "step_out", "dante_call", "alley_arrival", "after_fight"]:
		for step in story.scene(id):
			var panel: String = step.get("panel", "")
			if panel != "" and Art.panel(panel) == null:
				missing[panel] = true
	print("  info art slots still on placeholder: ", missing.keys())
	_check(Art.portrait("portrait_renzo") != null, "renzo portrait loads")


func _test_ring() -> void:
	print("timing ring")
	var ring := TimingRing.new()
	get_tree().root.add_child(ring)
	var grades: Array[String] = []
	ring.finished.connect(func(g: String) -> void: grades.append(g))

	ring.start("T", 1.0, "assisted")
	ring._armed_at -= 1000
	ring._process(0.2) # ring still wide: too early
	ring.press()
	_check(grades.size() == 1 and grades[0] == "miss", "assisted: early press is a miss")

	grades.clear()
	ring.start("T", 1.0, "assisted")
	ring._armed_at -= 1000
	ring._process(0.8) # inside the zone
	ring.press()
	_check(grades.size() == 1 and grades[0] != "miss", "assisted: in-zone press is a hit")

	grades.clear()
	ring.start("T", 1.0, "assisted")
	ring._armed_at -= 1000
	ring._process(0.95)
	ring.press()
	_check(grades.size() == 1 and grades[0] == "perfect", "assisted: late-in-zone press is perfect")

	grades.clear()
	ring.start("T", 1.0, "guided")
	ring._armed_at -= 1000
	ring._process(0.1)
	ring.press()
	_check(grades.is_empty() and ring.active, "guided: early press resets instead of failing")
	ring._process(1.0) # let the retry pause run out
	ring._process(0.8)
	ring.press()
	_check(grades.size() == 1 and grades[0] != "miss", "guided: hits after the retry")

	grades.clear()
	ring.start("T", 0.5, "free")
	ring._armed_at -= 1000
	ring._process(0.5)
	ring._process(0.3)
	_check(grades.size() == 1 and grades[0] == "miss", "free: letting it expire is a miss")
	ring.queue_free()


func _drive_dialogue(scene_id: String) -> bool:
	var d := Dialogue.new()
	get_tree().root.add_child(d)
	var state := {"done": false}
	d.finished.connect(func() -> void: state["done"] = true)
	d.play(story.scene(scene_id))
	var guard := 0
	while not state["done"] and guard < 400:
		guard += 1
		if d._busy:
			if d._choice_box.visible:
				d._settle_choice(0, false)
			elif d._ring.active:
				d._ring._armed_at -= 1000
				d._ring._t = d._ring.seconds * 0.9
				d._ring._pause = 0.0
				d._ring.press()
		else:
			d._advance()
		await get_tree().process_frame
	d.queue_free()
	return state["done"]


func _test_dialogue() -> void:
	print("dialogue runs (QTEs and choices included)")
	story.reset()
	for id in ["stakes", "shop_morning", "step_out", "dante_call", "act1_hook", "alley_arrival", "after_fight", "envelope", "lola_silence"]:
		var ok: bool = await _drive_dialogue(id)
		_check(ok, "scene '%s' plays to the end" % id)
	_check(story.loob == 1, "pressing Lola raises Loob (got %d)" % story.loob)


func _test_combat() -> void:
	print("battle rules (fuzzed) and a full fight through the UI")
	story.reset()
	# 1. Fuzz the pure rules: every player turn has a usable action, nothing goes out of bounds, fights end.
	var turns_checked := 0
	var bad := ""
	for seed_value in 300:
		var m := BattleModel.new()
		m.rng.seed = seed_value
		var hero := BattleModel.Unit.new("renzo", "Renzo", true, 100, 10)
		hero.hp = 30 + (seed_value * 7) % 71
		var foe := BattleModel.Unit.new("aswang", "Aswang", false, 140, 8)
		m.allies.append(hero)
		m.enemies.append(foe)
		if seed_value % 3 == 0:
			m.allies.append(BattleModel.Unit.new("dante", "Dante", true, 120, 6)) # a second party member
		m.start()
		var falls := 0
		var guard_count := 0
		while guard_count < 600 and falls < 4:
			guard_count += 1
			var u := m.current()
			if u == null:
				break
			if u.is_ally:
				var opts := m.usable(u)
				turns_checked += 1
				if opts.is_empty() or not opts.has("attack") or not opts.has("guard"):
					bad = "seed %d: no usable action %s" % [seed_value, opts]
					break
				var pick: String = opts[m.rng.randi_range(0, opts.size() - 1)]
				match pick:
					"attack":
						m.attack(foe)
					"guard":
						m.guard(u)
					"item":
						m.use_tea(u)
					"skill":
						m.rewind(u)
				m.check_awakening()
			else:
				m.begin_enemy_turn(u)
				var target := m.first_ally_alive()
				for i in int(u.intent["rings"]):
					if target == null or not target.alive():
						break
					var grades := ["perfect", "good", "miss"]
					var res := m.resolve_strike(u, target, grades[m.rng.randi_range(0, 2)])
					if res["counter"]:
						m.counter_hit(u, m.rng.randi() % 2 == 0)
				if target != null:
					target.guarding = false
				m.plan_intent(u)
			for x in m.allies + m.enemies:
				if x.hp < 0 or x.hp > x.max_hp:
					bad = "seed %d: hp out of range %d" % [seed_value, x.hp]
			if m.teas < 0 or m.rewinds_left < 0:
				bad = "seed %d: negative resources" % seed_value
			if bad != "":
				break
			if m.is_victory():
				break
			if m.is_defeat():
				falls += 1
				m.rewind_round()
				if m.is_defeat():
					bad = "seed %d: rewind did not revive" % seed_value
					break
				continue
			m.end_turn()
		if bad != "":
			break
	_check(bad == "", "fuzz: %d player turns, every one had a usable action and stayed in bounds %s" % [turns_checked, bad])

	# 2. The tutorial gates Skill until the watch awakens.
	var t := BattleModel.new()
	var hero2 := BattleModel.Unit.new("renzo", "Renzo", true, 100, 10)
	var foe2 := BattleModel.Unit.new("aswang", "Aswang", false, 140, 8)
	t.allies.append(hero2)
	t.enemies.append(foe2)
	t.start()
	_check(not t.usable(hero2).has("skill"), "Skill is locked at the start of Episode 1")
	foe2.hp = 70
	_check(t.check_awakening() and t.usable(hero2).has("skill"), "the watch awakens at 55% and unlocks Skill with one rewind")
	hero2.hp = 40
	t.begin_enemy_turn(foe2)
	hero2.hp = 12
	t.rewind(hero2)
	_check(hero2.hp == 40 and t.rewinds_left == 0, "Rewind undoes the last blow, once")
	_check(t.ring_level() == "guided", "the first parry is a guided lesson")

	# 3. A full fight through the real UI: press whatever is enabled, parry on the ring.
	for mode in ["parry", "miss"]:
		story.reset()
		var fight := Combat.new()
		fight.fast = true
		add_child(fight)
		var result := {"done": false, "won": false}
		fight.finished.connect(func(w: bool) -> void:
			result["done"] = true
			result["won"] = w)
		await get_tree().process_frame
		fight.begin()
		var empty_menus := 0
		var frames := 0
		while not result["done"] and frames < 6000:
			frames += 1
			await get_tree().process_frame
			if fight._ring.active:
				fight._ring._armed_at -= 1000
				if mode == "miss" and fight._ring.level != "guided":
					fight._ring._process(10.0)
				else:
					fight._ring._t = fight._ring.seconds * 0.9
					fight._ring._pause = 0.0
					fight._ring.press()
				continue
			var cmds := fight.enabled_commands()
			if fight._cmd_box.get_child_count() > 0 and cmds.is_empty():
				empty_menus += 1
			if not cmds.is_empty():
				var pick: String = "attack" if fight.menu_mode == "main" else cmds[0]
				if fight.menu_mode == "main" and not cmds.has("attack"):
					pick = cmds[0]
				fight._buttons[pick].pressed.emit()
		_check(result["done"] and result["won"], "fight (%s): finished with a victory in %d frames" % [mode, frames])
		_check(empty_menus == 0, "fight (%s): no player turn ever had an empty menu (%d)" % [mode, empty_menus])
		if mode == "miss":
			_check(story.deaths >= 1 and story.misses >= 1, "fight (miss): falls were shown and counted (deaths %d, misses %d)" % [story.deaths, story.misses])
		fight.queue_free()


func _test_courier() -> void:
	print("courier run")
	var run := CourierRun.new()
	get_tree().root.add_child(run)
	var result := {"hits": -1}
	run.finished.connect(func(h: int) -> void: result["hits"] = h)
	var steps := 0
	while result["hits"] < 0 and steps < 2000:
		steps += 1
		run._process(0.05)
	_check(result["hits"] >= 0, "reaches the alley in %d steps (%d hits)" % [steps, result["hits"]])
	run.queue_free()


# --- Layout and input at a phone and a desktop size -------------------------------------------------

const LOGICAL := Vector2(1280, 720)


func _controls(root: Node) -> Array:
	var out: Array = []
	for c in root.get_children():
		if c is Control:
			out.append(c)
		out.append_array(_controls(c))
	return out


## Every visible interactive or panel control must sit inside the (logical) viewport.
func _check_inside(root: Node, label: String) -> void:
	var bounds := Rect2(Vector2.ZERO, LOGICAL).grow(2.0)
	var bad: Array[String] = []
	var count := 0
	for c in _controls(root):
		if not (c is BaseButton or c is PanelContainer or c is ProgressBar or c is TimingRing):
			continue
		if not c.is_visible_in_tree():
			continue
		count += 1
		var r: Rect2 = c.get_global_rect()
		if not bounds.encloses(r):
			bad.append("%s %s" % [c.name, r])
	_check(count > 0 and bad.is_empty(), "%s: %d controls inside the viewport %s" % [label, count, bad])


func _click(vp: Viewport, pos: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = pos
	move.global_position = pos
	vp.push_input(move)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _make_viewport(size: Vector2i) -> SubViewport:
	var sub := SubViewport.new()
	sub.size = size
	sub.size_2d_override = Vector2i(LOGICAL)
	sub.size_2d_override_stretch = true
	add_child(sub)
	return sub


func _test_layout() -> void:
	print("layout and input (phone 844x390, desktop 1920x1080)")
	for size in [Vector2i(844, 390), Vector2i(1920, 1080)]:
		var tag := "%dx%d" % [size.x, size.y]
		var scale := Vector2(size) / LOGICAL

		# Title: controls inside the viewport, nothing on top of START, a real click starts the game.
		var sub := _make_viewport(size)
		var main: Control = load("res://scenes/Main.tscn").instantiate()
		sub.add_child(main)
		await _frames(3)
		var start: Button = main.find_child("StartButton", true, false)
		_check(start != null and start.is_visible_in_tree(), "title %s: START exists" % tag)
		_check_inside(main, "title " + tag)
		_check(not main._rotate.visible, "title %s: the rotate card is hidden on a landscape desktop" % tag)
		var center := start.get_global_rect().get_center()
		var px := center * scale
		var move := InputEventMouseMotion.new()
		move.position = px
		move.global_position = px
		sub.push_input(move)
		await _frames(2)
		var hovered := sub.gui_get_hovered_control()
		_check(hovered == start, "title %s: START is the control under the pointer (got %s)" % [tag, hovered])
		_click(sub, px)
		await _frames(4)
		_check(main._running, "title %s: clicking START begins the game" % tag)
		var card_label: Label = null
		for c in _controls(main):
			if c is Label and String(c.text).begins_with("PREVIOUSLY ON"):
				card_label = c
		_check(card_label != null and card_label.is_visible_in_tree(), "title %s: the Previously-on card follows START" % tag)
		if card_label != null:
			var r: Rect2 = card_label.get_global_rect()
			_check(Rect2(Vector2.ZERO, LOGICAL).grow(2.0).encloses(r), "title %s: the card text is inside the viewport %s" % [tag, r])
		sub.queue_free()

		# Timed choice: every option inside the viewport.
		var sub2 := _make_viewport(size)
		var d2 := Dialogue.new()
		sub2.add_child(d2)
		d2.play(story.scene("lola_silence"))
		var guard := 0
		while not d2._choice_box.visible and guard < 40:
			guard += 1
			d2._advance()
			await _frames(1)
		_check(d2._choice_box.visible, "choice %s: reached the timed choice" % tag)
		await _frames(2)
		_check_inside(d2, "choice " + tag)
		sub2.queue_free()

		# Fight menu and parry ring.
		var sub3 := _make_viewport(size)
		var fight := Combat.new()
		sub3.add_child(fight)
		await _frames(3)
		fight._show_menu("main")
		await _frames(3)
		_check_inside(fight, "fight " + tag)
		fight.model.skill_unlocked = true
		fight.model.rewinds_left = 1
		fight._show_menu("main")
		await _frames(3)
		_check_inside(fight, "fight (skill unlocked) " + tag)
		fight._ring.start("PARRY!", 2.0, "guided", Combat.LESSON)
		await _frames(2)
		_check_inside(fight, "parry ring " + tag)
		sub3.queue_free()

		# End card, and PLAY AGAIN is clickable.
		var sub4 := _make_viewport(size)
		var main4: Control = load("res://scenes/Main.tscn").instantiate()
		sub4.add_child(main4)
		await _frames(2)
		main4._show_end()
		await _frames(3)
		_check_inside(main4, "end card " + tag)
		var again: Button = main4.find_child("PlayAgainButton", true, false)
		_check(again != null, "end card %s: PLAY AGAIN exists" % tag)
		if again != null:
			_click(sub4, again.get_global_rect().get_center() * scale)
			await _frames(3)
			_check(main4.find_child("StartButton", true, false) != null, "end card %s: PLAY AGAIN returns to the title" % tag)
		sub4.queue_free()
