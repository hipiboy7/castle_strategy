extends "res://tests/helpers.gd"
## FR-112 — castle_common `cases/rules_cases.json`(받은 사본 `res://data/common/cases/`)의 줄 전부를 `sim/rules_common.gd` 로 돌려
## 기대 값과 같은지 본다. 실수는 차이 1e-9 까지 같으면 통과(cases 머리 _about). 시험 값은 castle_common `tools/gen_cases.py` 가
## `ref/rules.py` 로 만든다 — 여기서 고치지 않는다. castle_M3D tests/unit/test_common_cases.gd 를 옮겼다(파일 읽기는 src/data_files.gd).

const RulesCommon = preload("res://sim/rules_common.gd")
const DataFiles = preload("res://src/data_files.gd")
const CASES := "common/cases/rules_cases.json"
const EPS := 1e-9
const N_FN := 15                 # 시험 함수 수(bars_for … progress_at)
const MIN_ROWS := 3215           # castle_common 56839ec(91차) — one_shot 15 → 225줄

var _rc = null


func _rules() -> RefCounted:
	if _rc == null:
		var r: Dictionary = DataFiles.read(RulesCommon.FILES)
		check(r["errors"].is_empty(), "규칙 파일 읽기: %s" % [r["errors"]])
		_rc = RulesCommon.from_files(r["files"])
	return _rc


func _cases() -> Array:
	var r: Dictionary = DataFiles.read([CASES])
	return r["files"][CASES]["cases"] if r["errors"].is_empty() else []


func _call(rc, fn: String, a: Array):
	match fn:
		"bars_for": return rc.bars_for(a[0])
		"gauge_rate": return rc.gauge_rate(a[0], a[1])
		"offbeat_cost": return rc.offbeat_cost(a[0])
		"skill_cost": return rc.skill_cost(a[0], a[1])
		"can_learn": return rc.can_learn(a[0], a[1], a[2])
		"rank_gap": return rc.rank_gap(a[0], a[1])
		"rank_damage_k": return rc.rank_damage_k(a[0], a[1])
		"shrugs_off": return rc.shrugs_off(a[0], a[1])
		"immune_lower": return rc.immune_lower(a[0], a[1])
		"one_shot": return rc.one_shot(a[0], a[1])
		"skill_ko": return rc.skill_ko(a[0], a[1])
		"stun_sec": return rc.stun_sec(a[0], a[1], a[2])
		"lethal_fraction": return rc.lethal_fraction(a[0], a[1], a[2], a[3])
		"roulette_reflects": return rc.roulette_reflects(a[0], a[1])
		"progress_at": return rc.progress(a[0], rc.events_until(int(a[1])), a[2])
	return "모르는 함수 " + fn


## 같은가 — 수(int · float)끼리는 1e-9, 배열은 자리마다, 그 밖(bool · 문자열 · null)은 종류와 값이 같아야
func _same(got, want) -> bool:
	var num := [TYPE_INT, TYPE_FLOAT]
	if typeof(want) in num and typeof(got) in num:
		return absf(float(got) - float(want)) <= EPS
	if typeof(want) == TYPE_ARRAY and typeof(got) == TYPE_ARRAY:
		if want.size() != got.size():
			return false
		for i in want.size():
			if not _same(got[i], want[i]):
				return false
		return true
	return typeof(got) == typeof(want) and got == want


func test_rules_cases_all() -> void:
	var rc := _rules()
	var cases := _cases()
	check(cases.size() >= MIN_ROWS, "cases 를 읽었다 (%d줄 · 바란 값 %d줄 이상)" % [cases.size(), MIN_ROWS])
	var fns := {}
	var bad := 0
	for c in cases:
		var fn: String = c["fn"]
		fns[fn] = int(fns.get(fn, 0)) + 1
		var got = _call(rc, fn, c["args"])
		if not _same(got, c["want"]):
			bad += 1
			if bad <= 10:
				failures.append("%s%s = %s, 기대 %s" % [fn, c["args"], got, c["want"]])
	check(bad == 0, "cases %d줄 중 %d줄 다름" % [cases.size(), bad])
	check(fns.size() == N_FN, "시험 함수 %d개 (%s)" % [fns.size(), fns.keys()])
	print("common cases: %d줄 · 함수 %d개 · 다름 %d" % [cases.size(), fns.size(), bad])


## ranks.json 최상위에 모르는 칸(below · strength · strength_ref)이 있어도 ladder 만 등급으로 읽는다
func test_ranks_ladder_only() -> void:
	var rc := _rules()
	eq(rc.ranks.size(), 15, "사다리 15개")
	eq(rc.ranks[0], "건달급", "가장 아래")
	eq(rc.ranks[14], "재앙", "가장 위")
	eq(rc.rank_index("내성 중위"), 11, "내성 중위 번호")
	eq(rc.rank_index("없는 등급"), -1, "모르는 등급은 -1(시뮬은 찍지 않는다 — 표 검사가 먼저 잡는다)")


## cases 가 닿지 않는 갈래 — 모르는 기술 · 인물(빈 사전으로 다룬다) · rank_at_most 빈 값 · 진행 단계 끝 넘기
func test_edges_not_in_cases() -> void:
	var rc := _rules()
	eq(rc.rank_at_most("톱", null), false, "rank_at_most(빈 값) 은 거짓")
	eq(rc.rank_at_most("톱", ""), false, "rank_at_most(\"\") 은 거짓")
	eq(rc.skill_cost("없는_기술", "톱"), 1.0, "모르는 기술의 비용은 기본 1칸")
	eq(rc.can_learn("없는_기술", "건달급"), true, "모르는 기술은 거르지 않는다")
	eq(rc.progress("없는_인물"), ["", []], "모르는 인물은 빈 등급 · 빈 목록")
	var all: Array = rc.events_until(9999)
	eq(all.size(), rc.events_until(all.size()).size(), "단계가 사건 수를 넘으면 전부")
