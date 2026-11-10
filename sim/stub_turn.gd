extends RefCounted
## C1-0 빈 시뮬 — 턴마다 갈래 스트림에서 수 하나를 뽑아 상태에 섞는다. 실행 경로(서버 headless → CI → 폰)의 결정성을
## 먼저 확인하려고 둔다. C1 본체의 sim/turn.gd 가 들어오면 지운다(docs/C1_설계서_상태와턴.md 2절).
## 순수 함수 — 입력 상태를 바꾸지 않고 새 상태를 돌려준다. 요구: FR-106 · 기준 구현: tools/rng_ref.py stub_run · 시험: tests/unit/test_stub_turn.gd

const Pcg32 = preload("res://sim/rng.gd")
const M32 := 0xFFFFFFFF
const FIELDS := ["v", "seed", "turn", "acc", "last"]


static func new_state(seed: int) -> Dictionary:
	return {"v": 1, "seed": seed, "turn": 1, "acc": 0, "last": 0}


static func step(state: Dictionary) -> Dictionary:
	var x: int = Pcg32.new().init_stream(int(state["seed"]), int(state["turn"]), "stub", "acc").next_u32()
	var s := state.duplicate(true)
	s["acc"] = (int(state["acc"]) * 31 + x) & M32
	s["last"] = x
	s["turn"] = int(state["turn"]) + 1
	return s


static func run(seed: int, turns: int) -> Dictionary:
	var s := new_state(seed)
	for i in turns:
		s = step(s)
	return s


## 저장 글에서 읽은 사전(JSON 수는 실수로 온다) → 정수 상태. 사전이 아니거나 칸이 모자라면 빈 사전
static func from_dict(d) -> Dictionary:
	if not (d is Dictionary):
		return {}
	var out := {}
	for k in FIELDS:
		if not d.has(k):
			return {}
		out[k] = int(d[k])
	return out
