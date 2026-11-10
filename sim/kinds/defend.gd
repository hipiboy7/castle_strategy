extends RefCounted
## 명령 처리기 defend(충돌 단계 · 지키기) — 검사만 한다. 이번 주 그 구역이 습격받으면 지키는 쪽 작전 카드(args.card)를 쓴다(sim/combat.gd).
## 처리기 꼴(LSP): apply(s, o, ctx) -> 까닭. to = 간부가 서 있는 우리 구역 · card = data/game/combat.json defend_cards(매복 · 방패조).
## 등록: sim/orders.gd KINDS · 설계: docs/C3_설계서_습격과일기토.md 2절 · 요구: FR-302 · 시험: tests/unit/test_combat.gd


static func apply(s: Dictionary, o: Dictionary, ctx: Dictionary) -> String:
	var t: Dictionary = ctx["t"]
	var p: Dictionary = s["officers"][o["by"]]
	if not s["zones"].has(o["to"]) or s["zones"][o["to"]]["owner"] != o["org"]:
		return "우리 구역에서만 지킨다"
	if p["zone"] != o["to"]:
		return "%s 는 그 구역에 없다" % o["by"]
	var c = o["args"].get("card", "")
	if not t["combat"]["defend_cards"].has(c):
		return "지키기에 못 쓰는 카드 %s" % str(c)
	return ""
