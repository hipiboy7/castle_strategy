extends RefCounted
## [옮김] castle_M3D `src/combat/enemy_ai.gd`(2c3e69b) — 바꾼 것: 불러오는 경로만. 설계: docs/C4_설계서_직접조작전투.md 4-1 · 요구: FR-401
## 적 AI (여러 사람 판 — 0장 군터 호텔 · 1장 회암시 · 2장 하성 본사 · 11장 호텔 캐슬) — 프로필 표(PROFILES) 하나로 엑스트라 · 군터 · DS 간부 ·
## 김대건 · 윤덕수 · 경호원 · 경호대 최후의 4인 · 하야부사 · 신겐을 움직인다.
## 백도찬 AI(boss_ai.gd)처럼 Fighter.intent 만 채운다. 판(stage.gd)이 매 프레임 상대(가장 가까운 사람)와 may_attack 을 준다 —
## 여럿이 한꺼번에 몰아치지 않게 동시에 패턴을 내는 적 수를 판이 제한한다(협공은 하되 예고를 읽을 틈은 남긴다).
## 칼날 쳐내기는 못 한다(김신 · 백도찬만) — 상대가 치면 기술(능력치) 확률로 막는다(fighter can_parry false → 막기).
## 3층(이 판 소유): 패턴 · 박자 · 거리 · 확률. 처음 값은 봇 판으로 맞춘다(무정지 규칙 6).

const Fighter = preload("res://fight/fighter.gd")

const HELPLESS := ["down", "stagger", "hitstun", "recoil", "stun", "dead"]

## patterns: 이름 → [[동작, 다음까지 쉬는 프레임], ...] · weights[phase-1]: [[이름, 무게], ...] · cd: 패턴 사이 쉬는 프레임 [최소, 더함]
## near · far: 거리 조절 · engage: 이 안이면 패턴을 시작 · ranged: [동작, 최소 거리, 최대 거리, 쿨다운] (총)
const PROFILES := {
	"guard": {"patterns": {"baton": [["c_baton", 0]], "punch2": [["c_punch", 10], ["c_baton", 0]]},
		"weights": [[["baton", 2], ["punch2", 1]]], "cd": [80, 60], "near": 1.0, "far": 1.7, "engage": 1.9},
	"g4": {"patterns": {"slash2": [["g4_slash", 8], ["g4_thrust", 0]], "chop": [["s_g4_chop", 0]],
			"heel": [["s_g4_heel", 0]], "slash_heel": [["g4_slash", 10], ["s_g4_heel", 0]]},
		"weights": [[["slash2", 3], ["chop", 1], ["heel", 1], ["slash_heel", 1]]], "cd": [70, 60],
		"near": 1.1, "far": 1.9, "engage": 2.1, "ranged": ["t_shot", 2.6, 6.5, 260]},
	"hayabusa": {"patterns": {"slash3": [["hy_slash1", 6], ["hy_slash2", 8], ["hy_thrust", 0]], "arc": [["s_hy_arc", 0]],
			"low": [["s_hy_low", 0]], "slash_low": [["hy_slash1", 8], ["s_hy_low", 0]]},
		"weights": [[["slash3", 3], ["arc", 2], ["low", 1], ["slash_low", 1]]], "cd": [50, 40],
		"near": 1.3, "far": 2.3, "engage": 2.5},
	"shingen": {"patterns": {"slash3": [["sg_slash1", 6], ["sg_slash2", 8], ["sg_stab", 0]], "daegeuk": [["s_sg_daegeuk", 0]],
			"dive": [["s_sg_dive", 0]], "kick": [["s_sg_kick", 0]], "leap": [["s_sg_leap", 0]],
			"slash_kick": [["sg_slash1", 8], ["s_sg_kick", 0]], "stab_daegeuk": [["sg_stab", 10], ["s_sg_daegeuk", 0]]},
		"weights": [[["slash3", 4], ["daegeuk", 2], ["dive", 1], ["kick", 1], ["slash_kick", 1]],
			[["slash3", 2], ["daegeuk", 2], ["dive", 2], ["kick", 1], ["leap", 2], ["slash_kick", 1], ["stab_daegeuk", 2]]],
		"cd": [34, 30], "near": 1.4, "far": 2.4, "engage": 2.6, "phase2": {"dmg_k": 1.15, "cd_k": 0.7, "guard_add": 0.1}},
	# ---- 0 · 1장(S5 묶음 2 · 3) — canon fights 국면(화/컷)에서. 동작은 src/data/moves.gd(m_ · gt_ · hj_ · sj_ · dg_ · mj_ · yd_).
	# 덧붙인 칸(이 장들만 쓴다): guard_add — 막는 확률에 더함(강만재 하이가드) · counter: [동작, 확률] — 상대가 치기 시작할 때 막지 않으면
	# 이 확률로 맞받아 친다(김대건 크로스 카운터 014/030-032) · phase2.counter_add — 2차에 맞받는 확률을 더함 ·
	# kite — 총잡이: 주먹 차례에도 다가가지 않고 거리를 두며 쏜다(붙으면 그때 주먹)
	# 엑스트라: 정장(군터 경호원 · DS 조직원 — 주먹 · 휘두르기 · 칼, 002/013-020 · 003/016-045) · 포니테일 거구(훅 · 두 손 내려찍기) ·
	# 대머리(리볼버) · 장발(우지 난사) · DS 습격조(쇠파이프 · 방망이 · 함성 돌진, 008/001-004)
	"thug": {"patterns": {"punch": [["m_punch", 0]], "punch2": [["m_punch", 8], ["m_swing", 0]], "swing": [["m_swing", 0]],
			"knife": [["m_knife", 0]]},
		"weights": [[["punch", 2], ["punch2", 2], ["swing", 1], ["knife", 1]]], "cd": [80, 60], "near": 1.0, "far": 1.7, "engage": 1.9},
	"thug_brute": {"patterns": {"hook": [["m_brute_hook", 0]], "slam": [["m_brute_slam", 0]], "hook_slam": [["m_brute_hook", 8], ["m_brute_slam", 0]]},
		"weights": [[["hook", 3], ["slam", 1], ["hook_slam", 1]]], "cd": [90, 60], "near": 1.0, "far": 1.8, "engage": 2.0},
	"thug_revolver": {"patterns": {"punch": [["m_punch", 0]], "punch_swing": [["m_punch", 10], ["m_swing", 0]]},
		"weights": [[["punch", 2], ["punch_swing", 1]]], "cd": [90, 60], "near": 1.9, "far": 4.0, "engage": 2.0,
		"ranged": ["m_revolver", 2.1, 6.8, 200], "kite": true},
	"thug_uzi": {"patterns": {"swing": [["m_swing", 0]], "punch2": [["m_punch", 8], ["m_punch", 0]]},
		"weights": [[["swing", 1], ["punch2", 1]]], "cd": [90, 60], "near": 2.0, "far": 4.2, "engage": 2.0,
		"ranged": ["m_uzi", 2.1, 6.2, 220], "kite": true},
	"thug_pipe": {"patterns": {"pipe": [["m_pipe", 0]], "pipe2": [["m_pipe", 6], ["m_pipe_back", 0]], "charge": [["m_charge", 0]]},
		"weights": [[["pipe", 3], ["pipe2", 2], ["charge", 1]]], "cd": [70, 60], "near": 1.1, "far": 1.9, "engage": 2.2},
	# 군터(0장 보스 · 조장급, 002/021-028): 탁자 밑 리볼버 — 떨어지면 쏘고, 붙으면 발악(주먹 · 위스키 잔 · 코앞 사격)
	"gunter": {"patterns": {"swing2": [["gt_swing", 8], ["gt_glass", 0]], "point": [["gt_swing", 6], ["gt_point", 0]],
			"glass": [["gt_glass", 0]], "fan": [["gt_fan", 0]]},
		"weights": [[["swing2", 2], ["point", 2], ["glass", 1], ["fan", 1]]], "cd": [60, 50], "near": 1.6, "far": 3.8, "engage": 2.0,
		"ranged": ["gt_revolver", 2.1, 7.0, 150], "kite": true},
	# 김혁주(003/045-051): 잭나이프 두 자루 — 첫 베기는 잽, 두 번째가 진짜(멈칫 뒤). 돌진 · 찌르기
	"hyeokju": {"patterns": {"two": [["hj_jab", 2], ["hj_real", 0]], "two_thrust": [["hj_jab", 2], ["hj_real", 8], ["hj_thrust", 0]],
			"rush": [["hj_rush", 0]], "thrust": [["hj_thrust", 0]]},
		"weights": [[["two", 4], ["two_thrust", 2], ["rush", 1], ["thrust", 1]]], "cd": [55, 45], "near": 1.1, "far": 1.9, "engage": 2.1},
	# 김성준(008-010): 약에 취해 몰아친다(쉬는 틈이 짧다) — 연타 · 코트 휘두르기 · 부츠 발차기(멀리 날림) · 칼
	"seongjun": {"patterns": {"flurry": [["sj_flurry", 0]], "coat": [["sj_coat", 0]], "coat_kick": [["sj_coat", 6], ["sj_kick", 0]],
			"knife": [["sj_upslash", 8], ["sj_knife", 0]], "flurry_kick": [["sj_flurry", 6], ["sj_kick", 0]]},
		"weights": [[["flurry", 3], ["coat", 2], ["coat_kick", 2], ["knife", 2], ["flurry_kick", 1]]], "cd": [36, 40],
		"near": 1.0, "far": 1.8, "engage": 2.0},
	# 김대건(014-016): 1차 큰 주먹 · 훅 → 뒷발 · 페인트 하이킥 · 미끄러지기 · 태클, 크로스 카운터. 2차(015/042-048 '피떡이 돼야 시동')
	# 프로다운 연타(잽 잽 정권 · 잽 직선 훅 → 날아 무릎) — 더 몰아치고 더 맞받는다
	"daegeon": {"patterns": {"straight": [["dg_straight", 0]], "one_two": [["dg_straight", 4], ["dg_hook", 0]],
			"hook_spin": [["dg_hook", 2], ["dg_spin", 0]], "feint_kick": [["dg_highkick", 0]], "slide": [["dg_slide", 0]],
			"tackle": [["dg_tackle", 0]], "pro3": [["dg_jab", 3], ["dg_jab", 3], ["dg_jeongkwon", 0]],
			"pro4": [["dg_jab", 3], ["dg_straight", 4], ["dg_hook", 6], ["dg_knee", 0]], "knee": [["dg_knee", 0]]},
		"weights": [[["straight", 3], ["one_two", 3], ["hook_spin", 2], ["feint_kick", 2], ["slide", 1], ["tackle", 1]],
			[["pro3", 3], ["pro4", 2], ["one_two", 2], ["hook_spin", 1], ["feint_kick", 1], ["knee", 2], ["tackle", 2]]],
		"cd": [40, 30], "near": 1.1, "far": 2.0, "engage": 2.2, "counter": ["dg_cross", 0.25],
		"phase2": {"dmg_k": 1.2, "cd_k": 0.65, "guard_add": 0.1, "counter_add": 0.15}},
	# 강만재(005-006): 느린 흉터 거구 · 하이가드(잘 막는다) — 큰 오른손 · 훅 · 긴 스트레이트 · 낮은 돌진 · 보디블로(숨이 막힌다)
	"manjae": {"patterns": {"swing": [["mj_swing", 0]], "hook_straight": [["mj_hook", 6], ["mj_straight", 0]], "rush": [["mj_rush", 0]],
			"body": [["mj_body", 0]], "swing_body": [["mj_swing", 6], ["mj_body", 0]]},
		"weights": [[["swing", 3], ["hook_straight", 2], ["rush", 2], ["body", 1], ["swing_body", 1]]], "cd": [70, 50],
		"near": 1.0, "far": 1.8, "engage": 2.0, "guard_add": 0.25},
	# 윤덕수(018-020): 큰 오른 훅 · 오른 스트레이트 · 얼굴 잡아 메치기 → 짓밟기. 2차(옆구리를 맞은 뒤)는 메치기를 더 자주 · 더 몰아친다
	"deoksu": {"patterns": {"hook": [["yd_hook", 0]], "jab_hook": [["yd_jab", 4], ["yd_hook", 0]], "straight": [["yd_straight", 0]],
			"one_two": [["yd_straight", 6], ["yd_hook", 0]], "stomp": [["yd_stomp", 0]], "grab": [["yd_grab", 6], ["yd_stomp", 0]],
			"hook_grab": [["yd_hook", 6], ["yd_grab", 6], ["yd_stomp", 0]]},
		"weights": [[["hook", 3], ["jab_hook", 2], ["straight", 2], ["one_two", 2], ["stomp", 1], ["grab", 1]],
			[["hook", 2], ["jab_hook", 2], ["one_two", 3], ["grab", 3], ["hook_grab", 2]]],
		"cd": [44, 34], "near": 1.1, "far": 2.0, "engage": 2.2, "phase2": {"dmg_k": 1.15, "cd_k": 0.7, "guard_add": 0.1}},
	# ---- 2장 하성 본사(S5 묶음 4) — canon fights p1:022-033(화/컷 · conf ai). 동작은 src/data/moves.gd(is_ · hs_ · hg_ · oj_ · hb_ ·
	# cs_ · jh_ · ng_ · st_). 칸은 0 · 1장과 같다(guard_add · counter · phase2.counter_add · kite)
	# 이슬(022 공사장 한 합 · 전국구 거구): 성큼 다가와 크게 뻗는 주먹 · 내려치는 주먹 · 붙잡아 후려 날리기(026/000-001)
	"iseul": {"patterns": {"punch": [["is_punch", 0]], "hook_punch": [["is_hook", 6], ["is_punch", 0]], "hammer": [["is_hammer", 0]],
			"throw": [["is_throw", 0]], "hook_hammer": [["is_hook", 8], ["is_hammer", 0]]},
		"weights": [[["punch", 3], ["hook_punch", 2], ["hammer", 1], ["throw", 1], ["hook_hammer", 1]]], "cd": [60, 40],
		"near": 1.0, "far": 1.8, "engage": 2.1},
	# 하성 조직원(로비 · 024-028): 주먹 · 각목 · 칼 · 손도끼 — 정장 무리
	"haseong_suit": {"patterns": {"punch": [["hs_punch", 0]], "bat": [["hs_bat", 0]], "knife": [["hs_knife", 0]],
			"punch_knife": [["hs_punch", 8], ["hs_knife", 0]], "hatchet": [["hs_hatchet", 0]]},
		"weights": [[["punch", 2], ["bat", 2], ["knife", 2], ["punch_knife", 1], ["hatchet", 1]]], "cd": [80, 60],
		"near": 1.0, "far": 1.8, "engage": 2.0},
	# 특별 경호팀(대표실 앞 · 026/024-045): 칼 달려들기 · 휘두르기 · 덮쳐 붙잡기 — 정장보다 자주 · 빨리
	"haseong_guard": {"patterns": {"knife": [["hg_knife", 0]], "slash2": [["hg_slash", 6], ["hg_knife", 0]], "punch_slash": [["hg_punch", 6], ["hg_slash", 0]],
			"grab": [["hg_grab", 0]]},
		"weights": [[["knife", 3], ["slash2", 2], ["punch_slash", 2], ["grab", 1]]], "cd": [60, 50], "near": 1.0, "far": 1.9, "engage": 2.2},
	# 오지인(026/049-059 카타나 비서): 베기 · 되베기 · 찌르기 · 치마 뒤 단검(빨간 !) — 길을 내주는 체력은 장 표 yield_at
	"ojiin": {"patterns": {"slash2": [["oj_slash", 6], ["oj_slash2", 0]], "slash_thrust": [["oj_slash", 8], ["oj_thrust", 0]],
			"thrust": [["oj_thrust", 0]], "dagger": [["oj_dagger", 0]], "slash_dagger": [["oj_slash2", 6], ["oj_dagger", 0]]},
		"weights": [[["slash2", 3], ["slash_thrust", 2], ["thrust", 1], ["dagger", 1], ["slash_dagger", 1]]], "cd": [50, 40],
		"near": 1.3, "far": 2.3, "engage": 2.5},
	# 황보민철(026-027 두 칼): 돌진에 맞받아 얼굴 스치기(counter) · 내디딤 찌르기 · 치켜 내리찍기 · 두 칼. 2차(출혈 — 027/165-171
	# '시간 싸움이 불리') 왼다리 미끼 찌르기를 섞어 끝을 노린다
	"mincheol": {"patterns": {"lunge": [["hb_lunge", 0]], "twin": [["hb_twin", 6], ["hb_back", 0]], "chop": [["hb_chop", 0]],
			"back_lunge": [["hb_back", 6], ["hb_lunge", 0]], "bait": [["hb_bait", 0]], "twin_bait": [["hb_twin", 8], ["hb_bait", 0]]},
		"weights": [[["lunge", 3], ["twin", 3], ["chop", 2], ["back_lunge", 2]],
			[["twin", 3], ["back_lunge", 2], ["lunge", 2], ["bait", 2], ["twin_bait", 1], ["chop", 1]]],
		"cd": [46, 36], "near": 1.1, "far": 2.0, "engage": 2.3, "counter": ["hb_face", 0.15],
		"phase2": {"dmg_k": 1.1, "cd_k": 0.75, "guard_add": 0.05, "counter_add": 0.1}},
	# 강창석(칼잡이 2인자 — 013-019): 낮게 지나치며 베기 · 연속 찌르기 · 수평 베기 · 칼 쥔 채 하이킥
	"changseok": {"patterns": {"pass": [["cs_pass", 0]], "stab": [["cs_stab", 0]], "sweep": [["cs_sweep", 0]],
			"sweep_kick": [["cs_sweep", 6], ["cs_highkick", 0]], "pass_stab": [["cs_pass", 8], ["cs_stab", 0]]},
		"weights": [[["pass", 2], ["stab", 2], ["sweep", 2], ["sweep_kick", 1], ["pass_stab", 1]]], "cd": [70, 50],
		"near": 1.0, "far": 1.9, "engage": 2.1},
	# 김재훈(029 대표실 · 아주 약함 · 맨손 — 사용자 답 2026-11-06 '최하위, 맨손'. 원작 029 의 리볼버 연사는 뺐다): 헛스윙 · 밀치기
	"jaehoon": {"patterns": {"swing": [["jh_swing", 0]], "shove_swing": [["jh_shove", 8], ["jh_swing", 0]]},
		"weights": [[["swing", 2], ["shove_swing", 1]]], "cd": [100, 60], "near": 1.0, "far": 1.7, "engage": 1.9},
	# 남궁혁(024-030 너클): 기술 책 '너클 낀 주먹 카운터' — 치기 시작하면 자주 맞받는다(counter) · 하이가드. 연타 · 원 궤적 훅 ·
	# 휘두르는 발차기 · 날아차기 · 손목 잡고 무릎. 따돌리기 방(2장 6 — 쓰러뜨릴 수 없다)이라 2차는 없다
	"namgung": {"patterns": {"jab": [["ng_jab", 0]], "jab_hook": [["ng_jab", 4], ["ng_hook", 0]], "hook": [["ng_hook", 0]],
			"kick": [["ng_kick", 0]], "fly": [["ng_flykick", 0]], "knee": [["ng_knee", 0]], "kick_hook": [["ng_kick", 6], ["ng_hook", 0]]},
		"weights": [[["jab", 3], ["jab_hook", 3], ["hook", 2], ["kick", 2], ["fly", 1], ["knee", 1], ["kick_hook", 1]]],
		"cd": [40, 30], "near": 1.1, "far": 2.0, "engage": 2.3, "guard_add": 0.15, "counter": ["ng_counter", 0.4]},
	# 신태진(031-032 장도 · 쌍칼 · 권총): 1차 수평 베기 · 내려베기 · 낮은 휩쓸기 · 돌진 · 허수 · 코앞 권총.
	# 2차(복면을 벗음 032/020-031): 얼굴 찌르기 → 숨긴 두 번째 칼 · 쌍칼 밀어붙이기 · 올려 베기 · 권총 — 더 몰아친다
	"sintaejin": {"patterns": {"sweep": [["st_sweep", 0]], "sweep_drop": [["st_sweep", 8], ["st_drop", 0]], "low": [["st_low", 0]],
			"rush": [["st_rush", 0]], "feint": [["st_feint", 0]], "low_pistol": [["st_low", 6], ["st_pistol", 0]],
			"face_second": [["st_face", 4], ["st_second", 0]], "twin": [["st_twin", 0]], "twin_up": [["st_twin", 4], ["st_upslash", 0]],
			"pistol": [["st_pistol", 0]], "face_sweep": [["st_face", 6], ["st_sweep", 0]]},
		"weights": [[["sweep", 3], ["sweep_drop", 2], ["low", 2], ["rush", 2], ["feint", 1], ["low_pistol", 1]],
			[["face_second", 3], ["twin", 2], ["twin_up", 2], ["face_sweep", 2], ["rush", 1], ["pistol", 1], ["sweep_drop", 1]]],
		"cd": [38, 30], "near": 1.3, "far": 2.3, "engage": 2.5, "phase2": {"dmg_k": 1.15, "cd_k": 0.7, "guard_add": 0.1}},
	# ---- 3 ~ 13장 적 원형(x_ — 동작은 moves.gd x_). 이름 있는 적은 이 중 하나 + 장 표 ROLES(hp · dmg_k · phase2_at)로 가른다.
	# 2차 표(weights 둘째)는 phase2_at 이 있는 적만 쓴다
	"x_brawler": {"patterns": {"jab": [["x_jab", 0]], "one_two": [["x_jab", 4], ["x_straight", 0]], "hook": [["x_hook", 0]],
			"straight_hook": [["x_straight", 6], ["x_hook", 0]], "body": [["x_body", 0]], "rush": [["x_rush", 0]],
			"combo4": [["x_jab", 3], ["x_straight", 4], ["x_body", 6], ["x_hook", 0]]},
		"weights": [[["jab", 2], ["one_two", 3], ["hook", 2], ["straight_hook", 2], ["body", 1], ["rush", 1]],
			[["one_two", 2], ["straight_hook", 3], ["combo4", 3], ["rush", 2], ["body", 1]]],
		"cd": [48, 36], "near": 1.1, "far": 2.0, "engage": 2.2, "phase2": {"dmg_k": 1.15, "cd_k": 0.7, "guard_add": 0.1}},
	"x_boxer": {"patterns": {"jab2": [["x_jab", 3], ["x_jab", 0]], "one_two": [["x_jab", 3], ["x_straight", 0]], "hook": [["x_hook", 0]],
			"body_hook": [["x_body", 4], ["x_hook", 0]], "combo4": [["x_jab", 3], ["x_straight", 4], ["x_body", 4], ["x_hook", 0]]},
		"weights": [[["jab2", 3], ["one_two", 3], ["hook", 2], ["body_hook", 1]], [["one_two", 2], ["body_hook", 2], ["combo4", 3], ["hook", 1]]],
		"cd": [36, 30], "near": 1.1, "far": 2.0, "engage": 2.2, "guard_add": 0.12, "counter": ["x_straight", 0.22],
		"phase2": {"dmg_k": 1.15, "cd_k": 0.7, "guard_add": 0.1, "counter_add": 0.1}},
	"x_kicker": {"patterns": {"front": [["x_frontkick", 0]], "round": [["x_roundkick", 0]], "jab_round": [["x_jab", 4], ["x_roundkick", 0]],
			"spin": [["x_spinkick", 0]], "fly": [["x_flykick", 0]], "front_spin": [["x_frontkick", 6], ["x_spinkick", 0]]},
		"weights": [[["front", 3], ["round", 2], ["jab_round", 2], ["spin", 1], ["fly", 1]],
			[["round", 2], ["jab_round", 2], ["front_spin", 3], ["spin", 2], ["fly", 2]]],
		"cd": [44, 34], "near": 1.2, "far": 2.2, "engage": 2.4, "phase2": {"dmg_k": 1.15, "cd_k": 0.7, "guard_add": 0.1}},
	"x_grappler": {"patterns": {"hammer": [["x_hammer", 0]], "shoulder": [["x_shoulder", 0]], "grab": [["x_grab", 0]],
			"hook_grab": [["x_hook", 6], ["x_grab", 0]], "hammer2": [["x_hammer", 8], ["x_hammer", 0]]},
		"weights": [[["hammer", 3], ["shoulder", 2], ["grab", 1], ["hook_grab", 1]], [["hammer2", 2], ["shoulder", 2], ["grab", 2], ["hook_grab", 3]]],
		"cd": [56, 40], "near": 1.0, "far": 1.9, "engage": 2.1, "guard_add": 0.1, "phase2": {"dmg_k": 1.2, "cd_k": 0.7, "guard_add": 0.1}},
	"x_blade": {"patterns": {"cut2": [["x_cut", 6], ["x_cut2", 0]], "stab": [["x_stab", 0]], "cut_stab": [["x_cut", 8], ["x_stab", 0]],
			"lunge": [["x_lunge", 0]], "cut3": [["x_cut", 5], ["x_cut2", 6], ["x_stab", 0]]},
		"weights": [[["cut2", 3], ["stab", 2], ["cut_stab", 2], ["lunge", 1]], [["cut3", 3], ["cut_stab", 2], ["lunge", 2], ["stab", 1]]],
		"cd": [44, 34], "near": 1.3, "far": 2.3, "engage": 2.5, "phase2": {"dmg_k": 1.15, "cd_k": 0.7, "guard_add": 0.1}},
	"x_twin": {"patterns": {"twin": [["x_twin", 0]], "cross": [["x_cross", 0]], "twin_cross": [["x_twin", 4], ["x_cross", 0]],
			"cut_cross": [["x_cut", 6], ["x_cross", 0]], "lunge": [["x_lunge", 0]]},
		"weights": [[["twin", 3], ["cross", 2], ["cut_cross", 2], ["lunge", 1]], [["twin_cross", 3], ["cut_cross", 2], ["lunge", 2], ["twin", 1]]],
		"cd": [40, 32], "near": 1.2, "far": 2.2, "engage": 2.4, "phase2": {"dmg_k": 1.15, "cd_k": 0.7, "guard_add": 0.1}},
	"x_axe": {"patterns": {"swing": [["x_swing", 0]], "chop": [["x_chop", 0]], "swing_chop": [["x_swing", 6], ["x_chop", 0]],
			"overhead": [["x_overhead", 0]], "kick_chop": [["x_frontkick", 6], ["x_chop", 0]]},
		"weights": [[["swing", 3], ["chop", 2], ["swing_chop", 2], ["overhead", 1]], [["swing_chop", 3], ["overhead", 2], ["kick_chop", 2], ["chop", 1]]],
		"cd": [52, 38], "near": 1.2, "far": 2.2, "engage": 2.4, "phase2": {"dmg_k": 1.2, "cd_k": 0.7, "guard_add": 0.1}},
	"x_karambit": {"patterns": {"kara": [["x_kara", 0]], "spin": [["x_kara_spin", 0]], "kara_kick": [["x_kara", 4], ["x_frontkick", 0]],
			"lunge": [["x_lunge", 0]], "kara2": [["x_kara", 4], ["x_kara_spin", 0]]},
		"weights": [[["kara", 3], ["spin", 1], ["kara_kick", 2], ["lunge", 1]], [["kara2", 3], ["kara_kick", 2], ["lunge", 2], ["spin", 1]]],
		"cd": [36, 30], "near": 1.0, "far": 2.0, "engage": 2.2, "phase2": {"dmg_k": 1.15, "cd_k": 0.7, "guard_add": 0.1}},
	# 큰 보스(내성 · 톱 — 구스타프 · 리천 · 그롤라 · 유우성 · 마학영): 주먹 · 발 · 잡기를 섞고 맞받는다. gun 은 권총을 쥔 보스(거리 두면 쏜다)
	"x_master": {"patterns": {"one_two": [["x_jab", 3], ["x_straight", 0]], "hook": [["x_hook", 0]], "round": [["x_roundkick", 0]],
			"grab": [["x_grab", 0]], "spin": [["x_spinkick", 0]], "combo": [["x_jab", 3], ["x_body", 4], ["x_hook", 6], ["x_spinkick", 0]],
			"rush_grab": [["x_rush", 6], ["x_grab", 0]], "hook_round": [["x_hook", 4], ["x_roundkick", 0]]},
		"weights": [[["one_two", 3], ["hook", 2], ["round", 2], ["grab", 1], ["spin", 1], ["hook_round", 1]],
			[["combo", 3], ["rush_grab", 2], ["hook_round", 2], ["spin", 2], ["grab", 2], ["one_two", 1]]],
		"cd": [34, 28], "near": 1.1, "far": 2.1, "engage": 2.3, "guard_add": 0.15, "counter": ["x_straight", 0.25],
		"phase2": {"dmg_k": 1.2, "cd_k": 0.65, "guard_add": 0.1, "counter_add": 0.1}},
	"x_swordmaster": {"patterns": {"cut3": [["x_cut", 5], ["x_cut2", 6], ["x_stab", 0]], "cross": [["x_cross", 0]], "twin": [["x_twin", 0]],
			"lunge": [["x_lunge", 0]], "overhead": [["x_overhead", 0]], "cut_lunge": [["x_cut", 6], ["x_lunge", 0]],
			"twin_cross": [["x_twin", 4], ["x_cross", 0]]},
		"weights": [[["cut3", 3], ["cross", 2], ["twin", 2], ["lunge", 1], ["overhead", 1]],
			[["twin_cross", 3], ["cut_lunge", 2], ["overhead", 2], ["cut3", 2], ["lunge", 1]]],
		"cd": [34, 28], "near": 1.3, "far": 2.3, "engage": 2.5, "guard_add": 0.12, "phase2": {"dmg_k": 1.2, "cd_k": 0.65, "guard_add": 0.1}},
	"x_gun": {"patterns": {"one_two": [["x_jab", 3], ["x_straight", 0]], "hook": [["x_hook", 0]], "grab": [["x_grab", 0]],
			"stab": [["x_stab", 0]], "combo": [["x_jab", 3], ["x_body", 4], ["x_grab", 0]], "rush": [["x_rush", 0]]},
		"weights": [[["one_two", 3], ["hook", 2], ["stab", 2], ["grab", 1]], [["combo", 3], ["rush", 2], ["grab", 2], ["hook", 1], ["stab", 1]]],
		"cd": [36, 30], "near": 1.1, "far": 2.1, "engage": 2.3, "guard_add": 0.15, "ranged": ["t_shot", 2.6, 6.5, 240],
		"phase2": {"dmg_k": 1.2, "cd_k": 0.65, "guard_add": 0.1}},
}

var me
var foe
var rng: RandomNumberGenerator
var prof: Dictionary
var guard_rate := 0.3
var cd_k := 1.0                 # 공격 사이 쉬는 시간 배율(난이도 — src/data/difficulty.gd foe_cd)
var queue: Array = []
var wait := 0
var cooldown := 60
var guard_hold := 0
var seen_attack := ""
var ranged_cd := 0
var strafe := 1.0
var strafe_t := 0
var phase := 1
var counter_rate := 0.0          # 맞받아 치는 확률(프로필 counter — 0 · 1장 김대건)
var kite := false                # 총잡이(프로필 kite): 주먹 차례가 와도 다가가지 않고 거리를 둔다 — 붙으면 그때 친다


func _init(enemy, profile_id: String, r: RandomNumberGenerator, guard := 0.3) -> void:
	me = enemy
	prof = PROFILES.get(profile_id, PROFILES["guard"])     # 표에 없는 프로필은 경호원(시험 test_campaign 이 장 표의 ai 가 다 있는지 본다)
	rng = r
	guard_rate = minf(0.85, guard + float(prof.get("guard_add", 0.0)))     # guard_add: 하이가드(강만재) — 없으면 능력치 그대로
	if prof.has("counter"):
		counter_rate = float(prof["counter"][1])
	cooldown = 40 + rng.randi_range(0, 60)                  # 여럿이 같은 박자로 시작하지 않게
	ranged_cd = 90 + rng.randi_range(0, 120)
	kite = bool(prof.get("kite", false))
	if kite:
		ranged_cd = int(ranged_cd / 3.0)                   # 총잡이는 첫 발이 빠르다(들어서자 겨눈다 — 002/013-015)


func busy() -> bool:
	if not me.alive() or me.inert:
		return false                                   # 쓰러진 사람의 남은 패턴은 차례를 붙잡지 않는다
	return not queue.is_empty() or me.state == "attack"


func decide(target, may_attack: bool) -> Dictionary:
	foe = target
	var it := {"move": Vector2.ZERO}
	if foe == null or not me.alive() or not foe.alive() or me.inert:
		return it
	it["face"] = me.dir_to(foe)
	if me.phase == 2 and phase == 1:
		_enter_phase2()
	var d: float = me.dist_to(foe)
	if ranged_cd > 0:
		ranged_cd -= 1
	if guard_hold > 0:
		guard_hold -= 1
		it["parry_held"] = true
		return it
	if not me.can_act():
		return it
	# 1. 상대가 나를 향해 치기 시작하면(2프레임 안) 기술 확률로 막는다
	var key := "%d:%d" % [foe.get_instance_id(), foe.attack_id]
	if foe.state == "attack" and foe.t <= 2 and key != seen_attack and d < 2.6 and foe.facing.dot(foe.dir_to(me)) > 0.5:
		seen_attack = key
		if rng.randf() < guard_rate:
			it["parry"] = true
			it["parry_held"] = true
			guard_hold = Fighter.PARRY_MIN + 4
			queue.clear()
			return it
		# 막지 않으면 맞받아 친다(크로스 카운터 — 프로필 counter 가 있는 사람만, 판이 준 차례 안에서)
		if counter_rate > 0.0 and may_attack and d < float(prof["engage"]) and rng.randf() < counter_rate:
			queue.clear()
			it["use"] = str(prof["counter"][0])
			return it
	# 2. 패턴 이어 가기
	if not queue.is_empty():
		if wait > 0:
			wait -= 1
			it["move"] = it["face"] * 0.35 if d > float(prof["near"]) + 0.2 else Vector2.ZERO
			return it
		var step: Array = queue.pop_front()
		it["use"] = step[0]
		wait = int(step[1])
		return it
	# 3. 총: 떨어져 있으면 겨눠 쏜다(빨간 ! — 보고 구른다)
	if prof.has("ranged") and may_attack and ranged_cd == 0 and not foe.state in HELPLESS:
		var rg: Array = prof["ranged"]
		if d >= float(rg[1]) and d <= float(rg[2]):
			it["use"] = rg[0]
			ranged_cd = int(rg[3]) + rng.randi_range(0, 90)
			return it
	# 4. 쿨다운이 끝나고 차례(may_attack)면 패턴을 고른다
	cooldown -= 1
	if cooldown <= 0 and may_attack and d < float(prof["engage"]):
		_pick()
		return it
	# 5. 거리 조절 — 차례가 아니면 한 발 물러나 둘레를 돈다(포위)
	var to: Vector2 = it["face"]
	strafe_t -= 1
	if strafe_t <= 0:
		strafe = -strafe if rng.randf() < 0.5 else strafe
		strafe_t = 40 + rng.randi_range(0, 50)
	var far: float = float(prof["far"]) + (0.0 if may_attack else 1.0)
	var near: float = float(prof["near"]) + (0.0 if may_attack else 0.8)
	if d > far or (not kite and cooldown <= 0 and may_attack and d >= float(prof["engage"])):
		it["move"] = to * 0.6
	elif d < near:
		it["move"] = -to * 0.5
	else:
		it["move"] = Vector2(-to.y, to.x) * strafe * 0.4
	return it


func _enter_phase2() -> void:
	phase = 2
	var p2: Dictionary = prof.get("phase2", {})
	me.dmg_k *= float(p2.get("dmg_k", 1.0))
	guard_rate = minf(0.85, guard_rate + float(p2.get("guard_add", 0.0)))
	counter_rate = minf(0.85, counter_rate + float(p2.get("counter_add", 0.0)))
	queue.clear()
	cooldown = 30


func _pick() -> void:
	var tables: Array = prof["weights"]
	var table: Array = tables[mini(phase, tables.size()) - 1]
	var total := 0
	for row in table:
		total += int(row[1])
	var r := rng.randi_range(1, total)
	var name: String = table[0][0]
	for row in table:
		r -= int(row[1])
		if r <= 0:
			name = row[0]
			break
	queue = prof["patterns"][name].duplicate(true)
	wait = 0
	var cd: Array = prof["cd"]
	var k: float = float(prof.get("phase2", {}).get("cd_k", 1.0)) if phase == 2 else 1.0
	cooldown = int((int(cd[0]) + rng.randi_range(0, int(cd[1]))) * k * cd_k)
