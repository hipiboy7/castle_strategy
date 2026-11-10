extends RefCounted
## 읽기 전용 보기 — 순수 함수(상태 + 정적 표 → 사전 · 배열 · 글). 장면(ui/*.gd)은 이것을 그리기만 한다(CLAUDE.md 2절 ISP).
## 노드 · 텍스처 · 테마를 읽지 않고, 입력 상태를 바꾸지 않는다(커버리지 사본에서 돈다). 이름은 받은 데이터에서 id 로 찾는다.
## 돈 정수 1 = 1만 원(docs/기획_차이.md (나)15). 지도 노드의 '열기'는 구역 경찰 압력 3칸((나)17).
## 설계: docs/C2_설계서_화면과명령.md 4절 · 요구: FR-202 · 203 · 208 · 209 · 215 · 시험: tests/unit/test_view.gd

const State = preload("res://sim/state.gd")
const Economy = preload("res://sim/economy.gd")
const Tables = preload("res://sim/tables.gd")

## 화면 글 — id → 글(거점 · 명령 종류 · 자리 · 상태)
const FACILITY := {"hq": "본거지", "office": "사무실", "warehouse": "창고", "dojo": "수련장", "clinic": "의무실"}
const KIND := {"move": "이동", "open": "개업", "expand": "확장", "recruit": "모집", "rest": "쉼"}
const POST := {"boss": "두목", "staff": "참모", "zone_chief": "구역장", "captain": "조장", "guard": "경호", "": "간부"}
const STATUS := {"active": "움직임", "wounded": "다침", "captive": "잡힘", "dead": "죽음", "away": "판 밖"}
const POLICE_STEPS := [1000, 2000]          # 경찰 압력(×100) 10% · 20% 에서 칸이 는다
const SHOWN := ["active", "wounded", "captive"]   # 지도 · 카드에 보이는 간부 상태(판 밖 · 죽음은 안 보임)


## 돈 글 — '만 원' 단위 · 1억 이상은 억 + 만(쉼표)
static func money(n: int) -> String:
	var sign := "-" if n < 0 else ""
	var a := absi(n)
	var eok := a / 10000
	var man := a % 10000
	if eok == 0:
		return "%s%s만 원" % [sign, _comma(man)]
	if man == 0:
		return "%s%s억 원" % [sign, _comma(eok)]
	return "%s%s억 %s만 원" % [sign, _comma(eok), _comma(man)]


## 증감 글(+ · -)
static func delta(n: int) -> String:
	return ("+" if n > 0 else "") + money(n)


static func _comma(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


## 세력 글자 — 조직 이름 첫 글자(색만으로 구분하지 않음 — CLAUDE.md 4절 접근성). 주인 없음 "·"
static func mark(t: Dictionary, org: String) -> String:
	if org == "":
		return "·"
	var name := String(t["factions"].get(org, {}).get("name", ""))
	return (name if name != "" else org).left(1).to_upper()


static func org_name(t: Dictionary, org: String) -> String:
	if org == "":
		return "주인 없음"
	return String(t["factions"].get(org, {}).get("name", org))


static func person(t: Dictionary, id: String) -> String:
	return String(t.get("names", {}).get(id, id))


static func zone_name(t: Dictionary, z: String) -> String:
	return String(t["districts"].get(z, {}).get("name", z))


## 경찰 압력 칸 1~3
static func police_lv(p: int) -> int:
	var lv := 1
	for step in POLICE_STEPS:
		if p >= step:
			lv += 1
	return lv


static func _pct(v: int) -> String:
	return "%d%%" % int(round(v / 100.0))


## 위 막대 — 주 · 돈 · 주 순이익 예상 · 남은 행동 · 잠정 간부 수 · 끝났나
static func top(s: Dictionary, t: Dictionary, me: String, left: int, total: int) -> Dictionary:
	var length := int(s["length"])
	var over: bool = length > 0 and int(s["turn"]) > length
	var net := Economy.income_of(s, t, me) - Economy.upkeep_of(s, t, me)
	var prov := 0
	for id in State.sorted_keys(s["officers"]):
		if s["officers"][id]["rank_prov"]:
			prov += 1
	return {"week": ("끝 — %d주" % length) if over else "%d주 / %d" % [int(s["turn"]), length],
		"cash": money(int(s["orgs"][me]["cash"])), "net": delta(net) + " / 주", "actions": "행동 %d / %d" % [left, total],
		"left": left, "total": total, "prov": prov, "over": over}


## 지도 노드(구역 id 순) — {id, name, owner, mark, police_lv, mine[내 간부 id], others(남의 간부 수), slots_mine, slots_n}
static func map_nodes(s: Dictionary, t: Dictionary, me: String) -> Array:
	var out := []
	for zid in State.sorted_keys(s["zones"]):
		var z: Dictionary = s["zones"][zid]
		var mine := []
		var others := 0
		for id in State.sorted_keys(s["officers"]):
			var p: Dictionary = s["officers"][id]
			if p["zone"] != zid or not SHOWN.has(p["status"]):
				continue
			if p["org"] == me:
				mine.append(id)
			else:
				others += 1
		out.append({"id": zid, "name": zone_name(t, zid), "owner": z["owner"], "mark": mark(t, z["owner"]),
			"police_lv": police_lv(int(z["police"])), "mine": mine, "others": others,
			"slots_mine": z["slots"].filter(func(x): return x["org"] == me).size(), "slots_n": z["slots"].size()})
	return out


## 전선 — 주인이 서로 다른(둘 다 있음) 땅길 이웃 쌍(정렬)
static func fronts(s: Dictionary, t: Dictionary) -> Array:
	var out := []
	for a in State.sorted_keys(s["zones"]):
		var oa: String = s["zones"][a]["owner"]
		if oa == "":
			continue
		for b in Tables.neighbors(t, a):
			if b <= a or not s["zones"].has(b):
				continue
			var ob: String = s["zones"][b]["owner"]
			if ob != "" and ob != oa:
				out.append([a, b])
	return out


## 구역 카드 — 판에 없는 구역이면 {}
static func zone_card(s: Dictionary, t: Dictionary, zid: String, me: String) -> Dictionary:
	var z: Dictionary = s["zones"].get(zid, {})
	if z.is_empty():
		return {}
	var slots := []
	for sl in z["slots"]:
		slots.append({"kind": sl["kind"], "org": sl["org"], "org_name": org_name(t, sl["org"]) if sl["org"] != "" else "빈칸",
			"mark": mark(t, sl["org"]), "lv": sl["lv"], "mine": sl["org"] == me})
	var officers := []
	for id in State.sorted_keys(s["officers"]):
		var p: Dictionary = s["officers"][id]
		if p["zone"] == zid and SHOWN.has(p["status"]):
			officers.append({"id": id, "name": person(t, id), "org": p["org"], "mark": mark(t, p["org"]), "mine": p["org"] == me,
				"status": STATUS.get(p["status"], p["status"])})
	var d: Dictionary = t["districts"].get(zid, {})
	return {"id": zid, "name": zone_name(t, zid), "owner": z["owner"], "owner_name": org_name(t, z["owner"]), "mark": mark(t, z["owner"]),
		"slots": slots, "facilities": z["facilities"].map(func(f): return FACILITY.get(f, f)), "officers": officers,
		"flow": _pct(int(z["flow"])), "people": int(z["people"]), "police": _pct(int(z["police"])),
		"police_lv": police_lv(int(z["police"])), "income_me": Economy.zone_income(s, t, zid, me),
		"provisional": bool(d.get("provisional", false))}


## 간부 줄 — 내 조직의 움직일 수 있는 간부(id 순) · used = {간부 id: 대기 명령 수}
static func officer_cards(s: Dictionary, t: Dictionary, me: String, used: Dictionary) -> Array:
	var out := []
	var game: Dictionary = t["game"]
	for id in State.officers_of(s, me):
		var p: Dictionary = s["officers"][id]
		var boss: bool = s["orgs"][me]["boss"] == id
		var total := int(game["actions"]["boss"] if boss else game["actions"]["officer"])
		out.append({"id": id, "name": person(t, id), "zone": p["zone"], "zone_name": zone_name(t, p["zone"]), "rank": p["rank"],
			"prov": p["rank_prov"], "post": POST.get(p["post"], p["post"]), "boss": boss,
			"total": total, "left": maxi(0, total - int(used.get(id, 0)))})
	return out
