extends CharacterBody2D
const FX := preload("res://scripts/fx.gd")
## A prison guard or a security robot. Waits in its area until the villain
## comes close (or hits it), then chases and shoves on contact.
## Knocked out, it drops XP.

signal defeated(at: Vector2, xp: int)

const CHARACTER_SHADER := preload("res://shaders/character.gdshader")
const WAKE_DISTANCE := 260.0

var kind := "guard"    # "guard", "cook" (Mess Hall B squad) or "robot"
var target: Node2D
var hp := 3.0
var active := false
var xp_value := 3
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
var _mat: ShaderMaterial
var _squash := 0.0
var _waypoint := Vector2.INF
var _repath := 0.0
var frozen := 0.0          # seconds left frozen by the Remote Control


func _ready() -> void:
	add_to_group("enemies")
	if kind == "robot":
		hp = 4.0
		speed = 55.0
		xp_value = 4
	elif kind == "cook":
		hp = 3.0
		speed = 78.0
		xp_value = 3
	_mat = ShaderMaterial.new()
	_mat.shader = CHARACTER_SHADER
	_mat.set_shader_parameter("body_height", 44.0)
	_mat.set_shader_parameter("seed", randf() * 100.0)
	material = _mat
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


func take_hit(from: Vector2, damage_taken: float = 1.0, force: float = 280.0) -> void:
	if _dead:
		return
	active = true
	hp -= damage_taken
	_flash = 0.18
	_squash = 0.45
	_knock = (global_position - from).normalized() * force
	if hp <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	defeated.emit(global_position, xp_value)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.6)
	tween.tween_property(self, "_squash", 1.0, 0.4)   # crumple to the floor
	tween.set_parallel(false)
	tween.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	_touch_cooldown -= delta
	queue_redraw()
	# attack and damage animation through the vertex shader
	if not _dead:
		_squash = move_toward(_squash, 0.0, delta * 3.0)
	_mat.set_shader_parameter("hit", clampf(_flash * 6.0, 0.0, 1.0))
	_mat.set_shader_parameter("squash", _squash)
	_mat.set_shader_parameter("lean", _facing * (0.12 if active and not _dead else 0.0) - _knock.x / 900.0)
	var level_root := get_tree().current_scene
	if not active and is_instance_valid(target) and not target.held:
		# wake up when the villain is close *and* actually reachable (not behind a wall)
		var wake := WAKE_DISTANCE * (0.6 if target.has_method("has_relic") and target.has_relic("orange") else 1.0)
		if global_position.distance_to(target.global_position) < wake:
			if not level_root.has_method("path_length") or level_root.path_length(global_position, target.global_position) < 11:
				active = true
	if frozen > 0.0 and not _dead:
		# frozen like a paused TV: tinted blue, not moving, not attacking
		frozen -= delta
		self_modulate = Color(0.55, 0.8, 1.4)
		velocity = _knock
		_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		return
	self_modulate = Color.WHITE
	# route around walls toward the villain
	_repath -= delta
	if active and _repath <= 0.0 and is_instance_valid(target) and level_root.has_method("path_next"):
		_repath = 0.35
		_waypoint = level_root.path_next(global_position, target.global_position)

	var move := Vector2.ZERO
	if active and not _dead and is_instance_valid(target) and not target.dead:
		var to := target.global_position - global_position
		var flat := Vector2(to.x, to.y * 2.0)
		if flat.length() > 16.0:
			var goal := to
			if _waypoint != Vector2.INF and flat.length() > 50.0:
				goal = _waypoint - global_position
			var dir := Vector2(goal.x, goal.y * 2.0).normalized()
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
	if kind == "cook":
		# white kitchen apron over the uniform
		draw_colored_polygon(PackedVector2Array([
			o + Vector2(-6, -27), o + Vector2(6, -27), o + Vector2(7, -12), o + Vector2(-7, -12)
		]), Color("e9e6dc"))
		draw_circle(o + Vector2(2, -18), 1.6, Color(0.55, 0.6, 0.25, 0.6))
	# arms and stun baton (cooks swing a frying pan instead)
	draw_line(o + Vector2(-9, -30), o + Vector2(-11, -16), navy, 4.0)
	var hand := o + Vector2(11 * _facing, -18)
	draw_line(o + Vector2(9 * _facing, -30), hand, navy, 4.0)
	if kind == "cook":
		draw_line(hand, hand + Vector2(6 * _facing, -8), Color("3a3a40"), 2.5)
		draw_circle(hand + Vector2(9 * _facing, -13), 5.0, Color("2a2a30"))
		draw_circle(hand + Vector2(9 * _facing, -13), 3.5, Color("4a4a52"))
	else:
		draw_line(hand, hand + Vector2(8 * _facing, -10), Color("1a1a1a"), 3.0)
		draw_circle(hand + Vector2(8 * _facing, -10), 2.0, Color(1.0, 0.85, 0.3, 0.6 + 0.4 * sin(_t * 20.0)))
	# helmet with a red visor
	var head := o + Vector2(0, -38)
	draw_circle(head, 6.5, Color("d1b39a"))
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-7, 0), head + Vector2(-6, -6), head + Vector2(0, -8), head + Vector2(6, -6), head + Vector2(7, 0)
	]), navy_dark)
	draw_rect(Rect2(head + Vector2(-5 + 2 * _facing, -1), Vector2(10, 3)), Color("e84a4a"))
	if kind == "cook":
		# a hairnet over the helmet, regulations are regulations
		draw_arc(head + Vector2(0, -2), 7.5, PI, TAU, 12, Color(1, 1, 1, 0.45), 1.0)
		for i in 4:
			draw_line(head + Vector2(-6 + i * 4, -8), head + Vector2(-5 + i * 3.5, -1), Color(1, 1, 1, 0.3), 0.8)


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
