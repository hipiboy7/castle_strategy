extends RefCounted
## 시험 공통 — check · eq · 기대값 파일 읽기. tests/unit/* · tests/integration/* 가 extends "res://tests/helpers.gd" 로 쓴다.
## 러너: tests/run_tests.gd (CLAUDE.md 3절). 기대값: tests/unit/rng_vectors.json — tools/rng_ref.py --write 가 만든다.

var failures: Array = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


## 형과 값이 모두 같아야 한다 — 정수와 실수를 섞지 않는다(상태는 정수만 — 설계서 3-3)
func eq(got, want, msg: String) -> void:
	if typeof(got) != typeof(want) or got != want:
		failures.append("%s — 받은 값 %s · 바란 값 %s" % [msg, var_to_str(got), var_to_str(want)])


## 기준 구현이 만든 기대값. 없으면 빈 사전(시험이 '기대값 파일 없음'으로 실패한다)
static func vectors() -> Dictionary:
	var path := "res://tests/unit/rng_vectors.json"
	if not FileAccess.file_exists(path):
		return {}
	var v = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}


## JSON 수(실수)를 정수 배열로 — 2^53 아래만 정확하다(기대값 파일은 32비트 두 쪽으로 쓴다)
static func ints(a: Array) -> Array:
	var out := []
	for x in a:
		out.append(int(x))
	return out
