extends RefCounted
## 명령 처리기 expand(경영 단계 · 확장) — 간부가 있는 구역의 자기 사업장 레벨을 하나 올린다(최대 3).
## 칸: args.slot 이 있으면 그 칸, 없으면 가장 낮은 레벨(같으면 앞 칸). 비용 = BASE × expand_cost_k × 오를 레벨.
## 처리기 꼴(LSP): apply(s, o, ctx) -> 까닭. 등록: sim/orders.gd KINDS · 시험: tests/unit/test_orders.gd

const Economy = preload("res://sim/economy.gd")
const State = preload("res://sim/state.gd")


static func apply(s: Dictionary, o: Dictionary, ctx: Dictionary) -> String:
	var zid: String = s["officers"][o["by"]]["zone"]
	var z: Dictionary = s["zones"].get(zid, {})
	var slots: Array = z.get("slots", [])
	var pick := -1
	if o["args"].has("slot"):
		var i := int(o["args"]["slot"])
		if i >= 0 and i < slots.size() and slots[i]["org"] == o["org"] and slots[i]["lv"] < State.MAX_LV:
			pick = i
	else:
		for i in slots.size():
			if slots[i]["org"] == o["org"] and slots[i]["lv"] < State.MAX_LV and (pick < 0 or slots[i]["lv"] < slots[pick]["lv"]):
				pick = i
	if pick < 0:
		return "올릴 자기 사업장이 없다(%s)" % zid
	var sl: Dictionary = slots[pick]
	var cost := Economy.expand_cost(ctx["t"]["economy"], sl["kind"], sl["lv"] + 1)
	var org: Dictionary = s["orgs"][o["org"]]
	if org["cash"] < cost:
		return "돈이 모자라다(%d < %d)" % [org["cash"], cost]
	org["cash"] -= cost
	sl["lv"] += 1
	return ""
