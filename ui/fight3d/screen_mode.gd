extends RefCounted
## 화면 방향 · 기준 크기 — 지도 · 명령 · 보고는 세로(1080×1920), 실시간 전투 화면만 가로(1280×720 — castle_M3D 의 기준 크기:
## 옮겨 온 터치 단추 · 표시 크기가 이 기준에 맞춰져 있다). 들어갈 때 enter, 나올 때 leave(docs/기획_차이.md (나)47).
## mode_for 는 순수 함수(시험 tests/unit/test_fight_screen.gd), apply 만 창 · 기기를 건드린다 — 화면 방향은 Android 에서만 바꾼다
## (작업 서버 · CI 의 창은 실행 인자 --resolution 이 정한다). 설계: docs/C4_설계서_직접조작전투.md 6절 · 요구: FR-404

const PORTRAIT := Vector2i(1080, 1920)
const LANDSCAPE := Vector2i(1280, 720)


## 전투 화면인가 → {"size": 창 기준 크기, "orientation": DisplayServer.ScreenOrientation 값, "landscape": 가로인가}
static func mode_for(fight: bool) -> Dictionary:
	if fight:
		return {"size": LANDSCAPE, "orientation": DisplayServer.SCREEN_SENSOR_LANDSCAPE, "landscape": true}
	return {"size": PORTRAIT, "orientation": DisplayServer.SCREEN_PORTRAIT, "landscape": false}


static func apply(win: Window, fight: bool, os_name: String = OS.get_name()) -> Dictionary:
	var m := mode_for(fight)
	win.content_scale_size = m["size"]
	if os_name == "Android":
		DisplayServer.screen_set_orientation(m["orientation"])
	return m
