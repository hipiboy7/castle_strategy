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
			"trades": ["상권", "유흥"],
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
	}
