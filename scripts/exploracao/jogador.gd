class_name Jogador
extends Node2D
## Personagem controlado na exploração (setas ou WASD).
## Usa as linhas de exploração da folha de sprites: andar de frente, de costas e de lado.
## Andar para a esquerda reaproveita o lado direito espelhado (flip_h), como no documento de sprites.

const VELOCIDADE := 170.0

@export var folha := "res://arte/personagens/monstros/spike_sprites"
@export var altura := 110.0

## Retângulo (em pixels da tela) por onde o personagem pode andar.
var limites := Rect2(0, 0, 1280, 720)
## Quando verdadeiro (diálogo aberto, troca de cena), ignora o controle.
var bloqueado := false
## Usado pelo teste automático no lugar do teclado.
var entrada_simulada := Vector2.ZERO

var anim: AnimatedSprite2D
var _olhando := "frente"
var _tempo := 0.0


func _ready() -> void:
	anim = FolhaSprites.criar(folha, altura)
	add_child(anim)
	_parar()


func _direcao() -> Vector2:
	if entrada_simulada != Vector2.ZERO:
		return entrada_simulada.normalized()
	var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if v == Vector2.ZERO:
		v = Vector2(
			int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)),
			int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W)))
	return v.normalized()


func _process(delta: float) -> void:
	var v := Vector2.ZERO if bloqueado else _direcao()
	if v == Vector2.ZERO:
		_parar()
		return
	position = (position + v * VELOCIDADE * delta).clamp(limites.position, limites.end)
	_tempo += delta
	if absf(v.x) > absf(v.y):
		_olhando = "lado"
		FolhaSprites.virar(anim, v.x < 0)
		_tocar("andar_lado")
	elif v.y > 0:
		_olhando = "frente"
		FolhaSprites.virar(anim, false)
		_tocar("andar_frente")
	else:
		# de costas só existe 1 quadro: um balanço leve dá a sensação de passo
		_olhando = "costas"
		FolhaSprites.virar(anim, false)
		FolhaSprites.posar(anim, "costas")
		anim.position.y += sin(_tempo * 14.0) * 1.5


func _tocar(nome: String) -> void:
	if anim.animation != nome or not anim.is_playing():
		anim.play(nome)


func _parar() -> void:
	match _olhando:
		"lado":
			FolhaSprites.posar(anim, "andar_lado", 0)
		"costas":
			FolhaSprites.posar(anim, "costas")
			FolhaSprites.virar(anim, false)
		_:
			FolhaSprites.posar(anim, "andar_frente", 0)
