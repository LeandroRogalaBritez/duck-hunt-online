extends Node
var papel := "?"
var t0 := 0
func _log(s: String) -> void:
	print("[%s %05d] %s" % [papel, Time.get_ticks_msec() - t0, s])
func _ready() -> void:
	t0 = Time.get_ticks_msec()
	# instrumenta TODAS as saidas possiveis
	GameManager.aviso.connect(func(x): _log("GameManager.aviso -> " + x))
	GameManager.conexao_falhou.connect(func(x): _log("GameManager.conexao_falhou -> " + str(x)))
	GameManager.player_desconectou.connect(func(x): _log("player_desconectou -> " + str(x)))
	OnlineNetworkManager.falhou.connect(func(x): _log("ONM.falhou -> " + x))
	OnlineNetworkManager.peer_negociacao_falhou.connect(func(x): _log("ONM.negociacao_falhou -> " + str(x)))
	OnlineNetworkManager.host_saiu.connect(func(): _log("ONM.host_saiu"))
	multiplayer.peer_connected.connect(func(i): _log("mp.peer_connected " + str(i)))
	multiplayer.peer_disconnected.connect(func(i): _log("mp.peer_disconnected " + str(i)))
	multiplayer.server_disconnected.connect(func(): _log("mp.server_disconnected"))
	multiplayer.connection_failed.connect(func(): _log("mp.connection_failed"))

	await _w(func(): return get_node_or_null("/root/Main") != null, 40.0)
	_log("entrou no main.tscn")
	var main := get_node_or_null("/root/Main")
	if main == null: return _fim()
	if papel == "host":
		await get_tree().create_timer(1.5).timeout
		_log("comecando o round")
		main._start_game.rpc()
	# monitora por 45s
	var fim := Time.get_ticks_msec() + 45000
	var ultimo := ""
	while Time.get_ticks_msec() < fim:
		var estado := "cena=%s peers=%s patos=%d alvos=%d" % [
			"Main" if get_node_or_null("/root/Main") != null else ("Lobby" if get_node_or_null("/root/Lobby") != null else "?"),
			str(multiplayer.get_peers()),
			(get_node("/root/Main/Patos").get_child_count() if get_node_or_null("/root/Main/Patos") else -1),
			(get_node("/root/Main/Alvos").get_child_count() if get_node_or_null("/root/Main/Alvos") else -1)]
		if estado != ultimo:
			ultimo = estado
			_log(estado)
		await get_tree().process_frame
	_fim()
func _fim() -> void:
	_log("fim")
	get_tree().quit()
func _w(c: Callable, s: float) -> bool:
	var l := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < l:
		if c.call(): return true
		await get_tree().process_frame
	return false
