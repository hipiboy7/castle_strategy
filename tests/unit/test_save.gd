extends "res://tests/helpers.gd"
## FR-118(직렬화) — sim/save.gd: 저장 v1(format · format_version · game_version · castle_common · seed · scenario · player · mode · turn ·
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
	eq(sv["format_version"], 1, "형식 번호")
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
	eq(r["save"]["orders"], _log(), "명령 기록 그대로(정수로)")
	eq(r["save"]["seed"], 7, "시드 정수")


func test_v0_stub_save_migrates_to_new_game() -> void:
	var v0 := "{\"acc\":123,\"last\":5,\"seed\":4,\"turn\":9,\"v\":1}"
	var r: Dictionary = Save.from_text(v0, _t())
	eq(r["errors"], [], "C1-0 저장도 읽는다")
	eq(r["save"]["format_version"], 1, "v1 로 옮겼다")
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
