extends RefCounted
## 손가락으로 끌어 내리기 — 스크롤 목록(ScrollContainer) 안의 판(PanelContainer · Panel · Control)은 Godot 기본이 MOUSE_FILTER_STOP 라
## 판 위에서 시작한 끌기가 스크롤까지 가지 않는다(카드 사이 틈 · 스크롤 막대에서만 움직임 — 폰 v0.3.0-rc.2 · docs/트러블슈팅.md T-6).
## ui/app.gd 가 SceneTree.node_added 에 이어, 스크롤 목록 안에 들어오는 STOP 판을 PASS 로 바꾼다. 단추(BaseButton)는 그대로 STOP —
## 끌다 놓은 자리에서 단추가 눌리는 일(잘못된 명령)을 막는다. 시험: tests/unit/test_touch_scroll.gd


static func in_scroll(n: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


## 바꿨으면 true
static func fit(n: Node) -> bool:
	if not (n is Control) or n is BaseButton or n is ScrollBar or n is ScrollContainer:
		return false
	var c := n as Control
	if c.mouse_filter != Control.MOUSE_FILTER_STOP or not in_scroll(c):
		return false
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	return true
