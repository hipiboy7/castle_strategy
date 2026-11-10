extends "res://tests/helpers.gd"
## FR-204 · 205 — 대기 명령(sim/draft.gd — 순수): 행동 수 · 넣기 · 빼기 · 미리 보기(턴과 같은 plan → move → manage · 입력 불변) ·
## 고를 수 있는 명령(지금 구역 = 개업 · 확장 · 모집 · 쉼 / 다른 구역 = 이동 · 거절 까닭 · 쓴 돈 · 모집 수) · 줄마다 결과 · 맡기기.
## 판: tests/fixtures.gd 시나리오 A — 나 org_a(돈 500) · 두목 man_b(행동 2) · boss_a(1) · 둘 다 z1(내 구역 · lv1 하나 + 빈칸 둘) · z2 주인 없음.

const Draft = preload("res://sim/draft.gd")
const Orders = preload("res://sim/orders.gd")
const Setup = preload("res://sim/setup.gd")
const State = preload("res://sim/state.gd")
const Tables = preload("res://sim/tables.gd")
const Economy = preload("res://sim/economy.gd")
const Ai = preload("res://sim/ai.gd")
const Fixtures = preload("res://tests/fixtures.gd")


func _t() -> Dictionary:
	return Tables.build(Fixtures.files())


func _s(t: Dictionary) -> Dictionary:
	return Setup.scenario(t, "A", 1, "")["state"]


func _o(by: String, kind: String, to: String) -> Dictionary:
	return Orders.make("org_a", by, kind, to, {}, "player")


func test_limits_and_left() -> void:
	var t := _t()
	var s := _s(t)
	eq(Draft.limit(s, t, "man_b"), 2, "두목 2")
	eq(Draft.limit(s, t, "boss_a"), 1, "간부 1")
	var d := [_o("man_b", "rest", "z1")]
	eq(Draft.used(d), {"man_b": 1}, "간부별 낸 수")
	eq(Draft.left(s, t, d, "man_b"), 1, "두목 하나 남음")
	eq(Draft.total_left(s, t, d), [2, 3], "내 조직 남은 행동 / 전체")


func test_add_remove() -> void:
	var t := _t()
	var s := _s(t)
	var r: Dictionary = Draft.add(s, t, [], _o("boss_a", "rest", "z1"))
	eq(r["why"], "", "넣기")
	eq(r["draft"].size(), 1, "하나 들어감")
	var r2: Dictionary = Draft.add(s, t, r["draft"], _o("boss_a", "rest", "z1"))
	check(r2["why"] != "", "행동 수를 넘으면 거절")
	eq(r2["draft"], r["draft"], "거절이면 그대로")
	check(Draft.add(s, t, [], Orders.make("org_b", "new_c", "rest", "", {}, "player"))["why"] != "", "남의 간부는 거절")
	s["officers"]["boss_a"]["status"] = "wounded"
	check(Draft.add(s, t, [], _o("boss_a", "rest", "z1"))["why"] != "", "움직일 수 없는 간부는 거절")
	var d := [_o("man_b", "rest", "z1"), _o("man_b", "open", "z1")]
	eq(Draft.remove(d, 0), [_o("man_b", "open", "z1")], "빼기")
	eq(Draft.remove(d, 5), d, "없는 자리는 그대로")
	eq(d.size(), 2, "입력 배열은 그대로")


func test_preview_does_not_touch_input() -> void:
	var t := _t()
	var s := _s(t)
	var before := State.hash_of(s)
	var p: Dictionary = Draft.preview(s, t, [_o("boss_a", "open", "z1")])
	eq(State.hash_of(s), before, "입력 상태 그대로")
	eq(p["applied"].size(), 1, "받음")
	eq(p["state"]["orgs"]["org_a"]["cash"], 500 - Economy.open_cost(t["economy"], "상권"), "개업 비용만큼 줄어듦")
	eq(p["state"]["turn"], s["turn"], "미리 보기는 턴을 넘기지 않는다")


func test_move_then_open_there() -> void:
	var t := _t()
	var s := _s(t)
	var d := [_o("man_b", "move", "z2"), _o("man_b", "open", "z2")]
	var p: Dictionary = Draft.preview(s, t, d)
	eq(p["applied"].size(), 2, "이동 뒤 그 구역에서 개업")
	eq(p["state"]["officers"]["man_b"]["zone"], "z2", "간부가 z2 로")
	eq(p["state"]["zones"]["z2"]["slots"][0]["org"], "org_a", "z2 첫 칸이 내 것")
	var m: Array = Draft.marks(s, t, d)
	eq(m.map(func(x): return x["ok"]), [true, true], "줄마다 결과")


func test_options_here_and_there() -> void:
	var t := _t()
	var s := _s(t)
	var here: Array = Draft.options(s, t, [], "boss_a", "z1")
	eq(here.map(func(x): return x["kind"]), ["open", "expand", "recruit", "rest", "defend", "defend"], "지금 구역 — 등록부 순(C3 지키기 카드 둘)")
	var open: Dictionary = here[0]
	check(open["ok"], "개업 됨")
	eq(open["cost"], Economy.open_cost(t["economy"], "상권"), "개업 비용")
	eq(open["order"], _o("boss_a", "open", "z1"), "넣을 명령")
	check(here[1]["ok"] and here[1]["cost"] == Economy.expand_cost(t["economy"], "상권", 2), "확장 lv1 → 2 비용")
	check(here[2]["ok"] and here[2]["gain"] >= 3 * int(t["economy"]["recruit"]["per_people"]), "모집 수(사람 3 × per_people 이상)")
	eq(here[2]["cost"], Economy.recruit_cost(t["economy"], here[2]["gain"]), "모집 비용 = 머릿수 × 값")
	check(here[3]["ok"] and here[3]["cost"] == 0, "쉼은 공짜")
	var there: Array = Draft.options(s, t, [], "boss_a", "z2")
	eq(there.map(func(x): return x["kind"]).slice(0, 1), ["move"], "다른 구역 — 이동 먼저")
	eq(there.slice(1).map(func(x): return x["kind"]), ["raid", "raid", "raid", "raid", "raid", "raid"], "우리 구역이 아니면 습격(작전 카드 꼴 6)")
	check(there[0]["ok"], "이웃으로 이동 됨")
	var nowhere: Array = Draft.options(s, t, [], "boss_a", "nope")
	check(not nowhere[0]["ok"] and nowhere[0]["why"] != "", "판에 없는 구역 — 까닭")


func test_options_follow_pending_move_and_limits() -> void:
	var t := _t()
	var s := _s(t)
	var d := [_o("man_b", "move", "z2")]
	var at_z2: Array = Draft.options(s, t, d, "man_b", "z2")
	eq(at_z2.map(func(x): return x["kind"]), ["open", "expand", "recruit", "rest"], "이동한 뒤 자리에서 본다")
	check(at_z2[0]["ok"], "z2 개업 됨(주인 없는 구역)")
	check(not at_z2[1]["ok"] and at_z2[1]["why"] != "", "z2 에 내 칸이 없어 확장 안 됨 — 까닭")
	check(not at_z2[2]["ok"], "남의(주인 없는) 구역 모집 안 됨")
	var full := [_o("boss_a", "rest", "z1")]
	var none: Array = Draft.options(s, t, full, "boss_a", "z1")
	check(none.all(func(x): return not x["ok"] and x["why"] != ""), "행동을 다 쓰면 모두 안 됨")


func test_rich_order_rejected_mark() -> void:
	var t := _t()
	var s := _s(t)
	s["orgs"]["org_a"]["cash"] = Economy.open_cost(t["economy"], "상권")
	var d := [_o("man_b", "open", "z1"), _o("man_b", "open", "z1")]
	var m: Array = Draft.marks(s, t, d)
	eq(m[0]["ok"], true, "첫 개업은 됨")
	eq(m[1]["ok"], false, "두 번째는 돈이 모자람")
	check(m[1]["why"] != "", "까닭")


func test_auto_is_ai_for_me() -> void:
	var t := _t()
	var s := _s(t)
	eq(Draft.auto(s, t), Ai.orders_for(s, t, "org_a"), "맡기기 = 내 조직 AI 명령")
	check(Draft.auto(s, t).all(func(o): return o["src"] == "ai"), "src ai")
