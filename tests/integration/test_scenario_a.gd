extends "res://tests/helpers.gd"
## FR-119 — 경영만 하는 규칙 AI(sim/ai.gd)로 시나리오 A 의 모든 조직을 headless 26턴. 매 턴 불변식 위반 0 · 죽거나 움직일 수 없는
## 간부의 명령 적용 0 · 해시가 기준값(tests/integration/golden_a.json)과 같고 두 번 돌려도 같다.
## 기준값을 바꾸는 것은 시뮬 · AI · 3층 값을 일부러 바꿨을 때뿐이다 — 까닭을 테스트결과서에 적는다(옛 값 → 새 값).

const Game = preload("res://sim/game.gd")
const Ai = preload("res://sim/ai.gd")
const Setup = preload("res://sim/setup.gd")
const Orders = preload("res://sim/orders.gd")
const State = preload("res://sim/state.gd")
const Tables = preload("res://sim/tables.gd")
const DataFiles = preload("res://src/data_files.gd")
const GOLDEN := "res://tests/integration/golden_a.json"

var _tables := {}


func _t() -> Dictionary:
	if _tables.is_empty():
		_tables = DataFiles.load_tables()
	return _tables


func _golden() -> Dictionary:
	var g = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN)) if FileAccess.file_exists(GOLDEN) else null
	return g if g is Dictionary else {"hash": {}}


func test_autoplay_26_turns_matches_golden() -> void:
	var t := _t()
	var want: Dictionary = _golden()["hash"]
	for seed in [1, 2, 3]:
		var a: Dictionary = Game.autoplay(t, "A", seed, 26)
		eq(a["violations"], [], "seed %d 불변식 위반 0" % seed)
		eq(a["state"]["turn"], 27, "26턴 처리")
		eq(a["hash"], String(want.get(str(seed), "")), "seed %d 해시가 기준값과 같다(바뀌면 golden_a.json · 테스트결과서)" % seed)
		eq(Game.autoplay(t, "A", seed, 26)["hash"], a["hash"], "seed %d 두 번 같다" % seed)


func test_ai_runs_the_economy() -> void:
	var t := _t()
	var a: Dictionary = Game.autoplay(t, "A", 1, 26)
	var kinds := {}
	for entry in a["log"]:
		for o in entry["orders"]:
			kinds[o["kind"]] = int(kinds.get(o["kind"], 0)) + 1
	for k in ["open", "expand", "move"]:
		check(int(kinds.get(k, 0)) > 0, "AI 가 %s 명령을 낸다 (%s)" % [k, kinds])
	var s0: Dictionary = Setup.scenario(t, "A", 1)["state"]
	var slots := func(s, org): return s["zones"].values().reduce(func(n, z): return n + z["slots"].filter(func(x): return x["org"] == org).size(), 0)
	check(slots.call(a["state"], "bujinpa") > slots.call(s0, "bujinpa"), "부진파 사업장이 늘었다")
	for org in ["haseong", "iskra"]:
		eq(Ai.orders_for(s0, t, org), [], "판 밖 조직(%s)은 명령이 없다" % org)


func test_ai_orders_are_valid_shape_and_sorted_input_free() -> void:
	var t := _t()
	var s: Dictionary = Setup.scenario(t, "A", 1)["state"]
	var orders: Array = Ai.orders_all(s, t)
	check(not orders.is_empty(), "첫 턴 명령이 있다")
	for o in orders:
		eq(Orders.shape_error(o), "", "꼴: %s" % [o])
		eq(o["src"], "ai", "AI 명령 표시")
	eq(Ai.orders_all(s, t), orders, "같은 상태 → 같은 명령")
