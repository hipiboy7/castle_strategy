extends "res://tests/helpers.gd"
## FR-113 — sim/tables.gd: JSON 사전 → 정적 표(읽기 전용) · id 검사(오류 목록) · replaced_by · resolve(시나리오별 parent · becomes).
## 가짜 표(작은 사전)로 갈래를 보고, 마지막에 받은 사본 전부로 오류 0 을 본다. 설계: docs/C1_설계서_상태와턴.md 1 · 5절

const Tables = preload("res://sim/tables.gd")
const DataFiles = preload("res://src/data_files.gd")
const Fixtures = preload("res://tests/fixtures.gd")


func test_build_fake_has_no_errors() -> void:
	var t: Dictionary = Tables.build(Fixtures.files())
	eq(t["errors"], [], "가짜 표는 오류 없음")
	eq(t["ranks"], ["건달급", "조장급", "네임드"], "사다리")
	eq(t["rank_no"]["네임드"], 2, "등급 번호")
	eq(t["trades"], ["상권", "유흥"], "업종")
	check(t["factions"].has("org_b") and t["districts"].has("z2") and t["scenarios"].has("A"), "id 로 찾는 표")
	eq(t["strat"]["boss_a"]["business"], 60, "전략 능력치는 정수로")
	check(t["rules"] != null and t["rules"].rank_index("조장급") == 1, "규칙 함수(rules_common)가 같은 사다리를 쓴다")


func test_tables_are_read_only() -> void:
	var t: Dictionary = Tables.build(Fixtures.files())
	check(t.is_read_only(), "맨 위 사전은 읽기 전용")
	check(t["factions"].is_read_only() and t["factions"]["org_a"].is_read_only(), "안쪽 사전도 읽기 전용")
	check(t["ranks"].is_read_only(), "안쪽 배열도 읽기 전용")


func test_replaced_by_follows_chain() -> void:
	var t: Dictionary = Tables.build(Fixtures.files())
	eq(Tables.current_id(t, "old_c"), "new_c", "인물 replaced_by")
	eq(Tables.current_id(t, "old_org"), "org_a", "조직 replaced_by")
	eq(Tables.current_id(t, "old_place"), "z1", "장소 replaced_by")
	eq(Tables.current_id(t, "boss_a"), "boss_a", "그대로인 id")
	var f := Fixtures.files()
	f["common/canon/characters.json"]["characters"].append({"id": "loop_a", "replaced_by": "loop_b"})
	f["common/canon/characters.json"]["characters"].append({"id": "loop_b", "replaced_by": "loop_a"})
	var t2: Dictionary = Tables.build(f)
	check(t2["errors"].any(func(e): return String(e).contains("loop_")), "replaced_by 고리는 오류")


func test_resolve_scenario_parent_and_becomes() -> void:
	var t: Dictionary = Tables.build(Fixtures.files())
	eq(Tables.resolve(t, "org_a", "A"), "org_a", "조직은 그대로")
	eq(Tables.resolve(t, "org_b", "B"), "org_a", "becomes[B]")
	eq(Tables.resolve(t, "u_sub", "A"), "org_b", "단위 → 부모(문자열)")
	eq(Tables.resolve(t, "u_sub", "B"), "org_a", "단위 → 부모 → becomes")
	eq(Tables.resolve(t, "u_local", "A"), "", "부모 사전의 시나리오 값 null = 무소속")
	eq(Tables.resolve(t, "u_local", "D"), "org_b", "부모 사전의 시나리오 값")
	eq(Tables.resolve(t, "u_local", "B"), "org_a", "부모 사전의 시나리오 값 → 그 조직의 becomes[B]")
	eq(Tables.resolve(t, "u_local", "C"), "org_a", "부모 사전의 '*' 기본")
	eq(Tables.resolve(t, null, "A"), "", "null = 무소속")
	eq(Tables.resolve(t, "없는_조직", "A"), "", "모르는 id = 무소속")


func test_hq_for_scenario() -> void:
	var t: Dictionary = Tables.build(Fixtures.files())
	eq(Tables.hq_of(t, "org_b", "A"), "z2", "default")
	eq(Tables.hq_of(t, "org_b", "B"), "", "시나리오 값 null = 본거지 없음")
	eq(Tables.hq_of(t, "없는_조직", "A"), "", "모르는 조직")


func test_id_checks_report_file_and_id() -> void:
	var f := Fixtures.files()
	f["common/packs/strategy/scenarios.json"]["scenarios"][0]["roster"].append({"id": "nobody", "faction": "ghost_org", "rank": "외계"})
	f["common/packs/strategy/scenarios.json"]["scenarios"][0]["assign"].append({"id": "stranger", "faction": "ghost_org"})
	f["common/packs/strategy/scenarios.json"]["scenarios"][0]["playable"].append("ghost_org")
	f["common/packs/strategy/districts.json"]["districts"][0]["owners"]["B"] = "ghost_org"
	f["common/packs/strategy/districts.json"]["districts"][0]["trades"].append("우주")
	f["common/packs/strategy/factions.json"]["factions"][0]["hq"]["C"] = "ghost_zone"
	f["common/packs/strategy/factions.json"]["factions"][0]["boss"] = "ghost_man"
	f["common/packs/strategy/factions.json"]["factions"][0]["aces"].append("ghost_man2")
	f["common/packs/strategy/factions.json"]["factions"][0]["trade"] = "우주"
	f["common/packs/strategy/factions.json"]["factions"][1]["elite"] = {"unit": "ghost_unit"}
	f["common/packs/strategy/factions.json"]["factions"][1]["becomes"]["C"] = "ghost_org"
	f["common/packs/strategy/factions.json"]["units"][0]["parent"] = {"A": "ghost_org"}
	f["common/packs/strategy/characters.json"]["characters"].append({"id": "ghost_strat", "stats": {}})
	var errs: Array = Tables.build(f)["errors"]
	var want := ["nobody", "ghost_org", "외계", "stranger", "우주", "ghost_zone", "ghost_man", "ghost_man2", "ghost_unit", "ghost_strat"]
	for w in want:
		check(errs.any(func(e): return String(e).contains(w)), "오류 목록에 %s" % w)
	check(errs.all(func(e): return String(e).contains(".json:")), "모든 오류는 '파일:id — 까닭' 꼴: %s" % [errs])


func test_missing_file_and_bad_shape_are_errors() -> void:
	var f := Fixtures.files()
	f.erase("common/packs/strategy/districts.json")
	f["common/packs/strategy/scenarios.json"] = {"없는 칸": []}
	var errs: Array = Tables.build(f)["errors"]
	check(errs.any(func(e): return String(e).contains("districts.json")), "없는 파일: %s" % [errs])
	check(errs.any(func(e): return String(e).contains("scenarios.json")), "모양이 틀린 파일: %s" % [errs])


## 받은 사본 전부 — 오류 0(verify 가 이 시험으로 본다). 시나리오 A 는 구역 4 · 명단 14
func test_received_copy_builds_clean() -> void:
	var r: Dictionary = DataFiles.read(Tables.NEEDS)
	eq(r["errors"], [], "필요한 파일이 모두 있다")
	var t: Dictionary = Tables.build(r["files"])
	eq(t["errors"], [], "받은 사본 id 검사 오류 0")
	eq(t["scenarios"]["A"]["roster"].size(), 14, "A 명단 14")
	eq(Tables.districts_in(t, "A"), ["bujindong", "bukgu", "hoeamsijang", "namgu"], "A 구역 4(id 순)")
	eq(Tables.resolve(t, "namgucheongnyeonhoe", "A"), "", "A 의 남구희망청년회는 무소속")
	eq(Tables.resolve(t, "namgucheongnyeonhoe", "B"), "bujinpa", "B 에서는 부진파")
	eq(Tables.current_id(t, "gimdaegeon"), "kimdaegeon", "canon replaced_by")
