class_name SectorMap
extends Control
## Stylized nocturnal Quiapo District sector map: replaces jarring teleports between distant hubs with a visible
## walk along the lit street route, showing unlocked paths and curfew/flooded barricades to preserve linearity.

signal finished

const NODES := {
	"parlor": {"name": "DIMACULANGAN PARLOR", "sub": "24-Hour Wake", "at": Vector2(230, 430)},
	"hidalgo": {"name": "HIDALGO STREET", "sub": "Under the Balete", "at": Vector2(460, 370)},
	"quiapo_alley": {"name": "QUIAPO ALLEY", "sub": "Shuttered Shops", "at": Vector2(660, 315)},
	"estero": {"name": "ESTERO DE QUIAPO", "sub": "Sunken Creek", "at": Vector2(855, 255)},
	"pumphouse": {"name": "PUMPHOUSE", "sub": "Floodgate Station", "at": Vector2(1035, 195)},
	"service_alley": {"name": "SERVICE ALLEY", "sub": "Behind the Parlor", "at": Vector2(620, 495)},
	"morgue": {"name": "QUIAPO MORGUE", "sub": "Basement Cold Room", "at": Vector2(930, 540)},
}

const EDGES := [
	["parlor", "hidalgo"],
	["hidalgo", "quiapo_alley"],
	["quiapo_alley", "estero"],
	["estero", "pumphouse"],
	["hidalgo", "service_alley"],
	["service_alley", "morgue"],
]

var beat: Dictionary = {}
var fast := false

var _from_id := "hidalgo"
var _to_id := "estero"
var _path_pts: Array[Vector2] = []
var _progress := 0.0
var _duration := 2.0
var _done := false
var _t := 0.0
var _teo: Sprite2D
var _canvas: Control
var _banner: Label
var _sub: Label
var _hint: Label


func setup(p_beat: Dictionary) -> void:
	beat = p_beat
	_from_id = String(beat.get("from", "hidalgo"))
	_to_id = String(beat.get("to", "estero"))
	var via: Array = beat.get("via", [])
	_path_pts.clear()
	if NODES.has(_from_id):
		_path_pts.append(NODES[_from_id]["at"])
	for v in via:
		var vid := String(v)
		if NODES.has(vid):
			_path_pts.append(NODES[vid]["at"])
	if NODES.has(_to_id):
		_path_pts.append(NODES[_to_id]["at"])
	if _path_pts.size() < 2:
		_path_pts = [Vector2(460, 370), Vector2(855, 255)]
	_duration = 0.05 if fast else float(beat.get("duration", 1.9))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.045, 0.075, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_canvas = _DistrictCanvas.new()
	_canvas.owner_map = self
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)

	# 2D sprite for Teo walking along the district route.
	var strip_path := "res://assets/explore/teo_walk.png"
	var tex := load(strip_path) as Texture2D if ResourceLoader.exists(strip_path) else null
	if tex != null:
		var spr := Sprite2D.new()
		spr.name = "RouteTeo"
		spr.texture = tex
		spr.hframes = 12
		spr.frame = 4
		spr.scale = Vector2(2.2, 2.2)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = _path_pts[0]
		add_child(spr)
		_teo = spr

	var top := Retro.window(18, 12)
	top.position = Vector2(32, 24)
	top.custom_minimum_size = Vector2(540, 0)
	add_child(top)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	top.add_child(col)
	_banner = Retro.label(Fonts.label(), 22, Retro.NAME)
	var dest_name := String(NODES.get(_to_id, {}).get("name", _to_id.to_upper()))
	_banner.text = String(beat.get("title", "QUIAPO DISTRICT  ->  " + dest_name))
	col.add_child(_banner)
	_sub = Retro.label(Fonts.body_italic(), 17, Color(0.86, 0.9, 0.96, 0.85))
	_sub.text = String(beat.get("line", NODES.get(_to_id, {}).get("sub", "")))
	col.add_child(_sub)

	_hint = Retro.label(Fonts.label_medium(), 15, Color(1, 1, 1, 0.6))
	_hint.position = Vector2(36, 680)
	_hint.text = "WALKING ROUTE  ·  %s TO SKIP" % Story.accept_hint()
	add_child(_hint)

	if fast:
		_finish.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _done:
		return
	_progress = minf(1.0, _progress + delta / maxf(0.05, _duration))
	var pos := _sample_path(_progress)
	if _teo != null:
		var prev := _teo.position
		_teo.position = pos + Vector2(0, -18)
		var dx := pos.x - prev.x
		var dy := pos.y - prev.y
		var dir := 1 if absf(dx) >= absf(dy) else (0 if dy > 0.0 else 2)
		_teo.flip_h = dir == 1 and dx < 0.0
		_teo.frame = dir * 4 + (int(_t * 8.0) % 4)
	_canvas.queue_redraw()
	if _progress >= 1.0:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if Story.is_accept(event):
		get_viewport().set_input_as_handled()
		_finish()


func _sample_path(u: float) -> Vector2:
	if _path_pts.size() <= 1:
		return _path_pts[0] if not _path_pts.is_empty() else Vector2(640, 360)
	var segs := _path_pts.size() - 1
	var scaled := clampf(u, 0.0, 1.0) * float(segs)
	var idx := mini(segs - 1, int(floor(scaled)))
	var local := scaled - float(idx)
	return _path_pts[idx].lerp(_path_pts[idx + 1], local)


func _finish() -> void:
	if _done:
		return
	_done = true
	_progress = 1.0
	if _teo != null:
		_teo.position = _path_pts[_path_pts.size() - 1] + Vector2(0, -18)
	finished.emit()


class _DistrictCanvas extends Control:
	var owner_map: SectorMap

	func _draw() -> void:
		if owner_map == null:
			return
		var sz := size if size.x > 0.0 else Vector2(1280, 720)
		# Subtle blueprint grid lines.
		var grid_col := Color(0.14, 0.19, 0.28, 0.28)
		for gx in range(0, int(sz.x), 64):
			draw_line(Vector2(gx, 0), Vector2(gx, sz.y), grid_col, 1.0)
		for gy in range(0, int(sz.y), 64):
			draw_line(Vector2(0, gy), Vector2(sz.x, gy), grid_col, 1.0)

		# Estero canal curving across the north-east.
		var canal := PackedVector2Array([
			Vector2(760, 0), Vector2(815, 130), Vector2(855, 255),
			Vector2(925, 390), Vector2(1060, 560), Vector2(1180, 720)
		])
		draw_polyline(canal, Color(0.08, 0.22, 0.30, 0.65), 34.0, true)
		draw_polyline(canal, Color(0.20, 0.50, 0.62, 0.45), 10.0, true)

		# Inactive / curfew-locked district streets.
		for e in SectorMap.EDGES:
			var a: Vector2 = SectorMap.NODES[e[0]]["at"]
			var b: Vector2 = SectorMap.NODES[e[1]]["at"]
			draw_line(a, b, Color(0.24, 0.28, 0.38, 0.7), 6.0, true)

		# Active illuminated route.
		var pts := owner_map._path_pts
		for i in range(pts.size() - 1):
			draw_line(pts[i], pts[i + 1], Color("ffe08a"), 5.0, true)
			var cur_end := pts[i].lerp(pts[i + 1], clampf(owner_map._progress * float(pts.size() - 1) - float(i), 0.0, 1.0))
			draw_line(pts[i], cur_end, Color("7dffea"), 3.0, true)

		# District pins & labels.
		var font := Fonts.label_medium()
		for id in SectorMap.NODES:
			var n: Dictionary = SectorMap.NODES[id]
			var at: Vector2 = n["at"]
			var is_end: bool = String(id) == owner_map._to_id
			var is_start: bool = String(id) == owner_map._from_id
			var col := Color("ffe08a") if is_end else (Color("7dffea") if is_start else Color(0.45, 0.5, 0.62, 0.85))
			draw_circle(at, 11.0 if (is_end or is_start) else 7.0, Color(0.05, 0.07, 0.11))
			draw_arc(at, 11.0 if (is_end or is_start) else 7.0, 0.0, TAU, 24, col, 2.5, true)
			if is_end:
				var pulse := 14.0 + sin(owner_map._t * 6.0) * 4.0
				draw_arc(at, pulse, 0.0, TAU, 28, Color("ffe08a", 0.55), 2.0, true)
			var lbl := String(n["name"])
			draw_string(font, at + Vector2(-72, 28), lbl, HORIZONTAL_ALIGNMENT_CENTER, 144, 13, col)
