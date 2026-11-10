extends HBoxContainer
## 간부 줄 — View.officer_cards 를 카드(초상 · 이름 · 남은 행동)로 그린다. 카드를 끌면 {officer: id} 를 지도에 놓을 수 있고(끌어 놓기),
## 누르면 그 간부를 고른다(누르기 두 번 — 간부 → 구역). 상태는 바꾸지 않고 신호만 올린다(ISP). 요구: FR-204 · 기획_차이 (나)18

signal officer_pressed(officer: String)

var sprites = null
var _group := ButtonGroup.new()


class Card extends Button:
	var officer := ""
	var tex: Texture2D = null

	func _get_drag_data(_at: Vector2):
		var prev := TextureRect.new()
		prev.texture = tex
		prev.custom_minimum_size = Vector2(144, 144)
		prev.size = Vector2(144, 144)
		prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		prev.position = -prev.size / 2.0
		var holder := Control.new()
		holder.add_child(prev)
		set_drag_preview(holder)
		return {"officer": officer}


func _ready() -> void:
	_group.allow_unpress = true


## cards = View.officer_cards · picked = 고른 간부 id("" = 없음)
func show_cards(cards: Array, picked: String) -> void:
	for ch in get_children():
		ch.queue_free()
	if cards.is_empty():
		var l := Label.new()
		l.text = "움직일 수 있는 간부가 없다"
		l.theme_type_variation = "SmallLabel"
		add_child(l)
		return
	for c in cards:
		var b := Card.new()
		b.officer = c["id"]
		b.tex = sprites.portrait(c["id"]) if sprites != null else null
		b.theme_type_variation = "CardButton"
		b.toggle_mode = true
		b.button_group = _group
		b.button_pressed = c["id"] == picked
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio = 1.0
		b.clip_text = true
		b.pressed.connect(officer_pressed.emit.bind(c["id"]))
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		b.add_child(v)
		var r := TextureRect.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.texture = b.tex
		r.custom_minimum_size = Vector2(0, 112)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		v.add_child(r)
		for txt in [c["name"] + (" ★" if c["boss"] else ""), "●".repeat(c["left"]) + "○".repeat(c["total"] - c["left"])]:
			var l := Label.new()
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			l.text = txt
			l.theme_type_variation = "TinyLabel"
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			v.add_child(l)
		add_child(b)
