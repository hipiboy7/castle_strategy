extends RefCounted
## 데이터 파일 읽기 — 바깥 얇은 층(판정 없음). res://data/ 아래 상대 경로 목록 → {"files": {경로: JSON 값}, "errors": [...]}.
## sim/ 은 파일을 읽지 않는다(CLAUDE.md 2절 DIP) — 이 결과의 "files" 를 sim/tables.gd build 에 넘긴다.
## 받은 사본: data/common/(castle_common 이 원본 · 손대지 않음) · 3층 표: data/game/. 설계: docs/C1_설계서_상태와턴.md 1절 · 요구: FR-113

const Tables = preload("res://sim/tables.gd")
const ROOT := "res://data/"
const SOURCE := "common/SOURCE.json"


static func read(paths: Array, root: String = ROOT) -> Dictionary:
	var files := {}
	var errors := []
	for p in paths:
		var path: String = root + String(p)
		if not FileAccess.file_exists(path):
			errors.append("%s — 파일이 없다" % p)
			continue
		var j := JSON.new()
		if j.parse(FileAccess.get_file_as_string(path)) != OK:
			errors.append("%s — JSON %d줄: %s" % [p, j.get_error_line(), j.get_error_message()])
			continue
		files[p] = j.data
	return {"files": files, "errors": errors}


## 받은 castle_common 커밋(SOURCE.json — 받기 전이면 "")
static func source_sha(root: String = ROOT) -> String:
	var r := read([SOURCE], root)
	var d = r["files"].get(SOURCE)
	return String(d.get("castle_common", "")) if d is Dictionary else ""


## 정적 표 — sim/tables.gd NEEDS 를 읽어 build(없는 파일도 t["errors"] 에 든다)
static func load_tables(root: String = ROOT) -> Dictionary:
	return Tables.build(read(Tables.NEEDS, root)["files"])
