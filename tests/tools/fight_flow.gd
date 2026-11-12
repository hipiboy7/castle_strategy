extends SceneTree
## C4-2 화면 흐름 점검(FR-416~418 · 손으로 돌림 — tests/run_tests.gd 가 돌지 않는다):
##   <godot> --headless --fixed-fps 60 --path . -s res://tests/tools/fight_flow.gd -- <auto|ask|result>
## 앱(ui/app.gd)을 창 없이 띄워 시나리오 A 부진파 간부 넷을 남구로 옮기고 북구 습격 → 주 끝내기 → 전투 방식(ask 면 창이 뜬 뒤 '자동 플레이 보기')
## → 전투 화면이 구간을 잇고 → 보고. 'DONE … fights=[…] sheet=report' 와 보고 전투 줄을 찍는다. 저장은 하지 않는다(ephemeral).
const App = preload("res://ui/app.gd")
const Orders = preload("res://sim/orders.gd")
var app
var n := 0
var mode := "auto"
func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: mode = a[0]
	app = App.new()
	app.args = {"shot": "x", "seed": 1, "errors": [], "autoplay": false, "fight_test": false, "view": "", "week": 0, "zone": ""}
	root.add_child(app)
func _process(_dt) -> bool:
	n += 1
	if n == 3:
		var t = app._t
		app._g = load("res://sim/game.gd").new_game(t, "A", 1, "bujinpa")
		var s = app._g["state"]
		s["zones"]["namgu"]["owner"] = "bujinpa"
		var cfg = t["fight"]["test"]["raid"]
		for id in cfg["by"]:
			s["officers"][id]["zone"] = "namgu"
		app._draft = cfg["by"].map(func(id): return Orders.make("bujinpa", id, "raid", "bukgu", {"cards": cfg["cards"]}))
		app._settings["fight_mode"] = mode
		app._phase = "play"
		app._sheet = ""
		app._end_week()
	if n == 5 and mode == "ask":
		print("ASK visible=", app._ask.visible)
		app._ask.hide()
		app._go("auto")
	if n > 5 and app._fight == null and n % 30 == 0:
		var g = app._g
		print("DONE turn=", g["state"]["turn"], " log=", g["log"].size(), " fights=", g["log"][-1]["fights"].keys() if g["log"].size() > 0 else [], " sheet=", app._sheet)
		var b = g["reports"][-1]["report"]["battles"].filter(func(x): return x["zone"] == "bukgu")
		for l in load("res://ui/view.gd").battle_lines(b[0], app._t, "bujinpa"):
			print(l)
		quit()
		return true
	if n > 20000:
		print("TIMEOUT fight=", app._fight)
		quit(1)
	return false
