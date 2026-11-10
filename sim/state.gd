extends RefCounted
## GameState v1 — 상태는 정수만 든 사전이다(해시 · 저장이 그대로 된다). 이 파일은 스키마 · 만들기 · 되읽기 · 해시 · 불변식만 맡는다.
## 설계: docs/C1_설계서_상태와턴.md 3-3 · 요구: FR-114 · 시험: tests/unit/test_state.gd
## 단위: 돈 · 머릿수 · 체력은 정수 · 백분율(열기 · 충성 · 결속 · 명성 · 경찰)은 ×100(0~10000) · 유동은 10000 = 1.00배 ·
##       지분 · 상납은 만분율(합 10000 = 100%) · 등급은 ranks.json ladder 이름. 돈은 음수를 허용한다(08 3-1 · 설계서 7절).

const StateHash = preload("res://sim/hash.gd")
const VERSION := 1
const TOP_KEYS := ["v", "seed", "scenario", "mode", "length", "turn", "player", "orgs", "officers", "zones", "castle",
	"events_done", "progress_done", "flags"]
const ORG_KEYS := ["cash", "heat", "fame", "cohesion", "boss", "hq", "alive", "troops", "elite", "relations", "vassal_of",
	"tribute_bp", "debts", "intel", "neg_cash_turns", "hq_lost_turn"]
const OFFICER_KEYS := ["org", "zone", "post", "rank", "rank_prov", "loyalty", "wound", "status", "skills", "seen", "mastery"]
const ZONE_KEYS := ["owner", "flow", "people", "police", "slots", "facilities"]
const TROOP_GRADES := ["건달급", "조장급", "네임드", "경호대급"]
const STATUSES := ["active", "wounded", "captive", "dead", "away"]
const POSTS := ["boss", "staff", "zone_chief", "captain", "guard", ""]
const PCT_MAX := 10000
const MAX_LV := 3


static func new_state(seed: int, scenario: String, player: String, mode: String = "canon", length: int = 26) -> Dictionary:
	return {"v": VERSION, "seed": seed, "scenario": scenario, "mode": mode, "length": length, "turn": 1, "player": player,
		"orgs": {}, "officers": {}, "zones": {},
		"castle": {"chair": "", "stakes": {}, "next_council": 0, "enemies": []},
		"events_done": [], "progress_done": [], "flags": {}}


static func new_org(boss: String, hq: String) -> Dictionary:
	var troops := {}
	for g in TROOP_GRADES:
		troops[g] = 0
	return {"cash": 0, "heat": 0, "fame": 0, "cohesion": 5000, "boss": boss, "hq": hq, "alive": true,
		"troops": troops, "elite": {"unit": "", "n": 0}, "relations": {}, "vassal_of": "", "tribute_bp": 0,
		"debts": [], "intel": {}, "neg_cash_turns": 0, "hq_lost_turn": -1}


static func new_officer(org: String, zone: String, rank: String) -> Dictionary:
	return {"org": org, "zone": zone, "post": "", "rank": rank, "rank_prov": false, "loyalty": 5000, "wound": 0,
		"status": "active", "skills": [], "seen": {}, "mastery": 0}


static func new_zone(owner: String) -> Dictionary:
	return {"owner": owner, "flow": PCT_MAX, "people": 0, "police": 0, "slots": [], "facilities": []}


static func to_dict(s: Dictionary) -> Dictionary:
	return s.duplicate(true)


## 저장 글에서 읽은 사전(JSON 수는 실수) → 정수 상태 + 오류 목록. {"state": 사전, "errors": [...]}
static func from_dict(d) -> Dictionary:
	if not (d is Dictionary):
		return {"state": {}, "errors": ["상태가 사전이 아니다"]}
	var errs := []
	var s = _ints(d, errs, "state")
	if s.get("v") != VERSION:
		errs.append("state.v — 모르는 형식 %s (이 판은 %d)" % [s.get("v"), VERSION])
	_need(s, TOP_KEYS, "state", errs)
	for group in [["orgs", ORG_KEYS], ["officers", OFFICER_KEYS], ["zones", ZONE_KEYS]]:
		var m = s.get(group[0], {})
		if not (m is Dictionary):
			errs.append("state.%s — 사전이 아니다" % group[0])
			continue
		for id in sorted_keys(m):
			if m[id] is Dictionary:
				_need(m[id], group[1], "state.%s.%s" % [group[0], id], errs)
			else:
				errs.append("state.%s.%s — 사전이 아니다" % [group[0], id])
	return {"state": s, "errors": errs}


static func hash_of(s: Dictionary) -> String:
	return StateHash.of(s)


## 불변식(매 턴 · 비면 통과) — 설계서 3-3. t 는 sim/tables.gd build 결과
static func check_invariants(s: Dictionary, t: Dictionary) -> Array:
	var errs := []
	var why := StateHash.check(s)
	if why != "":
		errs.append("정수 아닌 값 — " + why)
		return errs
	var orgs: Dictionary = s["orgs"]
	var offs: Dictionary = s["officers"]
	var zones: Dictionary = s["zones"]
	for id in sorted_keys(orgs):
		var o: Dictionary = orgs[id]
		var at := "orgs.%s" % id
		if not t["factions"].has(id):
			errs.append("%s — 표에 없는 조직" % at)
		for g in TROOP_GRADES:
			if int(o["troops"].get(g, 0)) < 0:
				errs.append("%s.troops.%s — 머릿수 음수 %d" % [at, g, o["troops"][g]])
		if int(o["elite"]["n"]) < 0:
			errs.append("%s.elite.n — 음수" % at)
		for k in ["heat", "fame", "cohesion", "tribute_bp"]:
			_range(o[k], 0, PCT_MAX, "%s.%s" % [at, k], errs)
		if o["boss"] != "" and (not offs.has(o["boss"]) or offs[o["boss"]]["status"] == "dead"):
			errs.append("%s.boss — 없거나 죽은 두목 %s" % [at, o["boss"]])
		if o["hq"] != "" and not zones.has(o["hq"]):
			errs.append("%s.hq — 판에 없는 구역 %s" % [at, o["hq"]])
		if o["vassal_of"] != "" and not orgs.has(o["vassal_of"]):
			errs.append("%s.vassal_of — 판에 없는 조직" % at)
	for id in sorted_keys(offs):
		var p: Dictionary = offs[id]
		var at := "officers.%s" % id
		if not t["people"].has(id):
			errs.append("%s — canon 에 없는 인물" % at)
		if p["org"] != "" and not orgs.has(p["org"]):
			errs.append("%s.org — 판에 없는 조직 %s" % [at, p["org"]])
		if p["zone"] != "" and not zones.has(p["zone"]):
			errs.append("%s.zone — 판에 없는 구역 %s" % [at, p["zone"]])
		if not t["rank_no"].has(p["rank"]):
			errs.append("%s.rank — 모르는 등급 %s" % [at, p["rank"]])
		if not STATUSES.has(p["status"]):
			errs.append("%s.status — 모르는 값 %s" % [at, p["status"]])
		if not POSTS.has(p["post"]):
			errs.append("%s.post — 모르는 값 %s" % [at, p["post"]])
		_range(p["loyalty"], 0, PCT_MAX, at + ".loyalty", errs)
		_range(p["wound"], 0, PCT_MAX, at + ".wound", errs)
	for id in sorted_keys(zones):
		var z: Dictionary = zones[id]
		var at := "zones.%s" % id
		if not t["districts"].has(id):
			errs.append("%s — 표에 없는 구역" % at)
		if z["owner"] != "" and not (orgs.has(z["owner"]) and orgs[z["owner"]]["alive"]):
			errs.append("%s.owner — 판에 없거나 무너진 조직 %s" % [at, z["owner"]])
		_range(z["police"], 0, PCT_MAX, at + ".police", errs)
		_range(z["flow"], 0, PCT_MAX * 10, at + ".flow", errs)
		_range(z["people"], 0, PCT_MAX, at + ".people", errs)
		for i in z["slots"].size():
			var sl: Dictionary = z["slots"][i]
			var sat := "%s.slots[%d]" % [at, i]
			if sl["org"] != "" and not orgs.has(sl["org"]):
				errs.append("%s.org — 판에 없는 조직 %s" % [sat, sl["org"]])
			if not t["trades"].has(sl["kind"]):
				errs.append("%s.kind — 모르는 업종 %s" % [sat, sl["kind"]])
			_range(sl["lv"], 1 if sl["org"] != "" else 0, MAX_LV, sat + ".lv", errs)
			_range(sl["dmg"], 0, PCT_MAX, sat + ".dmg", errs)
	var stakes: Dictionary = s["castle"]["stakes"]
	if not stakes.is_empty():
		var sum := 0
		for k in sorted_keys(stakes):
			sum += int(stakes[k])
			if int(stakes[k]) < 0 or not orgs.has(k):
				errs.append("castle.stakes.%s — 음수이거나 판에 없는 조직" % k)
		if sum != PCT_MAX:
			errs.append("castle.stakes — 합 %d (바란 값 %d)" % [sum, PCT_MAX])
	return errs


## 그 조직의 간부 id(정렬). active_only 면 지금 움직일 수 있는(status active) 간부만
static func officers_of(s: Dictionary, org: String, active_only: bool = true) -> Array:
	var out := []
	for id in sorted_keys(s["officers"]):
		var p: Dictionary = s["officers"][id]
		if p["org"] == org and (not active_only or p["status"] == "active"):
			out.append(id)
	return out


static func sorted_keys(d: Dictionary) -> Array:
	var k := d.keys()
	k.sort()
	return k


static func _range(v, lo: int, hi: int, at: String, errs: Array) -> void:
	if typeof(v) != TYPE_INT or v < lo or v > hi:
		errs.append("%s — 범위 %d~%d 밖: %s" % [at, lo, hi, v])


static func _need(d: Dictionary, keys: Array, at: String, errs: Array) -> void:
	for k in keys:
		if not d.has(k):
			errs.append("%s.%s — 칸이 없다" % [at, k])


## JSON 실수 → 정수(깊이). 정수 꼴이 아니면 오류에 적고 그대로 둔다
static func _ints(v, errs: Array, at: String):
	if v is float:
		if v == floorf(v) and absf(v) < 9.0e15:
			return int(v)
		errs.append("%s — 정수가 아니다: %s" % [at, v])
		return v
	if v is Array:
		var out := []
		for i in v.size():
			out.append(_ints(v[i], errs, "%s[%d]" % [at, i]))
		return out
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _ints(v[k], errs, "%s.%s" % [at, k])
		return out
	return v
