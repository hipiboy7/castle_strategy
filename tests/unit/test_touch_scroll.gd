extends "res://tests/helpers.gd"
## T-6 — 스크롤 목록 안 판(PanelContainer · STOP)은 PASS 로 바뀌어 끌기가 스크롤까지 간다. 단추 · 목록 밖 판 · 이미 PASS/IGNORE 는 그대로.
## 대상: ui/touch_scroll.gd

const TouchScroll = preload("res://ui/touch_scroll.gd")


func test_fit_inside_scroll() -> void:
	var sc := ScrollContainer.new()
	var v := VBoxContainer.new()
	sc.add_child(v)
	var p := PanelContainer.new()
	v.add_child(p)
	var b := Button.new()
	v.add_child(b)
	var l := Label.new()
	p.add_child(l)
	check(TouchScroll.in_scroll(p), "판은 스크롤 안")
	check(TouchScroll.fit(p), "판을 바꿈")
	eq(p.mouse_filter, Control.MOUSE_FILTER_PASS, "판 → PASS")
	check(not TouchScroll.fit(b), "단추는 그대로")
	eq(b.mouse_filter, Control.MOUSE_FILTER_STOP, "단추 STOP")
	check(not TouchScroll.fit(l), "글(IGNORE)은 그대로")
	eq(l.mouse_filter, Control.MOUSE_FILTER_IGNORE, "글 IGNORE")
	check(not TouchScroll.fit(sc), "스크롤 자신은 그대로")
	sc.free()


func test_fit_outside_scroll() -> void:
	var root := PanelContainer.new()
	var p := PanelContainer.new()
	root.add_child(p)
	check(not TouchScroll.in_scroll(p), "스크롤 밖")
	check(not TouchScroll.fit(p), "스크롤 밖 판은 그대로")
	eq(p.mouse_filter, Control.MOUSE_FILTER_STOP, "STOP 그대로")
	var nd := Node.new()
	check(not TouchScroll.fit(nd), "Control 이 아니면 그대로")
	nd.free()
	root.free()
