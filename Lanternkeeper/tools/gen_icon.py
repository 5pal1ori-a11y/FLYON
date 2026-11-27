#!/usr/bin/env python3
"""앱 아이콘 생성: 어둠 속 등불 하나와 길게 뻗은 그림자.  실행: python3 tools/gen_icon.py"""
import os
import math
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icons")
S = 1024


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def make(size=S):
    img = Image.new("RGB", (S, S), (8, 8, 14))
    px = img.load()
    cx, cy = S * 0.5, S * 0.47
    for y in range(S):
        for x in range(S):
            d = math.hypot(x - cx, y - cy) / (S * 0.75)
            base = lerp((52, 30, 18), (7, 7, 13), min(1, d ** 0.8))
            px[x, y] = base
    # 바닥 그림자 (등불지기 실루엣의 긴 그림자)
    sh = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(sh)
    d.polygon([(S * 0.44, S * 0.80), (S * 0.56, S * 0.80), (S * 0.98, S * 1.02), (S * 0.70, S * 1.02)], fill=210)
    sh = sh.filter(ImageFilter.GaussianBlur(18))
    shadow_col = Image.new("RGB", (S, S), (20, 10, 34))
    img = Image.composite(shadow_col, img, sh)
    # 빛 번짐
    glow = Image.new("L", (S, S), 0)
    gd = ImageDraw.Draw(glow)
    for r, a in [(330, 40), (240, 70), (160, 120), (95, 200)]:
        gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=a)
    glow = glow.filter(ImageFilter.GaussianBlur(60))
    warm = Image.new("RGB", (S, S), (255, 170, 80))
    img = Image.composite(warm, img, glow.point(lambda v: int(v * 0.55)))
    d = ImageDraw.Draw(img)
    # 등불 몸체
    body_w, body_h = 230, 300
    bx0, by0 = cx - body_w / 2, cy - body_h / 2 + 30
    frame = (28, 20, 18)
    d.rounded_rectangle([bx0 - 18, by0 - 18, bx0 + body_w + 18, by0 + body_h + 18], radius=40, fill=frame)
    glass = Image.new("L", (S, S), 0)
    ImageDraw.Draw(glass).rounded_rectangle([bx0, by0, bx0 + body_w, by0 + body_h], radius=28, fill=255)
    inner = Image.new("RGB", (S, S), (255, 214, 140))
    img = Image.composite(inner, img, glass)
    d = ImageDraw.Draw(img)
    # 창살
    for i in range(1, 3):
        x = bx0 + body_w * i / 3
        d.rectangle([x - 7, by0, x + 7, by0 + body_h], fill=frame)
    # 불꽃
    flame = Image.new("L", (S, S), 0)
    fd = ImageDraw.Draw(flame)
    fcx, fcy = cx, by0 + body_h * 0.58
    fd.polygon([(fcx, fcy - 120), (fcx + 52, fcy + 10), (fcx + 30, fcy + 70), (fcx - 30, fcy + 70), (fcx - 52, fcy + 10)], fill=255)
    flame = flame.filter(ImageFilter.GaussianBlur(10))
    img = Image.composite(Image.new("RGB", (S, S), (255, 250, 230)), img, flame)
    d = ImageDraw.Draw(img)
    # 뚜껑과 고리
    d.polygon([(bx0 - 30, by0 - 14), (bx0 + body_w + 30, by0 - 14), (cx + 60, by0 - 90), (cx - 60, by0 - 90)], fill=frame)
    d.ellipse([cx - 70, by0 - 210, cx + 70, by0 - 70], outline=frame, width=26)
    d.rounded_rectangle([bx0 - 30, by0 + body_h + 8, bx0 + body_w + 30, by0 + body_h + 52], radius=14, fill=frame)
    img = img.resize((size, size), Image.LANCZOS)
    return img


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    big = make()
    big.save(os.path.join(OUT, "icon_1024.png"))
    big.resize((256, 256), Image.LANCZOS).save(os.path.join(OUT, "icon.png"))
    for s in (180, 167, 152, 120, 87, 80, 76, 60, 58, 40):
        big.resize((s, s), Image.LANCZOS).save(os.path.join(OUT, f"icon_{s}.png"))
    print("icons ok")
