"""기준 구현(Python 정수) — PCG32 · 갈래 스트림 · 정규형 JSON 해시. GDScript 쪽이 이것과 같아야 한다.
(C1-0 빈 시뮬 기준 구현은 C1 본체에서 sim/turn.gd 가 들어와 지웠다 — 시나리오 A 기준 해시는 tests/integration/golden_a.json)

    python3 -B tools/rng_ref.py --write   # tests/unit/rng_vectors.json 을 다시 쓴다
    python3 -B tools/rng_ref.py --check   # 다시 만들어 파일과 같은지 + 공개 PCG32 데모 수열과 같은지(scripts/verify.py 가 부른다)

설계: docs/C1_설계서_상태와턴.md 3-1(RNG) · 3-2(해시) · 요구: FR-103 · FR-104
GDScript: sim/rng.gd · sim/hash.gd · 시험: tests/unit/test_rng.gd · test_hash.gd
"""
import hashlib
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VECTORS = os.path.join(ROOT, "tests", "unit", "rng_vectors.json")
M32 = 0xFFFFFFFF
M64 = (1 << 64) - 1
MUL = 6364136223846793005
# pcg-c-basic pcg32-demo: pcg32_srandom_r(&rng, 42u, 54u) 뒤 처음 6개(공개 출력)
DEMO = (42, 54, [0xA15C02B7, 0x7B47F409, 0xBA1D3330, 0x83D2F293, 0xBFA4784B, 0xCBED606E])


class Pcg32:
    def __init__(self, initstate, initseq):
        self.state = 0
        self.inc = ((initseq << 1) | 1) & M64
        self.next_u32()
        self.state = (self.state + initstate) & M64
        self.next_u32()

    def next_u32(self):
        old = self.state
        self.state = (old * MUL + self.inc) & M64
        xorshifted = (((old >> 18) ^ old) >> 27) & M32
        rot = old >> 59
        return ((xorshifted >> rot) | (xorshifted << ((-rot) & 31))) & M32

    def below(self, bound):
        threshold = ((1 << 32) - bound) % bound
        while True:
            r = self.next_u32()
            if r >= threshold:
                return r % bound


def stream(seed, turn, phase, target):
    d = hashlib.sha256(f"{seed}|{turn}|{phase}|{target}".encode("utf-8")).digest()
    return Pcg32(int.from_bytes(d[0:8], "big"), int.from_bytes(d[8:16], "big"))


def canonical(v):
    """정렬 키 · 공백 없는 JSON — 정수 · 문자열 · 참거짓 · null · 배열 · 문자열 키 dict 만(실수는 거절)."""
    def chk(x):
        if isinstance(x, float):
            raise ValueError("실수는 쓸 수 없다")
        if isinstance(x, dict):
            for k, y in x.items():
                if not isinstance(k, str):
                    raise ValueError("키가 문자열이 아니다")
                chk(y)
        elif isinstance(x, list):
            for y in x:
                chk(y)
    chk(v)
    return json.dumps(v, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def sha16(v):
    return hashlib.sha256(canonical(v).encode("utf-8")).hexdigest()[:16]


# 정규형 시험 값 — tests/unit/test_hash.gd 가 같은 이름으로 같은 값을 만든다
HASH_VALUES = {
    "empty": {},
    "nested": {"b": 1, "a": [3, 1, 2], "B": {"z": True, "y": None}, "가": "값"},
    "escape": {"s": "따옴표\" 역슬래시\\ 줄\n탭\t제어\u0001"},
    "ints": {"n": -5, "big": 4294967295, "zero": 0},
}


def _split(x):
    return [x >> 32, x & M32]


def build():
    seeded = []
    for st, sq in ((42, 54), (0, 0), (M64, M64), (0x0123456789ABCDEF, 0xFEDCBA9876543210)):
        r = Pcg32(st, sq)
        seeded.append({"state": _split(st), "seq": _split(sq), "out": [r.next_u32() for _ in range(8)]})
    streams = []
    for seed, turn, phase, target in ((1, 1, "stub", "acc"), (12345, 7, "manage", "baekui"), (-3, 26, "settle", "가나")):
        r = stream(seed, turn, phase, target)
        streams.append({"seed": seed, "turn": turn, "phase": phase, "target": target, "out": [r.next_u32() for _ in range(5)]})
    below = []
    for bound in (1, 2, 7, 10000, 0x80000001):
        r = stream(1, 1, "below", str(bound))
        below.append({"bound": bound, "target": str(bound), "out": [r.below(bound) for _ in range(6)]})
    hashes = {k: {"text": canonical(v), "hash": sha16(v)} for k, v in HASH_VALUES.items()}
    return {"_about": "tools/rng_ref.py --write 가 만든다 — 손으로 고치지 않는다. 64비트 값은 [hi, lo] 32비트 두 쪽(JSON 수는 Godot 에서 실수라 2^53 을 넘으면 틀어진다)",
            "seeded": seeded, "streams": streams, "below": below, "hash": hashes}


def _text(data):
    return json.dumps(data, ensure_ascii=False, indent=1, sort_keys=True) + "\n"


def main(argv):
    r = Pcg32(DEMO[0], DEMO[1])
    demo = [r.next_u32() for _ in range(len(DEMO[2]))]
    if demo != DEMO[2]:
        print(f"[FAIL] PCG32 공개 데모 수열과 다르다: {[hex(x) for x in demo]}")
        return 1
    text = _text(build())
    if "--write" in argv:
        with open(VECTORS, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print(f"썼다: {os.path.relpath(VECTORS, ROOT)}")
        return 0
    try:
        with open(VECTORS, encoding="utf-8") as f:
            same = f.read() == text
    except OSError:
        same = False
    print("PCG32 공개 데모 수열과 같다 · " + ("기대값 파일이 기준 구현과 같다" if same else "기대값 파일이 기준 구현과 다르다 — --write 로 다시 쓴다"))
    return 0 if same else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
