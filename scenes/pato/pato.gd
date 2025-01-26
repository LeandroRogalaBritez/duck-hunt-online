extends CharacterBody2D

var _velocidade: float = 300.0
var _direcao_x: int
var _direcao_y: int = -1
@onready var _animacao_sprite: AnimatedSprite2D = $AnimatedSprite2D
var vivo: bool = true
@onready var audio = $Audio/Pato
@onready var label = $Label
@export var pontuacao = "0" 
var quantidade_bounce_top
@export var _jogavel: bool
@onready var auto_bounce = $TentativaDeBounce
@export var pode_fugir = false

func _ready() -> void:
	$TimerPodeFugir.start()
	if multiplayer.is_server():
		if !_jogavel:
			_mover_direcao_aleatoria_x()
			_seleciona_animacao()
			audio.play()

	if _jogavel:
		rpc_id(name.to_int(), "_grava_propriedades", _jogavel, pontuacao, position)
		auto_bounce.stop()

@rpc("any_peer", "call_local")
func _grava_autoridade() -> void:
	set_multiplayer_authority(name.to_int())

@rpc("any_peer", "call_local", "unreliable")
func _grava_propriedades(_jogavel, _pontuacao, _position) -> void:
	_grava_autoridade.rpc()
	self._jogavel = _jogavel
	self.pontuacao = _pontuacao
	self.position = _position
	if _jogavel:
		$Nome.text = GameManager._player_nome
		$Nome.visible = true
	
func _seleciona_animacao() -> void:
	if _jogavel:
		var _horizontal_input: float = Input.get_axis("ui_left", "ui_right")
		if _horizontal_input == -1:
			_animacao_sprite.flip_h = true
		if _horizontal_input == +1:
			_animacao_sprite.flip_h = false
		_animacao_sprite.play("cima")
		
	if _direcao_x < 0:
		_animacao_sprite.flip_h = true
		_animacao_sprite.play("cima")
		return
	elif _direcao_x > 0:
		_animacao_sprite.flip_h = false
		_animacao_sprite.play("cima")
		return

@rpc("any_peer", "call_local")
func _set_pode_fugir() -> void:
	pode_fugir = true
	_direcao_y = -1 
	_direcao_x = 0

func _physics_process(delta: float) -> void:
	if multiplayer.is_server() and !_jogavel:
		var direcao = Vector2(_direcao_x, _direcao_y).normalized()
		velocity.y = direcao.y * _velocidade
		velocity.x = direcao.x * _velocidade
		move_and_slide()
		return
	
	if is_multiplayer_authority():
		if _jogavel and ((vivo and pode_fugir) or (!vivo)) :
			var direcao = Vector2(_direcao_x, _direcao_y).normalized()
			velocity.y = direcao.y * _velocidade
			velocity.x = direcao.x * _velocidade
			move_and_slide()
			return
			
		if _jogavel and vivo and !pode_fugir:
			var direcao = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
			velocity = direcao * _velocidade
			move_and_slide()
			position.x = clamp(position.x, 45, 720)
			position.y = clamp(position.y, 55, 490)
			_seleciona_animacao()
		return

func _mover_direcao_aleatoria_x() -> void:
	_direcao_x = [-5, 5].pick_random()

@rpc("any_peer", "call_local")
func morreu() -> void:
	label.text = pontuacao
	label.visible = true
	vivo = false
	_animacao_sprite.play("susto")
	_direcao_x = 0
	_direcao_y = 0

func _on_animated_sprite_2d_animation_finished() -> void:
	if _animacao_sprite.get_animation() == "susto":
		label.visible = false
		_animacao_sprite.play("morte")
		_direcao_y = 1

func _bounce() -> void:
	_direcao_x = _direcao_x * -1
	_seleciona_animacao()
	
func _bounce_y() -> void:
	if !vivo:
		return
	_direcao_y = _direcao_y * -1
	
func _on_tentativa_de_bounce_timeout() -> void:
	if randi() % 100 < 30:
		_bounce()

func _on_timer_pode_fugir_timeout() -> void:
	_set_pode_fugir.rpc()
