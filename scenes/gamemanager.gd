extends Node

var _peer 
var players: Dictionary = {}
var _players = []
var _player_nome
var _multiplayer = false

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
	
func _join_server(ip, porta) -> void:
	_multiplayer = true
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
	
func _desconectou():
	_reset()
	OS.alert("Servidor Caiu a conexão", "ALERTA")
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")

func _remove_player(_id = 1):
	player_desconectou.emit(_id)
	_players.remove_at(_players.find(_id))
	_update_players_list.rpc(_players)
	
func _add_player(_id, nome):
	_players.append('{"id": "%s", "nome":"%s"}' % [_id, nome])
	_update_players_list.rpc(_players)

@rpc("any_peer")
func set_player_name(player_name: String):
	if multiplayer.is_server():
		_players.append('{"id": "%s", "nome":"%s"}' % [multiplayer.get_remote_sender_id(), player_name])
		_update_players_list.rpc(_players)

@rpc("any_peer", "call_local")
func _update_players_list(_players_update):
	_players = _players_update
	var player_list = get_tree().root.get_node("Lobby/Panel/PlayerList")
	if is_instance_valid(player_list):
		player_list.clear()
		for p in _players:
			var json = JSON.parse_string(p)
			player_list.add_item(json["nome"], null, false)
		
func _on_connected_to_server():
	set_player_name.rpc(_player_nome)
		
func _on_desconected() -> void:
	_reset()
