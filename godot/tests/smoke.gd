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
	await _test_progression()
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
			m.team_moves = PartyData.team_moves(3)
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
					"taser":
						m.taser(u, foe)
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
	_check(hero2.hp == 40 and not t.usable(hero2).has("skill"), "Rewind undoes the last blow, once")
	_check(t.ring_level() == "guided", "the first parry is a guided lesson")

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


# --- Season progression: skills, energy, amulets, party, save data -------------------------------------

func _model_with(skill_ids: Array, variant: String = "base") -> BattleModel:
	var m := BattleModel.new()
	m.rng.seed = 7
	m.episode = 5
	var hero := BattleModel.Unit.new("renzo", "Renzo", true, 100, 10)
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
	_check(amulet_fight.model.allies[0].max_hp == 90, "the amulet's cost applies (Renzo's max HP 90)")
	amulet_fight.queue_free()
	var tiny := BattleModel.new()
	tiny.mods = Amulets.mods("mutya_ng_ulan")
	tiny.allies.append(BattleModel.Unit.new("renzo", "Renzo", true, 100, 10))
	tiny.enemies.append(BattleModel.Unit.new("aswang", "Aswang", false, 140, 8))
	tiny.start()
	tiny.enemies[0].intent = BattleModel.ATTACKS["claw"].duplicate()
	tiny.resolve_strike(tiny.enemies[0], tiny.allies[0], "perfect")
	_check(tiny.energy == 2, "Mutya ng Ulan: a perfect parry charges 2 (got %d)" % tiny.energy)
	tiny.resolve_strike(tiny.enemies[0], tiny.allies[0], "miss")
	_check(tiny.allies[0].hp == 100 - int(round(18 * 1.1)), "Mutya ng Ulan: blows land harder")

	# Party of two: Dante from Episode 3, his own menu, a team move, and a whole fight.
	_check(PartyData.party_for(1) == ["renzo"] and PartyData.party_for(3).has("dante"), "Renzo alone in Episode 1; Dante joins in Episode 3")
	_check(PartyData.member("dante")["commands"].has("taser"), "Dante has his own command menu (Taser)")
	_check(PartyData.team_moves(2).is_empty() and PartyData.team_moves(3).size() == 1, "the team move arrives with Dante")
	var duo := BattleModel.new()
	duo.episode = 3
	duo.allies.append(BattleModel.Unit.new("renzo", "Renzo", true, 100, 10))
	duo.allies.append(BattleModel.Unit.new("dante", "Dante", true, 120, 6))
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
		_check_inside(pair, "two-member fight (Dante's menu) %dx%d" % [size.x, size.y])
		_check(pair._buttons.has("taser") and pair._buttons.has("attack") and pair._buttons.has("guard"), "Dante's menu shows Wrench, Taser, Cover")
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
			var pick: String = "team" if cmds.has("team") else ("taser" if cmds.has("taser") else ("attack" if cmds.has("attack") else cmds[0]))
			duo_fight._buttons[pick].pressed.emit()
	_check(duo_result["done"] and empty == 0, "a two-member fight (Renzo and Dante) is won, no empty menu (%d frames)" % f)
	duo_fight.queue_free()

	# Episode 1 is unchanged: tutorial gating, no energy meter, no team move.
	var ep1 := Combat.new()
	ep1.use_progress = false
	add_child(ep1)
	await get_tree().process_frame
	ep1._show_menu("main")
	await get_tree().process_frame
	var ep1_cmds := ep1.enabled_commands()
	_check(ep1.model.allies.size() == 1 and ep1.model.skills.is_empty() and ep1._energy == null and not ep1._buttons.has("team") and not ep1._buttons.has("skill"), "Episode 1: Renzo alone, no Skill, no energy meter, no team move")
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
