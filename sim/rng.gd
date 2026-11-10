extends RefCounted
## PCG32 — pcg-c-basic `pcg32_random_r` 과 같은 수열 · 갈래 스트림 · 편향 없는 범위 · 만분율 확률.
## 설계: docs/C1_설계서_상태와턴.md 3-1 · 요구: FR-103 · 기준 구현: tools/rng_ref.py · 시험: tests/unit/test_rng.gd
## 64비트 값(상태 · 증분)은 32비트 두 쪽(hi · lo, 0 ≤ x < 2^32)으로 둔다. 곱은 16비트 조각 곱이라 모든 중간값이 2^34 아래다 —
## GDScript int64 넘침에 기대지 않는다(서버 x86_64 · 폰 arm64 가 같은 수열 — CLAUDE.md 3절 결정성).
## 쓰는 법: var r = Pcg32.new().init_stream(seed, turn, "manage", org_id); r.below(100)

const M32 := 0xFFFFFFFF
const MUL_HI := 0x5851F42D          # 6364136223846793005 = 0x5851F42D_4C957F2D
const MUL_LO := 0x4C957F2D

var _hi := 0
var _lo := 0
var _inc_hi := 0
var _inc_lo := 0


## pcg32_srandom_r(initstate, initseq) — 64비트 둘을 [hi, lo] 로 받는다. 자기를 돌려준다(이어 쓰기)
func seed_with(state_hi: int, state_lo: int, seq_hi: int, seq_lo: int) -> RefCounted:
	_hi = 0
	_lo = 0
	_inc_hi = ((seq_hi << 1) | (seq_lo >> 31)) & M32
	_inc_lo = ((seq_lo << 1) & M32) | 1
	_step()
	var s := _lo + (state_lo & M32)
	_lo = s & M32
	_hi = (_hi + (state_hi & M32) + (s >> 32)) & M32
	_step()
	return self


## 갈래 스트림 — SHA-256("시드|턴|단계|대상") 앞 16바이트(빅엔디언) = initstate · initseq.
## 대상마다 스트림이 따로라 명령 하나가 바뀌어도 다른 대상의 난수는 밀리지 않는다(08 13절)
func init_stream(seed: int, turn: int, phase: String, target: String) -> RefCounted:
	var d: PackedByteArray = ("%d|%d|%s|%s" % [seed, turn, phase, target]).sha256_buffer()
	return seed_with(_be32(d, 0), _be32(d, 4), _be32(d, 8), _be32(d, 12))


## [0, 2^32) 정수 하나
func next_u32() -> int:
	var old_hi := _hi
	var old_lo := _lo
	_step()
	# xorshifted = ((old >> 18) ^ old) >> 27 (아래 32비트) · rot = old >> 59
	var t_hi := old_hi ^ (old_hi >> 18)
	var t_lo := old_lo ^ (((old_hi << 14) | (old_lo >> 18)) & M32)
	var x := ((t_hi << 5) | (t_lo >> 27)) & M32
	var rot := old_hi >> 27
	return ((x >> rot) | (x << ((32 - rot) & 31))) & M32


## [0, n) 정수 — pcg32_boundedrand_r 거절법(편향 없음). n 은 1 ~ 2^32
func below(n: int) -> int:
	var threshold := (0x100000000 - n) % n
	var r := next_u32()
	while r < threshold:
		r = next_u32()
	return r % n


## 만분율 확률(bp 10000 = 100%) — 실수 확률을 쓰지 않는다(설계서 3-6)
func chance_bp(bp: int) -> bool:
	return below(10000) < bp


## state = state × MUL + inc (mod 2^64)
func _step() -> void:
	var a0 := _lo & 0xFFFF
	var a1 := _lo >> 16
	var b0 := MUL_LO & 0xFFFF
	var b1 := MUL_LO >> 16
	var mid := a1 * b0 + a0 * b1                      # < 2^33
	var low := a0 * b0 + ((mid & 0xFFFF) << 16)       # < 2^33
	var high := a1 * b1 + (mid >> 16) + (low >> 32)   # lo × MUL_LO 의 위 32비트(+ 넘침 조금)
	var new_lo := low & M32
	var new_hi := (high + _mul32_lo(_hi, MUL_LO) + _mul32_lo(_lo, MUL_HI)) & M32
	var s := new_lo + _inc_lo
	_lo = s & M32
	_hi = (new_hi + _inc_hi + (s >> 32)) & M32


## (x × y) mod 2^32 — x · y < 2^32, 16비트 조각 곱
static func _mul32_lo(x: int, y: int) -> int:
	var x0 := x & 0xFFFF
	var y0 := y & 0xFFFF
	return (x0 * y0 + ((((x >> 16) * y0 + x0 * (y >> 16)) & 0xFFFF) << 16)) & M32


static func _be32(d: PackedByteArray, i: int) -> int:
	return (d[i] << 24) | (d[i + 1] << 16) | (d[i + 2] << 8) | d[i + 3]
