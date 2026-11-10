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
