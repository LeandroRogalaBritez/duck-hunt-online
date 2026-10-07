extends Node2D

# Variaveis de cena
@onready var _audio_tiro = $Audio/Tiro
@onready var _audio_recarga = $"Audio/TiroRecarregar"
@onready var _timer_recarga = $TimerRecarga
@onready var _nome_player = $Label

# Variaveis privadas
var _pato_na_mira
var _main

# Variaveis publicas
var pode_atirar = false
var cabou_balas = false

func _enter_tree() -> void:
	if multiplayer.get_unique_id() == name.to_int():
		self.z_index = 999
		_main = get_tree().root.get_node("Main")
		_main.alvo = self

func _ready() -> void:
	set_multiplayer_authority(name.to_int())
	if GameManager.modo_multiplayer:
		_nome_player.text = GameManager.get_nome(name)
		_nome_player.visible = true

func _process(_delta: float) -> void:
	if is_multiplayer_authority():
		position = get_viewport().get_mouse_position()
		
		if Input.is_action_pressed("atirar"):
			if cabou_balas:
				_audio_recarga.play()
				return
			if pode_atirar:
				_main.on_alvo_atirou()
				pode_atirar = false
				_on_alvo_atirou.rpc()
				_timer_recarga.start()
				if _pato_na_mira != null and _pato_na_mira.vivo:
					_pato_na_mira.morreu.rpc()
					_main.on_alvo_matou_pato.rpc()

func _on_area_2d_body_entered(_body: Node2D) -> void:
	if _body.pode_fugir:
		return
	_pato_na_mira = _body

func _on_area_2d_body_exited(_body: Node2D) -> void:
	_pato_na_mira = null
	
@rpc("any_peer", "call_local")
func _on_alvo_atirou() -> void:
	_audio_tiro.play()

func _on_timer_recarga_timeout() -> void:
	_audio_recarga.play()
	await _audio_recarga.finished
	_main.on_alvo_verifica_balas()
