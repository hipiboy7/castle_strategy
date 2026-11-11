extends RefCounted
## 저장 형식 v1 — 사전 ↔ 글(정규형 JSON · 정수만). 파일 읽기 · 쓰기는 src/storage.gd 가 한다(sim/ 은 파일을 쓰지 않는다).
## {"format": "castle_strategy.save", "format_version": 1, "game_version", "castle_common", "seed", "scenario", "player", "mode", "turn",
##  "state": GameState v1(빈 사전이면 명령 기록을 다시 돌려 만든다 — sim/game.gd from_save), "orders": [{"turn", "orders": [명령]}],
##  "pending": [이번 주 대기 명령](C2 선택 칸 — 없으면 [] · 꼴이 틀린 것은 버리고 알림 · 형식 버전은 그대로 — C2 설계서 6절)}
## 불러오기: 깨짐 · 다른 형식 · 더 새 판은 오류(원본 파일은 부른 쪽이 그대로 둔다) → 옛 판은 MIGRATE 를 차례로 → replaced_by 로 id 옮기기.
## v0 = C1-0 빈 시뮬 저장({v, seed, turn, acc, last}) — 같은 시드의 새 판(A)으로 옮긴다.
## 설계: docs/C1_설계서_상태와턴.md 3-7 · 요구: FR-118 · FR-213 · 시험: tests/unit/test_save.gd · tests/integration/test_save_resume.gd

const State = preload("res://sim/state.gd")
const StateHash = preload("res://sim/hash.gd")
const Tables = preload("res://sim/tables.gd")
const Orders = preload("res://sim/orders.gd")
const FORMAT := "castle_strategy.save"
const FORMAT_VERSION := 1
const META := ["game_version", "castle_common", "seed", "scenario", "player", "mode"]
const MIGRATE := {0: "_v0_to_v1"}
const V0_KEYS := ["v", "seed", "turn", "acc", "last"]


static func make(meta: Dictionary, state: Dictionary, log: Array, pending: Array = []) -> Dictionary:
	var sv := {"format": FORMAT, "format_version": FORMAT_VERSION, "turn": int(state.get("turn", 1)),
		"state": State.to_dict(state), "orders": log.duplicate(true), "pending": pending.duplicate(true)}
	for k in META:
		sv[k] = meta.get(k, "" if k != "seed" else 0)
	return sv


static func to_text(sv: Dictionary) -> String:
	return StateHash.canonical(sv)


## {"save": 사전, "errors": [...], "notes": [옮긴 기록]}
static func from_text(text: String, t: Dictionary) -> Dictionary:
	var notes := []
	var j := JSON.new()
	if j.parse(text) != OK or not (j.data is Dictionary):
		return {"save": {}, "errors": ["깨진 저장 — JSON 사전이 아니다"], "notes": notes}
	var d: Dictionary = j.data
	var errs := []
	d = State.ints(d, errs, "save")
	if not errs.is_empty():
		return {"save": {}, "errors": errs, "notes": notes}
	var fv := -1
	if d.get("format") == FORMAT:
		fv = int(d.get("format_version", -1))
	elif not d.has("format") and V0_KEYS.all(func(k): return d.has(k)):
		fv = 0
	else:
		return {"save": {}, "errors": ["다른 형식의 글 — format %s" % d.get("format")], "notes": notes}
	if fv > FORMAT_VERSION:
		return {"save": {}, "errors": ["더 새 판의 저장(format_version %d · 이 판 %d) — 판을 올린다" % [fv, FORMAT_VERSION]], "notes": notes}
	while fv < FORMAT_VERSION:
		if not MIGRATE.has(fv):
			return {"save": {}, "errors": ["옮길 수 없는 옛 형식 %d" % fv], "notes": notes}
		d = load("res://sim/save.gd").call(MIGRATE[fv], d)
		notes.append("v%d → v%d 옮김" % [fv, fv + 1])
		fv += 1
	for k in META + ["state", "orders", "turn"]:
		if not d.has(k):
			errs.append("save.%s — 칸이 없다" % k)
	if not errs.is_empty():
		return {"save": {}, "errors": errs, "notes": notes}
	if not d["state"].is_empty():
		var r: Dictionary = State.from_dict(d["state"])
		if not r["errors"].is_empty():
			return {"save": {}, "errors": r["errors"], "notes": notes}
		d["state"] = r["state"]
	var raw = d.get("pending", [])
	var keep := []
	for o in (raw if raw is Array else []):
		if Orders.shape_error(o) == "":
			keep.append(o)
	var dropped: int = (raw.size() if raw is Array else 1) - keep.size()
	if dropped > 0:
		notes.append("대기 명령 %d개 버림(꼴이 틀림)" % dropped)
	d["pending"] = keep
	_rename(d, t, notes)
	return {"save": d, "errors": [], "notes": notes}


## C1-0 빈 시뮬 저장 → 같은 시드의 새 판(시나리오 A · 빈 상태 · 명령 없음)
static func _v0_to_v1(d: Dictionary) -> Dictionary:
	return {"format": FORMAT, "format_version": 1, "game_version": "0.1.0", "castle_common": "", "seed": int(d["seed"]),
		"scenario": "A", "player": "", "mode": "canon", "turn": 1, "state": {}, "orders": []}


## replaced_by 로 옛 id 를 옮긴다 — 상태의 키 · 참조, 명령 기록, player
static func _rename(d: Dictionary, t: Dictionary, notes: Array) -> void:
	var seen := {}
	var cur := func(id) -> String:
		var n := Tables.current_id(t, String(id))
		if n != String(id):
			seen[String(id)] = n
		return n
	d["player"] = cur.call(d["player"])
	var s: Dictionary = d["state"]
	if not s.is_empty():
		s["player"] = cur.call(s["player"])
		for group in ["orgs", "officers", "zones"]:
			var m := {}
			for k in s[group]:
				m[cur.call(k)] = s[group][k]
			s[group] = m
		for k in s["orgs"]:
			var o: Dictionary = s["orgs"][k]
			for f in ["boss", "hq", "vassal_of"]:
				o[f] = cur.call(o[f])
		for k in s["officers"]:
			var p: Dictionary = s["officers"][k]
			p["org"] = cur.call(p["org"])
			p["zone"] = cur.call(p["zone"])
		for k in s["zones"]:
			var z: Dictionary = s["zones"][k]
			z["owner"] = cur.call(z["owner"])
			for sl in z["slots"]:
				sl["org"] = cur.call(sl["org"])
	var lists: Array = d["orders"].map(func(e): return e.get("orders", []))
	lists.append(d.get("pending", []))
	for list in lists:
		for o in list:
			for f in ["org", "by", "to"]:
				if o.has(f):
					o[f] = cur.call(o[f])
	for k in State.sorted_keys(seen):
		notes.append("id 옮김 %s → %s" % [k, seen[k]])
