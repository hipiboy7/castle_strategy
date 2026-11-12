extends Control
## 전투 화면 — 습격 한 구간을 실시간 3D 탑뷰로 보여 주고 조작을 받는다(가로 · 두 손 — 왼쪽 스틱 · 오른쪽 단추).
## 판정은 fight/section.gd 가 한다(60Hz 고정 — _physics_process 가 배속만큼 step). 이 장면은 그 상태와 신호(world.events)를 읽어
## 방(room3d) · 인형(그림 A GLB — 없으면 관절 인형) · 연출(event_fx · fx3d) · 카메라(camera_rig) · 위 표시(fight_hud) · 터치(touch_ui)에
## 넘기기만 한다(CLAUDE.md 2절 ISP). castle_M3D src/main.gd(2c3e69b)의 판 · 무대 · 인형 · 한 프레임 흐름을 본보기로 새로 썼다.
## 들어올 때 화면을 가로(screen_mode)로, 끝나면 세로로 되돌리고 finished(구간 결과, 요약)를 낸다 — 부르는 쪽(ui/app.gd)이 닫는다.
## 단추: 멈춤 · 속도(×1 · ×2 · ×4) · 자동(봇이 조종 ↔ 직접) · 교대(내 간부가 둘 이상). 뒤로 버튼: 멈춤 → 한 번 더 = 그만두기(봇이 빨리 감아 끝낸다).
## 로그 줄: FIGHT open · FIGHT over <win|lose> · FIGHT_FPS avg= min= n=(1초마다 직접 센 값 — docs/성능.md).
## C4-1: 습격 3구간을 한 화면에서 잇는다(next — 가로 그대로 · 닫기는 close) · 간부 고르기 · 내 간부 목록 · 구간 표시 · 방 두 벌(rooms) · 효과음(sound.gd).
## 설계: docs/C4_설계서_직접조작전투.md 6절 · 요구: FR-403 · FR-404 · FR-405 · FR-408 · FR-409

signal finished(outcome: Dictionary, summary: Dictionary)

const Section = preload("res://fight/section.gd")
const Build = preload("res://fight/build.gd")
const Moves = preload("res://fight/moves.gd")
const Room = preload("res://ui/fight3d/room3d.gd")
const Puppet = preload("res://ui/fight3d/puppet3d.gd")
const PuppetGlb = preload("res://ui/fight3d/puppet_glb.gd")
const Looks = preload("res://ui/fight3d/looks.gd")
const Fx = preload("res://ui/fight3d/fx3d.gd")
const Cam = preload("res://ui/fight3d/camera_rig.gd")
const EventFx = preload("res://ui/fight3d/event_fx.gd")
const Touch = preload("res://ui/fight3d/touch_ui.gd")
const Hud = preload("res://ui/fight3d/fight_hud.gd")
const ScreenMode = preload("res://ui/fight3d/screen_mode.gd")
const Sound = preload("res://ui/fight3d/sound.gd")
const SPEEDS := [1, 2, 4]
const END_WAIT := 240             # 끝난 뒤 이 프레임이 지나면 스스로 닫는다(누르면 더 빨리)
const CORPSE_T := 150             # 쓰러진 조직원 인형을 치우기까지(그리기 수를 줄인다)
const COL_CTRL := Color(0.35, 0.85, 1.0, 0.9)
const COL_MINE := Color(0.35, 0.55, 1.0, 0.45)


var _t: Dictionary = {}
var _d: Dictionary = {}
var _auto := false
var _speed_i := 0
var _paused := false
var _world: Node3D
var _fx
var _cam
var _evfx
var _hud
var _touch
var _pup := {}                    # 싸울 사람 → 인형
var _dead_t := {}                 # 쓰러진 조직원 → 지난 프레임
var _n_pup := 0
var _end_t := -1                  # 끝난 뒤 지난 프레임(-1 = 아직 싸우는 중)
var _fr_n := 0
var _fr_t0 := 0
var _fps: Array = []              # 1초마다 직접 센 fps
var _title := ""
var _pick: Control = null         # 간부 고르기 창(열린 동안 판이 멈춘다)
var _ctrl_id := ""                # 지금 조종 간부 id(다음 구간에도 같은 간부로)


## opts: auto(봇이 조종 — 자동 플레이 보기) · ctrl(조종할 간부 id) · title(시작 알림 글) · section(위 표시 — 예 '입구 1/3') ·
##       theme(방 — data/game/fight.json rooms) · pick(내 간부가 둘 이상이면 시작 전에 조종할 간부를 고른다 — FR-409)
func start(t: Dictionary, need: Dictionary, opts := {}) -> void:
	_t = t
	_auto = bool(opts.get("auto", false))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ScreenMode.apply(get_window(), true)
	_hud = Hud.new()
	add_child(_hud)
	_touch = Touch.new()
	add_child(_touch)
	_touch.show_pause = true
	_evfx = EventFx.new()
	_evfx.hud = _hud
	var snd = Sound.new()                             # 효과음(FR-414 · 창 없는 점검에서는 내지 않는다)
	add_child(snd)
	snd.setup(DisplayServer.get_name() == "headless")
	_evfx.snd = snd
	_build(need, opts)


## 다음 구간(FR-408) — 가로 화면 · 위 표시 · 터치는 그대로 두고 방과 사람만 새로 세운다(자동 · 조종 간부는 이어진다)
func next(need: Dictionary, opts := {}) -> void:
	var o := opts.duplicate()
	o["auto"] = _auto
	if not o.has("ctrl"):
		o["ctrl"] = _ctrl_id
	_build(need, o)


## 닫기 — 세로로 되돌린다(부르는 쪽이 finished 를 받은 뒤 부르고 이 장면을 지운다)
func close() -> void:
	_d = {}
	ScreenMode.apply(get_window(), false)


func _build(need: Dictionary, opts: Dictionary) -> void:
	_title = String(opts.get("title", ""))
	_d = Section.make(_t, need, {"ctrl": String(opts.get("ctrl", "")), "by": "auto" if _auto else "direct"})
	if _world != null:
		_world.queue_free()
	_pup = {}
	_dead_t = {}
	_n_pup = 0
	_end_t = -1
	_paused = false
	_world = Node3D.new()
	add_child(_world)
	move_child(_world, 0)
	var room = Room.new()
	_world.add_child(room)
	room.build(String(opts.get("theme", "office")), _d["world"].bounds, DisplayServer.get_name() != "headless")
	_fx = Fx.new()
	_world.add_child(_fx)
	_cam = Cam.new()
	_world.add_child(_cam)
	_cam.current = true
	_hud.bar_points = _d["rules"].bar_points()
	_hud.section_text = String(opts.get("section", ""))
	_hud.clear_messages()
	_touch.show_swap = _d["mine"].size() > 1
	_touch.set_label("menu", "직접" if _auto else "자동")
	_evfx.fx = _fx
	_evfx.cam = _cam
	_evfx.pup = _pup
	_sync_puppets()
	_markers()
	var at := _lead_pos()
	_cam.snap(at, at + Vector3(2.0, 0, 0))
	if _title != "":
		_hud.message(_title, "자동 플레이" if _auto else "", 1.6)
	if bool(opts.get("pick", false)) and not _auto and _d["mine"].size() > 1:
		_open_pick()
	print("FIGHT open %d" % int(need.get("i", 0)))


## 간부 고르기 — 이 구간에 선 내 간부(체력 · 등급)를 단추로 보이고, 누른 간부를 조종한다. 고를 동안 판은 멈춘다
func _open_pick() -> void:
	_pick = PanelContainer.new()
	add_child(_pick)
	_pick.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var box := VBoxContainer.new()
	_pick.add_child(box)
	var head := Label.new()
	head.text = "조종할 간부"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var row := HBoxContainer.new()
	box.add_child(row)
	for p in Section.party(_d):
		if p["down"]:
			continue
		var b := Button.new()
		b.text = "%s\n%s · 체력 %d" % [p["name"], p["rank"], int(p["hp"])]
		b.custom_minimum_size = Vector2(200, 96)
		b.pressed.connect(func() -> void: _picked(String(p["id"])))
		row.add_child(b)
	_pick.reset_size()
	_pick.position = (get_viewport_rect().size - _pick.size) * 0.5


func _picked(id: String) -> void:
	Section.set_ctrl(_d, id)
	_d["world"].events.clear()
	_ctrl_id = id
	if _pick != null:
		_pick.queue_free()
		_pick = null
	_markers()
	_touch.take_edges()


## 지금 판(시험 · 스크린샷이 읽는다)
func section() -> Dictionary:
	return _d


func _look_name(f) -> String:
	if f.is_mob:
		var looks: Array = Build.troop_role(_t, f.rank)["look"]
		return String(looks[_n_pup % looks.size()])
	return String(Build.role_of(_t, f.char_id)["look"])


## 판에 새로 선 사람의 인형을 만들고(채워 들어온 조직원), 쓰러진 지 오래된 조직원 인형은 치운다
func _sync_puppets() -> void:
	for f in _d["world"].fighters:
		if _pup.has(f) or _dead_t.get(f, 0) > CORPSE_T:
			continue
		var lname := _look_name(f)
		var p
		if lname != "" and ResourceLoader.exists(str(Looks.art_of(lname).get("glb", ""))):
			p = PuppetGlb.new()
			lname += "_a"
		else:
			p = Puppet.new()
		_world.add_child(p)
		p.setup(Looks.look(lname if lname != "" else "guard"))
		p.update_from(f, 0.0, false)
		_pup[f] = p
		_n_pup += 1
	for f in _pup.keys():
		if f.is_mob and not f.alive():
			_dead_t[f] = int(_dead_t.get(f, 0)) + 1
			if _dead_t[f] > CORPSE_T:
				_pup[f].queue_free()
				_pup.erase(f)


## 발밑 고리 — 조종 간부 하늘색 · 내 다른 간부 흐린 파랑
func _markers() -> void:
	for f in _pup:
		var col = null
		if f.alive() and _d["mine"].has(f):
			col = COL_CTRL if f == _d["hero"] else COL_MINE
		_pup[f].set_marker(col)


func _lead_pos() -> Vector3:
	var h = _d["hero"]
	if h != null:
		return Vector3(h.pos.x, 0, h.pos.y)
	return Vector3.ZERO


func _intent() -> Dictionary:
	var e: Dictionary = _touch.take_edges()
	var h = _d["hero"]
	var tg = h.target() if h != null else null
	return {
		"move": _touch.stick.limit_length(1.0) if _touch.stick.length() > 0.12 else Vector2.ZERO,
		"face": h.dir_to(tg) if tg != null else Vector2.ZERO,
		"attack": e.has("attack"), "parry": e.has("parry"), "parry_held": _touch.held("parry"),
		"roll": e.has("roll"), "dash": e.has("dash"), "skill": e.has("skill"), "skill_next": e.has("skill_next"),
		"swap": e.has("swap"),
	}


func set_paused(on: bool) -> void:
	if _end_t >= 0 or _paused == on:
		return
	_paused = on
	_hud.clear_messages()
	if on:
		_hud.message("멈춤", "아무 데나 누르면 계속 · 뒤로 한 번 더 = 그만두기", 3600.0)
	_touch.take_edges()


## 뒤로 버튼 — 멈춤 → 한 번 더 누르면 그만두기(봇이 이 구간을 빨리 감아 끝낸다 · 전투를 무르지 않는다)
func back() -> void:
	if _pick != null:
		_picked(_d["hero"].char_id if _d["hero"] != null else "")
		return
	if _end_t >= 0:
		_finish()
	elif not _paused:
		set_paused(true)
	else:
		_paused = false
		_hud.clear_messages()
		_auto = true
		Section.run(_d)
		_d["world"].events.clear()
		_over()


func _physics_process(_dt: float) -> void:
	if _d.is_empty() or _pick != null:
		return
	if _end_t >= 0:
		_end_t += 1
		if _end_t > END_WAIT or (_end_t > 45 and _touch.any_touch()):
			_finish()
		return
	if _paused:
		if not _touch.take_edges().is_empty():
			set_paused(false)
		return
	if _touch.take_edge("pause"):
		set_paused(true)
		return
	if _touch.take_edge("speed"):
		_speed_i = (_speed_i + 1) % SPEEDS.size()
		_touch.set_speed_label("×%d" % SPEEDS[_speed_i])
	if _touch.take_edge("menu"):
		_auto = not _auto
		_d["by"] = "auto" if _auto else "direct"
		_touch.set_label("menu", "직접" if _auto else "자동")
	for i in SPEEDS[_speed_i]:
		var it = null
		if not _auto and i == 0:
			it = _intent()
		elif not _auto:
			it = {"move": _touch.stick.limit_length(1.0), "parry_held": _touch.held("parry")}
		Section.step(_d, it)
		_after_tick()
		if _d["over"] != "":
			break


## 한 프레임 판정 뒤: 새로 선 사람의 인형 · 신호 → 연출 · 고리 · 끝
func _after_tick() -> void:
	var w = _d["world"]
	_sync_puppets()
	var changed: bool = w.events.any(func(e): return e[0] == "swap" or e[0] == "ko")
	_evfx.apply(_d)
	w.events.clear()
	if changed:
		_markers()
		_touch.show_swap = _d["mine"].filter(func(f): return f.alive()).size() > 1
	if _d["over"] != "":
		_over()


func _over() -> void:
	if _end_t >= 0:
		return
	_end_t = 0
	var s := Section.summary(_d)
	_hud.clear_messages()
	_hud.message("이겼다" if _d["over"] == "win" else "졌다", "쓰러뜨림 %d · 걸린 시간 %d초" % [int(s["kills"][0 if int(_d["side"]) == 0 else 1]),
		int(_d["frames"]) / 60], 3600.0)
	print("FIGHT over %s" % _d["over"])


func _finish() -> void:
	if _d.is_empty():
		return
	var out: Dictionary = Section.outcome(_d)
	var s: Dictionary = Section.summary(_d)
	s["fps"] = fps_stats()
	print("FIGHT_FPS avg=%d min=%d n=%d" % [s["fps"]["avg"], s["fps"]["min"], s["fps"]["n"]])
	_ctrl_id = _d["hero"].char_id if _d["hero"] != null else _ctrl_id
	_d = {}
	finished.emit(out, s)


## 1초마다 센 전투 화면 fps — {"avg", "min", "n"(초)}
func fps_stats() -> Dictionary:
	if _fps.is_empty():
		return {"avg": 0, "min": 0, "n": 0}
	var sum := 0
	for v in _fps:
		sum += int(v)
	return {"avg": int(round(float(sum) / _fps.size())), "min": int(_fps.min()), "n": _fps.size()}


func _process(dt: float) -> void:
	if _d.is_empty():
		return
	var us := Time.get_ticks_usec()
	_fr_n += 1
	if _fr_t0 == 0:
		_fr_t0 = us
	elif us - _fr_t0 >= 1000000:
		if not _paused and _end_t < 0:
			_fps.append(int(round(_fr_n * 1000000.0 / (us - _fr_t0))))
		_fr_n = 0
		_fr_t0 = us
	var w = _d["world"]
	var frozen: bool = w.hitstop > 0 and not _paused
	if not _paused:
		_evfx.tick_later(dt)
		for f in _pup:
			_pup[f].update_from(f, dt, frozen)
	var lead := _lead_pos()
	var pts: Array = []
	for f in _pup:
		if f.alive():
			pts.append(_pup[f].position)
	_cam.follow_group(lead, pts, dt, w.shake)
	var h = _d["hero"]
	_hud.hero = h
	_hud.party = Section.party(_d)
	_hud.hero_name = h.name if h != null else ""
	_hud.auto = _auto
	var mine := int(_d["side"])
	_hud.heads = [Section.heads(_d, mine), Section.heads(_d, 1 - mine)]
	_hud.morale = [int(_d["morale"][mine]), int(_d["morale"][1 - mine])]
	var cap: int = int(_t["combat"]["raid"]["tick_cap"]) * int(_t["fight"]["tick_frames"])
	_hud.secs_left = (cap - int(_d["fight_t"])) / 60
	var st := fps_stats()
	_hud.fps_text = "fps %d(평균 %d · 최저 %d)" % [int(_fps.back()), st["avg"], st["min"]] if st["n"] > 0 else ""
	if h != null and not h.moveset.is_empty():
		var shape := str(Moves.get_move(str(h.moveset.get("combo", "kf_jab")))["shape"])
		_touch.set_label("attack", "베기" if shape.begins_with("slash") or shape.begins_with("thrust") else "치기")
