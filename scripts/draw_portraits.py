"""인물 초상 그리기 — 일러스트 흉상(3/4 돌린 얼굴 · 셀 음영 · 굵기가 변하는 잉크 선) SVG. 도트를 쓰지 않는다
(2026-11-11 사용자 지시 · docs/기획_차이.md (라)12 · 2차 고침 (나)37).

    python3 -B scripts/draw_portraits.py           # assets/chars/looks.json → assets/chars/svg/<id>.svg (같은 looks 면 같은 파일 · 멱등)
    python3 -B scripts/draw_portraits.py --check   # 다시 그려 대조 · 명단 인물이 모두 있는지 · XML 이 맞는지(scripts/verify.py '인물 그림' 단계)

- 무엇: 장르 팩 시나리오 명단(roster · assign)의 인물마다 흉상 한 장(256×256 viewBox · 배경 투명 · 384px 로 가져옴).
  얼굴은 화면 왼쪽으로 조금 돌렸다(3/4) — 마주 보게 할 곳(전투 일기토)은 화면이 좌우를 뒤집는다(ui/sprites.gd box(flip)).
  배경 · 세력색 판은 화면(ui/)이 깐다 — 그림은 사람만 그린다.
- 원본: assets/chars/looks.json(사람 손으로 고쳐도 되는 외형 표 — 머리 모양 · 색 · 안경 · 수염 · 옷). 처음 값은 취호전 도트 초상의 색과
  canon look 글의 낱말에서 한 번 뽑았다(assets/ASSETS.md). 원작 컷은 읽지도 넣지도 않는다(CLAUDE.md 13절).
- 화풍: 기획_차이 (나)34 · (나)37 — 수상작(TGA 2019 전략 부문)에서 고른 '그림 초상이 화면 중심 · 셀 음영' 방향만 따른다.
  다른 게임의 그림 · 캐릭터 · 문양을 베끼지 않는다(장르 문법만). 빛은 왼쪽 위 — 그늘은 오른쪽 아래 가장자리에 진다.
- 결정성: 난수 대신 sha256(id) 로 작은 차이(앞머리 끝 · 눈썹 각 · 입 · 흘러내린 가닥)를 고른다. 순회는 정렬한 id.
- 요구: FR-212(정정 · C3) · 쓰는 곳: ui/sprites.gd
"""
import hashlib
import json
import math
import os
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOOKS = os.path.join(ROOT, "assets", "chars", "looks.json")
OUT = os.path.join(ROOT, "assets", "chars", "svg")
SCEN = os.path.join(ROOT, "data", "common", "packs", "strategy", "scenarios.json")
CANON = os.path.join(ROOT, "data", "common", "canon", "characters.json")

LINE = "#1c1420"
SHADE = (50, 32, 72)          # 그늘 쪽 섞는 색(차가운 보라)
LIGHT = (255, 247, 236)
COOL = (150, 176, 226)        # 검은 머리 윤기(푸른 빛)
PX = 384                      # 가져올 때 크기(화면 최대 ~300px · 밉맵)
STYLES = ("slick", "short", "bangs", "undercut", "buzz", "bald", "long", "bob", "tied", "wavy")
OUTFITS = ("suit", "coat", "shirt", "turtle", "hood", "jacket", "tee", "tank", "cardigan", "kimono", "dress")
FRINGE = ("short", "bangs", "long", "bob", "wavy")          # 앞머리가 이마를 덮는 모양 — 눈썹을 머리 위에 다시 그린다
EAR_HIDDEN = ("long", "bob", "wavy")                        # 귀를 머리가 덮는다


# ---------- 색 ----------
def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hexc(c):
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(round(v)))) for v in c)


def mix(a, b, t):
    a, b = rgb(a) if isinstance(a, str) else a, rgb(b) if isinstance(b, str) else b
    return hexc(tuple(a[i] + (b[i] - a[i]) * t for i in range(3)))


def shade(h, t=0.32):
    return mix(h, SHADE, t)


def light(h, t=0.35):
    return mix(h, LIGHT, t)


def lum(h):
    r, g, b = rgb(h)
    return 0.299 * r + 0.587 * g + 0.114 * b


def line_of(h, t=0.6):
    """그 색 면의 외곽선 색 — 검정 대신 그 색의 아주 짙은 쪽(선이 색을 먹지 않게)."""
    return mix(shade(h, 0.8), LINE, t)


# ---------- 결정적 작은 차이 ----------
class Pick:
    def __init__(self, key):
        self._b = hashlib.sha256(key.encode("utf-8")).digest()
        self._i = 0

    def u(self):
        v = self._b[self._i % len(self._b)] / 255.0
        self._i += 1
        return v

    def pm(self, k):
        return (self.u() * 2.0 - 1.0) * k


def f(v):
    s = ("%.1f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def op(v):
    return ' opacity="%s"' % ("%.2f" % v).rstrip("0").rstrip(".")


def P(*pts):
    """("M", x, y, "C", ...) → 'M x y C …'"""
    return " ".join(p if isinstance(p, str) else f(p) for p in pts)


def path(d, fill, stroke=None, w=0.0, extra=""):
    st = ' stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"' % (stroke, f(w)) if stroke else ""
    return '<path d="%s" fill="%s"%s%s/>' % (d, fill, st, extra)


def fills(shapes, col, extra=""):
    return "".join('<path d="%s" fill="%s"%s/>' % (d, col, extra) for d in shapes)


def union(shapes, w, line):
    """겹친 모양들의 바깥 외곽선만 — 굵은 선을 먼저 깔고(그 위에 채움을 덮어) 안쪽 경계선이 안 보이게. w = 밖으로 보이는 굵기."""
    s = "".join('<path d="%s"/>' % d for d in shapes)
    return '<g fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round">%s</g>' % (line, line, f(w * 2), s)


def clip(cid, d):
    """자르기 모양 하나. 여러 path 를 한 clipPath 에 넣지 않는다 — Godot 의 SVG 그리기(ThorVG)는 그것들을 감는 방향으로 합쳐
    겹친 곳이 구멍이 된다(앞머리 다발 · 빡빡머리 색이 빠짐 — 2026-11-11 확인). 겹친 모양은 모양마다 따로 자른다."""
    return '<clipPath id="%s"><path d="%s"/></clipPath>' % (cid, d)


# ---------- 잉크 선(굵기가 변하는 붓선 — 채운 모양) ----------
def _cub(seg):
    if len(seg) == 3:
        (x0, y0), (cx, cy), (x1, y1) = seg
        return ((x0, y0), (x0 + (cx - x0) * 2 / 3, y0 + (cy - y0) * 2 / 3), (x1 + (cx - x1) * 2 / 3, y1 + (cy - y1) * 2 / 3), (x1, y1))
    return seg


def _pts(seg, n):
    (x0, y0), (x1, y1), (x2, y2), (x3, y3) = _cub(seg)
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        out.append((u * u * u * x0 + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t * t * t * x3,
                    u * u * u * y0 + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t * y3))
    return out


PROF = {
    "mid": lambda t: 0.1 + 0.9 * math.sin(math.pi * t),                              # 가운데 굵음
    "in": lambda t: min(1.0, 0.3 + t * 6) * (1.0 - 0.88 * t),                         # 시작 굵음
    "out": lambda t: min(1.0, 0.3 + (1 - t) * 6) * (0.12 + 0.88 * t),                 # 끝 굵음
    "lash": lambda t: min(1.0, (1 - t) * 7 + 0.15) * (0.35 + 0.65 * t ** 0.6),        # 위 눈꺼풀 — 바깥으로 굵어짐
    "even": lambda t: 0.25 + 0.75 * min(1.0, t * 5, (1 - t) * 5),
}


def ink(seg, w, col, prof="mid", alpha=None, n=10):
    pts = _pts(seg, n)
    left, right = [], []
    for i, (x, y) in enumerate(pts):
        a, b = pts[max(0, i - 1)], pts[min(n, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / ln, dx / ln
        hw = w * PROF[prof](i / n) / 2
        left.append((x + nx * hw, y + ny * hw))
        right.append((x - nx * hw, y - ny * hw))
    ring = left + right[::-1]
    d = "M %s %s L " % (f(ring[0][0]), f(ring[0][1])) + " ".join("%s %s" % (f(x), f(y)) for x, y in ring[1:]) + " Z"
    return '<path d="%s" fill="%s"%s/>' % (d, col, op(alpha) if alpha is not None else "")


def sub_c(seg, s):
    """3차 곡선의 앞 s 만큼(de Casteljau)."""
    def lerp(a, b):
        return (a[0] + (b[0] - a[0]) * s, a[1] + (b[1] - a[1]) * s)
    p0, p1, p2, p3 = seg
    q0, q1, q2 = lerp(p0, p1), lerp(p1, p2), lerp(p2, p3)
    r0, r1 = lerp(q0, q1), lerp(q1, q2)
    return (p0, q0, r0, lerp(r0, r1))


# ---------- 머리카락 부품 ----------
def lock(a, b, tip, bend=0.0):
    """머리 다발 — 뿌리 a(왼) · b(오른) → 끝 tip. 두 가는 뿌리에서 곧게 내려와(이웃 다발과 겹쳐 틈이 없게) 끝 쪽에서 모인다.
    반환 (d, 오른쪽 가 3차 곡선 (tip, c1, c2, b)) — 다발 나눔 선을 끝에서 위로 긋는 데 쓴다."""
    ax, ay = a
    bx, by = b
    tx, ty = tip
    l1 = (ax, ay + (ty - ay) * 0.45)
    l2 = (tx + (ax - tx) * 0.3 + bend, ty - (ty - ay) * 0.3)
    r1 = (tx + (bx - tx) * 0.18 + bend * 0.5, ty - (ty - by) * 0.42)
    r2 = (bx, by + (ty - by) * 0.4)
    d = P("M", ax, ay, "C", l1[0], l1[1], l2[0], l2[1], tx, ty, "C", r1[0], r1[1], r2[0], r2[1], bx, by, "Z")
    return d, ((tx, ty), r1, r2, (bx, by))


def sliver(cx, cy, ln, ang, wd):
    """윤기 조각 — 가운데가 볼록한 가는 잎 모양(ang 도 방향)."""
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    nx, ny = -uy, ux
    p0 = (cx - ux * ln / 2, cy - uy * ln / 2)
    p1 = (cx + ux * ln / 2, cy + uy * ln / 2)
    return P("M", p0[0], p0[1], "Q", cx + nx * wd, cy + ny * wd, p1[0], p1[1], "Q", cx - nx * wd * 0.5, cy - ny * wd * 0.5, p0[0], p0[1], "Z")


def fringe(pk, n, x0, x1, root_y, tip_y, sweep, drop=6.0, jit=3.0, bend=-2.0):
    """앞머리 다발 n 개 — 뿌리는 머리 둥근 선을 따르고(가운데 높음) 끝은 tip_y 근처 · sweep 만큼 옆으로 쓸린다."""
    out = []
    for i in range(n):
        a = x0 + (x1 - x0) * i / n - 4
        b = x0 + (x1 - x0) * (i + 1) / n + 4
        mid = (a + b) / 2
        ry = root_y + ((mid - 124) / 48.0) ** 2 * 18
        s = math.sin(math.pi * (i + 0.5) / n)
        ty = tip_y - (1 - s) * drop + pk.pm(jit)
        tx = mid + sweep + pk.pm(2.0)
        out.append(lock((a, ry), (b, ry), (tx, max(ty, ry + 14)), bend + pk.pm(1.5)))
    return out


# 머리 공간 좌표(256×256): 얼굴 x 82~172 · 눈 y 120 · 턱 끝 (122, 182) · 귀(가까운 쪽) x 170~188 · 정수리 y ~38
_EAR_TOP = ("L", 186, 106, "C", 180, 101, 174, 101, 170, 106, "L", 170, 88, "C", 150, 78, 108, 74, 84, 88, "Z")
CAP_SPIKY = P("M", 80, 110, "C", 72, 84, 76, 56, 94, 38, "C", 108, 24, 126, 16, 146, 16, "C", 164, 16, 178, 20, 190, 26,
              "Q", 198, 24, 206, 18, "Q", 202, 30, 202, 36, "Q", 212, 42, 220, 46, "Q", 212, 56, 210, 64,
              "Q", 216, 76, 220, 86, "Q", 210, 94, 204, 102, *_EAR_TOP)
CAP_SMOOTH = P("M", 80, 110, "C", 72, 82, 80, 50, 104, 34, "C", 122, 22, 142, 20, 158, 22, "C", 182, 26, 200, 44, 204, 70,
               "C", 206, 86, 204, 98, 200, 106, *_EAR_TOP)
NAPE = P("M", 166, 98, "L", 202, 100, "C", 204, 122, 198, 138, 190, 152, "L", 166, 152, "Z")
SKULL = P("M", 84, 100, "C", 78, 64, 100, 38, 130, 38, "C", 162, 38, 188, 58, 190, 94,
          "C", 192, 116, 188, 134, 182, 148, "L", 166, 150, "L", 166, 110, "Z")


def hair_spec(lk, pk):
    """머리 모양 → 그릴 조각들.
    behind: 몸 뒤(묶은 머리 · 꽁지) · back: 머리 뒤 덩어리 · front: 이마 위 덩어리(+다발) · edges: 다발 나눔 선 곡선 · strands: 결 선
    shine: 윤기 조각 · skull: 두피가 보임(빡빡 · 대머리 · 옆 민 머리)."""
    st = lk["style"]
    sp = {"behind": [], "back": [], "front": [], "edges": [], "strands": [], "shine": [], "skull": False, "shaved": None, "tint": None}

    def add(d, e):   # 다발 하나 — 나눔 선은 그 다발 안에서만 긋는다(edges = (front 번호, 곡선))
        sp["front"].append(d)
        sp["edges"].append((len(sp["front"]) - 1, e))
    if st == "bald":
        sp["skull"] = True
        return sp
    if st == "buzz":
        sp["skull"] = True
        sp["tint"] = P("M", 82, 104, "C", 78, 70, 98, 40, 130, 40, "C", 162, 40, 188, 60, 190, 96, "L", 186, 104,
                       "C", 180, 100, 174, 100, 170, 104, "L", 170, 92, "C", 158, 76, 144, 72, 128, 72,
                       "C", 108, 72, 92, 82, 86, 100, "Z")
        return sp
    if st == "undercut":
        sp["skull"] = True
        sp["shaved"] = P("M", 84, 100, "C", 82, 84, 86, 76, 92, 72, "L", 190, 72, "C", 194, 96, 192, 124, 184, 146,
                         "L", 176, 146, "L", 172, 104, "L", 170, 92, "C", 150, 80, 110, 80, 88, 100, "Z")
        top = P("M", 86, 92, "C", 78, 66, 88, 36, 116, 24, "L", 112, 14, "C", 132, 12, 150, 12, 166, 18, "L", 176, 12,
                "C", 186, 22, 194, 34, 196, 50, "L", 204, 56, "C", 198, 66, 194, 74, 188, 80, "L", 172, 82,
                "C", 158, 74, 144, 72, 130, 74, "C", 112, 76, 98, 82, 92, 94, "Z")
        sp["front"] = [top]
        d, e = lock((96, 74), (122, 70), (88, 108), -4 + pk.pm(2))
        add(d, e)
        sp["strands"] = [((100, 80), (110, 50), (146, 30)), ((122, 74), (138, 48), (176, 36)), ((146, 74), (162, 56), (192, 54))]
        sp["shine"] = [(108, 44, 16, -50, 3.2), (126, 34, 16, -30, 3.4), (146, 28, 14, -12, 3.0)]
        return sp
    if st in ("slick", "tied"):
        tied = st == "tied"
        top = 30 if tied else 26
        sp["back"] = [NAPE]
        back = (("C", 164, top + 4, 186, 34, 196, 52, "C", 202, 66, 202, 86, 198, 104) if tied else
                ("C", 164, 22, 182, 26, 194, 32, "Q", 204, 30, 214, 26, "Q", 208, 38, 208, 44, "Q", 216, 52, 222, 60,
                 "Q", 214, 68, 212, 76, "Q", 216, 88, 216, 100, "Q", 208, 102, 204, 106))
        sp["front"] = [P("M", 82, 106, "C", 78, 86, 78, 64, 88, 48, "C", 100, 30, 120, top, 144, top, *back, "L", 186, 104,
                         "C", 180, 100, 174, 100, 170, 104, "L", 170, 92, "C", 160, 78, 146, 72, 132, 72,
                         "C", 124, 72, 120, 70, 116, 74, "C", 104, 74, 92, 82, 88, 96, "L", 86, 108, "Z")]
        far = 0 if not tied else -14
        sp["strands"] = [((94, 90), (98, 60), (130, 36), (176 + far, 30 + (8 if tied else 0))),
                         ((108, 78), (122, 52), (160, 40), (208 + far, 32 + (10 if tied else 0))),
                         ((126, 74), (146, 56), (180, 50), (216 + far, 58)),
                         ((146, 74), (166, 64), (190, 66), (212 + far * 0.6, 84)),
                         ((162, 80), (176, 78), (192, 86), (204 + far * 0.4, 100))]
        sp["shine"] = [(104, 50, 16, -55, 3.2), (122, 38, 18, -30, 3.8), (142, 32, 18, -10, 3.8), (162, 32, 16, 6, 3.4), (182, 38, 14, 22, 3.0)]
        if tied:
            bx = 178 + pk.pm(3)
            sp["behind"].append(P("M", bx - 18, 34, "C", bx - 22, 10, bx + 4, 2, bx + 16, 12, "C", bx + 26, 22, bx + 20, 42, bx + 4, 46, "Z"))
            if lk["sex"] == "f":
                sp["behind"].append(P("M", 182, 52, "C", 206, 80, 214, 140, 204, 200, "C", 200, 220, 196, 232, 190, 240,
                                      "C", 196, 210, 192, 150, 170, 90, "Z"))
                d, e = lock((96, 76), (114, 72), (92, 140), -6)
                add(d, e)
        elif pk.u() > 0.35:   # 흘러내린 가닥
            x = 116 + pk.pm(8)
            d, e = lock((x - 6, 72), (x + 6, 72), (x - 8 + pk.pm(3), 104 + pk.pm(4)), -3)
            add(d, e)
            if pk.u() > 0.6:
                d, e = lock((x + 4, 72), (x + 14, 72), (x + 10, 96), -1)
                add(d, e)
        return sp
    # 앞머리가 있는 모양: short · bangs · long · bob · wavy
    sp["front"] = [CAP_SPIKY if st in ("short", "bangs") else CAP_SMOOTH]
    if st in ("short", "bangs"):
        sp["back"] = [NAPE]
    elif st == "long":
        sp["back"] = [P("M", 72, 150, "C", 64, 110, 66, 76, 84, 56, "C", 102, 40, 126, 36, 144, 36, "C", 176, 36, 200, 50, 206, 80,
                        "C", 212, 110, 206, 150, 210, 190, "C", 212, 214, 218, 236, 226, 256, "L", 30, 256,
                        "C", 42, 234, 52, 210, 60, 186, "C", 66, 172, 70, 162, 72, 150, "Z")]
    elif st == "bob":
        sp["back"] = [P("M", 80, 150, "C", 74, 120, 72, 96, 80, 74, "C", 90, 50, 116, 40, 142, 40, "C", 176, 40, 200, 56, 204, 84,
                        "C", 208, 116, 206, 152, 200, 184, "C", 188, 192, 176, 190, 166, 184, "L", 150, 184, "L", 110, 190, "L", 84, 176, "Z")]
    else:   # wavy
        sp["back"] = [P("M", 82, 150, "C", 74, 120, 72, 96, 80, 74, "C", 90, 50, 116, 40, 142, 40, "C", 176, 40, 200, 56, 204, 84,
                        "C", 208, 110, 200, 130, 206, 150, "C", 210, 160, 204, 168, 198, 172, "L", 150, 176, "L", 110, 182, "L", 84, 168, "Z")]
    tip = {"short": 96, "bangs": 108, "long": 104, "bob": 106, "wavy": 100}[st]
    n = {"short": 7, "bangs": 7, "long": 6, "bob": 6, "wavy": 5}[st]
    sweep = -7.0 + pk.pm(3)
    for d, e in fringe(pk, n, 84, 172, 50, tip, sweep, drop=8.0 if st != "bangs" else 5.0, bend=-3.0 if st != "wavy" else -6.0):
        add(d, e)
    if st == "bob":   # 턱 길이 커튼 두 장(끝이 안으로 말림)
        add(P("M", 76, 82, "C", 68, 116, 68, 156, 72, 186, "L", 80, 180, "L", 87, 191, "C", 95, 184, 100, 176, 102, 166,
              "C", 102, 140, 104, 116, 104, 100, "Z"), ((86, 188), (87, 170), (90, 150), (95, 126)))
        add(P("M", 156, 98, "C", 160, 120, 162, 150, 164, 176, "L", 172, 185, "L", 178, 177, "L", 189, 189,
              "C", 195, 160, 195, 120, 186, 86, "Z"), ((177, 182), (175, 162), (173, 140), (171, 118)))
    elif st == "wavy":   # 물결 커튼 두 장
        add(P("M", 76, 82, "C", 66, 104, 74, 124, 68, 146, "C", 64, 160, 72, 168, 70, 178, "L", 80, 170, "L", 86, 180,
              "C", 94, 170, 98, 160, 100, 148, "C", 102, 130, 104, 112, 104, 100, "Z"), ((84, 176), (88, 160), (90, 140), (95, 120)))
        add(P("M", 156, 98, "C", 160, 118, 160, 140, 166, 160, "L", 174, 170, "L", 178, 160, "L", 190, 172,
              "C", 196, 156, 188, 140, 194, 122, "C", 198, 106, 192, 94, 186, 86, "Z"), ((178, 164), (176, 146), (172, 128), (170, 110)))
    elif st == "long":   # 얼굴 옆 다발
        ly = 236
        far, near = lock((74, 82), (102, 102), (72 + pk.pm(3), ly - 4), -9), lock((158, 98), (186, 86), (194 + pk.pm(3), ly), 10)
        for d, e in (far, near):
            add(d, e)
        add(*lock((84, 118), (100, 124), (86 + pk.pm(3), ly - 30), -4))   # 앞에 한 가닥씩 더(겹친 다발)
        add(*lock((170, 128), (186, 122), (182 + pk.pm(3), ly - 24), 5))
    sp["strands"] = [((112, 40), (106, 50), (102, 62)), ((132, 36), (128, 48), (124, 60)), ((152, 40), (150, 52), (146, 62))]
    sp["shine"] = [(98, 62, 13, -70, 2.6), (114, 52, 14, -82, 3.0), (132, 50, 14, 92, 3.0), (150, 54, 13, 76, 2.6), (166, 62, 11, 60, 2.2)]
    return sp


# ---------- 얼굴 ----------
FACE = {
    "m": P("M", 84, 96, "C", 80, 108, 79, 118, 82, 128, "C", 84, 140, 88, 150, 96, 160, "C", 102, 168, 108, 176, 116, 180,
           "C", 120, 182, 126, 182, 130, 180, "C", 142, 174, 154, 166, 160, 156, "C", 166, 146, 169, 132, 170, 118, "L", 172, 96,
           "C", 172, 70, 150, 50, 126, 50, "C", 102, 50, 86, 70, 84, 96, "Z"),
    "f": P("M", 86, 98, "C", 82, 110, 82, 120, 85, 130, "C", 88, 142, 94, 154, 102, 164, "C", 108, 172, 114, 178, 120, 180,
           "C", 124, 181, 128, 180, 131, 178, "C", 142, 172, 152, 164, 158, 154, "C", 163, 144, 166, 130, 167, 116, "L", 168, 96,
           "C", 168, 70, 148, 52, 126, 52, "C", 104, 52, 88, 70, 86, 96, "Z"),
}
FACE_SHADOW = {   # 가까운 쪽(오른쪽) 볼 · 턱 그늘 — 광대 밑에서 한 번 들어간다
    "m": P("M", 173, 92, "L", 170, 118, "C", 169, 132, 166, 146, 160, 156, "C", 154, 166, 142, 174, 130, 180,
           "C", 140, 172, 150, 164, 155, 152, "C", 158, 144, 159, 136, 160, 129, "C", 163, 118, 164, 104, 165, 92, "Z"),
    "f": P("M", 169, 92, "L", 167, 116, "C", 166, 130, 163, 144, 158, 154, "C", 152, 164, 142, 172, 131, 178,
           "C", 140, 170, 148, 162, 152, 152, "C", 155, 144, 156, 136, 157, 129, "C", 160, 118, 161, 104, 162, 92, "Z"),
}
NECK = {
    "m": P("M", 100, 156, "C", 104, 174, 102, 192, 96, 208, "L", 168, 208, "C", 164, 192, 162, 172, 162, 146, "Z"),
    "f": P("M", 107, 160, "C", 110, 176, 109, 192, 105, 208, "L", 160, 208, "C", 156, 194, 154, 176, 155, 150, "Z"),
}
NECK_SHADOW = P("M", 94, 150, "C", 106, 174, 118, 186, 130, 184, "C", 144, 178, 156, 168, 166, 144, "L", 170, 190,
                "C", 150, 198, 118, 200, 94, 194, "Z")
EAR = P("M", 170, 110, "C", 176, 100, 190, 103, 188, 119, "C", 187, 131, 182, 141, 171, 144, "Z")
EAR_RIM = ((171, 108), (180, 100), (191, 108), (188, 121), (186, 133), (181, 141), (172, 144))


def eye(cid, k, inner, outer, h, lk, iris_col, lift):
    """한쪽 눈 — inner(콧대 쪽) · outer(바깥 끝). 반환 (defs, 조각들)."""
    sex = lk["sex"]
    skin = lk["skin"]
    ix, iy = inner
    ox, oy = outer[0], outer[1] - lift
    W = abs(ox - ix)
    dx = 1.0 if ox > ix else -1.0
    up = ((ix, iy), (ix + dx * 0.2 * W, iy - h * 1.15), (ox - dx * 0.34 * W, oy - h * 0.95), (ox, oy))
    lo = ((ox, oy), (ox - dx * 0.3 * W, oy + h * 0.5), (ix + dx * 0.25 * W, iy + h * 0.55), (ix, iy))
    shape = P("M", ix, iy, "C", up[1][0], up[1][1], up[2][0], up[2][1], ox, oy, "C", lo[1][0], lo[1][1], lo[2][0], lo[2][1], ix, iy, "Z")
    eid = "e%d_%s" % (k, cid)
    defs = [clip(eid, shape)]
    gid = "ig%d_%s" % (k, cid)
    defs.append('<linearGradient id="%s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/><stop offset="0.5" stop-color="%s"/>'
                '<stop offset="1" stop-color="%s"/></linearGradient>' % (gid, shade(iris_col, 0.7), iris_col, light(iris_col, 0.5)))
    out = [path(shape, "#f8f4ef")]
    rx = W * (0.31 if sex == "m" else 0.34)
    ry = (9.4 if sex == "m" else 10.8) * (1.0 if h > 7 else 0.92)
    cx = ix + dx * W * 0.53 - 1.8          # 시선은 조금 왼쪽
    cy = (iy + oy) / 2 + h * 0.08
    lid_sh = P("M", ix, iy - 1, "C", up[1][0], up[1][1], up[2][0], up[2][1], ox, oy - 1, "L", ox, oy + 3,
               "C", up[2][0], up[2][1] + 5, up[1][0], up[1][1] + 5, ix, iy + 2, "Z")
    g = ['<g clip-path="url(#%s)">' % eid,
         path(lid_sh, mix(skin, "#9a8aa8", 0.55), extra=op(0.55)),
         '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="url(#%s)" stroke="%s" stroke-width="1.1"/>' % (f(cx), f(cy), f(rx), f(ry), gid, shade(iris_col, 0.8)),
         path(P("M", cx - rx * 0.78, cy + ry * 0.2, "Q", cx, cy + ry * 1.05, cx + rx * 0.78, cy + ry * 0.2,
                "Q", cx, cy + ry * 0.62, cx - rx * 0.78, cy + ry * 0.2, "Z"), light(iris_col, 0.62), extra=op(0.55)),
         '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s"/>' % (f(cx), f(cy + 0.4), f(rx * 0.42), f(ry * 0.5), mix(shade(iris_col, 0.85), "#08060a", 0.6)),
         path(P("M", ix, iy - h, "L", ox, oy - h, "L", ox, oy - 0.5, "C", up[2][0], up[2][1] + 3.2, up[1][0], up[1][1] + 3.2, ix, iy + 0.5, "Z"),
              shade(iris_col, 0.9), extra=op(0.5)),
         '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="#ffffff"/>' % (f(cx - rx * 0.36), f(cy - ry * 0.3), f(rx * 0.3), f(rx * 0.36)),
         '<circle cx="%s" cy="%s" r="%s" fill="#ffffff"%s/>' % (f(cx + rx * 0.42), f(cy + ry * 0.36), f(max(1.0, rx * 0.14)), op(0.85)),
         "</g>"]
    out += g
    lw = 3.6 if sex == "m" else 4.4
    out.append(ink(up, lw, LINE, "lash", n=12))
    if sex == "m":
        out.append(ink(((ox - dx * 1.5, oy - 0.8), (ox + dx * 1.5, oy + 0.5), (ox + dx * 0.5, oy + 4.0)), 2.0, LINE, "in", n=6))
    else:
        out.append(ink(((ox - dx * 2, oy - 1.2), (ox + dx * 4, oy - 2.0), (ox + dx * 7.5, oy - 5.5)), 2.8, LINE, "in", n=6))
        out.append(ink(((ox - dx * 5, oy - h * 0.55), (ox - dx * 1, oy - h * 0.9), (ox + dx * 3, oy - h * 1.05)), 1.6, LINE, "in", n=6))
    lash_c = mix(shade(skin, 0.75), LINE, 0.35)
    p_mid = (ix + dx * 0.42 * W, iy + h * 0.42)
    out.append(ink(((ox - dx * 0.5, oy + 1.2), (ox - dx * 0.3 * W, oy + h * 0.56), p_mid), 1.5 if sex == "m" else 1.7, lash_c, "in", n=8))
    out.append(ink(((ix + dx * 0.28 * W, iy - h * 1.05 - 2.6), (ix + dx * 0.55 * W, iy - h * 1.35 - 2.8), (ox - dx * 0.04 * W, oy - h * 0.8 - 2.6)),
                   1.2, shade(skin, 0.48), "mid", n=8))
    return defs, out


def brow(inner, outer, h, lk, pk, kind, lift):
    sex = lk["sex"]
    ix, iy = inner
    ox, oy = outer[0], outer[1] - lift
    dx = 1.0 if ox > ix else -1.0
    col = shade(lk["hair"], 0.5) if lk["style"] != "bald" else mix(shade(lk["skin"], 0.55), "#2a2026", 0.4)
    if lum(lk["hair"]) > 170:   # 흰 · 금빛 머리는 눈썹을 조금 짙게(얼굴에서 사라지지 않게)
        col = shade(lk["hair"], 0.62)
    b0y = iy - h - 9.5 + (3.2 if kind == "sharp" else 0.0) + (1.5 if kind == "droopy" else 0.0)
    b1y = oy - h - 9.0 - (1.5 if kind == "sharp" else 0.0) + (2.5 if kind == "droopy" else 0.0)
    b0 = (ix - dx * 1.5, b0y + pk.pm(1.0))
    b1 = (ox + dx * 3.5, b1y + pk.pm(1.2))
    arch = ((b0[0] + b1[0]) / 2 - dx * 2, min(b0[1], b1[1]) - (3.5 if kind != "sharp" else 2.0))
    return ink((b0, arch, b1), 5.4 if sex == "m" else 3.0, col, "in", n=10)


def face_feats(cid, lk, pk):
    """눈 · 눈썹 · 코 · 입 · 주름 — (defs, 얼굴 조각들, 눈썹 조각들)."""
    sex = lk["sex"]
    skin = lk["skin"]
    kind = lk.get("eyes", "normal")
    iris = lk.get("iris") or ("#4a3426" if lum(lk["hair"]) < 120 else "#6a4a32")
    h = {"sharp": 7.2, "droopy": 8.2, "normal": 9.0}.get(kind, 9.0) + (2.8 if sex == "f" else 0.0)
    lift = {"sharp": 1.6, "droopy": -3.2}.get(kind, 0.0)
    y0 = 120 if sex == "m" else 121
    far_i, far_o = (110, y0 + 1), (89, y0 - 2)
    near_i, near_o = (127, y0 + 1), (155, y0 - 3)
    if sex == "f":
        far_o, near_o = (88, y0 - 2), (156, y0 - 3)
    defs, out, brows = [], [], []
    # 볼 홍조(부드러운 원형 그러데이션)
    defs.append('<radialGradient id="bl_%s"><stop offset="0" stop-color="#ee7d74" stop-opacity="%s"/>'
                '<stop offset="1" stop-color="#ee7d74" stop-opacity="0"/></radialGradient>' % (cid, "0.42" if sex == "f" else "0.12"))
    out.append('<ellipse cx="96" cy="140" rx="13" ry="7" fill="url(#bl_%s)"/>' % cid)
    out.append('<ellipse cx="148" cy="140" rx="15" ry="8" fill="url(#bl_%s)"/>' % cid)
    for k, (i_, o_) in enumerate(((far_i, far_o), (near_i, near_o))):
        d2, o2 = eye(cid, k, i_, o_, h, lk, iris, lift)
        defs += d2
        out += o2
        brows.append(brow(i_, o_, h, lk, pk, kind, lift))
    sk_d = mix(shade(skin, 0.72), LINE, 0.3)
    # 코 — 콧대 빛 · 가까운 쪽 그늘 · 코끝 밑선
    if sex == "m":
        out.append(path(P("M", 121, 127, "C", 123.5, 136, 124.5, 143, 121, 149, "L", 116, 149, "C", 119, 143, 120, 136, 121, 127, "Z"), shade(skin, 0.3)))
        out.append(ink(((119.5, 124), (119, 134), (114.5, 145)), 1.2, shade(skin, 0.42), "mid", 0.7))
        out.append(ink(((108, 148.5), (113.5, 152.5), (121.5, 149)), 2.1, sk_d, "mid"))
        out.append('<ellipse cx="115" cy="139" rx="1.5" ry="4" fill="%s"%s/>' % (light(skin, 0.7), op(0.6)))
    else:
        out.append(path(P("M", 120, 132, "C", 122, 139, 122, 144, 119.5, 148, "L", 116, 148, "C", 118.5, 144, 119.5, 139, 120, 132, "Z"), shade(skin, 0.24)))
        out.append(ink(((111, 148), (115.5, 151), (120.5, 148.5)), 1.7, sk_d, "mid"))
    smile = (2.2 if lk.get("smile") else 0.0) + pk.pm(0.8)
    if sex == "m":
        my = 162
        out.append(ink(((106, my - smile * 0.6), (117, my + 2.2 + smile), (130, my - 1.2 - smile * 0.6)), 2.3, mix(shade(skin, 0.8), LINE, 0.4), "mid"))
        out.append(ink(((112, my + 7), (117.5, my + 8.6), (124, my + 7)), 1.7, shade(skin, 0.3), "mid"))
    else:
        my = 161
        lip = lk.get("lip") or "#c45a62"
        out.append(path(P("M", 108.5, my + 0.5, "Q", 118, my + 9, 128, my, "Q", 118, my + 4, 108.5, my + 0.5, "Z"), lip, extra=op(0.85)))
        out.append(ink(((106.5, my - smile * 0.5), (118, my + 2.2 + smile), (130, my - 1.5 - smile * 0.5)), 1.9, mix(lip, LINE, 0.55), "mid"))
        out.append('<ellipse cx="117" cy="%s" rx="3.2" ry="1.2" fill="#ffffff"%s/>' % (f(my + 5), op(0.45)))
    if lk.get("old"):
        wr = shade(skin, 0.42)
        out.append(ink(((104, 146), (99, 156), (104, 168)), 1.4, wr, "mid"))
        out.append(ink(((128, 146), (135, 156), (132, 168)), 1.5, wr, "mid"))
        out.append(ink(((92, 130), (99, 134), (107, 131)), 1.0, wr, "mid", 0.8))
        out.append(ink(((132, 131), (142, 135), (152, 131)), 1.0, wr, "mid", 0.8))
        out.append(ink(((158, 116), (162, 119), (164, 124)), 1.1, wr, "mid"))
    if lk.get("mole"):
        out.append('<circle cx="151" cy="134" r="1.5" fill="%s"/>' % shade(skin, 0.65))
    return defs, out, brows


def beard(lk):
    b = lk.get("beard", "none")
    hc = lk["hair"] if lk["style"] != "bald" else "#2a2228"
    out = []
    if b == "stubble":
        out.append('<path d="%s" fill="%s"%s/>' % (
            P("M", 86, 132, "C", 90, 154, 104, 174, 120, 182, "C", 138, 180, 156, 164, 166, 140, "L", 162, 152,
              "C", 152, 160, 140, 164, 130, 170, "C", 126, 168, 112, 168, 104, 160, "C", 96, 152, 90, 142, 86, 132, "Z"), mix(hc, "#3a3440", 0.3), op(0.18)))
        out.append('<path d="%s" fill="%s"%s/>' % (P("M", 104, 157, "C", 110, 153, 124, 153, 132, 157, "L", 130, 160, "C", 122, 157, 112, 157, 106, 160, "Z"),
                                                   mix(hc, "#3a3440", 0.3), op(0.22)))
    elif b == "full":
        sh = P("M", 84, 128, "C", 86, 150, 96, 170, 114, 184, "C", 122, 189, 130, 189, 138, 183, "C", 150, 174, 160, 162, 166, 146,
               "L", 168, 128, "C", 162, 146, 150, 160, 138, 166, "C", 126, 170, 108, 170, 96, 154, "C", 90, 146, 86, 138, 84, 128, "Z")
        out.append(union([sh], 1.2, line_of(hc)))
        out.append(path(sh, shade(hc, 0.1)))
        out.append(ink(((112, 174), (120, 180), (130, 176)), 1.6, light(hc, 0.35), "mid"))
        out.append(ink(((150, 164), (156, 158), (160, 150)), 1.4, shade(hc, 0.5), "mid"))
    if lk.get("mustache") or b == "full":
        for tip in ((101, 159.5), (135, 158)):
            mid = ((118 + tip[0]) / 2, 153.2)
            out.append(ink(((118, 155.6), mid, tip), 4.4, line_of(hc, 0.3), "in", n=8))
            out.append(ink(((118, 155.2), (mid[0], mid[1] + 0.3), tip), 3.0, hc, "in", n=8))
    return out


def extras(lk, pk):
    out = []
    if lk.get("scar"):
        col = mix(lk["skin"], "#a04848", 0.42)
        x = 146 + pk.pm(3)
        out.append(ink(((x, 102), (x + 4, 118), (x + 8, 136)), 2.4, col, "mid"))
        out.append(ink(((x + 1, 114), (x + 4.5, 113), (x + 8, 112)), 1.4, col, "mid"))
        out.append(ink(((x + 3, 124), (x + 6.5, 123), (x + 10, 122)), 1.4, col, "mid"))
    g = lk.get("glasses")
    if g:
        fr = g.get("frame") or "#2a2a30"
        tint = g.get("tint")
        lenses = (P("M", 86, 111, "L", 112, 112, "Q", 113, 126, 108, 131, "L", 91, 131, "Q", 86, 127, 86, 111, "Z"),
                  P("M", 124, 112, "L", 159, 110, "Q", 160, 126, 154, 131, "L", 129, 131, "Q", 124, 127, 124, 112, "Z"))
        for k, lens in enumerate(lenses):
            if tint:
                out.append(path(lens, tint, extra=op(0.88)))
                x = 92 if k == 0 else 132
                out.append(ink(((x, 117), (x + 5, 116), (x + 10, 116)), 2.2, "#ffffff", "mid", 0.5))
            else:
                out.append(path(lens, "#dfeaf5", extra=op(0.14)))
                x = 94 if k == 0 else 134
                out.append(ink(((x, 128), (x + 3, 122), (x + 7, 115)), 1.8, "#ffffff", "mid", 0.55))
            out.append(path(lens, "none", fr, 2.4))
        out.append(ink(((112, 116), (118, 112.5), (124, 116)), 2.2, fr, "even"))
        out.append(ink(((159, 113), (165, 113), (171, 114)), 2.2, fr, "even"))
    return out


# ---------- 몸 · 옷 ----------
BODY = {
    "m": P("M", -6, 256, "L", 0, 240, "C", 8, 224, 34, 214, 62, 208, "C", 80, 204, 92, 200, 98, 194, "L", 166, 192,
           "C", 178, 198, 200, 202, 222, 208, "C", 246, 216, 258, 232, 264, 256, "Z"),
    "f": P("M", 6, 256, "L", 12, 242, "C", 20, 228, 44, 218, 70, 212, "C", 88, 208, 100, 202, 104, 196, "L", 160, 194,
           "C", 172, 200, 192, 206, 212, 212, "C", 234, 220, 246, 236, 252, 256, "Z"),
}


def body(lk):
    """목 아래 — 반환 (defs, 조각들). 몸도 3/4: 가슴 가운데 선은 x ~124."""
    sex = lk["sex"]
    jacket = lk.get("jacket") or "#1d1b22"
    inner = lk.get("inner") or "#ecebe6"
    if lum(jacket) < 46:   # 아주 짙은 옷은 남색 화면판에 묻히지 않게 조금 띄운다
        jacket = mix(jacket, "#5a6488", 0.14)
    skin = lk["skin"]
    o = lk["outfit"]
    if o in ("suit", "coat") and abs(lum(inner) - lum(jacket)) < 18:   # 안감이 겉옷과 같으면 셔츠를 밝게
        inner = "#e9e7e1" if lum(jacket) < 128 else "#2a2830"
    bd = BODY[sex]
    defs = [clip("cb", bd), '<linearGradient id="fade" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#120e1a" stop-opacity="0"/>'
            '<stop offset="1" stop-color="#120e1a" stop-opacity="0.42"/></linearGradient>']
    out = []
    near_sh = P("M", 172, 200, "C", 204, 206, 236, 218, 252, 238, "L", 262, 256, "L", 204, 256, "C", 202, 236, 194, 214, 172, 200, "Z")
    collar_sh = P("M", 96, 196, "C", 114, 214, 150, 212, 170, 194, "L", 172, 214, "C", 150, 226, 112, 226, 94, 214, "Z")

    def cloth(col, sh=True):
        r = [path(bd, col, line_of(col), 2.6)]
        r.append('<g clip-path="url(#cb)">%s%s</g>' % (path(near_sh, shade(col, 0.38)), path(collar_sh, shade(col, 0.5), extra=op(0.5)) if sh else ""))
        r.append(ink(((6, 238), (26, 218), (70, 208)), 2.6, light(col, 0.32), "mid"))
        r.append(ink(((206, 220), (216, 236), (220, 256)), 1.8, shade(col, 0.55), "in"))
        r.append(ink(((46, 226), (40, 240), (38, 256)), 1.5, shade(col, 0.4), "in", 0.8))
        r.append('<g clip-path="url(#cb)"><rect x="0" y="214" width="256" height="42" fill="url(#fade)"/></g>')
        return r

    if o == "tank":
        out += cloth(skin, False)
        out.append(path(P("M", 90, 256, "L", 100, 210, "C", 112, 220, 146, 218, 158, 208, "L", 172, 256, "Z"), jacket, line_of(jacket), 2.2))
        for x0, x1 in ((96, 100), (162, 158)):
            out.append(ink(((x0, 212), (x0 - (2 if x0 < 128 else -2), 202), (x1, 196)), 4.0, jacket, "even"))
        return defs, out
    if o == "dress":
        out += cloth(skin, False)
        out.append(path(P("M", 16, 256, "C", 26, 232, 56, 220, 92, 214, "L", 124, 248, "L", 160, 212,
                          "C", 196, 218, 228, 232, 240, 256, "Z"), jacket, line_of(jacket), 2.2))
        if lk.get("choker"):
            out.append(path(P("M", 106, 176, "Q", 130, 186, 156, 172, "L", 157, 180, "Q", 130, 194, 106, 184, "Z"), "#c9ccd4", LINE, 1.6))
        return defs, out
    if o in ("suit", "coat", "cardigan"):
        if o == "coat":   # 세운 깃(목 뒤)
            out.append(path(P("M", 90, 204, "C", 90, 184, 98, 170, 110, 166, "L", 116, 198, "Z"), shade(jacket, 0.15), line_of(jacket), 2.2))
            out.append(path(P("M", 174, 200, "C", 176, 180, 170, 166, 158, 160, "L", 152, 194, "Z"), shade(jacket, 0.4), line_of(jacket), 2.2))
        out += cloth(jacket)
        out.append(path(P("M", 98, 196, "L", 122, 256, "L", 142, 256, "L", 168, 194, "Z"), inner, line_of(inner), 2.0))
        out.append(path(P("M", 142, 256, "L", 168, 194, "L", 160, 206, "L", 136, 256, "Z"), shade(inner, 0.25), extra=op(0.8)))
        # 셔츠 깃
        out.append(path(P("M", 100, 190, "C", 104, 198, 108, 208, 112, 224, "L", 123, 208, "L", 113, 196, "Z"), light(inner, 0.25), line_of(inner), 1.8))
        out.append(path(P("M", 166, 188, "C", 160, 198, 152, 208, 146, 224, "L", 128, 208, "L", 142, 196, "Z"), shade(inner, 0.14), line_of(inner), 1.8))
        if lk.get("tie"):
            tie = lk.get("tie_col") or ("#3a2430" if lum(jacket) < 70 else shade(jacket, 0.35))
            out.append(path(P("M", 120, 214, "L", 130, 214, "L", 139, 256, "L", 113, 256, "Z"), tie, line_of(tie), 1.8))
            out.append(path(P("M", 116, 202, "L", 134, 202, "L", 130, 215, "L", 120, 215, "Z"), light(tie, 0.08), line_of(tie), 1.8))
            out.append(ink(((122, 218), (120, 236), (118, 254)), 1.6, light(tie, 0.3), "mid"))
            out.append(path(P("M", 130, 215, "L", 139, 256, "L", 132, 256, "L", 127, 218, "Z"), shade(tie, 0.4), extra=op(0.7)))
        if o != "cardigan":   # 라펠(먼 쪽 좁게 · 가까운 쪽 넓게)
            wide = 10 if o == "coat" else 0
            out.append(path(P("M", 96, 198, "L", 120, 256, "L", 100 - wide, 256, "L", 88 - wide, 230, "L", 79 - wide, 224, "L", 86, 206, "Z"),
                            light(jacket, 0.14), line_of(jacket), 2.0))
            out.append(path(P("M", 170, 196, "L", 144, 256, "L", 170 + wide, 256, "L", 184 + wide, 230, "L", 195 + wide, 224, "L", 182, 204, "Z"),
                            shade(jacket, 0.24), line_of(jacket), 2.0))
            out.append(ink(((172, 200), (162, 226), (150, 254)), 1.4, light(jacket, 0.25), "mid", 0.6))
            out.append(ink(((86, 208), (90, 230), (101, 254)), 1.8, light(jacket, 0.4), "mid", 0.8))      # 먼 쪽 라펠 가 빛
            out.append(ink(((182, 244), (194, 241), (206, 240)), 1.6, shade(jacket, 0.5), "even"))      # 가슴 주머니
        else:
            out.append(ink(((98, 198), (110, 228), (122, 256)), 3.0, shade(jacket, 0.3), "even"))
            out.append(ink(((168, 196), (154, 226), (142, 256)), 3.0, shade(jacket, 0.3), "even"))
            for x, y in ((114, 236), (119, 252)):
                out.append('<circle cx="%s" cy="%s" r="2.6" fill="%s" stroke="%s" stroke-width="1.1"/>' % (x, y, light(jacket, 0.45), line_of(jacket)))
        if lk.get("badge"):
            out.append('<circle cx="96" cy="236" r="3.4" fill="#d9b44a" stroke="%s" stroke-width="1.3"/>' % LINE)
    elif o == "shirt":
        out += cloth(inner)
        out.append(path(P("M", 100, 190, "C", 104, 198, 108, 206, 112, 220, "L", 124, 206, "L", 113, 196, "Z"), light(inner, 0.3), line_of(inner), 1.8))
        out.append(path(P("M", 166, 188, "C", 160, 198, 152, 206, 146, 220, "L", 127, 206, "L", 142, 196, "Z"), shade(inner, 0.12), line_of(inner), 1.8))
        if lk.get("tie"):
            tie = lk.get("tie_col") or "#2a2230"
            out.append(path(P("M", 120, 212, "L", 131, 212, "L", 139, 256, "L", 113, 256, "Z"), tie, line_of(tie), 1.8))
            out.append(path(P("M", 117, 202, "L", 134, 202, "L", 131, 213, "L", 120, 213, "Z"), light(tie, 0.08), line_of(tie), 1.8))
        else:
            out.append(ink(((126, 208), (127, 232), (128, 256)), 1.8, shade(inner, 0.35), "even"))
            for y in (226, 246):
                out.append('<circle cx="130.5" cy="%d" r="1.8" fill="%s"/>' % (y, shade(inner, 0.32)))
        if lk.get("holster"):
            out.append(ink(((60, 212), (88, 232), (112, 256)), 7.0, "#6b4428", "even"))
            out.append(ink(((196, 210), (170, 232), (148, 256)), 7.0, "#5a3820", "even"))
    elif o == "turtle":
        layered = bool(lk.get("jacket")) and abs(lum(inner) - lum(jacket)) > 18
        out += cloth(jacket if layered else inner)
        if layered:
            out.append(path(P("M", 102, 202, "L", 116, 256, "L", 152, 256, "L", 164, 200, "Z"), inner, line_of(inner), 2.0))
        tn = P("M", 100, 172, "C", 112, 182, 150, 180, 164, 166, "L", 168, 202, "C", 146, 214, 118, 214, 96, 206, "Z")
        out.append(path(tn, inner, line_of(inner), 2.0))
        out.append(path(P("M", 146, 178, "C", 156, 176, 162, 172, 164, 166, "L", 168, 202, "C", 160, 206, 152, 208, 146, 210, "Z"), shade(inner, 0.3), extra=op(0.8)))
        for x in (108, 117, 126, 135, 144, 153):
            out.append(ink(((x, 182), (x + 0.5, 194), (x + 1, 208)), 1.3, shade(inner, 0.32), "mid"))
    elif o == "hood":
        out.append(path(P("M", 72, 216, "C", 76, 186, 98, 174, 118, 184, "L", 150, 180, "C", 172, 172, 192, 184, 196, 212, "Z"),
                        shade(jacket, 0.3), line_of(jacket), 2.4))
        out += cloth(jacket)
        out.append(ink(((98, 198), (126, 222), (166, 196)), 2.6, line_of(jacket), "mid"))
        for x in (114, 142):
            out.append(ink(((x, 212), (x - 1, 230), (x - 2, 250)), 2.6, light(jacket, 0.55), "even"))
    elif o == "jacket":
        out += cloth(jacket)
        out.append(path(P("M", 96, 196, "C", 112, 208, 150, 206, 168, 192, "L", 172, 206, "C", 150, 220, 112, 222, 92, 210, "Z"),
                        light(jacket, 0.12), line_of(jacket), 2.0))
        out.append(ink(((124, 216), (126, 236), (128, 256)), 2.4, light(jacket, 0.5), "even"))
    elif o == "kimono":
        out += cloth(jacket)
        out.append(path(P("M", 100, 194, "L", 156, 256, "L", 136, 256, "L", 94, 204, "Z"), inner, line_of(inner), 1.8))
        out.append(path(P("M", 166, 192, "L", 112, 256, "L", 92, 256, "L", 150, 196, "Z"), light(jacket, 0.12), line_of(jacket), 1.8))
    else:   # tee
        out += cloth(jacket)
        out.append(path(P("M", 98, 194, "C", 112, 206, 150, 204, 166, 190, "L", 168, 197, "C", 150, 212, 112, 214, 96, 201, "Z"),
                        shade(jacket, 0.18), line_of(jacket), 1.8))
    return defs, out


# ---------- 한 장 ----------
def portrait_svg(cid, lk):
    pk = Pick(cid)
    sex = lk["sex"]
    skin = lk["skin"]
    hc = lk["hair"]
    st = lk["style"]
    sp = hair_spec(lk, pk)
    hline = line_of(hc, 0.55)
    sline = mix(shade(skin, 0.75), "#3c1c26", 0.5)
    dark_hair = lum(hc) < 90
    hi = mix(hc, COOL, 0.55) if dark_hair else light(hc, 0.45)
    hsh = shade(hc, 0.42 if not dark_hair else 0.3)
    defs, parts = [], []
    # 1. 몸 뒤 머리(묶은 머리 · 꽁지) · 머리 뒤 덩어리
    if sp["behind"]:
        parts.append(union(sp["behind"], 1.4, hline) + fills(sp["behind"], shade(hc, 0.12)))
        parts.append(ink(((172, 20), (180, 14), (190, 18)), 1.6, hi, "mid", 0.8))
    if sp["back"]:
        parts.append(union(sp["back"], 1.5, hline) + fills(sp["back"], shade(hc, 0.3)))
    # 2. 목 · 몸
    neck = NECK[sex]
    defs.append(clip("nk_" + cid, neck))
    parts.append(path(neck, skin, sline, 2.0))
    parts.append('<g clip-path="url(#nk_%s)">%s</g>' % (cid, path(NECK_SHADOW, shade(skin, 0.36))))
    if sex == "m":
        parts.append(ink(((150, 176), (144, 192), (140, 208)), 1.3, shade(skin, 0.5), "mid", 0.8))
    d1, b = body(lk)
    defs += d1
    parts += b
    # 3. 얼굴(+두피) — 바깥선만 · 가까운 쪽 그늘
    face = FACE[sex]
    head_shapes = [face] + ([SKULL] if sp["skull"] else [])
    defs.append(clip("fc_" + cid, face))
    parts.append(union(head_shapes, 1.6, sline) + fills(head_shapes, skin))
    sh = [path(face, light(skin, 0.42)), '<g transform="translate(2.2 1.4)">%s</g>' % path(face, skin),   # 먼 쪽(빛 쪽) 가는 빛 테두리
          path(FACE_SHADOW[sex], shade(skin, 0.3))]
    hair_sh = '<g transform="translate(2.5 5)">%s</g>' % fills(sp["front"], shade(skin, 0.34)) if sp["front"] else ""
    if sp["skull"]:
        sk = []
        sk.append(path(P("M", 166, 46, "C", 184, 60, 192, 80, 190, 100, "C", 188, 120, 186, 136, 182, 148, "L", 168, 150,
                         "C", 174, 120, 176, 80, 166, 46, "Z"), shade(skin, 0.3)))
        if sp["shaved"]:
            sk.append(path(sp["shaved"], mix(hc, skin, 0.5), extra=op(0.85)))
        if not sp["tint"] and not sp["shaved"]:
            sk.append('<ellipse cx="114" cy="56" rx="17" ry="7" fill="%s" transform="rotate(-24 114 56)"%s/>' % (light(skin, 0.7), op(0.6)))
        defs.append(clip("sk_" + cid, SKULL))
        parts.append('<g clip-path="url(#sk_%s)">%s%s</g>' % (cid, "".join(sk), hair_sh))
    parts.append('<g clip-path="url(#fc_%s)">%s%s</g>' % (cid, "".join(sh), hair_sh))
    if sp["tint"]:   # 빡빡머리 — 두피 위 옅은 머리색(자르지 않음 · 모양이 두피 안)
        parts.append(path(sp["tint"], mix(hc, skin, 0.32), extra=op(0.86)))
        parts.append(path(P("M", 150, 44, "C", 176, 54, 190, 76, 190, 96, "L", 186, 104, "C", 182, 80, 172, 60, 150, 44, "Z"), shade(hc, 0.3), extra=op(0.6)))
    if sp["tint"]:
        parts.append(path(sp["tint"], "none", line_of(hc, 0.5), 1.0, op(0.6)))
    # 4. 귀 — 머리가 덮는 모양이면 머리 앞에 안 나온다
    ear = [path(EAR, skin), path(P("M", 171, 112, "C", 178, 106, 186, 110, 185, 120, "L", 180, 140, "Z"), shade(skin, 0.28), extra=op(0.7)),
           ink((EAR_RIM[0], EAR_RIM[1], EAR_RIM[2], EAR_RIM[3]), 2.2, sline, "in", n=8),
           ink((EAR_RIM[3], EAR_RIM[4], EAR_RIM[5], EAR_RIM[6]), 2.2, sline, "out", n=8),
           ink(((174, 114), (182, 112), (180, 126)), 1.4, shade(skin, 0.5), "mid")]
    if lk.get("earring"):
        ear.append('<circle cx="178" cy="145" r="2.8" fill="#1a1a1f" stroke="#c9ccd4" stroke-width="1.2"/>')
    # 5. 얼굴 부품
    d2, feats, brows = face_feats(cid, lk, pk)
    defs += d2
    parts += feats
    parts += beard(lk)
    parts += extras(lk, pk)
    if st not in FRINGE:
        parts += brows
    if st not in EAR_HIDDEN:
        parts += ear
    # 6. 앞머리 — 바깥선 · 그늘(빛 쪽으로 민 바탕색) · 윤기 · 다발 나눔 선 · 결
    if sp["front"]:
        edges = dict(sp["edges"])
        g = [union(sp["front"], 1.3, hline)]
        for i, d in enumerate(sp["front"]):   # 모양마다 따로 자른다(clip() 설명) — 다발마다 오른쪽 아래 가에 그늘이 진다
            ci = "h%d_%s" % (i, cid)
            defs.append(clip(ci, d))
            inner = [path(d, hsh), '<g transform="translate(-3 -5)">%s</g>' % path(d, hc)]
            if i == 0:
                for (cx, cy, ln, ang, wd) in sp["shine"]:
                    inner.append(path(sliver(cx + pk.pm(1.5), cy + pk.pm(1.5), ln, ang, wd), hi, extra=op(0.9)))
                for s_ in sp["strands"]:
                    inner.append(ink(s_, 1.5, hsh, "mid", n=10))
            if i in edges:
                inner.append(ink(sub_c(edges[i], 0.55), 1.4, mix(hline, hsh, 0.35), "in", n=8))
            g.append('<g clip-path="url(#%s)">%s</g>' % (ci, "".join(inner)))
        parts += g
    if st in FRINGE:
        parts += [b.replace("/>", op(0.92) + "/>", 1) for b in brows]
    head_ = ('<?xml version="1.0" encoding="UTF-8"?>\n'
             '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 256 256">\n'
             '<!-- %s · scripts/draw_portraits.py 가 assets/chars/looks.json 에서 그림(손대지 않음) -->\n' % (PX, PX, cid))
    return head_ + "<defs>" + "".join(defs) + "</defs>\n" + "\n".join(parts) + "\n</svg>\n"


# ---------- 입구 ----------
def wanted_ids():
    with open(SCEN, encoding="utf-8") as fh:
        sc = json.load(fh)["scenarios"]
    ids = set()
    for s in sc:
        for r in list(s.get("roster") or []) + list(s.get("assign") or []):
            ids.add(r["id"])
    return sorted(ids)


def load_looks():
    with open(LOOKS, encoding="utf-8") as fh:
        return json.load(fh)["looks"]


def validate(looks):
    errs = []
    for cid in sorted(looks):
        lk = looks[cid]
        if lk.get("sex") not in ("m", "f"):
            errs.append("%s sex" % cid)
        if lk.get("style") not in STYLES:
            errs.append("%s style=%s" % (cid, lk.get("style")))
        if lk.get("outfit") not in OUTFITS:
            errs.append("%s outfit=%s" % (cid, lk.get("outfit")))
        for k in ("skin", "hair"):
            v = lk.get(k, "")
            if not (isinstance(v, str) and len(v) == 7 and v.startswith("#")):
                errs.append("%s %s=%s" % (cid, k, v))
    return errs


def main(argv):
    check = "--check" in argv
    looks = load_looks()
    errs = validate(looks)
    with open(CANON, encoding="utf-8") as fh:
        canon = {c["id"] for c in json.load(fh)["characters"]}
    errs += ["looks id %s 가 canon 에 없다" % i for i in sorted(looks) if i not in canon]
    errs += ["명단 인물 %s 의 looks 가 없다" % i for i in wanted_ids() if i not in looks]
    drawn = {cid: portrait_svg(cid, looks[cid]) for cid in sorted(looks)}
    for cid, svg in drawn.items():
        try:
            ET.fromstring(svg.split("?>", 1)[1])
        except ET.ParseError as e:
            errs.append("%s XML: %s" % (cid, e))
    if check:
        have = sorted(n[:-4] for n in os.listdir(OUT) if n.endswith(".svg")) if os.path.isdir(OUT) else []
        errs += ["svg %s 는 looks 에 없다" % i for i in have if i not in drawn]
        for cid, svg in drawn.items():
            p = os.path.join(OUT, cid + ".svg")
            if not os.path.isfile(p):
                errs.append("svg %s 가 없다 — python3 -B scripts/draw_portraits.py" % cid)
                continue
            with open(p, encoding="utf-8") as fh:
                if fh.read() != svg:
                    errs.append("svg %s 가 looks 와 다르다 — 다시 그려라" % cid)
    else:
        os.makedirs(OUT, exist_ok=True)
        for n in os.listdir(OUT):
            if n.endswith(".svg") and n[:-4] not in drawn:
                os.remove(os.path.join(OUT, n))
        for cid, svg in drawn.items():
            with open(os.path.join(OUT, cid + ".svg"), "w", encoding="utf-8", newline="\n") as fh:
                fh.write(svg)
    for e in errs:
        print("[FAIL] " + e)
    print("chars: 초상 %d명 · 명단 %d명 · 오류 %d" % (len(drawn), len(wanted_ids()), len(errs)))
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
