extends Node2D
## Rotates the node around to face the direction of the mouse cursor

func _process(delta: float) -> void:
	var cursor_position = get_global_mouse_position()
	var rotation_angle = global_position.angle_to_point(cursor_position)
	rotation = rotation_angle
