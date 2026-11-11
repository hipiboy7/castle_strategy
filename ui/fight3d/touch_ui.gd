extends Control
## [옮김] castle_M3D `src/ui/touch_ui.gd`(2c3e69b) — 바꾼 것: 경로. 설계: docs/C4_설계서_직접조작전투.md 6절 · 요구: FR-403
## 터치 조작 — 왼쪽 절반 어디든 누르면 그 자리가 스틱 가운데(따라오는 스틱), 오른쪽 아래 버튼: 베기 · 쳐내기(누르고 있기) · 구르기 ·
## 기술 · 기술 바꾸기(고른 기술 이름 · 게이지는 hud.gd), 오른쪽 위 '멈춤' · 그 밑 '속도'(×1 · ×1.5 · ×2) · 왼쪽 옆 '메뉴'(스테이지 고르기 — 셋 다 결투 중에만, main.gd show_pause).
## 자리는 안전 영역(src/ui/safe_area.gd — 노치 · 제스처 바를 뺀 곳) 기준, 매 프레임 다시 읽는다(접는 폰).
## main.gd 가 매 프레임 stick · take_edges() · held() 로 읽는다(키보드와 같은 동작 이름 — castle_M engine/input.py 와 같은 생각).

const COL_RING := Color(1, 1, 1, 0.28)
const COL_KNOB := Color(1, 1, 1, 0.45)
const COL_BTN := Color(0.05, 0.06, 0.09, 0.55)
const COL_BTN_ON := Color(0.95, 0.8, 0.35, 0.6)
const COL_LABEL := Color(1, 1, 1, 0.9)
const STICK_R := 110.0
const SafeArea = preload("res://ui/fight3d/safe_area.gd")

var stick := Vector2.ZERO
var _stick_idx := -1
var _center := Vector2.ZERO
var _knob := Vector2.ZERO
var _pressed := {}
var _edges := {}
var show_pause := false:
	set(v):
		show_pause = v
		queue_redraw()
var show_swap := false:
	set(v):
		show_swap = v
		queue_redraw()
var show_fight := true:         # 싸움 버튼(베기 · 쳐내기 · 구르기 · 기술 · 바꾸기) — 처음 화면에서는 숨긴다
	set(v):
		show_fight = v
		queue_redraw()
var show_art := false:
	set(v):
		show_art = v
		queue_redraw()
var last_tap := Vector2(-1, -1)  # 마지막으로 누른 자리(처음 화면에서 왼쪽 · 오른쪽 고르기)
var _last_safe := Rect2()
# at: "br" 안전 영역 오른쪽 아래 기준(기본) · "tr" 오른쪽 위 기준. pause 는 show_pause 일 때만 보이고 눌린다
var buttons := [
	{"id": "attack", "label": "베기", "r": 82.0, "off": Vector2(-150, -150)},
	{"id": "parry", "label": "쳐내기", "r": 64.0, "off": Vector2(-300, -100)},
	{"id": "roll", "label": "구르기", "r": 64.0, "off": Vector2(-120, -320)},
	{"id": "skill", "label": "기술", "r": 60.0, "off": Vector2(-300, -270)},
	{"id": "skill_next", "label": "바꾸기", "r": 44.0, "off": Vector2(-440, -330)},
	{"id": "dash", "label": "대시", "r": 52.0, "off": Vector2(-450, -70)},      # 대시 + 베기 = 대시기(rc.2 폰 묶음 B)
	{"id": "pause", "label": "멈춤", "r": 34.0, "off": Vector2(-56, 92), "at": "tr"},
	{"id": "speed", "label": "×1", "r": 34.0, "off": Vector2(-56, 180), "at": "tr"},
	{"id": "menu", "label": "메뉴", "r": 34.0, "off": Vector2(-144, 92), "at": "tr"},
	{"id": "swap", "label": "교대", "r": 44.0, "off": Vector2(-450, -190)},
	{"id": "art", "label": "그림", "r": 44.0, "off": Vector2(70, 200), "at": "tl"},
	{"id": "bench", "label": "성능", "r": 44.0, "off": Vector2(70, 310), "at": "tl"},
	{"id": "difficulty", "label": "보통", "sub": "난이도", "r": 44.0, "off": Vector2(70, 420), "at": "tl"},   # 글은 main.gd 가 고른 난이도로
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_dt: float) -> void:
	var sa := SafeArea.rect(get_viewport())
	if sa != _last_safe:
		_last_safe = sa
		queue_redraw()


func _btn_pos(b: Dictionary) -> Vector2:
	var sa := SafeArea.rect(get_viewport())
	if b.get("at", "br") == "tr":
		return Vector2(sa.end.x, sa.position.y) + b["off"]
	if b.get("at", "br") == "tl":
		return sa.position + b["off"]
	return sa.end + b["off"]


func _active(b: Dictionary) -> bool:
	match str(b["id"]):
		"pause", "speed", "menu":
			return show_pause
		"swap":
			return show_swap
		"art", "bench", "difficulty":
			return show_art
	return show_fight


func _input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			last_tap = e.position
			_edges["tap"] = true
			var hit := false
			for b in buttons:
				if _active(b) and e.position.distance_to(_btn_pos(b)) <= b["r"] * 1.3:
					_pressed[b["id"]] = e.index
					_edges[b["id"]] = true
					hit = true
			var sa := SafeArea.rect(get_viewport())
			if not hit and e.position.x < sa.position.x + sa.size.x * 0.5 and _stick_idx == -1:
				_stick_idx = e.index
				_edges["stick"] = true                  # 새로 누름(멈춤 풀기에 쓴다)
				_center = e.position
				_knob = e.position
				stick = Vector2.ZERO
		else:
			if e.index == _stick_idx:
				_stick_idx = -1
				stick = Vector2.ZERO
			for id in _pressed.keys():
				if _pressed[id] == e.index:
					_pressed.erase(id)
		queue_redraw()
	elif e is InputEventScreenDrag and e.index == _stick_idx:
		var d: Vector2 = e.position - _center
		if d.length() > STICK_R:
			_center += d.normalized() * (d.length() - STICK_R)
			d = e.position - _center
		_knob = e.position
		stick = d / STICK_R
		queue_redraw()


func take_edges() -> Dictionary:
	var e := _edges
	_edges = {}
	return e


func peek_edge(id: String) -> bool:
	return _edges.has(id)


## 한 버튼의 누름만 가져간다(같은 프레임의 다른 누름 — 베기 등 — 은 남긴다)
func take_edge(id: String) -> bool:
	return _edges.erase(id)


## 속도 버튼 글(×1 · ×1.5 · ×2 — main.gd 가 고를 때마다)
func set_speed_label(t: String) -> void:
	set_label("speed", t)


## 버튼 글 바꾸기(속도 · 공격 — 칼이면 '베기', 맨손이면 '치기': main.gd 가 조작하는 사람이 바뀔 때)
func set_label(id: String, t: String) -> void:
	for b in buttons:
		if b["id"] == id and b["label"] != t:
			b["label"] = t
			queue_redraw()


func held(id: String) -> bool:
	return _pressed.has(id)


func any_touch() -> bool:
	return not _pressed.is_empty() or _stick_idx != -1


func _draw() -> void:
	var font := get_theme_default_font()
	if not show_fight:
		pass
	elif _stick_idx != -1:
		draw_arc(_center, STICK_R, 0, TAU, 48, COL_RING, 4.0)
		draw_circle(_knob, 44.0, COL_KNOB)
	else:
		var sa := SafeArea.rect(get_viewport())
		var c := Vector2(sa.position.x + 190, sa.end.y - 190)
		draw_arc(c, STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.14), 3.0)
		draw_string(font, c + Vector2(-46, 8), "이동", HORIZONTAL_ALIGNMENT_CENTER, 92, 24, Color(1, 1, 1, 0.35))
	for b in buttons:
		if not _active(b):
			continue
		var p := _btn_pos(b)
		var on := _pressed.has(b["id"])
		draw_circle(p, b["r"], COL_BTN_ON if on else COL_BTN)
		draw_arc(p, b["r"], 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		var w: float = b["r"] * 2.0
		if b.has("sub"):                                # 작은 이름(위) + 지금 값(아래) — 난이도
			draw_string(font, p + Vector2(-b["r"], -8), b["sub"], HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color(COL_LABEL, 0.7))
			draw_string(font, p + Vector2(-b["r"], 20), b["label"], HORIZONTAL_ALIGNMENT_CENTER, w, 22, COL_LABEL)
			continue
		draw_string(font, p + Vector2(-b["r"], 9), b["label"], HORIZONTAL_ALIGNMENT_CENTER, w, 22 if b["r"] < 40.0 else 26, COL_LABEL)
