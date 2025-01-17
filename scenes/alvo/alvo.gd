extends Node2D

var pato_na_mira
@onready var main = $"/root/GameManager"
@onready var audio = $Audio/Tiro
@onready var audio_recarga = $"../Audio/TiroRecarregar"
@onready var timer_recarga = $TimerRecarga
var pode_atirar = false
var cabou_balas = false

signal atirou
signal verifica_balas
signal matou_pato

func _process(delta: float) -> void:
	var _posicao_mouse = get_viewport().get_mouse_position()
	position = _posicao_mouse
	
	if Input.is_action_pressed("atirar"):
		if cabou_balas:
			audio_recarga.play()
			return
		if pode_atirar:
			atirou.emit()
			pode_atirar = false
			audio.play()
			timer_recarga.start()
			if pato_na_mira != null and pato_na_mira.vivo:
				pato_na_mira.morreu()
				matou_pato.emit()
		

func _on_area_2d_body_entered(body: Node2D) -> void:
	pato_na_mira = body

func _on_area_2d_body_exited(body: Node2D) -> void:
	pato_na_mira = null

func _on_timer_recarga_timeout() -> void:
	audio_recarga.play()
	await audio_recarga.finished
	verifica_balas.emit()
