class_name Fonts
extends RefCounted
## Project fonts (same families as the web build). Falls back to the engine default if a file is missing.

static var _cache: Dictionary = {}


static func _load_font(file_name: String) -> Font:
	if _cache.has(file_name):
		return _cache[file_name]
	var path := "res://assets/fonts/%s.woff2" % file_name
	var font: Font = null
	if ResourceLoader.exists(path):
		font = load(path) as Font
	if font == null:
		font = ThemeDB.fallback_font
	_cache[file_name] = font
	return font


static func display() -> Font:
	return _load_font("anton")


static func label() -> Font:
	return _load_font("oswald-600")


static func label_medium() -> Font:
	return _load_font("oswald-500")


static func body() -> Font:
	return _load_font("barlow-500")


static func body_italic() -> Font:
	return _load_font("barlow-500-italic")


static func sfx() -> Font:
	return _load_font("bangers")
