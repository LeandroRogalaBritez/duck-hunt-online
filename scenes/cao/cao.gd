extends Node2D

# Variaveis da cena
@onready var _animation = $AnimationPlayer
@onready var _audio_ganhou = $Audio/Ganhou
@onready var _audio_perdeu = $Audio/Perdeu
@onready var _audio_entrada = $Audio/Entrada
@onready var _animated_sprite = $AnimatedSprite2D
@onready var _audio_latida = $Audio/Latida
@onready var _timer_latida = $TempoLatida

# Variaveis Privadas
var _direcao: Vector2 = Vector2.RIGHT
var _speed = 100

# Variaveis Publicas
var pode_pular = false

# Sinais
signal cachorro_pulou

func _ready() -> void:
	_timer_latida.start()
	_audio_entrada.play()

func anima_fim_round(_ganhou: bool) -> void:
	if _ganhou:
		_animation.play("ganhou")
		_play_audio_ganhou.rpc()
		return
	_animation.play("perdeu")
	_play_audio_perdeu.rpc()

@rpc("any_peer", "call_local")
func _play_audio_ganhou() -> void:
	_audio_ganhou.play()

@rpc("any_peer", "call_local")
func _play_audio_perdeu() -> void:
	_audio_perdeu.play()

func _process(_delta: float) -> void:
	if multiplayer.is_server():
		position += _direcao * _speed * _delta
		
		if position.x <= 60 or position.x >= get_viewport().size.x - 80:
			_direcao *= -1
			_animated_sprite.flip_h = !_animated_sprite.flip_h
		
		if position.x > 380 and position.x < 390 and pode_pular:
			_animated_sprite.stop()
			_animation.play("pulando")
			set_process(false)

func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	if _anim_name == "pulando":
		cachorro_pulou.emit()
		_on_cachorrou_pulou.rpc()
		
@rpc("any_peer", "call_local")
func _on_cachorrou_pulou() -> void:
	_audio_entrada.stop()
	_timer_latida.stop()

func _on_tempo_latida_timeout() -> void:
	_timer_latida.start()
	_audio_latida.play()
