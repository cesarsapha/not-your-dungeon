extends Node2D
## Protótipo de combate por turnos (GDD: Fase 1, Tela 5).
## Spike + Gordot contra 2 Mercenários Lacaios e o Mercenário Líder (chefe).
##
## Controles: setas navegam, Z confirma, X volta.
## Teste automático (sem jogador):  Godot --path . -- --autoteste

enum Estado { AGUARDANDO, MENU_ACAO, MENU_ESPECIAL, ESCOLHER_ALVO }

signal acao_escolhida(acao: Dictionary)

const POS_MONSTROS := [Vector2(430, 390), Vector2(260, 480)]
const POS_INIMIGOS := [Vector2(820, 350), Vector2(1070, 440), Vector2(910, 510)]
const CURA_POCAO := 40

var monstros: Array[Combatente] = []
var inimigos: Array[Combatente] = []
var combos: Array[Combo] = BancoDados.combos()

var estado := Estado.AGUARDANDO
var atual: Combatente
var opcoes: Array[String] = []
var indice := 0
var alvos: Array[Combatente] = []
var indice_alvo := 0
var acao_pendente := {}
## Ações de habilidade feitas na rodada atual, na ordem: usadas para detectar combos.
var acoes_rodada: Array[Dictionary] = []
var pocoes := 2
var rodada := 0
var batalha_chefe := true
var fim := false
var autoteste := false

var lbl_status: Label
var lbl_menu: Label
var lbl_info: Label
var lbl_mensagem: Label
var lbl_turno: Label
var lbl_combo: Label


func _ready() -> void:
	autoteste = "--autoteste" in OS.get_cmdline_user_args()
	if autoteste:
		Engine.time_scale = 20.0
	_montar_fundo()
	_montar_ui()
	_criar_combatentes()
	await _mensagem("Os mercenários avançam, liderados pelo Mercenário Líder!", 1.5)
	_loop_combate()


# ---------------------------------------------------------------- Fluxo

func _loop_combate() -> void:
	while true:
		rodada += 1
		acoes_rodada.clear()
		for c in _ordem_turnos():
			if not c.vivo:
				continue
			c.defendendo = false
			await _aplicar_veneno(c)
			if _checar_fim():
				return
			if not c.vivo:
				continue
			if c.dados.eh_monstro:
				await _turno_jogador(c)
			else:
				await _turno_inimigo(c)
			_atualizar_status()
			if _checar_fim():
				return


## Gordot sempre age primeiro; os outros seguem a velocidade.
func _ordem_turnos() -> Array[Combatente]:
	var todos: Array[Combatente] = []
	todos.assign(_vivos(monstros) + _vivos(inimigos))
	todos.sort_custom(func(a: Combatente, b: Combatente) -> bool:
		if a.dados.sempre_primeiro != b.dados.sempre_primeiro:
			return a.dados.sempre_primeiro
		return a.dados.velocidade > b.dados.velocidade)
	return todos


func _turno_jogador(c: Combatente) -> void:
	atual = c
	lbl_turno.text = "Vez de: %s" % c.dados.nome.to_upper()
	_atualizar_dica_combo()
	_atualizar_status()
	var acao: Dictionary
	if autoteste:
		acao = _acao_automatica(c)
	else:
		_menu_principal()
		acao = await acao_escolhida
	lbl_combo.text = ""
	await _executar(c, acao)


func _turno_inimigo(c: Combatente) -> void:
	lbl_turno.text = "Vez de: %s" % c.dados.nome.to_upper()
	await get_tree().create_timer(0.4).timeout
	var possiveis := _vivos(monstros)
	var alvo: Combatente = possiveis.pick_random()
	if randf() < 0.5:
		# Metade das vezes mira no monstro mais ferido
		for m in possiveis:
			if m.hp < alvo.hp:
				alvo = m
	if not c.dados.habilidades.is_empty() and randf() < 0.35:
		var h: Habilidade = c.dados.habilidades[0]
		await _golpe(c, alvo, h.multiplicador, h.nome)
	else:
		await _golpe(c, alvo, 1.0, "Ataque")


func _executar(c: Combatente, acao: Dictionary) -> void:
	match acao.tipo:
		"atacar":
			await _golpe(c, acao.alvo, 1.0, "Ataque")
		"defender":
			c.defendendo = true
			await _mensagem("%s se defende (recebe metade do dano)." % c.dados.nome)
		"item":
			pocoes -= 1
			var curado: int = acao.alvo.curar(CURA_POCAO)
			_numero_flutuante(acao.alvo, "+%d" % curado, Color.LIME_GREEN)
			await _mensagem("%s usa uma Poção em %s: +%d HP." % [c.dados.nome, acao.alvo.dados.nome, curado])
		"habilidade":
			var h: Habilidade = acao.habilidade
			c.sp -= h.custo_sp
			_atualizar_status()
			var lista: Array = _vivos(inimigos) if h.alvo_todos else [acao.alvo]
			for alvo: Combatente in lista:
				await _golpe(c, alvo, h.multiplicador, h.nome)
				if alvo.vivo and h.veneno_turnos > 0:
					alvo.veneno_turnos = h.veneno_turnos
					alvo.veneno_dano = h.veneno_dano
					alvo.queue_redraw()
					await _mensagem("%s foi envenenado!" % alvo.dados.nome, 0.7)
			acoes_rodada.append({"unidade": c.dados.nome, "habilidade": h.nome})
			await _checar_combo(c, h)


func _golpe(atacante: Combatente, alvo: Combatente, multiplicador: float, nome_golpe: String) -> void:
	await atacante.animar_ataque(alvo.position)
	var dano := alvo.receber_dano(_calcular_dano(atacante.dados.ataque * multiplicador, alvo))
	_numero_flutuante(alvo, str(dano), Color.ORANGE)
	_atualizar_status()
	await _mensagem("%s usa %s em %s: %d de dano!" % [atacante.dados.nome, nome_golpe, alvo.dados.nome, dano])
	if not alvo.vivo:
		await _mensagem("%s foi derrotado!" % alvo.dados.nome, 0.8)


func _calcular_dano(poder: float, alvo: Combatente) -> int:
	var base := poder - alvo.dados.defesa * 0.5
	return maxi(1, roundi(base * randf_range(0.9, 1.1)))


func _checar_combo(c: Combatente, h: Habilidade) -> void:
	for combo in combos:
		if combo.segundo_unidade != c.dados.nome or combo.segundo_habilidade != h.nome:
			continue
		var preparado := false
		for a in acoes_rodada.slice(0, acoes_rodada.size() - 1):
			if a.unidade == combo.primeiro_unidade and a.habilidade == combo.primeiro_habilidade:
				preparado = true
		var parceiro := _buscar_monstro(combo.primeiro_unidade)
		if not preparado or parceiro == null or _vivos(inimigos).is_empty():
			continue
		acoes_rodada.clear()
		lbl_combo.text = "COMBO! %s" % combo.nome.to_upper()
		await _mensagem("%s e %s unem forças!" % [parceiro.dados.nome, c.dados.nome], 1.2)
		var poder := (c.dados.ataque + parceiro.dados.ataque) * combo.multiplicador
		var atingidos := _vivos(inimigos)
		for alvo in atingidos:
			var dano := alvo.receber_dano(_calcular_dano(poder, alvo))
			_numero_flutuante(alvo, str(dano), Color.VIOLET)
		_atualizar_status()
		await _mensagem("O vórtice atinge todos os inimigos!", 1.2)
		for alvo in atingidos:
			if not alvo.vivo:
				await _mensagem("%s foi derrotado!" % alvo.dados.nome, 0.6)
		lbl_combo.text = ""


func _aplicar_veneno(c: Combatente) -> void:
	if c.veneno_turnos <= 0:
		return
	c.veneno_turnos -= 1
	var dano := c.receber_dano(c.veneno_dano, true)
	_numero_flutuante(c, str(dano), Color.GREEN_YELLOW)
	_atualizar_status()
	await _mensagem("%s sofre %d de dano do veneno." % [c.dados.nome, dano], 0.7)
	if not c.vivo:
		await _mensagem("%s foi derrotado!" % c.dados.nome, 0.8)


func _checar_fim() -> bool:
	if fim:
		return true
	if _vivos(inimigos).is_empty():
		_finalizar(true)
	elif _vivos(monstros).is_empty():
		_finalizar(false)
	return fim


func _finalizar(vitoria: bool) -> void:
	fim = true
	estado = Estado.AGUARDANDO
	lbl_menu.text = ""
	lbl_turno.text = ""
	lbl_mensagem.text = "VITÓRIA! O Mercenário Líder caiu." if vitoria else "DERROTA... os monstros caíram."
	lbl_info.text = "Pressione Z para jogar de novo."
	if autoteste:
		print("RESULTADO: %s em %d rodadas" % ["vitoria" if vitoria else "derrota", rodada])
		get_tree().quit()


# ---------------------------------------------------------------- Menus

func _menu_principal() -> void:
	var itens: Array[String] = ["Atacar", "Defender", "Especial", "Item (Poção x%d)" % pocoes, "Fugir"]
	_abrir_menu(itens, Estado.MENU_ACAO)


func _abrir_menu(novas: Array[String], novo_estado: Estado) -> void:
	opcoes = novas
	indice = 0
	estado = novo_estado
	_desenhar_menu()


func _desenhar_menu() -> void:
	var texto := ""
	for i in opcoes.size():
		texto += ("> " if i == indice else "   ") + opcoes[i] + "\n"
	lbl_menu.text = texto
	_atualizar_info()


func _atualizar_info() -> void:
	if estado == Estado.MENU_ESPECIAL:
		var h: Habilidade = atual.dados.habilidades[indice]
		lbl_info.text = "%s  (%d SP)\n%s" % [h.nome, h.custo_sp, h.descricao]
		return
	var dicas := [
		"Ataque padrão baseado no ataque do personagem.",
		"Recebe metade do dano até o próximo turno.",
		"Habilidades especiais que custam SP.",
		"Poção: recupera %d HP de um aliado." % CURA_POCAO,
		"Tentar fugir do combate.",
	]
	lbl_info.text = dicas[indice]


func _confirmar_menu() -> void:
	if estado == Estado.MENU_ESPECIAL:
		var h: Habilidade = atual.dados.habilidades[indice]
		if atual.sp < h.custo_sp:
			lbl_info.text = "SP insuficiente para %s!" % h.nome
			return
		acao_pendente = {"tipo": "habilidade", "habilidade": h}
		if h.alvo_todos:
			_emitir(acao_pendente)
		else:
			_escolher_alvo(_vivos(inimigos))
		return

	match indice:
		0:
			acao_pendente = {"tipo": "atacar"}
			_escolher_alvo(_vivos(inimigos))
		1:
			_emitir({"tipo": "defender"})
		2:
			var nomes: Array[String] = []
			for h in atual.dados.habilidades:
				nomes.append("%s (%d SP)" % [h.nome, h.custo_sp])
			_abrir_menu(nomes, Estado.MENU_ESPECIAL)
		3:
			if pocoes <= 0:
				lbl_info.text = "Não há mais poções!"
				return
			acao_pendente = {"tipo": "item"}
			_escolher_alvo(_vivos(monstros))
		4:
			if batalha_chefe:
				lbl_info.text = "Não é possível fugir de uma batalha contra chefe!"


func _escolher_alvo(lista: Array[Combatente]) -> void:
	alvos = lista
	indice_alvo = 0
	estado = Estado.ESCOLHER_ALVO
	lbl_menu.text = "Escolha o alvo\n\n< setas >\nZ confirma / X volta"
	_marcar_alvo()


func _marcar_alvo() -> void:
	for c in monstros + inimigos:
		c.selecionado = false
	var alvo := alvos[indice_alvo]
	alvo.selecionado = true
	lbl_info.text = "%s\nHP %d/%d" % [alvo.dados.nome, alvo.hp, alvo.hp_max]


func _limpar_selecao() -> void:
	for c in monstros + inimigos:
		c.selecionado = false


func _emitir(acao: Dictionary) -> void:
	estado = Estado.AGUARDANDO
	lbl_menu.text = ""
	lbl_info.text = ""
	acao_escolhida.emit(acao)


func _unhandled_input(event: InputEvent) -> void:
	if fim:
		if event.is_action_pressed("confirmar"):
			get_tree().reload_current_scene()
		return

	match estado:
		Estado.MENU_ACAO, Estado.MENU_ESPECIAL:
			if event.is_action_pressed("ui_up"):
				indice = posmod(indice - 1, opcoes.size())
				_desenhar_menu()
			elif event.is_action_pressed("ui_down"):
				indice = posmod(indice + 1, opcoes.size())
				_desenhar_menu()
			elif event.is_action_pressed("confirmar"):
				_confirmar_menu()
			elif event.is_action_pressed("voltar") and estado == Estado.MENU_ESPECIAL:
				_menu_principal()
		Estado.ESCOLHER_ALVO:
			if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
				indice_alvo = posmod(indice_alvo - 1, alvos.size())
				_marcar_alvo()
			elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
				indice_alvo = posmod(indice_alvo + 1, alvos.size())
				_marcar_alvo()
			elif event.is_action_pressed("confirmar"):
				acao_pendente["alvo"] = alvos[indice_alvo]
				_limpar_selecao()
				_emitir(acao_pendente)
			elif event.is_action_pressed("voltar"):
				_limpar_selecao()
				_menu_principal()


# ---------------------------------------------------------------- Montagem

func _criar_combatentes() -> void:
	var dados_monstros := [BancoDados.spike(), BancoDados.gordot()]
	for i in dados_monstros.size():
		monstros.append(_novo_combatente(dados_monstros[i], POS_MONSTROS[i]))
	var dados_inimigos := [BancoDados.mercenario_lacaio(1), BancoDados.mercenario_lider(), BancoDados.mercenario_lacaio(2)]
	for i in dados_inimigos.size():
		inimigos.append(_novo_combatente(dados_inimigos[i], POS_INIMIGOS[i]))
	_atualizar_status()


func _novo_combatente(d: DadosUnidade, pos: Vector2) -> Combatente:
	var c := Combatente.new()
	c.position = pos
	add_child(c)
	c.configurar(d)
	return c


func _montar_fundo() -> void:
	var caminho := "res://arte/cenarios/masmorra_1/fundo_combate.png"
	if ResourceLoader.exists(caminho):
		var fundo := Sprite2D.new()
		fundo.texture = load(caminho)
		fundo.centered = false
		fundo.scale = Vector2(1280.0, 720.0) / fundo.texture.get_size()
		add_child(fundo)


func _draw() -> void:
	if not ResourceLoader.exists("res://arte/cenarios/masmorra_1/fundo_combate.png"):
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.07, 0.05, 0.09))
		draw_rect(Rect2(0, 260, 1280, 280), Color(0.13, 0.11, 0.15))


func _montar_ui() -> void:
	var camada := CanvasLayer.new()
	add_child(camada)

	var painel := Panel.new()
	painel.position = Vector2(0, 545)
	painel.size = Vector2(1280, 175)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.1, 0.09, 0.12)
	estilo.border_color = Color(0.45, 0.4, 0.5)
	estilo.set_border_width_all(3)
	painel.add_theme_stylebox_override("panel", estilo)
	camada.add_child(painel)

	lbl_status = _label(painel, Vector2(20, 15), Vector2(430, 150), 20)
	lbl_menu = _label(painel, Vector2(480, 8), Vector2(300, 160), 19)
	lbl_info = _label(painel, Vector2(800, 15), Vector2(460, 150), 18)
	lbl_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	lbl_turno = _label(camada, Vector2(20, 20), Vector2(400, 30), 22)
	lbl_mensagem = _label(camada, Vector2(0, 70), Vector2(1280, 40), 22)
	lbl_mensagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_combo = _label(camada, Vector2(0, 120), Vector2(1280, 50), 32)
	lbl_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_combo.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))


func _label(pai: Node, pos: Vector2, tamanho: Vector2, fonte: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = tamanho
	l.add_theme_font_size_override("font_size", fonte)
	pai.add_child(l)
	return l


# ---------------------------------------------------------------- Auxiliares

func _atualizar_status() -> void:
	var texto := ""
	for m in monstros:
		texto += "%s   HP %d/%d   SP %d/%d\n" % [m.dados.nome.to_upper(), m.hp, m.hp_max, m.sp, m.dados.sp_max]
	texto += "\nRodada %d" % rodada
	lbl_status.text = texto
	for c in monstros + inimigos:
		c.queue_redraw()


func _atualizar_dica_combo() -> void:
	lbl_combo.text = ""
	for combo in combos:
		if combo.segundo_unidade != atual.dados.nome:
			continue
		for a in acoes_rodada:
			if a.unidade == combo.primeiro_unidade and a.habilidade == combo.primeiro_habilidade:
				lbl_combo.text = "COMBO PRONTO: use %s!" % combo.segundo_habilidade


func _mensagem(texto: String, duracao := 0.9) -> void:
	lbl_mensagem.text = texto
	if autoteste:
		print(texto)
	await get_tree().create_timer(duracao).timeout


func _numero_flutuante(alvo: Combatente, texto: String, cor: Color) -> void:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = alvo.position + Vector2(-20, -alvo.dados.tamanho.y - 60)
	add_child(l)
	var t := create_tween()
	t.tween_property(l, "position:y", l.position.y - 40, 0.8)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.8)
	t.tween_callback(l.queue_free)


func _vivos(lista: Array[Combatente]) -> Array[Combatente]:
	var resultado: Array[Combatente] = []
	resultado.assign(lista.filter(func(c: Combatente) -> bool: return c.vivo))
	return resultado


func _buscar_monstro(nome: String) -> Combatente:
	for m in monstros:
		if m.dados.nome == nome and m.vivo:
			return m
	return null


## Usado só no --autoteste: Gordot prepara o combo e Spike o completa.
func _acao_automatica(c: Combatente) -> Dictionary:
	var alvo: Combatente = _vivos(inimigos)[0]
	var preferida := "Canal Sombrio" if c.dados.nome == "Gordot" else "Golpe Venenoso"
	for h in c.dados.habilidades:
		if h.nome == preferida and c.sp >= h.custo_sp:
			return {"tipo": "habilidade", "habilidade": h, "alvo": alvo}
	return {"tipo": "atacar", "alvo": alvo}
