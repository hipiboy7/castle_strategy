extends RefCounted
## [옮김] castle_M3D `src/combat/bot.gd`(2c3e69b) — 바꾼 것: 불러오는 경로만. 설계: docs/C4_설계서_직접조작전투.md 4-1 · 요구: FR-401
## 자동 플레이 봇 (김신 쪽) — 예고 표시만 보고 받는다: 흰 ! 는 쳐내기, 빨간 ! 는 구르기. 게이지가 되면 기술도 쓴다.
## castle_M BotController 처럼 '표시만 보고 이길 수 있는지'로 예고의 공정성을 확인하고, 데모 · 자동 점검에 쓴다.
## skill 은 제때 누를 확률(사람처럼 가끔 놓친다). 같은 시드면 같은 결과.
## 여러 사람 판(stage.gd): foe 는 판이 매 프레임 가장 가까운 적으로 바꾸고, foes(살아 있는 적 전부) 중 나를 노리는 예고가
## 가장 급한 것에 답한다(총은 선 위에 있을 때만). generic_skills: 아군(구일화)은 정해 둔 순서 대신 되는 기술 아무것이나.

const Fighter = preload("res://fight/fighter.gd")
const Skills = preload("res://fight/skills.gd")

var me
var foe
var rng: RandomNumberGenerator
var skill := 0.85
var answered := ""
var hold := 0
var poke_t := 0
var skill_cd := 120
var foes: Array = []
var generic_skills := false


func _init(hero, boss, r: RandomNumberGenerator) -> void:
	me = hero
	foe = boss
	rng = r


func decide() -> Dictionary:
	var to: Vector2 = me.dir_to(foe)
	var it := {"move": Vector2.ZERO, "face": to}
	if not me.alive() or not foe.alive():
		return it
	var d: float = me.dist_to(foe)
	if hold > 0:
		hold -= 1
		it["parry_held"] = true
		return it
	var src = foe
	var tel: Array = []
	for f in (foes if not foes.is_empty() else [foe]):
		if not f.alive() or f.inert:
			continue
		var tg: Array = f.telegraph()
		if tg.is_empty() or _key(f) == answered or not _threat(f):
			continue
		if tel.is_empty() or int(tg[1]) < int(tel[1]):
			tel = tg
			src = f
	if not tel.is_empty():
		var kind: String = tel[0]
		var left: int = tel[1]
		to = me.dir_to(src)
		if kind == "parry" and left <= 4 and left >= 1:
			answered = _key(src)
			if rng.randf() < skill:
				it["parry"] = true
				it["parry_held"] = true
				hold = Fighter.PARRY_MIN
			return it
		if kind == "unblock" and left <= 7:
			answered = _key(src)
			# 백도찬 엇박엔 엇엇박으로 맞받는다(부딪히면 엇엇박이 이긴다) — 게이지가 되면 반쯤은
			var ob2: int = me.skill_index("offbeat2")
			if str(src.move["lethal"]) == "offbeat" and ob2 >= 0 and me.can_act() and me.can_pay(me.skills[ob2]) \
					and rng.randf() < 0.5:
				it["skill_pick"] = ob2
				it["skill"] = true
				return it
			if rng.randf() < skill:
				var side := Vector2(-to.y, to.x) * (1.0 if rng.randf() < 0.5 else -1.0)
				it["roll"] = true
				it["move"] = (side - to * 0.6).normalized()
			return it
	var open: bool = foe.state in ["stagger", "recoil", "hitstun", "down", "stun"] or foe.in_recovery()
	skill_cd -= 1
	var sk := _pick_skill(d)
	if sk >= 0:
		it["skill_pick"] = sk                    # '기술 바꾸기'를 그만큼 누른 것과 같다 — 봇도 입력(intent)으로만 움직인다(리플레이 · 멀티)
		it["skill"] = true
		skill_cd = 240
		return it
	if me.counter_ready > 0 or open:
		if d > 1.15:
			it["move"] = to
		elif me.can_act() or me.state == "attack":
			it["attack"] = true
		return it
	# 기다리며 거리 조절, 가끔 먼저 찔러 본다 (맞수를 부르는 공격)
	if d > 1.9:
		it["move"] = to * 0.8
	elif d < 1.1:
		it["move"] = -to * 0.6
	else:
		it["move"] = Vector2(-to.y, to.x) * 0.35
	poke_t -= 1
	if poke_t <= 0 and d < 1.5 and me.can_act():
		poke_t = 50 + rng.randi_range(0, 60)
		it["attack"] = true
	return it


func _key(f) -> String:
	return "%d:%d" % [f.get_instance_id(), f.attack_id]


## 이 예고가 나를 노리나 — 총(shot)은 선 위(옆 0.7m 안 · 사거리 안)일 때만, 나머지는 3.2m 안
func _threat(f) -> bool:
	if str(f.move.get("shape", "")) == "shot":
		var to: Vector2 = me.pos - f.pos
		var along := to.dot(f.facing)
		return along > -0.3 and along < float(f.move["reach"]) + 0.5 and (to - f.facing * along).length() < 0.8
	return me.dist_to(f) < 3.2


## 기술: 쉬는 틈(skill_cd) 뒤 게이지가 되면 — 백도찬이 못 구르는 순간(쳐내기 당한 휘청 · 기절)엔 엇박 계열(배운 뒤,
## 엇엇박 → 엇박 → 반대발 순), 없으면 쳐낸 뒤 삼연타 · 움찔이나 헛친 뒤엔 각법. 빈틈엔 기술 대신 제압. 고를 수 없으면 -1
func _pick_skill(d: float) -> int:
	if skill_cd > 0 or not me.can_act() or me.skills.is_empty() or d > 1.6:
		return -1
	var order: Array = []
	match str(foe.state):
		"stun", "recoil":
			order = ["offbeat2", "offbeat", "offbeat_rev", "triple", "amur_weaving", "jin_original", "amur_triple"]
		"hitstun":
			order = ["kickarts", "amur_triple", "jintae_vital"]
		_:
			if foe.in_recovery():
				order = ["kickarts", "vanish_step", "jintae_vital"]
	if order.is_empty() and foes.filter(func(f): return f.alive() and not f.inert and me.dist_to(f) < 1.6).size() >= 3:
		order = ["jintae_storm"]                     # 셋 이상 붙어 있으면 난무(묶음 B)
	for id in order:
		var i: int = me.skill_index(id)
		if i >= 0 and me.can_pay(me.skills[i]):
			return i
	if generic_skills and not order.is_empty():
		for i in me.skills.size():
			if me.can_pay(me.skills[i]):
				return i
	return -1
