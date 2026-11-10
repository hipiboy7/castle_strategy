extends RefCounted
## 시험 고정물 — 가짜 데이터 파일(작은 사전). sim/ 은 파일을 읽지 않고 사전을 받으므로(CLAUDE.md 2절 DIP) 시험은 이것을 넣는다.
## 쓰는 곳: tests/unit/test_tables.gd · test_state.gd …(경로 키는 src/data_files.gd 와 같다 — res://data/ 아래 상대 경로)


## 가장 작은 판 — 조직 둘(하나는 B 에서 다른 조직이 됨) · 단위 둘(시나리오별 부모) · 구역 둘 · 시나리오 하나
static func files() -> Dictionary:
	return {
		"common/ranks.json": {"ladder": ["건달급", "조장급", "네임드"], "below": "그 아래급"},
		"common/rules.json": {"gauge": {"max_bars": 2}},
		"common/skills.json": {"skills": [{"id": "kick"}]},
		"common/characters.json": {"characters": [{"id": "boss_a", "rank": "네임드", "skills": ["kick"]}]},
		"common/progression.json": {"events": [], "steps": [], "unplaced": {}},
		"common/canon/characters.json": {"characters": [
			{"id": "boss_a"}, {"id": "man_b"}, {"id": "old_c", "deprecated": true, "replaced_by": "new_c"}, {"id": "new_c"}]},
		"common/canon/factions.json": {"factions": [{"id": "old_org", "replaced_by": "org_a"}]},
		"common/canon/locations.json": {"locations": [{"id": "old_place", "replaced_by": "z1"}]},
		"common/packs/strategy/factions.json": {
			"trades": ["유흥", "대부", "건설", "물류", "숙박", "상권"],
			"factions": [
				{"id": "org_a", "boss": "boss_a", "trade": "상권", "elite": null, "aces": ["man_b"], "hq": {"default": "z1"}, "becomes": {}},
				{"id": "org_b", "boss": "man_b", "trade": null, "elite": {"unit": "u_sub"}, "aces": [], "hq": {"default": "z2", "B": null},
				 "becomes": {"B": "org_a"}}],
			"units": [
				{"id": "u_sub", "kind": "unit", "parent": "org_b"},
				{"id": "u_local", "kind": "local", "parent": {"A": null, "B": "org_b", "D": "org_b", "*": "org_a"}}]},
		"common/packs/strategy/districts.json": {"districts": [
			{"id": "z1", "trades": ["상권"], "owners": {"A": "org_a"}},
			{"id": "z2", "trades": ["유흥", "상권"], "owners": {"A": "u_local", "B": "u_local"}}]},
		"common/packs/strategy/scenarios.json": {"scenarios": [
			{"id": "A", "roster": [
				{"id": "boss_a", "faction": "org_a", "rank": "네임드"},
				{"id": "man_b", "faction": "u_sub", "rank": null},
				{"id": "old_c", "faction": null, "rank": "그 아래급"}],
			 "assign": [{"id": "man_b", "faction": "org_a", "post": "boss"}], "playable": ["org_a"]}]},
		"common/packs/strategy/characters.json": {"characters": [
			{"id": "boss_a", "stats": {"command": 70.0, "scheming": 50.0, "business": 60.0, "loyalty": 80.0, "ambition": 40.0}, "tags": ["t"]}]},
		"game/game.json": {"actions": {"officer": 1.0, "boss": 2.0}, "lengths": [26.0, 52.0, 0.0], "rank_placeholder": "조장급"},
		"game/economy.json": economy(),
		"game/setup.json": {
			"org_default": {"cash": 200.0, "heat": 1000.0, "fame": 1000.0, "cohesion": 5000.0,
				"troops": {"건달급": 10.0, "조장급": 2.0, "네임드": 0.0, "경호대급": 0.0}},
			"zone_default": {"flow": 10000.0, "people": 3.0, "police": 1000.0, "slots": 3.0, "owned_slots": 1.0},
			"scenarios": {"A": {"orgs": {"org_a": {"cash": 500.0}}, "zones": {"z2": {"slots": 2.0, "people": 4.0}}}}},
		"game/combat.json": combat(),
		"game/map.json": {"zones": {"z1": {"x": 100.0, "y": 100.0}, "z2": {"x": 300.0, "y": 100.0}}, "links": [["z1", "z2"]]},
	}


## 습격 · 일기토 3층 값 — data/game/combat.json 그대로(값을 바꾸는 시험은 사본을 고친다)
static func combat() -> Dictionary:
	var v = JSON.parse_string(FileAccess.get_file_as_string("res://data/game/combat.json"))
	return v if v is Dictionary else {}


## 08 14-1 시작값 + 이 판이 정한 값(개업 · 확장 · 모집) — data/game/economy.json 과 같은 꼴
static func economy() -> Dictionary:
	return {"base": {"유흥": 60.0, "대부": 50.0, "건설": 70.0, "물류": 80.0, "숙박": 55.0, "상권": 35.0},
		"match_milli": 1250.0, "biz_base_milli": 800.0, "biz_per_point_milli": 4.0, "heat_div": 20000.0,
		"wage": {"건달급": 1.0, "조장급": 2.0, "네임드": 4.0, "경호대급": 8.0}, "officer_pay_per_rank": 3.0,
		"tribute_bp": 1500.0, "tribute_forced_bp": 3000.0, "loan": {"interest_bp": 300.0, "default_turns": 4.0}, "castle_fee_bp": 500.0,
		"neg_cash": {"turns": 2.0, "leave_bp": 1000.0, "loyalty_drop": 500.0},
		"open_cost_k": 4.0, "expand_cost_k": 4.0, "recruit": {"cost": 3.0, "per_people": 2.0, "rand": 3.0}}
