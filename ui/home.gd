extends Control
## C1 화면 — 시나리오 A 를 한 주씩 진행(모든 조직 AI — 플레이어 명령 화면은 C2): 주 · 내 조직 돈 · 상태 해시 · 자가 해시(시드 1 · 26주 —
## 서버 RESULT 와 대조) · '다음 주' 버튼. 세로 · 안전 영역 · 접기/펴기 때 다시 배치. 자동 저장(턴마다 · 백그라운드) → 켤 때 이어 하기.
## 판정은 sim/ 이 하고, 이 장면은 보여 주고 '다음 주'만 낸다(CLAUDE.md 2절). 설계: docs/C1_설계서_상태와턴.md 8절 · 요구: FR-107 · FR-118
## 저장이 깨졌거나 더 새 판이면 지우지 않고 save_auto.broken.json 으로 옮겨 두고 새 판으로 연다(설계서 5절 · 원본을 덮어쓰지 않음).
## 로그 줄(CI scripts/emu_check.sh · verify 화면 단계가 읽는다): APP ready · SELFHASH <16자> · TURN <주> · APP hide|show · FPS_LOG

const Game = preload("res://sim/game.gd")
const Save = preload("res://sim/save.gd")
const State = preload("res://sim/state.gd")
const DataFiles = preload("res://src/data_files.gd")
const Layout = preload("res://ui/layout.gd")
const Storage = preload("res://src/storage.gd")

const SAVE := "user://save_auto.json"
const BROKEN := "user://save_auto.broken.json"
const SCENARIO := "A"
const SELF_SEED := 1
const SELF_TURNS := 26
const BUTTON_MIN_H := 160          # 기준 화면 단위 — 폰(약 2.6px/dp)에서 48dp 이상
const SIDES := ["margin_left", "margin_top", "margin_right", "margin_bottom"]

var version := "0.0.0"
var common_sha := ""
var _t: Dictionary = {}
var _g: Dictionary = {}
var _margin: MarginContainer
var _mid: BoxContainer
var _week: Label
var _money: Label
var _hash: Label
var _self: Label
var _status: Label
var _next: Button
var _confirm: ConfirmationDialog
var _fps_t := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_t = DataFiles.load_tables()
	var note := ""
	var resumed := false
	if _t["errors"].is_empty():
		var text := Storage.read_text(SAVE)
		if text != "":
			var r: Dictionary = Save.from_text(text, _t)
			if r["errors"].is_empty():
				_g = Game.from_save(r["save"], _t)
			if not r["errors"].is_empty() or not _g.get("errors", []).is_empty():
				var why: Array = r["errors"] if not r["errors"].is_empty() else _g["errors"]
				DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE), ProjectSettings.globalize_path(BROKEN))
				note = "저장을 읽지 못해 새 판으로 엽니다 — %s" % str(why[0])
				_g = {}
			else:
				resumed = true
				if not r["notes"].is_empty():
					note = "저장 옮김: " + ", ".join(r["notes"])
		if _g.is_empty():
			_g = Game.new_game(_t, SCENARIO, SELF_SEED)
	_build()
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	var self_hash := ""
	if _t["errors"].is_empty():
		self_hash = Game.autoplay(_t, SCENARIO, SELF_SEED, SELF_TURNS)["hash"]
		_self.text = "자가 해시 (%s · 시드 %d · %d주)\n%s" % [SCENARIO, SELF_SEED, SELF_TURNS, self_hash]
		_status.text = note
		_refresh()
	else:
		_self.text = "데이터 오류 %d건\n%s" % [_t["errors"].size(), _t["errors"][0]]
		_next.disabled = true
	print("APP ready resumed=%s" % resumed)
	print("SELFHASH " + self_hash)


func _build() -> void:
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var col := VBoxContainer.new()
	_margin.add_child(col)
	col.add_child(_label("캐슬 제패", "TitleLabel"))
	var info := _label("판 %s · C1 시뮬 코어 · castle_common %s · 잠정(AI 후보 · 등급 자리값 %d명)" % [version,
		common_sha if common_sha != "" else "받기 전", _provisional()], "SmallLabel")
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(info)
	col.add_child(_spacer())
	_mid = BoxContainer.new()
	_mid.vertical = true
	_mid.add_theme_constant_override("separation", 28)
	col.add_child(_mid)
	_week = _label("", "BigLabel")
	_money = _label("", "SmallLabel")
	_hash = _label("", "SmallLabel")
	_mid.add_child(_panel([_week, _money, _hash]))
	_self = _label("", "SmallLabel")
	_self.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mid.add_child(_panel([_self]))
	col.add_child(_spacer())
	_status = _label("", "SmallLabel")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status)
	_next = Button.new()
	_next.text = "다음 주"
	_next.custom_minimum_size = Vector2(0, BUTTON_MIN_H)
	_next.pressed.connect(_on_next)
	col.add_child(_next)
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
	if _over():
		return
	var report: Dictionary = Game.step(_g, _t)
	_status.text = "" if _save() else "저장하지 못했다"
	if not report["violations"].is_empty():
		_status.text = "불변식 위반: " + str(report["violations"][0])
	print("TURN %d" % int(_g["state"]["turn"]))
	_refresh()


func _refresh() -> void:
	var s: Dictionary = _g["state"]
	var length := int(s["length"])
	_week.text = ("%d주 / %d" % [mini(s["turn"], length), length]) if not _over() else "끝 — %d주" % length
	var me: String = s["player"]
	_money.text = "%s 돈 %d · 사업장 %d" % [_t["factions"][me].get("name", me), s["orgs"][me]["cash"], _slots(s, me)]
	_hash.text = "상태 해시 " + State.hash_of(s)
	_next.disabled = _over()


func _over() -> bool:
	var s: Dictionary = _g["state"]
	return int(s["length"]) > 0 and int(s["turn"]) > int(s["length"])


func _save() -> bool:
	if _g.is_empty() or not _t["errors"].is_empty():
		return false
	var s: Dictionary = _g["state"]
	var meta := {"game_version": version, "castle_common": DataFiles.source_sha(), "seed": s["seed"], "scenario": s["scenario"],
		"player": s["player"], "mode": s["mode"]}
	return Storage.write_text(SAVE, Save.to_text(Save.make(meta, s, _g["log"])))


func _slots(s: Dictionary, org: String) -> int:
	var n := 0
	for z in s["zones"].values():
		n += z["slots"].filter(func(x): return x["org"] == org).size()
	return n


## 등급이 자리값인 간부 수(개발 빌드 잠정 표시 — CLAUDE.md 13절)
func _provisional() -> int:
	if _g.is_empty():
		return 0
	return _g["state"]["officers"].values().filter(func(p): return p["rank_prov"]).size()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _confirm.visible:
			_confirm.hide()
		else:
			_confirm.popup_centered()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		_save()
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
