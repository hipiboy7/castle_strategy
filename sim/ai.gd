extends RefCounted
## 규칙 기반 AI — C1 은 경영만(개업 · 확장 · 모집 · 이동 · 쉼). 플레이어와 같은 꼴의 명령(orders[])을 낸다(LSP · src "ai").
## 간부(id 순)마다 행동 수(간부 1 · 두목 2)만큼 아래 차례로 고른다. 고른 명령은 사본 상태에 처리기로 미리 적용해 보고(돈 · 칸이 줄어든다),
## 거절되면 다음 후보로 간다 — 그래서 낸 명령은 같은 조직 안에서는 늘 맞다. 같은 상태 → 같은 명령(난수 · 시각 없음).
##   1 지금 구역 개업(자기 · 주인 없는 구역 빈칸) 2 지금 구역 확장
##   3 모집 — 자기 구역 · 조직원이 사업장 × TROOPS_PER_SLOT 아래 · 주 순이익이 새 유지비의 RECRUIT_NET_K 배 이상
##   4 이동(한 턴 한 번 · 구역장은 떠나지 않는다) — 이웃(id 순) 중 아직 아무도 노리지 않은 빈칸이 있고 열 돈이 있는 곳,
##     없으면 자기 사업장이 없는 구역에 있을 때 자기 사업장이 있는 이웃(본거지 먼저)으로 돌아간다 5 쉼
## 구역장 = 그 구역 자기 사업장의 수입에 수완을 보태는 간부(sim/economy.gd chief_business 와 같은 사람). 돈은 '쓰고 나서도
## RESERVE_WEEKS 주 적자를 버틸 만큼' 남긴다. 성향 · 점수(08 14-5)는 C4.
## 설계: docs/C1_설계서_상태와턴.md 3-4 · 요구: FR-119 · 시험: tests/integration/test_scenario_a.gd

const State = preload("res://sim/state.gd")
const Orders = preload("res://sim/orders.gd")
const Economy = preload("res://sim/economy.gd")
const Tables = preload("res://sim/tables.gd")
const RESERVE_WEEKS := 2
const RESERVE_MIN := 20
const TROOPS_PER_SLOT := 5
const RECRUIT_NET_K := 2


## 모든 조직의 명령(조직 id 순)
static func orders_all(s: Dictionary, t: Dictionary) -> Array:
	var out := []
	for org in State.sorted_keys(s["orgs"]):
		out.append_array(orders_for(s, t, org))
	return out


static func orders_for(s: Dictionary, t: Dictionary, org: String) -> Array:
	var out := []
	if not s["orgs"].has(org) or not s["orgs"][org]["alive"]:
		return out
	var scratch := State.to_dict(s)
	var ctx := {"t": t, "seed": s["seed"], "turn": s["turn"], "phase": "manage", "report": {"applied": [], "rejected": [], "events": [], "money": {}}}
	var net := Economy.income_of(s, t, org) - Economy.upkeep_of(s, t, org)
	var plan := {"org": org, "reserve": maxi(RESERVE_MIN, -net * RESERVE_WEEKS), "net": net, "claimed": {}}
	for by in State.officers_of(s, org):                    # 이미 그 구역에 있는 간부는 그 구역 빈칸을 노리는 것으로 센다
		var z: String = s["officers"][by]["zone"]
		plan["claimed"][z] = int(plan["claimed"].get(z, 0)) + 1
	var game: Dictionary = t["game"]
	for by in State.officers_of(s, org):
		var n := int(game["actions"]["boss"] if s["orgs"][org]["boss"] == by else game["actions"]["officer"])
		var moved := false
		for i in n:
			var o := _pick(scratch, t, by, moved, plan, ctx)
			moved = moved or o["kind"] == "move"
			out.append(o)
	return out


static func _pick(sc: Dictionary, t: Dictionary, by: String, moved: bool, plan: Dictionary, ctx: Dictionary) -> Dictionary:
	var org: String = plan["org"]
	var reserve: int = plan["reserve"]
	var e: Dictionary = t["economy"]
	var zid: String = sc["officers"][by]["zone"]
	var z: Dictionary = sc["zones"].get(zid, {})
	var cash: int = sc["orgs"][org]["cash"]
	var cands := []
	var empty := _empty_slot(z, org)
	if empty >= 0 and cash - Economy.open_cost(e, z["slots"][empty]["kind"]) >= reserve:
		cands.append(Orders.make(org, by, "open", zid))
	var low := _lowest_own(z, org)
	if low >= 0 and cash - Economy.expand_cost(e, z["slots"][low]["kind"], z["slots"][low]["lv"] + 1) >= reserve:
		cands.append(Orders.make(org, by, "expand", zid))
	if z.get("owner", "") == org and _troops(sc, org) < _own_slots(sc, org) * TROOPS_PER_SLOT:
		var heads: int = z["people"] * int(e["recruit"]["per_people"]) + int(e["recruit"]["rand"])
		if cash - Economy.recruit_cost(e, heads) >= reserve * 2 and plan["net"] >= heads * int(e["wage"]["건달급"]) * RECRUIT_NET_K:
			cands.append(Orders.make(org, by, "recruit", zid))
	var mine := _count_own(z, org)
	if not moved and empty < 0 and not (mine > 0 and _is_chief(sc, t, org, by, zid)):
		var dest := ""
		for nb in Tables.neighbors(t, zid):
			var nz: Dictionary = sc["zones"].get(nb, {})
			var k := _empty_slot(nz, org)
			if k >= 0 and _count_empty(nz) > int(plan["claimed"].get(nb, 0)) and cash - Economy.open_cost(e, nz["slots"][k]["kind"]) >= reserve:
				dest = nb
				break
		if dest == "" and mine == 0:
			var hq: String = sc["orgs"][org]["hq"]
			var homes := Tables.neighbors(t, zid).filter(func(nb): return sc["zones"].has(nb) and _count_own(sc["zones"][nb], org) > 0)
			if homes.has(hq):
				dest = hq
			elif not homes.is_empty():
				dest = homes[0]
		if dest != "":
			cands.append(Orders.make(org, by, "move", dest))
	for o in cands:
		ctx["phase"] = Orders.KINDS[o["kind"]]["phase"]
		if Orders.apply_one(sc, o, ctx) == "":
			if o["kind"] == "move":
				plan["claimed"][o["to"]] = int(plan["claimed"].get(o["to"], 0)) + 1
			return o
	return Orders.make(org, by, "rest", zid)


## by 가 그 구역에서 그 조직의 구역장인가(움직일 수 있는 간부 중 수완이 가장 높고, 같으면 id 가 앞)
static func _is_chief(s: Dictionary, t: Dictionary, org: String, by: String, zid: String) -> bool:
	var best := ""
	var best_biz := -1
	for id in State.officers_of(s, org):
		if s["officers"][id]["zone"] != zid:
			continue
		var b := int(t["strat"].get(id, {}).get("business", 0))
		if b > best_biz:
			best_biz = b
			best = id
	return best == by


static func _count_own(z: Dictionary, org: String) -> int:
	return z.get("slots", []).filter(func(x): return x["org"] == org).size()


static func _count_empty(z: Dictionary) -> int:
	return z.get("slots", []).filter(func(x): return x["org"] == "").size()


## 그 조직이 열 수 있는 첫 빈칸(자기 · 주인 없는 구역) — 없으면 −1
static func _empty_slot(z: Dictionary, org: String) -> int:
	if z.is_empty() or (z["owner"] != "" and z["owner"] != org):
		return -1
	for i in z["slots"].size():
		if z["slots"][i]["org"] == "":
			return i
	return -1


## 가장 낮은 레벨의 자기 칸(lv < 3) — 없으면 −1
static func _lowest_own(z: Dictionary, org: String) -> int:
	var pick := -1
	for i in z.get("slots", []).size():
		var sl: Dictionary = z["slots"][i]
		if sl["org"] == org and sl["lv"] < State.MAX_LV and (pick < 0 or sl["lv"] < z["slots"][pick]["lv"]):
			pick = i
	return pick


static func _troops(s: Dictionary, org: String) -> int:
	var n := 0
	for g in State.TROOP_GRADES:
		n += int(s["orgs"][org]["troops"][g])
	return n


static func _own_slots(s: Dictionary, org: String) -> int:
	var n := 0
	for zid in State.sorted_keys(s["zones"]):
		for sl in s["zones"][zid]["slots"]:
			if sl["org"] == org:
				n += 1
	return n
