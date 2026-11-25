"""Gera as artes e os sprites dos itens coletáveis: picaretas e a chave das correntes.

Picaretas: recortadas da picareta desenhada pela equipe (arte/sprites_originais/assets_cenario_2.png).
A versão de ferro é a original; as outras trocam só a cor da cabeça (aço, ouro e cristal),
para as próximas fases/masmorras.

Chave: pixel art desenhada aqui na mesma grade de pixel dos assets (1 pixel da arte = 4 da imagem),
com contorno escuro e luz de cima/esquerda.

Saídas em arte/objetos/:
    <item>.png                ícone parado (fundo transparente)
    <item>_sprites.png/.json  animações "chao" (flutuando com brilho) e "coleta" (sobe e some)
    itens_previa.png          todos os itens e quadros, para conferir

Uso (na raiz do repositório):
    python ferramentas/gerar_itens.py
"""
import json
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
ASSETS = RAIZ / "arte" / "sprites_originais" / "assets_cenario_2.png"
SAIDA = RAIZ / "arte" / "objetos"
PX = 4                      # tamanho do pixel da arte dos assets

FUNDO_ASSETS = (28, 32, 43)
CAIXA_PICARETA = (580, 740, 732, 850)   # picareta deitada na folha de assets
CONTORNO = (18, 12, 10)

# Rampa de cores da cabeça da picareta (do escuro ao claro) para cada material
MATERIAIS = {
    "ferro": None,  # original
    "aco": [(40, 50, 66), (84, 100, 124), (150, 172, 196), (214, 228, 240)],
    "ouro": [(92, 52, 12), (176, 110, 24), (236, 180, 52), (255, 236, 150)],
    "cristal": [(20, 60, 90), (30, 140, 190), (90, 220, 240), (210, 255, 255)],
}


# ------------------------------------------------------------------ utilidades
def tirar_fundo(rgb, fundo, tolerancia=30):
    """Fundo ligado às bordas vira transparente."""
    h, w, _ = rgb.shape
    perto = np.abs(rgb.astype(int) - np.array(fundo)).sum(axis=2) <= tolerancia
    vis = np.zeros((h, w), bool)
    fila = deque((y, x) for y in range(h) for x in (0, w - 1) if perto[y, x])
    fila.extend((y, x) for x in range(w) for y in (0, h - 1) if perto[y, x])
    for y, x in fila:
        vis[y, x] = True
    while fila:
        y, x = fila.popleft()
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < h and 0 <= nx < w and perto[ny, nx] and not vis[ny, nx]:
                vis[ny, nx] = True
                fila.append((ny, nx))
    rgba = np.zeros((h, w, 4), np.uint8)
    rgba[:, :, :3] = rgb
    rgba[:, :, 3] = np.where(vis, 0, 255)
    img = Image.fromarray(rgba, "RGBA")
    return img.crop(img.getbbox())


def picareta_original():
    folha = Image.open(ASSETS).convert("RGB").crop(CAIXA_PICARETA)
    return tirar_fundo(np.array(folha), FUNDO_ASSETS)


def recolorir_cabeca(img, rampa):
    """Pinta só a cabeça de metal (pixels cinzentos e claros); o cabo de madeira continua igual."""
    a = np.array(img).astype(float)
    rgb = a[:, :, :3]
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    sat = (mx - mn) / np.maximum(mx, 1)
    lum = rgb.mean(axis=2)
    metal = (a[:, :, 3] > 0) & (sat < 0.22) & (lum > 55)
    # espalha o brilho da cabeça (que é escura) por toda a rampa do material
    lo, hi = np.percentile(lum[metal], [5, 97])
    niveis = np.clip(((lum - lo) / max(hi - lo, 1) * len(rampa)).astype(int), 0, len(rampa) - 1)
    rampa = np.array(rampa, float)
    a[metal, :3] = rampa[niveis[metal]]
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def chave():
    """Chave das correntes: argola, haste e dentes, em bronze envelhecido."""
    w, h = 30, 14
    cx, cy = 6.5, 6.5
    m = np.zeros((h, w), bool)
    for y in range(h):
        for x in range(w):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if 2.6 <= d <= 5.8:
                m[y, x] = True                      # argola
    m[5:9, 11:27] = True                            # haste
    m[9:12, 18:21] = True                           # dente 1
    m[9:13, 23:27] = True                           # dente 2
    m[4:10, 27:29] = True                           # ponta
    m[4:5, 13:15] = True                            # anel decorativo da haste
    m[9:10, 13:15] = True

    base, sombra, luz, brilho = (196, 136, 46), (120, 72, 22), (238, 192, 86), (255, 240, 180)
    img = np.zeros((h, w, 4), np.uint8)
    img[m] = (*base, 255)
    p = np.pad(m, 1)
    em_cima = p[:-2, 1:-1]
    a_esquerda = p[1:-1, :-2]
    em_baixo = p[2:, 1:-1]
    a_direita = p[1:-1, 2:]
    img[m & (~em_baixo | ~a_direita)] = (*sombra, 255)
    img[m & (~em_cima | ~a_esquerda) & em_baixo & a_direita] = (*luz, 255)
    for x, y in ((3, 4), (4, 3), (12, 5), (16, 5), (20, 5)):
        img[y, x] = (*brilho, 255)
    # contorno escuro de 1 pixel em volta
    perto = em_cima | em_baixo | a_esquerda | a_direita
    img[perto & ~m] = (*CONTORNO, 255)
    peq = Image.fromarray(img, "RGBA")
    out = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    out.alpha_composite(peq, (1, 1))
    o = np.array(out)
    a = o[:, :, 3] > 0
    p = np.pad(a, 1)
    borda = (p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]) & ~a
    o[borda] = (*CONTORNO, 255)
    final = Image.fromarray(o, "RGBA").resize(((w + 2) * PX, (h + 2) * PX), Image.NEAREST)
    return final.crop(final.getbbox())


# ------------------------------------------------------------------ animações
def estrela(d, x, y, tam, cor):
    """Brilho de 4 pontas na grade de pixel."""
    for i in range(-tam, tam + 1):
        d.rectangle((x + i * PX, y, x + i * PX + PX - 1, y + PX - 1), fill=cor)
        d.rectangle((x, y + i * PX, x + PX - 1, y + i * PX + PX - 1), fill=cor)


def sprites(item):
    """Monta as animações de um item. O 'pé' é o centro da sombra no chão."""
    iw, ih = item.size
    margem_x, margem_topo, chao = 24, 64, 16
    qw, qh = iw + 2 * margem_x, ih + margem_topo + chao
    pe = (qw // 2, qh - chao // 2)

    def quadro(sobe, alfa=1.0, sombra=True, brilhos=()):
        q = Image.new("RGBA", (qw, qh), (0, 0, 0, 0))
        d = ImageDraw.Draw(q)
        if sombra:
            r = max(iw // 2 - sobe // 2, iw // 4)
            d.ellipse((pe[0] - r, pe[1] - 6, pe[0] + r, pe[1] + 6), fill=(0, 0, 0, 90))
        it = item if alfa >= 1 else Image.fromarray(
            (np.array(item) * np.array([1, 1, 1, alfa])).astype(np.uint8), "RGBA")
        q.alpha_composite(it, ((qw - iw) // 2, qh - chao - ih - sobe))
        for bx, by, tam, cor in brilhos:
            estrela(d, int(qw / 2 + bx * iw / 2), int(qh - chao - ih / 2 - sobe + by * ih / 2), tam, cor)
        return q

    branco, amarelo = (255, 255, 240, 255), (255, 226, 120, 230)
    chao_anim = [
        quadro(0),
        quadro(PX, brilhos=[(-0.5, -0.6, 1, amarelo)]),
        quadro(2 * PX, brilhos=[(-0.5, -0.6, 2, branco)]),
        quadro(2 * PX, brilhos=[(0.55, -0.2, 1, amarelo)]),
        quadro(PX, brilhos=[(0.55, -0.2, 2, branco)]),
        quadro(0),
    ]
    coleta = [
        quadro(3 * PX, brilhos=[(-0.7, -0.8, 2, branco), (0.7, 0.4, 1, amarelo)]),
        quadro(6 * PX, 0.85, False, [(0.8, -0.9, 2, branco), (-0.8, 0.3, 2, amarelo)]),
        quadro(9 * PX, 0.55, False, [(-0.9, -1.1, 1, branco), (0.9, 0.6, 2, branco)]),
        quadro(12 * PX, 0.2, False, [(0.0, -1.3, 1, amarelo)]),
    ]
    anims = {"chao": (chao_anim, 6, True), "coleta": (coleta, 10, False)}
    folha = Image.new("RGBA", (qw * 6, qh * len(anims)), (0, 0, 0, 0))
    meta = {"quadro": [qw, qh], "pe": list(pe), "altura_corpo": ih, "animacoes": {}}
    for linha, (nome, (quadros, fps, repete)) in enumerate(anims.items()):
        for c, q in enumerate(quadros):
            folha.alpha_composite(q, (c * qw, linha * qh))
        meta["animacoes"][nome] = {"linha": linha, "quadros": len(quadros), "fps": fps, "repete": repete}
    return folha, meta


def salvar(nome, item, previa):
    item.save(SAIDA / f"{nome}.png")
    folha, meta = sprites(item)
    folha.save(SAIDA / f"{nome}_sprites.png")
    (SAIDA / f"{nome}_sprites.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    previa.append((nome, folha, meta))
    print(f"gerado: {nome}  ícone {item.size}  quadro {meta['quadro']}")


def gerar():
    SAIDA.mkdir(parents=True, exist_ok=True)
    previa = []
    original = picareta_original()
    for material, rampa in MATERIAIS.items():
        img = original if rampa is None else recolorir_cabeca(original, rampa)
        salvar(f"picareta_{material}", img, previa)
    salvar("chave", chave(), previa)

    # Prévia: uma linha por item, com os quadros de "chao" e "coleta"
    qw = max(m["quadro"][0] for _, _, m in previa)
    qh = max(m["quadro"][1] for _, _, m in previa)
    img = Image.new("RGB", (160 + qw * 10, qh * len(previa)), (30, 34, 46))
    d = ImageDraw.Draw(img)
    try:
        fonte = ImageFont.truetype("arialbd.ttf", 16)
    except OSError:
        fonte = ImageFont.load_default()
    for i, (nome, folha, meta) in enumerate(previa):
        w, h = meta["quadro"]
        d.text((8, i * qh + qh // 2 - 8), nome, fill=(236, 222, 186), font=fonte)
        x = 160
        for anim in ("chao", "coleta"):
            info = meta["animacoes"][anim]
            for c in range(info["quadros"]):
                q = folha.crop((c * w, info["linha"] * h, (c + 1) * w, (info["linha"] + 1) * h))
                img.paste(q, (x, i * qh), q)
                x += qw
    img.save(SAIDA / "itens_previa.png")


if __name__ == "__main__":
    gerar()
