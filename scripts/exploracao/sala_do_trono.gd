extends Node2D
## Fase 1, Tela 1 (GDD): sala do chefe.
## Spike anda pela sala (setas/WASD), fala com o Imperador Zork (Z) e recebe a ordem de
## coletar cristais para o trono. Depois sai pela escada de baixo.
## Protótipo: a saída leva direto ao combate da Tela 5 (as Telas 2 a 4 ainda não existem).
##
## Teste automático: Godot --path . -- --autoteste   (faz o caminho todo sozinho)

const CENARIO := "res://arte/cenarios/masmorra_1/sala_do_trono.png"
const PROXIMA_CENA := "res://cenas/corredor.tscn"
const DISTANCIA_CONVERSA := 150.0

# Falas provisórias: ajustem o texto à vontade.
const DIALOGO := [
	["Zork", "Spike! Olhe para este trono... sem brilho nenhum. Uma vergonha para um imperador."],
	["Zork", "Vá até a caverna e traga cristais para enfeitá-lo. E não demore!"],
	["Spike", "Sim, meu imperador. Trarei os cristais."],
	["Zork", "Ótimo. Agora suma da minha frente."],
]

var escala := 1.0          # escala do cenário (imagem 1024x765 ajustada à altura da tela)
var deslocamento := 0.0    # margem horizontal para centralizar o cenário

var jogador: Jogador
var zork: AnimatedSprite2D
var retratos := {}
var falou := false
var fala := -1
var autoteste := false

var lbl_dica: Label
var lbl_objetivo: Label
var caixa: Panel
var lbl_nome: Label
var lbl_fala: Label
var img_retrato: TextureRect


func _ready() -> void:
	autoteste = "--autoteste" in OS.get_cmdline_user_args()
	RenderingServer.set_default_clear_color(Color(0.04, 0.05, 0.07))   # laterais fora do cenário
	_montar_cenario()
	_montar_ui()
	_atualizar_objetivo()
	if autoteste:
		_teste_automatico()


## Converte um ponto da imagem do cenário (1024x765) para a tela.
func p(x: float, y: float) -> Vector2:
	return Vector2(deslocamento + x * escala, y * escala)


func _montar_cenario() -> void:
	var fundo := Sprite2D.new()
	fundo.texture = load(CENARIO)
	fundo.centered = false
	escala = 720.0 / fundo.texture.get_height()
	deslocamento = (1280.0 - fundo.texture.get_width() * escala) / 2.0
	fundo.scale = Vector2(escala, escala)
	fundo.position = Vector2(deslocamento, 0)
	add_child(fundo)

	# Personagens num nó com ordenação por Y: quem está mais abaixo fica na frente
	var mundo := Node2D.new()
	mundo.y_sort_enabled = true
	add_child(mundo)

	zork = FolhaSprites.criar("res://arte/personagens/monstros/zork_sprites", 150.0)
	var no_zork := Node2D.new()
	no_zork.position = p(512, 300)
	no_zork.add_child(zork)
	mundo.add_child(no_zork)
	FolhaSprites.posar(zork, "interacao", 0)      # sentado no trono
	retratos["Zork"] = FolhaSprites.textura(zork, "retrato")

	jogador = Jogador.new()
	jogador.position = p(512, 640)
	jogador.limites = Rect2(p(170, 420), p(860, 735) - p(170, 420))
	mundo.add_child(jogador)
	retratos["Spike"] = FolhaSprites.textura(jogador.anim, "retrato")


func _montar_ui() -> void:
	var camada := CanvasLayer.new()
	add_child(camada)
	lbl_objetivo = _label(camada, Vector2(20, 16), Vector2(700, 30), 20)
	lbl_dica = _label(camada, Vector2(0, 470), Vector2(1280, 30), 20)
	lbl_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_dica.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_dica.add_theme_constant_override("outline_size", 6)

	caixa = Panel.new()
	caixa.position = Vector2(120, 520)
	caixa.size = Vector2(1040, 180)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.07, 0.06, 0.09, 0.95)
	estilo.border_color = Color(0.5, 0.45, 0.55)
	estilo.set_border_width_all(3)
	caixa.add_theme_stylebox_override("panel", estilo)
	camada.add_child(caixa)
	img_retrato = TextureRect.new()
	img_retrato.position = Vector2(14, 14)
	img_retrato.size = Vector2(150, 150)
	img_retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img_retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img_retrato.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	caixa.add_child(img_retrato)
	lbl_nome = _label(caixa, Vector2(185, 14), Vector2(800, 30), 22)
	lbl_nome.add_theme_color_override("font_color", Color(0.93, 0.85, 0.65))
	lbl_fala = _label(caixa, Vector2(185, 50), Vector2(830, 110), 21)
	lbl_fala.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var continuar := _label(caixa, Vector2(860, 145), Vector2(170, 24), 15)
	continuar.text = "Z para continuar"
	continuar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caixa.visible = false


func _label(pai: Node, pos: Vector2, tamanho: Vector2, fonte: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = tamanho
	l.add_theme_font_size_override("font_size", fonte)
	pai.add_child(l)
	return l


func _process(_delta: float) -> void:
	if caixa.visible:
		lbl_dica.text = ""
		return
	if _perto_do_zork():
		lbl_dica.text = "Z: falar com o Imperador"
	elif falou and _na_saida():
		_sair()
	elif not falou and _na_saida():
		lbl_dica.text = "Melhor falar com o Imperador antes de sair..."
	else:
		lbl_dica.text = ""


func _perto_do_zork() -> bool:
	return jogador.position.distance_to(p(512, 300)) < DISTANCIA_CONVERSA + 60 and jogador.position.y < p(0, 470).y


func _na_saida() -> bool:
	return jogador.position.y > p(0, 725).y and absf(jogador.position.x - p(512, 0).x) < 70 * escala


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("confirmar"):
		if caixa.visible:
			_proxima_fala()
		elif _perto_do_zork():
			_iniciar_dialogo()


func _iniciar_dialogo() -> void:
	jogador.bloqueado = true
	FolhaSprites.posar(zork, "interacao", 2)      # apontando: dá a ordem
	fala = -1
	caixa.visible = true
	_proxima_fala()


func _proxima_fala() -> void:
	fala += 1
	if fala >= DIALOGO.size():
		caixa.visible = false
		jogador.bloqueado = false
		FolhaSprites.posar(zork, "interacao", 1)  # acena com desdém
		falou = true
		_atualizar_objetivo()
		return
	var quem: String = DIALOGO[fala][0]
	lbl_nome.text = quem.to_upper()
	lbl_fala.text = DIALOGO[fala][1]
	img_retrato.texture = retratos[quem]
	if autoteste:
		print("%s: %s" % [quem, DIALOGO[fala][1]])


func _atualizar_objetivo() -> void:
	if falou:
		lbl_objetivo.text = "Objetivo: buscar cristais (saia pela escada de baixo)"
	else:
		lbl_objetivo.text = "Objetivo: falar com o Imperador Zork"


func _sair() -> void:
	set_process(false)
	jogador.bloqueado = true
	if autoteste:
		print("SALA DO TRONO: saiu pela escada")
	var t := create_tween()
	t.tween_property(self, "modulate", Color.BLACK, 0.5)
	await t.finished
	get_tree().change_scene_to_file(PROXIMA_CENA)


## Faz o caminho da cena sozinho: vai até o Zork, conversa e sai.
func _teste_automatico() -> void:
	Engine.time_scale = 4.0
	await get_tree().create_timer(0.5).timeout
	jogador.entrada_simulada = Vector2(0, -1)
	while not _perto_do_zork():
		await get_tree().process_frame
	jogador.entrada_simulada = Vector2.ZERO
	print("SALA DO TRONO: chegou perto do Zork")
	_iniciar_dialogo()
	while caixa.visible:
		await get_tree().create_timer(0.3).timeout
		_proxima_fala()
	jogador.entrada_simulada = Vector2(0, 1)
	while is_processing():
		await get_tree().process_frame
