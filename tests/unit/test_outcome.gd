extends "res://tests/helpers.gd"
## FR-307 — 승패(sim/outcome.gd): A 목표 hold_all(판의 구역을 모두 차지) · 두목 잡힘 · 구역 0 · 판 길이 · 한 번 나면 그대로 · 목표 없는 시나리오는 보지 않음.

const Outcome = preload("res://sim/outcome.gd")
const Game = preload("res://sim/game.gd")
const DataFiles = preload("res://src/data_files.gd")

var _tables := {}


func _t() -> Dictionary:
	if _tables.is_empty():
		_tables = DataFiles.load_tables()
	return _tables


func _a() -> Dictionary:
	return Game.new_game(_t(), "A", 1)["state"]


func test_win_hold_all() -> void:
	var s := _a()
	eq(Outcome.verdict(s, _t()), {}, "처음엔 아직")
	for z in s["zones"]:
		s["zones"][z]["owner"] = "bujinpa"
	eq(Outcome.verdict(s, _t()), {"result": "win", "why": "hold_all"}, "판의 구역을 모두 차지")
	var ctx := {"t": _t(), "report": {"events": []}}
	Outcome.judge(s, ctx)
	eq([s["flags"]["result"], s["flags"]["result_turn"], s["flags"]["result_why"]], ["win", 1, "hold_all"], "flags 에 남긴다")
	eq(ctx["report"]["events"][0]["kind"], "outcome", "보고 사건")
	check(Outcome.over(s), "끝남")
	for z in s["zones"]:
		s["zones"][z]["owner"] = ""
	eq(Outcome.verdict(s, _t()), {}, "한 번 나면 다시 보지 않는다")


func test_lose_cases() -> void:
	var s := _a()
	s["officers"]["kimshin"]["status"] = "captive"
	eq(Outcome.verdict(s, _t())["why"], "boss", "두목이 잡힘")
	s = _a()
	for z in s["zones"]:
		if s["zones"][z]["owner"] == "bujinpa":
			s["zones"][z]["owner"] = "dssecurity"
	eq(Outcome.verdict(s, _t())["why"], "zones", "구역을 모두 잃음")
	s = _a()
	s["turn"] = 26
	eq(Outcome.verdict(s, _t()), {"result": "lose", "why": "time"}, "판 길이 마지막 주에 못 이룸")
	s = _a()
	s["scenario"] = "B"
	s["turn"] = 26
	eq(Outcome.verdict(s, _t()), {}, "목표가 없는 시나리오(C5)는 보지 않는다")
