class_name BancoDados
extends RefCounted
## Valores do protótipo. Mudem os números aqui para balancear o combate.
##
## Sprites: se existir um PNG no caminho indicado em _textura(...), ele é usado
## no lugar do retângulo colorido. O PNG precisa ter FUNDO TRANSPARENTE.


static func spike() -> DadosUnidade:
	var d := _unidade("Spike", true, 105, 50, 16, 6, 12, Color(0.35, 0.7, 0.25), Vector2(55, 90))
	d.bonus_vida = 0.2
	d.textura = _textura("res://arte/personagens/monstros/spike.png")
	d.habilidades.assign([
		_habilidade("Golpe Venenoso", 8, 1.4, "Ataque com adaga envenenada. Envenena o alvo por 3 turnos.", false, 3, 6),
	])
	return d


static func gordot() -> DadosUnidade:
	var d := _unidade("Gordot", true, 205, 30, 18, 10, 4, Color(0.55, 0.35, 0.75), Vector2(95, 120))
	d.sempre_primeiro = true
	d.textura = _textura("res://arte/personagens/monstros/gordot.png")
	d.habilidades.assign([
		_habilidade("Soco Esmagador", 10, 1.9, "Soco no chão que causa muito dano a um inimigo."),
		_habilidade("Canal Sombrio", 10, 0.8, "Canaliza energia sombria. Se Spike usar Golpe Venenoso na mesma rodada, dispara o COMBO."),
	])
	return d


static func mercenario_lacaio(numero: int) -> DadosUnidade:
	var d := _unidade("Lacaio %d" % numero, false, 60, 0, 12, 4, 8, Color(0.6, 0.45, 0.3), Vector2(55, 100))
	d.textura = _textura("res://arte/inimigos/mercenario_lacaio.png")
	d.espelhar = true
	return d


static func mercenario_lider() -> DadosUnidade:
	var d := _unidade("Líder", false, 190, 0, 17, 8, 6, Color(0.55, 0.58, 0.65), Vector2(80, 125))
	d.nivel = 2
	d.textura = _textura("res://arte/inimigos/mercenario_lider.png")
	d.espelhar = true
	d.habilidades.assign([
		_habilidade("Golpe de Maça", 0, 1.6, "Golpe pesado com a maça de duas mãos."),
	])
	return d


static func combos() -> Array[Combo]:
	var c := Combo.new()
	c.nome = "Vórtice Venenoso Sombrio"
	c.primeiro_unidade = "Gordot"
	c.primeiro_habilidade = "Canal Sombrio"
	c.segundo_unidade = "Spike"
	c.segundo_habilidade = "Golpe Venenoso"
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
