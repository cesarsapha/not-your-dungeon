"""Importa as folhas de sprites desenhadas pela equipe (documento sprites.docx).

As folhas originais ficam em arte/sprites_originais/ (fonte; a Godot não importa).
Cada folha de personagem é uma grade uniforme de 3 colunas x 4 linhas:

    <nome>_combate1.png   guarda, atacar, habilidade/combo, magia e item
    <nome>_combate2.png   defender, dano, stagger, derrota e vitória
    <nome>_exploracao.png andar de frente, costas e lado, interação, alerta e retrato

O script:
  1. apaga os títulos escritos sobre algumas folhas ("Row 1 — Defender"...)
  2. troca o fundo azul-escuro de cada quadro por transparência (o desenho não muda)
  3. reorganiza os quadros numa folha só por personagem, uma animação por linha,
     com um .json dizendo quadros, fps e posição do pé (lido pelo jogo)
  4. salva a pose parada de cada um (usada no GDD e como imagem estática)

Uso (na raiz do repositório):
    python ferramentas/importar_sprites.py
"""
import json
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
ORIGINAIS = RAIZ / "arte" / "sprites_originais"
MONSTROS = RAIZ / "arte" / "personagens" / "monstros"
INIMIGOS = RAIZ / "arte" / "inimigos"
NPCS = RAIZ / "arte" / "personagens" / "npcs"
PREVIAS = RAIZ / "arte" / "personagens" / "folhas"

FUNDO = (30, 34, 46)
TOLERANCIA = 33
COLUNAS, LINHAS = 3, 4

# animação: (folha, linha, colunas usadas, fps, repete)
ANIMACOES = {
    "parado": ("combate1", 0, [0, 1, 2], 4, True),
    "ataque": ("combate1", 1, [0, 1, 2], 7, False),
    "habilidade": ("combate1", 2, [0, 1, 2], 6, False),
    "magia": ("combate1", 3, [0, 1], 5, False),
    "item": ("combate1", 3, [2], 2, False),
    "defesa": ("combate2", 0, [0, 1, 2], 6, False),
    "dano": ("combate2", 1, [0, 1, 2], 8, False),
    "stagger": ("combate2", 2, [0, 1, 2], 4, True),
    "derrota": ("combate2", 3, [0, 1], 3, False),
    "vitoria": ("combate2", 3, [2], 2, False),
    "andar_frente": ("exploracao", 0, [0, 1, 2], 6, True),
    "costas": ("exploracao", 1, [0], 1, False),
    "andar_lado": ("exploracao", 1, [1, 2], 5, True),
    "interacao": ("exploracao", 2, [0, 1, 2], 5, False),
    "especial": ("exploracao", 3, [0], 1, False),
    "alerta": ("exploracao", 3, [1], 1, False),
    "retrato": ("exploracao", 3, [2], 1, False),
}
NOMES = {
    "parado": "GUARDA (PARADO)", "ataque": "ATACAR", "habilidade": "HABILIDADE / COMBO", "magia": "MAGIA",
    "item": "ITEM", "defesa": "DEFENDER", "dano": "DANO", "stagger": "STAGGER", "derrota": "DERROTA",
    "vitoria": "VITÓRIA", "andar_frente": "ANDAR (FRENTE)", "costas": "COSTAS", "andar_lado": "ANDAR (LADO)",
    "interacao": "INTERAÇÃO", "especial": "RESGATE / ESPECIAL", "alerta": "ALERTA (!)", "retrato": "RETRATO",
}

PERSONAGENS = [("spike", MONSTROS), ("gordot", MONSTROS), ("thyr", MONSTROS), ("zork", MONSTROS),
               ("mercenario", INIMIGOS)]


# ------------------------------------------------------------------ limpeza
FOLHAS_COM_TITULOS = {"spike_combate2", "spike_exploracao"}
MARGEM = 48     # espaço extra em volta de cada quadro para o que passa da borda da grade


def apagar_titulos(rgb):
    """Apaga os títulos brancos escritos no topo de cada linha da grade ("Row 1 — Defender"...)."""
    a = rgb.astype(int)
    branco = (a.min(axis=2) > 165) & (a.max(axis=2) - a.min(axis=2) < 40)
    h = rgb.shape[0]
    out = rgb.copy()
    for linha in range(LINHAS):
        y0 = round(linha * h / LINHAS)
        faixa = branco[y0:y0 + 50, 120:900]
        ys = np.where(faixa.sum(axis=1) >= 30)[0]
        if len(ys) == 0:
            continue
        ya, yb = y0 + ys.min(), y0 + ys.max()
        xs = np.where(branco[ya:yb + 1, 120:900].any(axis=0))[0] + 120
        out[ya - 5:yb + 6, xs.min() - 6:xs.max() + 7] = FUNDO
    return out


def mascara_fundo(rgb):
    """Fundo ligado às bordas da folha (preenchimento a partir das bordas)."""
    h, w, _ = rgb.shape
    perto = np.abs(rgb.astype(int) - np.array(FUNDO)).sum(axis=2) <= TOLERANCIA
    fundo = np.zeros((h, w), bool)
    fila = deque()
    for y in range(h):
        for x in (0, w - 1):
            if perto[y, x]:
                fundo[y, x] = True
                fila.append((y, x))
    for x in range(w):
        for y in (0, h - 1):
            if perto[y, x] and not fundo[y, x]:
                fundo[y, x] = True
                fila.append((y, x))
    while fila:
        y, x = fila.popleft()
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < h and 0 <= nx < w and perto[ny, nx] and not fundo[ny, nx]:
                fundo[ny, nx] = True
                fila.append((ny, nx))
    return fundo


def componentes(frente):
    """Rotula as regiões conectadas (8 vizinhos). Devolve lista de (ys, xs)."""
    h, w = frente.shape
    visto = np.zeros((h, w), bool)
    regioes = []
    for y, x in zip(*np.where(frente)):
        if visto[y, x]:
            continue
        visto[y, x] = True
        pilha, ys, xs = [(y, x)], [], []
        while pilha:
            cy, cx = pilha.pop()
            ys.append(cy)
            xs.append(cx)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < h and 0 <= nx < w and frente[ny, nx] and not visto[ny, nx]:
                        visto[ny, nx] = True
                        pilha.append((ny, nx))
        regioes.append((np.array(ys), np.array(xs)))
    return regioes


def tirar_fundo(rgb):
    """Imagem inteira -> RGBA com o fundo transparente e sem pontinhos soltos."""
    frente = ~mascara_fundo(rgb)
    for ys, xs in componentes(frente):
        if len(ys) < 12:
            frente[ys, xs] = False
    rgba = np.zeros((*rgb.shape[:2], 4), np.uint8)
    rgba[:, :, :3] = rgb
    rgba[:, :, 3] = np.where(frente, 255, 0)
    return rgba


def quadros_da_folha(caminho):
    """Separa a grade 3x4. Cada pedaço do desenho vai para o quadro onde está a maior parte dele,
    mesmo que passe da borda da grade (ex.: cimitarra erguida invadindo o quadro de cima)."""
    rgb = np.array(Image.open(caminho).convert("RGB"))
    if caminho.stem in FOLHAS_COM_TITULOS:
        rgb = apagar_titulos(rgb)
    h, w, _ = rgb.shape
    cw, ch = w / COLUNAS, h / LINHAS
    frente = ~mascara_fundo(rgb)
    qw, qh = round(cw) + 2 * MARGEM, round(ch) + 2 * MARGEM
    quadros = {(l, c): np.zeros((qh, qw, 4), np.uint8) for l in range(LINHAS) for c in range(COLUNAS)}
    for ys, xs in componentes(frente):
        if len(ys) < 12:
            continue
        linhas = np.minimum((ys // ch).astype(int), LINHAS - 1)
        cols = np.minimum((xs // cw).astype(int), COLUNAS - 1)
        celula = linhas * COLUNAS + cols
        contagem = np.bincount(celula, minlength=LINHAS * COLUNAS)
        ordem = np.argsort(contagem)[::-1]
        if contagem[ordem[1]] > 0.15 * len(ys):
            # dois desenhos vizinhos se encostam: divide a peça pela linha da grade
            destinos = celula
        else:
            destinos = np.full(len(ys), ordem[0])
        for d in np.unique(destinos):
            sel = destinos == d
            linha, col = divmod(int(d), COLUNAS)
            oy, ox = round(linha * ch) - MARGEM, round(col * cw) - MARGEM
            ly, lx = ys[sel] - oy, xs[sel] - ox
            ok = (ly >= 0) & (ly < qh) & (lx >= 0) & (lx < qw)
            q = quadros[(linha, col)]
            q[ly[ok], lx[ok], :3] = rgb[ys[sel][ok], xs[sel][ok]]
            q[ly[ok], lx[ok], 3] = 255
    return quadros


# ------------------------------------------------------------------ montagem
def pe_e_altura(rgba):
    """Pé = centro das colunas ocupadas nas últimas linhas do desenho; altura = do topo ao pé."""
    a = rgba[:, :, 3] > 0
    ys, _ = np.where(a)
    base = ys.max()
    cols = np.where(a[max(base - 12, 0):base + 1].any(axis=0))[0]
    return (int((cols.min() + cols.max()) / 2), int(base)), int(base - ys.min())


def importar(nome, pasta):
    folhas = {}
    for tipo in ("combate1", "combate2", "exploracao"):
        folhas[tipo] = quadros_da_folha(ORIGINAIS / f"{nome}_{tipo}.png")
    qw = max(q.shape[1] for f in folhas.values() for q in f.values())
    qh = max(q.shape[0] for f in folhas.values() for q in f.values())
    ordem = list(ANIMACOES)
    folha = Image.new("RGBA", (qw * COLUNAS, qh * len(ordem)), (0, 0, 0, 0))
    meta = {"quadro": [qw, qh], "animacoes": {}}
    for i, anim in enumerate(ordem):
        tipo, linha, cols, fps, repete = ANIMACOES[anim]
        for c, col in enumerate(cols):
            folha.alpha_composite(Image.fromarray(folhas[tipo][(linha, col)]), (c * qw, i * qh))
        meta["animacoes"][anim] = {"linha": i, "quadros": len(cols), "fps": fps, "repete": repete}
    parado = folhas["combate1"][(0, 0)]
    pe, altura = pe_e_altura(parado)
    meta["pe"] = list(pe)
    meta["altura_corpo"] = altura
    pasta.mkdir(parents=True, exist_ok=True)
    folha.save(pasta / f"{nome}_sprites.png")
    (pasta / f"{nome}_sprites.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")

    estatica = Image.fromarray(parado)
    estatica.crop(estatica.getbbox()).save(pasta / f"{nome}.png")
    salvar_previa(nome, folha, meta)
    print(f"importado: {nome}  quadro {qw}x{qh}  pé {pe}  altura {altura}")


def salvar_previa(nome, folha, meta):
    """Folha de apresentação: nome de cada animação e seus quadros, sobre fundo escuro."""
    qw, qh = meta["quadro"]
    escala = 0.45
    sw, sh = int(qw * escala), int(qh * escala)
    rotulo = 26
    anims = meta["animacoes"]
    largura = 2 * (COLUNAS * sw + 30)
    linhas = (len(anims) + 1) // 2
    img = Image.new("RGB", (largura, linhas * (sh + rotulo) + 10), (24, 24, 32))
    d = ImageDraw.Draw(img)
    try:
        fonte = ImageFont.truetype("arialbd.ttf", 16)
    except OSError:
        fonte = ImageFont.load_default()
    for k, (anim, info) in enumerate(anims.items()):
        bx = (k % 2) * (COLUNAS * sw + 30) + 10
        by = (k // 2) * (sh + rotulo) + 6
        d.text((bx, by), NOMES[anim], fill=(236, 222, 186), font=fonte)
        for c in range(info["quadros"]):
            q = folha.crop((c * qw, info["linha"] * qh, (c + 1) * qw, (info["linha"] + 1) * qh)).resize((sw, sh), Image.NEAREST)
            img.paste(q, (bx + c * sw, by + rotulo - 4), q)
    PREVIAS.mkdir(parents=True, exist_ok=True)
    img.save(PREVIAS / f"{nome}_folha.png")


# ------------------------------------------------------------------ NPCs e cenário
def importar_npcs():
    NPCS.mkdir(parents=True, exist_ok=True)
    # Vendedor (kobold mercante): grade 2x2 -> parado, oferecendo, alerta, retrato
    rgb = np.array(Image.open(ORIGINAIS / "vendedor.png").convert("RGB"))
    h, w, _ = rgb.shape
    nomes = ["vendedor", "vendedor_oferta", "vendedor_alerta", "vendedor_retrato"]
    for k, n in enumerate(nomes):
        lin, col = divmod(k, 2)
        q = Image.fromarray(tirar_fundo(rgb[lin * h // 2:(lin + 1) * h // 2, col * w // 2:(col + 1) * w // 2]))
        q.crop(q.getbbox()).save(NPCS / f"{n}.png")
    # Animal de carga: pose grande (o balão "!" fica de fora) e os 3 quadros andando
    rgb = np.array(Image.open(ORIGINAIS / "animal_de_carga.png").convert("RGB"))
    rgb[:110, 380:] = FUNDO
    q = Image.fromarray(tirar_fundo(rgb))
    q.crop(q.getbbox()).save(NPCS / "animal_de_carga.png")
    rgb = np.array(Image.open(ORIGINAIS / "animal_de_carga_andar.png").convert("RGB"))
    h, w, _ = rgb.shape
    quadros = [Image.fromarray(tirar_fundo(rgb[:, round(i * w / 3):round((i + 1) * w / 3)])) for i in range(3)]
    qw = max(q.width for q in quadros)
    tira = Image.new("RGBA", (qw * 3, h), (0, 0, 0, 0))
    for i, q in enumerate(quadros):
        tira.alpha_composite(q, (i * qw, 0))
    tira.save(NPCS / "animal_de_carga_andar.png")
    # Sala do trono: cenário inteiro, sem recorte
    Image.open(ORIGINAIS / "sala_do_trono.png").convert("RGB").save(
        RAIZ / "arte" / "cenarios" / "masmorra_1" / "sala_do_trono.png")
    print("importado: vendedor, animal de carga, sala do trono")


def gerar_gifs():
    """GIF de prévia de cada personagem: as animações de combate em sequência."""
    sequencia = ["parado", "ataque", "habilidade", "magia", "defesa", "dano", "stagger", "derrota", "vitoria"]
    for nome, pasta in PERSONAGENS:
        folha = Image.open(pasta / f"{nome}_sprites.png")
        meta = json.loads((pasta / f"{nome}_sprites.json").read_text(encoding="utf-8"))
        qw, qh = meta["quadro"]
        quadros, duracoes = [], []
        for anim in sequencia:
            info = meta["animacoes"][anim]
            voltas = 2 if info["repete"] else 1
            for _ in range(voltas):
                for c in range(info["quadros"]):
                    q = folha.crop((c * qw, info["linha"] * qh, (c + 1) * qw, (info["linha"] + 1) * qh))
                    fundo = Image.new("RGBA", (qw, qh), (*FUNDO, 255))
                    fundo.alpha_composite(q)
                    quadros.append(fundo.convert("RGB").resize((qw * 3 // 5, qh * 3 // 5), Image.NEAREST))
                    duracoes.append(int(1000 / info["fps"]))
            duracoes[-1] += 250
        quadros[0].save(PREVIAS / f"{nome}.gif", save_all=True, append_images=quadros[1:],
                        duration=duracoes, loop=0, optimize=True)
    print("gerado: GIFs de prévia")


def gerar_ficha():
    """Os quatro personagens principais lado a lado (pose parada), com nome e papel."""
    lista = [("spike", "SPIKE", "vida adicional"), ("gordot", "GORDOT", "veloz"),
             ("thyr", "THYR", "mago"), ("zork", "ZORK", "chefe (NPC)")]
    imgs = [(Image.open(MONSTROS / f"{n}.png"), t, p) for n, t, p in lista]
    margem = 40
    alto = max(i.height for i, _, _ in imgs)
    largura = sum(i.width for i, _, _ in imgs) + margem * (len(imgs) + 1)
    ficha = Image.new("RGB", (largura, alto + margem + 100), FUNDO)
    d = ImageDraw.Draw(ficha)
    try:
        fonte = ImageFont.truetype("arialbd.ttf", 28)
        fonte_p = ImageFont.truetype("arial.ttf", 20)
    except OSError:
        fonte = fonte_p = ImageFont.load_default()
    x, base_y = margem, alto + margem
    for img, titulo, papel in imgs:
        ficha.paste(img, (x, base_y - img.height), img)
        cx = x + img.width // 2
        d.text((cx, base_y + 32), titulo, fill=(230, 214, 180), font=fonte, anchor="mm")
        d.text((cx, base_y + 66), papel, fill=(160, 150, 150), font=fonte_p, anchor="mm")
        x += img.width + margem
    ficha.save(RAIZ / "arte" / "personagens" / "fichas_pixelart.png")
    print("gerado: fichas_pixelart.png", ficha.size)


if __name__ == "__main__":
    for nome, pasta in PERSONAGENS:
        importar(nome, pasta)
    importar_npcs()
    gerar_ficha()
    gerar_gifs()
