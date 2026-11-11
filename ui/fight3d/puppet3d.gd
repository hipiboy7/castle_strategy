extends "res://ui/fight3d/puppet_pose.gd"
## [옮김] castle_M3D `src/view/puppet3d.gd`(2c3e69b) — 바꾼 것: 경로. 설계: docs/C4_설계서_직접조작전투.md 6절 · 요구: FR-403
## 관절 인형의 모습 만들기 — setup(외형 표 src/view/looks.gd) → 뼈 노드 · 몸 · 얼굴 · 머리 · 모자 · 안경 · 무기. 뼈 길이 · 자세 · 움직임은
## 바탕 src/view/puppet_pose.gd(2026-11-09 나눔).

func setup(lk: Dictionary) -> void:
	look = lk
	var gd: Dictionary = {"kim": P.GUARD_KIM, "baek": P.GUARD_BAEK, "box": P.GUARD_BOX, "long": P.GUARD_LONG}.get(
		str(lk.get("guard", "kim")), P.GUARD_KIM)
	guard_pose = _merge(P.NEUTRAL, gd)
	for sh in P.SHAPES:
		var keys: Dictionary = P.SHAPES[sh]
		var w := _merge(guard_pose, keys["W"])
		var s := _merge(w, keys["S"])
		if sh.begins_with("slash"):
			s = _merge(_merge(w, P.LUNGE_LEGS), keys["S"])
		var f := _merge(s, keys["F"])
		shape_keys[sh] = [w, s, f]
		if sh == "punch" or sh == "shot":
			# 왼손 주먹: 오른손 주먹을 좌우로 뒤집는다 (삼연타 둘째 대)
			var wl := _merge(guard_pose, _mirror(keys["W"]))
			var sl := _merge(wl, _mirror(keys["S"]))
			shape_keys[sh + "_L"] = [wl, sl, _merge(sl, _mirror(keys["F"]))]
	cur = guard_pose.duplicate()
	_build()
	_apply(cur)


# ----------------------------------------------------------------------
# 몸 만들기
func _build() -> void:
	var lk := look
	var big: bool = lk.get("big", false)
	var outfit := str(lk.get("outfit", "suit"))
	var shirt_only: bool = outfit == "shirt"                    # 정장 없이 셔츠(소매 걷음) — 백도찬 부두 · 김대건 · 윤덕수
	var robe: bool = outfit == "robe"                           # 가운(군터) — 앞섶이 깊게 열리고 모피 깃
	var long_coat: bool = outfit == "coat" or robe              # 무릎까지 오는 옷자락(김성준 가죽 롱코트 · 군터 가운)
	var vest: bool = outfit == "vest"                           # 조끼(김재훈) · 긴소매 블라우스(오지인) — 몸통은 suit, 팔은 셔츠 소매
	var skirt: bool = lk.get("skirt", false)                    # 무릎 펜슬 스커트(오지인) — 정강이는 맨살
	var masked: bool = lk.get("mask") != null                   # 눈만 뚫린 복면(DS 습격조)
	var suit := _mat(lk["suit"], 0.4 if lk.get("leather", false) else 0.74, 0.45)
	var pants := _mat(lk["pants"], 0.78, 0.4)
	var shirt := _mat(lk["shirt"], 0.85, 0.2)
	var skin := _mat(lk["skin"], 0.62, 0.25)
	var hair := _mat(Looks.hair_lift(lk["hair"]), 0.42, 0.35)   # 아주 짙은 머리는 밝기 아래 한계(검은 덩어리 방지)
	var shoe := _mat(lk.get("shoe", Color(0.05, 0.05, 0.06)), 0.35, 0.3)
	var eye := _mat(lk.get("eye_col", Color(0.07, 0.05, 0.05)), 0.5, 0.0)
	var dark := _mat(Color(0.04, 0.04, 0.05), 0.4, 0.1)
	var top := shirt if shirt_only else suit                    # 몸통 겉감
	var arm := shirt if shirt_only or vest else suit            # 위팔 · 아래팔 겉감
	var wide: float = lk.get("wide", 1.08 if big else 1.0)      # 몸 너비(거구 · 어깨 넓음)
	var sh_wide: float = lk.get("shoulder", wide)               # 어깨 너비만 따로(김신 — 어깨 넓은 근육질)
	var depth: float = lk.get("depth", 1.0)                     # 몸통 두께(앞뒤) — 거구 · 근육질
	var limb: float = lk.get("limb", 1.0)                       # 팔다리 굵기 — 막대처럼 보이지 않게(rc.2 폰 리뷰 6)
	var head_k: float = lk.get("head", 1.0) * Looks.HEAD_K     # 머리 크기(HEAD_K — 사용자 2026-11-06 '머리가 너무 큼')
	var body_k: float = lk.get("scale", 1.06 if big else 1.0)

	J["fall"] = _node(self, Vector3.ZERO)
	J["roll"] = _node(J["fall"], Vector3(0, ROLL_PIVOT, 0))
	J["body"] = _node(J["roll"], Vector3(0, -ROLL_PIVOT, 0))
	J["body"].scale = Vector3.ONE * body_k
	J["hips"] = _node(J["body"], Vector3(0, PELVIS_H, 0))
	# 몸통 겉모양은 관절 노드 밑의 '껍데기' 노드에 붙여 앞뒤 두께(depth)만 늘린다 — 관절 노드를 늘이면 팔다리가 찌그러진다
	var hs := _shell(J["hips"], depth)
	_mesh(hs, _capsule(0.125, 0.36), pants, Vector3(0, -0.03, 0), Vector3(0, 0, 90), Vector3(1, wide, 0.8))
	# 검은 벨트 + 버클 (김신 은 버클 · 백도찬 검은 벨트)
	_mesh(hs, _cyl(0.142, 0.142, 0.036), dark, Vector3(0, 0.055, 0), Vector3.ZERO, Vector3(1.02 * wide, 1, 0.76))
	if lk.get("buckle") != null:
		_mesh(hs, _box(Vector3(0.05, 0.034, 0.012)), _mat(lk["buckle"], 0.22, 0.1, 0.9), Vector3(0, 0.055, -0.11))
	if long_coat:                                                # 옷자락 뒤판(골반) — 앞 두 자락은 허벅지에 붙인다(다리를 따라)
		_mesh(hs, _box(Vector3(0.3 * wide, 0.52, 0.03)), top,Vector3(0, -0.25, 0.1), Vector3(-7, 0, 0))
	if skirt:                                                    # 스커트: 골반에서 무릎까지(허벅지는 스커트 색 그대로)
		_mesh(hs, _cyl(0.15 * wide, 0.19 * wide, 0.52), pants, Vector3(0, -0.25, 0), Vector3.ZERO, Vector3(1, 1, 0.8))
	if robe:                                                     # 가운 허리끈
		_mesh(hs, _cyl(0.146, 0.146, 0.04), _mat(lk["suit"].darkened(0.25), 0.8, 0.1), Vector3(0, 0.06, 0), Vector3.ZERO,
			Vector3(1.04 * wide, 1, 0.78))
	J["spine"] = _node(J["hips"], Vector3(0, 0.02, 0))
	_mesh(_shell(J["spine"], depth), _capsule(0.13, 0.32), top, Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(1.12 * wide, 1, 0.74))
	J["chest"] = _node(J["spine"], Vector3(0, CHEST_UP, 0))
	var cs := _shell(J["chest"], depth)
	_mesh(cs, _cyl(0.2 * sh_wide, 0.15 * wide, 0.34), top, Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1, 1, 0.6))
	_mesh(cs, _capsule(0.082, 0.48 * sh_wide), top, Vector3(0, 0.15, 0), Vector3(0, 0, 90), Vector3(1, 1, 0.78))
	# 앞은 -Z
	if shirt_only:
		# 셔츠: 단추 줄 · 열린 깃(목 V) · 깃 — 둥근 목 티(crew)는 단추 · V 없이
		if str(lk.get("collar", "")) != "crew":
			_mesh(cs, _box(Vector3(0.008, 0.24, 0.01)), _mat(lk["shirt"].darkened(0.18), 0.8, 0.0), Vector3(0, 0.06, -0.122))
			_mesh(cs, _box(Vector3(0.05, 0.06, 0.012)), skin, Vector3(0, 0.18, -0.112))
		_mesh(cs, _cyl(0.064, 0.07, 0.045), shirt, Vector3(0, 0.205, -0.004))
		if lk.get("tie") != null:                                # 풀어 늘어뜨린 넥타이(윤덕수 — 재킷을 벗고 넥타이를 풂)
			_mesh(cs, _box(Vector3(0.034, 0.2, 0.014)), _mat(lk["tie"], 0.5, 0.2), Vector3(0.014, 0.04, -0.128), Vector3(0, 0, -7))
	elif robe:
		# 가운: 깊게 파인 앞섶(맨가슴 · 가슴털) + 검은 모피 깃(V 를 따라 내려온다)
		_mesh(cs, _box(Vector3(0.13, 0.25, 0.012)), skin, Vector3(0, 0.1, -0.118))
		if lk.get("chest_hair") != null:
			_mesh(cs, _box(Vector3(0.07, 0.1, 0.013)), _mat(lk["chest_hair"], 0.9, 0.0), Vector3(0, 0.12, -0.121))
		var fur := _mat(lk.get("fur", Color(0.06, 0.05, 0.05)), 0.95, 0.3)
		for sx in [-1.0, 1.0]:
			_mesh(cs, _capsule(0.034, 0.3), fur, Vector3(0.07 * sx, 0.1, -0.118), Vector3(0, 0, 14 * sx))
		_mesh(cs, _capsule(0.04, 0.3 * wide), fur, Vector3(0, 0.2, 0.04), Vector3(0, 0, 90))
	else:
		var collar := str(lk.get("collar", "tie"))
		if collar == "turtle":
			# 터틀넥(김신 1부 · 습격조 검은 윗옷): V 자리 + 목을 덮는 높은 깃
			_mesh(cs, _box(Vector3(0.1, 0.2, 0.012)), shirt, Vector3(0, 0.12, -0.118))
			_mesh(cs, _cyl(0.052 * wide, 0.06 * wide, 0.11), shirt, Vector3(0, 0.235, 0.0))
		elif collar == "open":
			# 깃 푼 셔츠(넥타이 없음): V 안에 맨가슴이 보인다. v_k: 앞섶을 더 풀어헤친 만큼(김성준 — 가슴까지)
			var vk: float = lk.get("v_k", 1.0)
			_mesh(cs, _box(Vector3(0.1 * vk, 0.2, 0.012)), shirt, Vector3(0, 0.12, -0.118))
			_mesh(cs, _box(Vector3(0.046 * vk, 0.1 * vk, 0.013)), skin, Vector3(0, 0.215 - 0.05 * vk, -0.121))
			_mesh(cs, _cyl(0.062, 0.066, 0.04), shirt, Vector3(0, 0.205, -0.004))
		else:
			# 정장: 셔츠 V · 넥타이 · 깃
			_mesh(cs, _box(Vector3(0.1, 0.2, 0.012)), shirt, Vector3(0, 0.12, -0.118))
			_mesh(cs, _cyl(0.062, 0.066, 0.04), shirt, Vector3(0, 0.205, -0.004))
		if lk.get("tie") != null:
			_mesh(cs, _box(Vector3(0.036, 0.24, 0.014)), _mat(lk["tie"], 0.5, 0.2), Vector3(0, 0.085, -0.127))
		if lk.get("coat_collar") != null:                        # 겉옷 깃 색(outfit.outer.collar — 마준영 베이지 깃): V 를 따라 넓은 깃 + 목 뒤
			var ccm := _mat(lk["coat_collar"], 0.9, 0.0)
			for sx in [-1.0, 1.0]:
				_mesh(cs, _capsule(0.026, 0.26), ccm, Vector3(0.068 * sx, 0.11, -0.118), Vector3(0, 0, 14 * sx))
			_mesh(cs, _capsule(0.032, 0.28 * wide), ccm, Vector3(0, 0.2, 0.04), Vector3(0, 0, 90))
	if lk.get("badge") != null:                                  # 옷깃 금 배지 (왼쪽 가슴)
		_mesh(cs, _cyl(0.014, 0.014, 0.008), _mat(lk["badge"], 0.2, 0.2, 0.9), Vector3(-0.085, 0.16, -0.122), Vector3(90, 0, 0))
	if lk.get("holster") != null:
		_holster(cs, _mat(lk["holster"], 0.7, 0.15), dark, wide)
	J["neck"] = _node(J["chest"], Vector3(0, NECK_UP, 0))
	_mesh(J["neck"], _cyl(0.047 * wide, 0.05 * wide, 0.12), skin, Vector3(0, 0.03, 0))
	J["head"] = _node(J["neck"], Vector3(0, HEAD_UP, 0))
	J["head"].scale = Vector3.ONE * head_k
	_mesh(J["head"], _sphere(0.105, 0.232), skin, Vector3(0, 0, 0), Vector3.ZERO, Vector3(0.94, 0.95, 0.98) if lk.get("female", false) else Vector3.ONE)   # 여성은 갸름하게
	if masked:
		_mask(J["head"], _mat(lk["mask"], 0.85, 0.3), skin, eye)
	else:
		_face(lk, skin, eye, dark, hair)
	var gl = lk.get("glasses", false)
	if gl is String:
		glasses = _shades(J["head"], str(gl), lk.get("lens", Color(0.05, 0.05, 0.06)))
	elif gl:
		glasses = _glasses(J["head"], lk.get("frame", Color(0.75, 0.77, 0.8)))
	if lk.get("chain") != null:                                  # 금 체인 목걸이 (구일화)
		_mesh(cs, _cyl(0.07, 0.075, 0.012), _mat(lk["chain"], 0.25, 0.2, 0.9), Vector3(0, 0.19, -0.03), Vector3(18, 0, 0))
	if lk.get("neck_tattoo") != null:                            # 목 옆 문신 (김성준)
		_mesh(J["neck"], _box(Vector3(0.012, 0.07, 0.03)), _mat(lk["neck_tattoo"], 0.8, 0.0), Vector3(0.044 * wide, 0.03, -0.012))
	var tat_side := str(lk.get("tattoo_side", "r"))
	# 팔 · 다리
	for side in ["r", "l"]:
		var sx := 1.0 if side == "r" else -1.0
		var sh := _node(J["chest"], Vector3(sx * SHOULDER_W * sh_wide, SHOULDER_UP, 0))
		J["sh_" + side] = sh
		_mesh(sh, _sphere(0.072 * sh_wide * limb, 0.144 * sh_wide * limb), top, Vector3.ZERO)          # 어깨(삼각근)
		_mesh(sh, _capsule(0.058 * wide * limb, 0.34), arm, Vector3(0, -UPPER_ARM * 0.5, 0))
		_mesh(sh, _sphere(0.064 * wide * limb, 0.17), arm, Vector3(0, -UPPER_ARM * 0.4, -0.01))       # 위팔 근육(이두)
		var el := _node(sh, Vector3(0, -UPPER_ARM, 0))
		J["el_" + side] = el
		if shirt_only:
			# 소매 걷음: 아래팔은 맨살, 팔꿈치 아래에 걷어 올린 소매 뭉치
			_mesh(el, _capsule(0.046 * wide * limb, 0.29), skin, Vector3(0, -FOREARM * 0.5, 0))
			_mesh(el, _sphere(0.054 * wide * limb, 0.15), skin, Vector3(0, -FOREARM * 0.32, 0))          # 아래팔 근육(팔꿈치 쪽 굵게)
			_mesh(el, _cyl(0.06 * wide * limb, 0.058 * wide * limb, 0.06), shirt, Vector3(0, -0.035, 0))
			if lk.get("tattoo") != null and (tat_side == side or tat_side == "both"):
				# 팔뚝 문신(김대건 뱀 · 윤덕수): 비스듬히 감긴 가는 띠 넷 — 뱀이 팔을 감은 듯
				var tm := _mat(lk["tattoo"].lerp(lk["skin"], 0.25), 0.8, 0.0)
				for k in 4:
					_mesh(el, _cyl(0.049 * wide * limb, 0.049 * wide * limb, 0.012), tm, Vector3(0, -0.08 - 0.036 * k, 0),
						Vector3(0, 40 * k, 24))
		else:
			_mesh(el, _capsule(0.048 * wide * limb, 0.29), arm, Vector3(0, -FOREARM * 0.5, 0))
			_mesh(el, _sphere(0.054 * wide * limb, 0.15), arm, Vector3(0, -FOREARM * 0.32, 0))
			_mesh(el, _cyl(0.05, 0.05, 0.028), shirt, Vector3(0, -FOREARM + 0.028, 0))            # 소맷부리
		var hand := _node(el, Vector3(0, -FOREARM, 0))
		J["hand_" + side] = hand
		_mesh(hand, _sphere(0.046 * sqrt(limb), 0.1 * sqrt(limb)), skin, Vector3(0, -0.044, -0.004), Vector3.ZERO, Vector3(0.82, 1, 1))
		var wrist = lk.get("bracelet_" + side, lk.get("bracelet"))    # 손목 금 팔찌 · 검은 밴드 · 시계
		if wrist != null:
			_mesh(el, _cyl(0.044 * wide * limb, 0.044 * wide * limb, 0.022), _mat(wrist, 0.3, 0.2, 0.8), Vector3(0, -FOREARM + 0.04, 0))
		if lk.get("rings") != null:                              # 손가락 금반지 여러 개 (군터)
			_mesh(hand, _box(Vector3(0.07, 0.012, 0.06) * sqrt(limb)), _mat(lk["rings"], 0.25, 0.2, 0.9), Vector3(0, -0.07, -0.006))
		var th := _node(J["hips"], Vector3(sx * HIP_W * wide, -0.03, 0))
		J["th_" + side] = th
		_mesh(th, _capsule(0.083 * wide * limb, 0.5), pants, Vector3(0, -THIGH * 0.5, 0))
		_mesh(th, _sphere(0.092 * wide * limb, 0.26), pants, Vector3(0, -THIGH * 0.3, 0))             # 허벅지 위쪽 굵게
		if long_coat:                                            # 옷자락 앞 두 자락 — 허벅지를 덮고 다리를 따라 흔들린다
			_mesh(th, _capsule(0.1 * wide * limb, 0.5), top, Vector3(0.012 * sx, -0.21, 0.004), Vector3.ZERO, Vector3(1.08, 1, 1.0))
		if lk.get("stripe") != null:                             # 트랙 바지 옆줄 (서진태)
			_mesh(th, _box(Vector3(0.014, 0.44, 0.03)), _mat(lk["stripe"], 0.7, 0.0), Vector3(sx * 0.083 * wide * limb, -THIGH * 0.5, 0))
		var kn := _node(th, Vector3(0, -THIGH, 0))
		J["kn_" + side] = kn
		var shin_m := skin if skirt else pants
		_mesh(kn, _capsule(0.062 * wide * limb, 0.48), shin_m, Vector3(0, -SHIN * 0.5, 0))
		_mesh(kn, _sphere(0.068 * wide * limb, 0.2), shin_m, Vector3(0, -SHIN * 0.28, 0.012))          # 종아리
		if lk.get("stripe") != null:
			_mesh(kn, _box(Vector3(0.014, 0.44, 0.03)), _mat(lk["stripe"], 0.7, 0.0), Vector3(sx * 0.062 * wide * limb, -SHIN * 0.5, 0))
		var ft := _node(kn, Vector3(0, -SHIN, 0))
		J["ft_" + side] = ft
		_mesh(ft, _capsule(0.045, 0.26), shoe, Vector3(0, -0.012, -0.055), Vector3(90, 0, 0), Vector3(1.05, 1, 0.9))
		if lk.get("sole") != null:                               # 운동화 밑창 (김신 1부 흰 밑창 · 서진태)
			_mesh(ft, _box(Vector3(0.096, 0.018, 0.27)), _mat(lk["sole"], 0.7, 0.0), Vector3(0, -0.05, -0.055))
	weapon_r = _attach(J["hand_r"], str(lk.get("weapon_r", "")), GRIP_FWD)
	weapon_l = _attach(J["hand_l"], str(lk.get("weapon_l", "")), GRIP_FWD if lk.get("grip_l", "rev") == "fwd" else GRIP_REV)
	# 예고 표시 (흰 ! 쳐내기 · 빨간 ! 가드 불가 · 빈틈)
	tele = Label3D.new()
	tele.font = FONT
	tele.font_size = 96
	tele.outline_size = 22
	tele.outline_modulate = Color(0, 0, 0, 0.9)
	tele.pixel_size = 0.0045
	tele.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tele.no_depth_test = true
	tele.position = Vector3(0, 2.22, 0)
	tele.visible = false
	tele_y = 2.22 + (body_k - 1.0) * 1.9                         # 큰 몸은 머리가 높다 — 예고 · 빈틈 글자를 그만큼 위로
	add_child(tele)


## 얼굴(코 · 턱 · 눈썹 · 입 · 귀 · 눈 · 흉터 · 머리 · 수염) — 복면이면 _mask 가 대신한다
func _face(lk: Dictionary, skin: Material, eye: Material, dark: Material, hair: Material) -> void:
	if lk.get("female", false):                                  # 여성 — 눈 · 눈썹 · 코 · 입 · 귀걸이를 따로(_face_fem)
		_face_fem(lk, skin, eye)
	else:
		_face_male(lk, skin, eye, dark)
	_face_rest(lk, hair)


## 남성 얼굴(2026-11-08 사용자 "남성 얼굴도 진행해" — 그림 A make_models _face_male 과 같은 구성): 상자 눈 · 상자 턱 대신 얼굴 곡면에
## 붙인 납작한 조각 — 가늘고 날카로운 눈(흰자 · 짙은 눈동자 · 굵은 윗눈꺼풀 선이 바깥으로 길게) · 눈 가까이 낮고 굵은 눈썹(brow_tilt 만큼
## 바깥 끝이 올라간다 — 김신, brow_k 굵기 — 윤덕수) · 작은 코 + 콧등 그늘 · 일자 입 + 아랫입술 그늘 · 턱(jaw 면 넓고 각지게).
## 눈 높이 eye_h: ≤ 0.006 실눈 · ≤ 0.008 날카로운 눈 · 나머지 보통. 먼 눈(blind_eye) · 흰자 눈(blank_eyes — 샤모)
func _face_male(lk: Dictionary, skin: Material, eye: Material, dark: Material) -> void:
	var h: Node3D = J["head"]
	var sk: Color = lk["skin"]
	if lk.get("jaw", false):                                     # 각진 턱: 넓고 납작한 턱 덩어리(상자 모서리 대신 둥근 네모)
		_mesh(h, _sphere(0.08, 0.12), skin, Vector3(0, -0.058, -0.03), Vector3(-8, 0, 0), Vector3(1.12, 0.85, 0.78))
	else:
		_mesh(h, _sphere(0.075, 0.12), skin, Vector3(0, -0.055, -0.03), Vector3(-10, 0, 0), Vector3(1.0, 0.9, 0.83))
	if lk.get("stubble", false):                                 # 턱 수염 그늘 — looks.json facial_hair 에 stubble 이 있을 때만(김신은 없음), 옅게
		_mesh(h, _sphere(0.5, 1.0), _mat(sk.lerp(lk["hair"], 0.22).darkened(0.08), 0.8, 0.0), Vector3(0, -0.074, -0.048),
			Vector3(-25, 0, 0), Vector3(0.112, 0.05, 0.088))
	# 코는 덩어리 없이 선으로(작은 공은 테두리 빛 rim 이 고리를 그려 '0' 처럼 보였다)
	_mesh(h, _capsule(0.0011, 0.02), _mat(sk.darkened(0.18), 0.8, 0.0), Vector3(-0.0095, -0.009, -0.1035), Vector3(0, -6, -8))   # 콧등 그늘
	_mesh(h, _box(Vector3(0.016, 0.0028, 0.004)), _mat(sk.darkened(0.38), 0.8, 0.0), Vector3(0, -0.027, -0.104))   # 코끝 아래 선
	var eh_k := float(lk.get("eye_h", 0.011))
	var eh: float = 0.008 if eh_k <= 0.006 else (0.012 if eh_k <= 0.008 else 0.015)   # 눈 높이(실눈 · 날카로운 눈 · 보통)
	var white := _mat(Color(0.95, 0.94, 0.92), 0.6, 0.0)
	var lash := _mat(Color(0.05, 0.035, 0.035), 0.5, 0.0)
	var brow := _mat(Looks.hair_lift(lk["hair"]).darkened(0.3), 0.7, 0.0)
	var shine := _mat(Color(0.95, 0.95, 0.95), 0.3, 0.0)
	var brow_tilt: float = lk.get("brow_tilt", 6.0)
	var brow_k: float = lk.get("brow_k", 1.0)
	var blind := str(lk.get("blind_eye", ""))                   # 먼 눈(인물 자기 쪽 l · r — 흰자에 흐린 눈동자)
	var blind_m := _mat(Color(0.72, 0.73, 0.74), 0.5, 0.0)
	for sx in [-1.0, 1.0]:
		var yw: float = -20.0 * sx                                     # 얼굴 곡면을 따라 바깥으로 돌린다
		var ec: Vector3 = Vector3(0.037 * sx, 0.003, -0.0985)
		_mesh(h, _sphere(0.5, 1.0), white, ec, Vector3(0, yw, 3 * sx), Vector3(0.036, eh, 0.007))                          # 흰자
		if not lk.get("blank_eyes", false):                       # 흰자 눈(샤모)은 눈동자 없음
			var dead := blind == ("l" if sx < 0.0 else "r")
			_mesh(h, _sphere(0.5, 1.0), blind_m if dead else eye, ec + Vector3(-0.0015 * sx, 0.0004, -0.0012), Vector3(0, yw, 0),
				Vector3(0.014, eh, 0.007))                                                                             # 눈동자
			if eh > 0.008 and not dead:
				_mesh(h, _sphere(0.5, 1.0), shine, ec + Vector3(0.001 * sx, eh * 0.18, -0.0034), Vector3(0, yw, 0), Vector3(0.003, 0.003, 0.003))   # 눈빛
		_mesh(h, _capsule(0.0032, 0.036), lash, ec + Vector3(0.0005 * sx, eh * 0.45, -0.0016), Vector3(0, yw, 90 + 4 * sx))   # 굵은 윗눈꺼풀 선
		_mesh(h, _capsule(0.0022, 0.012), lash, ec + Vector3(0.0195 * sx, eh * 0.28, -0.0004), Vector3(0, yw, 90 - 10 * sx))  # 바깥으로 뺀 눈꼬리
		_mesh(h, _capsule(0.001, 0.018), _mat(sk.darkened(0.3), 0.8, 0.0), ec + Vector3(0.003 * sx, -eh * 0.5, -0.001),
			Vector3(0, yw, 90 - 3 * sx))                                                                                  # 아랫눈꺼풀(옅게)
		# 눈썹: 눈 가까이 낮고 굵은 일자 — 안쪽 끝이 굵고 brow_tilt 만큼 바깥이 올라간다
		var bt: float = brow_tilt * 0.7 * sx
		var bc: Vector3 = Vector3(0.039 * sx, 0.022, -0.0975)
		_mesh(h, _capsule(0.0038 * brow_k, 0.04), brow, bc, Vector3(0, yw, 90 + bt))
		_mesh(h, _capsule(0.0048 * brow_k, 0.016), brow, bc + Vector3(-0.012 * sx, -0.0012 * signf(brow_tilt), 0.001), Vector3(0, yw, 90 + bt))
		_mesh(h, _sphere(0.022, 0.044), skin, Vector3(0.103 * sx, -0.004, 0.006))     # 귀
		if lk.get("piercing", false):                            # 귀 검은 스터드
			_mesh(h, _sphere(0.007, 0.014), dark, Vector3(0.112 * sx, -0.024, 0.0))
	# 입: 일자 선(입술 색 lips 가 있으면 그 색) · 아랫입술 그늘
	var lips = lk.get("lips")
	_mesh(h, _capsule(0.0022 if lips == null else 0.0035, 0.032), _mat(sk.darkened(0.5) if lips == null else (lips as Color).darkened(0.25), 0.7, 0.0),
		Vector3(0, -0.047, -0.0975), Vector3(-8, 0, 90))
	_mesh(h, _capsule(0.0014, 0.01), _mat(sk.darkened(0.1), 0.8, 0.0), Vector3(0, -0.056, -0.0952), Vector3(-12, 0, 90))


## 여성 얼굴(2026-11-07 폰 "오지인이 대표 미인 캐릭터인데 너무 못생김" — 원작 카드 초상 하성_오지인 · 차수민): 가는 아몬드 눈
## (흰자 + 짙은 눈동자 + 굵은 윗눈꺼풀 선이 바깥 끝에서 올라가는 눈꼬리) · 가늘고 긴 아치 눈썹 · 작은 코 · 도톰한 입술 ·
## 갸름한 턱(V 라인) · 옅은 볼 · 귀걸이(금 고리). 눈 높이 eye_h ≤ 0.008 은 날카로운 눈(오지인)
func _face_fem(lk: Dictionary, skin: Material, eye: Material) -> void:
	var h: Node3D = J["head"]
	var sk: Color = lk["skin"]
	_mesh(h, _sphere(0.07, 0.11), skin, Vector3(0, -0.052, -0.03), Vector3(-12, 0, 0), Vector3(1.0, 1.0, 0.95))   # 갸름한 턱 끝
	_mesh(h, _sphere(0.008, 0.02), skin, Vector3(0, -0.017, -0.105), Vector3(-14, 0, 0), Vector3(0.85, 1.0, 0.9))   # 작은 코
	_mesh(h, _box(Vector3(0.012, 0.003, 0.004)), _mat(sk.darkened(0.25), 0.8, 0.0), Vector3(0, -0.028, -0.1))     # 콧망울 그늘
	var sharp: bool = float(lk.get("eye_h", 0.011)) <= 0.008
	var white := _mat(Color(0.96, 0.95, 0.93), 0.6, 0.0)
	var lash := _mat(Color(0.05, 0.035, 0.04), 0.5, 0.0)
	var brow := _mat(Looks.hair_lift(lk["hair"]).darkened(0.15), 0.7, 0.0)
	var shine := _mat(Color(1, 1, 1), 0.3, 0.0)
	var blush := _mat(sk.lerp(Color(0.95, 0.52, 0.52), 0.22), 0.8, 0.0)
	var eh := 0.013 if sharp else 0.016
	for sx in [-1.0, 1.0]:
		var yw: float = -20.0 * sx                                     # 얼굴 곡면을 따라 바깥으로 돌린다
		var ec: Vector3 = Vector3(0.036 * sx, 0.004, -0.0985)
		_mesh(h, _sphere(0.5, 1.0), white, ec, Vector3(0, yw, 4 * sx), Vector3(0.032, eh, 0.007))                         # 흰자
		_mesh(h, _sphere(0.5, 1.0), eye, ec + Vector3(-0.0015 * sx, -0.0008, -0.0012), Vector3(0, yw, 0), Vector3(0.015, eh, 0.007))   # 눈동자
		_mesh(h, _sphere(0.5, 1.0), shine, ec + Vector3(0.0015 * sx, 0.0022, -0.0034), Vector3(0, yw, 0), Vector3(0.0034, 0.0034, 0.003))   # 눈빛
		_mesh(h, _capsule(0.003, 0.038), lash, ec + Vector3(0.0015 * sx, eh * 0.47, -0.0016), Vector3(0, yw, 90 + 8 * sx))   # 윗눈꺼풀 선
		_mesh(h, _capsule(0.0024, 0.014), lash, ec + Vector3(0.021 * sx, eh * 0.62, -0.0004), Vector3(0, yw, 90 + 30 * sx))  # 눈꼬리
		_mesh(h, _capsule(0.001, 0.016), _mat(sk.darkened(0.3), 0.8, 0.0), ec + Vector3(0.003 * sx, -eh * 0.5, -0.001),
			Vector3(0, yw, 90 - 4 * sx))                                                                                  # 아랫눈꺼풀(옅게)
		# 눈썹: 안쪽은 살짝 오르고 바깥 끝이 내려오는 가는 아치
		var bc: Vector3 = Vector3(0.038 * sx, 0.031 if sharp else 0.033, -0.097)
		_mesh(h, _capsule(0.0022, 0.025), brow, bc + Vector3(-0.005 * sx, 0.0, -0.001), Vector3(0, yw, 90 + 8 * sx))
		_mesh(h, _capsule(0.0017, 0.018), brow, bc + Vector3(0.0135 * sx, -0.0012, 0.002), Vector3(0, yw, 90 - 18 * sx))
		_mesh(h, _sphere(0.5, 1.0), blush, Vector3(0.05 * sx, -0.024, -0.087), Vector3(0, -32 * sx, 0), Vector3(0.026, 0.014, 0.008))   # 옅은 볼
		_mesh(h, _sphere(0.018, 0.04), skin, Vector3(0.102 * sx, -0.004, 0.006), Vector3.ZERO, Vector3(0.8, 1.0, 1.0))   # 귀(작게)
		if lk.get("piercing", false):                            # 금 고리 귀걸이(오지인 · 차수민 — looks.json piercing ring #c8a040)
			var ring := TorusMesh.new()
			ring.inner_radius = 0.009
			ring.outer_radius = 0.0125
			ring.rings = 12
			ring.ring_segments = 6
			_mesh(h, ring, _mat(Color(0.85, 0.66, 0.28), 0.25, 0.2, 0.9), Vector3(0.106 * sx, -0.036, -0.002), Vector3(90, 70 * sx, 0))
	# 입술: 윗입술(조금 짙게) · 아랫입술(도톰하게) · 가운데 선
	var lips: Color = lk.get("lips", sk.lerp(Color(0.8, 0.38, 0.4), 0.45))
	_mesh(h, _sphere(0.5, 1.0), _mat(lips.darkened(0.12), 0.45, 0.1), Vector3(0, -0.0435, -0.0955), Vector3(-8, 0, 0), Vector3(0.026, 0.0065, 0.009))
	_mesh(h, _sphere(0.5, 1.0), _mat(lips, 0.35, 0.15), Vector3(0, -0.0505, -0.094), Vector3(-14, 0, 0), Vector3(0.022, 0.0085, 0.01))
	_mesh(h, _box(Vector3(0.022, 0.0016, 0.004)), _mat(lips.darkened(0.55), 0.8, 0.0), Vector3(0, -0.0468, -0.0985))


## 얼굴 공통(흉터 · 머리 · 모자 · 수염 · 붕대 · 시가)
func _face_rest(lk: Dictionary, hair: Material) -> void:
	var sc = lk.get("scar", false)
	if sc is String or sc:                                       # 흉터 — 가는 짙은 선(붉게 섞으면 볼터치처럼 번졌다), + 로 여럿
		for kind in (str(sc) if sc is String else "cheek_l").split("+"):
			_scar(J["head"], kind, _mat(Looks.scar_col(lk), 0.7, 0.0))
	_hair(J["head"], hair, str(lk.get("hair_style", "short")))
	if lk.get("hat") != null:
		_hat(J["head"], str(lk["hat"]), _mat(lk.get("hat_col", Color(0.2, 0.2, 0.22)), 0.9, 0.2), lk.get("hat_band"))
	# 수염은 턱 · 윗입술 곡면에 붙인 납작한 조각(상자는 얼굴에서 각지게 튀어나왔다 — 2026-11-08). 색 beard_col(looks.json facial_hair_color)
	var bcol: Color = Looks.hair_lift(lk.get("beard_col", lk["hair"])).darkened(0.1)
	if lk.get("beard", false):                                   # 짧은 턱수염 · 콧수염 (신겐)
		var bm := _mat(bcol, 0.8, 0.0)
		_mesh(J["head"], _sphere(0.5, 1.0), bm, Vector3(0, -0.072, -0.062), Vector3(-30, 0, 0), Vector3(0.088, 0.055, 0.07))
		_mesh(J["head"], _capsule(0.0045, 0.042), bm, Vector3(0, -0.035, -0.1), Vector3(-10, 0, 90))
	if lk.get("mustache", false):                                # 끝이 처진 콧수염 (군터)
		var mm := _mat(bcol, 0.8, 0.0)
		_mesh(J["head"], _capsule(0.005, 0.04), mm, Vector3(0, -0.036, -0.101), Vector3(-10, 0, 90))
		for sx in [-1.0, 1.0]:
			_mesh(J["head"], _capsule(0.0042, 0.024), mm, Vector3(0.021 * sx, -0.047, -0.096), Vector3(-10, -18 * sx, 24 * sx))
	if lk.get("goatee", false):                                  # 염소수염 (김성준)
		var gm := _mat(bcol, 0.8, 0.0)
		_mesh(J["head"], _capsule(0.01, 0.036), gm, Vector3(0, -0.075, -0.088), Vector3(-30, 0, 0), Vector3(1.0, 1.0, 0.6))
	if lk.get("sideburns", false):                               # 구레나룻(귀 앞 ~ 턱 모서리 — 크리사 · 이환 · 마준영)
		var sbm := _mat(bcol, 0.8, 0.0)
		for sx in [-1.0, 1.0]:
			_mesh(J["head"], _capsule(0.007, 0.07), sbm, Vector3(0.094 * sx, -0.035, -0.036), Vector3(-15, 0, 8 * sx), Vector3(1.0, 1.0, 0.7))
	if lk.get("bandage") != null:                                # 머리띠처럼 감은 흰 붕대 (강만재 — 앞 화 부상)
		var bd := TorusMesh.new()
		bd.inner_radius = 0.094
		bd.outer_radius = 0.12
		bd.rings = 16
		bd.ring_segments = 6
		_mesh(J["head"], bd, _mat(lk["bandage"], 0.9, 0.2), Vector3(0, 0.045, 0.004), Vector3(-10, 0, 0), Vector3(1, 1.5, 1.04))
	if lk.get("cigar", false):                                   # 입에 문 시가 (군터)
		_mesh(J["head"], _cyl(0.008, 0.009, 0.07), _mat(Color(0.36, 0.22, 0.12), 0.8, 0.0), Vector3(0.022, -0.05, -0.13),
			Vector3(80, -20, 0))
		_mesh(J["head"], _cyl(0.0085, 0.0085, 0.008), _mat(Color(1.0, 0.35, 0.1), 0.5, 0.0), Vector3(0.034, -0.044, -0.163),
			Vector3(80, -20, 0))



## 흉터 자리: nose — 콧등에서 왼뺨 광대로 내려가는 사선 + 입술 아래 ~ 턱 세로(김대건) · brow — 이마에서 눈썹으로(군터) ·
## double — 왼뺨 사선 두 줄(강만재). 납작한 가는 띠(두께 0.0025 — 막대처럼 솟아 보이지 않게, 2026-11-08)
func _scar(head: Node3D, kind: String, m: Material) -> void:
	if kind == "cheek_l" or kind == "cheek_r":                    # 뺨 사선 한 줄(인물 자기 쪽 — 왼뺨 -x)
		var sx := -1.0 if kind == "cheek_l" else 1.0
		_mesh(head, _box(Vector3(0.0042, 0.046, 0.0025)), m, Vector3(0.06 * sx, -0.03, -0.088), Vector3(0, -30 * sx, 18 * sx))
	elif kind == "chin":                                         # 입술 아래 ~ 턱 세로
		_mesh(head, _box(Vector3(0.0042, 0.03, 0.0025)), m, Vector3(0.012, -0.072, -0.088), Vector3(16, 0, 0))
	elif kind == "nose":
		_mesh(head, _box(Vector3(0.0042, 0.075, 0.0025)), m, Vector3(-0.028, -0.004, -0.1), Vector3(0, -20, 58))
		_mesh(head, _box(Vector3(0.0042, 0.03, 0.0025)), m, Vector3(0.012, -0.072, -0.088), Vector3(16, 0, 0))
	elif kind == "brow":
		_mesh(head, _box(Vector3(0.0042, 0.06, 0.0025)), m, Vector3(0.04, 0.052, -0.094), Vector3(-24, 0, 10))
	elif kind == "x":                                            # 콧등에서 엇갈리는 긴 두 줄(최민욱 — 이마 · 눈썹에서 양뺨까지)
		_mesh(head, _box(Vector3(0.0042, 0.14, 0.0025)), m, Vector3(-0.004, 0.022, -0.1), Vector3(0, 0, -42))
		_mesh(head, _box(Vector3(0.0042, 0.12, 0.0025)), m, Vector3(0.012, 0.0, -0.1), Vector3(0, 0, 45))
	elif kind == "double":
		for k in 2:
			_mesh(head, _box(Vector3(0.0042, 0.042, 0.0025)), m, Vector3(-0.056 - 0.012 * k, -0.024 - 0.012 * k, -0.09 + 0.006 * k),
				Vector3(0, -30, 52))
	elif kind == "eye_l" or kind == "eye_r":                      # 눈썹 위에서 눈을 지나 뺨으로 세로 한 줄(황보민철 — 인물 자기 쪽)
		var ex := -0.037 if kind == "eye_l" else 0.037
		_mesh(head, _box(Vector3(0.0042, 0.085, 0.0025)), m, Vector3(ex, 0.0, -0.1), Vector3(-8, 0, 0))


## 모자: beanie — 챙 없는 니트 비니(인수 · 신태진 · 남구 청년회), bucket — 챙이 아래로 처진 벙거지
func _hat(head: Node3D, kind: String, m: Material, band = null) -> void:
	if kind == "beanie":
		_mesh(head, _sphere(0.116, 0.2), m, Vector3(0, 0.074, 0.014), Vector3(-6, 0, 0), Vector3(1.02, 0.68, 1.04))
		_mesh(head, _cyl(0.114, 0.117, 0.026), m, Vector3(0, 0.062, 0.01), Vector3(-8, 0, 0), Vector3(1.0, 1.0, 1.04))   # 접어 올린 단(눈썹 위 — 앞머리가 보이게)
	elif kind == "bucket":
		_mesh(head, _cyl(0.1, 0.112, 0.09), m, Vector3(0, 0.1, 0.01))
		_mesh(head, _cyl(0.118, 0.16, 0.03), m, Vector3(0, 0.055, 0.01))                                      # 처진 챙
	elif kind == "headband" or kind == "bandana":                # 이마 띠(라텔) — 위아래 밝은 단으로 검은 머리와 갈라 보이게
		_mesh(head, _cyl(0.118, 0.118, 0.04), m, Vector3(0, 0.045, 0.006), Vector3(-10, 0, 0), Vector3(1, 1, 1.04))
		for dy in [-0.021, 0.021]:
			_mesh(head, _cyl(0.12, 0.12, 0.005), _mat(Color(0.62, 0.62, 0.66), 0.8, 0.0), Vector3(0, 0.045 + dy, 0.006), Vector3(-10, 0, 0),
				Vector3(1, 1, 1.04))
	elif kind == "cap" or kind == "helmet":                      # 모자 · 헬멧: 머리통 + (모자는) 앞 챙
		_mesh(head, _sphere(0.118, 0.2), m, Vector3(0, 0.07, 0.012), Vector3(-6, 0, 0), Vector3(1.02, 0.66, 1.04))
		if kind == "cap":
			_mesh(head, _box(Vector3(0.15, 0.01, 0.08)), m, Vector3(0, 0.06, -0.12), Vector3(8, 0, 0))
	elif kind == "fedora":                                       # 중절모: 몸통 + 둘레 챙
		_mesh(head, _cyl(0.09, 0.1, 0.08), m, Vector3(0, 0.13, 0.01))
		_mesh(head, _cyl(0.17, 0.17, 0.012), m, Vector3(0, 0.085, 0.01))
		if band != null:                                          # 띠(headwear.band — 김황 흰 페도라 검은 띠)
			_mesh(head, _cyl(0.094, 0.098, 0.022), _mat(band, 0.8, 0.0), Vector3(0, 0.1, 0.01))
	elif kind == "hood":                                         # 후드: 머리 뒤 · 옆 · 위
		_mesh(head, _sphere(0.13, 0.27), m, Vector3(0, 0.02, 0.04), Vector3.ZERO, Vector3(1.05, 1.0, 0.95))


## 눈만 뚫린 복면(DS 습격조 — p1:008 '검은 복면(눈만 뚫림)'): 머리 전체를 덮고 눈 자리만 살색 띠
func _mask(head: Node3D, m: Material, skin: Material, eye: Material) -> void:
	_mesh(head, _sphere(0.112, 0.246), m, Vector3(0, 0.002, 0), Vector3.ZERO, Vector3(1, 1, 1.04))
	_mesh(head, _box(Vector3(0.1, 0.028, 0.014)), skin, Vector3(0, 0.01, -0.108))
	for sx in [-1.0, 1.0]:
		_mesh(head, _box(Vector3(0.024, 0.011, 0.012)), eye, Vector3(0.033 * sx, 0.01, -0.113))


## 머리 모양: slick_fringe(김신 — 짧게 뒤로 넘긴 올백 + 이마로 떨어진 앞머리 몇 가닥) · slick(백도찬 — 뒤로 넘긴 머리, 2차에
## 가닥이 흘러내린다 — loose_hair()) · parted · short · topknot · wavy_back · spiky · crew, 0 · 1장: fringe(김신 1부) · bald · buzz · long ·
## ponytail · curly · undercut(hair2 — 민 옆머리 색, loose 면 2차에 가닥). 외형 근거는 castle_common canon/characters.json look(conf ai — 연출용)
var loose: Node3D = null


func _hair(head: Node3D, m: Material, style: String) -> void:
	if style == "slick_fringe" or style == "slick":
		if style == "slick_fringe":
			# 김신: 옆은 짧게(관자놀이 · 귀 위 살이 보이게 — 옆까지 덮으면 헬멧 같다, rc.2 폰 리뷰 6), 위는 뒤로 넘기고 뒤통수는 목덜미까지
			_mesh(head, _sphere(0.108, 0.2), m, Vector3(0, 0.066, 0.026), Vector3.ZERO, Vector3(0.93, 0.6, 1.0))
			_mesh(head, _sphere(0.098, 0.15), m, Vector3(0, 0.004, 0.05), Vector3.ZERO, Vector3(0.93, 1.0, 0.85))
			_mesh(head, _sphere(0.09, 0.09), m, Vector3(0, 0.1, -0.03), Vector3(-8, 0, 0), Vector3(0.95, 0.55, 1.0))
		else:
			# 뒤로 넘긴 머리: 정수리 · 뒤통수를 덮고 앞이마 선은 높게, 앞쪽이 살짝 솟는다
			_mesh(head, _sphere(0.109, 0.2), m, Vector3(0, 0.052, 0.03), Vector3.ZERO, Vector3(1.0, 0.66, 1.0))
			# 앞쪽 살짝 솟은 부분 — 크게 두면 위에서 보는 카메라에 혹처럼 보인다(run #16), 빗은 결 줄도 뺐다
			_mesh(head, _sphere(0.096, 0.1), m, Vector3(0, 0.082, -0.022), Vector3(-8, 0, 0), Vector3(1.0, 0.5, 1.0))
		if style == "slick_fringe":
			for k in 3:                                          # 앞머리 몇 가닥 (이마로)
				_mesh(head, _box(Vector3(0.012, 0.075, 0.01)), m, Vector3(-0.03 + 0.024 * k, 0.05, -0.102),
					Vector3(-14, 0, -12 + 12 * k))
		else:
			loose = _node(head, Vector3.ZERO)                    # 백도찬: 싸우면 흘러내리는 가닥 (2차에 보인다)
			for k in 2:
				_mesh(loose, _box(Vector3(0.01, 0.075, 0.008)), m, Vector3(-0.022 + 0.04 * k, 0.045, -0.1),
					Vector3(-14, 0, 8 - 20 * k))
			loose.visible = false
	elif style == "topknot":
		# 피우진: 가운데 가르마 장발을 싸울 땐 정수리에 상투로 묶는다 — 짧게 붙인 머리 + 정수리 상투
		_mesh(head, _sphere(0.108, 0.2), m, Vector3(0, 0.05, 0.02), Vector3.ZERO, Vector3(1.0, 0.66, 1.02))
		_mesh(head, _sphere(0.045, 0.08), m, Vector3(0, 0.125, 0.03))
		_mesh(head, _box(Vector3(0.012, 0.06, 0.012)), m, Vector3(0, 0.06, -0.1), Vector3(-10, 0, 0))
	elif style == "wavy_back":
		# 하야부사 · 구일화: 웨이브 진 머리를 뒤로 넘겨 목덜미까지
		_mesh(head, _sphere(0.11, 0.2), m, Vector3(0, 0.05, 0.03), Vector3.ZERO, Vector3(1.04, 0.68, 1.04))
		_mesh(head, _sphere(0.085, 0.14), m, Vector3(0, -0.04, 0.075), Vector3.ZERO, Vector3(1.1, 1.2, 0.8))
		for k in 3:
			_mesh(head, _sphere(0.03, 0.06), m, Vector3(-0.05 + 0.05 * k, 0.1, 0.0))
	elif style == "spiky":
		# 신겐: 하얗게 곤두선 스파이크 백발
		_mesh(head, _sphere(0.106, 0.2), m, Vector3(0, 0.05, 0.02), Vector3.ZERO, Vector3(1.0, 0.62, 1.0))
		for k in 7:
			var a := TAU * k / 7.0
			var spike := CylinderMesh.new()
			spike.top_radius = 0.0
			spike.bottom_radius = 0.026
			spike.height = 0.09
			spike.radial_segments = 5
			_mesh(head, spike, m, Vector3(0.06 * cos(a), 0.12, 0.06 * sin(a) + 0.01), Vector3(-22 * sin(a), 0, 22 * cos(a)))
	elif style == "crew":
		# 경호대 최후의 4인 중심: 희끗한 짧은 크루컷
		# (0.5 높이는 머리통 0.116 보다 낮아 정수리가 뚫려 보였다 — 2026-11-09 폰 '김대건 가운데 머리 뚫림', 김대건 1층 머리도 crew)
		_mesh(head, _sphere(0.108, 0.2), m, Vector3(0, 0.05, 0.02), Vector3.ZERO, Vector3(1.0, 0.74, 1.0))
		_mesh(head, _sphere(0.1, 0.2), m, Vector3(0, -0.01, 0.05), Vector3.ZERO, Vector3(1.0, 0.95, 0.85))       # 뒤통수 ~ 목덜미
	elif style == "buzz":
		# 아주 짧게 깎은 머리(김대건 · 강만재): 머리통에 붙인 짧은 머리 + 이마선
		_mesh(head, _sphere(0.108, 0.2), m, Vector3(0, 0.05, 0.02), Vector3.ZERO, Vector3(1.0, 0.7, 1.0))           # 정수리까지 덮게(0.66 아래면 살이 비친다)
		_mesh(head, _sphere(0.094, 0.1), m, Vector3(0, 0.078, -0.03), Vector3(-6, 0, 0), Vector3(1.0, 0.48, 1.0))
		_mesh(head, _sphere(0.1, 0.2), m, Vector3(0, -0.01, 0.05), Vector3.ZERO, Vector3(1.0, 0.95, 0.85))       # 뒤통수 ~ 목덜미
	elif style == "bald":
		pass                                                     # 대머리(군터 경호원) — 머리털 없음
	elif look.get("female", false) and style in ["long", "bob", "ponytail"]:
		_hair_fem(head, m, style)
	elif style == "long" or style == "bob":
		# 어깨까지 오는 장발(우지 든 남자) · 턱선 단발(bob — 인형은 같은 모양): 가운데 가르마 + 옆 · 뒤로 늘어진 머리
		_mesh(head, _sphere(0.109, 0.2), m, Vector3(0, 0.05, 0.022), Vector3.ZERO, Vector3(1.02, 0.68, 1.02))
		_mesh(head, _sphere(0.09, 0.2), m, Vector3(0, -0.04, 0.07), Vector3(8, 0, 0), Vector3(1.0, 1.0, 0.6))
		for sx in [-1.0, 1.0]:
			_mesh(head, _capsule(0.03, 0.19), m, Vector3(0.094 * sx, -0.03, 0.02), Vector3(0, 0, -6 * sx), Vector3(1.0, 1.0, 1.6))
	elif style == "ponytail":
		# 뒤로 넘겨 하나로 묶은 머리(포니테일 거구 · 김혁주): 붙인 머리 + 뒤통수에서 늘어진 꼬리
		_mesh(head, _sphere(0.108, 0.2), m, Vector3(0, 0.05, 0.028), Vector3.ZERO, Vector3(1.0, 0.71, 1.02))
		_mesh(head, _sphere(0.096, 0.1), m, Vector3(0, 0.08, -0.024), Vector3(-8, 0, 0), Vector3(1.0, 0.5, 1.0))      # 이마선(앞에서 대머리처럼 안 보이게)
		_mesh(head, _sphere(0.026, 0.05), m, Vector3(0, 0.0, 0.112))
		_mesh(head, _capsule(0.026, 0.2), m, Vector3(0, -0.085, 0.13), Vector3(-14, 0, 0))
	elif style == "curly":
		# 눈을 덮는 흐트러진 곱슬머리(김성준): 부푼 머리 + 둥근 뭉치들, 앞머리가 눈썹까지
		_mesh(head, _sphere(0.116, 0.21), m, Vector3(0, 0.055, 0.02), Vector3.ZERO, Vector3(1.04, 0.7, 1.04))
		for k in 8:
			var a := TAU * k / 8.0
			_mesh(head, _sphere(0.034, 0.064), m, Vector3(0.085 * cos(a), 0.085 + 0.012 * sin(a * 3.0), 0.085 * sin(a) + 0.015))
		for k in 4:
			_mesh(head, _sphere(0.028, 0.06), m, Vector3(-0.054 + 0.036 * k, 0.04 - 0.008 * (k % 2), -0.092))
	elif style == "undercut":
		# 옆 · 뒤를 짧게 민 투블럭 위로 뒤로 넘긴 머리(서진태 금발 · 윤덕수). 민 자리 색 hair2
		var side_m := _mat(look.get("hair2", look["hair"]), 0.6, 0.2)
		_mesh(head, _sphere(0.107, 0.2), side_m, Vector3(0, 0.03, 0.024), Vector3.ZERO, Vector3(1.0, 0.7, 1.0))
		_mesh(head, _sphere(0.094, 0.13), m, Vector3(0, 0.1, 0.012), Vector3(-6, 0, 0), Vector3(0.9, 0.82, 1.1))
		_mesh(head, _sphere(0.06, 0.07), m, Vector3(0, 0.118, -0.05), Vector3(-10, 0, 0), Vector3(1.0, 0.8, 1.0))
		if look.get("loose", false):                             # 윤덕수: 싸움 끝에 넘긴 머리가 풀려 늘어진다(2차 — loose)
			loose = _node(head, Vector3.ZERO)
			for k in 3:
				_mesh(loose, _box(Vector3(0.012, 0.08, 0.01)), m, Vector3(-0.03 + 0.03 * k, 0.05, -0.1), Vector3(-12, 0, 10 - 10 * k))
			loose.visible = false
	elif style == "fringe":
		# 김신 1부: 짧은 검은 머리에 앞머리가 눈썹을 덮는다(p1:002 · 003 · 014 '눈 덮는 앞머리') — 옆 · 뒤는 slick_fringe 와 같게
		_mesh(head, _sphere(0.108, 0.2), m, Vector3(0, 0.066, 0.026), Vector3.ZERO, Vector3(0.93, 0.6, 1.0))
		_mesh(head, _sphere(0.098, 0.15), m, Vector3(0, 0.004, 0.05), Vector3.ZERO, Vector3(0.93, 1.0, 0.85))
		_mesh(head, _sphere(0.09, 0.09), m, Vector3(0, 0.09, -0.04), Vector3(-8, 0, 0), Vector3(0.98, 0.6, 1.0))
		for k in 5:
			_mesh(head, _box(Vector3(0.022, 0.07, 0.012)), m, Vector3(-0.048 + 0.024 * k, 0.05, -0.099),
				Vector3(-12, 0, 10 - 5 * k))
	elif style == "bun":
		# 오지인: 옆 가르마로 매끈하게 뒤로 넘겨 틀어 올린 낮은 쪽머리 + 얼굴 양옆으로 흘러내린 가는 앞 가닥(카드 초상 하성_오지인).
		# 폰 2026-11-07 '못생김' — 헬멧 같은 앞 단 · 판자 같은 가닥을 고쳤다: 이마 선은 둥글게 물리고, 가닥은 가늘게 휘어 턱까지
		_mesh(head, _sphere(0.108, 0.2), m, Vector3(0, 0.042, 0.024), Vector3(0, 0, -3), Vector3(0.97, 0.8, 1.04))
		_mesh(head, _sphere(0.088, 0.17), m, Vector3(0, 0.0, 0.05), Vector3.ZERO, Vector3(0.98, 0.9, 0.86))            # 뒤통수 · 목덜미 쪽
		_mesh(head, _sphere(0.05, 0.09), m, Vector3(0, -0.03, 0.118), Vector3(0, 0, 20), Vector3(1.2, 0.95, 0.85))    # 쪽(낮게)
		_mesh(head, _sphere(0.03, 0.06), m, Vector3(0.012, -0.022, 0.15), Vector3(0, 0, -30), Vector3(1.1, 0.8, 0.8))  # 틀어 감은 결
		for sx in [-1.0, 1.0]:                                   # 앞 가닥: 관자놀이에서 턱선까지 가늘게
			_mesh(head, _capsule(0.0035, 0.115), m, Vector3(0.075 * sx, -0.016, -0.066), Vector3(6, 0, 3 * sx))
	elif style == "parted":
		_mesh(head, _sphere(0.108, 0.2), m, Vector3(0, 0.05, 0.022), Vector3.ZERO, Vector3(1.0, 0.66, 1.02))
		_mesh(head, _box(Vector3(0.11, 0.03, 0.17)), m, Vector3(0.034, 0.088, -0.004), Vector3(0, 0, -12))
		_mesh(head, _box(Vector3(0.16, 0.03, 0.04)), m, Vector3(-0.01, 0.072, -0.086), Vector3(-24, 0, -8))
	else:
		# 짧은 머리: 정수리까지 덮게 높이 0.7(0.64 면 정수리 살이 비쳐 대머리처럼 보였다 — 황보민철 검토 2026-11-06)
		_mesh(head, _sphere(0.107, 0.2), m, Vector3(0, 0.05, 0.024), Vector3.ZERO, Vector3(1.0, 0.7, 1.02))
		_mesh(head, _sphere(0.096, 0.1), m, Vector3(0, 0.08, -0.026), Vector3(-8, 0, 0), Vector3(1.0, 0.52, 1.0))     # 정수리 앞(이마선)
		_mesh(head, _box(Vector3(0.15, 0.036, 0.05)), m, Vector3(0, 0.07, -0.084), Vector3(-22, 0, 0))


## 여성 머리(2026-11-07 폰 '오지인 못생김' 때 함께 — 헬멧 같은 껍질 · 귀마개 같은 옆머리를 고쳤다): long — 등으로 늘어진 생머리
## (hair_long 이면 가슴 아래까지, 리사 · 유세희) · bob — 턱선 단발 + 가운데서 갈라진 앞머리(차수민) · ponytail — 뒤로 묶은 꼬리 +
## 얼굴 옆 가는 앞 가닥(이리원 · 마리나)
func _hair_fem(head: Node3D, m: Material, style: String) -> void:
	_mesh(head, _sphere(0.108, 0.2), m, Vector3(0, 0.042, 0.024), Vector3.ZERO, Vector3(0.97, 0.8, 1.04))
	if style == "bob":
		_mesh(head, _sphere(0.112, 0.2), m, Vector3(0, -0.035, 0.028), Vector3.ZERO, Vector3(1.06, 0.9, 0.97))      # 턱선까지 오는 종 모양 옆 · 뒤
		for sx in [-1.0, 1.0]:                                   # 가운데서 갈라져 옆으로 흐르는 앞머리
			_mesh(head, _sphere(0.5, 1.0), m, Vector3(0.036 * sx, 0.07, -0.08), Vector3(-34, 12 * sx, -22 * sx), Vector3(0.07, 0.016, 0.04))
		return
	if style == "ponytail":
		_mesh(head, _sphere(0.028, 0.056), m, Vector3(0, 0.03, 0.11))
		_mesh(head, _capsule(0.03, 0.22), m, Vector3(0, -0.07, 0.135), Vector3(-12, 0, 0))
	else:
		var ln := 1.5 if look.get("hair_long", false) else 1.0
		_mesh(head, _capsule(0.08, 0.26 * ln), m, Vector3(0, -0.07 - 0.07 * (ln - 1.0), 0.06), Vector3(6, 0, 0), Vector3(1.05, 1.0, 0.5))   # 등으로 늘어진 뒷머리
		for sx in [-1.0, 1.0]:
			_mesh(head, _capsule(0.03, 0.22 * ln), m, Vector3(0.086 * sx, 0.055 - 0.11 * ln, 0.03), Vector3(0, 0, -3 * sx), Vector3(0.6, 1.0, 1.9))
	for sx in [-1.0, 1.0]:                                       # 얼굴 옆 가는 앞 가닥
		_mesh(head, _capsule(0.0035, 0.1 if style == "ponytail" else 0.115), m, Vector3(0.075 * sx, -0.012, -0.066), Vector3(6, 0, 3 * sx))


## 색안경: sun — 검은 사각 선글라스(피우진) · aviator — 에비에이터(구일화, 렌즈 색 lens)
func _shades(head: Node3D, kind: String, lens_col: Color) -> Node3D:
	var g := _node(head, Vector3.ZERO)
	var frame := _mat(Color(0.08, 0.08, 0.09), 0.3, 0.0, 0.6) if kind == "sun" else _mat(Color(0.8, 0.66, 0.3), 0.25, 0.0, 0.9)
	var lens := _mat(lens_col, 0.06, 0.5, 0.2)
	for sx in [-1.0, 1.0]:
		var sz := Vector3(0.042, 0.026, 0.006) if kind == "sun" else Vector3(0.04, 0.032, 0.006)
		_mesh(g, _box(sz), lens, Vector3(0.04 * sx, 0.008, -0.107))
		_mesh(g, _box(Vector3(0.004, 0.004, 0.09)), frame, Vector3(0.062 * sx, 0.014, -0.062))
	_mesh(g, _box(Vector3(0.024, 0.005, 0.006)), frame, Vector3(0, 0.016, -0.109))
	return g


## 맑은 안경: 테 없는(은테) 직사각 — 알이 빛을 받아 하얗게(백도찬 canon look). 맑은 렌즈(looks.json lens clear)는 검게 그리지 않는다 · 테 색 frame
func _glasses(head: Node3D, frame_col := Color(0.75, 0.77, 0.8)) -> Node3D:
	var g := _node(head, Vector3.ZERO)
	var frame := _mat(frame_col, 0.25, 0.0, 0.85)
	var lens := _mat(Color(0.97, 0.98, 1.0), 0.08, 0.6)
	for sx in [-1.0, 1.0]:
		_mesh(g, _box(Vector3(0.036, 0.022, 0.004)), lens, Vector3(0.039 * sx, 0.009, -0.106))
		_mesh(g, _box(Vector3(0.004, 0.004, 0.09)), frame, Vector3(0.06 * sx, 0.014, -0.062))
	_mesh(g, _box(Vector3(0.02, 0.004, 0.005)), frame, Vector3(0, 0.014, -0.108))
	return g


## 2차(전력): 안경을 벗고, 뒤로 넘긴 머리 가닥이 흘러내린다
func remove_glasses() -> void:
	if glasses != null:
		glasses.visible = false
	if loose != null:
		loose.visible = true


## 백도찬 어깨 홀스터: 등에서 X 자로 걸친 갈색 가죽 끈 + 앞쪽 어깨끈 + 왼 겨드랑이 권총집 · 권총 손잡이
func _holster(chest: Node3D, leather: Material, dark: Material, wide: float) -> void:
	for sx in [-1.0, 1.0]:
		_mesh(chest, _box(Vector3(0.036, 0.34, 0.012)), leather, Vector3(0, 0.08, 0.121), Vector3(0, 0, 32 * sx))     # 등 X
		_mesh(chest, _box(Vector3(0.03, 0.17, 0.012)), leather, Vector3(0.118 * sx * wide, 0.12, -0.112), Vector3(0, 0, -14 * sx))
	_mesh(chest, _box(Vector3(0.05, 0.12, 0.07)), leather, Vector3(-0.19 * wide, 0.0, -0.01))       # 권총집 (왼 겨드랑이)
	_mesh(chest, _box(Vector3(0.032, 0.055, 0.04)), dark, Vector3(-0.19 * wide, 0.075, 0.018), Vector3(-20, 0, 0))


func _attach(hand: Node3D, kind: String, dir: Vector3) -> Node3D:
	if kind == "":
		return null
	var w := _knife(kind)
	w.position = Vector3(0, -0.05, -0.006)
	w.basis = Basis(Quaternion(Vector3.UP, dir.normalized()))
	hand.add_child(w)
	return w


## 칼 (칼날이 +Y). combat: 김신 — 톱니 등날 군용 단검(canon look, 검은 손잡이 · 외날 · 등에 톱니) / gerber: 거버 Mark II —
## 양날 창끝 · 고무 손잡이(전 그림) / sashimi: 백도찬 — 길고 가는 외날 · 갈색 손잡이
func _knife(kind: String) -> Node3D:
	var root := Node3D.new()
	var steel := _mat(Color(0.86, 0.88, 0.92), 0.16, 0.0, 0.95)
	if kind == "combat":
		_mesh(root, _cyl(0.014, 0.013, 0.11), _mat(Color(0.08, 0.08, 0.09), 0.85, 0.0), Vector3(0, -0.01, 0))
		_mesh(root, _box(Vector3(0.06, 0.012, 0.02)), _mat(Color(0.3, 0.3, 0.33), 0.3, 0.0, 0.8), Vector3(0, 0.05, 0))
		_mesh(root, _box(Vector3(0.03, 0.15, 0.005)), steel, Vector3(0, 0.13, 0))
		var tip := PrismMesh.new()
		tip.size = Vector3(0.03, 0.05, 0.005)
		tip.left_to_right = 0.0
		_mesh(root, tip, steel, Vector3(0, 0.23, 0))
		for k in 4:                                              # 등날 톱니
			_mesh(root, _box(Vector3(0.008, 0.008, 0.005)), steel, Vector3(-0.017, 0.09 + 0.022 * k, 0), Vector3(0, 0, 45))
		return root
	if kind == "katana" or kind == "tachi":
		# 카타나(하야부사) · 대도 '대극'(신겐 — 더 길다): 검은 손잡이 · 금빛 츠바 · 살짝 휜 긴 날
		var long := 0.98 if kind == "tachi" else 0.82
		_mesh(root, _cyl(0.015, 0.015, 0.24), _mat(Color(0.07, 0.06, 0.07), 0.8, 0.0), Vector3(0, -0.07, 0))
		_mesh(root, _cyl(0.04, 0.04, 0.012), _mat(Color(0.8, 0.64, 0.25), 0.3, 0.0, 0.85), Vector3(0, 0.055, 0))
		_mesh(root, _box(Vector3(0.026, long, 0.006)), steel, Vector3(0.004, 0.065 + long * 0.5, 0), Vector3(0, 0, -2.0))
		return root
	if kind == "tanto":
		_mesh(root, _cyl(0.013, 0.013, 0.1), _mat(Color(0.1, 0.08, 0.07), 0.8, 0.0), Vector3(0, -0.01, 0))
		_mesh(root, _box(Vector3(0.024, 0.18, 0.005)), steel, Vector3(0, 0.13, 0))
		return root
	if kind == "pistol":
		var black := _mat(Color(0.1, 0.1, 0.11), 0.35, 0.1, 0.5)
		_mesh(root, _box(Vector3(0.03, 0.05, 0.1)), black, Vector3(0, -0.005, 0.02))         # 손잡이(손바닥 쪽)
		_mesh(root, _box(Vector3(0.03, 0.17, 0.04)), black, Vector3(0, 0.06, -0.01))         # 총열 — 아래팔 연장선(겨누는 쪽)
		return root
	if kind == "knuckles":
		# 금 너클(남궁혁 — 오른손): 주먹 앞 손가락 마디를 감싼 금 고리 막대
		var gold := _mat(Color(0.9, 0.72, 0.28), 0.25, 0.1, 0.9)
		_mesh(root, _box(Vector3(0.095, 0.045, 0.045)), gold, Vector3(0, 0.01, 0))
		return root
	if kind == "baton":
		_mesh(root, _cyl(0.018, 0.02, 0.5), _mat(Color(0.08, 0.08, 0.09), 0.5, 0.1), Vector3(0, 0.2, 0))
		return root
	if kind == "revolver":
		# 리볼버(군터 · 대머리 경호원): 나무 손잡이 · 은빛 약실(실린더) · 긴 총열
		var gun := _mat(Color(0.62, 0.63, 0.66), 0.25, 0.1, 0.9)
		_mesh(root, _box(Vector3(0.03, 0.05, 0.1)), _mat(Color(0.4, 0.25, 0.13), 0.7, 0.0), Vector3(0, -0.005, 0.02))
		_mesh(root, _cyl(0.024, 0.024, 0.05), gun, Vector3(0, 0.04, -0.012))
		_mesh(root, _cyl(0.011, 0.011, 0.16), gun, Vector3(0, 0.13, -0.022))
		return root
	if kind == "uzi":
		# 우지(장발 남자): 네모난 검은 몸통 · 손잡이 속 탄창이 아래로 길게
		var black := _mat(Color(0.12, 0.12, 0.13), 0.4, 0.1, 0.5)
		_mesh(root, _box(Vector3(0.04, 0.1, 0.075)), black, Vector3(0, -0.01, 0.035))
		_mesh(root, _box(Vector3(0.05, 0.25, 0.06)), black, Vector3(0, 0.08, -0.02))
		_mesh(root, _cyl(0.009, 0.009, 0.05), black, Vector3(0, 0.225, -0.025))
		return root
	if kind == "jackknife":
		# 붉은 손잡이 잭나이프(김혁주 — 허리띠에 두 자루): 붉은 손잡이 · 은 받침 · 끝이 젖혀진 외날
		_mesh(root, _cyl(0.014, 0.012, 0.11), _mat(Color(0.75, 0.1, 0.08), 0.5, 0.2), Vector3(0, -0.01, 0))
		_mesh(root, _box(Vector3(0.03, 0.01, 0.022)), _mat(Color(0.75, 0.76, 0.8), 0.25, 0.0, 0.9), Vector3(0, 0.048, 0))
		_mesh(root, _box(Vector3(0.024, 0.13, 0.005)), steel, Vector3(0, 0.115, 0))
		var tip := PrismMesh.new()
		tip.size = Vector3(0.024, 0.04, 0.005)
		tip.left_to_right = 1.0
		_mesh(root, tip, steel, Vector3(0, 0.2, 0))
		return root
	if kind == "pipe":
		# 쇠파이프(DS 습격조 — p1:008 '흰 소매 남자(쇠파이프)'): 회색 쇠관, 끝이 조금 굵다
		var iron := _mat(Color(0.5, 0.52, 0.55), 0.35, 0.1, 0.8)
		_mesh(root, _cyl(0.02, 0.02, 0.7), iron, Vector3(0, 0.28, 0))
		_mesh(root, _cyl(0.026, 0.026, 0.03), iron, Vector3(0, 0.62, 0))
		return root
	if kind == "bat":
		# 야구방망이(습격조 · DS 부하): 손잡이는 가늘고 끝으로 굵어지는 나무
		_mesh(root, _cyl(0.034, 0.016, 0.72), _mat(Color(0.62, 0.46, 0.28), 0.6, 0.1), Vector3(0, 0.29, 0))
		return root
	if kind == "sashimi":
		_mesh(root, _cyl(0.012, 0.012, 0.12), _mat(Color(0.45, 0.3, 0.17), 0.8, 0.0), Vector3(0, -0.01, 0))
		_mesh(root, _box(Vector3(0.026, 0.25, 0.004)), steel, Vector3(0, 0.175, 0))
		var tip := PrismMesh.new()
		tip.size = Vector3(0.026, 0.055, 0.004)
		tip.left_to_right = 1.0
		_mesh(root, tip, steel, Vector3(0, 0.3275, 0))
	else:
		_mesh(root, _cyl(0.013, 0.013, 0.11), _mat(Color(0.09, 0.09, 0.1), 0.85, 0.0), Vector3(0, -0.01, 0))
		_mesh(root, _box(Vector3(0.056, 0.012, 0.02)), _mat(Color(0.3, 0.3, 0.33), 0.3, 0.0, 0.8), Vector3(0, 0.05, 0))
		var blade := CylinderMesh.new()
		blade.top_radius = 0.0
		blade.bottom_radius = 0.02
		blade.height = 0.17
		blade.radial_segments = 4
		blade.rings = 1
		_mesh(root, blade, steel, Vector3(0, 0.14, 0), Vector3(0, 45, 0), Vector3(1, 1, 0.3))
	return root


## 몸통 겉모양 노드 — 앞뒤(z)만 depth 배. 관절 노드(위치 · 회전)는 그대로라 팔다리 길이 · 각도가 바뀌지 않는다
func _shell(parent: Node3D, depth: float) -> Node3D:
	var n := _node(parent, Vector3.ZERO)
	n.scale = Vector3(1, 1, depth)
	return n


func _node(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _mat(c: Color, rough := 0.7, rim := 0.3, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if rim > 0.0:
		m.rim_enabled = true
		m.rim = rim
		m.rim_tint = 0.35
	# 번쩍임 때 셰이더를 새로 만들지 않게 발광은 늘 켜 두고 색만 바꾼다
	m.emission_enabled = true
	m.emission = Color(0, 0, 0)
	mats.append(m)
	return m


func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	m.radial_segments = 12
	m.rings = 4
	return m


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 14
	m.rings = 1
	return m


func _sphere(r: float, h: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 16
	m.rings = 8
	return m


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


# ----------------------------------------------------------------------
# 자세
