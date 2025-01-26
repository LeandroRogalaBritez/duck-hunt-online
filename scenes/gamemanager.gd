extends Node

# Variaveis Publicas
var peer
var player_nome
var players_dicionario: Dictionary = {}
var alvo = true
var modo_multiplayer = false

# Variaveis privadas
var _quantidade_patos = 0
var _mostrar_alerta = true

var _players = []
var _players_patos = []

# Sinais
signal player_desconectou(player_id)

func get_nome(_unique_id) -> String:
	return players_dicionario[_unique_id]

func gera_dicionario() -> void:
	for p in _players:
		var _json = JSON.parse_string(p)
		players_dicionario[_json["id"]] = _json["nome"]
		
func create_server(_ip, _porta) -> void:
	modo_multiplayer = true
	peer = ENetMultiplayerPeer.new()
	peer.set_bind_ip(_ip)
	peer.create_server(_porta)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(remove_player)
	
func join_server(_ip, _porta, _alvo) -> void:
	modo_multiplayer = true
	self.alvo = _alvo
	peer = ENetMultiplayerPeer.new()
	multiplayer.connected_to_server.connect(on_connected_to_server)
	multiplayer.server_disconnected.connect(desconectou)
	peer.create_client(_ip, _porta)
	multiplayer.multiplayer_peer = peer
	
func reset():
	modo_multiplayer = false
	peer = null
	_players = []
	players_dicionario = {}
	player_nome = null
	_players_patos = []
	_mostrar_alerta = true
	
func desconectou():
	if _mostrar_alerta:
		OS.alert("Perdeu a conexão com servidor", "ALERTA")
	reset()
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")

func remove_player(_id = 1):
	player_desconectou.emit(_id)
	var index_remover = -1
	for p in _players:
		index_remover += 1
		var json = JSON.parse_string(p)
		if json["id"] == str(_id):
			if json["alvo"] == "false":
				_quantidade_patos -= 1
			break
	_players_patos.remove_at(_players_patos.find(str(_id)))
	_players.remove_at(index_remover)
	_update_players_list.rpc(_players)
	
func add_player(_id, _nome):
	_players.append('{"id": "%s", "nome":"%s", "alvo":"%s"}' % [_id, _nome, "true"])
	_update_players_list.rpc(_players)

@rpc("any_peer")
func set_player_name(_player_name: String, _alvo: bool):
	if multiplayer.is_server():
		if !_alvo:
			if _quantidade_patos == 2:
				_players.append('{"id": "%s", "nome":"%s", "alvo":"%s"}' % [multiplayer.get_remote_sender_id(), _player_name, "true"])
				_muda_para_alvo.rpc_id(multiplayer.get_remote_sender_id())
				_update_players_list.rpc(_players)
				return
			_quantidade_patos += 1
			_players.append('{"id": "%s", "nome":"%s", "alvo":"%s"}' % [multiplayer.get_remote_sender_id(), _player_name, "false"])
			_update_players_list.rpc(_players)
		else:
			_players.append('{"id": "%s", "nome":"%s", "alvo":"%s"}' % [multiplayer.get_remote_sender_id(), _player_name, "true"])
			_update_players_list.rpc(_players)

@rpc("any_peer")
func _muda_para_alvo():
	OS.alert("Limite de patos atingidos, você foi alterado para um alvo", "Atenção")
	alvo = true

@rpc("any_peer", "call_local")
func _update_players_list(_players_update):
	_players = _players_update
	var player_list = get_tree().root.get_node("Lobby/Panel/PlayerList")
	if is_instance_valid(player_list):
		player_list.clear()
		for p in _players:
			var _json = JSON.parse_string(p)
			player_list.add_item(_json["nome"] + " - " + _get_nome_jogavel(_json["alvo"]), null, false)

func _get_nome_jogavel(_alvo):
	if _alvo == "true":
		return "ALVO"
	return "PATO"

func on_connected_to_server():
	set_player_name.rpc(player_nome, alvo)
		
func on_desconected() -> void:
	if multiplayer.is_server():
		reset()
	_mostrar_alerta = false
	multiplayer.multiplayer_peer.close()
