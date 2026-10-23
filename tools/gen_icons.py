#!/usr/bin/env python3
"""Gera os ícones da interface em assets/ui/icons/*.png (64x64, com contorno, sombreamento e sombra).

Cada ícone é desenhado num grid lógico de 32x32 com formas vetoriais, renderizado em 8x
(256 px) e reduzido para 64 px com filtro Lanczos (bordas suaves). O jogo carrega os PNGs
automaticamente (src/art/icons.gd); sem eles usa os ícones pixel art 12x12 embutidos.

    python3 tools/gen_icons.py            # gera todos
    python3 tools/gen_icons.py --sheet    # também salva docs/icons_preview.png
"""
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

S = 8                # escala do grid lógico
N = 32 * S           # tamanho de trabalho
OUT = 64             # tamanho final
OUTLINE = (27, 18, 10, 255)
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DEST = os.path.join(ROOT, "assets", "ui", "icons")


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (c[3],)


class Icon:
    def __init__(self):
        self.img = Image.new("RGBA", (N, N), (0, 0, 0, 0))

    # ---- máscaras
    def _mask(self):
        return Image.new("L", (N, N), 0)

    def _paint(self, mask, color, grad=0.32, light=None):
        """Preenche a máscara com a cor e um degradê vertical (claro em cima, escuro embaixo)."""
        c = hexc(color) if isinstance(color, str) else color
        bbox = mask.getbbox()
        if bbox is None:
            return
        y0, y1 = bbox[1], max(bbox[1] + 1, bbox[3])
        fill = Image.new("RGBA", (N, N), c)
        if grad > 0:
            g = Image.new("RGBA", (1, N))
            for y in range(N):
                t = min(1.0, max(0.0, (y - y0) / (y1 - y0)))
                g.putpixel((0, y), shade(c, 1.0 + grad * 0.55 - grad * t * 1.25))
            fill = g.resize((N, N))
        self.img.paste(fill, (0, 0), mask)

    def _p(self, v):
        return v * S

    # ---- formas (coordenadas no grid 32x32)
    def shape(self, color, ops, grad=0.32):
        m = self._mask()
        d = ImageDraw.Draw(m)
        for op in ops:
            kind, args, val = op[0], op[1:-1], op[-1]
            fill = 255 if val else 0
            if kind == "c":
                cx, cy, r = args
                d.ellipse([self._p(cx - r), self._p(cy - r), self._p(cx + r), self._p(cy + r)], fill=fill)
            elif kind == "e":
                cx, cy, rx, ry = args
                d.ellipse([self._p(cx - rx), self._p(cy - ry), self._p(cx + rx), self._p(cy + ry)], fill=fill)
            elif kind == "p":
                pts = args[0]
                d.polygon([(self._p(x), self._p(y)) for x, y in pts], fill=fill)
            elif kind == "r":
                x, y, w, h, rad = args
                d.rounded_rectangle([self._p(x), self._p(y), self._p(x + w), self._p(y + h)], radius=self._p(rad), fill=fill)
            elif kind == "l":
                pts, w = args
                pp = [(self._p(x), self._p(y)) for x, y in pts]
                d.line(pp, fill=fill, width=int(self._p(w)))
                for x, y in pp:
                    rr = self._p(w) / 2
                    d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=fill)
            elif kind == "a":
                cx, cy, r, a0, a1, w = args
                d.arc([self._p(cx - r), self._p(cy - r), self._p(cx + r), self._p(cy + r)], a0, a1, fill=fill, width=int(self._p(w)))
            elif kind == "pie":
                cx, cy, r, a0, a1 = args
                d.pieslice([self._p(cx - r), self._p(cy - r), self._p(cx + r), self._p(cy + r)], a0, a1, fill=fill)
        self._paint(m, color, grad)
        return self

    # atalhos
    def circle(self, cx, cy, r, color, grad=0.32):
        return self.shape(color, [("c", cx, cy, r, True)], grad)

    def ell(self, cx, cy, rx, ry, color, grad=0.32):
        return self.shape(color, [("e", cx, cy, rx, ry, True)], grad)

    def poly(self, pts, color, grad=0.32):
        return self.shape(color, [("p", pts, True)], grad)

    def rect(self, x, y, w, h, color, rad=0.0, grad=0.32):
        return self.shape(color, [("r", x, y, w, h, rad, True)], grad)

    def line(self, pts, w, color, grad=0.0):
        return self.shape(color, [("l", pts, w, True)], grad)

    def ring(self, cx, cy, ro, ri, color, grad=0.32):
        return self.shape(color, [("c", cx, cy, ro, True), ("c", cx, cy, ri, False)], grad)

    def arc(self, cx, cy, r, a0, a1, w, color, grad=0.0):
        return self.shape(color, [("a", cx, cy, r, a0, a1, w, True)], grad)

    def shine(self, cx, cy, rx, ry, alpha=150):
        """Brilho especular branco translúcido."""
        layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        d.ellipse([self._p(cx - rx), self._p(cy - ry), self._p(cx + rx), self._p(cy + ry)], fill=(255, 255, 255, alpha))
        a = self.img.getchannel("A")
        la = ImageChops.multiply(layer.getchannel("A"), a)
        layer.putalpha(la)
        self.img = Image.alpha_composite(self.img, layer)
        return self

    # ---- acabamento: contorno arredondado + sombra
    def finish(self, outline=1.25):
        alpha = self.img.getchannel("A").point(lambda v: 255 if v > 90 else 0)
        rad = outline * S
        grown = alpha.filter(ImageFilter.GaussianBlur(rad * 0.62)).point(lambda v: 255 if v > 14 else 0)
        grown = grown.filter(ImageFilter.GaussianBlur(S * 0.35))
        base = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        shadow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        sh = grown.point(lambda v: int(v * 0.45))
        shadow.paste((0, 0, 0, 255), (int(S * 0.6), int(S * 1.1)), sh)
        base = Image.alpha_composite(base, shadow)
        ol = Image.new("RGBA", (N, N), OUTLINE)
        ol.putalpha(grown)
        base = Image.alpha_composite(base, ol)
        base = Image.alpha_composite(base, self.img)
        return base.resize((OUT, OUT), Image.LANCZOS)


def star_pts(cx, cy, ro, ri, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = ro if i % 2 == 0 else ri
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def rot_pts(pts, cx, cy, deg):
    a = math.radians(deg)
    out = []
    for x, y in pts:
        dx, dy = x - cx, y - cy
        out.append((cx + dx * math.cos(a) - dy * math.sin(a), cy + dx * math.sin(a) + dy * math.cos(a)))
    return out


GOLD = "#f4c542"
GOLD_D = "#c98a1c"
WOOD = "#a0602a"
WOOD_L = "#c88a48"
STEEL = "#dfe5ee"
STEEL_D = "#8d97a8"
RED = "#e5483a"
GREEN = "#5fcf4a"
BLUE = "#3b8de0"
PURPLE = "#a35cf0"
CREAM = "#f2e6c8"
DARK = "#2a1c10"


def coin():
    i = Icon()
    i.circle(16, 16, 13, GOLD)
    i.ring(16, 16, 10, 8.6, GOLD_D, 0)
    i.rect(14.4, 9.5, 3.2, 13, "#fbe7a0", 1.2, 0)
    i.shine(11, 10, 3.5, 2.2, 140)
    return i


def gem():
    i = Icon()
    i.poly([(6, 12), (11.5, 5), (20.5, 5), (26, 12), (16, 28)], "#3fb0f0")
    i.poly([(6, 12), (26, 12), (16, 28)], "#2b82d0", 0.2)
    i.poly([(11.5, 5), (20.5, 5), (22, 12), (10, 12)], "#a8e6ff", 0.1)
    i.poly([(10, 12), (22, 12), (16, 28)], "#4fb8f5", 0.2)
    i.shine(12, 8, 2.2, 1.4, 200)
    return i


def diamond():
    i = Icon()
    i.poly([(4, 12), (10, 5), (22, 5), (28, 12), (16, 28.5)], "#7fe8ff")
    i.poly([(4, 12), (28, 12), (16, 28.5)], "#3ec4f0", 0.25)
    i.poly([(10, 5), (16, 12), (22, 5)], "#d8fbff", 0.05)
    i.poly([(10, 12), (16, 28.5), (22, 12)], "#9af0ff", 0.15)
    i.poly([(4, 12), (10, 5), (10, 12)], "#b8f6ff", 0.1)
    i.poly([(22, 5), (28, 12), (22, 12)], "#56d4f8", 0.1)
    i.shine(12.5, 8, 2, 1.3, 230)
    i.poly(star_pts(25.5, 4.5, 3.6, 1.1, 4, 0), "#ffffff", 0)
    return i


def boost():
    i = Icon()
    i.circle(16, 16, 13, "#8a4ae0")
    i.circle(16, 16, 10.5, "#b07aff", 0.2)
    i.poly([(18, 5), (9, 18), (15, 18), (13, 27), (23, 13), (17, 13), (20, 5)], "#ffe36a", 0.25)
    i.shine(11, 10, 3, 2, 110)
    return i


def sword():
    i = Icon()
    i.poly([(24.5, 3.5), (28.5, 3.5), (28.5, 7.5), (13.5, 22.2), (9.8, 18.5)], STEEL, 0.25)
    i.line([(26.5, 5.5), (12, 20)], 0.9, "#ffffff")
    i.line([(7.5, 15.5), (15.5, 23.5)], 3.4, GOLD)
    i.line([(6, 25), (10.5, 20.5)], 3.2, "#7a4a26")
    i.circle(5, 26.5, 2.6, GOLD)
    return i


def shield():
    i = Icon()
    pts = [(5, 6), (16, 2.5), (27, 6), (26, 17), (16, 29.5), (6, 17)]
    i.poly(pts, "#6e8fbe")
    i.poly([(8.5, 8), (16, 5.5), (23.5, 8), (22.8, 16.5), (16, 25.5), (9.2, 16.5)], "#3f63a0", 0.25)
    i.poly([(16, 5.5), (23.5, 8), (22.8, 16.5), (16, 25.5)], "#5277b5", 0.2)
    i.poly(star_pts(16, 14.5, 4.6, 2.0), GOLD, 0.2)
    return i


def map_():
    i = Icon()
    i.poly([(3, 7), (11.5, 4.5), (20.5, 7.5), (29, 5), (29, 25), (20.5, 27.5), (11.5, 25), (3, 27.5)], CREAM, 0.2)
    i.poly([(11.5, 4.5), (20.5, 7.5), (20.5, 27.5), (11.5, 25)], "#dcc89a", 0.15)
    i.ell(7.5, 19, 3, 3.6, "#7ec46a", 0.1)
    i.ell(24, 11, 3, 2.4, "#7ec46a", 0.1)
    for a, b in [((6, 11), (9.5, 13)), ((12, 15), (15.5, 17)), ((17.5, 19), (21, 18))]:
        i.line([a, b], 1.4, RED)
    i.line([(22.5, 19.5), (26, 23)], 1.7, RED)
    i.line([(26, 19.5), (22.5, 23)], 1.7, RED)
    return i


def skull():
    i = Icon()
    i.circle(16, 13, 11, "#f3eedf")
    i.rect(10, 18, 12, 9, "#e6dfcb", 2.5)
    i.ell(11.6, 14, 3.2, 3.6, DARK, 0)
    i.ell(20.4, 14, 3.2, 3.6, DARK, 0)
    i.poly([(16, 17.5), (14.4, 20.5), (17.6, 20.5)], DARK, 0)
    for x in (13, 16, 19):
        i.line([(x, 23.5), (x, 26.5)], 1.1, "#9a907a")
    i.circle(12.6, 13, 0.9, "#ff5a40", 0)
    i.circle(21.4, 13, 0.9, "#ff5a40", 0)
    return i


def paw():
    i = Icon()
    c = "#c98d55"
    i.shape(c, [("e", 16, 21.5, 7.5, 6.2, True), ("p", [(10, 20), (22, 20), (16, 13)], True)])
    for x, y, r in [(6.8, 13.5, 3.3), (12, 7.8, 3.5), (20, 7.8, 3.5), (25.2, 13.5, 3.3)]:
        i.ell(x, y, r, r * 1.15, c)
    i.ell(16, 22.5, 4.4, 3, "#e8b08a", 0.1)
    for x, y in [(6.8, 13.8), (12, 8), (20, 8), (25.2, 13.8)]:
        i.ell(x, y + 0.6, 1.6, 1.8, "#e8b08a", 0.1)
    return i


def chest():
    i = Icon()
    i.rect(3.5, 14, 25, 14, WOOD, 1.5)
    i.shape(WOOD_L, [("r", 3.5, 6, 25, 9, 4.5, True), ("r", 3.5, 10, 25, 5, 0, True)])
    i.rect(3.5, 13.4, 25, 2.2, DARK, 0, 0)
    for x in (6.5, 22.5):
        i.rect(x, 6.2, 3, 21.6, GOLD, 0.6, 0.25)
    i.rect(13, 11.5, 6, 7.5, GOLD, 1.2)
    i.circle(16, 14.4, 1.2, DARK, 0)
    i.rect(15.4, 14.4, 1.2, 2.8, DARK, 0, 0)
    i.shine(10, 8.5, 3, 1.2, 90)
    return i


def bag():
    i = Icon()
    c = "#b97d45"
    i.shape(c, [("e", 16, 20.5, 11.5, 9, True), ("p", [(9.5, 15), (22.5, 15), (19.5, 8), (12.5, 8)], True)])
    i.poly([(11, 7.5), (8, 3.5), (13, 5.5), (16, 3), (19, 5.5), (24, 3.5), (21, 7.5)], "#9a6232", 0.2)
    i.line([(11.5, 9.2), (20.5, 9.2)], 2.2, GOLD)
    i.circle(16, 21, 4.6, GOLD)
    i.rect(15.1, 18.3, 1.8, 5.4, GOLD_D, 0.6, 0)
    i.shine(10, 16, 2.6, 3.4, 70)
    return i


def shop():
    i = Icon()
    i.rect(5, 13, 22, 15, "#c99058", 1)
    i.rect(13, 18, 6, 10, "#6a3d1c", 0.8)
    i.circle(17.6, 23.2, 0.7, GOLD, 0)
    i.rect(6.8, 16, 4.4, 4.4, "#9fd8ff", 0.5)
    i.rect(20.8, 16, 4.4, 4.4, "#9fd8ff", 0.5)
    i.rect(3, 4, 26, 4, "#8a3020", 1)
    xs = [3 + k * 26 / 6 for k in range(7)]
    for k in range(6):
        col = RED if k % 2 == 0 else "#fff3e0"
        x0, x1 = xs[k], xs[k + 1]
        i.shape(col, [("r", x0, 7, x1 - x0, 5, 0, True), ("e", (x0 + x1) / 2, 12, (x1 - x0) / 2, 2.2, True)], 0.15)
    return i


def scales():
    i = Icon()
    i.rect(14.8, 6, 2.4, 20, GOLD, 0.8)
    i.poly([(9, 29), (23, 29), (20, 25), (12, 25)], GOLD_D)
    i.line([(5, 9.5), (27, 9.5)], 2.2, GOLD)
    i.circle(16, 6, 2.2, GOLD)
    for cx in (7.5, 24.5):
        i.line([(cx, 10), (cx - 4.5, 19)], 0.6, "#8a6a2a")
        i.line([(cx, 10), (cx + 4.5, 19)], 0.6, "#8a6a2a")
        i.shape(GOLD, [("pie", cx, 18.6, 6, 0, 180, True)])
    return i


def altar():
    i = Icon()
    i.rect(4.5, 23.5, 23, 5, "#8f8a84", 1)
    i.rect(8.5, 16.5, 15, 7.5, "#b4aea6", 0.8)
    i.rect(6.5, 15, 19, 2.6, "#cfc9c0", 0.8)
    i.circle(16, 9, 8.5, (163, 92, 240, 70), 0)
    i.circle(16, 9, 5.8, PURPLE)
    i.circle(16, 9, 3.2, "#e2c4ff", 0.1)
    i.shine(14, 6.8, 1.6, 1.1, 220)
    for a in (210, 330, 90):
        x = 16 + 8.5 * math.cos(math.radians(a))
        y = 9 + 8.5 * math.sin(math.radians(a)) * 0.55
        i.poly(star_pts(x, y, 1.6, 0.6, 4), "#f0dcff", 0)
    return i


def book():
    i = Icon()
    i.rect(5, 4, 22, 24.5, "#2f5fb0", 1.6)
    i.rect(23, 5.5, 3, 21.5, CREAM, 0.6, 0.1)
    i.rect(5, 4, 3.4, 24.5, "#22488a", 1.2, 0.1)
    i.rect(10.5, 7.5, 10.5, 9.5, "#3f78cf", 1, 0.1)
    i.poly(star_pts(15.8, 12.3, 4, 1.7), GOLD, 0.2)
    i.line([(11, 21), (20.5, 21)], 1.1, GOLD)
    i.line([(11, 23.8), (18, 23.8)], 1.1, GOLD)
    return i


def trophy():
    i = Icon()
    i.arc(8.5, 11.5, 4.6, 90, 270, 2.2, GOLD_D)
    i.arc(23.5, 11.5, 4.6, 270, 90, 2.2, GOLD_D)
    i.shape(GOLD, [("p", [(8.5, 4.5), (23.5, 4.5), (22.5, 13), (16, 19.5), (9.5, 13)], True), ("e", 16, 12.5, 6.6, 7, True)])
    i.rect(14.2, 18.5, 3.6, 5, GOLD_D, 0.4)
    i.rect(9.5, 23, 13, 5.5, "#7a4a26", 1.2)
    i.rect(12, 24.4, 8, 2.4, GOLD, 0.5, 0.1)
    i.poly(star_pts(16, 11, 3.2, 1.4), "#fff1b0", 0.1)
    i.shine(11.5, 7.5, 1.6, 2.4, 140)
    return i


def gear():
    i = Icon()
    teeth = []
    for k in range(8):
        a = k * 45
        teeth.append(("p", rot_pts([(13.6, 2.5), (18.4, 2.5), (19.2, 8), (12.8, 8)], 16, 16, a), True))
    i.shape(STEEL_D, teeth + [("c", 16, 16, 10.5, True), ("c", 16, 16, 4.2, False)], 0.3)
    i.ring(16, 16, 7.6, 4.2, "#b8c0cc", 0.2)
    return i


def star(color=GOLD, inner="#fff1b0"):
    i = Icon()
    i.poly(star_pts(16, 17, 14.5, 6.4), color)
    i.poly(star_pts(16, 17, 7.5, 3.3), inner, 0.1)
    return i


def star_empty():
    i = Icon()
    i.poly(star_pts(16, 17, 14.5, 6.4), "#5d544a", 0.2)
    i.poly(star_pts(16, 17, 10.8, 4.8), "#3a332c", 0.1)
    return i


def lock():
    i = Icon()
    i.arc(16, 13, 7, 180, 360, 3, "#c2c8d2")
    i.line([(9, 13), (9, 15)], 3, "#c2c8d2")
    i.line([(23, 13), (23, 15)], 3, "#c2c8d2")
    i.rect(6, 14, 20, 15, GOLD, 2.2)
    i.circle(16, 20, 2.4, DARK, 0)
    i.poly([(15, 21), (17, 21), (17.6, 25.5), (14.4, 25.5)], DARK, 0)
    i.shine(10, 17, 2, 1.4, 120)
    return i


def play():
    i = Icon()
    i.shape("#ffffff", [("p", [(9, 5), (27, 16), (9, 27)], True)], 0.25)
    i.shine(12.5, 11, 1.5, 3, 150)
    return i


def crown():
    i = Icon()
    i.poly([(4, 25), (3.5, 9), (10.5, 16), (16, 5.5), (21.5, 16), (28.5, 9), (28, 25)], GOLD)
    i.rect(4, 21.5, 24, 5, GOLD_D, 1, 0.2)
    for x, c in [(9, RED), (16, BLUE), (23, RED)]:
        i.circle(x, 24, 1.8, c, 0.2)
    for x, y in [(3.5, 9), (16, 5.5), (28.5, 9)]:
        i.circle(x, y, 2, "#fff1b0", 0.1)
    return i


def clock():
    i = Icon()
    i.circle(16, 16, 13.5, GOLD_D)
    i.circle(16, 16, 11, CREAM, 0.15)
    for k in range(12):
        a = math.radians(k * 30)
        r0 = 8.6 if k % 3 else 7.6
        i.line([(16 + r0 * math.cos(a), 16 + r0 * math.sin(a)), (16 + 9.8 * math.cos(a), 16 + 9.8 * math.sin(a))], 0.9, "#7a6a50")
    i.line([(16, 16), (16, 8.5)], 1.8, DARK)
    i.line([(16, 16), (21, 18.5)], 1.6, DARK)
    i.circle(16, 16, 1.6, RED, 0)
    return i


def back():
    i = Icon()
    i.poly([(3.5, 16), (15, 5), (15, 11.5), (28, 11.5), (28, 20.5), (15, 20.5), (15, 27)], CREAM, 0.25)
    return i


def heart(color=RED):
    i = Icon()
    i.shape(color, [("c", 10.5, 12, 7, True), ("c", 21.5, 12, 7, True), ("p", [(4, 14.5), (28, 14.5), (16, 28.5)], True)])
    i.shine(9.5, 10, 2.4, 2, 170)
    return i


def plus():
    i = Icon()
    i.shape(GREEN, [("r", 12.5, 4, 7, 24, 1.5, True), ("r", 4, 12.5, 24, 7, 1.5, True)])
    return i


def minus():
    i = Icon()
    i.rect(4, 12.5, 24, 7, RED, 1.5)
    return i


def check():
    i = Icon()
    i.line([(5.5, 16.5), (12.5, 24), (26.5, 7.5)], 5, GREEN, 0.3)
    return i


def cross():
    i = Icon()
    i.shape(RED, [("l", [(7, 7), (25, 25)], 5, True), ("l", [(25, 7), (7, 25)], 5, True)])
    return i


def globe():
    i = Icon()
    i.circle(16, 16, 13, BLUE)
    i.shape(GREEN, [("e", 10.5, 11.5, 5.2, 4.4, True), ("e", 13, 16, 2.6, 4, True), ("e", 21.5, 20.5, 5, 4.6, True), ("e", 22.5, 9, 3, 2, True)], 0.2)
    i.arc(16, 16, 13, 0, 360, 0.7, "#9fd0ff")
    i.shine(10.5, 9, 3.5, 2.3, 110)
    return i


def cloud():
    i = Icon()
    i.shape("#f4f8ff", [("c", 10, 18.5, 6.2, True), ("c", 17, 14, 8, True), ("c", 24, 18.5, 5.6, True), ("r", 9, 17, 16, 7.6, 3.5, True)], 0.25)
    return i


def user():
    i = Icon()
    i.shape(BLUE, [("e", 16, 28, 11.5, 9, True), ("r", 4.5, 28, 23, 4, 0, False)])
    i.circle(16, 11, 6.6, "#f0c8a0")
    i.shape("#6a3d1c", [("pie", 16, 10.4, 7, 180, 360, True)], 0.2)
    return i


def flame(outer="#ee4f24", mid="#ff9a2a", inner="#ffe36a"):
    i = Icon()
    i.shape(outer, [("c", 16, 20, 9.5, True), ("p", [(6.6, 19), (13, 9), (16, 2), (19.5, 10), (25.4, 19)], True)], 0.2)
    i.shape(mid, [("c", 16, 21.5, 6.6, True), ("p", [(9.6, 21), (15, 10), (22.4, 21)], True)], 0.15)
    i.shape(inner, [("c", 16, 23.5, 3.8, True), ("p", [(12.3, 23), (16, 15), (19.7, 23)], True)], 0.1)
    return i


def house():
    i = Icon()
    i.rect(21, 4.5, 4, 8, "#9a5a3a", 0.5)
    i.rect(6, 14, 20, 14.5, CREAM, 0.8, 0.2)
    i.poly([(2.5, 16), (16, 3.5), (29.5, 16), (26.5, 17), (16, 7.5), (5.5, 17)], "#d24a32")
    i.poly([(5.5, 16.5), (16, 7), (26.5, 16.5)], "#d24a32", 0.15)
    i.rect(13, 19, 6.5, 9.5, "#7a4a26", 1)
    i.rect(7.8, 18.5, 4, 4, "#9fd8ff", 0.4)
    i.rect(21.5, 18.5, 3.6, 4, "#9fd8ff", 0.4)
    return i


def egg():
    i = Icon()
    i.shape(CREAM, [("e", 16, 18.5, 10, 11.5, True), ("e", 16, 12, 7.5, 9, True)])
    for x, y, r in [(11.5, 13, 2.2), (19.5, 19.5, 2.8), (13, 23.5, 1.6), (20, 10.5, 1.4)]:
        i.circle(x, y, r, "#68b85a", 0.1)
    i.shine(12, 9, 2, 3, 150)
    return i


def bolt(color="#f5d030"):
    i = Icon()
    i.poly([(19, 2.5), (6.5, 18), (14.5, 18), (11, 29.5), (25.5, 12.5), (17.5, 12.5), (22.5, 2.5)], color, 0.3)
    return i


def sparkle():
    i = Icon()
    i.poly([(14, 3), (16.6, 12.4), (26, 15), (16.6, 17.6), (14, 27), (11.4, 17.6), (2, 15), (11.4, 12.4)], GOLD, 0.25)
    i.poly(star_pts(24.5, 6.5, 4.2, 1.3, 4, 0), "#fff1b0", 0.1)
    i.poly(star_pts(24, 25, 3, 1, 4, 0), "#fff1b0", 0.1)
    return i


def swap():
    i = Icon()
    i.shape(GREEN, [("r", 4.5, 8.5, 17, 5, 1.6, True), ("p", [(19, 4), (28.5, 11), (19, 18)], True)], 0.25)
    i.shape("#58a8ff", [("r", 10.5, 18.5, 17, 5, 1.6, True), ("p", [(13, 14), (3.5, 21), (13, 28)], True)], 0.25)
    return i


def xp():
    i = Icon()
    i.circle(16, 16, 13, "#3f9a3a")
    i.shape("#b8ff9a", [("p", [(16, 5.5), (25, 15), (19.5, 15), (19.5, 25.5), (12.5, 25.5), (12.5, 15), (7, 15)], True)], 0.25)
    i.shine(11, 9.5, 3, 2, 100)
    return i


def clover():
    i = Icon()
    g = "#46b04a"
    i.line([(16, 17), (19, 29)], 2.2, "#2f7a2f")
    for a in (0, 90, 180, 270):
        x = 16 + 6.2 * math.cos(math.radians(a - 45))
        y = 15 + 6.2 * math.sin(math.radians(a - 45))
        i.circle(x, y, 5.6, g, 0.3)
    i.circle(16, 15, 2.2, "#a8f08a", 0.1)
    return i


def target():
    i = Icon()
    i.circle(16, 16, 13.5, RED)
    i.circle(16, 16, 10, "#fff3e0", 0.1)
    i.circle(16, 16, 6.5, RED)
    i.circle(16, 16, 3, "#fff3e0", 0.1)
    return i


def speed():
    i = Icon()
    c = "#40d0c0"
    i.shape(c, [("l", [(5, 6), (14, 16), (5, 26)], 4.2, True)], 0.3)
    i.shape(c, [("l", [(15, 6), (24, 16), (15, 26)], 4.2, True)], 0.3)
    return i


def hp_bonus():
    return heart()


def error():
    return cross()


# ---------------- ícones de tipo (elementos)
def t_agua():
    i = Icon()
    i.shape("#3b8de0", [("c", 16, 20, 9, True), ("p", [(16, 2.5), (7.4, 17.5), (24.6, 17.5)], True)])
    i.shine(12.4, 19, 2, 3.4, 170)
    return i


def t_fogo():
    return flame()


def t_gelo():
    i = Icon()
    c = "#8fe6f8"
    ops = []
    for k in range(3):
        a = math.radians(90 + k * 60)
        dx, dy = 13 * math.cos(a), 13 * math.sin(a)
        ops.append(("l", [(16 - dx, 16 - dy), (16 + dx, 16 + dy)], 2.6, True))
        for sgn in (1, -1):
            bx, by = 16 + sgn * dx * 0.62, 16 + sgn * dy * 0.62
            for side in (-1, 1):
                b = a + side * math.radians(40) + (0 if sgn > 0 else math.pi)
                ops.append(("l", [(bx, by), (bx + 4.6 * math.cos(b), by + 4.6 * math.sin(b))], 2.0, True))
    i.shape(c, ops, 0.25)
    i.circle(16, 16, 3, "#e8fbff", 0.1)
    return i


def t_planta():
    i = Icon()
    leaf = []
    for k in range(25):
        t = k / 24
        leaf.append((5 + 22 * t, 26 - 22 * t + 7.5 * math.sin(t * math.pi)))
    for k in range(25):
        t = 1 - k / 24
        leaf.append((5 + 22 * t, 26 - 22 * t - 7.5 * math.sin(t * math.pi)))
    i.poly(leaf, "#4caf3f")
    i.line([(5.5, 26.5), (24, 7.5)], 1.2, "#2f7a2f")
    for t in (0.35, 0.55, 0.75):
        x, y = 5 + 22 * t, 26 - 22 * t
        i.line([(x, y), (x - 3.5, y - 4.5)], 0.9, "#2f7a2f")
        i.line([(x, y), (x + 4.5, y + 3.5)], 0.9, "#2f7a2f")
    i.line([(3, 29), (6, 25.5)], 1.6, "#6a4a20")
    return i


def t_terra():
    i = Icon()
    i.poly([(4, 24), (7, 12), (14, 6), (23, 7.5), (28.5, 16), (27, 26), (15, 28.5)], "#a8743a")
    i.poly([(7, 12), (14, 6), (23, 7.5), (17, 14)], "#c99a5e", 0.1)
    i.poly([(17, 14), (23, 7.5), (28.5, 16), (22, 20)], "#8c5e2c", 0.1)
    i.line([(17, 14), (15, 22)], 0.9, "#6a4420")
    i.circle(10, 21, 1.4, "#6a4420", 0)
    return i


def t_eletrico():
    return bolt("#f2d023")


def t_vento():
    i = Icon()
    c = "#a8d4f0"
    i.line([(3, 11), (20, 11)], 2.6, c)
    i.arc(20, 7.5, 3.6, 180, 450, 2.6, c)
    i.line([(3, 17), (25, 17)], 2.6, c)
    i.arc(25, 21, 4, -90, 180, 2.6, c)
    i.line([(6, 23), (16, 23)], 2.6, c)
    return i


def t_luz():
    i = Icon()
    rays = []
    for k in range(8):
        a = math.radians(k * 45)
        p1 = (16 + 14.5 * math.cos(a), 16 + 14.5 * math.sin(a))
        l = (16 + 8 * math.cos(a + 0.33), 16 + 8 * math.sin(a + 0.33))
        r = (16 + 8 * math.cos(a - 0.33), 16 + 8 * math.sin(a - 0.33))
        rays.append(("p", [p1, l, r], True))
    i.shape("#ffb830", rays, 0.2)
    i.circle(16, 16, 8.4, "#f8d24e")
    i.circle(16, 16, 5, "#fff1b0", 0.1)
    return i


def t_sombra():
    i = Icon()
    i.shape("#8a5ad0", [("c", 15, 16, 12, True), ("c", 21, 12, 10, False)], 0.3)
    i.poly(star_pts(23, 20, 3.4, 1.3, 4, 0), "#e2c4ff", 0.1)
    i.poly(star_pts(25.5, 9, 2.2, 0.8, 4, 0), "#e2c4ff", 0.1)
    return i


ICONS = {
    "coin": coin, "gem": gem, "diamond": diamond, "boost": boost, "sword": sword, "shield": shield, "map": map_, "skull": skull, "paw": paw,
    "chest": chest, "bag": bag, "shop": shop, "scales": scales, "altar": altar, "book": book,
    "trophy": trophy, "gear": gear, "star": star, "star_empty": star_empty, "lock": lock, "play": play,
    "crown": crown, "clock": clock, "back": back, "heart": heart, "plus": plus, "minus": minus,
    "check": check, "cross": cross, "globe": globe, "cloud": cloud, "user": user, "flame": flame,
    "house": house, "egg": egg, "bolt": bolt, "sparkle": sparkle, "swap": swap, "xp": xp,
    "clover": clover, "target": target, "speed": speed, "error": error,
    "t_agua": t_agua, "t_fogo": t_fogo, "t_gelo": t_gelo, "t_planta": t_planta, "t_terra": t_terra,
    "t_eletrico": t_eletrico, "t_vento": t_vento, "t_luz": t_luz, "t_sombra": t_sombra,
}


def main():
    os.makedirs(DEST, exist_ok=True)
    out = {}
    for name, fn in ICONS.items():
        img = fn().finish()
        img.save(os.path.join(DEST, name + ".png"))
        out[name] = img
    print("ícones gerados:", len(out))
    if "--sheet" in sys.argv:
        cols = 10
        rows = (len(out) + cols - 1) // cols
        sheet = Image.new("RGBA", (cols * 80, rows * 80), (40, 32, 26, 255))
        for k, (name, img) in enumerate(out.items()):
            sheet.alpha_composite(img, ((k % cols) * 80 + 8, (k // cols) * 80 + 8))
        sheet.save(os.path.join(ROOT, "docs", "icons_preview.png"))


if __name__ == "__main__":
    main()
