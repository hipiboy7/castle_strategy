extends PanelContainer
## 구역 카드 — View.zone_card 사전을 그린다: 주인(세력 글자 + 이름) · 사업장 칸 · 거점 · 주둔 간부(초상) · 유동 · 사람 · 경찰 · 내 주 수입 · 잠정.
## 좁은 화면은 지도 아래쪽 판(닫기 단추), 넓은 화면은 옆 패널(닫기 없음). 상태는 바꾸지 않는다(ISP). 요구: FR-203

const View = preload("res://ui/view.gd")

signal closed

var sprites = null
var _title: Label
var _close: Button
var _body: VBoxContainer


func _ready() -> void:
	theme_type_variation = "SheetPanel"
	var col := VBoxContainer.new()
	add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	_title = Label.new()
	_title.theme_type_variation = "CardTitle"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(_title)
	_close = Button.new()
	_close.text = "닫기"
	_close.theme_type_variation = "TabButton"
	_close.custom_minimum_size = Vector2(170, 130)
	_close.pressed.connect(func() -> void: closed.emit())
	head.add_child(_close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)


func set_closable(on: bool) -> void:
	_close.visible = on


## 빈 상태(구역을 고르지 않음)
func show_empty(text: String) -> void:
	_title.text = "구역"
	_clear()
	_body.add_child(_line(text, "SmallLabel"))


func show_card(c: Dictionary) -> void:
	_clear()
	_title.text = "[%s] %s" % [c["mark"], c["name"]]
	_body.add_child(_line("주인 %s%s" % [c["owner_name"], " · 잠정 데이터" if c["provisional"] else ""], "SmallLabel"))
	_body.add_child(_line("유동 %s · 사람 %d · 경찰 %s(%d/3) · 내 주 수입 %s" % [c["flow"], c["people"], c["police"], c["police_lv"],
		View.money(int(c["income_me"]))], "SmallLabel"))
	if not c["facilities"].is_empty():
		_body.add_child(_line("거점 " + " · ".join(c["facilities"]), "SmallLabel"))
	_body.add_child(_line("사업장 %d칸" % c["slots"].size(), "Label"))
	for sl in c["slots"]:
		var txt := ("%s lv%d — [%s] %s%s" % [sl["kind"], sl["lv"], sl["mark"], sl["org_name"], " (내 칸)" if sl["mine"] else ""]) \
			if sl["org"] != "" else "%s — 빈칸(개업할 수 있음)" % sl["kind"]
		var row := PanelContainer.new()
		row.theme_type_variation = "RowPanel"
		row.add_child(_line(txt, "SmallLabel"))
		_body.add_child(row)
	_body.add_child(_line("주둔 %d명" % c["officers"].size(), "Label"))
	var flow := HFlowContainer.new()
	_body.add_child(flow)
	for o in c["officers"]:
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(170, 0)
		box.add_theme_constant_override("separation", 6)
		if sprites != null:
			box.add_child(sprites.box(o["id"], o["name"], 150))
		box.add_child(_line("%s[%s]" % [o["name"], o["mark"]] + ("" if o["status"] == "움직임" else " · " + o["status"]), "TinyLabel"))
		flow.add_child(box)


func _clear() -> void:
	for ch in _body.get_children():
		ch.queue_free()


func _line(text: String, variation: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
