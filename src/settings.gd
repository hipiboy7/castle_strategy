extends RefCounted
## 설정 — user://settings.json(판 저장과 따로). 지금은 전투 방식 기본값 하나(C4-2 · FR-417):
##   {"format": "castle_strategy.settings", "v": 1, "fight_mode": "ask" | "direct" | "auto" | "result"}
## ask = 내 전투를 만날 때마다 창으로 묻는다(기본) · direct = 늘 직접 · auto = 늘 자동 플레이 보기 · result = 늘 결과만(틱).
## 깨졌거나 모르는 값이면 기본값(알림 한 줄). 읽기 · 쓰기는 src/storage.gd(임시 파일 → 이름 바꾸기).
## 설계: docs/C4_설계서_직접조작전투.md 7절 · 요구: FR-417 · 시험: tests/unit/test_settings.gd

const Storage = preload("res://src/storage.gd")
const PATH := "user://settings.json"
const FORMAT := "castle_strategy.settings"
const MODES := ["ask", "direct", "auto", "result"]


static func defaults() -> Dictionary:
	return {"format": FORMAT, "v": 1, "fight_mode": "ask"}


## 글 → {"settings": 사전(늘 맞는 꼴), "note": "" | 알림}
static func from_text(text: String) -> Dictionary:
	var out := defaults()
	if text == "":
		return {"settings": out, "note": ""}
	var j := JSON.new()
	var d = j.data if j.parse(text) == OK else null
	if not (d is Dictionary) or d.get("format") != FORMAT:
		return {"settings": out, "note": "설정 파일이 깨져 기본값으로"}
	var note := ""
	var m = d.get("fight_mode", "ask")
	if MODES.has(m):
		out["fight_mode"] = m
	else:
		note = "모르는 전투 방식 %s — 기본값(매번 묻기)" % str(m)
	return {"settings": out, "note": note}


static func to_text(st: Dictionary) -> String:
	var out := defaults()
	if MODES.has(st.get("fight_mode")):
		out["fight_mode"] = st["fight_mode"]
	return JSON.stringify(out, "", true)


static func read(path := PATH) -> Dictionary:
	return from_text(Storage.read_text(path))


static func write(st: Dictionary, path := PATH) -> bool:
	return Storage.write_text(path, to_text(st))
