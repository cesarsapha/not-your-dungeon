extends Node2D
## Tela inicial: logo, fundo da sala do trono escurecido e o menu Jogar / Sair.
##
## Controles: setas/WASD (ou passar o mouse) escolhem; Z, Enter ou clique confirmam.
## Teste automático: Godot --path . -- --autoteste   (escolhe Jogar e segue para a fase)

const CENARIO := "res://arte/cenarios/masmorra_1/sala_do_trono.png"
const LOGO := "res://arte/ui/logo_transparente.png"
const PRIMEIRA_CENA := "res://cenas/sala_do_trono.tscn"

# Tochas da sala do trono, em pixels da imagem original (1024x765)
const TOCHAS := [Vector2(367, 330), Vector2(655, 330)]

const COR_NORMAL := Color(0.78, 0.72, 0.62)
const COR_ESCOLHIDA := Color(1.0, 0.84, 0.45)

var escala := 1.0
var deslocamento := 0.0
var opcoes: Array[Label] = []
var indice := 0
var saindo := false
var autoteste := false

var logo: Sprite2D
var marcador: Label
var luzes: Array[Sprite2D] = []
var cortina: ColorRect


func _ready() -> void:
	autoteste = "--autoteste" in OS.get_cmdline_user_args()
	RenderingServer.set_default_clear_color(Color(0.04, 0.05, 0.07))
	_montar_fundo()
	_montar_luzes()
	_montar_particulas()
	_montar_logo()
	_montar_menu()
	_montar_cortina()
	_escolher(0)
	# Entrada: a tela clareia a partir do preto
	var t := create_tween()
	t.tween_property(cortina, "color:a", 0.0, 0.8)
	if autoteste:
		await get_tree().create_timer(1.0).timeout
		print("TELA INICIAL: Jogar")
		_confirmar()


## Converte um ponto da imagem do cenário (1024x765) para a tela.
func p(x: float, y: float) -> Vector2:
	return Vector2(deslocamento + x * escala, y * escala)


func _montar_fundo() -> void:
	var fundo := Sprite2D.new()
	fundo.texture = load(CENARIO)
	fundo.centered = false
	escala = 720.0 / fundo.texture.get_height()
	deslocamento = (1280.0 - fundo.texture.get_width() * escala) / 2.0
	fundo.scale = Vector2(escala, escala)
	fundo.position = Vector2(deslocamento, 0)
	fundo.modulate = Color(0.42, 0.42, 0.5)          # sala escurecida
	add_child(fundo)

	# Escurece mais as bordas (vinheta) para destacar o centro
	var vinheta := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.85))
	grad.set_offset(0, 0.45)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.45)
	tex.fill_to = Vector2(1.05, 1.05)
	tex.width = 256
	tex.height = 144
	vinheta.texture = tex
	vinheta.stretch_mode = TextureRect.STRETCH_SCALE
	vinheta.size = Vector2(1280, 720)
	vinheta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vinheta)


## Brilho alaranjado em cima de cada tocha, piscando de leve.
func _montar_luzes() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.62, 0.25, 0.55))
	grad.set_color(1, Color(1.0, 0.45, 0.1, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	for ponto: Vector2 in TOCHAS:
		var luz := Sprite2D.new()
		luz.texture = tex
		luz.position = p(ponto.x, ponto.y)
		luz.scale = Vector2(2.2, 2.2)
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		luz.material = material
		add_child(luz)
		luzes.append(luz)
		_piscar(luz)


func _piscar(luz: Sprite2D) -> void:
	while is_instance_valid(luz):
		var t := create_tween()
		t.tween_property(luz, "modulate:a", randf_range(0.55, 1.0), randf_range(0.08, 0.2))
		await t.finished


## Fagulhas de cristal subindo devagar pela tela.
func _montar_particulas() -> void:
	var fagulhas := CPUParticles2D.new()
	fagulhas.position = Vector2(640, 740)
	fagulhas.amount = 40
	fagulhas.lifetime = 7.0
	fagulhas.preprocess = 7.0
	fagulhas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fagulhas.emission_rect_extents = Vector2(560, 10)
	fagulhas.direction = Vector2(0, -1)
	fagulhas.spread = 12.0
	fagulhas.gravity = Vector2.ZERO
	fagulhas.initial_velocity_min = 25.0
	fagulhas.initial_velocity_max = 60.0
	fagulhas.scale_amount_min = 2.0
	fagulhas.scale_amount_max = 4.0
	var cores := Gradient.new()
	cores.set_color(0, Color(0.45, 0.95, 1.0, 0.0))
	cores.add_point(0.2, Color(0.45, 0.95, 1.0, 0.85))
	cores.set_color(cores.get_point_count() - 1, Color(0.45, 0.95, 1.0, 0.0))
	fagulhas.color_ramp = cores
	add_child(fagulhas)


func _montar_logo() -> void:
	logo = Sprite2D.new()
	logo.texture = load(LOGO)
	var largura := 700.0
	logo.scale = Vector2.ONE * largura / logo.texture.get_width()
	logo.position = Vector2(640, 200)
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(logo)
	# Flutua devagar
	var t := create_tween().set_loops()
	t.tween_property(logo, "position:y", 192.0, 2.0).set_trans(Tween.TRANS_SINE)
	t.tween_property(logo, "position:y", 200.0, 2.0).set_trans(Tween.TRANS_SINE)


func _montar_menu() -> void:
	var camada := CanvasLayer.new()
	add_child(camada)
	for i in 2:
		var l := Label.new()
		l.text = ["JOGAR", "SAIR"][i]
		l.add_theme_font_size_override("font_size", 40)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 10)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(320, 56)
		l.position = Vector2(480, 440 + i * 72)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.mouse_entered.connect(_escolher.bind(i))
		l.gui_input.connect(_clique.bind(i))
		camada.add_child(l)
		opcoes.append(l)
	marcador = Label.new()
	marcador.text = "»"
	marcador.add_theme_font_size_override("font_size", 40)
	marcador.add_theme_color_override("font_color", COR_ESCOLHIDA)
	marcador.add_theme_color_override("font_outline_color", Color.BLACK)
	marcador.add_theme_constant_override("outline_size", 10)
	camada.add_child(marcador)
	var dica := Label.new()
	dica.text = "Setas / WASD: escolher     Z / Enter: confirmar"
	dica.add_theme_font_size_override("font_size", 16)
	dica.add_theme_color_override("font_color", Color(0.65, 0.62, 0.58))
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dica.size = Vector2(1280, 24)
	dica.position = Vector2(0, 680)
	camada.add_child(dica)


func _montar_cortina() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 10
	add_child(camada)
	cortina = ColorRect.new()
	cortina.color = Color(0, 0, 0, 1)
	cortina.size = Vector2(1280, 720)
	cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(cortina)


func _escolher(i: int) -> void:
	if saindo:
		return
	indice = i
	for k in opcoes.size():
		opcoes[k].add_theme_color_override("font_color", COR_ESCOLHIDA if k == i else COR_NORMAL)
		opcoes[k].scale = Vector2.ONE * (1.08 if k == i else 1.0)
		opcoes[k].pivot_offset = opcoes[k].size / 2
	var largura_texto := opcoes[i].get_theme_font("font").get_string_size(
		opcoes[i].text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	marcador.position = opcoes[i].position + Vector2(160 - largura_texto / 2 - 52, 0)


func _clique(evento: InputEvent, i: int) -> void:
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		_escolher(i)
		_confirmar()


func _unhandled_input(evento: InputEvent) -> void:
	if saindo:
		return
	if evento.is_action_pressed("ui_up") or _tecla(evento, KEY_W):
		_escolher(posmod(indice - 1, opcoes.size()))
	elif evento.is_action_pressed("ui_down") or _tecla(evento, KEY_S):
		_escolher(posmod(indice + 1, opcoes.size()))
	elif evento.is_action_pressed("confirmar") or evento.is_action_pressed("ui_accept"):
		_confirmar()


func _tecla(evento: InputEvent, tecla: Key) -> bool:
	return evento is InputEventKey and evento.pressed and not evento.echo and evento.physical_keycode == tecla


func _confirmar() -> void:
	if saindo:
		return
	saindo = true
	# Pisca a opção escolhida e escurece a tela
	var escolhida := opcoes[indice]
	var t := create_tween()
	for k in 3:
		t.tween_property(escolhida, "modulate:a", 0.25, 0.07)
		t.tween_property(escolhida, "modulate:a", 1.0, 0.07)
	t.tween_property(cortina, "color:a", 1.0, 0.6)
	await t.finished
	if indice == 0:
		_novo_jogo()
	else:
		get_tree().quit()


## Jogar: começa um jogo novo, sem nada do progresso anterior desta sessão.
func _novo_jogo() -> void:
	for chave in get_tree().get_meta_list():
		get_tree().remove_meta(chave)
	get_tree().change_scene_to_file(PRIMEIRA_CENA)
