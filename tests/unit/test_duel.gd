extends "res://tests/helpers.gd"
## FR-303 · FR-304 — 일기토(sim/duel.gd): 체력 · 보통 맞힘 공식(08 14-3) · 원콤 · 막기 0.7 · 쳐내기 반격 · 엇박이 막기를 뚫음 · 게이지 얻기 ·
## 기술 비용 · 기절 · 러시안 룰렛 · 무적 · 카피(copy.seen 2) · 같은 난수면 같은 결과 · 비기면 지키는 쪽. 받은 사본(규칙 2층) + 3층 combat.json.

const Duel = preload("res://sim/duel.gd")
const Pcg32 = preload("res://sim/rng.gd")
const DataFiles = preload("res://src/data_files.gd")

var _tables := {}


func _t() -> Dictionary:
	if _tables.is_empty():
		_tables = DataFiles.load_tables()
	return _tables


## 손으로 만든 싸울 사람(능력치를 정해 공식을 바로 본다)
func _f(id: String, rank: String, power: int = -1, skills: Array = [], parry := false, copy := false, hp := 1000) -> Dictionary:
	return {"id": id, "rank": rank, "r": _t()["rules"].rank_index(rank), "hp": hp, "max": hp, "power": power, "speed": 50, "tech": -1,
		"skills": skills, "seen": {}, "parry": parry, "copy": copy,
		"gauge": 0, "stun": false, "guards": 0, "immune": 0}


func _rng(tag: String):
	return Pcg32.new().init_stream(1, 1, "test", tag)


func test_fighter_hp_formula() -> void:
	var t := _t()
	var s := {"officers": {"kimshin": {"rank": "내성 중위", "skills": ["kickarts"], "seen": {}, "org": "bujinpa"},
		"chasumin": {"rank": "조장급", "skills": [], "seen": {}, "org": "bujinpa"}}}
	var k := Duel.fighter(t, s, "kimshin")
	eq(k["hp"], 600 + 30 * 11 + 4 * 85, "김신 체력 = 600 + 30r + 4 × 맷집")
	eq([k["power"], k["speed"], k["parry"], k["copy"]], [80, 90, true, true], "힘 · 속도 · 쳐내기 · 카피는 1층 인물")
	var c := Duel.fighter(t, s, "chasumin")
	eq(c["hp"], 600 + 30 * 1 + 200, "맷집이 없으면 + 200")
	eq(c["power"], -1, "힘 없음")


func test_hit_damage_formula() -> void:
	var t := _t()
	var a := _f("a", "외성 하위", 75)
	var b := _f("b", "외성 하위", 60)
	eq(Duel.hit_damage(t, a, b), 75, "같은 등급: 60 × (0.5 + 0.75) = 75")
	var low := _f("c", "건달급", -1)
	eq(Duel.hit_damage(t, low, b), 35, "힘 없음 60 × 1.0 × rank_damage_k(일곱 등급 아래 1 − 0.07 × 6 = 0.58) = 35")
	var up := _f("d", "외성 상위", 50)
	eq(Duel.hit_damage(t, up, b), Duel.Fixed.div_round(60 * 1250, 1000), "두 등급 위: × 1.25")


func test_one_shot_ends_on_first_hit() -> void:
	var t := _t()
	var top := _f("a", "내성 중위", 80)
	var low := _f("b", "경호대급", 60)
	var r := Duel.fight(t, top, low, _rng("os"))
	eq(r["winner"], "a", "다섯 등급 이상 위가 이긴다")
	check(r["ko"], "한 방")
	check(r["rounds"].size() <= 6, "6합 안")
	eq(r["wound"], int(t["combat"]["duel"]["ko_wound"]), "한 방이면 중상")


func test_guard_parry_and_pierce() -> void:
	var t := _t()
	var F := [_f("a", "외성 하위", 50), _f("b", "외성 하위", 50)]
	var gain := [[], []]
	Duel._strike(t, F, 0, [{"card": "attack", "skill": ""}, {"card": "guard", "skill": ""}], "guard", gain, [])
	eq(F[1]["hp"], 1000 - Duel.Fixed.div_round(60 * 700, 1000), "막기 = 피해 × guard.damage_k 0.7")
	eq(gain, [["hit"], ["guard", "taken"]], "게이지 이름 — 친 쪽 hit · 막은 쪽 guard + taken")
	F = [_f("a", "외성 하위", 50), _f("b", "외성 하위", 50, [], true)]
	gain = [[], []]
	Duel._strike(t, F, 0, [{"card": "attack", "skill": ""}, {"card": "parry", "skill": ""}], "parry", gain, [])
	eq(F[1]["hp"], 1000, "쳐내기 — 피해 없음")
	eq(F[0]["hp"], 1000 - Duel.Fixed.bp(60, 5000), "쳐낸 쪽 반격 = 보통 맞힘 × 0.5")
	eq(gain[1], ["parry"], "parry 게이지")
	F = [_f("a", "내성 중위", 80, ["offbeat"]), _f("b", "내성 하위", 50)]
	F[0]["gauge"] = 1000
	gain = [[], []]
	Duel._strike(t, F, 0, [{"card": "skill", "skill": "offbeat"}, {"card": "guard", "skill": ""}], "guard", gain, [])
	var frac: float = t["rules"].lethal_fraction("offbeat", "내성 하위", "내성 중위", null)
	eq(F[1]["hp"], 1000 - Duel.Fixed.div_round(1000 * Duel.Fixed.milli(frac), 1000), "엇박은 막기를 뚫고 lethal_fraction × 최대 체력")
	eq(F[0]["gauge"], 1000 - Duel.cost_points(t, "offbeat", "내성 중위"), "엇박 비용(점)을 냈다")


func test_gauge_and_cost() -> void:
	var t := _t()
	var f := _f("a", "내성 중위", 80)
	f["tech"] = 95
	var rate: float = t["rules"].gauge_rate("내성 중위", 95)
	eq(Duel.gain_points(t, f, ["hit", "taken"]), Duel.Fixed.div_round(11 * Duel.Fixed.milli(rate) * 5, 1000), "얻기 = (hit 6 + taken 5) × gauge_rate × K_TURN 5")
	eq(Duel.gauge_max(t, f), 10 * 100, "내성 중위 게이지 10칸")
	eq(Duel.cost_points(t, "amur_weaving", "내성 중위"), 200, "고정 비용 2칸 = 200점")
	eq(Duel.cost_points(t, "offbeat2", "내성 중위"), -1, "엇엇박은 전부(cost_all)")
	eq(Duel.best_skill(t, _with_gauge(_f("x", "내성 중위", 80, ["amur_triple", "amur_weaving"]), 150), _f("y", "외성 하위")), "amur_triple", "낼 수 있는 가장 비싼 기술(1칸)")
	eq(Duel.best_skill(t, _with_gauge(_f("x", "내성 중위", 80, ["amur_triple", "amur_weaving"]), 250), _f("y", "외성 하위")), "amur_weaving", "2칸이면 위빙")
	eq(Duel.best_skill(t, _with_gauge(_f("x", "내성 중위", 80, ["vanish_step"]), 500), _f("y", "톱")), "", "무적 기술은 윗급 상대에게 안 씀")


func _with_gauge(f: Dictionary, g: int) -> Dictionary:
	f["gauge"] = g
	return f


func test_stun_ko_rank_roulette_immune() -> void:
	var t := _t()
	var F := [_with_gauge(_f("a", "내성 중위", 80, ["kickarts"]), 500), _f("b", "외성 하위", 50)]
	var notes := []
	Duel._strike(t, F, 0, [{"card": "skill", "skill": "kickarts"}, {"card": "attack", "skill": ""}], "", [[], []], notes)
	check(F[1]["stun"], "각법 — 아랫급 기절 3초 → 다음 합 거름")
	eq(Duel.choose(t, F[1], F[0], _rng("st"))["card"], "stunned", "기절한 쪽 카드")
	F = [_with_gauge(_f("a", "내성 중위", 80, ["amur_weaving"]), 500), _f("b", "외성 상위", 50)]
	Duel._strike(t, F, 0, [{"card": "skill", "skill": "amur_weaving"}, {"card": "attack", "skill": ""}], "", [[], []], [])
	eq(F[1]["hp"], 0, "위빙 ko_rank 외성 상위 이하 — 한 방")
	F = [_with_gauge(_f("a", "외성 하위", 50, ["jintae_vital"]), 500), _f("b", "외성 하위", 50, ["roulette"])]
	Duel._strike(t, F, 0, [{"card": "skill", "skill": "jintae_vital"}, {"card": "attack", "skill": ""}], "", [[], []], [])
	eq(F[0]["hp"], F[1]["hp"], "러시안 룰렛 — 같은 등급 기술은 같은 피해를 돌려준다")
	F = [_f("a", "외성 하위", 50), _f("b", "내성 중위", 80)]
	F[1]["immune"] = 2
	Duel._strike(t, F, 0, [{"card": "attack", "skill": ""}, {"card": "attack", "skill": ""}], "", [[], []], [])
	eq(F[1]["hp"], 1000, "무적 중에는 아랫급 공격이 안 들어간다")


## castle_common 92차 '턴제 판 해석'(rules/등급과_게이지.md 4절 ② · rules/기술.md 5절 ① ④ ⑤ — castle_srpg 와 같이 따른다)
func test_turn_based_interpretation_92() -> void:
	var t := _t()
	var F := [_f("a", "내성 중위", 80), _f("b", "경호대급", 60)]
	Duel._strike(t, F, 0, [{"card": "attack", "skill": ""}, {"card": "guard", "skill": ""}], "guard", [[], []], [])
	eq(F[1]["hp"], 0, "② 막기는 한 방을 줄이지 않는다 — 막아도 쓰러진다")
	F = [_with_gauge(_f("a", "외성 상위", 80, ["amur_weaving"]), 500), _f("b", "외성 상위", 50, ["roulette"])]
	Duel._strike(t, F, 0, [{"card": "skill", "skill": "amur_weaving"}, {"card": "attack", "skill": ""}], "", [[], []], [])
	eq([F[0]["hp"], F[1]["hp"]], [1, 0], "① 룰렛이 한 방 기술(skill_ko)을 돌려주면 친 쪽 체력 1 을 남긴다")
	F = [_with_gauge(_f("a", "내성 중위", 80, ["offbeat"]), 1000), _f("b", "외성 하위", 50)]
	Duel._strike(t, F, 0, [{"card": "skill", "skill": "offbeat"}, {"card": "attack", "skill": ""}], "", [[], []], [])
	eq(F[1]["hp"], 0, "④ 한 방이 이긴다 — 다섯 등급 위의 엇박은 쓰러뜨림(비율 1)")
	F = [_with_gauge(_f("a", "내성 중위", 80, ["offbeat2"]), 1000), _f("b", "내성 중위", 80, [], false, false, 100000)]
	F[0]["hp"] = 100
	Duel._strike(t, F, 0, [{"card": "skill", "skill": "offbeat2"}, {"card": "attack", "skill": ""}], "", [[], []], [])
	eq(F[0]["hp"], 1, "⑤ 엇엇박 self_cost(최대 체력 × 0.2 = 200)로 쓴 사람은 쓰러지지 않는다 — 체력 1")


func test_copy_after_seen_twice() -> void:
	var t := _t()
	var shin := _f("kimshin", "내성 중위", 80, [], false, true, 100000)
	var foe := _f("jintae", "외성 하위", 75, ["jintae_vital"], false, false, 100000)
	foe["skills"] = ["jintae_vital"]
	var seen_total := 0
	var learned := false
	for i in 20:
		var r := Duel.fight(t, shin, foe, _rng("cp%d" % i))
		shin["seen"] = r["seen"][0]
		seen_total = int(shin["seen"].get("jintae_vital", 0))
		if not r["learned"][0].is_empty():
			learned = true
			eq(r["learned"][0], ["jintae_vital"], "본 기술을 배운다")
			break
	check(learned, "두 번 보면 배운다(본 수 %d)" % seen_total)
	check(seen_total >= 2, "copy.seen 2 이상에서")


func test_same_rng_same_result_and_tie() -> void:
	var t := _t()
	var a := _f("a", "외성 하위", 75, ["jintae_vital", "jintae_storm"])
	var b := _f("b", "외성 하위", 70)
	var r1 := Duel.fight(t, a, b, _rng("same"))
	var r2 := Duel.fight(t, a, b, _rng("same"))
	eq(JSON.stringify(r1), JSON.stringify(r2), "같은 갈래 난수면 같은 기록")
	check(r1["rounds"].size() >= 1 and r1["rounds"].size() <= 6, "1~6합")
	var g1 := _f("g1", "건달급", -1, [], false, false, 100000)
	var g2 := _f("g2", "건달급", -1, [], false, false, 100000)
	g1["speed"] = 50
	var guards := {"card": "guard", "skill": ""}
	var F := [g1.duplicate(true), g2.duplicate(true)]
	Duel._resolve(t, F, [guards, guards], [[], []], [])
	eq([F[0]["hp"], F[1]["hp"]], [100000, 100000], "둘 다 막기 — 피해 없음")
	var tie := Duel.fight(t, _f("p", "건달급", -1, [], false, false, 1000000), _f("q", "건달급", -1, [], false, false, 1000000), _rng("tie"))
	check(not tie["ko"], "체력이 많으면 6합까지")
	eq(tie["rounds"].size(), 6, "6합")
