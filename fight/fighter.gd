extends "res://fight/fighter_body.gd"
## [옮김] castle_M3D `src/combat/fighter.gd`(2c3e69b) — 바꾼 것: 규칙을 인스턴스(rules)로. 설계: docs/C4_설계서_직접조작전투.md 4-1 · 요구: FR-401
## 싸우는 사람 하나의 상태 기계 — 입력(intent)을 버퍼에 받고 tick 마다 한 프레임씩 나아간다(걷기 · 대시 · 공격 연타 · 기술 ·
## 막기 · 구르기 · 휘청 · 넘어짐에서 일어나기). 순수 로직(노드 없음, 60프레임 고정, 같은 입력이면 같은 결과).
## 상수 · 상태 값 · 맞기 · 게이지는 바탕 fighter_body.gd. 밖에서는 이 파일만 부른다(Fighter.new · Fighter.ROLL_T 등).


## 공격 · 막기 · 구르기 버튼은 '누른 프레임'만 true 로 온다. 역경직 중에도 받아 둔다(씹히지 않게).
func buffer_inputs() -> void:
	if intent.get("attack", false):
		buf_attack = ATTACK_BUFFER
	if intent.get("parry", false):
		buf_parry = PARRY_BUFFER
	if intent.get("roll", false):
		buf_roll = ROLL_BUFFER
	if intent.get("skill", false):
		buf_skill = ATTACK_BUFFER
	if intent.get("dash", false):
		buf_dash = DASH_BUFFER
	_pick_skill_input()


## 기술 고르기 입력: skill_next(다음으로 한 칸) · skill_pick(번호로 바로 — 봇)
func _pick_skill_input() -> void:
	if skills.is_empty():
		return
	if intent.get("skill_next", false):
		skill_idx = (skill_idx + 1) % skills.size()
	if intent.has("skill_pick") and int(intent["skill_pick"]) >= 0:
		skill_idx = clampi(int(intent["skill_pick"]), 0, skills.size() - 1)


func _decay_buffers() -> void:
	buf_skill = ATTACK_BUFFER if intent.get("skill", false) else maxi(0, buf_skill - 1)
	buf_attack = ATTACK_BUFFER if intent.get("attack", false) else maxi(0, buf_attack - 1)
	buf_parry = PARRY_BUFFER if intent.get("parry", false) else maxi(0, buf_parry - 1)
	buf_roll = ROLL_BUFFER if intent.get("roll", false) else maxi(0, buf_roll - 1)
	buf_dash = DASH_BUFFER if intent.get("dash", false) else maxi(0, buf_dash - 1)
	if dash_grace > 0:
		dash_grace -= 1


func tick() -> void:
	clock += 1
	t += 1
	var before := pos
	if flash > 0:
		flash -= 1
	if counter_ready > 0:
		counter_ready -= 1
	if flick_t > 0:
		flick_t -= 1
	_pick_skill_input()
	_decay_buffers()
	# 빈틈 · 움찔 중에도 쓰는 기술 (백도찬식 찌르기 — Move.any_state)
	var use: String = intent.get("use", "")
	if use != "" and (state == "stagger" or state == "hitstun") and Moves.get_move(use, rules)["any_state"]:
		start_move(use)
	if state != "idle" and state != "move":
		dash_t = 0                                     # 맞거나 막히면 대시가 끊긴다
	match state:
		"idle", "move":
			_tick_free()
		"attack":
			_tick_attack()
		"parry":
			if t >= PARRY_MIN and not intent.get("parry_held", false):
				last_parry_end = clock
				set_state("parry_end")
		"parry_end":
			if t >= PARRY_END:
				set_state("idle")
		"roll":
			_tick_roll()
		"hitstun", "recoil", "stun":
			if t >= hold_t:
				set_state("idle")
		"stagger":
			if t >= stagger_len:
				posture = 0.0
				set_state("idle")
		"down":
			if t >= DOWN_T:
				posture = 0.0
				set_state("idle")
	if vel.length() > 0.05:
		pos += vel / 60.0
		vel *= 0.86
	else:
		vel = Vector2.ZERO
	if clock - last_posture_hit > REGEN_AFTER and state != "stagger" and state != "down":
		posture = maxf(0.0, posture - POSTURE_REGEN)
	move_vec = pos - before
	speed_now = move_vec.length() * 60.0


func _tick_free() -> void:
	var mv: Vector2 = intent.get("move", Vector2.ZERO)
	if dash_t > 0:
		_tick_dash()
		return
	if buf_dash > 0:
		buf_dash = 0
		dash_dir = mv.normalized() if mv.length() > 0.2 else facing
		dash_t = DASH_T
		events.append(["dash", self])
		_tick_dash()
		return
	if buf_roll > 0:
		_start_roll(mv.normalized() if mv.length() > 0.2 else -facing)
		return
	if buf_parry > 0:
		_start_parry()
		return
	if buf_skill > 0 and _try_skill():
		return
	var use: String = intent.get("use", "")
	if use != "":
		start_move(use)
		if move["skill"]:
			events.append(["skill", self, {"id": use, "name": move["label"]}])     # 보스 기술 (게이지 없이 패턴으로)
		return
	if buf_attack > 0:
		var nm := _pick_attack()
		if nm != "":
			start_move(nm)
			return
	var face: Vector2 = intent.get("face", Vector2.ZERO)
	if mv.length() > 0.1:
		running_t = running_t + 1 if mv.length() > 0.85 else 0
		var running := running_t >= RUN_AFTER
		var spd := run_speed if running else walk_speed * clampf(mv.length() * 1.3, 0.35, 1.0)
		pos += mv.normalized() * spd / 60.0
		if running or face == Vector2.ZERO:
			facing = mv.normalized()
		else:
			facing = face.normalized()
		state = "move"
	else:
		running_t = 0
		if face != Vector2.ZERO:
			facing = face.normalized()
		state = "idle"


## 대시: 내달리는 동안 공격 · 기술 · 구르기 · 막기로 끊을 수 있다. 끝나면 DASH_GRACE 동안 공격 = 대시기
func _tick_dash() -> void:
	if buf_attack > 0 and moveset.has("dash"):
		dash_t = 0
		start_move(moveset["dash"])
		return
	if buf_skill > 0 and _try_skill():
		dash_t = 0
		return
	if buf_roll > 0 or buf_parry > 0:
		dash_t = 0
		return
	dash_t -= 1
	facing = dash_dir
	pos += dash_dir * run_speed * DASH_K / 60.0
	state = "move"
	running_t = RUN_AFTER
	if dash_t <= 0:
		dash_grace = DASH_GRACE


## 반격 베기(쳐내기 직후) · 제압(상대가 빈틈) — 연타 중이어도 이것이 먼저다
func _special_attack() -> String:
	if counter_ready > 0 and moveset.has("counter"):
		return moveset["counter"]
	var tg = target()
	if tg != null and tg.state == "stagger" and dist_to(tg) < 1.6 and moveset.has("finisher"):
		return moveset["finisher"]
	return ""


func _pick_attack() -> String:
	var special := _special_attack()
	if special != "":
		return special
	if (running_t >= RUN_AFTER or dash_grace > 0) and moveset.has("dash"):
		dash_grace = 0
		return moveset["dash"]
	return moveset.get("combo", "")


func _tick_attack() -> void:
	var s := int(move["startup"])
	var a := int(move["active"])
	# 준비 앞부분 동안은 상대 쪽으로 몸을 튼다 (보스는 길게 — 예고를 보고 옆으로 돌아도 따라온다)
	var track := int(s * 0.6) if is_boss else 2
	var tg = target()
	if tg != null and t <= track:
		facing = dir_to(tg)
	var lunge: float = move["lunge"]
	if lunge > 0.0 and t <= s + a:
		pos += facing * lunge / float(s + a)
	var side: float = move["side"]
	if side != 0.0 and t <= s:
		var sgn := 1.0
		if move.get("zigzag", false):
			sgn = 2.0 if t <= s / 2 else -2.0              # 좌우로 사라지는 스텝: 한쪽으로 갔다가 반대쪽으로(제자리에서 비켜 들어간다)
		pos += Vector2(-facing.y, facing.x) * side * sgn / float(s)
	if int(move["hits"]) > 1 and is_active():
		var step := maxi(1, a / int(move["hits"]))
		if (t - s - 1) % step == 0:
			hit_ids.clear()
	for fr in move["feints"]:
		if t == int(fr):
			events.append(["feint", self])
	if int(move["brake"]) > 0 and t == int(move["brake"]):
		events.append(["brake", self])                  # 엇엇박: 브레이크 — 온몸에 부하
	# 헛침: 판정이 끝날 때까지 아무도 못 맞혔으면 뻗은 채로 더 멈춘다 (엇박 · 엇엇박 — 역공을 받는다)
	if t == s + a + 1 and not landed and int(move["whiff"]) > 0:
		whiff_t = int(move["whiff"])
		events.append(["whiff", self])
	# 연타 중에도 기술로 끊을 수 있다(기술 동작에서 다른 기술로는 안 된다)
	if buf_skill > 0 and t >= Moves.cancel_at(move) and not move["skill"] and _try_skill():
		return
	if buf_attack > 0 and t >= Moves.cancel_at(move) and not is_boss and whiff_t == 0:
		var special := _special_attack()
		if special != "" and special != str(move["name"]):
			start_move(special)
			return
		if str(move["next"]) != "":
			start_move(str(move["next"]))
			return
	# 회수 뒤쪽은 구르기로 끊을 수 있다
	if buf_roll > 0 and t > s + a + whiff_t + 4:
		var mv: Vector2 = intent.get("move", Vector2.ZERO)
		_start_roll(mv.normalized() if mv.length() > 0.2 else -facing)
		return
	if t >= Moves.total(move) + whiff_t:
		set_state("idle")


## 고른 기술을 낸다 — 게이지가 모자라면 아무것도 안 하고 false (버퍼는 남겨 두지 않는다)
func _try_skill() -> bool:
	if skills.is_empty():
		return false
	buf_skill = 0
	var sk: Dictionary = skills[skill_idx]
	if not can_pay(sk):
		events.append(["no_gauge", self])
		return false
	if float(sk["cost"]) < 0.0:
		skill_paid = gauge / rules.bar_points()        # 엇엇박: 게이지 전부
		gauge = 0.0
	else:
		skill_paid = float(sk["cost"])
		gauge -= skill_paid * rules.bar_points()
	start_move(str(sk["move"]))
	events.append(["skill", self, sk])
	return true



func _start_parry() -> void:
	buf_parry = 0
	var tg = target()
	if tg != null and tg.state == "attack":
		parry_side = Moves.parry_side(tg.move)      # 상대가 내는 공격 쪽 팔을 세운다
	parry_bonus = -3 if clock - last_parry_end < PARRY_SPAM else 0
	set_state("parry")


func _start_roll(d: Vector2) -> void:
	buf_roll = 0
	roll_dir = d
	running_t = 0
	set_state("roll")


func _tick_roll() -> void:
	# 처음이 빠르고 끝이 느리다. 합하면 ROLL_DIST
	pos += roll_dir * ROLL_DIST * (1.0 - float(t) / ROLL_T) / 9.5
	if t >= ROLL_T:
		set_state("idle")
