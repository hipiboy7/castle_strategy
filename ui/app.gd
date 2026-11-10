extends Control
## C2 화면 — 상태 기계(loading · play · report · over · error)와 부품 연결만 한다. 판정 · 미리 보기는 sim/(game · draft), 보기 계산은
## ui/view.gd · layout.gd · map_layout.gd(순수)가 하고, 이 장면은 그것을 부품(지도 · 구역 카드 · 간부 줄 · 명령 고르기 · 보고 · 탭)에
## 넘기고 누름을 받는다(CLAUDE.md 2절 ISP). 화면 상태(탭 · 고른 구역 · 고른 간부 · 열린 판)는 여기만 들고, 배치가 바뀌어도 남는다.
## 틀: 위 막대 / 몸통(좁음 = 탭 내용 · 넓음 = 지도 + 옆 패널) / 간부 줄 / 행동 줄(맡기기 · 주 끝내기) / 아래 탭 6 — Layout.frame.
## 저장: 대기 명령이 바뀔 때 · 주 끝내기 · 백그라운드 → user://save_auto.json(저장 v1 + pending). --shot 이면 읽지도 쓰지도 않는다.
## 로그 줄(CI scripts/emu_check.sh · verify 가 읽는다): APP ready · SELFHASH <16자> · TURN <주> · REPORT <주> · APP hide|show ·
##   FPS_LOG · PERF boot_ms · turn_ms · fps · UI <이름> <x> <y>(창 화소 가운데 — 에뮬레이터가 누른다)
## 설계: docs/C2_설계서_화면과명령.md 3 · 4 · 6 · 7절 · 요구: FR-201~214 · 217 · 219 (C1 화면 ui/home.gd 를 바꿈)

const Game = preload("res://sim/game.gd")
const Draft = preload("res://sim/draft.gd")
const Save = preload("res://sim/save.gd")
const State = preload("res://sim/state.gd")
const DataFiles = preload("res://src/data_files.gd")
const Storage = preload("res://src/storage.gd")
const Layout = preload("res://ui/layout.gd")
const View = preload("res://ui/view.gd")
const Sprites = preload("res://ui/sprites.gd")
const MapView = preload("res://ui/map_view.gd")
const ZoneCard = preload("res://ui/zone_card.gd")
const OfficerStrip = preload("res://ui/officer_strip.gd")
const OrderPicker = preload("res://ui/order_picker.gd")
const ReportView = preload("res://ui/report_view.gd")
const Pages = preload("res://ui/tab_pages.gd")

const SAVE := "user://save_auto.json"
const BROKEN := "user://save_auto.broken.json"
const SCENARIO := "A"
const SELF_SEED := 1
const SELF_TURNS := 26
const TABS := [["map", "지도"], ["org", "조직"], ["orders", "명령"], ["diplo", "외교"], ["council", "원탁"], ["log", "기록"]]
const SOON := {"diplo": "외교(동맹 · 불가침 · 거래 · 상납)는 C4 에서 열린다.", "council": "원탁(지분 · 회의 · 교류회)은 C5 에서 열린다."}

var version := "0.0.0"
var common_sha := ""
var args: Dictionary = {}              # src/launch.gd 결과(main 이 넘긴다)

var _t: Dictionary = {}
var _g: Dictionary = {}
var _draft: Array = []
var _sprites = null
var _phase := "loading"
var _note := ""
var _tab := "map"
var _zone := ""
var _officer := ""
var _sheet := ""                       # "" · pick · report
var _pick := ["", ""]                  # 고르기 창의 [간부, 구역]
var _report_i := -1
var _ephemeral := false
var _resumed := false
var _self_hash := ""
var _boot_ms := 0
var _turn_ms := 0
var _fps_t := 0
var _wide := false

var _top: PanelContainer
var _week: Label
var _cash: Label
var _acts: Label
var _map
var _card
var _strip
var _picker
var _report
var _actions: HBoxContainer
var _hint: Label
var _auto: Button
var _end: Button
var _tabbar: HBoxContainer
var _tab_btn := {}
var _pages := {}
var _confirm: ConfirmationDialog
var _confirm_end: ConfirmationDialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ephemeral = String(args.get("shot", "")) != ""
	_t = DataFiles.load_tables()
	_sprites = Sprites.new()
	_build()
	if not _t["errors"].is_empty():
		_phase = "error"
		_note = "데이터 오류 %d건 — %s" % [_t["errors"].size(), _t["errors"][0]]
	else:
		_open_game()
		_self_hash = Game.autoplay(_t, SCENARIO, SELF_SEED, SELF_TURNS)["hash"]
		if _ephemeral:
			_setup_shot()
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	_refresh()
	_boot_ms = Time.get_ticks_msec()
	print("APP ready resumed=%s" % _resumed)
	print("SELFHASH " + _self_hash)
	_perf()


## 저장이 있으면 이어 하고(대기 명령 · 보고 다시 만들기), 깨졌으면 broken 으로 옮기고 새 판, 없으면 새 판
func _open_game() -> void:
	var text := "" if _ephemeral else Storage.read_text(SAVE)
	if text != "":
		var r: Dictionary = Save.from_text(text, _t)
		if r["errors"].is_empty():
			_g = Game.from_save(r["save"], _t)
		if not r["errors"].is_empty() or not _g.get("errors", []).is_empty():
			var why: Array = r["errors"] if not r["errors"].is_empty() else _g["errors"]
			DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE), ProjectSettings.globalize_path(BROKEN))
			_note = "저장을 읽지 못해 새 판으로 엽니다 — %s" % str(why[0])
			_g = {}
		else:
			_resumed = true
			var notes: Array = r["notes"].duplicate()
			var rb: Dictionary = Game.rebuild_reports(_t, r["save"])
			_g["reports"] = rb["reports"]
			if not rb["same"]:
				notes.append("다시 돌린 해시가 저장과 다르다(보고만 다를 수 있음)")
			_draft = r["save"].get("pending", [])
			_note = ("저장 알림: " + ", ".join(notes)) if not notes.is_empty() else "이어 하기 — %d주" % int(_g["state"]["turn"])
	if _g.is_empty():
		_g = Game.new_game(_t, SCENARIO, int(args.get("seed", SELF_SEED)) if _ephemeral else SELF_SEED)
	_phase = "over" if _over() else "play"


## 스크린샷 장면(--view · --week · --zone) — 맡기기로 week−1 주를 둔 뒤 그 장면을 연다(report 는 적어도 한 주)
func _setup_shot() -> void:
	var v: String = args.get("view", "map")
	var weeks := int(args.get("week", 1)) - 1
	if v == "report":
		weeks = maxi(1, weeks)
	for i in weeks:
		if not _over():
			Game.step_player(_g, _t, Draft.auto(_g["state"], _t))
	_phase = "over" if _over() else "play"
	var s: Dictionary = _g["state"]
	var me: String = s["player"]
	var z: String = args.get("zone", "")
	if z == "":
		z = s["orgs"][me]["hq"]
	if v in ["card", "pick"]:
		_zone = z
	elif v in ["org", "orders", "log", "diplo"]:
		_tab = v
	if v in ["orders", "log"]:
		_draft = Draft.auto(s, _t)
	if v == "pick":
		_open_pick(s["orgs"][me]["boss"], z)
	elif v == "report":
		_open_report(_g["reports"].size() - 1)


func _build() -> void:
	_top = PanelContainer.new()
	add_child(_top)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 24)
	_top.add_child(th)
	_week = _label("", "CardTitle")
	th.add_child(_week)
	_cash = _label("", "SmallLabel")
	_cash.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cash.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS      # 줄바꿈 글은 넓이 0 일 때 높이가 커져 막대를 밀어낸다
	th.add_child(_cash)
	_acts = _label("", "Label")
	th.add_child(_acts)

	_map = MapView.new()
	_map.sprites = _sprites
	_map.zone_pressed.connect(_on_zone)
	_map.officer_dropped.connect(_on_drop)
	add_child(_map)

	_pages["org"] = Pages.OrgPage.new()
	_pages["org"].sprites = _sprites
	_pages["orders"] = Pages.OrdersPage.new()
	_pages["orders"].remove_at.connect(_on_remove)
	_pages["orders"].clear_all.connect(_on_clear)
	_pages["log"] = Pages.LogPage.new()
	_pages["log"].open_report.connect(_open_report)
	for k in SOON:
		var p := PanelContainer.new()
		var l := _label(SOON[k], "SmallLabel")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(400, 0)
		p.add_child(l)
		_pages[k] = p
	for k in _pages:
		add_child(_pages[k])

	_card = ZoneCard.new()
	_card.sprites = _sprites
	_card.closed.connect(_close_card)
	add_child(_card)

	_strip = OfficerStrip.new()
	_strip.sprites = _sprites
	_strip.officer_pressed.connect(_on_officer)
	add_child(_strip)

	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 16)
	add_child(_actions)
	_hint = _label("", "TinyLabel")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.max_lines_visible = 2                 # 넓이가 0 일 때 줄바꿈 글이 높이를 키워 줄을 밀어내지 않게(최소 넓이 + 줄 수)
	_hint.custom_minimum_size = Vector2(240, 0)
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_actions.add_child(_hint)
	_auto = Button.new()
	_auto.text = "맡기기"
	_auto.custom_minimum_size = Vector2(250, 0)
	_auto.pressed.connect(_on_auto)
	_actions.add_child(_auto)
	_end = Button.new()
	_end.text = "주 끝내기"
	_end.custom_minimum_size = Vector2(330, 0)
	_end.pressed.connect(_on_end)
	_actions.add_child(_end)

	_picker = OrderPicker.new()
	_picker.picked.connect(_on_picked)
	_picker.cancelled.connect(_close_sheet)
	add_child(_picker)
	_report = ReportView.new()
	_report.closed.connect(_close_sheet)
	add_child(_report)

	_tabbar = HBoxContainer.new()
	_tabbar.add_theme_constant_override("separation", 8)
	add_child(_tabbar)
	var group := ButtonGroup.new()
	for tab in TABS:
		var b := Button.new()
		b.text = tab[1]
		b.theme_type_variation = "TabButton"
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_tab.bind(tab[0]))
		_tabbar.add_child(b)
		_tab_btn[tab[0]] = b

	_confirm = _dialog("끝낼까요?", "끝내기", "계속")
	_confirm.confirmed.connect(func() -> void: get_tree().quit())
	_confirm_end = _dialog("대기 명령이 없습니다. 명령 없이 주를 끝낼까요?", "끝내기", "돌아가기")
	_confirm_end.confirmed.connect(_end_week)


func _dialog(text: String, ok: String, cancel: String) -> ConfirmationDialog:
	var d := ConfirmationDialog.new()
	d.dialog_text = text
	d.ok_button_text = ok
	d.cancel_button_text = cancel
	add_child(d)
	return d


## 틀 다시 놓기 — 크기가 바뀔 때(접기 · 펴기) · 탭 · 카드 · 판이 바뀔 때. 화면 상태는 그대로 둔다
func _relayout() -> void:
	var view := get_viewport_rect().size
	var ins := Vector4.ZERO
	if OS.get_name() == "Android":
		ins = Layout.insets_from(view, DisplayServer.window_get_size(), DisplayServer.window_get_position(),
			DisplayServer.get_display_safe_area())
	var m := {}
	for k in ["margin", "gap", "top_h", "strip_h", "actions_h", "tabs_h", "side_min"]:
		m[k] = get_theme_constant(k, "Frame")
	m["side_ratio"] = get_theme_constant("side_pct", "Frame") / 100.0
	m["sheet_ratio"] = get_theme_constant("sheet_pct", "Frame") / 100.0
	var f: Dictionary = Layout.frame(view, ins, m, _tab == "map")
	_wide = f["wide"]
	_place(_top, f["top"])
	_place(_tabbar, f["tabs"])
	_place(_actions, f["actions"])
	_strip.visible = f["strip"].size.y > 0.0
	_place(_strip, f["strip"])
	_map.visible = _wide or _tab == "map"
	var covered: bool = not _wide and _tab == "map" and (_zone != "" or _sheet == "pick")
	_place(_map, f["map_above"] if covered else f["map"])
	for k in _pages:
		_pages[k].visible = k == _tab
		_place(_pages[k], f["side"] if _wide else f["body"])
	_card.visible = _tab == "map" and (_wide or _zone != "") and _sheet != "pick"
	_card.set_closable(not _wide)
	_place(_card, f["sheet"])
	_picker.visible = _sheet == "pick"
	_place(_picker, f["sheet"])
	_report.visible = _sheet == "report"
	_place(_report, f["body"])
	for k in _tab_btn:
		_tab_btn[k].set_pressed_no_signal(k == _tab)
	_print_ui.call_deferred()


func _place(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.size = r.size


## 화면 내용 다시 채우기 — 상태 · 대기 명령 · 화면 상태가 바뀔 때
func _refresh() -> void:
	if _phase == "error":
		_week.text = "오류"
		_cash.text = ""
		_acts.text = ""
		_hint.text = _note
		_end.disabled = true
		_auto.disabled = true
		return
	var s: Dictionary = _g["state"]
	var me: String = s["player"]
	var lt: Array = Draft.total_left(s, _t, _draft)
	var top: Dictionary = View.top(s, _t, me, lt[0], lt[1])
	_week.text = top["week"]
	_cash.text = "%s %s · %s" % [View.org_name(_t, me), top["cash"], top["net"]]
	_acts.text = top["actions"]
	_map.selected = _zone
	_map.show_map(_t["map"]["zones"], _t["map"]["links"], View.map_nodes(s, _t, me), View.fronts(s, _t))
	_strip.show_cards(View.officer_cards(s, _t, me, Draft.used(_draft)), _officer)
	if _zone != "":
		_card.show_card(View.zone_card(s, _t, _zone, me))
	else:
		_card.show_empty("구역을 누르면 사업장 · 주둔 · 정보가 여기 뜬다. 간부 카드를 끌어 구역에 놓으면 명령을 고른다.")
	_end.disabled = _phase != "play"
	_auto.disabled = _phase != "play"
	var hint := "간부를 끌어 구역에 놓거나, 간부 → 구역 순으로 누른다"
	if _officer != "":
		hint = "%s — 이제 구역을 누른다" % View.person(_t, _officer)
	elif _phase == "over":
		hint = "끝 — %d주(승패는 C5)" % int(s["length"])
	_hint.text = _note if _note != "" else hint
	_fill_pages(s, me, top)


func _fill_pages(s: Dictionary, me: String, top: Dictionary) -> void:
	_pages["org"].show_org(View.org_panel(s, _t, me))
	var marks: Array = Draft.marks(s, _t, _draft)
	var rows := []
	for i in _draft.size():
		rows.append({"text": View.order_text(_t, _draft[i]), "ok": marks[i]["ok"], "why": marks[i]["why"]})
	_pages["orders"].show_orders(rows, top["actions"] + " 남음")
	_pages["log"].show_log(_g.get("reports", []).map(func(e): return View.report_title(e, me)), _info(s, top))


func _info(s: Dictionary, top: Dictionary) -> String:
	return "판 %s · C2 화면 · castle_common %s\n자가 해시 (%s · 시드 %d · %d주) %s\n상태 해시 %s\n잠정: AI 후보 데이터 · 지도 좌표 · 등급 자리값 %d명\n%s" % [
		version, common_sha if common_sha != "" else "받기 전", SCENARIO, SELF_SEED, SELF_TURNS, _self_hash, State.hash_of(s),
		top["prov"], _perf_text()]


func _on_tab(tab: String) -> void:
	_tab = tab
	if _sheet == "pick":
		_sheet = ""
	_relayout()
	_refresh()


## 구역 누름 — 간부를 골라 두었으면 명령 고르기, 아니면 구역 카드
func _on_zone(z: String) -> void:
	if _officer != "" and _phase == "play":
		_open_pick(_officer, z)
		return
	_zone = z
	_relayout()
	_refresh()


func _on_officer(id: String) -> void:
	_officer = "" if _officer == id else id
	_refresh()


func _on_drop(officer: String, z: String) -> void:
	if _phase == "play":
		_open_pick(officer, z)


func _open_pick(officer: String, z: String) -> void:
	var s: Dictionary = _g["state"]
	_pick = [officer, z]
	_zone = z
	_sheet = "pick"
	var opts: Array = Draft.options(s, _t, _draft, officer, z)
	_picker.show_options("%s → %s" % [View.person(_t, officer), View.zone_name(_t, z)], opts)
	_relayout()
	_refresh()


func _on_picked(order: Dictionary) -> void:
	var r: Dictionary = Draft.add(_g["state"], _t, _draft, order)
	_draft = r["draft"]
	_note = r["why"]
	_officer = ""
	_close_sheet()
	_save()


func _on_auto() -> void:
	if _phase != "play":
		return
	_draft = Draft.auto(_g["state"], _t)
	_note = "맡기기 — 명령 %d개(명령 탭에서 빼거나 고칠 수 있다)" % _draft.size()
	_officer = ""
	_save()
	_refresh()


func _on_remove(i: int) -> void:
	_draft = Draft.remove(_draft, i)
	_note = ""
	_save()
	_refresh()


func _on_clear() -> void:
	_draft = []
	_note = ""
	_save()
	_refresh()


func _on_end() -> void:
	if _phase != "play":
		return
	if _draft.is_empty():
		_confirm_end.popup_centered()
		return
	_end_week()


## 주 끝내기 — 내 조직 = 대기 명령 · 다른 조직 = AI → 저장 → 보고
func _end_week() -> void:
	if _phase != "play":
		return
	var t0 := Time.get_ticks_usec()
	var report: Dictionary = Game.step_player(_g, _t, _draft)
	_turn_ms = int((Time.get_ticks_usec() - t0) / 1000)
	_draft = []
	_officer = ""
	_note = "" if _save() else "저장하지 못했다"
	if not report["violations"].is_empty():
		_note = "불변식 위반: " + str(report["violations"][0])
	print("TURN %d" % int(_g["state"]["turn"]))
	_perf()
	_open_report(_g["reports"].size() - 1)


func _open_report(i: int) -> void:
	if i < 0 or i >= _g.get("reports", []).size():
		return
	var e: Dictionary = _g["reports"][i]
	var me: String = _g["state"]["player"]
	var last: bool = i == _g["reports"].size() - 1
	_report_i = i
	_sheet = "report"
	_phase = "report" if _phase == "play" or _phase == "report" else _phase
	_report.show_report("%d주 보고" % int(e["report"]["turn"]), View.report_cards(e, _t, me),
		"닫기 — %d주로" % int(_g["state"]["turn"]) if last and not _over() else "닫기")
	print("REPORT %d" % int(e["report"]["turn"]))
	_relayout()
	_refresh()


func _close_sheet() -> void:
	if _sheet == "report":
		_phase = "over" if _over() else "play"
	_sheet = ""
	_relayout()
	_refresh()


func _close_card() -> void:
	_zone = ""
	_relayout()
	_refresh()


func _over() -> bool:
	var s: Dictionary = _g["state"]
	return int(s["length"]) > 0 and int(s["turn"]) > int(s["length"])


func _save() -> bool:
	if _ephemeral or _g.is_empty() or not _t["errors"].is_empty():
		return _ephemeral
	var s: Dictionary = _g["state"]
	var meta := {"game_version": version, "castle_common": DataFiles.source_sha(), "seed": s["seed"], "scenario": s["scenario"],
		"player": s["player"], "mode": s["mode"]}
	return Storage.write_text(SAVE, Save.to_text(Save.make(meta, s, _g["log"], _draft)))


## 뒤로 — 열린 것부터 닫고(고르기 · 보고 → 카드 → 고른 간부 → 다른 탭), 다 닫혔으면 '끝낼까요?'
func _back() -> void:
	if _confirm.visible or _confirm_end.visible:
		_confirm.hide()
		_confirm_end.hide()
	elif _sheet != "":
		_close_sheet()
	elif _tab == "map" and _zone != "" and not _wide:
		_close_card()
	elif _officer != "":
		_officer = ""
		_refresh()
	elif _tab != "map":
		_on_tab("map")
	else:
		_confirm.popup_centered()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		_save()
		print("APP hide")
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		print("APP show")
		_relayout()


## 버튼 자리(창 화소 가운데) — 에뮬레이터 점검이 이 값을 눌러 1분 경로를 돈다(FR-218)
func _print_ui() -> void:
	await get_tree().process_frame
	var xf := get_viewport().get_final_transform()
	var at := {"auto": _auto, "end": _end, "close": _report.close_button}
	for k in _tab_btn:
		at["tab_" + k] = _tab_btn[k]
	for i in _picker.buttons.size():
		at["pick_%d" % i] = _picker.buttons[i]
	for k in at:
		var c = at[k]
		if is_instance_valid(c) and c.is_visible_in_tree():
			var p: Vector2 = xf * c.get_global_rect().get_center()
			print("UI %s %d %d" % [k, int(p.x), int(p.y)])


func _perf_text() -> String:
	return "성능: 켜기 %d ms · 마지막 주 처리 %d ms · %d fps" % [_boot_ms, _turn_ms, Engine.get_frames_per_second()]


func _perf() -> void:
	print("PERF boot_ms=%d turn_ms=%d fps=%d" % [_boot_ms, _turn_ms, Engine.get_frames_per_second()])


func _process(_dt: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _fps_t >= 10000:
		_fps_t = now
		print("FPS_LOG fps=%d" % Engine.get_frames_per_second())
		if _tab == "log" and _phase != "error":
			var s: Dictionary = _g["state"]
			_pages["log"].show_log(_g.get("reports", []).map(func(e): return View.report_title(e, s["player"])),
				_info(s, View.top(s, _t, s["player"], 0, 0)))


func _label(text: String, variation: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	return l
