extends Control
## 전투 화면 위 표시 — 왼쪽 위: 조종 간부 이름 · 체력 · 체간 · 게이지(칸) · 고른 기술, 가운데 위: 양쪽 남은 머릿수 · 사기 · 남은 시간,
## 오른쪽 위: fps(1초마다 · 평균 · 최저), 가운데: 알림(시작 · 한 방 · 승패). 그리기만 한다 — 값은 fight_screen.gd 가 매 프레임 넣는다.
## 자리는 안전 영역(safe_area.gd) 기준 · 매 프레임 다시 읽는다(접는 폰). 색 · 글꼴은 테마(ui/theme.tres)에서 읽고, 없는 색 칸만 여기 상수.
## castle_M3D src/ui/hud.gd 와 같은 구실(message 는 event_fx.gd 가 부르는 이름 그대로). 설계: docs/C4_설계서_직접조작전투.md 6절 · 요구: FR-403

const SafeArea = preload("res://ui/fight3d/safe_area.gd")
const COL_BACK := Color(0.05, 0.06, 0.09, 0.6)
const COL_HP := Color(0.36, 0.8, 0.5)
const COL_HP_LOW := Color(0.9, 0.32, 0.26)
const COL_POSTURE := Color(0.95, 0.75, 0.3)
const COL_GAUGE := Color(0.45, 0.7, 1.0)
const COL_FOE := Color(0.86, 0.3, 0.26)
const COL_TEXT := Color(1, 1, 1, 0.95)
const COL_DIM := Color(1, 1, 1, 0.6)

var hero = null                     # 조종 간부(fight/fighter.gd) — 없으면 왼쪽 위를 그리지 않는다
var hero_name := ""
var heads := [0, 0]                 # [내 쪽, 상대] 남은 머릿수
var morale := [100, 100]
var secs_left := 0
var fps_text := ""
var auto := false
var bar_points := 100.0
var _msgs: Array = []               # [제목, 작은 글, 남은 초, 늦춤 초]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 가운데 알림 — event_fx.gd · fight_screen.gd 가 부른다
func message(text: String, small := "", secs := 2.0, delay := 0.0) -> void:
	_msgs.append([text, small, secs, delay])


func clear_messages() -> void:
	_msgs.clear()


func _process(dt: float) -> void:
	for m in _msgs:
		if m[3] > 0.0:
			m[3] -= dt
		else:
			m[2] -= dt
	_msgs = _msgs.filter(func(m): return m[2] > 0.0)
	queue_redraw()


func _bar(at: Vector2, w: float, h: float, k: float, col: Color) -> void:
	draw_rect(Rect2(at, Vector2(w, h)), COL_BACK)
	draw_rect(Rect2(at + Vector2(2, 2), Vector2(maxf(0.0, w - 4.0) * clampf(k, 0.0, 1.0), h - 4.0)), col)


func _text(at: Vector2, text: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	draw_string(get_theme_default_font(), at, text, align, w, size, col)


func _draw() -> void:
	var sa := SafeArea.rect(get_viewport())
	var x := sa.position.x + 24.0
	var y := sa.position.y + 20.0
	if hero != null:
		_text(Vector2(x, y + 26), hero_name + ("  · 자동" if auto else ""), 26, COL_TEXT)
		var k: float = hero.hp / maxf(1.0, hero.hp_max)
		_bar(Vector2(x, y + 38), 280, 22, k, COL_HP if k > 0.3 else COL_HP_LOW)
		_text(Vector2(x + 290, y + 56), "%d" % maxi(0, ceili(hero.hp)), 20, COL_DIM)
		_bar(Vector2(x, y + 64), 280, 10, hero.posture / maxf(1.0, hero.posture_max), COL_POSTURE)
		var bars := int(round(hero.gauge_max / maxf(1.0, bar_points)))
		for i in bars:
			_bar(Vector2(x + i * 28.0, y + 80), 25, 14, (hero.gauge - i * bar_points) / bar_points, COL_GAUGE)
		if not hero.skills.is_empty():
			var sk: Dictionary = hero.current_skill()
			_text(Vector2(x, y + 122), "기술  %s" % str(sk["name"]), 20, COL_TEXT if hero.can_pay(sk) else COL_DIM)
	var cx := sa.position.x + sa.size.x * 0.5
	_text(Vector2(cx - 230, y + 30), "우리 %d" % int(heads[0]), 30, COL_HP, HORIZONTAL_ALIGNMENT_RIGHT, 180)
	_text(Vector2(cx - 40, y + 30), "%d초" % maxi(0, secs_left), 24, COL_DIM, HORIZONTAL_ALIGNMENT_CENTER, 80)
	_text(Vector2(cx + 50, y + 30), "상대 %d" % int(heads[1]), 30, COL_FOE, HORIZONTAL_ALIGNMENT_LEFT, 180)
	_bar(Vector2(cx - 230, y + 40), 180, 8, float(morale[0]) / 100.0, COL_HP)
	_bar(Vector2(cx + 50, y + 40), 180, 8, float(morale[1]) / 100.0, COL_FOE)
	if fps_text != "":
		_text(Vector2(sa.end.x - 330, sa.end.y - 16), fps_text, 16, COL_DIM, HORIZONTAL_ALIGNMENT_RIGHT, 310)
	for m in _msgs:
		if m[3] > 0.0:
			continue
		_text(Vector2(sa.position.x, sa.position.y + sa.size.y * 0.36), str(m[0]), 64, COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER, sa.size.x)
		if str(m[1]) != "":
			_text(Vector2(sa.position.x, sa.position.y + sa.size.y * 0.36 + 44), str(m[1]), 26, COL_DIM, HORIZONTAL_ALIGNMENT_CENTER, sa.size.x)
		break
