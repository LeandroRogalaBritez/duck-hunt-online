extends Node2D

# Variaveis da Cena
@onready var _spaw_pato = $SpawPato
@onready var _spaw_pato2 = $SpawPato2
@onready var _spaw_pato3 = $SpawPato3
@onready var _patos = $Patos
@onready var _cao = $Cao
@onready var _timer_inicia_round = $TimerIniciaRound
@onready var _timer_finaliza_round = $FinalizaRound
@onready var _audio_round = $Audio/Round
@onready var _audio_atmosfera = $Audio/Atmosfera
@onready var _hud_inicial = $HudInicial
@onready var _score = $HudGame/Score/LabelPontuacao
@onready var _bala = $HudGame/Tiro/Bala
@onready var _audio_sino = $Audio/Sino
@onready var _pato = $HudGame/Patos/Pato
@onready var _bounce_top_area = $BounceTop/Top
@onready var _bounce_down_area = $BounceDown/Down

# Variaveis Privadas
@export var _multiplicador_velocidade = 1
@export var _aumento_multiplicador_por_round = 1.0
@export var _patos_matou = 0
@export var _pontuacao_por_pato = 500
@export var _soma_por_round = 150
@export var _patos_morto_para_tela = 0
var _cena_pato = preload("res://scenes/pato/pato.tscn")
var _patos_gerados = 0
var _patos_fugiu = 0
var _quantidade_maxima_pato = 2
var _patos_por_round = 4
var _balas_no_cartucho = []
var _patos_hud_tela = []
var _balas_maxima = 3
var _round = 1
var _quantidade_bounce_top = 0
var _patos_que_tocou = 0
var _quantidade_tiros

# Variaveis Publicas
var alvo

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
	self._quantidade_tiros = _quantidade_tiros
	$HudGame/Tiro/Label.text = str(_quantidade_tiros)

@rpc("any_peer")
func _remove_quantidade_tiros() -> void:
	if !GameManager.alvo:
		_quantidade_tiros -= 1
		$HudGame/Tiro/Label.text = str(_quantidade_tiros)

func _ready() -> void:
	if multiplayer.is_server():
		GameManager.player_desconectou.connect(_on_player_desconectou)
	
	if GameManager.alvo:
		_avisa_que_e_alvo.rpc()
	else:
		$HudGame/Tiro/Label.visible = true
		_avisa_que_e_pato.rpc()
	
	_cao.cachorro_pulou.connect(_inicia_round)
	
	for _p in _patos_por_round:
		var _patoduplicado = _pato.duplicate()
		_patoduplicado.position = _patoduplicado.position + Vector2(27 * _p, 0)
		_patos_hud_tela.append(_patoduplicado)
		$HudGame/Patos.add_child(_patoduplicado)
		
func _inicia_round() -> void:
	if !_audio_atmosfera.playing:
		_audio_atmosfera.play()
		
	_bounce_down_area.disabled = true
	_bounce_down_area.call_deferred("set_disabled", true)
	
	if _multiplicador_velocidade >= 2:
		_bounce_top_area.disabled = false
		_bounce_top_area.call_deferred("set_disabled", false)
	
	_prepara_inicio_round.rpc()
	
	_cao.visible = false
	if multiplayer.is_server():
		_timer_inicia_round.start()
		
	_play_audio_round.rpc()
	_patos_matou = 0
	_patos_fugiu = 0
	_quantidade_bounce_top = 0
	_patos_que_tocou = 0
	_patos_gerados = 0
	
@rpc("any_peer", "call_local")
func _play_audio_round() -> void:
	_audio_round.play()
	
@rpc("any_peer", "call_local")
func _prepara_inicio_round() -> void:
	if GameManager.alvo:
		alvo.pode_atirar = true
		alvo.cabou_balas = false
		for _b in _balas_no_cartucho.size():
			var _bala = _balas_no_cartucho[_b]
			if is_instance_valid(_bala):
				_bala.queue_free()
				
		_balas_no_cartucho.clear()

		for _b in _balas_maxima:
			var _baladuplicada = _bala.duplicate()
			_baladuplicada.position = _baladuplicada.position + Vector2(21 * _b, 0)
			_baladuplicada.visible = true
			_balas_no_cartucho.append(_baladuplicada)
			$HudGame/Tiro.add_child(_baladuplicada)
	else:
		_adiciona_quantidade_tiros($Alvos.get_children().size() * 3)

func _gera_patos(_quantidade: float) -> void:
	_patos_gerados = _quantidade
	var _spaws = [_spaw_pato, _spaw_pato2, _spaw_pato3]
	
	if !GameManager.players_patos.is_empty():
		for _p in GameManager.players_patos:
			_gera_pato(_p, _spaws, true)
			_quantidade -= 1
	
	for _numero in _quantidade:
		var _nome_pato = "Pato_%d" % _numero
		_gera_pato(_nome_pato, _spaws, false)
		
func _gera_pato(_nome, _spaws, _jogavel) -> void:
	var _pato = _cena_pato.instantiate()
	_pato.name = _nome
	_pato.pontuacao = str(_pontuacao_por_pato)
	_pato.velocidade = _pato.velocidade * _multiplicador_velocidade
	var _spaw = _spaws.pick_random()
	_pato.position = _spaw.position
	_pato.jogavel = _jogavel
	_spaws.erase(_spaw)
	$Patos.call_deferred("add_child", _pato)
		
func _on_topo_body_entered(_body: Node2D) -> void:
	if multiplayer.is_server():
		_patos_fugiu += 1
		_finaliza_round()
		_body.queue_free()

func _on_lados_body_entered(_body: Node2D) -> void:
	if multiplayer.is_server():
		_body.bounce_x()
		
func _log(_str) -> void:
	print("Quem ta executando: ", multiplayer.get_unique_id(), " - ", _str)

func _finaliza_round() -> void:
	if _patos_matou + _patos_fugiu == _patos_gerados:
		var _ganhou = _patos_matou == _patos_gerados
		_cao.visible = true
		_cao.anima_fim_round(_ganhou)
		if _ganhou:
			_round += 1
			if _round > 2:
				_round = 1
				_multiplicador_velocidade += _aumento_multiplicador_por_round
				if _multiplicador_velocidade >= 2:
					_bounce_top_area.disabled = false
					_bounce_top_area.call_deferred("set_disabled", false)
				_resetar_round.rpc()
		else:
			for _p in _patos_matou:
				var _score_novo = int(_score.text) - _pontuacao_por_pato
				var _scoreStr = "%09d" % _score_novo
				_score.text = _scoreStr
				_patos_morto_para_tela -= 1
			
			_reseta_patos_matado_hud.rpc()
		_timer_finaliza_round.start()

@rpc("any_peer", "call_local")
func _reseta_patos_matado_hud() -> void:
	if _patos_matou > 0:
		var _quantidade_patos_voltado_branco = 0
		for p in range(_patos_hud_tela.size() - 1, -1, -1):
			var pato_hud = _patos_hud_tela[p]
			var current_region = pato_hud.region_rect
			if current_region.position.y == 273:
				current_region.position.y = 253
				pato_hud.region_rect = current_region
				_quantidade_patos_voltado_branco += 1
				if _quantidade_patos_voltado_branco == _patos_matou:
					break

@rpc("any_peer", "call_local")
func _resetar_round() -> void:
	_patos_morto_para_tela = 0
	_pontuacao_por_pato += _soma_por_round
	for _p in _patos_hud_tela.size():
		var _pato_hud = _patos_hud_tela[_p]
		var _current_region = _pato_hud.region_rect
		_current_region.position.y = 253
		_pato_hud.region_rect = _current_region

func _on_baixo_body_entered(_body: Node2D) -> void:
	_patos_matou += 1
	_finaliza_round()
	_body.queue_free()

func _on_timer_inicia_round_timeout() -> void:
	_gera_patos(_quantidade_maxima_pato)

func _on_finaliza_round_timeout() -> void:
	_inicia_round()
	
@rpc("any_peer", "call_local")
func _start_game() -> void:
	_cao.pode_pular = true
	_hud_inicial.visible = false
	_audio_sino.play()

func _on_iniciar_pressed() -> void:
	_start_game.rpc()

func on_alvo_atirou() -> void:
	_remove_quantidade_tiros.rpc()
	var _bala = _balas_no_cartucho.pop_back()
	_bala.queue_free()

func on_alvo_verifica_balas() -> void:
	if _balas_no_cartucho.size() > 0:
		alvo.pode_atirar = true
	else:
		alvo.cabou_balas = true

@rpc("any_peer", "call_local")
func on_alvo_matou_pato() -> void:
	var _score_novo = int(_score.text) + _pontuacao_por_pato
	var _scoreStr = "%09d" % _score_novo
	_score.text = _scoreStr
	
	var _pato_hud = _patos_hud_tela[_patos_morto_para_tela]
	_patos_morto_para_tela += 1
	var _current_region = _pato_hud.region_rect
	_current_region.position.y = 273
	_pato_hud.region_rect = _current_region

func _on_bounce_top_body_entered(_body: Node2D) -> void:
	if _body.pode_fugir:
		return
	if multiplayer.is_server():
		_bounce_down_area.disabled = false
		_bounce_down_area.call_deferred("set_disabled", false)
		_quantidade_bounce_top += 1
		_body.bounce_y()

func _on_bounce_down_body_entered(_body: Node2D) -> void:
	if multiplayer.is_server():
		_body.bounce_y()

func _on_player_desconectou(_player_id) -> void:
	for _p in $Patos.get_children():
		if _p.name == str(_player_id):
			_p._perdeu_conexao_jogavel.rpc()
			return
	for _a in $Alvos.get_children():
		if _a.name == str(_player_id):
			_a.queue_free()
			return
