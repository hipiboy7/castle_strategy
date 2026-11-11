extends RefCounted
## 대기 명령(초안) — 순수 함수. 플레이어가 이번 주에 낼 명령 배열(draft · 명령 꼴은 sim/orders.gd · src "player", 맡기기는 "ai").
## 미리 보기는 사본 상태에 턴의 명령 단계(plan → move → manage — sim/turn.gd ORDER_PHASES)를 그대로 돌린다: 같은 처리기 · 같은 갈래 난수라
## 내 조직만 놓고 보면 실제 주 결과와 같다(다른 조직 명령이 먼저 빈칸을 가져가면 다를 수 있다 — 보고에 남는다). 입력은 바꾸지 않는다.
## 고를 수 있는 명령은 등록부(Orders.KINDS 의 at)를 따라간다 — 새 종류는 등록부 한 줄로 화면에 뜬다(OCP). 검사는 처리기가 한다.
## 설계: docs/C2_설계서_화면과명령.md 4절 · docs/C3_설계서_습격과일기토.md 6절 · 요구: FR-204 · FR-205 · FR-309 · 시험: tests/unit/test_draft.gd

const Orders = preload("res://sim/orders.gd")
const Turn = preload("res://sim/turn.gd")
const State = preload("res://sim/state.gd")
const Ai = preload("res://sim/ai.gd")


static func limit(s: Dictionary, t: Dictionary, by: String) -> int:
	var p: Dictionary = s["officers"].get(by, {})
	if p.is_empty() or not s["orgs"].has(p["org"]):
		return 0
	var game: Dictionary = t["game"]
	return int(game["actions"]["boss"] if s["orgs"][p["org"]]["boss"] == by else game["actions"]["officer"])


## {간부 id: 낸 수}
static func used(d: Array) -> Dictionary:
	var u := {}
	for o in d:
		u[o["by"]] = int(u.get(o["by"], 0)) + 1
	return u


static func left(s: Dictionary, t: Dictionary, d: Array, by: String) -> int:
	return maxi(0, limit(s, t, by) - int(used(d).get(by, 0)))


## 내 조직(s.player)의 움직일 수 있는 간부 전체 [남은 행동, 전체 행동]
static func total_left(s: Dictionary, t: Dictionary, d: Array) -> Array:
	var l := 0
	var n := 0
	for by in State.officers_of(s, s["player"]):
		l += left(s, t, d, by)
		n += limit(s, t, by)
	return [l, n]


## 넣기 — {"draft": 새 배열, "why": ""(넣음) 또는 까닭(그대로)}
static func add(s: Dictionary, t: Dictionary, d: Array, o: Dictionary) -> Dictionary:
	var p: Dictionary = s["officers"].get(o.get("by", ""), {})
	var why := ""
	if p.is_empty() or p["org"] != s["player"] or o.get("org", "") != s["player"]:
		why = "내 조직 간부가 아니다"
	elif p["status"] != "active":
		why = "움직일 수 없다"
	elif left(s, t, d, o["by"]) <= 0:
		why = "이번 주 행동을 다 썼다"
	if why != "":
		return {"draft": d, "why": why}
	var out := d.duplicate(true)
	out.append(o.duplicate(true))
	return {"draft": out, "why": ""}


static func remove(d: Array, i: int) -> Array:
	var out := d.duplicate(true)
	if i >= 0 and i < out.size():
		out.remove_at(i)
	return out


## 미리 보기 — {"state": 명령 단계 뒤 사본, "applied", "rejected", "events"}. 충돌 단계 명령(습격 · 지키기 — C3)은 싸움을 미리 돌리지 않고
## 명령 단계 뒤 상태에서 처리기 검사만 한다(받으면 applied — 싸움 결과는 주 끝 보고에서 · 다른 조직 명령에 따라 달라진다)
static func preview(s: Dictionary, t: Dictionary, d: Array) -> Dictionary:
	var r: Dictionary = Turn.phases(s, d, t, Turn.ORDER_PHASES)
	var applied: Array = r["report"]["applied"]
	var rejected: Array = r["report"]["rejected"]
	var ctx := {"t": t, "seed": s["seed"], "turn": s["turn"], "phase": "", "report": {"applied": [], "rejected": [], "events": [], "money": {}}}
	var no := {}
	for x in rejected:
		if x["order"] is Dictionary and Orders.shape_error(x["order"]) == "":
			no[_key(x["order"])] = int(no.get(_key(x["order"]), 0)) + 1
	for o in d:
		if not (o is Dictionary) or Orders.shape_error(o) != "" or not Orders.KINDS.has(o["kind"]):
			continue
		var ph: String = Orders.KINDS[o["kind"]]["phase"]
		if Turn.ORDER_PHASES.has(ph):
			continue
		if int(no.get(_key(o), 0)) > 0:
			no[_key(o)] -= 1
			continue
		ctx["phase"] = ph
		var why := Orders.apply_one(r["state"], o, ctx) if r["state"]["officers"].has(o["by"]) else "모르는 간부"
		if why == "":
			applied.append(o)
		else:
			rejected.append({"order": o, "why": why})
	return {"state": r["state"], "applied": applied, "rejected": rejected, "events": r["report"]["events"]}


## 줄마다 결과 [{ok, why}] — 같은 명령이 여럿이면 받은 수만큼 앞에서부터 ok
static func marks(s: Dictionary, t: Dictionary, d: Array) -> Array:
	var p := preview(s, t, d)
	var ok_left := {}
	for o in p["applied"]:
		var k := _key(o)
		ok_left[k] = int(ok_left.get(k, 0)) + 1
	var out := []
	for o in d:
		var k := _key(o)
		if int(ok_left.get(k, 0)) > 0:
			ok_left[k] -= 1
			out.append({"ok": true, "why": ""})
		else:
			out.append({"ok": false, "why": _why(p["rejected"], o)})
	return out


## 그 간부를 zone 에 놓았을 때 고를 수 있는 명령 [{kind, order, ok, why, cost, gain, later}] — 등록부 순 · 종류마다 args 꼴(variants — 작전 카드)
## later = 결과가 주 끝 충돌 단계에서 난다(습격 · 지키기)
static func options(s: Dictionary, t: Dictionary, d: Array, by: String, zone: String) -> Array:
	var me: String = s["player"]
	var base := preview(s, t, d)
	var at: String = base["state"]["officers"].get(by, {}).get("zone", "")
	var where := "here" if zone == at else "other"
	var spare := left(s, t, d, by)
	var out := []
	for kind in Orders.KINDS:
		if Orders.KINDS[kind]["at"] != where:
			continue
		var zk: String = Orders.KINDS[kind].get("zone", "")
		var own: bool = base["state"]["zones"].has(zone) and base["state"]["zones"][zone]["owner"] == me
		if (zk == "own" and not own) or (zk == "foe" and own):
			continue
		for args in Orders.variants(kind):
			var o := Orders.make(me, by, kind, zone, args.duplicate(true), "player")
			var row := {"kind": kind, "order": o, "ok": false, "why": "", "cost": 0, "gain": 0,
				"later": not Turn.ORDER_PHASES.has(Orders.KINDS[kind]["phase"])}
			if spare <= 0:
				row["why"] = "이번 주 행동을 다 썼다"
			else:
				var d2 := d.duplicate(true)
				d2.append(o)
				var p := preview(s, t, d2)
				var k := _key(o)
				row["ok"] = _count(p["applied"], k) > _count(base["applied"], k)
				if row["ok"]:
					row["cost"] = int(base["state"]["orgs"][me]["cash"]) - int(p["state"]["orgs"][me]["cash"])
					row["gain"] = int(p["state"]["orgs"][me]["troops"]["건달급"]) - int(base["state"]["orgs"][me]["troops"]["건달급"])
				else:
					row["why"] = _why(p["rejected"], o)
			out.append(row)
	return out


## 맡기기 — 내 조직 명령을 AI(C1 경영 AI)가 채운다(src "ai")
static func auto(s: Dictionary, t: Dictionary) -> Array:
	return Ai.orders_for(s, t, s["player"])


static func _key(o: Dictionary) -> String:
	return "%s|%s|%s|%s|%s" % [o["org"], o["by"], o["kind"], o["to"], JSON.stringify(o["args"])]


static func _count(list: Array, k: String) -> int:
	return list.filter(func(o): return _key(o) == k).size()


static func _why(rejected: Array, o: Dictionary) -> String:
	var k := _key(o)
	for r in rejected:
		if r["order"] is Dictionary and _key(r["order"]) == k:
			return String(r["why"])
	return "받지 않았다"
