extends RefCounted
## [옮김] castle_M3D `src/view/looks.gd`(2c3e69b) — 바꾼 것: 경로. 설계: docs/C4_설계서_직접조작전투.md 6절 · 요구: FR-403
## 외형 표(3층 · 이 판 소유) — 관절 인형(src/view/puppet3d.gd setup)이 읽는다. 새 인물은 한 칸을 더한다(OCP).
## GLB · 도트로 바꿀 때도 인물 id → 외형 이름은 여기서(hotel.gd ROLES look · main.gd).

# 외형(3층 · 이 판 소유): castle_common `canon/characters.json` 의 look 글(conf ai — 원작 화별 판독을 합친 것, 연출에만)을
# 관절 인형으로 옮겼다(2026-11-05 사용자 "김신과 백도찬도 캐릭터에 맞게 외형 바꿔졌으면"). 색은 3D 밤 조명에 맞게 조금 밝힘.
#  김신: 키 크고 어깨 넓은 근육질 · 검은 올백 + 앞머리 몇 가닥 · 가는 눈 · 왼뺨 흉터 · 귀 검은 스터드 · 턱 수염 그늘 ·
#        검은 정장 · 흰 셔츠 · 검은 넥타이 · 옷깃 금 배지 · 은 버클 검은 벨트 · 톱니 등날 군용 단검(역수 · 정수)
#  (rc.2 폰 리뷰 2026-11-05: 김신 '머리 · 얼굴 · 몸 비율이 이상함' → 옆머리 짧게 · 눈썹 · 입 · 머리 0.9 · 팔다리 굵게 · 몸통 두껍게,
#   백도찬 '몸이 더 크고 두꺼워야 함. 특히 김신보다는 더' → 키 1.2 · 너비 1.3 · 두께 1.4 · 팔다리 1.45)
#  백도찬(6장 부두 — 대표 차림, 사용자 2026-11-05): 뒤로 넘긴 밝은 갈색 머리(2차에 가닥이 흘러내림) · 빛 반사로 하얀 테 없는
#        직사각 안경 · 각진 턱 · 근육질 거구 · 소매 걷은 흰 셔츠 · 등에서 X 자 갈색 가죽 어깨 홀스터(왼 겨드랑이 권총) ·
#        검은 벨트 · 바지 · 구두 · 갈색 손잡이 가는 단도 · 귀 검은 피어싱
const LooksCommon = preload("res://ui/fight3d/looks_common.gd")

const LOOKS := {
	"kim": {"suit": Color(0.16, 0.16, 0.2), "pants": Color(0.13, 0.13, 0.17), "shirt": Color(0.93, 0.93, 0.94),
		"tie": Color(0.09, 0.09, 0.12), "skin": Color(0.91, 0.77, 0.65), "hair": Color(0.11, 0.11, 0.15),
		"hair_style": "slick_fringe", "glasses": false, "big": false, "scale": 1.04, "shoulder": 1.12, "eye_h": 0.007,
		"depth": 1.1, "limb": 1.15, "head": 0.9, "brow_tilt": 12.0, "jaw": true,
		"scar": true, "piercing": true, "badge": Color(0.95, 0.75, 0.25), "buckle": Color(0.82, 0.84, 0.88),
		"weapon_r": "combat", "weapon_l": "combat", "guard": "kim"},
	"baek": {"outfit": "shirt", "suit": Color(0.9, 0.9, 0.92), "pants": Color(0.11, 0.11, 0.13), "shirt": Color(0.92, 0.92, 0.94),
		"skin": Color(0.89, 0.75, 0.63), "hair": Color(0.62, 0.44, 0.27), "hair_style": "slick", "glasses": true,
		"big": true, "scale": 1.2, "wide": 1.28, "depth": 1.35, "limb": 1.2, "head": 0.95, "jaw": true, "piercing": true, "holster": Color(0.45, 0.27, 0.14),
		"buckle": Color(0.2, 0.2, 0.22), "weapon_r": "sashimi", "weapon_l": "", "guard": "baek"},
	# ---- 11장 호텔 캐슬 (S2) — 근거는 같은 canon look 글(conf ai)
	#  피우진: 큰 키 · 근육질 · 어깨 길이 검은 장발(싸울 땐 정수리 상투) · 왼뺨~콧등 흉터 · 귀 피어싱 · 검은 정장 · 흰 셔츠 ·
	#          검은 사각 선글라스 · 맨주먹
	"woojin": {"suit": Color(0.14, 0.14, 0.17), "pants": Color(0.12, 0.12, 0.15), "shirt": Color(0.92, 0.92, 0.93),
		"skin": Color(0.88, 0.74, 0.62), "hair": Color(0.08, 0.08, 0.1), "hair_style": "topknot", "glasses": "sun",
		"big": false, "scale": 1.06, "shoulder": 1.1, "depth": 1.15, "limb": 1.2, "head": 0.92, "jaw": true,
		"scar": true, "piercing": true, "buckle": Color(0.2, 0.2, 0.22), "weapon_r": "", "weapon_l": "", "guard": "box"},
	#  구일화: 근육질 거구 · 곱슬 웨이브 흑발(뒤로 묶음) · 턱수염 · 색안경(보라 렌즈 에비에이터) · 검은 정장 · 단추 푼 흰 셔츠 · 금 체인
	"guilhwa": {"suit": Color(0.12, 0.12, 0.14), "pants": Color(0.11, 0.11, 0.13), "shirt": Color(0.9, 0.9, 0.9),
		"skin": Color(0.85, 0.7, 0.56), "hair": Color(0.07, 0.07, 0.08), "hair_style": "wavy_back", "glasses": "aviator",
		"lens": Color(0.45, 0.25, 0.6), "beard": true, "big": true, "scale": 1.12, "wide": 1.25, "depth": 1.3, "limb": 1.3,
		"head": 0.95, "jaw": true, "chain": Color(0.95, 0.75, 0.25), "weapon_r": "", "weapon_l": "", "guard": "box"},
	#  캐슬 경호원(엑스트라 — 057 경호대 정장): 검은 정장 · 흰 셔츠 · 넥타이 · 짧은 머리 · 곤봉
	"guard": {"suit": Color(0.1, 0.1, 0.12), "pants": Color(0.1, 0.1, 0.12), "shirt": Color(0.88, 0.88, 0.9),
		"tie": Color(0.06, 0.06, 0.08), "skin": Color(0.86, 0.72, 0.6), "hair": Color(0.09, 0.09, 0.1), "hair_style": "short",
		"big": false, "scale": 1.02, "limb": 1.1, "weapon_r": "baton", "weapon_l": "", "guard": "box"},
	#  경호대 최후의 4인: 넷 다 거구 · 검은 정장 · 흰 셔츠 · 넥타이, 중심 인물은 희끗한 짧은 크루컷(058/039-045). 칼 · 권총
	"g4": {"suit": Color(0.07, 0.07, 0.09), "pants": Color(0.07, 0.07, 0.09), "shirt": Color(0.9, 0.9, 0.92),
		"tie": Color(0.05, 0.05, 0.06), "skin": Color(0.86, 0.72, 0.6), "hair": Color(0.08, 0.08, 0.09), "hair_style": "short",
		"big": true, "scale": 1.14, "wide": 1.25, "depth": 1.3, "limb": 1.3, "head": 0.95, "jaw": true,
		"weapon_r": "tanto", "weapon_l": "pistol", "grip_l": "fwd", "guard": "baek"},
	"g4_leader": {"suit": Color(0.07, 0.07, 0.09), "pants": Color(0.07, 0.07, 0.09), "shirt": Color(0.9, 0.9, 0.92),
		"tie": Color(0.05, 0.05, 0.06), "skin": Color(0.84, 0.7, 0.58), "hair": Color(0.62, 0.62, 0.64), "hair_style": "crew",
		"big": true, "scale": 1.2, "wide": 1.3, "depth": 1.35, "limb": 1.35, "head": 0.95, "jaw": true,
		"weapon_r": "tanto", "weapon_l": "pistol", "grip_l": "fwd", "guard": "baek"},
	#  하야부사: 웨이브 진 검은 곱슬머리를 뒤로 넘김(목덜미까지) · 흰 피부 · 흰(밝은 회색) 정장 · 검은 셔츠 · 검은 넥타이 · 카타나
	"hayabusa": {"suit": Color(0.74, 0.74, 0.76), "pants": Color(0.72, 0.72, 0.74), "shirt": Color(0.08, 0.08, 0.09),
		"tie": Color(0.04, 0.04, 0.05), "skin": Color(0.95, 0.85, 0.76), "hair": Color(0.06, 0.06, 0.07),
		"hair_style": "wavy_back", "big": false, "scale": 1.04, "limb": 1.05, "head": 0.92,
		"weapon_r": "katana", "weapon_l": "", "guard": "long"},
	#  사사키 신겐: 하얗게 곤두선 스파이크 백발 · 구릿빛 피부 · 짧은 턱수염 · 콧수염 · 가는 눈 · 거구 · 흰 세로줄 정장 · 흰 셔츠 ·
	#              적갈색 넥타이 · 흰 바지 · 긴 칼(대극) · 츠바 달린 단도
	"shingen": {"suit": Color(0.76, 0.76, 0.78), "pants": Color(0.74, 0.74, 0.76), "shirt": Color(0.86, 0.86, 0.88),
		"tie": Color(0.5, 0.14, 0.1), "skin": Color(0.72, 0.52, 0.36), "hair": Color(0.95, 0.95, 0.96), "hair_style": "spiky",
		"beard": true, "eye_h": 0.007, "big": true, "scale": 1.18, "wide": 1.25, "depth": 1.3, "limb": 1.3, "head": 0.95,
		"jaw": true, "weapon_r": "tachi", "weapon_l": "tanto", "grip_l": "fwd", "guard": "long"},
	# ---- 0 · 1장(S5 묶음 2 · 3) — 1부 처음(p1:002-020). 근거는 같은 canon look · looks_by_period · 화별 look 글(conf ai — 연출에만)
	#  김신(1부 처음 · 맨손): 눈썹을 덮는 검은 앞머리 · 귀 검은 귀걸이 · 몸에 붙는 검은 터틀넥 + 검은 정장 재킷 · 회색 바지 ·
	#        흰 밑창 검은 운동화(p1:003 · 008 · 014 · 019). 왼뺨 흉터는 031 무렵에 생긴다 → 아직 없음. 몸은 kim 과 같다
	"kim_bare": {"suit": Color(0.15, 0.15, 0.19), "pants": Color(0.34, 0.34, 0.37), "shirt": Color(0.07, 0.07, 0.09), "collar": "turtle",
		"skin": Color(0.91, 0.77, 0.65), "hair": Color(0.11, 0.11, 0.15), "hair_style": "fringe", "glasses": false, "big": false,
		"scale": 1.04, "shoulder": 1.12, "eye_h": 0.007, "depth": 1.1, "limb": 1.15, "head": 0.9, "brow_tilt": 12.0, "jaw": true,
		"piercing": true, "buckle": Color(0.82, 0.84, 0.88), "sole": Color(0.9, 0.9, 0.88),
		"weapon_r": "", "weapon_l": "", "guard": "box"},
	#  군터 경호원(fight:gunter p1:002/013-015 — '경호원들이 권총과 우지를 난사 · 총알 박힌 정장 남자'): 짙은 회색 정장 · 흰 셔츠 ·
	#        검은 넥타이 · 짧은 갈색 머리, 맨주먹
	"gunter_suit": {"suit": Color(0.22, 0.22, 0.24), "pants": Color(0.2, 0.2, 0.22), "shirt": Color(0.88, 0.88, 0.9),
		"tie": Color(0.06, 0.06, 0.08), "skin": Color(0.9, 0.78, 0.68), "hair": Color(0.36, 0.26, 0.17), "hair_style": "short",
		"big": false, "scale": 1.02, "limb": 1.1, "weapon_r": "", "weapon_l": "", "guard": "box"},
	#  대머리 경호원(p1:002/015-017 — '리볼버를 겨눈 대머리 · 김신 코트를 움켜쥠'): 대머리 · 다부진 몸 · 검은 정장 · 리볼버
	"gunter_bald": {"suit": Color(0.1, 0.1, 0.12), "pants": Color(0.1, 0.1, 0.12), "shirt": Color(0.88, 0.88, 0.9),
		"tie": Color(0.06, 0.06, 0.08), "skin": Color(0.9, 0.76, 0.66), "hair": Color(0.5, 0.4, 0.32), "hair_style": "bald",
		"big": false, "scale": 1.06, "wide": 1.16, "depth": 1.2, "limb": 1.2, "jaw": true,
		"weapon_r": "revolver", "weapon_l": "", "guard": "baek"},
	#  우지 든 장발 남자(p1:002/016-020 — 욕하며 우지 난사 · 권총 손잡이에 뒤통수를 맞음): 어깨까지 오는 장발 · 검은 셔츠 정장 · 우지
	"gunter_uzi": {"suit": Color(0.2, 0.19, 0.2), "pants": Color(0.12, 0.12, 0.13), "shirt": Color(0.1, 0.1, 0.11),
		"skin": Color(0.9, 0.78, 0.68), "hair": Color(0.3, 0.22, 0.15), "hair_style": "long", "big": false, "scale": 1.0,
		"limb": 1.05, "weapon_r": "uzi", "weapon_l": "", "guard": "baek"},
	#  포니테일 거구(p1:002/015 — 김신이 옆을 휩쓸고 지나감): 거구 · 뒤로 묶은 머리 · 검은 정장, 맨주먹
	"gunter_brute": {"suit": Color(0.08, 0.08, 0.1), "pants": Color(0.08, 0.08, 0.1), "shirt": Color(0.86, 0.86, 0.88),
		"tie": Color(0.3, 0.06, 0.06), "skin": Color(0.88, 0.74, 0.63), "hair": Color(0.55, 0.42, 0.26), "hair_style": "ponytail",
		"big": true, "scale": 1.22, "wide": 1.3, "depth": 1.38, "limb": 1.35, "head": 0.92, "jaw": true, "beard": true,
		"weapon_r": "", "weapon_l": "", "guard": "box"},
	#  군터: 뒤로 넘긴 금발 · 콧수염 · 이마에서 눈썹으로 내려오는 흉터 · 검은 모피 깃 와인색 가운(가슴털이 드러남) ·
	#        손가락 금반지 여러 개 · 시가(p1:002/007-008 · 021-029). 탁자 밑 리볼버(fight:gunter 4)
	"gunter": {"outfit": "robe", "suit": Color(0.44, 0.08, 0.15), "pants": Color(0.16, 0.1, 0.11), "shirt": Color(0.44, 0.08, 0.15),
		"skin": Color(0.93, 0.79, 0.7), "hair": Color(0.88, 0.74, 0.42), "hair_style": "slick", "mustache": true, "scar": "brow",
		"chest_hair": Color(0.55, 0.42, 0.25), "fur": Color(0.06, 0.05, 0.05), "rings": Color(0.95, 0.75, 0.25), "cigar": true,
		"big": false, "scale": 1.04, "wide": 1.16, "depth": 1.28, "limb": 1.12, "head": 0.96, "jaw": true,
		"weapon_r": "revolver", "weapon_l": "", "guard": "baek"},
	#  DS 씨큐리티 정장(fight:kimhyeokju p1:003 · fight:jintae_ds p1:019 — '검은 정장 · 흰 셔츠, 짧은 갈색 머리 · 은발 ·
	#        붉은 갈색 염소수염'): 검은 정장 · 깃 푼 흰 셔츠(넥타이 없음) · 짧은 갈색빛 머리, 맨주먹
	"ds_suit": {"suit": Color(0.12, 0.12, 0.14), "pants": Color(0.11, 0.11, 0.13), "shirt": Color(0.9, 0.9, 0.9), "collar": "open",
		"skin": Color(0.88, 0.74, 0.62), "hair": Color(0.3, 0.2, 0.13), "hair_style": "short", "big": false, "scale": 1.02,
		"limb": 1.1, "weapon_r": "", "weapon_l": "", "guard": "box"},
	#  DS 습격조(fight:pyechajang p1:008/001-004 — '방망이 · 쇠파이프 · 복면 · 검은 복면(눈만 뚫림) · 검은 상의 · 갈색 바지'):
	#        눈만 뚫린 검은 복면 · 검은 윗옷 · 갈색 바지 · 쇠파이프
	"ds_raider": {"suit": Color(0.1, 0.1, 0.11), "pants": Color(0.38, 0.28, 0.19), "shirt": Color(0.1, 0.1, 0.11), "collar": "turtle",
		"skin": Color(0.88, 0.74, 0.62), "hair": Color(0.1, 0.1, 0.1), "hair_style": "bald", "mask": Color(0.05, 0.05, 0.06),
		"big": false, "scale": 1.02, "limb": 1.12, "weapon_r": "pipe", "weapon_l": "", "guard": "long"},
	#  서진태(p1:003 첫 등장): 짧게 친 옆머리(검은 투블럭) 위 금발 웨이브 · 검은 뿔테 노란 렌즈 안경 · 양귀 검은 고리 귀걸이 ·
	#        연분홍 · 베이지 재킷 + 검은 티 · 흰 줄 검은 트랙 바지 · 흰 · 회색 운동화 · 군용 나이프. 근육질
	"jintae": {"suit": Color(0.92, 0.62, 0.74), "pants": Color(0.1, 0.1, 0.12), "shirt": Color(0.07, 0.07, 0.08),
		"skin": Color(0.92, 0.79, 0.68), "hair": Color(0.93, 0.8, 0.45), "hair2": Color(0.14, 0.11, 0.09), "hair_style": "undercut",
		"glasses": "sun", "lens": Color(0.98, 0.82, 0.12), "piercing": true, "stripe": Color(0.92, 0.92, 0.92),
		"shoe": Color(0.78, 0.78, 0.8), "sole": Color(0.95, 0.95, 0.95), "big": false, "scale": 1.0, "shoulder": 1.06,
		"limb": 1.1, "head": 0.92, "weapon_r": "", "weapon_l": "combat", "guard": "box"},
	#  김혁주(DS 부장 · p1:003/032-052): 짙은 피부 · 뒤로 넘겨 하나로 묶은 긴 검은 머리 · 날카로운 눈 · 남색 정장(열어 입음) ·
	#        흰 셔츠 · 굵은 금 사슬 목걸이 · 손목 금 팔찌 · 붉은 손잡이 잭나이프 두 자루
	"kimhyeokju": {"suit": Color(0.15, 0.19, 0.36), "pants": Color(0.13, 0.16, 0.3), "shirt": Color(0.92, 0.92, 0.9), "collar": "open",
		"skin": Color(0.72, 0.54, 0.4), "hair": Color(0.06, 0.06, 0.07), "hair_style": "ponytail", "eye_h": 0.007, "brow_tilt": 14.0,
		"chain": Color(0.95, 0.75, 0.25), "bracelet_r": Color(0.95, 0.75, 0.25), "big": false, "scale": 1.02, "limb": 1.08,
		"weapon_r": "jackknife", "weapon_l": "jackknife", "grip_l": "fwd", "guard": "baek"},
	#  김성준(약에 취한 — p1:008 · fight:pyechajang): 눈을 덮는 흐트러진 검은 곱슬머리 · 염소수염 · 양귀 귀걸이 · 목 문신 ·
	#        보랏빛으로 번뜩이는 눈 · 검은 가죽 롱코트 · 가슴까지 풀어헤친 흰 셔츠 · 카키 바지 · 두꺼운 밑창 부츠 · 품에 칼
	"kimseongjun": {"outfit": "coat", "leather": true, "suit": Color(0.1, 0.09, 0.09), "pants": Color(0.5, 0.46, 0.32),
		"shirt": Color(0.92, 0.92, 0.9), "collar": "open", "v_k": 1.7, "skin": Color(0.9, 0.77, 0.66), "hair": Color(0.06, 0.06, 0.07),
		"hair_style": "curly", "goatee": true, "piercing": true, "eye_col": Color(0.75, 0.3, 1.0), "neck_tattoo": Color(0.2, 0.2, 0.26),
		"sole": Color(0.14, 0.12, 0.11), "big": false, "scale": 1.04, "limb": 1.1, "head": 0.94,
		"weapon_r": "gerber", "weapon_l": "", "guard": "baek"},
	#  김대건(p1:014-016 노을 일대일): 건장한 근육질 · 아주 짧은 검은 머리 · 콧등 ~ 뺨 흉터 · 입술 아래 ~ 턱 흉터 · 턱수염 그늘 →
	#        재킷을 벗고 소매 걷은 흰 셔츠(깃 풂) · 검은 벨트 · 남색 바지 · 팔뚝 뱀 문신 · 오른손등 비늘 문신
	"kimdaegeon": {"outfit": "shirt", "suit": Color(0.92, 0.92, 0.93), "pants": Color(0.13, 0.15, 0.25), "shirt": Color(0.92, 0.92, 0.93),
		"skin": Color(0.87, 0.72, 0.6), "hair": Color(0.06, 0.06, 0.07), "hair_style": "buzz", "scar": "nose", "eye_h": 0.007,
		"brow_tilt": 14.0, "tattoo": Color(0.3, 0.4, 0.4), "tattoo_side": "both", "buckle": Color(0.2, 0.2, 0.22),
		"big": true, "scale": 1.12, "wide": 1.22, "depth": 1.28, "limb": 1.32, "head": 0.94, "jaw": true,
		"weapon_r": "", "weapon_l": "", "guard": "box"},
	#  강만재(p1:019 거리 — '부장님' · '삼겹살'): 짙은 피부 · 두꺼운 목의 근육질 거구 · 아주 짧은 검은 머리에 흰 붕대를 머리띠처럼 ·
	#        왼뺨 사선 흉터 두 줄 · 귀 검은 귀걸이 · 베이지 정장 재킷 · 깃 푼 흰 셔츠 · 베이지 바지(대표 look — 019 의 갈색 재킷은 짙은 피부와 섞여 대표 차림으로)
	"gangmanjae": {"suit": Color(0.78, 0.68, 0.52), "pants": Color(0.72, 0.63, 0.48), "shirt": Color(0.9, 0.9, 0.9), "collar": "open",
		"skin": Color(0.64, 0.47, 0.34), "hair": Color(0.06, 0.06, 0.07), "hair_style": "buzz", "bandage": Color(0.95, 0.95, 0.93),
		"scar": "double", "piercing": true, "big": true, "scale": 1.22, "wide": 1.4, "depth": 1.45, "limb": 1.45, "head": 0.95,
		"jaw": true, "weapon_r": "", "weapon_l": "", "guard": "box"},
	#  윤덕수(p1:019-020 거리 중앙선 · DS 대표): 어두운 피부 · 옆을 짧게 민 언더컷에 뒤로 넘긴 아주 짙은 갈색 머리(78차) · 굵은 눈썹 · 각진 턱 ·
	#        귀걸이 · 오른 팔뚝 문신의 근육질 거구 → 재킷을 벗고 넥타이를 푼 흰 셔츠(소매 걷음) · 회색 슬랙스(공통 #4d4f56 — 78차) · 손목 검은 밴드,
	#        싸움 끝에 넘긴 머리가 풀려 늘어진다(2차 — loose)
	"yundeoksu": {"outfit": "shirt", "suit": Color(0.9, 0.92, 0.95), "pants": Color(0.36, 0.37, 0.4), "shirt": Color(0.9, 0.92, 0.95),
		"tie": Color(0.42, 0.42, 0.46), "skin": Color(0.6, 0.43, 0.31), "hair": Color(0.05, 0.05, 0.06), "hair2": Color(0.24, 0.2, 0.18),
		"hair_style": "undercut", "loose": true, "brow_k": 1.7, "piercing": true, "tattoo": Color(0.18, 0.2, 0.26), "tattoo_side": "r",
		"bracelet_l": Color(0.05, 0.05, 0.06), "buckle": Color(0.75, 0.76, 0.8),
		"big": true, "scale": 1.28, "wide": 1.45, "depth": 1.5, "limb": 1.55, "head": 0.95, "jaw": true,
		"weapon_r": "", "weapon_l": "", "guard": "box"},
	# ---- 2장 하성 본사(1부 021~036) — 근거 castle_common data/looks.json(원작 조각 대조 · 2장 차림이 있으면 그것, conf ai — 연출에만).
	#      겉모습 칸은 looks_common 이 덮는다. 키 · 체격은 build.rel_height · rel_bulk 를 기존 인물(김신 1.0 · 1.0 = scale 1.04)에 견줘 손으로
	#  김신(2장 — looks.json 에 2장 차림이 없어 1장 귀국 차림 kim_bare 그대로 + 군용 단검 한 자루, 역수)
	"kim_p1_blade": {"suit": Color(0.15, 0.15, 0.19), "pants": Color(0.34, 0.34, 0.37), "shirt": Color(0.07, 0.07, 0.09), "collar": "turtle",
		"skin": Color(0.91, 0.77, 0.65), "hair": Color(0.11, 0.11, 0.15), "hair_style": "fringe", "glasses": false, "big": false,
		"scale": 1.04, "shoulder": 1.12, "eye_h": 0.007, "depth": 1.1, "limb": 1.15, "head": 0.9, "brow_tilt": 12.0, "jaw": true,
		"piercing": true, "buckle": Color(0.82, 0.84, 0.88), "sole": Color(0.9, 0.9, 0.88),
		"weapon_r": "combat", "weapon_l": "", "guard": "kim"},
	#  신태진(2장 '청소부' — 녹색 벙거지 · 자주 티 · 검은 긴 코트 · 끈 감은 나무 손잡이 외날 단도, 0.98 · 0.94 근육질): 가운데 가른 흑발 앞머리 · 왼뺨 흉
	"sintaejin": {"outfit": "coat", "suit": Color(0.07, 0.08, 0.1), "pants": Color(0.1, 0.1, 0.12), "shirt": Color(0.5, 0.4, 0.48), "collar": "crew",
		"skin": Color(0.92, 0.82, 0.76), "hair": Color(0.08, 0.09, 0.12), "hair_style": "fringe", "hat": "beanie", "hat_col": Color(0.17, 0.25, 0.21),
		"scar": true, "big": false, "scale": 1.0, "shoulder": 1.06, "limb": 1.1, "head": 0.92, "eye_h": 0.008, "brow_tilt": 10.0,
		"weapon_r": "tanto", "weapon_l": "", "guard": "baek"},
	#  남궁혁(1.02 · 1.15 근육질 · 굵은 팔다리): 그을린 피부 · 각진 흑발 올백 · 흰 정장 · 짙은 청록 넥타이 · 금 배지 · 금 너클(오른손)
	"namgunghyuk": {"suit": Color(0.93, 0.93, 0.91), "pants": Color(0.92, 0.92, 0.9), "shirt": Color(0.62, 0.61, 0.66), "tie": Color(0.12, 0.2, 0.28),
		"skin": Color(0.8, 0.68, 0.58), "hair": Color(0.13, 0.15, 0.17), "hair_style": "slick", "badge": Color(0.95, 0.75, 0.25),
		"piercing": true, "big": true, "scale": 1.14, "wide": 1.25, "depth": 1.3, "limb": 1.3, "head": 0.94, "jaw": true, "eye_h": 0.008,
		"brow_k": 1.5, "buckle": Color(0.2, 0.2, 0.22), "weapon_r": "knuckles", "weapon_l": "", "guard": "box"},
	#  황보민철(2장 싸움 차림 — 소매 걷은 흰 셔츠 · 등 X자 갈색 멜빵 · 검은 바지, 0.99 · 1.06): 짧은 흑발 · 왼눈 세로 흉터 · 나무 손잡이 단도 두 자루(1부 정수)
	"hwangbomincheol": {"outfit": "shirt", "suit": Color(0.95, 0.93, 0.91), "pants": Color(0.05, 0.05, 0.06), "shirt": Color(0.95, 0.93, 0.91),
		"skin": Color(0.86, 0.74, 0.64), "hair": Color(0.04, 0.04, 0.05), "hair_style": "short", "holster": Color(0.41, 0.34, 0.27),
		"buckle": Color(0.2, 0.2, 0.22), "big": false, "scale": 1.06, "shoulder": 1.12, "depth": 1.15, "limb": 1.2, "head": 0.92, "jaw": true,
		"eye_h": 0.008, "brow_k": 1.4, "weapon_r": "tanto", "weapon_l": "tanto", "grip_l": "fwd", "guard": "baek"},
	#  이슬(0.98 · 1.19 거구): 짙은 피부 · 아주 짧은 흑발 · 금테 에비에이터 갈색 렌즈 · 콧수염 + 염소수염 · 콧등 흉터 · 밝은 회색 더블 정장 · 겨자 넥타이 · 맨손
	"iseul": {"suit": Color(0.5, 0.5, 0.53), "pants": Color(0.48, 0.48, 0.51), "shirt": Color(0.72, 0.72, 0.74), "tie": Color(0.6, 0.48, 0.25),
		"skin": Color(0.52, 0.37, 0.25), "hair": Color(0.06, 0.06, 0.06), "hair_style": "crew", "glasses": "aviator", "lens": Color(0.3, 0.24, 0.19),
		"big": true, "scale": 1.1, "wide": 1.32, "depth": 1.38, "limb": 1.35, "head": 0.95, "jaw": true, "brow_k": 1.4,
		"weapon_r": "", "weapon_l": "", "guard": "box"},
	#  오지인(0.92 · 0.63 마름 — 비서): 뒤로 틀어 올린 낮은 쪽머리 · 양귀 금 고리 · 붉은 입술 · 검은 V넥 랩 블라우스(긴소매) · 버건디 펜슬 스커트 ·
	#        검은 하이힐 · 카타나. 긴소매라 outfit vest(몸통 · 팔 모두 블라우스 색)
	"ojiin": {"outfit": "vest", "suit": Color(0.17, 0.17, 0.18), "pants": Color(0.42, 0.24, 0.24), "shirt": Color(0.17, 0.17, 0.18), "collar": "open",
		"skirt": true, "skin": Color(0.95, 0.88, 0.83), "hair": Color(0.05, 0.05, 0.06), "hair_style": "bun", "piercing": true,
		"lips": Color(0.72, 0.22, 0.27), "big": false, "scale": 0.93, "wide": 0.84, "shoulder": 0.82, "depth": 0.85, "limb": 0.78, "head": 0.98,
		"eye_h": 0.008, "brow_k": 0.7, "weapon_r": "katana", "weapon_l": "", "guard": "long"},
	#  김재훈(0.97 · 0.89 보통): 실눈 · 붉은 갈색 투블럭 올백 · 녹회색 조끼 · 회색 셔츠 · 검은 넥타이 · 갈색 구두 · 은색 자동권총
	"kimjaehoon": {"outfit": "vest", "suit": Color(0.42, 0.44, 0.41), "pants": Color(0.42, 0.44, 0.41), "shirt": Color(0.6, 0.6, 0.63),
		"tie": Color(0.13, 0.13, 0.14), "skin": Color(0.86, 0.74, 0.66), "hair": Color(0.4, 0.27, 0.24), "hair2": Color(0.3, 0.21, 0.19),
		"hair_style": "undercut", "shoe": Color(0.28, 0.19, 0.16), "eye_h": 0.005, "big": false, "scale": 1.0, "wide": 0.97, "limb": 1.02,
		"head": 0.94, "weapon_r": "pistol", "weapon_l": "", "guard": "baek"},
	#  인수(1.03 · 1.2 근육질 — 남구희망청년회 2인자): 회색 니트 비니 + 어깨 닿는 흑발 · 콧수염 · 염소수염 · 왼귀 고리 · 짙은 회색 반팔 티 ·
	#        오른 팔뚝 문신 · 청바지 · 맨손
	"insu": {"outfit": "shirt", "suit": Color(0.3, 0.31, 0.35), "pants": Color(0.38, 0.46, 0.58), "shirt": Color(0.3, 0.31, 0.35), "collar": "crew",
		"skin": Color(0.9, 0.82, 0.75), "hair": Color(0.12, 0.11, 0.13), "hair_style": "long", "hat": "beanie", "hat_col": Color(0.42, 0.43, 0.47),
		"piercing": true, "tattoo": Color(0.15, 0.15, 0.17), "tattoo_side": "r", "sole": Color(0.85, 0.85, 0.85),
		"big": true, "scale": 1.16, "wide": 1.3, "depth": 1.35, "limb": 1.38, "head": 0.94, "jaw": true, "eye_h": 0.008, "brow_k": 1.4,
		"weapon_r": "", "weapon_l": "", "guard": "box"},
	#  강창석(029 사무실 — 0.99 · 0.93 어깨 넓음): 실눈 함박웃음 · 붉은 기 짙은 갈색 올백 + 늘어진 앞머리 · 버건디 정장 위아래 · 검은 크루넥 ·
	#        굵은 금 체인 · 금시계 · 긴 회칼(오른손) + 짧은 날(왼손 역수)
	"gangchangseok": {"suit": Color(0.47, 0.25, 0.27), "pants": Color(0.33, 0.2, 0.22), "shirt": Color(0.12, 0.1, 0.12), "collar": "crew",
		"skin": Color(0.92, 0.82, 0.74), "hair": Color(0.24, 0.13, 0.14), "hair_style": "slick_fringe", "chain": Color(0.8, 0.66, 0.3),
		"bracelet_l": Color(0.75, 0.66, 0.5), "eye_h": 0.005, "big": false, "scale": 1.02, "shoulder": 1.08, "limb": 1.05, "head": 0.94,
		"weapon_r": "sashimi", "weapon_l": "tanto", "guard": "baek"},
	#  하성 조직원(엑스트라 — 검은 정장 · 흰 셔츠 · 검은 넥타이 · 짧은 흑발, 단도)
	"haseong_suit": {"suit": Color(0.08, 0.08, 0.1), "pants": Color(0.08, 0.08, 0.1), "shirt": Color(0.9, 0.9, 0.92),
		"tie": Color(0.05, 0.05, 0.06), "skin": Color(0.87, 0.73, 0.61), "hair": Color(0.07, 0.07, 0.08), "hair_style": "short",
		"big": false, "scale": 1.02, "limb": 1.1, "weapon_r": "tanto", "weapon_l": "", "guard": "baek"},
	#  하성 정예 경호팀(엑스트라 — 검은 정장 · 턱수염 · 귀걸이 · 크루컷 거구, 맨손)
	"haseong_guard": {"suit": Color(0.06, 0.06, 0.08), "pants": Color(0.06, 0.06, 0.08), "shirt": Color(0.88, 0.88, 0.9),
		"tie": Color(0.05, 0.05, 0.06), "skin": Color(0.84, 0.7, 0.58), "hair": Color(0.07, 0.07, 0.08), "hair_style": "crew",
		"beard": true, "piercing": true, "big": true, "scale": 1.1, "wide": 1.2, "depth": 1.25, "limb": 1.25, "head": 0.95, "jaw": true,
		"weapon_r": "", "weapon_l": "", "guard": "box"},
	#  남구희망청년회(엑스트라 — 검은 비니 · 검은 반팔 티 · 검은 바지 · 흰 밑창 운동화, 맨손)
	"namgu_youth": {"outfit": "shirt", "suit": Color(0.09, 0.09, 0.1), "pants": Color(0.1, 0.1, 0.11), "shirt": Color(0.09, 0.09, 0.1),
		"collar": "crew", "skin": Color(0.88, 0.75, 0.64), "hair": Color(0.08, 0.08, 0.09), "hair_style": "short", "hat": "beanie",
		"hat_col": Color(0.1, 0.1, 0.11), "sole": Color(0.9, 0.9, 0.88), "big": false, "scale": 1.0, "limb": 1.08,
		"weapon_r": "", "weapon_l": "", "guard": "box"},
}

## 그림 A · B 가 있는 인물(S3 — 김신 · 신겐, 기획서 03 5절 '시험 범위 2명' · S5 0 · 1장 이름 있는 인물). 모델 · 시트는 이 표를 보고
## 만든다(tools/make_models.gd · make_sprites.gd). 엑스트라(군터 경호원 · DS 정장 · 습격조 · 하성 조직원 · 남구 청년회)는 관절 인형 그대로(main.gd 가 has_art 로 고른다)
const ART := {
	"kim": {"glb": "res://assets/models/kimshin_a.glb", "dots": "res://assets/sprites/kimshin_b"},
	"shingen": {"glb": "res://assets/models/shingen_a.glb", "dots": "res://assets/sprites/shingen_b"},
	"kim_bare": {"glb": "res://assets/models/kimshin_p1_a.glb", "dots": "res://assets/sprites/kimshin_p1_b"},   # 1부 처음 김신(터틀넥 · 맨손)
	"gunter": {"glb": "res://assets/models/gunter_a.glb", "dots": "res://assets/sprites/gunter_b"},
	"jintae": {"glb": "res://assets/models/jintae_a.glb", "dots": "res://assets/sprites/jintae_b"},
	"kimhyeokju": {"glb": "res://assets/models/kimhyeokju_a.glb", "dots": "res://assets/sprites/kimhyeokju_b"},
	"kimseongjun": {"glb": "res://assets/models/kimseongjun_a.glb", "dots": "res://assets/sprites/kimseongjun_b"},
	"kimdaegeon": {"glb": "res://assets/models/kimdaegeon_a.glb", "dots": "res://assets/sprites/kimdaegeon_b"},
	"gangmanjae": {"glb": "res://assets/models/gangmanjae_a.glb", "dots": "res://assets/sprites/gangmanjae_b"},
	"yundeoksu": {"glb": "res://assets/models/yundeoksu_a.glb", "dots": "res://assets/sprites/yundeoksu_b"},
	# 2장 하성 본사 — 김신 2장은 1부 처음과 몸 · 옷이 같아 GLB 를 같이 쓰고(칼은 인형 것) 도트만 따로(칼 자세)
	"kim_p1_blade": {"glb": "res://assets/models/kimshin_p1_a.glb", "dots": "res://assets/sprites/kimshin_p1_blade_b"},
	"sintaejin": {"glb": "res://assets/models/sintaejin_a.glb", "dots": "res://assets/sprites/sintaejin_b"},
	"namgunghyuk": {"glb": "res://assets/models/namgunghyuk_a.glb", "dots": "res://assets/sprites/namgunghyuk_b"},
	"hwangbomincheol": {"glb": "res://assets/models/hwangbomincheol_a.glb", "dots": "res://assets/sprites/hwangbomincheol_b"},
	"iseul": {"glb": "res://assets/models/iseul_a.glb", "dots": "res://assets/sprites/iseul_b"},
	"ojiin": {"glb": "res://assets/models/ojiin_a.glb", "dots": "res://assets/sprites/ojiin_b"},
	"kimjaehoon": {"glb": "res://assets/models/kimjaehoon_a.glb", "dots": "res://assets/sprites/kimjaehoon_b"},
	"insu": {"glb": "res://assets/models/insu_a.glb", "dots": "res://assets/sprites/insu_b"},
	"gangchangseok": {"glb": "res://assets/models/gangchangseok_a.glb", "dots": "res://assets/sprites/gangchangseok_b"},
	# 전인물 외형(2026-11-06) — 장 표에 쓰이는데 그림이 없던 이름(6장 백도찬 · 11장 호텔 캐슬 · 0 · 1장 DS 정장)
	"baek": {"glb": "res://assets/models/baekdochan_a.glb", "dots": "res://assets/sprites/baekdochan_b"},
	"woojin": {"glb": "res://assets/models/woojin_a.glb", "dots": "res://assets/sprites/woojin_b"},
	"guilhwa": {"glb": "res://assets/models/guilhwa_a.glb", "dots": "res://assets/sprites/guilhwa_b"},
	"hayabusa": {"glb": "res://assets/models/hayabusa_a.glb", "dots": "res://assets/sprites/hayabusa_b"},
	"guard": {"glb": "res://assets/models/castle_guard_a.glb", "dots": "res://assets/sprites/castle_guard_b"},
	"g4": {"glb": "res://assets/models/castle_g4_a.glb", "dots": "res://assets/sprites/castle_g4_b"},
	"g4_leader": {"glb": "res://assets/models/castle_g4_leader_a.glb", "dots": "res://assets/sprites/castle_g4_leader_b"},
	"ds_suit": {"glb": "res://assets/models/ds_member_a.glb", "dots": "res://assets/sprites/ds_member_b"},
}
## 명부(roster — 장 표에 아직 안 쓰는 looks.json 인물, looks_common ROSTER) 그림 자리. APK 에서 뺀다(export_presets.cfg exclude_filter
## assets/roster/*) — 편집기 · 시험 · 도구에서만 있고, 폰에서는 has_art 가 거짓이라 관절 인형으로 그린다
const ROSTER_DIR := "res://assets/roster"
## 3 ~ 13장 장 표에 나오는 명부 인물(그림 A · B 를 APK 에 넣는다 — 도트는 굳힌 명부 시트를 그대로 옮김, 사용자 2026-11-08 '그림 B 굳힘')
const STAGED := ["chasumin", "icheolmin", "vasily", "pyoyoung", "namilho", "bulgom", "moseunggyu", "odohwa", "masa", "shire", "ttolbae", "deumiteuri",
	"gustav", "barista", "jangho", "komodo", "keurisa", "medvedi", "ratel", "immuyeol", "choeminuk", "scaledanjang", "mark", "ryujihak",
	"andycheong", "eunbo", "bison", "pantera", "akila", "richeon", "douchen", "hantaecheol", "yuwoosung", "lingling", "majunyeong",
	"grolla", "eomji", "geomji", "choehyeokjin", "mahakyoung", "dohaksu", "eogwangdeuk", "sainjin", "jeongseono", "hide", "seungyeong"]


## 그림 A · B 자리(장 이름 ART + 명부). 없으면 빈 표
static func art_of(name: String) -> Dictionary:
	if ART.has(name):
		return ART[name]
	if LooksCommon.ROSTER.has(name):
		# 3 ~ 13장 장 표에 나오는 명부 인물은 그림을 assets/models · sprites 로 옮겨 APK 에 넣는다(STAGED — tools/stage_art.py)
		if STAGED.has(name):
			return {"glb": "res://assets/models/%s_a.glb" % name, "dots": "res://assets/sprites/%s_b" % name}
		return {"glb": "%s/models/%s_a.glb" % [ROSTER_DIR, name], "dots": "%s/sprites/%s_b" % [ROSTER_DIR, name]}
	return {}


## 외형 이름이 있는가(장 표 검사) — 손 표 LOOKS 또는 명부(castle_common looks.json — Looks.look 이 기본값으로 채운다)
static func known(name: String) -> bool:
	return LOOKS.has(name) or LooksCommon.ROSTER.has(name)


## 그림을 만드는 이름 전부(make_models · make_sprites · shot_looks) — 장 이름 다음에 명부
static func art_names() -> Array:
	var out: Array = ART.keys()
	out.append_array(LooksCommon.ROSTER.keys())
	return out


## 외형 이름 → 표. "<이름>_a" · "<이름>_b" 는 그 인물 외형 + 그림 A(GLB) · B(도트) 자리
static func look(name: String) -> Dictionary:
	var base := name.trim_suffix("_a").trim_suffix("_b")
	var lk: Dictionary = LOOKS.get(base, LOOKS["guard"]).duplicate()     # 표에 없는 외형은 경호원(시험 test_campaign 이 본다)
	if not LOOKS.has(base) and LooksCommon.ROSTER.has(base):   # 명부 인물 — 키 · 체격 · 무기 기본값(looks.json build · weapons)
		lk.merge(LooksCommon.ROSTER[base], true)
	if LooksCommon.BY_NAME.has(base):        # 원작 조각 대조 겉모습(castle_common data/looks.json — 사용자 답58)
		lk.merge(LooksCommon.BY_NAME[base], true)
	lk["scale"] = shown_scale(base, float(lk.get("scale", 1.06 if lk.get("big", false) else 1.0)))
	var wd: float = float(lk.get("wide", 1.08 if lk.get("big", false) else 1.0))
	if EXTRA_LOOKS.has(base):                         # 무리는 몸 너비를 EXTRA_MAX_WIDE 까지만(큰 경호원 · 거구도 메인보다 작게)
		lk["wide"] = minf(wd, EXTRA_MAX_WIDE)
		if lk.has("shoulder"):
			lk["shoulder"] = minf(float(lk["shoulder"]), EXTRA_MAX_WIDE)
	elif not lk.get("female", false):                 # 메인은 덩치(몸 · 어깨 너비)를 MAIN_WIDE 배 — 그림 A(GLB) · B(도트)는 다시 구워야 따른다
		# 여성은 빼고 표 그대로(2026-11-07 폰 '오지인 못생김' — 덩치를 키우면 가녀린 몸매가 둔해진다)
		if lk.has("shoulder"):
			lk["shoulder"] = float(lk["shoulder"]) * MAIN_WIDE
		lk["wide"] = wd * MAIN_WIDE
	if base == name:
		return lk
	lk.merge(art_of(base), true)
	return lk


## 화면 키(사용자 2026-11-06 "메인 케릭터들 크기는 비 메인 케릭터들보다 크게 그러나 지금보다 작게해주고, 머리가 너무크니까
## 머리 사이즈는 더 작게"): 표의 scale(인물끼리의 키 차 — 김신 1.04 · 백도찬 1.2 · 거구 보스 1.28)은 그대로 두고 화면에서만
## 메인(이름 있는 인물)은 MAIN_BASE 위로 차이를 MAIN_SPREAD 만큼 줄여 그리고, 엑스트라(EXTRA_LOOKS — 이름 없는 무리)는 표 그대로.
## 머리는 HEAD_K 배(관절 인형 머리 마디 · GLB 머리 뼈 — puppet3d · puppet_glb). 도트(그림 B)는 시트에 구워져 다시 만들 때 따른다.
## rc.2 폰(2026-11-07 "메인은 무리보다 덩치가 조금 더 컸으면 · 머리는 '머리만' 조금 더 작게 · 관절 인형이 그나마 낫다"):
## MAIN_BASE 1.03 → 1.05 · 메인 몸 너비 MAIN_WIDE · HEAD_K 0.82 → 0.75 · 무리는 키 EXTRA_MAX_SCALE · 너비 EXTRA_MAX_WIDE 까지만
## (표의 큰 무리 — 하성 경호팀 1.1 · 4인 1.14 · 군터 거구 1.22 — 가 메인 1.05 보다 커 보였다)
const MAIN_BASE := 1.05
const MAIN_SPREAD := 0.5
const MAIN_WIDE := 1.07
const EXTRA_MAX_SCALE := 1.0
const EXTRA_MAX_WIDE := 1.04
const HEAD_K := 0.75
const EXTRA_LOOKS := ["guard", "g4", "g4_leader", "gunter_suit", "gunter_bald", "gunter_uzi", "gunter_brute", "ds_suit", "ds_raider",
	"haseong_suit", "haseong_guard", "namgu_youth"]


static func shown_scale(base: String, s: float) -> float:
	if EXTRA_LOOKS.has(base):
		return minf(s, EXTRA_MAX_SCALE)
	return MAIN_BASE + maxf(0.0, s - 1.04) * MAIN_SPREAD


## 그림 A · B 가 있는가 — 명부 그림은 APK 에 없으니 파일이 있을 때만(폰에서는 관절 인형)
static func has_art(name: String) -> bool:
	if ART.has(name):
		return true
	return LooksCommon.ROSTER.has(name) and ResourceLoader.exists(str(art_of(name)["glb"]))


## 흉터 색: 살빛을 크게 어둡게 + 갈색 쪽(붉은 기 없이) — 가는 선이 살빛에 묻히지 않게
static func scar_col(lk: Dictionary) -> Color:
	return (lk["skin"] as Color).darkened(0.5).lerp(Color(0.25, 0.14, 0.12), 0.3)


## 아주 짙은 머리(검정에 가까운 색)는 툰 그늘 · 외곽선과 섞여 검은 덩어리로 보인다 — 밝기 아래 한계 + 푸른 기(만화의 검은 머리 표현)
static func hair_lift(c: Color) -> Color:
	var lum := 0.3 * c.r + 0.59 * c.g + 0.11 * c.b
	if lum >= 0.17:
		return c
	var d := 0.17 - lum
	return Color(c.r + d * 0.92, c.g + d * 0.96, c.b + d * 1.2)


## looks.json id(canon 인물 id) → 외형 이름(대표 차림). 없으면 ""
static func name_of(cid: String) -> String:
	return str(LooksCommon.ID_NAME.get(cid, ""))
