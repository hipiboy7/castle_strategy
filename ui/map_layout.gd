extends RefCounted
## 지도 계산 — 순수 함수(노드 · 텍스처 없음): 구역 좌표(data/game/map.json 0~1000)를 지도 칸에 맞추고(비율 유지 · 가운데),
## 노드 반지름을 가장 가까운 두 구역 사이로 정하고, 누른 자리에서 구역을 찾는다. ui/map_view.gd 가 그릴 때 · 끌어 놓을 때 부른다.
## 설계: docs/C2_설계서_화면과명령.md 1 · 3절 · 요구: FR-202 · 시험: tests/unit/test_map_layout.gd

const RADIUS_K := 0.35          # 가장 가까운 두 노드 사이 거리 × 이 값 = 반지름(겹치지 않게)


## ids 의 좌표를 rect 안(둘레 pad)에 맞춘 화면 좌표 {id: Vector2} — 좌표 없는 id 는 뺀다
static func fit(coords: Dictionary, ids: Array, rect: Rect2, pad: float) -> Dictionary:
	var pts := {}
	var have := ids.filter(func(id): return coords.has(id))
	if have.is_empty():
		return pts
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for id in have:
		var p := Vector2(float(coords[id]["x"]), float(coords[id]["y"]))
		lo = lo.min(p)
		hi = hi.max(p)
	var inner := Rect2(rect.position + Vector2(pad, pad), rect.size - Vector2(pad, pad) * 2.0)
	var box := hi - lo
	var k := INF
	if box.x > 0.0:
		k = inner.size.x / box.x
	if box.y > 0.0:
		k = minf(k, inner.size.y / box.y)
	if k == INF:
		k = 0.0
	var off := inner.position + (inner.size - box * k) / 2.0
	for id in have:
		var p := Vector2(float(coords[id]["x"]), float(coords[id]["y"]))
		pts[id] = off + (p - lo) * k
	return pts


## 노드 반지름 — 가장 가까운 두 점 거리 × RADIUS_K 를 [r_min, r_max] 로(점이 하나면 r_max)
static func radius(pts: Dictionary, r_min: float, r_max: float) -> float:
	var ids := pts.keys()
	var best := INF
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			best = minf(best, (pts[ids[i]] as Vector2).distance_to(pts[ids[j]]))
	if best == INF:
		return r_max
	return clampf(best * RADIUS_K, r_min, r_max)


## pos 에서 r 안의 가장 가까운 구역(같으면 id 앞) — 없으면 ""
static func hit(pts: Dictionary, pos: Vector2, r: float) -> String:
	var ids := pts.keys()
	ids.sort()
	var pick := ""
	var best := INF
	for id in ids:
		var d := pos.distance_to(pts[id])
		if d <= r and d < best:
			best = d
			pick = id
	return pick
