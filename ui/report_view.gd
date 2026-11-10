extends PanelContainer
## 턴 끝 보고 — View.report_cards 의 카드(승패 · 돈 · 내 명령 · 다른 조직 · 전투)를 차례로 보인다. '닫기'면 closed — 다음 주 지도로(app).
## 전투 카드에는 습격마다 '전투 보기 n' 단추 — 누르면 battle(n)(app 이 전투 화면 ui/battle_view.gd 를 연다). 요구: FR-208 · FR-310

signal closed
signal battle(i: int)

var _title: Label
var _list: VBoxContainer
var close_button: Button
var battle_buttons: Array = []         # 에뮬레이터 · 스크린샷용(app 이 자리를 찍는다)


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
	battle_buttons = []
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
		for i in int(c.get("battles", 0)):
			var b := Button.new()
			b.text = "전투 보기 %d" % (i + 1)
			b.theme_type_variation = "CardButton"
			b.custom_minimum_size = Vector2(0, 120)
			b.pressed.connect(battle.emit.bind(i))
			v.add_child(b)
			battle_buttons.append(b)
		_list.add_child(p)
