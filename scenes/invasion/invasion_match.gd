extends Node2D

const AlienActor = preload("res://scenes/invasion/alien_actor.gd")
const GameWorld = preload("res://scenes/invasion/invasion_world.gd")
const GameAudio = preload("res://scenes/invasion/invasion_audio.gd")
const Hud = preload("res://scenes/invasion/invasion_hud.gd")
const ARENA := Rect2(44, 164, 682, 356)
const MOVE_BOUNDS := Rect2(74, 211, 622, 276)
const CYAN := Color("67e6e0")
const AMBER := Color("ffb866")

enum Phase { READY, BRIEFING, DEFENSE, LANDING, RESULT, REPORT }
enum Role { AGENT, ET }

class Pulse:
	var point := Vector2.ZERO
	var remaining := 0.0
	var duration := 0.15
	var event_id := 0

class Feedback:
	var point := Vector2.ZERO
	var age := 0.0
	var hit := false

@export_range(0.0, 0.3, 0.01) var pulse_delay := 0.15
@export var shot_cooldown := 0.6
@export var defense_duration := 14.0
@export var landing_duration := 1.2
@export var alien_speed := 230.0
@export var charges_per_wave := 3

@onready var _world: GameWorld = $World
@onready var _audio: GameAudio = $Audio
@onready var _actors_node: Node2D = $Aliens
@onready var _hud: Hud = $Interface/Controls

var role: Role = Role.AGENT
var phase: Phase = Phase.READY
var wave := 0
var score := 0
var captures := 0
var infiltrations := 0
var defense_wins := 0
var invasion_wins := 0
var charges := 3
var phase_remaining := 0.0
var _actors: Array[AlienActor] = []
var _pulses: Array[Pulse] = []
var _feedback: Array[Feedback] = []
var _agents: Dictionary = {}
var _cooldowns: Dictionary = {}
var _owners: Array[int] = []
var _inputs: Dictionary = {}
var _input_times: Dictionary = {}
var _aims: Dictionary = {}
var _last_inputs: Dictionary = {}
var _last_shots: Dictionary = {}
var _buckets: Dictionary = {}
var _actions: Array[StringName] = []
var _network_ready := false
var _paused := false
var _hitboxes := false
var _reduced_motion := false
var _aim := Vector2(385, 300)
var _input_sequence := 0
var _shot_sequence := 0
var _event_sequence := 0
var _snapshot_sequence := 0
var _last_snapshot := -1
var _send_clock := 0.0
var _snapshot_clock := 0.0
var _ai_clock := 1.7
var _message := ""
var _message_time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	get_window().title = "Alerta: Terra"
	_rng.seed = 712
	_bind(&"invasion_left", [KEY_A, KEY_LEFT])
	_bind(&"invasion_right", [KEY_D, KEY_RIGHT])
	_bind(&"invasion_up", [KEY_W, KEY_UP])
	_bind(&"invasion_down", [KEY_S, KEY_DOWN])
	_bind(&"invasion_dash", [KEY_SPACE])
	_bind(&"invasion_restart", [KEY_R])
	_bind(&"invasion_switch", [KEY_TAB])
	_bind(&"invasion_pause", [KEY_ESCAPE])
	_bind(&"invasion_start", [KEY_ENTER])
	_bind(&"invasion_hitboxes", [KEY_H])
	_bind(&"invasion_fire", [])
	if _actions.has(&"invasion_fire"):
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(&"invasion_fire", click)
	role = Role.AGENT if GameManager.agente else Role.ET
	_hud.play_requested.connect(_primary_action)
	_hud.restart_requested.connect(begin_session)
	_hud.role_requested.connect(select_role)
	_hud.lobby_requested.connect(_return_to_lobby)
	_hud.delay_changed.connect(func(value: float) -> void: pulse_delay = value)
	_hud.effects_changed.connect(_audio.set_effects_volume)
	_hud.ambience_changed.connect(_audio.set_ambience_volume)
	_hud.motion_changed.connect(_set_reduced_motion)
	_show_ready()
	if GameManager.modo_multiplayer:
		GameManager.todos_prontos.connect(_on_todos_prontos)
		GameManager.player_desconectou.connect(_on_player_left)
		GameManager.notificar_pronto.rpc(multiplayer.get_unique_id(), GameManager.agente)


func _exit_tree() -> void:
	for action in _actions:
		InputMap.erase_action(action)


func _bind(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	_actions.append(action)
	for key: int in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"invasion_restart"):
		begin_session()
	elif event.is_action_pressed(&"invasion_switch"):
		select_role(Role.ET if role == Role.AGENT else Role.AGENT)
	elif event.is_action_pressed(&"invasion_start"):
		_primary_action()
	elif event.is_action_pressed(&"invasion_pause"):
		if phase == Phase.READY or phase == Phase.REPORT:
			_return_to_lobby()
		else:
			_paused = not _paused
			_hud.show_pause(_paused, GameManager.modo_multiplayer)
	elif event.is_action_pressed(&"invasion_hitboxes"):
		_hitboxes = not _hitboxes
	elif not _paused and event.is_action_pressed(&"invasion_dash") and role == Role.ET:
		if multiplayer.is_server():
			_accept_dash(multiplayer.get_unique_id(), wave)
		else:
			_submit_dash.rpc_id(1, wave)
	elif not _paused and event.is_action_pressed(&"invasion_fire") and role == Role.AGENT:
		request_shot(get_global_mouse_position())


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector(&"invasion_left", &"invasion_right", &"invasion_up", &"invasion_down")
	if _paused:
		direction = Vector2.ZERO
	if GameManager.modo_multiplayer and _network_ready:
		_send_clock -= delta
		if _send_clock <= 0.0:
			_send_clock = 0.05
			_input_sequence += 1
			if multiplayer.is_server():
				_accept_input(multiplayer.get_unique_id(), wave, _input_sequence, direction, get_global_mouse_position())
			else:
				_submit_input.rpc_id(1, wave, _input_sequence, direction, get_global_mouse_position())
	if multiplayer.is_server():
		step(delta, direction)
		if GameManager.modo_multiplayer and _network_ready:
			_snapshot_clock -= delta
			if _snapshot_clock <= 0.0:
				_snapshot_clock = 0.05
				_send_snapshot()
	else:
		_remote_step(delta, direction)
	_refresh_hud()
	queue_redraw()


func begin_session() -> void:
	if not multiplayer.is_server() or (GameManager.modo_multiplayer and not _network_ready):
		return
	_paused = false
	wave = 0
	score = 0
	defense_wins = 0
	invasion_wins = 0
	_audio.cue(&"ui")
	_configure_roster()
	_start_wave()


func select_role(new_role: int) -> void:
	if GameManager.modo_multiplayer:
		return
	role = new_role as Role
	GameManager.agente = role == Role.AGENT
	_paused = false
	_audio.cue(&"ui")
	_show_ready()


func request_shot(point: Vector2) -> bool:
	if _paused or role != Role.AGENT:
		return false
	_shot_sequence += 1
	if multiplayer.is_server():
		return _server_fire(multiplayer.get_unique_id(), wave, _shot_sequence, point)
	_submit_shot.rpc_id(1, wave, _shot_sequence, point)
	return true


func step(delta: float, direction: Vector2 = Vector2.ZERO) -> void:
	if _paused and not GameManager.modo_multiplayer:
		return
	_tick_feedback(delta)
	for peer_id in _cooldowns:
		_cooldowns[peer_id] = maxf(0.0, float(_cooldowns[peer_id]) - delta)
	if role == Role.AGENT:
		_aim = get_global_mouse_position()
	if phase == Phase.DEFENSE or phase == Phase.LANDING or phase == Phase.RESULT:
		for actor in _actors:
			var movement := Vector2.ZERO
			if actor.owner_peer == multiplayer.get_unique_id():
				movement = direction
			elif actor.owner_peer > 0 and Time.get_ticks_msec() - int(_input_times.get(actor.owner_peer, 0)) < 350:
				movement = _inputs.get(actor.owner_peer, Vector2.ZERO)
			var old_dash := actor.dash_cooldown
			actor.tick(delta, MOVE_BOUNDS, movement, phase == Phase.LANDING)
			if actor.dash_cooldown > old_dash:
				_dash_started.rpc(wave, actor.actor_id)
	for i in range(_pulses.size() - 1, -1, -1):
		var pulse := _pulses[i]
		pulse.remaining -= delta
		if pulse.remaining <= 0.0:
			_resolve_pulse(pulse.point, pulse.event_id)
			_pulses.remove_at(i)
	if phase == Phase.DEFENSE and not GameManager.modo_multiplayer and role == Role.ET:
		_ai_clock -= delta
		if _ai_clock <= 0.0 and int(_agents.get(0, 0)) > 0:
			_ai_clock = 3.5
			_ai_fire()
	if phase == Phase.DEFENSE and _total_charges() <= 0 and _pulses.is_empty() and captures < 2:
		_begin_landing()
	if phase == Phase.BRIEFING or phase == Phase.DEFENSE or phase == Phase.LANDING or phase == Phase.RESULT:
		phase_remaining -= delta
		if phase_remaining <= 0.0:
			match phase:
				Phase.BRIEFING:
					_set_phase.rpc(wave, Phase.DEFENSE, defense_duration)
				Phase.DEFENSE:
					_begin_landing()
				Phase.LANDING:
					for actor in _actors:
						if actor.land():
							infiltrations += 1
					_finish_wave()
				Phase.RESULT:
					if wave >= 5 or (GameManager.modo_multiplayer and (defense_wins >= 3 or invasion_wins >= 3)):
						_report.rpc(score, defense_wins, invasion_wins)
					else:
						_start_wave()
	if (phase == Phase.DEFENSE or phase == Phase.LANDING) and captures == 2:
		_finish_wave()
	if phase == Phase.RESULT:
		_world.presentation_age = 2.4 - phase_remaining
	_update_resources()
	_refresh_hud()
	queue_redraw()


func get_status() -> Dictionary:
	return {"phase": phase, "wave": wave, "charges": charges, "captures": captures,
		"infiltrations": infiltrations, "score": score, "defense_wins": defense_wins,
		"invasion_wins": invasion_wins, "pending_pulses": _pulses.size()}


func _configure_roster() -> void:
	_agents.clear()
	_owners.clear()
	if not GameManager.modo_multiplayer:
		_agents[1 if role == Role.AGENT else 0] = charges_per_wave
		if role == Role.ET:
			_owners.append(1)
		return
	var roster := GameManager.get_roster()
	var ids := roster.keys()
	ids.sort()
	for key in ids:
		var peer_id := int(key)
		if roster[key]["agente"]:
			_agents[peer_id] = charges_per_wave
		elif _owners.size() < 2:
			_owners.append(peer_id)


func _on_todos_prontos() -> void:
	_network_ready = true
	_hud.set_ready(_network_ready and multiplayer.is_server())


func _start_wave() -> void:
	wave += 1
	var owners: Array[int] = []
	var names: Array[String] = []
	for i in 2:
		var owner := _owners[i] if i < _owners.size() else 0
		owners.append(owner)
		names.append(GameManager.get_nome(owner) if owner > 0 and GameManager.modo_multiplayer else "")
	_wave_started.rpc(wave, owners, names, _agents.keys(), score, defense_wins, invasion_wins, pulse_delay)


@rpc("authority", "call_local", "reliable", 1)
func _wave_started(round_id: int, owners: Array, names: Array, agents: Array, points: int, defenders: int, invaders: int, delay: float) -> void:
	_clear_actors()
	_pulses.clear()
	_feedback.clear()
	_agents.clear()
	_cooldowns.clear()
	_last_shots.clear()
	_last_inputs.clear()
	_inputs.clear()
	_input_times.clear()
	_aims.clear()
	_last_snapshot = -1
	wave = round_id
	score = points
	defense_wins = defenders
	invasion_wins = invaders
	pulse_delay = delay
	captures = 0
	infiltrations = 0
	_paused = false
	_ai_clock = 1.7
	for peer_id in agents:
		_agents[int(peer_id)] = charges_per_wave
		_cooldowns[int(peer_id)] = 0.0
	if GameManager.modo_multiplayer:
		role = Role.AGENT if _agents.has(multiplayer.get_unique_id()) else Role.ET
	for i in 2:
		var actor := AlienActor.new()
		actor.setup(i, int(owners[i]) > 0, Vector2(225 + i * 300, 255 + i * 65), alien_speed * (1 + (wave - 1) * 0.08 if not GameManager.modo_multiplayer else 1.0))
		actor.owner_peer = int(owners[i])
		actor.is_local_player = actor.owner_peer == multiplayer.get_unique_id()
		actor.display_name = str(names[i])
		actor.reduced_motion = _reduced_motion
		actor.network_target = actor.position
		actor.collected.connect(func(_id: int) -> void: _audio.cue(&"collect"))
		_actors_node.add_child(actor)
		_actors.append(actor)
	phase = Phase.BRIEFING
	phase_remaining = 0.8
	_world.landing = false
	_world.presentation = false
	_world.presentation_age = 0.0
	_hud.hide_overlay()
	_audio.cue(&"wave")
	_notify("ONDA %d: naves lançando invasores!" % wave, 1.4)
	_update_resources()


func _server_fire(peer_id: int, round_id: int, sequence: int, point: Vector2) -> bool:
	if not multiplayer.is_server() or round_id != wave or not _agents.has(peer_id) or not point.is_finite() or not ARENA.has_point(point):
		return false
	if phase != Phase.DEFENSE and phase != Phase.LANDING:
		return false
	if phase == Phase.LANDING and phase_remaining < pulse_delay:
		return false
	if sequence <= int(_last_shots.get(peer_id, -1)):
		return false
	_last_shots[peer_id] = sequence
	if float(_cooldowns.get(peer_id, 0.0)) > 0.0:
		return false
	if int(_agents[peer_id]) <= 0:
		if peer_id == multiplayer.get_unique_id():
			_audio.cue(&"miss")
			_notify("Sem cargas. Aguarde o desembarque.", 0.8)
		_cooldowns[peer_id] = 0.15
		return false
	_agents[peer_id] = int(_agents[peer_id]) - 1
	_cooldowns[peer_id] = shot_cooldown
	_event_sequence += 1
	_pulse_started.rpc(wave, _event_sequence, peer_id, point, pulse_delay, int(_agents[peer_id]))
	_update_resources()
	return true


@rpc("any_peer", "call_remote", "reliable", 1)
func _submit_shot(round_id: int, sequence: int, point: Vector2) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and _allow_packet(sender):
		_server_fire(sender, round_id, sequence, point)


@rpc("authority", "call_local", "reliable", 1)
func _pulse_started(round_id: int, event_id: int, owner: int, point: Vector2, delay: float, remaining: int) -> void:
	if round_id != wave:
		return
	var pulse := Pulse.new()
	pulse.point = point
	pulse.duration = maxf(delay, 0.001)
	pulse.remaining = delay
	pulse.event_id = event_id
	_pulses.append(pulse)
	_agents[owner] = remaining
	_cooldowns[owner] = shot_cooldown
	_audio.cue(&"prepare" if delay > 0 else &"fire")


func _resolve_pulse(point: Vector2, event_id: int) -> void:
	if phase != Phase.DEFENSE and phase != Phase.LANDING:
		return
	var target: AlienActor = null
	var nearest := INF
	for actor in _actors:
		var distance := actor.position.distance_squared_to(point)
		if actor.contains_point(point) and distance < nearest:
			target = actor
			nearest = distance
	var target_id := -1
	if target != null and target.capture():
		captures += 1
		score += 500
		target_id = target.actor_id
	_impact.rpc(wave, event_id, target_id, point, captures, score)


@rpc("authority", "call_local", "reliable", 1)
func _impact(round_id: int, event_id: int, target_id: int, point: Vector2, total: int, points: int) -> void:
	if round_id != wave:
		return
	if not multiplayer.is_server():
		for i in range(_pulses.size() - 1, -1, -1):
			if _pulses[i].event_id == event_id:
				_pulses.remove_at(i)
		if target_id >= 0:
			_actors[target_id].capture()
	captures = total
	score = points
	var effect := Feedback.new()
	effect.point = point
	effect.hit = target_id >= 0
	_feedback.append(effect)
	_audio.cue(&"hit" if effect.hit else &"fire")
	_notify("CAPTURADO! +500" if effect.hit else "O pulso não acertou. Antecipe a trajetória.", 0.9)


func _begin_landing() -> void:
	_set_phase.rpc(wave, Phase.LANDING, landing_duration)


@rpc("authority", "call_local", "reliable", 1)
func _set_phase(round_id: int, state: int, remaining: float) -> void:
	if round_id != wave:
		return
	phase = state as Phase
	phase_remaining = remaining
	_world.landing = phase == Phase.LANDING
	if _world.landing:
		_audio.cue(&"landing")
		_notify("CORREDOR ABERTO! Invasores desembarcando.", 1.2)


func _finish_wave() -> void:
	if phase == Phase.RESULT or phase == Phase.REPORT:
		return
	var perfect := captures == 2
	if perfect:
		defense_wins += 1
		score += 250
	else:
		invasion_wins += 1
	_result.rpc(wave, perfect, captures, infiltrations, score, defense_wins, invasion_wins)


@rpc("authority", "call_local", "reliable", 1)
func _result(round_id: int, perfect: bool, contained_count: int, landed_count: int, points: int, defenders: int, invaders: int) -> void:
	if round_id != wave:
		return
	captures = contained_count
	infiltrations = landed_count
	score = points
	defense_wins = defenders
	invasion_wins = invaders
	for actor in _actors:
		if actor.state == AlienActor.State.ACTIVE:
			actor.land()
	phase = Phase.RESULT
	phase_remaining = 2.4
	_pulses.clear()
	_world.landing = false
	_world.presentation = true
	_world.contained = perfect
	_world.presentation_age = 0.0
	_audio.cue(&"win" if perfect else &"lose")
	_notify("Tá aqui a prova! Onda contida. +250" if perfect else "Eles passaram pela defesa!", 2.4)


@rpc("authority", "call_local", "reliable", 1)
func _report(points: int, defenders: int, invaders: int) -> void:
	score = points
	defense_wins = defenders
	invasion_wins = invaders
	phase = Phase.REPORT
	_paused = false
	_hud.show_report(defense_wins, invasion_wins, score, wave, role == Role.AGENT, not GameManager.modo_multiplayer or multiplayer.is_server())


func _accept_dash(peer_id: int, round_id: int) -> void:
	if round_id != wave or phase != Phase.DEFENSE:
		return
	for actor in _actors:
		if actor.owner_peer == peer_id:
			actor.buffer_dash()


@rpc("any_peer", "call_remote", "reliable", 1)
func _submit_dash(round_id: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and _allow_packet(sender):
		_accept_dash(sender, round_id)


@rpc("authority", "call_local", "reliable", 1)
func _dash_started(round_id: int, index: int) -> void:
	if round_id == wave and index < _actors.size():
		_audio.cue(&"dash")


@rpc("any_peer", "call_remote", "unreliable_ordered", 0)
func _submit_input(round_id: int, sequence: int, direction: Vector2, aim: Vector2) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and _allow_packet(sender):
		_accept_input(sender, round_id, sequence, direction, aim)


func _accept_input(peer_id: int, round_id: int, sequence: int, direction: Vector2, aim: Vector2) -> void:
	if round_id != wave or not direction.is_finite() or not aim.is_finite() or sequence <= int(_last_inputs.get(peer_id, -1)):
		return
	if not _agents.has(peer_id) and not _owners.has(peer_id):
		return
	_last_inputs[peer_id] = sequence
	_inputs[peer_id] = direction.limit_length(1)
	_input_times[peer_id] = Time.get_ticks_msec()
	_aims[peer_id] = aim.clamp(ARENA.position, ARENA.end)


func _allow_packet(peer_id: int) -> bool:
	var now := Time.get_ticks_msec()
	var bucket: Array = _buckets.get(peer_id, [now, 0])
	if now - int(bucket[0]) > 1000:
		bucket = [now, 0]
	bucket[1] = int(bucket[1]) + 1
	_buckets[peer_id] = bucket
	return int(bucket[1]) <= 60


func _send_snapshot() -> void:
	if _actors.size() != 2:
		return
	var data := PackedFloat32Array()
	for actor in _actors:
		data.append_array(PackedFloat32Array([actor.position.x, actor.position.y, actor.velocity.x, actor.velocity.y, actor.state, actor.dash_cooldown, actor.dash_remaining]))
	_snapshot_sequence += 1
	_snapshot.rpc(wave, _snapshot_sequence, phase, phase_remaining, data, _agents, _cooldowns, _aims)


@rpc("authority", "call_remote", "unreliable_ordered", 0)
func _snapshot(round_id: int, sequence: int, state: int, remaining: float, data: PackedFloat32Array, resources: Dictionary, cooldowns: Dictionary, aims: Dictionary) -> void:
	if round_id != wave or sequence <= _last_snapshot or data.size() != 14 or _actors.size() != 2:
		return
	_last_snapshot = sequence
	# Reliable state events own transitions. A stale snapshot cannot roll them back.
	if state == phase:
		phase_remaining = remaining
	_agents = resources
	_cooldowns = cooldowns
	_aims = aims
	for i in 2:
		var actor := _actors[i]
		var offset := i * 7
		actor.network_target = Vector2(data[offset], data[offset + 1])
		actor.velocity = Vector2(data[offset + 2], data[offset + 3])
		actor.dash_cooldown = data[offset + 5]
		actor.dash_remaining = data[offset + 6]
		actor._dash_direction = actor.velocity.normalized()
	_update_resources()


func _remote_step(delta: float, direction: Vector2) -> void:
	_tick_feedback(delta)
	phase_remaining = maxf(0, phase_remaining - delta)
	_aim = get_global_mouse_position()
	for actor in _actors:
		if actor.is_local_player and actor.state == AlienActor.State.ACTIVE and phase == Phase.DEFENSE:
			actor.tick(delta, MOVE_BOUNDS, direction, false)
		else:
			actor.visual_tick(delta)
		if actor.state == AlienActor.State.ACTIVE:
			actor.position = actor.position.lerp(actor.network_target, minf(delta * 18, 1))
		elif actor.state == AlienActor.State.CAPTURED:
			actor.position = actor.position.lerp(actor.network_target, minf(delta * 20, 1))
	for pulse in _pulses:
		pulse.remaining -= delta
	if phase == Phase.RESULT:
		_world.presentation_age = 2.4 - phase_remaining


func _ai_fire() -> void:
	var candidates: Array[AlienActor] = []
	for actor in _actors:
		if actor.state == AlienActor.State.ACTIVE:
			candidates.append(actor)
	if candidates.is_empty():
		return
	var target := candidates[_rng.randi_range(0, candidates.size() - 1)]
	_aim = target.position + target.velocity * pulse_delay * 0.7 + Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-12, 12))
	_shot_sequence += 1
	_server_fire(0, wave, _shot_sequence, _aim.clamp(ARENA.position, ARENA.end - Vector2.ONE))


func _on_player_left(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_agents.erase(peer_id)
	_cooldowns.erase(peer_id)
	_aims.erase(peer_id)
	var index := _owners.find(peer_id)
	if index >= 0:
		_owners[index] = 0
	for actor in _actors:
		if actor.owner_peer == peer_id:
			_ownership_changed.rpc(wave, actor.actor_id)


@rpc("authority", "call_local", "reliable", 1)
func _ownership_changed(round_id: int, index: int) -> void:
	if round_id == wave and index < _actors.size():
		var actor := _actors[index]
		actor.owner_peer = 0
		actor.human_controlled = false
		actor.is_local_player = false
		actor.display_name = ""
		actor._ai_angle = actor.velocity.angle()


func _total_charges() -> int:
	var total := 0
	for value in _agents.values():
		total += int(value)
	return total


func _update_resources() -> void:
	charges = int(_agents.get(multiplayer.get_unique_id(), 0)) if role == Role.AGENT else _total_charges()


func _tick_feedback(delta: float) -> void:
	_message_time = maxf(0, _message_time - delta)
	for effect in _feedback:
		effect.age += delta
	for i in range(_feedback.size() - 1, -1, -1):
		if _feedback[i].age > 0.65:
			_feedback.remove_at(i)


func _clear_actors() -> void:
	for actor in _actors:
		actor.free()
	_actors.clear()


func _show_ready() -> void:
	_clear_actors()
	_pulses.clear()
	_feedback.clear()
	phase = Phase.READY
	wave = 0
	score = 0
	captures = 0
	infiltrations = 0
	defense_wins = 0
	invasion_wins = 0
	charges = charges_per_wave
	_world.presentation = false
	_world.landing = false
	_hud.show_ready(role == Role.AGENT, GameManager.modo_multiplayer, multiplayer.is_server())
	_refresh_hud()


func _primary_action() -> void:
	if _paused:
		_paused = false
		_audio.cue(&"ui")
		_hud.hide_overlay()
	elif phase == Phase.READY or phase == Phase.REPORT:
		begin_session()


func _return_to_lobby() -> void:
	GameManager.on_desconected()
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")


func _set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	_world.reduced_motion = value
	for actor in _actors:
		actor.reduced_motion = value


func _notify(text: String, duration: float) -> void:
	_message = text
	_message_time = duration


func _refresh_hud() -> void:
	var cooldown := -1.0
	for actor in _actors:
		if actor.is_local_player:
			cooldown = actor.dash_cooldown if actor.state == AlienActor.State.ACTIVE else (-2.0 if actor.state == AlienActor.State.CAPTURED else -3.0)
	_hud.refresh(wave, score, charges, captures, defense_wins, invasion_wins, phase_remaining if phase == Phase.DEFENSE or phase == Phase.LANDING else -1, role == Role.AGENT, cooldown, _message if _message_time > 0 else "")


func _draw() -> void:
	for pulse in _pulses:
		var progress := clampf(1 - pulse.remaining / pulse.duration, 0, 1)
		draw_circle(pulse.point, 31, Color(AMBER, 0.08))
		draw_arc(pulse.point, lerpf(48, 28, progress), 0, TAU, 40, AMBER, 2)
		draw_line(pulse.point - Vector2(6, 0), pulse.point + Vector2(6, 0), AMBER, 2)
		draw_line(pulse.point - Vector2(0, 6), pulse.point + Vector2(0, 6), AMBER, 2)
	for effect in _feedback:
		var color := Color(CYAN if effect.hit else AMBER, 1.0 - effect.age / 0.65)
		draw_arc(effect.point, 12 + effect.age * 90, 0, TAU, 32, color, 3)
		if not _reduced_motion:
			for i in 8:
				var direction := Vector2.from_angle(i * TAU / 8)
				draw_line(effect.point + direction * (20 + effect.age * 70), effect.point + direction * (27 + effect.age * 90), color, 2)
		if effect.hit:
			draw_string(ThemeDB.fallback_font, effect.point + Vector2(-20, -44 - effect.age * 35), "+500", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, color)
	if (phase == Phase.DEFENSE or phase == Phase.LANDING) and not _paused:
		var aim := _aim
		if role == Role.ET and not _aims.is_empty():
			aim = _aims.values()[0]
		for i in 3:
			draw_arc(aim, 15, i * TAU / 3, i * TAU / 3 + 1.5, 12, CYAN if role == Role.AGENT else AMBER, 2)
		draw_circle(aim, 2, CYAN if role == Role.AGENT else AMBER)
	if _hitboxes:
		for actor in _actors:
			if actor.state == AlienActor.State.ACTIVE:
				draw_set_transform(actor.position, 0, AlienActor.BODY_RADIUS)
				draw_arc(Vector2.ZERO, 1, 0, TAU, 40, Color("ff6363"), 0.04)
				draw_set_transform(Vector2.ZERO)
