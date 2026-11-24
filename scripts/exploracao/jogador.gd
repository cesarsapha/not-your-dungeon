
class_name Jogador
extends Node2D
## Personagem controlado na exploração (setas ou WASD).
## Usa as linhas de exploração da folha de sprites: andar de frente, de costas e de lado.
## Andar para a esquerda reaproveita o lado direito espelhado (flip_h), como no documento de sprites.

# Velocidade de movimentação em pixels por segundo.
const VELOCIDADE := 170.0

# Caminho da folha de sprites e altura visual do personagem.
@export var folha := "res://arte/personagens/monstros/spike_sprites"
@export var altura := 110.0

## Retângulo (em pixels da tela) por onde o personagem pode andar.
var limites := Rect2(0, 0, 1280, 720)

## Polígono que delimita a área caminhável em cenários irregulares.
## Quando vazio, utiliza apenas os limites retangulares da sala.
var area_caminhavel := PackedVector2Array()

## Quando verdadeiro (diálogo aberto, troca de cena), ignora o controle.
var bloqueado := false

## Indica que o personagem está executando uma animação de interação.
## Enquanto verdadeiro, a movimentação e as animações automáticas são suspensas.
var interagindo := false

## Usado pelo teste automático no lugar do teclado.
var entrada_simulada := Vector2.ZERO

# Sprite responsável pelas animações do personagem.
var anim: AnimatedSprite2D

# Última direção para a qual o personagem estava olhando.
var _olhando := "frente"

# Tempo acumulado utilizado na animação de caminhada de costas.
var _tempo := 0.0


# Inicializa o personagem ao entrar na cena.
func _ready() -> void:
	# Cria o sprite animado a partir da folha de sprites.
	anim = FolhaSprites.criar(folha, altura)
	add_child(anim)

	# Inicia o personagem em posição de repouso.
	_parar()


# Retorna a direção de movimentação desejada pelo jogador.
func _direcao() -> Vector2:
	# Prioriza a entrada simulada quando utilizada em testes.
	if entrada_simulada != Vector2.ZERO:
		return entrada_simulada.normalized()

	# Verifica a entrada pelas setas direcionais.
	var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Caso nenhuma seta esteja pressionada, verifica as teclas WASD.
	if v == Vector2.ZERO:
		v = Vector2(
			int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)),
			int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W))
		)

	# Normaliza o vetor para evitar maior velocidade na diagonal.
	return v.normalized()


# Atualiza a movimentação e as animações a cada quadro.
func _process(delta: float) -> void:
	# Preserva a animação de interação até sua conclusão.
	if interagindo:
		return

	# Ignora os comandos de movimentação quando o jogador está bloqueado.
	var v := Vector2.ZERO if bloqueado else _direcao()

	# Sem movimento, mantém a pose correspondente à última direção.
	if v == Vector2.ZERO:
		_parar()
		return

	# -------------------------------------------------- Movimentação

	# Calcula a próxima posição do personagem.
	# O delta mantém a velocidade independente da taxa de quadros.
	# O clamp impede que o personagem ultrapasse os limites retangulares.
	var destino := (position + v * VELOCIDADE * delta).clamp(
		limites.position, limites.end
	)

	# Salas sem polígono utilizam os limites antigos.
	if area_caminhavel.is_empty():
		position = destino
	else:
		# Verifica os eixos separadamente para permitir que o personagem
		# deslize pelas paredes quando tenta se mover na diagonal.

		# Verifica movimentação horizontal.
		var destino_x := Vector2(destino.x, position.y)

		# Só altera a posição X se o destino estiver dentro do polígono.
		if Geometry2D.is_point_in_polygon(destino_x, area_caminhavel):
			position.x = destino.x

		# Verifica movimentação vertical.
		var destino_y := Vector2(position.x, destino.y)

		# Só altera a posição Y se o destino estiver dentro do polígono.
		if Geometry2D.is_point_in_polygon(destino_y, area_caminhavel):
			position.y = destino.y

	# -------------------------------------------------- Animações

	# Acumula o tempo para os efeitos de animação.
	_tempo += delta

	# Prioriza a animação lateral quando o movimento
	# horizontal é predominante ou diagonal.
	if absf(v.x) >= absf(v.y):
		_olhando = "lado"
		FolhaSprites.virar(anim, v.x < 0)
		_tocar("andar_lado")

	# Movimento para baixo: personagem de frente.
	elif v.y > 0:
		_olhando = "frente"
		FolhaSprites.virar(anim, false)
		_tocar("andar_frente")

	# Movimento para cima: personagem de costas.
	else:
		# de costas só existe 1 quadro: um balanço leve dá a sensação de passo
		_olhando = "costas"
		FolhaSprites.virar(anim, false)
		FolhaSprites.posar(anim, "costas")
		anim.position.y += sin(_tempo * 14.0) * 1.5


# Reproduz uma animação sem reiniciá-la desnecessariamente.
func _tocar(nome: String) -> void:
	if anim.animation != nome or not anim.is_playing():
		anim.play(nome)


# Interrompe a caminhada e mantém o personagem
# em uma pose estática correspondente à última direção.
func _parar() -> void:
	match _olhando:
		# Mantém a pose lateral e o espelhamento atual.
		"lado":
			FolhaSprites.posar(anim, "andar_lado", 0)

		# Mantém a pose de costas, sem espelhamento.
		"costas":
			FolhaSprites.posar(anim, "costas")
			FolhaSprites.virar(anim, false)

		# Mantém a pose frontal.
		_:
			FolhaSprites.posar(anim, "andar_frente", 0)
