#!/usr/bin/env bash
# 에뮬레이터 점검 — CI android 잡이 부른다(수동 실행 emulator=true · 태그). castle_M3D scripts/emu_check.sh 를 옮겼다(세로).
#   APK 설치 → 실행 → APP ready 기다림 → 첫 화면(지도) 스크린샷 → 자가 해시(SELFHASH)가 시나리오 A 기준값(tests/integration/golden_a.json seed 1)과 같은지
#   → C2 1분 경로 일부(FR-218): 앱이 찍은 버튼 자리(UI <이름> x y)를 눌러 맡기기 → 주 끝내기 → 보고(REPORT n) → 닫기를 5번 → TURN 6(아니면 실패) · C3: 맡기기에 AI 습격이 들어가 4주 안팎에 OUTCOME win 줄이 찍힌다(보기만 — 판정은 TURN 6)
#   → logcat 에 우리 앱 충돌 · 스크립트 오류가 없는지 → 화면 끄고 켜기(기록만)
# 입력: build/castle_strategy.apk · tests/integration/golden_a.json   출력: emu/*.png(지도 · 보고 · 5주 뒤 · 다시 켬) · emu/logcat*.txt
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
adb exec-out screencap -p > emu/emu_1_map.png
adb logcat -d > emu/logcat.txt
GOT=$(grep -oE "SELFHASH [0-9a-f]{16}" emu/logcat.txt | tail -1 | cut -d' ' -f2)
echo "자가 해시: 에뮬레이터 ${GOT:-없음} · 기준값(golden_a seed 1) $WANT"
if [ "$GOT" != "$WANT" ]; then
  echo "자가 해시가 다르다 — 판정이 기기마다 다르다(또는 앱이 뜨지 않았다)"
  grep -iE "godot|AndroidRuntime" emu/logcat.txt | tail -40
  exit 1
fi
# 1분 경로 일부 — 버튼 자리는 앱이 logcat 에 찍은 마지막 'UI <이름> x y'(창 화소 = 화면 화소 · 전체 화면)
at() { adb logcat -d | grep -oE "UI $1 [0-9]+ [0-9]+" | tail -1 | cut -d' ' -f3-; }
tap() {
  local xy; xy=$(at "$1")
  if [ -z "$xy" ]; then echo "버튼 자리 없음: $1"; return 1; fi
  adb shell input tap $xy; sleep "${2:-2}"
}
for week in 1 2 3 4 5; do
  tap auto 2 || break
  tap end 3 || break
  up=0
  while [ $up -lt 30 ] && ! adb logcat -d | grep -q "REPORT $week"; do sleep 2; up=$((up + 2)); done
  if [ "$week" = 1 ]; then adb exec-out screencap -p > emu/emu_2_report.png; fi
  tap close 2 || break
done
adb exec-out screencap -p > emu/emu_3_week6.png
adb logcat -d > emu/logcat.txt
grep -oE "TURN [0-9]+|REPORT [0-9]+|OUTCOME [a-z_]+ [a-z_]+ turn=[0-9]+|PERF [a-z_=0-9 ]+" emu/logcat.txt | tail -16
if ! grep -q "TURN 6" emu/logcat.txt; then
  echo "5주를 두지 못했다(TURN 6 없음) — 누른 자리:"
  grep -oE "UI (auto|end|close) [0-9]+ [0-9]+" emu/logcat.txt | tail -6
  exit 1
fi
echo "1분 경로 일부 OK — 맡기기 · 주 끝내기 · 보고 닫기 × 5 → TURN 6"
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
adb exec-out screencap -p > emu/emu_4_resume.png
adb logcat -d > emu/logcat_resume.txt
grep -oE "APP (hide|show)|TURN [0-9]+|FPS_LOG fps=[0-9]+" emu/logcat_resume.txt | tail -8 || true
[ -n "$(adb shell pidof "$PKG" | tr -d '\r')" ] && echo "끄고 켠 뒤 앱 살아 있음" || echo "끄고 켠 뒤 앱이 죽었다(기록만)"
exit 0
