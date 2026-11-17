class_name FolhaSprites
extends RefCounted
## Monta um AnimatedSprite2D a partir de <caminho>.png + <caminho>.json
## (gerados por ferramentas/importar_sprites.py: uma animação por linha).
## O pé do personagem fica na origem do nó, para posicionar pelo chão.


static func criar(caminho: String, altura: float, espelhar := false) -> AnimatedSprite2D:
	if not ResourceLoader.exists(caminho + ".png") or not FileAccess.file_exists(caminho + ".json"):
		return null
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(caminho + ".json"))
	var folha: Texture2D = load(caminho + ".png")
	var largura: int = meta.quadro[0]
	var alto: int = meta.quadro[1]
	var quadros := SpriteFrames.new()
	quadros.remove_animation("default")
	for nome: String in meta.animacoes:
		var info: Dictionary = meta.animacoes[nome]
		quadros.add_animation(nome)
		quadros.set_animation_speed(nome, info.fps)
		quadros.set_animation_loop(nome, info.repete)
		for i in int(info.quadros):
			var recorte := AtlasTexture.new()
			recorte.atlas = folha
			recorte.region = Rect2(i * largura, int(info.linha) * alto, largura, alto)
			quadros.add_frame(nome, recorte)
	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = quadros
	anim.centered = false
	var escala := altura / float(meta.altura_corpo)
	anim.scale = Vector2(escala, escala)
	# Reduzir pixel art em escala não inteira serrilha; nesse caso suaviza
	if escala < 1.0:
		anim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	anim.set_meta("pe", Vector2(meta.pe[0], meta.pe[1]))
	anim.set_meta("largura", float(largura))
	virar(anim, espelhar)
	return anim


## Espelha o sprite (olhar para a esquerda) mantendo o pé no mesmo lugar.
static func virar(anim: AnimatedSprite2D, esquerda: bool) -> void:
	var pe: Vector2 = anim.get_meta("pe")
	var largura: float = anim.get_meta("largura")
	anim.flip_h = esquerda
	var pe_x := largura - pe.x if esquerda else pe.x
	anim.position = -Vector2(pe_x, pe.y) * anim.scale.x


## Mostra um quadro parado de uma animação.
static func posar(anim: AnimatedSprite2D, animacao: String, quadro := 0) -> void:
	anim.animation = animacao
	anim.frame = quadro
	anim.pause()


## Textura de um quadro, recortada só na parte desenhada (ex.: o retrato das caixas de diálogo).
static func textura(anim: AnimatedSprite2D, animacao: String, quadro := 0) -> Texture2D:
	var original: AtlasTexture = anim.sprite_frames.get_frame_texture(animacao, quadro)
	var usado := original.get_image().get_used_rect()
	var recorte := AtlasTexture.new()
	recorte.atlas = original.atlas
	recorte.region = Rect2(original.region.position + Vector2(usado.position), Vector2(usado.size))
	return recorte
