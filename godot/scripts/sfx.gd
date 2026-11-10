extends Node
## Sound: a small pool of one-shot players plus one looping music player. Autoload "Sfx".
## Files live in res://assets/sfx and res://assets/bgm. Missing files are skipped silently.

var _players: Array[AudioStreamPlayer] = []
var _bgm: AudioStreamPlayer
var _cache: Dictionary = {}
var _current_bgm := ""


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_bgm = AudioStreamPlayer.new()
	_bgm.volume_db = -9.0
	add_child(_bgm)


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


func bgm(file_name: String) -> void:
	if file_name == _current_bgm:
		return
	_current_bgm = file_name
	var stream := _stream("bgm", file_name)
	if stream == null:
		_bgm.stop()
		return
	if "loop" in stream:
		stream.set("loop", true)
	_bgm.stream = stream
	_bgm.play()
