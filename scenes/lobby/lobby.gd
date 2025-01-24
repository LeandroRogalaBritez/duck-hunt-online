extends Control

func _on_host_pressed() -> void:
	GameManager._player_nome = $Panel/LineEditNome.text
	GameManager._create_server($Panel/LineEditIp.text, $Panel/LineEditPorta.text.to_int())
	_disable_buttons()
	GameManager._add_player(1, $Panel/LineEditNome.text)

func _disable_buttons():
	$Panel/Host.visible = false
	$Panel/Entrar.visible = false
	
func _able_buttons():
	$Panel/Host.visible = true
	$Panel/Entrar.visible = true
	
func _on_entrar_pressed() -> void:
	$Panel/Iniciar.visible = false
	GameManager._player_nome = $Panel/LineEditNome.text
	GameManager._join_server($Panel/LineEditIp.text, $Panel/LineEditPorta.text.to_int())
	_disable_buttons()
	
func _on_desconectar_pressed() -> void:
	GameManager._on_desconected()
	_able_buttons()
	$Panel/PlayerList.clear()
	$Panel/Iniciar.visible = true

func _on_fechar_pressed() -> void:
	get_tree().quit()
	
func _on_iniciar_pressed() -> void:
	if GameManager._peer:
		_start_game.rpc()
		return
	_start_game()
		
@rpc("any_peer", "call_local")
func _start_game() -> void:
	GameManager._gera_dicionario()
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
