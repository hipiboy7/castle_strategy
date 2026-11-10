extends Control
## 진입점(main.tscn) — 실행 인자(src/launch.gd)에 따라:
##   --autoplay  화면 없이 자동 진행(C1-0 은 빈 시뮬)을 돌려 RESULT 한 줄을 찍고 끝낸다(scripts/verify.py 가 읽는다)
##   (없음)      화면(ui/home.gd)을 띄운다. --shot PATH 면 --shot-frame 번째 프레임을 PNG 로 찍고 끝낸다(xvfb · CI)
## 인자가 틀리면 ARGS 줄을 찍고 종료 코드 2. 요구: FR-106 · FR-107 · 설계: docs/C1_설계서_상태와턴.md 1절

const Launch = preload("res://src/launch.gd")
const Stub = preload("res://sim/stub_turn.gd")
const StateHash = preload("res://sim/hash.gd")
const Home = preload("res://ui/home.gd")
const GAME_VERSION := "0.1.0"
const SOURCE := "res://data/common/SOURCE.json"

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
		var s: Dictionary = Stub.run(_args["seed"], _args["turns"])
		print("RESULT " + JSON.stringify({"turns": _args["turns"], "seed": _args["seed"], "acc": s["acc"], "hash": StateHash.of(s)}))
		get_tree().quit(0)
		return
	var home = Home.new()
	home.version = GAME_VERSION
	home.common_sha = _common_sha()
	add_child(home)
	set_process(_args["shot"] != "")


func _process(_dt: float) -> void:
	_frames += 1
	if _frames != int(_args["shot_frame"]):
		return
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(_args["shot"])
	print("SHOT %s %s" % [_args["shot"], "ok" if err == OK else "fail"])
	get_tree().quit(0 if err == OK else 1)


## 받은 castle_common 판(SOURCE.json — 받기 전이면 "")
func _common_sha() -> String:
	if not FileAccess.file_exists(SOURCE):
		return ""
	var d = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	return String(d.get("castle_common", "")).substr(0, 7) if d is Dictionary else ""
