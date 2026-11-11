class_name BattleActor
extends Control
## One character on the battle stage, with a small animation vocabulary driven from code.
##
## Today the visual is a programmatic silhouette; tomorrow it can be real art without touching the battle code.
## Drop-ins (checked in this order, per actor id, under `asset_root`):
##   1. res://assets/battle/<id>/actor.tscn   any scene; if it has a play(anim_name) method it is called with
##      the move names below (idle, windup, attack, hit, parry, down, rise, cast), so a Blender render, a
##      Spine rig or a 3D viewport in a SubViewportContainer can sit here.
##   2. res://assets/battle/<id>/<anim>.png + <anim>.json   horizontal sprite-sheet strips for each move,
##      json: {"frame_w": 256, "frame_h": 256, "frames": 6, "fps": 10, "loop": true}.
## Without either, the silhouette is drawn and animated by the tweens here (sway, lunge, flash, knockback).

signal contact # the moment an attack lands (the lunge's apex)

const MOVES := ["idle", "windup", "attack", "hit", "parry", "down", "rise", "cast"]

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


## Sprite-sheet strips: <asset_root>/<id>/<move>.png with <move>.json describing the frames.
func _build_sheet() -> bool:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var found := false
	for move in MOVES:
		var png := "%s%s/%s.png" % [asset_root, actor_id, move]
		var meta := "%s%s/%s.json" % [asset_root, actor_id, move]
		if not (FileAccess.file_exists(png) and FileAccess.file_exists(meta)):
			continue
		var def: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta))
		var img := Image.load_from_file(png)
		if not (def is Dictionary) or img == null:
			continue
		var tex := ImageTexture.create_from_image(img)
		var fw := int(def.get("frame_w", img.get_height()))
		var fh := int(def.get("frame_h", img.get_height()))
		frames.add_animation(move)
		frames.set_animation_speed(move, float(def.get("fps", 10)))
		frames.set_animation_loop(move, bool(def.get("loop", move == "idle")))
		for i in int(def.get("frames", 1)):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * fw, 0, fw, fh)
			frames.add_frame(move, atlas)
		found = true
	if not found:
		return false
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.centered = false
	_sprite.position = Vector2.ZERO
	rig.add_child(_sprite)
	return true


## Ask the real art (scene or sheet) to play a move; the code tweens still run on top of it.
func play_move(move: String) -> void:
	if _scene_view != null and _scene_view.has_method("play"):
		_scene_view.call("play", move)
	elif _sprite != null and _sprite.sprite_frames.has_animation(move):
		_sprite.play(move)


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
