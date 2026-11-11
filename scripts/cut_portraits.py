#!/usr/bin/env python3.11
"""원작 공식 인물 카드에서 초상을 잘라 낸다 — 개인 빌드 전용(00 결정 5 · CLAUDE.md 13절 · docs/기획_차이.md (라)14).

    python3.11 -B scripts/cut_portraits.py           # castle_common sources/character_profile/ 카드 → assets/chars/cut/<id>.png + heads.json (멱등)
    python3.11 -B scripts/cut_portraits.py --check   # 지금 파일이 다시 자른 것과 같은지(PIL 필요 — verify 단계에는 넣지 않음)

- 무엇: 공식 인물 카드(773×1124 · '© 2019 CASTLE 정연') 36장의 그림 칸(x 55~412 · y 160~543)에서
  위쪽 정사각형(357)을 잘라 384px PNG 로 줄인다. 얼굴 자리(heads.json)는 지도 동그란 패에 쓴다(ui/sprites.gd).
- 카드 목록 · 파일 ↔ id 는 castle_common work/profile/profiles.json 의 cards(읽기만). 작은 카드(thumbs · 80×116)는
  얼굴이 너무 작아 쓰지 않는다 — 그 인물은 벡터 초상(scripts/draw_portraits.py)이 그대로 쓰인다.
- 얼굴 자리(FACES)는 사람이 카드 묶음 그림을 보고 적은 값이다(원본 카드 좌표 · 중심 x · y · 한 변).
- 배포 빌드는 이 폴더를 빼야 한다(export_presets 의 exclude_filter 에 assets/chars/cut/* — 배포 때 다시 묻는다).
"""
import hashlib
import io
import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COMMON = os.environ.get("CASTLE_COMMON") or os.path.join(ROOT, "..", "castle_common")
SRC = os.path.join(COMMON, "sources", "character_profile")
PROFILES = os.path.join(COMMON, "work", "profile", "profiles.json")
OUT = os.path.join(ROOT, "assets", "chars", "cut")
SIZE = 384
FRAME = (55, 160, 412, 543)   # 카드 그림 칸(원본 좌표)

# id: (얼굴 중심 x, 중심 y, 머리 둘레 한 변) — 원본 카드 좌표
FACES = {
    "kimshin": (243, 263, 150), "gangchangseok": (243, 273, 160), "yundeoksu": (254, 284, 180),
    "gangminseong": (233, 263, 165), "kimhwang": (254, 295, 165), "kimdaegeon": (233, 263, 160),
    "kimseongjun": (200, 263, 150), "namyong": (233, 263, 165), "namilho": (254, 263, 165),
    "dojiung": (313, 244, 110), "immuyeol": (233, 263, 165), "jintae": (141, 283, 140),
    "baekdochan": (236, 250, 140), "wonil": (233, 252, 165), "wonyong": (233, 241, 160),
    "iriwon": (236, 244, 110), "iseul": (222, 263, 165), "icheolmin": (211, 226, 110),
    "ihwan": (200, 252, 165), "chasumin": (211, 263, 150), "ilguk": (234, 202, 120),
    "choeminuk": (222, 263, 165), "pyoyoung": (233, 263, 150), "woojin": (211, 241, 150),
    "kimyongseong": (243, 248, 150), "kimjaehoon": (233, 263, 150), "kimtaehoon": (254, 263, 165),
    "ryujihak": (243, 230, 125), "sintaejin": (222, 252, 160), "ojiin": (243, 241, 140),
    "hyeonseok": (233, 252, 165), "hwangbomincheol": (229, 230, 120), "juro": (222, 241, 140),
    "cheonildo": (233, 263, 165), "lingling": (273, 297, 100), "yuwoosung": (243, 252, 165),
}


def cards():
    with open(PROFILES, encoding="utf-8") as f:
        return sorted(json.load(f)["cards"], key=lambda c: c["id"])


def make(card):
    """카드 하나 → (PNG 바이트, 얼굴 자리 [x, y, w, h] — 384 그림 좌표)."""
    cx, cy, s = FACES[card["id"]]
    s = s * 1.15   # 지도 동그란 패에서 머리 둘레가 잘리지 않게 조금 넓힌다
    x0, y_top, x1, y_bot = FRAME
    side = x1 - x0
    y0 = min(max(int(cy - 0.42 * side), y_top), y_bot - side)
    im = Image.open(os.path.join(SRC, card["file"])).convert("RGB").crop((x0, y0, x1, y0 + side))
    im = im.resize((SIZE, SIZE), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "PNG", optimize=True)
    k = SIZE / side
    hx = max(0, min(SIZE - s * k, (cx - s / 2 - x0) * k))
    hy = max(0, min(SIZE - s * k, (cy - s / 2 - y0) * k))
    return buf.getvalue(), [round(hx), round(hy), round(s * k), round(s * k)]


def build():
    pngs, heads = {}, {}
    for c in cards():
        if c["id"] not in FACES:
            sys.exit("cut: 얼굴 자리 없음 %s (%s)" % (c["id"], c["file"]))
        data, head = make(c)
        pngs[c["id"] + ".png"] = data
        with open(os.path.join(SRC, c["file"]), "rb") as f:
            src_sha = hashlib.sha256(f.read()).hexdigest()
        heads[c["id"]] = {"head": head, "src": "sources/character_profile/" + c["file"], "src_sha256": src_sha}
    meta = {"_about": "원작 공식 인물 카드 초상(개인 빌드 전용) — scripts/cut_portraits.py 가 만든다. head = 지도 얼굴 패에 쓸 자리(384 그림 좌표 x · y · w · h).",
            "heads": heads}
    pngs["heads.json"] = (json.dumps(meta, ensure_ascii=False, indent=1, sort_keys=True) + "\n").encode("utf-8")
    return pngs


def main():
    files = build()
    if "--check" in sys.argv:
        bad = [n for n, b in files.items() if not os.path.exists(os.path.join(OUT, n)) or open(os.path.join(OUT, n), "rb").read() != b]
        extra = sorted(set(os.listdir(OUT)) - set(files) - {n + ".import" for n in files}) if os.path.isdir(OUT) else []
        print("cut: 초상 %d장 · 다름 %d · 남는 파일 %d" % (len(files) - 1, len(bad), len(extra)))
        sys.exit(1 if bad or extra else 0)
    os.makedirs(OUT, exist_ok=True)
    for n, b in sorted(files.items()):
        with open(os.path.join(OUT, n), "wb") as f:
            f.write(b)
    print("cut: 초상 %d장 → assets/chars/cut/" % (len(files) - 1))


if __name__ == "__main__":
    main()
