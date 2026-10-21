class_name Combatente
extends Node2D
## Uma unidade em combate (monstro ou inimigo).
## Enquanto não houver sprite, desenha um retângulo colorido no lugar.
## A posição do nó é o PÉ do personagem.

var dados: DadosUnidade
var hp := 0
var hp_max := 0
var sp := 0
var defendendo := false:
	set(valor):
		defendendo = valor
		queue_redraw()
var veneno_turnos := 0
var veneno_dano := 0
var selecionado := false:
	set(valor):
		selecionado = valor
		queue_redraw()

var vivo: bool:
	get:
		return hp > 0

var _sprite: Sprite2D


func configurar(d: DadosUnidade) -> void:
	dados = d
	hp_max = roundi(d.hp_max * (1.0 + d.bonus_vida))
	hp = hp_max
	sp = d.sp_max
	if d.textura:
		_sprite = Sprite2D.new()
		_sprite.texture = d.textura
		_sprite.flip_h = d.espelhar
		var escala := d.tamanho.y / d.textura.get_height()
		_sprite.scale = Vector2(escala, escala)
		_sprite.position = Vector2(0, -d.tamanho.y / 2)
		add_child(_sprite)
	queue_redraw()


func receber_dano(quantidade: int, ignorar_defesa := false) -> int:
	if defendendo and not ignorar_defesa:
		quantidade = ceili(quantidade / 2.0)
	hp = maxi(0, hp - quantidade)
	modulate = Color(1, 0.35, 0.35)
	var t := create_tween()
	t.tween_property(self, "modulate", Color.WHITE if vivo else Color(1, 1, 1, 0.35), 0.3)
	queue_redraw()
	return quantidade


func curar(quantidade: int) -> int:
	var antes := hp
	hp = mini(hp_max, hp + quantidade)
	queue_redraw()
	return hp - antes


func animar_ataque(destino: Vector2) -> void:
	var origem := position
	var t := create_tween()
	t.tween_property(self, "position", origem + (destino - origem).normalized() * 60.0, 0.12)
	t.tween_property(self, "position", origem, 0.15)
	await t.finished


func _draw() -> void:
	var t := dados.tamanho
	if _sprite == null:
		var cor := dados.cor if vivo else Color(0.3, 0.3, 0.3)
		draw_rect(Rect2(-t.x / 2, -t.y, t.x, t.y), cor)
		draw_rect(Rect2(-t.x / 2, -t.y, t.x, t.y), Color.BLACK, false, 2.0)

	var fonte := ThemeDB.fallback_font
	draw_string(fonte, Vector2(-80, 22), dados.nome.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 160, 16)

	# Barra de vida acima da cabeça
	var largura := 80.0
	var topo := -t.y - 16
	draw_rect(Rect2(-largura / 2, topo, largura, 8), Color(0.15, 0.05, 0.05))
	draw_rect(Rect2(-largura / 2, topo, largura * hp / float(hp_max), 8), Color(0.85, 0.15, 0.15))
	if veneno_turnos > 0:
		draw_string(fonte, Vector2(largura / 2 + 4, topo + 9), "VEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.GREEN_YELLOW)
	if defendendo:
		draw_string(fonte, Vector2(-largura / 2 - 32, topo + 9), "DEF", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.SKY_BLUE)

	if selecionado:
		var y := topo - 8
		draw_colored_polygon(PackedVector2Array([Vector2(-10, y - 14), Vector2(10, y - 14), Vector2(0, y)]), Color.YELLOW)
