extends RefCounted
## 시나리오 처음 상태 — 장르 팩 명단 + assign + 구역 주인(resolve) + factions(본거지 · 두목 · 정예) + 3층 시작값(data/game/setup.json).
## 설계: docs/C1_설계서_상태와턴.md 3-3 · 7절 · 요구: FR-117 · 시험: tests/unit/test_setup.gd · 결정: docs/기획_차이.md (나)9 · 12
## - 판 조직 = 명단 소속 · 구역 주인을 이 시나리오로 푼(resolve) 조직. 정치 · 공권력(units kind state)은 무소속("")으로 풀려 빠진다.
## - 본거지가 이 판 구역에 없으면 판 밖 조직이다: hq "" · 조직원 0 · 그 간부는 away(행동 · 대우 없음).
## - 두목: assign 의 post boss → 팩 두목(그 조직 간부일 때) → 가장 높은 등급(같으면 id 순).
## - 등급: 명단 rank 가 null · '그 아래급'(below) · rank_provisional 이면 자리값(game.json rank_placeholder) + rank_prov.
## - 칸: 구역마다 setup 의 slots 개 · 업종은 districts trades 를 돌아가며 · 주인은 앞 owned_slots 칸을 lv1 로 쥔다.

const State = preload("res://sim/state.gd")
const Tables = preload("res://sim/tables.gd")


## {"state": 처음 상태, "errors": [...]} — player 가 ""면 고를 수 있는 첫 조직
static func scenario(t: Dictionary, sid: String, seed: int, player: String = "") -> Dictionary:
	if not t["scenarios"].has(sid):
		return {"state": {}, "errors": ["모르는 시나리오 %s" % sid]}
	var sc: Dictionary = t["scenarios"][sid]
	var playable: Array = sc.get("playable", [])
	if player == "":
		player = String(playable[0]) if not playable.is_empty() else ""
	if not playable.has(player):
		return {"state": {}, "errors": ["%s 에서 고를 수 없는 조직 %s" % [sid, player]]}
	var cfg: Dictionary = t["setup"]
	var over: Dictionary = cfg.get("scenarios", {}).get(sid, {})
	var s := State.new_state(seed, sid, player, "canon", int(t["game"]["lengths"][0]))
	var zones := Tables.districts_in(t, sid)

	# 명단(+ assign) → 사람마다 [조직, 자리, 명단 줄]
	var assign := {}
	for a in sc.get("assign", []):
		assign[Tables.current_id(t, a["id"])] = a
	var people := {}
	var orgs := {}
	for m in sc.get("roster", []):
		var id := Tables.current_id(t, m["id"])
		var a: Dictionary = assign.get(id, {})
		var org := Tables.resolve(t, a.get("faction", m.get("faction")), sid)
		people[id] = {"org": org, "post": String(a.get("post", "")), "row": m}
		if org != "":
			orgs[org] = true
	for zid in zones:
		var owner := Tables.resolve(t, t["districts"][zid]["owners"][sid], sid)
		if owner != "":
			orgs[owner] = true

	# 조직
	for org in State.sorted_keys(orgs):
		var hq := Tables.hq_of(t, org, sid)
		if not zones.has(hq):
			hq = ""
		var o := State.new_org("", hq)
		var vals: Dictionary = _merged(cfg.get("org_default", {}), over.get("orgs", {}).get(org, {}))
		for k in ["cash", "heat", "fame", "cohesion"]:
			if vals.has(k):
				o[k] = int(vals[k])
		for g in State.TROOP_GRADES:
			o["troops"][g] = int(vals.get("troops", {}).get(g, 0)) if hq != "" else 0
		var el = t["factions"][org].get("elite")
		if el is Dictionary and el.get("unit") is String:
			o["elite"]["unit"] = el["unit"]
		s["orgs"][org] = o

	# 구역
	var zdef: Dictionary = cfg.get("zone_default", {})
	for zid in zones:
		var owner := Tables.resolve(t, t["districts"][zid]["owners"][sid], sid)
		var z := State.new_zone(owner)
		var vals: Dictionary = _merged(zdef, over.get("zones", {}).get(zid, {}))
		for k in ["flow", "people", "police"]:
			if vals.has(k):
				z[k] = int(vals[k])
		var trades: Array = t["districts"][zid].get("trades", [])
		for i in int(vals.get("slots", 0)):
			var mine := owner != "" and i < int(vals.get("owned_slots", 0))
			z["slots"].append({"kind": trades[i % trades.size()], "org": owner if mine else "", "lv": 1 if mine else 0, "dmg": 0})
		if owner != "":
			z["facilities"] = ["hq", "office"] if s["orgs"][owner]["hq"] == zid else ["office"]
		s["zones"][zid] = z

	# 간부
	var placeholder: String = t["game"]["rank_placeholder"]
	for id in State.sorted_keys(people):
		var info: Dictionary = people[id]
		var row: Dictionary = info["row"]
		var org: String = info["org"]
		var zone: String = s["orgs"][org]["hq"] if org != "" else ""
		var rank = row.get("rank")
		var prov: bool = rank == null or rank == t["below"] or row.get("rank_provisional", false) == true or not t["rank_no"].has(rank)
		var p := State.new_officer(org, zone, placeholder if (rank == null or not t["rank_no"].has(rank)) else String(rank))
		p["rank_prov"] = prov
		p["status"] = "active" if zone != "" else "away"
		var loyal = t["strat"].get(id, {}).get("loyalty")
		if loyal != null:
			p["loyalty"] = int(loyal) * 100
		p["skills"] = t["rules"].progress(id)[1]
		s["officers"][id] = p

	# 두목
	for org in State.sorted_keys(s["orgs"]):
		var boss := ""
		for id in State.sorted_keys(people):
			if people[id]["org"] == org and people[id]["post"] == "boss":
				boss = id
				break
		var fb = t["factions"][org].get("boss")
		if boss == "" and fb is String and people.has(Tables.current_id(t, fb)) and people[Tables.current_id(t, fb)]["org"] == org:
			boss = Tables.current_id(t, fb)
		if boss == "":
			var best := -1
			for id in State.officers_of(s, org, false):
				var r := int(t["rank_no"].get(s["officers"][id]["rank"], 0))
				if r > best:
					best = r
					boss = id
		s["orgs"][org]["boss"] = boss
		if boss != "":
			s["officers"][boss]["post"] = "boss"
	return {"state": s, "errors": State.check_invariants(s, t)}


## 기본값 위에 덮는 값(troops 는 등급마다 덮는다)
static func _merged(base: Dictionary, top: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in top:
		if k == "troops" and out.get("troops") is Dictionary:
			for g in top["troops"]:
				out["troops"][g] = top["troops"][g]
		else:
			out[k] = top[k]
	return out
