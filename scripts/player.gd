extends CharacterBody2D
## The villain. Walk with WASD or the arrow keys.
## Drawn with simple shapes for now: orange jumpsuit, purple cape, glowing eyes.

const SPEED := 150.0

var facing := 1.0      # 1 = facing right, -1 = facing left
var walk_time := 0.0   # drives the little walking bob


func _ready() -> void:
	# A small circle at the villain's feet is what bumps into walls.
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)

	var cam := Camera2D.new()
	cam.zoom = Vector2(1.6, 1.6)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	add_child(cam)


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y += 1
	input = input.normalized()
	# Squash vertical movement by half so it matches the isometric floor.
	velocity = Vector2(input.x, input.y * 0.5).normalized() * SPEED if input != Vector2.ZERO else Vector2.ZERO
	move_and_slide()

	if input.x != 0:
		facing = sign(input.x)
	if input != Vector2.ZERO:
		walk_time += delta * 12.0
	else:
		walk_time = 0.0
	queue_redraw()


func _draw() -> void:
	var bob := -absf(sin(walk_time)) * 2.0
	var stride := sin(walk_time) * 3.0
	var f := facing

	# shadow
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# legs
	draw_line(Vector2(-3, -10), Vector2(-3 + stride, 0), Color("c4561f"), 4.0)
	draw_line(Vector2(3, -10), Vector2(3 - stride, 0), Color("c4561f"), 4.0)

	# cape (behind the body, flaring to the back)
	var cape := PackedVector2Array([
		Vector2(-6 * f, -30 + bob), Vector2(6 * f, -30 + bob),
		Vector2(-2 * f, -6 + bob), Vector2(-13 * f, -4 + bob),
	])
	draw_colored_polygon(cape, Color("5a2a82"))

	# jumpsuit body
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -30 + bob), Vector2(7, -30 + bob), Vector2(6, -10 + bob), Vector2(-6, -10 + bob)
	]), Color("ee7a2b"))
	# prisoner number patch
	draw_rect(Rect2(Vector2(-3 + 1 * f, -25 + bob), Vector2(6, 4)), Color("f5efe0"))

	# high collar
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9, -36 + bob), Vector2(-5, -29 + bob), Vector2(5, -29 + bob), Vector2(9, -36 + bob), Vector2(0, -31 + bob)
	]), Color("7a3aa8"))

	# head
	var head := Vector2(0, -38 + bob)
	draw_circle(head, 7.0, Color("9fb0a4"))
	# slick black hair with a widow's peak
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-7, -1), head + Vector2(-6, -6), head + Vector2(0, -8),
		head + Vector2(6, -6), head + Vector2(7, -1), head + Vector2(0, -3)
	]), Color("16141c"))
	# glowing eyes
	draw_circle(head + Vector2(2.5 * f, 1), 1.4, Color("ffd23f"))
	draw_circle(head + Vector2(5.5 * f, 1), 1.2, Color("ffd23f"))
