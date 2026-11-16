class_name Habilidade
extends Resource
## Habilidade especial: custa SP e causa dano multiplicado.

@export var nome := ""
@export_multiline var descricao := ""
@export var custo_sp := 5
@export var multiplicador := 1.5
@export var alvo_todos := false
@export var veneno_turnos := 0
@export var veneno_dano := 0
## Turnos em que o usuário atrai os ataques inimigos e recebe 30% menos dano.
@export var provocar_turnos := 0
## Animação tocada ao usar (linha da folha de sprites: "habilidade", "ataque"...).
@export var animacao := "habilidade"
