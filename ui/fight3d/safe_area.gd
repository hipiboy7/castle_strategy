extends RefCounted
## [옮김] castle_M3D `src/ui/safe_area.gd`(2c3e69b) — 바꾼 것: 없음. 설계: docs/C4_설계서_직접조작전투.md 6절 · 요구: FR-403
## 안전 영역(노치 · 펀치홀 · 제스처 바를 뺀 자리, 개발 규격 게임개발규격 5절) — 화면 표시(hud.gd) · 터치(touch_ui.gd)가 매 프레임
## rect() 로 읽는다(접는 폰은 실행 중 화면이 바뀐다). Android 에서만 DisplayServer 값을 쓰고, PC 는 화면 전체.
## 시험 · 스크린샷: main.gd 실행 인자 --safe L,T,R,B(기준 화면 단위 여백)가 test_insets 를 채운다.

static var test_insets := Vector4.ZERO          # x 왼 · y 위 · z 오른 · w 아래 (기준 화면 단위)


## 창 픽셀의 안전 영역을 기준 화면(canvas) 단위 여백 [왼, 위, 오른, 아래]로 바꾼다 — 순수 함수(시험 tests/unit/test_ui_logic.gd)
static func insets_from(view: Vector2, win_size: Vector2i, win_pos: Vector2i, safe: Rect2i) -> Vector4:
	if win_size.x <= 0 or win_size.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	var k := view.x / float(win_size.x)
	var l := maxf(0.0, safe.position.x - win_pos.x)
	var t := maxf(0.0, safe.position.y - win_pos.y)
	var r := maxf(0.0, (win_pos.x + win_size.x) - safe.end.x)
	var b := maxf(0.0, (win_pos.y + win_size.y) - safe.end.y)
	return Vector4(l, t, r, b) * k


static func rect(vp: Viewport) -> Rect2:
	var view := vp.get_visible_rect().size
	var ins := test_insets
	if ins == Vector4.ZERO and OS.get_name() == "Android":
		ins = insets_from(view, DisplayServer.window_get_size(), DisplayServer.window_get_position(),
			DisplayServer.get_display_safe_area())
	return Rect2(ins.x, ins.y, maxf(1.0, view.x - ins.x - ins.z), maxf(1.0, view.y - ins.y - ins.w))
