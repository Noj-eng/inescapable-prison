extends Node2D
## A glowing scrap of XP dropped by a knocked-out enemy. It bobs on the floor
## until the villain comes close, then flies to them.

var value := 1
var player: Node2D
var _t := randf() * 3.0
var _speed := 0.0
var _scatter := Vector2.ZERO


func _ready() -> void:
	material = preload("res://scripts/fx.gd").unshaded_additive()
	_scatter = Vector2(randf_range(-1, 1), randf_range(-0.5, 0.5)) * 60.0


func _process(delta: float) -> void:
	_t += delta
	position += _scatter * delta
	_scatter = _scatter.move_toward(Vector2.ZERO, 120.0 * delta)
	queue_redraw()
	if not is_instance_valid(player) or player.dead:
		return
	var d := player.global_position - global_position
	if d.length() < player.pickup_radius() or _speed > 0.0:
		_speed = minf(_speed + 900.0 * delta, 520.0)
		global_position += d.normalized() * minf(_speed * delta, d.length())
		if d.length() < 8.0:
			player.add_xp(value)
			queue_free()


func _draw() -> void:
	var y := -6.0 - absf(sin(_t * 3.0)) * 3.0
	var r := 2.5 + value * 0.4
	draw_circle(Vector2(0, y), r * 2.6, Color(0.2, 1.0, 0.7, 0.18))
	draw_circle(Vector2(0, y), r, Color(0.5, 1.0, 0.8))
	draw_circle(Vector2(0, y), r * 0.45, Color.WHITE)
