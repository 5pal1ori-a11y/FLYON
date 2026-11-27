"""TRADEX 전용 3D(클레이) 아이콘 생성기 — SVG 그라데이션으로 입체감을 그려 PNG로 렌더링.
광원: 왼쪽 위. 공통: 바닥 그림자, 하이라이트, 어두운 아래쪽."""
import os, sys, json, colorsys
import cairosvg

OUT = sys.argv[1]

def hx(c):
    c = c.lstrip('#'); return tuple(int(c[i:i+2], 16) / 255 for i in (0, 2, 4))
def tohex(t): return '#' + ''.join(f'{max(0, min(255, round(v * 255))):02x}' for v in t)
def mix(a, b, t):
    A, B = hx(a), hx(b); return tohex(tuple(x + (y - x) * t for x, y in zip(A, B)))
def light(c, t=.45): return mix(c, '#ffffff', t)
def dark(c, t=.45): return mix(c, '#000000', t)

class Icon:
    def __init__(self):
        self.defs, self.body, self.n = [], [], 0
    def _id(self): self.n += 1; return f'i{self.n}'
    def lin(self, stops, x1=0, y1=0, x2=0, y2=1):
        i = self._id()
        s = ''.join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in stops)
        self.defs.append(f'<linearGradient id="{i}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{s}</linearGradient>')
        return f'url(#{i})'
    def rad(self, stops, cx=.35, cy=.3, r=.8):
        i = self._id()
        s = ''.join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in stops)
        self.defs.append(f'<radialGradient id="{i}" cx="{cx}" cy="{cy}" r="{r}">{s}</radialGradient>')
        return f'url(#{i})'
    def clay(self, base, cx=.33, cy=.28):
        """구·덩어리용 재질: 왼쪽 위 밝게, 오른쪽 아래 어둡게"""
        return self.rad([(0, light(base, .55)), (.45, base), (1, dark(base, .45))], cx, cy, .85)
    def face(self, base):
        """면(앞판)용 세로 그라데이션"""
        return self.lin([(0, light(base, .3)), (1, dark(base, .2))])
    def blur(self, sd=2.2):
        i = self._id()
        self.defs.append(f'<filter id="{i}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="{sd}"/></filter>')
        return f'url(#{i})'
    def shadow(self, cx=60, cy=106, rx=32, ry=6, op=.22):
        self.body.insert(0, f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="#000" opacity="{op}" filter="{self.blur(3)}"/>')
    def spec(self, cx, cy, rx, ry, rot=-30, op=.55):
        """반짝이는 하이라이트"""
        self.add(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" transform="rotate({rot} {cx} {cy})" fill="#fff" opacity="{op}" filter="{self.blur(1.2)}"/>')
    def add(self, s): self.body.append(s)
    def svg(self):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120" width="360" height="360">'
                f'<defs>{"".join(self.defs)}</defs>{"".join(self.body)}</svg>')

def box(ic, x, y, w, h, r, base, depth=6):
    """앞판 + 아래쪽 두께로 입체 상자"""
    ic.add(f'<rect x="{x}" y="{y + depth}" width="{w}" height="{h}" rx="{r}" fill="{dark(base, .35)}"/>')
    ic.add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{ic.face(base)}"/>')

BLACK, WHITE, GOLD, RED, BLUE, GREEN, ORANGE, PURPLE, SILVER, BRONZE, TEAL = (
    '#26262b', '#f4f5f7', '#f5b82e', '#e5322d', '#1f62d6', '#2fb36b', '#ff8a2a', '#7a5cff', '#c3c8d2', '#c9824a', '#1fb5a8')

icons = {}

def reg(name):
    def d(f): icons[name] = f; return f
    return d

@reg('trophy')
def _():
    ic = Icon(); ic.shadow(rx=28)
    g = GOLD
    # 손잡이
    for sx in (1, -1):
        cx = 60 + sx * 27
        ic.add(f'<path d="M{60 + sx*18} 34 C{cx + sx*14} 34 {cx + sx*14} 62 {60 + sx*16} 64" fill="none" stroke="{dark(g,.15)}" stroke-width="7" stroke-linecap="round"/>')
    ic.add(f'<path d="M32 26 H88 V44 C88 66 76 76 60 76 C44 76 32 66 32 44 Z" fill="{ic.clay(g, .3, .2)}"/>')
    ic.add(f'<ellipse cx="60" cy="26" rx="28" ry="6" fill="{light(g,.25)}"/>')
    ic.add(f'<ellipse cx="60" cy="26" rx="22" ry="3.6" fill="{dark(g,.35)}"/>')
    ic.add(f'<rect x="54" y="74" width="12" height="12" fill="{ic.face(dark(g,.1))}"/>')
    box(ic, 40, 86, 40, 12, 4, BLACK, 5)
    ic.add(f'<rect x="50" y="89" width="20" height="5" rx="2" fill="{GOLD}"/>')
    ic.spec(45, 40, 5, 11)
    return ic

@reg('gift')
def _():
    ic = Icon(); ic.shadow()
    box(ic, 24, 50, 72, 46, 8, BLACK, 7)
    box(ic, 20, 38, 80, 18, 6, mix(BLACK, '#3a3a40', .5), 5)
    ic.add(f'<rect x="54" y="38" width="12" height="65" fill="{ic.face(RED)}"/>')
    for sx in (-1, 1):
        ic.add(f'<path d="M60 38 C{60+sx*6} 22 {60+sx*28} 18 {60+sx*26} 32 C{60+sx*24} 40 {60+sx*8} 40 60 38Z" fill="{ic.clay(RED, .4, .3)}"/>')
    ic.add(f'<circle cx="60" cy="37" r="6" fill="{ic.clay(RED)}"/>')
    ic.spec(32, 44, 4, 2, 0, .35)
    return ic

@reg('calendar')
def _():
    ic = Icon(); ic.shadow()
    box(ic, 22, 26, 76, 70, 12, WHITE, 7)
    ic.add(f'<path d="M22 38 a12 12 0 0 1 12 -12 H86 a12 12 0 0 1 12 12 V44 H22Z" fill="{ic.face(RED)}"/>')
    for x in (40, 80):
        ic.add(f'<rect x="{x-3}" y="18" width="6" height="16" rx="3" fill="{ic.face(BLACK)}"/>')
    for r in range(3):
        for c in range(4):
            ic.add(f'<rect x="{32 + c*15}" y="{52 + r*13}" width="9" height="8" rx="2.5" fill="{"#d7dbe2" if (r, c) != (1, 2) else BLACK}"/>')
    ic.spec(36, 33, 6, 2, 0, .45)
    return ic

@reg('fire')
def _():
    ic = Icon(); ic.shadow(rx=24)
    ic.add(f'<path d="M60 14 C68 32 92 42 88 70 C85 92 70 100 60 100 C44 100 30 90 32 70 C33 56 42 50 44 40 C50 50 52 54 56 56 C54 40 56 26 60 14Z" fill="{ic.lin([(0,"#ffcf3d"),(.55,ORANGE),(1,RED)])}"/>')
    ic.add(f'<path d="M60 50 C66 62 76 68 74 82 C72 94 64 98 60 98 C52 98 44 92 46 80 C47 72 54 68 56 60 C58 66 60 66 60 50Z" fill="{ic.lin([(0,"#fff6b0"),(1,"#ffc23a")])}"/>')
    ic.spec(46, 62, 3, 8, -20, .4)
    return ic

@reg('target')
def _():
    ic = Icon(); ic.shadow(rx=30)
    for r, c in ((40, WHITE), (31, RED), (22, WHITE), (13, RED)):
        ic.add(f'<circle cx="58" cy="62" r="{r}" fill="{ic.clay(c, .35, .3)}"/>')
    ic.add(f'<line x1="58" y1="62" x2="96" y2="24" stroke="{BLACK}" stroke-width="5" stroke-linecap="round"/>')
    ic.add(f'<path d="M92 14 L104 26 L96 30 L88 22Z" fill="{ic.face(GOLD)}"/>')
    ic.add(f'<circle cx="58" cy="62" r="4" fill="{BLACK}"/>')
    ic.spec(40, 42, 6, 3)
    return ic

@reg('cart')
def _():
    ic = Icon(); ic.shadow(rx=34)
    ic.add(f'<path d="M14 26 H26 L34 72 H88" fill="none" stroke="{dark(BLACK,.1)}" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>')
    ic.add(f'<path d="M30 36 H98 L90 64 H36Z" fill="{ic.face(BLACK)}"/>')
    for i in range(4):
        ic.add(f'<rect x="{42 + i*12}" y="42" width="6" height="16" rx="3" fill="{light(BLACK,.25)}"/>')
    for x in (42, 82):
        ic.add(f'<circle cx="{x}" cy="86" r="8" fill="{ic.clay(WHITE)}"/><circle cx="{x}" cy="86" r="3" fill="{BLACK}"/>')
    ic.spec(44, 40, 8, 2, 0, .3)
    return ic

def arrow_tile(direction, color):
    ic = Icon(); ic.shadow()
    box(ic, 20, 20, 80, 76, 20, BLACK, 7)
    if direction == 'up':
        pts = "30,78 48,58 62,66 88,36"; head = "M78 34 L92 32 L90 46Z"
    else:
        pts = "30,40 48,58 62,50 88,78"; head = "M78 80 L92 82 L90 68Z"
    ic.add(f'<polyline points="{pts}" fill="none" stroke="{color}" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>')
    ic.add(f'<path d="{head}" fill="{color}" stroke="{color}" stroke-width="5" stroke-linejoin="round"/>')
    ic.spec(34, 28, 10, 3, 0, .25)
    return ic

reg('up')(lambda: arrow_tile('up', RED))
reg('down')(lambda: arrow_tile('down', BLUE))

@reg('barchart')
def _():
    ic = Icon(); ic.shadow(rx=36)
    for x, h, c in ((24, 34, BLUE), (48, 56, BLACK), (72, 74, RED)):
        y = 96 - h
        ic.add(f'<path d="M{x+18} {y} l6 -5 v{h} l-6 5z" fill="{dark(c,.4)}"/>')
        ic.add(f'<path d="M{x} {y} l6 -5 h18 l-6 5z" fill="{light(c,.35)}"/>')
        ic.add(f'<rect x="{x}" y="{y}" width="18" height="{h}" fill="{ic.face(c)}"/>')
    return ic

@reg('chart')
def _():
    ic = Icon(); ic.shadow(rx=36)
    box(ic, 16, 18, 88, 80, 18, WHITE, 7)
    for x, o, c, hi, lo, col in ((32, 66, 52, 46, 74, RED), (48, 54, 64, 48, 72, BLUE), (64, 62, 42, 36, 68, RED), (80, 44, 34, 28, 52, RED)):
        ic.add(f'<line x1="{x}" y1="{hi}" x2="{x}" y2="{lo}" stroke="{col}" stroke-width="2.5"/>')
        ic.add(f'<rect x="{x-5}" y="{min(o,c)}" width="10" height="{abs(o-c)}" rx="2" fill="{ic.face(col)}"/>')
    ic.spec(30, 26, 10, 2.5, 0, .5)
    return ic

@reg('grad')
def _():
    ic = Icon(); ic.shadow(rx=34)
    ic.add(f'<path d="M36 52 V74 C36 84 84 84 84 74 V52Z" fill="{ic.face(BLACK)}"/>')
    ic.add(f'<path d="M60 28 L104 46 L60 64 L16 46Z" fill="{ic.lin([(0,light(BLACK,.35)),(1,BLACK)])}"/>')
    ic.add(f'<path d="M60 46 L96 52 V78" fill="none" stroke="{GOLD}" stroke-width="3"/>')
    ic.add(f'<path d="M92 78 h8 l-2 14 h-4z" fill="{ic.face(GOLD)}"/>')
    ic.add(f'<circle cx="60" cy="46" r="4" fill="{GOLD}"/>')
    ic.spec(44, 40, 10, 2.5, -20, .35)
    return ic

@reg('alarm')
def _():
    ic = Icon(); ic.shadow(rx=30)
    for sx in (-1, 1):
        ic.add(f'<circle cx="{60+sx*26}" cy="30" r="12" fill="{ic.clay(BLACK)}"/>')
        ic.add(f'<line x1="{60+sx*24}" y1="90" x2="{60+sx*32}" y2="100" stroke="{BLACK}" stroke-width="6" stroke-linecap="round"/>')
    ic.add(f'<circle cx="60" cy="62" r="34" fill="{ic.clay(WHITE, .3, .25)}"/>')
    ic.add(f'<circle cx="60" cy="62" r="34" fill="none" stroke="{BLACK}" stroke-width="7"/>')
    ic.add(f'<path d="M60 62 V42 M60 62 L74 70" stroke="{BLACK}" stroke-width="5" stroke-linecap="round"/>')
    ic.add(f'<circle cx="60" cy="62" r="4" fill="{RED}"/>')
    ic.spec(44, 46, 8, 4)
    return ic

def medal(name, base, label):
    ic = Icon(); ic.shadow(rx=26)
    ic.add(f'<path d="M38 12 H54 L66 48 H50Z" fill="{ic.face(RED)}"/>')
    ic.add(f'<path d="M82 12 H66 L54 48 H70Z" fill="{ic.face(BLUE)}"/>')
    ic.add(f'<circle cx="60" cy="72" r="29" fill="{ic.clay(base, .3, .25)}"/>')
    ic.add(f'<circle cx="60" cy="72" r="21" fill="none" stroke="{dark(base,.25)}" stroke-width="3"/>')
    if label == '★':
        ic.add(f'<path d="M60 56 L65 67 L77 68 L68 76 L71 88 L60 82 L49 88 L52 76 L43 68 L55 67Z" fill="{dark(base,.45)}"/>')
    else:
        ic.add(f'<text x="60" y="83" text-anchor="middle" font-family="Helvetica, Arial" font-weight="900" font-size="30" fill="{dark(base,.45)}">{label}</text>')
    ic.spec(47, 60, 7, 4)
    return ic

reg('gold')(lambda: medal('gold', GOLD, '1'))
reg('silver')(lambda: medal('silver', SILVER, '2'))
reg('bronze')(lambda: medal('bronze', BRONZE, '3'))
reg('medal')(lambda: medal('medal', GOLD, '★'))

@reg('diamond')
def _():
    ic = Icon(); ic.shadow(rx=30)
    c = '#5fc8ff'
    ic.add(f'<path d="M30 40 L46 22 H74 L90 40 L60 96Z" fill="{ic.lin([(0,light(c,.5)),(1,dark(c,.25))])}"/>')
    ic.add(f'<path d="M30 40 H90 L60 96Z" fill="{dark(c,.1)}" opacity=".55"/>')
    ic.add(f'<path d="M46 22 L54 40 L60 22 L66 40 L74 22" fill="none" stroke="#fff" stroke-width="1.5" opacity=".7"/>')
    ic.add(f'<path d="M30 40 H90 M54 40 L60 96 L66 40" fill="none" stroke="#fff" stroke-width="1.5" opacity=".6"/>')
    ic.spec(44, 32, 6, 3, -30, .8)
    return ic

@reg('star')
def _():
    ic = Icon(); ic.shadow(rx=28)
    ic.add(f'<path d="M60 14 L72 44 L104 46 L79 66 L88 98 L60 80 L32 98 L41 66 L16 46 L48 44Z" fill="{ic.clay(GOLD, .4, .3)}" stroke="{dark(GOLD,.1)}" stroke-width="2" stroke-linejoin="round"/>')
    ic.spec(52, 40, 4, 8, -10, .5)
    return ic

@reg('seedling')
def _():
    ic = Icon(); ic.shadow(rx=26)
    ic.add(f'<path d="M60 70 C60 56 60 48 60 40" stroke="{dark(GREEN,.2)}" stroke-width="5" fill="none" stroke-linecap="round"/>')
    ic.add(f'<path d="M60 48 C46 50 30 42 28 24 C46 22 58 32 60 48Z" fill="{ic.clay(GREEN,.3,.3)}"/>')
    ic.add(f'<path d="M60 42 C70 30 90 26 96 34 C90 50 72 52 60 42Z" fill="{ic.clay(GREEN,.4,.3)}"/>')
    ic.add(f'<path d="M36 66 H84 L78 98 H42Z" fill="{ic.face(BLACK)}"/>')
    ic.add(f'<rect x="32" y="62" width="56" height="10" rx="5" fill="{ic.face(light(BLACK,.15))}"/>')
    ic.spec(38, 32, 5, 2.5, 30, .45)
    return ic

@reg('magnifier')
def _():
    ic = Icon(); ic.shadow(rx=30)
    ic.add(f'<line x1="72" y1="72" x2="98" y2="98" stroke="{BLACK}" stroke-width="13" stroke-linecap="round"/>')
    ic.add(f'<circle cx="52" cy="52" r="32" fill="{ic.clay(BLACK)}"/>')
    ic.add(f'<circle cx="52" cy="52" r="23" fill="{ic.rad([(0,"#ffffff"),(1,"#b9d7ff")], .35,.3,.9)}"/>')
    ic.spec(42, 42, 8, 4, -35, .9)
    return ic

@reg('map')
def _():
    ic = Icon(); ic.shadow(rx=36)
    xs = [18, 46, 74, 102]
    cols = [WHITE, '#dfe3ea', WHITE]
    for i in range(3):
        y1, y2 = (26, 34) if i % 2 == 0 else (34, 26)
        ic.add(f'<path d="M{xs[i]} {y1} L{xs[i+1]} {y2} L{xs[i+1]} {y2+62} L{xs[i]} {y1+62}Z" fill="{ic.face(cols[i])}"/>')
    ic.add(f'<path d="M30 72 C44 60 54 80 66 62 C76 48 86 56 90 48" fill="none" stroke="{RED}" stroke-width="3.5" stroke-dasharray="5 4" stroke-linecap="round"/>')
    ic.add(f'<path d="M90 30 C98 30 100 40 90 52 C80 40 82 30 90 30Z" fill="{ic.clay(RED)}"/><circle cx="90" cy="38" r="3" fill="#fff"/>')
    return ic

@reg('brain')   # 전문가: 번개
def _():
    ic = Icon(); ic.shadow(rx=24)
    ic.add(f'<path d="M66 10 L30 66 H56 L48 108 L90 46 H64 Z" fill="{ic.lin([(0,"#ffe066"),(1,ORANGE)])}" stroke="{dark(ORANGE,.15)}" stroke-width="2.5" stroke-linejoin="round"/>')
    ic.spec(52, 42, 3, 10, 30, .55)
    return ic

@reg('crown')
def _():
    ic = Icon(); ic.shadow(rx=34)
    ic.add(f'<path d="M18 40 L38 62 L60 26 L82 62 L102 40 L94 86 H26Z" fill="{ic.clay(GOLD,.35,.3)}" stroke="{dark(GOLD,.15)}" stroke-width="2" stroke-linejoin="round"/>')
    box(ic, 26, 82, 68, 12, 4, dark(GOLD, .1), 4)
    for x, y, c in ((18, 38, RED), (60, 24, BLUE), (102, 38, RED)):
        ic.add(f'<circle cx="{x}" cy="{y}" r="7" fill="{ic.clay(c)}"/>')
    ic.add(f'<circle cx="60" cy="66" r="7" fill="{ic.clay(BLACK)}"/>')
    ic.spec(40, 58, 4, 8, 20, .45)
    return ic

@reg('party')
def _():
    ic = Icon(); ic.shadow(cx=44, rx=26)
    ic.add(f'<path d="M20 102 L44 34 L88 78Z" fill="{ic.face(BLACK)}"/>')
    ic.add(f'<path d="M30 74 L60 88 M36 56 L72 74" stroke="{GOLD}" stroke-width="5" stroke-linecap="round"/>')
    for x, y, c, r in ((70, 24, RED, 5), (92, 40, BLUE, 4), (84, 16, GOLD, 4), (100, 62, GREEN, 4), (58, 14, PURPLE, 3.5)):
        ic.add(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{ic.clay(c)}"/>')
    ic.add(f'<path d="M66 44 C74 36 76 28 84 26" stroke="{RED}" stroke-width="3" fill="none" stroke-linecap="round"/>')
    return ic

@reg('moneybag')
def _():
    ic = Icon(); ic.shadow(rx=32)
    ic.add(f'<path d="M48 30 C40 24 44 14 52 16 C56 10 64 10 68 16 C76 14 80 24 72 30Z" fill="{ic.clay(dark(GOLD,.05))}"/>')
    ic.add(f'<path d="M48 32 C22 46 18 98 60 100 C102 98 98 46 72 32Z" fill="{ic.clay(GOLD,.32,.3)}"/>')
    ic.add(f'<rect x="44" y="28" width="32" height="7" rx="3.5" fill="{BLACK}"/>')
    ic.add(f'<text x="60" y="84" text-anchor="middle" font-family="Helvetica, Arial" font-weight="900" font-size="34" fill="{dark(GOLD,.5)}">₩</text>')
    ic.spec(40, 56, 6, 12, 15, .4)
    return ic

@reg('coin')
def _():
    ic = Icon(); ic.shadow(rx=30)
    ic.add(f'<ellipse cx="60" cy="64" rx="38" ry="38" fill="{dark(BLACK,.2)}"/>')
    ic.add(f'<circle cx="60" cy="58" r="38" fill="{ic.clay(BLACK,.3,.25)}"/>')
    ic.add(f'<circle cx="60" cy="58" r="30" fill="none" stroke="{light(BLACK,.35)}" stroke-width="2"/>')
    ic.add(f'<text x="60" y="72" text-anchor="middle" font-family="Helvetica, Arial" font-weight="900" font-size="38" fill="#fff">T</text>')
    ic.spec(44, 40, 8, 4)
    return ic

@reg('briefcase')
def _():
    ic = Icon(); ic.shadow(rx=36)
    ic.add(f'<rect x="44" y="20" width="32" height="18" rx="6" fill="none" stroke="{BLACK}" stroke-width="6"/>')
    box(ic, 16, 34, 88, 60, 12, BLACK, 7)
    ic.add(f'<rect x="16" y="56" width="88" height="5" fill="{light(BLACK,.2)}"/>')
    ic.add(f'<rect x="52" y="52" width="16" height="12" rx="3" fill="{ic.face(GOLD)}"/>')
    ic.spec(30, 42, 10, 2.5, 0, .3)
    return ic

@reg('sparkles')
def _():
    ic = Icon(); ic.shadow(rx=28)
    def star4(cx, cy, s, c):
        ic.add(f'<path d="M{cx} {cy-s} C{cx+s*.18} {cy-s*.18} {cx+s*.18} {cy-s*.18} {cx+s} {cy} C{cx+s*.18} {cy+s*.18} {cx+s*.18} {cy+s*.18} {cx} {cy+s} C{cx-s*.18} {cy+s*.18} {cx-s*.18} {cy+s*.18} {cx-s} {cy} C{cx-s*.18} {cy-s*.18} {cx-s*.18} {cy-s*.18} {cx} {cy-s}Z" fill="{ic.clay(c,.4,.35)}"/>')
    star4(52, 62, 34, GOLD); star4(92, 28, 14, PURPLE); star4(90, 88, 10, BLUE)
    ic.spec(46, 52, 3, 7, -20, .5)
    return ic

@reg('repeat')
def _():
    ic = Icon(); ic.shadow()
    box(ic, 20, 20, 80, 76, 20, BLACK, 7)
    ic.add(f'<path d="M38 52 A22 22 0 0 1 78 44" fill="none" stroke="#fff" stroke-width="7" stroke-linecap="round"/>')
    ic.add(f'<path d="M82 34 L82 50 L66 48Z" fill="#fff"/>')
    ic.add(f'<path d="M82 64 A22 22 0 0 1 42 72" fill="none" stroke="{GOLD}" stroke-width="7" stroke-linecap="round"/>')
    ic.add(f'<path d="M38 82 L38 66 L54 68Z" fill="{GOLD}"/>')
    ic.spec(34, 28, 10, 3, 0, .25)
    return ic

@reg('receipt')
def _():
    ic = Icon(); ic.shadow(rx=28)
    zig = ' '.join(f'L{34 + i*6.5} {100 if i % 2 == 0 else 94}' for i in range(9))
    ic.add(f'<path d="M30 14 H90 V100 {zig.replace("L", "L", 1)} L30 100Z" fill="{dark(WHITE,.2)}" transform="translate(0 4)"/>')
    ic.add(f'<path d="M30 14 H90 V96 L84 102 L78 96 L72 102 L66 96 L60 102 L54 96 L48 102 L42 96 L36 102 L30 96Z" fill="{ic.face(WHITE)}"/>')
    for i, w in enumerate((40, 30, 36, 24)):
        ic.add(f'<rect x="40" y="{30 + i*12}" width="{w}" height="5" rx="2.5" fill="#c9ced8"/>')
    ic.add(f'<rect x="40" y="80" width="40" height="6" rx="3" fill="{BLACK}"/>')
    return ic

@reg('rocket')
def _():
    ic = Icon(); ic.shadow(cx=56, rx=26)
    ic.add(f'<g transform="rotate(40 60 60)">'
           f'<path d="M48 84 L36 100 L48 96Z M72 84 L84 100 L72 96Z" fill="{RED}"/>'
           f'<path d="M60 10 C80 26 80 70 72 90 H48 C40 70 40 26 60 10Z" fill="{ic.clay(WHITE,.3,.3)}"/>'
           f'<path d="M60 10 C68 16 72 24 74 32 H46 C48 24 52 16 60 10Z" fill="{ic.face(BLACK)}"/>'
           f'<circle cx="60" cy="52" r="9" fill="{ic.clay(BLUE)}" stroke="{BLACK}" stroke-width="3"/>'
           f'<path d="M50 92 C52 104 56 110 60 114 C64 110 68 104 70 92Z" fill="{ic.lin([(0,"#ffd84d"),(1,ORANGE)])}"/>'
           f'</g>')
    return ic

@reg('check')
def _():
    ic = Icon(); ic.shadow()
    box(ic, 20, 20, 80, 76, 20, GREEN, 7)
    ic.add(f'<path d="M38 58 L54 74 L84 42" fill="none" stroke="#fff" stroke-width="10" stroke-linecap="round" stroke-linejoin="round"/>')
    return ic

@reg('lock')
def _():
    ic = Icon(); ic.shadow(rx=30)
    ic.add(f'<path d="M40 52 V40 A20 20 0 0 1 80 40 V52" fill="none" stroke="{SILVER}" stroke-width="9"/>')
    box(ic, 28, 50, 64, 46, 12, BLACK, 6)
    ic.add(f'<circle cx="60" cy="70" r="6" fill="{GOLD}"/><rect x="57" y="72" width="6" height="12" rx="3" fill="{GOLD}"/>')
    return ic

root = os.path.join(OUT, 'Emoji3D')
os.makedirs(root, exist_ok=True)
json.dump({"info": {"author": "xcode", "version": 1}}, open(os.path.join(root, 'Contents.json'), 'w'))
for name, f in icons.items():
    d = os.path.join(root, f'e3d-{name}.imageset'); os.makedirs(d, exist_ok=True)
    for old in os.listdir(d):
        if old.endswith('.png'): os.remove(os.path.join(d, old))
    cairosvg.svg2png(bytestring=f().svg().encode(), write_to=os.path.join(d, f'{name}.png'), output_width=180, output_height=180)
    json.dump({"images": [{"filename": f"{name}.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}},
              open(os.path.join(d, 'Contents.json'), 'w'))
print(len(icons), 'icons')
