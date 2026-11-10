extends PanelContainer
## 명령 고르기 — 간부를 구역에 놓았을 때(끌어 놓기 · 누르기 두 번) Draft.options 를 줄 단추로 보인다. 줄 = View.option_text(비용 · 모집 수 ·
## 안 되는 까닭). 안 되는 줄은 눌리지 않는다. 고르면 picked(명령), 그만이면 cancelled — 상태는 app 이 바꾼다(ISP). 요구: FR-204

const View = preload("res://ui/view.gd")

signal picked(order: Dictionary)
signal cancelled

var _title: Label
var _list: VBoxContainer
var buttons: Array = []                # 에뮬레이터 · 스크린샷용(app 이 자리를 찍는다)


func _ready() -> void:
	theme_type_variation = "SheetPanel"
	var col := VBoxContainer.new()
	add_child(col)
	_title = Label.new()
	_title.theme_type_variation = "CardTitle"
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(_title)
	var hint := Label.new()
	hint.theme_type_variation = "TinyLabel"
	hint.text = "미리 본 결과(다른 조직이 먼저 빈칸을 가져가면 달라질 수 있다)"
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(hint)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	var stop := Button.new()
	stop.text = "그만"
	stop.theme_type_variation = "TabButton"
	stop.custom_minimum_size = Vector2(0, 130)
	stop.pressed.connect(func() -> void: cancelled.emit())
	col.add_child(stop)


func show_options(title: String, options: Array) -> void:
	_title.text = title
	for ch in _list.get_children():
		ch.queue_free()
	buttons = []
	for opt in options:
		var b := Button.new()
		b.text = View.option_text(opt)
		b.theme_type_variation = "CardButton"
		b.custom_minimum_size = Vector2(0, 130)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.disabled = not opt["ok"]
		b.pressed.connect(picked.emit.bind(opt["order"]))
		_list.add_child(b)
		buttons.append(b)
