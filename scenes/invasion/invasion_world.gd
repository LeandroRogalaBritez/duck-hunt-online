extends Node2D

const SKY := preload("res://assets/alien/art/city_night.png")
const SHIP := preload("res://assets/alien/art/mothership.png")
const IDLE_AGENTS := preload("res://assets/alien/art/agents_idle.png")
const PRESENT := preload("res://assets/alien/art/agents_present.tres")
const CYAN := Color("67e6e0")
const AMBER := Color("ffb866")
var landing := false
var presentation := false
var contained := false
var presentation_age := 0.0
var reduced_motion := false
var clock := 0.0


func _process(delta: float) -> void:
	clock += delta
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(SKY, Rect2(1, 0, 768, 576), false)
	_ship(Vector2(385, 169), 1.4)
	_ship(Vector2(97, 224), 0.6)
	_ship(Vector2(681, 199), 0.75)
	draw_rect(Rect2(0, 544, 770, 32), Color("151d30"))
	draw_rect(Rect2(66, 532, 125, 12), Color("394764"))
	draw_line(Vector2(74, 532), Vector2(182, 532), CYAN, 3)
	draw_string(ThemeDB.fallback_font, Vector2(65, 567), "CONTENÇÃO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, CYAN)
	var corridor := AMBER if landing else Color("505f89")
	for x in [490, 585]:
		draw_arc(Vector2(x, 533), 34, PI, TAU, 24, corridor, 2)
		if landing:
			for i in 3:
				var y := 448.0 + fmod(clock * 80 + i * 27, 78)
				draw_polyline(PackedVector2Array([Vector2(x - 10, y), Vector2(x, y + 8), Vector2(x + 10, y)]), AMBER, 2)
	draw_string(ThemeDB.fallback_font, Vector2(460, 567), "DESEMBARQUE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, corridor)
	if presentation:
		var texture: Texture2D = IDLE_AGENTS
		if contained:
			var frame := 4 if reduced_motion else clampi(int(maxf(presentation_age - 0.3, 0) * 5), 0, 4)
			texture = PRESENT.get_frame_texture(&"present", frame)
		var arrival := 1.0 if reduced_motion else smoothstep(0, 0.4, presentation_age)
		draw_texture_rect(texture, Rect2(lerpf(-290, 241, arrival), 317, 288, 224), false)
		if not contained:
			draw_line(Vector2(683, 541), Vector2(683, 491), AMBER, 3)
			draw_colored_polygon(PackedVector2Array([Vector2(683, 491), Vector2(712, 502), Vector2(683, 511)]), AMBER)


func _ship(center: Vector2, size: float) -> void:
	var bob := 0.0 if reduced_motion else sin(clock * 0.8) * 3
	draw_texture_rect(SHIP, Rect2(center + Vector2(-64, -28) * size + Vector2(0, bob), Vector2(128, 56) * size), false)
