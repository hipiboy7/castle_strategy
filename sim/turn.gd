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
const ORDER_PHASES := ["plan", "move", "manage"]      # 명령이 바로 바꾸는 단계(미리 보기)
const HANDLERS := {
	"plan": {"mod": Orders, "fn": "plan"},
	"move": {"mod": Orders, "fn": "run_phase"},
	"manage": {"mod": Orders, "fn": "run_phase"},
	"settle": {"mod": Economy, "fn": "settle"},
}


static func run(state: Dictionary, orders: Array, t: Dictionary) -> Dictionary:
	var r := phases(state, orders, t, PHASES)
	r["report"]["invariants"] = State.check_invariants(r["state"], t)
	r["state"]["turn"] += 1
	return r


## 단계 일부만 돌린다(입력 상태 불변 · 턴을 넘기지 않음) — 대기 명령 미리 보기(sim/draft.gd)가 ORDER_PHASES 로 부른다.
## 같은 ctx(seed · turn · 단계 · 대상 id 갈래 난수)라 그 단계의 결과는 run 과 같다(C2 설계서 4절)
static func phases(state: Dictionary, orders: Array, t: Dictionary, names: Array) -> Dictionary:
	var s := State.to_dict(state)
	var report := {"turn": s["turn"], "applied": [], "rejected": [], "events": [], "money": {}, "invariants": []}
	var ctx := {"t": t, "seed": s["seed"], "turn": s["turn"], "phase": "", "all": orders, "accepted": {}, "report": report}
	for phase in PHASES:
		if not HANDLERS.has(phase) or not names.has(phase):
			continue
		ctx["phase"] = phase
		HANDLERS[phase]["mod"].call(HANDLERS[phase]["fn"], s, ctx)
	return {"state": s, "report": report}
