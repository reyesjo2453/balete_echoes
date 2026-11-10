extends SceneTree
## Headless smoke test, run in CI:  godot --headless --path godot --script res://tests/smoke.gd
## Exercises the story data, the timing ring, a full dialogue run (QTEs and choices included),
## the turn-based combat rules and the courier run. Exits 1 on the first failed expectation.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failures += 1
		printerr("  FAIL ", what)


func _initialize() -> void:
	print("== Balete smoke test ==")
	await process_frame
	await _test_story()
	await _test_ring()
	await _test_dialogue()
	await _test_combat()
	await _test_courier()
	print("== done, failures: %d ==" % failures)
	quit(1 if failures > 0 else 0)


func _test_story() -> void:
	print("story data")
	var story := root.get_node_or_null("Story")
	_check(story != null, "Story autoload present")
	if story == null:
		return
	for id in ["stakes", "shop_morning", "step_out", "dante_call", "alley_arrival", "after_fight", "envelope", "lola_silence", "tondo_safehouse", "cliffhanger"]:
		var steps: Array = story.scene(id)
		_check(steps.size() > 0, "scene '%s' has %d steps" % [id, steps.size()])
		for step in steps:
			if not (step is Dictionary and step.has("text")):
				_check(false, "scene '%s' step missing text" % id)
				break
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
	root.add_child(ring)
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
	root.add_child(d)
	var state := {"done": false}
	d.finished.connect(func() -> void: state["done"] = true)
	d.play(Story.scene(scene_id))
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
		await process_frame
	d.queue_free()
	return state["done"]


func _test_dialogue() -> void:
	print("dialogue runs (QTEs and choices included)")
	Story.reset()
	for id in ["stakes", "shop_morning", "step_out", "dante_call", "alley_arrival", "after_fight", "envelope", "lola_silence"]:
		var ok: bool = await _drive_dialogue(id)
		_check(ok, "scene '%s' plays to the end" % id)
	_check(Story.loob == 1, "pressing Lola costs nothing but raises Loob (got %d)" % Story.loob)


func _test_combat() -> void:
	print("combat rules")
	Story.reset()
	var c := Combat.new()
	root.add_child(c)
	await process_frame
	_check(c._pick_attack()["name"] == "Claw", "first enemy attack is the teaching claw")
	_check(c._pick_attack()["name"] == "Claw", "second enemy attack is also the claw")
	var hp0 := c.hp
	c._resolve_parry(Combat.ATTACKS["claw"], "miss")
	_check(c.hp == hp0 - 18, "a missed parry takes full damage")
	hp0 = c.hp
	c._resolve_parry(Combat.ATTACKS["claw"], "good")
	_check(c.hp < hp0 and c.hp > hp0 - 18, "a good parry blocks most of the damage")
	hp0 = c.hp
	var e0 := c.enemy_hp
	c._resolve_parry(Combat.ATTACKS["claw"], "perfect")
	_check(c.hp == hp0 and c.enemy_hp < e0 and c.stagger == 1, "a perfect parry takes nothing, counters and staggers")
	c._resolve_parry(Combat.ATTACKS["claw"], "perfect")
	c._resolve_parry(Combat.ATTACKS["claw"], "perfect")
	_check(c.stunned and c.stagger == 0, "three perfect parries break the guard")
	c.guarding = true
	hp0 = c.hp
	c._resolve_parry(Combat.ATTACKS["lunge"], "miss")
	_check(c.hp == hp0 - 14, "guarding halves a missed lunge")
	c.queue_free()


func _test_courier() -> void:
	print("courier run")
	var run := CourierRun.new()
	root.add_child(run)
	var result := {"hits": -1}
	run.finished.connect(func(h: int) -> void: result["hits"] = h)
	var steps := 0
	while result["hits"] < 0 and steps < 2000:
		steps += 1
		run._process(0.05)
	_check(result["hits"] >= 0, "reaches the alley in %d steps (%d hits)" % [steps, result["hits"]])
	run.queue_free()
