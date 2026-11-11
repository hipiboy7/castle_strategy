extends RefCounted
## 인물 도트 칸 — assets/chars/index.json(scripts/import_chars.py 가 만든 색인)을 읽어 canon id → AtlasTexture(초상 32×32 · 서기 24×32).
## 그림이 없는 인물(색인 missing · 외형 없음)은 null — 부른 쪽이 세력색 바탕 + 이름 첫 글자로 대신한다(설계서 5절).
## 그림은 최근접 필터(project.godot 기본 텍스처 필터). 요구: FR-212 · 출처: assets/ASSETS.md

const INDEX := "res://assets/chars/index.json"
const PORTRAITS := "res://assets/chars/portraits.png"
const FIGURES := "res://assets/chars/figures.png"

var _ids: Dictionary = {}
var _cols := 16
var _cell := {"portrait": Vector2(32, 32), "figure": Vector2(24, 32)}
var _tex := {}
var _cache := {}


func _init() -> void:
	if not FileAccess.file_exists(INDEX):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
	if not (d is Dictionary):
		return
	_ids = d.get("ids", {})
	_cols = int(d.get("cols", 16))
	for k in ["portrait", "figure"]:
		var c: Array = d.get("cell", {}).get(k, [])
		if c.size() == 2:
			_cell[k] = Vector2(c[0], c[1])
	_tex["portrait"] = load(PORTRAITS)
	_tex["figure"] = load(FIGURES)


func portrait(id: String) -> Texture2D:
	return _atlas("portrait", id)


func figure(id: String) -> Texture2D:
	return _atlas("figure", id)


func _atlas(kind: String, id: String) -> Texture2D:
	if not _ids.has(id) or _tex.get(kind) == null:
		return null
	var key := kind + ":" + id
	if not _cache.has(key):
		var n := int(_ids[id])
		var a := AtlasTexture.new()
		a.atlas = _tex[kind]
		var c: Vector2 = _cell[kind]
		a.region = Rect2(Vector2(n % _cols, n / _cols) * c, c)
		_cache[key] = a
	return _cache[key]
