extends "res://tests/helpers.gd"
## FR-107 — 화면 배치 계산(ui/layout.gd — 순수 함수): 창 픽셀 안전 영역 → 기준 화면 단위 여백 · 넓은 화면(폴드 안쪽) 판정.

const Layout = preload("res://ui/layout.gd")


func test_no_cutout_no_insets() -> void:
	eq(Layout.insets_from(Vector2(1080, 1920), Vector2i(1080, 1920), Vector2i(0, 0), Rect2i(0, 0, 1080, 1920)),
		Vector4.ZERO, "가린 곳이 없으면 여백 0")


func test_insets_scaled_to_canvas() -> void:
	# 창 540x960(기준의 절반) · 위 40px · 아래 20px 가림 → 기준 화면 단위로 두 배
	var ins: Vector4 = Layout.insets_from(Vector2(1080, 1920), Vector2i(540, 960), Vector2i(0, 0), Rect2i(0, 40, 540, 900))
	eq(ins, Vector4(0, 80, 0, 40), "여백을 기준 화면 단위로")


func test_invalid_sizes() -> void:
	eq(Layout.insets_from(Vector2(1080, 1920), Vector2i(0, 0), Vector2i(0, 0), Rect2i(0, 0, 0, 0)), Vector4.ZERO, "크기 0 은 여백 0")


func test_wide_screen() -> void:
	check(Layout.is_wide(Vector2(1812, 2176)), "폴드 안쪽(약 6:5)은 넓은 화면")
	check(not Layout.is_wide(Vector2(904, 2316)), "폴드 커버(약 23:9)는 좁은 화면")
	check(not Layout.is_wide(Vector2(1080, 1920)), "기준 9:16 은 좁은 화면")
	check(not Layout.is_wide(Vector2(100, 0)), "높이 0 은 좁은 화면")


## FR-201 — 틀 사각형(Layout.frame): 좁음 = 위 막대 / 몸통(지도) / 간부 줄 / 행동 줄 / 탭 · 넓음 = 몸통을 지도 + 옆 패널로
const M := {"margin": 20, "gap": 10, "top_h": 100, "strip_h": 200, "actions_h": 150, "tabs_h": 140,
	"side_ratio": 0.4, "side_min": 500, "sheet_ratio": 0.55}


func test_frame_narrow_stack() -> void:
	var f: Dictionary = Layout.frame(Vector2(1080, 1920), Vector4.ZERO, M, true)
	check(not f["wide"], "9:16 은 좁음")
	eq(f["top"], Rect2(20, 20, 1040, 100), "위 막대")
	eq(f["tabs"], Rect2(20, 1760, 1040, 140), "아래 탭은 맨 아래(엄지 영역)")
	eq(f["actions"], Rect2(20, 1600, 1040, 150), "행동 줄은 탭 바로 위")
	eq(f["strip"], Rect2(20, 1390, 1040, 200), "간부 줄은 행동 줄 위")
	eq(f["body"], Rect2(20, 130, 1040, 1250), "몸통은 남은 자리")
	eq(f["map"], f["body"], "좁으면 지도 = 몸통")
	eq(f["side"], Rect2(), "좁으면 옆 패널 없음")
	eq(f["sheet"], Rect2(20, 130 + 1250 - 687.5, 1040, 687.5), "카드 판은 몸통 아래쪽 55%")
	eq(f["map_above"], Rect2(20, 130, 1040, 1250 - 687.5 - 10), "카드가 열리면 지도는 카드 위로 맞춘다")


func test_frame_narrow_without_strip() -> void:
	var f: Dictionary = Layout.frame(Vector2(1080, 1920), Vector4.ZERO, M, false)
	eq(f["strip"], Rect2(), "간부 줄을 안 보이면 빈 사각형")
	eq(f["body"], Rect2(20, 130, 1040, 1460), "몸통이 간부 줄 자리까지")


func test_frame_wide_split() -> void:
	var f: Dictionary = Layout.frame(Vector2(1600, 1920), Vector4.ZERO, M, false)
	check(f["wide"], "6:5 쪽(0.83)은 넓음")
	eq(f["strip"].size.y, 200.0, "넓으면 지도가 늘 보여 간부 줄도 늘 있다")
	var side_w := 0.4 * (1600 - 40)
	eq(f["side"], Rect2(1580 - side_w, f["body"].position.y, side_w, f["body"].size.y), "옆 패널은 오른쪽 40%")
	eq(f["map"].size.x, 1560 - side_w - 10, "지도는 왼쪽 나머지(사이 gap)")
	eq(f["sheet"], f["side"], "넓으면 카드 판 = 옆 패널")
	eq(f["map_above"], f["map"], "넓으면 카드가 지도를 가리지 않는다")


func test_frame_side_min_and_insets() -> void:
	var f: Dictionary = Layout.frame(Vector2(1300, 1500), Vector4(30, 60, 0, 40), M, true)
	check(f["wide"], "1300x1500 은 넓음")
	eq(f["side"].size.x, 500.0, "옆 패널 최소 넓이")
	eq(f["top"].position, Vector2(50, 80), "안전 영역 + 여백")
	eq(f["tabs"].end.y, 1500.0 - 40 - 20, "아래 가림 + 여백")
