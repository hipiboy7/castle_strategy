extends RefCounted
## [옮김] castle_M3D `src/combat/world.gd`(2c3e69b) — 바꾼 것: 규칙 인스턴스 · 한 대 피해 _dmg(틱 기준) · 막기 배율 = 2층 0.7 · 카드 배율(team_dmg_k · mob_taken_k) · 쓰러뜨린 쪽 기록. 설계: docs/C4_설계서_직접조작전투.md 4-1 · 요구: FR-401
## 결투 판정 — 공격 판정 · 구르기 무적 · 칼날 쳐내기(늦은 쳐내기) · 막기 · 체간 · 빈틈 · 제압 · 역경직 · 페이즈 ·
## 기술(엇박 관통 · 엇박 피해 · 기절 · 삼연타) · 기술 게이지 · 등급 차 강함.
## 2층 규칙(엇박 피해 lethal_fraction · 기절 stun_sec · 등급 차 rank_damage_k · shrugs_off · 게이지 얻는 양)은 공통 데이터
## (src/data/common.gd) 함수로 — castle_M `castle_m/action/combat.py` 와 같은 자리에서 부른다.
## 3층(쳐내기 휘청 · 막기 배율 · 제압 상한 · 2차 바닥 · 역경직)은 castle_M combat.py 와 P2 설계서 8.3절의 수치를 초안 크기로 옮겼다.
## 순수 로직이라 테스트(tests/test_combat.gd)와 자동 플레이(--autoplay)가 그림 없이 돌린다.

const Fighter = preload("res://fight/fighter.gd")
const Moves = preload("res://fight/moves.gd")
const Skills = preload("res://fight/skills.gd")

const PARRY_HITSTOP := 9
const PARRY_SHAKE := 4
# 막기로 받는 피해 배율 — 2층 guard.damage_k(0.7 · rules/전투_쳐내기.md 1-1)를 쓴다(castle_M3D 는 그 판 3층 0.2 — 기획_차이 (나)43 ⓓ).
# 규칙 없이 만든 판(시험)은 이 기본값.
const BLOCK_DMG_K := 0.7
const BLOCK_POSTURE_K := 0.8
const FINISHER_CAP_BOSS := 0.08          # 보스에게 제압 피해는 최대 체력의 8%
const PHASE2_AT := 0.55                  # 1차 체력 바닥 — 여기서 2차로
const PHASE2_FREEZE := 50                # 2차로 넘어가는 동안 멈춤(컷인)
const LATE_PARRY := 6                    # 늦은 쳐내기: 서 있던 김신이 맞으면 맞음을 이만큼 미루고, 그 사이 누르면 쳐내기
                                         # (휘두름이 보이는 순간이 판정 순간이라 보고 누르면 늦다 — castle_common rules/전투_쳐내기.md 1절)
const TRIPLE_LAST := {"knockback_k": 8.0, "hitstop": 13, "shake": 6}   # 리천식 삼연타 셋째 대 (castle_M combat.py 와 같다)

var fighters: Array = []
var frame := 0
var hitstop := 0
var shake := 0
var slowmo := 0                          # 남은 슬로모션 로직 프레임 (main.gd 가 두 화면에 한 번만 돌린다 — 판정은 그대로)
var events: Array = []                   # [종류, ...] — 그림 · 소리가 매 프레임 가져가고 비운다
var bounds := Rect2(-6.6, -3.6, 13.2, 7.4)
var over := ""                           # "" / win / lose
var end_on_ko := true                    # 결투: 누가 쓰러지면 판이 끝난다. 여러 사람 판(stage.gd)은 false — 판 끝은 stage 가 정한다
var phase := 1
var pending: Array = []                  # 미룬 맞음 [공격자, 맞는 사람, 기술, 맞은 자리, 남은 프레임]
var rules = null                         # fight/rules_rt.gd 인스턴스
var block_dmg_k := BLOCK_DMG_K
var move_ref := 7.0                      # 기준 동작 피해(data/game/fight.json) — 한 대 = 틱 공격 기준 × 동작 피해 ÷ move_ref
var team_dmg_k := [1.0, 1.0]             # 쪽마다 주는 피해 배율(작전 카드 — 정면 돌파 · 매복)
var mob_taken_k := [1.0, 1.0]            # 쪽마다 조직원이 받는 피해 배율(방패조)
var stats := {"hits": 0, "parries": 0, "boss_parries": 0, "dodges": 0, "blocks": 0, "staggers": 0,
	"offbeats": 0, "boss_offbeats": 0}       # offbeats: 엇박 계열이 맞은 수 (김신 · 백도찬)


func _init(r = null) -> void:
	rules = r
	if r != null:
		block_dmg_k = r.guard_k()


## 한 대 피해(막기 전) — 습격 구간 값이 있으면 틱 기준(설계서 4-3), 없으면 castle_M3D 처럼 동작 피해 × dmg_k.
## mv["damage"] 에는 등급 차(rank_damage_k)가 이미 곱해져 온다(_resolve)
func _dmg(a, d, mv: Dictionary) -> float:
	var k: float = a.dmg_k * float(team_dmg_k[a.team])
	if d.is_mob:
		k *= float(mob_taken_k[d.team])
	if a.atk_mob <= 0.0:
		return float(mv["damage"]) * k
	var base: float = a.atk_mob if (a.is_mob or d.is_mob) else a.atk_off * d.off_k
	return float(mv["damage"]) / move_ref * base * k


func add(f) -> void:
	fighters.append(f)


func hero():
	for f in fighters:
		if not f.is_boss:
			return f
	return null


func boss():
	for f in fighters:
		if f.is_boss:
			return f
	return null


func tick() -> void:
	frame += 1
	if slowmo > 0:
		slowmo -= 1
	if shake > 0:
		shake -= 1
	if hitstop > 0:
		hitstop -= 1
		for f in fighters:
			f.buffer_inputs()
		return
	if over != "":
		return
	for f in fighters:
		f.tick()
		f.gauge = minf(f.gauge_max, f.gauge + rules.passive_per_frame() * f.gauge_rate)
		for e in f.events:
			events.append(e)
		f.events.clear()
	_separate()
	for f in fighters:
		f.pos.x = clampf(f.pos.x, bounds.position.x, bounds.end.x)
		f.pos.y = clampf(f.pos.y, bounds.position.y, bounds.end.y)
	_tick_pending()
	_hits()


## 미룬 맞음: 그 사이 쳐내기를 눌렀으면 쳐내기, 시간이 다 됐거나 다른 행동을 시작했으면 그대로 맞는다
func _tick_pending() -> void:
	for p in pending.duplicate():
		var a = p[0]
		var d = p[1]
		p[4] -= 1
		if over != "" or not d.alive():
			pending.erase(p)
		elif d.parry_open() and _faces(d, a):
			pending.erase(p)
			_parry(a, d, p[3], p[2])
		elif p[4] <= 0 or not d.can_act():
			pending.erase(p)
			_take_hit(a, d, p[2], p[3])


func _separate() -> void:
	for i in fighters.size():
		for j in range(i + 1, fighters.size()):
			var a = fighters[i]
			var b = fighters[j]
			if a.state == "roll" or b.state == "roll" or not a.alive() or not b.alive():
				continue
			var d: Vector2 = b.pos - a.pos
			var n := d.length()
			var need: float = Fighter.BODY_R * 2.0
			if n < need:
				var push := (d / n if n > 0.0001 else Vector2(1, 0)) * (need - n) * 0.5
				a.pos -= push
				b.pos += push


func _in_hit(a, d) -> bool:
	var mv: Dictionary = a.move
	var reach: float = mv["reach"]
	var radius: float = mv["radius"]
	var body: float = Fighter.BODY_R
	if str(mv["shape"]) == "spin":
		return a.pos.distance_to(d.pos) <= radius + body
	if str(mv["shape"]) == "shot":
		# 총: 앞으로 뻗은 선분(사거리 reach) 위 어디든 — 몸 반지름 + 탄 굵기(radius) 안이면 맞는다
		var to2: Vector2 = d.pos - a.pos
		var along := to2.dot(a.facing)
		if along < 0.0 or along > reach:
			return false
		return (to2 - a.facing * along).length() <= radius + body
	var center: Vector2 = a.pos + a.facing * reach
	if center.distance_to(d.pos) <= radius + body:
		return true
	# 호를 그리는 베기는 정면에서 호 반각 안 · 사거리 안이면 맞는다
	var arc: float = mv["arc"]
	if arc > 0.0:
		var to: Vector2 = d.pos - a.pos
		if to.length() <= reach + radius + body and to.length() > 0.0001:
			return absf(rad_to_deg(a.facing.angle_to(to))) <= arc * 0.5
	return false


func _faces(d, a) -> bool:
	return d.facing.dot(d.dir_to(a)) > 0.3


func _hits() -> void:
	for a in fighters:
		if not a.is_active() or a.inert:
			continue
		for d in fighters:
			if d == a or d.team == a.team or not d.alive() or d.inert:
				continue
			if a.hit_ids.has(d.get_instance_id()):
				continue
			if not _in_hit(a, d):
				continue
			a.hit_ids[d.get_instance_id()] = true
			_resolve(a, d)


func _resolve(a, d) -> void:
	for p in pending:
		if p[0] == a and p[1] == d:
			return                                   # 미룬 사이 같은 공격자의 다음 판정은 버린다(rules/전투_쳐내기.md 1절)
	var mv: Dictionary = _hit_move(a)
	var at: Vector3 = _contact(a, d)
	var push: Vector2 = a.dir_to(d)
	if d.iframes() or (d.state == "attack" and d.move.get("immune_lower", false) and rules.immune_lower(d.rank, a.rank)):
		stats["dodges"] += 1
		events.append(["dodge", d, at])
		d.gain("dodge")                          # 구르기로 피하면 게이지 (common gauge.gain.dodge)
		return
	# 카운터 자세(피우진 미친 코어 카운터): 마주 본 공격을 흘리고 그 자리에서 맞받는다(엇박 계열 · 가드 뚫기는 못 받는다)
	if d.stance_open() and _faces(d, a) and not mv["guard_break"] and str(mv["lethal"]) == "":
		a.landed = true
		events.append(["counter_catch", d, at, a])
		d.start_move(str(d.move["stance_hit"]))
		d.facing = d.dir_to(a)
		hitstop = maxi(hitstop, 6)
		return
	# 등급으로 막기를 뚫는 기술(사라지는 스텝 — 내성 중위 이하는 못 막는다)
	if str(mv["unblock_top"]) != "" and rules.rank_at_most(d.rank, mv["unblock_top"]):
		mv = mv.duplicate()
		mv["parryable"] = false
		mv["guard_break"] = true
	# 등급 차 강함: 보통 공격의 피해 · 체간 × rank_damage_k(치는 쪽, 맞는 쪽) — 엇박 계열은 빼고(castle_M combat.py 와 같게).
	# 이 결투(내성 상위 ↔ 톱, 1등급 차)는 1.0
	if str(mv["lethal"]) == "":
		var rk: float = rules.rank_damage_k(a.rank, d.rank)
		var vh: Array = mv["vs_high"]
		if not vh.is_empty() and rules.rank_index(d.rank) >= rules.rank_index(str(vh[0])):
			rk = maxf(1.0, rk) * float(vh[1])         # 윗급 상대에게 큰 타격(아무르 티그로 3연타) — 등급 차로 깎이지 않는다
		if rk != 1.0:
			mv = mv.duplicate()
			mv["damage"] = float(mv["damage"]) * rk
			mv["posture"] = float(mv["posture"]) * rk
	# 엇박 · 반대발 엇박이 엇엇박을 치면 무조건 엇엇박이 이긴다 — 브레이크로 박자를 흘려 닿지 않는다(헛침), 엇엇박은 그대로
	if d.state == "attack" and str(d.move["lethal"]) == "offbeat2" and str(mv["lethal"]) in ["offbeat", "offbeat_rev"]:
		events.append(["clash", d, at, a])
		return
	a.landed = true
	# 엇박 계열: 막기 · 쳐내기를 뚫는다 (castle_M combat.py '가드 관통!')
	if mv["guard_break"] and d.state == "parry" and _faces(d, a):
		events.append(["pierce", d, at])
		_take_hit(a, d, mv, at)
		return
	var parryable: bool = mv["parryable"]
	if parryable and d.parry_open() and _faces(d, a):
		_parry(a, d, at, mv)
		return
	if parryable and d.state == "parry" and _faces(d, a):
		stats["blocks"] += 1
		d.hp -= _dmg(a, d, mv) * block_dmg_k
		d.take_posture(float(mv["posture"]) * BLOCK_POSTURE_K)
		d.vel = push * float(mv["knockback"]) * 0.6
		hitstop = maxi(hitstop, 4)
		events.append(["block", d, at])
		d.gain("guard")
		if d.posture >= d.posture_max:
			_stagger(d)
		_check_hp(d, a)
		return
	# 늦은 쳐내기: 쳐내기가 있는 사람만 · 달리는 중이 아닐 때만(rules/전투_쳐내기.md 1절 — 69차 세부)
	if parryable and not mv["guard_break"] and not d.is_boss and d.can_parry and d.can_act() \
			and d.running_t < Fighter.RUN_AFTER and _faces(d, a) and LATE_PARRY > 0:
		pending.append([a, d, mv, at, LATE_PARRY])
		return
	_take_hit(a, d, mv, at)


func _take_hit(a, d, mv: Dictionary, at: Vector3) -> void:
	var push: Vector2 = a.dir_to(d)
	var dmg: float = _dmg(a, d, mv)
	if str(mv["name"]).ends_with("finisher") and d.state == "stagger":
		if d.finisher_cap > 0.0:
			dmg = minf(dmg, d.hp_max * d.finisher_cap)
		d.hp -= dmg
		d.posture = 0.0
		d.get_down()
		d.vel = push * float(mv["knockback"])
		d.flash = 10
		hitstop = maxi(hitstop, int(mv["hitstop"]))
		shake = maxi(shake, int(mv["shake"]))
		stats["hits"] += 1
		events.append(["finish", d, at, a])
		a.gain("finisher")
		_check_hp(d, a)
		return
	var lethal := str(mv["lethal"])
	if lethal != "":
		# 엇박 계열: 맞는 쪽 등급에 따라 최대 체력의 몇 분의 몇 (common lethal_fraction — 김신 내성 상위 → 백도찬 톱 엇박:
		# 1/3 × 2/3, 백도찬 → 김신: 1/2), 엇엇박은 쓴 칸 / 10, 외성 상위 이하는 즉사
		var frac: float = rules.lethal_fraction(lethal, d.rank, a.rank, a.skill_paid)
		dmg = d.hp_max * frac
		shake = maxi(shake, 6)
		events.append(["lethal", d, at, frac, lethal])
		stats["boss_offbeats" if a.is_boss else "offbeats"] += 1
	# 한 방: 기술의 ko_rank(그 등급 이하) · 등급 차 one_shot_gap 이상 — 조작 인물 · 방의 보스는 빼고(보스전은 보통 피해로 —
	# 위빙 · 오리지널이 보스를 두 번에 눕혀 2장 신태진전이 17초에 끝났다, 봇 판 2026-11-08)
	if lethal == "" and not d.oneshot_immune and (Skills.kills(rules, mv, d.rank) or Skills.one_shot(rules, a.rank, d.rank, false)):
		dmg = maxf(dmg, d.hp)
		events.append(["oneshot", d, at])
	d.hp -= dmg
	d.take_posture(float(mv["posture"]))
	d.get_hit(mv, push, a.rank)
	if float(mv["self_cost"]) > 0.0:
		# 엇엇박: 맞히면 쓴 사람도 체력 1/5 를 잃는다 (쓰러지지는 않는다)
		var cost: float = a.hp_max * float(mv["self_cost"])
		a.hp = maxf(1.0, a.hp - cost)
		events.append(["self_cost", a, cost])
	# 넘어뜨리기: 여러 대(삼연타)는 마지막 대에, 한 대짜리(0 · 1장 태클 · 메치기)는 그 대에 — hit_no 가 없으면 마지막 대로 본다
	if int(mv.get("hit_no", mv["hits"])) >= int(mv["hits"]) and mv["knockdown"] and not d.is_boss:
		d.get_down()
	stats["hits"] += 1
	hitstop = maxi(hitstop, int(mv["hitstop"]))
	shake = maxi(shake, int(mv["shake"]))
	events.append(["hit", d, at, mv])
	a.gain("hit", rules.skill_hit_k() if mv["skill"] else 1.0)
	d.gain("taken")
	if d.posture >= d.posture_max and d.state != "stagger" and d.state != "down":
		_stagger(d)
	# 기절은 빈틈(체간 무너짐) 다음에 본다 — 같은 대에 체간이 다 차면 빈틈이 이긴다(폰 리뷰 2026-10-26: 빈틈이 뜨면서
	# "기절!" 도 뜨던 것). 빈틈 · 넘어짐 중이면 기절이 걸리지 않는다(run #8 에서 글자만 떴다)
	var stun := Skills.stun_frames(rules, mv, a.rank, d.rank)          # common stun_sec → 없으면 3D 덧붙임 stun_3d
	if stun > 0 and d.hp > 0.0:
		d.get_stun(stun)
		if d.state == "stun":
			events.append(["stun", d, at, stun])
	_check_hp(d, a)


## 이번 한 대의 기술 값 — 리천식 삼연타는 맞은 순서(1 ~ hits)를 "hit_no" 로 달고, 셋째 대는 넉백 · 멈춤 · 흔들림을 크게
## (보스는 넘어지지 않는다 — 초안 잠정)
func _hit_move(a) -> Dictionary:
	var mv: Dictionary = a.move
	if not str(mv["fx"]) in ["triple", "amur3"] or int(mv["hits"]) <= 1:
		return mv
	var s := int(mv["startup"])
	var seg := maxi(1, int(mv["active"]) / int(mv["hits"]))
	var no := mini(int(mv["hits"]), maxi(1, (a.t - s - 1) / seg + 1))
	var m2: Dictionary = mv.duplicate()
	m2["hit_no"] = no
	if no < int(mv["hits"]):
		m2["stun_off"] = true                     # 기절은 셋째 대만
	elif str(mv["fx"]) == "amur3":
		m2["hitstop"] = 12                        # 아무르 티그로 3연타 셋째 '쾅' — 크게 멈추고 흔들되 날려 보내지는 않는다
		m2["shake"] = 6
	else:
		m2["knockback"] = float(mv["knockback"]) * TRIPLE_LAST["knockback_k"]
		m2["hitstop"] = TRIPLE_LAST["hitstop"]
		m2["shake"] = TRIPLE_LAST["shake"]
		m2["hit_sfx"] = "hit_heavy"
		m2["knockdown"] = true
	return m2


func _parry(a, d, at: Vector3, mv: Dictionary) -> void:
	d.parry_side = Moves.parry_side(mv)          # 쳐내는 동작 방향(그림) — 들어오는 쪽 팔로 튕긴다
	# 보스가 김신을 쳐내면 휘청이 짧다 (맞받아 베기를 다시 쳐낼 수 있게) — castle_M P2 설계서 8.3
	var k := 0.35 if d.is_boss else 2.2
	var bonus := 0.0 if d.is_boss else 22.0
	var frames := 12 if d.is_boss else 28
	a.take_posture(float(mv["posture"]) * k + bonus)
	a.get_recoil(frames, d.dir_to(a))
	d.counter_ready = Fighter.COUNTER_T
	d.flick_t = 10
	d.gain("parry")
	d.set_state("idle")
	hitstop = maxi(hitstop, PARRY_HITSTOP)
	shake = maxi(shake, PARRY_SHAKE)
	if d.is_boss:
		stats["boss_parries"] += 1
	else:
		stats["parries"] += 1
	events.append(["parry", d, at, a])
	if a.posture >= a.posture_max:
		_stagger(a)


func _stagger(f) -> void:
	f.get_stagger()
	stats["staggers"] += 1
	events.append(["stagger", f])


func _check_hp(d, a = null) -> void:
	if d.hp_floor > 0.0:
		d.hp = maxf(d.hp, d.hp_max * d.hp_floor)
	if d.phase2_at > 0.0 and d.phase == 1 and d.hp <= d.hp_max * d.phase2_at:
		d.hp = d.hp_max * d.phase2_at
		d.phase = 2
		phase = 2
		hitstop = maxi(hitstop, PHASE2_FREEZE)
		events.append(["phase2", d])
		return
	if d.hp <= 0.0:
		d.downed_by_mob = a != null and a.is_mob
		d.die()
		events.append(["ko", d])
		if a != null:
			a.gain("ko")                          # 쓰러뜨리면 게이지 (common gauge.gain.ko — 1:1 은 판이 끝나 화면엔 안 보인다)
		if end_on_ko:
			over = "lose" if not d.is_boss else "win"
			hitstop = maxi(hitstop, 30)
		else:
			hitstop = maxi(hitstop, 12)


## 맞은 자리 (3D: x, 높이, z) — 불꽃 · 번쩍임이 여기서 난다
func _contact(a, d) -> Vector3:
	var p: Vector2 = a.pos.lerp(d.pos, 0.6)
	var h := 1.15
	var shape := str(a.move["shape"])
	if shape == "sidekick":
		h = 0.95
	elif shape == "thrust_low":
		h = 0.9
	return Vector3(p.x, h, p.y)
