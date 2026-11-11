extends RefCounted
## [옮김] castle_M3D `src/data/moves.gd`(2c3e69b) — 바꾼 것: 기술 효과(2층)는 rules 인스턴스에서 · 사본 모음을 rules 마다. 설계: docs/C4_설계서_직접조작전투.md 4-1 · 요구: FR-401
## 기술 표 — 프레임(60프레임 = 1초) · 피해 · 체간 · 예고 · 거리는 3층(이 판 소유). 처음 값은 castle_M `castle_m/action/moves.py`
## (2026-10-26, castle_M 커밋 5ea02c3)에서 옮겼고 그 뒤 폰 리뷰로 바꿔 왔다. 거리(reach · radius · lunge · side)는 픽셀 단위
## 원본을 PX 로 미터로 바꾼다. 초안이라 김신 쌍칼 · 김신 기술 · 백도찬 사시미만 있다.
## 2층 효과(엇박 계열 피해 종류 lethal · 내 체력 self_cost · 각법 · 옆차기 기절 초)는 skill_id 로 공통 데이터
## (src/data/common.gd — castle_common skills.json effects)에서 읽는다 — 여기 다시 적지 않는다(S1 공통 받기).


const PX := 0.045                 # castle_M 1px → m (키 46px ≈ 1.8m 에서 몸 너비가 맞게 조금 크게)

const DEFAULTS := {
	"label": "", "startup": 4, "active": 3, "recovery": 10, "damage": 0.0,
	"reach": 14.0, "radius": 9.0, "arc": 0.0, "parryable": true, "knockback": 1.6,
	"hitstun": 16, "hitstop": 4, "knockdown": false, "posture": 10.0, "lunge": 0.0,
	"next": "", "cancel": -1, "telegraph": "", "shape": "slash", "sfx": "swing", "hit_sfx": "hit",
	"shake": 0, "hits": 1, "side": 0.0, "skill": false, "feints": [], "any_state": false, "hand": "R",      # hand: 치는 손 · 발 (R · L)
	"guard_break": false, "skill_id": "", "stun_3d": [], "fx": "", "whiff": 0, "brake": 0,
	"iframes": false, "unblock_top": "", "vs_high": [], "zigzag": false, "seq": [], "stance": 0, "stance_hit": "",
	# (rc.2 폰 피드백 묶음 B — 3D 덧붙임 기술, 2026-11-08) iframes: 판정이 끝날 때까지 무적 / unblock_top: 맞는 쪽 등급이 이 등급
	# 이하면 막기 · 쳐내기를 뚫는다 / (한 방 ko_rank 는 2층 — castle_common skills.json effects, common.skill_ko) /
	# vs_high: [등급, 배율] 맞는 쪽이 그 등급 이상이면 피해 · 체간 × 배율(등급 차로 깎이지도 않는다) / zigzag: side 를 한쪽 → 반대쪽 /
	# seq: 여러 대(hits)의 대마다 자세 모양(그림 — puppet3d) / stance: 준비 앞 이 프레임 동안 마주 본 공격을 받아 넘기고 stance_hit 로 맞받는다
	# guard_break: 막기 · 쳐내기를 뚫는다 / skill_id: castle_common skills.json 의 기술 id — get_move 가 effects 에서
	# lethal(엇박 계열 피해 종류, common lethal_fraction) · self_cost(맞혔을 때 쓴 사람이 잃는 체력 비율)를 채우고, 기절 초는
	# skills.gd stun_frames 가 common stun_sec 로 본다 / stun_3d: **3D 덧붙임** 기절 프레임 [아랫급에게, 같은 급 · 윗급에게] —
	# common 에 기절이 없는 기술에만(엇박 계열 · 삼연타 셋째 대, 폰 리뷰 2 · 3차에 3D 에서 먼저 시험 — castle_common_요청 1 ~ 4행)
	# whiff: 아무도 못 맞히면 회수에 더하는 프레임(헛친 큰 동작) / brake: 엇엇박 브레이크가 걸리는 프레임(그때부터 판정 직전까지 버틴다)
	# fx "triple": 리천식 삼연타 — 맞은 순서를 세어 셋째에 크게, 기절은 셋째 대만 (world.gd)
}

const M := {
	# 김신 — 쌍단검(거버 Mark II). 빠른 베기 2번 → 찌르기. 둘째 베기는 왼손 역수 칼(그림만)
	"k_slash1": {"label": "베기", "startup": 4, "active": 3, "recovery": 10, "damage": 7, "reach": 13, "radius": 10,
		"arc": 70, "lunge": 3, "next": "k_slash2", "cancel": 8, "posture": 8, "shape": "slash", "sfx": "swing"},
	"k_slash2": {"label": "되베기", "startup": 4, "active": 3, "recovery": 11, "damage": 7, "reach": 13, "radius": 10,
		"arc": 70, "lunge": 3, "next": "k_thrust", "cancel": 8, "posture": 8, "shape": "slash_back", "sfx": "swing",
		"hand": "L"},
	"k_thrust": {"label": "찌르기", "startup": 6, "active": 4, "recovery": 16, "damage": 12, "reach": 18, "radius": 8,
		"lunge": 8, "knockback": 3.2, "hitstop": 7, "posture": 18, "shape": "thrust", "sfx": "slash",
		"hit_sfx": "hit_heavy", "shake": 3},
	# 아무르 티그로 대시(rc.2 폰 묶음 B): 빠르게 낮게 내달리며 찌른다 — 대시 버튼 + 공격(달리다 공격해도 같다)
	"k_dash": {"label": "아무르 티그로 대시", "startup": 4, "active": 6, "recovery": 14, "damage": 13, "reach": 16, "radius": 9,
		"lunge": 36, "knockback": 3.8, "hitstop": 7, "posture": 18, "shape": "thrust_low", "sfx": "slash",
		"hit_sfx": "hit_heavy", "shake": 3},
	"k_counter": {"label": "반격 베기", "startup": 2, "active": 3, "recovery": 10, "damage": 15, "reach": 15, "radius": 11,
		"arc": 80, "lunge": 6, "posture": 24, "hitstop": 7, "shape": "slash", "sfx": "slash", "hit_sfx": "hit_heavy",
		"shake": 2},
	"k_finisher": {"label": "제압", "startup": 3, "active": 4, "recovery": 18, "damage": 40, "reach": 16, "radius": 10,
		"lunge": 8, "knockback": 4.0, "hitstop": 16, "posture": 0, "shape": "cross", "sfx": "slash",
		"hit_sfx": "hit_heavy", "shake": 6},
	# ---- rc.2 폰 피드백 묶음 B(사용자 2026-11-07) — 3D 덧붙임 기술(1층 이름은 addendum.gd SKILLS · castle_common 요청)
	# 아무르 티그로 3연타: 하복부에 주먹 세 대('쾅, 쾅, 쾅') — 셋째 대에 0.5초 기절, 외성 하위 이상에게 큰 타격(× 1.6)
	"s_amur3": {"label": "아무르 티그로 3연타", "startup": 4, "active": 15, "recovery": 14, "damage": 9, "reach": 13, "radius": 9,
		"arc": 60, "lunge": 8, "knockback": 0.6, "hitstop": 9, "posture": 16, "hits": 3, "shape": "punch", "sfx": "kick",
		"hit_sfx": "hit_heavy", "shake": 4, "skill": true, "skill_id": "amur_triple", "fx": "amur3",
		"vs_high": ["외성 하위", 1.6], "seq": ["punch", "punch_L", "punch"]},
	# 아무르 티그로 위빙: 상체를 흔들어 공격을 다 흘리며(무적) 세 대 — 외성 상위 이하는 한 방
	"s_weave": {"label": "아무르 티그로 위빙", "startup": 6, "active": 18, "recovery": 12, "damage": 10, "reach": 13, "radius": 10,
		"arc": 70, "lunge": 10, "knockback": 1.4, "hitstop": 7, "posture": 14, "hits": 3, "shape": "punch", "sfx": "swing",
		"hit_sfx": "hit_heavy", "shake": 3, "skill": true, "skill_id": "amur_weaving", "iframes": true,
		"seq": ["punch_L", "punch", "punch_L"]},
	# 좌우로 사라지는 스텝(castle_common vanish_step): 무적으로 좌우로 비켜 들며 두 번 찌른다 — 내성 중위 이하는 못 막는다
	"s_vanish": {"label": "좌우로 사라지는 스텝", "startup": 12, "active": 10, "recovery": 12, "damage": 11, "reach": 15, "radius": 9,
		"lunge": 10, "side": 16, "zigzag": true, "hits": 2, "knockback": 1.8, "hitstop": 6, "posture": 16, "shape": "thrust",
		"sfx": "slash", "hit_sfx": "hit_heavy", "shake": 2, "skill": true, "skill_id": "vanish_step", "iframes": true,
		"unblock_top": "내성 중위", "seq": ["thrust", "thrust"]},
	# 서진태 오리지널: 오른손으로 왼쪽 · 왼손으로 오른쪽 · 오른손으로 찌르기 — 외성 하위 이하 한 방
	"s_jt_original": {"label": "서진태 오리지널", "startup": 4, "active": 18, "recovery": 14, "damage": 10, "reach": 14, "radius": 10,
		"arc": 90, "lunge": 10, "knockback": 1.6, "hitstop": 6, "posture": 14, "hits": 3, "shape": "slash", "sfx": "slash",
		"hit_sfx": "hit_heavy", "shake": 3, "skill": true, "skill_id": "jin_original",
		"seq": ["slash", "slash_back_L", "thrust"]},
	# 근거리 급소 베기: 붙어 있을 때 빠르게 — 짧은 사거리 · 큰 체간
	"s_jt_vital": {"label": "근거리 급소 베기", "startup": 2, "active": 3, "recovery": 10, "damage": 16, "reach": 9, "radius": 10,
		"arc": 90, "lunge": 2, "knockback": 2.2, "hitstop": 8, "posture": 26, "shape": "slash_back", "hand": "L", "sfx": "knife",
		"hit_sfx": "hit_heavy", "shake": 2, "skill": true, "skill_id": "jintae_vital"},
	# 서진태 난무: 제자리에서 돌며 가까이 있는 사람을 모두 벤다(세 바퀴)
	"s_jt_storm": {"label": "서진태 난무", "startup": 8, "active": 21, "recovery": 16, "damage": 9, "reach": 0, "radius": 30,
		"knockback": 2.4, "hitstop": 5, "posture": 12, "hits": 3, "shape": "spin", "sfx": "slash", "hit_sfx": "hit_heavy",
		"shake": 4, "skill": true, "skill_id": "jintae_storm"},
	# 피우진 미친 코어 카운터: 몸을 낮춰 받을 자세(stance) — 그 사이 마주 본 공격이 오면 흘리고 코어로 강하게 맞받아 1초 기절.
	# 아무것도 안 오면 짧게 한 대만 내지른다
	"s_wj_core": {"label": "미친 코어 카운터", "startup": 20, "active": 3, "recovery": 12, "damage": 10, "reach": 12, "radius": 9,
		"lunge": 4, "knockback": 2.0, "hitstop": 6, "posture": 14, "shape": "punch", "sfx": "swing", "hit_sfx": "hit_heavy",
		"skill": true, "skill_id": "woojin_core_counter", "stance": 18, "stance_hit": "s_wj_core_hit", "stun_off": true},
	"s_wj_core_hit": {"label": "미친 코어 카운터", "startup": 2, "active": 4, "recovery": 14, "damage": 22, "reach": 13, "radius": 10,
		"arc": 70, "lunge": 8, "knockback": 5.0, "hitstop": 14, "posture": 30, "shape": "punch", "sfx": "kick", "hit_sfx": "hit_heavy",
		"shake": 6, "skill": true, "skill_id": "woojin_core_counter", "parryable": false},     # 기절 1초 = 공통 stun_rel_sec
	# 김신 · 백도찬 기술 (src/data/skills.gd — 김신은 게이지를 쓴다). 엇박 계열은 막기 · 쳐내기를 뚫고, 맞으면 기절,
	# 헛치면(whiff) 큰 동작 그대로 잠시 멈춰 역공을 받는다 — 폰 리뷰 3차(2026-10-27), 3D 초안에서 먼저 시험
	# 엇박 찌르기: 한 박자 멈칫(잔상)한 뒤 찌르는 팔 · 다리가 같은 쪽으로 깊고 길게 쭉 뻗는다
	"s_offbeat": {"label": "엇박 찌르기", "startup": 16, "active": 4, "recovery": 18, "damage": 16, "reach": 19,
		"radius": 9, "lunge": 26, "knockback": 4.2, "hitstop": 10, "posture": 45, "guard_break": true,
		"shape": "offbeat", "sfx": "knife", "hit_sfx": "hit_heavy", "shake": 4, "skill": true, "skill_id": "offbeat",
		"feints": [6], "telegraph": "unblock", "stun_3d": [90, 60], "whiff": 30},
	# 엇엇박 찌르기: 엇박처럼 나가다 브레이크(brake 프레임) — 온몸에 부하가 걸린 채 반 박자 버티다 쭉 찌른다.
	# 게이지 전부, 피해는 쓴 칸에 비례, 맞히면 내 체력 1/5. 엇박 · 반대발 엇박과 부딪히면 무조건 이긴다(world.gd)
	"s_offbeat2": {"label": "엇엇박 찌르기", "startup": 26, "active": 5, "recovery": 18, "damage": 26, "reach": 21,
		"radius": 10, "lunge": 30, "knockback": 5.0, "hitstop": 14, "posture": 80, "guard_break": true,
		"shape": "offbeat", "sfx": "knife", "hit_sfx": "hit_heavy", "shake": 6, "skill": true, "skill_id": "offbeat2",
		"brake": 10, "telegraph": "unblock", "stun_3d": [120, 90], "whiff": 36},
	# 반대발 엇박: 디딤발을 바꿔(왼발 앞) 작게 찌른다 — 피해 · 기절이 적은 대신 회수가 짧고 헛쳐도 멈추지 않는다
	"s_offbeat_rev": {"label": "반대발 엇박 찌르기", "startup": 13, "active": 4, "recovery": 9, "damage": 14,
		"reach": 18, "radius": 9, "lunge": 16, "side": 6, "knockback": 3.0, "hitstop": 8, "posture": 30,
		"guard_break": true, "shape": "offbeat_rev", "sfx": "knife", "hit_sfx": "hit_heavy", "shake": 2, "skill": true,
		"skill_id": "offbeat_rev", "feints": [5], "telegraph": "unblock", "stun_3d": [40, 24]},
	# 각법: 다리를 머리 위까지 곧게 들어 올렸다가 바닥까지 내려찍는다 — 기절은 common kickarts stun_rel_sec(아랫급 3초 · 같은 급 · 윗급 1초)
	"s_kick": {"label": "각법 — 내려찍기", "startup": 14, "active": 3, "recovery": 16, "damage": 12, "reach": 13,
		"radius": 10, "lunge": 6, "knockback": 0.8, "hitstop": 12, "posture": 22, "shape": "axe", "sfx": "kick",
		"hit_sfx": "hit_heavy", "shake": 7, "skill": true, "skill_id": "kickarts"},
	# 리천식 삼연타: 주먹 세 번(빠르게 — 판정 12프레임에 세 대) — 앞 두 대는 붙잡아 두고(넉백 작게) 셋째에 크게,
	# 셋째 대에 각법의 절반만큼 기절 (기절은 3D 초안에서 먼저 — 폰 리뷰 2026-10-26, castle_M 반영은 그쪽 세션)
	"s_triple": {"label": "리천식 삼연타", "startup": 3, "active": 12, "recovery": 14, "damage": 7, "reach": 14,
		"radius": 9, "arc": 60, "lunge": 8, "knockback": 0.5, "hitstop": 6, "posture": 12, "hits": 3, "shape": "punch",
		"sfx": "swing", "hit_sfx": "hit", "skill": true, "skill_id": "triple", "fx": "triple", "stun_3d": [90, 30]},
	# 보스 — 백도찬 (사시미 나이프 파이팅). 패턴 · 박자는 src/combat/boss_ai.gd (castle_M P2 설계서 8.2절)
	"b_slash1": {"label": "사시미 베기", "startup": 14, "active": 3, "recovery": 10, "damage": 9, "reach": 14, "radius": 10,
		"arc": 70, "lunge": 5, "posture": 10, "telegraph": "parry", "shape": "slash", "sfx": "knife"},
	"b_slash2": {"label": "되베기", "startup": 9, "active": 3, "recovery": 10, "damage": 9, "reach": 14, "radius": 10,
		"arc": 70, "lunge": 5, "posture": 10, "telegraph": "parry", "shape": "slash_back", "sfx": "knife"},
	"b_slash2_off": {"label": "엇박 되베기", "startup": 19, "active": 3, "recovery": 10, "damage": 10, "reach": 14,
		"radius": 10, "arc": 70, "lunge": 5, "posture": 12, "telegraph": "parry", "shape": "slash_back", "sfx": "knife",
		"feints": [9]},
	"b_thrust": {"label": "사시미 찌르기", "startup": 16, "active": 4, "recovery": 16, "damage": 12, "reach": 18, "radius": 8,
		"lunge": 12, "knockback": 3.2, "hitstop": 7, "posture": 16, "telegraph": "parry", "shape": "thrust",
		"sfx": "slash", "hit_sfx": "hit_heavy", "shake": 2},
	"b_step_l": {"label": "스텝 베기", "startup": 18, "active": 3, "recovery": 12, "damage": 10, "reach": 14, "radius": 10,
		"arc": 80, "lunge": 6, "side": 18, "posture": 12, "telegraph": "parry", "shape": "slash", "sfx": "knife"},
	"b_step_r": {"label": "스텝 베기", "startup": 18, "active": 3, "recovery": 12, "damage": 10, "reach": 14, "radius": 10,
		"arc": 80, "lunge": 6, "side": -18, "posture": 12, "telegraph": "parry", "shape": "slash", "sfx": "knife"},
	"b_counter": {"label": "맞받아 베기", "startup": 14, "active": 3, "recovery": 14, "damage": 11, "reach": 15,
		"radius": 10, "arc": 80, "lunge": 6, "posture": 14, "telegraph": "parry", "shape": "slash", "sfx": "slash",
		"hit_sfx": "hit_heavy"},
	"b_sidekick": {"label": "백도찬식 옆차기", "startup": 20, "active": 3, "recovery": 16, "damage": 10, "reach": 14,
		"radius": 9, "lunge": 30, "knockback": 5.5, "hitstop": 8, "posture": 20, "telegraph": "parry",
		"shape": "sidekick", "sfx": "kick", "hit_sfx": "hit_heavy", "shake": 3, "skill": true, "skill_id": "baek_sidekick"},
	"b_vital": {"label": "백도찬식 찌르기", "startup": 10, "active": 3, "recovery": 18, "damage": 22, "reach": 18,
		"radius": 7, "lunge": 14, "parryable": false, "knockback": 4.2, "hitstop": 12, "posture": 30,
		"telegraph": "unblock", "shape": "thrust_low", "sfx": "slash", "hit_sfx": "hit_heavy", "shake": 5,
		"skill": true, "skill_id": "baek_vital", "any_state": true},
	"b_wide": {"label": "살아있는 건 전부 죽여라", "startup": 30, "active": 10, "recovery": 26, "damage": 14, "reach": 0,
		"radius": 34, "parryable": false, "hits": 3, "knockback": 4.0, "hitstop": 6, "posture": 0,
		"telegraph": "unblock", "shape": "spin", "sfx": "wind", "hit_sfx": "hit_heavy", "shake": 4, "skill": true,
		"skill_id": "baek_wide"},
	# ---- 11장 호텔 캐슬 (S2, 2026-11-06) — 처음 값은 이 판이 정했다(봇 판 · 판 길이로 조정 — 무정지 규칙 6).
	# 기술 id · 원작 위치는 src/data/addendum.gd(3D 덧붙임 1층). 거리 단위는 위와 같다(PX). shape 는 인형 자세(src/view/poses.gd)
	# 피우진 — 맨주먹(원작 '남궁혁을 끝낸 주먹'). 잽 → 스트레이트 → 훅. 칼날 쳐내기는 못 한다(막기만)
	"w_jab": {"label": "잽", "startup": 4, "active": 3, "recovery": 9, "damage": 6, "reach": 12, "radius": 9,
		"lunge": 3, "next": "w_straight", "cancel": 7, "posture": 7, "shape": "punch", "sfx": "swing"},
	"w_straight": {"label": "스트레이트", "startup": 5, "active": 3, "recovery": 11, "damage": 8, "reach": 13, "radius": 9,
		"lunge": 5, "next": "w_hook", "cancel": 8, "posture": 10, "shape": "punch", "sfx": "swing", "hand": "L"},
	"w_hook": {"label": "훅", "startup": 7, "active": 4, "recovery": 15, "damage": 12, "reach": 12, "radius": 11,
		"arc": 90, "lunge": 4, "knockback": 3.4, "hitstop": 7, "posture": 18, "shape": "punch", "sfx": "kick",
		"hit_sfx": "hit_heavy", "shake": 2},
	"w_dash": {"label": "돌진 주먹", "startup": 6, "active": 5, "recovery": 14, "damage": 11, "reach": 14, "radius": 9,
		"lunge": 26, "knockback": 3.8, "hitstop": 6, "posture": 16, "shape": "punch", "sfx": "swing", "hit_sfx": "hit_heavy"},
	"w_finisher": {"label": "마무리 주먹", "startup": 4, "active": 4, "recovery": 18, "damage": 34, "reach": 14, "radius": 10,
		"lunge": 8, "knockback": 4.6, "hitstop": 16, "posture": 0, "shape": "punch", "sfx": "kick", "hit_sfx": "hit_heavy",
		"shake": 6},
	# 구일화 — 주먹 · 팔꿈치(057 중앙홀 난전). 아군 AI 로만 나온다
	"gu_jab": {"label": "주먹", "startup": 5, "active": 3, "recovery": 11, "damage": 7, "reach": 12, "radius": 9,
		"lunge": 4, "next": "gu_elbow", "cancel": 8, "posture": 9, "shape": "punch", "sfx": "swing"},
	"gu_elbow": {"label": "팔꿈치", "startup": 6, "active": 3, "recovery": 14, "damage": 10, "reach": 11, "radius": 10,
		"arc": 80, "lunge": 4, "knockback": 2.8, "posture": 14, "shape": "punch", "sfx": "kick", "hand": "L",
		"hit_sfx": "hit_heavy"},
	"gu_dash": {"label": "돌진", "startup": 6, "active": 5, "recovery": 14, "damage": 10, "reach": 13, "radius": 10,
		"lunge": 24, "knockback": 3.6, "posture": 16, "shape": "punch", "sfx": "swing", "hit_sfx": "hit_heavy"},
	"gu_finisher": {"label": "내리꽂기", "startup": 4, "active": 4, "recovery": 18, "damage": 30, "reach": 14, "radius": 10,
		"lunge": 6, "knockback": 4.4, "hitstop": 14, "posture": 0, "shape": "punch", "sfx": "kick", "hit_sfx": "hit_heavy",
		"shake": 5},
	"s_gu_headbutt": {"label": "들이받기", "startup": 12, "active": 4, "recovery": 16, "damage": 14, "reach": 13,
		"radius": 10, "lunge": 26, "knockback": 5.0, "hitstop": 10, "posture": 26, "shape": "thrust", "sfx": "kick",
		"hit_sfx": "hit_heavy", "shake": 4, "skill": true, "skill_id": "guilhwa_headbutt", "stun_3d": [60, 30]},
	"s_gu_forearm": {"label": "팔뚝 연타", "startup": 4, "active": 12, "recovery": 14, "damage": 6, "reach": 13,
		"radius": 10, "arc": 70, "lunge": 8, "knockback": 0.6, "hitstop": 5, "posture": 12, "hits": 3, "shape": "punch",
		"sfx": "swing", "skill": true, "skill_id": "guilhwa_forearm"},
	# 캐슬 경호원(엑스트라) — 곤봉 · 주먹
	"c_baton": {"label": "곤봉", "startup": 15, "active": 3, "recovery": 12, "damage": 8, "reach": 14, "radius": 10,
		"arc": 70, "lunge": 5, "posture": 10, "telegraph": "parry", "shape": "slash", "sfx": "swing"},
	"c_punch": {"label": "주먹", "startup": 13, "active": 3, "recovery": 12, "damage": 7, "reach": 12, "radius": 9,
		"lunge": 6, "posture": 9, "telegraph": "parry", "shape": "punch", "sfx": "swing"},
	# 경호대 최후의 4인 — 칼(오른손) · 권총(왼손). 기술은 마준영 기술의 전국구 하향(addendum.gd)
	"g4_slash": {"label": "칼 베기", "startup": 14, "active": 3, "recovery": 11, "damage": 9, "reach": 14, "radius": 10,
		"arc": 70, "lunge": 5, "posture": 10, "telegraph": "parry", "shape": "slash", "sfx": "knife"},
	"g4_thrust": {"label": "칼 찌르기", "startup": 15, "active": 4, "recovery": 14, "damage": 10, "reach": 17, "radius": 8,
		"lunge": 10, "knockback": 3.0, "posture": 14, "telegraph": "parry", "shape": "thrust", "sfx": "slash"},
	"s_g4_chop": {"label": "칼 내리찍기", "startup": 19, "active": 3, "recovery": 16, "damage": 13, "reach": 14,
		"radius": 10, "arc": 40, "lunge": 6, "knockback": 2.4, "hitstop": 8, "posture": 20, "telegraph": "parry",
		"shape": "slash", "sfx": "slash", "hit_sfx": "hit_heavy", "shake": 2, "skill": true, "skill_id": "g4_chop"},
	"s_g4_heel": {"label": "내려찍기 하이킥", "startup": 20, "active": 3, "recovery": 18, "damage": 12, "reach": 13,
		"radius": 10, "lunge": 6, "knockback": 1.0, "hitstop": 10, "posture": 18, "telegraph": "parry", "shape": "axe",
		"sfx": "kick", "hit_sfx": "hit_heavy", "shake": 4, "skill": true, "skill_id": "g4_heelkick", "stun_3d": [40, 20]},
	# 총: 겨누는 동안(startup) 빨간 ! — 보고 구른다. 선 판정(world.gd shape shot), 사거리 7m
	"t_shot": {"label": "근거리 사격", "startup": 28, "active": 2, "recovery": 18, "damage": 12, "reach": 155, "radius": 4,
		"parryable": false, "knockback": 2.0, "hitstop": 6, "posture": 12, "telegraph": "unblock", "shape": "shot",
		"sfx": "shot", "hit_sfx": "hit_heavy", "shake": 3, "skill": true, "skill_id": "g4_shot", "hand": "L"},
	# 하야부사 — 긴칼(카타나). 신겐보다 짧고 느리다(하향)
	"hy_slash1": {"label": "긴칼 베기", "startup": 13, "active": 3, "recovery": 11, "damage": 10, "reach": 20, "radius": 11,
		"arc": 80, "lunge": 6, "posture": 12, "telegraph": "parry", "shape": "slash", "sfx": "knife"},
	"hy_slash2": {"label": "되베기", "startup": 10, "active": 3, "recovery": 11, "damage": 10, "reach": 20, "radius": 11,
		"arc": 80, "lunge": 5, "posture": 12, "telegraph": "parry", "shape": "slash_back", "sfx": "knife"},
	"hy_thrust": {"label": "긴칼 찌르기", "startup": 15, "active": 4, "recovery": 15, "damage": 12, "reach": 24, "radius": 8,
		"lunge": 14, "knockback": 3.2, "hitstop": 7, "posture": 16, "telegraph": "parry", "shape": "thrust", "sfx": "slash",
		"hit_sfx": "hit_heavy", "shake": 2},
	"s_hy_arc": {"label": "하야부사식 큰 호 베기", "startup": 22, "active": 4, "recovery": 18, "damage": 17, "reach": 21,
		"radius": 13, "arc": 140, "lunge": 8, "knockback": 3.6, "hitstop": 9, "posture": 24, "telegraph": "parry",
		"shape": "slash", "sfx": "slash", "hit_sfx": "hit_heavy", "shake": 3, "skill": true, "skill_id": "hayabusa_arc"},
	"s_hy_low": {"label": "낮은 다리 베기", "startup": 15, "active": 3, "recovery": 18, "damage": 13, "reach": 18,
		"radius": 8, "lunge": 20, "parryable": false, "knockback": 2.4, "hitstop": 9, "posture": 20, "telegraph": "unblock",
		"shape": "thrust_low", "sfx": "slash", "hit_sfx": "hit_heavy", "shake": 3, "skill": true, "skill_id": "hayabusa_low"},
	# 사사키 신겐 — 대도(긴 칼 '대극') · 단도 · 발. 패턴은 boss 프로필(src/combat/enemy_ai.gd PROFILES shingen)
	"sg_slash1": {"label": "대도 베기", "startup": 15, "active": 4, "recovery": 12, "damage": 13, "reach": 23, "radius": 12,
		"arc": 90, "lunge": 7, "posture": 14, "telegraph": "parry", "shape": "slash", "sfx": "knife"},
	"sg_slash2": {"label": "대도 되베기", "startup": 10, "active": 4, "recovery": 12, "damage": 12, "reach": 23, "radius": 12,
		"arc": 90, "lunge": 6, "posture": 14, "telegraph": "parry", "shape": "slash_back", "sfx": "knife"},
	"sg_stab": {"label": "단도 찌르기", "startup": 12, "active": 3, "recovery": 13, "damage": 11, "reach": 15, "radius": 8,
		"lunge": 12, "knockback": 2.8, "posture": 14, "telegraph": "parry", "shape": "thrust", "sfx": "slash", "hand": "L"},
	"s_sg_daegeuk": {"label": "대극 큰 호 베기", "startup": 24, "active": 5, "recovery": 18, "damage": 24, "reach": 24,
		"radius": 14, "arc": 160, "lunge": 10, "knockback": 4.6, "hitstop": 11, "posture": 32, "telegraph": "parry",
		"shape": "slash", "sfx": "slash", "hit_sfx": "hit_heavy", "shake": 5, "skill": true, "skill_id": "shingen_daegeuk"},
	"s_sg_dive": {"label": "낮은 파고들기", "startup": 14, "active": 3, "recovery": 18, "damage": 18, "reach": 17,
		"radius": 8, "lunge": 30, "parryable": false, "knockback": 3.4, "hitstop": 10, "posture": 26, "telegraph": "unblock",
		"shape": "thrust_low", "sfx": "slash", "hit_sfx": "hit_heavy", "shake": 4, "skill": true, "skill_id": "shingen_dive",
		"hand": "L"},
	"s_sg_kick": {"label": "앞차기", "startup": 16, "active": 3, "recovery": 16, "damage": 11, "reach": 14, "radius": 10,
		"lunge": 18, "knockback": 6.5, "hitstop": 9, "posture": 22, "telegraph": "parry", "shape": "sidekick", "sfx": "kick",
		"hit_sfx": "hit_heavy", "shake": 4, "skill": true, "skill_id": "shingen_frontkick"},
	"s_sg_leap": {"label": "날아차기", "startup": 26, "active": 4, "recovery": 20, "damage": 20, "reach": 14, "radius": 11,
		"lunge": 44, "parryable": false, "knockback": 6.0, "hitstop": 12, "posture": 30, "telegraph": "unblock",
		"shape": "axe", "sfx": "kick", "hit_sfx": "hit_heavy", "shake": 6, "skill": true, "skill_id": "shingen_leap"},
	# ---- 0 · 1장(S5 묶음 2 · 3) — 1부 처음 김신은 맨손(p1:014/025-027 '너 정도엔 필요 없다'), 서진태는 아군 봇(1장 1 · 4 방).
	# 처음 값은 이 판이 정했다(봇 판 · 판 길이로 조정 — tests/sim_stage.gd ch0 · ch1). 원작 위치는 castle_common canon fights(화/컷).
	# 1부 처음 김신(내성 중위)은 이 장의 누구보다 여러 등급 위 — 보통 공격의 피해 · 체간이 몇 배로 들어가고(common rank_damage_k)
	# 아랫급의 보통 공격엔 움찔하지 않는다(shrugs_off). 그래서 보스는 넘어뜨리는(knockdown) · 숨 막히는(stun_3d) 큰 동작을 빨간 ! 로 낸다
	# 김신 맨손: 잽 → 주먹 → 턱 쳐 올리기 · 날아 차기 돌진 · 받아넘기며 치기 · 처박기
	"kf_jab": {"label": "잽", "startup": 4, "active": 3, "recovery": 9, "damage": 6, "reach": 12, "radius": 9,
		"lunge": 3, "next": "kf_jab2", "cancel": 7, "posture": 7, "shape": "punch", "sfx": "swing"},          # 014/027-030 파고들기
	"kf_jab2": {"label": "주먹", "startup": 4, "active": 3, "recovery": 10, "damage": 7, "reach": 13, "radius": 9,
		"lunge": 4, "next": "kf_upper", "cancel": 8, "posture": 9, "shape": "punch", "sfx": "swing", "hand": "L"},
	"kf_upper": {"label": "턱 쳐 올리기", "startup": 6, "active": 4, "recovery": 15, "damage": 12, "reach": 12, "radius": 10,
		"arc": 60, "lunge": 6, "knockback": 3.4, "hitstop": 7, "posture": 18, "shape": "punch", "sfx": "kick",
		"hit_sfx": "hit_heavy", "shake": 2},                                                                   # 002/016-017 · 014/027-030 어퍼컷
	"kf_dash": {"label": "날아 차기", "startup": 6, "active": 5, "recovery": 14, "damage": 11, "reach": 14, "radius": 9,
		"lunge": 28, "knockback": 3.8, "hitstop": 6, "posture": 16, "shape": "sidekick", "sfx": "kick", "hit_sfx": "hit_heavy"},   # 003/026-030 · 006/004-005
	"kf_counter": {"label": "받아넘기며 치기", "startup": 2, "active": 3, "recovery": 10, "damage": 15, "reach": 13, "radius": 11,
		"arc": 80, "lunge": 6, "posture": 24, "hitstop": 7, "shape": "punch", "sfx": "kick", "hit_sfx": "hit_heavy", "shake": 2},   # 014/027-030 ⑤ · 016/005-007 어깨로 흘리고 휘두르기
	"kf_finisher": {"label": "처박기", "startup": 3, "active": 4, "recovery": 18, "damage": 40, "reach": 14, "radius": 10,
		"lunge": 8, "knockback": 4.0, "hitstop": 16, "posture": 0, "shape": "punch", "sfx": "kick", "hit_sfx": "hit_heavy",
		"shake": 6},                                                                                           # 016/007 턱 밀어 메다꽂기 · 020/024-030 아스팔트에 처박기
	# 서진태(1장 아군) — 빠른 주먹 둘 → 하이킥(006/005-009 3연타 · 오른발 하이킥). 아군 AI 로만 나온다
	"j_jab": {"label": "주먹", "startup": 4, "active": 3, "recovery": 8, "damage": 6, "reach": 12, "radius": 9,
		"lunge": 4, "next": "j_jab2", "cancel": 6, "posture": 7, "shape": "punch", "sfx": "swing"},
	"j_jab2": {"label": "주먹", "startup": 4, "active": 3, "recovery": 9, "damage": 6, "reach": 12, "radius": 9,
		"lunge": 4, "next": "j_kick", "cancel": 7, "posture": 8, "shape": "punch", "sfx": "swing", "hand": "L"},
	"j_kick": {"label": "하이킥", "startup": 7, "active": 4, "recovery": 15, "damage": 11, "reach": 14, "radius": 10,
		"arc": 70, "lunge": 4, "knockback": 3.4, "hitstop": 7, "posture": 16, "shape": "sidekick", "sfx": "kick",
		"hit_sfx": "hit_heavy", "shake": 2},
	"j_dash": {"label": "뛰어들어 치기", "startup": 6, "active": 5, "recovery": 14, "damage": 10, "reach": 14, "radius": 9,
		"lunge": 26, "knockback": 3.8, "hitstop": 6, "posture": 16, "shape": "punch", "sfx": "kick", "hit_sfx": "hit_heavy"},   # 006/005-007 대각선으로 뛰어들어
	"j_finisher": {"label": "내려찍기", "startup": 4, "active": 4, "recovery": 18, "damage": 30, "reach": 14, "radius": 10,
		"lunge": 8, "knockback": 4.6, "hitstop": 14, "posture": 0, "shape": "axe", "sfx": "kick", "hit_sfx": "hit_heavy",
		"shake": 5},
	# 엑스트라(m_) — 군터 경호원 · DS 조직원 · DS 습격조(건달급). 느리고 예고가 길다(0장 첫 방은 '싸움 익히기')
	"m_punch": {"label": "주먹", "startup": 14, "active": 3, "recovery": 12, "damage": 7, "reach": 12, "radius": 9,
		"lunge": 6, "posture": 9, "telegraph": "parry", "shape": "punch", "sfx": "swing"},
	"m_swing": {"label": "휘두르기", "startup": 17, "active": 3, "recovery": 14, "damage": 9, "reach": 13, "radius": 10,
		"arc": 90, "lunge": 5, "knockback": 2.4, "posture": 12, "telegraph": "parry", "shape": "punch", "sfx": "swing"},        # 005/016-017 크게 휘두르자(후웅)
	"m_knife": {"label": "칼 찌르기", "startup": 16, "active": 3, "recovery": 13, "damage": 9, "reach": 15, "radius": 8,
		"lunge": 10, "posture": 10, "telegraph": "parry", "shape": "thrust", "sfx": "knife"},                                  # 003/016-018 · 003/026-030 칼을 들고 덮침
	"m_pipe": {"label": "쇠파이프 내려치기", "startup": 17, "active": 3, "recovery": 14, "damage": 10, "reach": 16, "radius": 10,
		"arc": 60, "lunge": 5, "posture": 12, "telegraph": "parry", "shape": "slash", "sfx": "swing", "hit_sfx": "hit_heavy"},  # 003/042-045 배트 · 008/001-004 쇠파이프 · 방망이
	"m_pipe_back": {"label": "되휘두르기", "startup": 12, "active": 3, "recovery": 14, "damage": 8, "reach": 16, "radius": 10,
		"arc": 100, "lunge": 4, "posture": 10, "telegraph": "parry", "shape": "slash_back", "sfx": "swing"},                     # 008/001-004 머리 위로 지나가는 휘두르기
	"m_charge": {"label": "함성 돌진", "startup": 18, "active": 4, "recovery": 16, "damage": 10, "reach": 14, "radius": 10,
		"arc": 60, "lunge": 24, "knockback": 3.0, "posture": 12, "telegraph": "parry", "shape": "slash", "sfx": "swing"},       # 008/001-004 함성과 함께 정면 돌진
	"m_brute_hook": {"label": "거구 훅", "startup": 18, "active": 4, "recovery": 16, "damage": 12, "reach": 13, "radius": 11,
		"arc": 90, "lunge": 6, "knockback": 3.6, "hitstop": 7, "posture": 16, "telegraph": "parry", "shape": "punch", "sfx": "kick",
		"hit_sfx": "hit_heavy", "shake": 2},                                                                   # 002/013-015 포니테일 거구
	"m_brute_slam": {"label": "두 손 내려찍기", "startup": 26, "active": 4, "recovery": 22, "damage": 14, "reach": 13, "radius": 11,
		"arc": 40, "lunge": 8, "parryable": false, "knockdown": true, "knockback": 3.0, "hitstop": 10, "posture": 20,
		"telegraph": "unblock", "shape": "slash", "sfx": "swing", "hit_sfx": "hit_heavy", "shake": 4, "whiff": 20},
	# 총(선 판정 world.gd shape shot) — 겨누는 동안 빨간 ! (보고 구른다). 리볼버는 한 발, 우지는 네 발을 흩뿌린다
	"m_revolver": {"label": "리볼버", "startup": 30, "active": 2, "recovery": 20, "damage": 12, "reach": 150, "radius": 4,
		"parryable": false, "knockback": 2.0, "hitstop": 6, "posture": 12, "telegraph": "unblock", "shape": "shot",
		"sfx": "shot", "hit_sfx": "hit_heavy", "shake": 3},                                                    # 002/013-015 리볼버를 겨눈 대머리
	"m_uzi": {"label": "우지 난사", "startup": 26, "active": 16, "recovery": 18, "damage": 4, "reach": 140, "radius": 6,
		"parryable": false, "hits": 4, "knockback": 0.8, "hitstop": 3, "posture": 5, "telegraph": "unblock", "shape": "shot",
		"sfx": "shot", "hit_sfx": "hit", "shake": 2},                                                          # 002/013-017 권총과 우지를 난사(타타타타)
	# 군터(gt_, 0장 보스 · 조장급) — 거래를 거절당하자 탁자 밑 리볼버(002/021-028). 쏘는 게 거의 전부, 붙으면 발악
	"gt_revolver": {"label": "탁자 밑 리볼버", "startup": 34, "active": 2, "recovery": 22, "damage": 18, "reach": 150, "radius": 4,
		"parryable": false, "knockback": 3.0, "hitstop": 8, "posture": 18, "telegraph": "unblock", "shape": "shot",
		"sfx": "shot", "hit_sfx": "hit_heavy", "shake": 4, "skill": true},
	"gt_fan": {"label": "리볼버 연사", "startup": 28, "active": 12, "recovery": 22, "damage": 7, "reach": 150, "radius": 6,
		"parryable": false, "hits": 3, "knockback": 1.2, "hitstop": 4, "posture": 8, "telegraph": "unblock", "shape": "shot",
		"sfx": "shot", "hit_sfx": "hit_heavy", "shake": 3},
	"gt_swing": {"label": "발악 주먹", "startup": 15, "active": 3, "recovery": 14, "damage": 8, "reach": 12, "radius": 10,
		"arc": 80, "lunge": 5, "posture": 10, "telegraph": "parry", "shape": "punch", "sfx": "swing"},
	"gt_glass": {"label": "위스키 잔 휘두르기", "startup": 16, "active": 3, "recovery": 14, "damage": 9, "reach": 13, "radius": 10,
		"arc": 90, "lunge": 4, "posture": 10, "telegraph": "parry", "shape": "slash_back", "sfx": "knife", "hand": "L"},        # 002/021-028 팔이 움직이며 위스키 잔이 깨지고(까앙)
	"gt_point": {"label": "코앞 사격", "startup": 20, "active": 2, "recovery": 20, "damage": 14, "reach": 60, "radius": 5,
		"parryable": false, "knockback": 3.0, "hitstop": 8, "posture": 16, "telegraph": "unblock", "shape": "shot",
		"sfx": "shot", "hit_sfx": "hit_heavy", "shake": 4},
	# 김혁주(hj_, DS 부장 서열 4위 · 잭나이프 두 자루, 003/045-051) — '잭나이프는 큰 베기 무기가 아니다 → 첫 베기는 잽, 두 번째가 진짜'.
	# 첫 베기는 빠르고 가볍게(넓은 호), 두 번째는 칼을 치켜든 채 반 박자 멈칫(feints)한 뒤 무겁게 내려온다 — 일찍 누르면 빗나간다
	"hj_jab": {"label": "잭나이프 잽", "startup": 9, "active": 3, "recovery": 7, "damage": 5, "reach": 13, "radius": 10,
		"arc": 100, "lunge": 4, "posture": 6, "telegraph": "parry", "shape": "slash", "sfx": "knife"},
	"hj_real": {"label": "진짜 베기", "startup": 20, "active": 3, "recovery": 14, "damage": 14, "reach": 14, "radius": 10,
		"arc": 70, "lunge": 6, "posture": 16, "telegraph": "parry", "shape": "slash_back", "sfx": "slash", "hit_sfx": "hit_heavy",
		"shake": 2, "hand": "L", "feints": [8]},
	"hj_thrust": {"label": "잭나이프 찌르기", "startup": 14, "active": 3, "recovery": 14, "damage": 10, "reach": 16, "radius": 8,
		"lunge": 10, "knockback": 2.6, "posture": 12, "telegraph": "parry", "shape": "thrust", "sfx": "slash"},
	"hj_rush": {"label": "양손 잭나이프 돌진", "startup": 18, "active": 8, "recovery": 16, "damage": 7, "reach": 14, "radius": 10,
		"arc": 70, "lunge": 26, "hits": 2, "knockback": 1.6, "posture": 10, "telegraph": "parry", "shape": "slash", "sfx": "knife"},   # 003/045 '작업 들어온 거냐' 외치며 돌진
	# 김성준(sj_, 약에 취함 · 칼, 008-010) — 몰아치는 주먹 · 코트 휘두르기 · 멀리 날려 보내는 부츠 발차기 · 칼
	"sj_flurry": {"label": "주먹 연타", "startup": 10, "active": 12, "recovery": 14, "damage": 5, "reach": 13, "radius": 10,
		"arc": 60, "lunge": 10, "hits": 3, "knockback": 0.6, "hitstop": 4, "posture": 7, "telegraph": "parry", "shape": "punch",
		"sfx": "swing"},                                                                                       # 009/014-015 '재밌게 좀 해보라' 연타(퍽 퍽)
	"sj_coat": {"label": "코트 휘두르기", "startup": 16, "active": 4, "recovery": 14, "damage": 9, "reach": 14, "radius": 12,
		"arc": 140, "lunge": 4, "knockback": 2.0, "posture": 12, "telegraph": "parry", "shape": "slash", "sfx": "swing"},        # 008/004-007 '지루해 죽겠다' 코트 팔을 수평으로 크게
	"sj_kick": {"label": "부츠 발차기", "startup": 20, "active": 3, "recovery": 18, "damage": 15, "reach": 14, "radius": 10,
		"lunge": 14, "parryable": false, "knockdown": true, "knockback": 16.0, "hitstop": 12, "posture": 26, "telegraph": "unblock",
		"shape": "sidekick", "sfx": "kick", "hit_sfx": "hit_heavy", "shake": 6, "skill": true},                 # 008/004-007 머리 쪽 발차기 → 김신이 승합차에 처박힘
	"sj_upslash": {"label": "칼 베어 올리기", "startup": 15, "active": 3, "recovery": 14, "damage": 12, "reach": 15, "radius": 10,
		"arc": 80, "lunge": 6, "posture": 14, "telegraph": "parry", "shape": "slash_back", "sfx": "knife", "hand": "L"},        # 009/017-019 아래에서 위로 크게 베어 올림
	"sj_knife": {"label": "칼 크게 휘두르기", "startup": 19, "active": 3, "recovery": 16, "damage": 14, "reach": 15, "radius": 11,
		"arc": 120, "lunge": 8, "posture": 16, "telegraph": "parry", "shape": "slash", "sfx": "slash", "hit_sfx": "hit_heavy",
		"feints": [9]},                                                                                        # 010/001-002 정수로 쥔 칼을 치켜들었다가 크게 호
	# 김대건(dg_, 1장 보스 · 경호대급, 014-016) — 1차: 큰 직선 · 훅 · 크로스 카운터(치기 시작하면 맞받는다 — enemy_ai counter) ·
	# 뒷발 돌려차기 · 페인트 하이킥 · 낮은 미끄러지기 · 베어허그 태클. 2차('피떡이 돼야 시동' 015/042-048): 프로다운 연타 · 정권 · 날아 무릎
	"dg_straight": {"label": "큰 직선 주먹", "startup": 14, "active": 3, "recovery": 13, "damage": 12, "reach": 14, "radius": 9,
		"lunge": 10, "knockback": 3.0, "hitstop": 6, "posture": 14, "telegraph": "parry", "shape": "punch", "sfx": "swing",
		"hit_sfx": "hit_heavy"},                                                                               # 014/027-030 '팡'
	"dg_hook": {"label": "오른 훅", "startup": 17, "active": 4, "recovery": 16, "damage": 14, "reach": 13, "radius": 11,
		"arc": 100, "lunge": 6, "knockback": 3.6, "hitstop": 7, "posture": 18, "telegraph": "parry", "shape": "punch", "sfx": "kick",
		"hit_sfx": "hit_heavy", "shake": 2},                                                                   # 015/000 크게 휘두른 오른 훅(부웅)
	"dg_cross": {"label": "크로스 카운터", "startup": 7, "active": 3, "recovery": 14, "damage": 13, "reach": 14, "radius": 9,
		"lunge": 8, "knockback": 3.2, "hitstop": 8, "posture": 16, "telegraph": "parry", "shape": "punch", "sfx": "kick",
		"hit_sfx": "hit_heavy", "shake": 3, "hand": "L"},                                                      # 014/030-032 엇갈려 동시에 꽂힘
	"dg_spin": {"label": "뒷발 돌려차기", "startup": 20, "active": 4, "recovery": 18, "damage": 17, "reach": 15, "radius": 11,
		"arc": 120, "lunge": 8, "parryable": false, "knockdown": true, "knockback": 5.0, "hitstop": 11, "posture": 26,
		"telegraph": "unblock", "shape": "sidekick", "sfx": "kick", "hit_sfx": "hit_heavy", "shake": 5, "skill": true},  # 015/006-009 헛친 몸이 돈 그대로 뒷발
	"dg_highkick": {"label": "페인트 하이킥", "startup": 22, "active": 3, "recovery": 18, "damage": 16, "reach": 15, "radius": 10,
		"arc": 70, "lunge": 8, "knockdown": true, "knockback": 4.0, "hitstop": 10, "posture": 24, "telegraph": "parry",
		"shape": "sidekick", "sfx": "kick", "hit_sfx": "hit_heavy", "shake": 4, "feints": [8], "skill": true},  # 015/012-016 '걸렸다' 큰 주먹(속임) 뒤 디딤 하이킥
	"dg_slide": {"label": "낮게 미끄러져 들기", "startup": 16, "active": 4, "recovery": 20, "damage": 11, "reach": 16, "radius": 8,
		"lunge": 34, "parryable": false, "knockdown": true, "knockback": 3.0, "hitstop": 9, "posture": 20, "telegraph": "unblock",
		"shape": "thrust_low", "sfx": "kick", "hit_sfx": "hit_heavy", "shake": 3, "whiff": 16},              # 015/023-028 낮게 미끄러져 다리를 뻗어
	"dg_tackle": {"label": "베어허그 태클", "startup": 24, "active": 6, "recovery": 22, "damage": 18, "reach": 13, "radius": 11,
		"lunge": 44, "parryable": false, "guard_break": true, "knockdown": true, "knockback": 5.0, "hitstop": 14, "posture": 34,
		"telegraph": "unblock", "shape": "thrust", "sfx": "wind", "hit_sfx": "hit_heavy", "shake": 6, "skill": true, "whiff": 30},   # 015/029-036 허리를 껴안아 밀어붙임 — 빠져나오면 크게 빈다
	"dg_jab": {"label": "잽", "startup": 8, "active": 3, "recovery": 9, "damage": 7, "reach": 13, "radius": 9,
		"lunge": 5, "posture": 8, "telegraph": "parry", "shape": "punch", "sfx": "swing", "hand": "L"},        # 016/001-002 주먹 연타(프로다워짐)
	"dg_jeongkwon": {"label": "정권", "startup": 12, "active": 3, "recovery": 14, "damage": 16, "reach": 15, "radius": 9,
		"lunge": 12, "knockback": 5.0, "hitstop": 9, "posture": 22, "telegraph": "parry", "shape": "punch", "sfx": "kick",
		"hit_sfx": "hit_heavy", "shake": 4},                                                                   # 015/042-048 일어나 정권 — 김신이 밀려남
	"dg_knee": {"label": "날아 무릎", "startup": 22, "active": 4, "recovery": 20, "damage": 20, "reach": 14, "radius": 11,
		"lunge": 38, "parryable": false, "knockdown": true, "knockback": 5.0, "hitstop": 13, "posture": 30, "telegraph": "unblock",
		"shape": "axe", "sfx": "kick", "hit_sfx": "hit_heavy", "shake": 6, "skill": true, "whiff": 20},       # 016/004-005 몸을 날려 내리꽂는 무릎
	# 강만재(mj_, 흉터 거구 · 네임드, 005-006) — 느리고 맷집이 대단하다 · 하이가드 · 큰 오른손 · 긴 스트레이트 · 보디블로
	"mj_swing": {"label": "큰 오른손 휘두르기", "startup": 19, "active": 4, "recovery": 16, "damage": 12, "reach": 14, "radius": 12,
		"arc": 110, "lunge": 6, "knockback": 3.4, "hitstop": 7, "posture": 16, "telegraph": "parry", "shape": "punch", "sfx": "swing",
		"hit_sfx": "hit_heavy"},                                                                               # 006/005-007
	"mj_hook": {"label": "훅", "startup": 16, "active": 4, "recovery": 15, "damage": 11, "reach": 13, "radius": 11,
		"arc": 90, "lunge": 5, "knockback": 3.0, "posture": 14, "telegraph": "parry", "shape": "punch", "sfx": "kick", "hand": "L"},   # 006/008-009 크게 훅(후웅)
	"mj_straight": {"label": "긴 스트레이트", "startup": 14, "active": 3, "recovery": 14, "damage": 11, "reach": 17, "radius": 9,
		"lunge": 8, "knockback": 3.0, "posture": 14, "telegraph": "parry", "shape": "punch", "sfx": "swing"},  # 006/009-011
	"mj_rush": {"label": "낮은 돌진 주먹", "startup": 18, "active": 4, "recovery": 16, "damage": 12, "reach": 14, "radius": 10,
		"lunge": 26, "knockback": 3.4, "posture": 16, "telegraph": "parry", "shape": "punch", "sfx": "kick", "hit_sfx": "hit_heavy"},  # 006/009-011 낮게 돌진(착)
	"mj_body": {"label": "보디블로", "startup": 22, "active": 3, "recovery": 18, "damage": 16, "reach": 12, "radius": 10,
		"lunge": 10, "parryable": false, "knockback": 1.6, "hitstop": 14, "posture": 30, "telegraph": "unblock", "shape": "punch",
		"sfx": "kick", "hit_sfx": "hit_heavy", "shake": 5, "skill": true, "stun_3d": [60, 45]},              # 005/019-020 시계 찬 주먹을 복부 깊이 — 털썩 주저앉는다
	# 윤덕수(yd_, 1장 끝 보스 · 전국구, 018-020) — 큰 오른 훅 · 오른 스트레이트 · 얼굴 잡아 들어 메치기 · 짓밟기.
	# 옆구리를 맞은 뒤(020/014-018 '이런... 낭패가') 2차 — 메치기를 더 자주
	"yd_jab": {"label": "왼손 견제", "startup": 9, "active": 3, "recovery": 10, "damage": 7, "reach": 13, "radius": 9,
		"lunge": 5, "posture": 8, "telegraph": "parry", "shape": "punch", "sfx": "swing", "hand": "L"},
	"yd_hook": {"label": "큰 오른 훅", "startup": 18, "active": 4, "recovery": 16, "damage": 16, "reach": 14, "radius": 12,
		"arc": 110, "lunge": 8, "knockback": 4.4, "hitstop": 9, "posture": 20, "telegraph": "parry", "shape": "punch", "sfx": "kick",
		"hit_sfx": "hit_heavy", "shake": 3},                                                                   # 020/000-005 붉은 눈빛 궤적과 함께 오른쪽 큰 훅
	"yd_straight": {"label": "오른 스트레이트", "startup": 13, "active": 3, "recovery": 14, "damage": 13, "reach": 16, "radius": 9,
		"lunge": 10, "knockback": 3.6, "hitstop": 7, "posture": 16, "telegraph": "parry", "shape": "punch", "sfx": "swing",
		"hit_sfx": "hit_heavy"},                                                                               # 020/014-018
	"yd_grab": {"label": "얼굴 잡아 메치기", "startup": 24, "active": 5, "recovery": 22, "damage": 22, "reach": 13, "radius": 10,
		"lunge": 16, "parryable": false, "guard_break": true, "knockdown": true, "knockback": 2.0, "hitstop": 16, "posture": 40,
		"telegraph": "unblock", "shape": "thrust", "sfx": "wind", "hit_sfx": "hit_heavy", "shake": 7, "skill": true, "whiff": 24},   # 019/124-138 얼굴을 움켜쥐어 들어 올려 등부터 꽂음
	"yd_stomp": {"label": "짓밟기", "startup": 16, "active": 4, "recovery": 18, "damage": 12, "reach": 10, "radius": 11,
		"lunge": 8, "parryable": false, "knockback": 0.6, "hitstop": 10, "posture": 18, "telegraph": "unblock", "shape": "axe",
		"sfx": "kick", "hit_sfx": "hit_heavy", "shake": 5},                                                    # 019/138 쓰러진 남자를 밟음(콰득)
	# ---- 2장 하성 본사(S5 묶음 4) — 원작 위치는 castle_common canon fights · episodes moves(p1:022-033, 화/컷 — conf ai 판독이라
	# 손 · 방향이 불분명한 컷은 '?' 그대로 · 연출에 맞춰 골랐다). 처음 값은 봇 판으로 맞췄다(tests/sim_stage.gd ch2).
	# 김신 2장 = 역수 단검(장 표 kimshin → k_slash1 …, 11장 쌍단검 동작 그대로 — 025-026 경호팀을 칼로 제압). 공사장은 맨손(kf_)
	# 서진태(jk_, 2장 조작 인물 · 칼) — 1장 아군 주먹(j_)과 따로. 칼날 쳐내기가 없어(characters.json can_parry false — 막기만)
	# 반격 동작(counter)은 두지 않는다(world 가 쳐내기에만 counter_ready 를 준다). 세 얼굴 연속 베기 → 회전 베기 · 낮은 대시 · 역수 내리꽂기
	"jk_slash1": {"label": "칼 베기", "startup": 4, "active": 3, "recovery": 8, "damage": 7, "reach": 13, "radius": 10,
		"arc": 80, "lunge": 4, "next": "jk_slash2", "cancel": 7, "posture": 8, "shape": "slash", "sfx": "knife"},      # 028/008-009 세 정장 얼굴 연속 베기
	"jk_slash2": {"label": "되베기", "startup": 4, "active": 3, "recovery": 9, "damage": 7, "reach": 13, "radius": 10,
		"arc": 80, "lunge": 4, "next": "jk_spin", "cancel": 7, "posture": 8, "shape": "slash_back", "sfx": "knife", "hand": "L"},   # 026/016 두 칼을 엇갈려 쥠
	"jk_spin": {"label": "회전 베기", "startup": 6, "active": 4, "recovery": 15, "damage": 13, "reach": 12, "radius": 24,
		"knockback": 3.0, "hitstop": 7, "posture": 16, "shape": "spin", "sfx": "slash", "hit_sfx": "hit_heavy", "shake": 2},  # 028/053-054 몸을 돌려 주변을 한 바퀴
	"jk_dash": {"label": "낮은 대시 베기", "startup": 5, "active": 5, "recovery": 14, "damage": 12, "reach": 14, "radius": 10,
		"arc": 60, "lunge": 30, "knockback": 3.4, "hitstop": 6, "posture": 16, "shape": "thrust_low", "sfx": "slash",
		"hit_sfx": "hit_heavy"},                                                                               # 028/006-009 낮게 돌진해 베며 통과
	"jk_finisher": {"label": "역수 내리꽂기", "startup": 4, "active": 4, "recovery": 18, "damage": 34, "reach": 14, "radius": 10,
		"lunge": 8, "knockback": 4.2, "hitstop": 15, "posture": 0, "shape": "axe", "sfx": "slash", "hit_sfx": "hit_heavy",
		"shake": 6},                                                                                           # 028/035-038 역수로 내리꽂기 · 027/180-186 옆구리 깊이
	# 이슬 아군(ia_ · s_is_, 로비 — 서진태 쪽 봇): 왼 주먹 → 큰 오른 주먹 · 어깨 돌진 · 메다꽂기, 기술은 addendum iseul skills
	"ia_hook": {"label": "왼 주먹", "startup": 6, "active": 3, "recovery": 11, "damage": 8, "reach": 13, "radius": 10,
		"arc": 60, "lunge": 5, "next": "ia_punch", "cancel": 9, "posture": 10, "shape": "punch", "sfx": "swing", "hand": "L"},   # 026/003 왼 주먹으로 부하 얼굴
	"ia_punch": {"label": "큰 주먹", "startup": 8, "active": 4, "recovery": 15, "damage": 13, "reach": 14, "radius": 11,
		"arc": 70, "lunge": 8, "knockback": 4.0, "hitstop": 7, "posture": 18, "shape": "punch", "sfx": "kick",
		"hit_sfx": "hit_heavy", "shake": 2},                                                                   # 027/191 정장 무리를 날려 버림('뻐억')
	"ia_dash": {"label": "어깨 돌진", "startup": 8, "active": 5, "recovery": 16, "damage": 12, "reach": 13, "radius": 11,
		"lunge": 26, "knockback": 4.4, "hitstop": 7, "posture": 18, "shape": "thrust", "sfx": "wind", "hit_sfx": "hit_heavy"},
	"ia_finisher": {"label": "메다꽂기", "startup": 5, "active": 4, "recovery": 20, "damage": 32, "reach": 13, "radius": 11,
		"lunge": 6, "knockback": 3.0, "hitstop": 15, "posture": 0, "shape": "axe", "sfx": "kick", "hit_sfx": "hit_heavy",
		"shake": 6},                                                                                           # 028/068-069 바닥에 메다꽂음('콰앙')
	"s_is_throw": {"label": "붙잡아 후려 날리기", "startup": 10, "active": 4, "recovery": 18, "damage": 15, "reach": 12,
		"radius": 11, "lunge": 12, "guard_break": true, "knockdown": true, "knockback": 6.0, "hitstop": 11, "posture": 26,
		"shape": "punch", "sfx": "wind", "hit_sfx": "hit_heavy", "shake": 4, "skill": true, "skill_id": "iseul_throw"},     # 026/000-001 '으라아앗!' 붙잡아 후려쳐 날림
	"s_is_slam": {"label": "양팔 머리 낚아채 메다꽂기", "startup": 12, "active": 5, "recovery": 20, "damage": 16, "reach": 12,
		"radius": 30, "guard_break": true, "knockdown": true, "knockback": 2.0, "hitstop": 14, "posture": 30, "shape": "spin",
		"sfx": "wind", "hit_sfx": "hit_heavy", "shake": 6, "skill": true, "skill_id": "iseul_double_slam"},              # 028/065-069 좌우 둘의 머리를 동시에(콱!)
	# 남구청년회(ny_, 로비 아군 봇 · 건달급): 주먹 둘 → 발차기 · 계단을 내리 달려 덮치기
	"ny_jab": {"label": "주먹", "startup": 5, "active": 3, "recovery": 10, "damage": 6, "reach": 12, "radius": 9,
		"lunge": 4, "next": "ny_punch", "cancel": 8, "posture": 7, "shape": "punch", "sfx": "swing"},          # 025/164-166 얼굴 · 배에 주먹('빠악')
	"ny_punch": {"label": "주먹", "startup": 5, "active": 3, "recovery": 11, "damage": 7, "reach": 12, "radius": 9,
		"lunge": 4, "next": "ny_kick", "cancel": 9, "posture": 8, "shape": "punch", "sfx": "swing", "hand": "L"},
	"ny_kick": {"label": "발차기", "startup": 7, "active": 4, "recovery": 15, "damage": 10, "reach": 14, "radius": 10,
		"arc": 60, "lunge": 4, "knockback": 3.2, "hitstop": 6, "posture": 14, "shape": "sidekick", "sfx": "kick",
		"hit_sfx": "hit_heavy"},                                                                               # 027/192 발차기
	"ny_dash": {"label": "덮치기", "startup": 7, "active": 5, "recovery": 15, "damage": 9, "reach": 13, "radius": 10,
		"lunge": 24, "knockback": 3.4, "posture": 14, "shape": "punch", "sfx": "swing", "hit_sfx": "hit_heavy"},   # 024/087 청년회가 계단을 내리 달림
	"ny_finisher": {"label": "짓밟기", "startup": 5, "active": 4, "recovery": 18, "damage": 24, "reach": 12, "radius": 10,
		"lunge": 6, "knockback": 3.0, "hitstop": 12, "posture": 0, "shape": "axe", "sfx": "kick", "hit_sfx": "hit_heavy", "shake": 4},
	# 이슬(is_, 공사장 적 · 전국구 거구 맨손, 022) — 한 합. 성큼 다가와 몸을 틀며 크게 뻗는 주먹(058-062) · 탁자 내려치기(020-021)
	# 같은 내려찍는 주먹 · 붙잡아 후려 날리기(026/000-001 — 로비에서 보인 힘)
	"is_hook": {"label": "왼 주먹", "startup": 12, "active": 3, "recovery": 12, "damage": 9, "reach": 13, "radius": 10,
		"arc": 60, "lunge": 6, "posture": 12, "telegraph": "parry", "shape": "punch", "sfx": "swing", "hand": "L"},  # 026/003
	"is_punch": {"label": "돌진 큰 주먹", "startup": 17, "active": 4, "recovery": 16, "damage": 15, "reach": 14, "radius": 11,
		"arc": 50, "lunge": 24, "knockback": 4.2, "hitstop": 8, "posture": 20, "telegraph": "parry", "shape": "punch", "sfx": "kick",
		"hit_sfx": "hit_heavy", "shake": 3},                                                                   # 022/058-062 성큼 · 상체를 틀며 크게 뻗음
	"is_hammer": {"label": "내려치는 주먹", "startup": 22, "active": 4, "recovery": 20, "damage": 16, "reach": 12, "radius": 11,
		"arc": 40, "lunge": 8, "parryable": false, "knockdown": true, "knockback": 2.6, "hitstop": 11, "posture": 24,
		"telegraph": "unblock", "shape": "axe", "sfx": "kick", "hit_sfx": "hit_heavy", "shake": 5, "whiff": 18},      # 022/020-021 탁자를 내리쳐 호두가 튐('쾅')
	"is_throw": {"label": "붙잡아 후려 날리기", "startup": 22, "active": 5, "recovery": 20, "damage": 15, "reach": 12, "radius": 11,
		"lunge": 14, "parryable": false, "guard_break": true, "knockdown": true, "knockback": 6.0, "hitstop": 12, "posture": 28,
		"telegraph": "unblock", "shape": "punch", "sfx": "wind", "hit_sfx": "hit_heavy", "shake": 5, "skill": true,
		"skill_id": "iseul_throw", "whiff": 24},                                                               # 026/000-001
	# 하성 조직원(hs_, 로비 엑스트라 · 건달급 · 맨손/칼) — 각목 · 칼 · 손도끼(024-028). 정장 무리라 느리고 예고가 길다
	"hs_punch": {"label": "주먹", "startup": 14, "active": 3, "recovery": 12, "damage": 7, "reach": 12, "radius": 9,
		"lunge": 6, "posture": 9, "telegraph": "parry", "shape": "punch", "sfx": "swing"},
	"hs_bat": {"label": "각목 내려치기", "startup": 17, "active": 3, "recovery": 14, "damage": 10, "reach": 16, "radius": 10,
		"arc": 60, "lunge": 5, "posture": 12, "telegraph": "parry", "shape": "slash", "sfx": "swing", "hit_sfx": "hit_heavy"},   # 024/124-125 각목 든 선글라스 정장
	"hs_knife": {"label": "칼 찌르기", "startup": 15, "active": 3, "recovery": 13, "damage": 9, "reach": 15, "radius": 8,
		"lunge": 10, "posture": 10, "telegraph": "parry", "shape": "thrust", "sfx": "knife"},                  # 025/169-171 칼을 뽑아 듦 · 028/019-021 사방의 칼
	"hs_hatchet": {"label": "손도끼 휘두르기", "startup": 19, "active": 3, "recovery": 15, "damage": 12, "reach": 13, "radius": 10,
		"arc": 90, "lunge": 6, "knockback": 2.6, "posture": 14, "telegraph": "parry", "shape": "slash_back", "sfx": "slash",
		"hit_sfx": "hit_heavy", "hand": "L"},                                                                  # 028/016-017 손도끼 정장
	# 특별 경호팀(hg_, 대표실 앞 · 경호대급) — 어둠 속 '연장 꺼내! 잡히는 대로 쑤셔!'(026/028). 정장보다 빠르고 덮친다
	"hg_punch": {"label": "주먹", "startup": 11, "active": 3, "recovery": 11, "damage": 8, "reach": 12, "radius": 9,
		"lunge": 6, "posture": 10, "telegraph": "parry", "shape": "punch", "sfx": "swing"},
	"hg_knife": {"label": "칼 달려들기", "startup": 14, "active": 4, "recovery": 13, "damage": 11, "reach": 15, "radius": 9,
		"lunge": 20, "knockback": 2.8, "posture": 13, "telegraph": "parry", "shape": "thrust", "sfx": "knife"},      # 026/029 '불 끄면 될 줄 알았냐?!' 오른손 칼로 달려듦
	"hg_slash": {"label": "칼 휘두르기", "startup": 13, "active": 3, "recovery": 12, "damage": 10, "reach": 14, "radius": 10,
		"arc": 90, "lunge": 5, "posture": 12, "telegraph": "parry", "shape": "slash", "sfx": "knife"},           # 026/032 '여기냐!' 하며 덤빔
	"hg_grab": {"label": "덮쳐 붙잡기", "startup": 20, "active": 4, "recovery": 18, "damage": 9, "reach": 12, "radius": 10,
		"lunge": 18, "parryable": false, "guard_break": true, "knockdown": true, "knockback": 1.6, "hitstop": 9, "posture": 18,
		"telegraph": "unblock", "shape": "thrust", "sfx": "wind", "hit_sfx": "hit_heavy", "shake": 3, "whiff": 18},   # 026/035 '잡았다!' 하며 덤빔
	# 오지인(oj_, 대표실 비서 · 경호대급 · 긴 칼(카타나) + 치마 뒤 단검, 026/049-059) — 원작은 맞붙지 않고 칼을 내려놓는다(장 표 yield_at)
	"oj_slash": {"label": "카타나 베기", "startup": 13, "active": 3, "recovery": 11, "damage": 10, "reach": 20, "radius": 11,
		"arc": 80, "lunge": 6, "posture": 12, "telegraph": "parry", "shape": "slash", "sfx": "knife"},           # 026/049-050 카타나를 쥔 비서
	"oj_slash2": {"label": "되베기", "startup": 10, "active": 3, "recovery": 11, "damage": 9, "reach": 20, "radius": 11,
		"arc": 80, "lunge": 5, "posture": 12, "telegraph": "parry", "shape": "slash_back", "sfx": "knife"},
	"oj_thrust": {"label": "카타나 찌르기", "startup": 15, "active": 4, "recovery": 15, "damage": 12, "reach": 24, "radius": 8,
		"lunge": 14, "knockback": 3.2, "hitstop": 7, "posture": 16, "telegraph": "parry", "shape": "thrust", "sfx": "slash",
		"hit_sfx": "hit_heavy", "shake": 2},
	"oj_dagger": {"label": "치마 뒤 단검", "startup": 16, "active": 3, "recovery": 16, "damage": 13, "reach": 13, "radius": 8,
		"lunge": 22, "parryable": false, "knockback": 2.4, "hitstop": 9, "posture": 18, "telegraph": "unblock", "shape": "thrust",
		"sfx": "knife", "hit_sfx": "hit_heavy", "shake": 3, "hand": "L", "skill": true, "skill_id": "ojiin_skirt_dagger", "whiff": 14},   # 026/053 치마 뒤 단검으로 등 뒤 기습(상상 컷)
	# 황보민철(hb_, 전국구 · 두 칼 — 가부키초 칼잡이, 026/004-018 · 027/165-190) — 돌진에 맞받아 얼굴 스치기(counter) · 긴 내디딤 찌르기 ·
	# 오른팔 치켜 내리찍기(그 틈에 옆구리를 내준다) · 두 칼 휘두르기. 2차(출혈로 몰림 027/165-171): 왼다리 미끼 → '그대로 시마이!' 찌르기
	"hb_face": {"label": "얼굴 스치기 베기", "startup": 7, "active": 3, "recovery": 13, "damage": 11, "reach": 14, "radius": 10,
		"arc": 90, "lunge": 6, "knockback": 2.6, "hitstop": 7, "posture": 14, "telegraph": "parry", "shape": "slash", "sfx": "knife",
		"hit_sfx": "hit_heavy", "shake": 2, "skill": true, "skill_id": "hwangbo_face_counter"},                 # 026/004-005 돌진에 맞받아 얼굴 높이 가로 베기('츠 츳')
	"hb_lunge": {"label": "내디딤 얼굴 찌르기", "startup": 15, "active": 4, "recovery": 15, "damage": 13, "reach": 20, "radius": 8,
		"lunge": 20, "knockback": 3.2, "hitstop": 7, "posture": 16, "telegraph": "parry", "shape": "thrust", "sfx": "slash",
		"hit_sfx": "hit_heavy", "shake": 2},                                                                   # 026/009 뒷발을 빼고 크게 내디뎌 얼굴로
	"hb_chop": {"label": "치켜 내리찍기", "startup": 20, "active": 3, "recovery": 18, "damage": 16, "reach": 14, "radius": 10,
		"arc": 40, "lunge": 6, "knockback": 3.4, "hitstop": 9, "posture": 20, "telegraph": "parry", "shape": "axe", "sfx": "slash",
		"hit_sfx": "hit_heavy", "shake": 3, "whiff": 16},                                                      # 026/013-014 오른팔을 들어 내리찍으려는 순간 옆구리를 내줌
	"hb_twin": {"label": "두 칼 휘두르기", "startup": 12, "active": 8, "recovery": 14, "damage": 7, "reach": 14, "radius": 11,
		"arc": 110, "lunge": 8, "hits": 2, "knockback": 1.6, "posture": 10, "telegraph": "parry", "shape": "slash", "sfx": "knife"},   # 027/167 두 칼로 휘두름
	"hb_back": {"label": "왼손 칼 되베기", "startup": 9, "active": 3, "recovery": 12, "damage": 9, "reach": 14, "radius": 10,
		"arc": 90, "lunge": 4, "posture": 12, "telegraph": "parry", "shape": "slash_back", "sfx": "knife", "hand": "L"},
	"hb_bait": {"label": "왼다리 미끼 찌르기", "startup": 26, "active": 4, "recovery": 22, "damage": 20, "reach": 15, "radius": 9,
		"lunge": 16, "parryable": false, "knockdown": true, "knockback": 4.0, "hitstop": 12, "posture": 28, "telegraph": "unblock",
		"shape": "thrust_low", "sfx": "slash", "hit_sfx": "hit_heavy", "shake": 5, "feints": [10], "skill": true,
		"skill_id": "hwangbo_bait", "whiff": 30},                                                              # 027/172-178 중심 무너지는 척 → '그대로 시마이!' (읽히면 크게 빈다)
	# 강창석(cs_, 칼잡이 2인자 · 네임드 · 칼) — 1장에서 보인 칼(013 · 017 · 018 · 019). 2장 대표실에선 김신을 보고 굳는다(029/032-047)
	"cs_pass": {"label": "낮게 지나치며 베기", "startup": 15, "active": 4, "recovery": 14, "damage": 10, "reach": 14, "radius": 10,
		"arc": 70, "lunge": 22, "posture": 12, "telegraph": "parry", "shape": "slash", "sfx": "knife"},          # 013/025-026 몸을 낮게 숙여 곁을 지나감
	"cs_stab": {"label": "칼 연속 찌르기", "startup": 12, "active": 9, "recovery": 14, "damage": 6, "reach": 15, "radius": 8,
		"lunge": 10, "hits": 3, "knockback": 0.8, "posture": 7, "telegraph": "parry", "shape": "thrust", "sfx": "knife"},   # 017/092-097 파고들며 연달아 찌름
	"cs_sweep": {"label": "칼 수평 베기", "startup": 16, "active": 3, "recovery": 15, "damage": 12, "reach": 16, "radius": 10,
		"arc": 110, "lunge": 6, "knockback": 2.6, "posture": 14, "telegraph": "parry", "shape": "slash_back", "sfx": "slash",
		"hit_sfx": "hit_heavy", "hand": "L"},                                                                  # 018/109-114 몸을 낮춰 가슴 높이를 수평으로
	"cs_highkick": {"label": "칼 쥔 채 하이킥", "startup": 18, "active": 3, "recovery": 16, "damage": 11, "reach": 14, "radius": 10,
		"arc": 60, "lunge": 6, "knockback": 3.6, "hitstop": 8, "posture": 18, "telegraph": "parry", "shape": "sidekick", "sfx": "kick",
		"hit_sfx": "hit_heavy", "shake": 2},                                                                   # 019/116-121 오른발 하이킥을 연달아 머리 높이로
	# 김재훈(jh_, 하성 대표 · 건달급 · 맨손 — 아주 약함, 029) — 오른팔 헛스윙 · 밀치기(원작 리볼버 연사는 뺌 — 사용자 답 '맨손')
	"jh_swing": {"label": "오른팔 헛스윙", "startup": 18, "active": 3, "recovery": 16, "damage": 6, "reach": 12, "radius": 10,
		"arc": 90, "lunge": 4, "posture": 8, "telegraph": "parry", "shape": "punch", "sfx": "swing", "whiff": 12},   # 029/060-061 '붕'
	"jh_shove": {"label": "밀치기", "startup": 14, "active": 3, "recovery": 14, "damage": 5, "reach": 11, "radius": 10,
		"lunge": 6, "knockback": 2.4, "posture": 8, "telegraph": "parry", "shape": "punch", "sfx": "swing", "hand": "L"},
	# 남궁혁(ng_, 외성 하위 · 금색 너클, 024-030) — 기술 책 '너클 낀 주먹 카운터'(castle_common characters.json book): 낮춰 파고들며
	# 흘리고(024) · 몸 젖혀 흘린 뒤(025) 맞받는다 — enemy_ai counter. 연타 · 원 궤적 너클 훅 · 휘두르는 발차기 · 날아차기 · 손목 잡고 무릎
	"ng_jab": {"label": "연타", "startup": 9, "active": 9, "recovery": 12, "damage": 6, "reach": 13, "radius": 10,
		"arc": 50, "lunge": 8, "hits": 3, "knockback": 0.8, "hitstop": 4, "posture": 8, "telegraph": "parry", "shape": "punch",
		"sfx": "swing"},                                                                                       # 025 몸 젖혀 흘린 뒤 주먹 연타('퍼버벅')
	# 너클 카운터에 맞으면 기절(아랫급 1초 · 같은 급 · 윗급 0.83초 — rc.2 폰 "안 무서움, 맞으면 스턴" 2026-11-07, 3D 덧붙임)
	"ng_counter": {"label": "너클 카운터", "startup": 7, "active": 3, "recovery": 14, "damage": 16, "reach": 14, "radius": 10,
		"lunge": 8, "knockback": 4.4, "hitstop": 10, "posture": 22, "telegraph": "parry", "shape": "punch", "sfx": "kick",
		"hit_sfx": "hit_heavy", "shake": 4, "skill": true, "skill_id": "namgung_knuckle_counter", "stun_3d": [60, 50]},               # 024 낮춰 파고들며 흘리기 → 품 안 반격 · 028/088-089 흘리고 갈비 훅
	"ng_hook": {"label": "너클 훅", "startup": 18, "active": 4, "recovery": 18, "damage": 18, "reach": 14, "radius": 12,
		"arc": 140, "lunge": 8, "knockback": 5.4, "hitstop": 11, "posture": 26, "telegraph": "parry", "shape": "punch", "sfx": "kick",
		"hit_sfx": "hit_heavy", "shake": 5, "skill": true, "skill_id": "namgung_knuckle_hook"},                 # 029/117-118 둥근 궤적 훅('콰아앙') · 030/010 원 궤적
	"ng_kick": {"label": "휘두르는 발차기", "startup": 15, "active": 4, "recovery": 16, "damage": 13, "reach": 15, "radius": 11,
		"arc": 120, "lunge": 6, "knockback": 3.8, "hitstop": 8, "posture": 18, "telegraph": "parry", "shape": "sidekick", "sfx": "kick",
		"hit_sfx": "hit_heavy", "shake": 2},                                                                   # 024 수평으로 크게 휘두른 발(잔상 띠)
	"ng_flykick": {"label": "날아차기", "startup": 20, "active": 4, "recovery": 20, "damage": 17, "reach": 14, "radius": 11,
		"lunge": 40, "parryable": false, "knockdown": true, "knockback": 5.0, "hitstop": 12, "posture": 26, "telegraph": "unblock",
		"shape": "sidekick", "sfx": "kick", "hit_sfx": "hit_heavy", "shake": 6, "whiff": 18},                  # 024 도약해 몸을 뉘어 한 발 — 못 막음
	"ng_knee": {"label": "손목 잡고 무릎", "startup": 22, "active": 4, "recovery": 20, "damage": 18, "reach": 12, "radius": 10,
		"lunge": 12, "parryable": false, "guard_break": true, "knockback": 2.0, "hitstop": 14, "posture": 30, "telegraph": "unblock",
		"shape": "axe", "sfx": "kick", "hit_sfx": "hit_heavy", "shake": 5, "skill": true, "stun_3d": [50, 36], "whiff": 22},   # 028/152 손목을 잡아 끌며 무릎('빠악')
	# 신태진(st_, 2장 끝 보스 · 준10강 · 장도 + 숨긴 두 번째 칼(쌍칼) + 권총, 031-032) — 1차(031): 두 손 장도 수평 베기 · 뛰어내리며
	# 내려베기 · 낮은 휩쓸기 · 돌진 베기 · 치켜든 장도의 허수(feints) · 코앞 권총. 2차(복면을 벗어 던짐 032/020-031 '얼굴을 봤으니'):
	# 얼굴 찌르기로 시선을 끌고 허리 뒤 두 번째 칼(032/035-038) · 쌍칼 밀착 · 쓰러진 채 올려 베기 · 주운 권총 근접 사격
	"st_sweep": {"label": "장도 수평 베기", "startup": 15, "active": 4, "recovery": 13, "damage": 14, "reach": 22, "radius": 12,
		"arc": 130, "lunge": 6, "knockback": 3.0, "hitstop": 7, "posture": 16, "telegraph": "parry", "shape": "slash", "sfx": "slash",
		"hit_sfx": "hit_heavy", "shake": 2, "skill": true, "skill_id": "sintaejin_sweep"},                      # 031/112-114 두 손으로 수평으로 크게
	"st_drop": {"label": "뛰어내리며 내려베기", "startup": 22, "active": 4, "recovery": 20, "damage": 18, "reach": 18, "radius": 11,
		"lunge": 34, "parryable": false, "knockdown": true, "knockback": 4.4, "hitstop": 12, "posture": 26, "telegraph": "unblock",
		"shape": "axe", "sfx": "slash", "hit_sfx": "hit_heavy", "shake": 6, "skill": true, "whiff": 20},        # 031/115 높은 데서 뛰어내리며
	"st_low": {"label": "낮은 장도 휩쓸기", "startup": 14, "active": 4, "recovery": 15, "damage": 13, "reach": 20, "radius": 11,
		"arc": 100, "lunge": 10, "knockback": 2.8, "hitstop": 7, "posture": 16, "telegraph": "parry", "shape": "slash_back",
		"sfx": "slash", "hand": "L"},                                                                          # 031/121-123 아래에서 위로 크게 휩씀
	"st_rush": {"label": "돌진 베기", "startup": 16, "active": 5, "recovery": 16, "damage": 15, "reach": 18, "radius": 11,
		"arc": 70, "lunge": 40, "knockback": 3.6, "hitstop": 8, "posture": 18, "telegraph": "parry", "shape": "slash", "sfx": "slash",
		"hit_sfx": "hit_heavy", "shake": 3},                                                                   # 031/139-144 발을 박차 돌진('하늘 위엔 또 다른 하늘')
	"st_feint": {"label": "치켜든 장도 — 허수", "startup": 26, "active": 4, "recovery": 12, "damage": 15, "reach": 20, "radius": 11,
		"arc": 60, "lunge": 4, "knockback": 3.4, "hitstop": 9, "posture": 20, "telegraph": "parry", "shape": "axe", "sfx": "slash",
		"hit_sfx": "hit_heavy", "shake": 3, "feints": [9, 18]},                                                # 031/152-163 머리 위로 치켜든 채 멈칫 — 들어가면 베인다
	"st_face": {"label": "얼굴 찌르기", "startup": 11, "active": 3, "recovery": 12, "damage": 11, "reach": 20, "radius": 8,
		"lunge": 12, "knockback": 2.6, "posture": 14, "telegraph": "parry", "shape": "thrust", "sfx": "knife"},  # 032/032 얼굴로 찌르고 수평으로 베어 지나감
	"st_second": {"label": "숨긴 두 번째 칼", "startup": 16, "active": 3, "recovery": 16, "damage": 17, "reach": 15, "radius": 9,
		"lunge": 14, "parryable": false, "guard_break": true, "knockback": 3.2, "hitstop": 12, "posture": 26, "telegraph": "unblock",
		"shape": "thrust", "sfx": "slash", "hit_sfx": "hit_heavy", "shake": 5, "hand": "L", "skill": true,
		"skill_id": "sintaejin_second_blade", "whiff": 18},                                                   # 032/035-038 허리 뒤 가로 칼집에서 뽑아 왼어깨를 찌름
	"st_twin": {"label": "쌍칼 밀어붙이기", "startup": 12, "active": 10, "recovery": 15, "damage": 7, "reach": 14, "radius": 11,
		"arc": 100, "lunge": 14, "hits": 3, "knockback": 1.2, "hitstop": 4, "posture": 10, "telegraph": "parry", "shape": "slash",
		"sfx": "knife"},                                                                                       # 032/039-042 쌍칼로 밀착 · 승합차로 밀어붙임
	"st_upslash": {"label": "올려 베기", "startup": 13, "active": 3, "recovery": 14, "damage": 12, "reach": 15, "radius": 10,
		"arc": 80, "lunge": 6, "knockback": 2.6, "posture": 14, "telegraph": "parry", "shape": "slash_back", "sfx": "slash",
		"hand": "L"},                                                                                          # 032/064-066 쓰러진 채 바닥 칼을 쥐고 올려 벰
	"st_pistol": {"label": "코앞 권총", "startup": 22, "active": 2, "recovery": 22, "damage": 16, "reach": 60, "radius": 5,
		"parryable": false, "knockback": 3.0, "hitstop": 9, "posture": 18, "telegraph": "unblock", "shape": "shot", "sfx": "shot",
		"hit_sfx": "hit_heavy", "shake": 4, "hand": "L", "skill": true, "skill_id": "sintaejin_pistol"},       # 031/106-119 칼과 다른 손의 권총 · 032/054-057 주운 권총 근접 사격
	# ---- 3 ~ 13장 적 원형(x_ — 2026-11-08 사용자 "3장부터 13장까지 중단없이"): 이름 있는 적이 40명이 넘어 사람마다 동작을 새로 짜지 않고
	# 싸움 갈래(주먹 · 발 · 잡기 · 칼 · 쌍칼 · 도끼 · 카람빗)마다 동작 묶음을 두고 장 표 ROLES(ai · hp · dmg_k)로 손맛을 가른다.
	# 예고: 흰 !(parry — 쳐내기 · 막기) · 빨간 !(unblock — 구르기). 원작 국면은 장 표 머리 주석(화/컷)
	"x_jab": {"label": "잽", "startup": 10, "active": 3, "recovery": 12, "damage": 7, "reach": 12, "radius": 10, "arc": 50, "lunge": 6,
		"posture": 10, "telegraph": "parry", "shape": "punch", "sfx": "swing", "hand": "L"},
	"x_straight": {"label": "스트레이트", "startup": 14, "active": 4, "recovery": 14, "damage": 12, "reach": 14, "radius": 10, "lunge": 10,
		"knockback": 3.6, "hitstop": 7, "posture": 16, "telegraph": "parry", "shape": "punch", "sfx": "kick", "hit_sfx": "hit_heavy"},
	"x_hook": {"label": "훅", "startup": 17, "active": 4, "recovery": 16, "damage": 15, "reach": 13, "radius": 12, "arc": 120, "lunge": 8,
		"knockback": 4.4, "hitstop": 9, "posture": 20, "telegraph": "parry", "shape": "punch", "sfx": "kick", "hit_sfx": "hit_heavy", "shake": 2},
	"x_body": {"label": "보디 블로", "startup": 16, "active": 4, "recovery": 18, "damage": 14, "reach": 12, "radius": 10, "lunge": 8,
		"knockback": 2.4, "hitstop": 9, "posture": 26, "telegraph": "parry", "shape": "punch", "sfx": "kick", "hit_sfx": "hit_heavy", "hand": "L"},
	"x_rush": {"label": "돌진 주먹", "startup": 20, "active": 5, "recovery": 20, "damage": 16, "reach": 13, "radius": 11, "lunge": 34,
		"parryable": false, "knockdown": true, "knockback": 5.0, "hitstop": 11, "posture": 24, "telegraph": "unblock", "shape": "punch",
		"sfx": "wind", "hit_sfx": "hit_heavy", "shake": 4, "whiff": 16},
	"x_frontkick": {"label": "앞차기", "startup": 13, "active": 4, "recovery": 15, "damage": 12, "reach": 16, "radius": 10, "lunge": 6,
		"knockback": 4.0, "hitstop": 7, "posture": 16, "telegraph": "parry", "shape": "sidekick", "sfx": "kick", "hit_sfx": "hit_heavy"},
	"x_roundkick": {"label": "돌려차기", "startup": 16, "active": 4, "recovery": 16, "damage": 14, "reach": 16, "radius": 11, "arc": 140,
		"lunge": 6, "knockback": 4.2, "hitstop": 8, "posture": 18, "telegraph": "parry", "shape": "sidekick", "sfx": "kick", "hit_sfx": "hit_heavy", "shake": 2},
	"x_spinkick": {"label": "뒤돌려차기", "startup": 22, "active": 4, "recovery": 20, "damage": 18, "reach": 16, "radius": 11, "lunge": 10,
		"parryable": false, "knockdown": true, "knockback": 5.2, "hitstop": 12, "posture": 26, "telegraph": "unblock", "shape": "sidekick",
		"sfx": "kick", "hit_sfx": "hit_heavy", "shake": 5, "whiff": 18},
	"x_flykick": {"label": "날아차기", "startup": 20, "active": 4, "recovery": 20, "damage": 17, "reach": 14, "radius": 11, "lunge": 40,
		"parryable": false, "knockdown": true, "knockback": 5.0, "hitstop": 12, "posture": 26, "telegraph": "unblock", "shape": "sidekick",
		"sfx": "kick", "hit_sfx": "hit_heavy", "shake": 6, "whiff": 18},
	"x_hammer": {"label": "내려치는 주먹", "startup": 18, "active": 4, "recovery": 18, "damage": 16, "reach": 13, "radius": 11, "lunge": 6,
		"knockback": 3.0, "hitstop": 10, "posture": 24, "telegraph": "parry", "shape": "axe", "sfx": "kick", "hit_sfx": "hit_heavy", "shake": 3},
	"x_shoulder": {"label": "어깨 들이받기", "startup": 18, "active": 5, "recovery": 18, "damage": 14, "reach": 13, "radius": 11, "lunge": 30,
		"knockback": 5.0, "hitstop": 9, "posture": 22, "telegraph": "parry", "shape": "thrust", "sfx": "wind", "hit_sfx": "hit_heavy", "shake": 3},
	"x_grab": {"label": "붙잡아 메치기", "startup": 20, "active": 4, "recovery": 22, "damage": 20, "reach": 12, "radius": 10, "lunge": 12,
		"parryable": false, "guard_break": true, "knockdown": true, "knockback": 2.4, "hitstop": 14, "posture": 30, "telegraph": "unblock",
		"shape": "axe", "sfx": "wind", "hit_sfx": "hit_heavy", "shake": 6, "stun_3d": [40, 30], "whiff": 20},
	"x_cut": {"label": "베기", "startup": 12, "active": 4, "recovery": 12, "damage": 10, "reach": 18, "radius": 11, "arc": 110, "lunge": 6,
		"knockback": 2.6, "hitstop": 6, "posture": 12, "telegraph": "parry", "shape": "slash", "sfx": "slash"},
	"x_cut2": {"label": "되베기", "startup": 12, "active": 4, "recovery": 14, "damage": 11, "reach": 18, "radius": 11, "arc": 110, "lunge": 6,
		"knockback": 3.0, "hitstop": 7, "posture": 14, "telegraph": "parry", "shape": "slash", "sfx": "slash", "hand": "L"},
	"x_stab": {"label": "찌르기", "startup": 14, "active": 3, "recovery": 14, "damage": 13, "reach": 20, "radius": 8, "lunge": 10,
		"knockback": 2.8, "hitstop": 8, "posture": 16, "telegraph": "parry", "shape": "thrust", "sfx": "slash", "hit_sfx": "hit_heavy"},
	"x_lunge": {"label": "파고드는 찌르기", "startup": 20, "active": 5, "recovery": 18, "damage": 16, "reach": 18, "radius": 9, "lunge": 32,
		"parryable": false, "knockback": 4.0, "hitstop": 10, "posture": 22, "telegraph": "unblock", "shape": "thrust", "sfx": "slash",
		"hit_sfx": "hit_heavy", "shake": 3, "whiff": 16},
	"x_twin": {"label": "쌍칼 몰아치기", "startup": 12, "active": 10, "recovery": 15, "damage": 6, "reach": 14, "radius": 11, "arc": 100,
		"lunge": 10, "hits": 3, "knockback": 1.2, "hitstop": 4, "posture": 9, "telegraph": "parry", "shape": "slash", "sfx": "slash"},
	"x_cross": {"label": "엇갈려 베기", "startup": 16, "active": 4, "recovery": 16, "damage": 16, "reach": 16, "radius": 12, "arc": 120,
		"lunge": 8, "knockback": 4.0, "hitstop": 9, "posture": 22, "telegraph": "parry", "shape": "slash", "sfx": "slash", "hit_sfx": "hit_heavy", "shake": 2},
	"x_chop": {"label": "내려찍기", "startup": 20, "active": 4, "recovery": 20, "damage": 20, "reach": 16, "radius": 10, "lunge": 6,
		"knockback": 4.4, "hitstop": 10, "posture": 26, "telegraph": "parry", "shape": "axe", "sfx": "slash", "hit_sfx": "hit_heavy", "shake": 3},
	"x_swing": {"label": "크게 휘두르기", "startup": 17, "active": 4, "recovery": 16, "damage": 15, "reach": 17, "radius": 12, "arc": 140,
		"lunge": 6, "knockback": 4.0, "hitstop": 8, "posture": 20, "telegraph": "parry", "shape": "slash", "sfx": "swing", "hit_sfx": "hit_heavy"},
	"x_overhead": {"label": "두 손 내려찍기", "startup": 26, "active": 4, "recovery": 22, "damage": 26, "reach": 16, "radius": 10, "lunge": 10,
		"parryable": false, "guard_break": true, "knockdown": true, "knockback": 5.0, "hitstop": 14, "posture": 32, "telegraph": "unblock",
		"shape": "axe", "sfx": "slash", "hit_sfx": "hit_heavy", "shake": 6, "whiff": 20},
	"x_kara": {"label": "카람빗 연속 베기", "startup": 9, "active": 9, "recovery": 12, "damage": 5, "reach": 12, "radius": 10, "arc": 90,
		"lunge": 8, "hits": 3, "knockback": 0.8, "hitstop": 4, "posture": 7, "telegraph": "parry", "shape": "slash", "sfx": "slash"},
	"x_kara_spin": {"label": "돌며 베기", "startup": 14, "active": 6, "recovery": 16, "damage": 7, "reach": 14, "radius": 24, "hits": 2,
		"knockback": 2.4, "hitstop": 6, "posture": 12, "telegraph": "parry", "shape": "spin", "sfx": "slash", "hit_sfx": "hit_heavy"},
	# 3 ~ 13장 조작 인물 · 아군(표영 · 김대건 · 이슬 맨손은 ia_ · 김대건 dk_): 표영 카람빗(p1:042-043 슬롯머신 · 049-050 모승규)
	"py_slash1": {"label": "카람빗 베기", "startup": 4, "active": 3, "recovery": 9, "damage": 7, "reach": 12, "radius": 10, "arc": 90,
		"lunge": 6, "next": "py_slash2", "cancel": 7, "posture": 8, "shape": "slash", "sfx": "slash"},
	"py_slash2": {"label": "되베기", "startup": 4, "active": 3, "recovery": 10, "damage": 8, "reach": 12, "radius": 10, "arc": 90,
		"lunge": 6, "next": "py_knee", "cancel": 8, "posture": 9, "shape": "slash", "sfx": "slash", "hand": "L"},
	"py_knee": {"label": "뛰어 무릎", "startup": 7, "active": 4, "recovery": 15, "damage": 12, "reach": 12, "radius": 10, "lunge": 14,
		"knockback": 4.0, "hitstop": 7, "posture": 16, "shape": "axe", "sfx": "kick", "hit_sfx": "hit_heavy", "shake": 2},
	"py_dash": {"label": "낮게 파고들기", "startup": 5, "active": 5, "recovery": 13, "damage": 11, "reach": 13, "radius": 10, "lunge": 28,
		"knockback": 3.2, "hitstop": 6, "posture": 14, "shape": "thrust_low", "sfx": "slash", "hit_sfx": "hit_heavy"},
	"py_finisher": {"label": "올라탄 주먹 연타", "startup": 4, "active": 8, "recovery": 18, "damage": 12, "reach": 12, "radius": 10,
		"hits": 3, "lunge": 6, "knockback": 2.0, "hitstop": 8, "posture": 0, "shape": "punch", "sfx": "kick", "hit_sfx": "hit_heavy", "shake": 4},
	# 김대건 조작(4장 공단 폐공장 — p1:081-084 바리스타의 곡도를 빼앗아): 잽 → 스트레이트 → 하이킥 · 미끄러져 들어가기 · 정권
	"dk_jab": {"label": "잽", "startup": 4, "active": 3, "recovery": 9, "damage": 7, "reach": 12, "radius": 10, "lunge": 5,
		"next": "dk_straight", "cancel": 7, "posture": 8, "shape": "punch", "sfx": "swing", "hand": "L"},
	"dk_straight": {"label": "스트레이트", "startup": 5, "active": 3, "recovery": 10, "damage": 9, "reach": 13, "radius": 10, "lunge": 7,
		"next": "dk_highkick", "cancel": 8, "posture": 10, "shape": "punch", "sfx": "kick"},
	"dk_highkick": {"label": "하이킥", "startup": 8, "active": 4, "recovery": 15, "damage": 13, "reach": 16, "radius": 11, "arc": 100,
		"lunge": 4, "knockback": 4.2, "hitstop": 8, "posture": 18, "shape": "sidekick", "sfx": "kick", "hit_sfx": "hit_heavy", "shake": 2},
	"dk_dash": {"label": "미끄러져 들어가기", "startup": 6, "active": 5, "recovery": 14, "damage": 11, "reach": 13, "radius": 10, "lunge": 28,
		"knockback": 3.4, "hitstop": 6, "posture": 14, "shape": "thrust_low", "sfx": "wind", "hit_sfx": "hit_heavy"},
	"dk_finisher": {"label": "정권", "startup": 5, "active": 4, "recovery": 18, "damage": 32, "reach": 13, "radius": 10, "lunge": 8,
		"knockback": 5.0, "hitstop": 15, "posture": 0, "shape": "punch", "sfx": "kick", "hit_sfx": "hit_heavy", "shake": 6},
}

static var _plain := {}                  # 규칙 없이 부를 때(그림 · 시험)의 사본 모음


## 이름 → 기술 (기본값을 채우고 거리를 미터로 바꾸고 2층 효과를 공통 데이터에서 채운 사본, 한 번 만들어 둔다)
static func get_move(name: String, rules = null) -> Dictionary:
	var cache: Dictionary = rules.move_cache if rules != null else _plain
	if cache.has(name):
		return cache[name]
	var d: Dictionary = DEFAULTS.duplicate(true)
	d.merge(M[name], true)
	d["name"] = name
	var fx: Dictionary = rules.skill(d["skill_id"]).get("effects", {}) if (d["skill_id"] != "" and rules != null) else {}
	d["lethal"] = str(fx.get("lethal", ""))
	d["self_cost"] = float(fx.get("self_cost", 0.0))
	d["immune_lower"] = bool(fx.get("immune_lower", false))      # 아랫급의 공격에 무적(castle_common vanish_step — world.gd)
	for k in ["reach", "radius", "lunge", "side"]:
		d[k] = float(d[k]) * PX
	d["damage"] = float(d["damage"])
	d["posture"] = float(d["posture"])
	d["knockback"] = float(d["knockback"]) * PX * 6.0     # px/프레임 넉백 → m/초 첫 속도
	cache[name] = d
	return d


## 쳐내는 동작 방향 (받는 사람 기준 L 왼팔 · R 오른팔, 그림용) — 판정은 쪽과 관계없다(castle_common rules/전투_쳐내기.md 2절).
## 들어오는 쪽(치는 사람 기준): 바로 베기(slash)는 오른쪽, 되베기(slash_back)는 왼쪽(fx3d.swing 궤적이 시작하는 쪽),
## 찌르기 · 주먹 · 발차기는 그 손 · 발("hand"). 마주 보고 있으니 치는 사람의 오른쪽은 막는 사람의 왼쪽이다.
static func parry_side(mv: Dictionary) -> String:
	var from := "L" if str(mv["shape"]) == "slash_back" else str(mv["hand"])
	return "R" if from == "L" else "L"


static func total(mv: Dictionary) -> int:
	return int(mv["startup"]) + int(mv["active"]) + int(mv["recovery"])


static func cancel_at(mv: Dictionary) -> int:
	var c := int(mv["cancel"])
	return c if c >= 0 else int(mv["startup"]) + int(mv["active"])
