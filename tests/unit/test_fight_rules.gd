extends "res://tests/helpers.gd"
## FR-401 · FR-402 — 규칙 잇기(fight/rules_rt.gd) · 기술 층(fight/skills.gd) · 싸울 사람 만들기(fight/build.gd).
## **같은 규칙 대조**(docs/기획_차이.md (나)43): 실시간 판이 쓰는 2층 값 = 표 t["rules"] 의 값 · 실시간 인물 값 = 틱 유닛 값 ·
## 간부끼리 쓰러지는 대 수 = 일기토(08 14-3)의 대 수. 받은 사본 + 3층 combat.json · fight.json · fight_roles.json.

const RulesRt = preload("res://fight/rules_rt.gd")
const Skills = preload("res://fight/skills.gd")
const Moves = preload("res://fight/moves.gd")
const Build = preload("res://fight/build.gd")
const EnemyAI = preload("res://fight/enemy_ai.gd")
const Looks = preload("res://ui/fight3d/looks.gd")
const Combat = preload("res://sim/combat.gd")
const Duel = preload("res://sim/duel.gd")
const Game = preload("res://sim/game.gd")
const DataFiles = preload("res://src/data_files.gd")

var _tables := {}


func _t() -> Dictionary:
	if _tables.is_empty():
		_tables = DataFiles.load_tables()
	return _tables


func test_rules_rt_same_values_as_table() -> void:
	var t := _t()
	var r = t["rules"]
	var rt = RulesRt.new(r)
	for a in ["건달급", "네임드", "외성 하위", "내성 중위", "톱"]:
		eq(rt.rank_index(a), r.rank_index(a), "rank_index %s" % a)
		eq(rt.bars_for(a), r.bars_for(a), "bars_for %s" % a)
		eq(rt.gauge_rate(a, 80), r.gauge_rate(a, 80), "gauge_rate %s" % a)
		eq(rt.gauge_rate(a), r.gauge_rate(a), "gauge_rate %s(기술 없음)" % a)
		eq(rt.skill_cost("kickarts", a), r.skill_cost("kickarts", a), "skill_cost %s" % a)
		eq(rt.stun_sec("kickarts", a, "네임드"), r.stun_sec("kickarts", a, "네임드"), "stun_sec %s" % a)
		eq(rt.rank_at_most(a, "네임드"), r.rank_at_most(a, "네임드"), "rank_at_most %s" % a)
		eq(rt.lethal_fraction("offbeat", a, "톱", 2), r.lethal_fraction("offbeat", a, "톱", 2), "lethal_fraction %s" % a)
		eq(rt.skill_ko("amur_weaving", a), r.skill_ko("amur_weaving", a), "skill_ko %s" % a)
		for b in ["건달급", "경호대급", "내성 상위"]:
			eq(rt.rank_gap(a, b), r.rank_gap(a, b), "rank_gap %s %s" % [a, b])
			eq(rt.rank_damage_k(a, b), r.rank_damage_k(a, b), "rank_damage_k %s %s" % [a, b])
			eq(rt.shrugs_off(a, b), r.shrugs_off(a, b), "shrugs_off %s %s" % [a, b])
			eq(rt.one_shot(a, b), r.one_shot(a, b), "one_shot %s %s" % [a, b])
			eq(rt.roulette_reflects(a, b), r.roulette_reflects(a, b), "roulette_reflects %s %s" % [a, b])
			eq(rt.immune_lower(a, b), r.immune_lower(a, b), "immune_lower %s %s" % [a, b])


func test_rules_rt_gauge_and_guard_read_rules_json() -> void:
	var t := _t()
	var r = t["rules"]
	var rt = RulesRt.new(r)
	eq(rt.bar_points(), float(r.rule("gauge", "bar_points")), "게이지 한 칸 점")
	eq(rt.all_min_bars(), int(r.rule("cost", "all_min_bars")), "엇엇박 최소 칸")
	eq(rt.passive_per_frame(), float(r.rule("gauge", "passive_per_frame")), "가만히 있어도 차는 양")
	eq(rt.skill_hit_k(), float(r.rule("gauge", "skill_hit_k")), "기술 맞힘 배율")
	eq(rt.guard_k(), float(r.rule("guard", "damage_k")), "막기 배율")
	check(is_equal_approx(rt.guard_k(), 0.7), "막기는 30%% 줄여 받는다(rules/전투_쳐내기.md 1-1 · %s)" % rt.guard_k())
	for kind in ["hit", "taken", "guard", "parry", "finisher", "ko", "dodge"]:
		eq(rt.gain_points(kind), float(r.rule("gauge", "gain")[kind]), "얻는 양 %s" % kind)
	eq(rt.gain_points("없는 것"), 0.0, "모르는 종류는 0")
	check(rt.has_skill("kickarts") and not rt.has_skill("없는 기술"), "받은 skills.json 에 있는 기술만 있다")
	eq(String(rt.skill("kickarts")["id"]), "kickarts", "기술 한 줄")
	check(rt.skill("없는 기술").is_empty(), "모르는 기술은 빈 사전")


func test_skills_layer() -> void:
	var t := _t()
	var rt = RulesRt.new(t["rules"])
	var list := Skills.entries(rt, ["kickarts", "amur_dash", "amur_weaving"], "내성 중위")
	eq(list.size(), 2, "동작이 있는 기술만 고를 수 있다(amur_dash 는 대시 + 공격)")
	eq(list[0]["move"], "s_kick", "기술 id → 동작")
	eq(list[0]["cost"], float(t["rules"].skill_cost("kickarts", "내성 중위")), "비용은 2층 skill_cost")
	for id in Skills.MOVE_OF:
		check(Moves.M.has(Skills.MOVE_OF[id]), "MOVE_OF %s 의 동작 %s 이 동작 표에 있다" % [id, Skills.MOVE_OF[id]])
		check(rt.has_skill(id), "MOVE_OF %s 은 받은 skills.json 에 있다" % id)
	check(Skills.one_shot(rt, "톱", "건달급", false) and not Skills.one_shot(rt, "톱", "건달급", true), "한 방 · 면제")
	check(not Skills.one_shot(rt, "", "건달급", false), "등급이 비면 한 방이 아니다")
	var weave := Moves.get_move("s_weave", rt)
	eq(Skills.kills(rt, weave, "건달급"), t["rules"].skill_ko("amur_weaving", "건달급"), "기술 ko_rank 는 2층 skill_ko")
	check(not Skills.kills(rt, Moves.get_move("k_slash1", rt), "건달급"), "기술이 아닌 동작은 ko_rank 가 없다")
	var kick := Moves.get_move("s_kick", rt)
	eq(Skills.stun_frames(rt, kick, "내성 중위", "네임드"), roundi(t["rules"].stun_sec("kickarts", "내성 중위", "네임드") * 60.0), "기절 프레임 = stun_sec × 60")
	var no := kick.duplicate()
	no["stun_off"] = true
	eq(Skills.stun_frames(rt, no, "내성 중위", "네임드"), 0, "기절을 끈 대")
	var ob := Moves.get_move("s_offbeat", rt)
	eq(Skills.stun_frames(rt, ob, "톱", "건달급"), int(ob["stun_3d"][0]), "2층에 기절이 없으면 3D 덧붙임(아랫급에게)")
	eq(Skills.stun_frames(rt, ob, "건달급", "톱"), int(ob["stun_3d"][1]), "3D 덧붙임(같은 급 · 윗급에게)")
	eq(Skills.stun_frames(rt, Moves.get_move("k_slash1", rt), "톱", "건달급"), 0, "기절이 없는 동작")


func test_officer_values_come_from_tick_unit() -> void:
	var t := _t()
	var s: Dictionary = Game.new_game(t, "A", 1)["state"]
	var rt = RulesRt.new(t["rules"])
	var u: Dictionary = Combat.officer_unit(s, t, "kimshin", 0)
	u["hp"] = int(u["max"]) - 100                          # 앞 구간에서 깎인 체력도 그대로 이어진다
	var f = Build.officer(t, rt, u, 0, {"skills": Array(s["officers"]["kimshin"]["skills"])})
	eq(f.hp_max, float(u["max"]), "체력 = 틱 유닛 체력(08 14-2)")
	eq(f.hp, float(u["hp"]), "남은 체력이 이어진다")
	eq(f.atk_mob, float(u["atk"]), "조직원을 칠 때 기준 = 유닛 공격")
	var df: Dictionary = Duel.fighter(t, s, "kimshin")
	eq(f.atk_off, float(Duel.hit_damage(t, df, df)), "간부를 칠 때 기준 = 일기토 보통 맞힘(08 14-3)")
	check(is_equal_approx(f.off_k * float(df["max"]), float(u["max"])), "맞는 쪽 환산 = 습격 체력 ÷ 일기토 체력")
	eq(f.rank, String(s["officers"]["kimshin"]["rank"]), "등급은 판 상태(유닛)에서")
	eq(f.can_parry, true, "쳐내기는 1층 can_parry")
	eq(f.gauge, 0.0, "게이지는 0 칸에서")
	eq(f.gauge_max, float(t["rules"].bars_for(f.rank)) * rt.bar_points(), "게이지 최대 = bars_for × 한 칸")
	check(not f.skills.is_empty() and not f.is_mob and not f.is_boss, "아는 기술 · 조종 쪽 몸놀림")
	eq(f.moveset, Build.role_of(t, "kimshin")["moveset"], "동작 묶음은 fight_roles.json")
	check(f.run_speed > f.walk_speed and f.walk_speed > 0.0, "빠르기")
	# 일기토에서 쓰러지는 대 수와 같다(간부 → 간부 · 같은 등급 · 보통 맞힘)
	var hits_duel := ceili(float(df["max"]) / float(Duel.hit_damage(t, df, df)))
	var hits_rt := ceili(f.hp_max / (f.atk_off * f.off_k))
	eq(hits_rt, hits_duel, "간부끼리 쓰러지는 대 수 = 일기토의 대 수")


func test_troop_values_and_roles() -> void:
	var t := _t()
	var rt = RulesRt.new(t["rules"])
	var g: Dictionary = Combat.group_unit(t, "조장급", 5, 1)
	var f = Build.troop(t, rt, g, 1)
	eq(f.hp_max, float(g["hp1"]), "조직원 체력 = 한 명 HP(08 14-2)")
	eq(f.atk_mob, float(g["atk1"]), "조직원 기준 피해 = 한 명 ATK")
	check(f.is_mob and f.is_boss and not f.can_parry, "조직원 · AI 쪽 몸놀림 · 쳐내기 없음")
	eq(f.rank, "조장급", "등급")
	eq(Build.troop_role(t, "없는 등급"), Build.troop_role(t, "건달급"), "모르는 등급은 건달급 줄")
	eq(Build.role_of(t, "없는 사람"), t["fight_roles"]["default"], "역할이 없는 간부는 default")
	eq(Build.speed_k(t, {}), 1.0, "속도가 없으면 1.0")
	check(is_equal_approx(Build.speed_k(t, {"속도": 80}), 1.0) and Build.speed_k(t, {"속도": 96}) > 1.0, "속도 배율")
	check(Build.guard_rate(t, "kimshin") > Build.guard_rate(t, "없는 사람"), "막는 확률은 기술 능력치에서")
	var du := Build.duel_of(t, "kimshin", "내성 중위")
	check(int(du["hp"]) > 0 and int(du["hit"]) > 0, "일기토 값")


## 3층 표 대조 — fight_roles.json 의 동작 · 프로필 id 가 실제로 있다(옮겨 적은 것은 기계로 대조 — CLAUDE.md 4절)
func test_fight_roles_ids_exist() -> void:
	var t := _t()
	var fr: Dictionary = t["fight_roles"]
	var rows := [fr["default"]]
	for id in fr["roles"]:
		check(t["people"].has(id), "roles %s 는 canon 인물" % id)
		rows.append(fr["roles"][id])
	for row in rows:
		for k in row["moveset"]:
			check(Moves.M.has(row["moveset"][k]), "동작 %s 이 동작 표에 있다" % row["moveset"][k])
		check(row["moveset"].has("combo"), "연타 동작이 있다")
		check(EnemyAI.PROFILES.has(row["ai"]), "AI 프로필 %s" % row["ai"])
		check(Looks.known(row["look"]), "외형 %s 이 외형 표에 있다" % row["look"])
	for row in t["scenarios"]["A"]["roster"]:
		var id: String = row["id"]
		check(fr["roles"].has(id) or t["noncombat"]["A"].has(id), "A 명단 %s 는 역할이 있다(싸우지 않는 사람 빼고 — C4-1 FR-411)" % id)
	for g in fr["troops"]:
		check(t["rules"].rank_index(g) >= 0, "조직원 등급 %s 는 사다리에 있다" % g)
		for p in fr["troops"][g]["ai"]:
			check(EnemyAI.PROFILES.has(p), "조직원 AI 프로필 %s" % p)
		for lk in fr["troops"][g]["look"]:
			check(Looks.known(lk), "조직원 외형 %s" % lk)
	for name in EnemyAI.PROFILES:
		for pat in EnemyAI.PROFILES[name]["patterns"].values():
			for step in pat:
				check(Moves.M.has(step[0]), "프로필 %s 의 동작 %s" % [name, step[0]])


## FR-408 — 구간 방: 구역 업종 → 방(3층 rooms) · 방 이름은 room3d THEMES 에 있다
func test_room_of_zone() -> void:
	var t := _t()
	eq(Build.room_of(t, "bukgu"), "club", "북구(유흥) → 클럽")
	eq(Build.room_of(t, "hoeamsijang"), "office", "회암 시장(상권 · 대부) → 사무실")
	eq(Build.room_of(t, "없는 구역"), t["fight"]["rooms"]["default"], "없는 구역 → default")
	var Room = preload("res://ui/fight3d/room3d.gd")
	for k in t["fight"]["rooms"]:
		check(Room.THEMES.has(t["fight"]["rooms"][k]), "방 %s 을 그릴 수 있다" % t["fight"]["rooms"][k])


## FR-403 · FR-414 — A 명단의 싸우는 사람은 그림 A 모델이 있다(없으면 관절 인형으로 내려가지만, A 는 다 갖춘다) · 효과음 이름은 파일이 있다
func test_a_models_and_sounds_exist() -> void:
	var t := _t()
	var s: Dictionary = preload("res://sim/game.gd").new_game(t, "A", 1)["state"]
	for id in s["officers"]:
		if t["noncombat"]["A"].has(id) or String(s["officers"][id]["org"]) == "":
			continue
		var lk := String(Build.role_of(t, id)["look"])
		check(ResourceLoader.exists(str(Looks.art_of(lk).get("glb", ""))), "%s(외형 %s) 모델 파일이 있다" % [id, lk])
	var Sound = preload("res://ui/fight3d/sound.gd")
	for n in Sound.SFX:
		check(ResourceLoader.exists("res://assets/sfx/%s.wav" % n), "효과음 %s" % n)
	for mv in Moves.M.values():
		if mv.has("hit_sfx"):
			check(Sound.SFX.has(str(mv["hit_sfx"])), "동작의 맞는 소리 %s 가 목록에 있다" % mv["hit_sfx"])
