extends Node

var _peer 
var players: Dictionary = {}
var _players = []
var _player_nome
var _multiplayer = false
var _alvo = true
var _players_patos = []
var quantidade_patos = 0
var mostrar_alerta = true

signal player_desconectou(player_id)

func _get_nome(unique_id) -> String:
	return players[unique_id]

func _gera_dicionario() -> void:
	for p in _players:
		var json = JSON.parse_string(p)
		players[json["id"]] = json["nome"]
		
func _create_server(ip, porta) -> void:
	_multiplayer = true
	_peer = ENetMultiplayerPeer.new()
	_peer.set_bind_ip(ip)
	_peer.create_server(porta)
	multiplayer.multiplayer_peer = _peer
	multiplayer.peer_disconnected.connect(_remove_player)
	
func _join_server(ip, porta, _alvo) -> void:
	_multiplayer = true
	self._alvo = _alvo
	_peer = ENetMultiplayerPeer.new()
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_desconectou)
	_peer.create_client(ip, porta)
	multiplayer.multiplayer_peer = _peer
	
func _reset():
	_multiplayer = false
	_peer = null
	_players = []
	players = {}
	_player_nome = null
	_players_patos = []
	mostrar_alerta = true
	
func _desconectou():
	if mostrar_alerta:
		OS.alert("Perdeu a conexão com servidor", "ALERTA")
	_reset()
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")

func _remove_player(_id = 1):
	player_desconectou.emit(_id)
	var index_remover = -1
	for p in _players:
		index_remover += 1
		var json = JSON.parse_string(p)
		if json["id"] == str(_id):
			if json["alvo"] == "false":
				quantidade_patos -= 1
			break
	_players_patos.remove_at(_players_patos.find(str(_id)))
	_players.remove_at(index_remover)
	_update_players_list.rpc(_players)
	
func _add_player(_id, nome):
	_players.append('{"id": "%s", "nome":"%s", "alvo":"%s"}' % [_id, nome, "true"])
	_update_players_list.rpc(_players)

@rpc("any_peer")
func set_player_name(player_name: String, _alvo: bool):
	if multiplayer.is_server():
		if !_alvo:
			if quantidade_patos == 2:
				_players.append('{"id": "%s", "nome":"%s", "alvo":"%s"}' % [multiplayer.get_remote_sender_id(), player_name, "true"])
				_muda_para_alvo.rpc_id(multiplayer.get_remote_sender_id())
				_update_players_list.rpc(_players)
				return
			quantidade_patos += 1
			_players.append('{"id": "%s", "nome":"%s", "alvo":"%s"}' % [multiplayer.get_remote_sender_id(), player_name, "false"])
			_update_players_list.rpc(_players)
		else:
			_players.append('{"id": "%s", "nome":"%s", "alvo":"%s"}' % [multiplayer.get_remote_sender_id(), player_name, "true"])
			_update_players_list.rpc(_players)

@rpc("any_peer")
func _muda_para_alvo():
	OS.alert("Limite de patos atingidos, você foi alterado para um alvo", "Atenção")
	_alvo = true

@rpc("any_peer", "call_local")
func _update_players_list(_players_update):
	_players = _players_update
	var player_list = get_tree().root.get_node("Lobby/Panel/PlayerList")
	if is_instance_valid(player_list):
		player_list.clear()
		for p in _players:
			var json = JSON.parse_string(p)
			player_list.add_item(json["nome"] + " - " + _get_nome_jogavel(json["alvo"]), null, false)

func _get_nome_jogavel(_alvo):
	if _alvo == "true":
		return "ALVO"
	return "PATO"

func _on_connected_to_server():
	set_player_name.rpc(_player_nome, _alvo)
		
func _on_desconected() -> void:
	if multiplayer.is_server():
		_reset()
	mostrar_alerta = false
	multiplayer.multiplayer_peer.close()
