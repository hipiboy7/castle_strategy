extends RefCounted
## 명령 처리기 recruit(경영 단계 · 모집) — 간부가 있는 자기 구역에서 건달급을 모은다.
## 머릿수 = 구역 사람 × per_people + 난수(0 ~ rand−1 · 갈래 스트림 시드 · 턴 · 단계 · 간부 id). 돈이 모자라면 살 수 있는 만큼만.
## 처리기 꼴(LSP): apply(s, o, ctx) -> 까닭. 등록: sim/orders.gd KINDS · 시험: tests/unit/test_orders.gd

const Pcg32 = preload("res://sim/rng.gd")
const Economy = preload("res://sim/economy.gd")


static func apply(s: Dictionary, o: Dictionary, ctx: Dictionary) -> String:
	var zid: String = s["officers"][o["by"]]["zone"]
	var z: Dictionary = s["zones"].get(zid, {})
	if z.is_empty() or z["owner"] != o["org"]:
		return "남의 구역에서는 모집하지 않는다(%s)" % zid
	var e: Dictionary = ctx["t"]["economy"]
	var rc: Dictionary = e["recruit"]
	var rng = Pcg32.new().init_stream(ctx["seed"], ctx["turn"], ctx["phase"], o["by"])
	var n: int = z["people"] * int(rc["per_people"]) + rng.below(maxi(1, int(rc["rand"])))
	var org: Dictionary = s["orgs"][o["org"]]
	n = mini(n, maxi(0, org["cash"]) / int(rc["cost"]))
	if n <= 0:
		return "돈이 모자라다"
	org["cash"] -= Economy.recruit_cost(e, n)
	org["troops"]["건달급"] += n
	ctx["report"]["events"].append({"kind": "recruit", "org": o["org"], "by": o["by"], "zone": zid, "n": n})
	return ""
