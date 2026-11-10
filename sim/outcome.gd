extends RefCounted
## 승패 — 결산 단계 마지막 처리기. 시나리오 목표(data/game/game.json goals)를 내 조직(state.player)으로 본다. 한 번 나면 그대로 둔다.
## C3 은 A 의 목표 하나(hold_all — 판의 구역을 모두 차지)와 공통 패배(두목 잡힘 · 죽음 · 구역 0 · 판 길이 넘김)만 본다. 08 6절 (가)(나)(다) 전체는 C5.
## 결과는 state.flags 에 둔다: result("win" · "lose") · result_turn · result_why(hold_all · boss · zones · time) — 해시 · 저장에 들어간다.
## 설계: docs/C3_설계서_습격과일기토.md 5절 · 요구: FR-307 · 시험: tests/unit/test_outcome.gd

const State = preload("res://sim/state.gd")


static func judge(s: Dictionary, ctx: Dictionary) -> void:
	var r := verdict(s, ctx["t"])
	if r.is_empty():
		return
	s["flags"]["result"] = r["result"]
	s["flags"]["result_turn"] = int(s["turn"])
	s["flags"]["result_why"] = r["why"]
	ctx["report"]["events"].append({"kind": "outcome", "org": s["player"], "result": r["result"], "why": r["why"]})


## {"result", "why"} 또는 {}(아직) — 상태를 바꾸지 않는다
static func verdict(s: Dictionary, t: Dictionary) -> Dictionary:
	var me: String = s.get("player", "")
	var goal: Dictionary = t["game"].get("goals", {}).get(s.get("scenario", ""), {})
	if me == "" or goal.is_empty() or String(s["flags"].get("result", "")) != "" or not s["orgs"].has(me):
		return {}
	var mine := 0
	for zid in State.sorted_keys(s["zones"]):
		if s["zones"][zid]["owner"] == me:
			mine += 1
	var boss: String = s["orgs"][me]["boss"]
	var bs: String = s["officers"][boss]["status"] if s["officers"].has(boss) else "dead"
	if goal.get("kind", "") == "hold_all" and mine == s["zones"].size():
		return {"result": "win", "why": "hold_all"}
	if bs == "dead" or bs == "captive":
		return {"result": "lose", "why": "boss"}
	if mine == 0:
		return {"result": "lose", "why": "zones"}
	if int(s["length"]) > 0 and int(s["turn"]) >= int(s["length"]):
		return {"result": "lose", "why": "time"}
	return {}


## 끝났나(화면 · 자동 진행)
static func over(s: Dictionary) -> bool:
	return String(s["flags"].get("result", "")) != ""
