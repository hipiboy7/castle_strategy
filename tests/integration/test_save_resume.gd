extends "res://tests/helpers.gd"
## FR-106 · FR-118(작은 판) — src/storage.gd 로 user:// 에 빈 시뮬 상태를 쓰고 읽어 이어 하면 처음부터 한 것과 같은 해시인지.
## 쓰기는 임시 파일 → 이름 바꾸기(남는 임시 파일 없음). 없는 파일은 빈 문자열.

const Stub = preload("res://sim/stub_turn.gd")
const StateHash = preload("res://sim/hash.gd")
const Storage = preload("res://src/storage.gd")
const PATH := "user://test_save_resume.json"


func test_save_load_resume_equals_straight_run() -> void:
	var mid: Dictionary = Stub.run(3, 13)
	check(Storage.write_text(PATH, StateHash.canonical(mid)), "쓰기")
	check(not FileAccess.file_exists(PATH + ".tmp"), "임시 파일이 남지 않는다")
	var s: Dictionary = Stub.from_dict(JSON.parse_string(Storage.read_text(PATH)))
	for i in 13:
		s = Stub.step(s)
	eq(StateHash.of(s), StateHash.of(Stub.run(3, 26)), "13턴 저장 → 불러오기 → 13턴 = 26턴 한 번에")
	check(Storage.write_text(PATH, "덮어쓰기"), "있는 파일 덮어쓰기")
	eq(Storage.read_text(PATH), "덮어쓰기", "덮어쓴 내용")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_read_missing_is_empty() -> void:
	eq(Storage.read_text("user://없는_파일_c1_0.json"), "", "없는 파일은 빈 문자열")
