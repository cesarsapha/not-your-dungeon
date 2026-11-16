"""Gera a pixel art dos personagens de Not your Dungeon.

Cada personagem é montado com formas simples (elipses, polígonos, linhas).
O script aplica sombra (canto inferior direito), luz (canto superior esquerdo)
e contorno escuro automaticamente.

Uso (na raiz do repositório):
    python ferramentas/gerar_pixelart.py

Saídas:
    arte/personagens/monstros/<nome>.png    sprite 1x, fundo transparente (usado pela Godot)
    arte/personagens/monstros/<nome>_8x.png ampliado 8x, para visualizar
    arte/personagens/fichas_pixelart.png    os quatro lado a lado, para o README/GDD
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
PASTA = RAIZ / "arte" / "personagens" / "monstros"


def deslocar(m, dy, dx):
    """out[y, x] = m[y + dy, x + dx] (False fora da imagem)."""
    h, w = m.shape
    out = np.zeros_like(m)
    ys, yd = (slice(dy, h), slice(0, h - dy)) if dy >= 0 else (slice(0, h + dy), slice(-dy, h))
    xs, xd = (slice(dx, w), slice(0, w - dx)) if dx >= 0 else (slice(0, w + dx), slice(-dx, w))
    out[yd, xd] = m[ys, xs]
    return out


def escurecer(cor, f=0.62):
    return tuple(int(c * f) for c in cor)


def clarear(cor, f=0.35):
    return tuple(int(c + (255 - c) * f) for c in cor)


class Sprite:
    def __init__(self, largura, altura, contorno=(22, 14, 20)):
        self.w, self.h = largura, altura
        self.rgba = np.zeros((altura, largura, 4), np.uint8)
        self.contorno = contorno

    def _mascara(self, desenho):
        im = Image.new("L", (self.w, self.h), 0)
        desenho(ImageDraw.Draw(im))
        return np.array(im) > 0

    def pintar(self, mascara, cor):
        self.rgba[mascara] = (*cor, 255)

    def parte(self, desenho, base, sombra=None, luz=None, esp=2, linha=False):
        """Desenha uma parte do corpo com sombra e luz automáticas."""
        m = self._mascara(desenho)
        sombra = sombra or escurecer(base)
        luz = luz or clarear(base)
        self.pintar(m, sombra)
        miolo = m & deslocar(m, esp, esp)
        self.pintar(miolo, base)
        borda_luz = m & ~deslocar(m, -1, -1) & miolo
        self.pintar(borda_luz, luz)
        if linha:
            vizinhos = deslocar(m, 1, 0) & deslocar(m, -1, 0) & deslocar(m, 0, 1) & deslocar(m, 0, -1)
            self.pintar(m & ~vizinhos, self.contorno)
        return m

    def elipse(self, caixa, base, **kw):
        return self.parte(lambda d: d.ellipse(caixa, fill=255), base, **kw)

    def poligono(self, pontos, base, **kw):
        return self.parte(lambda d: d.polygon(pontos, fill=255), base, **kw)

    def traco(self, pontos, cor, largura=1):
        m = self._mascara(lambda d: d.line(pontos, fill=255, width=largura))
        self.pintar(m, cor)

    def pixels(self, lista, cor):
        for x, y in lista:
            if 0 <= x < self.w and 0 <= y < self.h:
                self.rgba[y, x] = (*cor, 255)

    def finalizar(self):
        """Contorno externo de 1 pixel em volta de toda a silhueta."""
        a = self.rgba[:, :, 3] > 0
        perto = deslocar(a, 1, 0) | deslocar(a, -1, 0) | deslocar(a, 0, 1) | deslocar(a, 0, -1)
        self.pintar(perto & ~a, self.contorno)
        return Image.fromarray(self.rgba, "RGBA")


# ------------------------------------------------------------------ Spike
def spike():
    """Ogro tanque: pele laranja, manchas amarelas nos ombros, tanga e tronco."""
    s = Sprite(64, 64)
    pele = (206, 96, 44)
    s.elipse((19, 47, 30, 61), pele)                      # perna de trás
    s.elipse((34, 47, 45, 61), pele)                      # perna da frente
    s.elipse((5, 25, 19, 50), pele)                       # braço de trás
    s.elipse((11, 20, 51, 55), pele)                      # corpo
    s.elipse((20, 33, 44, 55), (222, 124, 62), esp=1)     # barriga
    s.poligono([(17, 46), (47, 46), (45, 55), (39, 52), (33, 57), (27, 52), (19, 55)], (98, 62, 44))  # tanga
    s.elipse((22, 10, 43, 30), pele, linha=True)          # cabeça baixa entre os ombros
    # tronco segurado pela mão da frente
    s.poligono([(43, 43), (48, 37), (62, 47), (58, 56)], (112, 66, 40))
    s.traco([(49, 42), (57, 48)], (84, 48, 30))           # veio da madeira
    s.elipse((55, 45, 63, 57), (214, 160, 108), esp=1)    # ponta cortada do tronco
    s.pixels([(58, 50), (59, 50), (58, 51), (59, 52), (60, 51)], (165, 112, 72))
    s.elipse((41, 27, 53, 47), pele)                      # braço da frente
    s.elipse((44, 40, 53, 49), pele)                      # mão
    # manchas amarelas (como a referência)
    manchas = [(9, 29), (13, 25), (17, 22), (11, 34), (16, 29), (21, 21), (7, 38), (45, 30), (48, 35)]
    s.pixels([(x + dx, y + dy) for x, y in manchas for dx in (0, 1) for dy in (0, 1)], (246, 192, 62))
    # rosto
    s.traco([(29, 16), (33, 17)], (120, 50, 25))           # sobrancelha
    s.pixels([(32, 18), (33, 18)], (255, 226, 96))         # olho
    s.pixels([(33, 18)], (40, 20, 10))
    s.traco([(28, 25), (39, 25)], (110, 40, 20))           # boca
    s.pixels([(30, 24), (30, 23), (37, 24), (37, 23)], (242, 236, 214))  # presas
    return s.finalizar()


# ------------------------------------------------------------------ Gordot
def gordot():
    """Orc veloz e venenoso: pele verde-azulada, chifres, colete de couro e martelo com veneno."""
    s = Sprite(64, 64)
    pele = (96, 146, 126)
    couro = (186, 120, 70)
    s.elipse((21, 45, 30, 59), pele)                       # pernas afastadas (pose de corrida)
    s.elipse((36, 45, 45, 59), pele)
    s.poligono([(18, 56), (31, 56), (31, 61), (17, 61)], (138, 84, 52))   # botas
    s.poligono([(35, 56), (47, 56), (48, 61), (35, 61)], (138, 84, 52))
    s.elipse((12, 28, 22, 46), pele)                       # braço de trás (segura o martelo)
    s.elipse((20, 25, 45, 50), pele)                       # tronco
    s.poligono([(20, 28), (28, 27), (27, 48), (21, 46)], couro)           # colete
    s.poligono([(37, 27), (45, 28), (44, 46), (38, 48)], couro)
    s.poligono([(21, 44), (44, 44), (44, 47), (21, 47)], (110, 66, 40))   # cinto
    s.elipse((30, 43, 35, 48), (222, 216, 232), esp=1)    # fivela de osso
    s.poligono([(38, 47), (42, 47), (42, 52), (38, 52)], (110, 226, 70))  # frasco de veneno
    s.pixels([(39, 46), (40, 46), (41, 46)], (90, 60, 40))
    s.elipse((42, 28, 51, 45), pele)                       # braço da frente
    s.elipse((44, 41, 52, 48), pele)
    # cabeça
    s.poligono([(25, 16), (16, 12), (26, 21)], pele)       # orelhas pontudas
    s.poligono([(39, 16), (48, 12), (38, 21)], pele)
    s.elipse((24, 10, 40, 29), pele)
    s.poligono([(26, 13), (21, 4), (24, 2), (29, 11)], (200, 194, 226))   # chifres
    s.poligono([(38, 13), (43, 4), (40, 2), (35, 11)], (200, 194, 226))
    s.traco([(27, 16), (30, 17)], (40, 70, 60))            # sobrancelhas bravas
    s.traco([(37, 16), (34, 17)], (40, 70, 60))
    s.pixels([(28, 18), (29, 18), (35, 18), (36, 18)], (232, 60, 172))    # olhos magenta
    s.traco([(28, 24), (36, 24)], (36, 50, 44))            # boca
    s.pixels([(29, 23), (35, 23)], (236, 234, 240))        # presas
    # martelo erguido com veneno escorrendo
    s.traco([(15, 44), (11, 18)], (96, 58, 36), largura=2)
    s.poligono([(2, 12), (20, 9), (22, 19), (4, 22)], (154, 148, 176))
    s.poligono([(9, 11), (14, 10), (15, 20), (10, 21)], (110, 226, 70), esp=1)  # faixa de veneno
    s.pixels([(10, 22), (10, 23), (10, 25), (14, 21), (14, 22), (14, 23), (14, 24), (6, 23), (18, 20),
              (18, 21)], (128, 236, 72))
    return s.finalizar()


# ------------------------------------------------------------------ Thyr
def thyr():
    """Mago espectral: armadura carbonizada, núcleo de fogo no peito, chama roxa na cabeça e cajado."""
    s = Sprite(64, 64)
    armadura = (72, 64, 68)
    s.poligono([(21, 41), (43, 41), (47, 58), (41, 52), (37, 61), (32, 53), (27, 61), (23, 52), (17, 58)],
               (54, 46, 52))                                # parte de baixo em farrapos (flutua)
    s.elipse((11, 29, 20, 47), armadura)                   # braço de trás
    s.poligono([(9, 45), (12, 44), (11, 52)], (236, 108, 40), esp=1)     # garras em chamas
    s.poligono([(13, 46), (16, 45), (16, 53)], (190, 62, 170), esp=1)
    s.poligono([(20, 23), (44, 23), (41, 45), (23, 45)], armadura)       # tronco
    s.elipse((13, 19, 28, 32), (86, 78, 80))               # ombreiras
    s.elipse((36, 19, 51, 32), (86, 78, 80))
    s.elipse((27, 27, 37, 37), (232, 92, 36), esp=1)       # núcleo de fogo
    s.elipse((29, 29, 35, 35), (255, 170, 52), esp=1)
    s.pixels([(31, 31), (32, 31), (31, 32), (32, 32)], (255, 240, 150))
    s.pixels([(24, 38), (25, 39), (25, 40), (39, 26), (40, 27), (22, 28), (42, 36), (41, 37)],
             (255, 116, 44))                                # rachaduras de lava
    # chama roxa saindo da cabeça
    s.poligono([(25, 15), (27, 6), (30, 11), (33, 1), (36, 10), (40, 5), (39, 15)], (150, 46, 160))
    s.poligono([(28, 14), (30, 9), (33, 5), (35, 11), (37, 14)], (222, 92, 196), esp=1)
    s.elipse((26, 11, 38, 25), (60, 52, 58))               # elmo
    s.pixels([(29, 18), (30, 18), (34, 18), (35, 18)], (255, 150, 50))   # olhos em brasa
    s.pixels([(30, 18), (34, 18)], (255, 236, 150))
    # cajado com cristal
    s.traco([(54, 14), (50, 62)], (74, 46, 60), largura=2)
    s.elipse((43, 29, 52, 45), armadura)                   # braço da frente
    s.elipse((47, 38, 55, 45), (86, 78, 80))               # mão no cajado
    s.poligono([(54, 3), (58, 9), (55, 16), (51, 9)], (110, 222, 204), esp=1)
    s.pixels([(54, 7), (54, 8)], (220, 255, 248))
    return s.finalizar()


# ------------------------------------------------------------------ Zork
def zork():
    """Chefe da masmorra: rei-sombra com coroa de chifres, olhos brancos e lança."""
    s = Sprite(80, 80, contorno=(10, 10, 14))
    escuro = (46, 46, 54)
    s.poligono([(20, 56), (62, 56), (66, 74), (58, 68), (52, 77), (46, 69), (40, 78), (34, 69), (28, 76),
                (24, 68), (16, 74)], (32, 32, 40))         # capa em farrapos
    s.elipse((28, 54, 38, 74), escuro)                     # pernas
    s.elipse((44, 54, 54, 74), escuro)
    s.elipse((14, 34, 25, 56), escuro, luz=(196, 202, 214))                     # braço da lança
    s.poligono([(24, 26), (58, 26), (54, 58), (28, 58)], escuro)        # tronco
    s.poligono([(36, 38), (46, 38), (41, 46)], (226, 232, 240), esp=1)  # placa brilhante no peito
    s.elipse((15, 23, 35, 39), (62, 62, 72), luz=(196, 202, 214))               # ombreiras
    s.elipse((47, 23, 67, 39), (62, 62, 72), luz=(196, 202, 214))
    s.pixels([(18, 26), (19, 25), (20, 25), (50, 25), (51, 25), (52, 26)], (226, 232, 240))
    s.elipse((56, 34, 67, 58), escuro, luz=(196, 202, 214))                     # braço com garras
    s.poligono([(57, 56), (59, 63), (61, 57), (63, 64), (65, 56)], (30, 30, 38), esp=1)
    # cabeça e coroa de chifres
    s.elipse((33, 13, 49, 30), (38, 38, 46), luz=(196, 202, 214))
    s.traco([(36, 15), (29, 2)], (30, 30, 38), largura=2)
    s.traco([(32, 8), (26, 6)], (30, 30, 38), largura=2)
    s.traco([(46, 15), (53, 2)], (30, 30, 38), largura=2)
    s.traco([(50, 8), (56, 6)], (30, 30, 38), largura=2)
    s.traco([(41, 13), (41, 6)], (30, 30, 38), largura=2)
    s.pixels([(37, 21), (38, 21), (44, 21), (45, 21)], (244, 248, 255))  # olhos brancos
    s.pixels([(37, 22), (45, 22)], (160, 170, 190))
    # lança
    s.traco([(11, 12), (11, 79)], (54, 50, 56), largura=2)
    s.poligono([(11, 0), (15, 7), (11, 15), (7, 7)], (210, 216, 228), esp=1)
    s.elipse((7, 46, 17, 56), escuro)                      # mão na lança
    return s.finalizar()


PERSONAGENS = [
    ("spike", spike, "SPIKE", "tanque"),
    ("gordot", gordot, "GORDOT", "veloz / veneno"),
    ("thyr", thyr, "THYR", "mago"),
    ("zork", zork, "ZORK", "chefe (NPC)"),
]


def gerar():
    PASTA.mkdir(parents=True, exist_ok=True)
    sprites = []
    for nome, funcao, titulo, papel in PERSONAGENS:
        img = funcao()
        img.save(PASTA / f"{nome}.png")
        img.resize((img.width * 8, img.height * 8), Image.NEAREST).save(PASTA / f"{nome}_8x.png")
        sprites.append((img, titulo, papel))
        print("gerado:", nome, img.size)

    # Ficha com os quatro lado a lado (escala 6x, pés alinhados)
    escala, margem, base_y = 6, 40, 80 * 6 + 40
    largura = sum(i.width * escala for i, _, _ in sprites) + margem * (len(sprites) + 1)
    ficha = Image.new("RGB", (largura, base_y + 110), (24, 22, 30))
    d = ImageDraw.Draw(ficha)
    try:
        fonte = ImageFont.truetype("arialbd.ttf", 30)
        fonte_p = ImageFont.truetype("arial.ttf", 22)
    except OSError:
        fonte = fonte_p = ImageFont.load_default()
    x = margem
    for img, titulo, papel in sprites:
        grande = img.resize((img.width * escala, img.height * escala), Image.NEAREST)
        ficha.paste(grande, (x, base_y - grande.height), grande)
        cx = x + grande.width // 2
        d.text((cx, base_y + 30), titulo, fill=(240, 226, 190), font=fonte, anchor="mm")
        d.text((cx, base_y + 68), papel, fill=(170, 160, 150), font=fonte_p, anchor="mm")
        x += grande.width + margem
    ficha.save(RAIZ / "arte" / "personagens" / "fichas_pixelart.png")
    print("gerado: fichas_pixelart.png", ficha.size)


if __name__ == "__main__":
    gerar()
