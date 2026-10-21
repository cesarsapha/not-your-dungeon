# Not your Dungeon

RPG tático por turnos em 2D, feito em **Godot**. O jogador comanda os **monstros da masmorra** contra as inquisições de heróis e mercenários humanos.

> Projeto acadêmico. O GDD completo está em [`docs/GDD_Not_your_Dungeon.docx`](docs/GDD_Not_your_Dungeon.docx) e o resumo em [`docs/GDD.md`](docs/GDD.md).

## Arte conceitual

Rascunhos visuais do jogo (ainda não recortados para uso na Godot). Ficam em [`arte/conceitos/`](arte/conceitos/).

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

## Folhas de animação

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
| `arte/conceitos/` | Rascunhos e concept art |
| `animacoes/` | Sprite sheets e arquivos de animação |
| `audio/` | Músicas e efeitos sonoros |

## Protótipo atual: combate por turnos

Feito em **Godot 4.7.2**. Para jogar, abra a Godot, clique em **Importar**, selecione o `project.godot` desta pasta e aperte **F5**.

Ele reproduz a **Fase 1, Tela 5** do GDD: Spike e Gordot contra 2 Mercenários Lacaios e o Mercenário Líder (chefe).

- Ordem de turnos pela velocidade. O Gordot **sempre age primeiro**.
- O Spike tem **+20% de vida**.
- Ações disponíveis: Atacar, Defender, Especial (gasta SP), Item (Poção) e Fugir. Não dá para fugir porque é batalha de chefe.
- **Combo:** o Gordot usa *Canal Sombrio* e, na mesma rodada, o Spike usa *Golpe Venenoso*. Isso dispara o **Vórtice Venenoso Sombrio**, que acerta todos os inimigos.

| Arquivo | Para que serve |
|---|---|
| `scripts/combate/banco_dados.gd` | Atributos, habilidades e combos. **Balanceamento é aqui.** |
| `scripts/combate/combate.gd` | Turnos, menus e regras do combate |
| `scripts/combate/combatente.gd` | Uma unidade em campo (vida, dano, desenho) |

**Arte:** por enquanto os personagens são retângulos coloridos. Se um PNG **com fundo transparente** for salvo num destes caminhos, ele aparece sozinho no jogo:

- `arte/personagens/monstros/spike.png`, `arte/personagens/monstros/gordot.png`
- `arte/inimigos/mercenario_lacaio.png`, `arte/inimigos/mercenario_lider.png`
- `arte/cenarios/masmorra_1/fundo_combate.png` (fundo, 1280x720)

**Teste automático** (simula uma batalha inteira e mostra o resultado no terminal):

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --autoteste
```

## Controles

| Tecla | Ação |
|---|---|
| Setas | Andar pelo cenário / navegar menus |
| Z | Confirmar / interagir |
| X | Voltar |

## Convenção de nomes dos arquivos de arte

`personagem_acao_direcao.png`. Exemplos: `spike_idle.png`, `spike_andar_direita.png`, `mercenario_lacaio_ataque.png`. Use letras minúsculas e não use acentos nem espaços.
