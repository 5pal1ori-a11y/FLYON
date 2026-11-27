#!/bin/bash
# 사용법: tools/shot.sh <demo> <출력.png> [지연초]
cd "$(dirname "$0")/.."
export SHOT_DELAY=${3:-2.0}
timeout 120 xvfb-run -a -s "-screen 0 720x1280x24" "${GODOT:-/home/user/tools/godot}" --path . --rendering-driver opengl3 --resolution 720x1280 -- --demo="$1" --shot="$2" 2>&1 \
  | grep -E "SCRIPT ERROR|^ERROR" -A2 | grep -vE "resources still in use|audio_driver_alsa|init_output_device|ERR_CANT_OPEN|resource.cpp" | head -30
