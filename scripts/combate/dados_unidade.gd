class_name DadosUnidade
extends Resource
## Atributos fixos de um personagem (monstro ou inimigo), conforme o GDD:
## pontos de vida, defesa, ataque e nível.

@export var nome := ""
@export var eh_monstro := true
@export var nivel := 1
@export var hp_max := 100
@export var sp_max := 30
@export var ataque := 10
@export var defesa := 5
@export var velocidade := 10
## Gordot: sempre age primeiro no combate.
@export var sempre_primeiro := false
## Spike: vida adicional (0.2 = +20% de HP).
@export var bonus_vida := 0.0
@export var habilidades: Array[Habilidade] = []

@export_group("Visual")
## Cor do retângulo usado enquanto não existe sprite.
@export var cor := Color.WHITE
## Tamanho em tela (largura x altura) do personagem.
@export var tamanho := Vector2(60, 100)
@export var textura: Texture2D
@export var espelhar := false
