extends Control

func _on_host_pressed() -> void:
	GameManager.player_nome = $Panel/LineEditNome.text
	GameManager.create_server($Panel/LineEditIp.text, $Panel/LineEditPorta.text.to_int())
	_disable_buttons()
	GameManager.add_player(1, $Panel/LineEditNome.text)

func _disable_buttons():
	$Panel/Host.visible = false
	$Panel/EntrarAlvo.visible = false
	$Panel/EntrarPato.visible = false
	
func _able_buttons():
	$Panel/Host.visible = true
	$Panel/EntrarAlvo.visible = true
	$Panel/EntrarPato.visible = true
	
func _on_desconectar_pressed() -> void:
	GameManager.on_desconected()
	_able_buttons()
	$Panel/PlayerList.clear()
	$Panel/Iniciar.visible = true

func _on_fechar_pressed() -> void:
	get_tree().quit()
	
func _on_iniciar_pressed() -> void:
	if GameManager.peer:
		_start_game.rpc()
		return
	_start_game()
		
@rpc("any_peer", "call_local")
func _start_game() -> void:
	GameManager.gera_dicionario()
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func _on_entrar_pato_pressed() -> void:
	$Panel/Iniciar.visible = false
	GameManager.player_nome = $Panel/LineEditNome.text
	GameManager.join_server($Panel/LineEditIp.text, $Panel/LineEditPorta.text.to_int(), false)
	_disable_buttons()

func _on_entrar_alvo_pressed() -> void:
	$Panel/Iniciar.visible = false
	GameManager.player_nome = $Panel/LineEditNome.text
	GameManager.join_server($Panel/LineEditIp.text, $Panel/LineEditPorta.text.to_int(), true)
	_disable_buttons()
