extends Node2D

@onready var animation = $AnimationPlayer
@onready var audio_ganhou = $Audio/Ganhou
@onready var audio_perdeu = $Audio/Perdeu
@onready var audio_entrada = $Audio/Entrada
@onready var animated_sprite = $AnimatedSprite2D
@onready var audio_latida = $Audio/Latida
@onready var timer_latida = $TempoLatida

var direcao: Vector2 = Vector2.RIGHT
var speed = 100

signal cachorro_pulou

var pode_pular = false

func _ready() -> void:
	timer_latida.start()
	audio_entrada.play()

func anima(ganhou: bool) -> void:
	if ganhou:
		animation.play("ganhou")
		_audio_ganhou.rpc()
	else:
		animation.play("perdeu")
		_audio_perdeu.rpc()

@rpc("any_peer", "call_local")
func _audio_ganhou() -> void:
	audio_perdeu.play()

@rpc("any_peer", "call_local")
func _audio_perdeu() -> void:
	audio_perdeu.play()

func _process(delta: float) -> void:
	if multiplayer.is_server():
		position += direcao * speed * delta
		
		if position.x <= 60 or position.x >= get_viewport().size.x - 80:
			direcao *= -1
			animated_sprite.flip_h = !animated_sprite.flip_h
		
		if position.x > 380 and position.x < 390 and pode_pular:
			animated_sprite.stop()
			animation.play("pulando")
			set_process(false)

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "pulando":
		cachorro_pulou.emit()
		_on_cachorrou_pulou.rpc()
		
@rpc("any_peer", "call_local")
func _on_cachorrou_pulou() -> void:
	audio_entrada.stop()
	timer_latida.stop()

func _on_tempo_latida_timeout() -> void:
	timer_latida.start()
	audio_latida.play()
