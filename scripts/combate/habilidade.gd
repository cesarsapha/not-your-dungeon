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
