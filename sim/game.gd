extends RefCounted
## 한 판 흐름(오케스트레이션) — 새 판 · 한 주 진행(AI 명령 → 턴) · 자동 진행 · 명령 기록 다시 돌리기 · 저장에서 이어 하기.
## 판 g = {"state": GameState, "log": [{"turn", "orders"}], "errors": [...]} — 사전 하나(UI · main 이 들고 있는다).
## 매 턴 '반드시' 불변식(CLAUDE.md 3절)을 본다: 상태 불변식(sim/state.gd) + 움직일 수 없던 간부의 명령이 적용되지 않았다.
## 설계: docs/C1_설계서_상태와턴.md 3-5 · 3-7 · 요구: FR-118 · FR-119 · 시험: tests/integration/test_scenario_a.gd · test_save_resume.gd

const State = preload("res://sim/state.gd")
const Setup = preload("res://sim/setup.gd")
const Turn = preload("res://sim/turn.gd")
const Ai = preload("res://sim/ai.gd")


static func new_game(t: Dictionary, scenario: String, seed: int, player: String = "") -> Dictionary:
	var r: Dictionary = Setup.scenario(t, scenario, seed, player)
	return {"state": r["state"], "log": [], "errors": r["errors"]}


## 한 주 — orders 가 null 이면 모든 조직을 AI 가 낸다(C1 은 플레이어 명령 화면이 없다 — C2). 보고 + 이번 턴 불변식 위반을 돌려준다
static func step(g: Dictionary, t: Dictionary, orders = null) -> Dictionary:
	var before: Dictionary = g["state"]
	var list: Array = Ai.orders_all(before, t) if orders == null else orders
	var r: Dictionary = Turn.run(before, list, t)
	var bad: Array = r["report"]["invariants"].duplicate()
	for o in r["report"]["applied"]:
		if before["officers"][o["by"]]["status"] != "active":
			bad.append("움직일 수 없던 %s 의 명령이 적용됐다" % o["by"])
	g["state"] = r["state"]
	g["log"].append({"turn": before["turn"], "orders": list})
	r["report"]["violations"] = bad
	return r["report"]


## 자동 진행 — {"state", "log", "violations": ["turn N — …"], "hash"}
static func autoplay(t: Dictionary, scenario: String, seed: int, turns: int) -> Dictionary:
	var g := new_game(t, scenario, seed)
	var bad: Array = g["errors"].duplicate()
	if bad.is_empty():
		for i in turns:
			for v in step(g, t)["violations"]:
				bad.append("turn %d — %s" % [g["state"]["turn"] - 1, v])
	return {"state": g["state"], "log": g["log"], "violations": bad, "hash": State.hash_of(g["state"])}


## 같은 명령 다시 돌리기 — 처음 상태에서 기록의 명령을 그대로 넣는다(시뮬만 바뀌었는지 본다)
static func replay(t: Dictionary, scenario: String, seed: int, player: String, log: Array) -> Dictionary:
	var g := new_game(t, scenario, seed, player)
	if g["errors"].is_empty():
		for entry in log:
			step(g, t, entry["orders"])
	return g


## 저장(sim/save.gd from_text 결과의 save)에서 이어 하기 — 상태가 비었으면 명령 기록을 다시 돌려 만든다
static func from_save(sv: Dictionary, t: Dictionary) -> Dictionary:
	if sv["state"].is_empty():
		return replay(t, sv["scenario"], sv["seed"], sv["player"], sv["orders"])
	var errs := State.check_invariants(sv["state"], t)
	return {"state": sv["state"], "log": sv["orders"].duplicate(true), "errors": errs}
