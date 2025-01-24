extends Control

var _peer 
var _players = []

func _on_host_pressed() -> void:
	_peer = ENetMultiplayerPeer.new()
	_peer.set_bind_ip($Panel/LineEditIp.text)
	_peer.create_server($Panel/LineEditPorta.text.to_int())
	multiplayer.multiplayer_peer = _peer
	multiplayer.peer_connected.connect(_add_player)
	multiplayer.peer_disconnected.connect(_remove_player)
	_disable_buttons()
	_add_player()

func _disable_buttons():
	$Panel/Host.visible = false
	$Panel/Entrar.visible = false
	
func _able_buttons():
	$Panel/Host.visible = true
	$Panel/Entrar.visible = true
	
func _volta_tela_inicial() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")

func _on_entrar_pressed() -> void:
	$Panel/Iniciar.visible = false
	_peer = ENetMultiplayerPeer.new()
	_peer.create_client($Panel/LineEditIp.text, $Panel/LineEditPorta.text.to_int())
	multiplayer.multiplayer_peer = _peer
	_disable_buttons()
	
@rpc("any_peer", "call_local")
func _update_players_list(_players_update):
	_players = _players_update
	$Panel/PlayerList.clear()
	for p in _players:
		$Panel/PlayerList.add_item(str(p), null, false)

func _on_desconectar_pressed() -> void:
	_peer.close()
	_able_buttons()
	_players = []
	$Panel/PlayerList.clear()

func _on_fechar_pressed() -> void:
	get_tree().quit()
	
func _add_player(_id = 1):
	_players.append(_id)
	_update_players_list.rpc(_players)

func _remove_player(_id = 1):
	_players.remove_at(_players.find(_id))
	_update_players_list.rpc(_players)

func _on_iniciar_pressed() -> void:
	if _peer:
		_start_game.rpc()
		return
	_start_game()
		
@rpc("any_peer", "call_local")
func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
