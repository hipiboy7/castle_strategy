extends RefCounted
## [옮김] castle_M3D `src/view/poses.gd`(2c3e69b) — 바꾼 것: 없음. 설계: docs/C4_설계서_직접조작전투.md 6절 · 요구: FR-403
## 관절 각도 표 (도) — src/view/puppet3d.gd 가 읽는다. 새 자세는 표에 한 줄을 더하면 된다.
##
## 몸통(pelvis · spine · chest · head): Vector3(앞으로 숙임, 비틀기(+ 오른 어깨가 앞), 옆 기울기(+ 오른쪽))
## 팔 · 다리(sh_ · th_): Vector3(앞으로 듦, 가로 휘두름(+ 몸 앞쪽으로), 옆으로 벌림(+ 바깥)) — 왼쪽도 같은 뜻(인형이 뒤집는다)
## 팔꿈치(el_) · 무릎(kn_) · 발목(ft_): 굽힘 각도 하나, 손목(wr_): Vector3(굽힘, 비틀기, 꺾기)
## root_y · root_fwd: 골반 높이 · 앞 보정(m), spin: 몸 전체 돌기(+ 왼쪽으로), roll: 앞구르기, fall: 뒤로 넘어짐
## 공격 동작은 모양(Move.shape)마다 W(준비 끝) · S(타격) · F(회수) 세 자세 — 그 사이는 인형이 부드럽게 잇는다.

const NEUTRAL := {
	"pelvis": Vector3.ZERO, "spine": Vector3.ZERO, "chest": Vector3.ZERO, "head": Vector3.ZERO,
	"sh_r": Vector3(0, 0, 8), "sh_l": Vector3(0, 0, 8), "el_r": 10.0, "el_l": 10.0,
	"wr_r": Vector3.ZERO, "wr_l": Vector3.ZERO,
	"th_r": Vector3(0, 0, 3), "th_l": Vector3(0, 0, 3), "kn_r": 4.0, "kn_l": 4.0, "ft_r": 0.0, "ft_l": 0.0,
	"root_y": 0.0, "root_fwd": 0.0, "spin": 0.0, "roll": 0.0, "fall": 0.0,
}

# 김신 칼 자세: 오른손 칼(바로 쥠)을 앞으로, 왼손 칼(거꾸로 쥠)은 아래팔에 붙여 목 · 얼굴을 막는다. 오른발이 앞
const GUARD_KIM := {
	"pelvis": Vector3(6, 14, 0), "spine": Vector3(4, 4, 0), "chest": Vector3(4, 6, 0), "head": Vector3(-6, -22, 0),
	"sh_r": Vector3(48, 22, 14), "el_r": 78.0, "sh_l": Vector3(52, 38, 12), "el_l": 118.0,
	"th_r": Vector3(24, -4, 6), "kn_r": 30.0, "ft_r": -6.0, "th_l": Vector3(-16, 4, 10), "kn_l": 26.0, "ft_l": 12.0,
}
# 백도찬: 오른손 사시미를 허리 앞에 낮게, 왼손은 빈손으로 가슴 앞(손등 받기 손)
const GUARD_BAEK := {
	"pelvis": Vector3(4, 16, 0), "spine": Vector3(2, 4, 0), "chest": Vector3(2, 6, 0), "head": Vector3(-4, -24, 0),
	"sh_r": Vector3(30, 14, 16), "el_r": 64.0, "sh_l": Vector3(46, 40, 10), "el_l": 104.0,
	"th_r": Vector3(22, -4, 6), "kn_r": 24.0, "ft_r": -6.0, "th_l": Vector3(-14, 4, 10), "kn_l": 22.0, "ft_l": 10.0,
}

# 맨주먹(피우진 · 구일화 · 경호원): 두 주먹을 턱 앞에, 왼발이 앞
const GUARD_BOX := {
	"pelvis": Vector3(6, 18, 0), "spine": Vector3(4, 4, 0), "chest": Vector3(6, 8, 0), "head": Vector3(-2, -24, 0),
	"sh_r": Vector3(36, 26, 22), "el_r": 128.0, "sh_l": Vector3(52, 34, 16), "el_l": 120.0,
	"th_r": Vector3(-14, -4, 8), "kn_r": 26.0, "ft_r": 10.0, "th_l": Vector3(22, 4, 6), "kn_l": 28.0, "ft_l": -6.0,
}
# 긴 칼(신겐 · 하야부사): 오른손 칼을 비스듬히 앞으로 낮게, 왼손은 비우거나 단도
const GUARD_LONG := {
	"pelvis": Vector3(6, 20, 0), "spine": Vector3(4, 4, 0), "chest": Vector3(4, 10, 0), "head": Vector3(-4, -28, 0),
	"sh_r": Vector3(40, 30, 12), "el_r": 50.0, "wr_r": Vector3(-30, 0, 0), "sh_l": Vector3(36, 30, 14), "el_l": 96.0,
	"th_r": Vector3(24, -4, 6), "kn_r": 28.0, "ft_r": -6.0, "th_l": Vector3(-18, 4, 10), "kn_l": 24.0, "ft_l": 12.0,
}

const LUNGE_LEGS := {"th_r": Vector3(40, -4, 6), "kn_r": 48.0, "ft_r": -10.0, "th_l": Vector3(-28, 4, 9), "kn_l": 14.0,
	"ft_l": 16.0}

const SHAPES := {
	# 오른손 바로 베기: 오른쪽 뒤 → 왼쪽 앞
	"slash": {
		"W": {"pelvis": Vector3(5, -18, 0), "chest": Vector3(6, -24, 0), "head": Vector3(-4, 30, 0),
			"sh_r": Vector3(34, -48, 80), "el_r": 72.0, "sh_l": Vector3(46, 44, 12), "el_l": 112.0},
		"S": {"pelvis": Vector3(10, 22, 0), "chest": Vector3(10, 28, 0), "head": Vector3(-6, -38, 0),
			"sh_r": Vector3(28, 76, 84), "el_r": 16.0, "root_fwd": 0.08},
		"F": {"pelvis": Vector3(12, 30, 0), "chest": Vector3(12, 42, 0), "head": Vector3(-6, -52, 0),
			"sh_r": Vector3(20, 116, 62), "el_r": 40.0, "root_fwd": 0.08},
	},
	# 왼손 거꾸로 쥔 칼로 되베기 (김신 쌍칼): 왼쪽 뒤 → 오른쪽 앞
	"slash_back_L": {
		"W": {"pelvis": Vector3(5, 20, 0), "chest": Vector3(6, 28, 0), "head": Vector3(-4, -36, 0),
			"sh_l": Vector3(34, -42, 78), "el_l": 82.0, "sh_r": Vector3(42, 30, 16), "el_r": 92.0},
		"S": {"pelvis": Vector3(10, -20, 0), "chest": Vector3(10, -30, 0), "head": Vector3(-6, 36, 0),
			"sh_l": Vector3(28, 76, 86), "el_l": 22.0, "root_fwd": 0.08},
		"F": {"pelvis": Vector3(12, -28, 0), "chest": Vector3(12, -40, 0), "head": Vector3(-6, 48, 0),
			"sh_l": Vector3(20, 112, 60), "el_l": 44.0, "root_fwd": 0.08},
	},
	# 오른손 손등 쪽으로 되베기 (백도찬): 왼쪽 → 오른쪽
	"slash_back_R": {
		"W": {"pelvis": Vector3(5, 24, 0), "chest": Vector3(6, 32, 0), "head": Vector3(-4, -42, 0),
			"sh_r": Vector3(40, 104, 56), "el_r": 88.0},
		"S": {"pelvis": Vector3(10, -14, 0), "chest": Vector3(10, -22, 0), "head": Vector3(-6, 26, 0),
			"sh_r": Vector3(32, 18, 86), "el_r": 14.0, "root_fwd": 0.08},
		"F": {"pelvis": Vector3(10, -24, 0), "chest": Vector3(10, -34, 0), "head": Vector3(-6, 40, 0),
			"sh_r": Vector3(28, -36, 76), "el_r": 26.0, "root_fwd": 0.08},
	},
	"thrust": {
		"W": {"pelvis": Vector3(2, -22, 0), "chest": Vector3(2, -26, 0), "head": Vector3(-4, 34, 0),
			"sh_r": Vector3(-6, -10, 26), "el_r": 116.0, "wr_r": Vector3(-20, 0, 0), "sh_l": Vector3(56, 44, 10),
			"el_l": 106.0, "th_r": Vector3(18, -4, 6), "kn_r": 36.0, "th_l": Vector3(-12, 4, 10), "kn_l": 32.0},
		"S": {"pelvis": Vector3(14, 18, 0), "chest": Vector3(12, 24, 0), "head": Vector3(-10, -30, 0),
			"sh_r": Vector3(84, 12, 6), "el_r": 4.0, "wr_r": Vector3(-30, 0, 0), "sh_l": Vector3(28, 10, 26),
			"el_l": 62.0, "th_r": Vector3(50, -4, 6), "kn_r": 60.0, "th_l": Vector3(-34, 4, 8), "kn_l": 8.0,
			"root_fwd": 0.16},
		"F": {"pelvis": Vector3(12, 14, 0), "chest": Vector3(10, 18, 0), "head": Vector3(-8, -24, 0),
			"sh_r": Vector3(70, 10, 8), "el_r": 22.0, "th_r": Vector3(44, -4, 6), "kn_r": 52.0,
			"th_l": Vector3(-30, 4, 8), "kn_l": 10.0, "root_fwd": 0.12},
	},
	# 엇박 찌르기 (엇엇박도) — 찌르는 오른팔과 오른다리가 같은 쪽으로 깊고 길게 쭉 뻗는다(펜싱 런지처럼). 뒷다리는 곧게,
	# 왼팔은 뒤로 균형. 준비(W)는 뒷다리에 무게를 싣고 칼을 허리 옆으로 당겨 몸을 감는다 (폰 리뷰 3차 2026-10-27)
	"offbeat": {
		"W": {"pelvis": Vector3(4, -30, 0), "chest": Vector3(4, -30, 0), "head": Vector3(-4, 50, 0),
			"sh_r": Vector3(-14, -14, 24), "el_r": 124.0, "wr_r": Vector3(-20, 0, 0), "sh_l": Vector3(50, 40, 12),
			"el_l": 100.0, "th_r": Vector3(12, -4, 6), "kn_r": 44.0, "th_l": Vector3(-8, 4, 10), "kn_l": 46.0},
		"S": {"pelvis": Vector3(22, 34, 0), "spine": Vector3(6, 0, 0), "chest": Vector3(12, 22, 0), "head": Vector3(-20, -52, 0),
			"sh_r": Vector3(88, 4, 2), "el_r": 0.0, "wr_r": Vector3(-24, 0, 0), "sh_l": Vector3(-36, -10, 46), "el_l": 18.0,
			"th_r": Vector3(74, -4, 6), "kn_r": 84.0, "ft_r": -16.0, "th_l": Vector3(-52, 4, 8), "kn_l": 2.0, "ft_l": 28.0,
			"root_fwd": 0.42},
		"F": {"pelvis": Vector3(20, 30, 0), "chest": Vector3(10, 20, 0), "head": Vector3(-18, -46, 0),
			"sh_r": Vector3(80, 4, 4), "el_r": 12.0, "th_r": Vector3(68, -4, 6), "kn_r": 78.0,
			"th_l": Vector3(-48, 4, 8), "kn_l": 6.0, "root_fwd": 0.38},
	},
	# 반대발 엇박 — 디딤발을 바꿔 왼발이 앞, 오른팔로 몸을 가로질러 짧게 찌른다. 엇박보다 작고 빨리 돌아온다
	"offbeat_rev": {
		"W": {"pelvis": Vector3(2, -12, 0), "chest": Vector3(2, -16, 0), "head": Vector3(-4, 24, 0),
			"sh_r": Vector3(0, -8, 24), "el_r": 110.0, "th_r": Vector3(14, -4, 6), "kn_r": 36.0,
			"th_l": Vector3(-10, 4, 10), "kn_l": 34.0},
		"S": {"pelvis": Vector3(10, -14, 0), "chest": Vector3(8, 30, 0), "head": Vector3(-8, -14, 0),
			"sh_r": Vector3(84, 14, 6), "el_r": 6.0, "wr_r": Vector3(-20, 0, 0), "sh_l": Vector3(20, 10, 30), "el_l": 70.0,
			"th_l": Vector3(46, 4, 8), "kn_l": 52.0, "ft_l": -10.0, "th_r": Vector3(-30, -4, 6), "kn_r": 10.0, "ft_r": 16.0,
			"root_fwd": 0.2},
		"F": {"pelvis": Vector3(8, -12, 0), "chest": Vector3(8, 22, 0), "head": Vector3(-6, -10, 0),
			"sh_r": Vector3(66, 10, 8), "el_r": 24.0, "th_l": Vector3(40, 4, 8), "kn_l": 46.0,
			"th_r": Vector3(-26, -4, 6), "kn_r": 12.0, "root_fwd": 0.16},
	},
	# 백도찬식 찌르기 — 낮게 깊이 파고들어 급소
	"thrust_low": {
		"W": {"pelvis": Vector3(16, -26, 0), "chest": Vector3(10, -20, 0), "head": Vector3(-10, 30, 0),
			"sh_r": Vector3(-10, -16, 26), "el_r": 120.0, "kn_r": 56.0, "kn_l": 54.0, "th_r": Vector3(34, -4, 6),
			"th_l": Vector3(-8, 4, 10)},
		"S": {"pelvis": Vector3(30, 16, 0), "chest": Vector3(20, 20, 0), "head": Vector3(-26, -26, 0),
			"sh_r": Vector3(56, 10, 6), "el_r": 4.0, "wr_r": Vector3(-48, 0, 0), "th_r": Vector3(64, -4, 6),
			"kn_r": 88.0, "th_l": Vector3(-38, 4, 8), "kn_l": 24.0, "root_fwd": 0.28},
		"F": {"pelvis": Vector3(26, 12, 0), "chest": Vector3(16, 16, 0), "head": Vector3(-20, -20, 0),
			"sh_r": Vector3(48, 8, 10), "el_r": 20.0, "th_r": Vector3(58, -4, 6), "kn_r": 80.0,
			"th_l": Vector3(-34, 4, 8), "kn_l": 22.0, "root_fwd": 0.24},
	},
	# 백도찬식 옆차기: (발구르며 달려나감은 인형이 따로) → 무릎 접기(W) → 옆으로 곧게(S). 몸은 90도 돌아 오른 허리가 상대 쪽
	"sidekick": {
		"W": {"spin": 86.0, "pelvis": Vector3(-8, 0, -6), "chest": Vector3(-4, 0, -4), "head": Vector3(0, -80, 0),
			"th_r": Vector3(84, 0, 22), "kn_r": 118.0, "ft_r": 30.0, "th_l": Vector3(-4, 0, 6), "kn_l": 24.0,
			"sh_r": Vector3(22, 20, 40), "el_r": 64.0, "sh_l": Vector3(42, 50, 20), "el_l": 120.0},
		"S": {"spin": 92.0, "pelvis": Vector3(0, 0, -30), "chest": Vector3(0, 0, -12), "head": Vector3(0, -84, 6),
			"th_r": Vector3(6, 0, 90), "kn_r": 2.0, "ft_r": 0.0, "th_l": Vector3(0, 0, 10), "kn_l": 18.0,
			"sh_r": Vector3(8, 0, 72), "el_r": 18.0, "sh_l": Vector3(40, 44, 20), "el_l": 118.0},
		"F": {"spin": 80.0, "pelvis": Vector3(-6, 0, -12), "chest": Vector3(-2, 0, -6), "head": Vector3(0, -70, 0),
			"th_r": Vector3(70, 0, 30), "kn_r": 100.0, "th_l": Vector3(-2, 0, 6), "kn_l": 22.0,
			"sh_r": Vector3(22, 20, 40), "el_r": 64.0, "sh_l": Vector3(42, 50, 20), "el_l": 120.0},
	},
	# 살아있는 건 전부 죽여라 — 낮게 웅크렸다(W) 칼을 뻗고 세 바퀴(S) 도는 원형 난도질
	"spin": {
		"W": {"pelvis": Vector3(22, -50, 0), "chest": Vector3(12, -30, 0), "head": Vector3(-12, 60, 0),
			"sh_r": Vector3(12, -64, 70), "el_r": 30.0, "sh_l": Vector3(40, 50, 20), "el_l": 100.0,
			"kn_r": 58.0, "kn_l": 56.0, "th_r": Vector3(36, -4, 10), "th_l": Vector3(-6, 4, 14)},
		"S": {"pelvis": Vector3(10, 0, 0), "chest": Vector3(6, 0, 0), "head": Vector3(-4, 0, 0),
			"sh_r": Vector3(6, 0, 92), "el_r": 6.0, "sh_l": Vector3(6, 0, 86), "el_l": 12.0,
			"kn_r": 34.0, "kn_l": 30.0, "th_r": Vector3(20, -4, 12), "th_l": Vector3(-10, 4, 14)},
		"F": {"pelvis": Vector3(6, 10, 0), "chest": Vector3(4, 10, 0), "sh_r": Vector3(14, 30, 70), "el_r": 30.0,
			"sh_l": Vector3(30, 40, 30), "el_l": 80.0},
	},
	# 각법 — 오른 다리를 머리 위까지 곧게 들어 올렸다가(W) 바닥까지 내려찍는다(S). 몸은 크게 젖혔다가 앞으로 접히고,
	# 디딤 무릎이 깊이 굽는다. 두 팔은 옆으로 넓게 균형 (폰 리뷰 3차: 동작을 더 크게)
	"axe": {
		"W": {"pelvis": Vector3(-22, 8, 0), "spine": Vector3(-10, 0, 0), "chest": Vector3(-12, 4, 0), "head": Vector3(18, -10, 0),
			"th_r": Vector3(176, -6, 4), "kn_r": 0.0, "ft_r": -30.0, "th_l": Vector3(-8, 4, 6), "kn_l": 22.0, "ft_l": 10.0,
			"sh_r": Vector3(30, -30, 80), "el_r": 30.0, "sh_l": Vector3(40, 20, 76), "el_l": 40.0},
		"S": {"pelvis": Vector3(30, 8, 0), "spine": Vector3(10, 0, 0), "chest": Vector3(20, 4, 0), "head": Vector3(-24, -10, 0),
			"th_r": Vector3(24, -4, 6), "kn_r": 4.0, "ft_r": -8.0, "th_l": Vector3(-24, 4, 6), "kn_l": 70.0, "ft_l": 20.0,
			"sh_r": Vector3(-10, -10, 56), "el_r": 30.0, "sh_l": Vector3(0, 20, 54), "el_l": 40.0, "root_fwd": 0.2},
		"F": {"pelvis": Vector3(24, 8, 0), "chest": Vector3(16, 4, 0), "head": Vector3(-18, -10, 0),
			"th_r": Vector3(26, -4, 6), "kn_r": 40.0, "th_l": Vector3(-22, 4, 8), "kn_l": 50.0, "root_fwd": 0.16},
	},
	# 주먹 (리천식 삼연타 — 인형이 한 대마다 오른손 · 왼손을 번갈아 내지른다). 몸통을 크게 비틀고 한 발씩 내딛는다
	"punch": {
		"W": {"pelvis": Vector3(6, -30, 0), "chest": Vector3(6, -34, 0), "head": Vector3(-6, 44, 0),
			"sh_r": Vector3(24, -14, 18), "el_r": 130.0, "sh_l": Vector3(54, 30, 12), "el_l": 108.0,
			"th_r": Vector3(16, -4, 6), "kn_r": 40.0},
		"S": {"pelvis": Vector3(12, 32, 0), "chest": Vector3(10, 36, 0), "head": Vector3(-10, -50, 0),
			"sh_r": Vector3(90, 8, 2), "el_r": 0.0, "th_r": Vector3(46, -4, 6), "kn_r": 56.0, "th_l": Vector3(-30, 4, 8),
			"kn_l": 12.0, "root_fwd": 0.2},
		"F": {"sh_r": Vector3(64, 10, 10), "el_r": 40.0},
	},
	# 총(경호대 최후의 4인): 오른팔을 곧게 뻗어 겨눈다 — 왼손 총은 인형이 좌우로 뒤집는다(shot_L)
	"shot": {
		"W": {"pelvis": Vector3(2, -24, 0), "chest": Vector3(2, -28, 0), "head": Vector3(-4, 30, 0),
			"sh_r": Vector3(86, 6, 4), "el_r": 4.0, "wr_r": Vector3(-40, 0, 0)},
		"S": {"pelvis": Vector3(-2, -24, 0), "chest": Vector3(-6, -28, 0), "head": Vector3(-2, 30, 0),
			"sh_r": Vector3(98, 6, 4), "el_r": 10.0, "wr_r": Vector3(-60, 0, 0)},
		"F": {"sh_r": Vector3(80, 6, 6), "el_r": 20.0, "wr_r": Vector3(-30, 0, 0)},
	},
	# 제압 — 두 칼을 높이 엇갈려 들었다가 X 자로 내리벤다
	"cross": {
		"W": {"pelvis": Vector3(-6, 0, 0), "chest": Vector3(-8, 0, 0), "head": Vector3(-6, 0, 0),
			"sh_r": Vector3(150, 34, 22), "el_r": 52.0, "sh_l": Vector3(150, 34, 22), "el_l": 52.0,
			"kn_r": 30.0, "kn_l": 30.0},
		"S": {"pelvis": Vector3(26, 0, 0), "chest": Vector3(16, 0, 0), "head": Vector3(-14, 0, 0),
			"sh_r": Vector3(42, -56, 70), "el_r": 10.0, "sh_l": Vector3(42, -56, 70), "el_l": 10.0,
			"th_r": Vector3(46, -4, 6), "kn_r": 62.0, "th_l": Vector3(-30, 4, 8), "kn_l": 10.0, "root_fwd": 0.22},
		"F": {"pelvis": Vector3(22, 0, 0), "chest": Vector3(14, 0, 0), "head": Vector3(-12, 0, 0),
			"sh_r": Vector3(30, -60, 64), "el_r": 20.0, "sh_l": Vector3(30, -60, 64), "el_l": 20.0,
			"th_r": Vector3(44, -4, 6), "kn_r": 58.0, "th_l": Vector3(-28, 4, 8), "kn_l": 12.0, "root_fwd": 0.2},
	},
}

# 막기(쳐내기 자세): 두 아래팔을 얼굴 앞에 세운다 / 쳐내기 성공: 칼을 바깥으로 튕겨 낸다
const PARRY := {"pelvis": Vector3(6, 6, 0), "chest": Vector3(6, 8, 0), "head": Vector3(-8, -12, 0),
	"sh_r": Vector3(76, 44, 12), "el_r": 102.0, "sh_l": Vector3(74, 46, 12), "el_l": 104.0, "kn_r": 32.0, "kn_l": 30.0}
const FLICK := {"chest": Vector3(6, -16, 0), "sh_r": Vector3(62, -12, 58), "el_r": 32.0, "sh_l": Vector3(60, 30, 20),
	"el_l": 100.0}
# 쳐내기 당함(휘청): 칼 든 팔이 위 뒤로 튕기고 몸이 젖혀진다
const RECOIL := {"pelvis": Vector3(-14, -14, 0), "chest": Vector3(-12, -20, 0), "head": Vector3(16, 20, 0),
	"sh_r": Vector3(122, -40, 60), "el_r": 32.0, "sh_l": Vector3(20, 0, 40), "el_l": 40.0,
	"th_r": Vector3(-8, 0, 6), "kn_r": 22.0, "th_l": Vector3(10, 0, 8), "kn_l": 26.0}
const HURT := {"pelvis": Vector3(-12, 0, 0), "chest": Vector3(-16, 10, 0), "head": Vector3(22, 0, 0),
	"sh_r": Vector3(-14, 0, 34), "el_r": 30.0, "sh_l": Vector3(-14, 0, 34), "el_l": 30.0, "kn_r": 18.0, "kn_l": 18.0}
# 기절: 무릎이 풀려 몸이 늘어진다 (인형이 흔든다)
const STUN := {"pelvis": Vector3(10, 0, 0), "chest": Vector3(14, 0, 0), "head": Vector3(26, 0, 14),
	"sh_r": Vector3(0, 0, 14), "el_r": 10.0, "sh_l": Vector3(0, 0, 14), "el_l": 10.0,
	"th_r": Vector3(18, 0, 6), "kn_r": 46.0, "th_l": Vector3(14, 0, 6), "kn_l": 44.0}
# 빈틈: 체간이 무너져 고개를 떨구고 휘청인다
const STAGGER := {"pelvis": Vector3(20, 0, 0), "chest": Vector3(18, 0, 0), "head": Vector3(30, 0, 0),
	"sh_r": Vector3(8, 10, 12), "el_r": 16.0, "sh_l": Vector3(8, 10, 12), "el_l": 16.0,
	"th_r": Vector3(12, 0, 6), "kn_r": 36.0, "th_l": Vector3(-6, 0, 6), "kn_l": 30.0}
# 앞구르기: 무릎을 가슴에 붙여 웅크린다 (돌기는 인형이)
const TUCK := {"pelvis": Vector3(40, 0, 0), "chest": Vector3(30, 0, 0), "head": Vector3(30, 0, 0),
	"sh_r": Vector3(64, 30, 10), "el_r": 112.0, "sh_l": Vector3(64, 30, 10), "el_l": 112.0,
	"th_r": Vector3(104, 0, 8), "kn_r": 124.0, "th_l": Vector3(104, 0, 8), "kn_l": 124.0}
# 넘어짐 · 쓰러짐: 등을 대고 눕는다 (넘어지는 각도는 인형이)
const LYING := {"head": Vector3(-14, 0, 0), "sh_r": Vector3(10, 0, 64), "el_r": 24.0, "sh_l": Vector3(10, 0, 58),
	"el_l": 30.0, "th_r": Vector3(8, 0, 10), "kn_r": 16.0, "th_l": Vector3(4, 0, 8), "kn_l": 22.0, "fall": 88.0}
# 이긴 자세 (결과 화면)
const VICTORY := {"pelvis": Vector3(2, 8, 0), "head": Vector3(-10, -10, 0), "sh_r": Vector3(10, 0, 18), "el_r": 20.0,
	"sh_l": Vector3(10, 0, 14), "el_l": 20.0, "kn_r": 6.0, "kn_l": 6.0}
