extends RefCounted
## 1 · 2층 규칙 함수 — castle_common `ref/rules.py` 공개 함수 20개를 같은 이름 · 같은 인자로 옮겼다(castle_M3D src/data/common.gd 를 바탕으로).
## 같은지는 tests/unit/test_common_cases.gd 가 castle_common `cases/rules_cases.json` 전부로 본다(실수는 1e-9 — 요구 FR-112).
## sim/ 이라 파일을 읽지 않는다 — 받은 사본 5개(FILES)의 JSON 값을 받아 만든다: RulesCommon.from_files(files) 또는 .new(…).
## JSON 수는 실수로 온다 — 칸 수 · 등급 번호는 int() 로 바꿔 쓴다. 모르는 등급은 -1(찍지 않는다 — sim/tables.gd 검사가 먼저 잡는다).
## 뜻: castle_common `rules/등급과_게이지.md` · `rules/기술.md`. 결과 실수는 상태에 넣기 전에 ×1000 정수로 바꾼다(설계서 3-6).

const FILES := ["common/ranks.json", "common/rules.json", "common/skills.json", "common/characters.json", "common/progression.json"]

var ranks: Array = []            # 아래 → 위 15개(ranks.json ladder — below · strength 는 읽지 않는다)
var _rank_no := {}
var _rules := {}
var _skills := {}
var _chars := {}
var _prog := {}


func _init(ranks_json: Dictionary = {}, rules_json: Dictionary = {}, skills_json: Dictionary = {},
		chars_json: Dictionary = {}, prog_json: Dictionary = {}) -> void:
	ranks = Array(ranks_json.get("ladder", [])).duplicate()
	for i in ranks.size():
		_rank_no[ranks[i]] = i
	_rules = rules_json
	for s in skills_json.get("skills", []):
		_skills[s["id"]] = s
	for c in chars_json.get("characters", []):
		_chars[c["id"]] = c
	_prog = prog_json


static func from_files(files: Dictionary) -> RefCounted:
	var g := func(k): return files.get(k) if files.get(k) is Dictionary else {}
	return load("res://sim/rules_common.gd").new(g.call(FILES[0]), g.call(FILES[1]), g.call(FILES[2]), g.call(FILES[3]), g.call(FILES[4]))


func _gauge() -> Dictionary:
	return _rules.get("gauge", {})


func _skill(id: String) -> Dictionary:
	return _skills.get(id, {})


func rank_index(rank: String) -> int:
	return int(_rank_no.get(rank, -1))


# ---- 게이지 (rules/등급과_게이지.md 2절)
## 등급 → 게이지 칸 수: 가장 아래 1칸, 한 등급마다 +1, max_bars 에서 멈춘다
func bars_for(rank: String) -> int:
	return mini(int(_gauge()["max_bars"]), rank_index(rank) + 1)


## 차는 배율 = (1 + rank_rate_step × 등급 번호) × (0.5 + 기술 / 100) × (칸이 다 찬 등급보다 위면 fast_rank_k)
func gauge_rate(rank: String, tech = null) -> float:
	var g := _gauge()
	var t: float = float(g["default_tech"]) if tech == null else float(tech)
	var i := rank_index(rank)
	var fast: float = float(g["fast_rank_k"]) if i + 1 > int(g["max_bars"]) else 1.0
	return (1.0 + float(g["rank_rate_step"]) * i) * (0.5 + t / 100.0) * fast


# ---- 비용 (rules/기술.md 1절)
## 엇박 비용(칸) = offbeat_base + (가장 위 등급 번호 - 쓰는 사람 등급 번호)
func offbeat_cost(rank: String) -> float:
	return float(_rules["cost"]["offbeat_base"]) + float(ranks.size() - 1 - rank_index(rank))


## 칸 수. cost_all 이면 null(all_min_bars 칸 이상일 때 게이지 전부)
func skill_cost(skill: String, rank: String):
	var s := _skill(skill)
	if s.get("cost_all", false):
		return null
	if float(s.get("cost_k", 0.0)) > 0.0:
		return offbeat_cost(rank) * float(s["cost_k"])
	return float(s.get("cost", 1.0))


## only(이 사람들만) · min_rank(이 등급 이상) — 카피 · 전수 · 진행 모두 이것으로 거른다
func can_learn(skill: String, rank: String, char_id = null) -> bool:
	var s := _skill(skill)
	var only: Array = s.get("only", [])
	if not only.is_empty() and not only.has(char_id):
		return false
	var mr = s.get("min_rank", null)
	return mr == null or mr == "" or rank_index(rank) >= rank_index(mr)


# ---- 등급 차 (rules/등급과_게이지.md 3절)
func rank_gap(att_rank: String, def_rank: String) -> int:
	return rank_index(att_rank) - rank_index(def_rank)


func rank_damage_k(att_rank: String, def_rank: String) -> float:
	var rg: Dictionary = _rules["rank_gap"]
	var g := rank_gap(att_rank, def_rank)
	if g >= int(rg["from"]):
		return minf(float(rg["up_max"]), 1.0 + float(rg["up_k"]) * (g - 1))
	if g <= -int(rg["from"]):
		return maxf(float(rg["down_min"]), 1.0 - float(rg["down_k"]) * (-g - 1))
	return 1.0


func shrugs_off(def_rank: String, att_rank: String) -> bool:
	return rank_gap(def_rank, att_rank) >= int(_rules["rank_gap"]["armor_gap"])


## 보통 공격도 한 대에 쓰러뜨리나 — 치는 쪽이 one_shot_gap 등급 이상 위
func one_shot(att_rank: String, def_rank: String) -> bool:
	return rank_gap(att_rank, def_rank) >= int(_rules["rank_gap"]["one_shot_gap"])


## immune_lower 효과가 있는 기술을 쓰는 중이면, 아랫급(등급이 낮은 상대)의 공격에 무적
func immune_lower(owner_rank: String, att_rank: String) -> bool:
	return rank_gap(owner_rank, att_rank) > 0


# ---- 효과 (rules/기술.md 2 · 3절)
func rank_at_most(rank: String, top) -> bool:
	return top != null and top != "" and rank_index(rank) <= rank_index(top)


## 기절 초(0 = 없음). stun_rel_sec 은 쓰는 사람과 견주고(윗급이 치면 앞 값), stun_rank 는 맞는 쪽 등급만 본다
func stun_sec(skill: String, att_rank: String, def_rank: String) -> float:
	var fx: Dictionary = _skill(skill).get("effects", {})
	var rel: Array = fx.get("stun_rel_sec", [])
	if not rel.is_empty():
		return float(rel[0]) if rank_gap(att_rank, def_rank) > 0 else float(rel[1])
	if rank_at_most(def_rank, fx.get("stun_rank", null)):
		return float(fx["stun_rank_sec"])
	return 0.0


## ko_rank 효과 — 맞는 쪽이 그 등급 이하면 한 방(rules/기술.md 3절)
func skill_ko(skill: String, def_rank: String) -> bool:
	return rank_at_most(def_rank, _skill(skill).get("effects", {}).get("ko_rank", null))


func in_kill_zone(rank: String) -> bool:
	return rank_index(rank) <= rank_index(_rules["offbeat"]["kill_zone_top"])


func jesus_fraction(target_rank: String) -> float:
	return float(_rules["jesus"]["fraction"].get(target_rank, 1.0))


## lethal 효과의 피해 = 맞는 쪽 최대 체력의 비율(1.0 = 즉사)
func lethal_fraction(kind: String, target_rank: String, user_rank = null, paid_bars = null) -> float:
	var ob: Dictionary = _rules["offbeat"]
	if kind == "jesus":
		return jesus_fraction(target_rank)
	if kind == "offbeat2":
		if in_kill_zone(target_rank):
			return 1.0
		var paid: float = 0.0 if paid_bars == null else float(paid_bars)
		return minf(1.0, maxf(0.0, paid / float(_gauge()["max_bars"])))
	if kind == "offbeat" and in_kill_zone(target_rank):
		return 1.0
	var frac: float = float(ob["fraction"].get(target_rank, 1.0)) * float(ob["scale"][kind])
	if user_rank != null and rank_index(user_rank) < rank_index(target_rank):
		frac *= float(ob["lower_rank_k"])
	return minf(1.0, frac)


func roulette_reflects(owner_rank: String, attacker_rank: String) -> bool:
	return rank_index(attacker_rank) >= rank_index(owner_rank)


# ---- 진행 (rules/기술.md 4절)
## 처음 값에 사건들을 적용한 [등급, 아는 기술 목록]. extra 면 시점 미정 기술도. 모르는 인물은 ["", []]
func progress(char_id: String, events: Array = [], extra := false) -> Array:
	var c: Dictionary = _chars.get(char_id, {})
	var rank: String = String(c.get("rank", ""))
	var known: Array = Array(c.get("skills", [])).duplicate()
	for st in _prog.get("steps", []):
		if st[1] != char_id or not events.has(st[0]):
			continue
		if st[2] == "rank":
			rank = st[3]
		elif not known.has(st[3]):
			known.append(st[3])
	if extra:                                        # ref: skills += [s for s in unplaced if s not in skills] — 더하기 전 목록과 견준다
		var more: Array = []
		for s in _prog.get("unplaced", {}).get(char_id, []):
			if not known.has(s):
				more.append(s)
		known.append_array(more)
	return [rank, known]


func events_until(stage: int) -> Array:
	var out: Array = []
	var evs: Array = _prog.get("events", [])
	for i in mini(stage, evs.size()):
		out.append(evs[i][0])
	return out
