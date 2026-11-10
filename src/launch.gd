extends RefCounted
## 실행 인자 — 순수 함수(글 목록 → 인자 사전). 잘못된 값은 "errors" 에 모은다(src/main.gd 가 찍고 종료 코드 2).
## 요구: FR-105 · FR-217 · 시험: tests/unit/test_launch.gd · 방식은 castle_M3D src/launch.gd 를 옮겼다.
##   --autoplay        화면 없이 시나리오 A 자동 진행(모든 조직 AI)을 --turns 턴 돌리고 RESULT 한 줄을 찍고 끝낸다
##   --turns N         자동 진행 턴 수(1 이상 · 기본 26 — 08 2절 주 시나리오)
##   --seed S          시드(정수 · 기본 1)
##   --shot PATH       화면을 --shot-frame 번째 프레임에 PNG 로 찍고 끝낸다(작업 서버 xvfb · CI 스크린샷)
##   --shot-frame N    (1 이상 · 기본 30)
##   --view NAME       화면 장면(C2 FR-217): map(기본) · card · pick · orders · report · org · log · diplo · battle(C3 — 1주 보고의 첫 전투 · 첫 일기토 장면) — --shot 과 함께 쓴다
##   --week N          (1 이상 · 기본 1) 맡기기로 N−1주를 둔 뒤의 화면
##   --zone ID         card · pick 에서 고를 구역(기본 = 내 본거지)

const INT_KEYS := {"--turns": "turns", "--seed": "seed", "--shot-frame": "shot_frame", "--week": "week"}
const MIN_ONE := ["turns", "shot_frame", "week"]
const VIEWS := ["map", "card", "pick", "orders", "report", "org", "log", "diplo", "battle"]


static func defaults() -> Dictionary:
	return {"autoplay": false, "turns": 26, "seed": 1, "shot": "", "shot_frame": 30, "view": "map", "week": 1, "zone": "", "errors": []}


static func parse(a: PackedStringArray) -> Dictionary:
	var args := defaults()
	var i := 0
	while i < a.size():
		var k := a[i]
		if k == "--autoplay":
			args["autoplay"] = true
		elif INT_KEYS.has(k):
			if i + 1 >= a.size() or not a[i + 1].is_valid_int():
				args["errors"].append("%s 에는 정수가 필요하다" % k)
				if i + 1 < a.size() and not a[i + 1].begins_with("--"):
					i += 1                                   # 틀린 값은 건너뛴다(다음 인자로 읽지 않는다)
			else:
				i += 1
				var name: String = INT_KEYS[k]
				var n := a[i].to_int()
				if name in MIN_ONE and n < 1:
					args["errors"].append("%s 는 1 이상이다: %d" % [k, n])
				else:
					args[name] = n
		elif k in ["--shot", "--view", "--zone"]:
			var name := k.trim_prefix("--")
			if i + 1 >= a.size() or a[i + 1].begins_with("--"):
				args["errors"].append("%s 에는 값이 필요하다" % k)
			elif name == "view" and not VIEWS.has(a[i + 1]):
				args["errors"].append("--view 는 %s 중 하나다: %s" % [" · ".join(VIEWS), a[i + 1]])
				i += 1
			else:
				i += 1
				args[name] = a[i]
		else:
			args["errors"].append("알 수 없는 인자: %s" % k)
		i += 1
	return args
