extends RefCounted
## 인물 초상 — assets/chars/svg/<canon id>.svg(scripts/draw_portraits.py 가 assets/chars/looks.json 에서 그린 벡터 일러스트 · 384px 로 가져옴).
## 그림이 없는 인물은 null — 부른 쪽(또는 box())이 이름 첫 글자로 대신한다. 배경판은 테마 PortraitPanel(ui/theme.tres).
## 도트(취호전 시트)는 2026-11-11 에 그만 썼다(사용자 지시 · docs/기획_차이.md (라)12). 요구: FR-212 · 출처: assets/ASSETS.md

const DIR := "res://assets/chars/svg/"
## 얼굴 둘레(그림 384px 안) — 지도 위 동그란 패에 머리만 넣을 때 쓴다(머리 공간 → 화면: scripts/draw_portraits.py HEAD)
const HEAD_REGION := Rect2(84, 24, 216, 216)

var _cache := {}


func portrait(id: String) -> Texture2D:
	if not _cache.has(id):
		var p := DIR + id + ".svg"
		_cache[id] = load(p) if ResourceLoader.exists(p) else null
	return _cache[id]


## 초상 한 칸 — 테마 판(PortraitPanel) 위에 그림(없으면 이름 첫 글자). 누름은 통과시킨다.
func box(id: String, name: String, side: float) -> Control:
	var p := PanelContainer.new()
	p.theme_type_variation = "PortraitPanel"
	p.custom_minimum_size = Vector2(side, side)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.clip_contents = true
	var tex := portrait(id)
	if tex != null:
		var r := TextureRect.new()
		r.texture = tex
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p.add_child(r)
	else:
		var l := Label.new()
		l.text = name.left(1)
		l.theme_type_variation = "CardTitle"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(l)
	return p
