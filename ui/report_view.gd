extends PanelContainer
## 턴 끝 보고 — View.report_cards 의 카드(돈 · 내 명령 · 다른 조직 · 전투)를 차례로 보인다. '닫기'면 closed — 다음 주 지도로(app). 요구: FR-208

signal closed

var _title: Label
var _list: VBoxContainer
var close_button: Button


func _ready() -> void:
	theme_type_variation = "SheetPanel"
	var col := VBoxContainer.new()
	add_child(col)
	_title = Label.new()
	_title.theme_type_variation = "CardTitle"
	col.add_child(_title)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	close_button = Button.new()
	close_button.text = "닫기"
	close_button.custom_minimum_size = Vector2(0, 140)
	close_button.pressed.connect(func() -> void: closed.emit())
	col.add_child(close_button)


func show_report(title: String, cards: Array, close_text: String) -> void:
	_title.text = title
	close_button.text = close_text
	for ch in _list.get_children():
		ch.queue_free()
	for c in cards:
		var p := PanelContainer.new()
		p.theme_type_variation = "RowPanel"
		var v := VBoxContainer.new()
		p.add_child(v)
		var h := Label.new()
		h.text = c["title"]
		v.add_child(h)
		for line in c["lines"]:
			var l := Label.new()
			l.text = line
			l.theme_type_variation = "SmallLabel"
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(l)
		_list.add_child(p)
