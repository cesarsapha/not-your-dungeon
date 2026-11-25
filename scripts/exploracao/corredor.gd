
extends Node2D

const CENARIO := "res://arte/cenarios/masmorra_1/corredor.png"

const MOSTRAR_COLISAO := false

# Próxima sala da primeira fase.
const PROXIMA_CENA := "res://cenas/camara_cristais.tscn"

# Área que ativa a passagem para a próxima sala.
const AREA_SAIDA := Rect2(915, 285, 80, 50)

# Picareta que o Spike precisa pegar para minerar o cristal na próxima sala.
const PONTO_PICARETA := Vector2(640, 545)
const FOLHA_PICARETA := "res://arte/objetos/picareta_ferro_sprites"

var jogador: Jogador
var picareta: ItemColetavel
var aviso: Label


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

	# A picareta só aparece se ainda não foi pega
	if not get_tree().get_meta("picareta_coletada", false):
		picareta = ItemColetavel.criar(FOLHA_PICARETA, PONTO_PICARETA, 52.0)
		add_child(picareta)

	_criar_aviso()
	queue_redraw()


func _criar_aviso() -> void:
	aviso = Label.new()
	aviso.add_theme_font_size_override("font_size", 20)
	aviso.add_theme_color_override("font_color", Color.WHITE)
	aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	aviso.add_theme_constant_override("outline_size", 5)
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.size = Vector2(420, 30)
	aviso.z_index = 10
	aviso.hide()
	add_child(aviso)


func _mostrar_aviso(texto: String) -> void:
	aviso.text = texto
	aviso.position = jogador.position + Vector2(-210, -145)
	aviso.show()


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

	var tem_picareta: bool = get_tree().get_meta("picareta_coletada", false)

	if is_instance_valid(picareta) and picareta.perto(jogador.position):
		_mostrar_aviso("[Z] Pegar picareta")
	elif AREA_SAIDA.has_point(jogador.position) and not tem_picareta:
		# A câmara dos cristais não tem volta: sem picareta o jogador ficaria preso
		_mostrar_aviso("Melhor levar aquela picareta para os cristais...")
	elif AREA_SAIDA.has_point(jogador.position):
		# Bloqueia a movimentação durante a troca de cena.
		jogador.bloqueado = true
		get_tree().change_scene_to_file(PROXIMA_CENA)
	elif aviso.visible and not aviso.text.begins_with("Picareta"):
		aviso.hide()


# Z perto da picareta: pega e guarda (fica marcado para as próximas salas).
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode != KEY_Z or jogador == null or jogador.bloqueado:
		return
	if is_instance_valid(picareta) and picareta.perto(jogador.position):
		get_tree().set_meta("picareta_coletada", true)
		picareta.coletar()
		picareta = null
		_mostrar_aviso("Picareta obtida!")
		await get_tree().create_timer(1.5).timeout
		if is_instance_valid(aviso):
			aviso.hide()