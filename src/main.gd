extends Control
## 진입점(main.tscn) — 실행 인자(src/launch.gd)에 따라:
##   --autoplay  화면 없이 시나리오 A 를 --turns 턴 자동 진행(모든 조직 AI)하고 RESULT 한 줄을 찍고 끝낸다(scripts/verify.py 가 읽는다).
##               불변식 위반이 있으면 VIOLATION 줄 · 종료 코드 1, 데이터 오류면 DATA 줄 · 종료 코드 3
##   --fight-test 화면 없이 전투 시험 구간(src/fight_test.gd)을 봇으로 끝까지 돌리고 FIGHT 한 줄을 찍고 끝낸다(C4 FR-405 · verify '구간 전투').
##               끝나지 않으면 종료 코드 1. --shot 과 함께면 화면을 띄운다(전투 화면 스크린샷 — ui/app.gd)
##   (없음)      화면(ui/app.gd)을 띄운다. --shot PATH 면 --shot-frame 번째 프레임을 PNG 로 찍고 끝낸다(xvfb · CI)
## 인자가 틀리면 ARGS 줄을 찍고 종료 코드 2. 요구: FR-106 · FR-107 · FR-119 · 설계: docs/C1_설계서_상태와턴.md 1절

const Launch = preload("res://src/launch.gd")
const DataFiles = preload("res://src/data_files.gd")
const Game = preload("res://sim/game.gd")
const State = preload("res://sim/state.gd")
const App = preload("res://ui/app.gd")
const FightTest = preload("res://src/fight_test.gd")
const GAME_VERSION := "0.2.0"
const SCENARIO := "A"

var _args: Dictionary = {}
var _frames := 0


func _ready() -> void:
	_args = Launch.parse(OS.get_cmdline_user_args())
	if not _args["errors"].is_empty():
		for e in _args["errors"]:
			print("ARGS " + e)
		get_tree().quit(2)
		return
	if _args["autoplay"]:
		get_tree().quit(_autoplay())
		return
	if _args["fight_test"] and _args["shot"] == "":
		get_tree().quit(_fight_test())
		return
	var app = App.new()
	app.version = GAME_VERSION
	app.common_sha = DataFiles.source_sha().substr(0, 7)
	app.args = _args
	add_child(app)
	set_process(_args["shot"] != "")


func _process(_dt: float) -> void:
	_frames += 1
	if _frames != int(_args["shot_frame"]):
		return
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(_args["shot"])
	print("SHOT %s %s" % [_args["shot"], "ok" if err == OK else "fail"])
	get_tree().quit(0 if err == OK else 1)


func _fight_test() -> int:
	var t: Dictionary = DataFiles.load_tables()
	if not t["errors"].is_empty():
		for e in t["errors"]:
			print("DATA " + e)
		return 3
	var r: Dictionary = FightTest.run(t, _args["seed"])
	print("FIGHT " + JSON.stringify(r))
	return 0 if r["over"] != "" else 1


func _autoplay() -> int:
	var t: Dictionary = DataFiles.load_tables()
	if not t["errors"].is_empty():
		for e in t["errors"]:
			print("DATA " + e)
		return 3
	var a: Dictionary = Game.autoplay(t, SCENARIO, _args["seed"], _args["turns"])
	var cash := {}
	for org in State.sorted_keys(a["state"]["orgs"]):
		cash[org] = a["state"]["orgs"][org]["cash"]
	print("RESULT " + JSON.stringify({"turns": _args["turns"], "seed": _args["seed"], "scenario": SCENARIO, "hash": a["hash"],
		"violations": a["violations"].size(), "cash": cash}))
	for v in a["violations"]:
		print("VIOLATION " + v)
	return 0 if a["violations"].is_empty() else 1
