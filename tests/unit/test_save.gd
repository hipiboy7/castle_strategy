extends "res://tests/helpers.gd"
## FR-118 · FR-419(직렬화) — sim/save.gd: 저장 v2(v1 + 기록 줄 fights · pending_fights — C4-2) · v1(format · format_version · game_version · castle_common · seed · scenario · player · mode · turn ·
## state · orders[]) ↔ 글. 옛 형식 옮기기(v0 = C1-0 빈 시뮬 저장) · 더 새 판 거절 · 깨진 글 · id 옮기기(replaced_by). 설계서 3-7

const Save = preload("res://sim/save.gd")
const State = preload("res://sim/state.gd")
const Tables = preload("res://sim/tables.gd")
const Orders = preload("res://sim/orders.gd")
const Fixtures = preload("res://tests/fixtures.gd")


func _t() -> Dictionary:
	return Tables.build(Fixtures.files())


func _meta() -> Dictionary:
	return {"game_version": "0.2.0", "castle_common": "abc", "seed": 7, "scenario": "A", "player": "org_a", "mode": "canon"}


func _state() -> Dictionary:
	var s := State.new_state(7, "A", "org_a")
	s["orgs"]["org_a"] = State.new_org("boss_a", "z1")
	s["orgs"]["org_a"]["cash"] = -12
	s["officers"]["boss_a"] = State.new_officer("org_a", "z1", "네임드")
	s["zones"]["z1"] = State.new_zone("org_a")
	s["turn"] = 3
	return s


func _log() -> Array:
	return [{"turn": 1, "orders": [Orders.make("org_a", "boss_a", "rest")]}, {"turn": 2, "orders": []}]


func test_make_has_v1_fields() -> void:
	var sv := Save.make(_meta(), _state(), _log())
	eq(sv["format"], "castle_strategy.save", "형식 이름")
	eq(sv["format_version"], 2, "형식 번호(C4-2 v2)")
	eq(sv["turn"], 3, "턴은 상태에서")
	for k in ["game_version", "castle_common", "seed", "scenario", "player", "mode", "state", "orders"]:
		check(sv.has(k), "칸 %s" % k)


func test_round_trip_same_hash() -> void:
	var s := _state()
	var text := Save.to_text(Save.make(_meta(), s, _log()))
	check(text != "" and not text.contains(".0,"), "정수만 든 정규형 글")
	var r: Dictionary = Save.from_text(text, _t())
	eq(r["errors"], [], "읽기 오류 없음")
	eq(State.hash_of(r["save"]["state"]), State.hash_of(s), "같은 상태 해시")
	eq(r["save"]["orders"], _log().map(func(e): e["fights"] = {}; return e), "명령 기록 그대로(정수로 · v2 fights 빈 칸)")
	eq(r["save"]["seed"], 7, "시드 정수")


func test_v0_stub_save_migrates_to_new_game() -> void:
	var v0 := "{\"acc\":123,\"last\":5,\"seed\":4,\"turn\":9,\"v\":1}"
	var r: Dictionary = Save.from_text(v0, _t())
	eq(r["errors"], [], "C1-0 저장도 읽는다")
	eq(r["save"]["format_version"], 2, "v1 → v2 로 옮겼다")
	eq(r["save"]["seed"], 4, "시드는 이어 받는다")
	eq(r["save"]["scenario"], "A", "시나리오 A")
	eq(r["save"]["state"], {}, "빈 상태 = 처음부터 새로(명령 기록 다시 돌리기)")
	eq(r["save"]["orders"], [], "명령 기록 없음")
	check(r["notes"].any(func(n): return String(n).contains("v0")), "옮김 기록: %s" % [r["notes"]])


func test_newer_or_broken_is_rejected() -> void:
	var sv := Save.make(_meta(), _state(), [])
	sv["format_version"] = 99
	check(str(Save.from_text(Save.to_text(sv), _t())["errors"]).contains("새 판"), "더 새 판은 거절")
	check(not Save.from_text("{깨진", _t())["errors"].is_empty(), "깨진 글")
	check(not Save.from_text("[1,2]", _t())["errors"].is_empty(), "사전이 아닌 글")
	check(not Save.from_text("{\"format\":\"other\",\"format_version\":1}", _t())["errors"].is_empty(), "다른 형식")
	var bad := Save.make(_meta(), _state(), [])
	bad["state"]["orgs"]["org_a"].erase("cash")
	check(not Save.from_text(Save.to_text(bad), _t())["errors"].is_empty(), "상태 칸이 모자라면 오류")


## 옛 id(canon replaced_by) — 상태의 키 · 참조와 명령 기록 · player 를 새 id 로 옮긴다
func test_replaced_ids_are_renamed() -> void:
	var s := State.new_state(7, "A", "old_org")
	s["orgs"]["old_org"] = State.new_org("old_c", "old_place")
	s["officers"]["old_c"] = State.new_officer("old_org", "old_place", "조장급")
	s["zones"]["old_place"] = State.new_zone("old_org")
	s["zones"]["old_place"]["slots"] = [{"kind": "상권", "org": "old_org", "lv": 1, "dmg": 0}]
	var log := [{"turn": 1, "orders": [Orders.make("old_org", "old_c", "move", "old_place")]}]
	var meta := _meta()
	meta["player"] = "old_org"
	var r: Dictionary = Save.from_text(Save.to_text(Save.make(meta, s, log)), _t())
	eq(r["errors"], [], "오류 없음")
	var st: Dictionary = r["save"]["state"]
	eq(State.sorted_keys(st["officers"]), ["new_c"], "인물 키")
	eq(State.sorted_keys(st["orgs"]), ["org_a"], "조직 키")
	eq(State.sorted_keys(st["zones"]), ["z1"], "구역 키")
	eq(st["officers"]["new_c"]["org"], "org_a", "간부 소속")
	eq(st["officers"]["new_c"]["zone"], "z1", "간부 자리")
	eq(st["orgs"]["org_a"]["boss"], "new_c", "두목")
	eq(st["orgs"]["org_a"]["hq"], "z1", "본거지")
	eq(st["zones"]["z1"]["owner"], "org_a", "구역 주인")
	eq(st["zones"]["z1"]["slots"][0]["org"], "org_a", "칸 주인")
	eq(st["player"], "org_a", "상태의 player")
	eq(r["save"]["player"], "org_a", "저장의 player")
	eq(r["save"]["orders"][0]["orders"][0], Orders.make("org_a", "new_c", "move", "z1"), "명령 기록")
	check(r["notes"].any(func(n): return String(n).contains("old_c")), "옮긴 id 기록")


## C2 FR-213 — 대기 명령 선택 칸 pending: 쓰고 읽으면 그대로 · 없는 옛 저장은 빈 목록 · 꼴이 틀린 명령은 버리고 알림 · id 옮기기
func test_pending_round_trip_and_old_saves() -> void:
	var t := _t()
	var pend := [Orders.make("org_a", "boss_a", "open", "z1", {}, "player")]
	var sv := Save.make(_meta(), _state(), _log(), pend)
	eq(sv["format_version"], 2, "형식 버전(v2)")
	var r: Dictionary = Save.from_text(Save.to_text(sv), _t())
	eq(r["errors"], [], "읽기")
	eq(r["save"]["pending"], pend, "대기 명령 그대로")
	var old := Save.make(_meta(), _state(), _log())
	old.erase("pending")
	eq(Save.from_text(Save.to_text(old), t)["save"]["pending"], [], "pending 없는 C1 저장 = 빈 목록")
	var bad := Save.make(_meta(), _state(), _log(), [pend[0], {"org": "org_a"}, "x"])
	var rb: Dictionary = Save.from_text(Save.to_text(bad), t)
	eq(rb["errors"], [], "틀린 대기 명령은 오류가 아니다")
	eq(rb["save"]["pending"], pend, "맞는 것만 남김")
	check(rb["notes"].any(func(n): return n.contains("대기 명령 2개 버림")), "버린 수 알림")
	var mv := Save.make(_meta(), _state(), _log(), [Orders.make("org_a", "old_c", "rest", "old_place", {}, "player")])
	var rm: Dictionary = Save.from_text(Save.to_text(mv), t)
	eq([rm["save"]["pending"][0]["by"], rm["save"]["pending"][0]["to"]], ["new_c", "z1"], "대기 명령도 id 옮김")


## C4-2 FR-419 — 저장 v2: 구간 결과(기록 줄 fights · pending_fights)를 쓰고 읽으면 그대로 · v1 저장은 빈 칸으로 옮김 · 꼴이 틀린 결과는 버리고 알림 · id 옮기기
func _res(i: int, id := "boss_a") -> Dictionary:
	return {"v": 1, "i": i, "by": "direct", "result": "att", "ticks": 2, "a": [{"t": "o", "id": id, "hp": 10, "down": false, "wound": 0}],
		"d": [{"t": "g", "grade": "건달급", "n": 0}], "morale": [100, 0], "seen": {id: {"kickarts": 1}}, "frames": 300, "kills": [3, 0]}


func test_v2_fights_round_trip() -> void:
	var t := _t()
	var log := _log()
	log[0]["fights"] = {"z2|org_a": {"0": _res(0), "1": _res(1)}}
	var pf := {"z2|org_a": {"0": _res(0)}}
	var sv := Save.make(_meta(), _state(), log, [], pf)
	eq(sv["orders"][1]["fights"], {}, "fights 없는 기록 줄은 빈 칸")
	var r: Dictionary = Save.from_text(Save.to_text(sv), t)
	eq(r["errors"], [], "읽기")
	eq(r["save"]["orders"][0]["fights"], log[0]["fights"], "기록 줄 fights 그대로")
	eq(r["save"]["pending_fights"], pf, "pending_fights 그대로")
	eq(r["notes"], [], "버린 것 없음")


func test_v1_save_migrates_to_v2() -> void:
	var t := _t()
	var v1 := Save.make(_meta(), _state(), _log())
	v1["format_version"] = 1
	v1.erase("pending_fights")
	for e in v1["orders"]:
		e.erase("fights")
	var r: Dictionary = Save.from_text(Save.to_text(v1), t)
	eq(r["errors"], [], "v1 저장도 읽는다")
	eq(r["save"]["format_version"], 2, "v2 로")
	eq(r["save"]["orders"].map(func(e): return e["fights"]), [{}, {}], "기록 줄마다 fights {}")
	eq(r["save"]["pending_fights"], {}, "pending_fights {}")
	check(r["notes"].has("v1 → v2 옮김"), "옮김 기록 %s" % str(r["notes"]))
	eq(State.hash_of(r["save"]["state"]), State.hash_of(_state()), "상태 그대로")


func test_bad_fights_dropped() -> void:
	var t := _t()
	var log := _log()
	log[0]["fights"] = {"z2|org_a": {"0": _res(0), "1": _res(0), "7": _res(7), "2": "x"}, "nokey": {"0": _res(0)}}
	var sv := Save.make(_meta(), _state(), log, [], {"z2|org_a": {"0": {"v": 2, "i": 0}}})
	var r: Dictionary = Save.from_text(Save.to_text(sv), t)
	eq(r["errors"], [], "틀린 구간 결과는 오류가 아니다")
	eq(r["save"]["orders"][0]["fights"], {"z2|org_a": {"0": _res(0)}}, "맞는 것만 남김")
	eq(r["save"]["pending_fights"], {}, "pending_fights 도 버림")
	check(r["notes"].has("구간 결과 5개 버림(꼴이 틀림)"), "버린 수 알림 %s" % str(r["notes"]))


func test_fights_ids_renamed() -> void:
	var t := _t()
	var log := _log()
	log[0]["fights"] = {"old_place|old_org": {"0": _res(0, "old_c")}}
	var r: Dictionary = Save.from_text(Save.to_text(Save.make(_meta(), _state(), log, [], {"old_place|old_org": {"1": _res(1, "old_c")}})), t)
	var f: Dictionary = r["save"]["orders"][0]["fights"]
	eq(f.keys(), ["z1|org_a"], "묶음 키 id 옮김")
	eq(f["z1|org_a"]["0"]["a"][0]["id"], "new_c", "줄 id 옮김")
	eq(f["z1|org_a"]["0"]["seen"].keys(), ["new_c"], "seen id 옮김")
	eq(r["save"]["pending_fights"].keys(), ["z1|org_a"], "pending_fights 키도 옮김")
