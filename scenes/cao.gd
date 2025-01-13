extends Node2D

@onready var animation = $AnimationPlayer
@onready var audio_ganhou = $AudioGanhou
@onready var audio_perdeu = $AudioPerdeu

func anima(ganhou: bool) -> void:
	if ganhou:
		animation.play("ganhou")
		audio_ganhou.play()
	else:
		animation.play("perdeu")
		audio_perdeu.play()
