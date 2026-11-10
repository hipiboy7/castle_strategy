#!/usr/bin/env bash
# 작업 서버(리눅스, root 없음)에서 가상 화면(Xvfb + Mesa llvmpipe)으로 화면 한 장을 찍는다 — castle_M3D tools/xvfb_shot.sh 를 옮겼다(세로).
#
#   tools/xvfb_shot.sh 출력.png [프레임] [추가 게임 인자..]
#   SHOT_W=1812 SHOT_H=2176 tools/xvfb_shot.sh .work/wide.png 30      # 폴드 안쪽(넓은 화면)
#
# 준비(한 번): Xvfb · Mesa 를 사용자 폴더에 푼다(sudo 없음 — XVFB_ROOT, 기본 ~/.local-opt/xvfb/root: usr/bin/Xvfb ·
#   usr/lib64(mesa · libGL · X 라이브러리) · usr/share/X11/xkb). Xvfb 는 /usr/bin/xkbcomp 를 고정 경로로 부르므로 사용자
#   이름공간(unshare -rm)에서 /usr/bin 위에 xkbcomp · sh 만 든 폴더를 덮어 띄운다. 게임은 바깥에서 그 화면(DISPLAY)에 붙는다.
# 게임 쪽: src/main.gd --shot PATH --shot-frame N (그 프레임을 PNG 로 쓰고 끝낸다)
set -u
OUT=${1:?출력.png}
FRAME=${2:-30}
shift $(( $# < 2 ? $# : 2 ))
HERE=$(cd "$(dirname "$0")/.." && pwd)
R=${XVFB_ROOT:-$HOME/.local-opt/xvfb/root}
OV=$(dirname "$R")/bin_overlay
GODOT=${GODOT:-$(python3 -B "$HERE/scripts/get_godot.py")}
W=${SHOT_W:-1080}; H=${SHOT_H:-2340}
DISP=:$(( 70 + RANDOM % 20 ))
mkdir -p "$(dirname "$OUT")" "$OV"
[ -x "$OV/xkbcomp" ] || cp "$R/usr/bin/xkbcomp" "$OV/"
[ -x "$OV/sh" ] || cp /usr/bin/bash "$OV/sh"
export LD_LIBRARY_PATH="$R/usr/lib64"
unshare -rm sh -c "mount --bind '$OV' /usr/bin && exec '$R/usr/bin/Xvfb' $DISP -screen 0 ${W}x${H}x24 -xkbdir '$R/usr/share/X11/xkb' -nolisten tcp" >/dev/null 2>&1 &
XPID=$!
trap 'kill $XPID 2>/dev/null' EXIT
for _ in $(seq 50); do [ -S /tmp/.X11-unix/X${DISP#:} ] && break; sleep 0.1; done
DISPLAY=$DISP LIBGL_DRIVERS_PATH="$R/usr/lib64/dri" __EGL_VENDOR_LIBRARY_DIRS="$R/usr/share/glvnd/egl_vendor.d" \
  timeout 300 "$GODOT" --path "$HERE" --rendering-driver opengl3 --audio-driver Dummy --resolution ${W}x${H} \
  -- --shot "$OUT" --shot-frame "$FRAME" "$@" 2>&1 | grep -vE "^\s*$|V-Sync|set_use_vsync"
ls -la "$OUT"
