extends Node2D

# Compatibility cursor only. Authoritative pulses belong to InvasionMatch.
func _process(_delta: float) -> void:
	position = get_global_mouse_position()
	queue_redraw()

func _draw() -> void:
	draw_arc(Vector2.ZERO, 15, 0, TAU, 32, Color("67e6e0"), 2)
