"""Gera as folhas de animação (sprite sheets) dos personagens a partir da folha de modelos.

Cada personagem tem 3 poses desenhadas pela equipe (parado, ataque e ação/habilidade).
Os quadros das animações são montados a partir dessas poses com respiração, inclinação,
deslocamento, rotação, piscadas de cor e efeitos (rastro, impacto, fogo, veneno, poeira).
As poses em si não são redesenhadas.

Saídas, para cada personagem:
    arte/personagens/monstros/<nome>_sprites.png   folha usada pelo jogo (fundo transparente)
    arte/personagens/monstros/<nome>_sprites.json  quadros por animação, fps e posição do pé
    arte/personagens/folhas/<nome>_folha.png       folha de apresentação com nomes das animações
    arte/personagens/folhas/<nome>.gif             prévia animada

Uso (na raiz do repositório):
    python ferramentas/gerar_animacoes.py
"""
import json
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from recortar_modelos import FOLHA, FUNDO, recortar

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "arte" / "personagens" / "monstros"
FOLHAS = RAIZ / "arte" / "personagens" / "folhas"

PX = 4                      # tamanho do "pixel" dos modelos; efeitos usam a mesma grade
TRABALHO = (1100, 800)      # tela de trabalho onde cada quadro é montado
PE = (550, 640)             # posição do pé (centro da sombra) na tela de trabalho

# Área de cada pose na folha (x0, y0, x1, y1): [parado, ataque, ação]
AREAS = {
    "gordot": [(0, 0, 385, 270), (385, 0, 710, 270), (710, 0, 1024, 270)],
    "spike": [(0, 270, 385, 516), (385, 270, 710, 520), (710, 270, 1024, 520)],
    "thyr": [(0, 516, 385, 746), (385, 520, 710, 766), (710, 520, 1024, 766)],
    "zork": [(0, 746, 385, 1024), (385, 766, 710, 1024), (710, 766, 1024, 1024)],
}
APAGAR = {"zork": [(0, 744, 250, 759)]}

# Paletas dos efeitos
BRANCO = [(250, 250, 255), (205, 215, 235), (150, 160, 190)]
FOGO = [(255, 244, 160), (255, 186, 52), (240, 96, 28), (168, 40, 26)]
VENENO = [(200, 255, 130), (120, 224, 60), (60, 140, 40)]
POEIRA = [(222, 204, 172), (182, 162, 136), (130, 116, 100)]
SANGUE = [(232, 52, 44), (160, 20, 26)]
SOMBRA = [(150, 110, 220), (90, 60, 150), (40, 26, 70)]


# ------------------------------------------------------------------ poses
class Pose:
    """Pose recortada, com o pé (centro da sombra no chão) como ponto de apoio."""

    def __init__(self, img):
        self.img = img
        a = np.array(img)[:, :, 3] > 0
        ys, xs = np.where(a)
        self.base = ys.max()
        perto_chao = a[max(self.base - 10, 0):self.base + 1]
        cols = np.where(perto_chao.any(axis=0))[0]
        self.pe_x = int((cols.min() + cols.max()) / 2)
        self.topo = ys.min()
        self.altura = self.base - self.topo
        # ponta da arma: ponto mais à direita na metade de cima do corpo
        cima = a[: self.topo + int(self.altura * 0.75)]
        cy, cx = np.where(cima)
        i = cx.argmax()
        self.ponta = (int(cx[i]) - self.pe_x, int(cy[i]) - self.base)


def carregar_poses(nome):
    folha = np.array(Image.open(FOLHA).convert("RGB"))
    poses = []
    for area in AREAS[nome]:
        apagar = [r for r in APAGAR.get(nome, []) if r[1] < area[3] and r[3] > area[1] and r[0] < area[2]]
        poses.append(Pose(recortar(folha, area, apagar)))
    return poses


# ------------------------------------------------------------------ transformações
def tela():
    return Image.new("RGBA", TRABALHO, (0, 0, 0, 0))


def colocar(pose, dx=0, dy=0, img=None):
    t = tela()
    img = img or pose.img
    t.alpha_composite(img, (PE[0] - pose.pe_x + dx, PE[1] - pose.base + dy))
    return t


def respirar(pose, k):
    """Estica o tronco para cima `k` pixels, mantendo pernas e pés no lugar."""
    if k == 0:
        return pose.img
    img = pose.img
    corte = pose.topo + int(pose.altura * 0.62)
    cima = img.crop((0, 0, img.width, corte))
    cima = cima.resize((img.width, corte + k), Image.NEAREST)
    novo = Image.new("RGBA", (img.width, img.height + k), (0, 0, 0, 0))
    novo.alpha_composite(cima, (0, 0))
    novo.alpha_composite(img.crop((0, corte, img.width, img.height)), (0, corte + k))
    # devolve com o mesmo pé: desloca para que a base continue no mesmo lugar
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(novo.crop((0, k, img.width, img.height + k)), (0, 0))
    return out


def inclinar(img, s, base_y, a_partir_de=None):
    """Cisalha a imagem: o topo vai para a direita se s > 0. Abaixo de `a_partir_de` nada muda."""
    w, h = img.size
    ref = base_y if a_partir_de is None else a_partir_de
    if a_partir_de is None:
        return img.transform((w, h), Image.AFFINE, (1, -s, s * ref, 0, 1, 0), Image.NEAREST)
    cima = img.crop((0, 0, w, a_partir_de))
    baixo = img.crop((0, a_partir_de, w, h))
    baixo = baixo.transform(baixo.size, Image.AFFINE, (1, -s, 0, 0, 1, 0), Image.NEAREST)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(cima, (0, 0))
    out.alpha_composite(baixo, (0, a_partir_de))
    return out


def girar(quadro, graus):
    """Gira o quadro inteiro em volta do pé (positivo = cai para trás, à esquerda)."""
    return quadro.rotate(graus, resample=Image.NEAREST, center=PE)


def achatar(img, base_y, fator):
    """Agacha: comprime na vertical mantendo a base."""
    w, h = img.size
    nh = max(1, int(base_y * fator))
    cima = img.crop((0, 0, w, base_y)).resize((w, nh), Image.NEAREST)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(cima, (0, base_y - nh))
    out.alpha_composite(img.crop((0, base_y, w, h)), (0, base_y))
    return out


def tingir(quadro, cor, f):
    a = np.array(quadro).astype(float)
    m = a[:, :, 3] > 0
    a[m, :3] = a[m, :3] * (1 - f) + np.array(cor) * f
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def transparencia(quadro, f):
    a = np.array(quadro)
    a[:, :, 3] = (a[:, :, 3] * f).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def contorno_brilho(quadro, cor, espessura=PX):
    """Contorno colorido em volta da silhueta (brilho de defesa/aura)."""
    a = np.array(quadro)[:, :, 3] > 0
    perto = a.copy()
    for _ in range(espessura):
        p = np.pad(perto, 1)
        perto = p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]
    borda = perto & ~a
    out = np.array(quadro)
    out[borda] = (*cor, 200)
    return Image.fromarray(out, "RGBA")


def rastro(pose, dx_lista, img=None, cor=(200, 210, 255)):
    """Cópias fantasmas atrás do golpe (sensação de velocidade)."""
    t = tela()
    for i, dx in enumerate(dx_lista):
        fantasma = transparencia(tingir(colocar(pose, dx, img=img), cor, 0.6), 0.22 + 0.12 * i)
        t.alpha_composite(fantasma)
    return t


# ------------------------------------------------------------------ efeitos em grade de pixel
class Efeito:
    """Camada desenhada numa grade de PX pixels, depois ampliada (fica com cara de pixel art)."""

    def __init__(self):
        self.img = Image.new("RGBA", (TRABALHO[0] // PX, TRABALHO[1] // PX), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def p(self, xy):
        return (xy[0] // PX, xy[1] // PX)

    def ponto(self, xy, cor, tam=1):
        x, y = self.p(xy)
        self.d.rectangle((x, y, x + tam - 1, y + tam - 1), fill=(*cor[:3], cor[3] if len(cor) > 3 else 255))

    def arco(self, centro, raio, ini, fim, cor, largura=2):
        cx, cy = self.p(centro)
        r = raio // PX
        self.d.arc((cx - r, cy - r, cx + r, cy + r), ini, fim, fill=cor, width=largura)

    def elipse(self, centro, rx, ry, cor, largura=1):
        cx, cy = self.p(centro)
        self.d.ellipse((cx - rx // PX, cy - ry // PX, cx + rx // PX, cy + ry // PX), outline=cor, width=largura)

    def circulo(self, centro, r, cor):
        cx, cy = self.p(centro)
        r = max(1, r // PX)
        self.d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=cor)

    def aplicar(self, quadro, por_cima=True):
        grande = self.img.resize(TRABALHO, Image.NEAREST)
        if por_cima:
            quadro.alpha_composite(grande)
            return quadro
        grande.alpha_composite(quadro)
        return grande


def ponto_mundo(pose, dx=0, dy=0, rel=None):
    rx, ry = rel if rel else pose.ponta
    return (PE[0] + rx + dx, PE[1] + ry + dy)


def efeito_corte(quadro, centro, raio, t, paleta=BRANCO):
    """Arco de corte (como o rastro de lâmina do exemplo)."""
    e = Efeito()
    abertura = int(40 + 100 * t)
    for i, cor in enumerate(paleta):
        e.arco(centro, raio - i * PX * 2, -60, -60 + abertura, cor, largura=3 - i if i < 3 else 1)
    return e.aplicar(quadro)


def efeito_linhas_velocidade(quadro, centro, comprimento, cor=(220, 225, 255)):
    e = Efeito()
    rnd = random.Random(7)
    for i in range(6):
        y = centro[1] - 40 + i * 16 + rnd.randint(-4, 4)
        x0 = centro[0] - comprimento - rnd.randint(0, 40)
        for x in range(x0, centro[0] - 30, PX * 2):
            e.ponto((x, y), (*cor, 170))
    return e.aplicar(quadro)


def efeito_impacto(quadro, centro, t, paleta=BRANCO):
    e = Efeito()
    raio = int(16 + 40 * t)
    for ang in range(0, 360, 45):
        r0, r1 = raio * 0.4, raio
        for k in range(4):
            f = r0 + (r1 - r0) * k / 3
            x = centro[0] + int(math.cos(math.radians(ang)) * f)
            y = centro[1] + int(math.sin(math.radians(ang)) * f)
            e.ponto((x, y), paleta[min(k // 2, len(paleta) - 1)])
    e.circulo(centro, int(10 * (1 - t)) + PX, paleta[0])
    return e.aplicar(quadro)


def efeito_poeira(quadro, centro, t, tamanho=1.0, semente=3):
    e = Efeito()
    rnd = random.Random(semente)
    for i in range(9):
        ang = rnd.uniform(math.pi, 2 * math.pi)
        dist = (20 + 60 * t) * tamanho * rnd.uniform(0.5, 1.2)
        x = centro[0] + int(math.cos(ang) * dist * 1.6)
        y = centro[1] + int(math.sin(ang) * dist * 0.7)
        r = int((10 + 18 * t) * tamanho * rnd.uniform(0.6, 1.1))
        cor = POEIRA[min(int(t * 3), 2)]
        e.circulo((x, y), r, (*cor, int(230 * (1 - t * 0.6))))
    return e.aplicar(quadro)


def efeito_nuvem_derrota(quadro, centro, t):
    """Nuvem de poeira que cobre o corpo (como o último quadro do exemplo)."""
    e = Efeito()
    rnd = random.Random(11)
    for i in range(14):
        x = centro[0] + rnd.randint(-70, 70)
        y = centro[1] - rnd.randint(0, 110) * t
        r = int(rnd.randint(14, 30) * (0.6 + t))
        cor = POEIRA[rnd.randint(0, 1)]
        e.circulo((int(x), int(y)), r, (*cor, int(255 * (1.15 - t))))
    return e.aplicar(quadro)


def efeito_fogo(quadro, origem, direcao, t, alcance=180, largura=60, semente=5):
    """Jato de fogo em cone, de `origem` na `direcao` (graus, 0 = direita)."""
    e = Efeito()
    rnd = random.Random(semente)
    for i in range(70):
        f = rnd.random() ** 0.7 * t
        ang = math.radians(direcao + rnd.uniform(-1, 1) * 18 * (0.4 + f))
        dist = alcance * f
        x = origem[0] + math.cos(ang) * dist
        y = origem[1] + math.sin(ang) * dist + rnd.uniform(-1, 1) * largura * f * 0.5
        cor = FOGO[min(int(f * 4 + rnd.random()), 3)]
        e.ponto((int(x), int(y)), cor, tam=rnd.choice((1, 2, 2, 3)))
    return e.aplicar(quadro)


def efeito_brasas(quadro, centro, t, quantidade=26, raio=120, semente=9, paleta=FOGO):
    """Fagulhas subindo em volta do personagem."""
    e = Efeito()
    rnd = random.Random(semente)
    for i in range(quantidade):
        x = centro[0] + rnd.uniform(-raio, raio)
        y = centro[1] - rnd.uniform(0, raio * 1.6) - t * 60 * rnd.uniform(0.5, 1.5)
        e.ponto((int(x), int(y)), paleta[rnd.randint(0, len(paleta) - 1)], tam=rnd.choice((1, 1, 2)))
    return e.aplicar(quadro)


def efeito_anel(quadro, centro, t, paleta, achatado=0.35):
    """Onda de choque/aura se expandindo no chão."""
    e = Efeito()
    rx = int(40 + 170 * t)
    for i, cor in enumerate(paleta[:2]):
        e.elipse(centro, rx - i * PX * 3, int((rx - i * PX * 3) * achatado), (*cor, int(255 * (1 - t * 0.7))), largura=2)
    return e.aplicar(quadro)


def efeito_gotas(quadro, centro, t, semente=4, paleta=VENENO, quantidade=10):
    e = Efeito()
    rnd = random.Random(semente)
    for i in range(quantidade):
        x = centro[0] + rnd.randint(-50, 50)
        y = centro[1] + rnd.randint(-30, 10) + int(t * rnd.randint(30, 70))
        e.ponto((x, y), paleta[1])
        e.ponto((x, y + PX), paleta[1])
        e.ponto((x, y + 2 * PX), paleta[0])
    return e.aplicar(quadro)


# ------------------------------------------------------------------ animações comuns
def anim_parado(p0, extra=None):
    quadros = []
    for i, k in enumerate((0, PX // 2, PX, PX, PX // 2, 0)):
        q = colocar(p0, img=respirar(p0, k))
        quadros.append(extra(q, i / 5) if extra else q)
    return quadros


def anim_andar(p0, extra=None):
    quadros = []
    quadril = p0.topo + int(p0.altura * 0.66)
    for i in range(8):
        fase = i / 8 * 2 * math.pi
        passo = math.sin(fase) * 0.32
        pulo = -int(abs(math.sin(fase)) * PX * 1.5)
        img = inclinar(p0.img, passo, p0.base, a_partir_de=quadril)
        img = inclinar(img, 0.03, p0.base)
        q = colocar(p0, 0, pulo, img=img)
        quadros.append(extra(q, i / 7) if extra else q)
    return quadros


def anim_defesa(p0, cor=(140, 190, 255)):
    quadros = []
    for i, (s, ag) in enumerate(((0, 1.0), (-0.04, 0.97), (-0.07, 0.94), (-0.07, 0.94), (-0.03, 0.97))):
        img = achatar(inclinar(p0.img, s, p0.base), p0.base, ag)
        q = colocar(p0, -PX * (1 if i in (2, 3) else 0), img=img)
        if i in (2, 3):
            q = contorno_brilho(q, cor, espessura=PX if i == 2 else PX // 2)
            q = tingir(q, cor, 0.12)
        quadros.append(q)
    return quadros


def anim_dano(p0):
    return [
        tingir(colocar(p0, -PX * 3), (255, 255, 255), 0.85),
        tingir(colocar(p0, -PX * 2), (230, 40, 40), 0.45),
        tingir(colocar(p0, -PX), (230, 40, 40), 0.2),
        colocar(p0),
    ]


def anim_derrota(p0):
    quadros = []
    for ang, f in ((0, 1.0), (8, 1.0), (24, 1.0), (50, 1.0), (78, 0.9), (88, 0.6)):
        q = girar(colocar(p0), ang)
        # ao girar, parte do corpo passa da linha do chão: sobe até encostar nela
        baixo = q.getbbox()[3]
        if baixo > PE[1] + PX:
            subido = tela()
            subido.alpha_composite(q, (0, PE[1] + PX - baixo))
            q = subido
        q = tingir(q, (40, 20, 30), 0.25 * (ang / 88))
        quadros.append(transparencia(q, f))
    corpo = quadros[-1]
    alvo = (PE[0] - int(p0.altura * 0.45), PE[1] - 30)
    quadros.append(efeito_nuvem_derrota(transparencia(corpo, 0.35), alvo, 0.4))
    quadros.append(efeito_nuvem_derrota(tela(), alvo, 0.9))
    return quadros


# ------------------------------------------------------------------ personagens
def golpe_basico(p0, p1, preparo=None, cor_corte=BRANCO):
    """Parado -> recua -> (preparo) -> golpe com rastro -> impacto -> volta."""
    ponta = ponto_mundo(p1)
    q = [colocar(p0), colocar(p0, -PX, img=inclinar(p0.img, -0.06, p0.base))]
    if preparo is not None:
        q.append(colocar(preparo, -PX))
    golpe = rastro(p1, [-90, -60, -30])
    golpe.alpha_composite(colocar(p1))
    golpe = efeito_linhas_velocidade(golpe, ponta, 120)
    q.append(efeito_corte(golpe, (ponta[0] - 40, ponta[1] + 20), 90, 0.5, cor_corte))
    q.append(efeito_impacto(efeito_corte(colocar(p1), (ponta[0] - 40, ponta[1] + 20), 90, 1.0, cor_corte), ponta, 0.3))
    q.append(efeito_impacto(colocar(p1), ponta, 0.9))
    q.append(colocar(p1, -PX))
    q.append(colocar(p0))
    return q


def spike(p0, p1, p2):
    chao_tronco = ponto_mundo(p1, dy=40)
    ataque = golpe_basico(p0, p1, preparo=p2)
    ataque[5] = efeito_poeira(ataque[5], (chao_tronco[0], PE[1]), 0.3, 0.8)
    ataque[6] = efeito_poeira(ataque[6], (chao_tronco[0], PE[1]), 0.8, 0.8)
    # Muralha de Tronco: ergue o tronco e ruge, aura vermelha pulsando no chão
    hab = [colocar(p0), colocar(p2, -PX)]
    for i, t in enumerate((0.15, 0.4, 0.65, 0.9)):
        q = colocar(p2, PX if i % 2 else -PX)
        q = tingir(q, SANGUE[0], 0.18 if i % 2 == 0 else 0.06)
        q = efeito_anel(q, PE, t, SANGUE)
        hab.append(q)
    hab.append(colocar(p0))
    return {"parado": anim_parado(p0), "andar": anim_andar(p0), "ataque": ataque, "habilidade": hab,
            "defesa": anim_defesa(p0), "dano": anim_dano(p0), "derrota": anim_derrota(p0)}


def gordot(p0, p1, p2):
    ataque = golpe_basico(p0, p1, preparo=p2)
    # Machadada Venenosa: machado brilha verde, golpe com rastro verde e respingo de veneno
    ponta = ponto_mundo(p1)
    alto = ponto_mundo(p2)
    hab = [colocar(p0)]
    for t in (0.3, 0.7):
        q = contorno_brilho(colocar(p2), VENENO[1], espessura=PX // 2)
        q = efeito_brasas(q, (alto[0], alto[1] + 60), t, quantidade=14, raio=40, paleta=VENENO)
        hab.append(q)
    golpe = rastro(p1, [-90, -60, -30], cor=VENENO[1])
    golpe.alpha_composite(colocar(p1))
    hab.append(efeito_corte(golpe, (ponta[0] - 40, ponta[1] + 20), 90, 0.6, VENENO))
    hab.append(efeito_gotas(efeito_impacto(colocar(p1), ponta, 0.4, VENENO), ponta, 0.2))
    hab.append(efeito_gotas(colocar(p1), ponta, 0.7))
    hab.append(colocar(p0))
    return {"parado": anim_parado(p0), "andar": anim_andar(p0), "ataque": ataque, "habilidade": hab,
            "defesa": anim_defesa(p0), "dano": anim_dano(p0), "derrota": anim_derrota(p0)}


def thyr(p0, p1, p2):
    cabeca = (PE[0] + p0.pe_x - p0.pe_x, PE[1] - p0.altura + 30)

    def chama_viva(q, t):
        return efeito_brasas(q, (cabeca[0], cabeca[1] + 20), t, quantidade=8, raio=24, semente=int(t * 10))

    ponta = ponto_mundo(p1)
    ataque = [colocar(p0), colocar(p0, -PX, img=inclinar(p0.img, -0.06, p0.base)), colocar(p1, -PX)]
    for t in (0.35, 0.7, 1.0, 0.6):
        ataque.append(efeito_fogo(colocar(p1), ponta, 0, t, alcance=220, semente=int(t * 100)))
    ataque.append(colocar(p0))
    # Chama do Núcleo: fogo sobe em volta e explode em um anel
    hab = [colocar(p0)]
    for i, t in enumerate((0.2, 0.45, 0.7, 1.0)):
        q = tingir(colocar(p2), FOGO[0], 0.03 * (i + 1))
        q = efeito_brasas(q, (PE[0], PE[1] - 20), t, quantidade=40, raio=110, semente=20 + i)
        if i >= 2:
            q = efeito_anel(q, PE, t, FOGO)
        hab.append(q)
    hab.append(colocar(p0))
    return {"parado": anim_parado(p0, chama_viva), "andar": anim_andar(p0, chama_viva), "ataque": ataque,
            "habilidade": hab, "defesa": anim_defesa(p0, cor=FOGO[1]), "dano": anim_dano(p0),
            "derrota": anim_derrota(p0)}


def zork(p0, p1, p2):
    ataque = golpe_basico(p0, p1)
    # Salto com a lança: agacha, sobe, cai cravando a lança, onda de choque
    hab = [colocar(p0), colocar(p0, img=achatar(p0.img, p0.base, 0.9))]
    for dy in (-40, -90, -60):
        q = colocar(p2, 20, dy)
        q = efeito_brasas(q, (PE[0], PE[1] + dy - 60), 0.5, quantidade=12, raio=70, paleta=SOMBRA)
        hab.append(q)
    impacto = efeito_anel(colocar(p1), PE, 0.3, SOMBRA)
    hab.append(efeito_poeira(impacto, (PE[0] + 60, PE[1]), 0.4, 1.2))
    hab.append(efeito_poeira(efeito_anel(colocar(p1), PE, 0.8, SOMBRA), (PE[0] + 60, PE[1]), 0.9, 1.2))
    hab.append(colocar(p0))
    return {"parado": anim_parado(p0), "andar": anim_andar(p0), "ataque": ataque, "habilidade": hab,
            "defesa": anim_defesa(p0, cor=SOMBRA[0]), "dano": anim_dano(p0), "derrota": anim_derrota(p0)}


PERSONAGENS = {"gordot": gordot, "spike": spike, "thyr": thyr, "zork": zork}
ORDEM = ["parado", "andar", "ataque", "habilidade", "defesa", "dano", "derrota"]
FPS = {"parado": 6, "andar": 10, "ataque": 12, "habilidade": 10, "defesa": 10, "dano": 12, "derrota": 8}
REPETE = {"parado": True, "andar": True}
NOMES = {"parado": "PARADO", "andar": "ANDAR", "ataque": "ATAQUE", "habilidade": "HABILIDADE",
         "defesa": "DEFESA", "dano": "DANO", "derrota": "DERROTA"}


# ------------------------------------------------------------------ montagem
def recortar_quadros(anims):
    """Corta todos os quadros na mesma caixa (a menor que contém todos)."""
    caixa = None
    for quadros in anims.values():
        for q in quadros:
            b = q.getbbox()
            if b:
                caixa = b if caixa is None else (min(caixa[0], b[0]), min(caixa[1], b[1]),
                                                 max(caixa[2], b[2]), max(caixa[3], b[3]))
    x0, y0, x1, y1 = (caixa[0] - PX, caixa[1] - PX, caixa[2] + PX, caixa[3] + PX)
    cortados = {k: [q.crop((x0, y0, x1, y1)) for q in v] for k, v in anims.items()}
    return cortados, (PE[0] - x0, PE[1] - y0)


def salvar(nome, anims, altura_corpo):
    anims, pe = recortar_quadros(anims)
    w, h = next(iter(anims.values()))[0].size
    colunas = max(len(v) for v in anims.values())

    # Folha do jogo: uma linha por animação, sem texto
    folha = Image.new("RGBA", (w * colunas, h * len(ORDEM)), (0, 0, 0, 0))
    meta = {"quadro": [w, h], "pe": list(pe), "altura_corpo": int(altura_corpo), "animacoes": {}}
    for linha, a in enumerate(ORDEM):
        for c, q in enumerate(anims[a]):
            folha.alpha_composite(q, (c * w, linha * h))
        meta["animacoes"][a] = {"linha": linha, "quadros": len(anims[a]), "fps": FPS[a], "repete": REPETE.get(a, False)}
    folha.save(SAIDA / f"{nome}_sprites.png")
    (SAIDA / f"{nome}_sprites.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")

    # Folha de apresentação (como os exemplos): fundo escuro, nome de cada animação, quadros menores
    escala = 0.5
    sw, sh = int(w * escala), int(h * escala)
    rotulo = 34
    apres = Image.new("RGB", (sw * colunas + 20, (sh + rotulo) * len(ORDEM) + 10), (24, 24, 32))
    d = ImageDraw.Draw(apres)
    try:
        fonte = ImageFont.truetype("arialbd.ttf", 20)
    except OSError:
        fonte = ImageFont.load_default()
    for linha, a in enumerate(ORDEM):
        y = linha * (sh + rotulo) + 6
        d.text((12, y), f"{NOMES[a]} ({len(anims[a])} quadros)", fill=(236, 222, 186), font=fonte)
        for c, q in enumerate(anims[a]):
            apres.paste(q.resize((sw, sh), Image.NEAREST), (10 + c * sw, y + rotulo - 6), q.resize((sw, sh), Image.NEAREST))
    FOLHAS.mkdir(parents=True, exist_ok=True)
    apres.save(FOLHAS / f"{nome}_folha.png")

    # GIF de prévia: todas as animações em sequência
    quadros_gif, duracoes = [], []
    for a in ORDEM:
        voltas = 2 if REPETE.get(a) else 1
        for _ in range(voltas):
            for q in anims[a]:
                fundo = Image.new("RGBA", (w, h), (24, 24, 32, 255))
                fundo.alpha_composite(q)
                quadros_gif.append(fundo.convert("RGB").resize((int(w * 0.6), int(h * 0.6)), Image.NEAREST))
                duracoes.append(int(1000 / FPS[a]))
        duracoes[-1] += 300
    quadros_gif[0].save(FOLHAS / f"{nome}.gif", save_all=True, append_images=quadros_gif[1:],
                        duration=duracoes, loop=0, optimize=True)
    print(f"gerado: {nome}  quadro {w}x{h}  pé {pe}  folha {folha.size}")


def gerar():
    SAIDA.mkdir(parents=True, exist_ok=True)
    for nome, funcao in PERSONAGENS.items():
        poses = carregar_poses(nome)
        salvar(nome, funcao(*poses), poses[0].altura)


if __name__ == "__main__":
    gerar()
