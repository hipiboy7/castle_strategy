extends RefCounted
## 명령 처리기 raid(충돌 단계 · 습격) — 검사만 한다(상태를 바꾸지 않음). 전투는 sim/combat.gd run_phase 가 (구역 → 조직) 순으로 묶어 돌린다.
## 처리기 꼴(LSP): apply(s, o, ctx) -> 까닭("" = 받을 수 있음). to = 들어갈 구역(우리 구역이 아님 · 간부가 서 있는 구역의 땅길 이웃이거나 그 구역).
## 싸우지 않는 사람(명단 noncombat — castle_common 92차 · C4 FR-409)은 나서지 못한다.
## args.cards = 작전 카드(data/game/combat.json attack_cards · 최대 max_cards · 겹치지 않음). 우회로는 그 구역 정보 2 이상(08 4-1).
## 등록: sim/orders.gd KINDS · 설계: docs/C3_설계서_습격과일기토.md 2절 · 요구: FR-301 · FR-302 · 시험: tests/unit/test_combat.gd

const Tables = preload("res://sim/tables.gd")


static func apply(s: Dictionary, o: Dictionary, ctx: Dictionary) -> String:
	var t: Dictionary = ctx["t"]
	var p: Dictionary = s["officers"][o["by"]]
	var to: String = o["to"]
	if not s["zones"].has(to):
		return "판에 없는 구역 %s" % to
	if Tables.noncombat(t, String(s.get("scenario", "")), o["by"]):
		return "싸우지 않는 사람이다(명단 noncombat)"
	if s["zones"][to]["owner"] == o["org"]:
		return "이미 우리 구역이다"
	if p["zone"] != to and not Tables.neighbors(t, p["zone"]).has(to):
		return "%s → %s 땅길이 없다" % [p["zone"], to]
	var cards = o["args"].get("cards", [])
	if not (cards is Array):
		return "cards 는 목록이다"
	if cards.size() > int(t["combat"]["raid"]["max_cards"]):
		return "작전 카드는 %d장까지" % int(t["combat"]["raid"]["max_cards"])
	var seen := {}
	for c in cards:
		if not t["combat"]["attack_cards"].has(c):
			return "습격에 못 쓰는 카드 %s" % c
		if seen.has(c):
			return "같은 카드를 두 번 %s" % c
		seen[c] = true
	if cards.has("bypass") and int(s["orgs"][o["org"]]["intel"].get(to, 0)) < int(t["combat"]["cards"]["bypass"]["intel"]):
		return "우회로 — 그 구역 정보 %d 이상 필요" % int(t["combat"]["cards"]["bypass"]["intel"])
	return ""
