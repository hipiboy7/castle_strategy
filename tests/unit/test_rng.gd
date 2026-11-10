extends "res://tests/helpers.gd"
## FR-103 — sim/rng.gd 가 기준 구현(tools/rng_ref.py)과 같은 PCG32 수열 · 갈래 스트림 · 범위를 내는지.
## 설계: docs/C1_설계서_상태와턴.md 3-1. 기대값: tests/unit/rng_vectors.json

const Pcg32 = preload("res://sim/rng.gd")
const U32 := 4294967296


func test_vectors_present() -> void:
	var v := vectors()
	check(v.has("seeded") and v.has("streams") and v.has("below"), "기대값 파일이 없다 — python3 -B tools/rng_ref.py --write")


## 바깥 출처: pcg-c-basic pcg32-demo — pcg32_srandom_r(42, 54) 의 처음 여섯 수
func test_public_demo_sequence() -> void:
	var r = Pcg32.new().seed_with(0, 42, 0, 54)
	var got := []
	for i in 6:
		got.append(r.next_u32())
	eq(got, [0xA15C02B7, 0x7B47F409, 0xBA1D3330, 0x83D2F293, 0xBFA4784B, 0xCBED606E], "pcg32-demo 수열")


func test_seeded_matches_reference() -> void:
	for c in vectors().get("seeded", []):
		var r = Pcg32.new().seed_with(int(c["state"][0]), int(c["state"][1]), int(c["seq"][0]), int(c["seq"][1]))
		var got := []
		for i in c["out"].size():
			got.append(r.next_u32())
		eq(got, ints(c["out"]), "seed_with %s · %s" % [c["state"], c["seq"]])


func test_streams_match_reference() -> void:
	for c in vectors().get("streams", []):
		var r = Pcg32.new().init_stream(int(c["seed"]), int(c["turn"]), String(c["phase"]), String(c["target"]))
		var got := []
		for i in c["out"].size():
			got.append(r.next_u32())
		eq(got, ints(c["out"]), "stream %s|%s|%s|%s" % [c["seed"], c["turn"], c["phase"], c["target"]])


func test_below_matches_reference() -> void:
	for c in vectors().get("below", []):
		var r = Pcg32.new().init_stream(1, 1, "below", String(c["target"]))
		var got := []
		for i in c["out"].size():
			got.append(r.below(int(c["bound"])))
		eq(got, ints(c["out"]), "below %s" % c["bound"])


func test_values_stay_in_range() -> void:
	var r = Pcg32.new().init_stream(99, 3, "range", "x")
	var ok := true
	for i in 2000:
		var x: int = r.next_u32()
		var b: int = r.below(37)
		ok = ok and x >= 0 and x < U32 and b >= 0 and b < 37
	check(ok, "next_u32 는 [0, 2^32) · below(37) 은 [0, 37)")


func test_chance_bp_edges() -> void:
	var r = Pcg32.new().init_stream(5, 1, "chance", "x")
	var never := false
	var always := true
	for i in 200:
		never = never or r.chance_bp(0)
		always = always and r.chance_bp(10000)
	check(not never, "확률 0 은 한 번도 참이 아니다")
	check(always, "확률 10000(100%) 은 늘 참")


## 같은 입력 = 같은 수열 · 대상이 다르면 다른 수열(갈래가 서로 밀지 않는다 — 08 13절)
func test_streams_are_independent_and_repeatable() -> void:
	var a = Pcg32.new().init_stream(7, 2, "manage", "baekui")
	var b = Pcg32.new().init_stream(7, 2, "manage", "baekui")
	var c = Pcg32.new().init_stream(7, 2, "manage", "gold")
	var sa := []
	var sb := []
	var sc := []
	for i in 4:
		sa.append(a.next_u32())
		sb.append(b.next_u32())
		sc.append(c.next_u32())
	eq(sa, sb, "같은 갈래는 같은 수열")
	check(sa != sc, "다른 대상은 다른 수열")
