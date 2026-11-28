#!/usr/bin/env python3
"""korea-mcp(npm)의 data/subway.json(OpenStreetMap 기반, ODbL 1.0)을 읽어
앱에서 쓰는 노선별 역 순서 파일(RailNow/Resources/subway.json)을 만든다.

사용: python3 scripts/build_subway.py <korea-mcp/data/subway.json> RailNow/Resources/subway.json
"""
import collections
import json
import sys

# 서울시 실시간 지하철 위치 API가 받는 노선 이름. 없는 노선은 실시간 미제공.
LIVE = {
    "1": "1호선", "2": "2호선", "3": "3호선", "4": "4호선", "5": "5호선",
    "6": "6호선", "7": "7호선", "8": "8호선", "9": "9호선",
    "arex": "공항철도", "gyeongui": "경의중앙선", "gyeongchun": "경춘선",
    "suin": "수인분당선", "shinbundang": "신분당선", "gyeonggang": "경강선",
    "seohae": "서해선", "gtx-a": "GTX-A", "ui-sinseol": "우이신설선", "sillim": "신림선",
}
SKIP = {"maglev"}
START = {"1": "연천", "3": "대화", "4": "진접", "5": "방화", "7": "장암", "8": "별내",
         "9": "개화", "arex": "서울", "gyeongui": "도라산", "gyeongchun": "청량리",
         "suin": "청량리", "shinbundang": "신사", "gyeonggang": "판교", "seohae": "일산",
         "incheon1": "검단호수공원", "incheon2": "검단오류", "ui-sinseol": "북한산우이",
         "sillim": "샛강", "gimpo": "양촌", "yongin": "기흥", "uijeongbu": "발곡"}
SHORT = {"1": "1", "2": "2", "3": "3", "4": "4", "5": "5", "6": "6", "7": "7", "8": "8", "9": "9",
         "arex": "공항", "gyeongui": "경의", "gyeongchun": "경춘", "suin": "수분", "shinbundang": "신분",
         "gyeonggang": "경강", "seohae": "서해", "gtx-a": "A", "incheon1": "인1", "incheon2": "인2",
         "ui-sinseol": "우이", "sillim": "신림", "gimpo": "김포", "yongin": "용인", "uijeongbu": "의정"}
# 원자료(OSM)에서 건너뛰기 간선 때문에 빠지거나 가지로 떨어진 역을 제자리에 넣는다. (앞역, 넣을 역, 뒷역)
INSERT = {
    "1": [("녹양", "가능", "의정부")],
    "gyeongui": [("풍산", "백마", "곡산"), ("원덕", "용문", "지평")],
    "seohae": [("풍산", "백마", "곡산")],
    "ui-sinseol": [("삼양", "삼양사거리", "솔샘")],
    "gyeonggang": [("판교", "성남", "이매")],
    "gtx-a": [("수서", "성남", "구성")],
}
COLOUR_FIX = {"incheon1": "#759CCE", "9": "#BDB092"}


def dist(g, a, b, limit, skip):
    seen, frontier = {a}, [a]
    for d in range(1, limit + 1):
        nxt = []
        for u in frontier:
            for v in g[u]:
                if (u, v) == skip or (v, u) == skip or v in seen:
                    continue
                if v == b:
                    return d
                seen.add(v)
                nxt.append(v)
        frontier = nxt
    return None


def farthest(g, start, edges):
    """edges 안에서만 움직여 start에서 가장 먼 역까지의 경로."""
    prev, order = {start: None}, [start]
    for u in order:
        for v in sorted(g[u]):
            if frozenset((u, v)) in edges and v not in prev:
                prev[v] = u
                order.append(v)
    end, path = order[-1], []
    while end is not None:
        path.append(end)
        end = prev[end]
    return path[::-1]


def segments(line_id, pairs):
    g = collections.defaultdict(set)
    for a, b in pairs:
        g[a].add(b)
        g[b].add(a)
    # 급행 표시가 빠진 건너뛰기 간선 제거 (다른 길로 5정거장 안에 닿으면 건너뛰기)
    for a, b in sorted(pairs):
        if b in g[a] and dist(g, a, b, 5, (a, b)):
            g[a].discard(b)
            g[b].discard(a)
    edges = {frozenset((a, b)) for a in g for b in g[a]}
    used, out = set(), []
    while edges:
        nodes = sorted({n for e in edges for n in e})
        attach = [n for n in nodes if n in used]
        if attach:
            path = max((farthest(g, n, edges) for n in attach), key=len)
        else:
            first = START.get(line_id) if START.get(line_id) in nodes and not out else None
            if first:
                path = farthest(g, first, edges)
            else:
                path = farthest(g, farthest(g, nodes[0], edges)[-1], edges)
        for a, b in zip(path, path[1:]):
            edges.discard(frozenset((a, b)))
        used.update(path)
        out.append(path)
    return out


LINE2 = ("시청 을지로입구 을지로3가 을지로4가 동대문역사문화공원 신당 상왕십리 왕십리 한양대 뚝섬 성수 건대입구 구의 강변 "
         "잠실나루 잠실 잠실새내 종합운동장 삼성 선릉 역삼 강남 교대 서초 방배 사당 낙성대 서울대입구 봉천 신림 신대방 "
         "구로디지털단지 대림 신도림 문래 영등포구청 당산 합정 홍대입구 신촌 이대 아현 충정로").split()


def main(src, dst):
    d = json.load(open(src, encoding="utf-8"))
    lines = []
    for l in d["lines"]:
        if l["id"] in SKIP:
            continue
        pairs = {tuple(sorted((e["from"], e["to"]))) for e in d["edges"]
                 if e["line"] == l["id"] and not e["express"]}
        loop = False
        if l["id"] == "2":
            names = {n for p in pairs for n in p}
            assert set(LINE2) <= names, set(LINE2) - names
            ring = {tuple(sorted(p)) for p in zip(LINE2, LINE2[1:] + LINE2[:1])}
            assert ring <= pairs, ring - pairs
            segs = [LINE2] + segments("2", pairs - ring)
            loop = True
        elif l["id"] == "6":
            # 응암순환(역촌→불광→독바위→연신내→구산→응암)은 한 방향 운행이라 한 줄로 편다.
            head = "역촌 불광 독바위 연신내 구산".split()
            rest = {p for p in pairs if not (set(p) & set(head))}
            segs = segments("6", rest)
            body = segs[0] if segs[0][0] == "응암" else segs[0][::-1]
            assert body[0] == "응암", body
            segs = [head + body] + segs[1:]
        else:
            segs = segments(l["id"], pairs)
        for a, x, b in INSERT.get(l["id"], []):
            segs = [sg for sg in segs if not (len(sg) == 2 and x in sg)]
            done = False
            for sg in segs:
                for i in range(len(sg) - 1):
                    if {sg[i], sg[i + 1]} == {a, b}:
                        sg.insert(i + 1, x)
                        done = True
                        break
                if done:
                    break
            assert done, (l["id"], a, x, b)
        lines.append({
            "id": l["id"], "name": l["ko"].replace("·", ""), "short": SHORT[l["id"]],
            "color": COLOUR_FIX.get(l["id"], l["colour"]), "live": LIVE.get(l["id"]), "loop": loop,
            "segments": segs,
        })
    out = {
        "attribution": "역·노선 자료 © OpenStreetMap contributors (ODbL 1.0), korea-mcp 가공본 기반",
        "generatedAt": d["generatedAt"],
        "lines": lines,
    }
    json.dump(out, open(dst, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    for l in lines:
        print(l["id"], l["name"], l["color"])
        for s in l["segments"]:
            print("   ", len(s), " ".join(s))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
