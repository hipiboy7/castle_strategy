extends Control
## 지도 그리기 — 거리 격자 바닥 · 구역 패(세력색 + 세력 글자 · 이름판 · 경찰 압력 3칸 · 내 구역 금테) · 땅길 · 전선(붉은 빛) · 내 간부 얼굴 패 · 남의 간부 수 · 고른 구역 · 끌어 놓을 자리.
## 계산은 ui/map_layout.gd(맞춤 · 반지름 · 누르기)와 ui/view.gd(노드 · 전선 보기)가 하고, 이 장면은 그리고 누름 · 끌어 놓기를 올린다(ISP).
## 색 · 치수는 테마 Map · Faction(ui/theme.tres). 설계: docs/C2_설계서_화면과명령.md 3절 · 요구: FR-202 · FR-204

const MapLayout = preload("res://ui/map_layout.gd")

signal zone_pressed(zone: String)
signal officer_dropped(officer: String, zone: String)

var sprites = null                     # ui/sprites.gd
var me := ""                           # 내 조직 id — 내 구역은 금테 · 금 이름판
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
	_draw_ground()
	for p in _links:
		draw_line(_pts[p[0]], _pts[p[1]], _col("link_casing"), float(_c("line_w")) * 2.4, true)
	for p in _links:
		draw_line(_pts[p[0]], _pts[p[1]], _col("link"), float(_c("line_w")), true)
		_dashes(_pts[p[0]], _pts[p[1]], _col("link_hi"), 2.0, 14.0, 22.0)
	for p in _fronts:
		if _pts.has(p[0]) and _pts.has(p[1]):
			draw_line(_pts[p[0]], _pts[p[1]], _col("front_glow"), float(_c("front_w")) * 3.0, true)
			draw_line(_pts[p[0]], _pts[p[1]], _col("front"), float(_c("front_w")), true)
			_dashes(_pts[p[0]], _pts[p[1]], _col("select"), 3.0, 10.0, 26.0)
	for n in _nodes:
		var c: Vector2 = _pts.get(n["id"], Vector2(-1, -1))
		if c.x >= 0:
			_draw_node(n, c)


## 바닥 — 어두운 거리 격자(구역 사이 길 느낌) + 가장자리 그늘. 무늬는 칸 번호로만 정해 같은 화면이면 늘 같다.
func _draw_ground() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _col("bg"))
	var g := float(_c("grid"))
	var cols := int(size.x / g) + 2
	var rows := int(size.y / g) + 2
	for j in rows:
		for i in cols:
			var k := (i * 7 + j * 13) % 5
			var inset := 6.0 + float(k)
			var r := Rect2(Vector2(i * g + inset, j * g + inset), Vector2(g - inset * 2.0, g - inset * 2.0))
			if k != 0:
				draw_rect(r, _col("block"))
	for i in range(0, cols, 4):
		draw_line(Vector2(i * g, 0), Vector2(i * g, size.y), _col("street"), 3.0)
	for j in range(0, rows, 4):
		draw_line(Vector2(0, j * g), Vector2(size.x, j * g), _col("street"), 3.0)
	var v := _col("vignette")
	var edge := minf(size.x, size.y) * 0.18
	for k in 6:
		var a := v.a * (1.0 - k / 6.0) * 0.35
		var w := edge * (1.0 - k / 6.0)
		var cc := Color(v.r, v.g, v.b, a)
		draw_rect(Rect2(0, 0, size.x, w), cc)
		draw_rect(Rect2(0, size.y - w, size.x, w), cc)
		draw_rect(Rect2(0, 0, w, size.y), cc)
		draw_rect(Rect2(size.x - w, 0, w, size.y), cc)


func _dashes(a: Vector2, b: Vector2, col: Color, w: float, dash: float, gap: float) -> void:
	var d := b - a
	var dl := d.length()
	if dl <= 0.0:
		return
	var u := d / dl
	var t := _r * 0.9
	while t + dash < dl - _r * 0.9:
		draw_line(a + u * t, a + u * (t + dash), col, w, true)
		t += dash + gap


func _draw_node(n: Dictionary, c: Vector2) -> void:
	var name_fs := get_theme_font_size("name", "Map")
	var mark_fs := get_theme_font_size("mark", "Map")
	var small_fs := get_theme_font_size("small", "Map")
	var bold := get_theme_font("bold", "Map")
	var body := get_theme_font("body", "Map")
	var mine: bool = me != "" and n["owner"] == me
	var fc := _faction(n["owner"])
	draw_circle(c + Vector2(0, _r * 0.1), _r * 1.06, _col("node_shadow"))
	if n["id"] == selected or n["id"] == _hover:
		var ring := _col("select") if n["id"] == selected else _col("drop")
		draw_circle(c, _r * 1.32, _col("select_glow"))
		draw_arc(c, _r * 1.18, 0.0, TAU, 72, ring, float(_c("ring_w")), true)
	draw_circle(c, _r + 6.0, _col("mine_ring") if mine else _col("node_rim"))
	draw_circle(c, _r, fc.darkened(0.28))
	draw_circle(c + Vector2(-_r * 0.06, -_r * 0.08), _r * 0.9, fc)
	draw_circle(c + Vector2(-_r * 0.28, -_r * 0.32), _r * 0.42, _col("node_light"))
	draw_arc(c, _r * 0.78, PI * 0.15, PI * 0.85, 24, _col("node_dark"), _r * 0.12, true)
	draw_arc(c, _r * 0.74, 0.0, TAU, 64, Color(fc.darkened(0.45), 0.6), 2.0, true)
	draw_string(bold, c + Vector2(-_r, mark_fs * 0.36), n["mark"], HORIZONTAL_ALIGNMENT_CENTER, _r * 2.0, mark_fs, _col("mark"))
	# 이름 판
	var sb: StyleBox = get_theme_stylebox("plate_mine" if mine else "plate", "Map")
	var tw := body.get_string_size(n["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, name_fs).x
	var pr := Rect2(c + Vector2(-tw * 0.5 - sb.content_margin_left, _r + 14.0), Vector2(tw + sb.content_margin_left + sb.content_margin_right, name_fs * 1.3 + sb.content_margin_top + sb.content_margin_bottom))
	draw_style_box(sb, pr)
	draw_string(body, Vector2(pr.position.x + sb.content_margin_left, pr.position.y + sb.content_margin_top + name_fs * 1.02), n["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, name_fs, _col("text"))
	# 경찰 압력 3칸
	var pip := maxf(_r * 0.09, 6.0)
	for i in 3:
		var at := c + Vector2((i - 1) * pip * 2.8, -_r - pip - 14.0)
		draw_circle(at, pip + 2.0, _col("node_rim"))
		draw_circle(at, pip, _col("police_on") if i < int(n["police_lv"]) else _col("police_off"))
	# 내 간부 — 동그란 얼굴 패(구역 아래쪽에 가운데 맞춰 한 줄 · 세력 글자를 가리지 않게)
	var ids: Array = n["mine"]
	var tr := minf(float(_c("token_r")), _r * 0.42)
	var step := tr * 1.55
	var x := c.x - step * (ids.size() - 1) * 0.5
	for id in ids:
		var tc := Vector2(x, c.y + _r * 0.74)
		draw_circle(tc + Vector2(0, 3), tr + 4.0, _col("node_shadow"))
		draw_circle(tc, tr + 4.0, _col("token_ring"))
		draw_circle(tc, tr, _col("token_bg"))
		var tex: Texture2D = sprites.portrait(id) if sprites != null else null
		if tex != null:
			var side := tr * 1.42
			draw_texture_rect_region(tex, Rect2(tc - Vector2(side, side) * 0.5, Vector2(side, side)), sprites.HEAD_REGION)
		x += step
	if int(n["others"]) > 0:
		var txt := "남 %d" % int(n["others"])
		var w := body.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs).x + 20.0
		var br := Rect2(c + Vector2(-_r * 1.05 - w, -small_fs * 0.8), Vector2(w, small_fs * 1.5))
		draw_rect(br, _col("badge"))
		draw_rect(br, _col("front"), false, 2.0)
		draw_string(body, br.position + Vector2(10, small_fs * 1.08), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, _col("text"))


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
