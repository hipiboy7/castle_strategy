extends "res://tests/helpers.gd"
## FR-104 — sim/hash.gd 의 정규형 JSON 과 해시가 기준 구현(tools/rng_ref.py HASH_VALUES)과 같은지.
## 같은 값이면 키 순서와 상관없이 같은 해시 · 실수와 문자열이 아닌 키는 거절(빈 문자열 + 까닭). 설계: 3-2

const StateHash = preload("res://sim/hash.gd")


## tools/rng_ref.py HASH_VALUES 와 같은 이름 · 같은 값
func _values() -> Dictionary:
	return {
		"empty": {},
		"nested": {"b": 1, "a": [3, 1, 2], "B": {"z": true, "y": null}, "가": "값"},
		"escape": {"s": "따옴표\" 역슬래시\\ 줄\n탭\t제어" + String.chr(1)},
		"ints": {"n": -5, "big": 4294967295, "zero": 0},
	}


func test_matches_reference() -> void:
	var want: Dictionary = vectors().get("hash", {})
	var vals := _values()
	check(want.size() == vals.size(), "기대값 이름 수가 다르다 — tools/rng_ref.py HASH_VALUES 와 맞춘다")
	for k in vals:
		if not want.has(k):
			check(false, "기대값에 %s 가 없다" % k)
			continue
		eq(StateHash.canonical(vals[k]), String(want[k]["text"]), "정규형 %s" % k)
		eq(StateHash.of(vals[k]), String(want[k]["hash"]), "해시 %s" % k)


func test_key_order_does_not_matter() -> void:
	var a := {"x": 1, "y": {"p": 2, "q": [3, 4]}}
	var b := {"y": {"q": [3, 4], "p": 2}, "x": 1}
	eq(StateHash.of(a), StateHash.of(b), "키 순서가 달라도 같은 해시")


func test_array_order_matters() -> void:
	check(StateHash.of([1, 2]) != StateHash.of([2, 1]), "배열은 순서가 값이다")


func test_rejects_float() -> void:
	eq(StateHash.canonical({"x": 1.5}), "", "실수가 있으면 정규형은 빈 문자열")
	eq(StateHash.of({"x": [1, 2.0]}), "", "실수가 있으면 해시도 빈 문자열")
	check(StateHash.check({"x": 0.5}).contains("실수"), "까닭에 '실수'")


func test_rejects_non_string_key() -> void:
	eq(StateHash.canonical({1: "a"}), "", "정수 키는 거절")
	check(StateHash.check({1: "a"}).contains("키"), "까닭에 '키'")


func test_valid_value_has_no_reason() -> void:
	eq(StateHash.check({"a": [1, "b", null, true]}), "", "올바른 값은 까닭 없음")
	eq(StateHash.of({"a": 1}).length(), 16, "해시는 16자")
