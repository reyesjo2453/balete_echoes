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
var _blip_player: AudioStreamPlayer
var _blip_cache: Dictionary = {}
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
	_blip_player = AudioStreamPlayer.new()
	_blip_player.name = "TextBlip"
	add_child(_blip_player)
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


## Synthesizes and plays a tiny 16-bit JRPG dialogue blip pitched per speaker.
func blip(speaker: String) -> void:
	if _blip_player == null or DisplayServer.get_name() == "headless":
		return
	var hz := _speaker_pitch(speaker)
	var key := str(int(hz))
	if not _blip_cache.has(key):
		_blip_cache[key] = _make_blip(hz, 0.022 if speaker == "" else 0.032)
	_blip_player.stream = _blip_cache[key]
	_blip_player.volume_db = -21.0 if speaker == "" else -15.0
	_blip_player.pitch_scale = randf_range(0.96, 1.04)
	_blip_player.play()


func _speaker_pitch(speaker: String) -> float:
	match speaker:
		"Teo":
			return 370.0
		"Lola Ising", "Ising", "Lola Ising (tape)":
			return 460.0
		"Kardo":
			return 220.0
		"Lolo Pido":
			return 260.0
		"Kapitan Obet":
			return 310.0
		"Mang Berto", "Mang Andoy", "Mang Ambo":
			return 195.0
		"Atty. Benitez":
			return 490.0
		"Aling Nena", "Aling Tess":
			return 430.0
		"Nonoy", "Boy on the roof":
			return 540.0
		"":
			return 620.0
		_:
			return 290.0 + float(absi(speaker.hash()) % 120)


func _make_blip(hz: float, secs: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * secs)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / float(rate)
		var env := minf(1.0, float(i) / 40.0) * (1.0 - float(i) / float(count))
		var ph := fmod(t * hz, 1.0)
		var tri := 1.0 - 4.0 * absf(ph - 0.5)
		var sq := 1.0 if ph < 0.5 else -1.0
		var s := clampi(int((tri * 0.7 + sq * 0.3) * env * 14000.0), -32768, 32767)
		data.encode_s16(i * 2, s)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav


func _synth(key: String, f0: float, f1: float, secs: float, wave: String = "sq") -> AudioStreamWAV:
	if _blip_cache.has(key):
		return _blip_cache[key]
	var rate := 22050
	var count := maxi(1, int(rate * secs))
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var u := float(i) / float(count)
		var hz := lerpf(f0, f1, u)
		phase = fmod(phase + hz / float(rate), 1.0)
		var sample := 0.0
		if wave == "tri":
			sample = 1.0 - 4.0 * absf(phase - 0.5)
		elif wave == "step":
			var step_hz := f0 if u < 0.45 else f1
			phase = fmod(float(i) * step_hz / float(rate), 1.0)
			sample = (1.0 if phase < 0.5 else -1.0) * 0.65 + (1.0 - 4.0 * absf(phase - 0.5)) * 0.35
		else:
			sample = (1.0 if phase < 0.45 else -1.0) * 0.6 + (1.0 - 4.0 * absf(phase - 0.5)) * 0.4
		var env := minf(1.0, float(i) / 36.0) * (1.0 - u)
		data.encode_s16(i * 2, clampi(int(sample * env * 13500.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	_blip_cache[key] = wav
	return wav


func _play_synth(wav: AudioStreamWAV, volume_db: float = -12.0) -> void:
	if wav == null or DisplayServer.get_name() == "headless":
		return
	for p in _players:
		if not p.playing:
			p.stream = wav
			p.volume_db = volume_db
			p.play()
			return


## Crisp 16-bit SNES cursor tick when moving focus across menu buttons.
func ui_move() -> AudioStreamWAV:
	var wav := _synth("ui_move", 880.0, 1175.0, 0.032, "sq")
	_play_synth(wav, -14.0)
	return wav


## Crisp 16-bit two-tone confirm chime on menu selection.
func ui_confirm() -> AudioStreamWAV:
	var wav := _synth("ui_confirm", 784.0, 1046.5, 0.068, "step")
	_play_synth(wav, -11.0)
	return wav


## 16-bit stingers for FF7-style pop-up overhead emotes ("!", "?", "sweat", "...").
func emote(kind: String) -> AudioStreamWAV:
	var wav: AudioStreamWAV = null
	match kind:
		"!":
			wav = _synth("emote_bang", 660.0, 1320.0, 0.09, "step")
		"?":
			wav = _synth("emote_q", 420.0, 740.0, 0.095, "tri")
		"sweat":
			wav = _synth("emote_sweat", 560.0, 260.0, 0.095, "sq")
		"...":
			wav = _synth("emote_dots", 240.0, 210.0, 0.07, "tri")
		_:
			return null
	_play_synth(wav, -10.0)
	return wav


## Crisp pocket-watch tick played when borrowed time (utang) is active or REWIND? opens.
func watch_tick() -> AudioStreamWAV:
	var wav := _synth("watch_tick", 1760.0, 1320.0, 0.028, "sq")
	_play_synth(wav, -14.0)
	return wav


## Low 16-bit warning drop for Phase II transitions and special wind-ups.
func phase_shift() -> AudioStreamWAV:
	var wav := _synth("phase_shift", 260.0, 110.0, 0.24, "step")
	_play_synth(wav, -9.0)
	return wav


## Warm ascending bell chime when a spirit is sent home.
func sent_home() -> AudioStreamWAV:
	var wav := _synth("sent_home", 523.25, 783.99, 0.26, "tri")
	_play_synth(wav, -9.0)
	return wav


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
