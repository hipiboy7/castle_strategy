extends "res://tests/helpers.gd"
## FR-115 — sim/turn.gd: 08 13절 9단계를 등록부로 돈다(C1 처리기: plan · move · manage · settle). 입력 상태는 바꾸지 않고
## 새 상태 + 보고를 돌려준다. 같은 입력이면 같은 해시. 설계서 3-5

const Turn = preload("res://sim/turn.gd")
const Orders = preload("res://sim/orders.gd")
const State = preload("res://sim/state.gd")
const Tables = preload("res://sim/tables.gd")
const Fixtures = preload("res://tests/fixtures.gd")


func _t() -> Dictionary:
	return Tables.build(Fixtures.files())


func _s() -> Dictionary:
	var s := State.new_state(5, "A", "org_a")
	s["orgs"]["org_a"] = State.new_org("boss_a", "z1")
	s["orgs"]["org_a"]["cash"] = 500
	s["officers"]["boss_a"] = State.new_officer("org_a", "z1", "네임드")
	s["officers"]["boss_a"]["post"] = "boss"
	s["officers"]["man_b"] = State.new_officer("org_a", "z1", "조장급")
	s["zones"]["z1"] = State.new_zone("org_a")
	s["zones"]["z1"]["people"] = 2
	s["zones"]["z1"]["slots"] = [{"kind": "상권", "org": "org_a", "lv": 1, "dmg": 0}]
	s["zones"]["z2"] = State.new_zone("")
	s["zones"]["z2"]["slots"] = [{"kind": "유흥", "org": "", "lv": 0, "dmg": 0}]
	return s


func test_phases_follow_08_13() -> void:
	eq(Turn.PHASES, ["plan", "move", "manage", "intrigue", "diplomacy", "clash", "events", "council", "settle"], "08 13절 순서")
	var with_handler := Turn.HANDLERS.keys()
	with_handler.sort()
	eq(with_handler, ["clash", "manage", "move", "plan", "settle"], "C1 처리기가 있는 단계 + C3 충돌")


func test_run_returns_new_state_and_report() -> void:
	var s := _s()
	var before := State.hash_of(s)
	var r: Dictionary = Turn.run(s, [], _t())
	eq(State.hash_of(s), before, "입력 상태는 그대로")
	eq(r["state"]["turn"], 2, "턴 + 1")
	for k in ["turn", "applied", "rejected", "events", "money", "invariants"]:
		check(r["report"].has(k), "보고 칸 %s" % k)
	eq(r["report"]["turn"], 1, "처리한 턴")
	eq(r["report"]["invariants"], [], "불변식 통과")
	# 상권 lv1: 35 × (0.8 + 60/250) × 1.25 = 45.5 → 46(열기 0) · 유지비 0 · 대우 6 + 3
	eq(r["report"]["money"]["org_a"], {"income": 46, "upkeep": 9, "cash": 537}, "결산")


func test_move_phase_runs_before_manage() -> void:
	var r: Dictionary = Turn.run(_s(), [
		Orders.make("org_a", "boss_a", "open"),
		Orders.make("org_a", "boss_a", "move", "z2"),
	], _t())
	eq(r["report"]["rejected"], [], "거절 없음")
	eq(r["state"]["officers"]["boss_a"]["zone"], "z2", "먼저 옮기고")
	eq(r["state"]["zones"]["z2"]["slots"][0]["org"], "org_a", "옮긴 곳에서 개업(낸 순서와 상관없이 이동 단계가 먼저)")


func test_same_input_same_hash_and_streams_do_not_shift() -> void:
	var t := _t()
	var a: Dictionary = Turn.run(_s(), [Orders.make("org_a", "man_b", "recruit")], t)
	var b: Dictionary = Turn.run(_s(), [Orders.make("org_a", "man_b", "recruit")], t)
	eq(State.hash_of(a["state"]), State.hash_of(b["state"]), "같은 입력 → 같은 해시")
	var c: Dictionary = Turn.run(_s(), [Orders.make("org_a", "boss_a", "rest"), Orders.make("org_a", "man_b", "recruit")], t)
	eq(c["state"]["orgs"]["org_a"]["troops"]["건달급"], a["state"]["orgs"]["org_a"]["troops"]["건달급"], "다른 명령이 끼어도 모집 수가 같다")


func test_invariant_violation_is_reported_not_hidden() -> void:
	var s := _s()
	s["orgs"]["org_a"]["troops"]["건달급"] = -3
	var r: Dictionary = Turn.run(s, [], _t())
	check(not r["report"]["invariants"].is_empty(), "결산 뒤 불변식 위반이 보고에 남는다")
