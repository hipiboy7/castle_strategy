extends RefCounted
## 명령 처리기 move(이동 단계) — 간부를 땅길로 이웃한 구역에 옮긴다. 처리기 꼴(LSP): apply(s, o, ctx) -> 까닭("" = 적용함).
## 등록: sim/orders.gd KINDS · 설계: docs/C1_설계서_상태와턴.md 3-4 · 시험: tests/unit/test_orders.gd

const Tables = preload("res://sim/tables.gd")


static func apply(s: Dictionary, o: Dictionary, ctx: Dictionary) -> String:
	var p: Dictionary = s["officers"][o["by"]]
	var to: String = o["to"]
	if not s["zones"].has(to):
		return "판에 없는 구역 %s" % to
	if p["zone"] == to:
		return "이미 그 구역에 있다"
	if not Tables.neighbors(ctx["t"], p["zone"]).has(to):
		return "%s → %s 길이 없다" % [p["zone"], to]
	p["zone"] = to
	return ""
