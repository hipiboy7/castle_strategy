#!/usr/bin/env bash
# 에뮬레이터 점검 — CI android 잡이 부른다(수동 실행 emulator=true · 태그). castle_M3D scripts/emu_check.sh 를 옮겼다(세로).
#   APK 설치 → 실행 → APP ready 기다림 → 첫 화면 스크린샷 → 자가 해시(SELFHASH)가 시나리오 A 기준값(tests/integration/golden_a.json seed 1)과 같은지(다르면 실패)
#   → '다음 주' 자리 누름(기록만) → logcat 에 우리 앱 충돌 · 스크립트 오류가 없는지 → 화면 끄고 켜기(기록만)
# 입력: build/castle_strategy.apk · tests/unit/rng_vectors.json(시드 1 · 26주 기대 해시)   출력: emu/*.png · emu/logcat*.txt
set -u
PKG=com.hipiboy7.castlestrategy
APK=build/castle_strategy.apk
WANT=$(python3 -c 'import json; print(json.load(open("tests/integration/golden_a.json"))["hash"]["1"])')
mkdir -p emu
adb install -r "$APK" || { echo "설치 실패"; exit 1; }
adb shell settings put secure immersive_mode_confirmations confirmed   # 전체 화면 안내 창이 스크린샷을 가린다
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 0                           # 세로 고정 앱 — 세로로 두고 띄운다
sleep 3
launch() {
  adb logcat -c
  adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > /dev/null
  up=0
  while [ $up -lt 120 ] && ! adb logcat -d | grep -q "APP ready"; do
    sleep 3; up=$((up + 3))
  done
}
launch
if ! adb logcat -d | grep -q "APP ready"; then
  adb logcat -d > emu/logcat_try1.txt
  echo "첫 실행에서 APP ready 가 안 왔다(약 ${up}초) — 한 번 더 띄운다"
  adb shell am force-stop "$PKG"
  launch
fi
echo "APP ready 까지 약 ${up}초"
sleep 6
adb exec-out screencap -p > emu/emu_1_home.png
adb logcat -d > emu/logcat.txt
GOT=$(grep -oE "SELFHASH [0-9a-f]{16}" emu/logcat.txt | tail -1 | cut -d' ' -f2)
echo "자가 해시: 에뮬레이터 ${GOT:-없음} · 기준값(golden_a seed 1) $WANT"
if [ "$GOT" != "$WANT" ]; then
  echo "자가 해시가 다르다 — 판정이 기기마다 다르다(또는 앱이 뜨지 않았다)"
  grep -iE "godot|AndroidRuntime" emu/logcat.txt | tail -40
  exit 1
fi
# '다음 주' 버튼 자리(화면 아래 가운데) 누름 — 기록만(판정에 넣지 않는다)
SIZE=$(adb shell wm size | grep -oE '[0-9]+x[0-9]+' | tail -1)
W=${SIZE%x*}; H=${SIZE#*x}
adb shell input tap $((W / 2)) $((H - H / 12))
sleep 6
adb exec-out screencap -p > emu/emu_2_after_tap.png
adb logcat -d > emu/logcat.txt
grep -oE "TURN [0-9]+" emu/logcat.txt | tail -2 || echo "(누름 기록 없음 — 기록만)"
# 우리 앱의 오류만 본다 — FATAL EXCEPTION 은 바로 다음 줄 'Process: <패키지>' 가 이 앱일 때만
if grep -A1 "FATAL EXCEPTION" emu/logcat.txt | grep -q "Process: $PKG" || grep -E "SCRIPT ERROR|USER SCRIPT ERROR" emu/logcat.txt; then
  grep -A3 "FATAL EXCEPTION" emu/logcat.txt | grep -B1 -A2 "Process: $PKG" || true
  echo "logcat 에 오류가 있다"
  exit 1
fi
pid=$(adb shell pidof "$PKG" | tr -d '\r')
if [ -z "$pid" ]; then
  echo "앱이 살아 있지 않다 (죽었다)"
  grep -iE "godot|AndroidRuntime" emu/logcat.txt | tail -40
  exit 1
fi
echo "OK — 앱이 살아 있음 (pid $pid) · 자가 해시 같음"
# 화면 끄고 켜기 — 기록만
adb logcat -c
adb shell input keyevent KEYCODE_SLEEP; sleep 6
adb shell input keyevent KEYCODE_WAKEUP; sleep 2
adb shell wm dismiss-keyguard; sleep 10
adb exec-out screencap -p > emu/emu_3_resume.png
adb logcat -d > emu/logcat_resume.txt
grep -oE "APP (hide|show)|TURN [0-9]+|FPS_LOG fps=[0-9]+" emu/logcat_resume.txt | tail -8 || true
[ -n "$(adb shell pidof "$PKG" | tr -d '\r')" ] && echo "끄고 켠 뒤 앱 살아 있음" || echo "끄고 켠 뒤 앱이 죽었다(기록만)"
exit 0
