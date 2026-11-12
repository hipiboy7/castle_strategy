extends "res://tests/helpers.gd"
## FR-402 — 구간 판(fight/section.gd): 틱 유닛에서 싸울 사람을 만들고 봇으로 끝까지 돌려 구간 결과(정수)를 낸다.
## 같은 시드면 같은 결과 · 결과 꼴(설계서 2-3) · 끝 조건(머릿수 · 사기 · 시간) · 화면 상한과 채우기 · 편 나누기(내 쪽 = 0) · 교대 · 사람 입력.
## 받은 사본(규칙 2층) + 3층 combat.json · fight.json · fight_roles.json. B 등급(흐름 — headless N 프레임).

const Section = preload("res://fight/section.gd")
const Combat = preload("res://sim/combat.gd")
const Game = preload("res://sim/game.gd")
const DataFiles = preload("res://src/data_files.gd")

var _tables := {}


func _t() -> Dictionary:
	if _tables.is_empty():
		_tables = DataFiles.load_tables()
	return _tables


## 준비 하나 — 들어가는 쪽 간부들 대 지키는 쪽 조직원 묶음들. side = 내가 선 쪽
func _need(officers: Array, troops: Array, seed := 1, side := 0) -> Dictionary:
	var t := _t()
	var s: Dictionary = Game.new_game(t, "A", 1)["state"]
	var a := []
	var d := []
	var known := {}
	for id in officers:
		a.append(Combat.officer_unit(s, t, id, 0))
		known[id] = {"skills": Array(s["officers"][id]["skills"]).duplicate(), "seen": {}}
	for g in troops:
		d.append(Combat.group_unit(t, g[0], int(g[1]), 1))
	return {"key": "bukgu|bujinpa", "turn": 1, "zone": "bukgu", "att": "bujinpa", "def": "dssecurity", "i": 0, "side": side,
		"A": a, "D": d, "cards": [], "def_cards": [], "known": known, "seed": seed}


func test_same_seed_same_outcome() -> void:
	var t := _t()
	var a := Section.simulate(t, _need(["kimshin"], [["건달급", 12], ["조장급", 4]], 7))
	var b := Section.simulate(t, _need(["kimshin"], [["건달급", 12], ["조장급", 4]], 7))
	check(a["over"] != "", "구간이 끝난다(over %s · frames %d)" % [a["over"], a["frames"]])
	eq(JSON.stringify(Section.outcome(a)), JSON.stringify(Section.outcome(b)), "같은 시드 · 같은 준비면 같은 구간 결과")
	eq(JSON.stringify(Section.summary(a)), JSON.stringify(Section.summary(b)), "요약도 같다")


func test_bot_officer_sweeps_thugs() -> void:
	var t := _t()
	var need := _need(["kimshin"], [["건달급", 12]])
	var d := Section.simulate(t, need)
	var o := Section.outcome(d)
	eq(o["result"], "att", "김신(내성 중위) 하나가 건달급 12명을 치운다")
	eq(d["over"], "win", "내가 들어가는 쪽이면 이긴 것")
	eq(o["d"][0]["n"], 0, "지키는 쪽 묶음이 남지 않는다")
	eq(o["kills"], [12, 0], "쓰러뜨린 수")
	check(not o["a"][0]["down"] and o["a"][0]["hp"] >= 1 and o["a"][0]["hp"] <= need["A"][0]["hp"], "간부 체력은 들어올 때 값 안(%s)" % o["a"][0]["hp"])
	check(o["ticks"] >= 1 and o["ticks"] <= int(t["combat"]["raid"]["tick_cap"]), "걸린 틱 %s" % o["ticks"])


func test_outcome_shape_is_integers() -> void:
	var t := _t()
	var need := _need(["kimshin", "jintae"], [["건달급", 6], ["조장급", 2]])
	var o := Section.outcome(Section.simulate(t, need))
	for k in ["v", "i", "by", "result", "ticks", "a", "d", "morale", "seen", "frames", "kills"]:
		check(o.has(k), "구간 결과 칸 %s" % k)
	eq(o["a"].size(), need["A"].size(), "들어가는 쪽 줄 수는 유닛과 같다")
	eq(o["d"].size(), need["D"].size(), "지키는 쪽 줄 수는 유닛과 같다")
	eq(o["a"][1]["id"], "jintae", "차례 · id 가 유닛과 같다")
	eq(o["d"][1]["grade"], "조장급", "묶음 등급이 유닛과 같다")
	var errs := []
	preload("res://sim/state.gd").ints(JSON.parse_string(JSON.stringify(o)), errs, "outcome")
	eq(errs, [], "정수 · 글 · 참거짓만(저장 형식에 들어간다)")


func test_no_defenders_ends_at_once() -> void:
	var t := _t()
	var d := Section.simulate(t, _need(["kimshin"], []))
	var o := Section.outcome(d)
	eq(o["result"], "att", "지키는 쪽이 없으면 들어가는 쪽이 넘는다")
	eq(o["ticks"], 0, "틱을 쓰지 않는다(틱 습격의 빈 구간과 같다)")
	check(int(d["frames"]) <= int(t["fight"]["intro_frames"]) + 2, "들어서자 끝난다(frames %d)" % d["frames"])


func test_defender_side_maps_to_my_team() -> void:
	var t := _t()
	var s: Dictionary = Game.new_game(t, "A", 1)["state"]
	var need := {"key": "bujindong|dssecurity", "turn": 1, "zone": "bujindong", "att": "dssecurity", "def": "bujinpa", "i": 2, "side": 1,
		"A": [Combat.group_unit(t, "건달급", 8, 0)], "D": [Combat.officer_unit(s, t, "kimshin", 1)],
		"cards": [], "def_cards": [], "known": {}, "seed": 3}
	var d := Section.make(t, need)
	eq(d["mine"].size(), 1, "지키는 쪽에 선 내 간부가 조종 대상")
	eq(d["mine"][0].team, 0, "내 쪽은 편 0")
	Section.run(d)
	var o := Section.outcome(d)
	eq(o["result"], "def", "들어온 무리를 다 쓰러뜨리면 지키는 쪽이 버틴 것")
	eq(d["over"], "win", "지키는 내가 이긴 것")
	eq(o["i"], 2, "구간 번호가 그대로")
	eq(o["kills"], [0, 8], "지키는 쪽이 쓰러뜨린 수")


func test_field_cap_and_reinforce() -> void:
	var t := _t()
	var cap := int(t["fight"]["on_field"]["foe"])
	var d := Section.make(t, _need(["kimshin"], [["건달급", cap + 9]]))
	eq(Section.heads(d, 1), cap + 9, "남은 머릿수 = 서 있는 수 + 아직 못 선 수")
	var worst := 0
	var guard := 0
	while d["over"] == "" and guard < 20000:
		Section.step(d)
		d["world"].events.clear()
		var on := 0
		for f in d["world"].fighters:
			if f.team == 1 and f.alive():
				on += 1
		worst = maxi(worst, on)
		guard += 1
	check(worst <= cap, "화면에 서는 상대는 상한 %d 까지(가장 많을 때 %d)" % [cap, worst])
	eq(Section.outcome(d)["kills"][0], cap + 9, "채워 들어온 사람까지 다 쓰러뜨린다")


func test_weak_officer_falls_and_morale_drops() -> void:
	var t := _t()
	var mo: Dictionary = t["combat"]["raid"]["morale"]
	var d := Section.simulate(t, _need(["icheolmin"], [["경호대급", 30]]))   # 건달급 간부 하나 대 경호대급 무리
	var o := Section.outcome(d)
	eq(o["result"], "def", "아랫급 간부 하나는 윗급 무리를 못 넘는다")
	eq(d["over"], "lose", "들어간 내가 진 것")
	check(o["a"][0]["down"] and o["a"][0]["hp"] == 0, "쓰러진 간부는 체력 0")
	eq(o["a"][0]["wound"], int(t["combat"]["raid"]["down_wound"]), "조직원에게 쓰러지면 raid.down_wound")
	check(o["morale"][0] <= int(mo["start"]) - int(mo["officer_down"]), "간부가 쓰러지면 그 쪽 사기가 깎인다(%s)" % o["morale"][0])


func test_swap_and_human_input() -> void:
	var t := _t()
	var d := Section.make(t, _need(["kimshin", "jintae"], [["건달급", 4]]), {"ctrl": "jintae"})
	eq(d["hero"].char_id, "jintae", "고른 간부를 조종한다")
	check(Section.swap(d), "교대할 수 있다")
	eq(d["hero"].char_id, "kimshin", "교대하면 다음 간부")
	for i in int(t["fight"]["intro_frames"]) + 1:
		Section.step(d, {})
	var x0: float = d["hero"].pos.x
	for i in 30:
		Section.step(d, {"move": Vector2(1, 0), "face": Vector2(1, 0)})
	check(d["hero"].pos.x > x0 + 0.5, "사람 입력으로 조종 간부가 움직인다(%.2f → %.2f)" % [x0, d["hero"].pos.x])
	Section.step(d, {"swap": true})
	eq(d["hero"].char_id, "jintae", "입력 swap 으로 교대")
	d["mine"][d["ctrl"]].die()
	d["world"].events.append(["ko", d["mine"][d["ctrl"]]])
	Section.step(d)
	eq(d["hero"].char_id, "kimshin", "조종 간부가 쓰러지면 다음 간부로 넘어간다")


## FR-405 — 전투 시험 준비(src/fight_test.gd): 표의 test 줄대로 need 를 만들고, 같은 시드면 같은 FIGHT 값
func test_fight_test_fixture() -> void:
	var FightTest = preload("res://src/fight_test.gd")
	var t := _t()
	var cfg: Dictionary = t["fight"]["test"]
	var need: Dictionary = FightTest.need(t, 1)
	eq(need["A"][0]["id"], cfg["officer"], "시험 간부")
	eq(need["D"].size(), cfg["troops"].size(), "시험 무리 묶음 수")
	eq(need["D"][0]["n"], int(cfg["troops"][0][1]), "묶음 머릿수")
	check(need["seed"] != FightTest.need(t, 2)["seed"], "시드가 다르면 구간 시드도 다르다")
	var a: Dictionary = FightTest.run(t, 1)
	eq(JSON.stringify(a), JSON.stringify(FightTest.run(t, 1)), "같은 시드면 같은 값")
	check(a["over"] != "" and a["outcome"]["result"] != "", "구간이 끝난다(%s)" % a["over"])


## FR-408 · FR-409 — 습격 하나를 3구간으로: 틱과 같은 준비(prepare) · 간부 최대 4 · 들어가는 쪽 체력 · 머릿수가 구간을 넘어 이어진다
func test_raid_three_sections_carry() -> void:
	var FightTest = preload("res://src/fight_test.gd")
	var t := _t()
	var r: Dictionary = FightTest.raid(t, 1)
	var offs: Array = r["prep"]["A"].filter(func(u): return u["t"] == "o")
	check(offs.size() >= 2 and offs.size() <= int(t["combat"]["raid"]["max_officers"]), "참전 간부 %d 명(최대 4)" % offs.size())
	var n0: Dictionary = FightTest.raid_need(t, r, 0)
	var n1: Dictionary = FightTest.raid_need(t, r, 1)
	check(n0["seed"] != n1["seed"], "구간마다 다른 시드")
	eq(n0["cards"], t["fight"]["test"]["raid"]["cards"], "카드가 need 로")
	var d := Section.simulate(t, n0, {"by": "auto"}, int(t["fight"]["test"]["max_frames"]))
	var o := Section.outcome(d)
	FightTest.carry(r, o)
	var n1b: Dictionary = FightTest.raid_need(t, r, 1)
	for k in o["a"].size():
		var row: Dictionary = o["a"][k]
		var u: Dictionary = n1b["A"][k]
		if row["t"] == "o":
			eq([u["hp"], u["down"]], [row["hp"], row["down"]], "다음 구간 간부 %s 체력 · 쓰러짐이 이어진다" % row["id"])
		else:
			eq(u["n"], row["n"], "다음 구간 %s 머릿수가 이어진다" % row["grade"])
	eq(FightTest.next_section(r, 0), 1, "다음 구간")
	r["prep"]["skip"] = 1
	eq(FightTest.next_section(r, 0), 2, "우회로로 건너뛴 구간은 넘는다")
	eq(FightTest.next_section(r, 2), -1, "마지막 뒤는 없다")
	var run: Dictionary = FightTest.run(t, 1)
	check(run["sections"].size() >= 1 and run["sections"].size() <= 3, "구간 %d 개" % run["sections"].size())
	eq(run["won"], run["over"] == "win" and run["sections"].size() == 3, "셋 다 이기면 습격을 이긴다")


## FR-413 — 작전 카드(틱과 같은 combat.json 값): 정면 돌파 · 기습 · 매복은 첫 구간만 · 방패조는 모든 구간
func test_cards_scale_like_ticks() -> void:
	var t := _t()
	var cd: Dictionary = t["combat"]["cards"]
	var tf := int(t["fight"]["tick_frames"])
	var need := _need(["kimshin"], [["건달급", 6]])
	need["cards"] = ["charge", "shield"]
	need["def_cards"] = ["ambush", "shield"]
	var d := Section.make(t, need)
	var w = d["world"]
	eq(w.team_dmg_k, [float(cd["charge"]["dmg_bp"]) / 10000.0, float(cd["ambush"]["dmg_bp"]) / 10000.0], "정면 돌파 × 1.2 · 매복 × 1.5(첫 구간)")
	eq(w.mob_taken_k, [0.6, 0.6], "방패조 — 그 쪽 조직원이 받는 피해 × 0.6")
	while int(d["fight_t"]) <= tf:
		Section.step(d)
		w.events.clear()
	eq(w.team_dmg_k[1], 1.0, "매복은 첫 틱 길이만")
	var n2 := need.duplicate(true)
	n2["i"] = 1
	var d2 := Section.make(t, n2)
	eq(d2["world"].team_dmg_k, [1.0, 1.0], "둘째 구간 — 정면 돌파 · 매복 없음")
	eq(d2["world"].mob_taken_k, [0.6, 0.6], "방패조는 그대로")
	var n3 := _need(["kimshin"], [["건달급", 6]])
	n3["cards"] = ["surprise"]
	var d3 := Section.make(t, n3)
	var hold := int(cd["surprise"]["skip_ticks"]) * tf
	eq(d3["surprise"], hold, "기습 — 틱 둘 × 틱 길이")
	var struck := false
	while int(d3["fight_t"]) < hold:
		Section.step(d3)
		for f in d3["ais"]:
			struck = struck or not f.intent.is_empty()
		d3["world"].events.clear()
	check(not struck, "기습 동안 지키는 쪽은 치지 못한다")
	var later := false
	for k in 120:
		Section.step(d3)
		for f in d3["ais"]:
			later = later or not f.intent.is_empty()
		d3["world"].events.clear()
	check(later, "기습이 끝나면 친다")
	eq(Section._no_strike({"attack": true, "skill": true, "use": "x", "dash": true, "move": Vector2(1, 0), "parry": true}),
		{"move": Vector2(1, 0), "parry": true}, "기습 중 지키는 쪽 사람 입력 — 치기 · 기술 · 대시를 뺀다")


## FR-411 · 92차 해석 ⑥ — 간부가 기술을 내면 서 있는 can_copy 간부(같은 편 · 기절 중도)가 본 횟수 +1 · 한 신호는 한 번만 센다
func test_copy_counts_seen() -> void:
	var t := _t()
	var need := _need(["kimshin", "jintae"], [["건달급", 2]])
	var d := Section.make(t, need)
	var k = d["mine"][0] if d["mine"][0].char_id == "kimshin" else d["mine"][1]
	var j = d["mine"][1] if k == d["mine"][0] else d["mine"][0]
	check(k.can_copy, "김신은 카피(1층 can_copy)")
	k.state = "stun"
	var w = d["world"]
	d["ev0"] = w.events.size()
	w.events.append(["skill", j, {"id": "jintae_vital"}])
	w.events.append(["skill", j, {"id": "없는 기술"}])
	Section._after(d)
	Section._after(d)
	eq(d["seen"].get("kimshin", {}), {"jintae_vital": 1}, "같은 편 기술 · 기절 중에도 본다 · 없는 기술은 안 센다 · 같은 신호는 한 번")
	check(not d["seen"].has("jintae") or j.can_copy, "can_copy 가 아니면 세지 않는다")
	d["over"] = "win"
	d["result"] = "att"
	eq(Section.outcome(d)["seen"], {"kimshin": {"jintae_vital": 1}}, "구간 결과의 seen")


## FR-410 — 동시에 치는 수는 대상마다(attackers): 내 간부 둘이면 한꺼번에 둘보다 많이 칠 수 있지만, 한 사람에게는 attackers 까지
func test_attackers_cap_per_target() -> void:
	var t := _t()
	var cap := int(t["fight"]["attackers"])
	var d := Section.make(t, _need(["kimshin", "jintae"], [["건달급", 20]], 3))
	var most := 0
	var total := 0
	for k in 900:
		Section.step(d)
		d["world"].events.clear()
		var by := {}
		var n := 0
		for f in d["ais"]:
			if d["ais"][f].busy() and f.target() != null:
				by[f.target()] = int(by.get(f.target(), 0)) + 1
				n += 1
		for v in by.values():
			most = maxi(most, v)
		total = maxi(total, n)
		if d["over"] != "":
			break
	check(most <= cap, "한 사람에게 동시에 %d 명까지(본 최대 %d)" % [cap, most])
	check(total > cap, "대상이 둘이면 모두 합쳐 %d 명보다 많이 친다(본 최대 %d)" % [cap, total])


## FR-409 — 시작할 때 조종할 간부를 고른다 · 쓰러진 간부는 못 고른다 · 내 간부 목록(위 표시)
func test_pick_ctrl_and_party() -> void:
	var t := _t()
	var d := Section.make(t, _need(["kimshin", "jintae", "woojin"], [["건달급", 4]]))
	eq(d["mine"][d["ctrl"]].char_id, "kimshin", "처음은 첫 간부(등급 높은 순)")
	check(Section.set_ctrl(d, "woojin"), "피우진을 고른다")
	eq(d["hero"].char_id, "woojin", "조종 간부가 바뀐다")
	var p := Section.party(d)
	eq(p.map(func(x): return x["id"]), ["kimshin", "jintae", "woojin"], "목록 차례")
	eq(p.map(func(x): return x["ctrl"]), [false, false, true], "조종 표시")
	d["mine"][1].hp = 0.0
	d["mine"][1].state = "dead"
	check(not Section.set_ctrl(d, "jintae"), "쓰러진 간부는 못 고른다")
	check(not Section.set_ctrl(d, "없는 사람"), "없는 사람")
	eq(Section.party(d)[1]["down"], true, "쓰러짐 표시")
