extends "res://tests/helpers.gd"
## FR-202 — 지도 계산(ui/map_layout.gd — 순수): 좌표 맞춤(비율 유지 · 가운데) · 노드 반지름 · 누르기 판정.

const MapLayout = preload("res://ui/map_layout.gd")

const COORDS := {"a": {"x": 0, "y": 0}, "b": {"x": 100, "y": 0}, "c": {"x": 100, "y": 50}, "far": {"x": 900, "y": 900}}


func test_fit_keeps_ratio_and_centers() -> void:
	var p: Dictionary = MapLayout.fit(COORDS, ["a", "b", "c"], Rect2(0, 0, 300, 300), 50)
	# 상자 100x50 → 칸 200x200 에 맞춤: 배율 2 · 가로 200 · 세로 100 → 세로 가운데(50 + 50)
	eq(p["a"], Vector2(50, 100), "왼위")
	eq(p["b"], Vector2(250, 100), "오른위")
	eq(p["c"], Vector2(250, 200), "오른아래")
	check(not p.has("far"), "고르지 않은 구역은 없다")


func test_fit_offset_rect_and_single() -> void:
	var p: Dictionary = MapLayout.fit(COORDS, ["far"], Rect2(10, 20, 200, 100), 10)
	eq(p["far"], Vector2(110, 70), "하나면 칸 가운데")
	var q: Dictionary = MapLayout.fit(COORDS, ["a", "b"], Rect2(10, 20, 200, 100), 0)
	eq(q["a"], Vector2(10, 70), "높이 0 상자 — 가로로만 맞추고 세로 가운데")
	eq(q["b"], Vector2(210, 70), "오른 끝")
	eq(MapLayout.fit(COORDS, [], Rect2(0, 0, 10, 10), 0), {}, "고른 것 없으면 빈 사전")
	eq(MapLayout.fit(COORDS, ["nope"], Rect2(0, 0, 10, 10), 0), {}, "좌표 없는 구역은 뺀다")


func test_radius_from_nearest_pair() -> void:
	var pts := {"a": Vector2(0, 0), "b": Vector2(100, 0), "c": Vector2(0, 400)}
	eq(MapLayout.radius(pts, 10.0, 80.0), 35.0, "가장 가까운 두 점 100 × 0.35")
	eq(MapLayout.radius(pts, 40.0, 80.0), 40.0, "최소")
	eq(MapLayout.radius({"a": Vector2(0, 0), "b": Vector2(1000, 0)}, 10.0, 80.0), 80.0, "최대")
	eq(MapLayout.radius({"a": Vector2(5, 5)}, 10.0, 80.0), 80.0, "하나면 최대")


func test_hit_nearest_inside() -> void:
	var pts := {"a": Vector2(0, 0), "b": Vector2(100, 0)}
	eq(MapLayout.hit(pts, Vector2(10, 5), 30.0), "a", "반지름 안 가까운 쪽")
	eq(MapLayout.hit(pts, Vector2(80, 0), 30.0), "b", "b 쪽")
	eq(MapLayout.hit(pts, Vector2(50, 0), 30.0), "", "둘 다 밖")
	eq(MapLayout.hit(pts, Vector2(50, 0), 50.0), "a", "거리가 같으면 id 앞")
