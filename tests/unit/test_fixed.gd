extends "res://tests/helpers.gd"
## FR-116 — sim/fixed.gd: 정수 고정소수 도우미. 반올림 나눗셈(0 이상은 반 올림 · 음수는 0 쪽 대칭) · 올림 나눗셈 · 만분율 곱. 설계서 3-6

const Fixed = preload("res://sim/fixed.gd")


func test_div_round() -> void:
	eq(Fixed.div_round(7, 2), 4, "3.5 → 4")
	eq(Fixed.div_round(5, 2), 3, "2.5 → 3")
	eq(Fixed.div_round(4, 3), 1, "1.33 → 1")
	eq(Fixed.div_round(0, 9), 0, "0")
	eq(Fixed.div_round(-7, 2), -4, "-3.5 → -4(대칭)")
	eq(Fixed.div_round(-4, 3), -1, "-1.33 → -1")


func test_ceil_div_and_bp() -> void:
	eq(Fixed.ceil_div(10, 3), 4, "올림")
	eq(Fixed.ceil_div(9, 3), 3, "나누어떨어짐")
	eq(Fixed.ceil_div(0, 3), 0, "0")
	eq(Fixed.bp(250, 1500), 38, "250 × 15% = 37.5 → 38")
	eq(Fixed.bp(-250, 1500), -38, "음수 대칭")


func test_milli_from_float() -> void:
	eq(Fixed.milli(1.25), 1250, "규칙 함수의 실수 → ×1000 정수")
	eq(Fixed.milli(0.0005), 1, "0.5 → 1(반올림)")
	eq(Fixed.milli(-0.0005), -1, "대칭")
