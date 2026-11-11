extends "res://tests/helpers.gd"
## FR-404 — 화면 방향 · 기준 크기(ui/fight3d/screen_mode.gd): 전투 화면만 가로 1280×720, 그 밖은 세로 1080×1920.
## 기기의 화면 방향은 Android 에서만 바꾼다 — 여기서는 창 기준 크기와 돌려주는 값만 본다(순수 로직).

const ScreenMode = preload("res://ui/fight3d/screen_mode.gd")


func test_mode_for() -> void:
	var f := ScreenMode.mode_for(true)
	eq(f["size"], Vector2i(1280, 720), "전투 화면 기준 크기(castle_M3D 와 같다)")
	eq(f["orientation"], DisplayServer.SCREEN_SENSOR_LANDSCAPE, "전투 화면은 가로(센서)")
	eq(f["landscape"], true, "가로")
	var p := ScreenMode.mode_for(false)
	eq(p["size"], Vector2i(1080, 1920), "지도 · 명령 · 보고 기준 크기(CLAUDE.md 0절)")
	eq(p["orientation"], DisplayServer.SCREEN_PORTRAIT, "세로")
	eq(p["landscape"], false, "세로")


func test_apply_sets_window_scale_size() -> void:
	var w := Window.new()
	var m := ScreenMode.apply(w, true, "Linux")
	eq(w.content_scale_size, Vector2i(1280, 720), "들어갈 때 창 기준 크기를 가로로")
	eq(m["landscape"], true, "돌려주는 값")
	ScreenMode.apply(w, false, "Linux")
	eq(w.content_scale_size, Vector2i(1080, 1920), "나올 때 세로로 되돌린다")
	w.free()
