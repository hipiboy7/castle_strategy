extends "res://tests/helpers.gd"
## FR-309 · FR-310 — 보기(ui/view.gd)의 C3 글: 습격 · 지키기 명령 글 · 고르기 줄 · 보고 전투 카드(battle_lines) · 승패 카드 · 전투 재생 장면(battle_frames).

const View = preload("res://ui/view.gd")
const Game = preload("res://sim/game.gd")
const Orders = preload("res://sim/orders.gd")
const Combat = preload("res://sim/combat.gd")
const Pcg32 = preload("res://sim/rng.gd")
const DataFiles = preload("res://src/data_files.gd")

var _tables := {}


func _t() -> Dictionary:
	if _tables.is_empty():
		_tables = DataFiles.load_tables()
	return _tables


func test_order_and_option_text() -> void:
	var t := _t()
	eq(View.order_text(t, Orders.make("bujinpa", "kimshin", "raid", "bukgu", {"cards": ["surprise", "charge"]})),
		"김신 · 습격 → %s (기습 · 정면 돌파)" % View.zone_name(t, "bukgu"), "습격 글")
	eq(View.order_text(t, Orders.make("bujinpa", "kimshin", "defend", "bujindong", {"card": "ambush"})),
		"김신 · 지키기 — %s (매복)" % View.zone_name(t, "bujindong"), "지키기 글")
	var opt := {"kind": "raid", "ok": true, "why": "", "cost": 0, "gain": 0, "later": true,
		"order": Orders.make("bujinpa", "kimshin", "raid", "bukgu", {"cards": []})}
	eq(View.option_text(opt), "습격 · 카드 없음 — 결과는 주 끝 보고", "습격 줄")
	opt["ok"] = false
	opt["why"] = "이미 우리 구역이다"
	eq(View.option_text(opt), "습격 · 카드 없음 — 안 됨: 이미 우리 구역이다", "안 되는 습격 줄")


func test_battle_lines_frames_and_outcome() -> void:
	var t := _t()
	var g: Dictionary = Game.new_game(t, "A", 1)
	var s: Dictionary = g["state"]
	var rec := Combat.raid(s, t, 1, "bukgu", "bujinpa", ["kimshin", "jintae"], ["surprise"], [], Pcg32.new().init_stream(1, 1, "clash", "v"))
	var lines := View.battle_lines(rec, t, "bujinpa")
	check(lines[0].ends_with("차지함 (기습)") or lines[0].ends_with("막힘 (기습)"), "첫 줄 — 결과 · 카드: %s" % lines[0])
	check(lines[1].begins_with("   입구 "), "구간 줄: %s" % lines[1])
	check(lines.any(func(l): return l.begins_with("   일기토 ")), "일기토 줄")
	var frames := View.battle_frames(rec, t)
	eq(frames[0]["text"], "입구 — 들어감", "첫 장면")
	eq(frames[-1]["sec"], -1, "끝 장면")
	check(frames.any(func(f): return not f["duel"].is_empty()), "일기토 장면(체력 · 카드)")
	for f in frames:
		check(f.has("att") and f.has("def") and f.has("text"), "장면 꼴")
	var many := {"zone": "bukgu", "att": "bujinpa", "def": "dssecurity", "won": false, "sections": [
		{"i": 0, "result": "def", "ticks": 30, "start": [10, 10], "end": [5, 5], "morale": [50, 50], "duels": [],
			"log": range(30).map(func(k): return [10, 10, 100, 100])}]}
	var fr := View.battle_frames(many, t, 12)
	check(fr.size() <= 1 + 12 + 1 + 1 + 1, "틱 장면은 구간마다 12개 안팎으로 줄인다(%d)" % fr.size())
	for z in s["zones"]:
		s["zones"][z]["owner"] = "bujinpa"
	var r: Dictionary = Game.step(g, t, [])
	var cards := View.report_cards(g["reports"][-1], t, "bujinpa")
	eq(cards[0]["kind"], "outcome", "승패 카드가 맨 앞")
	eq(cards[0]["title"], "승리 — %s" % View.org_name(t, "bujinpa"), "승리 제목")
	check(View.top(g["state"], t, "bujinpa", 0, 0)["week"].contains("승리(1주)"), "위 막대에 승패")
	eq(r["battles"], [], "명령이 없으면 전투 없음")
