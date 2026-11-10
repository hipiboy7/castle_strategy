extends Control
## C1-0 화면 — 주(턴) · 지금 상태 해시 · 자가 해시(시드 1 · 26주) · '다음 주' 버튼. 세로 · 안전 영역 · 접기/펴기 때 다시 배치.
## 판정은 sim/ 이 하고, 이 장면은 보여 주고 명령('다음 주')만 낸다(CLAUDE.md 2절). 설계: docs/C1_설계서_상태와턴.md 8절 · 요구: FR-107
## 로그 줄(CI scripts/emu_check.sh · verify 화면 단계가 읽는다): APP ready · SELFHASH <16자> · TURN <주> · APP hide|show · FPS_LOG

const Stub = preload("res://sim/stub_turn.gd")
const StateHash = preload("res://sim/hash.gd")
const Layout = preload("res://ui/layout.gd")
const Storage = preload("res://src/storage.gd")

const SAVE := "user://save_auto.json"
const SELF_SEED := 1
const SELF_TURNS := 26
const BUTTON_MIN_H := 160          # 기준 화면 단위 — 폰(약 2.6px/dp)에서 48dp 이상
const SIDES := ["margin_left", "margin_top", "margin_right", "margin_bottom"]

var version := "0.0.0"
var common_sha := ""
var state: Dictionary = {}
var _margin: MarginContainer
var _mid: BoxContainer
var _week: Label
var _hash: Label
var _self: Label
var _status: Label
var _confirm: ConfirmationDialog
var _fps_t := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var text := Storage.read_text(SAVE)
	if text != "":
		state = Stub.from_dict(JSON.parse_string(text))
	var resumed := not state.is_empty()
	if not resumed:
		state = Stub.new_state(SELF_SEED)
	_build()
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	_refresh()
	var self_hash := StateHash.of(Stub.run(SELF_SEED, SELF_TURNS))
	_self.text = "자가 해시 (시드 %d · %d주)\n%s" % [SELF_SEED, SELF_TURNS, self_hash]
	print("APP ready resumed=%s" % resumed)
	print("SELFHASH " + self_hash)


func _build() -> void:
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var col := VBoxContainer.new()
	_margin.add_child(col)
	col.add_child(_label("캐슬 제패", "TitleLabel"))
	var info := _label("판 %s · C1-0 기술 검증 · castle_common %s" % [version, common_sha if common_sha != "" else "받기 전"], "SmallLabel")
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(info)
	col.add_child(_spacer())
	_mid = BoxContainer.new()
	_mid.vertical = true
	_mid.add_theme_constant_override("separation", 28)
	col.add_child(_mid)
	_week = _label("", "BigLabel")
	_hash = _label("", "SmallLabel")
	_mid.add_child(_panel([_week, _hash]))
	_self = _label("", "SmallLabel")
	_self.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mid.add_child(_panel([_self]))
	col.add_child(_spacer())
	_status = _label("", "SmallLabel")
	col.add_child(_status)
	var next := Button.new()
	next.text = "다음 주"
	next.custom_minimum_size = Vector2(0, BUTTON_MIN_H)
	next.pressed.connect(_on_next)
	col.add_child(next)
	_confirm = ConfirmationDialog.new()
	_confirm.dialog_text = "끝낼까요?"
	_confirm.ok_button_text = "끝내기"
	_confirm.cancel_button_text = "계속"
	_confirm.confirmed.connect(func() -> void: get_tree().quit())
	add_child(_confirm)


## 안전 영역 여백 + 테마 여백 · 넓은 화면(폴드 안쪽)이면 가운데 묶음을 가로로
func _relayout() -> void:
	var view := get_viewport_rect().size
	var ins := Vector4.ZERO
	if OS.get_name() == "Android":
		ins = Layout.insets_from(view, DisplayServer.window_get_size(), DisplayServer.window_get_position(),
			DisplayServer.get_display_safe_area())
	for i in SIDES.size():
		_margin.add_theme_constant_override(SIDES[i], get_theme_constant(SIDES[i], "MarginContainer") + int(ins[i]))
	_mid.vertical = not Layout.is_wide(view)


func _on_next() -> void:
	state = Stub.step(state)
	_status.text = "" if Storage.write_text(SAVE, StateHash.canonical(state)) else "저장하지 못했다"
	print("TURN %d" % int(state["turn"]))
	_refresh()


func _refresh() -> void:
	_week.text = "%d주" % int(state["turn"])
	_hash.text = "상태 해시 " + StateHash.of(state)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _confirm.visible:
			_confirm.hide()
		else:
			_confirm.popup_centered()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		Storage.write_text(SAVE, StateHash.canonical(state))
		print("APP hide")
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		print("APP show")
		_relayout()


func _process(_dt: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _fps_t >= 10000:
		_fps_t = now
		print("FPS_LOG fps=%d" % Engine.get_frames_per_second())


func _label(text: String, variation: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	return l


func _panel(children: Array) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	p.add_child(v)
	for c in children:
		v.add_child(c)
	return p


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s
