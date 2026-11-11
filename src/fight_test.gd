extends RefCounted
## 전투 시험 준비(FR-405) — 정해진 구간 하나(data/game/fight.json `test`: 간부 하나 대 조직원 무리)를 need 꼴(설계서 2-2)로 만든다.
## 쓰는 곳: headless `-- --fight-test --seed S`(src/main.gd — FIGHT 한 줄 · verify '구간 전투') · 기록 탭 '전투 시험'(ui/app.gd) · 시험.
## 유닛은 틱 습격과 같은 함수(sim/combat.gd officer_unit · group_unit)로 만든다 — C4-2 에서 턴이 need 를 내면 이 파일은 시험용으로만 남는다.
## 설계: docs/C4_설계서_직접조작전투.md 2-2 · 8절 · 시험: tests/integration/test_fight_section.gd

const Game = preload("res://sim/game.gd")
const Combat = preload("res://sim/combat.gd")
const Pcg32 = preload("res://sim/rng.gd")
const Section = preload("res://fight/section.gd")
const SCENARIO := "A"


static func need(t: Dictionary, seed: int) -> Dictionary:
	var cfg: Dictionary = t["fight"]["test"]
	var s: Dictionary = Game.new_game(t, SCENARIO, seed)["state"]
	var id: String = cfg["officer"]
	var foes := []
	for row in cfg["troops"]:
		foes.append(Combat.group_unit(t, String(row[0]), int(row[1]), 1))
	return {"key": "test|test", "turn": 1, "zone": "", "att": String(s["officers"][id].get("org", "")), "def": "", "i": 0, "side": 0,
		"A": [Combat.officer_unit(s, t, id, 0)], "D": foes, "cards": [], "def_cards": [],
		"known": {id: {"skills": Array(s["officers"][id]["skills"]).duplicate(), "seen": {}}},
		"seed": Pcg32.new().init_stream(seed, 1, "fight", "test|0").next_u32()}


## 봇으로 끝까지 — 요약 + 구간 결과(끝나지 않았으면 빈 사전). 같은 시드면 같은 값
static func run(t: Dictionary, seed: int) -> Dictionary:
	var d := Section.simulate(t, need(t, seed), {"by": "auto"}, int(t["fight"]["test"]["max_frames"]))
	var out := Section.summary(d)
	out["seed"] = seed
	out["outcome"] = Section.outcome(d) if d["over"] != "" else {}
	return out
