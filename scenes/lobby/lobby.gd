extends Control

func _on_host_pressed() -> void:
	GameManager.create_server($Panel/LineEditIp.text, $Panel/LineEditPorta.text.to_int(), $Panel/LineEditNome.text)
	_set_visible_buttons(false)
	_set_editable_line_edit(false)

func _set_visible_buttons(value: bool):
	$Panel/Host.visible = value
	$Panel/EntrarAlvo.visible = value
	$Panel/EntrarPato.visible = value
	
func _on_desconectar_pressed() -> void:
	GameManager.on_desconected()
	_set_visible_buttons(true)
	$Panel/PlayerList.clear()
	$Panel/Iniciar.visible = true
	_set_editable_line_edit(true)

func _set_editable_line_edit(value: bool):
	$Panel/LineEditIp.editable = value
	$Panel/LineEditPorta.editable = value
	$Panel/LineEditNome.editable = value

func _on_fechar_pressed() -> void:
	get_tree().quit()
	
func _on_iniciar_pressed() -> void:
	if GameManager.peer:
		_start_game.rpc()
		return
	_start_game()
		
@rpc("any_peer", "call_local")
func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func _on_entrar_pato_pressed() -> void:
	_set_editable_line_edit(false)
	$Panel/Iniciar.visible = false
	GameManager.join_server($Panel/LineEditIp.text, $Panel/LineEditPorta.text.to_int(), false, $Panel/LineEditNome.text)
	_set_visible_buttons(false)

func _on_entrar_alvo_pressed() -> void:
	$Panel/Iniciar.visible = false
	GameManager.join_server($Panel/LineEditIp.text, $Panel/LineEditPorta.text.to_int(), true, $Panel/LineEditNome.text)
	_set_visible_buttons(false)
