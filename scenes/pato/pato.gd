extends CharacterBody2D

var _velocidade: float = 150.0
var _direcao_x: int
var _direcao_y: int = -1
@onready var _animacao_sprite: AnimatedSprite2D = $AnimatedSprite2D
var vivo: bool = true
@onready var audio = $AudioStreamPlayer2D

signal pato_morreu

func _ready() -> void:
	_mover_direcao_aleatoria_x()
	_seleciona_animacao()
	audio.play()
	
func _seleciona_animacao() -> void:
	if _direcao_x < 0:
		_animacao_sprite.flip_h = true
		_animacao_sprite.play("cima")
		return
	elif _direcao_x > 0:
		_animacao_sprite.flip_h = false
		_animacao_sprite.play("cima")
		return

func _physics_process(delta: float) -> void:
	velocity.y = _direcao_y * _velocidade
	velocity.x = _direcao_x * _velocidade
	move_and_slide()

func _mover_direcao_aleatoria_x() -> void:
	_direcao_x = [-1, 1].pick_random()

func morreu() -> void:
	vivo = false
	_animacao_sprite.play("susto")
	_direcao_x = 0
	_direcao_y = 0
	pato_morreu.emit()

func _on_animated_sprite_2d_animation_finished() -> void:
	if _animacao_sprite.get_animation() == "susto":
		_animacao_sprite.play("morte")
		_direcao_y = 1

func _bounce() -> void:
	_direcao_x = _direcao_x * -1
	_seleciona_animacao()
