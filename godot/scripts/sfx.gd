extends Node
## Sound: a small pool of one-shot players plus two music players that crossfade. Autoload "Sfx".
## Files live in res://assets/sfx and res://assets/bgm. Missing files are skipped silently.
##
## Music is played by *cue*, not by file: data/music.json maps each mood (title, wake, tension, battle, boss,
## sting) to a file, a volume and whether it loops. Story beats, scene steps and enemies name a cue; "silence"
## fades the music out for a big emotional beat. To swap in a real track, drop the file into assets/bgm and
## change the cue's "file" (credits go in assets/bgm/CREDITS.md and the cue's "credit").

const SILENCE := "silence"
const FADE := 1.2

var _players: Array[AudioStreamPlayer] = []
var _music: Array[AudioStreamPlayer] = []
var _active := 0
var _cache: Dictionary = {}
var _cues: Dictionary = {}
var _tweens: Array = [null, null]
## The cue playing now ("" before any, "silence" after a fade-out). Tests read it.
var current_cue := ""


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.name = "Music%d" % i
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
	var file := FileAccess.open("res://data/music.json", FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_cues = parsed.get("cues", {})


func _stream(dir: String, file_name: String) -> AudioStream:
	var key := dir + file_name
	if _cache.has(key):
		return _cache[key]
	var stream: AudioStream = null
	for ext in ["ogg", "mp3", "wav"]:
		var path := "res://assets/%s/%s.%s" % [dir, file_name, ext]
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
			break
	_cache[key] = stream
	return stream


func play(file_name: String, volume_db: float = 0.0) -> void:
	var stream := _stream("sfx", file_name)
	if stream == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.play()
			return


func has_cue(id: String) -> bool:
	return id == SILENCE or _cues.has(id)


## The file a cue plays (for tests and the credits).
func cue_file(id: String) -> String:
	return String(_cues.get(id, {}).get("file", ""))


## Crossfade to a music cue. The same cue again is a no-op, so a scene can name its cue without restarting it.
func cue(id: String, fade: float = FADE) -> void:
	if id == "" or id == current_cue:
		return
	if id != SILENCE and not _cues.has(id):
		push_warning("Unknown music cue: " + id)
		return
	current_cue = id
	_fade_out(_active, fade)
	if id == SILENCE:
		return
	var def: Dictionary = _cues[id]
	var stream := _stream("bgm", String(def.get("file", "")))
	if stream == null:
		return
	var loop := bool(def.get("loop", true))
	if "loop" in stream:
		stream.set("loop", loop)
	_active = 1 - _active
	var m := _music[_active]
	_kill_tween(_active)
	m.stream = stream
	m.volume_db = -60.0
	m.play()
	var tw := create_tween()
	tw.tween_property(m, "volume_db", float(def.get("volume_db", -9.0)), maxf(0.05, fade * 0.8))
	_tweens[_active] = tw


func _fade_out(index: int, fade: float) -> void:
	var m := _music[index]
	_kill_tween(index)
	if not m.playing:
		return
	var tw := create_tween()
	tw.tween_property(m, "volume_db", -60.0, maxf(0.05, fade))
	tw.tween_callback(m.stop)
	_tweens[index] = tw


func _kill_tween(index: int) -> void:
	var tw: Variant = _tweens[index]
	if tw is Tween and (tw as Tween).is_valid():
		(tw as Tween).kill()
	_tweens[index] = null


## The music player that holds the current cue (tests check what it plays).
func active_player() -> AudioStreamPlayer:
	return _music[_active]
