extends RefCounted
## 정수 고정소수 도우미 — 나눗셈은 0 이상이면 반올림((a + d/2) / d), 음수는 0 쪽 대칭. 한 공식은 한 번만 나눈다(분자를 다 곱한 뒤).
## 설계: docs/C1_설계서_상태와턴.md 3-6 · 요구: FR-116 · 시험: tests/unit/test_fixed.gd

const BP := 10000                # 만분율 1.00


## a ÷ d 반올림(d > 0)
static func div_round(a: int, d: int) -> int:
	if a >= 0:
		return (a + d / 2) / d
	return -((-a + d / 2) / d)


## a ÷ d 올림(a ≥ 0 · d > 0)
static func ceil_div(a: int, d: int) -> int:
	return (a + d - 1) / d


## a × 만분율 반올림
static func bp(a: int, rate_bp: int) -> int:
	return div_round(a * rate_bp, BP)


## 규칙 함수(rules_common)의 실수 결과 → ×1000 정수(반올림 · 0 쪽 대칭). 덧셈 · 곱셈 · 나눗셈만 쓴 값이라 플랫폼마다 같다
static func milli(x: float) -> int:
	return int(roundf(x * 1000.0))
