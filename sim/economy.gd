extends RefCounted
## 경제(08 3-1 · 14-1 · 정수판) — 사업장 수입 · 유지비 · 간부 대우 · 결산(settle 단계 처리기) · 현금 0 밑 N턴 규칙 · 명령 비용.
## 값은 data/game/economy.json(t["economy"]) 한 곳. 설계: docs/C1_설계서_상태와턴.md 3-6 · 요구: FR-116 · 시험: tests/unit/test_economy.gd
## 구역장(수입의 수완) = 그 구역에 있는 그 조직의 움직일 수 있는(active) 간부 중 수완이 가장 높은 사람(같으면 아무나 — 값만 쓴다).
## 사업장 부서짐(dmg)은 C3 에서 수입에 넣는다. 열기 · 공권력 · 충성 변화(08 13절 9 의 뒤쪽)는 C4.

const Fixed = preload("res://sim/fixed.gd")
const State = preload("res://sim/state.gd")
const PAID := ["active", "wounded"]          # 대우를 받는 간부 상태(포로 · 판 밖 · 죽음은 받지 않는다)


## 칸 하나의 주 수입 — 08 14-1 을 한 번 나누는 정수식으로(설계서 3-6)
static func slot_income(e: Dictionary, kind: String, lv: int, flow: int, biz: int, heat: int, matched: bool) -> int:
	var base := int(e["base"].get(kind, 0))
	var heat_div := int(e["heat_div"])
	var num := base * lv * flow * (int(e["biz_base_milli"]) + int(e["biz_per_point_milli"]) * biz) \
		* (heat_div - heat) * (int(e["match_milli"]) if matched else 1000)
	return Fixed.div_round(num, 10000 * 1000 * heat_div * 1000)


static func chief_business(s: Dictionary, t: Dictionary, zone: String, org: String) -> int:
	var best := 0
	for id in State.officers_of(s, org):
		if s["officers"][id]["zone"] == zone:
			best = maxi(best, int(t["strat"].get(id, {}).get("business", 0)))
	return best


static func income_of(s: Dictionary, t: Dictionary, org: String) -> int:
	var total := 0
	for zid in State.sorted_keys(s["zones"]):
		total += zone_income(s, t, zid, org)
	return total


## 구역 하나에서 그 조직이 버는 주 수입(구역 카드 — C2 FR-203). 구역마다 더하면 income_of
static func zone_income(s: Dictionary, t: Dictionary, zid: String, org: String) -> int:
	var z: Dictionary = s["zones"].get(zid, {})
	if z.is_empty() or not s["orgs"].has(org):
		return 0
	var e: Dictionary = t["economy"]
	var heat: int = s["orgs"][org]["heat"]
	var trade = t["factions"].get(org, {}).get("trade")
	var total := 0
	var biz := -1
	for sl in z["slots"]:
		if sl["org"] != org:
			continue
		if biz < 0:
			biz = chief_business(s, t, zid, org)
		total += slot_income(e, sl["kind"], sl["lv"], z["flow"], biz, heat, sl["kind"] == trade)
	return total


static func upkeep_of(s: Dictionary, t: Dictionary, org: String) -> int:
	var e: Dictionary = t["economy"]
	var troops: Dictionary = s["orgs"][org]["troops"]
	var total := 0
	for g in State.TROOP_GRADES:
		total += int(troops.get(g, 0)) * int(e["wage"][g])
	for id in State.officers_of(s, org, false):
		var p: Dictionary = s["officers"][id]
		if PAID.has(p["status"]):
			total += int(t["rank_no"].get(p["rank"], 0)) * int(e["officer_pay_per_rank"])
	return total


static func open_cost(e: Dictionary, kind: String) -> int:
	return int(e["base"].get(kind, 0)) * int(e["open_cost_k"])


static func expand_cost(e: Dictionary, kind: String, to_lv: int) -> int:
	return int(e["base"].get(kind, 0)) * int(e["expand_cost_k"]) * to_lv


static func recruit_cost(e: Dictionary, n: int) -> int:
	return n * int(e["recruit"]["cost"])


## settle 단계 처리기(sim/turn.gd) — 조직 id 순: 수입 → 지출 → 현금 규칙. ctx = {t, report}
static func settle(s: Dictionary, ctx: Dictionary) -> void:
	var t: Dictionary = ctx["t"]
	var nc: Dictionary = t["economy"]["neg_cash"]
	for org in State.sorted_keys(s["orgs"]):
		var o: Dictionary = s["orgs"][org]
		if not o["alive"]:
			continue
		var inc := income_of(s, t, org)
		var up := upkeep_of(s, t, org)
		o["cash"] += inc - up
		ctx["report"]["money"][org] = {"income": inc, "upkeep": up, "cash": o["cash"]}
		o["neg_cash_turns"] = o["neg_cash_turns"] + 1 if o["cash"] < 0 else 0
		if o["neg_cash_turns"] >= int(nc["turns"]):
			_leave(s, org, int(nc["leave_bp"]), int(nc["loyalty_drop"]), ctx["report"])


## 현금 0 밑 N턴 — 등급마다 leave_bp(올림)가 떠나고 간부 충성이 떨어진다(0 밑으로는 안 내려감)
static func _leave(s: Dictionary, org: String, leave_bp: int, drop: int, report: Dictionary) -> void:
	var troops: Dictionary = s["orgs"][org]["troops"]
	var lost := {}
	for g in State.TROOP_GRADES:
		var n: int = troops[g]
		var k := mini(n, Fixed.ceil_div(n * leave_bp, Fixed.BP))
		troops[g] = n - k
		lost[g] = k
	for id in State.officers_of(s, org, false):
		var p: Dictionary = s["officers"][id]
		p["loyalty"] = maxi(0, p["loyalty"] - drop)
	report["events"].append({"kind": "leave", "org": org, "lost": lost})
