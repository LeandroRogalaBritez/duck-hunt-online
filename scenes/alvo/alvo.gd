extends Node2D

var pato_na_mira
@onready var main = $"/root/GameManager"
@onready var audio = $AudioStreamPlayer2D

func _process(delta: float) -> void:
	var _posicao_mouse = get_viewport().get_mouse_position()
	position = _posicao_mouse
	
	if Input.is_action_pressed("atirar"):
		audio.play()
		if pato_na_mira != null and pato_na_mira.vivo:
			pato_na_mira.morreu()

func _on_area_2d_body_entered(body: Node2D) -> void:
	pato_na_mira = body

func _on_area_2d_body_exited(body: Node2D) -> void:
	pato_na_mira = null
