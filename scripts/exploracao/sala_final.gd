extends Node2D
## Quinta tela da primeira fase: apresentação do líder dos mercenários.
## A exploração anterior termina aqui; esta sala introduz o combate final.

const CENARIO := "res://arte/cenarios/masmorra_1/sala_final.png"
const COMBATE := "res://cenas/combate.tscn"
const TRANSICAO = preload("res://scripts/exploracao/transicao_combate.gd")

var escala: float
var deslocamento: float

func _ready() -> void:
	y_sort_enabled = true
	# Mantém o enquadramento das salas de exploração.
	var fundo := Sprite2D.new()
	fundo.texture = load(CENARIO)
	fundo.centered = false
	fundo.z_index = -1
	escala = 720.0 / fundo.texture.get_height()
	deslocamento = (1280.0 - fundo.texture.get_width() * escala) / 2.0
	fundo.scale = Vector2(escala, escala)
	fundo.position = Vector2(deslocamento, 0)
	add_child(fundo)

	# Os subordinados ficam atrás do líder, perto do fundo da sala.
	TRANSICAO.criar_pose(self, "res://arte/inimigos/mercenario_sprites", 100.0, _coordenada(Vector2(350, 380)), true)
	TRANSICAO.criar_pose(self, "res://arte/inimigos/mercenario_arqueiro_sprites", 100.0, _coordenada(Vector2(675, 380)), true)
	TRANSICAO.criar_pose(self, "res://arte/inimigos/mercenario_chefe_sprites", 150.0, _coordenada(Vector2(512, 480)), true)

	# Spike e Gordot entram juntos pelo acesso inferior.
	var spike: Node2D = TRANSICAO.criar_pose(self, "res://arte/personagens/monstros/spike_sprites", 110.0, _coordenada(Vector2(520, 735)))
	var gordot: Node2D = TRANSICAO.criar_pose(self, "res://arte/personagens/monstros/gordot_sprites", 125.0, _coordenada(Vector2(430, 755)))
	for aliado in [spike, gordot]:
		if aliado.get_child_count() > 0:
			FolhaSprites.posar(aliado.get_child(0) as AnimatedSprite2D, "costas")
	var entrada := create_tween().set_parallel(true)
	entrada.tween_property(spike, "position", _coordenada(Vector2(520, 610)), 0.65)
	entrada.tween_property(gordot, "position", _coordenada(Vector2(430, 665)), 0.75)
	await entrada.finished

	# Apresentação breve antes do impacto visual da batalha.
	var aviso := Label.new()
	aviso.position = Vector2(0, 40)
	aviso.size = Vector2(1280, 50)
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.add_theme_font_size_override("font_size", 24)
	aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	aviso.add_theme_constant_override("outline_size", 6)
	aviso.z_index = 5
	aviso.text = "Líder: Nenhum monstro sairá vivo daqui!"
	add_child(aviso)
	await get_tree().create_timer(1.5).timeout
	aviso.hide()

	get_tree().set_meta("encontro", "final")
	await TRANSICAO.executar(self, "CONFRONTO FINAL!")
	get_tree().change_scene_to_file(COMBATE)

# Converte posições da imagem original (1024 x 765) para a tela.
func _coordenada(ponto: Vector2) -> Vector2:
	return ponto * escala + Vector2(deslocamento, 0)
