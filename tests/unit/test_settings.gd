extends "res://tests/helpers.gd"
## C4-2 FR-417 — 설정(src/settings.gd): 기본값 = 매번 묻기 · 넷 중 하나를 쓰고 읽으면 그대로 · 깨진 글 · 모르는 값은 기본값 + 알림.
## 파일은 user://test_settings.json(시험 뒤 지운다)

const Settings = preload("res://src/settings.gd")
const PATH := "user://test_settings.json"


func test_defaults_and_round_trip() -> void:
	eq(Settings.read(PATH + ".none")["settings"]["fight_mode"], "ask", "파일이 없으면 매번 묻기")
	for m in Settings.MODES:
		check(Settings.write({"fight_mode": m}, PATH), "쓰기 %s" % m)
		var r := Settings.read(PATH)
		eq([r["settings"]["fight_mode"], r["note"]], [m, ""], "읽으면 그대로 %s" % m)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_broken_or_unknown() -> void:
	var r := Settings.from_text("{깨짐")
	eq(r["settings"]["fight_mode"], "ask", "깨진 글 = 기본값")
	check(r["note"] != "", "깨짐 알림")
	eq(Settings.from_text("{\"format\":\"other\"}")["settings"]["fight_mode"], "ask", "다른 형식 = 기본값")
	var u := Settings.from_text(Settings.to_text({"fight_mode": "direct"}).replace("direct", "turbo"))
	eq(u["settings"]["fight_mode"], "ask", "모르는 값 = 기본값")
	check(u["note"].contains("turbo"), "모르는 값 알림")
	eq(JSON.parse_string(Settings.to_text({"fight_mode": "x"}))["fight_mode"], "ask", "쓸 때도 모르는 값은 기본값")
