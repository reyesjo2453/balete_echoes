class_name Art
extends RefCounted
## Looks up panels and portraits by the same ids as the web build's art manifest.
## A missing file returns null; callers draw a labelled placeholder (plug and play: drop the file in).

const ALIAS := {
	"ep1_16_dante_wheel": "dante_panel1_wheel",
	"ep1_17_dante_approach": "dante_panel2_approach",
}

## Portrait ids for the cast, mapped to the files drawn for them (the art predates the names).
const PORTRAIT_ALIAS := {
	"teo": "renzo",
	"kardo": "dante",
	"ising": "lola",
	"domeng": "mang_domeng",
}

static var _cache: Dictionary = {}


static func _find(dir: String, file_name: String) -> Texture2D:
	var key := dir + "/" + file_name
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	for ext in ["webp", "png", "jpg"]:
		var path := "res://assets/%s/%s.%s" % [dir, file_name, ext]
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
			break
	_cache[key] = tex
	return tex


static func panel(id: String) -> Texture2D:
	var file_name: String = ALIAS.get(id, id)
	return _find("comics", file_name)


## A short looping clip that brings a panel to life (assets/clips/<panel id>.ogv, Theora). Null when the panel has
## none, so the still is shown as before.
static func clip(id: String) -> VideoStream:
	var key := "clips/" + id
	if _cache.has(key):
		return _cache[key]
	var path := "res://assets/clips/%s.ogv" % id
	var stream: VideoStream = load(path) as VideoStream if ResourceLoader.exists(path) else null
	_cache[key] = stream
	return stream


## Dialogue portraits are 16-bit pixel busts (assets/portraits_px/<id>.png), one per speaker. The older painted
## portraits are only a fallback for ids that have no pixel bust yet.
static func portrait(id: String) -> Texture2D:
	var key := id.trim_prefix("portrait_")
	if key == "":
		return null
	var px := _find("portraits_px", key)
	if px != null:
		return px
	return _find("portraits", String(PORTRAIT_ALIAS.get(key, key)))
