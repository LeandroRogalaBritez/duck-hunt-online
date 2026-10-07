extends Node

const MATCH := preload("res://scenes/invasion/invasion_match.tscn")
const Controller = preload("res://scenes/invasion/invasion_match.gd")
const Actor = preload("res://scenes/invasion/alien_actor.gd")
var _kind := "host"
var _transport := "lan"
var _game: Controller
var _acks: Dictionary = {}
var _started := 0
var _finished := false
var _saw_result := false
var _player_count := 3
var _room := "invasion-validation"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_kind = args[0] if args.size() > 0 else "host"
	_transport = args[1] if args.size() > 1 else "lan"
	_player_count = int(args[2]) if args.size() > 2 else 3
	_room = OS.get_environment("ALERTA_TERRA_TEST_ROOM")
	if _room.is_empty():
		_room = "invasion-validation"
	_started = Time.get_ticks_msec()
	if _kind == "host":
		if _transport == "lan":
			GameManager.hospedar_local("Defensor teste", 28910)
		else:
			GameManager.hospedar_online(_room, "Defensor teste")
		if not await _wait(func() -> bool: return GameManager.total_jogadores() == _player_count, 50 if _transport == "online" else 20):
			_fail("roster did not reach requested participant count")
			return
		_load_match.rpc()
		if not await _wait(func() -> bool: return is_instance_valid(_game) and _game._network_ready, 15):
			_fail("scene readiness handshake failed")
			return
		_game.begin_session()
		if not await _wait(func() -> bool: return _game.phase == Controller.Phase.DEFENSE, 5):
			_fail("defense phase did not start")
			return
		var start := (_game.get_node("Aliens").get_child(0) as Actor).position
		_movement_probe.rpc()
		await _wait(func() -> bool: return (_game.get_node("Aliens").get_child(0) as Actor).position.distance_to(start) > 20, 3)
		var moved := (_game.get_node("Aliens").get_child(0) as Actor).position.distance_to(start)
		if moved <= 20:
			_fail("ET movement inputs did not reach the host")
			return
		_freeze.rpc()
		await get_tree().process_frame
		for actor: Actor in _game.get_node("Aliens").get_children():
			actor.speed = 0
		_game.request_shot((_game.get_node("Aliens").get_child(0) as Actor).position)
		if not await _wait(func() -> bool: return _game.captures == 1, 3):
			_fail("host capture failed")
			return
		_shoot_second.rpc()
		if not await _wait(func() -> bool: return _game.captures == 2, 3):
			_fail("remote agent shot failed")
			return
		if _game.score != 1250 or _game.defense_wins != 1:
			_fail("authoritative score or victory count is incorrect")
			return
		_check_result.rpc()
		if not await _wait(func() -> bool: return _acks.size() == _player_count - 1, 5):
			_fail("clients did not confirm identical capture result")
			return
		_game.begin_session()
		if not await _wait(func() -> bool: return _game.phase == Controller.Phase.DEFENSE, 5):
			_fail("session restart failed")
			return
		_stale_shot.rpc()
		if not await _wait(func() -> bool: return _acks.has("stale"), 3):
			_fail("stale action probe was not acknowledged")
			return
		if _game.captures != 0 or int(_game._agents[1]) != 3:
			_fail("stale action changed the new round")
			return
		var departing_index := 0
		for actor: Actor in _game.get_node("Aliens").get_children():
			if actor.display_name == "ET teste":
				departing_index = actor.actor_id
		_disconnect_et.rpc()
		if not await _wait(func() -> bool: return (_game.get_node("Aliens").get_child(departing_index) as Actor).owner_peer == 0, 5):
			_fail("disconnected ET did not become AI")
			return
		GameManager.on_desconected()
		print("PASS: " + _transport + " host: readiness, movement, remote shot, score, restart, disconnect")
		_finished = true
		await _wait(func() -> bool: return _acks.size() >= 3, 5)
		get_tree().quit()
	else:
		if _transport == "lan":
			GameManager.entrar_local("127.0.0.1", _kind == "agent", "ET teste" if _kind == "et" else ("ET2 teste" if _kind == "et2" else "Agente teste"), 28910)
		else:
			GameManager.entrar_online(_room, _kind == "agent", "ET teste" if _kind == "et" else ("ET2 teste" if _kind == "et2" else "Agente teste"))


func _process(_delta: float) -> void:
	if _finished:
		return
	if Time.get_ticks_msec() - _started > (90000 if _transport == "online" else 45000):
		_fail("network test timed out")
	if (_kind == "agent" or _kind == "et2") and _saw_result and get_tree().current_scene != null and get_tree().current_scene.name == "Lobby":
		print("PASS: " + _transport + " agent: remote result and return to lobby after host loss")
		_finished = true
		get_tree().quit()


@rpc("authority", "call_local", "reliable")
func _load_match() -> void:
	_game = MATCH.instantiate() as Controller
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game


@rpc("authority", "call_local", "reliable")
func _movement_probe() -> void:
	if _kind == "et" or _kind == "et2":
		Input.action_press(&"invasion_right")
		_game._submit_shot.rpc_id(1, _game.wave, 500, Vector2(300, 300))


@rpc("authority", "call_local", "reliable")
func _freeze() -> void:
	Input.action_release(&"invasion_right")


@rpc("authority", "call_local", "reliable")
func _shoot_second() -> void:
	if _kind == "agent":
		_game.request_shot((_game.get_node("Aliens").get_child(1) as Actor).position)


@rpc("authority", "call_local", "reliable", 1)
func _check_result() -> void:
	if _kind != "host":
		if _game.score != 1250 or _game.captures != 2 or _game.defense_wins != 1:
			_fail("client result differs from host")
			return
		_saw_result = true
		_ack.rpc_id(1, _kind)


@rpc("any_peer", "call_remote", "reliable", 1)
func _ack(kind: String) -> void:
	_acks[kind] = true


@rpc("authority", "call_local", "reliable")
func _stale_shot() -> void:
	if _kind == "agent":
		_game._submit_shot.rpc_id(1, _game.wave - 1, 501, Vector2(225, 255))
		_ack.rpc_id(1, "stale")


@rpc("authority", "call_local", "reliable")
func _disconnect_et() -> void:
	if _kind == "et":
		GameManager.on_desconected()
		print("PASS: " + _transport + " ET: owned movement, forged shot rejected, consistent result")
		_finished = true
		get_tree().quit()


func _wait(condition: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await get_tree().process_frame
	return condition.call()


func _fail(message: String) -> void:
	push_error(_kind + ": " + message)
	_finished = true
	get_tree().quit(1)
