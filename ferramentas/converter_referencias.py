"""Converte as imagens de referência em sprites do jogo, com tom mais sombrio.

Etapas para cada personagem:
  1. remove o fundo (preenchimento a partir das bordas com as cores do fundo)
  2. recorta o personagem
  3. reduz para a altura do sprite escolhendo a cor mais comum de cada bloco
     (mantém o visual de pixel art, sem borrar)
  4. aplica a "gradação sombria": mais contraste, sombras puxadas para roxo/escuro,
     menos saturação nas cores claras
  5. retoques por personagem (olhos brilhando, sangue, veneno...)
  6. contorno escuro de 1 pixel

Uso (na raiz do repositório):
    python ferramentas/converter_referencias.py
"""
from collections import Counter, deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
REF = RAIZ / "arte" / "referencias"
SAIDA = RAIZ / "arte" / "personagens" / "monstros"
PREVIA = RAIZ / "arte" / "personagens" / "previas"
CONTORNO = (12, 6, 10)


# ------------------------------------------------------------------ fundo
def mascara_fundo(rgb, cores_fundo, tolerancia):
    """Pixels conectados à borda cuja cor está perto de alguma cor de fundo."""
    h, w, _ = rgb.shape
    a = rgb.astype(int)
    perto = np.zeros((h, w), bool)
    for c in cores_fundo:
        perto |= np.abs(a - np.array(c)).sum(axis=2) <= tolerancia
    fundo = np.zeros((h, w), bool)
    fila = deque()
    for x in range(w):
        for y in (0, h - 1):
            if perto[y, x] and not fundo[y, x]:
                fundo[y, x] = True
                fila.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if perto[y, x] and not fundo[y, x]:
                fundo[y, x] = True
                fila.append((y, x))
    while fila:
        y, x = fila.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and perto[ny, nx] and not fundo[ny, nx]:
                fundo[ny, nx] = True
                fila.append((ny, nx))
    return fundo


def maior_componente(m):
    """Mantém só a maior região conectada (remove sujeira solta)."""
    h, w = m.shape
    rotulo = np.zeros((h, w), int)
    atual, tamanhos = 0, {}
    for y in range(h):
        for x in range(w):
            if m[y, x] and not rotulo[y, x]:
                atual += 1
                fila, n = deque([(y, x)]), 0
                rotulo[y, x] = atual
                while fila:
                    cy, cx = fila.popleft()
                    n += 1
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and m[ny, nx] and not rotulo[ny, nx]:
                            rotulo[ny, nx] = atual
                            fila.append((ny, nx))
                tamanhos[atual] = n
    if not tamanhos:
        return m
    maior = max(tamanhos, key=tamanhos.get)
    return rotulo == maior


# ------------------------------------------------------------------ redução
def reduzir(rgb, frente, altura):
    """Reduz para `altura` pixels usando a cor mais comum de cada bloco."""
    ys, xs = np.where(frente)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgb, frente = rgb[y0:y1, x0:x1], frente[y0:y1, x0:x1]
    passo = (y1 - y0) / altura
    largura = max(1, round((x1 - x0) / passo))
    out = np.zeros((altura, largura, 4), np.uint8)
    for j in range(altura):
        for i in range(largura):
            ya, yb = int(j * passo), max(int((j + 1) * passo), int(j * passo) + 1)
            xa, xb = int(i * passo), max(int((i + 1) * passo), int(i * passo) + 1)
            bloco_m = frente[ya:yb, xa:xb]
            if bloco_m.mean() < 0.5:
                continue
            cores = rgb[ya:yb, xa:xb][bloco_m]
            # agrupa cores parecidas (JPEG tem ruído) antes de votar
            chave = [tuple(np.minimum((c.astype(int) // 12) * 12 + 6, 255)) for c in cores]
            mais_comum = Counter(chave).most_common(1)[0][0]
            out[j, i] = (*mais_comum, 255)
    return out


def limitar_paleta(rgba, n):
    a = rgba[:, :, 3] > 0
    img = Image.fromarray(rgba[:, :, :3])
    q = img.quantize(colors=n, method=Image.Quantize.MEDIANCUT).convert("RGB")
    out = rgba.copy()
    out[:, :, :3] = np.array(q)
    out[~a] = 0
    return out


# ------------------------------------------------------------------ tom sombrio
def gradacao_sombria(rgba, contraste=1.25, saturacao=0.85, tinta=(40, 10, 50), forca_tinta=0.35):
    a = rgba[:, :, 3] > 0
    c = rgba[:, :, :3].astype(float) / 255
    lum = (0.299 * c[..., 0] + 0.587 * c[..., 1] + 0.114 * c[..., 2])[..., None]
    c = lum + (c - lum) * saturacao                     # tira um pouco da cor "alegre"
    c = (c - 0.5) * contraste + 0.45                     # mais contraste, puxado para o escuro
    sombra = np.clip(1 - lum * 1.8, 0, 1)                # quanto mais escuro, mais tinta
    c = c * (1 - sombra * forca_tinta) + np.array(tinta) / 255 * sombra * forca_tinta
    out = rgba.copy()
    out[:, :, :3] = (np.clip(c, 0, 1) * 255).astype(np.uint8)
    out[~a] = 0
    return out


def contornar(rgba):
    a = rgba[:, :, 3] > 0
    h, w = a.shape
    p = np.pad(a, 1)
    perto = p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]
    out = np.pad(rgba, ((1, 1), (1, 1), (0, 0)))
    borda = np.pad(perto & ~a, 1)
    out[borda] = (*CONTORNO, 255)
    return out


def pintar(rgba, pontos, cor):
    for x, y in pontos:
        if 0 <= y < rgba.shape[0] and 0 <= x < rgba.shape[1]:
            rgba[y, x] = (*cor, 255)


def brilho(rgba, centro, cor, raio=2):
    """Halo de brilho (olhos, núcleo) somado por cima."""
    cx, cy = centro
    h, w = rgba.shape[:2]
    for y in range(max(0, cy - raio), min(h, cy + raio + 1)):
        for x in range(max(0, cx - raio), min(w, cx + raio + 1)):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= raio and rgba[y, x, 3]:
                f = 1 - d / (raio + 0.5)
                rgba[y, x, :3] = np.clip(rgba[y, x, :3] * (1 - f) + np.array(cor) * f, 0, 255)


# ------------------------------------------------------------------ personagens
def carregar(nome_arquivo):
    return np.array(Image.open(REF / nome_arquivo).convert("RGB"))


def recortar(rgb, cores_fundo, tolerancia, corte_y=None):
    frente = ~mascara_fundo(rgb, cores_fundo, tolerancia)
    if corte_y is not None:
        frente[int(corte_y):] = False
    return maior_componente(frente)


def abrir_mascara(m, r=1):
    """Abertura morfológica: remove linhas finas de 1 pixel soltas."""
    h, w = m.shape
    p = np.pad(m, r)
    e = np.ones_like(m)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            e &= p[r + dy:r + dy + h, r + dx:r + dx + w]
    p = np.pad(e, r)
    d = np.zeros_like(m)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            d |= p[r + dy:r + dy + h, r + dx:r + dx + w]
    return d


def componentes_grandes(m, minimo):
    """Mantém todas as regiões conectadas com pelo menos `minimo` pixels."""
    resto, out = m.copy(), np.zeros_like(m)
    while resto.any():
        c = maior_componente(resto)
        if c.sum() < minimo:
            break
        out |= c
        resto &= ~c
    return out


def recorte_spike():
    rgb = carregar("spike/spike_referencia.png")
    return rgb, recortar(rgb, [(75, 84, 99), (109, 117, 140), (255, 255, 255)], 40)


def recorte_gordot():
    rgb = carregar("gordot/gordot_referencia.jpg")
    m = np.abs(rgb.astype(int) - [152, 146, 132]).sum(axis=2) > 36   # fundo liso: remove em toda a imagem
    return rgb, maior_componente(m)


def recorte_thyr():
    rgb = carregar("thyr/thyr_referencia.png")
    fundo = [(51, 66, 87), (37, 52, 75), (12, 16, 40), (150, 215, 205), (120, 190, 185)]
    return rgb, maior_componente(abrir_mascara(~mascara_fundo(rgb, fundo, 45)))


def recorte_zork():
    rgb = carregar("zork/zork_referencia.png")
    fundo = [(70, 70, 70), (90, 90, 90), (110, 110, 110), (130, 130, 130), (55, 55, 55)]
    frente = ~mascara_fundo(rgb, fundo, 30)
    frente[288:] = False                                   # tira o chão
    frente = componentes_grandes(frente, 150)              # a coroa flutua separada do corpo
    # descarta restos de chão/névoa: regiões que só existem na parte de baixo
    resto, final = frente.copy(), np.zeros_like(frente)
    while resto.any():
        c = maior_componente(resto)
        if np.where(c)[0].min() < 240:
            final |= c
        resto &= ~c
    return rgb, final


# ------------------------------------------------------------------ recoloração
def hsv_ajuste(rgba, matiz=0.0, sat=1.0, val=1.0, filtro=None):
    """Ajusta matiz (graus), saturação e brilho; `filtro(h, s, v)` escolhe quais pixels mudam."""
    a = rgba[:, :, 3] > 0
    img = Image.fromarray(rgba[:, :, :3]).convert("HSV")
    hsv = np.array(img).astype(float)
    h, s, v = hsv[..., 0] * 360 / 255, hsv[..., 1] / 255, hsv[..., 2] / 255
    sel = a if filtro is None else a & filtro(h, s, v)
    h2 = np.where(sel, (h + matiz) % 360, h)
    s2 = np.where(sel, np.clip(s * sat, 0, 1), s)
    v2 = np.where(sel, np.clip(v * val, 0, 1), v)
    novo = np.stack([h2 * 255 / 360, s2 * 255, v2 * 255], -1).astype(np.uint8)
    out = rgba.copy()
    out[:, :, :3] = np.array(Image.fromarray(novo, "HSV").convert("RGB"))
    out[~a] = 0
    return out


# ------------------------------------------------------------------ cada personagem
SANGUE = (150, 12, 20)
SANGUE_ESCURO = (90, 6, 14)
VENENO = (118, 226, 58)
VENENO_CLARO = (196, 255, 120)


def spike():
    """Ogro tanque: pele vermelho-sangue, manchas de pus, olho em brasa, sangue nas presas e no tronco."""
    rgb, m = recorte_spike()
    s = reduzir(rgb, m, 64)
    s = hsv_ajuste(s, -14, 1.05, 0.72, lambda h, sa, v: (h > 5) & (h < 45) & (sa > 0.45))
    s = gradacao_sombria(s, 1.2, 0.9, (50, 8, 20), 0.45)
    # manchas amarelas -> pus esverdeado
    s = hsv_ajuste(s, 22, 0.75, 0.8, lambda h, sa, v: (h > 40) & (h < 70) & (v > 0.7))
    # presas amareladas e sujas de sangue
    # presas pontudas saindo de uma boca escura
    pintar(s, [(x, y) for y in range(10, 14) for x in (28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38)], (46, 6, 12))
    osso, osso_sombra = (222, 204, 150), (160, 132, 92)
    pintar(s, [(28, 13), (29, 13), (30, 13), (31, 13), (29, 12), (30, 12), (29, 11), (30, 11), (29, 10)], osso)
    pintar(s, [(36, 13), (37, 13), (38, 13), (37, 12), (38, 12), (37, 11), (38, 11), (38, 10)], osso)
    pintar(s, [(31, 13), (30, 12), (38, 13)], osso_sombra)
    pintar(s, [(32, 13), (33, 13), (34, 13), (35, 13)], (120, 14, 22))          # língua/gengiva
    pintar(s, [(29, 14), (29, 15), (30, 14), (37, 14), (37, 15), (37, 16)], SANGUE)
    pintar(s, [(29, 16), (37, 17)], SANGUE_ESCURO)
    # olho vermelho em brasa
    brilho(s, (30, 7), (255, 40, 30), raio=2)
    pintar(s, [(30, 7), (31, 7)], (255, 120, 90))
    # sangue na ponta do tronco
    pintar(s, [(70, 45), (71, 46), (72, 44), (69, 48), (73, 49), (71, 50), (74, 46), (68, 52)], SANGUE)
    pintar(s, [(72, 47), (70, 51), (73, 52), (75, 50)], SANGUE_ESCURO)
    return contornar(s)


def gordot():
    """Orc veloz: verde doentio, couro escuro, olhos magenta brilhando e martelo pingando veneno."""
    rgb, m = recorte_gordot()
    s = reduzir(rgb, m, 64)
    s = hsv_ajuste(s, -38, 1.1, 0.72, lambda h, sa, v: (h > 110) & (h < 200))
    s = gradacao_sombria(s, 1.25, 0.85, (20, 30, 10), 0.4)
    # couro do colete e botas mais gasto e escuro
    s = hsv_ajuste(s, -6, 0.8, 0.62, lambda h, sa, v: (h > 15) & (h < 50) & (sa > 0.25) & (v > 0.45))
    # cabeça do martelo: metal frio e sujo
    regiao = np.zeros(s.shape[:2], bool)
    regiao[10:30, 0:24] = True
    claro = (s[:, :, :3].astype(int).sum(axis=2) > 400) & regiao
    s[claro, :3] = (s[claro, :3] * np.array([0.62, 0.66, 0.6])).astype(np.uint8)
    # veneno escorrendo da cabeça do martelo
    # metade de baixo da cabeça do martelo coberta de veneno
    for y in range(19, 24):
        for x in range(2, 23):
            if s[y, x, 3] and int(s[y, x, :3].astype(int).sum()) > 150:
                s[y, x, :3] = (70, 150, 36) if (x + y) % 3 else VENENO
    # gotas escorrendo a partir do metal
    for x, comprimento in ((4, 6), (8, 9), (12, 4), (16, 8), (20, 3)):
        pintar(s, [(x, 23 + i) for i in range(comprimento)], VENENO)
        pintar(s, [(x, 23 + comprimento)], VENENO_CLARO)
        pintar(s, [(x + 1, 23)], VENENO)
    # olhos magenta em brasa
    brilho(s, (34, 11), (255, 40, 200), raio=2)
    brilho(s, (41, 11), (255, 40, 200), raio=2)
    pintar(s, [(34, 11), (41, 11)], (255, 170, 240))
    return contornar(s)


def thyr():
    """Espectro mago: já é sombrio; só reforça contraste e o brilho do núcleo."""
    rgb, m = recorte_thyr()
    s = reduzir(rgb, m, 80)
    s = gradacao_sombria(s, 1.15, 1.0, (30, 5, 40), 0.25)
    return contornar(s)


def zork():
    """Rei-sombra: preto e cinza com brilhos brancos, levemente azulado."""
    rgb, m = recorte_zork()
    s = reduzir(rgb, m, 96)
    s = gradacao_sombria(s, 1.1, 1.0, (10, 10, 25), 0.2)
    # luz de recorte fria no alto/esquerda da silhueta, para a coroa não sumir no fundo escuro
    a = s[:, :, 3] > 0
    borda = a & ~np.pad(a, ((1, 0), (1, 0)))[:-1, :-1]
    s[borda, :3] = np.maximum(s[borda, :3], np.array([78, 82, 104], np.uint8))
    return contornar(s)


PERSONAGENS = [
    ("spike", spike, "SPIKE", "tanque"),
    ("gordot", gordot, "GORDOT", "veloz / veneno"),
    ("thyr", thyr, "THYR", "mago"),
    ("zork", zork, "ZORK", "chefe (NPC)"),
]


def gerar():
    SAIDA.mkdir(parents=True, exist_ok=True)
    sprites = []
    for nome, funcao, titulo, papel in PERSONAGENS:
        img = Image.fromarray(funcao(), "RGBA")
        img.save(SAIDA / f"{nome}.png")
        img.resize((img.width * 8, img.height * 8), Image.NEAREST).save(SAIDA / f"{nome}_8x.png")
        sprites.append((img, titulo, papel))
        print("gerado:", nome, img.size)

    # Ficha com os quatro lado a lado, pés alinhados, escala 5x
    escala, margem = 5, 50
    alto = max(i.height for i, _, _ in sprites) * escala
    largura = sum(i.width * escala for i, _, _ in sprites) + margem * (len(sprites) + 1)
    ficha = Image.new("RGB", (largura, alto + margem + 110), (14, 11, 16))
    d = ImageDraw.Draw(ficha)
    try:
        fonte = ImageFont.truetype("arialbd.ttf", 30)
        fonte_p = ImageFont.truetype("arial.ttf", 22)
    except OSError:
        fonte = fonte_p = ImageFont.load_default()
    x, base_y = margem, alto + margem
    for img, titulo, papel in sprites:
        grande = img.resize((img.width * escala, img.height * escala), Image.NEAREST)
        ficha.paste(grande, (x, base_y - grande.height), grande)
        cx = x + grande.width // 2
        d.text((cx, base_y + 35), titulo, fill=(220, 200, 170), font=fonte, anchor="mm")
        d.text((cx, base_y + 72), papel, fill=(150, 130, 130), font=fonte_p, anchor="mm")
        x += grande.width + margem
    ficha.save(RAIZ / "arte" / "personagens" / "fichas_pixelart.png")
    print("gerado: fichas_pixelart.png", ficha.size)


if __name__ == "__main__":
    gerar()
