extends "res://tests/helpers.gd"
## FR-202 · 203 · 215 — 읽기 전용 보기(ui/view.gd — 순수): 돈 글('만 원') · 세력 글자 · 지도 노드 · 전선 · 구역 카드 · 간부 카드 · 위 막대.
## 표는 tests/fixtures.gd 에 이름을 더한 것. 상태는 손으로 만든다. 보기는 입력 상태를 바꾸지 않는다.

const View = preload("res://ui/view.gd")
const State = preload("res://sim/state.gd")
const Tables = preload("res://sim/tables.gd")
const Economy = preload("res://sim/economy.gd")
const Fixtures = preload("res://tests/fixtures.gd")


func _t() -> Dictionary:
	var f := Fixtures.files()
	f["common/packs/strategy/factions.json"]["factions"][0]["name"] = "가람파"
	f["common/packs/strategy/factions.json"]["factions"][1]["name"] = "Bee 회"
	f["common/canon/characters.json"]["characters"][0]["name"] = "보스"
	f["common/canon/characters.json"]["characters"][1]["name"] = "맨"
	f["common/packs/strategy/districts.json"]["districts"][0]["name"] = "첫 구역"
	f["common/packs/strategy/districts.json"]["districts"][1]["name"] = "둘째 구역"
	f["common/packs/strategy/districts.json"]["districts"][1]["provisional"] = true
	return Tables.build(f)


## org_a(나) — z1(내 구역 · 상권 lv1 · lv2 · 빈칸) · 간부 boss_a(두목) · man_b / org_b — z2(상권 lv1 · 빈칸) · 간부 new_c
func _s() -> Dictionary:
	var s := State.new_state(1, "A", "org_a")
	s["turn"] = 3
	s["orgs"]["org_a"] = State.new_org("boss_a", "z1")
	s["orgs"]["org_a"]["cash"] = 1200
	s["orgs"]["org_b"] = State.new_org("new_c", "z2")
	s["officers"]["boss_a"] = State.new_officer("org_a", "z1", "네임드")
	s["officers"]["man_b"] = State.new_officer("org_a", "z2", "조장급")
	s["officers"]["man_b"]["rank_prov"] = true
	s["officers"]["new_c"] = State.new_officer("org_b", "z2", "조장급")
	s["zones"]["z1"] = State.new_zone("org_a")
	s["zones"]["z1"]["police"] = 800
	s["zones"]["z1"]["people"] = 3
	s["zones"]["z1"]["slots"] = [{"kind": "상권", "org": "org_a", "lv": 1, "dmg": 0}, {"kind": "상권", "org": "org_a", "lv": 2, "dmg": 0},
		{"kind": "상권", "org": "", "lv": 0, "dmg": 0}]
	s["zones"]["z1"]["facilities"] = ["hq", "office"]
	s["zones"]["z2"] = State.new_zone("org_b")
	s["zones"]["z2"]["police"] = 2500
	s["zones"]["z2"]["slots"] = [{"kind": "유흥", "org": "org_b", "lv": 1, "dmg": 0}, {"kind": "상권", "org": "", "lv": 0, "dmg": 0}]
	return s


func test_money_text() -> void:
	eq(View.money(0), "0만 원", "0")
	eq(View.money(200), "200만 원", "백 단위")
	eq(View.money(1200), "1,200만 원", "천 단위 쉼표")
	eq(View.money(10000), "1억 원", "억 딱")
	eq(View.money(12000), "1억 2,000만 원", "억 + 만")
	eq(View.money(123456), "12억 3,456만 원", "십억")
	eq(View.money(-30), "-30만 원", "음수")
	eq(View.money(-12000), "-1억 2,000만 원", "음수 억")
	eq(View.delta(30), "+30만 원", "늘어남")
	eq(View.delta(-5), "-5만 원", "줄어듦")
	eq(View.delta(0), "0만 원", "그대로")


func test_marks_and_names() -> void:
	var t := _t()
	eq(View.mark(t, "org_a"), "가", "조직 이름 첫 글자")
	eq(View.mark(t, "org_b"), "B", "영문 첫 글자")
	eq(View.mark(t, ""), "·", "주인 없음")
	eq(View.mark(t, "zzz"), "Z", "표에 없으면 id 첫 글자(대문자)")
	eq(View.org_name(t, ""), "주인 없음", "빈 조직")
	eq(View.org_name(t, "org_a"), "가람파", "조직 이름")
	eq(View.person(t, "boss_a"), "보스", "canon 이름")
	eq(View.person(t, "nobody"), "nobody", "이름 없으면 id")
	eq(View.zone_name(t, "z2"), "둘째 구역", "구역 이름")
	eq(View.zone_name(t, "zz"), "zz", "모르는 구역은 id")


func test_police_levels() -> void:
	eq(View.police_lv(0), 1, "낮음")
	eq(View.police_lv(999), 1, "10% 아래")
	eq(View.police_lv(1000), 2, "10% 부터 둘")
	eq(View.police_lv(1999), 2, "20% 아래")
	eq(View.police_lv(2000), 3, "20% 부터 셋")


func test_map_nodes() -> void:
	var t := _t()
	var s := _s()
	var before := State.hash_of(s)
	var nodes: Array = View.map_nodes(s, t, "org_a")
	eq(nodes.map(func(n): return n["id"]), ["z1", "z2"], "구역 id 순")
	var z1: Dictionary = nodes[0]
	eq(z1["owner"], "org_a", "주인")
	eq(z1["mark"], "가", "글자")
	eq(z1["name"], "첫 구역", "이름")
	eq(z1["police_lv"], 1, "경찰 8% → 한 칸")
	eq(z1["mine"], ["boss_a"], "내 간부")
	eq(z1["others"], 0, "남의 간부 없음")
	eq(z1["slots_mine"], 2, "내 사업장 2")
	var z2: Dictionary = nodes[1]
	eq(z2["mine"], ["man_b"], "남의 구역에 있는 내 간부")
	eq(z2["others"], 1, "남의 간부 하나")
	eq(z2["police_lv"], 3, "경찰 25% → 셋")
	s["officers"]["new_c"]["status"] = "away"
	eq(View.map_nodes(s, t, "org_a")[1]["others"], 0, "판 밖 간부는 세지 않는다")
	s["officers"]["new_c"]["status"] = "active"
	eq(State.hash_of(s), before, "입력 상태 그대로")


func test_fronts() -> void:
	var t := _t()
	var s := _s()
	eq(View.fronts(s, t), [["z1", "z2"]], "주인이 다른 이웃 = 전선")
	s["zones"]["z2"]["owner"] = ""
	eq(View.fronts(s, t), [], "주인 없는 구역과는 전선이 아니다")
	s["zones"]["z2"]["owner"] = "org_a"
	eq(View.fronts(s, t), [], "같은 주인")


func test_zone_card() -> void:
	var t := _t()
	var s := _s()
	var c: Dictionary = View.zone_card(s, t, "z1", "org_a")
	eq(c["name"], "첫 구역", "이름")
	eq(c["owner_name"], "가람파", "주인 이름")
	eq(c["slots"].size(), 3, "칸 셋")
	eq(c["slots"][1], {"kind": "상권", "org": "org_a", "org_name": "가람파", "mark": "가", "lv": 2, "mine": true}, "내 칸")
	eq(c["slots"][2]["org_name"], "빈칸", "빈칸")
	eq(c["facilities"], ["본거지", "사무실"], "거점 이름")
	eq(c["officers"].map(func(o): return o["id"]), ["boss_a"], "주둔")
	eq(c["officers"][0]["name"], "보스", "주둔 이름")
	eq(c["flow"], "100%", "유동")
	eq(c["police"], "8%", "경찰")
	eq(c["people"], 3, "사람")
	eq(c["income_me"], Economy.zone_income(s, t, "z1", "org_a"), "이 구역 내 수입")
	check(c["income_me"] > 0, "수입이 있다")
	check(not c["provisional"], "잠정 아님")
	var c2: Dictionary = View.zone_card(s, t, "z2", "org_a")
	check(c2["provisional"], "팩 잠정 표시")
	eq(c2["officers"].map(func(o): return o["id"]), ["man_b", "new_c"], "주둔은 id 순")
	check(c2["officers"][0]["mine"] and not c2["officers"][1]["mine"], "내 간부 표시")
	eq(c2["income_me"], 0, "내 칸 없음")
	eq(View.zone_card(s, t, "nope", "org_a"), {}, "판에 없는 구역은 빈 사전")


func test_officer_cards_and_top() -> void:
	var t := _t()
	var s := _s()
	var cards: Array = View.officer_cards(s, t, "org_a", {"boss_a": 1})
	eq(cards.map(func(o): return o["id"]), ["boss_a", "man_b"], "내 움직일 수 있는 간부 id 순")
	eq([cards[0]["left"], cards[0]["total"], cards[0]["boss"]], [1, 2, true], "두목 2 중 1 남음")
	eq([cards[1]["left"], cards[1]["total"], cards[1]["prov"]], [1, 1, true], "간부 1 · 등급 잠정")
	eq(cards[1]["zone_name"], "둘째 구역", "있는 곳")
	eq(cards[0]["name"], "보스", "이름")
	s["officers"]["man_b"]["status"] = "wounded"
	eq(View.officer_cards(s, t, "org_a", {}).size(), 1, "다친 간부는 줄에 없다")
	var top: Dictionary = View.top(s, t, "org_a", 1, 3)
	eq(top["week"], "3주 / 26", "주")
	eq(top["cash"], "1,200만 원", "돈")
	eq(top["actions"], "행동 1 / 3", "남은 행동")
	eq(top["net"], View.delta(Economy.income_of(s, t, "org_a") - Economy.upkeep_of(s, t, "org_a")) + " / 주", "주 순이익 예상")
	eq(top["prov"], 1, "잠정 간부 수")
	check(not top["over"], "끝나지 않음")
	s["turn"] = 27
	var end: Dictionary = View.top(s, t, "org_a", 0, 0)
	check(end["over"], "26주 뒤")
	eq(end["week"], "끝 — 26주", "끝 글")


const Orders = preload("res://sim/orders.gd")


## 한 주 보고 고정물 — 나: z1 빈칸 개업(돈 −140) · 모집 거절 · 남: org_b 가 z2 lv1 → 2 확장 · new_c 가 z2 → z1 이동 · 구역 z2 주인 바뀜 없음
func _entry() -> Dictionary:
	var before := _s()
	var after := State.to_dict(before)
	after["turn"] = 4
	after["zones"]["z1"]["slots"][2]["org"] = "org_a"
	after["zones"]["z1"]["slots"][2]["lv"] = 1
	after["zones"]["z2"]["slots"][0]["lv"] = 2
	after["zones"]["z2"]["slots"][1]["org"] = "org_b"
	after["zones"]["z2"]["slots"][1]["lv"] = 1
	after["officers"]["new_c"]["zone"] = "z1"
	after["orgs"]["org_a"]["cash"] = 1200 - 140 + 50 - 20
	var open := Orders.make("org_a", "boss_a", "open", "z1", {}, "player")
	var rec := Orders.make("org_a", "man_b", "recruit", "z2", {}, "player")
	var report := {"turn": 3, "applied": [open, Orders.make("org_b", "new_c", "move", "z1")], "rejected": [{"order": rec, "why": "남의 구역"}],
		"events": [{"kind": "leave", "org": "org_a", "lost": {"건달급": 2, "조장급": 0, "네임드": 0, "경호대급": 0}}],
		"money": {"org_a": {"income": 50, "upkeep": 20, "cash": 1090}}}
	return {"report": report, "before": before, "after": after}


func test_order_and_option_text() -> void:
	var t := _t()
	eq(View.order_text(t, Orders.make("org_a", "boss_a", "move", "z2")), "보스 · 이동 → 둘째 구역", "이동 글")
	eq(View.order_text(t, Orders.make("org_a", "boss_a", "open", "z1")), "보스 · 개업 — 첫 구역", "개업 글")
	eq(View.order_text(t, Orders.make("org_a", "boss_a", "rest", "z1")), "보스 · 쉼", "쉼 글")
	eq(View.option_text({"kind": "open", "ok": true, "cost": 140, "gain": 0, "why": ""}), "개업 — 140만 원", "고르기 줄")
	eq(View.option_text({"kind": "recruit", "ok": true, "cost": 21, "gain": 7, "why": ""}), "모집 +7명 — 21만 원", "모집 줄")
	eq(View.option_text({"kind": "rest", "ok": true, "cost": 0, "gain": 0, "why": ""}), "쉼", "공짜 줄")
	eq(View.option_text({"kind": "expand", "ok": false, "cost": 0, "gain": 0, "why": "돈이 모자라다"}), "확장 — 안 됨: 돈이 모자라다", "안 되는 줄")


func test_report_cards() -> void:
	var t := _t()
	var cards: Array = View.report_cards(_entry(), t, "org_a")
	eq(cards.map(func(c): return c["kind"]), ["money", "orders", "intel", "battle"], "카드 넷")
	var money: Array = cards[0]["lines"]
	eq(money[0], "수입 +50만 원 · 지출 -20만 원", "수입 · 지출")
	eq(money[1], "명령에 쓴 돈 140만 원", "명령에 쓴 돈 = 전 + 수입 − 지출 − 뒤")
	eq(money[2], "남은 돈 1,090만 원 (이번 주 -110만 원)", "남은 돈 · 증감")
	check(money[3].contains("조직원이 떠났다") and money[3].contains("건달급 2"), "떠남")
	eq(cards[1]["title"], "내 명령 — 받음 1 · 거절 1", "명령 카드 제목")
	eq(cards[1]["lines"], ["○ 보스 · 개업 — 첫 구역", "× 맨 · 모집 — 둘째 구역 — 남의 구역"], "받음 · 거절 까닭")
	var intel: Array = cards[2]["lines"]
	check(intel.has("[B] Bee 회 · 개업 — 둘째 구역(상권)"), "남의 개업 %s" % [intel])
	check(intel.has("[B] Bee 회 · 확장 — 둘째 구역(유흥 lv2)"), "남의 확장")
	check(intel.has("[B] new_c 이동 — 둘째 구역 → 첫 구역"), "남의 이동")
	check(not intel.any(func(l): return l.contains("가람파")), "내 조직은 다른 조직 카드에 없다")
	eq(cards[3]["lines"].size(), 1, "전투 자리 한 줄")
	eq(View.report_title(_entry(), "org_a"), "3주 — 돈 -110만 원 · 받음 1 · 거절 1", "기록 탭 한 줄")


func test_report_quiet_week() -> void:
	var t := _t()
	var s := _s()
	var e := {"report": {"turn": 1, "applied": [], "rejected": [], "events": [], "money": {}}, "before": s, "after": s}
	var cards: Array = View.report_cards(e, t, "org_a")
	eq(cards[1]["lines"], ["낸 명령 없음"], "명령 없음")
	eq(cards[2]["lines"], ["눈에 띄는 움직임 없음"], "조용한 주")


func test_org_panel() -> void:
	var t := _t()
	var s := _s()
	var o: Dictionary = View.org_panel(s, t, "org_a")
	eq(o["name"], "가람파", "이름")
	eq(o["cash"], "1,200만 원", "돈")
	eq(o["income"], View.money(Economy.income_of(s, t, "org_a")), "주 수입")
	eq(o["upkeep"], View.money(Economy.upkeep_of(s, t, "org_a")), "주 지출")
	eq(o["heat"], "0%", "열기")
	eq(o["officers"].map(func(p): return p["id"]), ["boss_a", "man_b"], "간부 id 순")
	eq(o["officers"][1]["rank"], "조장급(잠정)", "자리값 등급 표시")
	eq([o["officers"][0]["post"], o["officers"][1]["post"]], ["두목", "간부"], "두목 · 자리 없음")
	eq(o["officers"][0]["loyalty"], "50%", "충성")
	eq(o["others"].map(func(x): return x["org"]), ["org_b"], "다른 조직")
	eq([o["others"][0]["zones"], o["others"][0]["slots"]], [1, 1], "다른 조직 구역 · 사업장 수")
