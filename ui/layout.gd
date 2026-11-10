extends RefCounted
## 화면 배치 계산 — 순수 함수: 창 픽셀의 안전 영역 → 기준 화면(canvas) 단위 여백, 넓은 화면(폴드 안쪽)인가.
## 접는 폰은 실행 중 크기 · 비율이 바뀌어서 ui/home.gd 가 크기가 바뀔 때마다 부른다(CLAUDE.md 4절 화면).
## 요구: FR-107 · 시험: tests/unit/test_layout.gd · insets_from 은 castle_M3D src/ui/safe_area.gd 를 옮겼다.

const WIDE_RATIO := 0.8          # 가로 ÷ 세로가 이보다 크면 넓은 화면(폴드 4 안쪽 약 6:5 = 0.83 · 커버 약 23:9 = 0.39)


## 창 픽셀 안전 영역 → 기준 화면 단위 여백 Vector4(왼, 위, 오른, 아래)
static func insets_from(view: Vector2, win_size: Vector2i, win_pos: Vector2i, safe: Rect2i) -> Vector4:
	if win_size.x <= 0 or win_size.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	var k := view.x / float(win_size.x)
	var l := maxf(0.0, safe.position.x - win_pos.x)
	var t := maxf(0.0, safe.position.y - win_pos.y)
	var r := maxf(0.0, (win_pos.x + win_size.x) - safe.end.x)
	var b := maxf(0.0, (win_pos.y + win_size.y) - safe.end.y)
	return Vector4(l, t, r, b) * k


static func is_wide(view: Vector2) -> bool:
	return view.y > 0.0 and view.x / view.y > WIDE_RATIO
