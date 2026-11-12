extends RefCounted
## 규칙 잇기 — 실시간 판정(fight/)이 2층 규칙을 읽는 하나뿐인 길. 표 t["rules"](sim/rules_common.gd 인스턴스 — castle_common
## ref/rules.py 와 같은 이름 · 인자 · cases 1e-9)를 감싸고, castle_M3D src/data/common.gd 에만 있던 읽기 함수(게이지 점 · 얻는 양 ·
## 막기 배율)를 더한다. 전역 · 정적 상태가 없다 — 싸울 사람 · 판(world)이 만들 때 이 인스턴스를 받아 든다(시험은 가짜 표를 넣는다).
## 2층 값을 여기 다시 적지 않는다. 설계: docs/C4_설계서_직접조작전투.md 4-2 · 요구: FR-401 · 시험: tests/unit/test_fight_rules.gd

var r                              # sim/rules_common.gd 인스턴스
var move_cache := {}               # fight/moves.gd get_move 가 이 규칙 표로 채운 동작 사본


func _init(rules) -> void:
	r = rules


# ---- 게이지 · 막기 상수(rules.json gauge · cost · guard)
func bar_points() -> float:
	return float(r.rule("gauge", "bar_points", 100.0))


func all_min_bars() -> int:
	return int(r.rule("cost", "all_min_bars", 5))


func gain_points(kind: String) -> float:
	return float(r.rule("gauge", "gain", {}).get(kind, 0.0))


func passive_per_frame() -> float:
	return float(r.rule("gauge", "passive_per_frame", 0.0))


func skill_hit_k() -> float:
	return float(r.rule("gauge", "skill_hit_k", 1.0))


func guard_k() -> float:
	return float(r.rule("guard", "damage_k", 0.7))


## 기술 한 줄(skills.json) — 모르는 기술은 빈 사전
func skill(id: String) -> Dictionary:
	return r.skill_info(id)


func has_skill(id: String) -> bool:
	return not r.skill_info(id).is_empty()


# ---- 2층 함수 — 이름 · 인자는 sim/rules_common.gd 와 같다
func rank_index(rank: String) -> int:
	return r.rank_index(rank)


func bars_for(rank: String) -> int:
	return r.bars_for(rank)


func gauge_rate(rank: String, tech = null) -> float:
	return r.gauge_rate(rank, tech)


func skill_cost(id: String, rank: String):
	return r.skill_cost(id, rank)


func rank_gap(att_rank: String, def_rank: String) -> int:
	return r.rank_gap(att_rank, def_rank)


func rank_damage_k(att_rank: String, def_rank: String) -> float:
	return r.rank_damage_k(att_rank, def_rank)


func shrugs_off(def_rank: String, att_rank: String) -> bool:
	return r.shrugs_off(def_rank, att_rank)


func one_shot(att_rank: String, def_rank: String) -> bool:
	return r.one_shot(att_rank, def_rank)


func skill_ko(id: String, def_rank: String) -> bool:
	return r.skill_ko(id, def_rank)


func immune_lower(owner_rank: String, att_rank: String) -> bool:
	return r.immune_lower(owner_rank, att_rank)


func rank_at_most(rank: String, top) -> bool:
	return r.rank_at_most(rank, top)


func stun_sec(id: String, att_rank: String, def_rank: String) -> float:
	return r.stun_sec(id, att_rank, def_rank)


func lethal_fraction(kind: String, target_rank: String, user_rank = null, paid_bars = null) -> float:
	return r.lethal_fraction(kind, target_rank, user_rank, paid_bars)


func roulette_reflects(owner_rank: String, attacker_rank: String) -> bool:
	return r.roulette_reflects(owner_rank, attacker_rank)
