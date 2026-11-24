
extends Node2D
## Sala de resgate — quarta tela da primeira fase.
## Spike encontra Gordot aprisionado pelos mercenários.

const CENARIO := "res://arte/cenarios/masmorra_1/sala_resgate.png"
const TEXTURA_GORDOT := "res://arte/personagens/monstros/gordot_preso.png"

# Ativa a visualização temporária das colisões.
const MOSTRAR_COLISAO := false

# Distâncias de interação em pixels da tela.
const DISTANCIA_CHAVE := 55.0
const DISTANCIA_GORDOT := 90.0
# A última sala possui uma cena própria para apresentar o chefe.
const PROXIMA_CENA := "res://cenas/sala_final.tscn"
const TRANSICAO = preload("res://scripts/exploracao/transicao_combate.gd")
const VELOCIDADE_GORDOT := 185.0
const PASSO_RASTRO := 12.0
const DISTANCIA_SEGUIR := 78.0

# Falas provisórias: a equipe pode editar o texto sem mudar a lógica.
const DIALOGO := [
	["Gordot", "Obrigado por me libertar... Eu e Kepis, meu amigo goblin estávamos sendo perseguidos por mercenários."],
	["Gordot", "Encontramos esta masmorra durante a fuga e tentamos nos esconder aqui, mas eles nos alcançaram."],
	["Gordot", "Precisamos sair daqui. Tinha mais mercenários nos perseguindo."],
	["Spike", "Esta é a nossa masmorra. Não podemos simplesmente deixá-los invadir."],
	["Spike", "Vamos enfrentá-los. Juntos teremos uma chance melhor."],
	["Gordot", "Certo. Conte comigo."]
]

var jogador: Jogador
var gordot_preso: Sprite2D
var gordot_livre: AnimatedSprite2D
var chave: Polygon2D
var aviso: Label
var ponto_chave: Vector2
var mensagem_temporaria := false

# Nó que representa a posição dos pés de Gordot e caminho percorrido por Spike.
var apoio_gordot: Node2D
var rastro: Array[Vector2] = []
var ultima_animacao_gordot := "andar_frente"

# Interface de diálogo, seguindo o estilo da sala do trono.
var caixa_dialogo: Panel
var lbl_nome: Label
var lbl_fala: Label
var img_retrato: TextureRect
var indice_fala := -1

# Escala e deslocamento do cenário na tela.
var escala: float
var deslocamento: float

# Posições utilizadas nos eventos da sala.
var ponto_resgate: Vector2
var ponto_saida: Vector2


func _ready() -> void:
	# -------------------------------------------------- Cenário
	# Ordena os personagens pela posição vertical dos pés.
	# Quem estiver mais abaixo na tela será desenhado na frente.
	y_sort_enabled = true

	# Carrega a imagem de fundo da sala.
	var fundo := Sprite2D.new()
	fundo.texture = load(CENARIO)
	fundo.centered = false
	fundo.z_index = -1

	# Ajusta o cenário à resolução do jogo,
	# preservando a proporção da imagem original.
	escala = 720.0 / fundo.texture.get_height()
	deslocamento = (
		1280.0 - fundo.texture.get_width() * escala
	) / 2.0

	fundo.scale = Vector2(escala, escala)
	fundo.position = Vector2(deslocamento, 0)
	add_child(fundo)

	# -------------------------------------------------- Jogador

	jogador = Jogador.new()

	# Spike aparece na escadaria esquerda.
	jogador.position = _coordenada(Vector2(245, 325))
	# Após vencer, Spike retorna ao centro da área de combate.
	if get_tree().get_meta("resgate_vencido", false):
		jogador.position = _coordenada(Vector2(420, 480))
	jogador.limites = Rect2(0, 0, 1280, 720)

	_atualizar_colisoes()
	add_child(jogador)

	# Posição de Gordot, próxima à parede do fundo.
	ponto_resgate = _coordenada(Vector2(710, 410))

	# Gordot permanece preso até ser libertado pelo jogador.
	if not get_tree().get_meta("gordot_recrutado", false):
		_criar_gordot_preso()
	else:
		_criar_gordot_livre()

	# Saída pela escadaria direita.
	ponto_saida = _coordenada(Vector2(1000, 305))

	# A chave surge no chão somente após a vitória.
	ponto_chave = _coordenada(Vector2(620, 560))
	_criar_aviso()
	_criar_dialogo()
	if get_tree().get_meta("resgate_vencido", false) and not get_tree().get_meta("chave_coletada", false) and not get_tree().get_meta("gordot_recrutado", false):
		_criar_chave()

	queue_redraw()

	# Na primeira entrada, inicia a batalha automaticamente.
	# A chamada adiada evita trocar a cena enquanto ela ainda está sendo montada.
	if not get_tree().get_meta("resgate_vencido", false):
		jogador.bloqueado = true
		_iniciar_combate.call_deferred()


# Recalcula os limites quando Gordot é libertado.
func _atualizar_colisoes() -> void:
	# Evita paredes, colunas, cristais e obstáculos.
	var pontos := PackedVector2Array([
		Vector2(205, 280),
		Vector2(275, 265),
		Vector2(320, 345),
		Vector2(420, 380),
		Vector2(565, 385),
		Vector2(790, 355),
		Vector2(955, 260),
		Vector2(1040, 285),
		Vector2(1060, 325),
		Vector2(975, 450),
		Vector2(980, 505),
		Vector2(990, 610),
		Vector2(975, 670),
		Vector2(910, 715),
		Vector2(850, 650),
		Vector2(780, 655),
		Vector2(650, 685),
		Vector2(610, 770),
		Vector2(440, 770),
		Vector2(425, 670),
		Vector2(280, 625),
		Vector2(185, 600),
		Vector2(165, 530),
		Vector2(190, 460),
		Vector2(245, 405),
		Vector2(200, 360)
	])

	# Acrescenta o recuo que impede a passagem pelos pés de Gordot preso.
	if not get_tree().get_meta("gordot_recrutado", false):
		pontos.insert(5, Vector2(610, 375))
		pontos.insert(6, Vector2(610, 460))
		pontos.insert(7, Vector2(810, 460))
		pontos.insert(8, Vector2(810, 345))

	# Converte os pontos da imagem para a tela do jogo.
	var poligono := PackedVector2Array()

	for ponto in pontos:
		poligono.append(_coordenada(ponto))

	jogador.area_caminhavel = poligono


# Converte coordenadas da imagem original
# para as coordenadas utilizadas pelo jogo.
func _coordenada(ponto: Vector2) -> Vector2:
	return ponto * escala + Vector2(deslocamento, 0)


# Cria o sprite estático de Gordot acorrentado.
func _criar_gordot_preso() -> void:
	# Verifica se a textura existe antes de carregar.
	if not ResourceLoader.exists(TEXTURA_GORDOT):
		push_error("Textura de Gordot preso não encontrada.")
		return

	gordot_preso = Sprite2D.new()
	gordot_preso.texture = load(TEXTURA_GORDOT)

	# Define a altura visual de Gordot ajoelhado.
	var tamanho := 90.0 / gordot_preso.texture.get_height()
	gordot_preso.scale = Vector2(tamanho, tamanho)

	# Alinha a base do sprite ao ponto de resgate.
	gordot_preso.position = ponto_resgate
	gordot_preso.offset.y = -gordot_preso.texture.get_height() / 2.0

	gordot_preso.z_index = 0

	add_child(gordot_preso)


# -------------------------------------------------- Depuração

# Exibe os limites de movimentação e pontos de interação.
func _draw() -> void:
	if not MOSTRAR_COLISAO or jogador == null:
		return

	var pontos := jogador.area_caminhavel.duplicate()

	if not pontos.is_empty():
		pontos.append(pontos[0])
		draw_polyline(pontos, Color.GREEN, 2.0)

	# Amarelo: localização de Gordot.
	draw_circle(ponto_resgate, 6.0, Color.YELLOW)

	# Azul: saída para a próxima sala.
	draw_circle(ponto_saida, 6.0, Color.CYAN)

# Inicia o primeiro combate da fase.
func _iniciar_combate() -> void:
	jogador.bloqueado = true

	# Informa ao sistema de combate qual encontro deve carregar.
	get_tree().set_meta("encontro", "resgate")

	# Mostra os invasores durante a introdução, antes da troca de cena.
	TRANSICAO.criar_pose(self, "res://arte/inimigos/mercenario_sprites", 100.0, _coordenada(Vector2(580, 465)), true)
	TRANSICAO.criar_pose(self, "res://arte/inimigos/mercenario_arqueiro_sprites", 100.0, _coordenada(Vector2(850, 470)), true)
	await TRANSICAO.executar(self, "EMBOSCADA!")
	get_tree().change_scene_to_file("res://cenas/combate.tscn")

# -------------------------------------------------- Chave e resgate

# Representação temporária da chave, sem depender de uma textura.
func _criar_chave() -> void:
	chave = Polygon2D.new()
	chave.polygon = PackedVector2Array([
		Vector2(0, -10), Vector2(10, 0),
		Vector2(0, 10), Vector2(-10, 0)
	])
	chave.color = Color.GOLD
	chave.position = ponto_chave
	add_child(chave)


# Texto de interação, desenhado acima dos personagens.
func _criar_aviso() -> void:
	aviso = Label.new()
	aviso.add_theme_font_size_override("font_size", 20)
	aviso.add_theme_color_override("font_color", Color.WHITE)
	aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	aviso.add_theme_constant_override("outline_size", 5)
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso.z_index = 10
	aviso.hide()
	add_child(aviso)


func _mostrar_aviso(texto: String) -> void:
	aviso.text = texto
	aviso.size = Vector2(440, 30)
	aviso.position = jogador.position + Vector2(-220, -145)
	aviso.show()


# Atualiza os avisos conforme o progresso e a posição de Spike.
func _process(delta: float) -> void:
	if jogador == null or jogador.bloqueado or mensagem_temporaria:
		return
	if not get_tree().get_meta("resgate_vencido", false):
		return

	_seguir_spike(delta)

	if is_instance_valid(chave) and jogador.position.distance_to(ponto_chave) <= DISTANCIA_CHAVE:
		_mostrar_aviso("[Z] Coletar chave")
	elif not get_tree().get_meta("gordot_recrutado", false) and jogador.position.distance_to(ponto_resgate) <= DISTANCIA_GORDOT:
		if get_tree().get_meta("chave_coletada", false):
			_mostrar_aviso("[Z] Libertar Gordot")
		else:
			_mostrar_aviso("Preciso da chave das correntes.")
	elif jogador.position.distance_to(ponto_saida) <= 55.0:
		if get_tree().get_meta("gordot_recrutado", false):
			if ResourceLoader.exists(PROXIMA_CENA):
				_mostrar_aviso("[Z] Avançar")
			else:
				_mostrar_aviso("Cena final não encontrada.")
		else:
			_mostrar_aviso("Preciso libertar Gordot primeiro.")
	else:
		aviso.hide()


# Uma interação por pressionamento de Z, sem repetição automática.
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo or event.physical_keycode != KEY_Z:
		return
	# Durante o diálogo, Z avança as falas mesmo com Spike bloqueado.
	if is_instance_valid(caixa_dialogo) and caixa_dialogo.visible:
		_proxima_fala()
		return
	if jogador == null or jogador.bloqueado or mensagem_temporaria:
		return
	if not get_tree().get_meta("resgate_vencido", false):
		return

	if is_instance_valid(chave) and jogador.position.distance_to(ponto_chave) <= DISTANCIA_CHAVE:
		# Registra a chave como item de missão, sem inventário visual.
		get_tree().set_meta("chave_coletada", true)
		chave.queue_free()
		chave = null
		await _mensagem("Chave das correntes obtida!")
	elif not get_tree().get_meta("gordot_recrutado", false) and get_tree().get_meta("chave_coletada", false) and jogador.position.distance_to(ponto_resgate) <= DISTANCIA_GORDOT:
		_libertar_gordot()
	elif get_tree().get_meta("gordot_recrutado", false) and jogador.position.distance_to(ponto_saida) <= 55.0:
		# Avança para a cena que apresenta o confronto final.
		if ResourceLoader.exists(PROXIMA_CENA):
			jogador.bloqueado = true
			var erro := get_tree().change_scene_to_file(PROXIMA_CENA)
			if erro != OK:
				jogador.bloqueado = false


# Substitui Gordot preso pela pose normal da folha de exploração.
func _criar_gordot_livre() -> void:
	gordot_livre = FolhaSprites.criar("res://arte/personagens/monstros/gordot_sprites", 125.0)
	if gordot_livre == null:
		push_warning("Folha de Gordot não encontrada.")
		return
	# A folha usa um deslocamento próprio para alinhar os pés.
	# Um nó pai mantém esse deslocamento e permite ordenar pela profundidade.
	apoio_gordot = Node2D.new()
	apoio_gordot.position = ponto_resgate
	add_child(apoio_gordot)
	apoio_gordot.add_child(gordot_livre)
	# Registra o ponto inicial do trajeto para o seguidor.
	rastro.clear()
	rastro.append(jogador.position)
	FolhaSprites.posar(gordot_livre, "andar_frente", 0)


# Liberta e recruta Gordot, removendo o obstáculo das correntes.
func _libertar_gordot() -> void:
	get_tree().set_meta("gordot_recrutado", true)
	if is_instance_valid(gordot_preso):
		gordot_preso.queue_free()
		gordot_preso = null
	_criar_gordot_livre()
	_atualizar_colisoes()
	queue_redraw()
	_iniciar_dialogo()


# Mantém a mensagem visível por um breve período.
func _mensagem(texto: String) -> void:
	mensagem_temporaria = true
	jogador.bloqueado = true
	_mostrar_aviso(texto)
	await get_tree().create_timer(1.5).timeout
	aviso.hide()
	jogador.bloqueado = false
	mensagem_temporaria = false


# -------------------------------------------------- Diálogo

# Cria uma caixa de diálogo com o mesmo estilo visual da sala do trono.
func _criar_dialogo() -> void:
	var camada := CanvasLayer.new()
	add_child(camada)
	caixa_dialogo = Panel.new()
	caixa_dialogo.position = Vector2(120, 520)
	caixa_dialogo.size = Vector2(1040, 180)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.07, 0.06, 0.09, 0.95)
	estilo.border_color = Color(0.5, 0.45, 0.55)
	estilo.set_border_width_all(3)
	caixa_dialogo.add_theme_stylebox_override("panel", estilo)
	camada.add_child(caixa_dialogo)

	img_retrato = TextureRect.new()
	img_retrato.position = Vector2(14, 14)
	img_retrato.size = Vector2(150, 150)
	img_retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img_retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	caixa_dialogo.add_child(img_retrato)
	lbl_nome = _label_dialogo(Vector2(185, 14), Vector2(800, 30), 22)
	lbl_nome.add_theme_color_override("font_color", Color(0.93, 0.85, 0.65))
	lbl_fala = _label_dialogo(Vector2(185, 50), Vector2(830, 100), 21)
	lbl_fala.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var continuar := _label_dialogo(Vector2(860, 145), Vector2(170, 24), 15)
	continuar.text = "Z para continuar"
	continuar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caixa_dialogo.hide()


# Cria um texto dentro da caixa de diálogo.
func _label_dialogo(pos: Vector2, tamanho: Vector2, fonte: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = tamanho
	l.add_theme_font_size_override("font_size", fonte)
	caixa_dialogo.add_child(l)
	return l


# Bloqueia a exploração enquanto os personagens conversam.
func _iniciar_dialogo() -> void:
	jogador.bloqueado = true
	aviso.hide()
	indice_fala = -1
	caixa_dialogo.show()
	_proxima_fala()


# Avança uma fala por pressionamento de Z e libera o jogador no final.
func _proxima_fala() -> void:
	indice_fala += 1
	if indice_fala >= DIALOGO.size():
		caixa_dialogo.hide()
		await _mensagem("Gordot entrou para a equipe!")
		return
	var quem: String = DIALOGO[indice_fala][0]
	lbl_nome.text = quem.to_upper()
	lbl_fala.text = DIALOGO[indice_fala][1]
	var sprite: AnimatedSprite2D = jogador.anim if quem == "Spike" else gordot_livre
	img_retrato.texture = null
	if is_instance_valid(sprite) and sprite.sprite_frames.has_animation("retrato"):
		img_retrato.texture = FolhaSprites.textura(sprite, "retrato")


# -------------------------------------------------- Seguidor

# Gordot percorre os pontos por onde Spike passou, em vez de cortar caminho
# diretamente até ele. Assim acompanha as curvas e contorna os obstáculos.
func _seguir_spike(delta: float) -> void:
	if not is_instance_valid(apoio_gordot) or not is_instance_valid(gordot_livre):
		return
	if rastro.is_empty():
		rastro.append(jogador.position)
	if rastro.back().distance_to(jogador.position) >= PASSO_RASTRO:
		rastro.append(jogador.position)

	# Conserva uma distância aproximada entre os personagens.
	var distancia_rastro := 0.0
	for i in range(1, rastro.size()):
		distancia_rastro += rastro[i - 1].distance_to(rastro[i])
	if distancia_rastro < DISTANCIA_SEGUIR:
		FolhaSprites.posar(gordot_livre, ultima_animacao_gordot, 0)
		return

	var alvo: Vector2 = rastro[0]
	var anterior := apoio_gordot.position
	apoio_gordot.position = anterior.move_toward(alvo, VELOCIDADE_GORDOT * delta)
	var movimento := apoio_gordot.position - anterior
	if apoio_gordot.position.distance_to(alvo) < 0.5 and rastro.size() > 1:
		rastro.pop_front()

	# Reaproveita as animações existentes da folha de exploração de Gordot.
	if movimento.length_squared() < 0.01:
		FolhaSprites.posar(gordot_livre, ultima_animacao_gordot, 0)
		return
	if absf(movimento.x) >= absf(movimento.y):
		ultima_animacao_gordot = "andar_lado"
		FolhaSprites.virar(gordot_livre, movimento.x < 0)
	elif movimento.y > 0:
		ultima_animacao_gordot = "andar_frente"
		FolhaSprites.virar(gordot_livre, false)
	else:
		ultima_animacao_gordot = "costas"
		FolhaSprites.virar(gordot_livre, false)
		FolhaSprites.posar(gordot_livre, "costas")
		return
	if gordot_livre.animation != ultima_animacao_gordot or not gordot_livre.is_playing():
		gordot_livre.play(ultima_animacao_gordot)
