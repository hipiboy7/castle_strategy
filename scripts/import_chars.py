"""인물 도트 받기 — 취호전 시트 내보내기(00 7절 · 08 10절 · 보류 #2 답 (가)) → 이 판의 묶음 그림 두 장 + 색인.

    python3 -B scripts/import_chars.py           # 받기 — 같은 취호전 커밋이면 같은 파일(멱등)
    python3 -B scripts/import_chars.py --check   # 받은 묶음 점검만(pygame 없이 · scripts/verify.py '도트 묶음' 단계)

- 무엇: 장르 팩 시나리오 명단(roster · assign)의 인물 중 취호전 외형이 있는 사람마다 대표 차림(base)의
  대화 초상(기본 표정 32×32)과 필드 정면 서기(아래 방향 · 프레임 1 · 24×32)를 한 장씩 묶는다.
  → assets/chars/portraits.png · figures.png(16칸 한 줄) · index.json(canon id → 칸 번호 · 취호전 커밋 도장 · 없는 인물).
- 어떻게: 취호전 tools/export_characters.py 를 --no-cards · 빈 --ref 로 돌려 .work/chars_export/ 에 떨군 뒤 그 PNG 만 읽는다
  (원작 조각 ref 그림은 읽지도 넣지도 않는다 — 저장소 공개 중 · CLAUDE.md 13절). 취호전 파일은 고치지 않는다(-B · 출력은 .work/).
- 환경: $CASTLE_RPG(취호전 폴더 · 없으면 ../castle) · $CASTLE_ART_PY(pygame 이 든 python · 없으면 .tools/artvenv/bin/python —
  만들기: python3.11 -m venv .tools/artvenv && .tools/artvenv/bin/pip install pygame).
- 설계: docs/C2_설계서_화면과명령.md 5절 · 요구: FR-212 · 출처: assets/ASSETS.md
"""
import json
import os
import shutil
import struct
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "chars")
WORK = os.path.join(ROOT, ".work", "chars_export")
NOREF = os.path.join(ROOT, ".work", "chars_noref")
SCEN = os.path.join(ROOT, "data", "common", "packs", "strategy", "scenarios.json")
CANON = os.path.join(ROOT, "data", "common", "canon", "characters.json")
COLS = 16
FILES = ("portraits.png", "figures.png", "index.json")


def rpg_dir():
    return os.environ.get("CASTLE_RPG") or os.path.join(os.path.dirname(ROOT), "castle")


def art_python():
    return os.environ.get("CASTLE_ART_PY") or os.path.join(ROOT, ".tools", "artvenv", "bin", "python")


def wanted_ids():
    """시나리오 명단 · assign 의 canon id(정렬)."""
    with open(SCEN, encoding="utf-8") as f:
        sc = json.load(f)["scenarios"]
    ids = set()
    for s in sc:
        for r in list(s.get("roster") or []) + list(s.get("assign") or []):
            ids.add(r["id"])
    return sorted(ids)


def canon_ids():
    with open(CANON, encoding="utf-8") as f:
        return {c["id"] for c in json.load(f)["characters"]}


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        return None
    return struct.unpack(">II", head[16:24])


def check():
    """받은 묶음 점검 — 파일 · 그림 크기 = 칸 수 · id 가 canon 에 있음 · 명단 인물은 그림이 있거나 '없음' 목록에 있음."""
    errs = []
    for n in FILES:
        if not os.path.exists(os.path.join(OUT, n)):
            errs.append(f"assets/chars/{n} 가 없다 — python3 -B scripts/import_chars.py")
    if errs:
        return errs
    with open(os.path.join(OUT, "index.json"), encoding="utf-8") as f:
        idx = json.load(f)
    ids, missing = idx.get("ids", {}), idx.get("missing", [])
    n = len(ids)
    rows = (n + COLS - 1) // COLS
    for name, cell in (("portraits.png", idx["cell"]["portrait"]), ("figures.png", idx["cell"]["figure"])):
        got = png_size(os.path.join(OUT, name))
        want = (cell[0] * COLS, cell[1] * rows)
        if got != want:
            errs.append(f"{name} 크기 {got} · 바란 값 {want}(칸 {n})")
    if sorted(ids.values()) != list(range(n)):
        errs.append("index.json ids 의 칸 번호가 0..n-1 이 아니다")
    known = canon_ids()
    bad = sorted(i for i in list(ids) + list(missing) if i not in known)
    if bad:
        errs.append("canon 에 없는 id: " + ", ".join(bad))
    left = sorted(set(wanted_ids()) - set(ids) - set(missing))
    if left:
        errs.append("명단에 있는데 색인에 없는 id(다시 받기): " + ", ".join(left))
    return errs


def git_head(path):
    try:
        sha = subprocess.run(["git", "-C", path, "rev-parse", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()
        dirty = subprocess.run(["git", "-C", path, "status", "--porcelain"], capture_output=True, text=True, check=True).stdout.strip()
        return sha, bool(dirty)
    except (OSError, subprocess.CalledProcessError):
        return "", False


def build():
    """art python 안에서 돈다 — pygame 으로 내보낸 PNG 를 읽어 묶는다."""
    os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
    os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
    os.environ.setdefault("PYGAME_HIDE_SUPPORT_PROMPT", "1")
    import pygame
    rpg = rpg_dir()
    tool = os.path.join(rpg, "tools", "export_characters.py")
    if not os.path.exists(tool):
        print(f"취호전 내보내기 도구가 없다: {tool} — $CASTLE_RPG 로 취호전 폴더를 알려 준다")
        return 2
    sha, dirty = git_head(rpg)
    sys.path.insert(0, rpg)
    pygame.init()
    if pygame.display.get_surface() is None:
        pygame.display.set_mode((1, 1))
    from castle.data.looks_canon import BASE, CANON_ID  # noqa: E402 — 취호전 외형 키 → canon id
    by_canon = {}
    for key in sorted(BASE):
        by_canon.setdefault(CANON_ID.get(key), []).append(key)
    sys.path.remove(rpg)
    want = wanted_ids()
    keys, missing = {}, []
    for cid in want:
        ks = by_canon.get(cid)
        if not ks:
            missing.append(cid)
            continue
        keys[cid] = cid if cid in ks else ks[0]        # 변형 키(kimshin_coat …)보다 canon id 와 같은 키
    shutil.rmtree(WORK, ignore_errors=True)
    os.makedirs(NOREF, exist_ok=True)
    cmd = [art_python(), "-B", tool, WORK] + sorted(set(keys.values())) + ["--ref", NOREF, "--no-cards"]
    p = subprocess.run(cmd, capture_output=True, text=True, cwd=rpg)
    print(p.stdout.strip().splitlines()[-1] if p.stdout.strip() else p.stderr[-800:])
    if p.returncode != 0:
        return 1
    with open(os.path.join(WORK, "index.json"), encoding="utf-8") as f:
        ex = json.load(f)
    base = {e["key"]: e for e in ex["entries"] if e["chapter"] is None}
    order = sorted(keys)
    n = len(order)
    rows = (n + COLS - 1) // COLS
    port = fig = None
    pw = ph = fw = fh = 0
    for i, cid in enumerate(order):
        d = os.path.join(WORK, "chars", keys[cid], "base")
        pi = pygame.image.load(os.path.join(d, "portrait_base.png"))
        fs = pygame.image.load(os.path.join(d, "field.png"))
        if port is None:
            pw, ph = pi.get_size()
            fw, fh = fs.get_width() // 3, fs.get_height() // len(ex["directions"])
            port = pygame.Surface((pw * COLS, ph * rows), pygame.SRCALPHA)
            fig = pygame.Surface((fw * COLS, fh * rows), pygame.SRCALPHA)
            port.fill((0, 0, 0, 0))
            fig.fill((0, 0, 0, 0))
        x, y = i % COLS, i // COLS
        port.blit(pi, (x * pw, y * ph))
        row = ex["directions"].index("down")
        fig.blit(fs, (x * fw, y * fh), pygame.Rect(fw * 1, fh * row, fw, fh))   # 정면 · 정지 프레임
        assert keys[cid] in base, keys[cid]
    os.makedirs(OUT, exist_ok=True)
    pygame.image.save(port, os.path.join(OUT, "portraits.png"))
    pygame.image.save(fig, os.path.join(OUT, "figures.png"))
    idx = {
        "about": "인물 도트 묶음 — scripts/import_chars.py 가 만든다(손대지 않음). 칸 번호 n → (n % cols, n // cols). 그림은 취호전 코드 생성 도트(원작 컷 아님).",
        "source": {"repo": "castle(취호전)", "commit": sha, "dirty": dirty, "tool": "tools/export_characters.py --no-cards",
                   "outfit": "base(대표 차림)", "portrait": "portrait_base.png(기본 표정)", "figure": "field.png 아래 방향 · 프레임 1"},
        "cols": COLS, "cell": {"portrait": [pw, ph], "figure": [fw, fh]},
        "ids": {cid: i for i, cid in enumerate(order)}, "keys": {cid: keys[cid] for cid in order},
        "missing": missing,
    }
    with open(os.path.join(OUT, "index.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(idx, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")
    print(f"import_chars: 인물 {n}명(없음 {len(missing)}) · 칸 초상 {pw}x{ph} · 서기 {fw}x{fh} · 취호전 {sha[:7]}{' (고친 파일 있음)' if dirty else ''} → assets/chars/")
    errs = check()
    for e in errs:
        print("FAIL " + e)
    return 1 if errs else 0


def main(a):
    if "--check" in a:
        errs = check()
        for e in errs:
            print("FAIL " + e)
        if not errs:
            with open(os.path.join(OUT, "index.json"), encoding="utf-8") as f:
                idx = json.load(f)
            print(f"chars: 인물 {len(idx['ids'])}명 · 그림 없음 {len(idx['missing'])}명 · 취호전 {idx['source']['commit'][:7]}")
        return 1 if errs else 0
    try:
        import pygame  # noqa: F401
    except ImportError:
        py = art_python()
        if os.path.abspath(sys.executable) == os.path.abspath(py) or not os.path.exists(py):
            print(f"pygame 이 든 python 이 없다({py}) — python3.11 -m venv .tools/artvenv && .tools/artvenv/bin/pip install pygame")
            return 2
        return subprocess.run([py, "-B", os.path.abspath(__file__)] + a).returncode
    return build()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
