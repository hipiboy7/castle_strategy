extends RefCounted
## [옮김] castle_M3D `src/data/skills.gd`(2c3e69b) — 바꾼 것: 규칙을 인스턴스(rules — fight/rules_rt.gd)로 받는다 · 그 판의 결투 전용 값
## (백도찬 엇박 패턴 · 처음 게이지 · 진행 사건으로 배우기)은 옮기지 않았다. 설계: docs/C4_설계서_직접조작전투.md 4-1 · 요구: FR-401
## 기술 값의 얇은 층: 2층(비용 · 한 방 · 기절 초)은 전부 rules 에서 읽고, 여기 남는 것은 3층 — 기술 id → 동작(fight/moves.gd) 표와
## 3D 덧붙임 기절(moves.gd stun_3d). 시험: tests/unit/test_fight_rules.gd · test_fight_world.gd

## 기술 id(castle_common skills.json) → 이 판 동작(fight/moves.gd). 여기 없는 기술은 동작이 없어 실시간 전투에서 고를 수 없다
const MOVE_OF := {"kickarts": "s_kick", "triple": "s_triple", "offbeat": "s_offbeat", "offbeat2": "s_offbeat2",
	"offbeat_rev": "s_offbeat_rev", "vanish_step": "s_vanish", "amur_triple": "s_amur3", "amur_weaving": "s_weave",
	"jin_original": "s_jt_original", "jintae_vital": "s_jt_vital", "jintae_storm": "s_jt_storm", "woojin_core_counter": "s_wj_core"}


## 등급 차 한 방(2층 one_shot) — immune 이면(판이 면제한 사람) 걸리지 않는다
static func one_shot(rules, att_rank: String, def_rank: String, immune: bool) -> bool:
	return not immune and att_rank != "" and def_rank != "" and rules.one_shot(att_rank, def_rank)


## 기술의 ko_rank(2층 skill_ko): 맞는 쪽 등급이 그 이하면 한 대에
static func kills(rules, mv: Dictionary, def_rank: String) -> bool:
	var sid := str(mv.get("skill_id", ""))
	return sid != "" and def_rank != "" and rules.skill_ko(sid, def_rank)


## 고를 수 있는 기술 한 칸 — 이름은 skills.json, 비용은 skill_cost(쓰는 사람 등급). cost -1 = 전부(all_min_bars 칸 이상일 때)
static func entry(rules, id: String, rank: String) -> Dictionary:
	var c = rules.skill_cost(id, rank)
	return {"id": id, "name": str(rules.skill(id).get("name", id)), "move": MOVE_OF[id], "cost": -1.0 if c == null else float(c)}


## 아는 기술 id 목록 → 고를 수 있는 목록(이 판에 동작이 있는 것만 · 순서 그대로)
static func entries(rules, ids: Array, rank: String) -> Array:
	var out: Array = []
	for id in ids:
		if MOVE_OF.has(id):
			out.append(entry(rules, id, rank))
	return out


## 기절 프레임(60 = 1초): 2층 stun_sec 이 먼저, 없으면 3D 덧붙임 stun_3d [아랫급에게, 같은 급 · 윗급에게]
static func stun_frames(rules, mv: Dictionary, att_rank: String, def_rank: String) -> int:
	if mv.get("stun_off", false):
		return 0
	var sid := str(mv["skill_id"])
	if sid != "" and rules.has_skill(sid):
		var sec: float = rules.stun_sec(sid, att_rank, def_rank)
		if sec > 0.0:
			return roundi(sec * 60.0)
	var rel: Array = mv["stun_3d"]
	if rel.is_empty():
		return 0
	return int(rel[0]) if rules.rank_gap(att_rank, def_rank) > 0 else int(rel[1])
