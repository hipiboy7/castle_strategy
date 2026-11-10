extends "res://tests/helpers.gd"
## FR-116 — sim/economy.gd: 08 14-1 사업장 수입(정수판 — 설계서 3-6) · 유지비 · 간부 대우 · 결산 · 현금 0 밑 2턴(조직원 이탈 · 충성 하락).
## 표는 tests/fixtures.gd(경제 값은 data/game/economy.json 과 같은 꼴). 기대값은 손으로 계산해 적었다(아래 주석).

const Economy = preload("res://sim/economy.gd")
const State = preload("res://sim/state.gd")
const Tables = preload("res://sim/tables.gd")
const Fixtures = preload("res://tests/fixtures.gd")


func _t() -> Dictionary:
	return Tables.build(Fixtures.files())


## org_a(돈줄 상권) — z1 에 상권 칸 둘(lv1 · lv2) · 간부 boss_a(네임드 · 수완 60) · man_b(조장급 · 능력치 없음)
func _s() -> Dictionary:
	var s := State.new_state(1, "A", "org_a")
	s["orgs"]["org_a"] = State.new_org("boss_a", "z1")
	s["orgs"]["org_a"]["heat"] = 1000
	s["orgs"]["org_a"]["troops"] = {"건달급": 10, "조장급": 2, "네임드": 1, "경호대급": 1}
	s["officers"]["boss_a"] = State.new_officer("org_a", "z1", "네임드")
	s["officers"]["man_b"] = State.new_officer("org_a", "z1", "조장급")
	s["zones"]["z1"] = State.new_zone("org_a")
	s["zones"]["z1"]["slots"] = [{"kind": "상권", "org": "org_a", "lv": 1, "dmg": 0}, {"kind": "상권", "org": "org_a", "lv": 2, "dmg": 0},
		{"kind": "상권", "org": "", "lv": 0, "dmg": 0}]
	s["zones"]["z2"] = State.new_zone("")
	return s


func test_slot_income_formula() -> void:
	var e: Dictionary = _t()["economy"]
	# 35 × 1 × 1.00 × (0.8 + 60/250) × (1 − 0.5 × 0.10) × 1.25 = 43.225 → 43
	eq(Economy.slot_income(e, "상권", 1, 10000, 60, 1000, true), 43, "상권 lv1 · 수완 60 · 열기 10% · 돈줄 맞음")
	# 같은데 돈줄 안 맞음: 34.58 → 35
	eq(Economy.slot_income(e, "상권", 1, 10000, 60, 1000, false), 35, "돈줄 안 맞음")
	# 60 × 3 × 1.20 × 0.8 × 1.0 × 1.25 = 216
	eq(Economy.slot_income(e, "유흥", 3, 12000, 0, 0, true), 216, "유흥 lv3 · 유동 1.2 · 수완 0 · 열기 0")
	# 열기 100%: 35 × 0.8 × 0.5 = 14
	eq(Economy.slot_income(e, "상권", 1, 10000, 0, 10000, false), 14, "열기 100% 면 반")
	eq(Economy.slot_income(e, "없는업종", 1, 10000, 0, 0, false), 0, "모르는 업종은 0")


func test_chief_business_is_best_officer_in_zone() -> void:
	var s := _s()
	var t := _t()
	eq(Economy.chief_business(s, t, "z1", "org_a"), 60, "구역장 = 그 구역에서 수완이 가장 높은 간부")
	s["officers"]["boss_a"]["zone"] = "z2"
	eq(Economy.chief_business(s, t, "z1", "org_a"), 0, "능력치 없는 간부만 남으면 0")
	s["officers"]["boss_a"]["zone"] = "z1"
	s["officers"]["boss_a"]["status"] = "wounded"
	eq(Economy.chief_business(s, t, "z1", "org_a"), 0, "움직이지 못하는 간부는 구역장이 아니다")


func test_income_and_upkeep() -> void:
	var s := _s()
	var t := _t()
	# lv1 43 + lv2 86.45 → 86 = 129 (칸마다 반올림)
	eq(Economy.income_of(s, t, "org_a"), 129, "칸마다 반올림해 더한다")
	# 조직원 10×1 + 2×2 + 1×4 + 1×8 = 26 · 간부 대우 네임드(2)×3 + 조장급(1)×3 = 9
	eq(Economy.upkeep_of(s, t, "org_a"), 35, "유지비 + 간부 대우")
	s["officers"]["man_b"]["status"] = "away"
	eq(Economy.upkeep_of(s, t, "org_a"), 32, "판 밖(away) 간부는 대우를 받지 않는다")
	s["officers"]["man_b"]["status"] = "wounded"
	eq(Economy.upkeep_of(s, t, "org_a"), 35, "다친 간부는 대우를 받는다")


func test_costs() -> void:
	var e: Dictionary = _t()["economy"]
	eq(Economy.open_cost(e, "상권"), 140, "개업 = BASE × 4")
	eq(Economy.expand_cost(e, "유흥", 2), 480, "확장 = BASE × 4 × 오를 레벨")
	eq(Economy.recruit_cost(e, 5), 15, "모집 = 머릿수 × 3")


func test_settle_adds_income_minus_upkeep() -> void:
	var s := _s()
	s["orgs"]["org_a"]["cash"] = 100
	var report := {"money": {}, "events": []}
	Economy.settle(s, {"t": _t(), "report": report})
	eq(s["orgs"]["org_a"]["cash"], 194, "100 + 129 − 35")
	eq(report["money"]["org_a"], {"income": 129, "upkeep": 35, "cash": 194}, "결산 보고")
	eq(s["orgs"]["org_a"]["neg_cash_turns"], 0, "0 이상이면 이어진 턴 0")


func test_negative_cash_two_turns_troops_leave() -> void:
	var s := _s()
	var t := _t()
	s["zones"]["z1"]["slots"] = []
	s["orgs"]["org_a"]["cash"] = 20
	var report := {"money": {}, "events": []}
	Economy.settle(s, {"t": t, "report": report})
	eq(s["orgs"]["org_a"]["cash"], -15, "20 − 35")
	eq(s["orgs"]["org_a"]["neg_cash_turns"], 1, "0 밑 1턴")
	eq(s["orgs"]["org_a"]["troops"]["건달급"], 10, "1턴째는 아직 그대로")
	Economy.settle(s, {"t": t, "report": report})
	eq(s["orgs"]["org_a"]["neg_cash_turns"], 2, "0 밑 2턴")
	# 등급마다 10% 올림: 10 → 9 · 2 → 1 · 1 → 0 · 1 → 0
	eq(s["orgs"]["org_a"]["troops"], {"건달급": 9, "조장급": 1, "네임드": 0, "경호대급": 0}, "조직원이 떠난다(올림 10%)")
	eq(s["officers"]["boss_a"]["loyalty"], 4500, "충성 −5.00")
	check(report["events"].any(func(ev): return ev["kind"] == "leave" and ev["org"] == "org_a"), "이탈 사건이 보고에 있다")
	s["officers"]["boss_a"]["loyalty"] = 100
	Economy.settle(s, {"t": t, "report": report})
	eq(s["officers"]["boss_a"]["loyalty"], 0, "충성은 0 밑으로 내려가지 않는다")


func test_dead_org_is_skipped() -> void:
	var s := _s()
	s["orgs"]["org_a"]["alive"] = false
	s["orgs"]["org_a"]["cash"] = 7
	var report := {"money": {}, "events": []}
	Economy.settle(s, {"t": _t(), "report": report})
	eq(s["orgs"]["org_a"]["cash"], 7, "무너진 조직은 결산하지 않는다")
	check(not report["money"].has("org_a"), "보고에도 없다")


## C2 FR-203 — 구역 하나의 내 주 수입(구역 카드) · 구역마다 더하면 income_of 와 같다
func test_zone_income_sums_to_income_of() -> void:
	var t := _t()
	var s := _s()
	s["zones"]["z2"]["slots"] = [{"kind": "유흥", "org": "org_a", "lv": 1, "dmg": 0}]
	var sum := 0
	for z in State.sorted_keys(s["zones"]):
		sum += Economy.zone_income(s, t, z, "org_a")
	eq(sum, Economy.income_of(s, t, "org_a"), "구역 합 = 조직 수입")
	check(Economy.zone_income(s, t, "z2", "org_a") > 0, "z2 수입")
	eq(Economy.zone_income(s, t, "nope", "org_a"), 0, "판에 없는 구역")

