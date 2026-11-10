extends "res://tests/helpers.gd"
## FR-106 — C1-0 빈 시뮬(sim/stub_turn.gd)이 기준 구현(tools/rng_ref.py stub_run)과 같은 해시를 내고 순수 함수인지.
## 시드 1 · 26턴 해시는 폰 자가 해시 기대값이다(docs/폰확인.md).

const Stub = preload("res://sim/stub_turn.gd")
const StateHash = preload("res://sim/hash.gd")


func test_matches_reference() -> void:
	var cases: Array = vectors().get("stub", [])
	check(cases.size() == 3, "기대값 stub 3개(시드 1 · 2 · 3)")
	for c in cases:
		var s: Dictionary = Stub.run(int(c["seed"]), int(c["turns"]))
		eq(s["acc"], int(c["acc"]), "시드 %d acc" % int(c["seed"]))
		eq(s["turn"], int(c["turns"]) + 1, "시드 %d 다음 턴" % int(c["seed"]))
		eq(StateHash.of(s), String(c["hash"]), "시드 %d 해시" % int(c["seed"]))


func test_step_is_pure() -> void:
	var s0: Dictionary = Stub.new_state(5)
	var before := s0.duplicate(true)
	var s1: Dictionary = Stub.step(s0)
	eq(s0, before, "step 은 입력 상태를 바꾸지 않는다")
	eq(s1["turn"], 2, "턴이 하나 오른다")
	check(s1["acc"] != s0["acc"] or s1["last"] != 0, "수가 섞였다")


func test_seed_changes_hash() -> void:
	eq(StateHash.of(Stub.run(9, 10)), StateHash.of(Stub.run(9, 10)), "같은 시드는 같은 해시")
	check(StateHash.of(Stub.run(9, 10)) != StateHash.of(Stub.run(10, 10)), "다른 시드는 다른 해시")


func test_from_dict_restores_ints() -> void:
	var s: Dictionary = Stub.run(4, 3)
	var back: Dictionary = Stub.from_dict(JSON.parse_string(StateHash.canonical(s)))   # JSON 수는 실수로 온다
	eq(StateHash.of(back), StateHash.of(s), "저장 글 → 정수 상태 → 같은 해시")


func test_from_dict_rejects_bad_input() -> void:
	eq(Stub.from_dict(null), {}, "null 은 빈 사전")
	eq(Stub.from_dict({"v": 1, "seed": 1}), {}, "칸이 모자라면 빈 사전")
	eq(Stub.from_dict([1, 2]), {}, "사전이 아니면 빈 사전")
