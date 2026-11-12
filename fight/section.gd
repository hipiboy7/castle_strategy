extends RefCounted
## 구간 판 — 습격의 한 구간(입구 · 안 · 본진)을 실시간으로 푼다. 받은 준비(need — 유닛 · 카드 · 시드 · 설계서 2-2)에서 싸울 사람을
## 만들고(fight/build.gd), 한 프레임씩 진행하고(사람 입력 또는 봇), 끝나면 **구간 결과**(정수 — 설계서 2-3)를 낸다.
## 순수 로직(노드 없음 · 60프레임 고정 · 시드 하나 · 같은 시드 · 같은 입력이면 같은 결과). 판 상태(sim/)는 모른다.
## castle_M3D `src/combat/stage.gd`(2c3e69b — 장 진행 · 방 · 교대)를 본보기로 새로 썼다: 겨누기 · 차례(동시에 치는 수) · 봇은 같은 생각.
## 쪽: 유닛의 side(0 들어가는 쪽 · 1 지키는 쪽) ↔ 편(team): 묻는 조직이 선 쪽 = 0(내 쪽 — 조종 · 봇 간부 + AI 조직원), 상대 = 1(전부 AI).
## 사기 · 시간 상한 · 부상 값은 틱 습격과 같은 data/game/combat.json, 실시간 환산은 data/game/fight.json(틱 길이 · 세우는 수 · 차례).
## C4-0: 간부 · 조직원 세우기 · 채우기 · 봇 자동 플레이 · 교대 · 사기 · 시간 · 구간 결과. C4-1: 작전 카드(정면 돌파 · 기습 · 매복 · 방패조 — 틱과 같은
## combat.json 값 · 틱 수는 틱 길이로 환산) · 카피(같은 방의 간부가 기술을 낼 때마다 서 있는 can_copy 간부가 본 횟수 +1 — 같은 편 · 기절 중도 센다 ·
## 92차 해석 ⑥) · 한 대상에 동시에 패턴을 내는 수(attackers — 포위 한도).
## 신호: world.events(그림 · 소리가 읽는다) · 설계: docs/C4_설계서_직접조작전투.md 4-4 · 4-5 · 요구: FR-402 · 시험: tests/integration/test_fight_section.gd

const World = preload("res://fight/world.gd")
const Bot = preload("res://fight/bot.gd")
const EnemyAI = preload("res://fight/enemy_ai.gd")
const Build = preload("res://fight/build.gd")
const RulesRt = preload("res://fight/rules_rt.gd")
const BP := 10000.0


## opts: ctrl(조종할 간부 id — 없으면 내 쪽 첫 간부) · by("direct" | "auto" — 구간 결과에 남긴다)
static func make(t: Dictionary, need: Dictionary, opts := {}) -> Dictionary:
	var fc: Dictionary = t["fight"]
	var rules = RulesRt.new(t["rules"])
	var w = World.new(rules)
	w.end_on_ko = false
	w.move_ref = float(fc["move_ref"])
	var hw := float(fc["room"]["w"]) * Build.CM * 0.5
	var hd := float(fc["room"]["d"]) * Build.CM * 0.5
	w.bounds = Rect2(-hw, -hd, hw * 2.0, hd * 2.0)
	var start := int(t["combat"]["raid"]["morale"]["start"])
	var d := {"kind": "section", "t": t, "need": need, "rules": rules, "world": w, "side": int(need["side"]),
		"units": [need["A"], need["D"]], "who": {}, "mine": [], "ctrl": -1, "bots": {}, "ais": {}, "wait": [[], []],
		"morale": [start, start], "heads0": [0, 0], "frames": 0, "fight_t": 0, "stage": "intro", "over": "", "result": "",
		"kills": [0, 0], "counted": {}, "by": String(opts.get("by", "direct")), "n": 0, "hero": null, "boss": null,
		"seen": {}, "ev0": 0, "surprise": 0, "ambush": 0}
	_cards(d)
	for side in 2:
		var units: Array = d["units"][side]
		for ui in units.size():
			var u: Dictionary = units[ui]
			if u["t"] == "o":
				if not u["down"]:
					_add_officer(d, side, ui)
			else:
				for k in int(u["n"]):
					d["wait"][side].append(ui)
		d["heads0"][side] = heads(d, side)
		_fill(d, side)
	var want := String(opts.get("ctrl", ""))
	for k in d["mine"].size():
		if d["ctrl"] < 0 or d["mine"][k].char_id == want:
			d["ctrl"] = k
	_focus(d)
	return d


## 작전 카드(08 4-1 · 틱 sim/combat.gd _section 과 같은 값) — 정면 돌파 · 기습 · 매복은 첫 구간만, 방패조는 모든 구간.
## 들어가는 쪽 카드 = need.cards · 지키는 쪽 카드 = need.def_cards. 미끼 · 우회로는 준비(sim/combat.gd prepare)에서 이미 반영돼 온다.
static func _cards(d: Dictionary) -> void:
	var t: Dictionary = d["t"]
	var cd: Dictionary = t["combat"]["cards"]
	var w = d["world"]
	var need: Dictionary = d["need"]
	var first: bool = int(need["i"]) == 0
	var tf := int(t["fight"]["tick_frames"])
	var att := team_of(d, 0)
	var dfn := team_of(d, 1)
	if first and need["cards"].has("charge"):
		w.team_dmg_k[att] = float(cd["charge"]["dmg_bp"]) / BP
	if need["cards"].has("shield"):
		w.mob_taken_k[att] = float(cd["shield"]["loss_bp"]) / BP
	if need["def_cards"].has("shield"):
		w.mob_taken_k[dfn] = float(cd["shield"]["loss_bp"]) / BP
	if first and need["cards"].has("surprise"):
		d["surprise"] = int(cd["surprise"]["skip_ticks"]) * tf      # 싸움 시간 이 프레임까지 지키는 쪽이 치지 못한다
	if first and need["def_cards"].has("ambush"):
		d["ambush"] = tf                                            # 첫 틱 길이 동안 지키는 쪽 피해 ×
		w.team_dmg_k[dfn] = float(cd["ambush"]["dmg_bp"]) / BP


static func team_of(d: Dictionary, side: int) -> int:
	return 0 if side == int(d["side"]) else 1


static func _rng(d: Dictionary, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = int(d["need"]["seed"]) * 7919 + salt
	return r


## 서는 자리 — 내 쪽은 왼쪽 · 상대는 오른쪽. k = 그 쪽에서 몇 번째(줄을 바꿔 가며), late = 싸움 중에 채워 들어오는 사람(끝에서)
static func _spot(d: Dictionary, team: int, k: int, mob: bool, late: bool) -> Vector2:
	var b: Rect2 = d["world"].bounds
	var hw := b.size.x * 0.5
	var hd := b.size.y * 0.5
	var sx := -1.0 if team == 0 else 1.0
	var x := hw * 0.3 if not mob else hw * (0.5 + 0.12 * float(k / 5 % 3))
	if late:
		x = hw - 0.5
	return Vector2(sx * x, (float(k % 5) - 2.0) * hd * 0.36)


static func _add_officer(d: Dictionary, side: int, ui: int) -> void:
	var t: Dictionary = d["t"]
	var u: Dictionary = d["units"][side][ui]
	var team := team_of(d, side)
	var f = Build.officer(t, d["rules"], u, team, d["need"].get("known", {}).get(u["id"], {}))
	f.unit_i = ui
	var n: int = d["n"]
	f.pos = _spot(d, team, n, false, false)
	f.facing = Vector2(1, 0) if team == 0 else Vector2(-1, 0)
	d["who"][f] = [side, ui]
	if team == 0:
		var b = Bot.new(f, null, _rng(d, 977 + n))
		b.generic_skills = true
		d["bots"][f] = b
		d["mine"].append(f)
	else:
		f.is_boss = true
		d["ais"][f] = EnemyAI.new(f, String(Build.role_of(t, u["id"])["ai"]), _rng(d, 131 + n), Build.guard_rate(t, u["id"]))
	d["n"] = n + 1
	d["world"].add(f)


## 아직 못 선 조직원 한 명을 세운다(그 쪽 wait 맨 앞)
static func _spawn_troop(d: Dictionary, side: int) -> void:
	var t: Dictionary = d["t"]
	var ui: int = d["wait"][side].pop_front()
	var u: Dictionary = d["units"][side][ui]
	var team := team_of(d, side)
	var f = Build.troop(t, d["rules"], u, team)
	f.unit_i = ui
	var n: int = d["n"]
	f.pos = _spot(d, team, n, true, d["stage"] != "intro")
	f.facing = Vector2(1, 0) if team == 0 else Vector2(-1, 0)
	d["who"][f] = [side, ui]
	var ais: Array = Build.troop_role(t, u["grade"])["ai"]
	d["ais"][f] = EnemyAI.new(f, String(ais[n % ais.size()]), _rng(d, 131 + n), float(t["fight"]["troop"]["guard_bp"]) / BP)
	d["n"] = n + 1
	d["world"].add(f)


## 그 쪽의 서 있는 조직원이 화면 상한(on_field)보다 적으면 wait 에서 채운다
static func _fill(d: Dictionary, side: int) -> void:
	var cap := int(d["t"]["fight"]["on_field"]["mine" if team_of(d, side) == 0 else "foe"])
	var on := 0
	for f in d["who"]:
		if f.is_mob and f.alive() and int(d["who"][f][0]) == side:
			on += 1
	while on < cap and not d["wait"][side].is_empty():
		_spawn_troop(d, side)
		on += 1


## 그 쪽에 남은 머릿수 — 서 있는 사람(간부 · 조직원) + 아직 못 선 조직원
static func heads(d: Dictionary, side: int) -> int:
	var n: int = d["wait"][side].size()
	for f in d["who"]:
		if f.alive() and int(d["who"][f][0]) == side:
			n += 1
	return n


## 한 프레임. human 이 null 이면 봇이 조종 간부도 움직인다(자동 플레이). human["swap"] 이면 교대
static func step(d: Dictionary, human = null) -> void:
	var w = d["world"]
	d["frames"] += 1
	if d["stage"] == "intro":
		if int(d["frames"]) >= int(d["t"]["fight"]["intro_frames"]):
			d["stage"] = "fight"
	elif d["stage"] == "fight" and d["over"] == "":
		d["fight_t"] += 1
	if int(d["ambush"]) > 0 and int(d["fight_t"]) > int(d["ambush"]):
		w.team_dmg_k[team_of(d, 1)] = 1.0
		d["ambush"] = 0
	if human != null and human.get("swap", false):
		swap(d)
	_targets(d)
	_intents(d, human)
	d["ev0"] = w.events.size()                       # 이번 프레임에 새로 난 신호만 센다(그림이 비우기 전에 여러 번 부를 때 — 배속)
	w.tick()
	_after(d)


## 교대 — 살아 있는 다음 내 간부에게 조종을 넘긴다(넘겨준 간부는 봇이 이어 받는다)
static func swap(d: Dictionary) -> bool:
	var mine: Array = d["mine"]
	for k in range(1, mine.size()):
		var other: int = (int(d["ctrl"]) + k) % mine.size()
		if mine[other].alive():
			d["ctrl"] = other
			d["world"].events.append(["swap", mine[other]])
			_focus(d)
			return true
	return false


static func _foes_of(d: Dictionary, f) -> Array:
	var out: Array = []
	for o in d["world"].fighters:
		if o.team != f.team and o.alive() and not o.inert:
			out.append(o)
	return out


## 저마다 가장 가까운 상대를 겨눈다(같은 거리면 먼저 선 쪽 — 결정적)
static func _targets(d: Dictionary) -> void:
	for f in d["world"].fighters:
		if not f.alive():
			continue
		if d["ais"].has(f) and d["ais"][f].busy() and f.target() != null and f.target().alive():
			continue                                  # 패턴을 내는 중이면 대상을 바꾸지 않는다(포위 한도를 대상마다 센다)
		var best = null
		var bd := INF
		for o in _foes_of(d, f):
			var dd: float = f.dist_to(o)
			if dd < bd:
				bd = dd
				best = o
		f.set_target(best)


static func _intents(d: Dictionary, human) -> void:
	var w = d["world"]
	var frozen: bool = w.hitstop > 0 or d["over"] != ""
	var fighting: bool = d["stage"] == "fight"
	var cap := int(d["t"]["fight"]["attackers"])
	var held: bool = int(d["surprise"]) > 0 and int(d["fight_t"]) <= int(d["surprise"])   # 기습 — 지키는 쪽이 아직 치지 못한다
	var busy := {}                                    # 대상마다 지금 패턴을 내는 AI 수(포위 한도 · 예고를 읽을 틈 — castle_M3D MAX_ATTACKERS)
	for f in d["ais"]:
		if d["ais"][f].busy() and f.target() != null:
			busy[f.target()] = int(busy.get(f.target(), 0)) + 1
	for f in d["ais"]:
		if frozen or not fighting or (held and int(d["who"][f][0]) == 1):
			f.intent = {}
			continue
		var ai = d["ais"][f]
		var was: bool = ai.busy()
		var tg = f.target()
		f.intent = ai.decide(tg, was or int(busy.get(tg, 0)) < cap)
		if not was and ai.busy() and tg != null:
			busy[tg] = int(busy.get(tg, 0)) + 1
	for k in d["mine"].size():
		var h = d["mine"][k]
		if k == int(d["ctrl"]) and human != null:
			h.intent = human
			if held and int(d["who"][h][0]) == 1:
				h.intent = _no_strike(human)
		elif frozen or not fighting or not h.alive() or h.target() == null:
			h.intent = {}
		else:
			var b = d["bots"][h]
			b.foe = h.target()
			b.foes = _foes_of(d, h)
			h.intent = b.decide()


static func _after(d: Dictionary) -> void:
	var w = d["world"]
	var rc: Dictionary = d["t"]["combat"]["raid"]
	var mo: Dictionary = rc["morale"]
	for ei in range(int(d["ev0"]), w.events.size()):
		var e: Array = w.events[ei]
		if e[0] == "skill":
			_saw(d, e)
			continue
		if e[0] != "ko" or d["counted"].has(e[1]) or not d["who"].has(e[1]):
			continue
		var f = e[1]
		d["counted"][f] = true                        # 신호는 그림이 비울 때까지 남는다 — 한 번만 센다
		var side: int = d["who"][f][0]
		d["ais"].erase(f)
		if f.is_mob:
			d["kills"][1 - side] += 1
		else:
			d["morale"][side] -= int(mo["officer_down"])
			if not f.downed_by_mob:
				d["morale"][1 - side] += int(mo["duel_win"])
	d["ev0"] = w.events.size()                        # 센 신호는 다시 세지 않는다
	for side in 2:
		_fill(d, side)
	if int(d["ctrl"]) >= 0 and not d["mine"][d["ctrl"]].alive():
		swap(d)
	var tick_frames := int(d["t"]["fight"]["tick_frames"])
	if d["stage"] == "fight" and d["over"] == "":
		if int(d["fight_t"]) > 0 and int(d["fight_t"]) % tick_frames == 0:
			for side in 2:
				if heads(d, side) * 2 < int(d["heads0"][side]):
					d["morale"][side] -= int(mo["half_tick"])
		var res := ""
		if heads(d, 1) == 0 or int(d["morale"][1]) <= 0:
			res = "att"
		elif heads(d, 0) == 0 or int(d["morale"][0]) <= 0 or int(d["fight_t"]) >= int(rc["tick_cap"]) * tick_frames:
			res = "def"
		if res != "":
			d["result"] = res
			d["over"] = "win" if (res == "att") == (int(d["side"]) == 0) else "lose"
			w.over = d["over"]
			w.events.append(["over", d["over"], res])
	_focus(d)


## 기습 중인 지키는 쪽 사람 입력 — 움직이기 · 막기 · 구르기만(치기 · 기술 · 대시는 뺀다)
static func _no_strike(human: Dictionary) -> Dictionary:
	var out := human.duplicate()
	for k in ["attack", "skill", "use", "dash"]:
		out.erase(k)
	return out


## 카피(설계서 4-5 · 92차 해석 ⑥) — 간부가 기술을 내면, 서 있는 다른 can_copy 간부(같은 편 · 기절 중도)의 본 횟수 +1.
## 기술 id 는 이 판 규칙에 있는 것만(게이지 기술 = 신호의 id · 보스 패턴 기술 = 그 동작의 skill_id). 배우기는 sim 이 판단한다.
static func _saw(d: Dictionary, e: Array) -> void:
	var x = e[1]
	if x.is_mob or not d["who"].has(x):
		return
	var rules = d["rules"]
	var sid := String(e[2].get("id", "")) if e.size() > 2 and e[2] is Dictionary else ""
	if not rules.has_skill(sid):
		sid = String(x.move.get("skill_id", ""))
	if sid == "" or not rules.has_skill(sid):
		return
	for f in d["who"]:
		if f == x or f.is_mob or not f.can_copy or not f.alive():
			continue
		var m: Dictionary = d["seen"].get(f.char_id, {})
		m[sid] = int(m.get(sid, 0)) + 1
		d["seen"][f.char_id] = m


## 화면에 보일 두 사람: hero = 조종 간부(없으면 null), boss = 그에게 가장 가까운 상대 간부(없으면 가장 가까운 상대)
static func _focus(d: Dictionary) -> void:
	var h = d["mine"][d["ctrl"]] if int(d["ctrl"]) >= 0 else null
	d["hero"] = h
	var best = null
	var bd := INF
	if h != null:
		for o in _foes_of(d, h):
			var dd: float = h.dist_to(o) + (100.0 if o.is_mob else 0.0)
			if dd < bd:
				bd = dd
				best = o
	d["boss"] = best


## 구간 결과(정수만 — 설계서 2-3). 끝난 뒤(d["over"] != "")에 부른다
static func outcome(d: Dictionary) -> Dictionary:
	var t: Dictionary = d["t"]
	var rc: Dictionary = t["combat"]["raid"]
	var hk := float(t["fight"]["hp_bp"]) / BP
	var left := [{}, {}]                              # 쪽 → 유닛 자리 → 남은 조직원 수
	var officers := {}
	for f in d["who"]:
		var sw: Array = d["who"][f]
		if not f.is_mob:
			officers["%d:%d" % sw] = f
		elif f.alive():
			left[sw[0]][sw[1]] = int(left[sw[0]].get(sw[1], 0)) + 1
	for side in 2:
		for ui in d["wait"][side]:
			left[side][ui] = int(left[side].get(ui, 0)) + 1
	var lists := [[], []]
	for side in 2:
		var units: Array = d["units"][side]
		for ui in units.size():
			var u: Dictionary = units[ui]
			if u["t"] == "g":
				lists[side].append({"t": "g", "grade": u["grade"], "n": int(left[side].get(ui, 0))})
				continue
			var f = officers.get("%d:%d" % [side, ui])
			if f == null:                              # 들어올 때 이미 쓰러져 있던 간부 — 그대로
				lists[side].append({"t": "o", "id": u["id"], "hp": 0, "down": true, "wound": int(u["wound"])})
				continue
			var down: bool = not f.alive()
			var wound := 0
			if down:
				wound = int(rc["down_wound"]) if f.downed_by_mob else int(t["combat"]["duel"]["ko_wound"])
			lists[side].append({"t": "o", "id": u["id"], "hp": 0 if down else clampi(ceili(f.hp / hk), 1, int(u["hp"])),
				"down": down, "wound": wound})
	return {"v": 1, "i": int(d["need"]["i"]), "by": d["by"], "result": d["result"],
		"ticks": clampi(ceili(float(d["fight_t"]) / float(t["fight"]["tick_frames"])), 0, int(rc["tick_cap"])),
		"a": lists[0], "d": lists[1], "morale": [maxi(0, int(d["morale"][0])), maxi(0, int(d["morale"][1]))],
		"seen": _seen_sorted(d["seen"]), "frames": int(d["frames"]), "kills": [int(d["kills"][0]), int(d["kills"][1])]}


## 본 횟수(인물 id → 기술 id → 수)를 키 차례로 — 결과를 글로 바꿔도 늘 같은 차례(결정성)
static func _seen_sorted(seen: Dictionary) -> Dictionary:
	var out := {}
	var ids: Array = seen.keys()
	ids.sort()
	for id in ids:
		var sk: Array = seen[id].keys()
		sk.sort()
		var m := {}
		for k in sk:
			m[k] = int(seen[id][k])
		out[id] = m
	return out


## 그림 없이 끝까지(또는 max_frames 까지) — 시험 · 자동 점검 · 빨리 감기. 판(d)을 돌려준다(끝났는지는 d["over"])
static func simulate(t: Dictionary, need: Dictionary, opts := {}, max_frames := 0) -> Dictionary:
	var d := make(t, need, opts)
	run(d, max_frames)
	return d


## 지금 판을 봇으로 끝까지 — 건너뛰기(빨리 감기)가 쓴다
static func run(d: Dictionary, max_frames := 0) -> void:
	var fc: Dictionary = d["t"]["fight"]
	var cap: int = max_frames if max_frames > 0 else \
		int(d["t"]["combat"]["raid"]["tick_cap"]) * int(fc["tick_frames"]) + int(fc["intro_frames"]) + 600
	while d["over"] == "" and int(d["frames"]) < cap:
		step(d)
		d["world"].events.clear()


## 한 줄 요약(정수 · 글) — headless `--fight-test` 의 FIGHT 줄 · 시험
static func summary(d: Dictionary) -> Dictionary:
	var hp: Array = []
	for h in d["mine"]:
		hp.append(int(round(h.hp)))
	return {"over": d["over"], "result": d["result"], "frames": int(d["frames"]), "kills": [int(d["kills"][0]), int(d["kills"][1])],
		"heads": [heads(d, 0), heads(d, 1)], "morale": [int(d["morale"][0]), int(d["morale"][1])], "hp": hp}
