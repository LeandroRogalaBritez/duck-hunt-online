extends Control

signal play_requested
signal restart_requested
signal role_requested(role: int)
signal lobby_requested
signal delay_changed(value: float)
signal effects_changed(value: float)
signal ambience_changed(value: float)
signal motion_changed(value: bool)

const CYAN := Color("67e6e0")
const AMBER := Color("ffb866")
const ICON := preload("res://assets/alien/art/game_icon.png")
var _overlay: PanelContainer
var _title: Label
var _body: Label
var _start: Button
var _agent: Button
var _et: Button
var _restart: Button
var _wave: Label
var _time: Label
var _points: Label
var _resource: Label
var _captures: Label
var _wins: Label
var _message: Label
var _delay_label: Label
var _delay: HSlider


func _ready() -> void:
	_build()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 770, 120), Color("11162b"))
	draw_texture_rect(ICON, Rect2(24, 12, 40, 40), false)
	draw_string(ThemeDB.fallback_font, Vector2(78, 42), "ALERTA: TERRA", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("f3f0e8"))
	draw_string(ThemeDB.fallback_font, Vector2(476, 37), "DEFESA TERRESTRE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, CYAN)
	draw_rect(Rect2(0, 576, 770, 144), Color("11162b"))


func refresh(wave: int, points: int, charges: int, captures: int, defenders: int, invaders: int, seconds: float, agent: bool, dash: float, message: String) -> void:
	_wave.text = "ONDA %d / 5" % wave
	_time.text = "DESEMBARQUE: " + ("%.1f s" % maxf(seconds, 0) if seconds >= 0 else "--")
	_points.text = "%04d PONTOS" % points
	_resource.text = "CARGAS: %d" % charges if agent else "IMPULSO: " + ("PRONTO" if dash <= 0 else "%.1f s" % dash)
	if not agent and dash == -2.0:
		_resource.text = "CONTIDO · observe seu aliado"
	elif not agent and dash == -3.0:
		_resource.text = "DESEMBARCADO"
	_captures.text = "CONTIDOS %d / 2" % captures
	_wins.text = "DEFESA %d × %d ETs" % [defenders, invaders]
	_message.text = message
	_message.modulate = CYAN if captures == 2 else AMBER


func show_ready(agent: bool, networked: bool, host: bool) -> void:
	_agent.visible = not networked
	_et.visible = not networked
	_delay.visible = not networked
	_delay_label.visible = not networked
	_agent.disabled = agent
	_et.disabled = not agent
	_restart.disabled = networked and not host
	_title.text = "A TERRA ESTÁ SOB INVASÃO"
	if agent:
		_body.text = "Você é o AGENTE.\nCapture os dois ETs antes que desembarquem.\n\nMouse para mirar · Clique para disparar\n3 cargas por onda. Antecipe a trajetória!\nO círculo marca onde o pulso vai acertar."
	else:
		_body.text = "Você é o ET marcado com VOCÊ.\nEsquive até o corredor de desembarque abrir.\n\nWASD / Setas para mover · Espaço para impulso\nO impulso recarrega em 2 segundos.\nSaia do círculo anunciado pelo agente!"
	_start.text = "INICIAR DEFESA" if agent else "INICIAR INVASÃO"
	_start.disabled = networked
	_overlay.show()


func set_ready(can_start: bool) -> void:
	_start.disabled = not can_start
	_start.text = "INICIAR DEFESA" if can_start else "AGUARDANDO O ANFITRIÃO"


func show_pause(visible_now: bool, networked: bool) -> void:
	_overlay.visible = visible_now
	_title.text = "OPÇÕES" if networked else "PAUSA"
	_body.text = "A partida continua enquanto este menu está aberto.\nEsc para fechar." if networked else "Esc para continuar. R reinicia.\nExperimente o outro papel com Tab."
	_start.text = "CONTINUAR"
	_start.disabled = false


func show_report(defenders: int, invaders: int, points: int, waves: int, agent: bool, can_restart: bool) -> void:
	var won := defenders > invaders if agent else invaders > defenders
	_title.text = "CIDADE PROTEGIDA" if defenders > invaders else "INVASORES DESEMBARCARAM"
	_body.text = "%s\nDefesa %d × %d Invasores\n%d pontos em %d ondas\n\nVolte ao lobby para uma nova equipe." % ["Você venceu!" if won else "Tente outra vez!", defenders, invaders, points, waves]
	_start.text = "JOGAR NOVAMENTE" if can_restart else "AGUARDANDO O ANFITRIÃO"
	_start.disabled = not can_restart
	_overlay.show()


func hide_overlay() -> void:
	_overlay.hide()


func _build() -> void:
	_agent = _button("Jogar como Agente", Rect2(24, 67, 216, 42), func() -> void: role_requested.emit(0))
	_et = _button("Jogar como ET", Rect2(250, 67, 190, 42), func() -> void: role_requested.emit(1))
	_restart = _button("Reiniciar", Rect2(450, 67, 135, 42), func() -> void: restart_requested.emit())
	_button("Lobby", Rect2(595, 67, 151, 42), func() -> void: lobby_requested.emit())
	_message = _label(Vector2(24, 121), 18, AMBER)
	_wave = _label(Vector2(24, 585), 19)
	_time = _label(Vector2(215, 585), 17, AMBER)
	_points = _label(Vector2(550, 585), 18)
	_resource = _label(Vector2(24, 616), 15, CYAN)
	_captures = _label(Vector2(280, 616), 15)
	_wins = _label(Vector2(535, 616), 15)
	_delay_label = _label(Vector2(24, 647), 14)
	_delay_label.text = "Pulso: 150 ms"
	_delay = HSlider.new()
	_delay.position = Vector2(150, 648)
	_delay.size = Vector2(130, 24)
	_delay.min_value = 0.0
	_delay.max_value = 0.3
	_delay.step = 0.01
	_delay.value = 0.15
	_delay.value_changed.connect(func(value: float) -> void: _delay_label.text = "Pulso: %.0f ms" % (value * 1000); delay_changed.emit(value))
	add_child(_delay)
	_volume("Efeitos", Vector2(311, 647), func(value: float) -> void: effects_changed.emit(value))
	_volume("Ambiente", Vector2(533, 647), func(value: float) -> void: ambience_changed.emit(value))
	var motion := CheckBox.new()
	motion.position = Vector2(24, 677)
	motion.text = "Movimento reduzido"
	motion.add_theme_font_size_override("font_size", 13)
	motion.toggled.connect(func(value: bool) -> void: motion_changed.emit(value))
	add_child(motion)
	var hint := _label(Vector2(327, 686), 13, Color("9caec8"))
	hint.text = "R: reiniciar · Tab: papel · Esc: opções"
	_overlay = PanelContainer.new()
	_overlay.position = Vector2(107, 211)
	_overlay.size = Vector2(556, 299)
	add_child(_overlay)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	_overlay.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 23)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_theme_font_size_override("font_size", 17)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_body)
	_start = Button.new()
	_start.pressed.connect(func() -> void: play_requested.emit())
	box.add_child(_start)


func _volume(text: String, point: Vector2, action: Callable) -> void:
	var label := _label(point, 14)
	label.text = text
	var slider := HSlider.new()
	slider.position = point + Vector2(78, 0)
	slider.size = Vector2(125, 24)
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.05
	slider.value = 1
	slider.value_changed.connect(action)
	add_child(slider)


func _label(point: Vector2, font_size: int, color: Color = Color("f3f0e8")) -> Label:
	var label := Label.new()
	label.position = point
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _button(text: String, rect: Rect2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.pressed.connect(action)
	add_child(button)
	return button
