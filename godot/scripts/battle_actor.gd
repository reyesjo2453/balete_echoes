class_name BattleActor
extends Control
## One character on the battle stage, with a small animation vocabulary driven from code.
##
## Today the visual is a programmatic silhouette; real art drops in without touching the battle code.
## Drop-ins (checked in this order, per actor id, under `asset_root`):
##   1. res://assets/battle/<id>/actor.tscn   any scene; if it has a play(anim_name) method it is called with
##      the move names below (idle, windup, attack, hit, parry, down, rise, cast).
##   2. res://assets/battle/<id>/<move>.png (or .webp)   one pose per move, or a horizontal strip of frames.
##      A pose needs no json. A strip adds <move>.json: {"frames": 6, "fps": 10, "loop": true} (frame_w and
##      frame_h default to the image height and width / frames). One scale per character: the idle figure fills
##      90% of the box height (poses may spill past the box), feet on the bottom centre, so one drawing works at
##      every box size. A move with no art falls back to a close one
##      (windup -> idle, down -> hit, ...); a single pose is held for the whole move and the tweens, plus a
##      small squash when the pose changes, carry the motion.
## Without either, the silhouette is drawn and animated by the tweens here (sway, lunge, flash, knockback).
## Under res:// the images go through Godot's importer (so they ship in exported builds) and the json is
## packed by the export include filter (assets/battle/*.json).

signal contact # the moment an attack lands (the lunge's apex)

const MOVES := ["idle", "windup", "attack", "hit", "parry", "down", "rise", "cast"]
## When a move has no art, show this one instead (followed until one exists).
const FALLBACK := {"windup": "idle", "parry": "idle", "rise": "idle", "cast": "attack", "down": "hit", "hit": "idle", "attack": "idle"}

var actor_id: String = ""
var kind: String = "teo"
var rim: Color = Color("c9a24a")
var facing: float = 1.0 # +1 faces right
var home: Vector2 = Vector2.ZERO
var asset_root: String = "res://assets/battle/"
var rig: Control # what the tweens move: it holds whatever visual is in use
var view_kind: String = "silhouette" # "silhouette" | "scene" | "sheet"

var _idle: Tween
var _move: Tween
var _sprite: AnimatedSprite2D
var _pose_holder: Node2D # feet at the bottom centre of the box; scaled so the pose fits
var _pose_tw: Tween
var _frame_sizes: Dictionary = {} # move -> Vector2 frame size
var _fit: float = 1.0 # one scale for every pose of this character
var _used: Dictionary = {} # move -> Rect2i of the drawn (non-transparent) part of its first frame
## How tall the standing (idle) figure should be, as a share of the box height. Poses may spill past the box.
var fill: float = 0.9
## Most screen pixels any pose may rise above the feet (0 = no limit), so tall poses stay under the HUD.
var max_height: float = 0.0
var pose: String = "" # the move whose art is showing (sheets only)
var _scene_view: Node
var _windup_glow: bool = false


func _init(p_id: String = "", p_kind: String = "teo", p_rim: Color = Color("c9a24a"), p_size: Vector2 = Vector2(220, 340), p_facing: float = 1.0) -> void:
	actor_id = p_id
	kind = p_kind
	rim = p_rim
	facing = p_facing
	size = p_size
	custom_minimum_size = p_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	rig = Control.new()
	rig.size = size
	rig.pivot_offset = Vector2(size.x * 0.5, size.y - 10.0)
	rig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rig)
	_build_view()
	if facing < 0.0:
		rig.scale.x = -1.0
	home = position
	idle()


func _build_view() -> void:
	var scene_path := "%s%s/actor.tscn" % [asset_root, actor_id]
	if actor_id != "" and ResourceLoader.exists(scene_path):
		var packed := load(scene_path) as PackedScene
		if packed != null:
			_scene_view = packed.instantiate()
			rig.add_child(_scene_view)
			view_kind = "scene"
			return
	if actor_id != "" and _build_sheet():
		view_kind = "sheet"
		return
	var sil := Silhouette.new(kind, rim)
	sil.size = size
	rig.add_child(sil)
	view_kind = "silhouette"


## Poses and strips: <asset_root>/<id>/<move>.png|webp, with an optional <move>.json for multi-frame strips.
func _build_sheet() -> bool:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for move in MOVES:
		var tex := _load_texture("%s%s/%s" % [asset_root, actor_id, move])
		if tex == null:
			continue
		var def := _load_meta("%s%s/%s.json" % [asset_root, actor_id, move])
		var count := maxi(1, int(def.get("frames", 1)))
		var fw := int(def.get("frame_w", tex.get_width() / count))
		var fh := int(def.get("frame_h", tex.get_height()))
		frames.add_animation(move)
		frames.set_animation_speed(move, float(def.get("fps", 10)))
		frames.set_animation_loop(move, bool(def.get("loop", move == "idle")))
		for i in count:
			if count == 1 and fw == tex.get_width() and fh == tex.get_height():
				frames.add_frame(move, tex)
				continue
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * fw, 0, fw, fh)
			frames.add_frame(move, atlas)
		_frame_sizes[move] = Vector2(fw, fh)
	if _frame_sizes.is_empty():
		return false
	_fit = _character_scale(frames)
	_pose_holder = Node2D.new()
	_pose_holder.position = Vector2(size.x * 0.5, size.y)
	rig.add_child(_pose_holder)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_pose_holder.add_child(_sprite)
	_show_pose(_resolve(MOVES[0]), false)
	return true


## One scale for the whole character: the idle figure fills `fill` of the box height, and the tallest pose
## still fits under `max_height`. The drawn part of each pose is measured, so canvas padding doesn't count.
func _character_scale(frames: SpriteFrames) -> float:
	var tallest := 1
	for move in _frame_sizes:
		var img := frames.get_frame_texture(move, 0).get_image()
		var r := img.get_used_rect() if img != null else Rect2i(Vector2i.ZERO, Vector2i(_frame_sizes[move]))
		if r.size.y <= 0:
			r = Rect2i(Vector2i.ZERO, Vector2i(_frame_sizes[move]))
		_used[move] = r
		# a pose stands on the canvas bottom, so its height above the feet runs from its top to the bottom
		tallest = maxi(tallest, int(_frame_sizes[move].y) - r.position.y)
	var stand: Rect2i = _used[_resolve("idle")]
	var s := fill * size.y / maxf(1.0, float(stand.size.y))
	if max_height > 0.0:
		s = minf(s, max_height / float(tallest))
	return s


## An imported texture (res://, ships in exports) or, for loose files such as test fixtures, a raw image.
func _load_texture(base: String) -> Texture2D:
	for ext in ["png", "webp"]:
		var path := "%s.%s" % [base, ext]
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				return tex
		if not path.begins_with("res://") and FileAccess.file_exists(path):
			var img := Image.load_from_file(path)
			if img != null and not img.is_empty():
				return ImageTexture.create_from_image(img)
	return null


func _load_meta(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var def: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return def if def is Dictionary else {}


## The move to show for `move`: itself if drawn, else its fallback chain, else whatever is drawn.
func _resolve(move: String) -> String:
	var m := move
	for i in 4:
		if _frame_sizes.has(m):
			return m
		m = String(FALLBACK.get(m, "idle"))
	return String(_frame_sizes.keys()[0])


## Swap the pose: fit it to the box, feet on the bottom centre, with a quick squash so the change reads.
func _show_pose(move: String, pop: bool = true) -> void:
	var fs: Vector2 = _frame_sizes[move]
	_sprite.position = Vector2(-fs.x * 0.5, -fs.y)
	_sprite.play(move)
	var changed := move != pose
	pose = move
	if _pose_tw != null and _pose_tw.is_valid():
		_pose_tw.kill()
	_pose_holder.position = Vector2(size.x * 0.5, size.y)
	if not (pop and changed):
		_pose_holder.scale = Vector2(_fit, _fit)
		return
	_pose_tw = create_tween()
	_pose_holder.scale = Vector2(_fit * 1.07, _fit * 0.93)
	_pose_tw.tween_property(_pose_holder, "scale", Vector2(_fit, _fit), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if move == "hit":
		for i in 4: # a short shake on the struck pose
			_pose_tw.parallel().tween_property(_pose_holder, "position:x", size.x * 0.5 + (6.0 if i % 2 == 0 else -6.0), 0.035).set_delay(0.035 * i)
		_pose_tw.tween_property(_pose_holder, "position:x", size.x * 0.5, 0.035)


## Ask the real art (scene or sheet) to play a move; the code tweens still run on top of it.
func play_move(move: String) -> void:
	if _scene_view != null and _scene_view.has_method("play"):
		_scene_view.call("play", move)
	elif _sprite != null:
		_show_pose(_resolve(move))


## Any move takes over the rig: the idle sway stops (it would fight the move) and resumes when the move ends.
func _stop_move() -> void:
	if _move != null and _move.is_valid():
		_move.kill()
	if _idle != null and _idle.is_valid():
		_idle.kill()


# --- The move set -------------------------------------------------------------------------------

## Idle: a slow sway and breathing, so nothing on the stage is ever a still picture.
func idle() -> void:
	play_move("idle")
	if _idle != null and _idle.is_valid():
		_idle.kill()
	_idle = create_tween().set_loops()
	var phase := randf_range(0.0, 0.6)
	_idle.tween_interval(phase)
	_idle.tween_property(rig, "position:y", -5.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle.parallel().tween_property(rig, "rotation", 0.018 * facing, 0.9).set_trans(Tween.TRANS_SINE)
	_idle.tween_property(rig, "position:y", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle.parallel().tween_property(rig, "rotation", -0.018 * facing, 0.9).set_trans(Tween.TRANS_SINE)


## Lunge toward a point and back; emits `contact` at the apex. Returns the tween so callers can await it.
func lunge_to(target_home: Vector2, stop_short: float = 110.0) -> Tween:
	_stop_move()
	_windup_glow = false
	rig.modulate = Color.WHITE
	play_move("attack")
	_draw_above_fighters() # the attacker passes in front of its target (but stays under the HUD drawn after it)
	var dir := (target_home - home)
	var dist := dir.length()
	var unit := dir / maxf(dist, 1.0)
	var apex := home + unit * maxf(dist - stop_short, 20.0)
	_move = create_tween()
	_move.tween_property(self, "position", home - unit * 16.0, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT) # wind back
	_move.parallel().tween_property(rig, "scale", Vector2(0.94 * facing, 1.06), 0.09)
	_move.tween_property(self, "position", apex, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_move.parallel().tween_property(rig, "scale", Vector2(1.1 * facing, 0.94), 0.12)
	_move.tween_callback(func() -> void: contact.emit())
	_move.tween_interval(0.05)
	_move.tween_property(self, "position", home, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_move.parallel().tween_property(rig, "scale", Vector2(facing, 1.0), 0.2)
	_move.finished.connect(idle)
	return _move


## Move this actor just after the last fighter among its siblings, so it draws over them and under later UI.
func _draw_above_fighters() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var last := get_index()
	for c in parent.get_children():
		if c is BattleActor and c != self:
			last = maxi(last, c.get_index())
	if last > get_index():
		parent.move_child(self, last)


## Struck: a white flash, a knockback away from the attacker and a spring back.
func hit(from_dir_x: float, heavy: bool = false) -> Tween:
	_stop_move()
	play_move("hit")
	var push := (30.0 if heavy else 14.0) * signf(from_dir_x if from_dir_x != 0.0 else 1.0)
	_move = create_tween()
	rig.modulate = Color(2.2, 2.2, 2.2)
	_move.tween_property(rig, "modulate", Color.WHITE, 0.16)
	_move.parallel().tween_property(self, "position", home + Vector2(push, 0.0), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move.parallel().tween_property(rig, "rotation", 0.12 * signf(push), 0.06)
	_move.tween_property(self, "position", home, 0.26).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_move.parallel().tween_property(rig, "rotation", 0.0, 0.26)
	_move.finished.connect(idle)
	return _move


## Enemy wind-up: a visible telegraph of the intent, so the player can read what is coming.
func windup(intent_key: String) -> void:
	_stop_move()
	play_move("windup")
	_windup_glow = true
	_move = create_tween()
	match intent_key:
		"lunge":
			# Crouch low and coil.
			_move.tween_property(rig, "scale", Vector2(1.08 * facing, 0.82), 0.4).set_trans(Tween.TRANS_QUAD)
			_move.parallel().tween_property(self, "position", home + Vector2(-facing * 24.0, 0.0), 0.4)
		"flurry":
			# Rapid shaking: a blur of claws coming.
			for i in 6:
				_move.tween_property(rig, "rotation", (0.07 if i % 2 == 0 else -0.07), 0.06)
			_move.tween_property(rig, "rotation", 0.0, 0.05)
		_:
			# Claw: rear back and raise the arm.
			_move.tween_property(rig, "rotation", -0.2 * facing, 0.35).set_trans(Tween.TRANS_BACK)
			_move.parallel().tween_property(self, "position", home + Vector2(-facing * 14.0, -6.0), 0.35)
	_move.parallel().tween_property(rig, "modulate", Color(1.35, 0.75, 0.75), 0.35)


func end_windup() -> void:
	if not _windup_glow:
		return
	_windup_glow = false
	_stop_move()
	_move = create_tween()
	_move.tween_property(rig, "modulate", Color.WHITE, 0.15)
	_move.parallel().tween_property(rig, "scale", Vector2(facing, 1.0), 0.15)
	_move.parallel().tween_property(rig, "rotation", 0.0, 0.15)
	_move.parallel().tween_property(self, "position", home, 0.15)
	_move.finished.connect(idle)


## A successful parry: a braced pose with a golden flash.
func parry_pose() -> Tween:
	_stop_move()
	play_move("parry")
	_move = create_tween()
	rig.modulate = Color(1.8, 1.6, 1.0)
	_move.tween_property(rig, "modulate", Color.WHITE, 0.25)
	_move.parallel().tween_property(rig, "rotation", -0.14 * facing, 0.08)
	_move.parallel().tween_property(self, "position", home + Vector2(-facing * 12.0, 0.0), 0.08)
	_move.tween_property(rig, "rotation", 0.0, 0.2)
	_move.parallel().tween_property(self, "position", home, 0.2)
	_move.finished.connect(idle)
	return _move


## The enemy reels after a parry (its guard is open).
func recoil() -> Tween:
	_stop_move()
	_windup_glow = false
	play_move("hit")
	_move = create_tween()
	_move.tween_property(self, "position", home + Vector2(facing * 26.0, 0.0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move.parallel().tween_property(rig, "rotation", 0.16 * facing, 0.08)
	_move.parallel().tween_property(rig, "modulate", Color.WHITE, 0.08)
	_move.tween_property(self, "position", home, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_move.parallel().tween_property(rig, "rotation", 0.0, 0.3)
	_move.parallel().tween_property(rig, "scale", Vector2(facing, 1.0), 0.3)
	_move.finished.connect(idle)
	return _move


func down() -> Tween:
	_stop_move()
	play_move("down")
	_move = create_tween().set_parallel(true)
	_move.tween_property(rig, "rotation", 1.3 * facing, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_move.tween_property(rig, "modulate:a", 0.25, 0.6)
	return _move


func rise() -> Tween:
	_stop_move()
	play_move("rise")
	_move = create_tween().set_parallel(true)
	_move.tween_property(rig, "rotation", 0.0, 0.4)
	_move.tween_property(rig, "modulate", Color.WHITE, 0.4)
	_move.chain().tween_callback(idle)
	return _move


## The watch turns back: teal afterimages slide backward behind the character.
func rewind_pulse(parent: Control) -> void:
	play_move("cast")
	if view_kind == "sheet": # a held cast pose goes back to idle once the pulse has played
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if is_instance_valid(self) and pose == _resolve("cast"):
				play_move("idle"))
	for i in 3:
		var ghost := Control.new()
		ghost.size = size
		ghost.position = position
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.modulate = Color(0.0, 1.0, 0.8, 0.45 - 0.12 * float(i))
		var sil := Silhouette.new(kind, Color("00ffcc"))
		sil.size = size
		ghost.add_child(sil)
		parent.add_child(ghost)
		var tw := ghost.create_tween().set_parallel(true)
		tw.tween_property(ghost, "position:x", position.x - facing * (30.0 + 26.0 * float(i)), 0.5)
		tw.tween_property(ghost, "modulate:a", 0.0, 0.5)
		tw.chain().tween_callback(ghost.queue_free)


func center_point() -> Vector2:
	return home + Vector2(size.x * 0.5, size.y * 0.45)
