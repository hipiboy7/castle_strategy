extends RefCounted
## 아래 탭 내용 셋(조직 · 명령 · 기록) — 보기 사전을 그리기만 하고 누름은 신호로 올린다(ISP). 외교 · 원탁은 빈 상태 글(app).
## 요구: FR-206(명령) · FR-209(조직) · FR-211(기록 · 새 판)

const View = preload("res://ui/view.gd")


## 스크롤 + 세로 줄 — 쪽(PanelContainer)에 붙여 쓰고, 세로 줄을 돌려준다
static func _scroll(page: PanelContainer) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return v


static func _line(v: Control, text: String, variation: String = "SmallLabel") -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	return l


static func _clear(v: Control) -> void:
	for ch in v.get_children():
		ch.queue_free()


class OrgPage extends PanelContainer:
	var sprites = null
	var _v: VBoxContainer

	func _ready() -> void:
		_v = load("res://ui/tab_pages.gd")._scroll(self)

	func show_org(o: Dictionary) -> void:
		var T = load("res://ui/tab_pages.gd")
		T._clear(_v)
		T._line(_v, "[%s] %s" % [o["mark"], o["name"]], "CardTitle")
		T._line(_v, "돈 %s · 주 수입 %s · 지출 %s · 순이익 %s" % [o["cash"], o["income"], o["upkeep"], o["net"]])
		T._line(_v, "열기 %s · 명성 %s · 결속 %s" % [o["heat"], o["fame"], o["cohesion"]])
		T._line(_v, "조직원 " + o["troops"])
		T._line(_v, "간부 %d명" % o["officers"].size(), "Label")
		for p in o["officers"]:
			var row := PanelContainer.new()
			row.theme_type_variation = "RowPanel"
			var h := HBoxContainer.new()
			row.add_child(h)
			h.add_theme_constant_override("separation", 20)
			if sprites != null:
				h.add_child(sprites.box(p["id"], p["name"], 128))
			var l: Label = T._line(h, "%s · %s · %s\n충성 %s · %s · %s" % [p["name"], p["post"], p["rank"], p["loyalty"], p["status"], p["zone_name"]])
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_v.add_child(row)
		T._line(_v, "다른 조직", "Label")
		for x in o["others"]:
			T._line(_v, "[%s] %s — 구역 %d · 사업장 %d" % [x["mark"], x["name"], x["zones"], x["slots"]])


class OrdersPage extends PanelContainer:
	signal remove_at(i: int)
	signal clear_all
	var _v: VBoxContainer

	func _ready() -> void:
		_v = load("res://ui/tab_pages.gd")._scroll(self)

	## rows = [{text, ok, why}] (대기 명령 순)
	func show_orders(rows: Array, left_text: String) -> void:
		var T = load("res://ui/tab_pages.gd")
		T._clear(_v)
		T._line(_v, "대기 명령 %d · %s" % [rows.size(), left_text], "CardTitle")
		if rows.is_empty():
			T._line(_v, "대기 명령이 없다. 지도에서 간부를 구역에 놓거나 '맡기기'를 누른다.")
			return
		for i in rows.size():
			var r: Dictionary = rows[i]
			var row := PanelContainer.new()
			row.theme_type_variation = "RowPanel"
			var h := HBoxContainer.new()
			row.add_child(h)
			var l: Label = T._line(h, ("○ " if r["ok"] else "× ") + r["text"] + ("" if r["ok"] else " — " + r["why"]))
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var b := Button.new()
			b.text = "빼기"
			b.theme_type_variation = "TabButton"
			b.custom_minimum_size = Vector2(160, 120)
			b.pressed.connect(remove_at.emit.bind(i))
			h.add_child(b)
			_v.add_child(row)
		var c := Button.new()
		c.text = "모두 비우기"
		c.theme_type_variation = "TabButton"
		c.custom_minimum_size = Vector2(0, 130)
		c.pressed.connect(func() -> void: clear_all.emit())
		_v.add_child(c)


class LogPage extends PanelContainer:
	signal open_report(i: int)
	signal new_game
	var _v: VBoxContainer
	var _perf: Label

	func _ready() -> void:
		_v = load("res://ui/tab_pages.gd")._scroll(self)

	## titles = 보고 한 줄(오래된 것부터) · info = 판 · 해시 글 · perf = 성능 줄(1초마다 set_perf 로 글만 바꾼다 — 끌어 둔 자리를 지키려고)
	func show_log(titles: Array, info: String, perf: String) -> void:
		var T = load("res://ui/tab_pages.gd")
		T._clear(_v)
		T._line(_v, "지난 보고 %d" % titles.size(), "CardTitle")
		if titles.is_empty():
			T._line(_v, "아직 끝낸 주가 없다.")
		for i in range(titles.size() - 1, -1, -1):
			var b := Button.new()
			b.text = titles[i]
			b.theme_type_variation = "CardButton"
			b.custom_minimum_size = Vector2(0, 120)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.pressed.connect(open_report.emit.bind(i))
			_v.add_child(b)
		var n := Button.new()
		n.text = "새 판으로(지금 판을 지운다)"
		n.theme_type_variation = "TabButton"
		n.custom_minimum_size = Vector2(0, 130)
		n.pressed.connect(func() -> void: new_game.emit())
		_v.add_child(n)
		_perf = T._line(_v, perf, "Label")
		T._line(_v, "판 정보", "Label")
		T._line(_v, info, "TinyLabel")

	func set_perf(text: String) -> void:
		if is_instance_valid(_perf):
			_perf.text = text
