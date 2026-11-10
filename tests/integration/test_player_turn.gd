extends "res://tests/helpers.gd"
## C2 FR-205 · 207 · 213 — 플레이어 주(sim/game.gd step_player): 시나리오 A 를 맡기기 명령으로 5주 — 매 주 미리 보기가 실제 결과
## (내 간부 자리 · 사업장 · 받은 명령)와 같고, 불변식 위반 0 · 명령 기록에 플레이어 명령이 들어가 다시 돌리면 같은 해시 ·
## 보고 목록(전 · 뒤 상태)을 명령 기록에서 다시 만들 수 있다. 맡기기 대신 직접 낸 명령(이동 + 개업)도 같다.

const Game = preload("res://sim/game.gd")
const Draft = preload("res://sim/draft.gd")
const Orders = preload("res://sim/orders.gd")
const Save = preload("res://sim/save.gd")
const State = preload("res://sim/state.gd")
const DataFiles = preload("res://src/data_files.gd")

var _tables := {}


func _t() -> Dictionary:
	if _tables.is_empty():
		_tables = DataFiles.load_tables()
	return _tables


func _mine(s: Dictionary) -> Dictionary:
	var me: String = s["player"]
	var zones := {}
	for z in State.sorted_keys(s["zones"]):
		zones[z] = s["zones"][z]["slots"].map(func(x): return x["lv"] if x["org"] == me else 0)
	var at := {}
	for id in State.officers_of(s, me):
		at[id] = s["officers"][id]["zone"]
	return {"zones": zones, "at": at, "troops": s["orgs"][me]["troops"].duplicate()}


func test_five_player_weeks_preview_matches() -> void:
	var t := _t()
	var g: Dictionary = Game.new_game(t, "A", 1)
	for week in 5:
		var s: Dictionary = g["state"]
		var d: Array = Draft.auto(s, t)
		var p: Dictionary = Draft.preview(s, t, d)
		var rep: Dictionary = Game.step_player(g, t, d)
		eq(rep["violations"], [], "주 %d 불변식" % (week + 1))
		var mine_applied: Array = rep["applied"].filter(func(o): return o["org"] == s["player"])
		eq(mine_applied, p["applied"], "주 %d 받은 명령 = 미리 보기" % (week + 1))
		var me: String = s["player"]
		if rep["battles"].any(func(b): return b["att"] == me or b["def"] == me):
			continue                    # 싸움이 있던 주는 구역 · 조직원 · 간부 자리가 충돌 단계에서 바뀐다(미리 보기는 명령 단계까지 — C3 설계서 6절)
		var want := _mine(p["state"])
		var got := _mine(g["state"])
		eq(got["zones"], want["zones"], "주 %d 내 사업장 = 미리 보기" % (week + 1))
		eq(got["at"], want["at"], "주 %d 간부 자리 = 미리 보기" % (week + 1))
		eq(got["troops"], want["troops"], "주 %d 조직원 = 미리 보기(모집 갈래 난수 같음)" % (week + 1))
	eq(int(g["state"]["turn"]), 6, "6주째")
	eq(g["reports"].size(), 5, "보고 5")
	eq(g["reports"][4]["after"], g["state"], "마지막 보고 뒤 상태 = 지금")
	var again: Dictionary = Game.replay(t, "A", 1, "", g["log"])
	eq(State.hash_of(again["state"]), State.hash_of(g["state"]), "명령 기록을 다시 돌리면 같은 해시")
	var sv := Save.make({"seed": 1, "scenario": "A", "player": g["state"]["player"]}, g["state"], g["log"])
	var rb: Dictionary = Game.rebuild_reports(t, sv)
	check(rb["same"], "다시 만든 보고의 상태가 저장 상태와 같다")
	eq(rb["reports"].size(), 5, "보고 5 다시 만듦")
	eq(rb["reports"][2]["report"]["money"], g["reports"][2]["report"]["money"], "3주 보고 돈 같음")
	sv["state"]["orgs"][g["state"]["player"]]["cash"] += 1
	check(not Game.rebuild_reports(t, sv)["same"], "저장 상태가 다르면 알린다")


func test_hand_orders_move_and_open() -> void:
	var t := _t()
	var g: Dictionary = Game.new_game(t, "A", 1)
	var s: Dictionary = g["state"]
	var me: String = s["player"]
	var boss: String = s["orgs"][me]["boss"]
	var opts: Array = Draft.options(s, t, [], boss, "namgu")
	eq(opts.map(func(x): return x["kind"]).slice(0, 1), ["move"], "이웃 구역은 이동 먼저(주인 없는 구역이라 습격 줄도 있다)")
	var d: Array = Draft.add(s, t, [], opts[0]["order"])["draft"]
	var there: Array = Draft.options(s, t, d, boss, "namgu")
	var open: Dictionary = there.filter(func(x): return x["kind"] == "open")[0]
	check(open["ok"], "남구(주인 없음)에서 개업 됨 — %s" % open["why"])
	d = Draft.add(s, t, d, open["order"])["draft"]
	var others: Array = Game.others_ai(s, t, me)
	check(others.all(func(o): return o["org"] != me), "다른 조직 명령에 내 조직 없음")
	var rep: Dictionary = Game.step_player(g, t, d)
	eq(rep["violations"], [], "불변식")
	eq(g["state"]["officers"][boss]["zone"], "namgu", "두목이 남구로")
	check(g["state"]["zones"]["namgu"]["slots"].any(func(x): return x["org"] == me), "남구에 내 사업장")
	check(g["log"][0]["orders"].any(func(o): return o["src"] == "player"), "명령 기록에 플레이어 명령")
