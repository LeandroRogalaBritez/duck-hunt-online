extends Node

# Variaveis Publicas
var peer
var alvo = true
var modo_multiplayer = false
var players_patos = []

# Variaveis Privadas
var _player_nome
var _quantidade_patos = 0
var _mostrar_alerta = true
var _players_dicionario: Dictionary = {}

# Sinais
signal player_desconectou(player_id)

func get_nome(_unique_id) -> String:
	return _players_dicionario[_unique_id]["nome"]

func create_server(_ip, _porta, _nome) -> void:
	modo_multiplayer = true
	peer = ENetMultiplayerPeer.new()
	peer.set_bind_ip(_ip)
	peer.create_server(_porta)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(remove_player)
	_gera_dicionario_player(multiplayer.get_unique_id(), _nome, "true")
	_update_players_dicionario.rpc(_players_dicionario)

func _gera_dicionario_player(_id, _nome, _alvo):
	_players_dicionario[str(_id)] = {"nome":_nome, "alvo":_alvo}
	
func join_server(_ip, _porta, _alvo, _player_nome) -> void:
	modo_multiplayer = true
	self.alvo = _alvo
	self._player_nome = _player_nome
	peer = ENetMultiplayerPeer.new()
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_disconnected_to_server)
	peer.create_client(_ip, _porta)
	multiplayer.multiplayer_peer = peer
	
func _reset():
	modo_multiplayer = false
	peer = null
	_players_dicionario = {}
	_player_nome = null
	players_patos = []
	_mostrar_alerta = true
	
func _on_disconnected_to_server():
	if _mostrar_alerta:
		OS.alert("Perdeu a conexão com servidor", "ALERTA")
	_reset()
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")

func remove_player(_id = 1):
	player_desconectou.emit(_id)
	
	if _players_dicionario[str(_id)]["alvo"]:
		_quantidade_patos -= 1
		
	_players_dicionario.erase(str(_id))

	players_patos.remove_at(players_patos.find(str(_id)))
	_update_players_dicionario.rpc(_players_dicionario)

@rpc("any_peer")
func set_player_name(_player_name: String, _alvo: bool):
	if multiplayer.is_server():
		if !_alvo:
			if _quantidade_patos == 2:
				_gera_dicionario_player(multiplayer.get_remote_sender_id(), _player_name, "true")
				_muda_para_alvo.rpc_id(multiplayer.get_remote_sender_id())
				_update_players_dicionario.rpc(_players_dicionario)
				return
			_quantidade_patos += 1
			_gera_dicionario_player(multiplayer.get_remote_sender_id(), _player_name, "false")
			_update_players_dicionario.rpc(_players_dicionario)
		else:
			_gera_dicionario_player(multiplayer.get_remote_sender_id(), _player_name, "true")
			_update_players_dicionario.rpc(_players_dicionario)

@rpc("any_peer")
func _muda_para_alvo():
	OS.alert("Limite de patos atingidos, você foi alterado para um alvo", "Atenção")
	alvo = true

@rpc("any_peer", "call_local")
func _update_players_dicionario(_players_dicionario):
	self._players_dicionario = _players_dicionario
	var _player_list = get_tree().root.get_node("Lobby/Panel/PlayerList")
	if is_instance_valid(_player_list):
		_player_list.clear()
		for _p in _players_dicionario:
			var _json = _players_dicionario[_p]
			_player_list.add_item(_json["nome"] + " - " + _get_nome_jogavel(_json["alvo"]), null, false)

func _get_nome_jogavel(_alvo):
	if _alvo == "true":
		return "ALVO"
	return "PATO"

func _on_connected_to_server():
	set_player_name.rpc(_player_nome, alvo)
		
func on_desconected() -> void:
	if multiplayer.is_server():
		_reset()
	_mostrar_alerta = false
	multiplayer.multiplayer_peer.close()
