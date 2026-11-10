extends "res://tests/helpers.gd"
## FR-114 — sim/state.gd: GameState v1 스키마(설계서 3-3) · 정수만 · to_dict/from_dict · 해시 · 불변식.
## 표는 tests/fixtures.gd 의 가짜 판(조직 org_a · org_b · 구역 z1 · z2 · 인물 boss_a · man_b · new_c)을 쓴다.

const State = preload("res://sim/state.gd")
const Tables = preload("res://sim/tables.gd")
const StateHash = preload("res://sim/hash.gd")
const Fixtures = preload("res://tests/fixtures.gd")


func _tables() -> Dictionary:
	return Tables.build(Fixtures.files())


## 조직 하나 · 간부 둘 · 구역 둘(하나는 주인 없음)인 작은 상태
func _small() -> Dictionary:
	var s := State.new_state(7, "A", "org_a")
	s["orgs"]["org_a"] = State.new_org("boss_a", "z1")
	s["orgs"]["org_a"]["cash"] = 300
	s["orgs"]["org_a"]["troops"]["건달급"] = 20
	s["officers"]["boss_a"] = State.new_officer("org_a", "z1", "네임드")
	s["officers"]["boss_a"]["post"] = "boss"
	s["officers"]["man_b"] = State.new_officer("org_a", "z1", "조장급")
	s["zones"]["z1"] = State.new_zone("org_a")
	s["zones"]["z1"]["slots"] = [{"kind": "상권", "org": "org_a", "lv": 1, "dmg": 0}, {"kind": "상권", "org": "", "lv": 0, "dmg": 0}]
	s["zones"]["z2"] = State.new_zone("")
	return s


func test_new_state_schema() -> void:
	var s := State.new_state(7, "A", "org_a")
	for k in State.TOP_KEYS:
		check(s.has(k), "최상위 칸 %s" % k)
	eq(s["v"], State.VERSION, "형식 번호")
	eq(s["turn"], 1, "처음 턴")
	eq(s["mode"], "canon", "기본 모드")
	eq(s["length"], 26, "기본 판 길이")
	eq(s["castle"]["stakes"], {}, "지분은 비어 있다")
	var o := State.new_org("boss_a", "z1")
	for k in State.ORG_KEYS:
		check(o.has(k), "조직 칸 %s" % k)
	eq(o["troops"].keys(), ["건달급", "조장급", "네임드", "경호대급"], "조직원 등급 넷(08 3-3)")
	eq(o["hq_lost_turn"], -1, "본거지 잃은 턴 없음")
	var p := State.new_officer("org_a", "z1", "조장급")
	for k in State.OFFICER_KEYS:
		check(p.has(k), "간부 칸 %s" % k)
	eq(p["status"], "active", "처음 상태")
	var z := State.new_zone("")
	for k in State.ZONE_KEYS:
		check(z.has(k), "구역 칸 %s" % k)
	eq(z["flow"], 10000, "유동 1.00배 = 10000")


func test_small_state_passes_invariants() -> void:
	eq(State.check_invariants(_small(), _tables()), [], "작은 상태는 불변식 통과")


func test_negative_cash_is_allowed() -> void:
	var s := _small()
	s["orgs"]["org_a"]["cash"] = -50
	eq(State.check_invariants(s, _tables()), [], "돈은 음수를 허용한다(08 3-1 · 설계서 7절)")


func test_invariant_violations_are_reported() -> void:
	var t := _tables()
	var cases := {
		"머릿수": func(s): s["orgs"]["org_a"]["troops"]["건달급"] = -1,
		"정예": func(s): s["orgs"]["org_a"]["elite"]["n"] = -2,
		"열기": func(s): s["orgs"]["org_a"]["heat"] = 10001,
		"충성": func(s): s["officers"]["man_b"]["loyalty"] = -1,
		"경찰": func(s): s["zones"]["z2"]["police"] = 20000,
		"상납": func(s): s["orgs"]["org_a"]["tribute_bp"] = 10001,
		"지분": func(s): s["castle"]["stakes"] = {"org_a": 6000, "org_b": 3000},
		"주인": func(s): s["zones"]["z2"]["owner"] = "org_b",
		"죽은 두목": func(s): s["officers"]["boss_a"]["status"] = "dead",
		"칸 주인": func(s): s["zones"]["z1"]["slots"][1]["org"] = "ghost",
		"칸 레벨": func(s): s["zones"]["z1"]["slots"][0]["lv"] = 4,
		"모르는 인물": func(s): s["officers"]["ghost_man"] = State.new_officer("org_a", "z1", "조장급"),
		"모르는 조직": func(s): s["orgs"]["ghost_org"] = State.new_org("", ""),
		"모르는 구역": func(s): s["zones"]["ghost_zone"] = State.new_zone(""),
		"모르는 등급": func(s): s["officers"]["man_b"]["rank"] = "외계",
		"간부 소속": func(s): s["officers"]["man_b"]["org"] = "org_b",
		"간부 자리": func(s): s["officers"]["man_b"]["zone"] = "ghost_zone",
		"상태 값": func(s): s["officers"]["man_b"]["status"] = "sleeping",
		"자리 값": func(s): s["officers"]["man_b"]["post"] = "king",
		"실수": func(s): s["orgs"]["org_a"]["cash"] = 1.5,
	}
	for name in cases:
		var s := _small()
		cases[name].call(s)
		var errs: Array = State.check_invariants(s, t)
		check(not errs.is_empty(), "%s 위반을 잡는다" % name)


func test_stakes_sum_10000_ok() -> void:
	var s := _small()
	s["orgs"]["org_b"] = State.new_org("man_b", "z2")
	s["castle"]["stakes"] = {"org_a": 6000, "org_b": 4000}
	eq(State.check_invariants(s, _tables()), [], "지분 합 10000")


func test_to_dict_is_deep_copy() -> void:
	var s := _small()
	var d := State.to_dict(s)
	d["orgs"]["org_a"]["cash"] = 1
	eq(s["orgs"]["org_a"]["cash"], 300, "to_dict 는 깊은 복사")


## 저장 글(JSON)을 거치면 수가 실수로 온다 — from_dict 가 정수로 되돌리고 해시가 같다
func test_json_round_trip_same_hash() -> void:
	var s := _small()
	s["orgs"]["org_a"]["cash"] = -42
	var back: Dictionary = State.from_dict(JSON.parse_string(JSON.stringify(State.to_dict(s))))
	eq(back["errors"], [], "되읽기 오류 없음")
	eq(State.hash_of(back["state"]), State.hash_of(s), "같은 해시")
	eq(typeof(back["state"]["zones"]["z1"]["slots"][0]["lv"]), TYPE_INT, "배열 안 수도 정수")


func test_from_dict_rejects_bad_input() -> void:
	check(not State.from_dict("글").get("errors", []).is_empty(), "사전이 아니면 오류")
	var d := State.to_dict(_small())
	d.erase("zones")
	check(not State.from_dict(d)["errors"].is_empty(), "최상위 칸이 모자라면 오류")
	var d2 := State.to_dict(_small())
	d2["orgs"]["org_a"].erase("cash")
	check(not State.from_dict(d2)["errors"].is_empty(), "조직 칸이 모자라면 오류")
	var d3 := State.to_dict(_small())
	d3["orgs"]["org_a"]["cash"] = 2.5
	check(not State.from_dict(d3)["errors"].is_empty(), "정수가 아닌 수는 오류")
	var d4 := State.to_dict(_small())
	d4["v"] = 99
	check(not State.from_dict(d4)["errors"].is_empty(), "모르는 형식 번호는 오류")


func test_hash_is_key_order_free_and_rejects_floats() -> void:
	var a := _small()
	var b := {}
	var keys := a.keys()
	keys.reverse()
	for k in keys:
		b[k] = a[k]
	eq(State.hash_of(a), State.hash_of(b), "키 순서와 상관없이 같은 해시")
	eq(State.hash_of(a).length(), 16, "16자")
	a["orgs"]["org_a"]["cash"] = 0.5
	eq(State.hash_of(a), "", "실수가 있으면 빈 해시")


func test_officers_of_org_sorted() -> void:
	var s := _small()
	s["officers"]["new_c"] = State.new_officer("org_a", "z1", "건달급")
	s["officers"]["new_c"]["status"] = "dead"
	eq(State.officers_of(s, "org_a"), ["boss_a", "man_b"], "살아 움직이는 간부만 · id 순")
	eq(State.officers_of(s, "org_a", false), ["boss_a", "man_b", "new_c"], "죽은 간부도(id 순)")
	eq(State.sorted_keys(s["orgs"]), ["org_a"], "정렬한 키")
