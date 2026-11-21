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
	Progress.save_path = "user://smoke_save.json"
	Progress.reset()
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
	await _test_stage()
	await _test_retro()
	await _test_stage_fights()
	await _test_specials()
	await _test_aaa_phase2_and_combos()
	await _test_bystanders_reactivity_and_transit()
	await _test_intro_video()
	await _test_hd2d_upgrade()
	await _test_stagger_and_boss_gates()
	await _test_pixel_cg()
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
				_check(not StageBattle.enemy_def(String(beat["enemy"])).is_empty(), "fight beat enemy '%s' exists" % beat["enemy"])
				for id in beat.get("party", []):
					_check(not PartyData.member(String(id)).is_empty(), "fight beat party member '%s' exists" % id)
	_check(fights == 7, "Episode 1 has 7 fights: two waves of the drowned, Mang Berto, the unsent, the aswang ambush, the hound, the parlor finale (%d)" % fights)


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
	print("StageBattle rules (candles, wires, dodge, miss/rewind, victory)")
	story.reset()
	# 1. Every StageBattle enemy defines valid stats, attacks, and map placement; Spirit foes carry special tells.
	for enemy_id in ["lunod", "lunod_tide", "magbabalot", "ligaw_berto", "unsent", "aswang", "hiraya_hound", "aswang_finale"]:
		var d := StageBattle.enemy_def(enemy_id)
		_check(not d.is_empty() and int(d.get("hp", 0)) > 0 and not Dictionary(d.get("attacks", {})).is_empty(), "StageBattle enemy '%s' has valid stats and attacks" % enemy_id)

	# 2. Kardo's circuit rules on StageBattle: no KONTRA before a wire is clamped, capped at _max_wires().
	var kb := StageBattle.new()
	kb.setup({"enemy": "hiraya_hound", "party": ["teo", "kardo"]})
	var kardo := kb.unit("kardo")
	_check(kardo != null and not kb._usable(kardo, "discharge") and kb._usable(kardo, "wire"), "Kardo: KONTRA requires at least 1 clamped wire")
	kb.wired = kb._max_wires()
	_check(kb._usable(kardo, "discharge") and not kb._usable(kardo, "wire"), "Kardo: circuit caps at %d wires" % kb._max_wires())
	kb.free()

	# 3. Full StageBattle fights: normal parry win, plus forced miss -> fall/misses/rewind tracking.
	story.reset()
	var win_fight := await _play_stage({"enemy": "magbabalot"})
	_check(win_fight.get_meta("done") and win_fight.outcome in ["sent", "scattered"], "StageBattle (parry): Mang Andoy ends in %s" % win_fight.outcome)

	story.reset()
	var miss_fight := await _play_stage({"enemy": "lunod", "party": ["pido"], "test_miss": 1, "auto_react": 0.0})
	_check(miss_fight.get_meta("done") and story.misses >= 1, "StageBattle (miss): missed parries are counted (%d)" % story.misses)


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
		Story.clear_run() # a title with no save: START only
		var main: Control = load("res://scenes/Main.tscn").instantiate()
		main.boot_intro = false
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
		var fight := StageBattle.new()
		fight.setup({"enemy": "magbabalot"})
		sub3.add_child(fight)
		await _frames(3)
		fight._show_menu(fight.unit("teo"), "main")
		await _frames(3)
		_check_inside(fight, "fight " + tag)
		fight._ring.start("PARRY!", 2.0, "guided", StageBattle.LESSON)
		await _frames(2)
		_check_inside(fight, "parry ring " + tag)
		sub3.queue_free()

		# End card, and PLAY AGAIN is clickable.
		var sub4 := _make_viewport(size)
		Story.clear_run() # a title with no save: START only
		var main4: Control = load("res://scenes/Main.tscn").instantiate()
		main4.boot_intro = false
		sub4.add_child(main4)
		await _frames(2)
		main4._show_end()
		await _frames(3)
		# CASE CLOSED first: click one upgrade for each member, then CONTINUE.
		var cont: Button = main4.find_child("LevelContinue", true, false)
		_check(cont != null and cont.disabled, "end of case %s: CASE CLOSED waits for the upgrades" % tag)
		for who in Levels.roster(1):
			var perk: Button = main4.find_child("Perk_%s_%s" % [who, Levels.choices(String(who), 1)[0]["id"]], true, false)
			if perk != null:
				_click(sub4, perk.get_global_rect().get_center() * scale)
				await _frames(2)
		_check(cont != null and not cont.disabled and Progress.perks.get("1", {}).size() == Levels.roster(1).size(), "end of case %s: an upgrade picked for everyone (%s)" % [tag, Progress.perks])
		if cont != null:
			_click(sub4, cont.get_global_rect().get_center() * scale)
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
	main.boot_intro = false
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
	main.boot_intro = false
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
	var fight: StageBattle = null
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
			if c is StageBattle:
				fight = c
	_check(saw_recap, "continue: \"Previously on Balete\" plays first")
	_check(fight != null and fight.enemy_id == "hiraya_hound", "continue: resumes at the hound fight")
	_check(story.injury == 10 and story.flags.get("went_home", false), "continue: the fight restarts with the saved injuries and choices")
	if fight != null:
		var lead: StageBattle.Unit = fight.party[0]
		_check(lead.hp < lead.max_hp and fight.party.size() == 2, "continue: the lead starts the fight hurt, Kardo beside him (%d/%d)" % [lead.hp, lead.max_hp])
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
	main.boot_intro = false
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
	for e in ["lunod", "lunod_tide", "magbabalot", "ligaw_berto", "unsent", "aswang", "hiraya_hound", "aswang_finale"]:
		var ed := StageBattle.enemy_def(e)
		if ed.has("music") and not Sfx.has_cue(String(ed["music"])):
			unknown.append(ed["music"])
	_check(unknown.is_empty(), "every cue named by the flow, the scenes and the enemies exists %s" % [unknown])
	_check(silences >= 4, "big emotional beats fall silent (%d)" % silences)
	_check(String(StageBattle.enemy_def("hiraya_hound").get("music", "")) == "boss", "the hound fight gets the boss cue")
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

# --- Season progression: skills, amulets, party, StageBattle, save data -------------------------------------

func _test_progression() -> void:
	print("progression: skills, Loob forms, amulets, party, save data")

	# Skill data: one new power per episode, three forms each.
	var order := []
	for sk in Skills.all():
		order.append("%s@%d" % [sk["id"], int(sk["episode"])])
		var complete: bool = sk.has("name") and sk.has("text") and sk.has("energy_cost") and sk["effects"].has("base") and sk["effects"].has("protective") and sk["effects"].has("aggressive")
		_check(complete and not sk["effects"]["base"].is_empty() and not sk["effects"]["protective"].is_empty() and not sk["effects"]["aggressive"].is_empty(), "skill '%s' has base, protective and aggressive forms" % sk["id"])
	_check(order == ["rewind@1", "slow@2", "echo@4", "seventeen@5"], "skills unlock in order: Rewind, Slow, Echo, the 4:17 finale (%s)" % [order])
	_check(Skills.variant_for("slow", 0) == "protective" and Skills.variant_for("slow", 1) == "aggressive" and Skills.variant_for("slow", 5) == "aggressive", "Loob picks the form (below 1 protective, 1 or more aggressive)")
	_check(Skills.variant_for("rewind", 5) == "base", "Episode 1's Rewind stays in its base form (plays exactly as built)")
	_check(not Skills.effects("slow", "protective").is_empty() and not Skills.effects("echo", "aggressive").is_empty(), "Skills expose variant effect tables")

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

	# Party data & StageBattle rosters: Lolo Pido in cold open, Teo alone in Episode 1, Teo+Kardo against the hound.
	_check(PartyData.party_for(1) == ["teo"] and PartyData.party_for(2).has("kardo"), "Teo alone in Episode 1; Kardo joins in Episode 2; Lolo Pido is a guest only")
	_check(PartyData.member("kardo")["commands"].has("wire") and PartyData.member("kardo")["commands"].has("discharge"), "Kardo has his own command menu (Wire, Discharge)")
	_check(PartyData.team_moves(1).is_empty() and PartyData.team_moves(2).size() == 1, "the team move arrives with Kardo")

	var guest := StageBattle.new()
	guest.setup({"enemy": "lunod", "party": ["pido"]})
	_check(guest.party.size() == 1 and guest.party[0].id == "pido", "the cold-open fight is Lolo Pido's")
	guest.free()
	var pair1 := StageBattle.new()
	pair1.setup({"enemy": "hiraya_hound", "party": ["teo", "kardo"]})
	_check(pair1.party.size() == 2 and pair1.unit("teo") != null and pair1.unit("kardo") != null, "the hound fight stages Teo and Kardo")
	pair1.free()

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
		for which in ["cold open"]:
			var sub := _make_viewport(size)
			Story.clear_run() # a title with no save: START only
			var main: Control = load("res://scenes/Main.tscn").instantiate()
			main.boot_intro = false
			sub.add_child(main)
			await _frames(2)
			var done := {"v": false}
			_flag_prev(main, done)
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
		main.boot_intro = false
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
	print("battle effects and export preset filters")
	var stage := Control.new()
	stage.size = Vector2(1280, 720)
	add_child(stage)
	FxBurst.play(stage, "clock", Vector2(640, 300), Color("00ffcc"))
	for mode in ["spark", "slash", "ring"]:
		FxBurst.play(stage, mode, Vector2(900, 300), Color("fff3b0"), 1.5)
	await _real_wait(1.0)
	var leftover := 0
	for c in stage.get_children():
		if c is FxBurst:
			leftover += 1
	_check(leftover == 0, "FxBurst effects free themselves when done")
	stage.queue_free()
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	_check(presets.count('include_filter="data/*.json"') >= 2, "exports pack data/*.json (web and linux include filters)")


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
	_check(hubs == 3, "Hidalgo Street, the wake and the estero are hubs (%d)" % hubs)
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
		_check(res["fights"] >= 6, "playthrough (%s): all six story fights were played, as side-view battles (%d)" % [strategy, res["fights"]])
		_check(story.flags.get("watch_awake", false) and story.age_stage() >= 1, "playthrough (%s): the watch awoke and Teo's hair greyed (stage %d)" % [strategy, story.age_stage()])
		_check(res["cues"].has("battle") and res["cues"].has("boss"), "playthrough (%s): fights play the battle and boss cues, not the story music (%s)" % [strategy, res["cues"].keys()])
		_check(not story.has_run(), "playthrough (%s): finishing the episode clears the mid-episode save" % strategy)


func _autoplay_episode(strategy: String) -> Dictionary:
	story.reset()
	var sub := _make_viewport(Vector2i(1280, 720))
	Story.clear_run() # a title with no save: START only
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	main.boot_intro = false
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
			elif c is StageBattle:
				# Retro side-view fights play themselves at speed in fast mode (sensible picks, rings and prayers).
				if not fights.has(c.get_instance_id()):
					fights[c.get_instance_id()] = String(c.enemy_id)
				cues[Sfx.current_cue] = true
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
	# The 1998 choice belongs to Young Kardo, thinking: uses his young 1998 portrait (not Teo's or 2026 Kardo's), no "Kardo:" on the options.
	var kardo_step: Dictionary = {}
	for st in story.scene("co_rewind"):
		if st.has("choice"):
			kardo_step = st
	_check(String(kardo_step.get("speaker", "")) == "Kardo" and String(kardo_step.get("portrait", "")) == "portrait_y_kardo" and not String(kardo_step["choice"]["options"][0]).begins_with("Kardo:"), "the 1998 choice is Young Kardo's thought with his 1998 portrait, not Teo's")
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

	# Waves & difficulty: stage_enemies define survive_turns for the tide and Phase 2 tuning on bosses.
	_check(int(StageBattle.enemy_def("lunod_tide").get("survive_turns", 0)) == 3, "lunod_tide is outlasted for 3 turns")
	_check(int(StageBattle.enemy_def("ligaw_berto").get("hp", 0)) >= 150 and int(StageBattle.enemy_def("aswang").get("hp", 0)) >= 160 and int(StageBattle.enemy_def("aswang_finale").get("hp", 0)) >= 350, "Episode 1 bosses have substantial HP pools")
	_check(bool(StageBattle.enemy_def("aswang").get("scripted_death_awaken", false)) and not Dictionary(StageBattle.enemy_def("aswang_finale").get("phase2", {})).is_empty() and not Dictionary(StageBattle.enemy_def("hiraya_hound").get("phase2", {})).is_empty(), "Episode 1 bosses carry scripted awakening and Phase 2+ escalations")


# --- Round 2 of the playtest: transition panels, the rewind clip, the walkable hubs ------------------------------
func _test_walk_and_clips() -> void:
	print("transition panels, panel clips, the walkable 2.5D hubs")
	var story := get_node("/root/Story")
	# Retro JRPG (step 3): the cold open is acted in the flooded parlor. Only its big moments keep a panel (the flood,
	# the rewind, Santa Ana), and the episode as a whole is down to a dozen or so panels.
	var used := {}
	for id in ["co_flood", "co_wave", "co_rewind", "co_downriver"]:
		for st in story.scene(id):
			if String(st.get("panel", "")) != "":
				used[String(st["panel"])] = true
	_check(used.keys().size() == 3 and used.has("ep1_c02_pido_rewind") and Art.panel("ep1_c02_pido_rewind") != null, "the cold open keeps three big panels %s" % [used.keys()])
	var all_panels := {}
	for sid in story._episode.get("scenes", {}):
		for st in story.scene(String(sid)):
			if String(st.get("panel", "")) != "":
				all_panels[String(st["panel"])] = true
	_check(all_panels.size() <= 13, "the episode uses %d comic panels, for the big moments" % all_panels.size())
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
	if d._typing:
		d._advance()
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


# --- Hidalgo Street: scenes acted in the map, and the retro side-view test fight -------------------------------

func _test_stage() -> void:
	print("acted scenes and the stage battle")
	story.reset()
	# The debt scene is acted on Hidalgo Street: Kap Obet walks up, Lola comes out, the choice cuts to the panel.
	var sub := _make_viewport(Vector2i(1280, 720))
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	main.boot_intro = false
	main.test_fast = true
	sub.add_child(main)
	await _frames(2)
	var stage: Dictionary = {}
	for b in main._beats:
		if String(b["beat"].get("id", "")) == "debt_notice":
			stage = b["beat"].get("stage", {})
	_check(stage.get("map", "") == "hidalgo", "the debt scene is staged on Hidalgo Street")
	main._clear()
	main._play("debt_notice", stage)
	await _frames(2)
	var room: ExploreMap = null
	var d: Dialogue = null
	for c in main._layer.get_children():
		if c is ExploreMap:
			room = c
		elif c is Dialogue:
			d = c
	_check(room != null and room.stage_mode and d != null and d.stage == room, "the scene plays over the map, in stage mode")
	if room != null and d != null:
		_check(stage["cast"]["obet"].get("hidden", false) and room._cast.has("obet"), "Kap Obet starts off stage and is cast")
		_check(not d._back.visible, "no comic panel covers the map on an ordinary line")
		await _frames(3)
		_check((room._cast["obet"]["node"] as Sprite3D).visible and (room._cast["obet"]["pos"] as Vector2).distance_to(Vector2(11.9, 3.5)) < 0.1, "the first line walks Kap Obet up to the parlor door (%s)" % [room._cast["obet"]["pos"]])
		var saw_panel := false
		var saw_marker := false
		var f := 0
		while f < 400 and is_instance_valid(d) and d.is_inside_tree():
			f += 1
			await get_tree().process_frame
			if not is_instance_valid(d):
				break
			if room._marker != null and room._marker.visible:
				saw_marker = true
			if d._busy and d._choice_box.visible:
				saw_panel = not d._back.visible # the choice plays over the street now (no panel)
				d._settle_choice(1, false)
			elif not d._busy:
				d._advance()
		_check(saw_panel, "Kap Obet's choice plays on the street, with no panel")
		_check(saw_marker, "a marker shows who is speaking")
	sub.queue_free()
	await _frames(2)

	# The fight: the menu opens on Teo's time bar, the prayer takes arrows, the call can be interrupted.
	sub = _make_viewport(Vector2i(1280, 720))
	var fight := StageBattle.new()
	fight.setup({"enemy": "magbabalot"})
	sub.add_child(fight)
	_check(fight.foe_max == 150 and fight._map != null and fight._map.stage_mode, "the fight is set on the street map")
	fight.party[0].atb = 0.999
	fight.foe_atb = 0.0
	var f2 := 0
	while f2 < 300 and not fight._cmd_panel.visible:
		f2 += 1
		await get_tree().process_frame
	_check(fight._cmd_panel.visible and fight._cmd_box.find_child("Cmd_hatid", true, false) != null, "Teo's time bar opens the command window with HATID")
	var t0 := fight.foe_atb
	await _frames(10)
	_check(fight.foe_atb == t0, "time stops while the menu is open (wait mode)")
	(fight._cmd_box.find_child("Cmd_hatid", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(fight._cmd_box.find_child("Cmd_pray_paalam", true, false) != null, "HATID lists the prayers")
	fight.charging = true # pretend the call is coming
	(fight._cmd_box.find_child("Cmd_pray_paalam", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(fight._seq_active and fight._seq_row.get_child_count() == 3, "PAALAM asks for three arrows")
	for k in ["left", "right", "up"]:
		fight._seq_input(k)
	var f3 := 0
	while f3 < 3000 and fight.interrupts == 0: # the prayer now has a wind-up, a thread of light and a leap
		f3 += 1
		await get_tree().process_frame
	_check(fight.interrupts == 1 and not fight.charging and fight.foe_hp < 150, "the prayer lands, hurts the spirit and drowns out the call (%d hp)" % fight.foe_hp)
	sub.queue_free()
	await _frames(2)
	# A wrong arrow fizzles the prayer.
	sub = _make_viewport(Vector2i(1280, 720))
	fight = StageBattle.new()
	fight.setup({"enemy": "magbabalot"})
	sub.add_child(fight)
	await _frames(2)
	fight._acting = true
	var res := [null]
	var co := func() -> void: res[0] = await fight._sequence(StageBattle.PRAYERS[1])
	co.call()
	fight._seq_input("down")
	await _frames(3)
	_check(res[0] == false, "a wrong arrow fizzles the prayer")
	sub.queue_free()
	await _frames(2)
	# Played through at speed: weaken him, then UWI KA NA sends him home.
	story.reset()
	sub = _make_viewport(Vector2i(1280, 720))
	fight = StageBattle.new()
	fight.fast = true
	fight.setup({"enemy": "magbabalot"})
	sub.add_child(fight)
	var done := [false, false]
	fight.finished.connect(func(w: bool) -> void:
		done[0] = true
		done[1] = w)
	var f4 := 0
	while f4 < 6000 and not done[0]:
		f4 += 1
		await get_tree().process_frame
	_check(done[0] and done[1] and fight.outcome == "sent" and story.flags.get("andoy_sent", false), "the fight ends with Mang Andoy sent home (%s in %d frames)" % [fight.outcome, f4])
	_check(fight.foe_turns >= 3, "the enemy got to use its signature tell (%d turns)" % fight.foe_turns)
	_check(fight.cut_ins >= 2, "special moves play a cut-in (%d)" % fight.cut_ins)
	_check(fight.swift_prayers >= 1, "a quick prayer powers up (SWIFT, %d)" % fight.swift_prayers)
	sub.queue_free()
	story.reset()
	await _frames(2)


# --- Retro JRPG: text boxes with pixel portraits, talks over the map, enemies you can see -----------------------

func _test_retro() -> void:
	var story: Node = get_node("/root/Story")
	story.reset()
	# Every portrait a line asks for is a pixel bust.
	var missing: Array = []
	for sid in story._episode.get("scenes", {}):
		for st in story.scene(String(sid)):
			var pid := String(st.get("portrait", ""))
			if pid != "" and not ResourceLoader.exists("res://assets/portraits_px/%s.png" % pid.trim_prefix("portrait_")):
				if not missing.has(pid):
					missing.append(pid)
	_check(missing.is_empty(), "every speaking portrait is a pixel bust %s" % [missing])
	var hid: Dictionary = {}
	for act in story.flow.get("acts", []):
		for b in act["beats"]:
			if String(b.get("id", "")) == "hidalgo":
				hid = b
	var panels := 0
	for o in hid.get("options", []):
		for st in story.scene(String(o["scene"])):
			if String(st.get("panel", "")) != "":
				panels += 1
	_check(panels == 0, "talks on a walkable map have no backdrop panels (%d)" % panels)
	# Scenes acted on their maps: every map, sprite and pose they use exists, and only big moments keep a panel.
	var maps: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps.json"))
	var staged := 0
	var staged_panels := 0
	var bad: Array = []
	for act in story.flow.get("acts", []):
		for b in act["beats"]:
			var stg: Dictionary = b.get("stage", {})
			if stg.is_empty():
				continue
			staged += 1
			if not maps.has(String(stg.get("map", ""))):
				bad.append("%s: map %s" % [b["id"], stg.get("map", "")])
			var cast: Dictionary = stg.get("cast", {})
			for id in cast:
				if String(id) != "teo" and not ResourceLoader.exists("res://assets/explore/%s.png" % cast[id].get("sprite", id)):
					bad.append("%s: sprite %s" % [b["id"], cast[id].get("sprite", id)])
			for st in story.scene(String(b["id"])):
				if String(st.get("panel", "")) != "":
					staged_panels += 1
				for a in st.get("act", []):
					if a.has("who") and String(a["who"]) != "teo" and not cast.has(String(a["who"])):
						bad.append("%s: nobody called %s" % [b["id"], a["who"]])
					if a.has("sprite") and not ResourceLoader.exists("res://assets/explore/%s.png" % a["sprite"]):
						bad.append("%s: pose %s" % [b["id"], a["sprite"]])
	_check(staged >= 20 and bad.is_empty(), "%d scenes are acted on their maps, with every sprite in place %s" % [staged, bad])
	_check(staged_panels <= staged, "acted scenes keep panels only for big moments (%d panels in %d scenes)" % [staged_panels, staged])
	for mid in ["lola_room", "pumphouse", "morgue"]:
		for p in maps.get(mid, {}).get("props", []):
			if not ResourceLoader.exists("res://assets/explore/%s.png" % p["s"]):
				bad.append("%s: prop %s" % [mid, p["s"]])
	_check(maps.has("lola_room") and maps.has("pumphouse") and bad.is_empty(), "Lola's room, the pump house and the morgue are built from their props %s" % [bad])
	# The text box: speech shows the speaker's bust in a retro window.
	var sub := _make_viewport(Vector2i(1280, 720))
	var d := Dialogue.new()
	sub.add_child(d)
	d.play([{"kind": "say", "speaker": "Mang Isko", "portrait": "portrait_isko", "text": "Balut!"}])
	await _frames(2)
	_check(d._say_bar.visible and d._say_portrait.texture != null and d._say_portrait.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "speech shows a pixel portrait in the retro window")
	sub.queue_free()
	# A talk in a hub plays on the map where it happens.
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	main.set("_room_pos", Vector2(8.0, 4.4))
	var st0: Dictionary = main._hub_stage(hid, 0)
	_check(st0.get("map", "") == "hidalgo" and st0["cast"].has("teo") and st0["cast"].has("o0") and not st0["cast"].has("o3"), "talking to Mang Isko is staged on the street with everyone in place")
	var st3: Dictionary = main._hub_stage(hid, 3)
	_check(st3["cast"].has("foe"), "walking into Mang Andoy stages him in front of Teo")
	main.free()
	# Mang Andoy drifts under the balete; he has no tag; walking into him starts the fight.
	sub = _make_viewport(Vector2i(1280, 720))
	var room := ExploreMap.new()
	room.test_fast = true
	room.setup(hid, {}, 1, Vector2(4.0, 6.0))
	sub.add_child(room)
	await _frames(2)
	var tag3: Button = room.find_child("Hub_3", true, false)
	_check(room.find_child("Roamer_3", true, false) != null and tag3 != null and not tag3.visible, "Mang Andoy is on the map, with no name tag")
	var got := [-9]
	room.picked.connect(func(i: int) -> void: got[0] = i)
	await _frames(10)
	_check(got[0] == -9, "far away, nothing happens")
	room.teo_pos = room.roamer_pos(3) + Vector2(1.5, 0.4)
	var f := 0
	while f < 400 and got[0] == -9:
		f += 1
		await get_tree().process_frame
	_check(got[0] == 3, "close by, he comes for Teo and the fight starts (%d after %d frames)" % [got[0], f])
	sub.queue_free()
	story.reset()
	await _frames(2)


# --- Every Episode 1 fight as a retro side-view battle --------------------------------------------------------------

func _play_stage(def: Dictionary) -> StageBattle:
	var sub := _make_viewport(Vector2i(1280, 720))
	var fight := StageBattle.new()
	fight.fast = true
	fight.setup(def)
	for k in ["auto_charge", "auto_rhythm"]:
		if def.has(k):
			fight.set(k, float(def[k]))
	if def.has("test_miss"):
		fight.test_miss = int(def["test_miss"])
	if def.has("auto_react"):
		fight.auto_react = float(def["auto_react"]) > 0.0
	sub.add_child(fight)
	var done := [false]
	fight.finished.connect(func(_w: bool) -> void: done[0] = true)
	var f := 0
	while f < 9000 and not done[0]:
		f += 1
		await get_tree().process_frame
	fight.set_meta("frames", f)
	fight.set_meta("done", done[0])
	sub.queue_free.call_deferred()
	return fight


## Step 4: a special for everyone, each with its own input (SpecialGauge).
func _test_specials() -> void:
	print("specials: KONTRA, ORASYON, REWIND, HATID II")
	var story: Node = get_node("/root/Story")
	_check(SpecialGauge.zone(0.3) == "weak" and SpecialGauge.zone(0.7) == "clean" and SpecialGauge.zone(0.95) == "over", "KONTRA's gauge: weak, clean (green), over (red)")
	for id in ["lolab_ready", "lolab_slash", "lolab_pray", "lolab_burst", "lolab_guard", "lolab_hurt", "lolab_down", "lolab_win", "kardob_charge", "kardob_shock", "pidob_wind", "teob_aura"]:
		_check(ResourceLoader.exists("res://assets/explore/%s.png" % id), "special pose %s is drawn" % id)
	# The gauge played by hand: hold, let go in the green; wind the crown; keep the beat.
	var sub := _make_viewport(Vector2i(1280, 720))
	var g := SpecialGauge.new()
	sub.add_child(g)
	var got := [{}]
	g.finished.connect(func(r: Dictionary) -> void: got[0] = r)
	g.start("charge", "KONTRA", "", Color.CYAN)
	g._press(true)
	g._process(SpecialGauge.CHARGE_SECS * 0.72)
	g._press(false)
	await _frames(2)
	_check(String(got[0].get("zone", "")) == "clean", "KONTRA: held to about 72%% and let go is a clean circuit (%s)" % got[0])
	g.start("charge", "KONTRA", "", Color.CYAN)
	g._press(true)
	for i in 12:
		g._process(0.2)
	await _frames(2)
	_check(bool(got[0].get("tripped", false)), "KONTRA: held at the top too long, the breaker trips")
	g.start("wind", "REWIND", "", Color.CYAN)
	for i in 4:
		g._press(true)
	g._process(SpecialGauge.WIND_SECS + 0.1)
	await _frames(2)
	_check(is_equal_approx(float(got[0].get("value", 0.0)), 0.4), "REWIND: four turns of the crown wind it back 40%% (%s)" % got[0])
	g.start("rhythm", "ORASYON", "", Color.GOLD)
	var n0: float = g.notes[0]["at"]
	g._process(n0)
	g._press(true) # dead on the first bead
	g._process(float(g.notes[1]["at"]) - n0 + 0.12)
	g._press(true) # a little late on the second
	g._process(5.0) # and lets the rest go by
	await _frames(2)
	_check(int(got[0].get("perfect", 0)) == 1 and int(got[0].get("good", 0)) == 1 and float(got[0].get("value", 1.0)) < 0.4, "ORASYON: one perfect, one good, the rest missed (%s)" % got[0])
	sub.queue_free()
	# Kardo overcharges: more damage, and the shock comes back up the wire (it never drops him).
	story.reset()
	story.flags["watch_awake"] = true
	var hot := await _play_stage({"enemy": "hiraya_hound", "party": ["teo", "kardo"], "auto_charge": 0.95})
	_check(hot.get_meta("done") and hot.overcharges >= 1 and hot.unit("kardo").hp >= 1, "KONTRA overcharged: Kardo takes the shock and keeps fighting (%d)" % hot.overcharges)
	_check(hot.heat_peak >= 1, "KONTRA heats the line: the red comes sooner next time (heat %d)" % hot.heat_peak)
	# REWIND is a reaction: a missed parry lands, the watch offers to take it back, the same ring comes again.
	story.reset()
	var w := await _play_stage({"enemy": "lunod", "party": ["pido"], "test_miss": 1})
	_check(w.get_meta("done") and w.rewinds == 1 and story.utang == 0, "1998: Pido misses a parry and takes the blow back (rewinds %d, no utang for Teo)" % w.rewinds)
	_check(w.unit("pido").d["cmds"].find("watch") == -1, "REWIND is no longer a menu command")
	story.reset()
	var nw := await _play_stage({"enemy": "lunod", "party": ["pido"], "test_miss": 1, "auto_react": 0.0})
	_check(nw.get_meta("done") and nw.rewinds == 0 and story.misses >= 1, "let the light run out and the blow stands")
	story.reset()
	var w0 := await _play_stage({"enemy": "unsent"})
	_check(w0.rewinds == 0 and w0.watch_charge == 0, "before the watch wakes, Teo has no REWIND")
	story.reset()
	story.flags["watch_awake"] = true
	var tw := await _play_stage({"enemy": "unsent", "test_miss": 1})
	_check(tw.get_meta("done") and tw.rewinds == 1 and story.utang == 1, "Teo's REWIND takes a blow back and writes it down: +1 utang (%d)" % story.utang)
	# Candles: prayers burn them, one a fight's worth lit fresh.
	story.reset()
	var cx := StageBattle.new()
	cx.setup({"enemy": "magbabalot"})
	_check(cx.candles == 4 and cx._can_pray("tawid") and cx._candle_cost("tawid") == 2, "Teo brings four candles; TAWID burns two")
	cx.candles = 1
	_check(cx._can_pray("paalam") and not cx._can_pray("tawid"), "with one candle left, only the short prayers")
	cx.candles = 0
	_check(not cx._usable(cx.unit("teo"), "hatid"), "no candles: no HATID")
	cx.free()
	# Utang na loob: sending a soul home earns it; Teo's TAWAG (from Episode 2, the heartwood) spends it.
	story.reset()
	story.flags["heartwood_read"] = true
	story.gratitude = 1
	var call := await _play_stage({"enemy": "magbabalot"})
	_check(call.get_meta("done") and call.summons == 1, "Teo speaks a name from the heartwood: Lolo Pido answers (TAWAG)")
	_check(story.gratitude == (1 if call.outcome == "sent" else 0), "TAWAG spends one utang na loob; sending Mang Andoy home earns one back (%d, %s)" % [story.gratitude, call.outcome])
	story.reset()
	# HATID II: locked for Teo until his Loob is high enough; Pido always knows it.
	story.loob = 0
	var px := StageBattle.new()
	px.setup({"enemy": "lunod", "party": ["pido"]})
	_check(px.hatid2(px.unit("pido")) and px.candles == 5, "Lolo Pido knows TAWID (HATID II) and brings five candles")
	px.free()
	var tx := StageBattle.new()
	tx.setup({"enemy": "magbabalot"})
	_check(not tx.hatid2(tx.unit("teo")), "Teo's HATID II is locked at Loob 0")
	story.loob = StageBattle.HATID2_LOOB
	_check(tx.hatid2(tx.unit("teo")), "and opens at Loob %d" % StageBattle.HATID2_LOOB)
	tx.free()
	story.reset()
	# TAWID sends a spirit home from above the gold line.
	story.loob = StageBattle.HATID2_LOOB
	var mb := await _play_stage({"enemy": "magbabalot"})
	_check(mb.get_meta("done") and mb.outcome == "sent", "with HATID II, Mang Andoy is sent home (%s)" % mb.outcome)
	_check(story.gratitude == 1, "and the dead remember it: utang na loob +1 (%d)" % story.gratitude)
	# Levels: the end of a case adds a level and the upgrade picked; the next episode's fights carry them.
	var saved_done: Array = Progress.episodes_done.duplicate()
	var saved_perks: Dictionary = Progress.perks.duplicate(true)
	Progress.episodes_done = [1]
	Progress.perks = {"1": {"teo": "tibay", "kardo": "kawad"}}
	_check(Levels.level("teo", 1) == 1 and Levels.level("teo", 2) == 2, "Teo fights Episode 1 at level 1, Episode 2 at level 2")
	var lv := StageBattle.new()
	lv.setup({"enemy": "hiraya_hound", "party": ["teo", "kardo"], "episode": 2})
	_check(lv.unit("teo").max_hp == 110 + 12 + 15 and lv.unit("teo").d["hit"][0] == 12, "level 2 + TIBAY: Teo has %d HP (137) and hits harder" % lv.unit("teo").max_hp)
	_check(lv._max_wires() == 4, "DAGDAG KAWAD: Kardo can clamp a fourth wire")
	lv.free()
	var lv1 := StageBattle.new()
	lv1.setup({"enemy": "hiraya_hound", "party": ["teo", "kardo"]})
	_check(lv1.unit("teo").max_hp == 110 and lv1._max_wires() == 3, "replaying Episode 1 plays the same")
	lv1.free()
	Progress.episodes_done = saved_done
	Progress.perks = saved_perks
	story.reset()
	await _frames(2)


func _test_stage_fights() -> void:
	print("every Episode 1 fight as a retro side-view battle")
	var story: Node = get_node("/root/Story")
	var flow_enemies: Array = []
	for act in story.flow.get("acts", []):
		for b in act["beats"]:
			if String(b.get("type", "")) == "fight":
				flow_enemies.append(String(b["enemy"]))
	for e in flow_enemies:
		var d := StageBattle.enemy_def(e)
		_check(not d.is_empty(), "fight '%s' has a side-view battle" % e)
		var missing: Array = []
		for pose in ["idle", "idle_b", "tell", "wail", "claw", "hurt", "calm", "fade"]:
			if not ResourceLoader.exists("res://assets/explore/%s_%s.png" % [d.get("art", ""), pose]):
				missing.append(pose)
		_check(missing.is_empty(), "%s has every battle pose %s" % [e, missing])
		_check(not ExploreMap.map_def(String(d.get("map", ""))).get("battle", {}).is_empty(), "%s is fought on a map with battle positions (%s)" % [e, d.get("map", "")])
	for id in StageBattle.MEMBERS:
		var art := String(StageBattle.MEMBERS[id]["art"])
		var miss: Array = []
		for pose in ["ready", "slash", "pray", "burst", "guard", "hurt", "down", "win"]:
			if not ResourceLoader.exists("res://assets/explore/%s_%s.png" % [art, pose]):
				miss.append(pose)
		_check(miss.is_empty(), "%s has every battle pose %s" % [id, miss])
	# 1998: Lolo Pido alone, the wounds carry from wave to wave, and the tide can only be outlasted.
	story.reset()
	var w1 := await _play_stage({"enemy": "lunod", "party": ["pido"], "carry_wounds": true})
	_check(w1.get_meta("done") and w1.outcome == "scattered" and w1.party[0].id == "pido", "Lolo Pido beats the first wave of the drowned (%s)" % w1.outcome)
	var hurt := int(story.injury)
	_check(hurt == w1.party[0].max_hp - w1.party[0].hp, "his wounds carry into the next wave (%d)" % hurt)
	var tide := await _play_stage({"enemy": "lunod_tide", "party": ["pido"]})
	_check(tide.get_meta("done") and tide.outcome == "outlasted" and tide.foe_hp >= 1 and tide.foe_turns == 3, "the tide cannot be beaten, only outlasted for three turns (%s, %d turns)" % [tide.outcome, tide.foe_turns])
	story.reset()
	var berto := await _play_stage({"enemy": "ligaw_berto"})
	_check(berto.get_meta("done") and berto.outcome == "scattered" and berto.cut_ins >= 1, "Mang Berto's hunger is cut out of him (%s)" % berto.outcome)
	_check(berto.unit("ising") != null and berto.orasyons >= 1, "Lola Ising fights beside Teo at the wake, and prays ORASYON (%d)" % berto.orasyons)
	_check(berto.tired_turns >= 1, "ORASYON tires her: she sits a turn out (%d)" % berto.tired_turns)
	_check(berto.summons == 1, "Lola calls on the sundô before her, once (TAWAG: %d)" % berto.summons)
	var unsent := await _play_stage({"enemy": "unsent"})
	_check(unsent.get_meta("done") and unsent.outcome == "scattered", "the creek's unsent are held off")
	# The aswang kills Teo to wake the watch, then flees once driven down to half health, returning for the parlor finale.
	story.reset()
	var asw := await _play_stage({"enemy": "aswang"})
	_check(asw.get_meta("done") and asw.awakened and story.flags.get("watch_awake", false) and story.utang >= 2, "the aswang fight wakes the watch (+%d utang)" % story.utang)
	_check(asw.outcome == "fled" and story.flags.get("aswang_escaped", false), "the wounded aswang flees over the roofs instead of dying (%s)" % asw.outcome)
	# The hound: Teo and Kardo; Kardo's wires and discharge.
	story.flags["watch_awake"] = true
	var hound := await _play_stage({"enemy": "hiraya_hound", "party": ["teo", "kardo"]})
	_check(hound.get_meta("done") and hound.outcome == "scattered" and hound.party.size() == 2, "Teo and Kardo take the hound down together")
	_check(hound.unit("kardo") != null and hound.cut_ins >= 1, "Kardo discharged his wires (a cut-in played)")
	# The parlor finale: Teo and Kardo finish the scarred/overclocked aswang for good.
	story.gratitude = 1
	var asw_fin := await _play_stage({"enemy": "aswang_finale", "party": ["teo", "kardo"]})
	_check(asw_fin.get_meta("done") and asw_fin.outcome == "scattered", "Teo and Kardo put down the unchained aswang in the parlor finale (%s)" % asw_fin.outcome)
	story.reset()
	await _frames(2)


func _test_aaa_phase2_and_combos() -> void:
	print("AAA polish: team combos, 2-phase bosses, REWIND? box, blank-choice guard")
	var story: Node = get_node("/root/Story")
	# 1. REWIND? react gauge sits off-center above the party HUD.
	_check(SpecialGauge.REACT_BOX.position.x > SpecialGauge.BOX.position.x and SpecialGauge.REACT_BOX.position.y > SpecialGauge.BOX.position.y, "REWIND? react box sits off-center, clear of center action")
	# 2. Blank decision card guard in Dialogue.
	var dlg := Dialogue.new()
	get_tree().root.add_child(dlg)
	dlg.play([{"kind": "narr", "speaker": "", "text": "Test", "choice": {"id": "c_blank", "seconds": 0, "options": ["   ", "Real option"]}}])
	_check(dlg._choice_box.get_child_count() >= 2, "Dialogue builds choice buttons without leaving blank cards")
	var first_btn := dlg._choice_box.get_child(0) as Button
	_check(first_btn != null and not first_btn.text.strip_edges().is_empty(), "whitespace option gets non-empty fallback text")
	dlg.queue_free()
	# 3. Team Combo: Teo + Kardo (Hatid sa Kuryente) & Boss Phase 2 on Hiraya Hound.
	story.reset()
	story.gratitude = 1
	var hound := await _play_stage({"enemy": "hiraya_hound", "party": ["teo", "kardo"]})
	_check(hound.get_meta("done") and hound.outcome == "scattered", "Hiraya Hound defeated with Phase 2 + Team Combo")
	_check(hound._phase2, "Hiraya Hound entered Phase II")
	_check(hound.combos_used >= 1 and story.gratitude == 0, "Teo + Kardo used Hatid sa Kuryente and spent 1 utang na loob (%d)" % hound.combos_used)
	_check(hound.dual_cut_ins >= 1, "Hatid sa Kuryente triggered a dual-portrait cut-in (%d)" % hound.dual_cut_ins)
	# 4. Team Combo: Teo + Lola (Dasal ng Dalawa) & Boss Phase 2 on Mang Berto.
	story.reset()
	story.gratitude = 1
	var berto := await _play_stage({"enemy": "ligaw_berto", "party": ["teo", "ising"]})
	_check(berto.get_meta("done") and berto.outcome == "scattered", "Mang Berto defeated with Phase 2 + Team Combo")
	_check(berto._phase2, "Mang Berto entered Phase II")
	_check(berto.combos_used >= 1, "Teo + Lola used Dasal ng Dalawa (%d)" % berto.combos_used)
	_check(berto.dual_cut_ins >= 1, "Dasal ng Dalawa triggered a dual-portrait cut-in (%d)" % berto.dual_cut_ins)
	# 5. FF7-style ExploreMap animations & emotes.
	var st_sub := _make_viewport(Vector2i(1280, 720))
	var st_map := ExploreMap.new()
	st_map.stage_mode = true
	st_map.test_fast = true
	var morgue_stage := {"map": "morgue", "focus": [5.6, 3.6], "cast": {
		"teo": {"at": [4.6, 3.9], "face": "right"},
		"kardo": {"sprite": "kardo", "at": [6.3, 4.3], "h": 1.8, "name": "Kardo", "flip": true}}}
	st_map.setup({"map": "morgue"}, {}, 0, Vector2(-1, -1))
	st_sub.add_child(st_map)
	await _frames(2)
	st_map.set_stage(morgue_stage)
	st_map.act([{"who": "teo", "anim": "hop", "emote": "!"}, {"who": "kardo", "anim": "shake", "emote": "sweat"}])
	await _frames(2)
	var em_teo := st_map.find_child("Emote_teo", true, false) as Label
	var em_kardo := st_map.find_child("Emote_kardo", true, false) as Label
	_check(st_map._anims.has("teo") and st_map._anims.has("kardo"), "ExploreMap triggers hop/shake animations on stage actors")
	_check(em_teo != null and em_teo.text == "!" and em_kardo != null and em_kardo.text == ";;", "ExploreMap spawns FF7 pop-up emote labels")
	st_map.act([{"who": "teo", "emote": "clear"}])
	_check(not st_map._emotes.has("teo"), "emote 'clear' removes an active emote immediately")
	st_map._tick_anims(2.0)
	_check(st_map._anims.is_empty() and st_map._emotes.is_empty(), "stage animations and emotes expire cleanly")
	st_sub.queue_free()
	# 6. Per-speaker 16-bit text blips + 16-bit UI & emote SFX.
	var wav := Sfx._make_blip(Sfx._speaker_pitch("Teo"), 0.03)
	_check(Sfx._speaker_pitch("Teo") != Sfx._speaker_pitch("Kardo"), "Sfx assigns distinct blip pitches per speaker")
	_check(wav != null and wav.format == AudioStreamWAV.FORMAT_16_BITS and wav.data.size() > 0, "Sfx synthesizes 16-bit AudioStreamWAV dialogue blips")
	Sfx.blip("Teo")
	var w_move := Sfx.ui_move()
	var w_conf := Sfx.ui_confirm()
	_check(w_move != null and w_move.format == AudioStreamWAV.FORMAT_16_BITS and w_move.data.size() > 0, "Sfx synthesizes 16-bit UI cursor move SFX")
	_check(w_conf != null and w_conf.format == AudioStreamWAV.FORMAT_16_BITS and w_conf.data.size() > 0, "Sfx synthesizes 16-bit UI confirm SFX")
	for ek in ["!", "?", "sweat", "..."]:
		var ew := Sfx.emote(ek)
		_check(ew != null and ew.format == AudioStreamWAV.FORMAT_16_BITS and ew.data.size() > 0, "Sfx synthesizes 16-bit emote SFX for '%s'" % ek)
	# 7. Mobile timing forgiveness & utang na loob Team Combo label clarity.
	_check(is_equal_approx(SpecialGauge.GOOD_WIN, 0.20) and is_equal_approx(SpecialGauge.REACT_SECS, 1.85) and is_equal_approx(SpecialGauge.REACT_HOLD, 0.30), "SpecialGauge mobile timings tuned (GOOD_WIN 0.20, REACT 1.85/0.30)")
	story.reset()
	story.gratitude = 1
	var csub := _make_viewport(LOGICAL)
	var cfight := StageBattle.new()
	cfight.setup({"enemy": "hiraya_hound", "party": ["teo", "kardo"]})
	csub.add_child(cfight)
	await _frames(2)
	cfight._show_menu(cfight.unit("teo"), "main")
	var combo_btn := cfight._cmd_box.find_child("Cmd_combo", true, false) as Button
	_check(combo_btn != null and combo_btn.text.contains("utang na loob"), "Team Combo button clarifies 'utang na loob' vs HATID II 'Loob' (%s)" % [combo_btn.text if combo_btn else "missing"])
	cfight._show_menu(cfight.unit("teo"), "combo")
	await _frames(2)
	var k_combo := cfight._cmd_box.find_child("Cmd_combo_kuryente", true, false) as Button
	_check(k_combo != null and k_combo.text.contains("1 utang na loob"), "Hatid sa Kuryente lists '1 utang na loob'")
	_check_inside(cfight, "StageBattle combo submenu")
	csub.queue_free()
	# 8. Title screen key art, breathing tween cleanup & Chapter & Fight Select transition.
	Story.clear_run()
	var tsub := _make_viewport(LOGICAL)
	var tmain: Control = load("res://scenes/Main.tscn").instantiate()
	tmain.boot_intro = false
	tsub.add_child(tmain)
	await _frames(3)
	var tart := tmain.find_child("TitleArt", true, false) as TextureRect
	var cbtn := tmain.find_child("ChapterButton", true, false) as Button
	var sbtn := tmain.find_child("StartButton", true, false) as Button
	_check(tart != null and tart.texture != null, "title screen loads bespoke Quiapo balete key art")
	_check(tmain._title_breath != null and tmain._title_breath.is_valid(), "title key-art breathing tween is active")
	_check(cbtn != null and cbtn.is_visible_in_tree(), "title screen has Chapter & Fight Select button")
	_check_inside(tmain, "new title layout")
	cbtn.pressed.emit()
	await _frames(2)
	var coverlay := tmain.find_child("ChapterOverlay", true, false)
	var cback := tmain.find_child("ChapterBackButton", true, false) as Button
	_check(coverlay != null and coverlay.is_visible_in_tree(), "Chapter & Fight Select opens cleanly")
	_check_inside(tmain, "chapter select modal")
	cback.pressed.emit()
	await _frames(2)
	_check(tmain.find_child("ChapterOverlay", true, false) == null, "Chapter & Fight Select closes cleanly")
	sbtn.pressed.emit()
	await _frames(4)
	_check(tmain._running and tmain._title_breath == null, "START kills the breathing tween cleanly and begins the episode")
	tsub.queue_free()

	# 9. New 16-bit stingers (watch tick, phase shift, sent home).
	for s_name in ["watch_tick", "phase_shift", "sent_home"]:
		var sw: AudioStreamWAV = Sfx.call(s_name)
		_check(sw != null and sw.format == AudioStreamWAV.FORMAT_16_BITS and sw.data.size() > 0, "Sfx synthesizes 16-bit '%s' stinger" % s_name)

	# 10. Dynamic battle camera focus/reset, Kardo wire chip-jolt, amulet wiring, and live utang HUD.
	var prev_amulets: Array = Progress.amulets.duplicate()
	var prev_equipped: String = Progress.equipped
	Progress.amulets = ["buhok_tikbalang", "tanikala"]
	Progress.equip("buhok_tikbalang")
	story.reset()
	story.flags["bearer_teo"] = true
	story.add_utang(2)
	var afight := StageBattle.new()
	afight.fast = true
	afight.setup({"enemy": "hiraya_hound", "party": ["teo", "kardo"]})
	var asub := _make_viewport(LOGICAL)
	asub.add_child(afight)
	await _frames(2)
	_check(afight.unit("teo").max_hp == 99 and is_equal_approx(float(afight._amulet.get("parry_zone", 0.0)), 0.06), "StageBattle applies equipped Buhok ng Tikbalang amulet (max_hp 99, parry_zone +0.06)")
	_check(afight._res_label.text.contains("UTANG 2") and afight._res_label.text.contains("WHITE STREAK"), "StageBattle HUD shows live utang and white streak pressure (%s)" % afight._res_label.text)
	afight._map.battle_cam_focus(Vector2(9.2, 6.7), 26.5, 0.5)
	await _frames(2)
	_check(is_equal_approx(afight._map._battle_fov, 26.5) and afight._map._battle_weight > 0.4, "ExploreMap battle_cam_focus shifts camera weight and FOV")
	afight._map.battle_cam_reset()
	_check(is_equal_approx(afight._map._battle_fov, 30.0) and afight._map._battle_weight == 0.0, "ExploreMap battle_cam_reset restores framing")
	afight.wired = 2
	afight._acting = true
	await afight._foe_turn()
	_check(afight.wire_jolts == 1 and afight.foe_hp == 186, "Kardo's clamped wires deal micro-jolt chip damage on enemy turns (jolts %d, foe_hp %d)" % [afight.wire_jolts, afight.foe_hp])
	asub.queue_free()

	Progress.amulets = prev_amulets
	Progress.equipped = prev_equipped
	Progress.save_game()
	story.reset()
	await _frames(2)


func _test_bystanders_reactivity_and_transit() -> void:
	print("battle bystanders, decision reactivity, walkable transit corridors & chapter select")
	var story: Node = get_node("/root/Story")
	# 1. Battle bystanders: conditional spawning, reactions, and bounded Bark_<id> overlays.
	story.reset()
	var bf1 := await _play_stage({"enemy": "magbabalot"})
	_check(bf1.get_meta("done") and bf1.bystander_reactions >= 2, "magbabalot fight triggers bystander reactions (%d)" % bf1.bystander_reactions)
	_check(bf1._has_bystander("nonoy") and not bf1._has_bystander("domeng"), "Hidalgo battle includes Nonoy when not warned")
	_check(bf1._has_bystander("isko") and bf1._has_bystander("rudy"), "Hidalgo battle includes Mang Isko and Rudy as onlookers")

	story.reset()
	story.flags["nonoy_warned"] = true
	story.flags["heard_isko"] = true
	var sub := _make_viewport(LOGICAL)
	var bf2 := StageBattle.new()
	bf2.setup({"enemy": "magbabalot"})
	sub.add_child(bf2)
	await _frames(2)
	_check(bf2._has_bystander("domeng") and not bf2._has_bystander("nonoy"), "when Nonoy was warned, Mang Domeng stands on Hidalgo instead")
	var open_bark := bf2._bystander_bark_for("opening")
	_check(String(open_bark.get("text", "")).contains("Hold your ground"), "Isko opening battle bark reflects heard_isko")
	bf2._react_bystanders("cheer", true)
	await _frames(2)
	var rudy_bark := bf2._map.find_child("Bark_rudy", true, false) as PanelContainer
	_check(rudy_bark != null and rudy_bark.visible, "bystander_bark creates visible Bark_rudy pill on cheer")
	if rudy_bark != null:
		var r := Rect2(rudy_bark.position, rudy_bark.size)
		_check(Rect2(Vector2.ZERO, LOGICAL).encloses(r), "Bark_rudy stays inside viewport %s" % r)
	sub.queue_free()
	await _frames(2)

	story.reset()
	story.flags["van_schedule"] = true
	sub = _make_viewport(LOGICAL)
	var bf3 := StageBattle.new()
	bf3.fast = true
	bf3.setup({"enemy": "aswang"})
	sub.add_child(bf3)
	await _frames(2)
	_check(bf3._has_bystander("tess") and bf3._has_bystander("celso") and not bf3._has_bystander("guard"), "aswang battle omits guard when van_schedule already sent him off")
	sub.queue_free()

	story.reset()
	sub = _make_viewport(LOGICAL)
	var bf4 := StageBattle.new()
	bf4.fast = true
	bf4.setup({"enemy": "aswang"})
	sub.add_child(bf4)
	await _frames(2)
	_check(bf4._has_bystander("guard"), "aswang battle includes Hiraya guard when van_schedule is false")
	sub.queue_free()

	story.reset()
	sub = _make_viewport(LOGICAL)
	var bf5 := StageBattle.new()
	bf5.fast = true
	bf5.setup({"enemy": "lunod", "party": ["pido"]})
	sub.add_child(bf5)
	await _frames(2)
	_check(bf5._has_bystander("y_ising") and bf5._has_bystander("y_kardo"), "1998 flood battle shows young Ising and Kardo watching from the stairs")
	sub.queue_free()
	await _frames(2)

	# 2. Story reactivity: has_white_streak, loob_min / bond_min, conditional scene steps & hub murmurs.
	story.reset()
	story.flags["bearer_teo"] = true
	story.add_utang(2)
	_check(story.age_stage() >= 1 and story.flags.get("has_white_streak", false), "borrowed time >= stage 1 sets has_white_streak automatically")
	_check(not story.cond_ok({"loob_min": 2}) and not story.cond_ok({"bond_min": {"kardo": 1}}), "cond_ok rejects unmet loob_min / bond_min")
	story.loob = 2
	story.bonds["kardo"] = 1
	_check(story.cond_ok({"loob_min": 2}) and story.cond_ok({"bond_min": {"kardo": 1}}), "cond_ok accepts met loob_min / bond_min")

	story.reset()
	var celso_plain := 0
	for st in story.scene("hub2_celso"):
		if story.cond_ok(st):
			celso_plain += 1
	story.flags["obet_out"] = true
	var celso_react := 0
	for st in story.scene("hub2_celso"):
		if story.cond_ok(st):
			celso_react += 1
	_check(celso_react > celso_plain, "hub2_celso adds reactive dialogue when obet_out is set (%d > %d)" % [celso_react, celso_plain])

	story.reset()
	var offer_plain := 0
	for st in story.scene("the_offer"):
		if story.cond_ok(st):
			offer_plain += 1
	story.flags["heard_tess"] = true
	story.flags["obet_permit"] = true
	var offer_react := 0
	for st in story.scene("the_offer"):
		if story.cond_ok(st):
			offer_react += 1
	_check(offer_react > offer_plain, "the_offer adds reactive lines for heard_tess & obet_permit (%d > %d)" % [offer_react, offer_plain])

	var hidalgo_beat: Dictionary = {}
	var qa_beat: Dictionary = {}
	var sa_beat: Dictionary = {}
	for act in story.flow.get("acts", []):
		for b in act["beats"]:
			var bid := String(b.get("id", ""))
			if bid == "hidalgo":
				hidalgo_beat = b
			elif bid == "quiapo_alley":
				qa_beat = b
			elif bid == "service_alley":
				sa_beat = b
	_check(not qa_beat.is_empty() and String(qa_beat.get("type", "")) == "transit", "quiapo_alley transit beat present in flow")
	_check(not sa_beat.is_empty() and String(sa_beat.get("type", "")) == "transit", "service_alley transit beat present in flow")

	# Hub proximity murmurs fire cleanly without blocking Teo's movement.
	story.reset()
	sub = _make_viewport(LOGICAL)
	var hmap := ExploreMap.new()
	hmap.setup(hidalgo_beat, {}, 1, Vector2(6.5, 3.3))
	sub.add_child(hmap)
	await _frames(2)
	hmap._check_ambient_banter(1.0)
	await _frames(2)
	_check(hmap._murmurs_done.has(0) and hmap.find_child("Bark_o0", true, false) != null, "walking near Mang Isko in Hidalgo hub triggers ambient murmur Bark_o0")
	var pos_before := hmap.teo_pos
	_check(hmap._move(Vector2(0.25, 0.0)) > 0.1 and hmap.teo_pos.x > pos_before.x, "hub murmur does not block Teo's movement")
	sub.queue_free()
	await _frames(2)

	# 3. Walkable transit corridors: assets exist, zones fire, companion follows, exit beacon auto-transitions.
	for tb in [qa_beat, sa_beat]:
		var mid := String(tb.get("map", ""))
		var mdef := ExploreMap.map_def(mid)
		_check(not mdef.is_empty(), "transit map '%s' defined in maps.json" % mid)
		var miss_art: Array = []
		for p in mdef.get("props", []):
			if not ResourceLoader.exists("res://assets/explore/%s.png" % p["s"]):
				miss_art.append(String(p["s"]))
		if tb.has("companion"):
			var cspr := String(tb["companion"].get("sprite", ""))
			if not ResourceLoader.exists("res://assets/explore/%s.png" % cspr):
				miss_art.append(cspr)
		_check(miss_art.is_empty(), "transit '%s' prop & companion textures exist %s" % [mid, miss_art])
		for o in tb.get("options", []):
			var os: Array = story.scene(String(o.get("scene", "")))
			_check(not os.is_empty(), "transit inspect scene '%s' exists" % o.get("scene", ""))
			for st in os:
				_check(String(st.get("panel", "")) == "", "transit inspect scene '%s' stays on map (no panel)" % o.get("scene", ""))

	story.reset()
	story.flags["salt_door"] = true
	sub = _make_viewport(LOGICAL)
	var qa := ExploreMap.new()
	qa.setup(qa_beat, {}, 0, Vector2(-1, -1))
	sub.add_child(qa)
	await _frames(2)
	var qa_go := qa.find_child("HubGo", true, false) as Button
	_check(qa.transit_mode and qa_go != null and not qa_go.disabled, "quiapo_alley transit starts with exit unlocked (need: 0)")
	_check(qa.find_child("TransitExitBeacon", true, false) != null, "quiapo_alley spawns TransitExitBeacon")
	qa.teo_pos = Vector2(3.6, 4.4)
	qa._check_ambient_banter(0.1)
	await _frames(2)
	_check(qa.find_child("Bark_teo", true, false) != null, "quiapo_alley triggers Teo zone banter Bark_teo as he walks past x")
	sub.queue_free()
	await _frames(2)

	story.reset()
	story.flags["has_tag"] = true
	story.flags["went_home"] = true
	sub = _make_viewport(LOGICAL)
	var sa := ExploreMap.new()
	sa.setup(sa_beat, {}, 0, Vector2(-1, -1))
	sub.add_child(sa)
	await _frames(2)
	var comp := sa.find_child("Companion_kardo", true, false) as Sprite3D
	_check(comp != null, "service_alley spawns Companion_kardo")
	var k0 := sa._companion_pos
	_check(sa.teo_pos.distance_to(k0) >= 0.7, "Kardo starts trailing behind Teo (dist %.2f)" % sa.teo_pos.distance_to(k0))
	Input.action_press("ui_right")
	var wf := 0
	while sa.teo_pos.x < 3.8 and wf < 300:
		wf += 1
		await get_tree().process_frame
	Input.action_release("ui_right")
	await _frames(2)
	_check(sa.teo_pos.x >= 3.8 and sa._companion_pos.x > k0.x + 1.0, "Companion_kardo follows Teo forward along service_alley (%.2f -> %.2f)" % [k0.x, sa._companion_pos.x])
	_check(sa.find_child("Bark_kardo", true, false) != null or sa._zones_done.has(0), "service_alley zone banter triggers as party walks")
	var exited := [-9]
	sa.picked.connect(func(idx: int) -> void: exited[0] = idx)
	sa._walked_dist = 3.0
	sa.teo_pos = sa._exit_point() + Vector2(-0.6, 0.0)
	await _frames(3)
	_check(exited[0] == -1, "walking into service_alley TransitExitBeacon auto-exits cleanly (%d)" % exited[0])
	sub.queue_free()
	await _frames(2)

	# 4. Dynamic Chapter Select resolves shifted indices accurately after transit insertion.
	var csub := _make_viewport(LOGICAL)
	var cmain: Control = load("res://scenes/Main.tscn").instantiate()
	cmain.boot_intro = false
	csub.add_child(cmain)
	await _frames(2)
	var b_act1: int = cmain._find_beat_idx("act_card", "chapter", 1)
	var b_ghost: int = cmain._find_beat_idx("scene", "id", "berto_ghost")
	var b_act2: int = cmain._find_beat_idx("act_card", "chapter", 2)
	var b_act3: int = cmain._find_beat_idx("act_card", "chapter", 4)
	_check(b_act1 > 0 and b_ghost > b_act1 and b_act2 > b_ghost and b_act3 > b_act2, "Main._find_beat_idx resolves ordered chapter jump indices (%d, %d, %d, %d)" % [b_act1, b_ghost, b_act2, b_act3])
	_check(String(cmain._beats[b_ghost]["beat"].get("id", "")) == "berto_ghost", "berto_ghost index points to the actual berto_ghost scene beat")
	csub.queue_free()
	story.reset()
	await _frames(2)


func _test_intro_video() -> void:
	print("opening HyperFrames intro video: boot playback, skip HUD, replay button, save bypass, attract mode")
	_check(Art.clip("balete_intro") != null, "Art.clip('balete_intro') loads Ogg Theora stream")

	# 1. Fresh boot (no saved run) enters IntroScreen automatically and silences title BGM.
	Story.clear_run()
	story.reset()
	for size in [Vector2i(844, 390), LOGICAL]:
		var tag := "%dx%d" % [size.x, size.y]
		var sub := _make_viewport(size)
		var main: Control = load("res://scenes/Main.tscn").instantiate()
		sub.add_child(main)
		await _frames(3)
		var vid := main.find_child("IntroVideo", true, false) as VideoStreamPlayer
		var skip_btn := main.find_child("IntroSkipButton", true, false) as Button
		_check(vid != null and vid.stream != null and main._intro_active, "intro %s: fresh boot plays IntroVideo" % tag)
		_check(Sfx.current_cue == Sfx.SILENCE, "intro %s: title music silenced during video audio (%s)" % [tag, Sfx.current_cue])
		await _real_wait(0.65)
		_check_inside(main, "intro skip hud " + tag)
		_check(skip_btn != null and skip_btn.is_visible_in_tree(), "intro %s: skip HUD visible" % tag)
		# Skip via keyboard/accept after arm delay -> lands cleanly on interactive Title Screen.
		sub.push_input(_accept_event("enter"))
		var wf := 0
		while wf < 180 and main.find_child("StartButton", true, false) == null:
			wf += 1
			await get_tree().process_frame
		var start_btn := main.find_child("StartButton", true, false) as Button
		var intro_btn := main.find_child("IntroButton", true, false) as Button
		_check(start_btn != null and intro_btn != null and not intro_btn.disabled, "intro %s: skipping transitions cleanly to Title with Start & Watch Intro buttons" % tag)
		_check(Sfx.current_cue == "title", "intro %s: title music resumes on Title Screen (%s)" % [tag, Sfx.current_cue])
		_check_inside(main, "title after intro skip " + tag)
		sub.queue_free()
		await _frames(2)

	# 2. Title WATCH INTRO button replays intro and Escape skips back to Title.
	var rsub := _make_viewport(LOGICAL)
	var rmain: Control = load("res://scenes/Main.tscn").instantiate()
	rmain.boot_intro = false
	rsub.add_child(rmain)
	await _frames(3)
	var ibtn := rmain.find_child("IntroButton", true, false) as Button
	_check(ibtn != null, "Title has IntroButton")
	ibtn.pressed.emit()
	await _frames(3)
	_check(rmain._intro_active and rmain.find_child("IntroVideo", true, false) != null, "clicking WATCH INTRO starts IntroVideo playback")
	await _real_wait(0.35)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	rsub.push_input(esc)
	var rw := 0
	while rw < 180 and rmain.find_child("IntroButton", true, false) == null:
		rw += 1
		await get_tree().process_frame
	_check(rmain.find_child("IntroButton", true, false) != null and not rmain._intro_active, "pressing ESC skips replay intro cleanly back to Title")
	rsub.queue_free()
	await _frames(2)

	# 3. Idle Attract Mode triggers intro after idle threshold.
	var asub := _make_viewport(LOGICAL)
	var amain: Control = load("res://scenes/Main.tscn").instantiate()
	amain.boot_intro = false
	asub.add_child(amain)
	await _frames(3)
	amain._title_idle = amain.ATTRACT_IDLE + 0.1
	await _frames(3)
	_check(amain._intro_active and amain.find_child("IntroVideo", true, false) != null, "idle attract mode launches IntroVideo cleanly")
	await _real_wait(0.35)
	var sbtn := amain.find_child("IntroSkipButton", true, false) as Button
	sbtn.pressed.emit()
	var aw := 0
	while aw < 180 and amain.find_child("StartButton", true, false) == null:
		aw += 1
		await get_tree().process_frame
	_check(amain.find_child("StartButton", true, false) != null, "clicking IntroSkipButton returns attract mode to Title")
	asub.queue_free()

	# 4. Returning player with saved run bypasses boot intro straight to Continue.
	story.checkpoint(1, [])
	var ssub := _make_viewport(LOGICAL)
	var smain: Control = load("res://scenes/Main.tscn").instantiate()
	ssub.add_child(smain)
	await _frames(3)
	_check(smain.find_child("ContinueButton", true, false) != null and not smain._intro_active, "saved mid-run bypasses boot intro straight to CONTINUE")
	ssub.queue_free()
	Story.clear_run()
	story.reset()
	await _frames(2)


func _test_hd2d_upgrade() -> void:
	print("HD-2D upgrade: cinematic camera/VFX, 3D dioramas, SectorMap routes, expression portraits")
	# Phase 1: FxBurst new modes & ExploreMap battle_cam_shot.
	var fx_host := Control.new()
	add_child(fx_host)
	for m in ["cross_slash", "lightning", "prayer_motes", "shockwave"]:
		var b := FxBurst.play(fx_host, m, Vector2(640, 360), Color("ffe08a"), 1.2)
		_check(b != null and b.is_inside_tree(), "FxBurst mode '%s' spawns cleanly" % m)
	fx_host.queue_free()

	var map := ExploreMap.new()
	map.test_fast = true
	map.setup({"type": "hub", "map": "hidalgo", "options": []}, {}, 0, Vector2(-1, -1))
	add_child(map)
	map.fixed_cam = [Vector3(10, 4.5, 13), Vector3(10, 1.0, 5.5)]
	map.battle_cam_shot(Vector2(6.0, 5.5), Vector3(0.8, -0.6, -1.5), 23.0, 0.8, 8.0, -2.5)
	await _frames(2)
	_check(map.camera().fov < 25.0, "ExploreMap.battle_cam_shot zooms camera FOV (%.1f)" % map.camera().fov)
	map.battle_cam_reset()
	await _frames(2)
	_check(is_equal_approx(map.camera().fov, 30.0), "ExploreMap.battle_cam_reset restores FOV (%.1f)" % map.camera().fov)
	map.queue_free()

	# Phase 2: 3D architectural boxes in maps.json & SectorMap route beats in episode1_flow.json.
	for mid in ["quiapo_alley", "service_alley", "morgue", "pumphouse"]:
		var md := ExploreMap.map_def(mid)
		_check(md.get("boxes", []).size() >= 3, "maps.json '%s' has 3D architectural boxes (%d)" % [mid, md.get("boxes", []).size()])
	var route_count := 0
	for act in story.flow.get("acts", []):
		for b in act.get("beats", []):
			if String(b.get("type", "")) == "route":
				route_count += 1
	_check(route_count >= 4, "episode1_flow.json includes %d SectorMap route beats" % route_count)

	var sm := SectorMap.new()
	sm.fast = true
	sm.setup({"type": "route", "from": "parlor", "to": "quiapo_alley", "via": ["hidalgo"]})
	add_child(sm)
	sm.toggle_tricycle()
	var stop_ok := sm.inspect_side_stop("plaza_candles")
	await _frames(2)
	_check(sm._done and sm.find_child("RouteTeo", true, false) != null, "SectorMap traverses route and places RouteTeo")
	_check(sm.find_child("ManilaWorld", true, false) != null and sm.find_child("LRT1Train", true, false) != null, "SectorMap builds HD-2D Metro Manila 3D diorama with LRT-1 viaduct train")
	_check(sm._trike_mode and stop_ok and sm._visited_stops.has("plaza_candles"), "SectorMap supports Tricycle toggle and inspectable Manila side stops")
	sm.queue_free()

	var sp_fx_host := Control.new()
	add_child(sp_fx_host)
	for fx_mode in ["sky_bolt", "pillar_beam", "holy_mandala", "sun_sigil", "crescent_cleave", "plasma_cage", "x_break", "starburst", "heal_curtain"]:
		var fx := FxBurst.play(sp_fx_host, fx_mode, Vector2(640, 360), Color("ffe08a"), 1.2)
		_check(fx != null and fx.mode == fx_mode, "FxBurst special mode '%s' spawns cleanly" % fx_mode)
	sp_fx_host.queue_free()

	_check(ExploreMap.SHRINK == 1 and int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")) == 0, "HD-2D maps render at native 1280x720 with NEAREST canvas filter")
	var sh_map := ExploreMap.new()
	sh_map.test_fast = true
	sh_map.setup({"map": "hidalgo"}, {}, 0, Vector2(-1, -1))
	add_child(sh_map)
	await _frames(2)
	var moon_l := sh_map._vp.find_child("MoonKeyLight", true, false) as DirectionalLight3D
	_check(moon_l != null and moon_l.shadow_enabled and sh_map._we.environment.tonemap_mode == Environment.TONE_MAPPER_ACES and sh_map._teo.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "ExploreMap uses ACES tonemapping and casts real 3D shadows on Hidalgo")
	sh_map.queue_free()

	# Phase 3: Expression portrait variants & missing cast/boss busts resolve cleanly.
	var p_base := Art.portrait("teo")
	var p_expr := Art.portrait("teo", "tense")
	var p_det := Art.portrait("teo", "determined")
	_check(p_base != null and p_expr != null and p_det != null and p_expr != p_base and p_det != p_base, "Teo expression portraits (tense, determined) load distinct from base bust")
	for extra_p in ["y_kardo", "y_ising", "ambo", "junjun", "villacorta", "boy", "lunod", "unsent", "aswang", "aswang_finale", "hiraya_hound", "celeste"]:
		_check(Art.portrait(extra_p) != null, "Portrait '%s' resolves cleanly" % extra_p)

	# Phase 4: Enemy sprite idle height alignment + 3-phase Aswang + HD-2D mob attack recovery.
	for art_id in ["mag", "lunod", "lberto", "unsent", "aswang", "aswangf", "hound"]:
		var ti := load("res://assets/explore/%s_idle.png" % art_id) as Texture2D
		var tib := load("res://assets/explore/%s_idle_b.png" % art_id) as Texture2D
		var dh := absi(ti.get_height() - tib.get_height()) if (ti != null and tib != null) else 999
		_check(dh <= 9, "%s idle/idle_b heights aligned (diff %dpx at 3x)" % [art_id, dh])

	story.reset()
	var asw_stage := await _play_stage({"enemy": "aswang_finale", "party": ["teo", "kardo"]})
	_check(asw_stage.get_meta("done") and asw_stage.outcome == "scattered", "Aswang Finale defeated cleanly after 3-phase overhaul")
	_check(asw_stage._phase2 and asw_stage._phase3 and asw_stage._phase == 3, "Aswang Finale escalated through Phase II and Phase III (phase %d)" % asw_stage._phase)
	_check(asw_stage._floats() and asw_stage._foe_glow == "e866ff", "Aswang Finale took flight (floats=true) and reached overload glow (%s)" % asw_stage._foe_glow)
	_check(String(asw_stage._active_special().get("name", "")) == "SAKMAL: OVERLOAD", "Aswang Finale Phase III swapped in SAKMAL: OVERLOAD special")
	_check(not asw_stage._foe_moving, "Aswang Finale resets _foe_moving cleanly after combat actions")
	story.reset()
	await _frames(1)


func _test_stagger_and_boss_gates() -> void:
	print("stagger bar mechanic & boss 3-phase gate clamping")
	# 1. Stagger scope & HUD visibility/bounds.
	for eid in ["magbabalot", "unsent", "ligaw_berto", "aswang", "hiraya_hound", "aswang_finale"]:
		story.reset()
		var sub := _make_viewport(LOGICAL)
		var b := StageBattle.new()
		b.fast = true
		b.setup({"enemy": eid})
		sub.add_child(b)
		await _frames(2)
		_check(b.stagger_max > 0 and b._stagger_row != null and b._stagger_row.visible, "%s shows Stagger bar (max %d)" % [eid, b.stagger_max])
		_check_inside(b, "StageBattle Stagger HUD (%s)" % eid)
		sub.queue_free()
		await _frames(1)

	for eid in ["lunod", "lunod_tide"]:
		story.reset()
		var sub := _make_viewport(LOGICAL)
		var b := StageBattle.new()
		b.fast = true
		b.setup({"enemy": eid, "party": ["pido"]})
		sub.add_child(b)
		await _frames(2)
		_check(b.stagger_max == 0 and b._stagger_row != null and not b._stagger_row.visible, "1998 %s omits Stagger bar" % eid)
		sub.queue_free()
		await _frames(1)

	# 2. Stagger buildup, Stagger Break (foe_atb reset), 1.5x multiplier, send_home 1 HP safety clamp.
	story.reset()
	var msub := _make_viewport(LOGICAL)
	var mb := StageBattle.new()
	mb.fast = true
	mb.setup({"enemy": "magbabalot"})
	msub.add_child(mb)
	await _frames(2)
	mb._add_stagger_pct(0.30)
	_check(mb.stagger == 30 and not mb.staggered and mb._stagger_label.text == "STAGGER 30%", "Perfect parry buildup raises Magbabalot stagger to 30%% (%s)" % mb._stagger_label.text)
	mb._add_stagger_pct(0.35)
	_check(mb.stagger == 65 and not mb.staggered, "Weakness prayer buildup brings stagger to 65%")
	mb.foe_atb = 0.85
	mb._add_stagger_pct(0.35)
	_check(mb.staggered and mb.staggers == 1 and mb.foe_atb == 0.0 and mb._stagger_label.text == "STAGGERED! 1.5x", "Reaching 100%% triggers STAGGERED and resets foe_atb (staggers %d, label %s)" % [mb.staggers, mb._stagger_label.text])
	var hp_before := mb.foe_hp
	mb._hurt_foe(20, false, {"no_stagger_build": true})
	_check(hp_before - mb.foe_hp == 30, "STAGGERED amplifies incoming damage by 1.5x (20 -> %d)" % (hp_before - mb.foe_hp))
	mb.foe_hp = 20
	mb._hurt_foe(50, false)
	_check(mb.foe_hp == 1 and not mb._over, "send_home safety clamp holds staggered Magbabalot at 1 HP instead of scattering prematurely (%d)" % mb.foe_hp)
	mb._hurt_foe(10, false)
	_check(mb.foe_hp == 0 and mb.outcome == "scattered", "Attacking again at 1 HP scatters normally (no softlock)")
	msub.queue_free()
	await _frames(1)

	# 3. Staggered enemy recovers cleanly on its next turn.
	story.reset()
	var usub := _make_viewport(LOGICAL)
	var ub := StageBattle.new()
	ub.fast = true
	ub.setup({"enemy": "unsent"})
	usub.add_child(ub)
	await _frames(2)
	ub._add_stagger_pct(1.0)
	_check(ub.staggered and ub.stagger == ub.stagger_max, "Unsent enters STAGGERED state")
	ub.test_miss = 1
	ub._acting = true
	await ub._foe_turn()
	_check(not ub.staggered and ub.stagger == 0, "Stagger clears after enemy completes its recovery turn")
	usub.queue_free()
	await _frames(1)

	# 4a. Act 2 Aswang: cannot die before Teo falls, lethal blow wakes Watch (not _lose), then flees at 50% HP.
	story.reset()
	var asub := _make_viewport(LOGICAL)
	var ab := StageBattle.new()
	ab.fast = true
	ab.setup({"enemy": "aswang"})
	asub.add_child(ab)
	await _frames(2)
	var pre_floor := ab.foe_floor
	ab._hurt_foe(220, true)
	_check(ab.foe_hp == pre_floor and not ab._over and not ab.awakened, "Pre-awakening burst clamps Act 2 Aswang at %d HP without ending fight (got %d)" % [pre_floor, ab.foe_hp])
	var teo_u: StageBattle.Unit = ab.unit("teo")
	ab._hurt_member(teo_u, teo_u.hp, true, false)
	_check(ab._pending_scripted_awaken and not ab._over and Story.deaths == 0, "Lethal blow against Teo queues scripted Watch Awakening instead of Game Over")
	await ab._trigger_scripted_death_awakening()
	_check(ab.awakened and ab.foe_floor == 0 and teo_u.hp == teo_u.max_hp and int(teo_u.mods.get("hit", 0)) >= 5 and Story.flags.get("watch_awake", false), "Scripted death awakens Watch, revives Teo at full HP with +5 hit")
	ab._hurt_foe(200, true)
	_check(ab.foe_hp == 110 and ab.outcome == "fled" and Story.flags.get("aswang_escaped", false), "Post-awakening burst drives Act 2 Aswang to 50%% (110 HP) and triggers escape (outcome=%s)" % ab.outcome)
	asub.queue_free()
	story.reset()
	await _frames(1)

	# 4b. Act 3 Aswang Finale (380 HP): heavy burst cannot skip Phase II (228) or Phase III (114).
	story.reset()
	var afsub := _make_viewport(LOGICAL)
	var af := StageBattle.new()
	af.fast = true
	af.setup({"enemy": "aswang_finale", "party": ["teo", "kardo"]})
	afsub.add_child(af)
	await _frames(2)
	af._hurt_foe(300, true)
	_check(af.foe_hp == 228 and not af._over, "First burst clamps Aswang Finale at Phase II gate 228 HP (got %d)" % af.foe_hp)
	await _frames(2)
	var gf := 0
	while (af._checking_gates or af._waking) and gf < 120:
		gf += 1
		await get_tree().process_frame
	_check(af._phase == 2 and af._phase2 and af._floats(), "Phase II BLOOD SCENT triggers cleanly (phase=%d, floats=%s)" % [af._phase, af._floats()])

	af._hurt_foe(300, true)
	_check(af.foe_hp == 114 and not af._over, "Second burst clamps Aswang Finale at Phase III gate 114 HP (got %d)" % af.foe_hp)
	await _frames(2)
	gf = 0
	while (af._checking_gates or af._waking) and gf < 120:
		gf += 1
		await get_tree().process_frame
	_check(af._phase == 3 and af._phase3 and af._foe_glow == "e866ff", "Phase III HIRAYA TAG OVERLOAD triggers cleanly (phase=%d, glow=%s)" % [af._phase, af._foe_glow])

	af._hurt_foe(300, true)
	_check(af.foe_hp == 0 and af.outcome == "scattered", "Aswang Finale can be defeated once all 3 phases have triggered (outcome=%s)" % af.outcome)
	afsub.queue_free()
	story.reset()
	await _frames(1)

	# 5. Kardo 12-frame walk cycle sprite strip (no gliding / fake vertical bob).
	var kw := load("res://assets/explore/kardo_walk.png") as Texture2D
	_check(kw != null and kw.get_width() == 1128 and kw.get_height() == 132, "kardo_walk.png 12-frame strip loads at 1128x132")
	var ksub := _make_viewport(LOGICAL)
	var km := ExploreMap.new()
	km.test_fast = false
	km.setup({"type": "hub", "map": "service_alley", "companion": {"id": "kardo", "name": "Kardo", "sprite": "kardo", "h": 1.75}, "options": []}, {}, 0, Vector2(8.0, 6.0))
	ksub.add_child(km)
	await _frames(2)
	km._trail = [Vector2(5.0, 6.0), Vector2(10.0, 6.0)]
	km._update_companion(0.08)
	_check(km._companion_walking and km._companion != null and km._companion.hframes == 12 and is_zero_approx(km._companion.position.y), "Kardo companion animates via 12-frame walk strip without bobbing when moving")
	km._companion_pos = km._trail[1]
	km._trail = [km._companion_pos]
	km._update_companion(0.08)
	_check(not km._companion_walking and km._companion.hframes == 1, "Kardo companion reverts cleanly to idle frame (hframes=1) when stopped")
	ksub.queue_free()
	story.reset()
	await _frames(1)


# HD-2D round: two render tiers, pixelized-3D cinematics, art placeholders (docs/HD2D_TECH.md).
func _test_pixel_cg() -> void:
	print("hd-2d: tiers, pixel cg, placeholders")
	_check(RenderTier.label() != "" and not RenderTier.high(), "headless tests run as the WEB tier (%s)" % RenderTier.label())
	var ph := Placeholder.texture("test_card", Vector2i(48, 32))
	_check(ph != null and ph.get_width() == 48 and ph.get_height() == 32 and Placeholder.texture("test_card", Vector2i(48, 32)) == ph, "a placeholder card has the requested size and is cached")
	_check(Placeholder.missing("res://assets/models/summon_pido.glb") == Blockouts.is_placeholder("summon_pido"), "the model slot and the placeholder check agree")
	_check(not Blockouts.is_placeholder("summon_pido"), "summon_pido.glb is installed (zero PLACEHOLDER tag on TAWAG)")
	_check(ResourceLoader.exists("res://assets/vfx/palette_hatid.png") and ResourceLoader.exists("res://assets/vfx/ember.png") and ResourceLoader.exists("res://assets/vfx/wisp.png"), "TAWAG palette_hatid.png, ember.png, and wisp.png VFX assets exist")
	var m := Blockouts.model("summon_pido")
	var meshes := m.find_children("*", "MeshInstance3D", true, false)
	_check(meshes.size() >= 10 and m.find_child("LanternLight", true, false) != null and m.find_child("Body", true, false) != null, "Lolo Pido's blockout is built from %d shapes, with a lit lantern" % meshes.size())
	var mat := (meshes[0] as MeshInstance3D).material_override as ShaderMaterial
	_check(mat != null and mat.next_pass != null, "every blockout part is toon-shaded with an ink outline pass")
	m.free()
	var other := Blockouts.model("no_such_model")
	_check(other != null and other.get_child_count() >= 1, "an unknown model id still gives a stand-in")
	other.free()
	# The cinematic itself, played for real (not fast) for a moment: it builds its world and finishes.
	var sub := _make_viewport(Vector2i(1280, 720))
	var cg := PixelCG.new()
	sub.add_child(cg)
	var shot := {"model": "summon_pido", "scale": 3.0, "duration": 0.6, "rise": [0.0, 0.3, -7.0], "pillar": [0.0, 0.5],
		"particles": ["embers", "wisps"], "flash": 0.4,
		"cam": [{"t": 0.0, "pos": [0, 1, 16], "look": [0, 4, 0], "fov": 45}, {"t": 0.6, "pos": [8, 4, 8], "look": [0, 4, 0], "fov": 38}],
		"titles": [{"t0": 0.1, "t1": 0.5, "who": "W", "name": "N", "move": "M"}]}
	var finished := [false]
	cg.done.connect(func() -> void: finished[0] = true)
	cg.play(shot)
	var f := 0
	while f < 600 and not finished[0]:
		f += 1
		await get_tree().process_frame
	_check(finished[0] and cg._vp != null and cg._vp.size == Vector2i(PixelCG.W, PixelCG.H) and cg._model != null, "PixelCG renders the shot at %dx%d and finishes (%d frames)" % [PixelCG.W, PixelCG.H, f])
	_check(cg.placeholder == Blockouts.is_placeholder("summon_pido"), "and says when its model is still a placeholder")
	sub.queue_free()
	# TAWAG still does what it did: Lola calls once, and the shot is the pixel cinematic.
	story.reset()
	var berto := await _play_stage({"enemy": "ligaw_berto"})
	_check(berto.get_meta("done") and berto.summons == 1 and berto.cut_ins >= 1, "Lola's TAWAG plays as a pixelized-3D cinematic and the fight goes on (summons %d)" % berto.summons)
	var berto_anims: Dictionary = berto.last_bystander_anims.duplicate()
	var berto_reacts: int = berto.bystander_reactions
	var r_devout: Array = berto._bystander_reaction("devout", "awe", false)
	var r_scared: Array = berto._bystander_reaction("scared", "opening", false)
	var r_brave_early: Array = berto._bystander_reaction("brave", "awe", false)
	var r_brave_late: Array = berto._bystander_reaction("brave", "awe", true)
	var seq: Dictionary = berto._tawag_shot(StageBattle.ANCESTORS[0], berto.unit("ising"))
	var cuts: Array = seq.get("cuts", [])
	var total := 0.0
	var has_model := false
	var has_strike := false
	for c in cuts:
		total += float(c.get("dur", 0.0))
		has_model = has_model or String(c.get("model", "")) == "summon_pido"
		has_strike = has_strike or (not (c.get("slash", []) as Array).is_empty() and not (c.get("hitstop", []) as Array).is_empty())
	_check(cuts.size() >= 5 and total >= 14.0 and total <= 16.0, "TAWAG is an FF7-style summon: %d cuts, %.1f s" % [cuts.size(), total])
	_check(has_model and has_strike and String(seq.get("id", "")) != "", "it shows Lolo Pido, a slash with a hitstop, and has an id for skipping")
	var pido := Blockouts.model("summon_pido")
	_check(pido.find_child("SwordArm", true, false) != null, "the Pido blockout has a SwordArm pivot to swing")
	pido.free()
	# Multi-cut playback, for real: both cuts play, then it finishes. Skipping only once it has been seen.
	Progress.seen_cg.clear()
	var sub2 := _make_viewport(Vector2i(1280, 720))
	var cg2 := PixelCG.new()
	sub2.add_child(cg2)
	var fin2 := [false]
	cg2.done.connect(func() -> void: fin2[0] = true)
	cg2.play({"id": "smoke_cuts", "cuts": [
		{"dur": 0.3, "in": "fade", "props": ["candle"], "candle_out": 0.1, "cam": [{"t": 0.0, "pos": [0.3, 1, 1], "look": [0, 1, 0], "fov": 34}]},
		{"dur": 0.3, "in": "flash", "model": "summon_pido", "scale": 3.0, "fog": 3, "wake": [0.0, 0.3],
			"nodes": {"SwordArm": [{"t": 0.0, "rot": [0, 0, 40]}, {"t": 0.2, "rot": [0, 0, -120]}]},
			"sprites": [{"path": "res://assets/explore/lberto_idle.png", "h": 5.0, "at": [0, 0, 17], "hit": 0.1}],
			"slash": [{"t": 0.05, "at": [0, 4, 16], "size": 8}], "shock": [{"t": 0.1, "at": [0, 0.06, 16]}],
			"hitstop": [{"t": 0.1, "dur": 0.05}], "shake": [{"t": 0.1, "amp": 10}], "slowmo": [0.0, 0.1, 0.5],
			"cam": [{"t": 0.0, "pos": [8, 3, 11], "look": [0, 4, 16]}, {"t": 0.3, "pos": [10, 2, 9], "look": [0, 3, 16]}]}]})
	_check(not cg2.can_skip(), "a cinematic can't be skipped the first time")
	f = 0
	while f < 600 and not fin2[0]:
		f += 1
		await get_tree().process_frame
	_check(fin2[0] and cg2.cuts_played == 2 and not cg2.skipped, "PixelCG plays a two-cut sequence to the end (%d frames)" % f)
	_check(Progress.saw_cg("smoke_cuts"), "and remembers it was seen, so next time it can be skipped")
	sub2.queue_free()
	Progress.seen_cg.clear()
	# Bystanders: a grounded crowd. Nobody hops for joy at a supernatural fight.
	var hops := 0
	for id in berto_anims:
		if String(berto_anims[id]) == "hop":
			hops += 1
	_check(berto_reacts > 0 and not berto_anims.is_empty() and hops == 0, "the wake crowd reacts without cheering (%s)" % str(berto_anims))
	_check(r_devout[0] == "pray" and r_scared[2] == true, "the devout pray at a special; the scared back away when it starts")
	_check(r_brave_early[0] != "shout" and r_brave_late[0] == "shout", "the brave tito only shouts once it's clearly being won")
	story.reset()
	# The aswang flies: wings drawn as pixel art (until the art lands), out only while it is airborne.
	story.flags["bearer_teo"] = true
	story.flags["watch_awake"] = true
	var fin := await _play_stage({"enemy": "aswang_finale", "party": ["teo", "kardo"]})
	_check(fin.get_meta("done") and fin._has_wings() and fin._floats(), "the Unchained Aswang is airborne after Phase II (%s)" % fin.outcome)
	_check(fin.wingbeats > 0, "and flies to a wingbeat (%d downstrokes)" % fin.wingbeats)
	_check((fin._wings != null) == ResourceLoader.exists("res://assets/explore/aswangf_fly.png"), "its flight strip is used only once the art exists")
	_check(fin._wings != null and ResourceLoader.exists("res://assets/explore/aswang_fly.png"), "aswang_fly.png and aswangf_fly.png flight strips are present and active")
	story.reset()
	# Bystander reaction poses (#5): pray / cower / phone assets exist for all 9 NPC sprites and swap cleanly in ExploreMap.
	for spr in ["nena", "domeng", "cards_a", "balut", "trike", "kid", "tess", "celso", "guard"]:
		for pose in ["pray", "cower", "phone"]:
			_check(ResourceLoader.exists("res://assets/explore/%s_%s.png" % [spr, pose]), "bystander pose %s_%s.png exists" % [spr, pose])
	var psub := _make_viewport(LOGICAL)
	var sb_pose := StageBattle.new()
	sb_pose.fast = true
	sb_pose.setup({"enemy": "aswang"})
	psub.add_child(sb_pose)
	await _frames(2)
	var tess_spr: Sprite3D = sb_pose._map._cast["tess"]["node"]
	var celso_spr: Sprite3D = sb_pose._map._cast["celso"]["node"]
	sb_pose._map.bystander_react("tess", "pray", "pray", true)
	sb_pose._map.bystander_react("celso", "film", "!", true)
	await _frames(2)
	_check(tess_spr.texture.resource_path.ends_with("/tess_pray.png"), "tess swaps to tess_pray.png on pray reaction")
	_check(celso_spr.texture.resource_path.ends_with("/celso_phone.png"), "celso swaps to celso_phone.png on film reaction")
	sb_pose._map.bystander_react("tess", "cower", "sweat", true)
	await _frames(2)
	_check(tess_spr.texture.resource_path.ends_with("/tess_cower.png"), "tess swaps to tess_cower.png on cower reaction")
	sb_pose._map._tick_anims(5.0)
	sb_pose._map._update_cast()
	_check(not tess_spr.texture.resource_path.ends_with("_cower.png") and not celso_spr.texture.resource_path.ends_with("_phone.png"), "bystanders revert to idle sprite once reaction anim expires")
	psub.queue_free()
	await _frames(2)
	story.reset()

