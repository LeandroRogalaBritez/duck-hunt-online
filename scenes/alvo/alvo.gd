extends Node2D

var pato_na_mira
@onready var audio = $Audio/Tiro
@onready var audio_recarga = $"Audio/TiroRecarregar"
@onready var timer_recarga = $TimerRecarga
var pode_atirar = false
var cabou_balas = false
@onready var label = $Label
var main

func _enter_tree() -> void:
	if multiplayer.get_unique_id() == name.to_int():
		main = get_tree().root.get_node("Main")
		self.z_index = 999
		main.alvo = self

func _ready() -> void:
	set_multiplayer_authority(name.to_int())
	label.text = GameManager._get_nome(name)

func _process(delta: float) -> void:
	if is_multiplayer_authority():
		var _posicao_mouse = get_viewport().get_mouse_position()
		position = _posicao_mouse
		
		if Input.is_action_pressed("atirar"):
			if cabou_balas:
				audio_recarga.play()
				return
			if pode_atirar:
				main._on_alvo_atirou()
				pode_atirar = false
				_on_alvo_atirou.rpc()
				timer_recarga.start()
				if pato_na_mira != null and pato_na_mira.vivo:
					pato_na_mira.morreu.rpc()
					main._on_alvo_matou_pato.rpc()

func _on_area_2d_body_entered(body: Node2D) -> void:
	pato_na_mira = body

func _on_area_2d_body_exited(body: Node2D) -> void:
	pato_na_mira = null
	
@rpc("any_peer", "call_local")
func _on_alvo_atirou() -> void:
	audio.play()

func _on_timer_recarga_timeout() -> void:
	audio_recarga.play()
	await audio_recarga.finished
	main._on_alvo_verifica_balas()
