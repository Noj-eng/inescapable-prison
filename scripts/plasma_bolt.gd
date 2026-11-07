extends Node2D
## A plasma bolt from the rifle. Flies straight, hurts the first enemy it
## touches, and fizzles out against walls.

const SPEED := 430.0
const LIFETIME := 1.2
const HEIGHT := 25.0   # drawn at chest height; the node itself sits on the floor

var direction := Vector2.RIGHT
var _age := 0.0


func _ready() -> void:
	var light := preload("res://scripts/fx.gd").make_light(Color(0.75, 0.4, 1.0), 1.0, 0.35)
	light.position = Vector2(0, -HEIGHT)
	add_child(light)


func _physics_process(delta: float) -> void:
	_age += delta
	var flat_dir := Vector2(direction.x, direction.y * 0.5).normalized() if absf(direction.y) > 0.01 else direction
	position += direction * SPEED * delta
	queue_redraw()
	if _age > LIFETIME:
		queue_free()
		return

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var d: Vector2 = enemy.global_position - global_position
		if Vector2(d.x, d.y * 2.0).length() < 14.0 + enemy.hit_radius:
			enemy.take_hit(global_position - flat_dir * 10.0)
			queue_free()
			return

	# Stop at walls, bars and furniture.
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_position
	for hit in get_world_2d().direct_space_state.intersect_point(query, 4):
		if hit.collider is StaticBody2D and not hit.collider.name.begins_with("ContainmentRig"):
			queue_free()
			return


func _draw() -> void:
	var tail := -direction * 14.0
	var lift := Vector2(0, -HEIGHT)
	draw_line(lift + tail, lift, Color(0.7, 0.35, 1.0, 0.5), 6.0)
	draw_line(lift + tail * 0.6, lift, Color("e2c4ff"), 2.5)
	draw_circle(lift, 3.5, Color.WHITE)
