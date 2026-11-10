extends "res://tests/helpers.gd"
## FR-115 — sim/orders.gd(명령 꼴 · 정렬 · 마감 검사 · 처리기 등록부)와 C1 처리기 sim/kinds/*.gd(move · open · expand · recruit · rest).
## 설계서 3-4. 표는 tests/fixtures.gd(구역 z1 — z2 한 길). 틀린 명령은 적용하지 않고 까닭을 보고에 남긴다(같은 입력 → 같은 거절).

const Orders = preload("res://sim/orders.gd")
const State = preload("res://sim/state.gd")
const Tables = preload("res://sim/tables.gd")
const Fixtures = preload("res://tests/fixtures.gd")

var _tables := {}


func _t() -> Dictionary:
	if _tables.is_empty():
		_tables = Tables.build(Fixtures.files())
	return _tables


## org_a(두목 boss_a) 가 z1 을 쥐고 칸 셋(lv1 · lv3 · 빈칸) · org_b(두목 new_c) 가 z2 를 쥔 상태
func _s() -> Dictionary:
	var s := State.new_state(1, "A", "org_a")
	s["orgs"]["org_a"] = State.new_org("boss_a", "z1")
	s["orgs"]["org_a"]["cash"] = 1000
	s["orgs"]["org_b"] = State.new_org("new_c", "z2")
	s["officers"]["boss_a"] = State.new_officer("org_a", "z1", "네임드")
	s["officers"]["boss_a"]["post"] = "boss"
	s["officers"]["man_b"] = State.new_officer("org_a", "z1", "조장급")
	s["officers"]["new_c"] = State.new_officer("org_b", "z2", "조장급")
	s["zones"]["z1"] = State.new_zone("org_a")
	s["zones"]["z1"]["people"] = 3
	s["zones"]["z1"]["slots"] = [{"kind": "상권", "org": "org_a", "lv": 1, "dmg": 0}, {"kind": "상권", "org": "org_a", "lv": 3, "dmg": 0},
		{"kind": "상권", "org": "", "lv": 0, "dmg": 0}]
	s["zones"]["z2"] = State.new_zone("org_b")
	s["zones"]["z2"]["slots"] = [{"kind": "유흥", "org": "", "lv": 0, "dmg": 0}]
	return s


func _ctx(phase: String = "manage") -> Dictionary:
	return {"t": _t(), "seed": 1, "turn": 1, "phase": phase, "report": {"applied": [], "rejected": [], "events": [], "money": {}}}


func test_registry_kinds_and_phases() -> void:
	var kinds := Orders.KINDS.keys()
	kinds.sort()
	eq(kinds, ["defend", "expand", "move", "open", "raid", "recruit", "rest"], "C1 명령 종류 + C3 습격 · 지키기")
	eq(Orders.KINDS["move"]["phase"], "move", "이동은 이동 단계")
	for k in ["open", "expand", "recruit", "rest"]:
		eq(Orders.KINDS[k]["phase"], "manage", "%s 는 경영 단계" % k)


func test_make_and_shape() -> void:
	var o := Orders.make("org_a", "man_b", "rest")
	eq(o, {"org": "org_a", "by": "man_b", "kind": "rest", "to": "", "args": {}, "src": "ai"}, "명령 꼴")
	eq(Orders.shape_error(o), "", "꼴이 맞다")
	var bad := o.duplicate()
	bad.erase("to")
	check(Orders.shape_error(bad) != "", "칸이 모자라면 틀림")
	var bad2 := o.duplicate()
	bad2["src"] = "cheat"
	check(Orders.shape_error(bad2) != "", "src 는 player · ai")
	check(Orders.shape_error("글") != "", "사전이 아니면 틀림")


func test_sort_org_then_officer_then_issue_order() -> void:
	var a1 := Orders.make("org_a", "boss_a", "rest", "", {"n": 1})
	var a2 := Orders.make("org_a", "boss_a", "rest", "", {"n": 2})
	var b := Orders.make("org_a", "man_b", "rest")
	var c := Orders.make("org_b", "new_c", "rest")
	eq(Orders.sorted([c, b, a1, a2]), [a1, a2, b, c], "조직 id → 간부 id → 낸 순서")


func test_plan_rejects_with_reasons() -> void:
	var s := _s()
	s["officers"]["new_c"]["status"] = "dead"
	var ctx := _ctx("plan")
	ctx["all"] = [
		Orders.make("ghost", "man_b", "rest"),
		Orders.make("org_a", "new_c", "rest"),
		Orders.make("org_b", "new_c", "rest"),
		Orders.make("org_a", "man_b", "fly"),
		Orders.make("org_a", "man_b", "rest"),
		Orders.make("org_a", "man_b", "rest"),
		Orders.make("org_a", "boss_a", "rest"),
		Orders.make("org_a", "boss_a", "rest"),
		Orders.make("org_a", "boss_a", "rest"),
	]
	Orders.plan(s, ctx)
	var rej: Array = ctx["report"]["rejected"]
	eq(rej.size(), 6, "거절 여섯: %s" % [rej])
	var whys := rej.map(func(r): return r["why"])
	for w in ["조직", "소속", "움직일 수 없다", "모르는 명령", "행동 수"]:
		check(whys.any(func(x): return String(x).contains(w)), "까닭에 '%s'" % w)
	eq(ctx["accepted"]["manage"].size(), 3, "받은 명령: man_b 1 · boss_a 2")


func test_move_handler() -> void:
	var s := _s()
	var ctx := _ctx("move")
	eq(Orders.apply_one(s, Orders.make("org_a", "man_b", "move", "z2"), ctx), "", "길이 있는 이웃 구역으로")
	eq(s["officers"]["man_b"]["zone"], "z2", "옮겼다")
	check(Orders.apply_one(s, Orders.make("org_a", "man_b", "move", "z2"), ctx) != "", "같은 구역은 거절")
	check(Orders.apply_one(s, Orders.make("org_a", "man_b", "move", "ghost"), ctx) != "", "모르는 구역은 거절")
	s["zones"]["z3"] = State.new_zone("")
	check(Orders.apply_one(s, Orders.make("org_a", "man_b", "move", "z3"), ctx) != "", "길이 없으면 거절")


func test_open_handler() -> void:
	var s := _s()
	var ctx := _ctx()
	eq(Orders.apply_one(s, Orders.make("org_a", "man_b", "open", "z1"), ctx), "", "자기 구역 빈칸 개업")
	eq(s["zones"]["z1"]["slots"][2], {"kind": "상권", "org": "org_a", "lv": 1, "dmg": 0}, "빈칸이 lv1 이 됐다")
	eq(s["orgs"]["org_a"]["cash"], 860, "1000 − 상권 35 × 4")
	check(String(Orders.apply_one(s, Orders.make("org_a", "man_b", "open"), ctx)).contains("빈 칸"), "빈칸이 없으면 거절")
	check(String(Orders.apply_one(s, Orders.make("org_a", "man_b", "open", "z2"), ctx)).contains("없다"), "간부가 없는 구역은 거절")
	s["officers"]["man_b"]["zone"] = "z2"
	check(String(Orders.apply_one(s, Orders.make("org_a", "man_b", "open"), ctx)).contains("남의"), "남의 구역은 거절")
	s["zones"]["z2"]["owner"] = ""
	s["orgs"]["org_a"]["cash"] = 100
	check(String(Orders.apply_one(s, Orders.make("org_a", "man_b", "open"), ctx)).contains("돈"), "돈이 모자라면 거절")
	s["orgs"]["org_a"]["cash"] = 240
	eq(Orders.apply_one(s, Orders.make("org_a", "man_b", "open"), ctx), "", "주인 없는 구역에도 연다")
	eq(s["orgs"]["org_a"]["cash"], 0, "240 − 유흥 60 × 4")


func test_expand_handler() -> void:
	var s := _s()
	var ctx := _ctx()
	eq(Orders.apply_one(s, Orders.make("org_a", "boss_a", "expand"), ctx), "", "가장 낮은 레벨부터")
	eq(s["zones"]["z1"]["slots"][0]["lv"], 2, "lv1 → 2")
	eq(s["orgs"]["org_a"]["cash"], 720, "1000 − 35 × 4 × 2")
	eq(Orders.apply_one(s, Orders.make("org_a", "boss_a", "expand", "", {"slot": 0}), ctx), "", "칸을 고를 수 있다")
	eq(s["zones"]["z1"]["slots"][0]["lv"], 3, "lv2 → 3")
	check(Orders.apply_one(s, Orders.make("org_a", "boss_a", "expand"), ctx) != "", "모두 lv3 이면 거절")
	check(Orders.apply_one(s, Orders.make("org_a", "boss_a", "expand", "", {"slot": 2}), ctx) != "", "남의(빈) 칸은 거절")
	s["zones"]["z1"]["slots"][0]["lv"] = 1
	s["orgs"]["org_a"]["cash"] = 50
	check(String(Orders.apply_one(s, Orders.make("org_a", "boss_a", "expand"), ctx)).contains("돈"), "돈이 모자라면 거절")


func test_recruit_handler_uses_officer_stream() -> void:
	var s := _s()
	var ctx := _ctx()
	eq(Orders.apply_one(s, Orders.make("org_a", "man_b", "recruit"), ctx), "", "자기 구역에서 모집")
	var n: int = s["orgs"]["org_a"]["troops"]["건달급"]
	check(n >= 6 and n <= 8, "사람 3 × 2 + 0~2 = 6~8명 (%d)" % n)
	eq(s["orgs"]["org_a"]["cash"], 1000 - 3 * n, "머릿수 × 3")
	var s2 := _s()
	Orders.apply_one(s2, Orders.make("org_a", "boss_a", "rest"), ctx)
	Orders.apply_one(s2, Orders.make("org_a", "man_b", "recruit"), ctx)
	eq(s2["orgs"]["org_a"]["troops"]["건달급"], n, "다른 간부의 명령이 끼어도 같은 수(간부마다 갈래 스트림)")
	check(ctx["report"]["events"].any(func(e): return e["kind"] == "recruit" and e["n"] == n), "모집 수가 보고에 있다")
	s["orgs"]["org_a"]["cash"] = 7
	eq(Orders.apply_one(s, Orders.make("org_a", "man_b", "recruit"), ctx), "", "돈만큼만 모집")
	eq(s["orgs"]["org_a"]["cash"], 1, "7 → 2명 × 3 = 6")
	s["orgs"]["org_a"]["cash"] = 2
	check(String(Orders.apply_one(s, Orders.make("org_a", "man_b", "recruit"), ctx)).contains("돈"), "한 명도 못 사면 거절")
	s["officers"]["man_b"]["zone"] = "z2"
	s["orgs"]["org_a"]["cash"] = 100
	check(String(Orders.apply_one(s, Orders.make("org_a", "man_b", "recruit"), ctx)).contains("남의"), "남의 구역에서는 모집하지 않는다")


func test_rest_handler_changes_nothing() -> void:
	var s := _s()
	var before := State.hash_of(s)
	eq(Orders.apply_one(s, Orders.make("org_a", "man_b", "rest"), _ctx()), "", "쉼")
	eq(State.hash_of(s), before, "상태 그대로")


func test_run_phase_applies_in_order_and_rechecks() -> void:
	var s := _s()
	s["orgs"]["org_a"]["cash"] = 150
	var ctx := _ctx("plan")
	ctx["all"] = [Orders.make("org_a", "man_b", "open"), Orders.make("org_a", "boss_a", "open")]
	Orders.plan(s, ctx)
	ctx["phase"] = "manage"
	Orders.run_phase(s, ctx)
	eq(ctx["report"]["applied"].size(), 1, "boss_a 가 먼저(id 순) 열고")
	eq(ctx["report"]["applied"][0]["by"], "boss_a", "먼저 낸 쪽")
	eq(ctx["report"]["rejected"].size(), 1, "man_b 는 빈칸이 없어 거절")
