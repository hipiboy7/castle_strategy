extends RefCounted
## 습격 — 08 4-1 · 14-2. 충돌 단계(13절 6) 처리기: 받은 습격 · 지키기 명령을 (구역 id → 조직 id) 순으로 묶어 3구간(입구 → 안 → 본진) 자동 전투를 돌린다.
## 들어가는 쪽이 본진을 넘으면 구역을 차지한다. 지키는 쪽은 그 구역 간부 + 이웃 자기 구역의 원군(본진) + 조직원. 같은 구간에 양쪽 간부가 있으면 구간 시작에 가장 높은 등급끼리 일기토(sim/duel.gd)로 넘긴다.
## 결정적: 난수는 Pcg32 갈래(seed · 턴 · "clash" · "구역|조직") 하나 · 순회는 정렬한 키 · 상태는 정수. 기록(보고 battles)은 해시에 넣지 않는다.
## 결과를 상태에 넣는다: 조직원 손실 · 간부 부상(wounded · wound) · 카피(seen · skills) · 구역 주인 · 사업장 · 거점 · 물러남 · 잡힘 · 열기 · 명성.
## 3층 값: data/game/combat.json(raid · unit · cards). 2층: rank_damage_k · one_shot · shrugs_off · immune_lower(rules_common).
## heal(s, ctx) — 결산 단계: 다친 간부의 부상이 heal.per_turn 씩 낫고 0 이면 다시 움직인다.
## C4-2 구간 결과 계약(FR-415 · 416): ctx 의 fights(받은 구간 결과) · ask(묻는 조직) · auto(틱으로 풀 묶음 키) — 받은 결과는 outcome_error 로 검증해
## 넣고(틀리면 틱 · 기록 rejected), 묻는 조직의 간부가 서 있는 미해결 구간이면 ctx["need"] 를 채우고 멈춘다(작업 사본은 turn 이 버린다). 없으면 C4 전과 같다.
## 설계: docs/C3_설계서_습격과일기토.md 2 · 4절 · docs/C4_설계서_직접조작전투.md 2 · 3절 · 요구: FR-301 · FR-302 · FR-305 · FR-306 · FR-308 · FR-415 · FR-416
## 시험: tests/unit/test_combat.gd · tests/unit/test_fight_outcome.gd

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
		var rec := raid(s, t, ctx["turn"], g["zone"], g["org"], standing, g["cards"], guard.get("%s|%s" % [g["zone"], owner], []), rng, ctx)
		if rec.has("need"):
			ctx["need"] = rec["need"]
			return
		if not rec["used"].is_empty():
			if not ctx.has("used"):
				ctx["used"] = {}
			ctx["used"][key] = rec["used"]
		rec.erase("used")
		report["battles"].append(rec)
		for o in g["orders"]:
			report["applied"].append(o)


## 습격 준비(상태를 바꾸지 않는다 — 유닛은 값 사본) — {"A": 들어가는 쪽 유닛, "D": [구간 0 · 1 · 2 의 지키는 쪽 유닛], "skip": 건너뛸 구간(-1 없음),
## "def": 지키는 조직, "rec": 습격 기록 머리}. 틱 습격(raid)과 실시간 구간(C4 — fight/section.gd 의 need)이 같은 준비를 쓴다(설계서 2절).
## 싸우지 않는 사람(명단 noncombat)은 들어가는 쪽 · 지키는 쪽 · 원군 어디에도 서지 않는다(FR-409).
static func prepare(s: Dictionary, t: Dictionary, zone: String, org: String, by: Array, cards: Array, def_cards: Array) -> Dictionary:
	var rc: Dictionary = t["combat"]["raid"]
	var cd: Dictionary = t["combat"]["cards"]
	var owner: String = s["zones"][zone]["owner"]
	var rec := {"zone": zone, "att": org, "def": owner, "by": by.duplicate(), "cards": cards.duplicate(),
		"def_cards": def_cards.duplicate() if owner != "" else [], "sections": [], "won": false, "notes": [],
		"loss": {org: {}}, "down": [], "captive": [], "learned": [], "def_officers": [], "reinforce": [], "rejected": [], "used": {}}
	if owner != "":
		rec["loss"][owner] = {}
	# 들어가는 쪽 — 간부(등급 높은 순) + 조직원 commit_bp(올림)
	var att: Array = []
	for id in by_rank(s, t, fighters_only(s, t, by)):
		att.append(officer_unit(s, t, id, 0))
	for g in State.TROOP_GRADES:
		var n := Fixed.ceil_div(int(s["orgs"][org]["troops"][g]) * int(rc["commit_bp"]), Fixed.BP)
		if n > 0:
			att.append(group_unit(t, g, n, 0))
	# 지키는 쪽 — 그 구역의 움직일 수 있는 간부 + 조직원(본거지 100% · 다른 구역 50% · 올림)을 구간에 나눈다
	var D := [[], [], []]
	if owner != "":
		var defs: Array = by_rank(s, t, fighters_only(s, t, State.officers_of(s, owner).filter(func(id): return s["officers"][id]["zone"] == zone)))
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
		var near: Array = fighters_only(s, t, State.officers_of(s, owner).filter(func(id):
			var z: String = s["officers"][id]["zone"]
			return z != zone and s["zones"].has(z) and s["zones"][z]["owner"] == owner and Tables.neighbors(t, zone).has(z)))
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
	return {"A": att, "D": D, "skip": skip, "def": owner, "rec": rec}


## 실시간으로 풀 구간 하나의 준비 need(설계서 2-2 — 값 사본 · 정수 · 글). prep = prepare() 결과(들어가는 쪽 유닛은 앞 구간 결과가 옮겨진 채),
## side = 묻는 조직이 선 쪽(0 들어가는 쪽 · 1 지키는 쪽). 시드 = Pcg32(seed, turn, "fight", 묶음 키 | 구간)의 첫 값. 상태는 읽기만 한다.
static func need_of(s: Dictionary, t: Dictionary, turn: int, prep: Dictionary, i: int, side: int) -> Dictionary:
	var rec: Dictionary = prep["rec"]
	var key := "%s|%s" % [rec["zone"], rec["att"]]
	var A: Array = prep["A"].duplicate(true)
	var D: Array = prep["D"][i].duplicate(true)
	var known := {}
	for u in A + D:
		if u["t"] == "o":
			var p: Dictionary = s["officers"][u["id"]]
			known[u["id"]] = {"skills": Array(p["skills"]).duplicate(), "seen": Dictionary(p.get("seen", {})).duplicate()}
	return {"key": key, "turn": turn, "zone": rec["zone"], "att": rec["att"], "def": rec["def"], "i": i, "side": side,
		"A": A, "D": D, "cards": rec["cards"].duplicate(), "def_cards": rec["def_cards"].duplicate(), "known": known,
		"seed": Pcg32.new().init_stream(int(s["seed"]), turn, "fight", "%s|%d" % [key, i]).next_u32()}


## 싸울 수 있는 사람만(명단 noncombat 이 아닌 사람 · 차례는 그대로)
static func fighters_only(s: Dictionary, t: Dictionary, ids: Array) -> Array:
	return ids.filter(func(id): return not Tables.noncombat(t, String(s.get("scenario", "")), id))


## 구간 결과의 한쪽 줄(설계서 2-3 의 "a" 또는 "d" — 유닛과 같은 차례 · 같은 종류)을 유닛에 옮긴다: 간부 체력 · 쓰러짐 · 부상, 묶음 머릿수.
## 들어가는 쪽 유닛은 이렇게 다음 구간으로 이어진다(FR-408). 꼴 검사는 부르는 쪽 몫(C4-2 outcome_error) — 여기서는 범위만 자른다.
static func apply_section(units: Array, rows: Array) -> void:
	for k in mini(units.size(), rows.size()):
		var u: Dictionary = units[k]
		var r: Dictionary = rows[k]
		if u["t"] == "g":
			u["n"] = clampi(int(r.get("n", u["n"])), 0, int(u["n"]))
			u["dmg"] = 0
		elif not u["down"]:
			u["hp"] = clampi(int(r.get("hp", u["hp"])), 0, int(u["hp"]))
			if r.get("down", false) == true or u["hp"] == 0:
				u["down"] = true
				u["hp"] = 0
				u["wound"] = clampi(int(r.get("wound", 0)), 0, State.PCT_MAX)


## 습격 하나 — s 를 바꾸고 기록을 돌려준다(AI 가 사본으로 미리 돌려 볼 때도 쓴다 — opts 없이).
## opts(C4-2 · 설계서 3절): fights{묶음 키: {"<구간>": 구간 결과}} · ask(묻는 조직) · auto([묶음 키]). 구간마다 ① 우회로면 건너뜀 ② 받은 결과가
## 검증을 지나면 적용(기록 used) ③ 묻는 조직의 간부가 그 구간에 서 있고 · 맞은편에 누군가 있고 · 결과가 없으면 {"need": …}(s 는 앞 구간까지 바뀐 채 — 부른 쪽이 버린다) ④ 아니면 틱
static func raid(s: Dictionary, t: Dictionary, turn: int, zone: String, org: String, by: Array, cards: Array, def_cards: Array, rng, opts := {}) -> Dictionary:
	var prep := prepare(s, t, zone, org, by, cards, def_cards)
	var rc: Dictionary = t["combat"]["raid"]
	var owner: String = prep["def"]
	var rec: Dictionary = prep["rec"]
	var att: Array = prep["A"]
	var D: Array = prep["D"]
	var skip: int = prep["skip"]
	var key := "%s|%s" % [zone, org]
	var got = opts.get("fights", {}).get(key, {})
	var ask: String = String(opts.get("ask", ""))
	var side := -1
	if ask != "" and not Array(opts.get("auto", [])).has(key):
		side = 0 if ask == org else (1 if owner != "" and ask == owner else -1)
	var won := true
	for i in 3:
		if i == skip:
			rec["sections"].append({"i": i, "result": "skip", "ticks": 0, "log": [], "duels": [], "start": [_heads(att), _heads(D[i])]})
			continue
		var sec := {}
		var res = got.get(str(i)) if got is Dictionary else null
		if res != null:
			var why := outcome_error(t, i, att, D[i], res)
			if why == "":
				sec = _apply_rt(s, t, i, att, D[i], res, rec)
				rec["used"][str(i)] = res
			else:
				rec["rejected"].append({"i": i, "why": why})
		elif side >= 0 and _officer_stands(att if side == 0 else D[i]) and _heads(D[i] if side == 0 else att) > 0:
			return {"need": need_of(s, t, turn, prep, i, side)}
		if sec.is_empty():
			sec = _section(s, t, i, att, D[i], cards, def_cards, rng, rec)
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


## 서 있는 간부가 하나라도 있나
static func _officer_stands(units: Array) -> bool:
	for u in units:
		if u["t"] == "o" and not u["down"]:
			return true
	return false


## 구간 결과 검증(설계서 2-4) — "" 면 받는다. A · Di = 그 구간에 들어올 때의 유닛(need 의 A · D 와 같은 것). 결과가 정하지 않는 것(배우기)은 sim 이 판단한다
static func outcome_error(t: Dictionary, i: int, A: Array, Di: Array, res) -> String:
	if not (res is Dictionary):
		return "구간 결과가 사전이 아니다"
	for k in ["v", "i", "by", "result", "ticks", "a", "d", "morale", "seen"]:
		if not res.has(k):
			return "칸 %s 가 없다" % k
	if typeof(res["v"]) != TYPE_INT or res["v"] != 1:
		return "v 는 1"
	if typeof(res["i"]) != TYPE_INT or res["i"] != i:
		return "i 는 %d" % i
	if not ["direct", "auto"].has(res["by"]):
		return "by 는 direct · auto"
	if not ["att", "def"].has(res["result"]):
		return "result 는 att · def"
	var rc: Dictionary = t["combat"]["raid"]
	if not _int_in(res["ticks"], 0, int(rc["tick_cap"])):
		return "ticks 는 0 ~ %d" % int(rc["tick_cap"])
	var heads := [0, 0]
	var offs := 0
	var standing := {}
	for side in 2:
		var units: Array = A if side == 0 else Di
		var rows = res["a" if side == 0 else "d"]
		if not (rows is Array) or rows.size() != units.size():
			return "%s 줄 수가 유닛과 다르다" % ("a" if side == 0 else "d")
		for k in units.size():
			var u: Dictionary = units[k]
			var r = rows[k]
			var at := "%s[%d]" % ["a" if side == 0 else "d", k]
			if not (r is Dictionary) or r.get("t") != u["t"]:
				return "%s 종류가 다르다" % at
			if u["t"] == "g":
				if r.get("grade") != u["grade"]:
					return "%s 등급이 다르다" % at
				if not _int_in(r.get("n"), 0, int(u["n"])):
					return "%s n 은 0 ~ %d" % [at, int(u["n"])]
				heads[side] += int(r["n"])
				continue
			offs += 1
			if r.get("id") != u["id"]:
				return "%s id 가 다르다" % at
			if typeof(r.get("down")) != TYPE_BOOL:
				return "%s down 은 참거짓" % at
			if not _int_in(r.get("hp"), 0, int(u["hp"])):
				return "%s hp 는 0 ~ %d" % [at, int(u["hp"])]
			if not _int_in(r.get("wound"), 0, State.PCT_MAX):
				return "%s wound 는 0 ~ %d" % [at, State.PCT_MAX]
			if r["down"] != (r["hp"] == 0):
				return "%s 쓰러지면 hp 0 · hp 0 이면 쓰러짐" % at
			if u["down"] and not r["down"]:
				return "%s 쓰러져 들어온 간부가 일어섰다" % at
			if not r["down"]:
				heads[side] += 1
			if not u["down"]:
				standing[u["id"]] = true
	var mo: Dictionary = rc["morale"]
	var top: int = int(mo["start"]) + int(mo["duel_win"]) * offs
	var m = res["morale"]
	if not (m is Array) or m.size() != 2 or not _int_in(m[0], 0, top) or not _int_in(m[1], 0, top):
		return "morale 은 [0 ~ %d, 0 ~ %d]" % [top, top]
	var att_won: bool = heads[1] == 0 or m[1] == 0
	if (res["result"] == "att") != att_won:
		return "승패가 남은 수 · 사기와 맞지 않다"
	if res.has("frames") and not _int_in(res["frames"], 0, 100000000):
		return "frames 는 0 이상"
	var kl = res.get("kills", [0, 0])
	if not (kl is Array) or kl.size() != 2 or not _int_in(kl[0], 0, 1000000) or not _int_in(kl[1], 0, 1000000):
		return "kills 는 [정수, 정수]"
	if not (res["seen"] is Dictionary):
		return "seen 은 사전"
	for id in res["seen"]:
		if not standing.has(id) or t["chars"].get(id, {}).get("can_copy", false) != true:
			return "seen %s — 이 구간에 선 카피 간부가 아니다" % id
		var m2 = res["seen"][id]
		if not (m2 is Dictionary):
			return "seen %s 는 사전" % id
		for sk in m2:
			if t["rules"].skill_info(String(sk)).is_empty():
				return "seen %s — 판에 없는 기술 %s" % [id, sk]
			if not _int_in(m2[sk], 1, 1000000):
				return "seen %s.%s 는 1 이상" % [id, sk]
	return ""


static func _int_in(v, lo: int, hi: int) -> bool:
	return typeof(v) == TYPE_INT and v >= lo and v <= hi


## 받은 구간 결과를 넣는다(검증을 지난 것) — 유닛 체력 · 머릿수 · 쓰러짐, 본 횟수 → 배우기(copy.seen · can_learn — 일기토와 같은 규칙). 구간 기록을 돌려준다
static func _apply_rt(s: Dictionary, t: Dictionary, i: int, A: Array, Di: Array, res: Dictionary, rec: Dictionary) -> Dictionary:
	var start := [_heads(A), _heads(Di)]
	apply_section(A, res["a"])
	apply_section(Di, res["d"])
	var need_n: int = int(t["rules"].rule("copy", "seen", 2))
	for id in State.sorted_keys(res["seen"]):
		var p: Dictionary = s["officers"][id]
		for sk in State.sorted_keys(res["seen"][id]):
			p["seen"][sk] = int(p["seen"].get(sk, 0)) + int(res["seen"][id][sk])
			if int(p["seen"][sk]) >= need_n and not p["skills"].has(sk) and t["rules"].can_learn(sk, p["rank"], id):
				p["skills"].append(sk)
				rec["learned"].append({"id": id, "skill": sk})
	return {"i": i, "result": res["result"], "ticks": int(res["ticks"]), "log": [], "duels": [], "start": start,
		"end": [_heads(A), _heads(Di)], "morale": Array(res["morale"]).duplicate(), "rt": res["by"],
		"kills": Array(res.get("kills", [0, 0])).duplicate(), "frames": int(res.get("frames", 0))}


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
