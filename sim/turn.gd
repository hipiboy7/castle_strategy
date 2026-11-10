extends RefCounted
## 턴 — 08 13절 9단계를 차례로 부르기만 한다(SRP). 처리기가 없는 단계는 건너뛴다. 새 단계 처리기는 HANDLERS 에 한 줄(OCP).
## run(state, orders, t) 는 입력 상태를 바꾸지 않고 {"state": 새 상태, "report": 보고}를 돌려준다. 보고는 화면용이라 해시에 넣지 않는다.
## 처리기 꼴(LSP): <모듈>.<함수>(s, ctx) — ctx = {t, seed, turn, phase, all(명령 전부), accepted(단계별), report}.
## 난수는 처리기가 Pcg32.init_stream(seed, turn, phase, 대상 id)로 만든다(대상마다 갈래 — 08 13절).
## 설계: docs/C1_설계서_상태와턴.md 3-5 · 요구: FR-115 · 시험: tests/integration/test_turn.gd

const State = preload("res://sim/state.gd")
const Orders = preload("res://sim/orders.gd")
const Economy = preload("res://sim/economy.gd")
const PHASES := ["plan", "move", "manage", "intrigue", "diplomacy", "clash", "events", "council", "settle"]
const HANDLERS := {
	"plan": {"mod": Orders, "fn": "plan"},
	"move": {"mod": Orders, "fn": "run_phase"},
	"manage": {"mod": Orders, "fn": "run_phase"},
	"settle": {"mod": Economy, "fn": "settle"},
}


static func run(state: Dictionary, orders: Array, t: Dictionary) -> Dictionary:
	var s := State.to_dict(state)
	var report := {"turn": s["turn"], "applied": [], "rejected": [], "events": [], "money": {}, "invariants": []}
	var ctx := {"t": t, "seed": s["seed"], "turn": s["turn"], "phase": "", "all": orders, "accepted": {}, "report": report}
	for phase in PHASES:
		if not HANDLERS.has(phase):
			continue
		ctx["phase"] = phase
		HANDLERS[phase]["mod"].call(HANDLERS[phase]["fn"], s, ctx)
	report["invariants"] = State.check_invariants(s, t)
	s["turn"] += 1
	return {"state": s, "report": report}
