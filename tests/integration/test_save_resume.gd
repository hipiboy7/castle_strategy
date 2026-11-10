extends "res://tests/helpers.gd"
## FR-118(흐름) — 시나리오 A: 10턴 → 저장(src/storage.gd · user://) → 불러오기 → 16턴 = 처음부터 26턴과 같은 해시.
## 상태 없이 명령 기록만으로 다시 돌려도(같은 명령) 같은 해시. C1-0 빈 시뮬 저장(v0)은 같은 시드의 새 판으로 연다.
## 쓰기는 임시 파일 → 이름 바꾸기(남는 임시 파일 없음). 없는 파일은 빈 문자열.

const Game = preload("res://sim/game.gd")
const Save = preload("res://sim/save.gd")
const State = preload("res://sim/state.gd")
const Tables = preload("res://sim/tables.gd")
const DataFiles = preload("res://src/data_files.gd")
const Storage = preload("res://src/storage.gd")
const PATH := "user://test_save_resume.json"

var _tables := {}


func _t() -> Dictionary:
	if _tables.is_empty():
		_tables = DataFiles.load_tables()
	return _tables


func _meta(g: Dictionary) -> Dictionary:
	return {"game_version": "test", "castle_common": DataFiles.source_sha(), "seed": g["state"]["seed"],
		"scenario": g["state"]["scenario"], "player": g["state"]["player"], "mode": g["state"]["mode"]}


func test_save_load_resume_equals_straight_run() -> void:
	var t := _t()
	var straight: Dictionary = Game.autoplay(t, "A", 3, 26)
	var g: Dictionary = Game.new_game(t, "A", 3)
	for i in 10:
		Game.step(g, t)
	check(Storage.write_text(PATH, Save.to_text(Save.make(_meta(g), g["state"], g["log"]))), "쓰기")
	check(not FileAccess.file_exists(PATH + ".tmp"), "임시 파일이 남지 않는다")
	var r: Dictionary = Save.from_text(Storage.read_text(PATH), t)
	eq(r["errors"], [], "읽기 오류 없음")
	var back: Dictionary = Game.from_save(r["save"], t)
	eq(back["errors"], [], "이어 하기 준비")
	eq(back["state"]["turn"], 11, "11턴부터")
	for i in 16:
		Game.step(back, t)
	eq(State.hash_of(back["state"]), straight["hash"], "10턴 저장 → 불러오기 → 16턴 = 26턴 한 번에")
	eq(back["log"].size(), 26, "명령 기록 26턴")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_replay_from_log_only() -> void:
	var t := _t()
	var a: Dictionary = Game.autoplay(t, "A", 2, 12)
	var sv := Save.make(_meta(a), {}, a["log"])
	var g: Dictionary = Game.from_save(sv, t)
	eq(g["errors"], [], "다시 돌리기 오류 없음")
	eq(State.hash_of(g["state"]), a["hash"], "상태 없이 명령 기록(같은 명령)만으로 같은 해시")


func test_v0_file_opens_new_game_with_same_seed() -> void:
	var t := _t()
	check(Storage.write_text(PATH, "{\"acc\":1,\"last\":2,\"seed\":5,\"turn\":13,\"v\":1}"), "C1-0 저장 쓰기")
	var r: Dictionary = Save.from_text(Storage.read_text(PATH), t)
	var g: Dictionary = Game.from_save(r["save"], t)
	eq(g["errors"], [], "열린다")
	eq(g["state"]["turn"], 1, "새 판 1턴")
	eq(g["state"]["seed"], 5, "시드는 이어 받는다")
	check(Storage.write_text(PATH, "덮어쓰기"), "있는 파일 덮어쓰기")
	eq(Storage.read_text(PATH), "덮어쓰기", "덮어쓴 내용")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_read_missing_is_empty() -> void:
	eq(Storage.read_text("user://없는_파일_c1.json"), "", "없는 파일은 빈 문자열")
