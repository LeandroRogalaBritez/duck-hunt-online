extends CharacterBody2D

# Variaveis da cena
@onready var _animacao_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _audio = $Audio/Pato
@onready var _label = $Label
@onready var _auto_bounce = $TentativaDeBounce

# Variaveis Privadas
var _direcao_x: int
var _direcao_y: int = -1
@export var _dash_velocidade: float = 600
var _is_dashing = false
var _pode_executar_dash = true

# Variaveis Publicas
@export var pode_fugir = false 
@export var jogavel: bool
@export var pontuacao = "0"
var vivo: bool = true
@export var velocidade: float = 300.0

func _ready() -> void:
	_dash_velocidade = velocidade * 2
	$TimerPodeFugir.start()
	if multiplayer.is_server():
		if !jogavel:
			_mover_direcao_aleatoria_x()
			_seleciona_animacao()
			_audio.play()
			return
	if jogavel:
		rpc_id(name.to_int(), "_grava_propriedades", jogavel, pontuacao, position, velocidade, _dash_velocidade)
		_auto_bounce.stop()

@rpc("any_peer", "call_local")
func _perdeu_conexao_jogavel() -> void:
	set_multiplayer_authority(1)
	jogavel = false
	_mover_direcao_aleatoria_x()
	_seleciona_animacao()
	$Nome.visible = false

@rpc("any_peer", "call_local")
func _grava_autoridade() -> void:
	set_multiplayer_authority(name.to_int())

@rpc("any_peer", "call_local", "unreliable")
func _grava_propriedades(_jogavel, _pontuacao, _position, _velocidade, _dash_velocidade_nova) -> void:
	_grava_autoridade.rpc()
	self.jogavel = _jogavel
	self.pontuacao = _pontuacao
	self.position = _position
	self.velocidade = _velocidade
	self._dash_velocidade = _dash_velocidade_nova
	if jogavel:
		$Nome.text = GameManager.get_nome(str(multiplayer.get_unique_id()))
		$Nome.visible = true
	
func _seleciona_animacao() -> void:
	if jogavel:
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

@rpc("any_peer", "call_local")
func _set_pode_fugir() -> void:
	pode_fugir = true
	_direcao_y = -1 
	_direcao_x = 0

func _physics_process(_delta: float) -> void:
	if multiplayer.is_server() and !jogavel:
		var _direcao = Vector2(_direcao_x, _direcao_y).normalized()
		velocity.y = _direcao.y * velocidade
		velocity.x = _direcao.x * velocidade
		move_and_slide()
		return
	
	if is_multiplayer_authority():
		if jogavel and ((vivo and pode_fugir) or (!vivo)) :
			var _direcao = Vector2(_direcao_x, _direcao_y).normalized()
			velocity.y = _direcao.y * velocidade
			velocity.x = _direcao.x * velocidade
			move_and_slide()
			return
			
		if jogavel and vivo and !pode_fugir:
			var _direcao = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
			#print("_DASH ", _dash_velocidade)
			print("VEL ", velocidade)
			if !_is_dashing:
				velocity = _direcao * velocidade
			
			move_and_slide()
			position.x = clamp(position.x, 45, 720)
			position.y = clamp(position.y, 55, 490)
			_seleciona_animacao()
			
			if Input.is_action_just_pressed("ui_accept") and _direcao.length() > 0 and not _is_dashing and _pode_executar_dash:
				_iniciar_dash(_direcao)

func _iniciar_dash(_direcao):
	_pode_executar_dash = false
	_is_dashing = true
	velocity = _direcao * _dash_velocidade
	$TimerTempoDash.start()
	
func _mover_direcao_aleatoria_x() -> void:
	_direcao_x = [-5, 5].pick_random()

@rpc("any_peer", "call_local")
func morreu() -> void:
	_label.text = pontuacao
	_label.visible = true
	vivo = false
	_animacao_sprite.play("susto")
	_direcao_x = 0
	_direcao_y = 0

func _on_animated_sprite_2d_animation_finished() -> void:
	if _animacao_sprite.get_animation() == "susto":
		_label.visible = false
		_animacao_sprite.play("morte")
		_direcao_y = 1

func bounce_x() -> void:
	_direcao_x = _direcao_x * -1
	_seleciona_animacao()
	
func bounce_y() -> void:
	if !vivo:
		return
	_direcao_y = _direcao_y * -1
	
func _on_tentativa_de_bounce_timeout() -> void:
	if randi() % 100 < 30:
		bounce_x()

func _on_timer_pode_fugir_timeout() -> void:
	_set_pode_fugir.rpc()


func _on_timer_tempo_dash_timeout() -> void:
	_is_dashing = false
	$TimerDashResfriamento.start()

func _on_timer_dash_resfriamento_timeout() -> void:
	_pode_executar_dash = true
