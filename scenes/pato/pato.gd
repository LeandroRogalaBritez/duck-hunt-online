extends CharacterBody2D

var _velocidade: float = 300.0
var _direcao_x: int
var _direcao_y: int = -1
@onready var _animacao_sprite: AnimatedSprite2D = $AnimatedSprite2D
var vivo: bool = true
@onready var audio = $Audio/Pato
@onready var label = $Label
var pontuacao
var quantidade_bounce_top

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
	var direcao = Vector2(_direcao_x, _direcao_y).normalized()
	velocity.y = direcao.y * _velocidade
	velocity.x = direcao.x * _velocidade
	
	move_and_slide()

func _mover_direcao_aleatoria_x() -> void:
	_direcao_x = [-5, 5].pick_random()

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
