extends "res://tests/helpers.gd"
## FR-216 — 지도 데이터(data/game/map.json — 3층 · 잠정) 대조: 팩 32구역 모두 좌표(0~1000 정수) · 땅길 대칭 · 중복 · 제 고리 없음 ·
## 바닷길은 항구끼리 · 국내 구역은 땅길로 서로 이어짐 · A 의 회암시 땅길 5개는 C1 그대로(기준 해시 — verify 자동 진행이 본다).
## 표에 canon 인물 이름(t["names"])이 있다(화면이 id 로 이름을 찾는다 — FR-215).

const DataFiles = preload("res://src/data_files.gd")
const Tables = preload("res://sim/tables.gd")

var _t: Dictionary = {}


func _tables() -> Dictionary:
	if _t.is_empty():
		_t = DataFiles.load_tables()
		check(_t["errors"].is_empty(), "표 오류 %s" % [_t["errors"]])
	return _t


func test_every_district_has_coords() -> void:
	var t := _tables()
	var mz: Dictionary = t["map"]["zones"]
	eq(mz.size(), t["districts"].size(), "지도 구역 수 = 팩 구역 수")
	for id in Tables.sorted_keys(t["districts"]):
		check(mz.has(id), "좌표 없음 %s" % id)
		if mz.has(id):
			for k in ["x", "y"]:
				check(typeof(mz[id][k]) == TYPE_INT and mz[id][k] >= 0 and mz[id][k] <= 1000, "%s.%s 0~1000 정수" % [id, k])


func test_links_clean() -> void:
	var t := _tables()
	for key in ["links", "sea"]:
		var seen := {}
		for pair in t["map"][key]:
			eq(pair.size(), 2, "%s 쌍" % key)
			check(pair[0] != pair[1], "%s 제 고리 %s" % [key, pair])
			var k := "%s|%s" % ([pair[0], pair[1]] if pair[0] < pair[1] else [pair[1], pair[0]])
			check(not seen.has(k), "%s 겹침 %s" % [key, k])
			seen[k] = true
			for z in pair:
				check(t["map"]["zones"].has(z), "%s 끝 %s 가 지도에 없다" % [key, z])
	for pair in t["map"]["sea"]:
		for z in pair:
			check(bool(t["districts"][z].get("port", false)), "바닷길 끝 %s 는 항구" % z)
	for z in t["neighbors"]:
		for nb in t["neighbors"][z]:
			check(t["neighbors"][nb].has(z), "땅길 대칭 %s ↔ %s" % [z, nb])


func test_domestic_connected() -> void:
	var t := _tables()
	var home := []
	for id in Tables.sorted_keys(t["districts"]):
		if not t["districts"][id].get("abroad", false):
			home.append(id)
	var seen := {home[0]: true}
	var todo := [home[0]]
	while not todo.is_empty():
		var z: String = todo.pop_back()
		for nb in Tables.neighbors(t, z):
			if not seen.has(nb):
				seen[nb] = true
				todo.append(nb)
	for id in home:
		check(seen.has(id), "국내 %s 가 땅길로 이어지지 않는다" % id)
	eq(home.size(), 22, "국내 22구역(08 3-4)")


func test_scenario_a_links_kept() -> void:
	var t := _tables()
	var want := {"bujindong": ["hoeamsijang", "namgu"], "namgu": ["bujindong", "bukgu", "hoeamsijang"],
		"bukgu": ["hoeamsijang", "namgu"], "hoeamsijang": ["bujindong", "bukgu", "namgu"]}
	for z in want:
		var inside: Array = Tables.neighbors(t, z).filter(func(nb): return want.has(nb))
		eq(inside, want[z], "회암시 안 땅길 %s(C1 그대로)" % z)


func test_names_from_canon() -> void:
	var t := _tables()
	eq(t["names"].get("kimshin", ""), "김신", "canon 인물 이름")
	eq(t["names"].size(), t["people"].size(), "이름 수 = canon 인물 수")
