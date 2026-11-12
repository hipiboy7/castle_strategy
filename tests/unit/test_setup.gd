extends "res://tests/helpers.gd"
## FR-117 — sim/setup.gd: 시나리오 처음 상태 = 팩 명단 + assign + 구역 주인(resolve) + factions(본거지 · 두목 · 정예) + 3층 시작값(data/game/setup.json).
## 등급 빈칸(null · '그 아래급' · rank_provisional)은 자리값 조장급 + rank_prov(기획_차이 (나)9). 판 밖 조직(본거지가 이 판에 없음)의 간부는 away.

const Setup = preload("res://sim/setup.gd")
const State = preload("res://sim/state.gd")
const Tables = preload("res://sim/tables.gd")
const DataFiles = preload("res://src/data_files.gd")
const Fixtures = preload("res://tests/fixtures.gd")

var _real := {}


func _real_t() -> Dictionary:
	if _real.is_empty():
		var r: Dictionary = DataFiles.read(Tables.NEEDS)
		check(r["errors"].is_empty(), "읽기 %s" % [r["errors"]])
		_real = Tables.build(r["files"])
	return _real


func test_fake_scenario() -> void:
	var t := Tables.build(Fixtures.files())
	var r: Dictionary = Setup.scenario(t, "A", 9)
	eq(r["errors"], [], "오류 없음")
	var s: Dictionary = r["state"]
	eq(s["seed"], 9, "시드")
	eq(s["player"], "org_a", "고를 수 있는 첫 조직")
	eq(State.sorted_keys(s["orgs"]), ["org_a"], "판 조직(명단 · 구역 주인을 resolve)")
	eq(s["orgs"]["org_a"]["boss"], "man_b", "assign post boss 가 두목")
	eq(s["orgs"]["org_a"]["cash"], 500, "시나리오 값이 기본값을 덮는다")
	eq(s["orgs"]["org_a"]["troops"], {"건달급": 10, "조장급": 2, "네임드": 0, "경호대급": 0}, "조직원 기본값")
	eq(s["orgs"]["org_a"]["hq"], "z1", "본거지")
	eq(s["officers"]["man_b"]["post"], "boss", "두목 자리")
	eq(s["officers"]["boss_a"]["post"], "", "두목이 아닌 간부")
	eq(s["officers"]["boss_a"]["loyalty"], 8000, "충성 = 의리 × 100")
	eq(s["officers"]["man_b"]["loyalty"], 5000, "능력치가 없으면 50.00")
	check(not s["officers"].has("old_c") and s["officers"].has("new_c"), "replaced_by 로 옮긴 id")
	eq(s["officers"]["new_c"]["org"], "", "무소속")
	eq(s["officers"]["new_c"]["status"], "away", "판 밖")
	eq(s["officers"]["new_c"]["rank"], "조장급", "'그 아래급' → 자리값")
	eq(s["officers"]["new_c"]["rank_prov"], true, "자리값 표시")
	eq(s["zones"]["z2"]["owner"], "", "A 의 u_local 은 무소속")
	eq(s["zones"]["z2"]["slots"], [{"kind": "유흥", "org": "", "lv": 0, "dmg": 0}, {"kind": "상권", "org": "", "lv": 0, "dmg": 0}],
		"칸 수(시나리오 값) · 업종은 구역 trades 를 돌아가며")
	eq(s["zones"]["z1"]["slots"][0], {"kind": "상권", "org": "org_a", "lv": 1, "dmg": 0}, "주인이 처음 칸을 쥔다")
	eq(s["zones"]["z1"]["slots"][1]["org"], "", "owned_slots 1")
	eq(s["zones"]["z1"]["facilities"], ["hq", "office"], "본거지 구역 거점")
	eq(s["zones"]["z2"]["people"], 4, "구역 값")
	eq(s["officers"]["boss_a"]["skills"], ["kick"], "기술 = data/characters.json 처음 값(rules_common progress)")


func test_bad_scenario_or_player() -> void:
	var t := Tables.build(Fixtures.files())
	check(not Setup.scenario(t, "Z", 1)["errors"].is_empty(), "모르는 시나리오")
	check(not Setup.scenario(t, "A", 1, "org_b")["errors"].is_empty(), "고를 수 없는 조직")


func test_real_scenario_a() -> void:
	var t := _real_t()
	var r: Dictionary = Setup.scenario(t, "A", 1)
	eq(r["errors"], [], "받은 사본으로 A 오류 없음")
	var s: Dictionary = r["state"]
	eq(s["player"], "bujinpa", "A 는 부진파(김신 쪽)")
	eq(State.sorted_keys(s["orgs"]), ["bujinpa", "dssecurity", "haseong", "iskra"], "A 의 판 조직 넷(혁신당은 정치 — 조직 아님)")
	eq(State.sorted_keys(s["zones"]), ["bujindong", "bukgu", "hoeamsijang", "namgu"], "구역 넷")
	eq(s["officers"].size(), 14, "명단 14")
	eq(s["orgs"]["bujinpa"]["boss"], "kimshin", "김신이 두목(assign)")
	eq(s["orgs"]["bujinpa"]["hq"], "bujindong", "부진파 본거지")
	eq(s["orgs"]["dssecurity"]["boss"], "yundeoksu", "DS 두목")
	eq(s["orgs"]["dssecurity"]["hq"], "bukgu", "DS 본거지")
	eq(s["orgs"]["iskra"]["hq"], "", "이스크라 본거지(블라디보스토크)는 이 판 밖")
	eq(s["officers"]["jintae"]["org"], "bujinpa", "서진태는 김신 쪽(assign)")
	eq(s["officers"]["risa"]["status"], "away", "판 밖 조직의 간부는 away")
	eq(s["officers"]["kimshin"]["rank"], "내성 중위", "김신 등급(data/characters.json 처음 등급)")
	eq(s["officers"]["kimshin"]["rank_prov"], false, "확정 등급")
	eq(s["officers"]["chasumin"]["rank"], "조장급", "차수민 조장급(castle_common 92차 확정)")
	eq(s["officers"]["chasumin"]["rank_prov"], false, "92차 확정 등급 — 자리값 표시 없음")
	eq(s["officers"]["gangmanjae"]["rank_prov"], false, "92차가 rank_provisional 을 뺐다(1장 등급 확정)")
	eq(s["officers"]["risa"]["rank"], "조장급", "빈 등급(noncombat) → 자리값")
	eq(s["officers"]["risa"]["rank_prov"], true, "자리값 표시")
	eq(s["zones"]["namgu"]["owner"], "", "남구는 무소속")
	eq(s["zones"]["hoeamsijang"]["slots"].map(func(x): return x["kind"]), ["상권", "대부", "상권", "대부"], "시장 칸 넷 — 업종을 돌아가며")
	eq(State.check_invariants(s, t), [], "불변식 통과")
	eq(State.hash_of(Setup.scenario(t, "A", 1)["state"]), State.hash_of(s), "같은 입력 → 같은 처음 상태")
