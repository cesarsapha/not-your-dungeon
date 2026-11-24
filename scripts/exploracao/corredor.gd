
extends Node2D

const CENARIO := "res://arte/cenarios/masmorra_1/corredor.png"

const MOSTRAR_COLISAO := false

# Próxima sala da primeira fase.
const PROXIMA_CENA := "res://cenas/camara_cristais.tscn"

# Área que ativa a passagem para a próxima sala.
const AREA_SAIDA := Rect2(915, 285, 80, 50)

var jogador: Jogador


func _ready() -> void:

	# Carregar cenário
	var fundo := Sprite2D.new()
	fundo.texture = load(CENARIO)
	fundo.centered = false
	fundo.z_index = -1

	var escala := 720.0 / fundo.texture.get_height()
	var deslocamento := (
		1280.0 - fundo.texture.get_width() * escala
	) / 2.0

	fundo.scale = Vector2(escala, escala)
	fundo.position = Vector2(deslocamento, 0)

	add_child(fundo)

	# Criar jogador
	jogador = Jogador.new()

	# Posição inicial na escadaria
	jogador.position = Vector2(445, 220)

	jogador.limites = Rect2(0, 0, 1280, 720)

	# Área permitida para movimentação
	jogador.area_caminhavel = PackedVector2Array([
		Vector2(400, 175),
		Vector2(495, 175),
		Vector2(510, 240),
		Vector2(620, 270),
		Vector2(700, 370),
		Vector2(815, 390),
		Vector2(905, 290),
		Vector2(995, 290),
		Vector2(1010, 430),
		Vector2(1010, 540),
		Vector2(960, 630),
		Vector2(750, 640),
		Vector2(380, 640),
		Vector2(350, 530),
		Vector2(390, 400),
		Vector2(420, 270)
	])

	add_child(jogador)

	queue_redraw()


# Visualização temporária das colisões
func _draw() -> void:
	if not MOSTRAR_COLISAO:
		return

	if jogador == null:
		return

	var pontos := jogador.area_caminhavel.duplicate()

	if not pontos.is_empty():
		pontos.append(pontos[0])
		draw_polyline(pontos, Color.GREEN, 2.0)

# Verifica se o jogador alcançou a saída do corredor.
func _process(_delta: float) -> void:
	if jogador == null or jogador.bloqueado:
		return

	if AREA_SAIDA.has_point(jogador.position):
		# Bloqueia a movimentação durante a troca de cena.
		jogador.bloqueado = true
		get_tree().change_scene_to_file(PROXIMA_CENA)