extends "res://tests/helpers.gd"
## 옮겨 적은 것 대조(CLAUDE.md 4절) — data/game/economy.json 의 08 14-1 시작값이 기획서 08(castle_common 98ac39cc · 56839ec 같은 값)과 같은지.
## 아래 기대값은 08 14-1 본문을 손으로 옮겼다. 밸런스로 economy.json 을 고치면 이 기대도 같이 고치고 까닭을 테스트결과서에 적는다.
##   사업장 수입 = BASE × lv × 유동/100 × (0.8 + 수완/250) × (1 − 0.5 × 열기/100) × (돈줄 맞으면 1.25)
##   BASE 유흥 60 · 대부 50 · 건설 70 · 물류 80 · 숙박 55 · 상권 35 · 유지비 건달급 1 · 조장급 2 · 네임드 4 · 경호대급 8 · 간부 대우 등급 번호 × 3
##   상납 0.15 · 강요 0.30 · 대부 주 이자 3% · 4턴 · 회비 0.05

const DataFiles = preload("res://src/data_files.gd")
const PATH := "game/economy.json"


func _e() -> Dictionary:
	var r: Dictionary = DataFiles.read([PATH])
	check(r["errors"].is_empty(), "읽기 %s" % [r["errors"]])
	return r["files"].get(PATH, {})


func test_matches_08_section_14_1() -> void:
	var e := _e()
	var base := {"유흥": 60, "대부": 50, "건설": 70, "물류": 80, "숙박": 55, "상권": 35}
	for k in base:
		eq(int(e["base"][k]), base[k], "BASE[%s]" % k)
	eq(e["base"].size(), 6, "업종 여섯")
	var wage := {"건달급": 1, "조장급": 2, "네임드": 4, "경호대급": 8}
	for k in wage:
		eq(int(e["wage"][k]), wage[k], "유지비[%s]" % k)
	eq(int(e["officer_pay_per_rank"]), 3, "간부 대우 = 등급 번호 × 3")
	eq(int(e["match_milli"]), 1250, "돈줄 맞으면 1.25")
	eq(int(e["biz_base_milli"]), 800, "0.8")
	eq(int(e["biz_per_point_milli"]), 4, "수완/250 = 수완 × 0.004")
	eq(int(e["heat_div"]), 20000, "(1 − 0.5 × 열기/100) = (20000 − 열기×100) ÷ 20000")
	eq(int(e["tribute_bp"]), 1500, "상납 0.15")
	eq(int(e["tribute_forced_bp"]), 3000, "강요 0.30")
	eq(int(e["loan"]["interest_bp"]), 300, "대부 주 이자 3%")
	eq(int(e["loan"]["default_turns"]), 4, "4턴 못 갚으면 압류")
	eq(int(e["castle_fee_bp"]), 500, "회비 0.05")


## 08 3-1 '현금이 0 밑으로 2턴' — 몇 턴째부터인지만 08 값이고, 떠나는 비율 · 충성 하락은 이 판 값(기획_차이 (나)12)
func test_neg_cash_turns_from_08_3_1() -> void:
	eq(int(_e()["neg_cash"]["turns"]), 2, "0 밑으로 2턴")
