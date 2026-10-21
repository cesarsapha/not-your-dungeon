class_name Combo
extends Resource
## Combo entre aliados: quando "primeiro" usa a habilidade dele e, na MESMA
## rodada, "segundo" usa a dele, o combo dispara (GDD, página 07).

@export var nome := ""
@export var primeiro_unidade := ""
@export var primeiro_habilidade := ""
@export var segundo_unidade := ""
@export var segundo_habilidade := ""
## Dano = (ataque dos dois somado) x multiplicador, em todos os inimigos.
@export var multiplicador := 1.2
