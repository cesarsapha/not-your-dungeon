class_name BancoDados
extends RefCounted
## Valores do protótipo. Mudem os números aqui para balancear o combate.
##
## Sprites: se existir um PNG no caminho indicado em _textura(...), ele é usado
## no lugar do retângulo colorido. O PNG precisa ter FUNDO TRANSPARENTE.


## Réptil veloz com cimitarra (GDD: grande velocidade, tende a agir primeiro).
static func spike() -> DadosUnidade:
	var d := _unidade("Spike", true, 120, 40, 20, 6, 14, Color(0.3, 0.5, 0.35), Vector2(150, 150))
	d.sempre_primeiro = true
	d.textura = _textura("res://arte/personagens/monstros/spike.png")
	d.animacoes = "res://arte/personagens/monstros/spike_sprites"
	var investida := _habilidade("Investida Esmeralda", 8, 1.5, "Investida rápida com a cimitarra. Prepara o combo com Gordot.")
	d.habilidades.assign([investida])
	d.habilidades.assign([investida])
	return d


## Ogro roxo e tanque (GDD: possui vida adicional).
static func gordot() -> DadosUnidade:
	var d := _unidade("Gordot", true, 160, 30, 16, 10, 4, Color(0.55, 0.35, 0.65), Vector2(160, 160))
	d.bonus_vida = 0.2
	d.textura = _textura("res://arte/personagens/monstros/gordot.png")
	d.animacoes = "res://arte/personagens/monstros/gordot_sprites"
	var investida := _habilidade("Impacto Colossal", 10, 1.7, "Golpe pesado com o tronco. Atrai os ataques inimigos por 2 turnos e reduz o dano recebido em 30%. Completa o combo iniciado por Spike.")
	investida.provocar_turnos = 2
	d.habilidades.assign([investida])
	return d


static func mercenario_lacaio(numero: int) -> DadosUnidade:
	var d := _unidade("Lacaio %d" % numero, false, 45, 0, 12, 4, 8, Color(0.6, 0.45, 0.3), Vector2(55, 100))
	d.textura = _textura("res://arte/inimigos/mercenario.png")
	d.animacoes = "res://arte/inimigos/mercenario_sprites"
	d.tamanho = Vector2(150, 140)
	d.espelhar = true
	return d

static func mercenario_arqueiro() -> DadosUnidade:
	var d := _unidade("Arqueiro", false, 35, 0, 14, 2, 10, Color(0.6, 0.45, 0.3), Vector2(150, 140))
	d.textura = _textura("res://arte/inimigos/mercenario_arqueiro.png")
	d.animacoes = "res://arte/inimigos/mercenario_arqueiro_sprites"
	d.espelhar = true
	return d

static func mercenario_lider() -> DadosUnidade:
	var d := _unidade("Líder", false, 190, 0, 17, 8, 6, Color(0.55, 0.58, 0.65), Vector2(80, 125))
	d.nivel = 2
	# Provisório: ainda não há sprite do líder (maça de duas mãos); usa o mercenário maior
	d.textura = _textura("res://arte/inimigos/mercenario_chefe.png")
	d.animacoes = "res://arte/inimigos/mercenario_chefe_sprites"
	d.tamanho = Vector2(170, 175)
	d.espelhar = true
	d.habilidades.assign([
		_habilidade("Golpe de Maça", 0, 1.6, "Golpe pesado com a maça de duas mãos."),
	])
	return d


static func combos() -> Array[Combo]:
	var c := Combo.new()
	c.nome = "Investida Dupla"
	c.primeiro_unidade = "Spike"
	c.primeiro_habilidade = "Investida Esmeralda"
	c.segundo_unidade = "Gordot"
	c.segundo_habilidade = "Impacto Colossal"
	c.multiplicador = 0.8
	var lista: Array[Combo] = [c]
	return lista


static func _unidade(nome: String, eh_monstro: bool, hp: int, sp: int, atk: int, def: int, vel: int, cor: Color, tamanho: Vector2) -> DadosUnidade:
	var d := DadosUnidade.new()
	d.nome = nome
	d.eh_monstro = eh_monstro
	d.hp_max = hp
	d.sp_max = sp
	d.ataque = atk
	d.defesa = def
	d.velocidade = vel
	d.cor = cor
	d.tamanho = tamanho
	return d


static func _habilidade(nome: String, custo: int, mult: float, descricao: String, todos := false, veneno_turnos := 0, veneno_dano := 0) -> Habilidade:
	var h := Habilidade.new()
	h.nome = nome
	h.custo_sp = custo
	h.multiplicador = mult
	h.descricao = descricao
	h.alvo_todos = todos
	h.veneno_turnos = veneno_turnos
	h.veneno_dano = veneno_dano
	return h


static func _textura(caminho: String) -> Texture2D:
	if ResourceLoader.exists(caminho):
		return load(caminho)
	return null
