"""전체 검증(창 없음) — 이 명령이 0 으로 끝나야 커밋 · push 한다(CLAUDE.md 1절 9단계). castle_M3D scripts/verify.py 골격을 옮겼다.

    python3 -B scripts/verify.py            # 작업 서버(약 30초 — Godot 은 scripts/get_godot.py 가 .tools/ 에 받는다)
    python3 -B scripts/verify.py --strict   # castle_common 이 받은 판보다 앞서 있으면 실패(마일스톤 끝 · 태그 전)
    GODOT=/path/to/godot python3 scripts/verify.py   # CI — Godot 실행 파일을 환경 변수로

단계(요구: docs/C1_요구사항정의서_시뮬코어.md FR-108):
  공통 데이터   data/common/ 받은 파일이 도장 SOURCE.json 의 sha256(CRLF → LF)과 같다(손으로 고치지 않았다). 도장의 판이
                data/common_pin.json 과 같다(공개 판 예외 — data/common/ 은 커밋하지 않고 CI 가 핀 판을 받는다 · 기획_차이 (다)14).
                옆 castle_common(환경 변수 CASTLE_COMMON, 없으면 ../castle_common)이 앞서 있으면 알림(--strict 는 실패).
                받은 사본이 없으면 실패(받는 명령을 알려 준다)
  자산 출처     assets/ 의 파일(.import 빼고)이 모두 assets/ASSETS.md 에 있고, 목록에만 있는 파일이 없다
  인물 그림     scripts/draw_portraits.py --check — assets/chars/svg 가 looks.json 에서 다시 그린 것과 같음 · id 가 canon 에 있음 · 명단 인물이 모두 있음(FR-212 · (라)12)
  기준 구현     tools/rng_ref.py --check — 기대값 파일이 기준 구현 그대로이고, PCG32 공개 데모 수열과 같다
  가져오기      godot --headless --path . --import (스크립트 문법 · 자원)
  시험          godot --headless --path . -s res://tests/run_tests.gd (tests/unit = A · tests/integration = B)
  커버리지      함수 단위 — .tools/cov/ 사본의 A · B 파일 함수 머리마다 표시 줄을 넣고 시험을 다시 돌린다. A ≥ 90% · B ≥ 70%
  자동 진행     -- --autoplay --turns 26 --seed S (시나리오 A · 시드 1 · 2 · 3, 두 번씩) — RESULT 해시가 두 번 같고
                tests/integration/golden_a.json 기준값과 같다 · 불변식 위반 0
  구간 전투     -- --fight-test --seed 1 두 번(C4 FR-405) — 실시간 구간 판(fight/)을 봇으로 끝까지: FIGHT 줄이 두 번 같고 구간이 끝난다
  화면 띄우기   --quit-after 120 (창 없이 화면 장면을 120 프레임) — APP ready · SELFHASH 가 시드 1 기준값
  잘못된 인자   -- --turns 0 — ARGS 줄 · 종료 코드 2
  문서 명령     README · 테스트결과서 · 폰확인의 `python3 -B <파일>` 과 저장소 경로가 실제로 있다
출력에 SCRIPT ERROR · ERROR: · WARNING: · Leaked · Parse Error 가 하나라도 있으면 그 단계는 실패다.
마지막 줄: verify: N/M 통과 · X초 — OK|FAIL (종료 코드 0 · 1)
"""
import fnmatch
import glob
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import get_godot  # noqa: E402

COMMON_DIR = os.path.join(ROOT, "data", "common")
COMMON_PIN = os.path.join(ROOT, "data", "common_pin.json")   # 받은 판(커밋한다 — data/common/ 은 .gitignore)
COMMON_SRC = os.environ.get("CASTLE_COMMON") or os.path.join(os.path.dirname(ROOT), "castle_common")
RECEIVES = ("data/*.json", "cases/*.json", "canon/*.json", "packs/strategy/*.json", "docs/개발규격/*.md")  # docs/castle_common_요청.md #14
ASSETS = os.path.join(ROOT, "assets")
GOLDEN = os.path.join(ROOT, "tests", "integration", "golden_a.json")   # 시나리오 A 26턴 기준 해시(seed → hash)
# CLAUDE.md 3절 TDD 등급 — 함수 단위 커버리지를 재는 파일(화면 장면 ui/app.gd 와 부품 · 진입 src/main.gd 는 C · 화면 단계가 본다)
COV_FILES = {
    "A": ["sim/rng.gd", "sim/hash.gd", "src/launch.gd", "ui/layout.gd",
          "sim/rules_common.gd", "sim/tables.gd", "sim/state.gd", "sim/fixed.gd", "sim/economy.gd", "sim/setup.gd",
          "sim/orders.gd", "sim/kinds/move.gd", "sim/kinds/open.gd", "sim/kinds/expand.gd", "sim/kinds/recruit.gd",
          "sim/kinds/rest.gd", "sim/save.gd", "ui/map_layout.gd", "ui/view.gd", "sim/draft.gd",
          "sim/duel.gd", "sim/combat.gd", "sim/outcome.gd", "sim/kinds/raid.gd", "sim/kinds/defend.gd",
          "ui/touch_scroll.gd",
          "fight/rules_rt.gd", "fight/build.gd", "fight/world.gd", "fight/fighter.gd", "fight/fighter_body.gd",
          "fight/moves.gd", "fight/skills.gd", "ui/fight3d/screen_mode.gd", "src/settings.gd"],
    "B": ["src/storage.gd", "src/data_files.gd", "sim/turn.gd", "sim/ai.gd", "sim/game.gd",
          "fight/section.gd", "fight/bot.gd", "fight/enemy_ai.gd", "src/fight_test.gd"],
}
COV_DIRS = ("sim", "src", "ui", "tests", "data", "fight")
COV_MIN = {"A": 0.90, "B": 0.70}
DOCS_WITH_COMMANDS = ("README.md", "docs/폰확인.md", "docs/C*_테스트결과서_*.md")
FUNC_RE = re.compile(r"^(\s*)(?:static\s+)?func\s+(\w+)\s*\(")
BAD = re.compile(r"SCRIPT ERROR|^ERROR:|^WARNING:|Leaked|Parse Error", re.M)


def godot():
    exe = os.environ.get("GODOT")
    if exe:
        return exe
    if get_godot.main() != 0:
        sys.exit("Godot 를 받지 못했다")
    return get_godot.EXE


def _tail(out, n=25):
    return "\n".join("     " + ln for ln in out.strip().splitlines()[-n:])


def run(name, cmd, check_out=None, timeout=600, want_code=0):
    t0 = time.time()
    try:
        p = subprocess.run(cmd, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True,
                           encoding="utf-8", errors="replace", stdin=subprocess.DEVNULL, timeout=timeout)
    except subprocess.TimeoutExpired as e:
        out = e.stdout.decode("utf-8", "replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
        print(f"[FAIL] {name} — {timeout}초 안에 끝나지 않았다\n" + _tail(out))
        return False
    out = p.stdout or ""
    bad = BAD.findall(out)
    msg = ""
    ok = p.returncode == want_code and not bad
    if check_out is not None:
        good, msg = check_out(out)
        ok = ok and good
    print(f"[{'ok' if ok else 'FAIL'}] {name} ({time.time() - t0:.1f}s){' — ' + msg if msg else ''}")
    if not ok:
        print(f"     종료 코드 {p.returncode}(바란 값 {want_code})" + (f" · 나쁜 줄 {bad[:3]}" if bad else ""))
        print(_tail(out))
    return ok


def _digest(path):
    """sha256 — 줄 끝 CRLF 를 LF 로 바꾼 내용(castle_common tools/sync.py 와 같은 방법)."""
    with open(path, "rb") as f:
        return hashlib.sha256(f.read().replace(b"\r\n", b"\n")).hexdigest()


def _src_path(rel):
    """받은 파일의 castle_common 쪽 경로 — data/ 의 것은 받는 폴더 바로 아래로 온다(sync.py)."""
    return os.path.join(COMMON_SRC, *(rel.split("/") if "/" in rel else ["data", rel]))


def step_common(strict):
    """True/False = 통과/실패"""
    stamp_path = os.path.join(COMMON_DIR, "SOURCE.json")
    with open(COMMON_PIN, encoding="utf-8") as f:
        pin = json.load(f)["castle_common"]
    if not os.path.exists(stamp_path):
        print(f"[FAIL] 공통 데이터 — 받은 사본이 없다(data/common/ 은 커밋하지 않는다 · 기획_차이 (다)14). castle_common 을 "
              f"{pin[:7]} 판으로 두고 그 폴더에서 python3 -B tools/sync.py castle_strategy")
        return False
    with open(stamp_path, encoding="utf-8") as f:
        stamp = json.load(f)
    if stamp["castle_common"] != pin:
        print(f"[FAIL] 공통 데이터 — 받은 판 {stamp['castle_common'][:7]} 이 핀 data/common_pin.json {pin[:7]} 과 다르다 "
              "(새로 받았으면 핀을 SOURCE.json 값으로 고치고 시험 · 아니면 핀 판으로 다시 받는다)")
        return False
    want = stamp["files"]
    have = {}
    for p in glob.glob(os.path.join(COMMON_DIR, "**", "*"), recursive=True):
        rel = os.path.relpath(p, COMMON_DIR).replace(os.sep, "/")
        if os.path.isfile(p) and rel != "SOURCE.json":
            have[rel] = _digest(p)
    edited = sorted(k for k in set(want) | set(have) if want.get(k) != have.get(k))
    if edited:
        print("[FAIL] 공통 데이터 — 도장과 다른 파일(손으로 고치지 않는다 — castle_common 에서 고치고 받는다): " + ", ".join(edited))
        return False
    ok, msg = True, f"castle_common {stamp['castle_common'][:7]} 받음 · 파일 {len(want)}개 도장과 같다"
    if os.path.isdir(os.path.join(COMMON_SRC, "data")):
        up = {rel: (_digest(_src_path(rel)) if os.path.isfile(_src_path(rel)) else None) for rel in want}
        for pat in RECEIVES:
            for p in glob.glob(os.path.join(COMMON_SRC, *pat.split("/"))):
                rel = os.path.relpath(p, COMMON_SRC).replace(os.sep, "/")
                up.setdefault(rel[len("data/"):] if rel.startswith("data/") else rel, _digest(p))
        behind = sorted(k for k in up if up[k] != want.get(k))
        if behind:
            ok = not strict
            msg += (f" · {'[실패]' if strict else '[알림]'} castle_common 이 앞섰다({len(behind)}개: {', '.join(behind[:5])}) — "
                    "castle_common 에서 python3 -B tools/sync.py castle_strategy 로 받고 시험")
        else:
            msg += " · castle_common 과 같다"
    else:
        msg += " · castle_common 폴더 없음 — 비교 건너뜀"
    print(f"[{'ok' if ok else 'FAIL'}] 공통 데이터 — {msg}")
    return ok


def step_assets():
    path = os.path.join(ASSETS, "ASSETS.md")
    if not os.path.exists(path):
        print("[FAIL] 자산 출처 — assets/ASSETS.md 가 없다")
        return False
    with open(path, encoding="utf-8") as f:
        listed = set(re.findall(r"^\|\s*`([^`]+)`", f.read(), re.M))
    files = set()
    for p in glob.glob(os.path.join(ASSETS, "**", "*"), recursive=True):
        rel = os.path.relpath(p, ASSETS).replace(os.sep, "/")
        if os.path.isfile(p) and not rel.endswith(".import") and rel != "ASSETS.md":
            files.add(rel)
    pats = {x for x in listed if "*" in x}
    hit = {x for x in files for q in pats if fnmatch.fnmatchcase(x, q)}
    missing = sorted(files - listed - hit)
    stale = sorted((listed - pats - files) | {q for q in pats if not any(fnmatch.fnmatchcase(x, q) for x in files)})
    ok = not missing and not stale
    msg = f"파일 {len(files)}개 출처 있음" if ok else (
        (f"출처 없는 파일: {', '.join(missing)}" if missing else "") + (f" · 목록에만 있음: {', '.join(stale)}" if stale else ""))
    print(f"[{'ok' if ok else 'FAIL'}] 자산 출처 — {msg}")
    return ok


def _instrument(text, rel):
    """함수마다 몸 첫 줄 앞에 커버리지 표시 줄을 넣는다. 돌려주는 값: (새 글, 함수 이름 목록)."""
    lines = text.split("\n")
    out, names, i = [], [], 0
    while i < len(lines):
        m = FUNC_RE.match(lines[i])
        if not m:
            out.append(lines[i])
            i += 1
            continue
        names.append(m.group(2))
        depth = 0
        while True:                                   # 여러 줄 머리: 괄호가 닫히고 ':' 로 끝나는 줄까지
            ln = lines[i]
            out.append(ln)
            depth += ln.count("(") - ln.count(")")
            i += 1
            if depth <= 0 and ln.rstrip().endswith(":"):
                break
        j = i
        while j < len(lines) and (not lines[j].strip() or lines[j].lstrip().startswith("#")):
            j += 1
        indent = re.match(r"^(\s*)", lines[j]).group(1) if j < len(lines) else "\t"
        out.append(f'{indent}if Engine.has_meta("cov"): Engine.get_meta("cov")["{rel}:{m.group(2)}"] = 1')
    return "\n".join(out), names


def step_coverage(g):
    t0 = time.time()
    dst = os.path.join(ROOT, ".tools", "cov")
    shutil.rmtree(dst, ignore_errors=True)
    os.makedirs(dst)
    with open(os.path.join(ROOT, "project.godot"), encoding="utf-8") as f:     # 테마 줄을 뺀다 — 사본엔 가져온 글꼴이 없다
        proj = "".join(ln for ln in f if not ln.startswith("theme/custom"))
    with open(os.path.join(dst, "project.godot"), "w", encoding="utf-8") as f:
        f.write(proj)
    for d in COV_DIRS:
        if os.path.isdir(os.path.join(ROOT, d)):
            shutil.copytree(os.path.join(ROOT, d), os.path.join(dst, d))
    funcs = {}
    for grade, files in COV_FILES.items():
        for rel in files:
            with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
                text, names = _instrument(f.read(), rel)
            with open(os.path.join(dst, rel), "w", encoding="utf-8") as f:
                f.write(text)
            funcs[rel] = (grade, names)
    out_json = os.path.join(dst, "cov.json")
    p = subprocess.run([g, "--headless", "--path", dst, "-s", "res://tests/run_tests.gd", "--", "--cov", out_json],
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True, encoding="utf-8",
                       errors="replace", timeout=600, stdin=subprocess.DEVNULL)
    if not os.path.exists(out_json):
        print("[FAIL] 커버리지 — 결과 파일이 없다\n" + _tail(p.stdout or "", 15))
        return False
    with open(out_json, encoding="utf-8") as f:
        hit = set(json.load(f))
    ok, parts, missed = True, [], []
    for grade in COV_FILES:
        tot = sum(len(funcs[r][1]) for r in COV_FILES[grade])
        got = sum(1 for r in COV_FILES[grade] for n in funcs[r][1] if f"{r}:{n}" in hit)
        k = got / tot if tot else 1.0
        ok = ok and k >= COV_MIN[grade]
        parts.append(f"{grade} {got}/{tot} {k:.0%}(기준 {COV_MIN[grade]:.0%})")
        missed += [f"{os.path.basename(r)}:{n}" for r in COV_FILES[grade] for n in funcs[r][1] if f"{r}:{n}" not in hit]
    msg = " · ".join(parts) + (f" · 안 불린 함수: {', '.join(missed)}" if missed else "")
    print(f"[{'ok' if ok else 'FAIL'}] 커버리지 ({time.time() - t0:.1f}s) — {msg}")
    return ok


def _result(out):
    m = re.search(r"^RESULT (.*)$", out, re.M)
    return json.loads(m.group(1)) if m else None


def step_autoplay(g, want):
    ok_all = True
    for seed in (1, 2, 3):
        got = []
        for _ in range(2):
            def chk(out, got=got):
                r = _result(out)
                got.append(r)
                ok = r is not None and r.get("violations") == 0
                return ok, ("" if ok else "RESULT 줄 없음 또는 불변식 위반")
            ok_all &= run(f"자동 진행 seed {seed} · 26주", [g, "--headless", "--path", ".", "--", "--autoplay", "--turns", "26",
                                                       "--seed", str(seed)], chk, timeout=120)
        hashes = [r["hash"] if r else None for r in got]
        same = len(set(hashes)) == 1 and hashes[0] == want.get(seed)
        ok_all &= same
        print(f"[{'ok' if same else 'FAIL'}] 결정성 seed {seed} — 두 번 {hashes} · 기준값 {want.get(seed)}")
    return ok_all


def step_fight(g):
    """구간 전투(C4 FR-405) — 같은 시드로 두 번 돌린 FIGHT 줄이 같고(결정성) 구간이 끝난다."""
    got = []

    def chk(out):
        m = re.search(r"^FIGHT (.*)$", out, re.M)
        got.append(m.group(1) if m else None)
        r = json.loads(m.group(1)) if m else {}
        ok = r.get("over") in ("win", "lose") and r.get("outcome", {}).get("result") in ("att", "def")
        return ok, (f"{r.get('over')} · {r.get('frames')}프레임 · 쓰러뜨림 {r.get('kills')}" if ok else "FIGHT 줄 없음 또는 구간이 안 끝남")
    ok_all = True
    for _ in range(2):
        ok_all &= run("구간 전투 seed 1", [g, "--headless", "--path", ".", "--", "--fight-test", "--seed", "1"], chk, timeout=120)
    same = len(got) == 2 and got[0] is not None and got[0] == got[1]
    print(f"[{'ok' if same else 'FAIL'}] 구간 전투 결정성 — 두 번 {'같다' if same else '다르다'}")
    return ok_all and same


def step_docs():
    paths = []
    for pat in DOCS_WITH_COMMANDS:
        paths += sorted(glob.glob(os.path.join(ROOT, *pat.split("/"))))
    missing = []
    for path in paths:
        with open(path, encoding="utf-8") as f:
            spans = re.findall(r"`([^`\n]+)`", f.read())
        for s in spans:
            m = re.match(r"python3 -B ([\w./-]+\.py)", s)
            cand = m.group(1) if m else s
            if m is None and (" " in s or "/" not in s or "://" in s or s.startswith(("~", "../", "res://", "user://", "-"))
                              or any(ch in s for ch in "*<>|{}$")):
                continue
            if not os.path.exists(os.path.join(ROOT, *cand.rstrip("/").split("/"))):
                missing.append(f"{os.path.relpath(path, ROOT)}: {cand}")
    ok = not missing
    print(f"[{'ok' if ok else 'FAIL'}] 문서 명령 — " + (f"문서 {len(paths)}개의 명령 · 경로가 있다" if ok else "없는 것: " + ", ".join(missing)))
    return ok


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")      # 윈도우 콘솔에서 한글 출력에 죽지 않게
    except (AttributeError, ValueError):
        pass
    strict = "--strict" in sys.argv[1:]
    g = godot()
    t0 = time.time()
    results = [r for r in (step_common(strict),) if r is not None]
    results.append(step_assets())
    results.append(run("인물 그림", [sys.executable, "-B", os.path.join("scripts", "draw_portraits.py"), "--check"],
                       lambda out: (True, (re.findall(r"^chars: .*$", out, re.M) or [""])[-1])))
    results.append(run("기준 구현", [sys.executable, "-B", os.path.join("tools", "rng_ref.py"), "--check"]))
    with open(GOLDEN, encoding="utf-8") as f:
        want = {int(k): v for k, v in json.load(f)["hash"].items()}
    if not os.path.isdir(os.path.join(ROOT, ".godot", "imported")):
        # 새로 받은 저장소(CI): 첫 가져오기는 테마 글꼴을 가져오기 전에 읽으려 해 ERROR 를 낸다 — 한 번 돌리고 다시 본다
        p = subprocess.run([g, "--headless", "--path", ".", "--import"], cwd=ROOT, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, timeout=600, stdin=subprocess.DEVNULL)
        print(f"[..] 첫 가져오기 (종료 코드 {p.returncode}, 출력은 다음 가져오기에서 본다)")
    results.append(run("가져오기", [g, "--headless", "--path", ".", "--import"]))

    def tests_ok(out):
        m = re.search(r"tests: (\d+) passed, (\d+) failed", out)
        return (m is not None and m.group(2) == "0"), (m.group(0) if m else "결과 줄 없음")
    results.append(run("시험", [g, "--headless", "--path", ".", "-s", "res://tests/run_tests.gd"], tests_ok, timeout=180))
    results.append(step_coverage(g))
    results.append(step_autoplay(g, want))
    results.append(step_fight(g))
    self_line = f"SELFHASH {want[1]}"
    results.append(run("화면 띄우기 (창 없이 120 프레임)", [g, "--headless", "--path", ".", "--quit-after", "120"],
                       lambda out: ("APP ready" in out and self_line in out, self_line if self_line in out else "자가 해시 줄 없음")))
    results.append(run("잘못된 인자", [g, "--headless", "--path", ".", "--", "--turns", "0"],
                       lambda out: ("ARGS " in out, "ARGS 줄 · 종료 코드 2"), want_code=2))
    results.append(step_docs())
    n_ok = sum(1 for r in results if r)
    print(f"verify: {n_ok}/{len(results)} 통과 · {time.time() - t0:.0f}초 — {'OK' if n_ok == len(results) else 'FAIL'}")
    return 0 if n_ok == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
