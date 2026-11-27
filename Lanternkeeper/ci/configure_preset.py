#!/usr/bin/env python3
"""CI에서 export_presets.cfg의 iOS 서명·버전 값을 채운다. 비밀값은 저장소에 남지 않는다.

사용 (Lanternkeeper 폴더에서): python3 ci/configure_preset.py --team TEAMID --bundle com.x.y --profile-uuid UUID --build 42 [--version 1.0.0] [--project-only]
"""
import argparse
import re
import sys

ap = argparse.ArgumentParser()
ap.add_argument("--team", required=True)
ap.add_argument("--bundle", required=True)
ap.add_argument("--profile-uuid", required=True)
ap.add_argument("--build", required=True)
ap.add_argument("--version", default="")
ap.add_argument("--file", default="export_presets.cfg")
ap.add_argument("--project-only", action="store_true", help="ipa 대신 Xcode 프로젝트만 만든다 (서명·업로드는 xcodebuild가 한다)")
a = ap.parse_args()

if not re.fullmatch(r"[A-Z0-9]{10}", a.team):
    sys.exit("APPLE_TEAM_ID는 10자리 영문 대문자·숫자여야 합니다.")
if not re.fullmatch(r"[A-Za-z0-9.\-]+", a.bundle) or "." not in a.bundle:
    sys.exit("IOS_BUNDLE_ID 형식이 올바르지 않습니다 (예: com.yourname.lanternkeeper).")
if not a.build.isdigit():
    sys.exit("빌드 번호는 숫자여야 합니다.")

version = a.version
if not version:
    with open("project.godot", encoding="utf-8") as f:
        m = re.search(r'^config/version="([^"]+)"', f.read(), re.M)
        version = m.group(1) if m else "1.0.0"

with open(a.file, encoding="utf-8") as f:
    s = f.read()


def put(key, value):
    global s
    pat = re.compile(r"^" + re.escape(key) + r"=.*$", re.M)
    line = f'{key}="{value}"'
    if not pat.search(s):
        sys.exit(f"export_presets.cfg에 {key} 항목이 없습니다.")
    s = pat.sub(lambda _m: line, s, count=1)


put("application/app_store_team_id", a.team)
put("application/bundle_identifier", a.bundle)
put("application/provisioning_profile_uuid_release", a.profile_uuid)
put("application/short_version", version)
put("application/version", a.build)
if a.project_only:
    s = re.sub(r"^application/export_project_only=.*$", "application/export_project_only=true", s, count=1, flags=re.M)

with open(a.file, "w", encoding="utf-8") as f:
    f.write(s)
print(f"iOS 프리셋 설정 완료: {a.bundle} v{version} ({a.build})")
