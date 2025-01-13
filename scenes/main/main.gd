extends Node2D

@onready var spaw_pato = $SpawPato
@onready var spaw_pato2 = $SpawPato2
@onready var spaw_pato3 = $SpawPato3
@onready var patos = $Patos
@onready var cao = $Cao
@onready var timer_inicia_round = $TimerIniciaRound
@onready var timer_finaliza_round = $FinalizaRound
@onready var audio_round = $AudioRound
var cena_pato = preload("res://scenes/pato/pato.tscn")
var nivel = 1
var multiplicador_velocidade = 1
var patos_gerados = 0

func _ready() -> void:
	_inicia_round()
	
func _inicia_round() -> void:
	cao.visible = false
	timer_inicia_round.start()
	audio_round.play()

func _process(delta: float) -> void:
	pass

func gera_patos(_quantidade: float) -> void:
	patos_gerados = _quantidade
	for numero in _quantidade:
		var _pato = cena_pato.instantiate()
		_pato.pato_morreu.connect(_on_pato_morreu)
		_pato.position = [spaw_pato, spaw_pato2, spaw_pato3].pick_random().position
		patos.add_child(_pato)

func _on_topo_body_entered(body: Node2D) -> void:
	_finaliza_round()
	body.queue_free()

func _on_lados_body_entered(body: Node2D) -> void:
	body._bounce()

func _on_pato_morreu() -> void:
	patos_gerados -= 1

func _finaliza_round() -> void:
	cao.visible = true
	cao.anima(patos_gerados <= 0)
	timer_finaliza_round.start()

func _on_baixo_body_entered(body: Node2D) -> void:
	_finaliza_round()
	body.queue_free()

func _on_timer_inicia_round_timeout() -> void:
	gera_patos(nivel)

func _on_finaliza_round_timeout() -> void:
	_inicia_round()
