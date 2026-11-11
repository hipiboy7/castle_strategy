extends Control
## 지도 그리기 — 구역 노드(세력색 + 세력 글자 · 이름 · 경찰 압력 3칸) · 땅길 · 전선 · 내 간부 서기 그림 · 남의 간부 수 · 고른 구역 · 끌어 놓을 자리.
## 계산은 ui/map_layout.gd(맞춤 · 반지름 · 누르기)와 ui/view.gd(노드 · 전선 보기)가 하고, 이 장면은 그리고 누름 · 끌어 놓기를 올린다(ISP).
## 색 · 치수는 테마 Map · Faction(ui/theme.tres). 설계: docs/C2_설계서_화면과명령.md 3절 · 요구: FR-202 · FR-204

const MapLayout = preload("res://ui/map_layout.gd")

signal zone_pressed(zone: String)
signal officer_dropped(officer: String, zone: String)

var sprites = null                     # ui/sprites.gd
var _coords: Dictionary = {}
var _nodes: Array = []
var _links: Array = []
var _fronts: Array = []
var _pts: Dictionary = {}
var _r := 80.0
var selected := ""
var _hover := ""
var _press_at := Vector2(-1, -1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(_fit)


## 보기를 받아 다시 그린다 — coords = map.json zones · links = 땅길 · nodes = View.map_nodes · fronts = View.fronts
func show_map(coords: Dictionary, links: Array, nodes: Array, fronts: Array) -> void:
	_coords = coords
	_nodes = nodes
	_fronts = fronts
	var ids := nodes.map(func(n): return n["id"])
	_links = links.filter(func(p): return ids.has(p[0]) and ids.has(p[1]))
	_fit()


func _fit() -> void:
	var ids := _nodes.map(func(n): return n["id"])
	var rect := Rect2(Vector2.ZERO, size)
	var r_min := float(_c("node_r_min"))
	var r_max := float(_c("node_r_max"))
	_pts = MapLayout.fit(_coords, ids, rect, float(_c("pad")))
	_r = MapLayout.radius(_pts, r_min, r_max)
	# 둘레를 반지름 + 이름 줄만큼 다시 잡아 맞춘다(작은 지도 칸에서 이름 · 경찰 칸이 잘리지 않게)
	var pad := maxf(float(_c("pad")), _r + get_theme_font_size("name", "Map") * 1.4 + 12.0)
	_pts = MapLayout.fit(_coords, ids, rect, pad)
	_r = minf(_r, MapLayout.radius(_pts, r_min, r_max))
	queue_redraw()


## 구역 가운데(지도 안 좌표) — 없으면 (-1, -1)
func zone_center(zone: String) -> Vector2:
	return _pts.get(zone, Vector2(-1, -1))


func _c(name: String) -> int:
	return get_theme_constant(name, "Map")


func _col(name: String) -> Color:
	return get_theme_color(name, "Map")


func _faction(org: String) -> Color:
	if org == "":
		return get_theme_color("none", "Faction")
	return get_theme_color(org, "Faction") if has_theme_color(org, "Faction") else get_theme_color("default", "Faction")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _col("bg"))
	var font := get_theme_default_font()
	for p in _links:
		draw_line(_pts[p[0]], _pts[p[1]], _col("link"), float(_c("line_w")), true)
	for p in _fronts:
		if _pts.has(p[0]) and _pts.has(p[1]):
			draw_line(_pts[p[0]], _pts[p[1]], _col("front"), float(_c("front_w")), true)
	var name_fs := get_theme_font_size("name", "Map")
	var mark_fs := get_theme_font_size("mark", "Map")
	var small_fs := get_theme_font_size("small", "Map")
	for n in _nodes:
		var c: Vector2 = _pts.get(n["id"], Vector2(-1, -1))
		if c.x < 0:
			continue
		draw_circle(c, _r, _faction(n["owner"]))
		var ring := _col("select") if n["id"] == selected else (_col("drop") if n["id"] == _hover else Color(0, 0, 0, 0))
		if ring.a > 0.0:
			draw_arc(c, _r + float(_c("ring_w")), 0.0, TAU, 64, ring, float(_c("ring_w")) * 1.5, true)
		draw_string(font, c + Vector2(-_r, mark_fs * 0.35), n["mark"], HORIZONTAL_ALIGNMENT_CENTER, _r * 2.0, mark_fs, _col("mark"))
		draw_string(font, c + Vector2(-_r * 2.0, _r + name_fs + 6.0), n["name"], HORIZONTAL_ALIGNMENT_CENTER, _r * 4.0, name_fs, _col("text"))
		var pip := Vector2(_r * 0.28, _r * 0.12)
		for i in 3:
			var at := c + Vector2(-pip.x * 1.65 + i * pip.x * 1.1, -_r - pip.y - 10.0)
			draw_rect(Rect2(at, pip), _col("police_on") if i < int(n["police_lv"]) else _col("police_off"))
		var k := float(_c("fig_scale"))
		var x := c.x + _r * 0.55
		for id in n["mine"]:
			var tex: Texture2D = sprites.figure(id) if sprites != null else null
			var sz := Vector2(24, 32) * k
			var at := Vector2(x, c.y + _r * 0.2 - sz.y * 0.5)
			if tex != null:
				draw_texture_rect(tex, Rect2(at, sz), false)
			else:
				draw_rect(Rect2(at + Vector2(sz.x * 0.2, sz.y * 0.3), sz * Vector2(0.6, 0.7)), _col("select"))
			x += sz.x * 0.6
		if int(n["others"]) > 0:
			draw_string(font, c + Vector2(-_r * 1.6, _r * 0.15), "남 %d" % int(n["others"]), HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, _col("text"))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_at = event.position
		elif _press_at.x >= 0.0 and event.position.distance_to(_press_at) < _r:
			var z := MapLayout.hit(_pts, event.position, _r * 1.25)
			_press_at = Vector2(-1, -1)
			if z != "":
				zone_pressed.emit(z)
				accept_event()


func _can_drop_data(at: Vector2, data) -> bool:
	var z := ""
	if data is Dictionary and data.has("officer"):
		z = MapLayout.hit(_pts, at, _r * 1.4)
	if z != _hover:
		_hover = z
		queue_redraw()
	return z != ""


func _drop_data(at: Vector2, data) -> void:
	var z := MapLayout.hit(_pts, at, _r * 1.4)
	_hover = ""
	queue_redraw()
	if z != "":
		officer_dropped.emit(String(data["officer"]), z)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _hover != "":
		_hover = ""
		queue_redraw()
