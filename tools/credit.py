"""크레딧 사용 기록 — 대화 기록(~/.claude/projects/…/*.jsonl)의 토큰 수 × API 정가로 $ 환산 (CLAUDE.md 규칙 3).

실행: python3 -B tools/credit.py [report | est N | note "작업 이름" [--est $] [--until 시각] | since "YYYY-MM-DD HH:MM" | job [start "이름" [--cap $] | end] | refresh | merge 다른원장.json]
- merge  : 다른 리눅스 계정 사본의 docs/크레딧_기록.json 에서 계정 칸 · 끝난 작업을 합친다(1부 병렬 — 마감한 계정이 다시 오면 '<계정>#2' 칸)
- report : 누적 · 일별(월/일) · 작업 기록을 화면에 (파일은 안 건드린다)
- est N  : 앞으로 호출 N 번의 예상 $ — 이 저장소 작업의 최근 호출 30번 평균 · 분위수 (작업 전 예상용)
- note   : docs/크레딧_기록.json 을 지금 값으로 갱신하고 작업 한 줄(예상 · 실제 · 누적)을 남긴 뒤 docs/크레딧_기록.md 를 다시 쓴다
           (--until 시각: 그 시각까지의 호출만 센다 — 이미 지난 구간의 기준선용)
- since  : 누적 기준일(시작 시각)을 바꾸고 그 시각부터 다시 센다 — 작업 기록은 남기고 누적 칸만 다시 계산한다
- job    : 한 번 작업의 $ 상한(기본 $1,000, 사용자 2026-11-06 답52). start 로 시작점을 잡고, 인자 없이 부르면 쓴 $ · 남은 $ 를 낸다(종료 코드 0 정상 · 2 80% 넘음 · 3 상한 도달). end 로 끝낸다
           작업은 대화(세션)마다 따로다(2026-10-30 1 · 2부 병렬): Claude Code 안에서 부르면 환경의 세션 id(CLAUDE_CODE_SESSION_ID)로
           그 대화와 그 서브에이전트 호출만 센다. 세션 id 가 없으면(손으로 터미널에서) 예전처럼 이 저장소 전체를 센다
- refresh: 지금까지를 periods 에 보관하고 누적을 0 부터 다시 시작 — 사용자가 refresh 를 요청할 때만
$ 는 정가 환산 **추정**이다(구독 · 계약 요금과 다를 수 있다). 지금 로그인한 계정의 대화 기록(~/.claude/projects)만 센다(토큰 수만 읽는다).
원장은 docs/크레딧_기록.json 하나 — 계정마다 칸(accounts.<계정>)을 나눠 쌓고 보고할 땐 더한다(계정마다 대화 기록 폴더가 달라
같은 날 · 모델 칸을 최댓값으로 합치면 틀린다). 계정 칸은 own_only 로 갈린다: false = 이 PC 전체를 센 계정(yj.jung · 2026-10-28 마감),
true = 이 저장소 작업분만 센다(juho.hong 부터 — 사용자 2026-10-28). '누적' = 계정 칸 합, '이 저장소' = 이 저장소 폴더와 그 상위 폴더에서 연 대화의 합.
다른 PC · 웹 · 데스크톱 앱 사용은 안 보인다. 진행 중인 호출과 마지막 답변은 다음 갱신에 들어간다. 월/일은 이 PC 의 현지 시각 기준.
"""
import argparse
import contextlib
import getpass
import glob
import json
import os
import re
import sys
from datetime import datetime

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import jsonfmt  # noqa: E402

LEDGER = os.path.join(ROOT, "docs", "크레딧_기록.json")
VIEW = os.path.join(ROOT, "docs", "크레딧_기록.md")
ACCOUNT = getpass.getuser()  # 원장의 계정 칸 — 대화 기록 폴더(~/.claude)가 계정마다 따로다
JOB_CAP = 1000.0  # 한 번 작업 상한 $ (사용자 2026-10-27 $50 → 2026-10-28 $100 → 2026-11-06 $1,000 답52)
PROJECTS = os.path.join(os.path.expanduser("~"), ".claude", "projects")
TOK = ("inp", "out", "cr", "w5", "w1")  # 입력 · 출력 · 캐시 읽기 · 캐시 쓰기(5분) · 캐시 쓰기(1시간)
PRICES = {  # $/MTok: (입력, 출력, 캐시 읽기)
    "claude-sonnet-5-5": (2.00, 10.00, 0.20),
    "claude-sonnet-5": (2.00, 10.00, 0.20),
    "claude-opus-5-5": (4.00, 20.00, 0.20),
    "claude-opus-5": (5.00, 25.00, 0.50),
    "claude-fable-5-1": (10.00, 50.00, 0.25),
    "claude-fable-5-2": (8.00, 40.00, 0.20),  # 스킬 모델표 2026-11-03 판 — 2026-11-11 더함(없으면 Sonnet 단가로 낮게 잡힌다)
    "claude-haiku-5-5": (0.10, 0.50, 0.01),
    "claude-haiku-4-5-20251001": (1.00, 5.00, 0.10),  # 공개 단가 — 스킬 표에 없어 추가
}
FALLBACK = "claude-sonnet-5-5"
SID = os.environ.get("CLAUDE_CODE_SESSION_ID") or None  # 지금 대화 — 작업 상한을 대화마다 따로 센다
PRICE_NOTE = "claude-api 스킬 모델표(2026-10-06 기준 · Fable 5.2 는 2026-11-03 판 $8/$40) · 캐시 쓰기는 입력 × 1.25(5분) · × 2(1시간) · Haiku 4.5 는 공개 단가 $1/$5"


def _slug(path):
    return re.sub(r"[^A-Za-z0-9]", "-", path)


def _is_own(path):
    """이 저장소 작업의 대화인가 — 프로젝트 폴더 이름이 저장소 폴더 · 그 아래 폴더.
    castle_common 원본은 상위 폴더 대화도 셌지만, 이 판은 상위 폴더(판들이 모인 곳)를 다른 판과 같이 쓰므로 뺀다(2026-11-10)."""
    top = os.path.relpath(path, PROJECTS).split(os.sep)[0]
    own = _slug(ROOT)
    return top == own or top.startswith(own + "-")


def _sid(path):
    """대화 기록 경로 → 세션 id(<프로젝트>/<세션>.jsonl · <프로젝트>/<세션>/subagents/… 모두 그 세션)."""
    parts = os.path.relpath(path, PROJECTS).split(os.sep)
    return parts[1][:-6] if len(parts) > 1 and parts[1].endswith(".jsonl") else (parts[1] if len(parts) > 1 else None)


@contextlib.contextmanager
def _lock():
    """원장을 두 대화가 동시에 고치지 않게 잠근다(fcntl 이 없는 Windows 에서는 잠그지 않는다)."""
    try:
        import fcntl
    except ImportError:
        yield
        return
    with open(LEDGER + ".lock", "w") as fh:
        fcntl.flock(fh, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(fh, fcntl.LOCK_UN)


def _transcripts():
    if not os.path.isdir(PROJECTS):
        return []
    return sorted(glob.glob(os.path.join(PROJECTS, "**", "*.jsonl"), recursive=True))


def _local(ts):
    try:
        t = datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except ValueError:
        t = datetime.strptime(ts, "%Y-%m-%dT%H:%M:%S.%f%z")
    return t.astimezone()


def _now():
    return datetime.now().astimezone()


def calls():
    """호출 하나 = 요청 하나(requestId). 같은 호출이 내용 조각마다 여러 줄로 기록되므로 칸마다 최댓값을 쓴다."""
    seen = {}
    for p in _transcripts():
        own, sid = _is_own(p), _sid(p)
        with open(p, encoding="utf-8", errors="replace") as f:
            for line in f:
                if '"usage"' not in line or '"assistant"' not in line:
                    continue
                try:
                    o = json.loads(line)
                except ValueError:
                    continue
                m = o.get("message")
                if o.get("type") != "assistant" or not isinstance(m, dict) or not m.get("usage") or not o.get("timestamp"):
                    continue
                u = m["usage"]
                cc = u.get("cache_creation") or {}
                rec = {"inp": u.get("input_tokens") or 0, "out": u.get("output_tokens") or 0,
                       "cr": u.get("cache_read_input_tokens") or 0,
                       "w5": cc.get("ephemeral_5m_input_tokens", 0) if cc else (u.get("cache_creation_input_tokens") or 0),
                       "w1": cc.get("ephemeral_1h_input_tokens", 0) if cc else 0}
                key = o.get("requestId") or m.get("id") or o.get("uuid")
                old = seen.get(key)
                if old:
                    rec = {k: max(v, old["rec"][k]) for k, v in rec.items()}
                seen[key] = {"rec": rec, "ts": old["ts"] if old else o["timestamp"], "model": m.get("model") or "?",
                             "own": old["own"] if old else own, "sid": old["sid"] if old else sid}
    return sorted(seen.values(), key=lambda c: c["ts"])


def usd(model, r):
    pin, pout, pcr = PRICES.get(model) or PRICES[FALLBACK]
    return (r["inp"] * pin + r["out"] * pout + r["cr"] * pcr + r["w5"] * pin * 1.25 + r["w1"] * pin * 2) / 1e6


def load():
    if os.path.exists(LEDGER):
        led = jsonfmt.read(LEDGER)
        if "accounts" not in led:  # 계정 칸이 생기기 전 원장 — 통째로 한 계정 칸으로 옮긴다
            led["accounts"] = {"이전": {"own_only": False, "days": led.pop("days", {}), "days_own": led.pop("days_own", {})}}
    else:
        first = calls()
        since = _local(first[0]["ts"]) if first else _now()
        led = {"since": since.isoformat(timespec="seconds"), "price_note": PRICE_NOTE, "accounts": {},
               "log": [], "periods": []}
    led["_about"] = ("tools/credit.py 가 쓴다 — 손으로 고치지 않는다. 토큰 수만 적고 $ 는 단가표로 그때그때 계산한다"
                     "(단가를 고치면 다시 계산된다). accounts.<계정>: days = 그 계정의 이 PC 전체(own_only 이면 비움), "
                     "days_own = 이 저장소 작업분, closed = 마감(더 세지 않음). 누적 = 계정 칸 합. 읽는 용: docs/크레딧_기록.md")
    global ACCOUNT
    while led["accounts"].get(ACCOUNT, {}).get("closed"):  # 마감한 칸의 계정이 다시 오면 새 칸(<계정>#2 …)에 쌓는다(2026-10-30)
        base, _, k = ACCOUNT.partition("#")
        ACCOUNT = f"{base}#{int(k or 1) + 1}"
    led["accounts"].setdefault(ACCOUNT, {"own_only": True, "days": {}, "days_own": {}})
    return led


def cmd_merge(path):
    """다른 리눅스 계정 · 다른 사본에서 쌓은 원장의 계정 칸 · 끝난 작업을 이 원장에 합친다(1부 병렬 — 2026-10-30).
    같은 계정 칸은 칸마다 최댓값(같은 대화 기록을 두 번 세지 않는다), 지금 계정 칸은 건드리지 않는다."""
    with _lock():
        led = load()
        sync(led)
        other = jsonfmt.read(path)
        n = 0
        for name, a in other.get("accounts", {}).items():
            if name == ACCOUNT:
                continue
            cur = led["accounts"].setdefault(name, {"own_only": a.get("own_only", True), "days": {}, "days_own": {}})
            for key in ("days", "days_own"):
                _merge(cur.setdefault(key, {}), a.get(key, {}))
                cur[key] = dict(sorted(cur[key].items()))
            if a.get("closed"):
                cur["closed"] = a["closed"]
            n += 1
        have = {(j["name"], j["from"]) for j in led.get("jobs", [])}
        for j in other.get("jobs", []):
            if (j["name"], j["from"]) not in have:
                led.setdefault("jobs", []).append(dict(j, src=os.path.abspath(path)))
        save(led)
    print(f"합침: 계정 칸 {n}개 · 누적 ${total(led):.2f}(전체) · 이 저장소 ${total(led, 'days_own'):.2f}")


def _tally(days, c):
    t = _local(c["ts"])
    d = days.setdefault(t.strftime("%Y-%m-%d"), {}).setdefault(
        c["model"], {"calls": 0, "inp": 0, "out": 0, "cr": 0, "w5": 0, "w1": 0})
    d["calls"] += 1
    for k in TOK:
        d[k] += c["rec"][k]


def _merge(days, fresh):
    for day, ms in fresh.items():
        cur = days.setdefault(day, {})
        for model, v in ms.items():
            cur[model] = {k: max(v[k], cur.get(model, {}).get(k, 0)) for k in v}


def sync(led, until=None):
    """대화 기록 → 지금 계정 칸의 일별 토큰(전체 `days` · 이 저장소 `days_own`). 이미 적힌 값보다 줄어들지 않게 칸마다 최댓값
    (기록 파일이 지워져도 남는다). 최댓값은 한 계정 칸 안에서만 쓴다 — 계정끼리는 더한다(`_combined`)."""
    acct = led["accounts"][ACCOUNT]
    if acct.get("closed"):
        return
    since = datetime.fromisoformat(led["since"])
    everything, own = {}, {}
    for c in calls():
        t = _local(c["ts"])
        if t < since or (until and t > until):
            continue
        if not acct.get("own_only"):
            _tally(everything, c)
        if c["own"]:
            _tally(own, c)
    for key, fresh in (("days", everything), ("days_own", own)):
        _merge(acct.setdefault(key, {}), fresh)
        acct[key] = dict(sorted(acct[key].items()))


def _combined(led, key, only=None):
    """계정 칸을 더한 일별 토큰. key="days" 면 own_only 계정은 days_own 을 쓴다(그 계정은 이 저장소분만 센다)."""
    out = {}
    for name, a in led["accounts"].items():
        if only and name != only:
            continue
        src = a.get("days_own", {}) if key == "days_own" or a.get("own_only") else a.get("days", {})
        for day, ms in src.items():
            cur = out.setdefault(day, {})
            for model, v in ms.items():
                d = cur.setdefault(model, {k: 0 for k in v})
                for k in v:
                    d[k] = d.get(k, 0) + v[k]
    return dict(sorted(out.items()))


def rows(led, key="days", only=None):
    """[(월일, 합계 토큰, 일계 $, 누적 $)]"""
    out, cum = [], 0.0
    for day, ms in _combined(led, key, only).items():
        s = {k: sum(v[k] for v in ms.values()) for k in ("calls",) + TOK}
        d = sum(usd(m, v) for m, v in ms.items())
        cum += d
        out.append((day, s, d, cum))
    return out


def total(led, key="days", only=None):
    rs = rows(led, key, only)
    return rs[-1][3] if rs else 0.0


def render(led):
    rs = rows(led)
    own = {r[0]: r[2] for r in rows(led, "days_own")}
    models = sorted({m for ms in _combined(led, "days").values() for m in ms})
    L = [f"# 크레딧 사용 기록 — {os.path.basename(ROOT)}", "",
         "> 이 파일은 `tools/credit.py` 가 만든다(손으로 고치지 않는다). 대화 기록의 토큰 수 × API 정가 환산 **추정**이다 — "
         "구독 · 계약 요금과 다를 수 있다. 계정마다 칸을 나눠 쌓고 누적은 그 합이다(토큰 수만 읽는다). 다른 PC · 웹 · 데스크톱 앱 사용은 "
         "안 보인다. 진행 중인 호출과 마지막 답변은 다음 갱신에 들어간다.", "",
         f"- **누적 ${total(led):.2f}**(계정 합) · 그중 이 저장소 작업 ${total(led, 'days_own'):.2f} · 호출 "
         f"{sum(r[1]['calls'] for r in rs)}번 · 기준 {led['since'][:16].replace('T', ' ')}(마지막 refresh · 기준일 설정) · "
         f"갱신 {_now():%m/%d %H:%M}",
         "- 계정별: " + " · ".join(
             f"{n} ${total(led, only=n):.2f}(이 저장소 ${total(led, 'days_own', only=n):.2f} · "
             f"{'이 저장소분만' if a.get('own_only') else '이 PC 전체'}{' · 마감 ' + a['closed'][:10] if a.get('closed') else ''})"
             for n, a in led["accounts"].items()),
         f"- 단가: {PRICE_NOTE} · 쓴 모델: {', '.join(models) or '—'}"]
    cs = calls() if any(j.get("sid") for j in _jobs(led).values()) else None
    for j in _jobs(led).values():
        L.append(f"- 진행 중 {_job_line(led, j, cs)[0]}")
    unknown = [m for m in models if m not in PRICES]
    if unknown:
        L.append(f"- ⚠ 단가표에 없는 모델({', '.join(unknown)}) — {FALLBACK} 단가로 환산했다")
    L += ["", "## 일별 (월/일)", "", "| 월/일 | 호출 | 입력 | 출력 | 캐시 읽기 | 캐시 쓰기 | 일계 $ | 누적 $ | 이 저장소 일계 $ |",
          "|---|---|---|---|---|---|---|---|---|"]
    for day, s, d, cum in rs:
        L.append(f"| {day[5:].replace('-', '/')} | {s['calls']} | {s['inp']:,} | {s['out']:,} | {s['cr']:,} | "
                 f"{s['w5'] + s['w1']:,} | {d:.2f} | {cum:.2f} | {own.get(day, 0.0):.2f} |")
    L += ["", "## 작업 기록 (예상 대 실제 — 실제는 이 저장소 작업분)", "",
          "| 시각 | 작업 | 예상 $ | 실제 $ | 누적 $(전체) | 누적 $(이 저장소) |", "|---|---|---|---|---|---|"]
    for r in led["log"]:
        est = "—" if r.get("est") is None else format(r["est"], ".2f")
        L.append(f"| {r['at'][5:16].replace('T', ' ')} | {r['task']} | {est} | {r['delta']:.2f} | {r['cum']:.2f} | "
                 f"{r.get('cum_own', r['cum']):.2f} |")
    if led.get("since_log"):
        L += ["", "## 기준일 이력", "", "| 바꾼 때 | 이전 | 이후 | 사유 |", "|---|---|---|---|"]
        for s in led["since_log"]:
            L.append(f"| {s['at'][5:16].replace('T', ' ')} | {s['from'][:16].replace('T', ' ')} | "
                     f"{s['to'][:16].replace('T', ' ')} | {s['why']} |")
    if led.get("jobs"):
        L += ["", "## 작업 단위 상한 이력", "", "| 작업 | 기간 | 쓴 $ | 상한 $ |", "|---|---|---|---|"]
        for j in led["jobs"]:
            L.append(f"| {j['name']} | {j['from'][5:16].replace('T', ' ')} ~ {j['to'][5:16].replace('T', ' ')} | "
                     f"{j['spent']:.2f} | {j['cap']:g} |")
    if led["periods"]:
        L += ["", "## refresh 이력", "", "| 기간 | 누적 $ | 호출 |", "|---|---|---|"]
        for p in led["periods"]:
            L.append(f"| {p['since'][:10]} ~ {p['until'][:10]} | {p['usd']:.2f} | {p['calls']} |")
    return "\n".join(L) + "\n"


def save(led):
    jsonfmt.write(LEDGER, led)
    with open(VIEW, "w", encoding="utf-8", newline="\n") as f:
        f.write(render(led))


def cmd_est(n):
    cs = [c for c in calls() if c["own"]][-30:]
    if not cs:
        print("대화 기록이 없어 예상을 못 낸다")
        return
    xs = sorted(usd(c["model"], c["rec"]) for c in cs)
    avg = sum(xs) / len(xs)
    lo, hi = xs[len(xs) // 4], xs[min(len(xs) - 1, int(len(xs) * 0.9))]
    print(f"예상: 호출 {n}번 ≈ ${n * avg:.2f} (범위 ${n * lo:.2f} ~ ${n * hi:.2f}) — 이 저장소 최근 {len(cs)}번 호출 평균 ${avg:.3f}")


def _jobs(led):
    """열린 작업 {세션 id 또는 '*': 작업} — 예전 원장의 led['job'](세션 없음)은 '*' 로 옮긴다."""
    js = led.setdefault("open_jobs", {})
    if led.get("job"):
        js.setdefault(led["job"].get("sid") or "*", led.pop("job"))
    return js


def _my_job(led):
    js = _jobs(led)
    return js.get(SID) if SID and SID in js else js.get("*")


def _spent(led, j, cs=None):
    if not j.get("sid"):  # 세션 없음 — 이 저장소 전체(예전 방식)
        return max(total(led, "days_own") - j["base_own"], 0.0)
    t0 = datetime.fromisoformat(j["at"])
    return sum(usd(c["model"], c["rec"]) for c in (cs if cs is not None else calls())
               if c.get("sid") == j["sid"] and _local(c["ts"]) >= t0)


def _job_line(led, j=None, cs=None):
    """(문장, 상한 대비 %) — 진행 중인 작업이 없으면 None."""
    j = j or _my_job(led)
    if not j:
        return None
    spent = _spent(led, j, cs)
    pct = spent / j["cap"] * 100
    flag = ("🛑 상한 도달 — 멈추고 사용자에게 보고" if pct >= 100
            else "⚠ 80% 넘음 — 다음 배치 전에 사용자에게 보고" if pct >= 80 else "OK")
    who = ("이 대화" if j["sid"] == SID else f"대화 {j['sid'][:8]}") if j.get("sid") else "이 저장소 전체"
    return (f"작업 '{j['name']}'({who}): ${spent:.2f} / 상한 ${j['cap']:g}({pct:.0f}%) · 남은 ${max(j['cap'] - spent, 0):.2f} · {flag}", pct)


def _end_job(led, key=None):
    js = _jobs(led)
    key = key or (SID if SID in js else "*")
    j = js.pop(key)
    led.setdefault("jobs", []).append({"name": j["name"], "from": j["at"], "to": _now().isoformat(timespec="minutes"),
                                       "cap": j["cap"], "spent": round(_spent(led, j), 3), "sid": j.get("sid")})


def cmd_job(action, name, cap):
    """한 번 작업의 $ 상한(CLAUDE.md 규칙 3) — 종료 코드: 0 정상 · 2 80% 넘음 · 3 상한 도달. 작업은 대화마다 하나."""
    with _lock():
        led = load()
        sync(led)
        js = _jobs(led)
        if action == "start":
            if not name:
                print('job start 에는 작업 이름이 필요하다: job start "이름" [--cap $]')
                return 1
            if _my_job(led) and (SID in js or not SID):
                print(f"이미 진행 중인 작업이 있다 — {_job_line(led)[0]}")
                return 1
            js[SID or "*"] = {"name": name, "at": _now().isoformat(timespec="seconds"), "cap": cap, "sid": SID,
                              "base_own": round(total(led, "days_own"), 3)}
        elif action == "end":
            if _my_job(led):
                print("끝:", _job_line(led)[0])
                _end_job(led)
        elif action is not None:
            print('job [start "이름" [--cap $] | end]')
            return 1
        save(led)
    others = [j for k, j in js.items() if j is not _my_job(led)]
    for j in others:
        print("  (다른 대화)", _job_line(led, j)[0])
    line = _job_line(led)
    print(line[0] if line else '진행 중인 작업 없음 — job start "이름" 으로 시작')
    return 3 if line and line[1] >= 100 else 2 if line and line[1] >= 80 else 0


def cmd_note(task, est, until):
    with _lock():
        _cmd_note(task, est, until)


def _cmd_note(task, est, until):
    led = load()
    sync(led, until)
    mine, everything = total(led, "days_own"), total(led)
    # 실제 $ = 이 계정이 자기 앞 기록 뒤로 이 저장소에서 쓴 것(2026-10-31 — 원장에 다른 계정 칸을 합치면 누적 차이에 남의 증가분이 섞였다).
    # 앞 기록 = 같은 계정(acct) 의 마지막 줄, 없으면 마지막 줄.
    last = next((x for x in reversed(led["log"]) if x.get("acct") == ACCOUNT), led["log"][-1] if led["log"] else None)
    t0 = datetime.fromisoformat(last["at"]) if last else datetime.fromisoformat(led["since"])
    delta = sum(usd(c["model"], c["rec"]) for c in calls()
                if c["own"] and t0 < _local(c["ts"]) and (not until or _local(c["ts"]) <= until))
    row = {"at": (until or _now()).isoformat(timespec="minutes"), "task": task, "est": est,
           "delta": round(delta, 3), "cum": round(everything, 3), "cum_own": round(mine, 3), "acct": ACCOUNT}
    led["log"].append(row)
    save(led)
    shown = "—" if est is None else f"${est:.2f}"
    print(f"기록: {task} · 예상 {shown} · 실제 ${row['delta']:.2f}(이 저장소) · 누적 ${row['cum']:.2f}(전체) · "
          f"이 저장소 누적 ${row['cum_own']:.2f}")
    line = _job_line(led)
    if line:
        print(line[0])


def cmd_since(text, why):
    t = datetime.fromisoformat(text.strip()).astimezone()
    led = load()
    if _jobs(led):
        print("진행 중인 작업이 있다 — 먼저 job end 로 끝낸 뒤 기준일을 바꾼다")
        return
    if any(n != ACCOUNT for n in led["accounts"]):
        print("다른 계정 칸이 있다 — 그 계정 대화 기록은 여기서 다시 셀 수 없어 기준일을 못 바꾼다(refresh 는 된다)")
        return
    old = led["since"]
    led["since"] = t.isoformat(timespec="seconds")
    led["accounts"][ACCOUNT].update(days={}, days_own={})
    sync(led)
    cs = calls()
    own_only = led["accounts"][ACCOUNT].get("own_only")
    for r in led["log"]:  # 작업 기록의 누적(전체)을 새 기준일로 다시 센다 — 예상 · 실제 · 이 저장소 누적은 그대로
        r.setdefault("cum_own", r["cum"])
        end = _local(r["at"])
        elsewhere = 0 if own_only else sum(usd(c["model"], c["rec"]) for c in cs
                                           if not c["own"] and t <= _local(c["ts"]) <= end)
        r["cum"] = round(r["cum_own"] + elsewhere, 3)
    led.setdefault("since_log", []).append({"at": _now().isoformat(timespec="minutes"), "from": old,
                                            "to": led["since"], "why": why})
    save(led)
    print(f"기준일: {old[:16]} → {led['since'][:16]} · 누적 ${total(led):.2f}(전체) · 이 저장소 ${total(led, 'days_own'):.2f}")


def cmd_refresh():
    led = load()
    sync(led)
    now = _now()
    t = total(led)
    for k in list(_jobs(led)):
        _end_job(led, k)
        print("진행 중이던 작업을 끝냈다(refresh 로 누적이 0 부터 다시 시작) — 필요하면 job start")
    led["periods"].append({"since": led["since"], "until": now.isoformat(timespec="seconds"), "usd": round(t, 3),
                           "usd_own": round(total(led, "days_own"), 3),
                           "calls": sum(r[1]["calls"] for r in rows(led)), "log": led["log"]})
    led.update(since=now.isoformat(timespec="seconds"), log=[],
               accounts={ACCOUNT: {"own_only": led["accounts"][ACCOUNT].get("own_only", True), "days": {}, "days_own": {}}})
    save(led)
    print(f"refresh: 지난 누적 ${t:.2f} 를 보관하고 0 부터 다시 시작 ({now:%m/%d %H:%M})")


def main(argv=None):
    ap = argparse.ArgumentParser(description="크레딧 사용 기록 (정가 환산 추정)")
    ap.add_argument("cmd", nargs="?", default="report", choices=["report", "est", "note", "since", "job", "refresh", "merge"])
    ap.add_argument("arg", nargs="?", help="est: 예상 호출 수 · note: 작업 이름 · since: 시각(예 \"2026-10-01 00:00\") · job: start | end")
    ap.add_argument("arg2", nargs="?", help="job start: 작업 이름")
    ap.add_argument("--cap", type=float, default=JOB_CAP, help="job start: 이 작업의 상한 $")
    ap.add_argument("--est", type=float, help="note: 작업 전에 낸 예상 $")
    ap.add_argument("--until", help="note: 이 시각(ISO)까지의 호출만 센다")
    ap.add_argument("--why", default="사용자 지시", help="since: 기준일 이력에 남길 사유")
    a = ap.parse_args(argv)
    jsonfmt.utf8_stdout()
    if a.cmd == "est":
        cmd_est(int(a.arg or 10))
    elif a.cmd == "note":
        if not a.arg:
            ap.error("note 에는 작업 이름이 필요하다")
        cmd_note(a.arg, a.est, _local(a.until) if a.until else None)
    elif a.cmd == "since":
        if not a.arg:
            ap.error("since 에는 시각이 필요하다(예: \"2026-10-01 00:00\")")
        cmd_since(a.arg, a.why)
    elif a.cmd == "job":
        return cmd_job(a.arg, a.arg2, a.cap)
    elif a.cmd == "refresh":
        cmd_refresh()
    elif a.cmd == "merge":
        if not a.arg:
            ap.error("merge 에는 다른 원장 경로가 필요하다")
        cmd_merge(a.arg)
    else:
        led = load()
        sync(led)
        print(render(led), end="")
    return 0


if __name__ == "__main__":
    sys.exit(main())
