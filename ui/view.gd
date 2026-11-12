extends RefCounted
## 읽기 전용 보기 — 순수 함수(상태 + 정적 표 → 사전 · 배열 · 글). 장면(ui/*.gd)은 이것을 그리기만 한다(CLAUDE.md 2절 ISP).
## 노드 · 텍스처 · 테마를 읽지 않고, 입력 상태를 바꾸지 않는다(커버리지 사본에서 돈다). 이름은 받은 데이터에서 id 로 찾는다.
## 돈 정수 1 = 1만 원(docs/기획_차이.md (나)15). 지도 노드의 '열기'는 구역 경찰 압력 3칸((나)17).
## C3: 습격 · 지키기 글 · 보고 전투 카드(battle_lines) · 전투 화면 재생 장면(battle_frames) · 승패(top.result).
## 설계: docs/C2_설계서_화면과명령.md 4절 · docs/C3_설계서_습격과일기토.md 6절 · 요구: FR-202 · 203 · 208 · 209 · 215 · FR-309 · FR-310 · 시험: tests/unit/test_view.gd · test_view_battle.gd

const State = preload("res://sim/state.gd")
const Economy = preload("res://sim/economy.gd")
const Tables = preload("res://sim/tables.gd")

## 화면 글 — id → 글(거점 · 명령 종류 · 자리 · 상태)
const FACILITY := {"hq": "본거지", "office": "사무실", "warehouse": "창고", "dojo": "수련장", "clinic": "의무실"}
const KIND := {"move": "이동", "open": "개업", "expand": "확장", "recruit": "모집", "rest": "쉼", "raid": "습격", "defend": "지키기"}
const CARD := {"charge": "정면 돌파", "surprise": "기습", "decoy": "미끼", "bypass": "우회로", "shield": "방패조", "ambush": "매복"}
const SECTION := ["입구", "안", "본진"]
const RT := {"direct": "직접", "auto": "자동"}                # 실시간으로 끝낸 구간(C4-2 FR-420)
const DUEL_CARD := {"attack": "공격", "skill": "기술", "guard": "막기", "parry": "쳐내기", "stunned": "기절"}
const RESULT := {"win": "승리", "lose": "패배"}
const RESULT_WHY := {"hold_all": "판의 구역을 모두 차지했다", "boss": "두목이 잡히거나 죽었다", "zones": "구역을 모두 잃었다", "time": "판 길이 안에 목표를 이루지 못했다"}
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
	var res: String = String(s["flags"].get("result", ""))
	var week: String = ("끝 — %d주" % length) if over else "%d주 / %d" % [int(s["turn"]), length]
	if res != "":
		week += " · %s(%d주)" % [RESULT.get(res, res), int(s["flags"].get("result_turn", 0))]
	return {"week": week,
		"cash": money(int(s["orgs"][me]["cash"])), "net": delta(net) + " / 주", "actions": "행동 %d / %d" % [left, total],
		"left": left, "total": total, "prov": prov, "over": over, "result": res}


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
	var out: String = head + (" → " if o["kind"] == "move" or o["kind"] == "raid" else " — ") + zone_name(t, o["to"])
	var cards := _cards_of(o)
	return out + (" (%s)" % " · ".join(cards) if not cards.is_empty() else "")


## 명령의 작전 카드 이름(습격 args.cards · 지키기 args.card)
static func _cards_of(o: Dictionary) -> Array:
	var args: Dictionary = o.get("args", {})
	var ids: Array = args.get("cards", []) if args.get("cards") is Array else []
	if args.get("card") is String:
		ids = [args["card"]]
	return ids.map(func(c): return CARD.get(c, c))


## 명령 고르기 줄 — Draft.options 한 줄 → "개업 — 140만 원" · "모집 +7명 — 21만 원" · "확장 — 안 됨: 까닭"
static func option_text(opt: Dictionary) -> String:
	var name: String = KIND.get(opt["kind"], opt["kind"])
	var cards := _cards_of(opt.get("order", {}))
	if opt["kind"] == "raid":
		name += " · " + (" · ".join(cards) if not cards.is_empty() else "카드 없음")
	elif not cards.is_empty():
		name += " · " + " · ".join(cards)
	if opt.get("later", false) and opt["ok"]:
		return name + " — 결과는 주 끝 보고"
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
	var battles: Array = rep.get("battles", [])
	var blines := []
	for i in battles.size():
		blines.append_array(battle_lines(battles[i], t, me))
	if blines.is_empty():
		blines.append("이번 주 습격 · 전투 없음")
	var cards := []
	for ev in rep["events"]:
		if ev.get("kind") == "outcome":
			cards.append({"kind": "outcome", "title": "%s — %s" % [RESULT.get(ev["result"], ev["result"]), org_name(t, ev["org"])],
				"lines": [RESULT_WHY.get(ev["why"], ev["why"]), "판 길이까지 이어서 둘 수 있다"]})
	var goal := goal_card(a, t, me)
	if not goal.is_empty():
		cards.append(goal)
	# 싸움이 있던 주는 전투 카드를 앞에 — 맨 아래에 두면 폰에서 '전투 보기' 단추가 스크롤 밖으로 숨는다(폰 v0.3.0-rc.2 · 트러블슈팅 T-6)
	var battle := {"kind": "battle", "title": "전투 %d" % battles.size() if not battles.is_empty() else "전투", "lines": blines,
		"battles": battles.size()}
	if not battles.is_empty():
		cards.append(battle)
	cards.append_array([
		{"kind": "money", "title": "돈", "lines": money_lines},
		{"kind": "orders", "title": "내 명령 — 받음 %d · 거절 %d" % [mine_ok.size(), mine_no.size()], "lines": order_lines},
		{"kind": "intel", "title": "다른 조직", "lines": intel},
	])
	if battles.is_empty():
		cards.append(battle)
	return cards


## 목표 카드(아직 승패가 안 났을 때) — hold_all: "목표 — 판의 구역 모두 차지 3/4" · 남은 곳 · 어떻게. 목표가 없거나 승패가 났으면 {}
static func goal_card(s: Dictionary, t: Dictionary, me: String) -> Dictionary:
	var goal: Dictionary = t.get("game", {}).get("goals", {}).get(s.get("scenario", ""), {})
	if goal.get("kind", "") != "hold_all" or String(s.get("flags", {}).get("result", "")) != "":
		return {}
	var left := []
	for z in State.sorted_keys(s["zones"]):
		if s["zones"][z]["owner"] != me:
			left.append(zone_name(t, z))
	var n: int = s["zones"].size()
	return {"kind": "goal", "title": "목표 — 판의 구역 모두 차지 %d / %d" % [n - left.size(), n],
		"lines": ["남은 곳: " + " · ".join(left), "간부를 남은 구역에 놓아 습격하거나 '맡기기'(컴퓨터가 습격도 고른다) → 주 끝내기"]}


## 보고의 전투 한 줄 묶음 — "[부] 부진파 → [D] DS 씨큐리티 · 회암시장 — 차지함" · 구간 · 일기토 · 손실 · 다침 · 잡힘
static func battle_lines(rec: Dictionary, t: Dictionary, me: String) -> Array:
	var out := []
	var def_name: String = org_name(t, rec["def"]) if rec["def"] != "" else "주인 없음"
	var head := "[%s] %s → %s · %s — %s" % [mark(t, rec["att"]), org_name(t, rec["att"]), def_name, zone_name(t, rec["zone"]),
		"차지함" if rec["won"] else "막힘"]
	if not rec["cards"].is_empty():
		head += " (%s)" % " · ".join(rec["cards"].map(func(c): return CARD.get(c, c)))
	out.append(head)
	var secs := []
	var rts := []
	for sec in rec["sections"]:
		var r: String = {"att": "뚫음", "def": "막힘", "skip": "건너뜀"}.get(sec["result"], sec["result"])
		if sec.has("rt"):
			secs.append("%s %s(%s)" % [SECTION[int(sec["i"])], r, RT.get(sec["rt"], sec["rt"])])
			rts.append("   %s %s — %d초 · 쓰러뜨림 우리 %d · 적 %d" % [SECTION[int(sec["i"])], RT.get(sec["rt"], sec["rt"]), int(sec.get("frames", 0)) / 60,
				int(sec["kills"][0 if rec["att"] == me else 1]), int(sec["kills"][1 if rec["att"] == me else 0])])
			continue
		secs.append("%s %s%s" % [SECTION[int(sec["i"])], r, (" %d틱" % int(sec["ticks"])) if int(sec["ticks"]) > 0 else ""])
	if not secs.is_empty():
		out.append("   " + " · ".join(secs))
	out.append_array(rts)
	for rj in rec.get("rejected", []):
		out.append("   %s 실시간 결과를 버림 — %s(결과만으로 풂)" % [SECTION[int(rj["i"])], rj["why"]])
	for sec in rec["sections"]:
		for d in sec["duels"]:
			out.append("   일기토 %s — %s 이김(%d합%s)" % [_pair(t, d), person(t, d["winner"]), d["rounds"].size(), " · 한 방" if d["ko"] else ""])
	for n in rec["notes"]:
		out.append("   %s %s%s" % [CARD.get(n["card"], n["card"]), "됨" if n["ok"] else "안 됨", (" — " + person(t, n["who"])) if n["who"] != "" else ""])
	if not rec.get("reinforce", []).is_empty():
		out.append("   원군 — " + ", ".join(rec["reinforce"].map(func(id): return person(t, id))))
	for org in State.sorted_keys(rec["loss"]):
		var lost: Array = State.TROOP_GRADES.filter(func(g): return int(rec["loss"][org].get(g, 0)) > 0) \
			.map(func(g): return "%s %d" % [g, int(rec["loss"][org][g])])
		if not lost.is_empty():
			out.append("   [%s] 잃음 — %s" % [mark(t, org), " · ".join(lost)])
	if not rec["down"].is_empty():
		out.append("   다침 — " + ", ".join(rec["down"].map(func(id): return person(t, id))))
	if not rec["captive"].is_empty():
		out.append("   잡힘 — " + ", ".join(rec["captive"].map(func(id): return person(t, id))))
	for l in rec["learned"]:
		out.append("   %s 카피 — %s" % [person(t, l["id"]), skill_name(t, l["skill"])])
	return out


static func _pair(t: Dictionary, d: Dictionary) -> String:
	var w: int = int(d["w"])
	var a: String = d["winner"] if w == 0 else d["loser"]
	var b: String = d["loser"] if w == 0 else d["winner"]
	return "%s vs %s" % [person(t, a), person(t, b)]


## 전투 화면 재생 장면 — 기록 하나 → [{sec, tick, att, def, am, dm, text}] (아래 = 들어가는 쪽 · 위 = 지키는 쪽).
## 구간 시작 장면 · 일기토 합마다 · 틱마다 · 끝 장면. 장면 수가 많으면 틱을 고르게 건너뛴다(최대 max_ticks 장면 / 구간)
static func battle_frames(rec: Dictionary, t: Dictionary, max_ticks: int = 12) -> Array:
	var out := []
	for sec in rec["sections"]:
		var i := int(sec["i"])
		var st: Array = sec["start"]
		out.append({"sec": i, "tick": 0, "att": int(st[0]), "def": int(st[1]), "am": 100, "dm": 100, "duel": {},
			"text": "%s — %s" % [SECTION[i], "건너뜀(우회로)" if sec["result"] == "skip" else ("들어감 — %s" % RT[sec["rt"]] if RT.has(sec.get("rt", "")) else "들어감")]})
		for d in sec["duels"]:
			var w: int = int(d["w"])
			var ids := [d["winner"] if w == 0 else d["loser"], d["loser"] if w == 0 else d["winner"]]
			for k in d["rounds"].size():
				var rd: Dictionary = d["rounds"][k]
				out.append({"sec": i, "tick": 0, "att": int(st[0]), "def": int(st[1]), "am": 100, "dm": 100,
					"duel": {"a": ids[0], "b": ids[1], "a_name": person(t, ids[0]), "b_name": person(t, ids[1]),
						"hp": rd["hp"], "max": d["max"], "gauge": rd["gauge"],
						"cards": [_duel_card(t, rd["cards"][0]), _duel_card(t, rd["cards"][1])]},
					"text": "일기토 %d합 — %s %s / %s %s" % [k + 1, person(t, ids[0]), _duel_card(t, rd["cards"][0]),
						person(t, ids[1]), _duel_card(t, rd["cards"][1])]})
			out.append({"sec": i, "tick": 0, "att": int(st[0]), "def": int(st[1]), "am": 100, "dm": 100, "duel": {},
				"text": "일기토 — %s 이김%s" % [person(t, d["winner"]), " · 한 방" if d["ko"] else ""]})
		var log: Array = sec["log"]
		var step := maxi(1, _ceil_div(log.size(), max_ticks))
		for k in log.size():
			if k % step != 0 and k != log.size() - 1:
				continue
			var row: Array = log[k]
			out.append({"sec": i, "tick": k + 1, "att": int(row[0]), "def": int(row[1]), "am": int(row[2]), "dm": int(row[3]), "duel": {},
				"text": "%s %d틱 — 우리 %d · 적 %d" % [SECTION[i], k + 1, int(row[0]), int(row[1])]})
		if sec["result"] != "skip":
			var e: Array = sec.get("end", st)
			out.append({"sec": i, "tick": int(sec["ticks"]), "att": int(e[0]), "def": int(e[1]),
				"am": int(sec.get("morale", [100, 100])[0]), "dm": int(sec.get("morale", [100, 100])[1]), "duel": {},
				"text": "%s %s" % [SECTION[i], "뚫음" if sec["result"] == "att" else "막힘"]})
	out.append({"sec": -1, "tick": 0, "att": 0, "def": 0, "am": 0, "dm": 0, "duel": {},
		"text": "%s — %s" % [zone_name(t, rec["zone"]), "차지함" if rec["won"] else "막힘"]})
	return out


static func _duel_card(t: Dictionary, c: Dictionary) -> String:
	var n: String = DUEL_CARD.get(c["card"], c["card"])
	return n + ("(%s)" % skill_name(t, c["skill"]) if c["skill"] != "" else "")


## 기술 이름(skills.json name — 없으면 id)
static func skill_name(t: Dictionary, id: String) -> String:
	return String(t["rules"].skill_info(id).get("name", id))


static func _ceil_div(a: int, d: int) -> int:
	return (a + d - 1) / d


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
