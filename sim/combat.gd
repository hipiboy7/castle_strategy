extends RefCounted
## 습격 — 08 4-1 · 14-2. 충돌 단계(13절 6) 처리기: 받은 습격 · 지키기 명령을 (구역 id → 조직 id) 순으로 묶어 3구간(입구 → 안 → 본진) 자동 전투를 돌린다.
## 들어가는 쪽이 본진을 넘으면 구역을 차지한다. 지키는 쪽은 그 구역 간부 + 이웃 자기 구역의 원군(본진) + 조직원. 같은 구간에 양쪽 간부가 있으면 구간 시작에 가장 높은 등급끼리 일기토(sim/duel.gd)로 넘긴다.
## 결정적: 난수는 Pcg32 갈래(seed · 턴 · "clash" · "구역|조직") 하나 · 순회는 정렬한 키 · 상태는 정수. 기록(보고 battles)은 해시에 넣지 않는다.
## 결과를 상태에 넣는다: 조직원 손실 · 간부 부상(wounded · wound) · 카피(seen · skills) · 구역 주인 · 사업장 · 거점 · 물러남 · 잡힘 · 열기 · 명성.
## 3층 값: data/game/combat.json(raid · unit · cards). 2층: rank_damage_k · one_shot · shrugs_off · immune_lower(rules_common).
## heal(s, ctx) — 결산 단계: 다친 간부의 부상이 heal.per_turn 씩 낫고 0 이면 다시 움직인다.
## 설계: docs/C3_설계서_습격과일기토.md 2 · 4절 · 요구: FR-301 · FR-302 · FR-305 · FR-306 · FR-308 · 시험: tests/unit/test_combat.gd

const Fixed = preload("res://sim/fixed.gd")
const State = preload("res://sim/state.gd")
const Tables = preload("res://sim/tables.gd")
const Orders = preload("res://sim/orders.gd")
const Duel = preload("res://sim/duel.gd")
const Pcg32 = preload("res://sim/rng.gd")
const SECTIONS := ["입구", "안", "본진"]
const DEF_SLOT := [2, 0, 1]                  # 지키는 간부 자리(등급 높은 순): 본진 → 입구 → 안 → 본진 …


## 충돌 단계 처리기 — ctx["accepted"]["clash"] 의 습격 · 지키기 명령
static func run_phase(s: Dictionary, ctx: Dictionary) -> void:
	var t: Dictionary = ctx["t"]
	var rc: Dictionary = t["combat"]["raid"]
	var report: Dictionary = ctx["report"]
	if not report.has("battles"):
		report["battles"] = []
	var guard := {}
	var raids := {}
	for o in ctx.get("accepted", {}).get("clash", []):
		var why := ""
		if s["officers"][o["by"]]["status"] != "active":
			why = "%s 는 움직일 수 없다" % o["by"]
		else:
			why = Orders.apply_one(s, o, ctx)
		if why == "" and o["kind"] == "raid":
			var key := "%s|%s" % [o["to"], o["org"]]
			if not raids.has(key):
				raids[key] = {"zone": o["to"], "org": o["org"], "by": [], "cards": [], "orders": []}
			var g: Dictionary = raids[key]
			if g["by"].has(o["by"]):
				why = "%s 는 이미 이 습격에 나섰다" % o["by"]
			elif g["by"].size() >= int(rc["max_officers"]):
				why = "습격 간부는 %d명까지" % int(rc["max_officers"])
			else:
				g["by"].append(o["by"])
				g["orders"].append(o)
				for c in o["args"].get("cards", []):
					if not g["cards"].has(c) and g["cards"].size() < int(rc["max_cards"]):
						g["cards"].append(c)
		elif why == "" and o["kind"] == "defend":
			var key := "%s|%s" % [o["to"], o["org"]]
			if not guard.has(key):
				guard[key] = []
			var c: String = o["args"].get("card", "")
			if guard[key].has(c) or guard[key].size() >= int(rc["max_cards"]):
				why = "이 구역 지키기 카드는 이미 %s" % ", ".join(guard[key])
			else:
				guard[key].append(c)
				report["applied"].append(o)
		if why != "":
			report["rejected"].append({"order": o, "why": why})
	for key in State.sorted_keys(raids):
		var g: Dictionary = raids[key]
		var owner: String = s["zones"][g["zone"]]["owner"]
		if owner == g["org"]:
			for o in g["orders"]:
				report["rejected"].append({"order": o, "why": "앞 습격으로 이미 우리 구역이 됐다"})
			continue
		var standing: Array = g["by"].filter(func(id): return s["officers"][id]["status"] == "active")
		if standing.is_empty():
			for o in g["orders"]:
				report["rejected"].append({"order": o, "why": "나설 간부가 없다(앞 싸움에서 다침)"})
			continue
		var rng = Pcg32.new().init_stream(ctx["seed"], ctx["turn"], "clash", key)
		var rec := raid(s, t, ctx["turn"], g["zone"], g["org"], standing, g["cards"], guard.get("%s|%s" % [g["zone"], owner], []), rng)
		report["battles"].append(rec)
		for o in g["orders"]:
			report["applied"].append(o)


## 습격 하나 — s 를 바꾸고 기록을 돌려준다(AI 가 사본으로 미리 돌려 볼 때도 쓴다)
static func raid(s: Dictionary, t: Dictionary, turn: int, zone: String, org: String, by: Array, cards: Array, def_cards: Array, rng) -> Dictionary:
	var rc: Dictionary = t["combat"]["raid"]
	var cd: Dictionary = t["combat"]["cards"]
	var owner: String = s["zones"][zone]["owner"]
	var rec := {"zone": zone, "att": org, "def": owner, "by": by.duplicate(), "cards": cards.duplicate(),
		"def_cards": def_cards.duplicate() if owner != "" else [], "sections": [], "won": false, "notes": [],
		"loss": {org: {}}, "down": [], "captive": [], "learned": [], "def_officers": [], "reinforce": []}
	if owner != "":
		rec["loss"][owner] = {}
	# 들어가는 쪽 — 간부(등급 높은 순) + 조직원 commit_bp(올림)
	var att: Array = []
	for id in by_rank(s, t, by):
		att.append(officer_unit(s, t, id, 0))
	for g in State.TROOP_GRADES:
		var n := Fixed.ceil_div(int(s["orgs"][org]["troops"][g]) * int(rc["commit_bp"]), Fixed.BP)
		if n > 0:
			att.append(group_unit(t, g, n, 0))
	# 지키는 쪽 — 그 구역의 움직일 수 있는 간부 + 조직원(본거지 100% · 다른 구역 50% · 올림)을 구간에 나눈다
	var D := [[], [], []]
	if owner != "":
		var defs: Array = by_rank(s, t, State.officers_of(s, owner).filter(func(id): return s["officers"][id]["zone"] == zone))
		if cards.has("decoy") and not defs.is_empty():
			var mine := 0
			for id in by:
				mine = maxi(mine, int(t["strat"].get(id, {}).get("scheming", 0)))
			var theirs := int(t["strat"].get(defs[0], {}).get("scheming", 0))
			if theirs > mine:
				rec["notes"].append({"card": "decoy", "ok": false, "who": defs[0]})
			else:
				rec["notes"].append({"card": "decoy", "ok": true, "who": defs[0]})
				defs.remove_at(0)
		rec["def_officers"] = defs.duplicate()
		for i in defs.size():
			D[DEF_SLOT[i % 3]].append(officer_unit(s, t, defs[i], 1))
		# 원군 — 땅길로 이웃한 자기 구역의 움직일 수 있는 간부(등급 높은 순 · reinforce_max)가 본진에 더해진다
		var near: Array = State.officers_of(s, owner).filter(func(id):
			var z: String = s["officers"][id]["zone"]
			return z != zone and s["zones"].has(z) and s["zones"][z]["owner"] == owner and Tables.neighbors(t, zone).has(z))
		rec["reinforce"] = by_rank(s, t, near).slice(0, int(rc["reinforce_max"]))
		for id in rec["reinforce"]:
			D[2].append(officer_unit(s, t, id, 1))
		var share: int = int(rc["defend_bp"]["hq"] if s["orgs"][owner]["hq"] == zone else rc["defend_bp"]["other"])
		for g in State.TROOP_GRADES:
			var n := Fixed.ceil_div(int(s["orgs"][owner]["troops"][g]) * share, Fixed.BP)
			var parts := _split(n, rc["sections"])
			for i in 3:
				if parts[i] > 0:
					D[i].append(group_unit(t, g, parts[i], 1))
	var skip := -1
	if cards.has("bypass"):
		var ok: bool = int(s["orgs"][org]["intel"].get(zone, 0)) >= int(cd["bypass"]["intel"])
		rec["notes"].append({"card": "bypass", "ok": ok, "who": ""})
		if ok:
			skip = 1
	var won := true
	for i in 3:
		if i == skip:
			rec["sections"].append({"i": i, "result": "skip", "ticks": 0, "log": [], "duels": [], "start": [_heads(att), _heads(D[i])]})
			continue
		var sec := _section(s, t, i, att, D[i], cards, def_cards, rng, rec)
		rec["sections"].append(sec)
		if sec["result"] != "att":
			won = false
			break
	rec["won"] = won
	# 손실 · 부상을 상태에 넣는다
	var all_units: Array = att.duplicate()
	for i in 3:
		all_units.append_array(D[i])
	for u in all_units:
		var side_org: String = org if u["side"] == 0 else owner
		if u["t"] == "g":
			var lost: int = u["n0"] - u["n"]
			if lost > 0:
				var tr: Dictionary = s["orgs"][side_org]["troops"]
				lost = mini(lost, int(tr[u["grade"]]))
				tr[u["grade"]] = int(tr[u["grade"]]) - lost
				rec["loss"][side_org][u["grade"]] = int(rec["loss"][side_org].get(u["grade"], 0)) + lost
		elif u["down"]:
			_wound(s, u["id"], int(u["wound"]))
			rec["down"].append(u["id"])
	var heat: Dictionary = s["orgs"][org]
	heat["heat"] = mini(State.PCT_MAX, int(heat["heat"]) + int(rc["heat_bp"]))
	if won:
		_fame(s, org, int(rc["fame_win_bp"]))
		if owner != "":
			_fame(s, owner, -int(rc["fame_lose_bp"]))
		_capture(s, t, turn, zone, org, owner, rec)
	else:
		_fame(s, org, -int(rc["fame_lose_bp"]))
		if owner != "":
			_fame(s, owner, int(rc["fame_win_bp"]))
	return rec


## 한 구간 — 구간 시작 일기토(가장 높은 등급끼리 · 남은 간부가 한쪽에만 있을 때까지) → 틱(상한 tick_cap · 넘으면 지키는 쪽이 버팀)
static func _section(s: Dictionary, t: Dictionary, i: int, A: Array, D: Array, cards: Array, def_cards: Array, rng, rec: Dictionary) -> Dictionary:
	var rc: Dictionary = t["combat"]["raid"]
	var cd: Dictionary = t["combat"]["cards"]
	var mo: Dictionary = rc["morale"]
	var morale := [int(mo["start"]), int(mo["start"])]
	var sides := [A, D]
	var sec := {"i": i, "result": "", "ticks": 0, "log": [], "duels": [], "start": [_heads(A), _heads(D)]}
	for side in sides:
		for u in side:
			if u["t"] == "o" and not u["down"]:
				u["immune"] = int(rc["immune_ticks"]) if u["imm"] else 0
				u["pin"] = false
	while true:
		var a := _top_officer(A)
		var b := _top_officer(D)
		if a.is_empty() or b.is_empty():
			break
		var r := Duel.fight(t, Duel.fighter(t, s, a["id"]), Duel.fighter(t, s, b["id"]), rng)
		r["sec"] = i
		sec["duels"].append(r)
		var lose_u: Dictionary = a if r["w"] == 1 else b
		lose_u["down"] = true
		lose_u["wound"] = r["wound"]
		morale[r["w"]] += int(mo["duel_win"])
		morale[1 - r["w"]] -= int(mo["officer_down"])
		for k in 2:
			var who: String = a["id"] if k == 0 else b["id"]
			var p: Dictionary = s["officers"][who]
			p["seen"] = r["seen"][k]
			for sk in r["learned"][k]:
				if not p["skills"].has(sk):
					p["skills"].append(sk)
					rec["learned"].append({"id": who, "skill": sk})
	var heads0 := [_heads(A), _heads(D)]
	for tick in range(1, int(rc["tick_cap"]) + 1):
		if _heads(A) == 0 or _heads(D) == 0 or morale[0] <= 0 or morale[1] <= 0:
			break
		sec["ticks"] = tick
		var siege := {}
		for u in _act_order(A, D):
			if (u["t"] == "g" and u["n"] <= 0) or (u["t"] == "o" and u["down"]):
				continue
			if u["side"] == 1 and i == 0 and cards.has("surprise") and tick <= int(cd["surprise"]["skip_ticks"]):
				continue
			if u["t"] == "o" and u["pin"]:
				u["pin"] = false
				continue
			var mult := Fixed.BP
			if u["side"] == 0 and i == 0 and cards.has("charge"):
				mult = int(cd["charge"]["dmg_bp"])
			if u["side"] == 1 and i == 0 and tick == 1 and def_cards.has("ambush"):
				mult = int(cd["ambush"]["dmg_bp"])
			var foes: Array = D if u["side"] == 0 else A
			var shield: bool = (cards if u["side"] == 1 else def_cards).has("shield")
			_act(t, u, foes, mult, shield, siege, rng, morale, mo)
		for side in sides:
			for u in side:
				if u["t"] == "o" and u["immune"] > 0:
					u["immune"] -= 1
		for k in 2:
			if _heads(sides[k]) * 2 < heads0[k]:
				morale[k] -= int(mo["half_tick"])
		sec["log"].append([_heads(A), _heads(D), maxi(0, morale[0]), maxi(0, morale[1])])
	if _heads(D) == 0 or morale[1] <= 0:
		sec["result"] = "att"
	else:
		sec["result"] = "def"
	sec["morale"] = [maxi(0, morale[0]), maxi(0, morale[1])]
	sec["end"] = [_heads(A), _heads(D)]
	return sec


## 한 유닛의 한 번 — 간부는 적 조직원 묶음(높은 등급 먼저)을 친다. 묶음은 적 간부(포위 한도 siege)를 먼저, 없으면 적 묶음을 친다
static func _act(t: Dictionary, u: Dictionary, foes: Array, mult: int, shield: bool, siege: Dictionary, rng, morale: Array, mo: Dictionary) -> void:
	var rules = t["rules"]
	var rc: Dictionary = t["combat"]["raid"]
	var cap: int = int(rc["siege"])
	if u["t"] == "o":
		var g := _top_group(foes)
		if g.is_empty():
			return
		var gap: int = rules.rank_gap(u["rank"], g["grade"])
		var half: int = gap / 2 if gap >= 0 else -((-gap + 1) / 2)
		var sweep: int = maxi(1, 1 + half)
		var kills := 0
		if rules.one_shot(u["rank"], g["grade"]):
			kills = mini(g["n"], sweep)
		else:
			var dmg := Fixed.div_round(Fixed.bp(u["atk"], mult) * Fixed.milli(rules.rank_damage_k(u["rank"], g["grade"])), 1000)
			var total: int = g["dmg"] + dmg
			kills = mini(mini(total / g["hp1"], sweep), g["n"])
			g["dmg"] = total - kills * g["hp1"] if kills < sweep else 0
		if shield:
			kills -= kills * (Fixed.BP - int(t["combat"]["cards"]["shield"]["loss_bp"])) / Fixed.BP
		g["n"] -= kills
		if g["n"] <= 0:
			g["n"] = 0
			g["dmg"] = 0
		return
	var target := {}
	for f in foes:
		if f["t"] == "o" and not f["down"] and int(siege.get(f["id"], 0)) < cap:
			target = f
			break
	if not target.is_empty():
		var eff: int = mini(u["n"], cap - int(siege.get(target["id"], 0)))
		siege[target["id"]] = int(siege.get(target["id"], 0)) + eff
		if target["immune"] > 0 and rules.immune_lower(target["rank"], u["grade"]):
			return
		var dmg := Fixed.div_round(Fixed.bp(eff * u["atk1"], mult) * Fixed.milli(rules.rank_damage_k(u["grade"], target["rank"])), 1000)
		target["hp"] = maxi(0, target["hp"] - dmg)
		if target["hp"] == 0:
			target["down"] = true
			target["wound"] = int(rc["down_wound"])
			morale[target["side"]] -= int(mo["officer_down"])
		elif not rules.shrugs_off(target["rank"], u["grade"]):
			if rng.chance_bp(mini(int(rc["pin_max_bp"]), eff * Fixed.BP / int(rc["pin_div"]))):
				target["pin"] = true
		return
	var g := _top_group(foes)
	if g.is_empty():
		return
	var dmg := Fixed.div_round(Fixed.bp(u["n"] * u["atk1"], mult) * Fixed.milli(rules.rank_damage_k(u["grade"], g["grade"])), 1000)
	if shield:
		dmg = Fixed.bp(dmg, int(t["combat"]["cards"]["shield"]["loss_bp"]))
	var total: int = g["dmg"] + dmg
	var kills: int = mini(total / g["hp1"], g["n"])
	g["n"] -= kills
	g["dmg"] = total - kills * g["hp1"] if g["n"] > 0 else 0


## 차지 — 구역 주인 · 옛 주인의 사업장(같은 레벨) · 거점(사무실만) · 옛 주인 간부 물러남(없으면 잡힘).
## 나선 간부는 출발한 구역으로 돌아온다(습격은 출격 — 들어가 살려면 다음 주 이동 명령 · docs/기획_차이.md (나)27)
static func _capture(s: Dictionary, t: Dictionary, turn: int, zone: String, org: String, old: String, rec: Dictionary) -> void:
	var z: Dictionary = s["zones"][zone]
	z["owner"] = org
	for sl in z["slots"]:
		if old != "" and sl["org"] == old:
			sl["org"] = org
	z["facilities"] = ["office"]
	if old != "":
		if s["orgs"][old]["hq"] == zone:
			s["orgs"][old]["hq_lost_turn"] = turn
		var dest := _retreat(s, t, old, zone)
		for id in State.officers_of(s, old, false):
			var p: Dictionary = s["officers"][id]
			if p["zone"] != zone or not ["active", "wounded"].has(p["status"]):
				continue
			if dest == "":
				p["status"] = "captive"
				rec["captive"].append(id)
			else:
				p["zone"] = dest


## 물러날 곳 — 아직 쥔 본거지 → 쥔 구역(id 순) → ""(잡힘)
static func _retreat(s: Dictionary, t: Dictionary, org: String, lost: String) -> String:
	var hq: String = s["orgs"][org]["hq"]
	if hq != "" and hq != lost and s["zones"].has(hq) and s["zones"][hq]["owner"] == org:
		return hq
	for zid in State.sorted_keys(s["zones"]):
		if zid != lost and s["zones"][zid]["owner"] == org:
			return zid
	return ""


## 결산 단계 처리기 — 다친 간부 회복(heal.per_turn) · 다 나으면 active
static func heal(s: Dictionary, ctx: Dictionary) -> void:
	var per: int = int(ctx["t"]["combat"]["heal"]["per_turn"])
	for id in State.sorted_keys(s["officers"]):
		var p: Dictionary = s["officers"][id]
		if p["status"] != "wounded":
			continue
		p["wound"] = maxi(0, int(p["wound"]) - per)
		if p["wound"] == 0:
			p["status"] = "active"


static func _wound(s: Dictionary, id: String, w: int) -> void:
	var p: Dictionary = s["officers"][id]
	p["wound"] = mini(State.PCT_MAX, int(p["wound"]) + w)
	p["status"] = "wounded"


static func _fame(s: Dictionary, org: String, d: int) -> void:
	var o: Dictionary = s["orgs"][org]
	o["fame"] = clampi(int(o["fame"]) + d, 0, State.PCT_MAX)


## 간부 유닛 — HP = 200 + 40r (+ 맷집 × 4) · ATK = 10(r+1)(1 + 힘/100 — 없으면 0.5) · 무적 기술(immune_lower)이 있으면 구간마다 immune_ticks
static func officer_unit(s: Dictionary, t: Dictionary, id: String, side: int) -> Dictionary:
	var un: Dictionary = t["combat"]["unit"]
	var p: Dictionary = s["officers"][id]
	var st: Dictionary = t["chars"].get(id, {}).get("stats", {})
	var r: int = t["rules"].rank_index(p["rank"])
	var hp: int = int(un["off_hp_base"]) + int(un["off_hp_step"]) * r
	if st.has("맷집"):
		hp += int(un["off_hp_tough"]) * int(st["맷집"])
	var power: int = int(st["힘"]) if st.has("힘") else int(un["no_power"])
	var imm := false
	for sk in p["skills"]:
		if t["rules"].skill_info(sk).get("effects", {}).get("immune_lower", false):
			imm = true
	return {"t": "o", "id": id, "side": side, "rank": p["rank"], "r": r, "hp": hp, "max": hp,
		"atk": Fixed.div_round(int(un["off_atk"]) * (r + 1) * (100 + power), 100), "imm": imm, "immune": 0, "pin": false,
		"down": false, "wound": 0}


## 조직원 묶음 — 한 명 HP · ATK = 10(r+1)
static func group_unit(t: Dictionary, grade: String, n: int, side: int) -> Dictionary:
	var un: Dictionary = t["combat"]["unit"]
	var r: int = t["rules"].rank_index(grade)
	return {"t": "g", "grade": grade, "r": r, "side": side, "n": n, "n0": n, "dmg": 0,
		"hp1": int(un["troop_hp"]) * (r + 1), "atk1": int(un["troop_atk"]) * (r + 1)}


## 행동 차례 — 간부(id 순 · 들어가는 쪽 먼저) → 묶음(높은 등급 먼저 · 들어가는 쪽 먼저)
static func _act_order(A: Array, D: Array) -> Array:
	var offs := (A + D).filter(func(u): return u["t"] == "o")
	offs.sort_custom(func(x, y): return x["id"] < y["id"] if x["id"] != y["id"] else x["side"] < y["side"])
	var groups := (A + D).filter(func(u): return u["t"] == "g")
	groups.sort_custom(func(x, y): return x["r"] > y["r"] if x["r"] != y["r"] else x["side"] < y["side"])
	return offs + groups


static func _top_officer(side: Array) -> Dictionary:
	for u in side:
		if u["t"] == "o" and not u["down"]:
			return u
	return {}


static func _top_group(side: Array) -> Dictionary:
	var best := {}
	for u in side:
		if u["t"] == "g" and u["n"] > 0 and (best.is_empty() or u["r"] > best["r"]):
			best = u
	return best


## 남은 머릿수(조직원 + 선 간부)
static func _heads(side: Array) -> int:
	var n := 0
	for u in side:
		if u["t"] == "g":
			n += int(u["n"])
		elif not u["down"]:
			n += 1
	return n


## 등급 높은 순(같으면 id 순)
static func by_rank(s: Dictionary, t: Dictionary, ids: Array) -> Array:
	var out := ids.duplicate()
	out.sort_custom(func(x, y):
		var rx: int = t["rules"].rank_index(s["officers"][x]["rank"])
		var ry: int = t["rules"].rank_index(s["officers"][y]["rank"])
		return rx > ry if rx != ry else x < y)
	return out


## n 을 만분율 나눔(앞 구간이 나머지를 받는다)
static func _split(n: int, parts: Array) -> Array:
	var out := [0, 0, 0]
	var rest := n
	for i in range(1, 3):
		out[i] = n * int(parts[i]) / Fixed.BP
		rest -= out[i]
	out[0] = rest
	return out
