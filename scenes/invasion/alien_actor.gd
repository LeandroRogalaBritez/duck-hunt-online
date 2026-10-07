extends Node2D

signal collected(actor_id: int)

enum State { ACTIVE, CAPTURED, LANDED }

const BODY_RADIUS := Vector2(27, 30)

var state: State = State.ACTIVE
var human_controlled := false
var owner_peer := 0
var display_name := ""
var is_local_player := false
var reduced_motion := false
var network_target := Vector2.ZERO
const HOVER := preload("res://assets/alien/art/et_hover.tres")
const BUBBLE := preload("res://assets/alien/art/containment.png")
var actor_id := 0
var velocity := Vector2.ZERO
var speed := 230.0
var dash_cooldown := 0.0
var dash_remaining := 0.0
var dash_buffer := 0.0
var _dash_direction := Vector2.ZERO
var _clock := 0.0
var _state_age := 0.0
var _capture_origin := Vector2.ZERO
var _ai_turn := 0.0
var _ai_angle := 0.0
var _rng := RandomNumberGenerator.new()
var _collection_announced := false


func setup(id: int, human: bool, start: Vector2, move_speed: float) -> void:
	actor_id = id
	human_controlled = human
	position = start
	speed = move_speed
	_rng.seed = 891 + id * 97
	_ai_angle = 0.5 if id == 0 else 2.6


func tick(delta: float, bounds: Rect2, input_direction: Vector2, landing: bool) -> void:
	_clock += delta
	_state_age += delta
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	dash_buffer = maxf(0.0, dash_buffer - delta)
	if state == State.CAPTURED:
		var progress := clampf(_state_age / 0.65, 0.0, 1.0)
		position = _capture_origin.lerp(Vector2(110 + actor_id * 60, 525), 1.0 - pow(1.0 - progress, 3.0))
		_check_collection()
		queue_redraw()
		return
	if state == State.LANDED:
		queue_redraw()
		return
	if landing:
		var target := Vector2(490 + actor_id * 95, 518)
		velocity = position.direction_to(target) * 620.0
		position = position.move_toward(target, delta * 620.0)
		queue_redraw()
		return
	var direction := input_direction
	if not human_controlled:
		_ai_turn -= delta
		if _ai_turn <= 0.0:
			_ai_turn = _rng.randf_range(0.8, 1.4)
			_ai_angle += _rng.randf_range(-0.6, 0.6)
		direction = Vector2(cos(_ai_angle), sin(_ai_angle) * 0.55).normalized()
		if position.x < bounds.position.x + 10:
			direction.x = absf(direction.x)
			_ai_angle = direction.angle()
		elif position.x > bounds.end.x - 10:
			direction.x = -absf(direction.x)
			_ai_angle = direction.angle()
		if position.y < bounds.position.y + 10:
			direction.y = absf(direction.y)
			_ai_angle = direction.angle()
		elif position.y > bounds.end.y - 10:
			direction.y = -absf(direction.y)
			_ai_angle = direction.angle()
	if dash_buffer > 0.0 and dash_cooldown <= 0.0 and direction.length_squared() > 0.0:
		_dash_direction = direction.normalized()
		dash_remaining = 0.2
		dash_cooldown = 2.0
		dash_buffer = 0.0
	if dash_remaining > 0.0:
		dash_remaining = maxf(0.0, dash_remaining - delta)
		velocity = _dash_direction * speed * 2.0
	else:
		velocity = direction * speed
	position += velocity * delta
	position = position.clamp(bounds.position, bounds.end)
	queue_redraw()


func buffer_dash() -> void:
	if state == State.ACTIVE:
		dash_buffer = 0.12


func contains_point(point: Vector2) -> bool:
	if state != State.ACTIVE:
		return false
	var relative := (point - position) / BODY_RADIUS
	return relative.length_squared() <= 1.0


func capture() -> bool:
	if state != State.ACTIVE:
		return false
	state = State.CAPTURED
	_capture_origin = position
	_state_age = 0.0
	velocity = Vector2.ZERO
	return true


func land() -> bool:
	if state != State.ACTIVE:
		return false
	state = State.LANDED
	position = Vector2(490 + actor_id * 95, 518)
	velocity = Vector2.ZERO
	_state_age = 0.0
	return true



func visual_tick(delta: float) -> void:
	_clock += delta
	_state_age += delta
	_check_collection()
	queue_redraw()


func _check_collection() -> void:
	if state == State.CAPTURED and _state_age >= 0.65 and not _collection_announced:
		_collection_announced = true
		collected.emit(actor_id)


func _draw() -> void:
	if state == State.LANDED:
		draw_line(Vector2.ZERO, Vector2(0, -35), Color("ffb866"), 3)
		draw_colored_polygon(PackedVector2Array([Vector2(0, -35), Vector2(18, -28), Vector2(0, -22)]), Color("ffb866"))
		return
	var frame := int(_clock * 8) % HOVER.get_frame_count(&"hover")
	var texture := HOVER.get_frame_texture(&"hover", frame)
	var sprite_scale := Vector2.ONE
	var dimensions := Vector2(96, 112)
	if state == State.CAPTURED:
		var progress := clampf(_state_age / 0.65, 0, 1)
		dimensions *= lerpf(1.0, 0.32, progress)
		draw_texture_rect(BUBBLE, Rect2(-dimensions * 0.62, dimensions * 1.24), false)
		if not reduced_motion:
			sprite_scale = Vector2(1 + sin(minf(_state_age * 20, PI)) * 0.18, 1.0)
	if dash_remaining > 0 and not reduced_motion:
		for i in range(1, 4):
			draw_texture_rect(texture, Rect2(-dimensions / 2 - _dash_direction * i * 14, dimensions), false, Color(1, 1, 1, 0.14 / i))
	draw_set_transform(Vector2.ZERO, 0, sprite_scale)
	draw_texture_rect(texture, Rect2(-dimensions / 2, dimensions), false)
	draw_set_transform(Vector2.ZERO)
	if state != State.ACTIVE:
		return
	if is_local_player:
		draw_arc(Vector2.ZERO, 45, -PI * 0.9, -PI * 0.1, 24, Color("ffb866"), 2)
		draw_string(ThemeDB.fallback_font, Vector2(-17, -56), "VOCÊ", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffb866"))
	elif not display_name.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(-35, -56), display_name.left(12), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f3f0e8"))

