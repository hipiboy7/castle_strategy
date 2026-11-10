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


## 명령 글 — "김신 · 이동 → 회암시 남구" · "김신 · 개업 — 회암시 부진" · "김신 · 쉼"
static func order_text(t: Dictionary, o: Dictionary) -> String:
	var head := "%s · %s" % [person(t, o["by"]), KIND.get(o["kind"], o["kind"])]
	if o["kind"] == "rest" or o["to"] == "":
		return head
	return head + (" → " if o["kind"] == "move" else " — ") + zone_name(t, o["to"])


## 명령 고르기 줄 — Draft.options 한 줄 → "개업 — 140만 원" · "모집 +7명 — 21만 원" · "확장 — 안 됨: 까닭"
static func option_text(opt: Dictionary) -> String:
	var name: String = KIND.get(opt["kind"], opt["kind"])
	if not opt["ok"]:
		return "%s — 안 됨: %s" % [name, opt["why"]]
	if int(opt["gain"]) > 0:
		name += " +%d명" % int(opt["gain"])
	return name if int(opt["cost"]) == 0 else "%s — %s" % [name, money(int(opt["cost"]))]


## 턴 끝 보고 카드 — entry = {report, before, after}(sim/game.gd g.reports 한 줄) → [{kind, title, lines}]: 돈 · 내 명령 · 다른 조직 · 전투
static func report_cards(entry: Dictionary, t: Dictionary, me: String) -> Array:
	var rep: Dictionary = entry["report"]
	var b: Dictionary = entry["before"]
	var a: Dictionary = entry["after"]
	var m: Dictionary = rep["money"].get(me, {"income": 0, "upkeep": 0})
	var cash_b := int(b["orgs"][me]["cash"])
	var cash_a := int(a["orgs"][me]["cash"])
	var money_lines := ["수입 %s · 지출 %s" % [delta(int(m["income"])), money(-int(m["upkeep"]))]]
	var spent := cash_b + int(m["income"]) - int(m["upkeep"]) - cash_a
	if spent != 0:
		money_lines.append("명령에 쓴 돈 %s" % money(spent))
	money_lines.append("남은 돈 %s (이번 주 %s)" % [money(cash_a), delta(cash_a - cash_b)])
	var intel := []
	for ev in rep["events"]:
		if ev.get("kind") == "leave":
			var lost: Array = State.TROOP_GRADES.filter(func(g): return int(ev["lost"].get(g, 0)) > 0) \
				.map(func(g): return "%s %d" % [g, int(ev["lost"][g])])
			if ev["org"] == me:
				money_lines.append("돈이 0 밑 — 조직원이 떠났다(%s)" % " · ".join(lost))
			else:
				intel.append("[%s] %s · 조직원이 떠났다(%s)" % [mark(t, ev["org"]), org_name(t, ev["org"]), " · ".join(lost)])
	var mine_ok: Array = rep["applied"].filter(func(o): return o["org"] == me)
	var mine_no: Array = rep["rejected"].filter(func(r): return r["order"] is Dictionary and r["order"].get("org") == me)
	var order_lines := []
	for o in mine_ok:
		order_lines.append("○ " + order_text(t, o))
		for ev in rep["events"]:
			if ev.get("kind") == "recruit" and ev.get("by") == o["by"] and o["kind"] == "recruit":
				order_lines.append("   모집 +%d명" % int(ev["n"]))
	for r in mine_no:
		order_lines.append("× %s — %s" % [order_text(t, r["order"]), r["why"]])
	if order_lines.is_empty():
		order_lines.append("낸 명령 없음")
	intel = _moves(t, b, a, me) + intel
	if intel.is_empty():
		intel.append("눈에 띄는 움직임 없음")
	return [
		{"kind": "money", "title": "돈", "lines": money_lines},
		{"kind": "orders", "title": "내 명령 — 받음 %d · 거절 %d" % [mine_ok.size(), mine_no.size()], "lines": order_lines},
		{"kind": "intel", "title": "다른 조직", "lines": intel},
		{"kind": "battle", "title": "전투", "lines": ["이번 주 습격 · 전투 없음(습격은 C3)"]},
	]


## 다른 조직 움직임(전 · 뒤 상태 비교) — 개업 · 확장 · 구역 주인 바뀜 · 간부 이동
static func _moves(t: Dictionary, b: Dictionary, a: Dictionary, me: String) -> Array:
	var out := []
	for zid in State.sorted_keys(a["zones"]):
		var za: Dictionary = a["zones"][zid]
		var zb: Dictionary = b["zones"].get(zid, za)
		for i in za["slots"].size():
			var sa: Dictionary = za["slots"][i]
			var sb: Dictionary = zb["slots"][i] if i < zb["slots"].size() else {"org": "", "lv": 0}
			if sa["org"] == "" or sa["org"] == me:
				continue
			if sb["org"] != sa["org"]:
				out.append("[%s] %s · 개업 — %s(%s)" % [mark(t, sa["org"]), org_name(t, sa["org"]), zone_name(t, zid), sa["kind"]])
			elif int(sa["lv"]) > int(sb["lv"]):
				out.append("[%s] %s · 확장 — %s(%s lv%d)" % [mark(t, sa["org"]), org_name(t, sa["org"]), zone_name(t, zid), sa["kind"], int(sa["lv"])])
		if za["owner"] != zb["owner"]:
			out.append("%s 주인 바뀜 — %s → %s" % [zone_name(t, zid), org_name(t, zb["owner"]), org_name(t, za["owner"])])
	for id in State.sorted_keys(a["officers"]):
		var pa: Dictionary = a["officers"][id]
		var pb: Dictionary = b["officers"].get(id, pa)
		if pa["org"] != me and pa["zone"] != pb["zone"] and SHOWN.has(pa["status"]):
			out.append("[%s] %s 이동 — %s → %s" % [mark(t, pa["org"]), person(t, id), zone_name(t, pb["zone"]), zone_name(t, pa["zone"])])
	return out


## 기록 탭 한 줄 — "3주 — 돈 -110만 원 · 받음 1 · 거절 1"
static func report_title(entry: Dictionary, me: String) -> String:
	var rep: Dictionary = entry["report"]
	var d := int(entry["after"]["orgs"][me]["cash"]) - int(entry["before"]["orgs"][me]["cash"])
	var ok: int = rep["applied"].filter(func(o): return o["org"] == me).size()
	var no: int = rep["rejected"].filter(func(r): return r["order"] is Dictionary and r["order"].get("org") == me).size()
	return "%d주 — 돈 %s · 받음 %d · 거절 %d" % [int(rep["turn"]), delta(d), ok, no]


## 조직 탭 — 내 조직 돈 · 수입 · 지출 · 열기 · 명성 · 결속 · 조직원 · 간부 · 다른 조직 요약(구역 · 사업장 수)
static func org_panel(s: Dictionary, t: Dictionary, me: String) -> Dictionary:
	var o: Dictionary = s["orgs"][me]
	var inc := Economy.income_of(s, t, me)
	var up := Economy.upkeep_of(s, t, me)
	var officers := []
	for id in State.officers_of(s, me, false):
		var p: Dictionary = s["officers"][id]
		officers.append({"id": id, "name": person(t, id), "rank": p["rank"] + ("(잠정)" if p["rank_prov"] else ""),
			"post": "두목" if o["boss"] == id else POST.get(p["post"], p["post"]), "loyalty": _pct(int(p["loyalty"])),
			"status": STATUS.get(p["status"], p["status"]), "zone_name": zone_name(t, p["zone"]) if p["zone"] != "" else "—"})
	var others := []
	for org in State.sorted_keys(s["orgs"]):
		if org == me or not s["orgs"][org]["alive"]:
			continue
		var zones := 0
		var slots := 0
		for zid in State.sorted_keys(s["zones"]):
			var z: Dictionary = s["zones"][zid]
			zones += 1 if z["owner"] == org else 0
			slots += z["slots"].filter(func(x): return x["org"] == org).size()
		others.append({"org": org, "name": org_name(t, org), "mark": mark(t, org), "zones": zones, "slots": slots})
	return {"name": org_name(t, me), "mark": mark(t, me), "cash": money(int(o["cash"])), "income": money(inc), "upkeep": money(up),
		"net": delta(inc - up), "heat": _pct(int(o["heat"])), "fame": _pct(int(o["fame"])), "cohesion": _pct(int(o["cohesion"])),
		"troops": " · ".join(State.TROOP_GRADES.map(func(g): return "%s %d" % [g, int(o["troops"][g])])),
		"officers": officers, "others": others}
