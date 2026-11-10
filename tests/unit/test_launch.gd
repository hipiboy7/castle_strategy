extends "res://tests/helpers.gd"
## FR-105 — 실행 인자 파서(src/launch.gd — 순수 함수). 잘못된 값은 오류 목록으로 돌려준다(그 자리에서 끝내지 않는다).

const Launch = preload("res://src/launch.gd")


func _p(a: Array) -> Dictionary:
	return Launch.parse(PackedStringArray(a))


func test_defaults() -> void:
	var a := _p([])
	eq(a["autoplay"], false, "자동 진행 꺼짐")
	eq(a["turns"], 26, "기본 26턴(08 2절 주 시나리오)")
	eq(a["seed"], 1, "기본 시드 1")
	eq(a["shot"], "", "스크린샷 없음")
	eq(a["shot_frame"], 30, "스크린샷 프레임 기본 30")
	eq(a["errors"], [], "오류 없음")


func test_autoplay_turns_seed() -> void:
	var a := _p(["--autoplay", "--turns", "52", "--seed", "-7"])
	eq(a["autoplay"], true, "--autoplay")
	eq(a["turns"], 52, "--turns 52")
	eq(a["seed"], -7, "음수 시드도 된다")
	eq(a["errors"], [], "오류 없음")


func test_shot() -> void:
	var a := _p(["--shot", "/tmp/a.png", "--shot-frame", "12"])
	eq(a["shot"], "/tmp/a.png", "--shot 경로")
	eq(a["shot_frame"], 12, "--shot-frame")


func test_errors() -> void:
	eq(_p(["--bogus"])["errors"].size(), 1, "모르는 인자")
	eq(_p(["--turns"])["errors"].size(), 1, "값 없는 --turns")
	eq(_p(["--turns", "abc"])["errors"].size(), 1, "정수가 아닌 --turns")
	eq(_p(["--turns", "0"])["errors"].size(), 1, "--turns 는 1 이상")
	eq(_p(["--shot"])["errors"].size(), 1, "경로 없는 --shot")
	eq(_p(["--shot-frame", "0"])["errors"].size(), 1, "--shot-frame 은 1 이상")
	eq(_p(["--seed", "x", "--autoplay"])["autoplay"], true, "오류 뒤 인자도 계속 읽는다")
