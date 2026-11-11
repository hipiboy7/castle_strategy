extends Node3D
## [옮김] castle_M3D `src/view/puppet_pose.gd`(2c3e69b) — 바꾼 것: 경로 · 글꼴(Noto Sans KR). 설계: docs/C4_설계서_직접조작전투.md 6절 · 요구: FR-403
## 관절 인형의 바탕 — 뼈 · 자세 · 움직임(update_from · 자세 고르기 · 섞기 · 발 붙이기 · 표시)만. 모습 만들기(몸 · 얼굴 · 머리 · 옷 · 무기)는
## 이어받는 src/view/puppet3d.gd(관절 인형) — 그림 A(puppet_glb) · B(puppet_dot)는 puppet3d 를 이어받는다(2026-11-09 큰 파일 나누기 — 동작은 그대로).
## 3D 관절 인형 — 뼈 길이가 고정된 노드 계층(골반 → 허리 → 가슴 → 목 → 머리, 어깨 → 팔꿈치 → 손, 엉덩이 → 무릎 → 발목)에
## 캡슐 · 원기둥 몸을 붙이고 관절 각도(src/view/poses.gd)로 자세를 잡는다. 길이는 노드 위치라 자세가 바뀌어도 그대로다
## (castle_M 2D 인형의 '팔다리 길이가 자세마다 늘었다 줄었다' 하던 문제 — castle_M history 2026-10-26).
## 상태가 바뀌면 자세를 지수 감쇠로 섞고(크로스페이드), 걷기 · 달리기는 주기 함수, 발은 땅에 붙인다(가장 낮은 발목 = 땅).
## 나중에 ArtCraft · Mixamo GLB 캐릭터로 바꿀 때는 같은 update_from(f, dt, frozen) 을 가진 그림으로 바꿔 끼운다.


const P = preload("res://ui/fight3d/poses.gd")
const Looks = preload("res://ui/fight3d/looks.gd")
const Fighter = preload("res://fight/fighter.gd")
const FONT = preload("res://assets/fonts/NotoSansKR-wght.ttf")

const PELVIS_H := 0.97
const HIP_W := 0.095
const THIGH := 0.45
const SHIN := 0.44
const ANKLE_H := 0.055
const BRAKE_AT := 0.45            # 엇엇박: 준비 → 타격 자세의 이만큼 뻗은 데서 브레이크가 걸린다
const CHEST_UP := 0.27
const NECK_UP := 0.215
const HEAD_UP := 0.135
const SHOULDER_W := 0.2
const SHOULDER_UP := 0.165
const UPPER_ARM := 0.29
const FOREARM := 0.26
const ROLL_PIVOT := 0.45
const GRIP_FWD := Vector3(0, -0.82, -0.57)    # 바로 쥔 칼날 방향 (손 좌표: 아래팔 연장선에서 엄지 쪽으로)
const GRIP_REV := Vector3(0, 0.55, 0.83)      # 거꾸로 쥔 칼날 (새끼손가락 쪽 → 아래팔을 따라 뒤로)

var look: Dictionary
var J := {}
var mats: Array = []
var cur := {}
var guard_pose := {}
var shape_keys := {}
var phase := 0.0
var yaw := 0.0
var time := 0.0
var glasses: Node3D = null
var tele: Label3D
var weapon_r: Node3D = null
var weapon_l: Node3D = null
var victory := false
var tele_y := 2.22
var _last_state := ""




static func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	for k in b:
		out[k] = b[k]
	return out


static func _lerp_pose(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := {}
	for key in P.NEUTRAL:
		var va = a.get(key, P.NEUTRAL[key])
		var vb = b.get(key, P.NEUTRAL[key])
		if va is Vector3:
			out[key] = (va as Vector3).lerp(vb, k)
		else:
			out[key] = lerpf(float(va), float(vb), k)
	return out


static func _ease_out(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u)


static func _ease_in_out(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func _torso(v: Vector3) -> Vector3:
	return Vector3(deg_to_rad(-v.x), deg_to_rad(v.y), deg_to_rad(-v.z))


static func _limb(v: Vector3, side: float) -> Vector3:
	return Vector3(deg_to_rad(v.x), deg_to_rad(v.y * side), deg_to_rad(v.z * side))


func _apply(p: Dictionary) -> void:
	J["hips"].position = Vector3(0, PELVIS_H + float(p["root_y"]), -float(p["root_fwd"]))
	J["hips"].rotation = _torso(p["pelvis"])
	J["spine"].rotation = _torso(p["spine"])
	J["chest"].rotation = _torso(p["chest"])
	J["neck"].rotation = _torso(p["head"])
	for side in ["r", "l"]:
		var sx := 1.0 if side == "r" else -1.0
		J["sh_" + side].rotation = _limb(p["sh_" + side], sx)
		J["el_" + side].rotation = Vector3(deg_to_rad(float(p["el_" + side])), 0, 0)
		J["hand_" + side].rotation = _limb(p["wr_" + side], sx)
		J["th_" + side].rotation = _limb(p["th_" + side], sx)
		J["kn_" + side].rotation = Vector3(-deg_to_rad(float(p["kn_" + side])), 0, 0)
		J["ft_" + side].rotation = Vector3(deg_to_rad(float(p["ft_" + side])), 0, 0)
	J["body"].rotation = Vector3(0, deg_to_rad(float(p["spin"])), 0)
	J["roll"].rotation = Vector3(deg_to_rad(float(p["roll"])), 0, 0)
	var fall := deg_to_rad(float(p["fall"]))
	J["fall"].rotation = Vector3(fall, 0, 0)
	J["fall"].position = Vector3(0, 0.11 * sin(fall), 0)


## 발 붙이기: 가장 낮은 발목이 땅 높이에 오도록 골반을 올리거나 내린다 (무릎을 굽히면 몸이 낮아진다)
func _ground() -> void:
	var lo := INF
	for side in ["r", "l"]:
		lo = minf(lo, to_local(J["ft_" + side].global_position).y)
	var k: float = J["body"].scale.y
	J["hips"].position.y += (ANKLE_H * k - lo) / k


## 발밑 고리 — 여럿이 섞이는 11장에서 누가 누구인지(조작 · 짝 · 아군). null 이면 없앤다
var marker: MeshInstance3D = null


func set_marker(col) -> void:
	if col == null:
		if marker != null:
			marker.visible = false
		return
	if marker == null:
		var t := TorusMesh.new()
		t.inner_radius = 0.42
		t.outer_radius = 0.5
		t.rings = 24
		t.ring_segments = 4
		marker = MeshInstance3D.new()
		marker.mesh = t
		marker.scale = Vector3(1, 0.08, 1)
		marker.position = Vector3(0, 0.02, 0)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		marker.material_override = m
		add_child(marker)
	marker.visible = true
	marker.material_override.albedo_color = col


func update_from(f, dt: float, frozen: bool) -> void:
	position = Vector3(f.pos.x, 0, f.pos.y)
	_update_flash(f)
	_update_telegraph(f)
	if frozen:
		return                                   # 역경직: 자세를 그대로 멈춘다
	time += dt
	if f.state != _last_state:
		# 돌기 · 구르기 각도를 짧은 쪽으로 감아 둔다 (세 바퀴 돈 뒤 거꾸로 풀리지 않게)
		cur["spin"] = wrapf(float(cur["spin"]), -180.0, 180.0)
		cur["roll"] = wrapf(float(cur["roll"]), -180.0, 180.0)
		_last_state = f.state
	var target := _target_pose(f, dt)
	var rate := 15.0
	match f.state:
		"attack":
			rate = 38.0
		"roll":
			rate = 40.0
		"recoil", "hitstun", "parry", "down", "dead", "stun":
			rate = 28.0
	cur = _lerp_pose(cur, target, 1.0 - exp(-rate * dt))
	if f.state == "attack":
		cur["spin"] = target["spin"]
	elif f.state == "roll":
		cur["roll"] = target["roll"]
	_apply(cur)
	if f.state != "roll" and f.state != "down" and f.state != "dead":
		_ground()
	var want: Vector2 = f.roll_dir if f.state == "roll" else f.facing
	var yaw_rate := 40.0 if f.state == "roll" or f.state == "attack" else 14.0
	yaw = lerp_angle(yaw, atan2(-want.x, -want.y), 1.0 - exp(-yaw_rate * dt))
	rotation.y = yaw


func _target_pose(f, dt: float) -> Dictionary:
	if victory:
		return _merge(guard_pose, P.VICTORY)
	match f.state:
		"idle", "move":
			return _locomotion(f, dt)
		"attack":
			return _attack_pose(f)
		"parry":
			# 쳐내는 쪽 팔만 세우고 반대 팔은 가드 그대로
			var pp := _merge(guard_pose, P.PARRY)
			var off := "l" if f.parry_side == "R" else "r"
			pp["sh_" + off] = guard_pose["sh_" + off]
			pp["el_" + off] = guard_pose["el_" + off]
			return pp
		"roll":
			var u := float(f.t) / Fighter.ROLL_T
			var p := _merge(guard_pose, P.TUCK)
			p["root_y"] = -0.4
			if u > 0.75:
				p = _lerp_pose(p, guard_pose, (u - 0.75) / 0.25)
			p["roll"] = -360.0 * _ease_in_out(u)
			return p
		"hitstun":
			return _merge(guard_pose, P.HURT)
		"recoil":
			return _merge(guard_pose, P.RECOIL)
		"stun":
			var st := _merge(guard_pose, P.STUN)
			st["chest"] = st["chest"] + Vector3(0, 6.0 * sin(time * 3.0), 10.0 * sin(time * 2.2))
			st["head"] = st["head"] + Vector3(0, 10.0 * sin(time * 3.0 - 0.5), 0)
			return st
		"stagger":
			var q := _merge(guard_pose, P.STAGGER)
			q["chest"] = q["chest"] + Vector3(0, 0, 9.0 * sin(time * 4.5))
			q["head"] = q["head"] + Vector3(0, 0, 12.0 * sin(time * 4.5 - 0.6))
			return q
		"down":
			return _down_pose(f, true)
		"dead":
			return _down_pose(f, false)
	return guard_pose


func _locomotion(f, dt: float) -> Dictionary:
	var p: Dictionary = guard_pose.duplicate()
	if f.flick_t > 0:
		p = _merge(p, P.FLICK if f.parry_side == "R" else _mirror(P.FLICK))   # 들어오는 쪽 팔로 바깥으로 튕긴다
	p["chest"] = p["chest"] + Vector3(1.4 * sin(time * 2.3), 0, 0)      # 숨
	var sp: float = f.speed_now
	if sp < 0.2:
		return p
	var mv: Vector2 = f.move_vec.normalized()
	var fwd: float = mv.dot(f.facing)
	var side: float = mv.dot(Vector2(-f.facing.y, f.facing.x))
	var run := sp > 3.2
	var cadence := 2.7 if run else 1.7 + 0.5 * clampf(sp / 2.1, 0.0, 1.0)
	phase = fmod(phase + TAU * cadence * dt, TAU)
	var s := sin(phase)
	var c := cos(phase)
	if run:
		return _merge(p, {
			"pelvis": Vector3(12, 8 * s, 0), "spine": Vector3(4, 0, 0), "chest": Vector3(6, -12 * s, 0),
			"head": Vector3(-14, 4 * s, 0),
			"th_r": Vector3(46 * s + 6, 0, 4), "th_l": Vector3(-46 * s + 6, 0, 4),
			"kn_r": 16.0 + 80.0 * maxf(0.0, c), "kn_l": 16.0 + 80.0 * maxf(0.0, -c),
			"ft_r": -12.0 * s, "ft_l": 12.0 * s,
			"sh_r": Vector3(-36 * s + 18, 10, 14), "el_r": 88.0, "sh_l": Vector3(36 * s + 18, 10, 14), "el_l": 88.0,
		})
	# 칼 자세 그대로 발만 옮긴다 (마주 본 채 앞뒤 · 옆걸음)
	var amp := 26.0 * clampf(sp / 2.1, 0.4, 1.0)
	p["th_r"] = p["th_r"] + Vector3(amp * s * fwd, 0, 14.0 * s * side)
	p["th_l"] = p["th_l"] + Vector3(-amp * s * fwd, 0, -14.0 * s * side)
	p["kn_r"] = float(p["kn_r"]) + 24.0 * maxf(0.0, c)
	p["kn_l"] = float(p["kn_l"]) + 24.0 * maxf(0.0, -c)
	p["sh_r"] = p["sh_r"] + Vector3(4.0 * s, 0, 0)
	p["sh_l"] = p["sh_l"] + Vector3(-4.0 * s, 0, 0)
	return p


## 동작 → 자세 모양 이름(되베기 · 왼손 주먹 · 왼손 총은 쪽을 붙인다) — 도트 시트 칸 이름도 이것(tools/make_sprites.gd · puppet_dot.gd)
func shape_key(mv: Dictionary) -> String:
	var shape := str(mv["shape"])
	if shape == "slash_back":
		return "slash_back_L" if str(mv["hand"]) == "L" and weapon_l != null else "slash_back_R"
	if (shape == "punch" or shape == "shot") and str(mv["hand"]) == "L" and str(mv["fx"]) != "triple":
		return shape + "_L"                            # 왼손 주먹(스트레이트 · 팔꿈치) · 왼손 총
	return shape


func _attack_pose(f) -> Dictionary:
	var mv: Dictionary = f.move
	var shape := shape_key(mv)
	var keys: Array = shape_keys.get(shape, shape_keys["slash"])
	var w: Dictionary = keys[0]
	var s: Dictionary = keys[1]
	var fo: Dictionary = keys[2]
	var su := int(mv["startup"])
	var ac := int(mv["active"])
	var rc := int(mv["recovery"])
	var t: int = f.t
	var brake := int(mv["brake"])
	var from := w if brake <= 0 else _lerp_pose(w, s, BRAKE_AT)
	if t <= su and brake > 0:
		return _brake_pose(t, brake, w, s, from)
	if t <= su:
		var u := float(t) / maxf(1.0, su)
		if shape == "sidekick":
			return _sidekick_windup(f, u, w)
		var p := _lerp_pose(guard_pose, w, 1.0 - (1.0 - u) * (1.0 - u))   # 준비 자세가 일찍 보이게(처음이 빠르다)
		for fr in mv["feints"]:
			if t >= int(fr) and t < int(fr) + 4:
				p = _lerp_pose(w, s, 0.7)       # 멈칫: 치는 척만 하고 몸은 다시 준비로
		return p
	if t <= su + ac and (str(mv["fx"]) == "triple" or not (mv.get("seq", []) as Array).is_empty()):
		return _triple_pose(mv, t - su)
	if t <= su + ac:
		var u2 := float(t - su) / maxf(1.0, ac)
		var p2 := _lerp_pose(from, s, minf(1.0, _ease_out(u2) * 1.5))
		if shape == "spin":
			p2["spin"] = 1080.0 * u2
		return p2
	var rt := t - su - ac
	if f.whiff_t > 0:
		if rt <= f.whiff_t:
			# 헛침: 뻗은 채로 앞으로 쏠려 멈춰 있다 (역공을 받는 틈)
			var wp := _lerp_pose(s, fo, 0.2)
			wp["chest"] = wp["chest"] + Vector3(5.0 + 3.0 * sin(time * 8.0), 0, 0)
			wp["head"] = wp["head"] + Vector3(6.0, 0, 0)
			return wp
		rt -= f.whiff_t
	var hold := maxi(2, int(rc * 0.45))
	var p3: Dictionary
	if rt <= hold:
		p3 = _lerp_pose(s, fo, _ease_out(float(rt) / hold))
	else:
		p3 = _lerp_pose(fo, guard_pose, _ease_in_out(float(rt - hold) / maxf(1.0, rc - hold)))
	if shape == "spin":
		p3["spin"] = 1080.0
	return p3


## 엇엇박 준비: 엇박처럼 감았다가(앞 70%) 뻗기 시작한 순간(brake) 브레이크 — 반쯤 뻗은 채 온몸에 힘이 걸려 떨며
## 반 박자 버틴다. 판정이 시작되면 그 자리에서 쭉 찌른다
func _brake_pose(t: int, brake: int, w: Dictionary, s: Dictionary, held: Dictionary) -> Dictionary:
	var coil := maxf(1.0, brake * 0.7)
	if t < coil:
		return _lerp_pose(guard_pose, w, _ease_out(float(t) / coil))
	if t < brake:
		return _lerp_pose(w, held, (t - coil) / maxf(1.0, brake - coil))
	var q := sin(time * 70.0)
	var p := held.duplicate()
	p["chest"] = p["chest"] + Vector3(3.0 * q, 0, 2.5 * q)
	p["head"] = p["head"] + Vector3(2.0 * q, 0, 0)
	p["sh_r"] = p["sh_r"] + Vector3(4.0 * q, 0, 0)
	p["sh_l"] = p["sh_l"] + Vector3(-4.0 * q, 0, 0)
	p["kn_r"] = float(p["kn_r"]) + 5.0 * q
	p["kn_l"] = float(p["kn_l"]) - 4.0 * q
	return p


## 리천식 삼연타 판정 동안: 한 대마다 오른손 · 왼손 · 오른손을 번갈아 내지르고(앞 1/3) 반쯤 거둔다. 셋째 대는 더 깊이
func _triple_pose(mv: Dictionary, ta: int) -> Dictionary:
	var hits := int(mv["hits"])
	var seg := maxi(1, int(mv["active"]) / hits)
	var k := mini(hits - 1, (ta - 1) / seg)
	var u := float((ta - 1) % seg + 1) / seg
	var keys: Array = shape_keys["punch_L"] if k % 2 == 1 else shape_keys["punch"]
	var seq: Array = mv.get("seq", [])
	if not seq.is_empty():                             # 대마다 모양(묶음 B — 서진태 오리지널 베기 · 되베기 · 찌르기 등)
		var nm := str(seq[mini(k, seq.size() - 1)])
		if nm == "slash_back_L" and weapon_l == null:
			nm = "slash_back_R"
		keys = shape_keys.get(nm, keys)
	var e := minf(1.0, u * 3.0) if u < 0.34 else 1.0 - 0.6 * (u - 0.34) / 0.66
	var p := _lerp_pose(keys[0], keys[1], e)
	if k == hits - 1:
		p["root_fwd"] = float(p["root_fwd"]) + 0.2 * e
		p["chest"] = p["chest"] + Vector3(12, 0, 0) * e
	return p


## 백도찬식 옆차기 준비: 빠르게 발을 구르며 달려나가다(앞 65%) 몸을 돌려 무릎을 접는다
func _sidekick_windup(f, u: float, w: Dictionary) -> Dictionary:
	var stomp := 0.65
	var turn := _merge(guard_pose, {"spin": 50.0, "head": Vector3(-6, -60, 0), "pelvis": Vector3(12, 10, 0)})
	if u < stomp:
		var q := u / stomp
		var p := _lerp_pose(guard_pose, turn, q)
		var s := sin(f.t * 0.95)
		var c := cos(f.t * 0.95)
		p["th_r"] = Vector3(30 * s + 12, 0, 6)
		p["th_l"] = Vector3(-30 * s + 12, 0, 8)
		p["kn_r"] = 30.0 + 44.0 * maxf(0.0, c)
		p["kn_l"] = 30.0 + 44.0 * maxf(0.0, -c)
		return p
	return _lerp_pose(turn, w, _ease_out((u - stomp) / (1.0 - stomp)))


func _down_pose(f, gets_up: bool) -> Dictionary:
	var lying := _merge(guard_pose, P.LYING)
	var t: int = f.t
	if t < 14:
		var p := _lerp_pose(_merge(guard_pose, P.HURT), lying, t / 14.0)
		p["fall"] = 88.0 * _ease_in_out(t / 14.0)
		return p
	if gets_up and t > Fighter.DOWN_T - 22:
		var u := (t - (Fighter.DOWN_T - 22)) / 22.0
		var kneel := _merge(guard_pose, {"kn_r": 70.0, "kn_l": 80.0, "th_r": Vector3(60, 0, 8), "fall": 0.0})
		return _lerp_pose(lying, kneel if u < 0.7 else guard_pose, _ease_in_out(u))
	return lying


## 좌우 뒤집기: 팔다리 r · l 을 맞바꾸고(팔다리 각도는 _limb 가 쪽마다 뒤집는다) 몸통 · 머리의 좌우 돌림(y · z)을 뒤집는다
func _mirror(p: Dictionary) -> Dictionary:
	var q := {}
	for k in p:
		var v = p[k]
		var nk: String = k
		if k.ends_with("_r"):
			nk = k.substr(0, k.length() - 2) + "_l"
		elif k.ends_with("_l"):
			nk = k.substr(0, k.length() - 2) + "_r"
		elif v is Vector3:
			v = Vector3(v.x, -v.y, -v.z)
		q[nk] = v
	return q


func _update_flash(f) -> void:
	var on: bool = f.flash > 0 and (f.flash / 2) % 2 == 0
	var col := Color(0.12, 0.1, 0.09) if on else Color(0, 0, 0)
	if f.state == "attack" and int(f.move["brake"]) > 0 and f.t >= int(f.move["brake"]) \
			and f.t <= int(f.move["startup"]):              # 찌르는 순간 풀린다 (run #11: 맞은 뒤 멈춤 내내 붉었다)
		var k := 0.6 + 0.4 * sin(time * 38.0)
		col = Color(0.34 * k, 0.07 * k, 0.03 * k)       # 엇엇박 브레이크: 온몸이 붉게 달아오른다(부하)
	for m in mats:
		m.emission = col


func _update_telegraph(f) -> void:
	if f.state == "stagger" or f.state == "stun":
		tele.visible = true
		tele.text = "빈틈" if f.state == "stagger" else "기절"
		tele.position = Vector3(0, tele_y, 0)
		tele.font_size = 64
		tele.modulate = Color(1.0, 0.82, 0.3, 1.0)
		tele.scale = Vector3.ONE
		return
	var tg: Array = f.telegraph()
	if tg.is_empty():
		tele.visible = false
		return
	var kind: String = tg[0]
	var left: int = tg[1]
	var big := left <= 6
	tele.visible = true
	tele.text = "!"
	tele.font_size = 96
	tele.position = Vector3(0, tele_y, 0)
	var col := Color(1, 1, 1) if kind == "parry" else Color(1.0, 0.22, 0.18)
	col.a = 0.5 if big and left % 2 == 1 else 1.0
	tele.modulate = col
	tele.scale = Vector3.ONE * (1.6 if big else 0.95)
