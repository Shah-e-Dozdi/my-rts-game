extends Control

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.2, 0.6, 1.0, 0.15))
	draw_rect(rect, Color(0.3, 0.8, 1.0, 0.8), false, 1.5)
