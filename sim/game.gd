extends RefCounted
## 한 판 흐름(오케스트레이션) — 새 판 · 한 주 진행(AI 명령 → 턴) · 자동 진행 · 명령 기록 다시 돌리기 · 저장에서 이어 하기.
## 판 g = {"state": GameState, "log": [{"turn", "orders"}], "errors": [...], "reports": [{"report", "before", "after"}]} — 사전 하나(UI · main 이 들고 있는다).
## C2: 플레이어 주(step_player — 내 조직 = 대기 명령 · 다른 조직 = AI) · 보고 목록(전 · 뒤 상태 — 화면 보고 카드) · 저장에서 보고 다시 만들기.
## 매 턴 '반드시' 불변식(CLAUDE.md 3절)을 본다: 상태 불변식(sim/state.gd) + 움직일 수 없던 간부의 명령이 적용되지 않았다.
## C4-2(FR-416): step · step_player 의 opts = {fights, ask, auto} — 묻는 조직의 미해결 실시간 구간이면 g 를 바꾸지 않고 {"need": …}.
## 끝까지 돌면 기록 줄 {"turn", "orders", "fights": 쓴 구간 결과만}. replay 는 기록 줄의 fights 를 넣는다(묻지 않음). autoplay · AI 미리 보기는 opts 없이.
## 설계: docs/C1_설계서_상태와턴.md 3-5 · 3-7 · docs/C2_설계서_화면과명령.md 4 · 6절 · docs/C4_설계서_직접조작전투.md 3절 · 요구: FR-118 · FR-119 · FR-207 · FR-213 · FR-416
## 시험: tests/integration/test_scenario_a.gd · test_save_resume.gd · test_player_turn.gd

const State = preload("res://sim/state.gd")
const Setup = preload("res://sim/setup.gd")
const Turn = preload("res://sim/turn.gd")
const Ai = preload("res://sim/ai.gd")


static func new_game(t: Dictionary, scenario: String, seed: int, player: String = "") -> Dictionary:
	var r: Dictionary = Setup.scenario(t, scenario, seed, player)
	return {"state": r["state"], "log": [], "errors": r["errors"], "reports": []}


## 한 주 — orders 가 null 이면 모든 조직을 AI 가 낸다(C1 은 플레이어 명령 화면이 없다 — C2). 보고 + 이번 턴 불변식 위반을 돌려준다
static func step(g: Dictionary, t: Dictionary, orders = null, opts := {}) -> Dictionary:
	var before: Dictionary = g["state"]
	var list: Array = Ai.orders_all(before, t) if orders == null else orders
	var r: Dictionary = Turn.run(before, list, t, opts)
	if r.has("need"):
		return {"need": r["need"]}
	var bad: Array = r["report"]["invariants"].duplicate()
	for o in r["report"]["applied"]:
		if before["officers"][o["by"]]["status"] != "active":
			bad.append("움직일 수 없던 %s 의 명령이 적용됐다" % o["by"])
	g["state"] = r["state"]
	g["log"].append({"turn": before["turn"], "orders": list, "fights": r["fights"].duplicate(true)})
	r["report"]["violations"] = bad
	if not g.has("reports"):
		g["reports"] = []
	g["reports"].append({"report": r["report"], "before": before, "after": r["state"]})   # 전 상태는 바꾸지 않은 원본(Turn 이 복사함)
	return r["report"]


## 플레이어 한 주 — 내 조직 = 대기 명령(draft), 다른 조직 = AI(조직 id 순). 같은 꼴의 orders[] 로 step 과 같은 길(LSP)
static func step_player(g: Dictionary, t: Dictionary, draft: Array, opts := {}) -> Dictionary:
	var s: Dictionary = g["state"]
	var list := draft.duplicate(true)
	list.append_array(others_ai(s, t, s["player"]))
	return step(g, t, list, opts)


## 내 조직을 뺀 모든 조직의 AI 명령(조직 id 순)
static func others_ai(s: Dictionary, t: Dictionary, me: String) -> Array:
	var out := []
	for org in State.sorted_keys(s["orgs"]):
		if org != me:
			out.append_array(Ai.orders_for(s, t, org))
	return out


## 저장(Save.from_text 결과의 save)에서 보고 목록을 다시 만든다 — 처음 상태에서 명령 기록을 다시 돌린다.
## same = 다시 돌린 상태 해시가 저장 상태 해시와 같은가(저장 상태가 비었으면 true)
static func rebuild_reports(t: Dictionary, sv: Dictionary) -> Dictionary:
	var g := replay(t, sv["scenario"], sv["seed"], sv["player"], sv["orders"])
	var same: bool = sv["state"].is_empty() or (g["errors"].is_empty() and State.hash_of(g["state"]) == State.hash_of(sv["state"]))
	return {"reports": g.get("reports", []), "same": same}


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
			step(g, t, entry["orders"], {"fights": entry.get("fights", {})})
	return g


## 저장(sim/save.gd from_text 결과의 save)에서 이어 하기 — 상태가 비었으면 명령 기록을 다시 돌려 만든다
static func from_save(sv: Dictionary, t: Dictionary) -> Dictionary:
	if sv["state"].is_empty():
		return replay(t, sv["scenario"], sv["seed"], sv["player"], sv["orders"])
	var errs := State.check_invariants(sv["state"], t)
	return {"state": sv["state"], "log": sv["orders"].duplicate(true), "errors": errs, "reports": []}
