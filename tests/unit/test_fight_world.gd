extends "res://tests/helpers.gd"
## FR-401 — 실시간 판정(fight/world.gd · fighter.gd · fighter_body.gd · moves.gd): castle_M3D `tests/unit/test_combat.gd`(2c3e69b)의
## 경우를 옮겼다 — 맞기 · 구르기 무적 · 칼날 쳐내기 · 늦은 쳐내기 · 가드 불가 · 막기 · 빈틈 → 제압 상한 · 연타 · 각법 기절 · 게이지 ·
## 등급 차 강함 · 움찔 안 함 · 한 방. 다른 곳: 막기 배율은 2층 guard.damage_k(0.7 — castle_M3D 는 0.2) · 한 대 피해의 틱 기준(_dmg).
## 두 사람을 손 입력으로 world.tick 을 돌린다(AI · 봇 없음). 값은 받은 사본(규칙 2층) — castle_M3D 결투(김신 내성 상위 ↔ 백도찬 톱)와 같은 꼴.

const World = preload("res://fight/world.gd")
const Fighter = preload("res://fight/fighter.gd")
const Moves = preload("res://fight/moves.gd")
const Skills = preload("res://fight/skills.gd")
const RulesRt = preload("res://fight/rules_rt.gd")
const DataFiles = preload("res://src/data_files.gd")
const HERO_HP := 200.0
const BOSS_HP := 400.0

var _tables := {}


func _rules():
	if _tables.is_empty():
		_tables = DataFiles.load_tables()
	return RulesRt.new(_tables["rules"])


## 두 사람을 가까이 마주 세운 판 — hero(편 0 · 쌍칼 · 쳐내기) · boss(편 1 · 사시미 · 버팀 · 제압 상한)
func _close(dist := 0.8) -> Dictionary:
	var rules = _rules()
	var w = World.new(rules)
	w.end_on_ko = false
	var h = Fighter.new("hero", 0, rules)
	h.char_id = "kimshin"
	h.hp = HERO_HP
	h.hp_max = HERO_HP
	h.posture_max = 60.0
	h.stagger_len = 50
	h.moveset = {"combo": "k_slash1", "dash": "k_dash", "counter": "k_counter", "finisher": "k_finisher"}
	h.rank = "내성 상위"
	h.can_parry = true
	h.skills = Skills.entries(rules, ["kickarts", "triple"], h.rank)
	h.gauge_max = rules.bars_for(h.rank) * rules.bar_points()
	h.gauge_rate = rules.gauge_rate(h.rank, 95)
	h.gauge = h.gauge_max
	h.pos = Vector2(0, 0)
	h.facing = Vector2(1, 0)
	var b = Fighter.new("boss", 1, rules)
	b.char_id = "baekdochan"
	b.is_boss = true
	b.hp = BOSS_HP
	b.hp_max = BOSS_HP
	b.posture_max = 220.0
	b.stagger_len = 100
	b.poise = 12.0
	b.finisher_cap = World.FINISHER_CAP_BOSS
	b.rank = "톱"
	b.pos = Vector2(dist, 0)
	b.facing = Vector2(-1, 0)
	w.add(h)
	w.add(b)
	h.set_target(b)
	b.set_target(h)
	return {"world": w, "hero": h, "boss": b, "rules": rules}


func _tick(d: Dictionary, hero_it := {}, boss_it := {}) -> void:
	d["hero"].intent = hero_it
	d["boss"].intent = boss_it
	d["world"].tick()


func _run(d: Dictionary, n: int) -> void:
	for i in n:
		_tick(d)


func _events(d: Dictionary, kind: String) -> Array:
	var out := []
	for e in d["world"].events:
		if e[0] == kind:
			out.append(e)
	return out


func test_slash_hits() -> void:
	var d := _close()
	_tick(d, {"attack": true})
	_run(d, 30)
	check(is_equal_approx(d["boss"].hp, BOSS_HP - 7.0), "베기 한 번 = 7(boss hp %s)" % d["boss"].hp)
	check(not _events(d, "hit").is_empty(), "맞음 신호")


func test_roll_iframes_dodge_thrust() -> void:
	var d := _close(1.0)
	_tick(d, {}, {"use": "b_thrust"})                       # 준비 16 → 판정 17 ~ 20
	for i in 7:
		_tick(d)
	_tick(d, {"roll": true, "move": Vector2(0, 1)})         # 보스 9프레임째 구르기 → 판정 때 구르기 8 ~ 11프레임
	_run(d, 30)
	check(is_equal_approx(d["hero"].hp, HERO_HP), "구르기 무적이면 안 맞는다(hero hp %s)" % d["hero"].hp)


## 구르기로 피하면 게이지가 찬다(gauge.gain.dodge × 배율)
func test_dodge_gains_gauge() -> void:
	var d := _close(1.0)
	var h = d["hero"]
	h.gauge = 0.0
	_tick(d, {}, {"use": "b_thrust"})                       # 판정 17 ~ 20
	for i in 14:
		_tick(d)
	var g0: float = h.gauge
	_tick(d, {"roll": true, "move": Vector2(0, 1)})         # 판정 때 구르기 무적 초반(아직 사거리 안)
	var dodged := false
	for i in 30:
		_tick(d)
		dodged = dodged or not _events(d, "dodge").is_empty()
		if dodged:
			break
	check(dodged, "피함 신호")
	var want: float = d["rules"].gain_points("dodge") * h.gauge_rate
	check(h.gauge - g0 >= want - 0.001, "피하면 %s 이상 찬다(%s)" % [want, h.gauge - g0])


func test_parry_recoils_attacker() -> void:
	var d := _close(0.9)
	_tick(d, {}, {"use": "b_slash1"})                       # 준비 14 → 판정 15
	for i in 10:
		_tick(d)
	_tick(d, {"parry": true, "parry_held": true})           # 판정 4프레임 전
	var seen := false
	for i in 12:
		_tick(d, {"parry_held": true})
		seen = seen or not _events(d, "parry").is_empty()
	check(seen, "칼날 쳐내기 신호")
	check(is_equal_approx(d["hero"].hp, HERO_HP), "쳐내면 안 맞는다")
	check(d["boss"].posture > 0.0, "쳐내기 당한 쪽 체간이 찬다")
	check(d["hero"].counter_ready > 0, "쳐낸 쪽은 반격 베기를 낼 수 있다")
	_tick(d, {"attack": true})
	_run(d, 3)
	eq(String(d["hero"].move.get("name", "")), "k_counter", "쳐낸 뒤 공격 = 반격 베기")


func test_late_parry_after_contact() -> void:
	var d := _close(0.9)
	_tick(d, {}, {"use": "b_slash1"})
	for i in 16:
		_tick(d)                                            # 판정이 지나도록 아무것도 안 함 → 맞음이 미뤄진다
	_tick(d, {"parry": true, "parry_held": true})           # 닿은 뒤 늦게 누름
	var seen := false
	for i in 10:
		_tick(d, {"parry_held": true})
		seen = seen or not _events(d, "parry").is_empty()
	check(seen, "닿은 뒤 %d프레임 안에 누르면 쳐내기" % World.LATE_PARRY)
	check(is_equal_approx(d["hero"].hp, HERO_HP), "늦은 쳐내기는 피해가 없다(hero hp %s)" % d["hero"].hp)
	eq(d["hero"].parry_side, "L", "바로 베기는 왼팔로 튕긴다")


func test_no_parry_hit_lands_after_grace() -> void:
	var d := _close(0.9)
	_tick(d, {}, {"use": "b_slash1"})
	_run(d, 15 + World.LATE_PARRY + 4)
	check(is_equal_approx(d["hero"].hp, HERO_HP - 9.0), "안 누르면 미룬 맞음이 들어온다(hero hp %s)" % d["hero"].hp)


func test_parry_side_and_move_helpers() -> void:
	var rules = _rules()
	eq(Moves.parry_side(Moves.get_move("b_slash1", rules)), "L", "바로 베기 → 왼쪽")
	eq(Moves.parry_side(Moves.get_move("b_slash2", rules)), "R", "되베기 → 오른쪽")
	eq(Moves.parry_side({"shape": "thrust", "hand": "L"}), "R", "왼손 · 왼발 → 오른팔")
	var mv := Moves.get_move("k_slash1", rules)
	eq(Moves.total(mv), 17, "베기 길이 = 준비 4 + 판정 3 + 회수 10")
	eq(Moves.cancel_at(mv), int(mv["cancel"]) if int(mv["cancel"]) >= 0 else 7, "연타로 끊는 프레임")
	check(Moves.get_move("k_slash1", rules) == mv, "같은 규칙 표면 사본을 다시 쓴다")
	eq(String(Moves.get_move("s_offbeat", rules)["lethal"]), "offbeat", "엇박 계열 효과(2층)는 규칙 표에서 채운다")
	eq(String(Moves.get_move("s_offbeat")["lethal"]), "", "규칙 없이 부르면 2층 효과를 채우지 않는다(그림용)")


func test_unblockable_ignores_parry() -> void:
	var d := _close(1.0)
	_tick(d, {}, {"use": "b_vital"})                        # 준비 10, 가드 불가
	for i in 7:
		_tick(d)
	_tick(d, {"parry": true, "parry_held": true})
	for i in 12:
		_tick(d, {"parry_held": true})
	check(d["hero"].hp < HERO_HP, "빨간 ! 는 쳐낼 수 없다(hero hp %s)" % d["hero"].hp)


func test_block_uses_guard_k() -> void:
	var d := _close(0.9)
	var h = d["hero"]
	h.can_parry = false                                     # 쳐내기가 없는 사람 — 막기만
	eq(d["world"].block_dmg_k, d["rules"].guard_k(), "막기 배율은 2층 guard.damage_k")
	_tick(d, {"parry": true, "parry_held": true})
	_tick(d, {"parry_held": true}, {"use": "b_slash1"})
	for i in 20:
		_tick(d, {"parry_held": true})
	check(is_equal_approx(h.hp, HERO_HP - 9.0 * d["rules"].guard_k()), "막으면 피해 × %s(hero hp %s)" % [d["rules"].guard_k(), h.hp])
	check(d["world"].stats["blocks"] == 1, "막기 한 번")
	check(h.gauge > 0.0, "막아도 게이지가 찬다")


func test_stagger_then_finisher_capped() -> void:
	var d := _close()
	var b = d["boss"]
	b.posture = b.posture_max - 1.0
	_tick(d, {"attack": true})
	_run(d, 20)
	eq(b.state, "stagger", "체간이 차면 빈틈")
	var hp_before: float = b.hp
	_tick(d, {"attack": true})
	_run(d, 25)
	eq(b.state, "down", "빈틈에 공격 = 제압 → 넘어짐")
	check(hp_before - b.hp <= b.hp_max * 0.08 + 0.001, "보스 제압 피해는 최대 체력 8%% 까지(%s)" % (hp_before - b.hp))
	_run(d, Fighter.DOWN_T + 2)
	check(b.can_act(), "넘어진 뒤 일어난다(state %s)" % b.state)


func test_combo_chains_to_second_slash() -> void:
	var d := _close(3.0)
	_tick(d, {"attack": true})
	_run(d, 4)
	_tick(d, {"attack": true})                              # 연타 버퍼 8프레임
	_run(d, 6)
	eq(String(d["hero"].move.get("name", "")), "k_slash2", "베기 → 되베기")


func test_kick_stuns_and_costs_gauge() -> void:
	var d := _close(0.8)
	var h = d["hero"]
	var b = d["boss"]
	h.skill_idx = h.skill_index("kickarts")
	var g0: float = h.gauge
	_tick(d, {"skill": true})
	check(h.gauge < g0, "기술을 내면 게이지를 쓴다(%s → %s)" % [g0, h.gauge])
	check(is_equal_approx(h.skill_paid, float(h.current_skill()["cost"])), "쓴 칸 수 = skill_cost")
	_run(d, 16)
	eq(b.state, "stun", "각법에 맞으면 기절")
	eq(b.hold_t, 60, "같은 급 · 윗급에게는 1초")
	_run(d, 75)
	check(b.state != "stun", "1초 뒤 풀린다(state %s)" % b.state)


func test_skill_needs_gauge_and_pick() -> void:
	var d := _close(0.8)
	var h = d["hero"]
	h.gauge = 50.0
	h.skill_idx = 0
	_tick(d, {"skill": true})
	check(h.state != "attack", "게이지가 모자라면 기술이 안 나간다(state %s)" % h.state)
	check(not _events(d, "no_gauge").is_empty(), "게이지 부족 신호")
	_tick(d, {"skill_next": true})
	eq(h.skill_idx, 1, "기술 바꾸기")
	_tick(d, {"skill_pick": 0})
	eq(h.skill_idx, 0, "번호로 고르기(봇)")
	eq(h.skill_index("offbeat"), -1, "모르는 기술은 없다")
	h.skills = []
	check(h.current_skill().is_empty(), "기술이 없으면 빈 것")


func test_rank_gap_damage_and_armor() -> void:
	var d := _close()
	var h = d["hero"]
	var b = d["boss"]
	h.rank = "재앙"
	b.rank = "외성 하위"
	b.oneshot_immune = true                                 # 한 방은 따로 본다 — 여기는 배율만
	_tick(d, {"attack": true})
	_run(d, 30)
	var k_up: float = d["rules"].rank_damage_k("재앙", "외성 하위")
	check(k_up > 1.0 and is_equal_approx(b.hp, b.hp_max - 7.0 * k_up), "윗급의 베기 = 7 × %s(boss hp %s)" % [k_up, b.hp])
	var d2 := _close(0.9)
	d2["hero"].rank = "재앙"
	d2["boss"].rank = "외성 하위"
	_tick(d2, {}, {"use": "b_slash1"})
	var flinch := false
	for i in 15 + World.LATE_PARRY + 4:
		_tick(d2)
		flinch = flinch or d2["hero"].state == "hitstun"
	var k_down: float = d2["rules"].rank_damage_k("외성 하위", "재앙")
	check(is_equal_approx(d2["hero"].hp, HERO_HP - 9.0 * k_down), "아랫급의 베기 = 9 × %s(hero hp %s)" % [k_down, d2["hero"].hp])
	check(not flinch, "한참 아랫급에게 맞아도 움찔하지 않는다(shrugs_off)")


func test_one_shot_by_rank_gap() -> void:
	var d := _close()
	var b = d["boss"]
	d["hero"].rank = "톱"
	b.rank = "건달급"
	check(d["rules"].one_shot("톱", "건달급"), "톱은 건달급을 한 방에(2층)")
	_tick(d, {"attack": true})
	_run(d, 12)
	check(not b.alive(), "한 대에 쓰러진다(boss hp %s)" % b.hp)
	check(not _events(d, "oneshot").is_empty() or not b.alive(), "한 방 신호")
	var d2 := _close()
	d2["hero"].rank = "톱"
	d2["boss"].rank = "건달급"
	d2["boss"].oneshot_immune = true
	_tick(d2, {"attack": true})
	_run(d2, 12)
	check(d2["boss"].alive(), "판이 면제한 사람은 한 방을 안 받는다")


func test_tick_basis_damage_and_card_scales() -> void:
	var d := _close()
	var w = d["world"]
	var h = d["hero"]
	var b = d["boss"]
	var mv := {"damage": 14.0}
	check(is_equal_approx(w._dmg(h, b, mv), 14.0), "구간 값이 없으면 동작 피해 × dmg_k(castle_M3D 그대로)")
	w.move_ref = 7.0
	h.atk_mob = 216.0
	h.atk_off = 78.0
	b.off_k = 0.5
	check(is_equal_approx(w._dmg(h, b, mv), 78.0 * 0.5 * 2.0), "간부 → 간부 = 일기토 보통 맞힘 × 맞는 쪽 환산 × 동작 피해 ÷ 기준")
	b.is_mob = true
	check(is_equal_approx(w._dmg(h, b, mv), 216.0 * 2.0), "간부 → 조직원 = 유닛 공격 × 동작 피해 ÷ 기준")
	w.team_dmg_k = [1.2, 1.0]
	w.mob_taken_k = [1.0, 0.6]
	check(is_equal_approx(w._dmg(h, b, mv), 216.0 * 2.0 * 1.2 * 0.6), "작전 카드 배율(정면 돌파 × 방패조)")
	h.is_mob = true
	h.atk_mob = 10.0
	b.is_mob = false
	w.team_dmg_k = [1.0, 1.0]
	check(is_equal_approx(w._dmg(h, b, mv), 10.0 * 2.0), "조직원 → 간부 = 한 명 공격 × 동작 피해 ÷ 기준")


func test_dash_roll_and_accessors() -> void:
	var d := _close(4.0)
	var w = d["world"]
	var h = d["hero"]
	check(w.hero() == h and w.boss() == d["boss"], "world.hero() · boss()")
	var x0: float = h.pos.x
	_tick(d, {"dash": true, "move": Vector2(1, 0)})
	check(not _events(d, "dash").is_empty(), "대시 신호")
	_run(d, 4)
	check(h.pos.x > x0 + 0.3, "대시로 내달린다(%.2f → %.2f)" % [x0, h.pos.x])
	_tick(d, {"attack": true})
	_run(d, 2)
	eq(String(h.move.get("name", "")), "k_dash", "대시 중 공격 = 대시기")
	var d2 := _close(4.0)
	var h2 = d2["hero"]
	var y0: float = h2.pos.y
	_tick(d2, {"roll": true, "move": Vector2(0, 1)})
	eq(h2.state, "roll", "구르기")
	_run(d2, Fighter.ROLL_T + 1)
	check(h2.pos.y > y0 + 1.0 and h2.can_act(), "구르기로 %.1f m 옮기고 일어선다(%.2f)" % [Fighter.ROLL_DIST, h2.pos.y - y0])
	check(h2.telegraph().is_empty(), "공격 중이 아니면 예고가 없다")
	_tick(d2, {}, {"use": "b_slash1"})
	eq(String(d2["boss"].telegraph()[0]), "parry", "베기는 흰 ! 예고")
	check(d2["boss"].in_recovery() == false and d2["boss"].is_active() == false, "준비 중에는 판정 · 회수가 아니다")
	h2.get_stun(30)
	eq(h2.state, "stun", "기절")
	h2.get_recoil(5, Vector2(1, 0))
	eq(h2.state, "recoil", "튕겨남")


func test_determinism() -> void:
	var outs := []
	for k in 2:
		var d := _close(0.9)
		_tick(d, {"attack": true}, {"use": "b_slash1"})
		for i in 90:
			_tick(d, {"attack": i % 9 == 0, "parry": i % 17 == 0, "move": Vector2(0.2, 0.1)}, {"use": "b_slash1" if i % 31 == 0 else ""})
		outs.append([d["hero"].hp, d["boss"].hp, d["hero"].pos, d["boss"].pos, d["hero"].state, d["boss"].posture, d["world"].frame])
	eq(str(outs[0]), str(outs[1]), "같은 입력이면 같은 결과")
