extends RefCounted
## [옮김] castle_M3D `src/combat/fighter_body.gd`(2c3e69b) — 바꾼 것: 규칙을 인스턴스(rules)로 받음 · 습격 구간 값 칸(is_mob · atk_mob · atk_off · off_k · unit_i). 설계: docs/C4_설계서_직접조작전투.md 4-1 · 요구: FR-401
## 싸우는 사람 하나의 바탕 — 상수 · 상태 값 · 묻기(살았나 · 판정 중인가 · 예고) · 기술 게이지 · 맞기(world.gd 가 부른다).
## 순수 로직(노드 없음, 60프레임 고정). 입력을 받아 한 프레임씩 나아가는 상태 기계는 fighter.gd(이 파일을 잇는다 — 2026-11-09 나눔).
## castle_M `castle_m/action/fighter.py` 의 규칙을 초안에 필요한 만큼 줄여 옮겼다(구르기 무적 · 쳐내기 창 · 버퍼 ·
## 휘청 · 빈틈). 판정은 world.gd, 그림은 src/view/puppet3d.gd 가 이 상태를 읽어서 그린다.
## 좌표: pos 는 바닥 평면 (x, z) 미터. z 는 화면 아래(카메라 쪽)로 커진다.

const Moves = preload("res://fight/moves.gd")

const ROLL_T := 20
const ROLL_IFRAMES := Vector2i(2, 14)
const ROLL_DIST := 2.2
const PARRY_WINDOW := 7          # 누른 뒤 이 프레임 안에 칼을 받으면 '칼날 쳐내기' (늦게 누른 것은 world.gd LATE_PARRY)
const PARRY_MIN := 12            # 짧게 눌러도 이만큼은 막는 자세
const PARRY_END := 8             # 막기를 풀고 돌아오는 동안은 빈틈
const PARRY_SPAM := 24           # 막기를 푼 뒤 이 안에 다시 누르면 판정 창이 줄어든다
const PARRY_BUFFER := 3
const ATTACK_BUFFER := 8
const ROLL_BUFFER := 5
const COUNTER_T := 24            # 쳐내기 성공 뒤 반격 베기를 낼 수 있는 프레임
const DOWN_T := 70               # 제압당해 넘어진 뒤 일어나기까지
const RUN_AFTER := 10            # 스틱을 끝까지 이만큼 밀면 달리기 → 공격은 돌진 찌르기
## 대시 버튼(rc.2 폰 2026-11-07 — 사용자 '대시 버튼 따로 · 대시 + 공격 = 특별기'): 누르면 DASH_T 프레임 동안 DASH_K × 달리기 빠르기로
## 스틱 쪽(없으면 보는 쪽)으로 내달린다. 대시 중이거나 끝난 뒤 DASH_GRACE 프레임 안에 공격하면 moveset dash(인물마다 대시기).
## 무적은 없다(무적은 구르기)
const DASH_T := 12
const DASH_K := 1.8
const DASH_GRACE := 10
const DASH_BUFFER := 5
const BODY_R := 0.3
const POSTURE_REGEN := 0.22      # 체간 회복(프레임당), 마지막 체간 피해 뒤 REGEN_AFTER 부터
const REGEN_AFTER := 90

var name := ""                   # 화면 이름 (characters.json name)
var char_id := ""                # 인물 id (characters.json — kimshin · baekdochan)
var team := 0
var is_boss := false
var pos := Vector2.ZERO
var facing := Vector2(0, -1)
var vel := Vector2.ZERO          # 넉백 속도 (m/초)
var state := "idle"
var t := 0
var clock := 0
var move: Dictionary = {}
var attack_id := 0               # 기술을 낼 때마다 1씩 — AI 가 같은 공격에 두 번 반응하지 않게
var hit_ids := {}
var landed := false              # 이번 기술이 누군가에게 닿았는지 (맞힘 · 막힘 · 쳐내짐) — 헛치면 move.whiff 만큼 더 멈춘다
var whiff_t := 0                 # 헛쳐서 회수에 더해진 프레임
var moveset := {}
var _target: WeakRef = null      # 마주 보는 상대 (서로 붙잡으면 순환 참조라 약한 참조)

var hp := 100.0
var hp_max := 100.0
var posture := 0.0
var posture_max := 100.0
var last_posture_hit := -999
var poise := 0.0                 # 체간 피해가 이보다 작은 공격에는 움찔하지 않는다 (보스)
var dmg_k := 1.0
var parry_extra := 0
var stagger_len := 50
var walk_speed := 2.1
var run_speed := 4.6

var intent := {}
var buf_attack := 0
var buf_parry := 0
var parry_side := "R"            # 쳐내는 동작 방향 (L 왼팔 · R 오른팔, 그림용) — 판정과 관계없다
var buf_roll := 0
var parry_bonus := 0
var last_parry_end := -999
var hold_t := 0                  # 휘청 · 움찔이 이어지는 프레임
var counter_ready := 0
var flick_t := 0                 # 쳐내기 성공 동작(그림용)
var roll_dir := Vector2.ZERO
var running_t := 0
var buf_dash := 0
var dash_t := 0
var dash_grace := 0
var dash_dir := Vector2.ZERO
var speed_now := 0.0             # 지난 프레임 움직인 빠르기 (m/초, 그림용)
var move_vec := Vector2.ZERO     # 지난 프레임 움직인 방향 (그림용)
var flash := 0
var events: Array = []           # world 가 모아 가는 연출 신호

# 기술(스킬) — src/data/skills.gd · common.gd. 게이지는 점수(한 칸 = common bar_points), 보스는 게이지 없이 패턴으로 쓴다(gauge_max 0)
var rank := ""                   # 등급 이름 (ranks.json ladder — "내성 상위" 등)
var skills: Array = []
var skill_idx := 0
var gauge := 0.0
var gauge_max := 0.0
var gauge_rate := 1.0
var buf_skill := 0
var skill_paid := 0.0            # 마지막 기술에 쓴 칸 수 (엇엇박 피해가 비례)
var hp_floor := 0.0              # 체력이 최대 체력의 이 비율 아래로 내려가지 않는다 (백도찬 첫 엇박 장면)
# 여러 사람 판(11장) — 결투(duel.gd)는 백도찬만 finisher_cap · phase2_at 을 쓴다
var can_parry := true            # 칼날 쳐내기(타이밍 패리)는 김신 · 백도찬만 — 다른 사람은 막기만 (castle_common 김신 book)
var finisher_cap := 0.0          # 제압 피해 상한(최대 체력 비율, 0 = 없음) — 백도찬 0.08
var phase := 1
var phase2_at := 0.0             # 체력이 이 비율이 되면 2차(0 = 2차 없음)
var inert := false               # 싸움에서 빠졌다(신겐이 길을 내줌) — 치지도 맞지도 않는다
var rules = null                 # fight/rules_rt.gd 인스턴스(2층 규칙 · 게이지 값) — 만들 때 받는다
## 습격 구간 판(fight/build.gd)이 채우는 값 — 틱 유닛에서 온다(설계서 4-3). atk_mob 이 0 이면 castle_M3D 처럼 동작 피해 × dmg_k
var is_mob := false              # 조직원(묶음의 한 명)
var atk_mob := 0.0               # 한 대 기준 피해 — 조직원을 칠 때 · 조직원이 칠 때(유닛 atk · atk1)
var atk_off := 0.0               # 한 대 기준 피해 — 간부가 간부를 칠 때(일기토 보통 맞힘)
var off_k := 1.0                 # 맞는 간부의 환산(습격 체력 ÷ 일기토 체력)
var unit_i := -1                 # 이 사람이 온 유닛 자리(구간 결과를 낼 때)
var downed_by_mob := false       # 조직원에게 쓰러졌다(부상 값이 다르다)
var oneshot_immune := false      # 한 방(등급 차 common.one_shot · 기술 ko_rank)을 안 받는다 — 조작 인물 · 방의 보스(판이 정한다)


func set_target(f) -> void:
	_target = weakref(f) if f != null else null


func target():
	return _target.get_ref() if _target != null else null


func _init(nm := "", tm := 0, r = null) -> void:
	name = nm
	team = tm
	rules = r


func can_act() -> bool:
	return state == "idle" or state == "move"


func alive() -> bool:
	return state != "dead"


func set_state(s: String) -> void:
	state = s
	t = 0


func start_move(nm: String) -> void:
	move = Moves.get_move(nm, rules)
	attack_id += 1
	hit_ids.clear()
	landed = false
	whiff_t = 0
	buf_attack = 0
	running_t = 0
	set_state("attack")


func is_active() -> bool:
	if state != "attack":
		return false
	var s := int(move["startup"])
	return t > s and t <= s + int(move["active"])


func in_recovery() -> bool:
	return state == "attack" and t > int(move["startup"]) + int(move["active"])


func iframes() -> bool:
	if state == "attack" and move.get("iframes", false):
		return t <= int(move["startup"]) + int(move["active"])        # 무적 기술(위빙 · 사라지는 스텝) — 판정이 끝날 때까지
	return state == "roll" and t >= ROLL_IFRAMES.x and t <= ROLL_IFRAMES.y


## 카운터 자세(move.stance): 준비 앞 stance 프레임 동안 마주 본 공격을 받아 넘긴다(world.gd 가 보고 stance_hit 로 맞받는다)
func stance_open() -> bool:
	return state == "attack" and int(move.get("stance", 0)) > 0 and t <= int(move["stance"])


func parry_open() -> bool:
	return can_parry and state == "parry" and t <= PARRY_WINDOW + parry_bonus + parry_extra


## 예고: [종류, 판정까지 남은 프레임] — 종류 parry(흰 !) · unblock(빨간 !). 예고가 없으면 [].
func telegraph() -> Array:
	if state != "attack" or str(move["telegraph"]) == "":
		return []
	var left := int(move["startup"]) - t
	if left < 0:
		return []
	return [str(move["telegraph"]), left]


func dir_to(other) -> Vector2:
	var d: Vector2 = other.pos - pos
	return d.normalized() if d.length() > 0.0001 else facing


func dist_to(other) -> float:
	return pos.distance_to(other.pos)


# ----------------------------------------------------------------------
# 기술 게이지 (기술을 내는 것은 fighter.gd _try_skill)
func current_skill() -> Dictionary:
	return skills[skill_idx] if not skills.is_empty() else {}


## 이 기술을 쓸 만큼 게이지가 찼는지 (cost < 0 = 엇엇박: ALL_MIN_BARS 칸 이상)
func can_pay(sk: Dictionary) -> bool:
	var cost := float(sk["cost"])
	if cost < 0.0:
		return gauge + 0.001 >= rules.all_min_bars() * rules.bar_points()
	return gauge + 0.001 >= cost * rules.bar_points()


## 기술 목록에서 id 의 자리 (없으면 -1)
func skill_index(id: String) -> int:
	for i in skills.size():
		if str(skills[i]["id"]) == id:
			return i
	return -1


## 기술 게이지 채우기 (kind: common rules.json gauge.gain 의 종류 — hit · parry · guard · taken · finisher · ko · dodge)
func gain(kind: String, k := 1.0) -> void:
	if gauge_max > 0.0:
		gauge = clampf(gauge + rules.gain_points(kind) * k * gauge_rate, 0.0, gauge_max)


# ----------------------------------------------------------------------
# 맞기 · 쳐내기 당하기 (world.gd 가 부른다)
func take_posture(v: float) -> void:
	posture = minf(posture_max, posture + v)
	last_posture_hit = clock


func get_hit(mv: Dictionary, from_dir: Vector2, att_rank := "") -> void:
	flash = 8
	vel = from_dir * float(mv["knockback"])
	if state == "stagger" or state == "down" or state == "dead":
		return
	if is_boss and float(mv["posture"]) < poise:
		return                                   # 버팀: 피해만 받고 움찔하지 않는다
	if rank != "" and att_rank != "" and not mv["knockdown"] and rules.shrugs_off(rank, att_rank):
		return                                   # 한참 아랫급의 공격에는 움찔하지 않는다 (common shrugs_off, 넘어뜨리기 빼고)
	hold_t = int(mv["hitstun"])
	set_state("hitstun")


func get_recoil(frames: int, from_dir: Vector2) -> void:
	vel = from_dir * 1.8
	hold_t = frames
	set_state("recoil")


## 기절 (각법): 움직이지 못하고 머리 위에 '기절'
func get_stun(frames: int) -> void:
	if state == "stagger" or state == "down" or state == "dead":
		return
	hold_t = frames
	set_state("stun")


func get_stagger() -> void:
	posture = posture_max
	set_state("stagger")


func get_down() -> void:
	set_state("down")


func die() -> void:
	hp = 0.0
	set_state("dead")
