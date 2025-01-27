extends Node2D

@onready var spaw_pato = $SpawPato
@onready var spaw_pato2 = $SpawPato2
@onready var spaw_pato3 = $SpawPato3
@onready var patos = $Patos
@onready var cao = $Cao
@onready var timer_inicia_round = $TimerIniciaRound
@onready var timer_finaliza_round = $FinalizaRound
@onready var audio_round = $Audio/Round
var alvo
@onready var audio_atmosfera = $Audio/Atmosfera
@onready var hud_inicial = $HudInicial
@onready var score = $HudGame/Score/LabelPontuacao
@onready var bala = $HudGame/Tiro/Bala
var cena_pato = preload("res://scenes/pato/pato.tscn")
@export var multiplicador_velocidade = 1
@export var aumento_multiplicador_por_round = 1.0
var patos_gerados = 0
@export var patos_matou = 0
var patos_fugiu = 0
var quantidade_maxima_pato = 2
var patos_por_round = 4
@onready var audio_sino = $Audio/Sino
var balas_no_cartucho = []
var patos_hud_tela = []
var balas_maxima = 3
@export var pontuacao_por_pato = 500
@export var soma_por_round = 150
@export var patos_morto_para_tela = 0
@onready var pato = $HudGame/Patos/Pato
var round = 1
var quantidade_bounce_top = 0
@onready var bounce_top_area = $BounceTop/Top
@onready var bounce_down_area = $BounceDown/Down
var patos_que_tocou = 0
var quantidade_tiros

@rpc("any_peer", "call_local", "reliable")
func _avisa_que_e_alvo() -> void:
	if multiplayer.is_server():
		var _alvo = preload("res://scenes/alvo/alvo.tscn").instantiate()
		_alvo.name = str(multiplayer.get_remote_sender_id())
		_alvo.z_index = 999
		$Alvos.call_deferred("add_child", _alvo)

@rpc("any_peer", "call_local", "reliable")
func _avisa_que_e_pato() -> void:
	if multiplayer.is_server():
		GameManager.players_patos.append(str(multiplayer.get_remote_sender_id()))

func _adiciona_quantidade_tiros(_quantidade_tiros) -> void:
	quantidade_tiros = _quantidade_tiros
	$HudGame/Tiro/Label.text = str(quantidade_tiros)

@rpc("any_peer")
func _remove_quantidade_tiros() -> void:
	if !GameManager.alvo:
		quantidade_tiros -= 1
		$HudGame/Tiro/Label.text = str(quantidade_tiros)

func _ready() -> void:
	if multiplayer.is_server():
		GameManager.player_desconectou.connect(_on_player_desconectou)
	var bus_index = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_index, -10000)
	
	if GameManager.alvo:
		_avisa_que_e_alvo.rpc()
	else:
		$HudGame/Tiro/Label.visible = true
		_avisa_que_e_pato.rpc()
	
	cao.cachorro_pulou.connect(_inicia_round)
	
	for p in patos_por_round:
		var patoduplicado = pato.duplicate()
		patoduplicado.position = patoduplicado.position + Vector2(27 * p, 0)
		patos_hud_tela.append(patoduplicado)
		$HudGame/Patos.add_child(patoduplicado)
		
func _inicia_round() -> void:
	if !audio_atmosfera.playing:
		audio_atmosfera.play()
		
	bounce_down_area.disabled = true
	bounce_down_area.call_deferred("set_disabled", true)
	
	if multiplicador_velocidade >= 2:
		bounce_top_area.disabled = false
		bounce_top_area.call_deferred("set_disabled", false)
	
	_prepara_inicio_round.rpc()
	
	cao.visible = false
	if multiplayer.is_server():
		timer_inicia_round.start()
		
	_play_audio_round.rpc()
	patos_matou = 0
	patos_fugiu = 0
	quantidade_bounce_top = 0
	patos_que_tocou = 0
	patos_gerados = 0
	
@rpc("any_peer", "call_local")
func _play_audio_round() -> void:
	audio_round.play()
	
@rpc("any_peer", "call_local")
func _prepara_inicio_round() -> void:
	if GameManager.alvo:
		alvo.pode_atirar = true
		alvo.cabou_balas = false
		for b in balas_no_cartucho.size():
			var bala = balas_no_cartucho[b]
			if is_instance_valid(bala):
				bala.queue_free()
				
		balas_no_cartucho.clear()

		for b in balas_maxima:
			var baladuplicada = bala.duplicate()
			baladuplicada.position = baladuplicada.position + Vector2(21 * b, 0)
			baladuplicada.visible = true
			balas_no_cartucho.append(baladuplicada)
			$HudGame/Tiro.add_child(baladuplicada)
	else:
		_adiciona_quantidade_tiros($Alvos.get_children().size() * 3)

func gera_patos(_quantidade: float) -> void:
	patos_gerados = _quantidade
	var spaws = [spaw_pato, spaw_pato2, spaw_pato3]
	
	if !GameManager.players_patos.is_empty():
		for p in GameManager.players_patos:
			_gera_pato(p, spaws, true)
			_quantidade -= 1
	
	for numero in _quantidade:
		var nome_pato = "Pato_%d" % numero
		_gera_pato(nome_pato, spaws, false)
		
func _gera_pato(nome, spaws, jogavel) -> void:
	var _pato = cena_pato.instantiate()
	_pato.name = nome
	_pato.pontuacao = str(pontuacao_por_pato)
	_pato._velocidade = _pato._velocidade * multiplicador_velocidade
	var spaw = spaws.pick_random()
	_pato.position = spaw.position
	_pato._jogavel = jogavel
	spaws.erase(spaw)
	$Patos.call_deferred("add_child", _pato)
		
func _on_topo_body_entered(body: Node2D) -> void:
	if multiplayer.is_server():
		patos_fugiu += 1
		_finaliza_round()
		body.queue_free()

func _on_lados_body_entered(body: Node2D) -> void:
	if multiplayer.is_server():
		body._bounce()
		
func _log(str) -> void:
	print("Quem ta executando: ", multiplayer.get_unique_id(), " - ", str)

func _finaliza_round() -> void:
	if patos_matou + patos_fugiu == patos_gerados:
		var ganhou = patos_matou == patos_gerados
		cao.visible = true
		cao.anima_fim_round(ganhou)
		if ganhou:
			round += 1
			if round > 2:
				round = 1
				multiplicador_velocidade += aumento_multiplicador_por_round
				if multiplicador_velocidade >= 2:
					bounce_top_area.disabled = false
					bounce_top_area.call_deferred("set_disabled", false)
				_resetar_round.rpc()
		else:
			for p in patos_matou:
				var score_novo = int(score.text) - pontuacao_por_pato
				var scoreStr = "%09d" % score_novo
				score.text = scoreStr
				patos_morto_para_tela -= 1
			
			_reseta_patos_matado_hud.rpc()
		timer_finaliza_round.start()

@rpc("any_peer", "call_local")
func _reseta_patos_matado_hud() -> void:
	if patos_matou > 0:
		var quantidade_patos_voltado_branco = 0
		for p in range(patos_hud_tela.size() - 1, -1, -1):
			var pato_hud = patos_hud_tela[p]
			var current_region = pato_hud.region_rect
			if current_region.position.y == 273:
				current_region.position.y = 253
				pato_hud.region_rect = current_region
				quantidade_patos_voltado_branco += 1
				if quantidade_patos_voltado_branco == patos_matou:
					break

@rpc("any_peer", "call_local")
func _resetar_round() -> void:
	patos_morto_para_tela = 0
	pontuacao_por_pato += soma_por_round
	for p in patos_hud_tela.size():
		var pato_hud = patos_hud_tela[p]
		var current_region = pato_hud.region_rect
		current_region.position.y = 253
		pato_hud.region_rect = current_region

func _on_baixo_body_entered(body: Node2D) -> void:
	patos_matou += 1
	_finaliza_round()
	body.queue_free()

func _on_timer_inicia_round_timeout() -> void:
	gera_patos(quantidade_maxima_pato)

func _on_finaliza_round_timeout() -> void:
	_inicia_round()
	
@rpc("any_peer", "call_local")
func _start_game() -> void:
	cao.pode_pular = true
	hud_inicial.visible = false
	audio_sino.play()

func _on_iniciar_pressed() -> void:
	_start_game.rpc()

func on_alvo_atirou() -> void:
	_remove_quantidade_tiros.rpc()
	var bala = balas_no_cartucho.pop_back()
	bala.queue_free()

func on_alvo_verifica_balas() -> void:
	if balas_no_cartucho.size() > 0:
		alvo.pode_atirar = true
	else:
		alvo.cabou_balas = true

@rpc("any_peer", "call_local")
func on_alvo_matou_pato() -> void:
	var score_novo = int(score.text) + pontuacao_por_pato
	var scoreStr = "%09d" % score_novo
	score.text = scoreStr
	
	var pato_hud = patos_hud_tela[patos_morto_para_tela]
	patos_morto_para_tela += 1
	var current_region = pato_hud.region_rect
	current_region.position.y = 273
	pato_hud.region_rect = current_region

func _on_bounce_top_body_entered(body: Node2D) -> void:
	if body.pode_fugir:
		return
	if multiplayer.is_server():
		bounce_down_area.disabled = false
		bounce_down_area.call_deferred("set_disabled", false)
		quantidade_bounce_top += 1
		body._bounce_y()

func _on_bounce_down_body_entered(body: Node2D) -> void:
	if multiplayer.is_server():
		body._bounce_y()

func _on_player_desconectou(player_id) -> void:
	for p in $Patos.get_children():
		if p.name == str(player_id):
			p._perdeu_conexao_jogavel.rpc()
			return
	for a in $Alvos.get_children():
		if a.name == str(player_id):
			a.queue_free()
			return
