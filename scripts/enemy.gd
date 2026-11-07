extends CharacterBody2D
const FX := preload("res://scripts/fx.gd")
## A prison guard or a security robot. Chases the villain and shoves them
## on contact. Knock it out with casing slams.

signal defeated

var kind := "guard"    # "guard" or "robot"
var target: Node2D
var hp := 3
var speed := 70.0
var damage := 1
var hit_radius := 0.0   # extra reach for attacks aimed at this enemy (big bodies)

var _knock := Vector2.ZERO
var _flash := 0.0
var _touch_cooldown := 0.0
var _walk := 0.0
var _facing := 1.0
var _dead := false
var _t := 0.0
var _detour := Vector2.ZERO   # sidestep direction while walking around an obstacle
var _detour_time := 0.0


func _ready() -> void:
	add_to_group("enemies")
	if kind == "robot":
		hp = 4
		speed = 55.0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)
	if kind == "robot":
		var eye := FX.make_light(Color(1.0, 0.15, 0.1), 0.7, 0.4)
		eye.position = Vector2(0, -40)
		add_child(eye)
	else:
		var baton := FX.make_light(Color(1.0, 0.8, 0.35), 0.35, 0.25)
		baton.position = Vector2(18, -28)
		add_child(baton)
	# drop in from above
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)


func take_hit(from: Vector2) -> void:
	if _dead:
		return
	hp -= 1
	_flash = 0.15
	_knock = (global_position - from).normalized() * 280.0
	if hp <= 0:
		_die()


func _die() -> void:
	_dead = true
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	defeated.emit()
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.6)
	tween.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	_touch_cooldown -= delta
	queue_redraw()

	var move := Vector2.ZERO
	if not _dead and is_instance_valid(target) and not target.dead:
		var to := target.global_position - global_position
		var flat := Vector2(to.x, to.y * 2.0)
		if flat.length() > 16.0:
			var dir := flat.normalized()
			if _detour_time > 0.0:
				_detour_time -= delta
				dir = (dir * 0.3 + _detour).normalized()
			move = Vector2(dir.x, dir.y * 0.5).normalized() * speed
		elif _touch_cooldown <= 0.0:
			target.hit(global_position, damage)
			_touch_cooldown = 1.0
		if absf(to.x) > 2.0:
			_facing = signf(to.x)
	velocity = move + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
	var before := global_position
	move_and_slide()
	# Bumped into furniture and barely moved? Sidestep around it for a moment.
	if move != Vector2.ZERO and _detour_time <= 0.0 and before.distance_to(global_position) < speed * delta * 0.3:
		var side := 1.0 if randf() < 0.5 else -1.0
		_detour = Vector2(move.x, move.y * 2.0).normalized().orthogonal() * side
		_detour_time = 0.6
	_walk = _walk + delta * 10.0 if move != Vector2.ZERO else 0.0


func _draw() -> void:
	FX.draw_character_shadow(self, 11.0, 44.0)
	if _flash > 0.0:
		self_modulate = Color(3, 3, 3)
	else:
		self_modulate = Color.WHITE
	if kind == "robot":
		_draw_robot()
	else:
		_draw_guard()


func _draw_guard() -> void:
	var o := Vector2(0, -absf(sin(_walk)) * 1.5)
	var stride := sin(_walk) * 3.0
	var navy := Color("223152")
	var navy_dark := Color("141e36")
	# legs
	draw_line(o + Vector2(-3, -14), o + Vector2(-3 + stride, 0), navy_dark, 4.0)
	draw_line(o + Vector2(3, -14), o + Vector2(3 - stride, 0), navy_dark, 4.0)
	# body armour
	draw_colored_polygon(PackedVector2Array([
		o + Vector2(-9, -32), o + Vector2(9, -32), o + Vector2(7, -13), o + Vector2(-7, -13)
	]), navy)
	draw_rect(Rect2(o + Vector2(-7, -28), Vector2(14, 8)), Color("2f4470"))
	draw_rect(Rect2(o + Vector2(2 * _facing - 2, -27), Vector2(4, 3)), Color("e0b03a"))  # badge
	# arms and stun baton
	draw_line(o + Vector2(-9, -30), o + Vector2(-11, -16), navy, 4.0)
	var hand := o + Vector2(11 * _facing, -18)
	draw_line(o + Vector2(9 * _facing, -30), hand, navy, 4.0)
	draw_line(hand, hand + Vector2(8 * _facing, -10), Color("1a1a1a"), 3.0)
	draw_circle(hand + Vector2(8 * _facing, -10), 2.0, Color(1.0, 0.85, 0.3, 0.6 + 0.4 * sin(_t * 20.0)))
	# helmet with a red visor
	var head := o + Vector2(0, -38)
	draw_circle(head, 6.5, Color("d1b39a"))
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-7, 0), head + Vector2(-6, -6), head + Vector2(0, -8), head + Vector2(6, -6), head + Vector2(7, 0)
	]), navy_dark)
	draw_rect(Rect2(head + Vector2(-5 + 2 * _facing, -1), Vector2(10, 3)), Color("e84a4a"))


func _draw_robot() -> void:
	var o := Vector2(0, -6 + sin(_t * 3.0) * 2.0)  # hovers
	var steel := Color("6b7280")
	var steel_dark := Color("383d48")
	# thruster glow
	draw_circle(Vector2(0, -2), 4.0, Color(1.0, 0.4, 0.2, 0.5))
	# boxy body
	draw_rect(Rect2(o + Vector2(-11, -30), Vector2(22, 24)), steel_dark)
	draw_rect(Rect2(o + Vector2(-9, -28), Vector2(18, 20)), steel)
	draw_line(o + Vector2(-9, -20), o + Vector2(9, -20), Color("e0b03a"), 2.0)
	# claw arms
	for side: int in [-1, 1]:
		var a := o + Vector2(11 * side, -24)
		var b := a + Vector2(6 * side, 8)
		draw_line(a, b, steel_dark, 4.0)
		draw_line(b, b + Vector2(3 * side, 4), steel_dark, 3.0)
	# sensor head with a sweeping red eye
	draw_rect(Rect2(o + Vector2(-7, -40), Vector2(14, 10)), steel_dark)
	var eye_x := sin(_t * 4.0) * 3.0 + 2.0 * _facing
	draw_circle(o + Vector2(eye_x, -35), 2.5, Color("ff3b3b"))
	draw_circle(o + Vector2(eye_x, -35), 5.0, Color(1, 0.2, 0.2, 0.25))
