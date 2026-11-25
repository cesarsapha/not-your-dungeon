class_name ItemColetavel
extends Node2D
## Item no chão que o jogador pode pegar com Z (picaretas, chave...).
## Usa a folha gerada por ferramentas/gerar_itens.py: "chao" (flutuando com brilho) e "coleta".
## A posição do nó é o ponto no chão onde fica a sombra do item.

## Caminho da folha sem extensão, ex.: "res://arte/objetos/picareta_ferro_sprites".
var folha := ""
## Altura do item na tela, em pixels.
var altura := 40.0
## Distância do jogador para mostrar o aviso e permitir a coleta.
var alcance := 60.0

var anim: AnimatedSprite2D
var coletado := false


static func criar(caminho: String, posicao: Vector2, altura_item := 40.0) -> ItemColetavel:
	var item := ItemColetavel.new()
	item.folha = caminho
	item.altura = altura_item
	item.position = posicao
	return item


func _ready() -> void:
	anim = FolhaSprites.criar(folha, altura)
	add_child(anim)
	anim.play("chao")


func perto(ponto: Vector2) -> bool:
	return not coletado and position.distance_to(ponto) <= alcance


## Toca a animação de coleta e remove o item da cena.
func coletar() -> void:
	if coletado:
		return
	coletado = true
	anim.play("coleta")
	await anim.animation_finished
	queue_free()
