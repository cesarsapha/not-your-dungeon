# Not your Dungeon

![Not your Dungeon](arte/ui/logo.png)

RPG tático por turnos em 2D, feito em **Godot**. O jogador comanda os **monstros da masmorra** contra as inquisições humanas, lutando pela liberdade de cada monstro escolher o próprio destino.

> Projeto acadêmico. O GDD completo está em [`docs/GDD_Not_your_Dungeon.docx`](docs/GDD_Not_your_Dungeon.docx) e o resumo em [`docs/GDD.md`](docs/GDD.md).

## Personagens (modelos definitivos)

![Spike, Gordot, Thyr e Zork](arte/personagens/fichas_pixelart.png)

| Personagem | Papel | Atributo | Habilidade única | Inspiração |
|---|---|---|---|---|
| **Spike** | tanque | vida adicional | Muralha de Tronco | [ogro com tronco](arte/referencias/spike/spike_referencia.png) |
| **Gordot** | veloz / veneno | age primeiro | Machadada Venenosa | [orc com martelo](arte/referencias/gordot/gordot_referencia.jpg) |
| **Thyr** | mago | ganha mais experiência | Chama do Núcleo | [espectro de fogo](arte/referencias/thyr/thyr_referencia.png) |
| **Zork** | chefe da masmorra (não jogável) | — | — | [rei-sombra](arte/referencias/zork/zork_referencia.png) |

Modelos feitos pela equipe. A folha completa, com pose parada, ataque e habilidade de cada um, está em [`arte/personagens/modelos_definitivos.jpg`](arte/personagens/modelos_definitivos.jpg):

![Folha de modelos](arte/personagens/modelos_definitivos.jpg)

As poses paradas recortadas, com fundo transparente, ficam em [`arte/personagens/monstros/`](arte/personagens/monstros/) e são usadas pelo jogo. O script [`ferramentas/recortar_modelos.py`](ferramentas/recortar_modelos.py) faz o recorte **sem alterar o desenho**: só troca o fundo azul-escuro por transparência e mantém a sombra no chão. Se a folha mudar, substitua o arquivo e rode `python ferramentas/recortar_modelos.py`. As imagens que serviram de inspiração, incluindo os mapas de cenário, estão em [`arte/referencias/`](arte/referencias/).

## Animações (sprite sheets)

| Gordot | Spike | Thyr | Zork |
|---|---|---|---|
| ![Gordot](arte/personagens/folhas/gordot.gif) | ![Spike](arte/personagens/folhas/spike.gif) | ![Thyr](arte/personagens/folhas/thyr.gif) | ![Zork](arte/personagens/folhas/zork.gif) |

Cada personagem tem 7 animações: **parado, andar, ataque, habilidade, defesa, dano e derrota**.

| Personagem | Ataque | Habilidade |
|---|---|---|
| Gordot | ergue o machado e golpeia com rastro | **Machadada Venenosa**: machado brilha verde, rastro e respingo de veneno |
| Spike | ergue o tronco e golpeia; poeira no impacto | **Muralha de Tronco**: ruge com o tronco erguido, aura vermelha no chão |
| Thyr | jato de fogo saindo da espada | **Chama do Núcleo**: fagulhas sobem e explodem num anel de fogo |
| Zork | estocada com a lança | salto com a lança, onda de choque e poeira ao cair |

Folhas de apresentação, com o nome de cada animação: [Gordot](arte/personagens/folhas/gordot_folha.png), [Spike](arte/personagens/folhas/spike_folha.png), [Thyr](arte/personagens/folhas/thyr_folha.png) e [Zork](arte/personagens/folhas/zork_folha.png).

- O jogo usa `arte/personagens/monstros/<nome>_sprites.png` (uma linha por animação) e `<nome>_sprites.json` (quadros, fps e posição do pé). No combate, Spike e Gordot já tocam parado, ataque, habilidade, defesa, dano e derrota.
- Os quadros são gerados por [`ferramentas/gerar_animacoes.py`](ferramentas/gerar_animacoes.py) **a partir das 3 poses desenhadas** de cada personagem, com respiração, inclinação, deslocamento, rotação e efeitos por cima. As poses não são redesenhadas.
- **Limitação:** como só existem 3 poses, o **andar** é um balanço com passada e não um ciclo de pernas desenhado quadro a quadro. Para um andar completo, alguém precisa desenhar as poses intermediárias. É só adicioná-las na folha de modelos e no script.
- Para refazer depois de mudar a folha de modelos: `python ferramentas/recortar_modelos.py` e em seguida `python ferramentas/gerar_animacoes.py`.

## Arte conceitual (primeira versão)

Rascunhos visuais da primeira fase do projeto. **Atenção:** nesta versão o Spike era um goblin e o Gordot um ogro roxo. A aparência atual é a da seção acima. Ficam em [`arte/conceitos/`](arte/conceitos/).

### Menu inicial
![Menu inicial](arte/conceitos/menu_inicial.jpg)

### Mapa das masmorras
![Mapa de seleção das masmorras](arte/conceitos/mapa_masmorras.jpg)

### Personagens
![Zork, Spike, Gordot, Thyr, Mercenário Lacaio e Líder](arte/conceitos/personagens_lineup.jpg)

### Sala do trono (Fase 1, Tela 1)
![Sala do trono do Zork](arte/conceitos/sala_do_trono.jpg)

### Combate
![Combo Vórtice Venenoso Sombrio](arte/conceitos/combate_combo.jpg)

![Combate em grade hexagonal](arte/conceitos/combate_hexagonos.jpg)

### Grupo e inventário
![Tela de grupo de monstros e inventário](arte/conceitos/grupo_inventario.jpg)

### Itens e armas
| Itens | Armas |
|---|---|
| ![Cristais, picaretas, poções e pergaminhos](arte/conceitos/itens.jpg) | ![Espada, maça, adaga e cajado](arte/conceitos/armas.jpg) |

## Folhas de animação (primeira versão)

### Spike
![Folha de animação do Spike](arte/conceitos/spike_folha_animacao.jpg)

### Gordot
![Folha de animação do Gordot](arte/conceitos/gordot_folha_animacao.jpg)

### Zork
![Folha de animação do Zork](arte/conceitos/zork_folha_animacao.jpg)

### Mercenários (Lacaio e Líder)
![Folha de animação dos mercenários](arte/conceitos/mercenarios_folha_animacao.jpg)

## Equipe

- Cesar Sapha
- Vitor Souza
- Tales Fernandes
- Pietro Pelozato Maeda

## Estrutura do repositório

| Pasta | Conteúdo |
|---|---|
| `docs/` | GDD e documentação |
| `arte/personagens/monstros/` | Monstros jogáveis (Spike, Gordot, Thyr, Zork...) |
| `arte/personagens/herois/` | Heróis humanos |
| `arte/inimigos/` | Mercenário Lacaio, Mercenário Líder... |
| `arte/cenarios/masmorra_1/` | Caverna Destruída |
| `arte/ui/` | Interface, caixas de diálogo, ícones |
| `arte/conceitos/` | Rascunhos e concept art (primeira versão) |
| `arte/referencias/` | Imagens de referência de cada personagem e do cenário |
| `ferramentas/` | Scripts que recortam os modelos e geram as animações |
| `animacoes/` | Sprite sheets e arquivos de animação |
| `audio/` | Músicas e efeitos sonoros |

## Protótipo atual: combate por turnos

Feito em **Godot 4.7.2**. Para jogar, abra a Godot, clique em **Importar**, selecione o `project.godot` desta pasta e aperte **F5**.

Ele reproduz a **Fase 1, Tela 5** do GDD: Spike e Gordot contra 2 Mercenários Lacaios e o Mercenário Líder (chefe).

- Ordem de turnos pela velocidade. O Gordot **sempre age primeiro**.
- O Spike é o tanque: tem **+20% de vida** e a **Muralha de Tronco**, que atrai os ataques inimigos por 2 turnos com 30% menos dano.
- O Gordot envenena com a **Machadada Venenosa**.
- Ações disponíveis: Atacar, Defender, Especial (gasta SP), Item (Poção) e Fugir. Não dá para fugir porque é batalha de chefe.
- **Combo:** o Gordot usa *Machadada Venenosa* e, na mesma rodada, o Spike usa *Esmagar com Tronco*. Isso dispara o **Esmagamento Tóxico**, que acerta todos os inimigos.
- Ainda não implementado (previsto no GDD): MP para magias, stagger, moral, crítico com tempo e o Thyr no combate.

| Arquivo | Para que serve |
|---|---|
| `scripts/combate/banco_dados.gd` | Atributos, habilidades e combos. **Balanceamento é aqui.** |
| `scripts/combate/combate.gd` | Turnos, menus e regras do combate |
| `scripts/combate/combatente.gd` | Uma unidade em campo (vida, dano, desenho) |

**Arte:** Spike e Gordot já aparecem com a pixel art. Os mercenários ainda são retângulos. Se um PNG **com fundo transparente** for salvo num destes caminhos, ele aparece sozinho no jogo:

- `arte/inimigos/mercenario_lacaio.png`, `arte/inimigos/mercenario_lider.png`
- `arte/cenarios/masmorra_1/fundo_combate.png` (fundo, 1280x720)

**Teste automático** (simula uma batalha inteira e mostra o resultado no terminal):

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --autoteste
```

Para ver a batalha automática em velocidade normal, com as animações, tire o `--headless` e acrescente `--lento` no final.

## Controles

| Tecla | Ação |
|---|---|
| Setas / WASD | Andar pelo cenário / navegar menus |
| Z | Confirmar / interagir |
| X | Voltar |

## Convenção de nomes dos arquivos de arte

`personagem_acao_direcao.png`. Exemplos: `spike_idle.png`, `spike_andar_direita.png`, `mercenario_lacaio_ataque.png`. Use letras minúsculas e não use acentos nem espaços.
