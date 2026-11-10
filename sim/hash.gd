extends RefCounted
## 정규형 JSON · 상태 해시 — 같은 값이면 키 순서와 상관없이 같은 글 · 같은 해시(서버 · CI · 폰).
## 설계: docs/C1_설계서_상태와턴.md 3-2 · 요구: FR-104 · 기준 구현: tools/rng_ref.py canonical · sha16 · 시험: tests/unit/test_hash.gd
## 규칙(Python json.dumps(sort_keys=True, separators=(",", ":"), ensure_ascii=False) 와 같다):
##   dict 키(문자열만)는 코드 포인트 순 · 배열은 순서 그대로 · 정수 10진 · true/false/null · 공백 없음
##   문자열은 " \ 와 U+0000~001F 만 바꾼다(\" \\ \n \r \t \b \f, 그 밖은 \u00xx)
## 실수나 문자열이 아닌 키가 있으면 canonical · of 는 빈 문자열, check 는 까닭을 돌려준다(이 층은 출력하지 않는다 — 부른 쪽이 정한다).

static var _needs_escape := RegEx.create_from_string("[\\x00-\\x1f\"\\\\]")


## 정규형 JSON 글. 쓸 수 없는 값이면 ""
static func canonical(v) -> String:
	var out := PackedStringArray()
	if _write(v, out) != "":
		return ""
	return "".join(out)


## 정규형의 SHA-256 앞 16자(소문자 16진). 쓸 수 없는 값이면 ""
static func of(v) -> String:
	var text := canonical(v)
	if text == "":
		return ""
	return text.sha256_text().substr(0, 16)


## 쓸 수 없는 까닭(없으면 "")
static func check(v) -> String:
	return _write(v, PackedStringArray())


static func _write(v, out: PackedStringArray) -> String:
	match typeof(v):
		TYPE_NIL:
			out.append("null")
		TYPE_BOOL:
			out.append("true" if v else "false")
		TYPE_INT:
			out.append(str(v))
		TYPE_STRING, TYPE_STRING_NAME:
			out.append(_quote(String(v)))
		TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			out.append("[")
			var first := true
			for x in v:
				if not first:
					out.append(",")
				first = false
				var why := _write(x, out)
				if why != "":
					return why
			out.append("]")
		TYPE_DICTIONARY:
			var keys: Array = v.keys()
			for k in keys:
				if typeof(k) != TYPE_STRING and typeof(k) != TYPE_STRING_NAME:
					return "키가 문자열이 아니다: %s" % [k]
			var names: Array = []
			for k in keys:
				names.append(String(k))
			names.sort()
			out.append("{")
			for i in names.size():
				if i > 0:
					out.append(",")
				out.append(_quote(names[i]))
				out.append(":")
				var why := _write(v[names[i]], out)
				if why != "":
					return why
			out.append("}")
		TYPE_FLOAT:
			return "실수는 쓸 수 없다(상태는 정수만 — 설계서 3-3): %s" % [v]
		_:
			return "쓸 수 없는 형: %s" % type_string(typeof(v))
	return ""


static func _quote(s: String) -> String:
	if _needs_escape.search(s) == null:
		return "\"" + s + "\""
	var out := PackedStringArray(["\""])
	for i in s.length():
		var c := s.unicode_at(i)
		match c:
			34:
				out.append("\\\"")
			92:
				out.append("\\\\")
			10:
				out.append("\\n")
			13:
				out.append("\\r")
			9:
				out.append("\\t")
			8:
				out.append("\\b")
			12:
				out.append("\\f")
			_:
				if c < 0x20:
					out.append("\\u%04x" % c)
				else:
					out.append(String.chr(c))
	out.append("\"")
	return "".join(out)
