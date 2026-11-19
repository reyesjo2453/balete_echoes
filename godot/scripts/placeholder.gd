class_name Placeholder
## Stand-ins for art that has not been made yet (docs/ART_REQUESTS.md). New art comes from John's Antigravity /
## Gemini pipeline: drop the finished file in at the path the request names and it replaces the stand-in, with no
## code change. A stand-in is never subtle: magenta and black stripes with a border, and, where text can be shown,
## the asset id and PLACEHOLDER.

static var _cache: Dictionary = {}


## A striped stand-in texture of exactly `size` pixels (cached per id and size).
static func texture(id: String, size: Vector2i) -> Texture2D:
	var key := "%s@%dx%d" % [id, size.x, size.y]
	if _cache.has(key):
		return _cache[key]
	var w := maxi(2, size.x)
	var h := maxi(2, size.y)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var a := Color(0.85, 0.1, 0.75)
	var b := Color(0.06, 0.04, 0.08)
	var stripe := maxi(2, mini(w, h) / 8)
	for y in h:
		for x in w:
			var edge := x < 2 or y < 2 or x >= w - 2 or y >= h - 2
			img.set_pixel(x, y, Color.WHITE if edge else (a if ((x + y) / stripe) % 2 == 0 else b))
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


## The file if it exists, else a stand-in of `size`. `path` is a res:// path.
static func load_or(path: String, size: Vector2i) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return texture(path.get_file().get_basename(), size)


## Is this asset still a stand-in?
static func missing(path: String) -> bool:
	return not ResourceLoader.exists(path)


## A small corner tag for a screen that shows stand-in art, so a reviewer knows what is still to be drawn.
static func tag(text: String) -> Label:
	var l := Label.new()
	l.text = "PLACEHOLDER  ·  " + text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(1.0, 0.55, 0.95, 0.85))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
