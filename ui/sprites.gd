extends RefCounted
## 인물 초상 — assets/chars/svg/<canon id>.svg(scripts/draw_portraits.py 가 assets/chars/looks.json 에서 그린 벡터 일러스트 · 384px 로 가져옴).
## 그림이 없는 인물은 null — 부른 쪽(또는 box())이 이름 첫 글자로 대신한다. 배경판은 테마 PortraitPanel(ui/theme.tres).
## 도트(취호전 시트)는 2026-11-11 에 그만 썼다(사용자 지시 · docs/기획_차이.md (라)12). 요구: FR-212 · 출처: assets/ASSETS.md
## 원작 초상(개인 빌드 전용 · (라)14): assets/chars/cut/<id>.png(scripts/cut_portraits.py — 공식 인물 카드에서 자름)가 있으면 그것을 먼저 쓴다.
## 배포 빌드는 그 폴더를 빼고 내보낸다 — 그러면 저절로 벡터 초상으로 돌아간다.

const DIR := "res://assets/chars/svg/"
const CUT_DIR := "res://assets/chars/cut/"
const CUT_HEADS := "res://assets/chars/cut/heads.json"
## 얼굴 둘레(그림 384px 안) — 지도 위 동그란 패에 머리만 넣을 때 쓴다(그림 256 좌표 x 48~208 · y 24~184 × 1.5 — scripts/draw_portraits.py 얼굴 자리)
const HEAD_REGION := Rect2(72, 36, 240, 240)

var _cache := {}
var _heads = null   # id -> Rect2(원작 초상 얼굴 자리) · 처음 부를 때 읽는다


func _load_heads() -> void:
	_heads = {}
	if not FileAccess.file_exists(CUT_HEADS):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(CUT_HEADS))
	if typeof(d) != TYPE_DICTIONARY or typeof(d.get("heads")) != TYPE_DICTIONARY:
		return
	for id in d["heads"]:
		var h: Array = d["heads"][id]["head"]
		_heads[id] = Rect2(h[0], h[1], h[2], h[3])


## 원작 초상이 있는 인물인가(그림이 화면 쪽을 보는 방향이 제각각이라 뒤집지 않는다)
func is_cut(id: String) -> bool:
	if _heads == null:
		_load_heads()
	return _heads.has(id) and ResourceLoader.exists(CUT_DIR + id + ".png")


func portrait(id: String) -> Texture2D:
	if not _cache.has(id):
		var p := CUT_DIR + id + ".png" if is_cut(id) else DIR + id + ".svg"
		_cache[id] = load(p) if ResourceLoader.exists(p) else null
	return _cache[id]


## 지도 동그란 패에 넣을 얼굴 자리(그림 384px 좌표)
func head_region(id: String) -> Rect2:
	return _heads[id] if is_cut(id) else HEAD_REGION


## 초상 한 칸 — 테마 판(PortraitPanel) 위에 그림(없으면 이름 첫 글자). 누름은 통과시킨다.
## 그림은 모두 화면 왼쪽을 본다(3/4) — flip = 좌우를 뒤집어 오른쪽을 보게(전투 일기토에서 마주 보게).
func box(id: String, name: String, side: float, flip := false) -> Control:
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
		r.flip_h = flip and not is_cut(id)
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
