extends Node2D
## The plasma rifle the guard captain drops. Walk over it to pick it up.

signal picked_up

var player: Node2D
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if is_instance_valid(player) and not player.dead:
		var d := player.global_position - global_position
		if Vector2(d.x, d.y * 2.0).length() < 22.0:
			player.has_rifle = true
			picked_up.emit()
			queue_free()


func _draw() -> void:
	var glow := 0.5 + 0.5 * sin(_t * 4.0)
	# glow pool on the floor
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 18.0, Color(0.7, 0.35, 1.0, 0.15 + 0.15 * glow))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var o := Vector2(0, -8 - glow * 3.0)
	draw_line(o + Vector2(-16, 3), o + Vector2(16, -3), Color("15171d"), 7.0)
	draw_line(o + Vector2(-16, 3), o + Vector2(16, -3), Color("3b4150"), 5.0)
	draw_rect(Rect2(o + Vector2(-12, 2), Vector2(5, 6)), Color("3b4150"))  # grip
	for t in [0.45, 0.6, 0.75]:
		draw_circle((o + Vector2(-16, 3)).lerp(o + Vector2(16, -3), t), 2.5, Color("b25cff"))
