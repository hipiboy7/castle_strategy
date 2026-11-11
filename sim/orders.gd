extends RefCounted
## 명령 — 꼴 · 정렬 · 마감 검사(plan 단계) · 단계별 적용(move · manage 단계 — clash 는 sim/combat.gd) · 처리기 등록부(OCP: 새 종류 = KINDS 에 한 줄 + sim/kinds/<종류>.gd).
## 꼴: {"org", "by", "kind", "to", "args", "src": "player"|"ai"} — 플레이어와 AI 가 같은 꼴을 낸다(LSP). 시뮬은 누가 냈는지 보지 않는다.
## 처리 순서: 조직 id → 간부 id → 한 간부 안에서는 낸 순서(08 13절 1). 행동 수는 간부 1 · 두목 2(data/game/game.json actions).
## 틀린 명령은 적용하지 않고 까닭을 보고(rejected)에 남긴다 — 같은 입력이면 같은 거절. 설계: docs/C1_설계서_상태와턴.md 3-4 · 시험: tests/unit/test_orders.gd

## at: 화면이 그 명령을 어디에 놓을 때 고르게 하나(C2 sim/draft.gd options) — "here" = 간부가 서 있는 구역 · "other" = 다른 구역
## zone: 화면이 그 줄을 보일 구역 — "own" 우리 구역만 · "foe" 우리 구역이 아닌 곳만(없으면 늘). variants: 화면 · AI 가 고를 args 꼴들(없으면 [{}]) — C3 습격 · 지키기의 작전 카드. clash 단계 처리기는 검사만 하고 전투는 sim/combat.gd
const KINDS := {
	"move": {"phase": "move", "at": "other", "mod": preload("res://sim/kinds/move.gd")},
	"open": {"phase": "manage", "at": "here", "mod": preload("res://sim/kinds/open.gd")},
	"expand": {"phase": "manage", "at": "here", "mod": preload("res://sim/kinds/expand.gd")},
	"recruit": {"phase": "manage", "at": "here", "mod": preload("res://sim/kinds/recruit.gd")},
	"rest": {"phase": "manage", "at": "here", "mod": preload("res://sim/kinds/rest.gd")},
	"defend": {"phase": "clash", "at": "here", "zone": "own", "mod": preload("res://sim/kinds/defend.gd"),
		"variants": [{"card": "ambush"}, {"card": "shield"}]},
	"raid": {"phase": "clash", "at": "other", "zone": "foe", "mod": preload("res://sim/kinds/raid.gd"),
		"variants": [{"cards": []}, {"cards": ["surprise"]}, {"cards": ["charge"]}, {"cards": ["decoy"]}, {"cards": ["shield"]}, {"cards": ["bypass"]}]},
}
const FIELDS := {"org": TYPE_STRING, "by": TYPE_STRING, "kind": TYPE_STRING, "to": TYPE_STRING, "args": TYPE_DICTIONARY, "src": TYPE_STRING}
const SOURCES := ["player", "ai"]


## 그 종류의 args 꼴들(화면 고르기 · AI)
static func variants(kind: String) -> Array:
	return KINDS[kind].get("variants", [{}])


static func make(org: String, by: String, kind: String, to: String = "", args: Dictionary = {}, src: String = "ai") -> Dictionary:
	return {"org": org, "by": by, "kind": kind, "to": to, "args": args, "src": src}


## 꼴이 틀린 까닭("" = 맞음)
static func shape_error(o) -> String:
	if not (o is Dictionary):
		return "명령이 사전이 아니다"
	for k in FIELDS:
		if not o.has(k) or typeof(o[k]) != FIELDS[k]:
			return "명령 칸 %s 가 없거나 꼴이 틀렸다" % k
	if not SOURCES.has(o["src"]):
		return "src 는 player · ai 다: %s" % o["src"]
	return ""


## 조직 id → 간부 id → 낸 순서(안정 정렬)
static func sorted(orders: Array) -> Array:
	var idx := []
	for i in orders.size():
		idx.append(i)
	var field := func(i: int, k: String) -> String: return String(orders[i].get(k, "")) if orders[i] is Dictionary else ""
	idx.sort_custom(func(a: int, b: int) -> bool:
		var oa: String = field.call(a, "org")
		var ob: String = field.call(b, "org")
		if oa != ob:
			return oa < ob
		var ba: String = field.call(a, "by")
		var bb: String = field.call(b, "by")
		if ba != bb:
			return ba < bb
		return a < b)
	return idx.map(func(i): return orders[i])


## plan 단계 처리기 — ctx["all"](이번 턴 명령 전부) → 정렬 · 검사 → ctx["accepted"][단계] = [명령]. 거절은 ctx.report.rejected
static func plan(s: Dictionary, ctx: Dictionary) -> void:
	var game: Dictionary = ctx["t"]["game"]
	var used := {}
	var accepted := {}
	for o in sorted(ctx.get("all", [])):
		var why := _plan_error(s, o, game, used)
		if why != "":
			ctx["report"]["rejected"].append({"order": o, "why": why})
			continue
		used[o["by"]] = int(used.get(o["by"], 0)) + 1
		var phase: String = KINDS[o["kind"]]["phase"]
		if not accepted.has(phase):
			accepted[phase] = []
		accepted[phase].append(o)
	ctx["accepted"] = accepted


static func _plan_error(s: Dictionary, o, game: Dictionary, used: Dictionary) -> String:
	var why := shape_error(o)
	if why != "":
		return why
	if not s["orgs"].has(o["org"]) or not s["orgs"][o["org"]]["alive"]:
		return "판에 없거나 무너진 조직 %s" % o["org"]
	var p: Dictionary = s["officers"].get(o["by"], {})
	if p.is_empty() or p["org"] != o["org"]:
		return "%s 는 %s 소속 간부가 아니다" % [o["by"], o["org"]]
	if p["status"] != "active":
		return "%s 는 움직일 수 없다(%s)" % [o["by"], p["status"]]
	if not KINDS.has(o["kind"]):
		return "모르는 명령 %s" % o["kind"]
	var limit := int(game["actions"]["boss"] if s["orgs"][o["org"]]["boss"] == o["by"] else game["actions"]["officer"])
	if int(used.get(o["by"], 0)) >= limit:
		return "%s 행동 수 %d 를 넘었다" % [o["by"], limit]
	return ""


## move · manage 단계 처리기 — 그 단계로 받은 명령을 차례로 적용한다(적용 때 다시 검사 — 앞 명령이 상태를 바꿨을 수 있다)
static func run_phase(s: Dictionary, ctx: Dictionary) -> void:
	for o in ctx.get("accepted", {}).get(ctx["phase"], []):
		var why := ""
		if s["officers"][o["by"]]["status"] != "active":
			why = "%s 는 움직일 수 없다" % o["by"]
		else:
			why = apply_one(s, o, ctx)
		if why == "":
			ctx["report"]["applied"].append(o)
		else:
			ctx["report"]["rejected"].append({"order": o, "why": why})


## 명령 하나를 그 처리기로 적용(검사는 처리기가 한다). AI 가 사본 상태로 미리 볼 때도 쓴다
static func apply_one(s: Dictionary, o: Dictionary, ctx: Dictionary) -> String:
	if not KINDS.has(o["kind"]):
		return "모르는 명령 %s" % o["kind"]
	return KINDS[o["kind"]]["mod"].apply(s, o, ctx)
