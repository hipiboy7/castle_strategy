extends RefCounted
## 화면 배치 계산 — 순수 함수: 창 픽셀의 안전 영역 → 기준 화면(canvas) 단위 여백, 넓은 화면(폴드 안쪽)인가, 틀 사각형(C2 frame).
## 접는 폰은 실행 중 크기 · 비율이 바뀌어서 ui/home.gd 가 크기가 바뀔 때마다 부른다(CLAUDE.md 4절 화면).
## 요구: FR-107 · FR-201 · 설계: docs/C2_설계서_화면과명령.md 3절 · 시험: tests/unit/test_layout.gd · insets_from 은 castle_M3D src/ui/safe_area.gd 를 옮겼다.

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


## 틀 사각형(기준 화면 단위) — 위 막대 / 몸통 / 간부 줄 / 행동 줄 / 아래 탭(엄지 영역). 넓으면 몸통 = 지도 + 옆 패널(간부 줄 늘 보임).
## m = 테마 Frame 상수(margin · gap · top_h · strip_h · actions_h · tabs_h · side_ratio · side_min · sheet_ratio).
## 돌려주는 것: {wide, top, body, map, map_above(카드가 열렸을 때 지도), side, sheet(좁으면 몸통 아래쪽 판 · 넓으면 옆 패널), strip, actions, tabs}
## — 없는 칸은 Rect2()
static func frame(view: Vector2, insets: Vector4, m: Dictionary, show_strip: bool) -> Dictionary:
	var wide := is_wide(view)
	var mg := float(m["margin"])
	var gap := float(m["gap"])
	var x := insets.x + mg
	var y := insets.y + mg
	var w := view.x - insets.x - insets.z - mg * 2.0
	var bottom := view.y - insets.w - mg
	var f := {"wide": wide, "side": Rect2(), "strip": Rect2()}
	f["top"] = Rect2(x, y, w, float(m["top_h"]))
	f["tabs"] = Rect2(x, bottom - float(m["tabs_h"]), w, float(m["tabs_h"]))
	f["actions"] = Rect2(x, f["tabs"].position.y - gap - float(m["actions_h"]), w, float(m["actions_h"]))
	var body_end: float = f["actions"].position.y - gap
	if wide or show_strip:
		f["strip"] = Rect2(x, body_end - float(m["strip_h"]), w, float(m["strip_h"]))
		body_end = f["strip"].position.y - gap
	var body_y: float = f["top"].end.y + gap
	f["body"] = Rect2(x, body_y, w, maxf(0.0, body_end - body_y))
	if wide:
		var side_w := maxf(float(m["side_min"]), w * float(m["side_ratio"]))
		f["side"] = Rect2(x + w - side_w, body_y, side_w, f["body"].size.y)
		f["map"] = Rect2(x, body_y, maxf(0.0, w - side_w - gap), f["body"].size.y)
		f["sheet"] = f["side"]
		f["map_above"] = f["map"]
	else:
		f["map"] = f["body"]
		var sh: float = f["body"].size.y * float(m["sheet_ratio"])
		f["sheet"] = Rect2(x, f["body"].end.y - sh, w, sh)
		f["map_above"] = Rect2(x, body_y, w, maxf(0.0, f["sheet"].position.y - gap - body_y))
	return f
