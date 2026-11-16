"""Recorta os personagens parados da folha de modelos definitivos.

A folha (arte/personagens/modelos_definitivos.jpg) tem 4 linhas, uma por personagem,
de cima para baixo: Gordot, Spike, Thyr e Zork. A primeira coluna é a pose parada.

O recorte NÃO altera o desenho: só troca o fundo azul-escuro liso por transparência.
A sombra no chão faz parte do desenho e é mantida.

Uso (na raiz do repositório):
    python ferramentas/recortar_modelos.py
"""
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
FOLHA = RAIZ / "arte" / "personagens" / "modelos_definitivos.jpg"
SAIDA = RAIZ / "arte" / "personagens" / "monstros"

FUNDO = (28, 31, 45)
TOLERANCIA = 36            # soma das diferenças RGB aceitas como fundo (a folha é JPEG)
MARGEM = 2

# Faixas da folha que pertencem ao vizinho de cima e devem ser apagadas (x0, y0, x1, y1).
# A sombra do Thyr encosta na ponta da lança do Zork.
APAGAR = {"zork": [(0, 744, 250, 759)]}

# (nome, título, papel, área da pose parada na folha: x0, y0, x1, y1)
PERSONAGENS = [
    ("gordot", "GORDOT", "veloz / veneno", (0, 0, 385, 270)),
    ("spike", "SPIKE", "tanque", (0, 270, 385, 516)),
    ("thyr", "THYR", "mago", (0, 516, 385, 746)),
    ("zork", "ZORK", "chefe (NPC)", (0, 746, 385, 1024)),
]


def fundo_conectado(rgb):
    """Pixels parecidos com o fundo e ligados à borda da área (preenchimento a partir das bordas)."""
    h, w, _ = rgb.shape
    perto = np.abs(rgb.astype(int) - np.array(FUNDO)).sum(axis=2) <= TOLERANCIA
    fundo = np.zeros((h, w), bool)
    fila = deque((y, x) for y in range(h) for x in (0, w - 1) if perto[y, x])
    fila.extend((y, x) for x in range(w) for y in (0, h - 1) if perto[y, x])
    for y, x in fila:
        fundo[y, x] = True
    while fila:
        y, x = fila.popleft()
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < h and 0 <= nx < w and perto[ny, nx] and not fundo[ny, nx]:
                fundo[ny, nx] = True
                fila.append((ny, nx))
    return fundo


def recortar(folha, area, apagar=()):
    x0, y0, x1, y1 = area
    rgb = folha[y0:y1, x0:x1].copy()
    for ax0, ay0, ax1, ay1 in apagar:
        rgb[max(ay0 - y0, 0):max(ay1 - y0, 0), max(ax0 - x0, 0):max(ax1 - x0, 0)] = FUNDO
    frente = ~fundo_conectado(rgb)
    ys, xs = np.where(frente)
    ya, yb = max(ys.min() - MARGEM, 0), min(ys.max() + MARGEM + 1, rgb.shape[0])
    xa, xb = max(xs.min() - MARGEM, 0), min(xs.max() + MARGEM + 1, rgb.shape[1])
    rgba = np.zeros((yb - ya, xb - xa, 4), np.uint8)
    rgba[:, :, :3] = rgb[ya:yb, xa:xb]
    rgba[:, :, 3] = np.where(frente[ya:yb, xa:xb], 255, 0)
    return Image.fromarray(rgba, "RGBA")


def gerar():
    folha = np.array(Image.open(FOLHA).convert("RGB"))
    SAIDA.mkdir(parents=True, exist_ok=True)
    recortes = []
    for nome, titulo, papel, area in PERSONAGENS:
        img = recortar(folha, area, APAGAR.get(nome, ()))
        img.save(SAIDA / f"{nome}.png")
        recortes.append((img, titulo, papel))
        print("gerado:", nome, img.size)

    # Ficha com os quatro lado a lado (pés alinhados), sobre o mesmo fundo da folha
    margem = 40
    alto = max(i.height for i, _, _ in recortes)
    largura = sum(i.width for i, _, _ in recortes) + margem * (len(recortes) + 1)
    ficha = Image.new("RGB", (largura, alto + margem + 100), FUNDO)
    d = ImageDraw.Draw(ficha)
    try:
        fonte = ImageFont.truetype("arialbd.ttf", 28)
        fonte_p = ImageFont.truetype("arial.ttf", 20)
    except OSError:
        fonte = fonte_p = ImageFont.load_default()
    x, base_y = margem, alto + margem
    for img, titulo, papel in recortes:
        ficha.paste(img, (x, base_y - img.height), img)
        cx = x + img.width // 2
        d.text((cx, base_y + 32), titulo, fill=(230, 214, 180), font=fonte, anchor="mm")
        d.text((cx, base_y + 66), papel, fill=(160, 150, 150), font=fonte_p, anchor="mm")
        x += img.width + margem
    ficha.save(RAIZ / "arte" / "personagens" / "fichas_pixelart.png")
    print("gerado: fichas_pixelart.png", ficha.size)


if __name__ == "__main__":
    gerar()
