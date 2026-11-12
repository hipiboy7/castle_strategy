extends RefCounted
## 싸울 사람 만들기 — 틱 습격의 유닛(sim/combat.gd officer_unit · group_unit) + 1층 인물(t["chars"]) + 3층 표(data/game/fight.json ·
## fight_roles.json) → fight/fighter.gd. **값은 틱 유닛에서 온다**(같은 규칙 — docs/기획_차이.md (나)43 ⓐ): 체력 = 유닛 체력,
## 한 대 기준 피해 = 유닛 공격(조직원이 끼면) · 일기토 보통 맞힘(간부끼리 — 맞는 쪽 체력 환산과 함께). 공식을 다시 적지 않고
## sim/duel.gd 의 순수 함수(fighter · hit_damage)를 부른다. 판 상태는 받지 않는다(유닛 · 아는 기술만).
## 설계: docs/C4_설계서_직접조작전투.md 4-3 · 5절 · 요구: FR-402 · 시험: tests/unit/test_fight_rules.gd

const Fighter = preload("res://fight/fighter.gd")
const Skills = preload("res://fight/skills.gd")
const Duel = preload("res://sim/duel.gd")
const CM := 0.01                    # 표의 길이(cm) → m
const BP := 10000.0


## 인물의 역할(동작 묶음 · AI 프로필 · 모델) — fight_roles.json roles → 없으면 default
static func role_of(t: Dictionary, id: String) -> Dictionary:
	var fr: Dictionary = t["fight_roles"]
	return fr["roles"].get(id, fr["default"])


## 조직원 등급의 역할(AI 프로필 목록 · 모델 목록) — 없는 등급은 건달급 줄
static func troop_role(t: Dictionary, grade: String) -> Dictionary:
	var tr: Dictionary = t["fight_roles"]["troops"]
	return tr.get(grade, tr["건달급"])


## 빠르기 배율 — 0.5 + 0.5 × 속도 ÷ speed_ref(속도가 없으면 1.0 · castle_M3D addendum.derive 와 같은 꼴)
static func speed_k(t: Dictionary, stats: Dictionary) -> float:
	if not stats.has("속도"):
		return 1.0
	return 0.5 + 0.5 * float(stats["속도"]) / float(t["fight"]["speed_ref"])


## 일기토 값(08 14-3) — {"hp": 일기토 체력, "hit": 보통 맞힘(등급 차 곱하기 전)}. sim/duel.gd 공식 그대로
static func duel_of(t: Dictionary, id: String, rank: String) -> Dictionary:
	var f: Dictionary = Duel.fighter(t, {"officers": {id: {"rank": rank, "skills": [], "seen": {}}}}, id)
	return {"hp": int(f["max"]), "hit": Duel.hit_damage(t, f, f)}


## 간부 — u = 간부 유닛 · known = {"skills": [아는 기술 id], "seen": {…}}(판 상태의 사본 · 없으면 빈 사전)
static func officer(t: Dictionary, rules, u: Dictionary, team: int, known: Dictionary = {}):
	var fc: Dictionary = t["fight"]
	var base: Dictionary = fc["officer"]
	var id: String = u["id"]
	var c: Dictionary = t["chars"].get(id, {})
	var st: Dictionary = c.get("stats", {})
	var role := role_of(t, id)
	var f = Fighter.new(String(t["names"].get(id, id)), team, rules)
	f.char_id = id
	f.rank = u["rank"]
	var hk := float(fc["hp_bp"]) / BP
	f.hp_max = float(u["max"]) * hk
	f.hp = float(u["hp"]) * hk
	var du := duel_of(t, id, u["rank"])
	f.atk_mob = float(u["atk"])
	f.atk_off = float(du["hit"])
	f.off_k = float(u["max"]) / float(du["hp"])
	var sk := speed_k(t, st)
	f.walk_speed = float(base["walk"]) * CM * sk
	f.run_speed = float(base["run"]) * CM * sk
	f.posture_max = float(role.get("posture", base["posture"]))
	f.stagger_len = int(role.get("stagger", base["stagger"]))
	f.poise = float(role.get("poise", base["poise"]))
	f.moveset = role["moveset"]
	f.can_parry = c.get("can_parry", false) == true
	f.can_copy = c.get("can_copy", false) == true
	f.roulette = Array(known.get("skills", [])).has("roulette")
	f.skills = Skills.entries(rules, known.get("skills", []), f.rank)
	f.gauge_max = rules.bars_for(f.rank) * rules.bar_points()
	f.gauge_rate = rules.gauge_rate(f.rank, st.get("기술"))
	return f


## 조직원 한 명 — u = 묶음 유닛(등급 · hp1 · atk1). 몸놀림은 AI 쪽(is_boss — 예고를 보이고 연타를 잇지 않는다)
static func troop(t: Dictionary, rules, u: Dictionary, team: int):
	var fc: Dictionary = t["fight"]
	var base: Dictionary = fc["troop"]
	var f = Fighter.new("", team, rules)
	f.is_mob = true
	f.is_boss = true
	f.rank = u["grade"]
	f.hp_max = float(u["hp1"]) * float(fc["hp_bp"]) / BP
	f.hp = f.hp_max
	f.atk_mob = float(u["atk1"])
	f.walk_speed = float(base["walk"]) * CM
	f.run_speed = float(base["run"]) * CM
	f.posture_max = float(base["posture"])
	f.stagger_len = int(base["stagger"])
	f.poise = float(base["poise"])
	f.can_parry = false
	return f


## 적 AI 가 막는 확률 — 간부는 기술 능력치에서(castle_M3D derive.guard — 0.55 × 기술 ÷ speed_ref, 0.05 ~ 0.8), 없으면 표 값
static func guard_rate(t: Dictionary, id: String) -> float:
	var st: Dictionary = t["chars"].get(id, {}).get("stats", {})
	if st.has("기술"):
		return clampf(0.55 * float(st["기술"]) / float(t["fight"]["speed_ref"]), 0.05, 0.8)
	return float(t["fight"]["officer"]["guard_bp"]) / BP
