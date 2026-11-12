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


## T-6 — 싸움이 있던 주는 전투 카드가 앞(목표 다음) · 목표 카드에 차지한 수 · 남은 곳 · 조용한 주는 전투 카드가 맨 끝
func test_report_order_battle_first() -> void:
	var t := _t()
	var g: Dictionary = Game.new_game(t, "A", 1)
	const Draft = preload("res://sim/draft.gd")
	Game.step_player(g, t, Draft.auto(g["state"], t))
	var e: Dictionary = g["reports"][-1]
	check(not e["report"]["battles"].is_empty(), "1주 맡기기에 습격이 있다")
	var cards := View.report_cards(e, t, "bujinpa")
	eq(cards.map(func(c): return c["kind"]), ["goal", "battle", "money", "orders", "intel"], "목표 · 전투가 앞")
	eq(cards[0]["title"], "목표 — 판의 구역 모두 차지 2 / 4", "목표 수")
	check(cards[0]["lines"][0].begins_with("남은 곳: ") and cards[0]["lines"][0].contains(View.zone_name(t, "bukgu")), "남은 곳: %s" % cards[0]["lines"][0])
	check(not cards[0]["lines"][0].contains(View.zone_name(t, "hoeamsijang")), "차지한 곳은 남은 곳에 없다")
	var quiet := {"report": {"turn": 1, "applied": [], "rejected": [], "events": [], "money": {}, "battles": []},
		"before": g["state"], "after": g["state"]}
	eq(View.report_cards(quiet, t, "bujinpa").map(func(c): return c["kind"]), ["goal", "money", "orders", "intel", "battle"], "조용한 주는 전투가 끝")
	eq(View.goal_card({"scenario": "Z", "zones": {}, "flags": {}}, t, "bujinpa"), {}, "목표 없는 시나리오는 카드 없음")


## C4-2 FR-420 — 실시간으로 끝낸 구간: 구간 줄에 '직접' · '자동' · 요약 줄(걸린 시간 · 쓰러뜨림 — 내 쪽 먼저) · 버린 결과 줄 · 재생 첫 장면 표시
func test_realtime_marks() -> void:
	var t := _t()
	var rec := {"zone": "bukgu", "att": "bujinpa", "def": "dssecurity", "won": true, "cards": [], "notes": [], "loss": {}, "down": [],
		"captive": [], "learned": [], "rejected": [{"i": 2, "why": "i 는 2"}], "sections": [
		{"i": 0, "result": "att", "ticks": 4, "start": [10, 8], "end": [9, 0], "morale": [100, 0], "duels": [], "log": [],
			"rt": "direct", "frames": 1260, "kills": [8, 1]},
		{"i": 1, "result": "att", "ticks": 2, "start": [9, 5], "end": [9, 0], "morale": [100, 0], "duels": [], "log": [],
			"rt": "auto", "frames": 600, "kills": [5, 0]},
		{"i": 2, "result": "att", "ticks": 3, "start": [9, 4], "end": [8, 0], "morale": [100, 0], "duels": [], "log": [[8, 0, 100, 0]]}]}
	var lines := View.battle_lines(rec, t, "bujinpa")
	eq(lines[1], "   입구 뚫음(직접) · 안 뚫음(자동) · 본진 뚫음 3틱", "구간 줄 표시")
	eq(lines[2], "   입구 직접 — 21초 · 쓰러뜨림 우리 8 · 적 1", "직접 요약")
	eq(lines[3], "   안 자동 — 10초 · 쓰러뜨림 우리 5 · 적 0", "자동 요약")
	check(lines.has("   본진 실시간 결과를 버림 — i 는 2(결과만으로 풂)"), "버린 결과 줄")
	var def_view := View.battle_lines(rec, t, "dssecurity")
	eq(def_view[2], "   입구 직접 — 21초 · 쓰러뜨림 우리 1 · 적 8", "지키는 쪽에서 보면 내 쪽 먼저")
	var frames := View.battle_frames(rec, t)
	eq(frames[0]["text"], "입구 — 들어감 — 직접", "재생 첫 장면에 직접 표시")
