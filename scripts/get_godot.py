"""고정 버전 Godot 받기 (작업 서버용 — 리눅스 x86_64 · Windows). castle_M3D scripts/get_godot.py 를 옮겼다.

입력: 없음 — 버전은 아래 VERSION 한 곳이다. CI 는 .github/workflows/android.yml 의 GODOT_VERSION 과 같게 둔다.
출력: .tools/godot/<VERSION>/Godot_v<VERSION>_linux.x86_64(리눅스) · Godot_v<VERSION>_win64_console.exe(Windows)
멱등: 이미 있으면 다시 받지 않는다. 내보내기 템플릿은 받지 않는다 — APK 는 CI 가 만든다(CLAUDE.md 0절).
요구: docs/C1_요구사항정의서_시뮬코어.md FR-101

    python3 -B scripts/get_godot.py        # 받고 실행 파일 경로를 찍는다(Windows: py -3.12)
"""
import os
import sys
import urllib.request
import zipfile

VERSION = "4.7.2-stable"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, ".tools", "godot", VERSION)
if sys.platform.startswith("win"):
    ZIP_NAME = f"Godot_v{VERSION}_win64.exe.zip"
    EXE = os.path.join(DEST, f"Godot_v{VERSION}_win64_console.exe")
else:
    ZIP_NAME = f"Godot_v{VERSION}_linux.x86_64.zip"
    EXE = os.path.join(DEST, f"Godot_v{VERSION}_linux.x86_64")
URL = f"https://github.com/godotengine/godot/releases/download/{VERSION}/{ZIP_NAME}"


def main():
    if os.path.exists(EXE):
        print(EXE)
        return 0
    os.makedirs(DEST, exist_ok=True)
    zpath = os.path.join(DEST, ZIP_NAME)
    if not os.path.exists(zpath):
        print(f"받는 중: {URL}", file=sys.stderr)
        tmp = zpath + ".part"
        urllib.request.urlretrieve(URL, tmp)      # 프록시는 환경 변수(HTTPS_PROXY)를 따른다
        os.replace(tmp, zpath)
    with zipfile.ZipFile(zpath) as z:
        z.extractall(DEST)
    os.remove(zpath)
    if os.path.exists(EXE) and not sys.platform.startswith("win"):
        os.chmod(EXE, 0o755)
    if not os.path.exists(EXE):
        print(f"실행 파일이 없다: {EXE}", file=sys.stderr)
        return 1
    print(EXE)
    return 0


if __name__ == "__main__":
    sys.exit(main())
