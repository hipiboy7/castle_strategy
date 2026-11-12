extends "res://tests/helpers.gd"
## C4-2 FR-415 — 구간 결과 계약(sim/combat.gd outcome_error · raid opts): 실시간 판(fight/section.gd)이 낸 결과는 검증을 지난다 ·
## 꼴 · 범위 · 승패가 틀린 결과는 까닭과 함께 버린다 · 받은 결과를 넣으면 구간 기록에 rt · 본 횟수 → 배우기 · 묻는 조직이면 need · 버린 결과는 틱.
## 설계: docs/C4_설계서_직접조작전투.md 2-3 · 2-4 · 2-5

const Combat = preload("res://sim/combat.gd")
const State = preload("res://sim/state.gd")
const Pcg32 = preload("res://sim/rng.gd")
const FightTest = preload("res://src/fight_test.gd")
const Section = preload("res://fight/section.gd")
const DataFiles = preload("res://src/data_files.gd")

var _tables := {}


func _t() -> Dictionary:
	if _tables.is_empty():
		_tables = DataFiles.load_tables()
	return _tables


func _raid(s: Dictionary, opts: Dictionary) -> Dictionary:
	var cfg: Dictionary = _t()["fight"]["test"]["raid"]
	var rng = Pcg32.new().init_stream(int(s["seed"]), 1, "clash", "%s|%s" % [cfg["zone"], cfg["org"]])
	return Combat.raid(s, _t(), 1, cfg["zone"], cfg["org"], cfg["by"], cfg["cards"], [], rng, opts)


func test_real_outcome_passes() -> void:
	var t := _t()
	var r := FightTest.raid(t, 1)
	var need := FightTest.raid_need(t, r, 0)
	var d := Section.simulate(t, need, {"by": "auto"})
	var out := Section.outcome(d)
	eq(Combat.outcome_error(t, 0, r["prep"]["A"], r["prep"]["D"][0], out), "", "실시간 판이 낸 결과는 검증을 지난다")
	var back = State.ints(JSON.parse_string(JSON.stringify(out)), [], "x")
	eq(Combat.outcome_error(t, 0, r["prep"]["A"], r["prep"]["D"][0], back), "", "글로 갔다 와도(저장) 지난다")


func test_bad_results_rejected() -> void:
	var t := _t()
	var r := FightTest.raid(t, 1)
	var A: Array = r["prep"]["A"]
	var D: Array = r["prep"]["D"][0]
	var good := FightTest.fake(FightTest.raid_need(t, r, 0), true)
	eq(Combat.outcome_error(t, 0, A, D, good), "", "꾸민 결과(이김)는 지난다")
	eq(Combat.outcome_error(t, 0, A, D, FightTest.fake(FightTest.raid_need(t, r, 0), false)), "", "꾸민 결과(짐)도 지난다")
	var cases := {
		"사전 아님": func(x): return [1],
		"칸 없음": func(x): x.erase("a"); return x,
		"구간 번호": func(x): x["i"] = 1; return x,
		"by": func(x): x["by"] = "cheat"; return x,
		"승패 불일치": func(x): x["result"] = "def"; return x,
		"틱 상한": func(x): x["ticks"] = 999; return x,
		"줄 수": func(x): x["a"].pop_back(); return x,
		"체력 늘어남": func(x): x["a"][0]["hp"] += 1; return x,
		"실수 체력": func(x): x["a"][0]["hp"] = 1.5; return x,
		"쓰러졌는데 체력": func(x): x["a"][0]["down"] = true; return x,
		"머릿수 늘어남": func(x): x["a"][x["a"].size() - 1]["n"] += 1; return x,
		"등급 바뀜": func(x): x["a"][x["a"].size() - 1]["grade"] = "톱"; return x,
		"사기 범위": func(x): x["morale"] = [100, -1]; return x,
		"카피 못 하는 사람": func(x): x["seen"] = {"jintae": {"kickarts": 1}}; return x,
		"없는 기술": func(x): x["seen"] = {"kimshin": {"no_such": 1}}; return x,
		"kills": func(x): x["kills"] = [1]; return x,
	}
	for name in cases:
		var bad = cases[name].call(good.duplicate(true))
		var why := Combat.outcome_error(t, 0, A, D, bad)
		check(why != "", "%s — 버린다(%s)" % [name, why])


func test_raid_asks_then_applies() -> void:
	var t := _t()
	var s: Dictionary = FightTest.raid(t, 1)["s"]
	var cfg: Dictionary = t["fight"]["test"]["raid"]
	var key := "%s|%s" % [cfg["zone"], cfg["org"]]
	var fights := {key: {}}
	var before := State.hash_of(s)
	var need: Dictionary = _raid(State.to_dict(s), {"ask": cfg["org"], "fights": fights})["need"]
	eq([need["i"], need["side"], need["key"]], [0, 0, key], "들어가는 쪽이면 첫 구간을 묻는다")
	eq(State.hash_of(s), before, "준비만 — 원본 상태 그대로")
	var asked := [0]
	for k in 3:
		fights[key][str(need["i"])] = FightTest.fake(need, true)
		var rec := _raid(State.to_dict(s), {"ask": cfg["org"], "fights": fights})
		if not rec.has("need"):
			eq(asked, [0, 1, 2], "구간마다 차례로 묻는다")
			check(rec["won"], "세 구간 다 이기면 차지")
			eq(rec["sections"].map(func(x): return x.get("rt", "")), ["direct", "direct", "direct"], "구간 기록에 직접 표시")
			eq(rec["used"].keys().size(), 3, "쓴 결과 셋")
			eq(rec["rejected"], [], "버린 것 없음")
			return
		need = rec["need"]
		asked.append(need["i"])
	check(false, "세 구간 안에 끝나야 한다")


func test_auto_key_and_other_org_tick() -> void:
	var t := _t()
	var s: Dictionary = FightTest.raid(t, 1)["s"]
	var cfg: Dictionary = t["fight"]["test"]["raid"]
	var key := "%s|%s" % [cfg["zone"], cfg["org"]]
	var plain := _raid(State.to_dict(s), {})
	var auto := _raid(State.to_dict(s), {"ask": cfg["org"], "auto": [key]})
	var other := _raid(State.to_dict(s), {"ask": "baekui"})
	check(not auto.has("need") and not other.has("need"), "결과만(auto) · 상관없는 조직은 묻지 않는다")
	eq(str(auto["sections"]), str(plain["sections"]), "결과만 = 틱 그대로")
	eq(str(other["sections"]), str(plain["sections"]), "상관없는 조직 = 틱 그대로")


func test_rejected_falls_back_to_tick() -> void:
	var t := _t()
	var s: Dictionary = FightTest.raid(t, 1)["s"]
	var cfg: Dictionary = t["fight"]["test"]["raid"]
	var key := "%s|%s" % [cfg["zone"], cfg["org"]]
	var plain := _raid(State.to_dict(s), {})
	var asked := _raid(State.to_dict(s), {"ask": cfg["org"], "fights": {key: {"0": {"v": 1, "i": 0}}}})
	eq(asked.get("need", {}).get("i", -1), 1, "버린 구간은 다시 묻지 않고 틱 → 다음 구간을 묻는다")
	var rec := _raid(State.to_dict(s), {"fights": {key: {"0": {"v": 1, "i": 0}}}})
	check(not rec.has("need"), "다시 돌리기(묻지 않음)")
	eq(rec["rejected"].size(), 1, "버린 결과를 기록")
	eq(rec["rejected"][0]["i"], 0, "버린 구간 번호")
	eq(str(rec["sections"][0]["log"]), str(plain["sections"][0]["log"]), "버린 구간은 틱과 같다")


func test_seen_counts_and_learns() -> void:
	var t := _t()
	var s: Dictionary = FightTest.raid(t, 1)["s"]
	var cfg: Dictionary = t["fight"]["test"]["raid"]
	var key := "%s|%s" % [cfg["zone"], cfg["org"]]
	var sk := ""
	for c in ["triple", "inch", "roulette", "jin_original", "baek_wide"]:
		if not s["officers"]["kimshin"]["skills"].has(c) and t["rules"].can_learn(c, s["officers"]["kimshin"]["rank"], "kimshin"):
			sk = c
			break
	check(sk != "", "배울 수 있는 기술 하나")
	var n0 := int(s["officers"]["kimshin"]["seen"].get(sk, 0))
	var need: Dictionary = _raid(State.to_dict(s), {"ask": cfg["org"]})["need"]
	var res := FightTest.fake(need, false)
	res["seen"] = {"kimshin": {sk: int(t["rules"].rule("copy", "seen", 2))}}
	var s2 := State.to_dict(s)
	var rec := _raid(s2, {"ask": cfg["org"], "fights": {key: {"0": res}}})
	check(not rec.has("need"), "진 구간 뒤엔 끝")
	check(s2["officers"]["kimshin"]["skills"].has(sk), "본 횟수가 차면 배운다(sim 이 판단)")
	eq(int(s2["officers"]["kimshin"]["seen"][sk]), n0 + int(t["rules"].rule("copy", "seen", 2)), "본 횟수 더하기")
	check(rec["learned"].any(func(x): return x["id"] == "kimshin" and x["skill"] == sk), "기록 learned")
