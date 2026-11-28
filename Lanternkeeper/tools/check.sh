#!/bin/bash
# 모든 스크립트의 문법 오류를 찾는다.
cd "$(dirname "$0")/.."
timeout 90 "${GODOT:-/home/user/tools/godot}" --headless --path . --quit-after 30 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error" -A1 | grep -vE "^--$" | head -${1:-20}
