"""인물 초상 그리기 — 벡터 일러스트(셀 음영 · 굵은 외곽선) SVG. 도트를 그만 쓴다(2026-11-11 사용자 지시 · docs/기획_차이.md (라)12).

    python3 -B scripts/draw_portraits.py           # assets/chars/looks.json → assets/chars/svg/<id>.svg (같은 looks 면 같은 파일 · 멱등)
    python3 -B scripts/draw_portraits.py --check   # 다시 그려 대조 · 명단 인물이 모두 있는지 · XML 이 맞는지(scripts/verify.py '인물 그림' 단계)

- 무엇: 장르 팩 시나리오 명단(roster · assign)의 인물마다 앞모습 흉상 한 장(256×256 viewBox · 배경 투명 · 384px 로 가져옴).
  배경 · 세력색 판은 화면(ui/)이 깐다 — 그림은 사람만 그린다.
- 원본: assets/chars/looks.json(사람 손으로 고쳐도 되는 외형 표 — 머리 모양 · 색 · 안경 · 수염 · 옷). 처음 값은 취호전 도트 초상의 색과
  canon look 글의 낱말에서 한 번 뽑았다(assets/ASSETS.md). 원작 컷은 읽지도 넣지도 않는다(CLAUDE.md 13절).
- 화풍: 기획_차이 (라)12 — 수상작(TGA 2019 전략 부문)에서 고른 '그림 초상 + 셀 음영' 방향만 따르고, 다른 게임의 그림 · 문양을 베끼지 않는다.
- 결정성: 난수 대신 sha256(id) 로 작은 차이(눈썹 각 · 입 · 흘러내린 머리 가닥)를 고른다. 순회는 정렬한 id.
- 요구: FR-212(정정 · C3) · 쓰는 곳: ui/sprites.gd
"""
import hashlib
import json
import os
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOOKS = os.path.join(ROOT, "assets", "chars", "looks.json")
OUT = os.path.join(ROOT, "assets", "chars", "svg")
SCEN = os.path.join(ROOT, "data", "common", "packs", "strategy", "scenarios.json")
CANON = os.path.join(ROOT, "data", "common", "canon", "characters.json")

LINE = "#18131d"
SHADE = (46, 30, 66)          # 그림자 쪽 섞는 색(차가운 보라) — 곱하기 느낌
LIGHT = (255, 246, 232)
PX = 384                      # 가져올 때 크기(화면 최대 ~300px · 밉맵)
STYLES = ("slick", "short", "bangs", "undercut", "buzz", "bald", "long", "bob", "tied", "wavy")
OUTFITS = ("suit", "coat", "shirt", "turtle", "hood", "jacket", "tee", "tank", "cardigan", "kimono", "dress")


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


def P(*pts):
    """("M", x, y, "C", ...) → 'M x y C …'"""
    return " ".join(p if isinstance(p, str) else f(p) for p in pts)


def path(d, fill, stroke=LINE, w=3.0, extra=""):
    st = ' stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"' % (stroke, f(w)) if stroke else ""
    return '<path d="%s" fill="%s"%s%s/>' % (d, fill, st, extra)


# ---------- 부품 ----------
# 좌표: 256×256. 머리 부품은 '머리 공간'(얼굴 x 84~172 · y 50~176)에 그리고 HEAD 변환으로 줄여 올린다 — 몸은 바로 그린다.
HEAD = "matrix(0.9 0 0 0.9 12.8 4)"          # x' = 0.9x + 12.8(가운데 128 유지) · y' = 0.9y + 4 → 턱 162
FACE = {
    "m": P("M", 84, 98, "C", 84, 64, 104, 48, 128, 48, "C", 152, 48, 172, 64, 172, 98, "L", 171, 122,
           "C", 169, 141, 159, 155, 146, 165, "Q", 128, 178, 110, 165, "C", 97, 155, 87, 141, 85, 122, "Z"),
    "f": P("M", 86, 98, "C", 86, 64, 105, 50, 128, 50, "C", 151, 50, 170, 64, 170, 98, "L", 169, 118,
           "C", 167, 138, 156, 154, 142, 164, "Q", 128, 174, 114, 164, "C", 100, 154, 89, 138, 87, 118, "Z"),
}
FACE_SHADOW = {   # 오른쪽 볼 · 턱 그늘(빛은 왼쪽 위)
    "m": P("M", 172, 96, "L", 171, 122, "C", 169, 141, 159, 155, 146, 165, "Q", 128, 178, 110, 165,
           "C", 128, 168, 142, 160, 151, 146, "C", 160, 132, 163, 114, 161, 96, "Z"),
    "f": P("M", 170, 96, "L", 169, 118, "C", 167, 138, 156, 154, 142, 164, "Q", 128, 174, 114, 164,
           "C", 128, 166, 140, 158, 148, 146, "C", 157, 132, 160, 114, 158, 96, "Z"),
}


def union(shapes, w, line=LINE):
    """겹친 모양들의 바깥 외곽선만 — 굵은 선을 먼저 깔고 그 위에 채움(안쪽 경계선이 안 보이게)."""
    s = "".join('<path d="%s"/>' % d for d, _ in shapes)
    fills = "".join('<path d="%s" fill="%s"/>' % (d, c) for d, c in shapes)
    return ('<g fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round">%s</g>' % (line, line, f(w * 2), s)) + "<g>" + fills + "</g>"


def lit(cid, shapes, base, rim, dx=3.5, dy=3.0):
    """역광 — 모양 안에서 밝은 색을 깔고 바탕색을 오른쪽 아래로 밀어 덮어 왼쪽 위 가장자리에 가는 빛을 남긴다."""
    clip = '<clipPath id="%s">%s</clipPath>' % (cid, "".join('<path d="%s"/>' % d for d in shapes))
    body_ = "".join('<path d="%s" fill="%s"/>' % (d, rim) for d in shapes)
    body_ += '<g transform="translate(%s %s)">%s</g>' % (f(dx), f(dy), "".join('<path d="%s" fill="%s"/>' % (d, base) for d in shapes))
    return clip, '<g clip-path="url(#%s)">%s' % (cid, body_)


def clump(a, b, yr, tx, ty, bend=0.0):
    """앞머리 한 다발 — 뿌리 [a, b](y = yr)에서 끝 (tx, ty)로 가늘어진다."""
    w = b - a
    return P("M", a, yr, "C", a - 2, yr + (ty - yr) * 0.55, tx - w * 0.2 + bend, ty - 8, tx, ty,
             "C", tx + w * 0.22 + bend, ty - 12, b + 1, yr + (ty - yr) * 0.4, b, yr, "Z")


def body(lk):
    """몸 · 옷 — 목 아래(머리 변환 없음). 반환: (defs, 조각들)"""
    sex = lk["sex"]
    jacket = lk.get("jacket") or "#1d1b22"
    inner = lk.get("inner") or "#ecebe6"
    skin = lk["skin"]
    o = lk["outfit"]
    if o in ("suit", "coat") and abs(lum(inner) - lum(jacket)) < 18:   # 안감이 겉옷과 같으면 셔츠를 밝게(안 보이는 차림 방지)
        inner = "#e9e7e1" if lum(jacket) < 128 else "#2a2830"
    sw = 0 if sex == "m" else 12
    defs, out = [], []
    shoulders = P("M", -8 + sw, 256, "C", -4 + sw, 224, 30 + sw, 204, 74 + sw * 0.5, 194, "C", 92, 190, 104, 184, 112, 176,
                  "L", 144, 176, "C", 152, 184, 164, 190, 182 - sw * 0.5, 194, "C", 226 - sw, 204, 260 - sw, 224, 264 - sw, 256, "Z")
    neck = P("M", 112, 130, "L", 112, 184, "Q", 128, 196, 144, 184, "L", 144, 130, "Z")
    neck_sh = P("M", 112, 140, "Q", 128, 172, 144, 140, "L", 144, 166, "Q", 128, 186, 112, 166, "Z")
    defs.append('<clipPath id="cb"><path d="%s"/></clipPath>' % shoulders)
    defs.append('<linearGradient id="bg_fade" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1a1424" stop-opacity="0"/>'
                '<stop offset="1" stop-color="#1a1424" stop-opacity="0.38"/></linearGradient>')
    body_shadow = P("M", 166, 190, "C", 206, 198, 244, 214, 262, 240, "L", 266, 256, "L", 206, 256,
                    "C", 204, 232, 192, 210, 166, 190, "Z")

    def cloth(col):
        r = [path(shoulders, col, LINE, 3.2)]
        r.append('<g clip-path="url(#cb)"><path d="%s" fill="%s"/>'
                 '<ellipse cx="128" cy="184" rx="40" ry="12" fill="%s" opacity="0.45"/>'
                 '<rect x="0" y="176" width="256" height="80" fill="url(#bg_fade)"/></g>' % (body_shadow, shade(col, 0.42), shade(col, 0.6)))
        r.append(path(P("M", 14 + sw, 230, "C", 26 + sw, 212, 50 + sw, 202, 80, 196), "none", light(col, 0.3), 3.0))
        return r

    out.append(path(neck, skin, mix(shade(skin, 0.6), LINE, 0.5), 2.6))
    out.append('<path d="%s" fill="%s" opacity="0.8"/>' % (neck_sh, shade(skin, 0.34)))
    if o == "tank":
        out.append(path(shoulders, skin, LINE, 3.2))
        out.append('<g clip-path="url(#cb)"><path d="%s" fill="%s" opacity="0.6"/></g>' % (body_shadow, shade(skin, 0.3)))
        out.append(path(P("M", 84, 256, "L", 90, 200, "Q", 128, 222, 166, 200, "L", 172, 256, "Z"), jacket, LINE, 3.0))
        return defs, out
    if o == "dress":
        out.append(path(shoulders, skin, LINE, 3.2))
        out.append(path(P("M", 18 + sw, 256, "C", 26 + sw, 226, 54 + sw, 208, 90, 202, "L", 128, 244, "L", 166, 202,
                          "C", 202 - sw, 208, 230 - sw, 226, 238 - sw, 256, "Z"), jacket, LINE, 3.0))
        if lk.get("choker"):
            out.append(path(P("M", 112, 168, "Q", 128, 178, 144, 168, "L", 144, 176, "Q", 128, 186, 112, 176, "Z"), "#c9ccd4", LINE, 2))
        return defs, out
    if o in ("suit", "coat", "cardigan"):
        out += cloth(jacket)
        v = P("M", 104, 184, "L", 128, 244, "L", 152, 184, "Q", 128, 198, 104, 184, "Z")
        out.append(path(v, inner, LINE, 2.6))
        out.append(path(P("M", 106, 182, "L", 115, 210, "L", 128, 194, "Z"), light(inner, 0.25), LINE, 2.2))   # 깃
        out.append(path(P("M", 150, 182, "L", 141, 210, "L", 128, 194, "Z"), shade(inner, 0.14), LINE, 2.2))
        if lk.get("tie"):
            tie = lk.get("tie_col") or ("#3a2430" if lum(jacket) < 70 else shade(jacket, 0.35))
            out.append(path(P("M", 122, 196, "L", 134, 196, "L", 131, 205, "L", 125, 205, "Z"), tie, LINE, 2.2))
            out.append(path(P("M", 125, 205, "L", 131, 205, "L", 137, 232, "L", 128, 244, "L", 119, 232, "Z"), tie, LINE, 2.2))
            out.append(path(P("M", 127, 208, "L", 125, 228), "none", light(tie, 0.3), 1.6))
        if o != "cardigan":   # 라펠
            lw = 14 if o == "coat" else 8
            out.append(path(P("M", 100, 186, "L", 128, 246, "L", 104 - lw, 214, "L", 98, 204, "Z"), light(jacket, 0.16), LINE, 2.6))
            out.append(path(P("M", 156, 186, "L", 128, 246, "L", 152 + lw, 214, "L", 158, 204, "Z"), shade(jacket, 0.22), LINE, 2.6))
            if o == "coat":
                out.append(path(P("M", 90, 186, "Q", 98, 164, 112, 160, "L", 112, 186, "Z"), light(jacket, 0.1), LINE, 2.6))
                out.append(path(P("M", 166, 186, "Q", 158, 164, 144, 160, "L", 144, 186, "Z"), shade(jacket, 0.25), LINE, 2.6))
        else:
            for y in (220, 236):
                out.append('<circle cx="128" cy="%d" r="2.6" fill="%s" stroke="%s" stroke-width="1.2"/>' % (y, light(jacket, 0.45), LINE))
        if lk.get("badge"):
            out.append('<circle cx="102" cy="222" r="3.4" fill="#d9b44a" stroke="%s" stroke-width="1.4"/>' % LINE)
    elif o == "shirt":
        out += cloth(inner)
        out.append(path(P("M", 106, 180, "L", 115, 208, "L", 128, 192, "Z"), light(inner, 0.3), LINE, 2.2))
        out.append(path(P("M", 150, 180, "L", 141, 208, "L", 128, 192, "Z"), shade(inner, 0.12), LINE, 2.2))
        if lk.get("tie"):
            tie = lk.get("tie_col") or "#2a2230"
            out.append(path(P("M", 123, 194, "L", 133, 194, "L", 137, 232, "L", 128, 244, "L", 119, 232, "Z"), tie, LINE, 2.2))
        else:
            out.append(path(P("M", 128, 194, "L", 128, 256), "none", shade(inner, 0.35), 2.0))
            for y in (214, 236):
                out.append('<circle cx="131" cy="%d" r="1.8" fill="%s"/>' % (y, shade(inner, 0.3)))
        if lk.get("holster"):
            out.append(path(P("M", 64, 204, "L", 114, 256), "none", "#6b4428", 7.0))
            out.append(path(P("M", 192, 204, "L", 142, 256), "none", "#5a3820", 7.0))
    elif o == "turtle":
        out += cloth(jacket)
        out.append(path(P("M", 108, 158, "L", 107, 190, "Q", 128, 202, 149, 190, "L", 148, 158, "Q", 128, 168, 108, 158, "Z"), inner, LINE, 2.6))
        out.append('<path d="%s" fill="%s" opacity="0.6"/>' % (P("M", 138, 164, "Q", 146, 162, 148, 158, "L", 149, 190, "Q", 144, 194, 138, 196, "Z"), shade(inner, 0.3)))
        for x in (116, 124, 132, 140):
            out.append(path(P("M", x, 168, "L", x, 194), "none", shade(inner, 0.28), 1.5))
        if lk.get("jacket") and abs(lum(inner) - lum(jacket)) > 18:
            out.append(path(P("M", 104, 190, "L", 114, 256), "none", shade(jacket, 0.35), 2.6))
            out.append(path(P("M", 152, 190, "L", 142, 256), "none", shade(jacket, 0.35), 2.6))
    elif o == "hood":
        out.append(path(P("M", 56, 206, "C", 66, 166, 100, 160, 128, 178, "C", 156, 160, 190, 166, 200, 206, "Z"), shade(jacket, 0.28), LINE, 3.0))
        out += cloth(jacket)
        out.append(path(P("M", 98, 186, "Q", 128, 214, 158, 186), "none", LINE, 3.0))
        for x in (114, 142):
            out.append(path(P("M", x, 202, "L", x - 2, 236), "none", light(jacket, 0.55), 2.4))
    elif o == "jacket":
        out += cloth(jacket)
        out.append(path(P("M", 100, 172, "L", 104, 192, "L", 128, 204, "L", 152, 192, "L", 156, 172, "Q", 128, 186, 100, 172, "Z"), light(jacket, 0.14), LINE, 2.6))
        out.append(path(P("M", 128, 204, "L", 128, 256), "none", light(jacket, 0.5), 2.4))
    elif o == "kimono":
        out += cloth(jacket)
        out.append(path(P("M", 104, 182, "L", 152, 256, "L", 128, 256, "L", 96, 194, "Z"), inner, LINE, 2.4))
        out.append(path(P("M", 152, 182, "L", 110, 256, "L", 92, 256, "L", 138, 192, "Z"), light(jacket, 0.12), LINE, 2.4))
    else:   # tee
        out += cloth(jacket)
        out.append(path(P("M", 104, 184, "Q", 128, 206, 152, 184), "none", LINE, 3.0))
        out.append(path(P("M", 108, 188, "Q", 128, 202, 148, 188), "none", shade(jacket, 0.35), 3.0))
    return defs, out


def back_hair(lk, pk):
    st, hc = lk["style"], lk["hair"]
    sh = shade(hc, 0.3)
    if st == "long":
        return union([(P("M", 82, 90, "C", 68, 140, 66, 196, 52, 246, "Q", 90, 256, 114, 232, "L", 116, 150, "L", 140, 150,
                         "L", 142, 232, "Q", 166, 256, 204, 246, "C", 190, 196, 188, 140, 174, 90, "Z"), sh)], 1.6)
    if st == "bob":
        return union([(P("M", 82, 90, "C", 72, 126, 72, 160, 78, 182, "Q", 100, 192, 114, 176, "L", 116, 150, "L", 140, 150,
                         "L", 142, 176, "Q", 156, 192, 178, 182, "C", 184, 160, 184, 126, 174, 90, "Z"), sh)], 1.6)
    if st == "wavy":
        return union([(P("M", 80, 92, "C", 70, 118, 72, 150, 84, 162, "Q", 96, 168, 104, 152, "L", 152, 152,
                         "Q", 160, 168, 172, 162, "C", 184, 150, 186, 118, 176, 92, "Z"), sh)], 1.6)
    if st == "tied":
        bx = 128 + pk.pm(3)
        return union([(P("M", bx - 16, 40, "C", bx - 22, 16, bx + 22, 16, bx + 16, 40, "Z"), hc)], 1.6) + \
            path(P("M", bx - 8, 26, "Q", bx, 20, bx + 8, 26), "none", light(hc, 0.45), 2.4)
    return ""


def hair_shapes(lk, pk):
    """앞(이마 위) 머리 모양 목록 [(d, 색)] · 결 · 그늘 조각 — 모양별."""
    st, hc = lk["style"], lk["hair"]
    shapes, strands, shadow, plain = [], [], [], []
    if st in ("bald",):
        return shapes, strands, shadow, plain
    if st == "buzz":
        shapes.append(P("M", 84, 100, "C", 82, 60, 102, 44, 128, 44, "C", 154, 44, 174, 60, 172, 100,
                        "C", 168, 84, 160, 74, 150, 72, "Q", 128, 66, 106, 72, "C", 96, 74, 88, 84, 84, 100, "Z"))
        return shapes, strands, shadow, plain
    if st == "undercut":
        shapes.append(P("M", 90, 86, "C", 82, 42, 112, 20, 140, 22, "C", 168, 24, 182, 46, 168, 88,
                        "C", 160, 70, 146, 64, 128, 66, "C", 112, 66, 98, 74, 90, 86, "Z"))
        shadow.append(P("M", 150, 30, "C", 170, 40, 178, 60, 168, 88, "C", 162, 74, 154, 68, 146, 66, "C", 156, 56, 156, 42, 150, 30, "Z"))
        for i in range(4):
            x = 104 + i * 13
            strands.append(P("M", x, 68, "C", x + 2, 50, x + 12, 36, x + 26, 30))
        return shapes, strands, shadow, plain
    if st in ("slick", "tied"):
        top = 30 if st == "slick" else 38
        shapes.append(P("M", 82, 104, "C", 76, 56, 100, top, 130, top, "C", 160, top, 182, 54, 174, 104,
                        "C", 170, 88, 162, 76, 150, 70, "Q", 128, 62, 104, 70, "C", 94, 76, 86, 88, 82, 104, "Z"))
        shadow.append(P("M", 150, 70, "C", 168, 76, 176, 90, 174, 104, "C", 174, 70, 158, 44, 134, top + 6, "C", 152, top + 14, 158, 58, 150, 70, "Z"))
        for i in range(4):
            x0 = 96 + i * 16
            strands.append(P("M", x0, 70, "C", x0 + 4, 52, x0 + 14, top + 12, x0 + 28, top + 8))
        if st == "slick" and pk.u() > 0.3:   # 흘러내린 가닥
            x = 116 + pk.pm(10)
            shapes.append(P("M", x, 64, "C", x - 8, 78, x - 4, 92, x - 12, 102, "C", x, 94, x + 4, 80, x + 8, 66, "Z"))
        if st == "tied" and lk["sex"] == "f":
            shapes.append(P("M", 102, 68, "C", 92, 92, 90, 116, 96, 140, "C", 100, 116, 104, 92, 112, 70, "Z"))
        return shapes, strands, shadow, plain
    # 앞머리가 있는 모양: short · bangs · long · bob · wavy
    low = {"short": 84, "bangs": 108, "long": 98, "bob": 100, "wavy": 90}[st]
    side = st in ("long", "bob", "wavy")
    shapes.append(P("M", 80, 116 if side else 102, "C", 74, 60, 100, 32, 128, 32, "C", 156, 32, 182, 60, 176, 116 if side else 102,
                    "C", 172, 88, 160, 72, 144, 68, "L", 112, 68, "C", 96, 72, 84, 88, 80, 116 if side else 102, "Z"))
    n = 6 if st != "wavy" else 5
    x0, x1 = 88, 168
    sweep = -6.0 + pk.pm(3)       # 왼쪽으로 쓸림
    for i in range(n):
        a = x0 + (x1 - x0) * i / n - 3
        b = x0 + (x1 - x0) * (i + 1) / n + 3
        mid = (a + b) / 2
        yr = 62 + ((mid - 128) / 44.0) ** 2 * 26        # 뿌리는 머리 둥근 선을 따른다(옆으로 삐지지 않게)
        edge = 1.0 - abs((i + 0.5) / n - 0.5) * 2      # 가운데 1 · 끝 0
        ty = low - 10 + edge * 10 + pk.pm(4)
        if st == "wavy":
            ty += 4
        shapes.append(clump(a, b, yr, mid + sweep - (4 if i < n / 2 else -2), max(ty, yr + 14), bend=pk.pm(2)))
        plain.append(shapes[-1])
    if side:   # 얼굴 옆 머리 다발
        ly = {"long": 178, "bob": 168, "wavy": 150}[st]
        shapes.append(P("M", 80, 76, "C", 72, 118, 76, 154, 84, ly, "C", 92, ly - 20, 100, 132, 106, 88, "Z"))
        shapes.append(P("M", 176, 76, "C", 184, 118, 180, 154, 172, ly, "C", 164, ly - 20, 156, 132, 150, 88, "Z"))
    shadow.append(P("M", 150, 44, "C", 170, 56, 180, 78, 176, 104, "C", 168, 86, 158, 74, 146, 70, "C", 154, 62, 156, 52, 150, 44, "Z"))
    for i in range(3):
        x = 106 + i * 15 + pk.pm(3)
        strands.append(P("M", x, 40, "Q", x - 4, 54, x - 6, 66))
    return shapes, strands, shadow, plain


def front_hair(cid, lk, pk):
    st, hc = lk["style"], lk["hair"]
    defs, out = [], []
    if st == "bald":
        out.append('<ellipse cx="108" cy="68" rx="15" ry="7" fill="%s" opacity="0.55" transform="rotate(-24 108 68)"/>' % light(lk["skin"], 0.65))
        return defs, out
    shapes, strands, shadow, plain = hair_shapes(lk, pk)
    sh, hi = shade(hc, 0.38), light(hc, 0.5 if lum(hc) < 90 else 0.32)
    if st == "undercut":   # 민 옆머리 — 피부 위에 옅게
        side = mix(hc, lk["skin"], 0.5)
        out.append('<path d="%s" fill="%s" opacity="0.85"/>' % (P("M", 85, 106, "C", 83, 86, 87, 74, 97, 68, "L", 100, 98, "Z"), side))
        out.append('<path d="%s" fill="%s" opacity="0.85"/>' % (P("M", 171, 106, "C", 173, 86, 169, 74, 159, 68, "L", 156, 98, "Z"), side))
    if st == "buzz":
        out.append('<path d="%s" fill="%s" opacity="0.9" stroke="%s" stroke-width="2.4" stroke-linejoin="round"/>' % (shapes[0], hc, LINE))
        out.append(path(P("M", 100, 56, "Q", 120, 48, 142, 52), "none", hi, 2.4, ' opacity="0.7"'))
        return defs, out
    out.append(union([(d, hc) for d in shapes], 1.5))
    c, g = lit("h_" + cid, shapes, hc, hi)
    defs.append(c)
    inner = g
    inner += "".join('<path d="%s" fill="%s"/>' % (d, hc) for d in plain)   # 앞머리 다발은 역광 없이(안쪽 이음매가 안 보이게)
    inner += "".join('<path d="%s" fill="%s"/>' % (d, sh) for d in shadow)
    inner += '<path d="%s" fill="%s" opacity="0.45"/>' % (P("M", 96, 50, "C", 112, 38, 144, 38, 160, 50, "L", 157, 55, "C", 142, 45, 114, 45, 99, 56, "Z"), hi)   # 윤기 띠
    inner += "".join(path(d, "none", sh, 1.8) for d in strands)
    out.append(inner + "</g>")
    return defs, out


def eyes(cid, lk, pk):
    sex, kind = lk["sex"], lk.get("eyes", "normal")
    iris = lk.get("iris") or ("#4a3426" if lum(lk["hair"]) < 120 else "#6a4a32")
    h = {"sharp": 8.0, "droopy": 10.0, "normal": 11.0}.get(kind, 11.0) + (3.5 if sex == "f" else 0.0)
    tilt = {"sharp": -4.5, "droopy": 3.0}.get(kind, -1.5)
    defs, out = [], []
    defs.append('<linearGradient id="ig_%s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/>'
                '<stop offset="1" stop-color="%s"/></linearGradient>' % (cid, shade(iris, 0.55), light(iris, 0.35)))
    brow_col = shade(lk["hair"], 0.5) if lk["style"] != "bald" else shade(lk["skin"], 0.6)
    bt = pk.pm(2.0) + (-3.5 if kind == "sharp" else 1.0)
    for side in (-1, 1):
        cx, cy = 128 + side * 21, 120
        w = 14.0
        inner_x, outer_x = cx - side * w, cx + side * w
        oy = cy + tilt
        eye = P("M", inner_x, cy + 1, "Q", cx - side * 2, cy - h, outer_x, oy - 1, "Q", cx, cy + h * 0.6, inner_x, cy + 1, "Z")
        eid = "e%d_%s" % (side + 1, cid)
        defs.append('<clipPath id="%s"><path d="%s"/></clipPath>' % (eid, eye))
        out.append('<path d="%s" fill="#fbf7f0"/>' % eye)
        ir = 6.8 if sex == "m" else 7.6
        ix = cx + side * 0.5
        out.append('<g clip-path="url(#%s)"><path d="%s" fill="%s" opacity="0.35"/>'
                   '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="url(#ig_%s)" stroke="%s" stroke-width="1.2"/>'
                   '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="#120d12"/></g>' % (
                       eid, P("M", inner_x, cy - h, "L", outer_x, cy - h, "L", outer_x, cy - h * 0.2, "Q", cx, cy - h * 0.6, inner_x, cy - h * 0.2, "Z"), shade(lk["skin"], 0.4),
                       f(ix), f(cy), f(ir), f(ir + 2.0), cid, shade(iris, 0.6),
                       f(ix), f(cy + 0.5), f(ir * 0.42), f(ir * 0.62)))
        out.append('<circle cx="%s" cy="%s" r="%s" fill="#ffffff"/>' % (f(ix - 2.6), f(cy - 3.2), "2.2" if sex == "m" else "2.6"))
        out.append('<circle cx="%s" cy="%s" r="1.2" fill="#ffffff" opacity="0.8"/>' % (f(ix + 2.8), f(cy + 3.5)))
        lid = P("M", inner_x - side * 1.0, cy + 1.5, "Q", cx - side * 2, cy - h - 1.5, outer_x + side * (4.0 if sex == "f" else 1.5), oy - (3.5 if sex == "f" else 1.5))
        out.append(path(lid, "none", LINE, 4.6 if sex == "f" else 3.8))
        if sex == "f":
            out.append(path(P("M", outer_x, oy - 2, "L", outer_x + side * 5, oy - 6), "none", LINE, 2.4))
        out.append(path(P("M", outer_x - side * 8.0, cy + h * 0.5, "Q", outer_x - side * 2.0, oy + 3.0, outer_x, oy), "none", shade(lk["skin"], 0.6), 1.6))
        out.append(path(P("M", cx - side * 8, cy - h - 4.5, "Q", cx, cy - h - 6.5, cx + side * 9, cy - h - 3.5), "none", shade(lk["skin"], 0.3), 1.4))   # 쌍꺼풀
        by = cy - h - 10.0 + (2.0 if kind == "sharp" else 0.0)
        brow = P("M", cx - side * 14.0, by + 3.0 - bt * 0.3, "Q", cx - side * 2, by - 3.5, cx + side * 15.0, by + 1.5 + bt)
        out.append(path(brow, "none", brow_col, 5.2 if sex == "m" else 2.8))
        if lk.get("mole") and side == 1:
            out.append('<circle cx="%s" cy="%s" r="1.6" fill="%s"/>' % (f(cx + 12), f(cy + 11), shade(lk["skin"], 0.6)))
    return defs, out


def face_parts(lk, pk):
    sex, skin = lk["sex"], lk["skin"]
    out = []
    out.append('<path d="%s" fill="%s" opacity="0.5"/>' % (P("M", 130, 124, "L", 134, 140, "Q", 131, 144, 127, 142, "Q", 130, 136, 130, 124, "Z"), shade(skin, 0.45)))
    out.append(path(P("M", 126, 142, "Q", 130, 145, 134, 141), "none", shade(skin, 0.5), 2.0))
    out.append('<ellipse cx="129" cy="138" rx="1.6" ry="1.2" fill="#ffffff" opacity="0.5"/>')
    my = 155 if sex == "m" else 153
    smile = pk.pm(1.5) + (1.5 if lk.get("smile") else 0.0)
    if sex == "f":
        lip = lk.get("lip") or "#b9555a"
        out.append(path(P("M", 120, my, "Q", 128, my + 4 + smile, 136, my, "Q", 128, my + 7, 120, my, "Z"), lip, mix(lip, LINE, 0.5), 1.4))
        out.append('<ellipse cx="103" cy="138" rx="9" ry="4.5" fill="#f08a80" opacity="0.3"/>')
        out.append('<ellipse cx="153" cy="138" rx="9" ry="4.5" fill="#f08a80" opacity="0.26"/>')
    else:
        out.append(path(P("M", 118, my, "Q", 128, my + 2.5 + smile, 138, my - 0.5), "none", mix(shade(skin, 0.7), LINE, 0.3), 2.6))
        out.append(path(P("M", 123, my + 6, "Q", 128, my + 7.5, 133, my + 6), "none", shade(skin, 0.28), 1.6))
    if lk.get("old"):
        for side in (-1, 1):
            out.append(path(P("M", 128 + side * 13, 140, "Q", 128 + side * 18, 150, 128 + side * 16, 158), "none", shade(skin, 0.32), 1.6))
            out.append(path(P("M", 128 + side * 30, 124, "L", 128 + side * 34, 128), "none", shade(skin, 0.3), 1.4))
    return out


def beard(lk):
    b = lk.get("beard", "none")
    hc = lk["hair"] if lk["style"] != "bald" else "#2a2228"
    out = []
    if b == "stubble":
        out.append('<path d="%s" fill="%s" opacity="0.2"/>' % (
            P("M", 92, 134, "C", 98, 156, 112, 172, 128, 174, "C", 144, 172, 158, 156, 164, 134,
              "C", 156, 150, 142, 160, 128, 160, "C", 114, 160, 100, 150, 92, 134, "Z"), shade(hc, 0.2)))
    elif b == "full":
        out.append(union([(P("M", 90, 130, "C", 94, 160, 110, 180, 128, 182, "C", 146, 180, 162, 160, 166, 130,
                             "C", 158, 150, 146, 162, 128, 162, "C", 110, 162, 98, 150, 90, 130, "Z"), hc)], 1.2))
        out.append(path(P("M", 118, 170, "Q", 128, 176, 138, 170), "none", light(hc, 0.35), 1.8))
    if lk.get("mustache") or b == "full":
        out.append(path(P("M", 114, 151, "Q", 122, 145, 128, 149, "Q", 134, 145, 142, 151, "Q", 134, 151, 128, 152, "Q", 122, 151, 114, 151, "Z"), hc, LINE, 1.8))
    return out


def extras(lk, pk):
    out = []
    if lk.get("scar"):
        x = 148 + pk.pm(4)
        col = mix(lk["skin"], "#a8504a", 0.35)
        out.append(path(P("M", x, 108, "L", x + 7, 136), "none", col, 2.0))
        out.append(path(P("M", x + 1, 120, "L", x + 6, 119), "none", col, 1.4))
    g = lk.get("glasses")
    if g:
        fr = g.get("frame") or "#2a2a30"
        tint = g.get("tint")
        for side in (-1, 1):
            cx = 128 + side * 21
            lens = P("M", cx - 15, 111, "L", cx + 15, 111, "Q", cx + 16, 128, cx + 11, 131, "L", cx - 11, 131, "Q", cx - 16, 128, cx - 15, 111, "Z")
            if tint:
                out.append('<path d="%s" fill="%s" opacity="0.85"/>' % (lens, tint))
                out.append(path(P("M", cx - 10, 116, "L", cx - 3, 116), "none", "#ffffff", 2.2, ' opacity="0.55"'))
            else:
                out.append('<path d="%s" fill="#dfeaf5" opacity="0.16"/>' % lens)
                out.append(path(P("M", cx - 10, 126, "L", cx - 4, 116), "none", "#ffffff", 1.8, ' opacity="0.5"'))
            out.append(path(lens, "none", fr, 2.8))
        out.append(path(P("M", 122, 115, "Q", 128, 111, 134, 115), "none", fr, 2.6))
    if lk.get("earring"):
        out.append('<circle cx="86" cy="130" r="2.8" fill="#1a1a1f" stroke="#c9ccd4" stroke-width="1.2"/>')
    return out


def head(cid, lk, pk):
    skin = lk["skin"]
    sex = lk["sex"]
    face = FACE[sex]
    sline = mix(shade(skin, 0.7), LINE, 0.55)
    defs, out = [], []
    ears = []
    for s in (-1, 1):
        x = 128 + s * 43
        ears.append(P("M", x, 102, "C", x + s * 13, 98, x + s * 15, 128, x + s * 1, 134, "Z"))
    out.append(union([(d, skin) for d in ears] + [(face, skin)], 1.5, sline))
    c, g = lit("f_" + cid, [face], skin, light(skin, 0.45), 3.0, 2.0)
    defs.append(c)
    out.append(g + '<path d="%s" fill="%s" opacity="0.5"/></g>' % (FACE_SHADOW[sex], shade(skin, 0.4)))
    for s in (-1, 1):
        x = 128 + s * 43
        out.append(path(P("M", x + s * 3, 108, "Q", x + s * 10, 116, x + s * 3, 126), "none", shade(skin, 0.4), 1.8))
    if lk["style"] not in ("bald", "buzz", "slick", "undercut", "tied"):   # 앞머리 그늘
        out.append('<path d="%s" fill="%s" opacity="0.4"/>' % (P("M", 86, 92, "Q", 128, 112, 170, 92, "L", 170, 104, "Q", 128, 124, 86, 104, "Z"), shade(skin, 0.45)))
    out += beard(lk)
    d2, o2 = eyes(cid, lk, pk)
    defs += d2
    out += o2
    out += face_parts(lk, pk)
    out += extras(lk, pk)
    d3, o3 = front_hair(cid, lk, pk)
    defs += d3
    out += o3
    return defs, out


def portrait_svg(cid, lk):
    pk = Pick(cid)
    defs, parts = [], []
    bh = back_hair(lk, pk)
    if bh:
        parts.append('<g transform="%s">%s</g>' % (HEAD, bh))
    d1, b = body(lk)
    defs += d1
    parts += b
    d2, h = head(cid, lk, pk)
    defs += d2
    parts.append('<g transform="%s">\n%s\n</g>' % (HEAD, "\n".join(h)))
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
