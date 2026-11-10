extends RefCounted
## 저장소 입출력 — 글을 user:// 에 쓰고 읽는 얇은 층(판정 없음 · sim/ 은 파일을 쓰지 않는다 — CLAUDE.md 2절 DIP).
## 쓰기는 같은 폴더의 임시 파일 → 이름 바꾸기라, 중간에 끊겨도 옛 파일이 남는다. 저장 형식은 docs/C1_설계서_상태와턴.md 3-7.
## 시험: tests/integration/test_save_resume.gd


static func write_text(path: String, text: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path)) == OK


## 없거나 못 열면 ""
static func read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text
