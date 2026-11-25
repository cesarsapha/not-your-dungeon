
extends Node2D
## Câmara dos cristais — terceira tela da primeira fase.
## Introduz a mineração e a emboscada dos mercenários.

const CENARIO := "res://arte/cenarios/masmorra_1/camara_cristais.png"
const TEXTURA_FLECHA := "res://arte/objetos/flecha.png"

# Próxima sala da primeira fase.
const PROXIMA_CENA := "res://cenas/sala_resgate.tscn"

# Configurações de interação.
const DISTANCIA_INTERACAO := 55.0
const PICARETADAS_EMBOSCADA := 3

# Visualização dos limites de movimentação.
const MOSTRAR_COLISAO := false

var jogador: Jogador

# Escala e deslocamento utilizados para centralizar o cenário.
var escala: float
var deslocamento: float

# Posições das interações da sala.
var ponto_mineracao: Vector2
var ponto_saida: Vector2

# Controle do progresso da mineração.
var picaretadas := 0
var minerando := false
var emboscada_ativada := false

# Elementos visuais.
var aviso: Label
var flecha: Sprite2D


func _ready() -> void:
	# -------------------------------------------------- Cenário

	var fundo := Sprite2D.new()
	fundo.texture = load(CENARIO)
	fundo.centered = false
	fundo.z_index = -1

	# Ajusta o cenário à altura da tela, preservando sua proporção.
	escala = 720.0 / fundo.texture.get_height()
	deslocamento = (
		1280.0 - fundo.texture.get_width() * escala
	) / 2.0

	fundo.scale = Vector2(escala, escala)
	fundo.position = Vector2(deslocamento, 0)
	add_child(fundo)

	# -------------------------------------------------- Jogador

	jogador = Jogador.new()

	# Entrada pela abertura da caverna à esquerda.
	jogador.position = _coordenada(Vector2(320, 310))
	jogador.limites = Rect2(0, 0, 1280, 720)

	# Área caminhável definida na imagem original.
	var pontos := PackedVector2Array([
		Vector2(265, 270),
		Vector2(365, 270),
		Vector2(420, 325),
		Vector2(475, 325),
		Vector2(475, 410),
		Vector2(485, 515),
		Vector2(590, 550),
		Vector2(700, 525),
		Vector2(785, 475),
		Vector2(920, 435),
		Vector2(950, 365),
		Vector2(1015, 290),
		Vector2(1080, 330),
		Vector2(1050, 420),
		Vector2(1080, 490),
		Vector2(1090, 570),
		Vector2(1050, 675),
		Vector2(1010, 745),
		Vector2(925, 760),
		Vector2(895, 695),
		Vector2(785, 710),
		Vector2(705, 690),
		Vector2(570, 700),
		Vector2(435, 710),
		Vector2(310, 665),
		Vector2(220, 610),
		Vector2(180, 490),
		Vector2(250, 460),
		Vector2(275, 380)
	])

	# Converte o polígono para as coordenadas do jogo.
	var poligono := PackedVector2Array()

	for ponto in pontos:
		poligono.append(_coordenada(ponto))

	jogador.area_caminhavel = poligono
	add_child(jogador)

	# -------------------------------------------------- Interações

	# Posição em frente ao cristal principal.
	ponto_mineracao = _coordenada(Vector2(435, 500))

	# Saída para a sala de resgate.
	ponto_saida = _coordenada(Vector2(1045, 335))

	_criar_aviso()
	_criar_flecha()

	queue_redraw()


# Converte coordenadas da imagem original
# para as coordenadas da tela do jogo.
func _coordenada(ponto: Vector2) -> Vector2:
	return ponto * escala + Vector2(deslocamento, 0)


# -------------------------------------------------- Interface

# Cria o texto utilizado nas interações com o cenário.
func _criar_aviso() -> void:
	aviso = Label.new()
	aviso.add_theme_font_size_override("font_size", 20)
	aviso.add_theme_color_override("font_color", Color.WHITE)
	aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	aviso.add_theme_constant_override("outline_size", 5)
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.z_index = 10
	aviso.hide()
	add_child(aviso)


# Exibe uma mensagem acima do jogador.
func _mostrar_aviso(texto: String) -> void:
	aviso.text = texto
	aviso.size = Vector2(320, 30)
	aviso.position = jogador.position + Vector2(-160, -145)
	aviso.show()


# -------------------------------------------------- Flecha

# Cria o projétil, inicialmente invisível.
func _criar_flecha() -> void:
	flecha = Sprite2D.new()
	flecha.texture = load(TEXTURA_FLECHA)
	flecha.z_index = 2

	# Redimensiona a flecha para aproximadamente 35 pixels.
	var tamanho := 35.0 / flecha.texture.get_width()
	flecha.scale = Vector2(tamanho, tamanho)

	flecha.hide()
	add_child(flecha)


# -------------------------------------------------- Interação

func _process(_delta: float) -> void:
	if jogador == null or minerando:
		return

	# Verifica a proximidade do cristal principal.
	var perto_cristal := jogador.position.distance_to(
		ponto_mineracao
	) <= DISTANCIA_INTERACAO

	# Verifica a proximidade da saída.
	var perto_saida := jogador.position.distance_to(
		ponto_saida
	) <= DISTANCIA_INTERACAO

	if perto_cristal and not emboscada_ativada:
		if get_tree().get_meta("picareta_coletada", false):
			_mostrar_aviso("[Z] Minerar")
		else:
			_mostrar_aviso("Preciso de uma picareta para minerar.")

	elif perto_saida:
		if emboscada_ativada:
			# Libera a passagem somente após a emboscada.
			jogador.bloqueado = true
			get_tree().change_scene_to_file(PROXIMA_CENA)
		else:
			_mostrar_aviso("Preciso coletar os cristais.")

	else:
		aviso.hide()


# Detecta um pressionamento individual da tecla Z.
# Ignora repetições causadas por manter a tecla pressionada.
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	if not event.pressed or event.echo:
		return

	if event.physical_keycode != KEY_Z:
		return

	if jogador == null or minerando or emboscada_ativada:
		return

	if jogador.position.distance_to(ponto_mineracao) <= DISTANCIA_INTERACAO:
		if get_tree().get_meta("picareta_coletada", false):
			_minerar()


# -------------------------------------------------- Mineração

# Executa uma picaretada e verifica o progresso da mineração.
func _minerar() -> void:
	minerando = true

	# Impede que o personagem se movimente durante a interação.
	jogador.bloqueado = true
	jogador.interagindo = true

	aviso.hide()

	# Reposiciona Spike próximo ao cristal.
	jogador.position = ponto_mineracao

	# Executa a animação de mineração da folha de exploração.
	FolhaSprites.virar(jogador.anim, false)
	# Reinicia a animação de mineração desde o primeiro quadro.
	jogador.anim.stop()
	jogador.anim.play("interacao")
	jogador.anim.frame = 0

	# Aguarda os três quadros da mineração (5 FPS).
	# Evita que o jogador fique bloqueado caso o sinal
	# de conclusão da animação não seja emitido.
	await get_tree().create_timer(0.6).timeout

	picaretadas += 1

	# Na terceira picaretada, inicia a emboscada.
	if picaretadas == PICARETADAS_EMBOSCADA:
		await _ativar_emboscada()

	# Devolve o controle ao jogador.
	jogador.interagindo = false
	jogador.bloqueado = false
	minerando = false


# -------------------------------------------------- Emboscada

func _ativar_emboscada() -> void:
	emboscada_ativada = true

	# Pequena pausa antes do disparo.
	await get_tree().create_timer(0.2).timeout

	# A flecha parte da entrada superior direita.
	var origem := ponto_saida

	# A flecha erra Spike e atinge o cristal principal.
	var destino := _coordenada(Vector2(615, 400))

	flecha.position = origem

	# A textura original aponta para a esquerda.
	# Soma PI para alinhar a ponta com a direção do disparo.
	flecha.rotation = (destino - origem).angle() + PI

	flecha.show()

	# Anima o deslocamento da flecha.
	var disparo := create_tween()

	disparo.tween_property(
		flecha,
		"position",
		destino,
		0.35
	)

	await disparo.finished

	# Spike reage à presença dos invasores.
	FolhaSprites.posar(jogador.anim, "alerta")

	_mostrar_aviso("?!")

	await get_tree().create_timer(1.0).timeout

	aviso.hide()


# -------------------------------------------------- Depuração

# Visualiza a área caminhável e os pontos de interação.
func _draw() -> void:
	if not MOSTRAR_COLISAO or jogador == null:
		return

	var pontos := jogador.area_caminhavel.duplicate()

	if not pontos.is_empty():
		pontos.append(pontos[0])
		draw_polyline(pontos, Color.GREEN, 2.0)

	draw_circle(ponto_mineracao, 6.0, Color.YELLOW)
	draw_circle(ponto_saida, 6.0, Color.CYAN)
