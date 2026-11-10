"""castle_common JSON 서식 — 사람이 읽기 좋게: 한 줄(들여쓰기 포함 110자)에 들어가는 묶음은 한 줄로, 아니면 펼친다.

data/ · cases/ 를 쓰는 도구(gen_cases.py, 처음 옮기기)가 같이 쓴다. 같은 값이면 같은 글자(멱등).
data/ 를 손으로 고친 뒤 `py -3.12 tools/jsonfmt.py` 로 서식을 맞출 수 있다(값은 안 바뀐다).
"""
import glob
import json
import os
import sys

WIDTH = 110
NL = "\n"


def _one(v):
    return json.dumps(v, ensure_ascii=False)


def _fmt(v, ind, lead=0):
    """ind: 이 줄의 들여쓰기, lead: 같은 줄에서 값 앞에 오는 글자 수(키 등)."""
    one = _one(v)
    if not isinstance(v, (dict, list)) or not v or ind + lead + len(one) <= WIDTH:
        return one
    pad = " " * (ind + 2)
    if isinstance(v, dict):
        items = [f"{pad}{_one(k)}: {_fmt(x, ind + 2, len(_one(k)) + 2)}" for k, x in v.items()]
        return "{" + NL + ("," + NL).join(items) + NL + " " * ind + "}"
    items = [pad + _fmt(x, ind + 2) for x in v]
    return "[" + NL + ("," + NL).join(items) + NL + " " * ind + "]"


def dumps(v):
    return _fmt(v, 0) + NL


def write(path, v):
    with open(path, "w", encoding="utf-8", newline=NL) as f:
        f.write(dumps(v))


def utf8_stdout():
    """콘솔이 cp1252 여도 한글 출력이 안 깨지게 (castle_M 트러블슈팅 T-8 과 같은 문제)."""
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def read(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    paths = sorted(glob.glob(os.path.join(root, "data", "*.json")) + glob.glob(os.path.join(root, "canon", "*.json")) + glob.glob(os.path.join(root, "canon", "episodes", "*.json")) + glob.glob(os.path.join(root, "packs", "*", "*.json"))) + glob.glob(os.path.join(root, "games.json"))
    for p in paths:
        write(p, read(p))
