extends RefCounted
## 일기토 — 08 4-2 · 14-3. 두 간부가 합마다 카드 하나씩(공격 · 기술 · 막기 / 쳐낼 수 있으면 쳐내기)을 내는 3~6합 싸움을 자동으로 푼다.
## 순수 함수: fighter(t, s, id) 가 싸울 사람 값을 만들고, fight(t, a, b, rng) 가 기록 {winner, loser, ko, rounds[], seen, learned}을 낸다.
## 상태는 바꾸지 않는다 — 부상 · 카피(seen · skills)는 부르는 쪽(sim/combat.gd)이 기록을 보고 넣는다.
## 2층은 castle_common 값 그대로(rules_common · rules.json): 게이지 bars_for · gauge_rate · gauge.gain · 비용 skill_cost · 엇박 lethal_fraction ·
## 등급 차 rank_damage_k · one_shot · 막기 guard.damage_k · 쳐내기 can_parry · 룰렛 roulette_reflects · 기절 stun_sec · ko_rank · 카피 copy.seen · can_learn.
## castle_common 92차 '턴제 판 해석'(rules/기술.md 5절 · rules/등급과_게이지.md 4절): ① 룰렛이 즉사 계열을 돌려주면 친 쪽 체력 1 · ② 막기는 한 방을
## 줄이지 않음 · ④ 한 방이 lethal 기술보다 앞 · ⑤ 엇엇박 self_cost 는 체력 1 을 남김(③ 무리 쓸어 내기는 sim/combat.gd).
## 3층(data/game/combat.json duel): 체력 · 보통 맞힘 · K_TURN · 기술 피해 배율 · 쳐내기 반격 · 카드 고르는 확률 · 부상.
## 정수: 체력 · 게이지(점 — 한 칸 = gauge.bar_points)는 정수. 규칙 함수의 실수 결과는 Fixed.milli 로 바꿔 한 번 곱한다(설계서 3-6).
## 설계: docs/C3_설계서_습격과일기토.md 3절 · 요구: FR-303 · FR-304 · 시험: tests/unit/test_duel.gd

const Fixed = preload("res://sim/fixed.gd")
const OFFENSE := ["attack", "skill"]


## 싸울 사람 값 — 상태의 간부(등급 · 기술 · 본 기술) + 1층 인물(힘 · 속도 · 기술 · 맷집 · 쳐내기 · 카피). 없는 능력치는 3층 기본값
static func fighter(t: Dictionary, s: Dictionary, id: String) -> Dictionary:
	var p: Dictionary = s["officers"][id]
	var c: Dictionary = t["chars"].get(id, {})
	var st: Dictionary = c.get("stats", {})
	var d: Dictionary = t["combat"]["duel"]
	var r: int = t["rules"].rank_index(p["rank"])
	var hp: int = int(d["hp_base"]) + int(d["hp_step"]) * r
	hp += int(d["hp_tough"]) * int(st["맷집"]) if st.has("맷집") else int(d["hp_no_tough"])
	return {"id": id, "rank": p["rank"], "r": r, "hp": hp, "max": hp,
		"power": int(st["힘"]) if st.has("힘") else -1, "speed": int(st.get("속도", d["no_speed"])),
		"tech": int(st["기술"]) if st.has("기술") else -1,
		"skills": Array(p["skills"]).duplicate(), "seen": Dictionary(p["seen"]).duplicate(),
		"parry": c.get("can_parry", false) == true, "copy": c.get("can_copy", false) == true}


## 보통 맞힘 피해(막기 전) — 60 × (0.5 + 힘/100) × rank_damage_k(힘이 없으면 0.5 + 힘/100 대신 no_power_k)
static func hit_damage(t: Dictionary, att: Dictionary, def: Dictionary) -> int:
	var d: Dictionary = t["combat"]["duel"]
	var base: int = Fixed.div_round(int(d["hit"]) * (50 + att["power"]), 100) if att["power"] >= 0 else Fixed.bp(int(d["hit"]), int(d["no_power_k"]))
	return Fixed.div_round(base * Fixed.milli(t["rules"].rank_damage_k(att["rank"], def["rank"])), 1000)


## 게이지 최대(점)
static func gauge_max(t: Dictionary, f: Dictionary) -> int:
	return t["rules"].bars_for(f["rank"]) * int(t["rules"].rule("gauge", "bar_points", 100))


## 기술 비용(점) — cost_all 이면 -1(all_min_bars 칸 이상일 때 전부)
static func cost_points(t: Dictionary, skill: String, rank: String) -> int:
	var c = t["rules"].skill_cost(skill, rank)
	if c == null:
		return -1
	return Fixed.div_round(Fixed.milli(float(c)) * int(t["rules"].rule("gauge", "bar_points", 100)), 1000)


## 지금 게이지로 낼 수 있는 기술 가운데 가장 비싼 것(같으면 아는 차례). 무적 기술(immune_lower)은 상대가 아랫급일 때만 · 이미 무적이면 빼고
static func best_skill(t: Dictionary, f: Dictionary, foe: Dictionary) -> String:
	var bar := int(t["rules"].rule("gauge", "bar_points", 100))
	var best := ""
	var best_cost := -2
	for sk in f["skills"]:
		var info: Dictionary = t["rules"].skill_info(sk)
		if info.is_empty():
			continue
		var fx: Dictionary = info.get("effects", {})
		if fx.get("immune_lower", false) and (f.get("immune", 0) > 0 or not t["rules"].immune_lower(f["rank"], foe["rank"])):
			continue
		var c := cost_points(t, sk, f["rank"])
		var need: int = int(t["rules"].rule("cost", "all_min_bars", 5)) * bar if c < 0 else c
		var rank_c: int = 1000000 if c < 0 else c
		if f["gauge"] >= need and rank_c > best_cost:
			best = sk
			best_cost = rank_c
	return best


## 한 합의 카드 — 기절이면 stunned. 기술을 낼 수 있으면 skill_use_bp 확률로 기술, 아니면 attack_bp 확률로 공격 · 나머지 막기(쳐낼 수 있으면 쳐내기).
## 막기를 pressure 합 이어 했으면 막지 못한다(판정 압박)
static func choose(t: Dictionary, f: Dictionary, foe: Dictionary, rng) -> Dictionary:
	var d: Dictionary = t["combat"]["duel"]
	if f["stun"]:
		return {"card": "stunned", "skill": ""}
	var sk := best_skill(t, f, foe)
	if sk != "" and rng.chance_bp(int(d["skill_use_bp"])):
		return {"card": "skill", "skill": sk}
	if f["guards"] >= int(d["pressure"]) or rng.chance_bp(int(d["attack_bp"])):
		return {"card": "attack", "skill": ""}
	return {"card": "parry" if f["parry"] else "guard", "skill": ""}


## 일기토 한 판 — a · b 는 fighter 값. rng = Pcg32 갈래(부르는 쪽이 만든다). 비기면(6합 뒤 남은 체력 비율이 같으면) b(지키는 쪽)가 이긴다
static func fight(t: Dictionary, a: Dictionary, b: Dictionary, rng) -> Dictionary:
	var d: Dictionary = t["combat"]["duel"]
	var F := [a.duplicate(true), b.duplicate(true)]
	for f in F:
		f["gauge"] = 0
		f["stun"] = false
		f["guards"] = 0
		f["immune"] = 0
	var rounds := []
	var learned := [[], []]
	for i in int(d["rounds"]):
		var cards := [choose(t, F[0], F[1], rng), choose(t, F[1], F[0], rng)]
		var gain := [[], []]
		var notes := []
		for k in 2:
			F[k]["stun"] = false
		_resolve(t, F, cards, gain, notes)
		for k in 2:
			var dfd: bool = cards[k]["card"] == "guard" or cards[k]["card"] == "parry"
			F[k]["guards"] = F[k]["guards"] + 1 if dfd else 0
			F[k]["immune"] = maxi(0, F[k]["immune"] - 1) if cards[k]["skill"] == "" or not t["rules"].skill_info(cards[k]["skill"]).get("effects", {}).get("immune_lower", false) else F[k]["immune"]
			F[k]["gauge"] = mini(gauge_max(t, F[k]), F[k]["gauge"] + gain_points(t, F[k], gain[k]))
			var foe_card: Dictionary = cards[1 - k]
			if F[k]["copy"] and foe_card["card"] == "skill":
				var sk: String = foe_card["skill"]
				F[k]["seen"][sk] = int(F[k]["seen"].get(sk, 0)) + 1
				if F[k]["seen"][sk] >= int(t["rules"].rule("copy", "seen", 2)) and not F[k]["skills"].has(sk) \
						and t["rules"].can_learn(sk, F[k]["rank"], F[k]["id"]):
					F[k]["skills"].append(sk)
					learned[k].append(sk)
					notes.append("%s 카피 — %s" % [F[k]["id"], sk])
		rounds.append({"cards": cards, "hp": [F[0]["hp"], F[1]["hp"]], "gauge": [F[0]["gauge"], F[1]["gauge"]], "notes": notes})
		if F[0]["hp"] <= 0 or F[1]["hp"] <= 0:
			break
	var ko: bool = F[0]["hp"] <= 0 or F[1]["hp"] <= 0
	var w := 0
	if F[1]["hp"] <= 0 and F[0]["hp"] > 0:
		w = 0
	elif F[0]["hp"] <= 0:
		w = 1
	else:
		w = 0 if F[0]["hp"] * F[1]["max"] > F[1]["hp"] * F[0]["max"] else 1
	return {"winner": F[w]["id"], "loser": F[1 - w]["id"], "w": w, "ko": ko, "rounds": rounds,
		"max": [F[0]["max"], F[1]["max"]], "seen": [F[0]["seen"], F[1]["seen"]], "learned": learned,
		"wound": int(d["ko_wound"]) if ko else int(d["lose_wound"])}


## 합에 일어난 일(gauge.gain 이름들) → 게이지 점 = 합 × gauge_rate(등급, 기술) × K_TURN
static func gain_points(t: Dictionary, f: Dictionary, events: Array) -> int:
	var table: Dictionary = t["rules"].rule("gauge", "gain", {})
	var sum := 0
	for e in events:
		sum += int(table.get(e, 0))
	var rate: float = t["rules"].gauge_rate(f["rank"], null if f["tech"] < 0 else f["tech"])
	return Fixed.div_round(sum * Fixed.milli(rate) * int(t["combat"]["duel"]["k_turn"]), 1000)


## 카드 맞대기(14-3 표) — 둘 다 공세면 기술이 먼저, 같은 종류면 속도가 높은 쪽(같으면 a) 먼저. 먼저 쓰러지면 나중 쪽은 못 친다
static func _resolve(t: Dictionary, F: Array, cards: Array, gain: Array, notes: Array) -> void:
	var off := [OFFENSE.has(cards[0]["card"]), OFFENSE.has(cards[1]["card"])]
	if not off[0] and not off[1]:
		for k in 2:
			if cards[k]["card"] != "stunned":
				gain[k].append("dodge")
		return
	if off[0] and off[1]:
		var first := 0
		if cards[0]["card"] != cards[1]["card"]:
			first = 0 if cards[0]["card"] == "skill" else 1
		elif F[1]["speed"] > F[0]["speed"]:
			first = 1
		_strike(t, F, first, cards, "", gain, notes)
		if F[1 - first]["hp"] > 0 and F[first]["hp"] > 0:
			_strike(t, F, 1 - first, cards, "", gain, notes)
		return
	var att := 0 if off[0] else 1
	var dc: String = cards[1 - att]["card"]
	_strike(t, F, att, cards, dc if dc != "stunned" else "", gain, notes)


## att 가 친다 — guard("" · guard · parry)는 맞는 쪽 카드
static func _strike(t: Dictionary, F: Array, att: int, cards: Array, guard: String, gain: Array, notes: Array) -> void:
	var rules = t["rules"]
	var d: Dictionary = t["combat"]["duel"]
	var A: Dictionary = F[att]
	var D: Dictionary = F[1 - att]
	var card: Dictionary = cards[att]
	var sk: String = card["skill"]
	var fx: Dictionary = rules.skill_info(sk).get("effects", {}) if sk != "" else {}
	var paid := 0
	if sk != "":
		var c := cost_points(t, sk, A["rank"])
		paid = A["gauge"] if c < 0 else c
		A["gauge"] -= paid
		if fx.get("immune_lower", false):
			A["immune"] = int(d["immune_rounds"])
			notes.append("%s %s — 아랫급에게 무적 %d합" % [A["id"], sk, A["immune"]])
			return
	var dmg := hit_damage(t, A, D)
	var one: bool = rules.one_shot(A["rank"], D["rank"])
	var kill := one   # 즉사 계열(한 방 · 즉사 비율 1 · skill_ko) — 룰렛이 돌려줄 때 친 쪽 체력 1 을 남긴다(92차 해석 ①)
	if one:
		dmg = D["hp"]   # ④ 한 방이 이긴다 — lethal 기술도 쓰러뜨림
	elif sk != "":
		if fx.has("lethal"):
			var bars: float = float(paid) / float(rules.rule("gauge", "bar_points", 100))
			var frac: float = rules.lethal_fraction(fx["lethal"], D["rank"], A["rank"], bars)
			dmg = Fixed.div_round(D["max"] * Fixed.milli(frac), 1000)
			kill = frac >= 1.0
		elif rules.skill_ko(sk, D["rank"]):
			dmg = D["hp"]
			kill = true
		else:
			dmg = Fixed.bp(dmg, int(d["skill_bp"]))
	if guard == "parry":
		var counter := Fixed.bp(hit_damage(t, D, A), int(d["parry_counter_bp"]))
		A["hp"] = maxi(0, A["hp"] - counter)
		gain[1 - att].append("parry")
		gain[att].append("taken")
		notes.append("%s 쳐내기 — 반격 %d" % [D["id"], counter])
		return
	if guard == "guard":
		if one:
			notes.append("%s 한 방 — 막아도 쓰러진다" % A["id"])   # 92차 해석 ②
		elif not (fx.has("lethal") and d["pierce"].has(fx["lethal"])):
			dmg = Fixed.div_round(dmg * Fixed.milli(float(rules.rule("guard", "damage_k", 1.0))), 1000)
			gain[1 - att].append("guard")
		else:
			notes.append("%s 엇박 — 막기를 뚫음" % A["id"])
	if D["immune"] > 0 and rules.immune_lower(D["rank"], A["rank"]):
		notes.append("%s 무적 — 아랫급 공격이 안 들어감" % D["id"])
		return
	D["hp"] = maxi(0, D["hp"] - dmg)
	gain[att].append("finisher" if sk != "" else "hit")
	gain[1 - att].append("taken")
	if sk != "" and D["skills"].has("roulette") and rules.roulette_reflects(D["rank"], A["rank"]):
		A["hp"] = maxi(mini(1, A["hp"]) if kill else 0, A["hp"] - dmg)
		notes.append("%s 러시안 룰렛 — 같은 피해 %d 를 돌려줌" % [D["id"], dmg])
	if sk != "" and fx.has("self_cost") and A["hp"] > 0:   # ⑤ 엇엇박으로 쓴 사람은 쓰러지지 않는다 — 체력 1
		A["hp"] = maxi(1, A["hp"] - Fixed.div_round(A["max"] * Fixed.milli(float(fx["self_cost"])), 1000))
	if D["hp"] <= 0:
		gain[att].append("ko")
	elif sk != "" and rules.stun_sec(sk, A["rank"], D["rank"]) >= 1.0:
		D["stun"] = true
		notes.append("%s 기절 — 다음 합을 거른다" % D["id"])
