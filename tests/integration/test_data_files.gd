extends "res://tests/helpers.gd"
## FR-111 · FR-113 — src/data_files.gd(바깥 얇은 층): 받은 사본 읽기 · 없는 파일 · 깨진 JSON 은 오류 목록 · SOURCE.json 도장의 커밋.

const DataFiles = preload("res://src/data_files.gd")
const TMP := "user://test_data_files/"


func test_reads_received_copy_and_stamp() -> void:
	var r: Dictionary = DataFiles.read(["common/ranks.json"])
	eq(r["errors"], [], "받은 사본을 읽는다")
	check(r["files"]["common/ranks.json"] is Dictionary, "JSON 값")
	var sha := DataFiles.source_sha()
	eq(sha.length(), 40, "SOURCE.json 의 castle_common 커밋(40자): %s" % sha)


func test_missing_and_broken_files_are_errors() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP))
	var f := FileAccess.open(TMP + "broken.json", FileAccess.WRITE)
	f.store_string("{\"a\": ")
	f.close()
	var r: Dictionary = DataFiles.read(["broken.json", "none.json"], TMP)
	eq(r["files"], {}, "읽은 것 없음")
	eq(r["errors"].size(), 2, "오류 둘: %s" % [r["errors"]])
	check(String(r["errors"][0]).begins_with("broken.json — JSON"), "깨진 JSON")
	check(String(r["errors"][1]).begins_with("none.json — 파일이 없다"), "없는 파일")
	eq(DataFiles.source_sha(TMP), "", "도장이 없으면 빈 글")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP + "broken.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
