extends PanelContainer
## 전투 화면 — 보고의 습격 기록 하나를 재생한다(08 4-1 '화면' · 9절). 세로: 위 = 적 · 아래 = 우리(내가 지키는 쪽이면 뒤집음).
## 장면은 View.battle_frames(순수 함수)가 만든다 — 이 장면은 그리기 · 재생(배속 ×1 · ×2 · ×4 · 건너뛰기 = 다음 구간 · 결과만)만 한다(ISP).
## 일기토 장면은 두 사람 초상(마주 봄 · VS) · 이름 · 체력 막대 · 낸 카드. 인물은 초상 일러스트 Sprites.box(없으면 이름 첫 글자). 색 · 글꼴은 테마(ui/theme.tres)만 쓴다.
## 닫으면 closed. 요구: FR-310 · 설계: docs/C3_설계서_습격과일기토.md 6절

const View = preload("res://ui/view.gd")
const STEP_SEC := 0.7
const SPEEDS := [1, 2, 4]

signal closed

var _frames: Array = []
var _i := 0
var _acc := 0.0
var _speed_i := 0
var _flip := false
var _playing := false
var _title: Label
var _top_name: Label
var _top_bar: ProgressBar
var _top_figs: HBoxContainer
var _secs: Array = []
var _duel: VBoxContainer
var _duel_a: Label
var _duel_b: Label
var _hp_a: ProgressBar
var _hp_b: ProgressBar
var _line: Label
var _bot_name: Label
var _bot_bar: ProgressBar
var _bot_figs: HBoxContainer
var _speed: Button
var close_button: Button
var skip_button: Button
var end_button: Button
var _max := [1, 1]
var _sprites = null
var _pic := [null, null]          # 일기토 초상 칸 [a(아래), b(위)]
var _pic_id := ["", ""]


func _ready() -> void:
	theme_type_variation = "SheetPanel"
	var col := VBoxContainer.new()
	add_child(col)
	_title = _label("", "CardTitle")
	col.add_child(_title)
	_top_name = _label("", "SmallLabel")
	col.add_child(_top_name)
	_top_figs = HBoxContainer.new()
	col.add_child(_top_figs)
	_top_bar = ProgressBar.new()
	_top_bar.theme_type_variation = "FoeBar"
	_top_bar.show_percentage = false
	_top_bar.custom_minimum_size = Vector2(0, 34)
	col.add_child(_top_bar)
	var secs := HBoxContainer.new()
	secs.alignment = BoxContainer.ALIGNMENT_CENTER
	for n in View.SECTION:
		var l := _label(n, "SmallLabel")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		secs.add_child(l)
		_secs.append(l)
	col.add_child(secs)
	_duel = VBoxContainer.new()
	_duel.add_theme_constant_override("separation", 6)
	_duel_b = _label("", "SmallLabel")
	_hp_b = ProgressBar.new()
	_hp_b.theme_type_variation = "FoeBar"
	_hp_b.show_percentage = false
	_hp_b.custom_minimum_size = Vector2(0, 30)
	_duel_a = _label("", "SmallLabel")
	_hp_a = ProgressBar.new()
	_hp_a.show_percentage = false
	_hp_a.custom_minimum_size = Vector2(0, 30)
	_duel.add_child(_duel_row(_duel_b, _hp_b, 1, false))
	var vs := _label("VS", "NameLabel")
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_duel.add_child(vs)
	_duel.add_child(_duel_row(_duel_a, _hp_a, 0, true))
	col.add_child(_duel)
	_line = _label("", "SmallLabel")
	_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS   # 줄 바꿈은 쓰지 않는다 — 폭이 정해지기 전 최소 높이가 커져 아래가 밀려난다
	_line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_line)
	_bot_bar = ProgressBar.new()
	_bot_bar.show_percentage = false
	_bot_bar.custom_minimum_size = Vector2(0, 34)
	col.add_child(_bot_bar)
	_bot_figs = HBoxContainer.new()
	col.add_child(_bot_figs)
	_bot_name = _label("", "SmallLabel")
	col.add_child(_bot_name)
	var row := HBoxContainer.new()
	_speed = _button("×1", func() -> void:
		_speed_i = (_speed_i + 1) % SPEEDS.size()
		_speed.text = "×%d" % SPEEDS[_speed_i])
	skip_button = _button("건너뛰기", _skip_section)
	end_button = _button("결과만", func() -> void: _show(_frames.size() - 1))
	for b in [_speed, skip_button, end_button]:
		row.add_child(b)
	col.add_child(row)
	close_button = _button("닫기", func() -> void:
		_playing = false
		closed.emit())
	col.add_child(close_button)


## rec = 보고 battles 한 줄 · me = 내 조직 · sprites = ui/sprites.gd(없으면 null)
func show_battle(rec: Dictionary, t: Dictionary, me: String, sprites) -> void:
	_frames = View.battle_frames(rec, t)
	_sprites = sprites
	_pic_id = ["", ""]
	_flip = rec["def"] == me and rec["att"] != me
	var att_name := "[%s] %s" % [View.mark(t, rec["att"]), View.org_name(t, rec["att"])]
	var def_name := "[%s] %s" % [View.mark(t, rec["def"]), View.org_name(t, rec["def"])] if rec["def"] != "" else "주인 없음"
	_title.text = "%s 습격" % View.zone_name(t, rec["zone"])
	_top_name.text = att_name if _flip else def_name
	_bot_name.text = def_name if _flip else att_name
	var att_ids: Array = rec["by"]
	var def_ids: Array = rec.get("def_officers", []) + rec.get("reinforce", [])
	_figs(_top_figs, att_ids if _flip else def_ids, t, sprites)
	_figs(_bot_figs, def_ids if _flip else att_ids, t, sprites)
	_max = [1, 1]
	for f in _frames:
		_max = [maxi(_max[0], int(f["att"])), maxi(_max[1], int(f["def"]))]
	_speed_i = 0
	_speed.text = "×1"
	_show(0)
	_playing = true


## 스크린샷용 — 재생을 멈추고 첫 일기토 장면(없으면 끝 장면)에 둔다
func hold_at_first_duel() -> void:
	_playing = false
	for k in _frames.size():
		if not _frames[k]["duel"].is_empty():
			_show(k)
			return
	_show(_frames.size() - 1)


func _process(dt: float) -> void:
	if not _playing or not visible or _frames.is_empty():
		return
	_acc += dt * SPEEDS[_speed_i]
	if _acc >= STEP_SEC:
		_acc = 0.0
		if _i < _frames.size() - 1:
			_show(_i + 1)
		else:
			_playing = false


func _skip_section() -> void:
	var cur: int = int(_frames[_i]["sec"]) if not _frames.is_empty() else -1
	for k in range(_i + 1, _frames.size()):
		if int(_frames[k]["sec"]) != cur:
			_show(k)
			return
	_show(_frames.size() - 1)


func _show(k: int) -> void:
	if _frames.is_empty():
		return
	_i = clampi(k, 0, _frames.size() - 1)
	var f: Dictionary = _frames[_i]
	var ours := [int(f["att"]), _max[0], int(f["am"])]
	var theirs := [int(f["def"]), _max[1], int(f["dm"])]
	if _flip:
		var tmp := ours
		ours = theirs
		theirs = tmp
	_top_bar.max_value = theirs[1]
	_top_bar.value = theirs[0]
	_bot_bar.max_value = ours[1]
	_bot_bar.value = ours[0]
	for n in _secs.size():
		_secs[n].text = ("▶ " if n == int(f["sec"]) else "") + View.SECTION[n]
	var d: Dictionary = f["duel"]
	_duel.visible = not d.is_empty()
	if not d.is_empty():
		_duel_b.text = "%s — %s\n체력 %d / %d" % [d["b_name"], d["cards"][1], int(d["hp"][1]), int(d["max"][1])]
		_duel_a.text = "%s — %s\n체력 %d / %d" % [d["a_name"], d["cards"][0], int(d["hp"][0]), int(d["max"][0])]
		_set_pic(1, d["b"], d["b_name"])
		_set_pic(0, d["a"], d["a_name"])
		_hp_b.max_value = int(d["max"][1])
		_hp_b.value = int(d["hp"][1])
		_hp_a.max_value = int(d["max"][0])
		_hp_a.value = int(d["hp"][0])
	var heads := "우리 %d명 · 사기 %d / 적 %d명 · 사기 %d" % [ours[0], ours[2], theirs[0], theirs[2]] if int(f["sec"]) >= 0 else ""
	_line.text = "%s\n%s%s(%d / %d)" % [f["text"], heads, " · " if heads != "" else "", _i + 1, _frames.size()]


func _figs(box: HBoxContainer, ids: Array, t: Dictionary, sprites) -> void:
	for ch in box.get_children():
		ch.queue_free()
	for id in ids:
		if sprites != null:
			var r: Control = sprites.box(id, View.person(t, id), 96)
			r.tooltip_text = View.person(t, id)
			box.add_child(r)
		else:
			box.add_child(_label(View.person(t, id).left(1), "CardTitle"))


## 일기토 한 사람 줄 — 초상(칸 _pic[k]) + 이름 · 카드 · 체력 막대. pic_right = 초상을 오른쪽에(아래 사람)
func _duel_row(name: Label, bar: ProgressBar, k: int, pic_right: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var pic := HBoxContainer.new()
	pic.custom_minimum_size = Vector2(96, 96)
	_pic[k] = pic
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(name)
	v.add_child(bar)
	if pic_right:
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(v)
		row.add_child(pic)
	else:
		row.add_child(pic)
		row.add_child(v)
	return row


func _set_pic(k: int, id: String, who: String) -> void:
	if _pic_id[k] == id or _sprites == null:
		return
	_pic_id[k] = id
	for ch in _pic[k].get_children():
		ch.queue_free()
	var b: Control = _sprites.box(id, who, 96)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pic[k].add_child(b)


func _label(text: String, variation: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(1, 0)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "TabButton"
	b.custom_minimum_size = Vector2(0, 130)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b
