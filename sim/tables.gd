extends RefCounted
## 정적 표 — 받은 사본 · 3층 표의 JSON 값(src/data_files.gd 가 읽은 사전) → id 로 찾는 읽기 전용 표 + id 검사 오류 목록.
## 설계: docs/C1_설계서_상태와턴.md 1 · 5절 · 요구: FR-113 · 시험: tests/unit/test_tables.gd
## - 오류는 "파일:id — 까닭" 꼴로 t["errors"] 에 모은다(verify 는 받은 사본으로 0 인지 본다). 찍지 않는다(sim/).
## - 장르 팩(packs/strategy)과 3층 표(data/game)의 정수 꼴 수는 int 로 바꾼다(JSON 은 실수로 온다). 규칙 파일은 그대로 둔다(rules_common).
## - 조직 id 푸는 법(resolve)은 factions.json `resolve` 그대로: ① 조직이면 becomes[시나리오] ② 단위면 parent(문자열 또는 {시나리오, "*"}) ③ null = 무소속.
## - deprecated id 는 canon 의 replaced_by 를 따른다(current_id — 인물 · 조직 · 장소).

const RulesCommon = preload("res://sim/rules_common.gd")
const PACK := "common/packs/strategy/"
const CANON := "common/canon/"
const MAX_HOPS := 16
## 읽을 파일(res://data/ 아래) — src/data_files.gd read(NEEDS)
const NEEDS := [
	"common/ranks.json", "common/rules.json", "common/skills.json", "common/characters.json", "common/progression.json",
	"common/canon/characters.json", "common/canon/factions.json", "common/canon/locations.json",
	"common/packs/strategy/factions.json", "common/packs/strategy/districts.json",
	"common/packs/strategy/scenarios.json", "common/packs/strategy/characters.json",
	"game/game.json", "game/economy.json", "game/setup.json", "game/map.json", "game/combat.json",
	"game/fight.json", "game/fight_roles.json",
]
const GAME := ["game", "economy", "setup", "map", "combat", "fight", "fight_roles"]     # data/game/<이름>.json → t[이름] (정수로) · fight* = 실시간 구간 전투(C4)


static func build(files: Dictionary) -> Dictionary:
	var errors := []
	var t := {"errors": errors}
	var ranks_json = files.get("common/ranks.json")
	if not (ranks_json is Dictionary and ranks_json.get("ladder") is Array):
		errors.append("common/ranks.json:ladder — 파일이 없거나 사다리가 없다")
		ranks_json = {"ladder": []}
	t["ranks"] = Array(ranks_json["ladder"]).duplicate()
	t["below"] = String(ranks_json.get("below", ""))
	var rank_no := {}
	for i in t["ranks"].size():
		rank_no[t["ranks"][i]] = i
	t["rank_no"] = rank_no
	t["rules"] = RulesCommon.from_files(files)
	t["chars"] = _by_id(_list(files, errors, "common/characters.json", "characters").duplicate(true))

	# canon — 있는 id 와 replaced_by
	var people := {}
	var names := {}                       # canon 인물 id → 이름(화면이 id 로 찾는다 — C2 FR-215)
	var replaced := {}
	var replaced_src := {}
	for f in [["characters.json", "characters"], ["factions.json", "factions"], ["locations.json", "locations"]]:
		var path: String = CANON + f[0]
		for e in _list(files, errors, path, f[1]):
			if f[1] == "characters":
				people[e["id"]] = true
				names[e["id"]] = String(e.get("name", e["id"]))
			if e.get("replaced_by") is String and e["replaced_by"] != "":
				replaced[e["id"]] = e["replaced_by"]
				replaced_src[e["id"]] = path
	t["people"] = people
	t["names"] = names
	t["replaced"] = replaced
	for k in replaced:
		var seen := {k: true}
		var cur: String = replaced[k]
		while replaced.has(cur):
			if seen.has(cur):
				errors.append("%s:%s — replaced_by 고리" % [replaced_src[k], k])
				break
			seen[cur] = true
			cur = replaced[cur]

	# 장르 팩
	var fpath := PACK + "factions.json"
	var fjson = files.get(fpath)
	t["trades"] = _ints(fjson.get("trades", [])) if fjson is Dictionary else []
	t["factions"] = _by_id(_ints(_list(files, errors, fpath, "factions")))
	t["units"] = _by_id(_ints(_list(files, errors, fpath, "units")))
	t["districts"] = _by_id(_ints(_list(files, errors, PACK + "districts.json", "districts")))
	t["scenarios"] = _by_id(_ints(_list(files, errors, PACK + "scenarios.json", "scenarios")))
	var strat := {}
	var tags := {}
	var spath := PACK + "characters.json"
	for c in _ints(_list(files, errors, spath, "characters")):
		strat[c["id"]] = c.get("stats", {})
		tags[c["id"]] = c.get("tags", [])
		if not people.has(current_id(t, c["id"])):
			errors.append("%s:%s — canon 인물에 없다" % [spath, c["id"]])
	t["strat"] = strat
	t["tags"] = tags
	for name in GAME:
		var g = files.get("game/%s.json" % name)
		if not (g is Dictionary):
			errors.append("game/%s.json:- — 파일이 없거나 사전이 아니다" % name)
			g = {}
		t[name] = _ints(g)
	var nb := {}
	for pair in t["map"].get("links", []):
		for i in 2:
			if not nb.has(pair[i]):
				nb[pair[i]] = []
			nb[pair[i]].append(pair[1 - i])
	for k in nb:
		nb[k].sort()
	t["neighbors"] = nb
	_check_pack(t, errors)
	_check_game(t, errors)
	_freeze(t)
	return t


## 장르 팩 id 검사 — 명단 · 배치 · 구역 주인 · 본거지 · 정예 · becomes · 단위 부모(빈 값 null 은 허용 — 팩 _about)
static func _check_pack(t: Dictionary, errors: Array) -> void:
	var is_org := func(v): return v == null or t["factions"].has(v) or t["units"].has(v)
	var is_rank := func(v): return v == null or t["rank_no"].has(v) or (v == t["below"] and v != "")
	var sp := PACK + "scenarios.json"
	for sid in sorted_keys(t["scenarios"]):
		var s: Dictionary = t["scenarios"][sid]
		var ids := {}
		for m in s.get("roster", []):
			var who := current_id(t, m["id"])
			ids[who] = true
			if not t["people"].has(who):
				errors.append("%s:%s/%s — canon 인물에 없다" % [sp, sid, m["id"]])
			if not is_org.call(m.get("faction")):
				errors.append("%s:%s/%s — 모르는 소속 %s" % [sp, sid, m["id"], m.get("faction")])
			if not is_rank.call(m.get("rank")):
				errors.append("%s:%s/%s — 모르는 등급 %s" % [sp, sid, m["id"], m.get("rank")])
		for a in s.get("assign", []):
			if not ids.has(current_id(t, a["id"])):
				errors.append("%s:%s/assign/%s — 명단에 없다" % [sp, sid, a["id"]])
			if not t["factions"].has(a.get("faction")):
				errors.append("%s:%s/assign/%s — 모르는 조직 %s" % [sp, sid, a["id"], a.get("faction")])
		for p in s.get("playable", []):
			if not t["factions"].has(p):
				errors.append("%s:%s/playable — 모르는 조직 %s" % [sp, sid, p])
	var dp := PACK + "districts.json"
	for did in sorted_keys(t["districts"]):
		var d: Dictionary = t["districts"][did]
		for k in sorted_keys(d.get("owners", {})):
			if not is_org.call(d["owners"][k]):
				errors.append("%s:%s — %s 주인 %s 모름" % [dp, did, k, d["owners"][k]])
		for tr in d.get("trades", []):
			if not t["trades"].has(tr):
				errors.append("%s:%s — 모르는 업종 %s" % [dp, did, tr])
	var fp := PACK + "factions.json"
	for fid in sorted_keys(t["factions"]):
		var f: Dictionary = t["factions"][fid]
		for k in sorted_keys(f.get("hq", {})):
			if f["hq"][k] != null and not t["districts"].has(f["hq"][k]):
				errors.append("%s:%s — %s 본거지 %s 모름" % [fp, fid, k, f["hq"][k]])
		if f.get("boss") != null and not t["people"].has(current_id(t, f["boss"])):
			errors.append("%s:%s — 두목 %s 가 canon 에 없다" % [fp, fid, f["boss"]])
		for a in f.get("aces", []):
			if not t["people"].has(current_id(t, a)):
				errors.append("%s:%s — 대표 간부 %s 가 canon 에 없다" % [fp, fid, a])
		if f.get("trade") != null and not t["trades"].has(f["trade"]):
			errors.append("%s:%s — 모르는 업종 %s" % [fp, fid, f["trade"]])
		var el = f.get("elite")
		if el is Dictionary and el.get("unit") != null and not t["units"].has(el["unit"]):
			errors.append("%s:%s — 정예 단위 %s 모름" % [fp, fid, el["unit"]])
		var bec = f.get("becomes", {})
		for k in sorted_keys(bec if bec is Dictionary else {}):
			if bec[k] != null and not t["factions"].has(bec[k]):
				errors.append("%s:%s — becomes %s → %s 모름" % [fp, fid, k, bec[k]])
	for uid in sorted_keys(t["units"]):
		var p = t["units"][uid].get("parent")
		for v in (p.values() if p is Dictionary else [p]):
			if not is_org.call(v):
				errors.append("%s:%s — 부모 %s 모름" % [fp, uid, v])


## 3층 표 검사 — 지도 구역 · 길 끝 · 경제 업종 · 시작값의 조직 · 구역이 표에 있다
static func _check_game(t: Dictionary, errors: Array) -> void:
	var mz: Dictionary = t["map"].get("zones", {})
	for z in sorted_keys(mz):
		if not t["districts"].has(z):
			errors.append("game/map.json:%s — 모르는 구역" % z)
	for key in ["links", "sea"]:
		for pair in t["map"].get(key, []):
			for z in pair:
				if not mz.has(z):
					errors.append("game/map.json:%s/%s — 길 끝이 지도 구역에 없다" % [key, z])
	for kind in sorted_keys(t["economy"].get("base", {})):
		if not t["trades"].has(kind):
			errors.append("game/economy.json:base/%s — 모르는 업종" % kind)
	var cards: Dictionary = t["combat"].get("cards", {})
	for key in ["attack_cards", "defend_cards"]:
		for c in t["combat"].get(key, []):
			if not cards.has(c):
				errors.append("game/combat.json:%s/%s — 모르는 작전 카드" % [key, c])
	for sid in sorted_keys(t["game"].get("goals", {})):
		if not t["scenarios"].has(sid):
			errors.append("game/game.json:goals/%s — 모르는 시나리오" % sid)
	var sc: Dictionary = t["setup"].get("scenarios", {})
	for sid in sorted_keys(sc):
		if not t["scenarios"].has(sid):
			errors.append("game/setup.json:%s — 모르는 시나리오" % sid)
		for org in sorted_keys(sc[sid].get("orgs", {})):
			if not t["factions"].has(org):
				errors.append("game/setup.json:%s/orgs/%s — 모르는 조직" % [sid, org])
		for z in sorted_keys(sc[sid].get("zones", {})):
			if not t["districts"].has(z):
				errors.append("game/setup.json:%s/zones/%s — 모르는 구역" % [sid, z])


## 땅길 이웃(id 순 — data/game/map.json links)
static func neighbors(t: Dictionary, zone: String) -> Array:
	return t["neighbors"].get(zone, [])


## replaced_by 를 끝까지 따라간 id(고리면 MAX_HOPS 에서 멈춘다)
static func current_id(t: Dictionary, id: String) -> String:
	var cur := id
	for i in MAX_HOPS:
		if not t["replaced"].has(cur):
			return cur
		cur = t["replaced"][cur]
	return cur


## 명단 · 구역 주인의 조직 id → 이 시나리오의 판 조직 id("" = 무소속)
static func resolve(t: Dictionary, id, scenario: String) -> String:
	var cur = id
	for i in MAX_HOPS:
		if cur == null or cur == "":
			return ""
		cur = current_id(t, cur)
		if t["factions"].has(cur):
			var bec = t["factions"][cur].get("becomes", {})
			if bec is Dictionary and bec.has(scenario) and bec[scenario] != cur:
				cur = bec[scenario]
				continue
			return cur
		if not t["units"].has(cur):
			return ""
		var p = t["units"][cur].get("parent")
		if p is Dictionary:
			p = p[scenario] if p.has(scenario) else p.get("*")
		cur = p
	return ""


## 조직의 이 시나리오 본거지 구역("" = 없음)
static func hq_of(t: Dictionary, org: String, scenario: String) -> String:
	if not t["factions"].has(org):
		return ""
	var hq: Dictionary = t["factions"][org].get("hq", {})
	var v = hq[scenario] if hq.has(scenario) else hq.get("default")
	return String(v) if v != null else ""


## 이 시나리오에 있는 구역(owners 에 키가 있는 것) — id 순
static func districts_in(t: Dictionary, scenario: String) -> Array:
	var out := []
	for did in sorted_keys(t["districts"]):
		if t["districts"][did].get("owners", {}).has(scenario):
			out.append(did)
	return out


static func sorted_keys(d: Dictionary) -> Array:
	var k := d.keys()
	k.sort()
	return k


static func _list(files: Dictionary, errors: Array, path: String, key: String) -> Array:
	var d = files.get(path)
	if d == null:
		errors.append("%s:- — 파일이 없다" % path)
		return []
	if not (d is Dictionary and d.get(key) is Array):
		errors.append("%s:%s — 칸이 없거나 목록이 아니다" % [path, key])
		return []
	return d[key]


static func _by_id(a: Array) -> Dictionary:
	var out := {}
	for e in a:
		if e is Dictionary and e.has("id"):
			out[e["id"]] = e
	return out


## 정수 꼴 실수 → int (깊이). 새 값을 돌려준다
static func _ints(v):
	if v is float and v == floorf(v) and absf(v) < 9.0e15:
		return int(v)
	if v is Array:
		var out := []
		for x in v:
			out.append(_ints(x))
		return out
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _ints(v[k])
		return out
	return v


static func _freeze(v) -> void:
	if v is Dictionary:
		for k in v:
			_freeze(v[k])
		v.make_read_only()
	elif v is Array:
		for x in v:
			_freeze(x)
		v.make_read_only()
