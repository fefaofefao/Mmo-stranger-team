#!/usr/bin/env python3
"""Acabamento final das spritesheets dos monstros (arte definitiva gerada).

Recebe as folhas "cruas" exportadas por tools/export_raw_sprites.gd e aplica, quadro a quadro:
  - luz volumétrica vinda de cima/esquerda (normais estimadas pela silhueta borrada),
    com sombras puxando para o frio/roxo e luzes para o quente;
  - realce de borda no topo (rim light) e oclusão no contato com o chão;
  - contorno seletivo colorido (selout): escuro da própria cor, mais forte embaixo/à direita.
Saída: assets/sprites/monsters/<form_id>.png (o jogo carrega automaticamente).

    godot --headless --path . -s tools/export_raw_sprites.gd -- /tmp/raw_sprites
    python3 tools/shade_sprites.py /tmp/raw_sprites [--preview]
"""
import os
import sys

import numpy as np
from PIL import Image

FRAME = 56
COLS, ROWS = 10, 4
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DEST = os.path.join(ROOT, "assets", "sprites", "monsters")
LIGHT = np.array([-0.55, -0.83])  # direção da luz (x, y), y para baixo


def blur(a, r):
    p = np.pad(a, r, mode="constant")
    out = np.zeros_like(a)
    n = 0
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            out += p[r + dy:r + dy + a.shape[0], r + dx:r + dx + a.shape[1]]
            n += 1
    return out / n


def shift(a, dx, dy, fill=0):
    """Desloca a matriz: resultado[y, x] = a[y - dy, x - dx]."""
    out = np.full_like(a, fill)
    h, w = a.shape[:2]
    ys = slice(max(dy, 0), h + min(dy, 0))
    xs = slice(max(dx, 0), w + min(dx, 0))
    ys2 = slice(max(-dy, 0), h + min(-dy, 0))
    xs2 = slice(max(-dx, 0), w + min(-dx, 0))
    out[ys, xs] = a[ys2, xs2]
    return out


def shade_frame(fr):
    rgb = fr[..., :3].astype(np.float64) / 255.0
    a = fr[..., 3].astype(np.float64) / 255.0
    body = a > 0.6
    if not body.any():
        return fr
    m = body.astype(np.float64)
    k = np.zeros_like(m)
    for r, wgt in ((1, 0.5), (3, 0.8), (5, 0.7)):
        mb = blur(blur(m, r), r)
        gy, gx = np.gradient(mb)
        k += wgt * (-(gx * LIGHT[0] + gy * LIGHT[1]))
    k = np.clip(k * 3.6, -1.0, 1.0)
    # degraus de sombreamento (visual pixel art, sem degradê contínuo)
    k = np.round(k * 3.0) / 3.0
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    # olhos, pupilas e brilhos dos olhos ficam intactos
    keep = (lum < 0.13) | ((lum > 0.9) & (sat < 0.12))
    sel = body & ~keep
    warm = np.array([1.0, 0.96, 0.82])
    cool = np.array([0.22, 0.17, 0.42])
    kp = np.clip(k, 0, 1)[..., None]
    kn = np.clip(-k, 0, 1)[..., None]
    out = rgb.copy()
    out = out + (warm - out) * 0.36 * kp
    out = out * (1 - 0.42 * kn) + cool * 0.24 * kn
    # rim light no topo da silhueta e oclusão perto do chão
    top_edge = body & ~shift(body, 0, 1, False)
    out[top_edge & sel] = out[top_edge & sel] + (warm - out[top_edge & sel]) * 0.22
    rgb = np.where(sel[..., None], np.clip(out, 0, 1), rgb)
    # contorno seletivo
    res = np.zeros((FRAME, FRAME, 4))
    res[..., :3] = rgb
    res[..., 3] = a
    outline = ~body & (shift(body, 1, 0, False) | shift(body, -1, 0, False) | shift(body, 0, 1, False) | shift(body, 0, -1, False))
    acc = np.zeros((FRAME, FRAME, 3))
    cnt = np.zeros((FRAME, FRAME))
    below = np.zeros((FRAME, FRAME), dtype=bool)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nb = shift(body, dx, dy, False)
        col = shift(rgb, dx, dy, 0)
        acc += col * nb[..., None]
        cnt += nb
        if dy == 1 or dx == 1:
            below |= nb  # o corpo está acima/à esquerda do pixel do contorno
    base = acc / np.maximum(cnt, 1)[..., None]
    # escurece mantendo o matiz (e puxa para o roxo nas partes de baixo)
    dark = base * 0.42 + np.array([0.04, 0.02, 0.08])
    darker = base * 0.26 + np.array([0.03, 0.01, 0.07])
    oc = np.where(below[..., None], darker, dark)
    res[outline, :3] = oc[outline]
    res[outline, 3] = 1.0
    return (np.clip(res, 0, 1) * 255 + 0.5).astype(np.uint8)


def shade_sheet(path):
    img = np.array(Image.open(path).convert("RGBA"))
    out = img.copy()
    for r in range(ROWS):
        for c in range(COLS):
            fr = img[r * FRAME:(r + 1) * FRAME, c * FRAME:(c + 1) * FRAME]
            out[r * FRAME:(r + 1) * FRAME, c * FRAME:(c + 1) * FRAME] = shade_frame(fr)
    return Image.fromarray(out, "RGBA")


def main():
    src = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else "/tmp/raw_sprites"
    os.makedirs(DEST, exist_ok=True)
    files = sorted(f for f in os.listdir(src) if f.endswith(".png"))
    for f in files:
        shade_sheet(os.path.join(src, f)).save(os.path.join(DEST, f), optimize=True)
    print("folhas finalizadas:", len(files))


if __name__ == "__main__":
    main()
