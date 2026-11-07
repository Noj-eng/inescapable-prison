extends CharacterBody2D
## The villain. Walk with WASD or the arrow keys.
## Starts suspended in the containment rig; the first key press releases them.
## Arms and shins stay locked in heavy mechanical casings, so they move slowly.
## Drawn with simple shapes for now: orange jumpsuit, gunmetal restraints,
## glowing cyan seams, and yellow eyes.

signal released

const SPEED := 120.0
const HOVER := 16.0  # how high the rig holds the villain off the floor

const SUIT := Color("ee7a2b")
const SUIT_DARK := Color("b85a1c")
const CASING := Color("5a6272")
const CASING_DARK := Color("2f3540")
const CASING_LIGHT := Color("8790a3")
const SEAM := Color("5ff3ff")
const SKIN := Color("9fb0a4")

var held := true
var hover := HOVER
var facing := 1.0      # 1 = facing right, -1 = facing left
var walk_time := 0.0   # drives the walking stride
var _t := 0.0


func _ready() -> void:
	# A small circle at the villain's feet is what bumps into walls.
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)

	var cam := Camera2D.new()
	cam.zoom = Vector2(1.8, 1.8)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	add_child(cam)


func _read_input() -> Vector2:
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y += 1
	return input.normalized()


func _physics_process(delta: float) -> void:
	_t += delta
	var input := _read_input()

	if held:
		if input != Vector2.ZERO and _t > 0.5:
			_release()
		queue_redraw()
		return

	# Squash vertical movement by half so it matches the isometric floor.
	velocity = Vector2(input.x, input.y * 0.5).normalized() * SPEED if input != Vector2.ZERO else Vector2.ZERO
	move_and_slide()

	if input.x != 0:
		facing = sign(input.x)
	if input != Vector2.ZERO:
		walk_time += delta * 9.0
	else:
		walk_time = 0.0
	queue_redraw()


func _release() -> void:
	held = false
	var tween := create_tween()
	tween.tween_property(self, "hover", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	released.emit()


func _draw() -> void:
	# shadow (shrinks while floating)
	var shadow_scale := 1.0 - hover / HOVER * 0.35
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(shadow_scale, shadow_scale * 0.45))
	draw_circle(Vector2.ZERO, 13.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if held:
		_draw_held()
	else:
		_draw_walking()


## Suspended in the rig: arms spread wide inside heavy casings, legs locked together.
func _draw_held() -> void:
	var lift := -hover + sin(_t * 2.0) * 1.5
	var o := Vector2(0, lift)

	# legs locked together in shin casings
	_leg(o + Vector2(-3, 0), 0.0)
	_leg(o + Vector2(3, 0), 0.0)
	_torso(o)
	# arms straight out, fully encased, reaching to the rig's clamps
	for side: int in [-1, 1]:
		var shoulder := o + Vector2(9 * side, -33)
		var hand := o + Vector2(38 * side, -56 - lift)  # hands stay pinned in the clamps
		_casing(shoulder, hand, 12.0)
	_head(o + Vector2(0, 1), 1.0)


## Free to walk, but the casings stay on.
func _draw_walking() -> void:
	var o := Vector2(0, -hover - absf(sin(walk_time)) * 1.5)
	var stride := sin(walk_time) * 3.0
	_leg(o + Vector2(-4, 0), stride)
	_leg(o + Vector2(4, 0), -stride)
	_torso(o)
	for side: int in [-1, 1]:
		var swing := -stride * side * 0.8
		var shoulder := o + Vector2(10 * side, -32)
		var hand := o + Vector2(13 * side + swing, -14)
		_casing(shoulder, hand, 11.0)
	_head(o, facing)


func _leg(foot: Vector2, stride: float) -> void:
	var hip := foot + Vector2(0, -18)
	var knee := foot + Vector2(stride, -11)
	draw_line(hip, knee, SUIT_DARK, 5.0)
	# shin casing: chunky block with a glowing band
	var shin := Rect2(knee + Vector2(-5, -1), Vector2(10, 13))
	draw_rect(shin.grow(1), CASING_DARK)
	draw_rect(shin, CASING)
	draw_line(shin.position + Vector2(0, 5), shin.position + Vector2(10, 5), SEAM, 1.5)


func _torso(o: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([
		o + Vector2(-11, -35), o + Vector2(11, -35), o + Vector2(7, -16), o + Vector2(-7, -16)
	]), SUIT)
	draw_line(o + Vector2(0, -34), o + Vector2(0, -17), SUIT_DARK, 1.0)
	# prisoner number patch
	draw_rect(Rect2(o + Vector2(-8, -31), Vector2(6, 4)), Color("f5efe0"))
	# restraint belt
	draw_rect(Rect2(o + Vector2(-8, -19), Vector2(16, 4)), CASING_DARK)
	draw_rect(Rect2(o + Vector2(-2, -19), Vector2(4, 4)), SEAM)


## A heavy mechanical sleeve from a to b, with a big cuff block at the end.
func _casing(a: Vector2, b: Vector2, thickness: float) -> void:
	draw_line(a, b, CASING_DARK, thickness + 2.0)
	draw_line(a, b, CASING, thickness)
	draw_line(a + Vector2(0, -thickness * 0.3), b + Vector2(0, -thickness * 0.3), CASING_LIGHT, 1.5)
	# glowing seams along the sleeve
	for t in [0.35, 0.7]:
		var p: Vector2 = a.lerp(b, t)
		var n := (b - a).orthogonal().normalized() * thickness * 0.5
		draw_line(p - n, p + n, SEAM, 1.5)
	# fist-sized cuff block
	var cuff := Rect2(b - Vector2(7, 7), Vector2(14, 14))
	draw_rect(cuff.grow(1), CASING_DARK)
	draw_rect(cuff, CASING)
	draw_circle(b, 2.0, SEAM)


func _head(o: Vector2, f: float) -> void:
	# restraint collar
	draw_rect(Rect2(o + Vector2(-7, -39), Vector2(14, 5)), CASING_DARK)
	draw_rect(Rect2(o + Vector2(-6, -38), Vector2(12, 3)), CASING)
	draw_circle(o + Vector2(0, -36.5), 1.2, SEAM)
	var head := o + Vector2(0, -45)
	draw_circle(head, 7.0, SKIN)
	# slick black hair with a widow's peak
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-7, -1), head + Vector2(-6, -6), head + Vector2(0, -8),
		head + Vector2(6, -6), head + Vector2(7, -1), head + Vector2(0, -3)
	]), Color("16141c"))
	# glowing eyes (looking straight ahead when f is 0)
	var ex := 2.5 * f
	draw_circle(head + Vector2(ex - 2.0, 1), 1.3, Color("ffd23f"))
	draw_circle(head + Vector2(ex + 2.0, 1), 1.3, Color("ffd23f"))
