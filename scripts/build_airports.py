#!/usr/bin/env python3
"""OurAirports(공개 도메인) CSV에서 정기편이 있는 IATA 공항만 뽑아 앱 번들용 JSON을 만든다.

  python3 scripts/build_airports.py <airports.csv> FLYON/Resources/airports.json

출처: https://github.com/davidmegginson/ourairports-data (Public Domain)
출력: [[iata, 공항명(영문), 도시(영문), 국가코드], ...]
"""
import csv
import json
import sys

src, dst = sys.argv[1], sys.argv[2]
out, seen = [], set()
with open(src, newline="", encoding="utf-8") as f:
    for r in csv.DictReader(f):
        iata = (r["iata_code"] or "").strip().upper()
        if len(iata) != 3 or iata in seen:
            continue
        if r["type"] not in ("large_airport", "medium_airport", "small_airport"):
            continue
        if r["scheduled_service"] != "yes":
            continue
        city = (r["municipality"] or r["name"]).strip()
        out.append([iata, r["name"].strip(), city, r["iso_country"].strip()])
        seen.add(iata)
out.sort(key=lambda x: x[0])
with open(dst, "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
print(len(out), "airports")
