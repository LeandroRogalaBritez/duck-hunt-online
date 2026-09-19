extends Node
# Reproducao: host ALVO + cliente PATO no modo Online, com o round rolando.
var papel := "host"
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: papel = a[0]
	var m := Node.new(); m.name = "M"; m.set_script(preload("res://_t/repro_mon.gd")); m.papel = papel
	get_tree().root.call_deferred("add_child", m)
	if papel == "host":
		GameManager.hospedar_online("repro", "HOST")
		await _w(func(): return multiplayer.get_peers().size() == 1 and GameManager.total_jogadores() == 2, 40.0)
		OnlineNetworkManager.trancar_sala()
		_ir.rpc()
	else:
		await get_tree().create_timer(2.0).timeout
		GameManager.entrar_online("repro", false, "PATO")   # <- cliente PATO
@rpc("any_peer", "call_local", "reliable")
func _ir() -> void: get_tree().change_scene_to_file("res://scenes/main/main.tscn")
func _w(c: Callable, s: float) -> bool:
	var l := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < l:
		if c.call(): return true
		await get_tree().process_frame
	return false
