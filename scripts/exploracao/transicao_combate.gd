extends RefCounted
## Efeito visual reutilizável antes de entrar em uma batalha.
## Não altera atributos, turnos ou regras de combate.

# Cria uma pose estática com os pés ancorados na posição informada.
static func criar_pose(pai: Node2D, folha: String, altura: float, pos: Vector2, esquerda: bool = false) -> Node2D:
	var apoio := Node2D.new()
	apoio.position = pos
	pai.add_child(apoio)
	var anim := FolhaSprites.criar(folha, altura, esquerda)
	if anim != null:
		apoio.add_child(anim)
		FolhaSprites.posar(anim, "parado")
	return apoio

# Exibe um flash curto e uma faixa diagonal que cobre a tela.
# O CanvasLayer mantém o efeito acima dos personagens e da interface.
static func executar(pai: Node2D, texto: String) -> void:
	var camada := CanvasLayer.new()
	camada.layer = 30
	pai.add_child(camada)

	var flash := ColorRect.new()
	flash.size = Vector2(1280, 720)
	flash.color = Color(1, 1, 1, 0.45)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(flash)
	var brilho := pai.create_tween()
	brilho.tween_property(flash, "modulate:a", 0.0, 0.18)
	await brilho.finished

	# A faixa entra pela esquerda com uma borda inclinada.
	var faixa := Polygon2D.new()
	faixa.polygon = PackedVector2Array([Vector2(-240, 0), Vector2(1280, 0), Vector2(1520, 720), Vector2(-240, 720)])
	faixa.color = Color("20151d")
	faixa.position.x = -1600.0
	camada.add_child(faixa)

	var detalhe := Polygon2D.new()
	detalhe.polygon = PackedVector2Array([Vector2(0, 265), Vector2(1280, 195), Vector2(1280, 420), Vector2(0, 490)])
	detalhe.color = Color("8f2739")
	faixa.add_child(detalhe)

	var titulo := Label.new()
	titulo.position = Vector2(0, 300)
	titulo.size = Vector2(1280, 100)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 56)
	titulo.add_theme_color_override("font_color", Color.WHITE)
	titulo.add_theme_color_override("font_outline_color", Color.BLACK)
	titulo.add_theme_constant_override("outline_size", 8)
	titulo.text = texto
	faixa.add_child(titulo)

	var entrada := pai.create_tween()
	entrada.tween_property(faixa, "position:x", 0.0, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await entrada.finished
	await pai.get_tree().create_timer(0.45).timeout
	# A faixa permanece na tela até a cena ser substituída.
