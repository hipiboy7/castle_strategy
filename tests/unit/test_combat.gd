extends "res://tests/helpers.gd"
## FR-301 · FR-302 · FR-305 · FR-306 · FR-308 — 습격(sim/combat.gd) · 습격 · 지키기 처리기(sim/kinds/raid.gd · defend.gd).
## 08 14-2 본보기 대조(톱 간부 한 명 HP 720 대 건달급 100 → 틱마다 7명 · 15틱 · 입은 피해 약 160) · 쓸어 내기 상한 · 포위 한도 · 카드 ·
## 빈 구역 차지 · 차지 뒤(사업장 · 거점 · 본거지 잃음 · 물러남 · 잡힘) · 손실 · 회복 · 묶기(간부 4 · 카드) · 같은 시드면 같은 기록 · 명령 검사.

const Combat = preload("res://sim/combat.gd")
const Orders = preload("res://sim/orders.gd")
const State = preload("res://sim/state.gd")
const Game = preload("res://sim/game.gd")
const Pcg32 = preload("res://sim/rng.gd")
const DataFiles = preload("res://src/data_files.gd")

var _tables := {}


func _t() -> Dictionary:
	if _tables.is_empty():
		_tables = DataFiles.load_tables()
	return _tables


func _a() -> Dictionary:
	return Game.new_game(_t(), "A", 1)["state"]


func _rng(tag: String):
	return Pcg32.new().init_stream(1, 1, "clash", tag)


func _ctx(s: Dictionary, accepted: Array = []) -> Dictionary:
	return {"t": _t(), "seed": s["seed"], "turn": s["turn"], "phase": "clash", "accepted": {"clash": accepted},
		"report": {"applied": [], "rejected": [], "events": [], "money": {}, "battles": []}}


func test_08_example_top_vs_100() -> void:
	var t := _t()
	var s := _a()
	s["officers"]["chasumin"]["rank"] = "톱"            # 능력치 없는 인물 — HP 200 + 40 × 13 = 720(08 본보기)
	var o := Combat.officer_unit(s, t, "chasumin", 0)
	eq(o["hp"], 720, "톱 간부 HP 720")
	var g := Combat.group_unit(t, "건달급", 100, 1)
	var rec := {"learned": []}
	var sec := Combat._section(s, t, 0, [o], [g], [], [], _rng("ex"), rec)
	eq(sec["result"], "att", "휩쓴다")
	eq(sec["ticks"], 15, "틱마다 7명 → 15틱")
	eq(sec["log"][0][1], 93, "첫 틱에 7명(1 + ⌊13/2⌋)")
	eq(720 - o["hp"], 160, "남은 무리가 6명 이상인 동안 틱마다 12(6 × 10 × 0.2) — 모두 160")


func test_sweep_cap_without_one_shot() -> void:
	var t := _t()
	var s := _a()
	var o := Combat.officer_unit(s, t, "woojin", 0)       # 경호대급(3) 대 건달급 — 원콤 아님(차 3 < 5)
	var g := Combat.group_unit(t, "건달급", 50, 1)
	Combat._act(t, o, [g], 10000, false, {}, _rng("cap"), [100, 100], t["combat"]["raid"]["morale"])
	eq(g["n"], 48, "원콤이 아니어도 쓸어 내기 상한 1 + ⌊3/2⌋ = 2명 · 남는 피해는 버림")
	eq(g["dmg"], 0, "상한에 걸리면 남는 피해 0")


func test_siege_limit_and_pin() -> void:
	var t := _t()
	var s := _a()
	var o := Combat.officer_unit(s, t, "icheolmin", 1)    # 조장급
	var g := Combat.group_unit(t, "건달급", 20, 0)
	var siege := {}
	Combat._act(t, g, [o], 10000, false, siege, _rng("siege"), [100, 100], t["combat"]["raid"]["morale"])
	eq(siege["icheolmin"], 6, "한 대상에 6명까지")
	eq(o["max"] - o["hp"], 6 * 10, "6 × ATK 10 × rank_damage_k(차 1 → 1.0)")


func test_cards_surprise_ambush_shield() -> void:
	var t := _t()
	var s := _a()
	var mk := func(): return [Combat.group_unit(t, "건달급", 30, 0)]
	var mkd := func(): return [Combat.group_unit(t, "건달급", 30, 1)]
	var plain := Combat._section(s, t, 0, mk.call(), mkd.call(), [], [], _rng("p"), {"learned": []})
	var A: Array = mk.call()
	var sur := Combat._section(s, t, 0, A, mkd.call(), ["surprise"], [], _rng("p"), {"learned": []})
	eq(sur["result"], "att", "기습 — 첫 두 틱 지키는 쪽이 못 쳐서 들어가는 쪽이 이긴다")
	eq(A[0]["n"], 30, "기습이면 첫 구간에서 잃지 않는다(첫 틱에 다 쓰러뜨림)")
	var D: Array = mkd.call()
	var A2: Array = mk.call()
	var amb := Combat._section(s, t, 0, A2, D, [], ["ambush"], _rng("p"), {"learned": []})
	check(amb["log"].size() >= 1, "매복 구간이 돌았다 %s" % str(plain["result"]))
	var A3: Array = [Combat.group_unit(t, "건달급", 30, 0)]
	var D3: Array = [Combat.group_unit(t, "건달급", 30, 1)]
	Combat._act(t, D3[0], A3, 10000, true, {}, _rng("sh"), [100, 100], t["combat"]["raid"]["morale"])
	eq(A3[0]["n"], 30 - 18, "방패조 — 조직원 손실 × 0.6(300 피해 → 180 → 18명)")


func test_empty_zone_capture_and_raiders_stay() -> void:
	var t := _t()
	var s := _a()
	var rec := Combat.raid(s, t, 1, "namgu", "bujinpa", ["kimshin"], [], [], _rng("e"))
	check(rec["won"], "주인 없는 구역은 바로 차지")
	eq(s["zones"]["namgu"]["owner"], "bujinpa", "주인")
	eq(s["zones"]["namgu"]["facilities"], ["office"], "사무실")
	eq(s["officers"]["kimshin"]["zone"], "bujindong", "나선 간부는 출발한 구역으로 돌아온다")
	eq(s["orgs"]["bujinpa"]["heat"], 800 + 300, "습격 열기 +3%")


func test_capture_hq_retreat_and_captive() -> void:
	var t := _t()
	var s := _a()
	var before: int = s["orgs"]["dssecurity"]["troops"]["건달급"]
	var rec := Combat.raid(s, t, 3, "bukgu", "bujinpa", ["kimshin", "jintae", "woojin"], ["surprise"], [], _rng("hq"))
	check(rec["won"], "김신 · 서진태 · 피우진이 DS 본거지를 뚫는다")
	eq(s["zones"]["bukgu"]["owner"], "bujinpa", "북구 주인")
	eq(s["orgs"]["dssecurity"]["hq_lost_turn"], 3, "본거지 잃은 턴")
	for sl in s["zones"]["bukgu"]["slots"]:
		check(sl["org"] != "dssecurity", "옛 주인 사업장은 넘어온다")
	check(rec["sections"][2]["duels"].size() + rec["sections"][0]["duels"].size() + rec["sections"][1]["duels"].size() >= 1, "간부끼리 맞닥뜨려 일기토")
	for id in ["yundeoksu", "kimdaegeon", "kimseongjun"]:
		var p: Dictionary = s["officers"][id]
		check(p["zone"] == "hoeamsijang" or p["status"] == "captive", "%s — 회암시장으로 물러남(다쳐도)" % id)
	check(s["orgs"]["dssecurity"]["troops"]["건달급"] < before, "지킨 조직원을 잃었다")
	eq(State.check_invariants(s, t), [], "불변식")
	var r2 := Combat.raid(s, t, 3, "hoeamsijang", "bujinpa", ["kimshin"], [], [], _rng("hq2"))
	check(r2["won"], "마지막 구역")
	for id in ["yundeoksu", "kimdaegeon", "kimseongjun"]:
		eq(s["officers"][id]["status"], "captive", "%s — 물러날 곳이 없으면 잡힘" % id)


func test_heal_returns_to_active() -> void:
	var t := _t()
	var s := _a()
	Combat._wound(s, "jintae", 3000)
	eq(s["officers"]["jintae"]["status"], "wounded", "다침")
	var ctx := _ctx(s)
	Combat.heal(s, ctx)
	eq(s["officers"]["jintae"]["wound"], 1500, "한 주에 15%")
	Combat.heal(s, ctx)
	eq([s["officers"]["jintae"]["wound"], s["officers"]["jintae"]["status"]], [0, "active"], "다 나으면 움직인다")


func test_run_phase_groups_and_rejects() -> void:
	var t := _t()
	var s := _a()
	var os := [Orders.make("bujinpa", "kimshin", "raid", "namgu", {"cards": []}),
		Orders.make("bujinpa", "jintae", "raid", "namgu", {"cards": ["charge"]}),
		Orders.make("bujinpa", "woojin", "raid", "namgu", {"cards": ["surprise", "charge"]}),
		Orders.make("bujinpa", "chasumin", "raid", "namgu", {"cards": []}),
		Orders.make("bujinpa", "icheolmin", "raid", "namgu", {"cards": []}),
		Orders.make("bujinpa", "kimshin", "raid", "bujindong", {"cards": []}),
		Orders.make("dssecurity", "yundeoksu", "defend", "bukgu", {"card": "ambush"}),
		Orders.make("dssecurity", "kimdaegeon", "defend", "bukgu", {"card": "ambush"})]
	var ctx := _ctx(s, os)
	Combat.run_phase(s, ctx)
	var rep: Dictionary = ctx["report"]
	eq(rep["battles"].size(), 1, "남구 습격 하나로 묶음")
	eq(rep["battles"][0]["by"].size(), 4, "간부 4명까지")
	eq(rep["battles"][0]["cards"], ["charge", "surprise"], "카드는 낸 차례 · 겹치지 않게 2장까지")
	var whys: Array = rep["rejected"].map(func(r): return r["why"])
	check(whys.has("습격 간부는 4명까지"), "다섯째는 거절 %s" % str(whys))
	check(whys.has("이미 우리 구역이다"), "우리 구역 습격은 거절")
	check(whys.any(func(w): return w.begins_with("이 구역 지키기 카드는 이미")), "같은 지키기 카드 두 번은 거절")


func test_order_checks() -> void:
	var t := _t()
	var s := _a()
	var ctx := _ctx(s)
	var raid := func(to: String, cards: Array): return Orders.apply_one(s, Orders.make("bujinpa", "kimshin", "raid", to, {"cards": cards}), ctx)
	eq(raid.call("namgu", []), "", "이웃 빈 구역")
	eq(raid.call("bukgu", []), "bujindong → bukgu 땅길이 없다", "이웃이 아님")
	eq(raid.call("nowhere", []), "판에 없는 구역 nowhere", "없는 구역")
	eq(raid.call("namgu", ["ambush"]), "습격에 못 쓰는 카드 ambush", "지키는 카드")
	eq(raid.call("namgu", ["charge", "charge"]), "같은 카드를 두 번 charge", "같은 카드")
	eq(raid.call("namgu", ["charge", "surprise", "shield"]), "작전 카드는 2장까지", "카드 수")
	eq(raid.call("hoeamsijang", ["bypass"]), "우회로 — 그 구역 정보 2 이상 필요", "정보 없이 우회로")
	s["orgs"]["bujinpa"]["intel"]["hoeamsijang"] = 2
	eq(raid.call("hoeamsijang", ["bypass"]), "", "정보 2 면 우회로")
	var rec := Combat.raid(s, t, 1, "hoeamsijang", "bujinpa", ["kimshin"], ["bypass"], [], _rng("by"))
	eq(rec["sections"][1]["result"], "skip", "안 구간 건너뜀")
	var dfd := func(by: String, to: String, card): return Orders.apply_one(s, Orders.make("bujinpa", by, "defend", to, {"card": card}), ctx)
	eq(dfd.call("kimshin", "bujindong", "ambush"), "", "우리 구역 매복")
	eq(dfd.call("kimshin", "bukgu", "ambush"), "우리 구역에서만 지킨다", "남의 구역")
	eq(dfd.call("kimshin", "bujindong", "charge"), "지키기에 못 쓰는 카드 charge", "습격 카드")


func test_decoy_success_and_fail() -> void:
	var t := _t()
	var s := _a()
	var rec := Combat.raid(s.duplicate(true), t, 1, "bukgu", "bujinpa", ["kimshin"], ["decoy"], [], _rng("d1"))
	eq(rec["notes"][0], {"card": "decoy", "ok": true, "who": "yundeoksu"}, "김신 계산 92 ≥ 윤덕수 55 — 윤덕수를 붙잡아 둠")
	check(not rec["def_officers"].has("yundeoksu"), "붙잡힌 간부는 지키지 않는다")
	var rec2 := Combat.raid(s.duplicate(true), t, 1, "bukgu", "bujinpa", ["icheolmin"], ["decoy"], [], _rng("d2"))
	eq(rec2["notes"][0]["ok"], false, "이철민 계산 50 < 윤덕수 55 — 미끼 실패")


func test_same_seed_same_record() -> void:
	var t := _t()
	var r1 := Combat.raid(_a(), t, 1, "bukgu", "bujinpa", ["jintae", "woojin"], ["charge"], ["ambush"], _rng("same"))
	var r2 := Combat.raid(_a(), t, 1, "bukgu", "bujinpa", ["jintae", "woojin"], ["charge"], ["ambush"], _rng("same"))
	eq(JSON.stringify(r1), JSON.stringify(r2), "같은 갈래 난수 · 같은 상태면 같은 기록")


func test_tick_cap_defender_holds() -> void:
	var t := _t()
	var s := _a()
	var t2 := t.duplicate()
	var cb: Dictionary = t["combat"].duplicate(true)
	cb["raid"]["tick_cap"] = 1
	t2["combat"] = cb
	var A := [Combat.officer_unit(s, t2, "kimshin", 0)]
	check(A[0]["imm"], "김신은 무적 기술(좌우로 사라지는 스텝)이 있다")
	var D := [Combat.group_unit(t2, "경호대급", 100, 1)]
	var sec := Combat._section(s, t2, 0, A, D, [], [], _rng("cap"), {"learned": []})
	eq(sec["ticks"], 1, "틱 상한")
	eq(sec["result"], "def", "상한을 넘기면 지키는 쪽이 버틴 것")
	eq(D[0]["n"], 95, "원콤 쓸어 내기 1 + ⌊8/2⌋ = 5명")
	eq(A[0]["hp"], A[0]["max"], "무적 3틱 — 아랫급 피해 없음")
