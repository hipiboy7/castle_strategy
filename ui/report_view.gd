extends PanelContainer
## 턴 끝 보고 — View.report_cards 의 카드(승패 · 돈 · 내 명령 · 다른 조직 · 전투)를 차례로 보인다. '닫기'면 closed — 다음 주 지도로(app).
## 전투 카드에는 습격마다 '전투 보기 n' 단추(카드 제목 바로 밑) — 누르면 battle(n)(app 이 전투 화면 ui/battle_view.gd 를 연다).
## 싸움이 있던 주는 아래 '닫기' 옆에도 '전투 보기' 단추를 늘 둔다(스크롤하지 않아도 보이게 — 폰 v0.3.0-rc.2 · docs/트러블슈팅.md T-6). 요구: FR-208 · FR-310

signal closed
signal battle(i: int)

var _title: Label
var _list: VBoxContainer
var close_button: Button
var watch_button: Button               # 아래 '전투 보기'(첫 싸움) — 싸움이 없으면 숨김
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
	var foot := HBoxContainer.new()
	col.add_child(foot)
	watch_button = Button.new()
	watch_button.text = "전투 보기"
	watch_button.theme_type_variation = "CardButton"
	watch_button.custom_minimum_size = Vector2(0, 140)
	watch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	watch_button.visible = false
	watch_button.pressed.connect(func() -> void: battle.emit(0))
	foot.add_child(watch_button)
	close_button = Button.new()
	close_button.text = "닫기"
	close_button.custom_minimum_size = Vector2(0, 140)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.pressed.connect(func() -> void: closed.emit())
	foot.add_child(close_button)


func show_report(title: String, cards: Array, close_text: String) -> void:
	_title.text = title
	close_button.text = close_text
	for ch in _list.get_children():
		ch.queue_free()
	battle_buttons = []
	var fights := 0
	for c in cards:
		var p := PanelContainer.new()
		p.theme_type_variation = "RowPanel"
		var v := VBoxContainer.new()
		p.add_child(v)
		var h := Label.new()
		h.text = c["title"]
		v.add_child(h)
		fights += int(c.get("battles", 0))
		for i in int(c.get("battles", 0)):
			var b := Button.new()
			b.text = "전투 보기 %d — 구간 · 일기토 장면" % (i + 1)
			b.theme_type_variation = "CardButton"
			b.custom_minimum_size = Vector2(0, 120)
			b.pressed.connect(battle.emit.bind(i))
			v.add_child(b)
			battle_buttons.append(b)
		for line in c["lines"]:
			var l := Label.new()
			l.text = line
			l.theme_type_variation = "SmallLabel"
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(l)
		_list.add_child(p)
	watch_button.visible = fights > 0
	watch_button.text = "전투 보기" if fights <= 1 else "전투 보기 1 / %d" % fights
