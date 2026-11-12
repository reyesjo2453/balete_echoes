extends Node
## Headless smoke test, run in CI:  godot --headless --path godot res://tests/Smoke.tscn
## (A scene, not --script, so the Story and Sfx autoloads exist, exactly as in the real game.)
## Exercises the story data, the timing ring, a full dialogue run (QTEs and choices included),
## the turn-based combat rules (parry, dodge, Kardo's circuit), the wake hub and two full playthroughs. Exits 1 on the first failed expectation.

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
	Story.run_path = "user://smoke_run.json" # never touch a player's real mid-episode save
	Story.clear_run()
	await get_tree().process_frame
	await _test_story()
	await _test_ring()
	await _test_dialogue()
	await _test_combat()
	await _test_layout()
	await _test_skippable()
	await _test_narrow_screen()
	await _test_battle_animation()
	await _test_episode_flow()
	await _test_saves()
	await _test_music()
	await _test_progression()
	await _test_feedback_round()
	await _test_walk_and_clips()
	print("== done, failures: %d ==" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _test_story() -> void:
	print("story data")
	story = get_tree().root.get_node_or_null("Story")
	_check(story != null, "Story autoload present")
	if story == null:
		return
	for id in ["co_flood", "co_rewind", "lamay_open", "hub_nena", "berto_ghost", "lola_watch", "lola_answers", "act1_hook", "estero", "gate_ram", "parlor_taken", "tape", "the_offer", "cliffhanger"]:
		var steps: Array = story.scene(id)
		_check(steps.size() > 0, "scene '%s' has %d steps" % [id, steps.size()])
		for step in steps:
			if not (step is Dictionary and step.has("text")):
				_check(false, "scene '%s' step missing text" % id)
				break
	var acts: Array = story.structure.get("episodes", {}).get("1", {}).get("acts", [])
	_check(acts.size() == 3, "Episode 1 has 3 acts, each with a hook (%d)" % acts.size())
	var missing := {}
	for id in ["co_flood", "lamay_open", "lola_watch", "aswang_drop", "gate_ram", "cliffhanger"]:
		for step in story.scene(id):
			var panel: String = step.get("panel", "")
			if panel != "" and Art.panel(panel) == null:
				missing[panel] = true
	print("  info art slots still on placeholder: ", missing.keys())
	_check(Art.portrait("portrait_teo") != null and Art.portrait("portrait_kardo") != null and Art.portrait("portrait_ising") != null, "Teo, Kardo and Lola Ising portraits load")
	var fights := 0
	for act in story.flow.get("acts", []):
		for beat in act["beats"]:
			if String(beat.get("type", "")) == "fight":
				fights += 1
				_check(story.enemy_defs.has(String(beat["enemy"])), "fight beat enemy '%s' exists" % beat["enemy"])
				for id in beat.get("party", []):
					_check(not PartyData.member(String(id)).is_empty(), "fight beat party member '%s' exists" % id)
	_check(fights == 7, "Episode 1 has 7 fights: three waves of the drowned, Mang Berto, the unsent, the aswang, the hound (%d)" % fights)


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
	for id in ["co_rewind", "lamay_open", "debt_notice", "berto_ghost", "lola_watch", "berto_turns", "lola_answers", "two_forty", "dead_sundo"]:
		var ok: bool = await _drive_dialogue(id)
		_check(ok, "scene '%s' plays to the end" % id)
	_check(story.flags.get("watch_catch_ok", false) and story.flags.get("oil_ok", false), "story QTEs set <id>_ok flags")
	_check(story.flags.get("bearer_teo", false), "Lola's watch scene makes Teo the bearer")
	_check(story.flags.get("ask_watch", false) and story.remembered.size() >= 2, "choices set flags and are remembered (%d)" % story.remembered.size())
	_check(story.loob >= 1, "choices raise resolve (got %d)" % story.loob)
	# Borrowed time greys Teo: nothing before he carries the watch, a streak at the first rewind.
	story.reset()
	story.add_utang(2)
	_check(story.age_stage() == 0, "borrowing before Teo carries the watch does not age him")
	story.flags["bearer_teo"] = true
	story.add_utang(2)
	_check(story.age_stage() == 1 and story.age_amount() > 0.0, "the first rewind gives Teo his first white streak")
	story.apply_qte("gate_brace", false, {"miss": {"injury": 10}})
	_check(story.flags.get("gate_brace_miss", false) and story.injury == 10, "a missed QTE plays out worse (injury), never game over")


func _test_combat() -> void:
	print("battle rules (fuzzed) and a full fight through the UI")
	story.reset()
	# 1. Fuzz the pure rules: every player turn has a usable action, nothing goes out of bounds, fights end.
	var turns_checked := 0
	var bad := ""
	for seed_value in 300:
		var m := BattleModel.new()
		m.rng.seed = seed_value
		var hero := BattleModel.Unit.new("teo", "Teo", true, 100, 10)
		hero.hp = 30 + (seed_value * 7) % 71
		var foe := BattleModel.Unit.new("aswang", "Aswang", false, 140, 8)
		m.allies.append(hero)
		m.enemies.append(foe)
		if seed_value % 3 == 0:
			m.allies.append(BattleModel.Unit.new("kardo", "Kardo", true, 120, 6)) # a second party member
			m.team_moves = PartyData.team_moves(3)
		if seed_value % 5 == 1:
			m.attack_table = Story.enemy_defs["aswang"]["attacks"] # includes an attack that must be dodged
		if seed_value % 2 == 0:
			m.episode = 5
			var variants := ["base", "protective", "aggressive"]
			m.load_skills([
				{"id": "rewind", "variant": variants[seed_value % 3]},
				{"id": "slow", "variant": variants[(seed_value + 1) % 3]},
				{"id": "echo", "variant": variants[(seed_value + 2) % 3]},
				{"id": "seventeen", "variant": variants[seed_value % 3]},
			])
			m.energy = seed_value % 7
			m.mods = Amulets.mods(["buhok_tikbalang", "batong_buhay", "mutya_ng_ulan", "tanikala"][seed_value % 4])
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
						var picks := m.usable_skills()
						if picks.is_empty():
							bad = "seed %d: skill offered but none usable" % seed_value
						else:
							m.use_skill(String(picks[m.rng.randi_range(0, picks.size() - 1)]["id"]), u, foe)
					"wire":
						m.wire(u, foe)
					"discharge":
						m.discharge(u, foe)
					"team":
						var moves := m.usable_team_moves()
						if moves.is_empty():
							bad = "seed %d: team move offered but none usable" % seed_value
						else:
							m.team_move(moves[0], foe)
				m.check_awakening()
			else:
				m.begin_enemy_turn(u)
				var target := m.pick_target()
				m.consume_parry_widen()
				for i in int(u.intent["rings"]):
					if u.intent.get("skipped", false):
						break
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
			if m.teas < 0 or m.energy < 0 or m.energy > BattleModel.MAX_ENERGY:
				bad = "seed %d: resources out of range (energy %d)" % [seed_value, m.energy]
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
	var hero2 := BattleModel.Unit.new("teo", "Teo", true, 100, 10)
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
	_check(hero2.hp == 40 and not t.usable(hero2).has("skill"), "Rewind undoes the last blow, once")
	_check(t.ring_level() == "guided", "the first parry is a guided lesson")

	# Dodge: some attacks cannot be parried. Any hit in the zone avoids them, with no counter; a miss takes all of it.
	var dg := BattleModel.new()
	var dh := BattleModel.Unit.new("teo", "Teo", true, 100, 10)
	var df := BattleModel.Unit.new("aswang", "Aswang", false, 140, 8)
	dg.allies.append(dh)
	dg.enemies.append(df)
	dg.start()
	df.intent = {"name": "Drag Under", "rings": 1, "seconds": 1.3, "damage": 24, "dodge": true}
	var r1 := dg.resolve_strike(df, dh, "perfect")
	_check(r1["dodged"] and not r1["counter"] and dh.hp == 100 and df.stagger == 0, "dodge: a perfect press avoids it, but there is no counter")
	var r2 := dg.resolve_strike(df, dh, "good")
	_check(r2["dodged"] and dh.hp == 100, "dodge: a good press avoids it too")
	dh.guarding = true
	dg.resolve_strike(df, dh, "miss")
	_check(dh.hp == 76, "dodge: Guard does not help against it (hp %d)" % dh.hp)
	_check(dg.intent_text(df).find("DODGE") >= 0, "the intent card says DODGE")

	# Kardo's circuit: wire stacks up to 3, discharge spends them, staggers, and three stacks break the guard.
	var kc := BattleModel.new()
	var kd := BattleModel.Unit.new("kardo", "Kardo", true, 120, 6)
	var kf := BattleModel.Unit.new("aswang", "Aswang", false, 140, 8)
	kc.allies.append(kd)
	kc.enemies.append(kf)
	kc.start()
	_check(not kc.usable(kd).has("discharge") and kc.usable(kd).has("wire"), "Kardo: nothing to discharge before a wire is on")
	for i in 4:
		kc.wire(kd, kf)
	_check(kf.wired == BattleModel.MAX_WIRES and not kc.usable(kd).has("wire"), "Kardo: the circuit holds 3 wires")
	var zap := kc.discharge(kd, kf)
	_check(zap == 36 and kf.wired == 0 and kf.stunned, "Kardo: discharging 3 wires hits for 36 and breaks its guard")

	# 3. A full fight through the real UI: press whatever is enabled, parry on the ring.
	for mode in ["parry", "miss"]:
		story.reset()
		var fight := Combat.new()
		fight.fast = true
		fight.use_progress = false
		add_child(fight)
		var result := {"done": false, "won": false}
		fight.finished.connect(func(w: bool) -> void:
			result["done"] = true
			result["won"] = w)
		await get_tree().process_frame
		if mode == "miss":
			fight.model.allies[0].hp = 12 # a fragile start so a fatal miss is certain
			fight._refresh()
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
		if not (c is BaseButton or c is PanelContainer or c is ProgressBar or c is TimingRing or c is BattleActor):
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
		Story.clear_run() # a title with no save: START only
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
			if c is Label and String(c.text).begins_with("QUIAPO"):
				card_label = c
		_check(card_label != null and card_label.is_visible_in_tree(), "title %s: the cold-open card follows START" % tag)
		if card_label != null:
			var r: Rect2 = card_label.get_global_rect()
			_check(Rect2(Vector2.ZERO, LOGICAL).grow(2.0).encloses(r), "title %s: the card text is inside the viewport %s" % [tag, r])
		sub.queue_free()

		# Timed choice: every option inside the viewport.
		var sub2 := _make_viewport(size)
		var d2 := Dialogue.new()
		sub2.add_child(d2)
		d2.play(story.scene("lamay_open"))
		var guard := 0
		while not d2._choice_box.visible and guard < 40:
			guard += 1
			d2._advance()
			await _frames(1)
		_check(d2._choice_box.visible, "choice %s: reached the choice" % tag)
		await _frames(2)
		_check_inside(d2, "choice " + tag)
		sub2.queue_free()

		# Fight menu and parry ring.
		var sub3 := _make_viewport(size)
		var fight := Combat.new()
		fight.use_progress = false
		sub3.add_child(fight)
		await _frames(3)
		fight._show_menu("main")
		await _frames(3)
		_check_inside(fight, "fight " + tag)
		fight.model.skills.append({"id": "rewind", "variant": "base", "uses_left": 1})
		fight._show_menu("main")
		await _frames(3)
		_check_inside(fight, "fight (skill unlocked) " + tag)
		fight._ring.start("PARRY!", 2.0, "guided", Combat.LESSON)
		await _frames(2)
		_check_inside(fight, "parry ring " + tag)
		sub3.queue_free()

		# End card, and PLAY AGAIN is clickable.
		var sub4 := _make_viewport(size)
		Story.clear_run() # a title with no save: START only
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



# --- Mid-episode saves: checkpoints, Continue on the title, the recap, resuming a hub and a fight ---------------

func _beat_index(main: Node, kind: String, key: String, value: String) -> int:
	for i in main._beats.size():
		var b: Dictionary = main._beats[i]["beat"]
		if String(b.get("type", "")) == kind and String(b.get(key, "")) == value:
			return i
	return -1


func _test_saves() -> void:
	print("mid-episode saves: checkpoint, continue, recap, chapters")
	story.reset()
	story.clear_run()
	_check(not story.has_run(), "no save: nothing to continue")
	story.flags["ghost_nod"] = true
	story.flags["choice_big1"] = 2
	story.flags["bearer_teo"] = true
	story.bonds["kardo"] = 2
	story.injury = 10
	story.utang = 3
	story.chapter = 2
	story.remember("Kardo", "you chased the van")
	story.checkpoint(20, [1])
	_check(story.has_run(), "a checkpoint is written to disk")
	story.reset()
	_check(story.load_run(), "the checkpoint loads")
	_check(story.run_beat == 20 and story.run_heard == [1] and story.chapter == 2, "it resumes at the same beat, hub progress and chapter (%d %s %d)" % [story.run_beat, story.run_heard, story.chapter])
	_check(story.injury == 10 and story.utang == 3 and story.bond("kardo") == 2, "injuries, utang and bonds come back")
	_check(story.flags.get("ghost_nod", false) and story.flags.get("choice_big1", 0) is int and int(story.flags["choice_big1"]) == 2, "flags come back, numbers as ints")
	_check(story.remembered.size() == 1, "what people remember comes back")
	_check(story.recap_lines(6).size() >= 1, "the recap has lines from this run's own choices (%s)" % [story.recap_lines(6)])
	story.clear_run()
	_check(not story.has_run(), "clearing the save leaves nothing to continue")

	# Four chapter cards (about 7, 22, 31 and 41 minutes in), numbered 1 to 4.
	var chapters: Array = []
	for act in story.flow.get("acts", []):
		for beat in act["beats"]:
			if beat.has("chapter") and int(beat["chapter"]) > 0:
				chapters.append(int(beat["chapter"]))
	_check(chapters == [1, 2, 3, 4], "chapter cards 1 to 4 in order (%s)" % [chapters])

	# Title: "Continue: Chapter N" above "Start over".
	var size := Vector2i(1280, 720)
	var sub := _make_viewport(size)
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	sub.add_child(main)
	await _frames(2)
	var hound := _beat_index(main, "fight", "enemy", "hiraya_hound")
	var wake := _beat_index(main, "hub", "id", "wake")
	_check(hound > 0 and wake > 0, "the flow has the hound fight and the wake hub (%d, %d)" % [hound, wake])
	sub.queue_free()
	story.reset()
	story.chapter = 4
	story.injury = 10
	story.flags["went_home"] = true
	story.flags["seen_tape"] = true
	story.checkpoint(hound)
	sub = _make_viewport(size)
	main = load("res://scenes/Main.tscn").instantiate()
	main.test_fast = true
	sub.add_child(main)
	await _frames(3)
	var resume: Button = main.find_child("ContinueButton", true, false)
	var start: Button = main.find_child("StartButton", true, false)
	_check(resume != null and resume.text == "CONTINUE: CHAPTER 4", "title: CONTINUE: CHAPTER 4 (%s)" % [resume.text if resume else "none"])
	_check(start != null and start.text == "START OVER", "title: START OVER under it")
	if resume != null and start != null:
		_check(resume.get_global_rect().position.y < start.get_global_rect().position.y, "title: Continue is above Start over")
		_check_inside(main, "title with a save")

	# Continue: the recap card, then the fight restarts with the injury kept.
	story.reset()
	main._continue_game()
	var saw_recap := false
	var fight: Combat = null
	var frames := 0
	while frames < 3000 and fight == null:
		frames += 1
		await get_tree().process_frame
		for c in _controls(main):
			if c is Label and String(c.text) == "PREVIOUSLY ON BALETE":
				saw_recap = true
		if main._card_active and main._card_age > 0.3:
			main._card_skip = true
		for c in main._layer.get_children():
			if c is Combat:
				fight = c
	_check(saw_recap, "continue: \"Previously on Balete\" plays first")
	_check(fight != null and fight.enemy_id == "hiraya_hound", "continue: resumes at the hound fight")
	_check(story.injury == 10 and story.flags.get("went_home", false), "continue: the fight restarts with the saved injuries and choices")
	if fight != null:
		var lead: BattleModel.Unit = fight.model.first_ally_alive()
		_check(lead != null and lead.hp < lead.max_hp, "continue: the lead starts the fight hurt (%d/%d)" % [lead.hp if lead else 0, lead.max_hp if lead else 0])
	_check(story.has_run() and story.run_beat == hound, "a checkpoint was taken at the fight's start")
	main._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(story.has_run(), "going to the background keeps the save on disk")
	sub.queue_free()
	await _real_wait(0.2)

	# A hub resumes with the people already heard marked.
	story.reset()
	story.chapter = 1
	story.flags["clue_underpass"] = true
	story.checkpoint(wake, [0])
	sub = _make_viewport(size)
	main = load("res://scenes/Main.tscn").instantiate()
	main.test_fast = true
	sub.add_child(main)
	await _frames(2)
	story.reset()
	main._continue_game()
	var hub0: Button = null
	frames = 0
	while frames < 2000 and hub0 == null:
		frames += 1
		await get_tree().process_frame
		if main._card_active and main._card_age > 0.3:
			main._card_skip = true
		hub0 = main._layer.find_child("Hub_0", true, false)
	_check(hub0 != null and hub0.disabled and String(hub0.text).begins_with("HEARD"), "continue: the wake hub remembers who was heard")
	var go: Button = main._layer.find_child("HubGo", true, false)
	_check(go != null and go.disabled, "continue: one more person is still needed before leaving the wake")
	_check(story.flags.get("clue_underpass", false), "continue: the hub scene's clue is still known")
	sub.queue_free()
	story.clear_run()
	story.reset()
	await _real_wait(0.2)


# --- Music: every cue exists, scenes and fights name real cues, crossfades switch the player -------------------

func _test_music() -> void:
	print("music cues")
	for id in ["title", "wake", "tension", "battle", "boss", "sting"]:
		var f := Sfx.cue_file(id)
		var found := false
		for ext in ["ogg", "mp3", "wav"]:
			if ResourceLoader.exists("res://assets/bgm/%s.%s" % [f, ext]):
				found = true
		_check(found, "cue '%s' has a file (%s)" % [id, f])
	_check(Sfx.cue_file("battle") != Sfx.cue_file("boss") and Sfx.cue_file("wake") != Sfx.cue_file("tension") and Sfx.cue_file("battle") != Sfx.cue_file("wake"), "wake, tension, battle and boss are different tracks")
	var unknown: Array = []
	for act in story.flow.get("acts", []):
		for beat in act["beats"]:
			if beat.has("music") and not Sfx.has_cue(String(beat["music"])):
				unknown.append(beat["music"])
	var all: Dictionary = story._episode.get("scenes", {})
	var silences := 0
	for id in all:
		for st in all[id]:
			if st.has("music"):
				if String(st["music"]) == "silence":
					silences += 1
				if not Sfx.has_cue(String(st["music"])):
					unknown.append(st["music"])
	for e in story.enemy_defs:
		if e != "_note" and story.enemy_defs[e] is Dictionary and story.enemy_defs[e].has("music") and not Sfx.has_cue(String(story.enemy_defs[e]["music"])):
			unknown.append(story.enemy_defs[e]["music"])
	_check(unknown.is_empty(), "every cue named by the flow, the scenes and the enemies exists %s" % [unknown])
	_check(silences >= 4, "big emotional beats fall silent (%d)" % silences)
	_check(String(story.enemy_defs["aswang"].get("music", "")) == "boss" and String(story.enemy_defs["hiraya_hound"].get("music", "")) == "boss", "the aswang and the hound get the boss cue")
	Sfx.cue("wake")
	var p1: AudioStreamPlayer = Sfx.active_player()
	_check(Sfx.current_cue == "wake" and p1.stream != null, "cue wake plays")
	Sfx.cue("battle", 0.2)
	var p2: AudioStreamPlayer = Sfx.active_player()
	_check(Sfx.current_cue == "battle" and p2 != p1 and p2.stream != null and String(p2.stream.resource_path).contains(Sfx.cue_file("battle")), "cue battle crossfades onto the other player")
	await _real_wait(0.5)
	_check(not p1.playing, "the old cue fades out and stops")
	_check(p2.volume_db > -20.0, "the new cue fades in (%.1f dB)" % p2.volume_db)
	Sfx.cue("silence", 0.2)
	await _real_wait(0.5)
	_check(Sfx.current_cue == "silence" and not p2.playing, "silence fades the music out")

# --- Season progression: skills, energy, amulets, party, save data -------------------------------------

func _model_with(skill_ids: Array, variant: String = "base") -> BattleModel:
	var m := BattleModel.new()
	m.rng.seed = 7
	m.episode = 5
	var hero := BattleModel.Unit.new("teo", "Teo", true, 100, 10)
	var foe := BattleModel.Unit.new("aswang", "Aswang", false, 140, 8)
	m.allies.append(hero)
	m.enemies.append(foe)
	var list: Array = []
	for id in skill_ids:
		list.append({"id": id, "variant": variant})
	m.load_skills(list)
	m.start()
	return m


func _test_progression() -> void:
	print("progression: skills, Loob forms, energy, amulets, party, save data")

	# Skill data: one new power per episode, three forms each.
	var order := []
	for sk in Skills.all():
		order.append("%s@%d" % [sk["id"], int(sk["episode"])])
		var complete: bool = sk.has("name") and sk.has("text") and sk.has("energy_cost") and sk["effects"].has("base") and sk["effects"].has("protective") and sk["effects"].has("aggressive")
		_check(complete and not sk["effects"]["base"].is_empty() and not sk["effects"]["protective"].is_empty() and not sk["effects"]["aggressive"].is_empty(), "skill '%s' has base, protective and aggressive forms" % sk["id"])
	_check(order == ["rewind@1", "slow@2", "echo@4", "seventeen@5"], "skills unlock in order: Rewind, Slow, Echo, the 4:17 finale (%s)" % [order])
	_check(Skills.variant_for("slow", 0) == "protective" and Skills.variant_for("slow", 1) == "aggressive" and Skills.variant_for("slow", 5) == "aggressive", "Loob picks the form (below 1 protective, 1 or more aggressive)")
	_check(Skills.variant_for("rewind", 5) == "base", "Episode 1's Rewind stays in its base form (plays exactly as built)")

	# Effects per power and form.
	var m := _model_with(["rewind"], "protective")
	var me: BattleModel.Unit = m.allies[0]
	var foe: BattleModel.Unit = m.enemies[0]
	me.hp = 50
	m.begin_enemy_turn(foe) # the blow it will undo starts from 50 HP
	me.hp = 20
	var r := m.use_skill("rewind", me, foe)
	_check(me.hp == 60 and int(r["healed"]) == 10, "Rewind (protective) undoes the blow and also heals a little (hp %d)" % me.hp)
	m = _model_with(["rewind"], "aggressive")
	me = m.allies[0]
	foe = m.enemies[0]
	var hit := m.attack(foe, me)
	m.begin_enemy_turn(foe)
	me.hp = 10
	var foe_hp := foe.hp
	r = m.use_skill("rewind", me, foe)
	_check(foe.hp == foe_hp - hit, "Rewind (aggressive) replays your hit for bonus damage (%d)" % hit)

	m = _model_with(["slow"])
	m.energy = 2
	me = m.allies[0]
	foe = m.enemies[0]
	_check(m.usable_skills().size() == 1, "Slow is usable with 2 watch energy")
	m.use_skill("slow", me, foe)
	_check(m.parry_widen > 1.0 and m.zone_bonus() > 0.0 and m.energy == 0, "Slow widens the next parry window and spends its energy")
	m = _model_with(["slow"], "protective")
	m.energy = 2
	me = m.allies[0]
	m.use_skill("slow", me, m.enemies[0])
	_check(me.shield == 15, "Slow (protective) shields the party")
	m.enemies[0].intent = BattleModel.ATTACKS["claw"].duplicate()
	var res := m.resolve_strike(m.enemies[0], me, "miss")
	_check(res["damage"] == 3 and me.hp == 97, "a shield absorbs the first of a blow (took %d)" % res["damage"])
	m = _model_with(["slow"], "aggressive")
	m.energy = 2
	m.use_skill("slow", m.allies[0], m.enemies[0])
	m.enemies[0].intent = BattleModel.ATTACKS["claw"].duplicate()
	res = m.resolve_strike(m.enemies[0], m.allies[0], "good")
	_check(res["counter"], "Slow (aggressive) leaves the enemy open to a counter")

	m = _model_with(["echo"])
	m.energy = 3
	me = m.allies[0]
	foe = m.enemies[0]
	hit = m.attack(foe, me)
	foe_hp = foe.hp
	m.use_skill("echo", me, foe)
	_check(foe.hp == foe_hp - hit, "Echo replays your last action (%d again)" % hit)
	m = _model_with(["echo"], "aggressive")
	m.energy = 3
	hit = m.attack(m.enemies[0], m.allies[0])
	foe_hp = m.enemies[0].hp
	m.use_skill("echo", m.allies[0], m.enemies[0])
	_check(m.enemies[0].hp == foe_hp - int(round(hit * 1.5)), "Echo (aggressive) hits 1.5x")

	m = _model_with(["seventeen"], "aggressive")
	m.energy = 6
	foe_hp = m.enemies[0].hp
	m.use_skill("seventeen", m.allies[0], m.enemies[0])
	_check(m.enemies[0].stalled and m.enemies[0].hp == foe_hp - 40, "the 4:17 finale (aggressive) stalls and damages every enemy")
	m.begin_enemy_turn(m.enemies[0])
	_check(m.enemies[0].intent.get("skipped", false), "a stalled enemy loses its turn")

	# Energy: perfect parries earn it, nothing else does; skills spend it; it is capped.
	m = _model_with(["slow"])
	me = m.allies[0]
	foe = m.enemies[0]
	foe.intent = BattleModel.ATTACKS["claw"].duplicate()
	m.resolve_strike(foe, me, "good")
	m.resolve_strike(foe, me, "miss")
	_check(m.energy == 0, "only perfect parries earn watch energy")
	_check(m.usable_skills().is_empty(), "Slow is not usable without energy")
	m.resolve_strike(foe, me, "perfect")
	_check(m.energy == 1, "a perfect parry earns 1 watch energy")
	for i in 10:
		m.resolve_strike(foe, me, "perfect")
	_check(m.energy == BattleModel.MAX_ENERGY, "watch energy is capped at %d" % BattleModel.MAX_ENERGY)
	var tutorial := BattleModel.new()
	_check(not tutorial.energy_enabled(), "Episode 1 shows no energy meter (no energy skill yet)")
	_check(_model_with(["slow"]).energy_enabled(), "the energy meter appears once an energy skill is unlocked")

	# Amulets: data, one at a time, perk and cost.
	var first := Amulets.choice_for(2)
	_check(first.size() == 2, "the first amulet is chosen from two in Episode 2")
	for a in Amulets.all():
		_check(a.has("name") and not a["perk"].is_empty() and not a["cost"].is_empty(), "amulet '%s' has a perk and a small cost" % a["id"])
	var tik := Amulets.mods("buhok_tikbalang")
	_check(is_equal_approx(float(tik["parry_zone"]), 0.06) and is_equal_approx(float(tik["max_hp_mult"]), 0.9), "Buhok ng Tikbalang: wider window, less health")
	var ring := TimingRing.new()
	add_child(ring)
	var got: Array[String] = []
	ring.finished.connect(func(g: String) -> void: got.append(g))
	ring.start("T", 1.0, "assisted")
	ring._armed_at -= 1000
	ring._process(0.62) # k = 0.38: just outside the normal 0.36 window
	ring.press()
	var without: String = got[0]
	got.clear()
	ring.start("T", 1.0, "assisted", "", 0.06)
	ring._armed_at -= 1000
	ring._process(0.62)
	ring.press()
	_check(without == "miss" and got[0] != "miss", "an amulet that widens the window catches a press the base window misses")
	ring.queue_free()
	var amulet_fight := Combat.new()
	amulet_fight.use_progress = false
	amulet_fight.episode = 2
	amulet_fight.model.mods = Amulets.mods("buhok_tikbalang")
	add_child(amulet_fight)
	await get_tree().process_frame
	_check(amulet_fight.model.allies[0].max_hp == 90, "the amulet's cost applies (Teo's max HP 90)")
	amulet_fight.queue_free()
	var tiny := BattleModel.new()
	tiny.mods = Amulets.mods("mutya_ng_ulan")
	tiny.allies.append(BattleModel.Unit.new("teo", "Teo", true, 100, 10))
	tiny.enemies.append(BattleModel.Unit.new("aswang", "Aswang", false, 140, 8))
	tiny.start()
	tiny.enemies[0].intent = BattleModel.ATTACKS["claw"].duplicate()
	tiny.resolve_strike(tiny.enemies[0], tiny.allies[0], "perfect")
	_check(tiny.energy == 2, "Mutya ng Ulan: a perfect parry charges 2 (got %d)" % tiny.energy)
	tiny.resolve_strike(tiny.enemies[0], tiny.allies[0], "miss")
	_check(tiny.allies[0].hp == 100 - int(round(18 * 1.1)), "Mutya ng Ulan: blows land harder")

	# Party of two: Kardo from Episode 2 (a guest in Episode 1's last fight), his own menu, a team move, a fight.
	_check(PartyData.party_for(1) == ["teo"] and PartyData.party_for(2).has("kardo"), "Teo alone in Episode 1; Kardo joins in Episode 2; Lolo Pido is a guest only")
	_check(PartyData.member("kardo")["commands"].has("wire") and PartyData.member("kardo")["commands"].has("discharge"), "Kardo has his own command menu (Wire, Discharge)")
	_check(PartyData.team_moves(1).is_empty() and PartyData.team_moves(2).size() == 1, "the team move arrives with Kardo")
	var duo := BattleModel.new()
	duo.episode = 3
	duo.allies.append(BattleModel.Unit.new("teo", "Teo", true, 100, 10))
	duo.allies.append(BattleModel.Unit.new("kardo", "Kardo", true, 120, 6))
	duo.enemies.append(BattleModel.Unit.new("aswang", "Aswang", false, 140, 8))
	duo.team_moves = PartyData.team_moves(3)
	duo.start()
	_check(not duo.usable(duo.allies[1]).has("team"), "Bayanihan needs watch energy")
	duo.energy = 4
	_check(duo.usable(duo.allies[1]).has("team"), "Bayanihan is usable with 4 energy and both members up")
	var total := duo.team_move(duo.usable_team_moves()[0], duo.enemies[0])
	_check(total > 40 and duo.energy == 0, "Bayanihan strikes together and spends the energy (%d)" % total)
	duo.allies[1].hp = 0
	duo.energy = 6
	_check(not duo.usable(duo.allies[0]).has("team"), "no team move with a member down")
	for size in [Vector2i(844, 390), Vector2i(1920, 1080)]:
		var sub := _make_viewport(size)
		var pair := Combat.new()
		pair.use_progress = false
		pair.episode = 3
		sub.add_child(pair)
		await _frames(3)
		pair._actor = pair.model.allies[1]
		pair._show_menu("main")
		await _frames(3)
		_check_inside(pair, "two-member fight (Kardo's menu) %dx%d" % [size.x, size.y])
		_check(pair._buttons.has("wire") and pair._buttons.has("discharge") and pair._buttons.has("attack") and pair._buttons.has("guard"), "Kardo's menu shows Wrench, Wire, Discharge, Cover")
		sub.queue_free()
	var duo_fight := Combat.new()
	duo_fight.fast = true
	duo_fight.use_progress = false
	duo_fight.episode = 3
	add_child(duo_fight)
	var duo_result := {"done": false}
	duo_fight.finished.connect(func(w: bool) -> void: duo_result["done"] = w)
	await get_tree().process_frame
	duo_fight.begin()
	var f := 0
	var empty := 0
	while not duo_result["done"] and f < 8000:
		f += 1
		await get_tree().process_frame
		if duo_fight._ring.active:
			duo_fight._ring._armed_at -= 1000
			duo_fight._ring._t = duo_fight._ring.seconds * 0.9
			duo_fight._ring._pause = 0.0
			duo_fight._ring.press()
			continue
		var cmds := duo_fight.enabled_commands()
		if duo_fight._cmd_box.get_child_count() > 0 and cmds.is_empty():
			empty += 1
		if not cmds.is_empty():
			var pick: String = "team" if cmds.has("team") else ("discharge" if cmds.has("discharge") else ("wire" if cmds.has("wire") else ("attack" if cmds.has("attack") else cmds[0])))
			duo_fight._buttons[pick].pressed.emit()
	_check(duo_result["done"] and empty == 0, "a two-member fight (Teo and Kardo) is won, no empty menu (%d frames)" % f)
	duo_fight.queue_free()

	# Episode 1 is unchanged: tutorial gating, no energy meter, no team move.
	var ep1 := Combat.new()
	ep1.use_progress = false
	add_child(ep1)
	await get_tree().process_frame
	ep1._show_menu("main")
	await get_tree().process_frame
	var ep1_cmds := ep1.enabled_commands()
	_check(ep1.model.allies.size() == 1 and ep1.model.skills.is_empty() and ep1._energy == null and not ep1._buttons.has("team") and not ep1._buttons.has("skill"), "Episode 1: Teo alone, no Skill, no energy meter, no team move")

	# A story beat can name the party: Lolo Pido alone in the cold open, Teo and Kardo against the hound.
	var guest := Combat.new()
	guest.use_progress = false
	guest.party_override.append("pido")
	guest.enemy_id = "lunod"
	add_child(guest)
	await get_tree().process_frame
	_check(guest.model.allies.size() == 1 and guest.model.allies[0].display_name == "Lolo Pido", "the cold-open fight is Lolo Pido's")
	guest.queue_free()
	var pair1 := Combat.new()
	pair1.use_progress = false
	pair1.party_override.append_array(["teo", "kardo"])
	pair1.enemy_id = "hiraya_hound"
	add_child(pair1)
	await get_tree().process_frame
	_check(pair1.model.allies.size() == 2 and pair1.model.team_moves.is_empty(), "the hound fight: Teo and Kardo, no team move yet")
	pair1.queue_free()
	_check(ep1_cmds.has("attack") and ep1_cmds.has("guard") and ep1_cmds.has("item"), "Episode 1: Attack, Guard and Item only")
	ep1.queue_free()

	# Save data.
	var p = load("res://scripts/progress.gd").new()
	p.save_path = "user://test_save_a.json"
	p.reset()
	_check(p.unlock_skill("rewind", 1, 1) == "base", "Episode 1 unlocks Rewind in its base form")
	_check(p.unlock_skill("slow", 0, 2) == "protective", "Loob 0 at unlock gives Slow's protective form")
	p.grant_amulet("buhok_tikbalang")
	p.grant_amulet("batong_buhay")
	_check(p.equip("buhok_tikbalang") and p.equipped == "buhok_tikbalang", "an amulet can be equipped")
	_check(p.equip("batong_buhay") and p.equipped == "batong_buhay", "equipping another swaps the first out (one at a time)")
	_check(not p.equip("tanikala"), "an amulet you do not own cannot be equipped")
	p.complete_episode(1, 1)
	p.complete_episode(2, 0)
	var q = load("res://scripts/progress.gd").new()
	q.save_path = "user://test_save_a.json"
	q.reset()
	_check(q.load_game(), "the save file loads")
	_check(q.skills.has("rewind") and q.skills["slow"]["variant"] == "protective" and q.episodes_done == [1, 2] and q.equipped == "batong_buhay" and q.amulets.size() == 2, "unlocks, amulets and episodes persist across a save and load")
	_check(q.battle_skills(1).is_empty() and q.battle_skills(2).size() == 2, "Episode 1 starts without the watch powers; Episode 2 carries Rewind and Slow")
	var path_before: String = q.loob_path
	q.new_season()
	_check(q.season == 2 and q.skills.is_empty() and q.episodes_done.is_empty() and q.loob_path == path_before and q.amulets.size() == 2 and q.equipped == "batong_buhay", "a new season keeps the Loob path and the amulets, and resets the rest")
	var old := FileAccess.open("user://test_save_old.json", FileAccess.WRITE)
	old.store_string('{"unlocked": ["rewind"], "season": 1}')
	old.close()
	var legacy = load("res://scripts/progress.gd").new()
	legacy.save_path = "user://test_save_old.json"
	_check(legacy.load_game() and legacy.skills.has("rewind"), "an old (unversioned) save is migrated")
	var junk := FileAccess.open("user://test_save_bad.json", FileAccess.WRITE)
	junk.store_string("{not json at all")
	junk.close()
	var broken = load("res://scripts/progress.gd").new()
	broken.save_path = "user://test_save_bad.json"
	_check(not broken.load_game() and broken.skills.is_empty() and broken.season == 1, "a corrupt save is ignored and the defaults stay")


# --- Every timed card or wait skips at once on a single tap, click, Enter or controller A ------------------

func _flag_prev(main: Node, done: Dictionary) -> void:
	await main._card("QUIAPO  ·  3 HUNYO 1998", ["3:58 in the morning."], 4.5)
	done["v"] = true


func _flag_act(main: Node, n: int, done: Dictionary) -> void:
	await main._act_card(n)
	done["v"] = true


func _flag_wait(fight: Node, seconds: float, done: Dictionary) -> void:
	await fight._wait(seconds)
	done["v"] = true


func _accept_event(kind: String) -> InputEvent:
	match kind:
		"touch":
			var t := InputEventScreenTouch.new()
			t.pressed = true
			t.index = 0
			t.position = Vector2(400, 200)
			return t
		"enter":
			var k := InputEventKey.new()
			k.pressed = true
			k.keycode = KEY_ENTER
			k.physical_keycode = KEY_ENTER
			return k
		"joypad A":
			var j := InputEventJoypadButton.new()
			j.pressed = true
			j.button_index = JOY_BUTTON_A
			return j
	var m := InputEventMouseButton.new()
	m.pressed = true
	m.button_index = MOUSE_BUTTON_LEFT
	m.position = Vector2(400, 200)
	m.global_position = m.position
	return m


func _real_wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _test_skippable() -> void:
	print("timed cards and waits skip on one tap, click, Enter or controller A")
	var size := Vector2i(844, 390)
	for kind in ["click", "touch", "enter", "joypad A"]:
		for which in ["cold open", "act 1", "act 2"]:
			var sub := _make_viewport(size)
			Story.clear_run() # a title with no save: START only
			var main: Control = load("res://scenes/Main.tscn").instantiate()
			sub.add_child(main)
			await _frames(2)
			var done := {"v": false}
			match which:
				"cold open":
					_flag_prev(main, done)
				"act 1":
					_flag_act(main, 1, done)
				_:
					_flag_act(main, 2, done)
			await _real_wait(0.7)
			var hint_ok := false
			for c in _controls(main):
				if c is Label and c.name == "ContinueHint" and c.modulate.a > 0.5 and c.text == Story.continue_hint():
					hint_ok = true
			_check(hint_ok and not done["v"], "%s card (%s): the continue hint shows and the card is still up" % [which, kind])
			var t0 := Time.get_ticks_msec()
			sub.push_input(_accept_event(kind))
			var frames := 0
			while not done["v"] and frames < 200:
				frames += 1
				await get_tree().process_frame
			var elapsed := Time.get_ticks_msec() - t0
			_check(done["v"] and elapsed < 1500, "%s card (%s): one input skips it at once (%d ms, hold is 2.4 to 5.5 s)" % [which, kind, elapsed])
			sub.queue_free()
			await _real_wait(0.2)

	# Dialogue: a tap finishes the line; the next tap moves on; an auto-advance line skips too.
	var sub2 := _make_viewport(size)
	var d := Dialogue.new()
	sub2.add_child(d)
	d.play(story.scene("lamay_open"))
	await _frames(3)
	await _real_wait(0.25)
	_check(d._typing, "dialogue: the first line is still typing")
	sub2.push_input(_accept_event("touch"))
	await _frames(2)
	_check(not d._typing and d._index == 0, "dialogue: one tap completes the line")
	await _real_wait(0.2)
	sub2.push_input(_accept_event("click"))
	await _frames(2)
	_check(d._index == 1, "dialogue: the next tap moves on")
	sub2.queue_free()
	var sub3 := _make_viewport(size)
	var d3 := Dialogue.new()
	sub3.add_child(d3)
	d3.play([
		{"kind": "narr", "speaker": "", "text": "Auto.", "autoAdvance": 8.0},
		{"kind": "narr", "speaker": "", "text": "Next."},
	])
	await _real_wait(0.6) # typed out, now counting down 8 seconds
	_check(d3._index == 0, "auto-advance line: waiting on its timer")
	sub3.push_input(_accept_event("enter"))
	await _frames(2)
	_check(d3._index == 1, "auto-advance line: one Enter skips the countdown")
	sub3.queue_free()

	# Battle pauses (the turn caption, the awakening, victory, a fall) skip too.
	for kind in ["click", "touch", "enter", "joypad A"]:
		var sub4 := _make_viewport(size)
		var fight := Combat.new()
		fight.use_progress = false
		sub4.add_child(fight)
		await _frames(2)
		var done2 := {"v": false}
		_flag_wait(fight, 10.0, done2)
		await _real_wait(0.3)
		_check(fight._waiting and fight._continue.visible, "battle pause (%s): waiting, with the continue hint shown" % kind)
		var t1 := Time.get_ticks_msec()
		sub4.push_input(_accept_event(kind))
		var f2 := 0
		while not done2["v"] and f2 < 200:
			f2 += 1
			await get_tree().process_frame
		_check(done2["v"] and Time.get_ticks_msec() - t1 < 1000, "battle pause (%s): one input skips a 10 second wait" % kind)
		sub4.queue_free()
		await _real_wait(0.2)


# --- A tall narrow screen (a folded phone's cover display) with real touch input --------------------------

func _touch_at(vp: Viewport, pos: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.pressed = true
	down.index = 0
	down.position = pos
	vp.push_input(down)
	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.index = 0
	up.position = pos
	vp.push_input(up)


func _test_narrow_screen() -> void:
	print("narrow tall screen (cover display), touch only")
	Story.force_touch = true
	for win in [Vector2i(904, 2316), Vector2i(360, 800)]:
		var tag := "%dx%d" % [win.x, win.y]
		var sub := _make_viewport(Vector2i(360, 800))
		Story.clear_run() # a title with no save: START only
		var main: Control = load("res://scenes/Main.tscn").instantiate()
		main.window_size_override = win
		sub.add_child(main)
		await _frames(3)
		_check(main._rotate.visible, "narrow %s: the rotate suggestion shows" % tag)
		var label_ok := false
		for c in _controls(main):
			if c is Label and c.name == "BuildLabel" and String(c.text).begins_with("build "):
				label_ok = true
		_check(label_ok, "narrow %s: the title shows the build label" % tag)
		await _real_wait(0.2)
		_touch_at(sub, Vector2(180, 400))
		await _frames(2)
		_check(not main._rotate.visible, "narrow %s: one tap dismisses the rotate suggestion" % tag)
		var start: Button = main.find_child("StartButton", true, false)
		await _real_wait(0.2)
		sub.push_input(_accept_event("touch")) # a touch that is not on a button: must not start anything
		var started_before: bool = main._running
		_check(started_before == false, "narrow %s: a stray tap does not start the game" % tag)
		# START by touch, then the opening card skips on one touch.
		var scale := Vector2(360, 800) / LOGICAL
		var center := start.get_global_rect().get_center() * scale
		var emu := InputEventMouseButton.new() # Godot sends the emulated click to buttons
		emu.button_index = MOUSE_BUTTON_LEFT
		emu.position = center
		emu.global_position = center
		emu.pressed = true
		sub.push_input(emu)
		emu = emu.duplicate()
		emu.pressed = false
		sub.push_input(emu)
		await _real_wait(0.9)
		_check(main._running and main._card_active, "narrow %s: touching START begins the opening card" % tag)
		var t0 := Time.get_ticks_msec()
		_touch_at(sub, Vector2(180, 400))
		var frames := 0
		while main._card_active and frames < 120:
			frames += 1
			await get_tree().process_frame
		_check(not main._card_active and Time.get_ticks_msec() - t0 < 1500, "narrow %s: one touch skips the opening card (%d ms)" % [tag, Time.get_ticks_msec() - t0])
		sub.queue_free()
		await _real_wait(0.3)
	Story.force_touch = false


# --- Battle animation: code-driven motion on placeholder shapes, with drop-in slots for real art -----------

func _test_battle_animation() -> void:
	print("battle animation (code-driven placeholders and drop-in slots)")
	var stage := Control.new()
	stage.size = Vector2(1280, 720)
	add_child(stage)
	var hero := BattleActor.new("no_art_hero", "teo", Color("c9a24a"), Vector2(220, 340), 1.0)
	hero.position = Vector2(150, 130)
	stage.add_child(hero)
	var foe := BattleActor.new("no_art_foe", "aswang", Color("c8452e"), Vector2(300, 280), -1.0)
	foe.position = Vector2(860, 190)
	stage.add_child(foe)
	await _frames(2)
	_check(hero.view_kind == "silhouette" and foe.view_kind == "silhouette", "with no art dropped in, actors use the programmatic silhouette")

	# Idle sway: the rig is never still.
	await _real_wait(0.25)
	var a := hero.rig.position.y
	var ra := hero.rig.rotation
	await _real_wait(0.45)
	_check(not is_equal_approx(a, hero.rig.position.y) or not is_equal_approx(ra, hero.rig.rotation), "idle: the character sways (not a still picture)")

	# Lunge: reaches toward the target, signals contact once, comes home.
	var contacts := {"n": 0, "min_gap": 99999.0}
	hero.contact.connect(func() -> void:
		contacts["n"] += 1
		contacts["min_gap"] = foe.home.x - hero.position.x)
	var tw := hero.lunge_to(foe.home, 120.0)
	await tw.finished
	_check(contacts["n"] == 1, "lunge: contact fires once at the apex")
	_check(hero.get_index() > foe.get_index(), "lunge: the attacker is drawn in front of its target")
	_check(contacts["min_gap"] < foe.home.x - hero.home.x - 200.0, "lunge: the attacker travels toward the target (gap %d)" % contacts["min_gap"])
	_check(hero.position.distance_to(hero.home) < 1.0, "lunge: the attacker returns home")

	# Hit: flash, knockback, spring back.
	var tw2 := foe.hit(1.0, true)
	await _frames(2)
	_check(foe.rig.modulate.r > 1.2, "hit: a white flash")
	await _frames(8)
	_check(absf(foe.position.x - foe.home.x) > 2.0, "hit: knockback away from the attacker")
	await tw2.finished
	_check(foe.position.distance_to(foe.home) < 1.0 and foe.rig.modulate.is_equal_approx(Color.WHITE), "hit: springs back and the flash clears")

	# Wind-up telegraphs each intent with a different pose, then clears.
	for key in ["claw", "lunge", "flurry"]:
		foe.windup(key)
		await _real_wait(0.5)
		_check(foe.rig.modulate.r > 1.1 and foe.rig.modulate.g < 1.0, "wind-up (%s): the enemy glows red as a telegraph" % key)
		foe.end_windup()
		await _real_wait(0.3)
		_check(foe.rig.modulate.is_equal_approx(Color.WHITE) and foe.position.distance_to(foe.home) < 1.0, "wind-up (%s): clears back to rest" % key)
	var tw3 := hero.parry_pose()
	await tw3.finished
	var tw4 := foe.recoil()
	await tw4.finished
	hero.down()
	await _real_wait(0.7)
	_check(hero.rig.modulate.a < 0.5 and absf(hero.rig.rotation) > 1.0, "down: the character falls")
	hero.rise()
	await _real_wait(0.6)
	_check(hero.rig.modulate.a > 0.95 and absf(hero.rig.rotation) < 0.3, "rise: the watch turns back and the character stands")
	hero.rewind_pulse(stage)
	FxBurst.play(stage, "clock", Vector2(640, 300), Color("00ffcc"))
	for mode in ["spark", "slash", "ring"]:
		FxBurst.play(stage, mode, Vector2(900, 300), Color("fff3b0"), 1.5)
	await _real_wait(1.0)
	var leftover := 0
	for c in stage.get_children():
		if c is FxBurst:
			leftover += 1
	_check(leftover == 0, "effects free themselves when done")
	stage.queue_free()

	# Drop-in slot 1: a sprite-sheet strip plus a json per move.
	DirAccess.make_dir_recursive_absolute("user://battle_test/sheeted")
	var strip := Image.create(128, 32, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0.9, 0.3, 0.3))
	strip.save_png("user://battle_test/sheeted/idle.png")
	var meta := FileAccess.open("user://battle_test/sheeted/idle.json", FileAccess.WRITE)
	meta.store_string('{"frame_w": 32, "frame_h": 32, "frames": 4, "fps": 8, "loop": true}')
	meta.close()
	var sheeted := BattleActor.new("sheeted", "teo", Color("c9a24a"), Vector2(200, 300), 1.0)
	sheeted.asset_root = "user://battle_test/"
	add_child(sheeted)
	await _frames(3)
	_check(sheeted.view_kind == "sheet" and sheeted._sprite != null and sheeted._sprite.sprite_frames.get_frame_count("idle") == 4, "drop-in: a sprite-sheet strip replaces the silhouette (4 frames)")
	_check(sheeted._sprite.is_playing() and sheeted._sprite.animation == "idle", "drop-in: the sheet plays its idle")
	sheeted.queue_free()

	# Drop-in slot 1b: one strong pose per move, no json; scaled to fit the box, feet on the bottom centre.
	DirAccess.make_dir_recursive_absolute("user://battle_test/posed")
	for pose_move in ["idle", "attack"]:
		var pimg := Image.create(400, 600, false, Image.FORMAT_RGBA8)
		pimg.fill(Color(0.3, 0.3, 0.9) if pose_move == "idle" else Color(0.9, 0.9, 0.3))
		pimg.save_png("user://battle_test/posed/%s.png" % pose_move)
	var posed := BattleActor.new("posed", "teo", Color("c9a24a"), Vector2(200, 300), 1.0)
	posed.asset_root = "user://battle_test/"
	add_child(posed)
	await _frames(3)
	_check(posed.view_kind == "sheet" and posed._sprite.sprite_frames.get_frame_count("idle") == 1 and posed.pose == "idle", "single pose: a lone png with no json is a one-frame pose")
	_check(is_equal_approx(posed._pose_holder.scale.x, 0.45) and is_equal_approx(posed._pose_holder.position.y, 300.0) and is_equal_approx(posed._sprite.position.y, -600.0), "single pose: a 600 px tall idle stands 90%% of a 300 px box (scale %.3f), feet on the bottom" % posed._pose_holder.scale.x)
	posed.windup("claw")
	_check(posed.pose == "idle", "single pose: a move with no art (windup) falls back to idle")
	posed.end_windup()
	var ptw := posed.lunge_to(Vector2(900, 0), 100.0)
	await _frames(2)
	_check(posed.pose == "attack" and posed._pose_holder.scale.x > 0.45, "single pose: the attack pose shows with a squash as it changes")
	await ptw.finished
	await _frames(2)
	_check(posed.pose == "idle", "single pose: back to idle after the lunge")
	posed.hit(1.0)
	_check(posed.pose == "idle", "single pose: hit with no art falls back to idle (the flash and knockback still play)")
	posed.queue_free()

	# Per-fight backgrounds: res://assets/battle/bg/<fight_id>.webp, falling back to the shared panel.
	for ep_enemy in ["lunod", "ligaw_berto", "unsent", "aswang", "hiraya_hound"]:
		var bf := Combat.new()
		bf.enemy_id = ep_enemy
		var bg_tex := bf.battle_background()
		_check(bf.fight_id == "ep1_" + ep_enemy and (bf.bg_is_custom or bg_tex == Art.panel("ep1_12_alley_delivery")), "battle background for %s: its own art or the ep1_12 stand-in" % bf.fight_id)
		bf.free()
	# The Episode 1 battle art: every fighter has its poses, every fight its background.
	var drawn := {"teo": 7, "pido": 7, "kardo": 7, "lunod": 4, "ligaw_berto": 4, "unsent": 4, "aswang": 4, "hiraya_hound": 4}
	for art_id in drawn:
		var party_side: bool = int(drawn[art_id]) == 7
		var real := BattleActor.new(art_id, "teo", Color.WHITE, Vector2(220, 340) if party_side else Vector2(300, 280), 1.0 if party_side else -1.0)
		add_child(real)
		await _frames(1)
		_check(real.view_kind == "sheet" and real._frame_sizes.size() == int(drawn[art_id]) and real.pose == "idle", "battle art: %s has its %d poses (%d)" % [art_id, drawn[art_id], real._frame_sizes.size()])
		real.queue_free()
	# In every fight: the standing fighter is big, and no pose leaves the screen or rises into the HUD.
	for setup in [["lunod", ["pido"]], ["ligaw_berto", ["teo"]], ["unsent", ["teo"]], ["aswang", ["teo"]], ["hiraya_hound", ["teo", "kardo"]]]:
		var lf := Combat.new()
		lf.enemy_id = setup[0]
		for pid in setup[1]:
			lf.party_override.append(pid)
		add_child(lf)
		await _frames(2)
		var bad: Array[String] = []
		for key in lf._actors:
			var ba: BattleActor = lf._actors[key]
			var feet := ba.position.y + ba.size.y
			var idle_h := float(ba._used[ba._resolve("idle")].size.y) * ba._fit
			if idle_h < 0.6 * ba.size.y:
				bad.append("%s idle only %d%% of its box" % [key, 100.0 * idle_h / ba.size.y])
			for mv in ba._used:
				var r: Rect2i = ba._used[mv]
				var fs: Vector2 = ba._frame_sizes[mv]
				var cx := ba.position.x + ba.size.x * 0.5
				var x0 := cx + (r.position.x - fs.x * 0.5) * ba._fit if ba.facing > 0 else cx - (r.end.x - fs.x * 0.5) * ba._fit
				var top := feet - (fs.y - r.position.y) * ba._fit
				if x0 < 0.0 or x0 + r.size.x * ba._fit > 1280.0 or feet - top > ba.max_height + 0.5:
					bad.append("%s %s (x %d..%d, top %d)" % [key, mv, x0, x0 + r.size.x * ba._fit, top])
		_check(bad.is_empty(), "battle layout ep1_%s: fighters fill their boxes, every pose stays on screen and under the HUD %s" % [setup[0], bad])
		lf.queue_free()
	for fight_enemy in ["lunod", "ligaw_berto", "unsent", "aswang", "hiraya_hound"]:
		var cf := Combat.new()
		cf.enemy_id = fight_enemy
		cf.battle_background()
		_check(cf.bg_is_custom, "battle art: ep1_%s has its own background" % fight_enemy)
		cf.free()
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	_check(presets.count("assets/battle/*.json") >= 2, "exports pack battle strip json (web and linux include filters)")

	# Drop-in slot 2: any scene (a Blender render, a rig, a 3D viewport) as actor.tscn.
	DirAccess.make_dir_recursive_absolute("user://battle_test/sceneful")
	var root := ColorRect.new()
	root.color = Color(0.2, 0.8, 0.4)
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "user://battle_test/sceneful/actor.tscn")
	var sceneful := BattleActor.new("sceneful", "teo", Color("c9a24a"), Vector2(200, 300), 1.0)
	sceneful.asset_root = "user://battle_test/"
	add_child(sceneful)
	await _frames(3)
	_check(sceneful.view_kind == "scene" and sceneful._scene_view != null, "drop-in: an actor.tscn scene replaces the silhouette")
	sceneful.queue_free()


# --- Episode 1 as a whole: structure, goals, and two full automatic playthroughs ---------------------------

func _test_episode_flow() -> void:
	print("Episode 1 flow: structure, goals, and full playthroughs")
	var acts: Array = story.flow.get("acts", [])
	_check(acts.size() == 3, "Episode 1 has 3 acts in the flow (%d)" % acts.size())
	var scene_beats := 0
	var problems: Array[String] = []
	var interactions := 0
	var hubs := 0
	for act in acts:
		var beats: Array = act["beats"]
		for i in beats.size():
			var beat: Dictionary = beats[i]
			var kind := String(beat.get("type", ""))
			if kind == "hub":
				hubs += 1
				for o in beat.get("options", []):
					if story.scene(String(o["scene"])).is_empty():
						problems.append("hub scene '%s' does not exist" % o["scene"])
			if kind != "scene":
				if kind in ["fight", "hub"] and String(beat.get("goal", "")) == "":
					problems.append("%s beat has no goal" % kind)
				continue
			scene_beats += 1
			var id := String(beat["id"])
			var steps: Array = story.scene(id)
			if steps.is_empty():
				problems.append("scene '%s' does not exist" % id)
				continue
			if String(beat.get("goal", "")) == "":
				problems.append("scene '%s' has no goal" % id)
			var has_choice := false
			for st in steps:
				if st.has("choice") or st.has("qte"):
					has_choice = true
					interactions += 1
			var next_type := ""
			if i + 1 < beats.size():
				next_type = String(beats[i + 1].get("type", ""))
			var connector: bool = String(beat.get("action", "")) == "note" and steps.size() <= 16 # both arrival paths counted; a player sees one
			if not (has_choice or next_type in ["fight", "hub"] or connector):
				problems.append("scene '%s' has no choice, no action beat and is not a short connector (%d steps)" % [id, steps.size()])
	_check(problems.is_empty(), "every scene has a goal and a choice, a QTE or an action beat, %d scenes %s" % [scene_beats, problems])
	_check(interactions >= 20, "Episode 1 has choices and timing beats throughout (%d)" % interactions)
	_check(hubs == 2, "the wake and the estero are hubs (%d)" % hubs)
	for big in ["lola_answers", "gate_ram", "the_offer"]:
		var found := false
		for act in acts:
			for beat in act["beats"]:
				if beat.get("id", "") == big:
					found = true
		_check(found, "a big choice scene in every act: %s" % big)

	for strategy in ["first", "wild"]:
		var res := await _autoplay_episode(strategy)
		_check(res["ended"], "playthrough (%s): reaches the end card in %d frames" % [strategy, res["frames"]])
		_check(res["steps"] >= 200, "playthrough (%s): %d story steps shown, %d fights" % [strategy, res["steps"], res["fights"]])
		_check(res["fights"] == 7, "playthrough (%s): all seven fights were played (%d)" % [strategy, res["fights"]])
		_check(story.flags.get("watch_awake", false) and story.age_stage() >= 1, "playthrough (%s): the watch awoke and Teo's hair greyed (stage %d)" % [strategy, story.age_stage()])
		_check(res["cues"].has("battle") and res["cues"].has("boss"), "playthrough (%s): fights play the battle and boss cues, not the story music (%s)" % [strategy, res["cues"].keys()])
		_check(not story.has_run(), "playthrough (%s): finishing the episode clears the mid-episode save" % strategy)


func _fight_tick(fight: Combat, strategy: String, rng: RandomNumberGenerator) -> void:
	if fight._ring.active:
		fight._ring._armed_at -= 1000
		if strategy == "wild" and fight._ring.level != "guided" and rng.randf() < 0.25:
			fight._ring._process(10.0) # a deliberate miss: falls and rewinds get exercised
		else:
			fight._ring._t = fight._ring.seconds * 0.9
			fight._ring._pause = 0.0
			fight._ring.press()
		return
	var cmds := fight.enabled_commands()
	if cmds.is_empty():
		return
	var pick: String = cmds[0]
	if fight.menu_mode == "main":
		if cmds.has("skill") and strategy == "wild" and rng.randf() < 0.3:
			pick = "skill"
		elif cmds.has("guard") and strategy == "wild" and rng.randf() < 0.2:
			pick = "guard"
		elif cmds.has("attack"):
			pick = "attack"
	else:
		for c in cmds:
			if c != "back":
				pick = c
				break
	fight._buttons[pick].pressed.emit()


func _autoplay_episode(strategy: String) -> Dictionary:
	story.reset()
	var sub := _make_viewport(Vector2i(1280, 720))
	Story.clear_run() # a title with no save: START only
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	main.test_fast = true
	sub.add_child(main)
	await _frames(3)
	main._start_game()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var frames := 0
	var steps := 0
	var fights := {}
	var ended := false
	var seen_index := {}
	var cues := {}
	while frames < 120000:
		frames += 1
		await get_tree().process_frame
		if main._card_active:
			main._card_skip = true
		var layer: Control = main._layer
		if layer.find_child("PlayAgainButton", true, false) != null:
			ended = true
			break
		var go: Button = layer.find_child("HubGo", true, false)
		if go != null:
			# The hub: "first" hears the minimum and leaves; "wild" hears everyone.
			var picked := false
			for i in 4:
				var hb: Button = layer.find_child("Hub_%d" % i, true, false)
				if hb != null and not hb.disabled and (strategy == "wild" or go.disabled):
					hb.pressed.emit()
					picked = true
					break
			if not picked and not go.disabled:
				go.pressed.emit()
			await get_tree().process_frame
			continue
		for c in layer.get_children():
			if c is Dialogue:
				var d: Dialogue = c
				var key := d.get_instance_id()
				if d._index != seen_index.get(key, -2):
					seen_index[key] = d._index
					steps += 1
				if d._busy:
					if d._choice_box.visible:
						var n: int = d._choice_step["choice"]["options"].size()
						var pick := 0 if strategy == "first" else rng.randi_range(0, n - 1)
						d._settle_choice(pick, false)
					elif d._ring.active:
						d._ring._armed_at -= 1000
						d._ring._t = d._ring.seconds * 0.9
						d._ring._pause = 0.0
						d._ring.press()
				else:
					d._advance()
			elif c is Combat:
				fights[c.get_instance_id()] = true
				cues[Sfx.current_cue] = true
				_fight_tick(c, strategy, rng)
	sub.queue_free()
	await _real_wait(0.2)
	return {"ended": ended, "frames": frames, "steps": steps, "fights": fights.size(), "cues": cues}


# --- John's playtest notes (Nov 2026): tones, corner notes, flood waves, harder fights, shadows, moving panels ---

func _test_feedback_round() -> void:
	print("playtest notes: tones, notes, waves, difficulty, shadows, panel drift")
	# Every choice in Episode 1 says how it is said, and the buttons show it.
	var untagged: Array[String] = []
	var all_scenes: Dictionary = story._episode.get("scenes", {})
	for sid in all_scenes:
		for st in all_scenes[sid]:
			if st.has("choice"):
				var c: Dictionary = st["choice"]
				if c.get("tones", []).size() != c["options"].size():
					untagged.append(String(c["id"]))
	_check(untagged.is_empty(), "every Episode 1 choice has a tone per option %s" % [untagged])
	# The 1998 choice belongs to Kardo, thinking: no Teo portrait, no "Kardo:" on the options.
	var kardo_step: Dictionary = {}
	for st in story.scene("co_rewind"):
		if st.has("choice"):
			kardo_step = st
	_check(String(kardo_step.get("speaker", "")) == "Kardo" and String(kardo_step.get("portrait", "")) == "" and not String(kardo_step["choice"]["options"][0]).begins_with("Kardo:"), "the 1998 choice is Kardo's thought, not Teo's")
	# Mang Berto's wake: no ghost of Berto forty years ago.
	for st in story.scene("berto_ghost"):
		_check(not String(st.get("text", "")).contains("saw me at my") and not String(st.get("text", "")).contains("He saw me too"), "Mang Berto does not claim Lolo saw his ghost forty years ago")

	story.reset()
	var dlg := Dialogue.new()
	add_child(dlg)
	dlg.play(story.scene("debt_notice"))
	var guard := 0
	while not dlg._choice_box.visible and guard < 60:
		dlg._advance()
		await _frames(1)
		guard += 1
	var first_btn := dlg._choice_box.get_child(0) as Button
	_check(first_btn != null and first_btn.get_node_or_null("Tone") != null, "choice buttons carry a tone tag")
	_check((dlg._choice_box.get_child(1) as Button).get_node("Tone").text == "ANGRY", "\"Leave the wake.\" reads ANGRY")
	dlg._settle_choice(1, false)
	await _frames(2)
	_check(dlg._banner.visible and dlg._banner.position.y < 60.0 and dlg._banner.position.x > 640.0, "a consequence note shows small, in the top-right corner")
	dlg._advance()
	await _frames(1)
	_check(not dlg._banner.visible, "moving the story on clears the note at once")
	_check(dlg._art.scale.x > 1.0 or dlg._art.texture == null, "the panel drifts (Ken Burns), scale %.2f" % dlg._art.scale.x)
	dlg.queue_free()

	# Waves: wounds carry into the next wave, and the tide cannot be beaten, only outlasted.
	story.reset()
	var w1 := Combat.new()
	w1.enemy_id = "lunod"
	w1.fast = true
	w1.carry_wounds = true
	w1.party_override.append("pido")
	add_child(w1)
	await _frames(1)
	w1.model.allies[0].hp = 70
	w1.model.enemies[0].hp = 0
	await w1._victory()
	_check(story.injury == w1.model.allies[0].max_hp - 70, "a won wave carries Pido's wounds into the next (%d)" % story.injury)
	w1.queue_free()
	var tide := Combat.new()
	tide.enemy_id = "lunod_tide"
	tide.party_override.append("pido")
	add_child(tide)
	await _frames(1)
	_check(tide.model.allies[0].hp == tide.model.allies[0].max_hp - story.injury, "the next wave starts hurt")
	tide.model.enemies[0].hp = 0
	_check(tide.model.enemies[0].hp == 1 and not tide.model.is_victory(), "the tide cannot be beaten")
	_check(not tide._outlasted(), "the tide is not over at once")
	tide.model.enemy_turns = tide._turns_at_start + 4
	_check(tide._outlasted(), "four enemy turns outlast the tide")
	_check(tide._aswang_actor.actor_id == "lunod" and tide.fight_id == "ep1_lunod", "the waves reuse the drowned's art and background")
	tide.queue_free()
	story.injury = 0

	# Harder: a cornered enemy hits a quarter harder, and says so.
	var hm := BattleModel.new()
	var foe := BattleModel.Unit.new("x", "X", false, 100, 8)
	hm.enemies.append(foe)
	hm.enemy_turns = 3
	foe.hp = 35
	hm.plan_intent(foe)
	_check(bool(foe.intent.get("enraged", false)) and hm.intent_text(foe).begins_with("ENRAGED"), "under 40%% health the enemy is ENRAGED")
	var defs: Dictionary = story.enemy_defs
	_check(int(defs["ligaw_berto"]["hp"]) >= 120 and int(defs["aswang"]["hp"]) >= 200, "Episode 1 enemies have more health")

	# Fighters stand on the floor: a contact shadow under the feet.
	var shadowed := BattleActor.new("teo", "teo", Color.WHITE, Vector2(220, 340), 1.0)
	add_child(shadowed)
	await _frames(1)
	var sh := shadowed.rig.get_node_or_null("Shadow") as Node2D
	_check(sh != null and absf(sh.position.y - shadowed.size.y) < 4.0, "a contact shadow sits under Teo's feet")
	shadowed.queue_free()


# --- Round 2 of the playtest: transition panels, the rewind clip, the walkable hubs ------------------------------
func _test_walk_and_clips() -> void:
	print("transition panels, panel clips, the walkable 2.5D hubs")
	var story := get_node("/root/Story")
	# The six in-between panels exist and the cold open uses them.
	var used := {}
	for id in ["co_wave2", "co_wave3", "co_rewind", "co_downriver"]:
		for st in story.scene(id):
			used[String(st.get("panel", ""))] = true
	for p in ["ep1_c01b_drain", "ep1_c01c_stairs", "ep1_c02b_recede", "ep1_c02c_counting", "ep1_c02d_white", "ep1_c02e_street"]:
		_check(Art.panel(p) != null and used.has(p), "transition panel %s exists and is used" % p)
	# A panel with a clip plays it inside the panel; one without hides the player.
	_check(Art.clip("ep1_c02_pido_rewind") != null, "the rewind panel has a clip")
	_check(Art.clip("ep1_c01_flood_parlor") == null, "a panel without a clip has none")
	var sub := _make_viewport(Vector2i(1280, 720))
	var d := Dialogue.new()
	sub.add_child(d)
	d.play([{"kind": "narr", "speaker": "", "text": "a", "panel": "ep1_c02_pido_rewind"}, {"kind": "narr", "speaker": "", "text": "b", "panel": "ep1_c01_flood_parlor"}])
	await _frames(3)
	var clip: VideoStreamPlayer = d.find_child("PanelClip", true, false)
	_check(clip != null and clip.visible and clip.stream != null and clip.get_parent() == d._art, "the clip plays over the rewind panel and moves with it")
	d._advance()
	await _frames(3)
	_check(clip != null and not clip.visible, "the clip is hidden on the next panel")
	sub.queue_free()

	# The walkable 2.5D hubs.
	var hubs := {}
	for act in story.flow.get("acts", []):
		for beat in act["beats"]:
			if String(beat.get("type", "")) == "hub":
				hubs[String(beat.get("id", ""))] = beat
	for id in ["wake", "estero"]:
		var hub: Dictionary = hubs.get(id, {})
		_check(hub.has("map") and not ExploreMap.map_def(String(hub.get("map", ""))).is_empty(), "the %s hub is a walkable map" % id)
		var art := ["teo_walk"]
		for o in hub.get("options", []):
			_check(o.has("at"), "%s option %s has a place on the map" % [id, o.get("scene", "")])
			if o.has("sprite"):
				art.append(String(o["sprite"]))
		for e in hub.get("extras", []):
			art.append(String(e["sprite"]))
		for p in ExploreMap.map_def(String(hub.get("map", ""))).get("props", []):
			art.append(String(p["s"]))
		var missing: Array = []
		for n in art:
			if not ResourceLoader.exists("res://assets/explore/%s.png" % n):
				missing.append(n)
		_check(missing.is_empty(), "%s map art all exists %s" % [id, missing])
	var wake: Dictionary = hubs.get("wake", {})
	sub = _make_viewport(Vector2i(1280, 720))
	var room := ExploreMap.new()
	room.setup(wake, {}, 2, Vector2(-1, -1))
	sub.add_child(room)
	await _frames(2)
	for i in 4:
		_check(room.find_child("Hub_%d" % i, true, false) != null, "the wake has a tag for option %d" % i)
	var go: Button = room.find_child("HubGo", true, false)
	_check(go != null and go.disabled, "the stairs stay locked until two people are heard")
	_check(room.find_child("Npc_nena", true, false) != null and room.find_child("Npc_berto", true, false) != null, "Nena sits in the room and Mang Berto's ghost watches")
	var p0: Vector2 = room.teo_pos
	Input.action_press("ui_right")
	await _frames(20)
	Input.action_release("ui_right")
	_check(room.teo_pos.x > p0.x + 0.3 and room._dir == ExploreMap.SIDE and not room._flip, "the right arrow walks Teo right (%.2f -> %.2f)" % [p0.x, room.teo_pos.x])
	var p1: Vector2 = room.teo_pos
	Input.action_press("ui_up")
	await _frames(20)
	Input.action_release("ui_up")
	_check(room.teo_pos.y < p1.y - 0.3 and room._dir == ExploreMap.UP, "the up arrow walks Teo away from the camera (%.2f -> %.2f)" % [p1.y, room.teo_pos.y])
	# Solid things stop him: walking into the card table from the front leaves him in front of it.
	room.teo_pos = Vector2(4.6, 6.2)
	for k in 60:
		room._move(Vector2(0, -0.05))
	_check(room.teo_pos.y > 5.0, "the card table blocks him (stopped at z %.2f)" % room.teo_pos.y)
	# A tap on the floor lands on the floor.
	var tap := room.floor_at(Vector2(640, 500))
	_check(tap.x > 0.0 and tap.y > 0.0, "a tap lands on the floor (%.1f, %.1f)" % [tap.x, tap.y])
	# Tapping a tag walks him over and then starts the talk.
	room.teo_pos = Vector2(6.0, 7.0)
	var got := [-9]
	room.picked.connect(func(i: int) -> void: got[0] = i)
	(room.find_child("Hub_0", true, false) as Button).pressed.emit()
	var f := 0
	while f < 900 and got[0] == -9:
		f += 1
		await get_tree().process_frame
	_check(got[0] == 0 and room.teo_pos.distance_to(Vector2(8.4, 3.1)) < ExploreMap.REACH, "tapping Aling Nena's tag walks Teo to her, then talks (%d at %s)" % [got[0], room.teo_pos])
	sub.queue_free()
	# Standing next to someone, SPACE talks; the exit opens once enough people are heard.
	sub = _make_viewport(Vector2i(1280, 720))
	room = ExploreMap.new()
	room.setup(wake, {0: true, 2: true}, 2, Vector2(14.9, 4.6))
	sub.add_child(room)
	await _frames(2)
	go = room.find_child("HubGo", true, false)
	_check(not go.disabled and room.nearest() == -1, "with two heard, the stairs are open and in reach")
	var heard0: Button = room.find_child("Hub_0", true, false)
	_check(heard0.disabled and heard0.text.begins_with("HEARD"), "a heard person's tag is marked")
	room.teo_pos = Vector2(9.4, 3.6)
	_check(room.nearest() == 1, "standing at the coffin, the coffin is what SPACE talks to (%d)" % room.nearest())
	sub.queue_free()
	# The estero: the creek is in the way except at the footbridge, and the woman sits across it.
	var est: Dictionary = hubs.get("estero", {})
	sub = _make_viewport(Vector2i(1280, 720))
	room = ExploreMap.new()
	room.setup(est, {}, 1, Vector2(5.0, 7.0))
	sub.add_child(room)
	await _frames(2)
	_check(room._blocked(Vector2(5.0, 4.6)), "Teo cannot walk into the creek")
	_check(not room._blocked(Vector2(9.7, 4.6)), "the footbridge crosses it")
	_check(room.find_child("Water", true, false) != null, "the estero has water")
	sub.queue_free()
	await _frames(2)
