extends RefCounted
## 전투 시험 준비(FR-405 · FR-408) — data/game/fight.json `test`:
##   need(t, seed)  간부 하나 대 조직원 무리 한 구간(C4-0 — 손맛 · fps 시험)
##   raid(t, seed)  시나리오 A 처음 상태에서 습격 하나(test.raid — 구역 · 조직 · 간부 최대 4 · 카드)를 틱과 같은 준비(sim/combat.gd prepare)로 3구간 준비
##   run(t, seed)   raid 를 봇으로 구간마다 끝까지 — 구간 결과를 들어가는 쪽 유닛에 옮겨(sim/combat.gd apply_section) 다음 구간으로 잇는다(FR-408)
## 쓰는 곳: headless `-- --fight-test --seed S`(src/main.gd — FIGHT 한 줄 · verify '구간 전투') · 기록 탭 '전투 시험'(ui/app.gd) · 시험.
## C4-2 에서 턴이 need 를 내면 이 파일은 시험용으로만 남는다.
## 설계: docs/C4_설계서_직접조작전투.md 2-2 · 8절 · 시험: tests/integration/test_fight_section.gd

const Game = preload("res://sim/game.gd")
const Combat = preload("res://sim/combat.gd")
const Pcg32 = preload("res://sim/rng.gd")
const Section = preload("res://fight/section.gd")
const SCENARIO := "A"
const TURN := 1


static func need(t: Dictionary, seed: int) -> Dictionary:
	var cfg: Dictionary = t["fight"]["test"]
	var s: Dictionary = Game.new_game(t, SCENARIO, seed)["state"]
	var id: String = cfg["officer"]
	var foes := []
	for row in cfg["troops"]:
		foes.append(Combat.group_unit(t, String(row[0]), int(row[1]), 1))
	return {"key": "test|test", "turn": TURN, "zone": "", "att": String(s["officers"][id].get("org", "")), "def": "", "i": 0, "side": 0,
		"A": [Combat.officer_unit(s, t, id, 0)], "D": foes, "cards": [], "def_cards": [],
		"known": {id: {"skills": Array(s["officers"][id]["skills"]).duplicate(), "seen": {}}},
		"seed": Pcg32.new().init_stream(seed, 1, "fight", "test|0").next_u32()}


## 습격 하나의 3구간 준비 — {"s": 처음 상태, "prep": sim/combat.gd prepare 결과(유닛은 구간마다 apply_section 으로 이어진다)}
static func raid(t: Dictionary, seed: int) -> Dictionary:
	var cfg: Dictionary = t["fight"]["test"]["raid"]
	var s: Dictionary = Game.new_game(t, SCENARIO, seed)["state"]
	return {"s": s, "prep": Combat.prepare(s, t, cfg["zone"], cfg["org"], cfg["by"], cfg["cards"], cfg.get("def_cards", []))}


## 그 습격의 구간 i 준비(내가 들어가는 쪽)
static func raid_need(t: Dictionary, r: Dictionary, i: int) -> Dictionary:
	return Combat.need_of(r["s"], t, TURN, r["prep"], i, 0)


## 구간 결과를 유닛에 옮긴다(들어가는 쪽은 다음 구간으로 이어진다)
static func carry(r: Dictionary, out: Dictionary) -> void:
	Combat.apply_section(r["prep"]["A"], out["a"])
	Combat.apply_section(r["prep"]["D"][int(out["i"])], out["d"])


## 다음에 풀 구간(우회로로 건너뛴 구간은 넘는다) — 없으면 -1
static func next_section(r: Dictionary, after: int) -> int:
	for i in range(after + 1, 3):
		if i != int(r["prep"]["skip"]):
			return i
	return -1


## 봇으로 3구간을 끝까지 — 요약(마지막 구간의 over · outcome + 구간마다 요약). 같은 시드면 같은 값
static func run(t: Dictionary, seed: int) -> Dictionary:
	var r := raid(t, seed)
	var secs := []
	var frames := 0
	var kills := [0, 0]
	var last := {}
	var over := ""
	var i := next_section(r, -1)
	while i >= 0:
		var d := Section.simulate(t, raid_need(t, r, i), {"by": "auto"}, int(t["fight"]["test"]["max_frames"]))
		if d["over"] == "":
			break
		var o := Section.outcome(d)
		carry(r, o)
		var sm := Section.summary(d)
		sm["i"] = i
		secs.append(sm)
		frames += int(d["frames"])
		kills = [kills[0] + int(o["kills"][0]), kills[1] + int(o["kills"][1])]
		last = o
		over = d["over"]
		if o["result"] != "att":
			break
		i = next_section(r, i)
	return {"seed": seed, "over": over, "won": over == "win" and i < 0, "frames": frames, "kills": kills,
		"sections": secs, "outcome": last}
