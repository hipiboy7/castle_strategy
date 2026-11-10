extends RefCounted
## 명령 처리기 open(경영 단계 · 개업) — 간부가 있는 구역의 첫 빈칸을 lv1 사업장으로 연다. 자기 구역이나 주인 없는 구역만.
## 비용 = BASE[업종] × open_cost_k(data/game/economy.json). 돈이 모자라면 거절(쓰는 돈으로 음수가 되지 않는다).
## 처리기 꼴(LSP): apply(s, o, ctx) -> 까닭. 등록: sim/orders.gd KINDS · 시험: tests/unit/test_orders.gd

const Economy = preload("res://sim/economy.gd")


static func apply(s: Dictionary, o: Dictionary, ctx: Dictionary) -> String:
	var p: Dictionary = s["officers"][o["by"]]
	var zid: String = p["zone"]
	if o["to"] != "" and o["to"] != zid:
		return "간부가 %s 에 없다" % o["to"]
	var z: Dictionary = s["zones"].get(zid, {})
	if z.is_empty():
		return "판 밖에서는 열 수 없다"
	if z["owner"] != "" and z["owner"] != o["org"]:
		return "남의 구역 %s" % zid
	for sl in z["slots"]:
		if sl["org"] != "":
			continue
		var cost := Economy.open_cost(ctx["t"]["economy"], sl["kind"])
		var org: Dictionary = s["orgs"][o["org"]]
		if org["cash"] < cost:
			return "돈이 모자라다(%d < %d)" % [org["cash"], cost]
		org["cash"] -= cost
		sl["org"] = o["org"]
		sl["lv"] = 1
		return ""
	return "빈 칸이 없다"
