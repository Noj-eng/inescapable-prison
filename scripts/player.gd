extends CharacterBody2D
## The villain. Walk with WASD or the arrow keys, slam with Space,
## and once the plasma rifle is picked up, fire with a mouse click or F.
## Starts suspended in the containment rig until the earthquake drops them.
## Arms and shins are locked in heavy mechanical casings. Every enemy knocked
## out cracks one casing off; the last one is saved for the first boss.
## Drawn with simple shapes for now.

signal casing_broken(piece: int)
signal health_changed(hp: int, max_hp: int)
signal died

const SPEED := 120.0
const HOVER := 16.0          # how high the rig holds the villain off the floor
const SLAM_RANGE := 42.0     # how far the casing slam reaches
const SLAM_COOLDOWN := 0.55
const MAX_HP := 10
const INVULNERABLE_TIME := 0.8   # seconds of safety after taking a hit
const FIRE_COOLDOWN := 0.22

const FX := preload("res://scripts/fx.gd")
const SUIT := Color("ee7a2b")
const SUIT_DARK := Color("b85a1c")
const CASING := Color("5a6272")
const CASING_DARK := Color("2f3540")
const CASING_LIGHT := Color("8790a3")
const SEAM := Color("5ff3ff")
const SKIN := Color("9fb0a4")

enum Piece { LEFT_ARM, RIGHT_ARM, LEFT_LEG, RIGHT_LEG }

var held := true
var hover := HOVER
var facing := 1.0
var walk_time := 0.0
var broken := [false, false, false, false]
var hp := MAX_HP
var dead := false
var has_rifle := false

var _t := 0.0
var _knock := Vector2.ZERO
var _hurt_flash := 0.0
var _slam_time := 0.0        # counts down while the slam animation plays
var _slam_cooldown := 0.0
var _invulnerable := 0.0
var _fire_cooldown := 0.0
var _muzzle_flash := 0.0
var _shake_time := 0.0
var _shake_amount := 0.0
var _cam: Camera2D
var _glow: PointLight2D


func _ready() -> void:
	add_to_group("player")
	# A small circle at the villain's feet is what bumps into walls.
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)

	# The casings' cyan seams glow faintly; the glow fades as they break off.
	_glow = FX.make_light(Color(0.3, 0.95, 1.0), 0.45, 0.45)
	_glow.position = Vector2(0, -24)
	add_child(_glow)

	_cam = Camera2D.new()
	_cam.zoom = Vector2(1.8, 1.8)
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 6.0
	add_child(_cam)


## Called by the earthquake: the rig fails and the villain falls to the floor.
func drop() -> void:
	held = false
	var tween := create_tween()
	tween.tween_property(self, "hover", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(shake.bind(4.0, 0.25))


## Jump the camera straight to the villain (used when a new level loads).
func snap_camera() -> void:
	_cam.reset_smoothing()


func heal(amount: int) -> void:
	hp = mini(MAX_HP, hp + amount)
	health_changed.emit(hp, MAX_HP)


## Back on your feet after a game over, with the health and casings given.
func revive(new_hp: int, casings: Array) -> void:
	dead = false
	held = false
	hover = 0.0
	hp = new_hp
	broken = casings.duplicate()
	_knock = Vector2.ZERO
	_invulnerable = 1.0
	health_changed.emit(hp, MAX_HP)


func shake(amount: float, duration: float) -> void:
	_shake_amount = amount
	_shake_time = duration


## An enemy hit us: lose health, get shoved back, and flash red.
func hit(from: Vector2, damage: int = 1, force: float = 220.0) -> void:
	if dead or held or _invulnerable > 0.0:
		return
	hp = maxi(0, hp - damage)
	health_changed.emit(hp, MAX_HP)
	_knock = (global_position - from).normalized() * force
	_hurt_flash = 0.25
	_invulnerable = INVULNERABLE_TIME
	shake(3.0 + damage * 2.0, 0.25)
	if hp == 0:
		dead = true
		died.emit()


## Breaks the next casing. Returns false if only the boss's piece is left.
func break_next_casing() -> bool:
	for i in 3:  # the 4th piece (right leg) is saved for the first boss
		if not broken[i]:
			broken[i] = true
			casing_broken.emit(i)
			shake(5.0, 0.3)
			return true
	return false


## Only beating the guard captain breaks the last casing.
func break_final_casing() -> void:
	broken[Piece.RIGHT_LEG] = true
	casing_broken.emit(Piece.RIGHT_LEG)
	shake(8.0, 0.5)


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


func _process(delta: float) -> void:
	# Camera shake
	if _shake_time > 0.0:
		_shake_time -= delta
		_cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_amount
	else:
		_cam.offset = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_t += delta
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	_slam_time = maxf(0.0, _slam_time - delta)
	_slam_cooldown = maxf(0.0, _slam_cooldown - delta)
	_invulnerable = maxf(0.0, _invulnerable - delta)
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_muzzle_flash = maxf(0.0, _muzzle_flash - delta)
	_glow.energy = 0.12 * broken.count(false) + (0.8 if _muzzle_flash > 0.0 else 0.0)
	_glow.color = Color(0.75, 0.45, 1.0) if _muzzle_flash > 0.0 else Color(0.3, 0.95, 1.0)
	queue_redraw()
	if held:
		return
	if dead:
		velocity = _knock
		_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		return

	var input := _read_input()
	if Input.is_key_pressed(KEY_SPACE) and _slam_cooldown <= 0.0:
		_slam()
	var firing := Input.is_key_pressed(KEY_F) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if has_rifle and firing and _fire_cooldown <= 0.0:
		_fire()

	# Squash vertical movement by half so it matches the isometric floor.
	var move := Vector2(input.x, input.y * 0.5).normalized() * SPEED if input != Vector2.ZERO else Vector2.ZERO
	if _slam_time > 0.0:
		move *= 0.3  # slamming roots you in place
	velocity = move + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()

	if input.x != 0:
		facing = sign(input.x)
	walk_time = walk_time + delta * 9.0 if input != Vector2.ZERO else 0.0


## Smash the heavy casings into the floor, hitting every enemy close by.
func _slam() -> void:
	_slam_time = 0.3
	_slam_cooldown = SLAM_COOLDOWN
	shake(2.5, 0.12)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var d: Vector2 = enemy.global_position - global_position
		# Measure distance on the flat floor (undo the isometric squash).
		if Vector2(d.x, d.y * 2.0).length() < SLAM_RANGE * 1.4 + enemy.hit_radius:
			enemy.take_hit(global_position)


## Fire a plasma bolt toward the mouse (or straight ahead when using F).
func _fire() -> void:
	_fire_cooldown = FIRE_COOLDOWN
	_muzzle_flash = 0.06
	var aim := get_global_mouse_position() - global_position
	if Input.is_key_pressed(KEY_F) or aim.length() < 4.0:
		aim = Vector2(facing, 0)
	facing = signf(aim.x) if absf(aim.x) > 1.0 else facing
	var bolt := Node2D.new()
	bolt.set_script(preload("res://scripts/plasma_bolt.gd"))
	bolt.direction = aim.normalized()
	bolt.position = global_position + bolt.direction * 14.0
	get_parent().add_child(bolt)


func _draw() -> void:
	# shockwave from a slam
	if _slam_time > 0.0:
		var k := 1.0 - _slam_time / 0.3
		_iso_ring(Vector2.ZERO, SLAM_RANGE * (0.4 + k), Color(SEAM, 1.0 - k), 3.0)

	# long shadow (shrinks while floating)
	FX.draw_character_shadow(self, 13.0 * (1.0 - hover / HOVER * 0.35), 46.0)

	if dead:
		modulate = Color(0.55, 0.55, 0.6)
	elif _hurt_flash > 0.0:
		modulate = Color(1, 0.45, 0.45)
	elif _invulnerable > 0.0 and int(_t * 20.0) % 2 == 0:
		modulate = Color(1, 1, 1, 0.45)  # blink while invulnerable
	else:
		modulate = Color.WHITE
	if dead:
		# slumped on the floor
		draw_set_transform(Vector2(0, -4), PI * 0.5 * facing, Vector2.ONE)
		_draw_free()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif held:
		_draw_held()
	else:
		_draw_free()


## Suspended in the rig: arms spread wide inside heavy casings, legs locked together.
func _draw_held() -> void:
	var lift := -hover + sin(_t * 2.0) * 1.5
	var o := Vector2(0, lift)
	_leg(o + Vector2(-3, 0), 0.0, Piece.LEFT_LEG)
	_leg(o + Vector2(3, 0), 0.0, Piece.RIGHT_LEG)
	_torso(o)
	for side: int in [-1, 1]:
		var shoulder := o + Vector2(9 * side, -33)
		var hand := o + Vector2(38 * side, -56 - lift)  # hands stay pinned in the clamps
		_arm(shoulder, hand, Piece.LEFT_ARM if side < 0 else Piece.RIGHT_ARM)
	_head(o + Vector2(0, 1), 1.0)


func _draw_free() -> void:
	var o := Vector2(0, -hover - absf(sin(walk_time)) * 1.5)
	var stride := sin(walk_time) * 3.0
	_leg(o + Vector2(-4, 0), stride, Piece.LEFT_LEG)
	_leg(o + Vector2(4, 0), -stride, Piece.RIGHT_LEG)
	_torso(o)
	for side: int in [-1, 1]:
		var shoulder := o + Vector2(12 * side, -33)
		var hand: Vector2
		if has_rifle and _slam_time <= 0.0:
			hand = o + Vector2((14 + 4 * side) * facing, -24)  # both hands on the rifle
		elif _slam_time > 0.15:
			hand = o + Vector2(6 * side, -58)        # arms raised overhead
		elif _slam_time > 0.0:
			hand = o + Vector2(16 * side, -6)        # smashing down
		else:
			hand = o + Vector2(15 * side - stride * side * 0.8, -14)
		_arm(shoulder, hand, Piece.LEFT_ARM if side < 0 else Piece.RIGHT_ARM)
	if has_rifle and _slam_time <= 0.0:
		_draw_rifle(o)
	_head(o, facing)


func _draw_rifle(o: Vector2) -> void:
	var f := facing
	var back := o + Vector2(2 * f, -23)
	var tip := o + Vector2(30 * f, -27)
	draw_line(back, tip, Color("15171d"), 6.0)
	draw_line(back, tip, Color("3b4150"), 4.0)
	# glowing plasma coils along the barrel
	for t in [0.45, 0.6, 0.75]:
		draw_circle(back.lerp(tip, t), 2.2, Color("b25cff"))
	if _muzzle_flash > 0.0:
		draw_circle(tip, 6.0, Color(0.85, 0.6, 1.0, 0.8))
		draw_circle(tip, 3.0, Color.WHITE)


func _leg(foot: Vector2, stride: float, piece: int) -> void:
	var hip := foot + Vector2(0, -18)
	var knee := foot + Vector2(stride, -10)
	draw_line(hip, knee, SUIT_DARK, 6.5)
	draw_line(hip + Vector2(-1, 0), knee + Vector2(-1, 0), SUIT, 3.5)
	if broken[piece]:
		# torn trouser leg, bare shin, and the broken ankle cuff with dangling wires
		var ankle := foot + Vector2(stride * 0.5, -3)
		draw_line(knee, ankle, SUIT_DARK, 5.5)
		_torn_edge(knee + Vector2(-3.5, 1), knee + Vector2(3.5, 1))
		draw_line(knee + Vector2(0, 2), ankle, SKIN.darkened(0.2), 3.0)
		_cuff_remnant(ankle, 6.0, piece)
		draw_rect(Rect2(foot + Vector2(stride * 0.5 - 3.5, -2), Vector2(7, 3)), Color("141318"))
		return
	var shin := Rect2(knee + Vector2(-5.5, -1), Vector2(11, 13))
	draw_rect(shin.grow(1), CASING_DARK)
	FX.gradient_quad(self, PackedVector2Array([shin.position, shin.position + Vector2(shin.size.x, 0), shin.end, shin.position + Vector2(0, shin.size.y)]), CASING_LIGHT, CASING_DARK)
	draw_line(shin.position + Vector2(0, 5), shin.position + Vector2(11, 5), SEAM, 1.5)
	draw_line(shin.position + Vector2(5.5, 6), shin.position + Vector2(5.5, 13), Color(0, 0, 0, 0.35), 1.0)
	draw_circle(shin.position + Vector2(2, 2), 0.8, CASING_LIGHT.lightened(0.3))
	draw_circle(shin.position + Vector2(9, 2), 0.8, CASING_LIGHT.lightened(0.3))


func _arm(shoulder: Vector2, hand: Vector2, piece: int) -> void:
	if broken[piece]:
		# torn sleeve to the elbow, bare muscular forearm, cuff remnant at the wrist
		var elbow := shoulder.lerp(hand, 0.45)
		draw_line(shoulder, elbow, SUIT_DARK, 7.5)
		draw_line(shoulder, elbow, SUIT, 5.0)
		_torn_edge(elbow + (hand - shoulder).orthogonal().normalized() * 3.5, elbow - (hand - shoulder).orthogonal().normalized() * 3.5)
		draw_line(elbow, hand, SKIN.darkened(0.25), 5.5)
		draw_line(elbow, hand, SKIN, 3.5)
		draw_line(elbow.lerp(hand, 0.2), elbow.lerp(hand, 0.7), SKIN.lightened(0.2), 1.0)  # muscle highlight
		_cuff_remnant(elbow.lerp(hand, 0.8), 7.0, piece)
		draw_circle(hand, 3.8, SKIN.darkened(0.1))
		draw_circle(shoulder, 4.5, CASING_DARK)  # jagged stump of the shoulder mount
		return
	_casing(shoulder, hand, 13.0)


## A ragged fabric edge where the jumpsuit has been torn.
func _torn_edge(a: Vector2, b: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		var p := a.lerp(b, i / 5.0)
		pts.append(p + Vector2(0, 2.0 if i % 2 == 0 else -0.5))
	draw_polyline(pts, SUIT_DARK.darkened(0.3), 1.5)


## What's left of a casing once it breaks: a jagged steel band with torn-out wires.
func _cuff_remnant(at: Vector2, radius: float, piece: int) -> void:
	var band := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0
		var r := radius + (1.2 if i % 3 == 0 else 0.0)
		band.append(at + Vector2(cos(a) * r, sin(a) * r * 0.45))
	draw_colored_polygon(band, CASING_DARK)
	draw_polyline(band, CASING_LIGHT, 1.0)
	# broken teeth sticking out
	for k in 3:
		var a := TAU * (k + 0.3 * piece) / 3.0
		var base := at + Vector2(cos(a) * radius, sin(a) * radius * 0.45)
		draw_line(base, base + Vector2(cos(a) * 3.0, -2.5), CASING_LIGHT, 1.2)
	# dangling wires swinging as he moves
	var sway := sin(_t * 3.0 + piece) * 2.0 + sin(walk_time) * 1.5
	var colors := [Color("c23b2e"), Color("2f7fd1"), Color("d9c23a")]
	for k in 3:
		var start := at + Vector2(-2.5 + k * 2.5, 1.5)
		var end := start + Vector2(sway + k - 1, 7.0 + k * 2.0)
		draw_polyline(PackedVector2Array([start, start.lerp(end, 0.5) + Vector2(1.5, 0), end]), colors[k], 0.9)
	# the odd spark from a severed seam
	if fmod(_t * 2.0 + piece * 1.3, 3.0) < 0.1:
		draw_circle(at + Vector2(sway, 9), 2.5, Color(0.6, 1.0, 1.0, 0.9))


func _torso(o: Vector2) -> void:
	# broad, hunched shoulders tapering to the waist
	FX.gradient_quad(self, PackedVector2Array([
		o + Vector2(-13, -36), o + Vector2(13, -36), o + Vector2(7.5, -15), o + Vector2(-7.5, -15)
	]), SUIT.lightened(0.08), SUIT_DARK)
	draw_line(o + Vector2(0, -35), o + Vector2(0, -16), SUIT_DARK.darkened(0.2), 1.0)  # zip
	for fold in [[Vector2(-9, -27), Vector2(-5, -24)], [Vector2(5, -22), Vector2(8, -19)]]:
		draw_line(o + fold[0], o + fold[1], Color(0, 0, 0, 0.3), 0.8)
	# a rip in the suit across the ribs
	draw_polyline(PackedVector2Array([o + Vector2(3, -30), o + Vector2(5, -28.5), o + Vector2(7, -30), o + Vector2(9, -28)]), SKIN.darkened(0.3), 1.4)
	draw_rect(Rect2(o + Vector2(-9, -32), Vector2(7, 4)), Color("efe8d6"))  # prisoner number
	draw_line(o + Vector2(-8, -30), o + Vector2(-3.5, -30), Color(0, 0, 0, 0.6), 0.8)
	draw_rect(Rect2(o + Vector2(-8.5, -19), Vector2(17, 4)), CASING_DARK)  # restraint belt
	draw_rect(Rect2(o + Vector2(-2, -19), Vector2(4, 4)), SEAM)


## A heavy mechanical sleeve from a to b, with a big cuff block at the end.
func _casing(a: Vector2, b: Vector2, thickness: float) -> void:
	var n := (b - a).orthogonal().normalized() * thickness * 0.5
	draw_line(a, b, CASING_DARK, thickness + 2.0)
	draw_polygon(PackedVector2Array([a - n, b - n, b + n, a + n]),
		PackedColorArray([CASING_LIGHT, CASING_LIGHT, CASING_DARK, CASING_DARK]))
	draw_line(a - n * 0.7, b - n * 0.7, CASING_LIGHT.lightened(0.25), 1.0)
	for t in [0.33, 0.66]:
		var p: Vector2 = a.lerp(b, t)
		draw_line(p - n, p + n, SEAM, 1.5)
		draw_circle(p - n * 0.6 + (b - a).normalized() * 2.5, 0.8, CASING_LIGHT.lightened(0.3))
	var cuff := Rect2(b - Vector2(7.5, 7.5), Vector2(15, 15))
	draw_rect(cuff.grow(1), CASING_DARK)
	FX.gradient_quad(self, PackedVector2Array([cuff.position, cuff.position + Vector2(cuff.size.x, 0), cuff.end, cuff.position + Vector2(0, cuff.size.y)]), CASING_LIGHT, CASING_DARK)
	draw_rect(Rect2(cuff.position + Vector2(2, 2), Vector2(11, 2)), Color(0, 0, 0, 0.3))
	draw_circle(b, 2.2, SEAM)
	draw_circle(b, 4.0, Color(SEAM, 0.25))


func _head(o: Vector2, f: float) -> void:
	# restraint collar
	draw_rect(Rect2(o + Vector2(-7.5, -40), Vector2(15, 5)), CASING_DARK)
	draw_rect(Rect2(o + Vector2(-6.5, -39), Vector2(13, 2)), CASING_LIGHT)
	draw_circle(o + Vector2(0, -37.5), 1.3, SEAM)
	var head := o + Vector2(0, -46)
	draw_circle(head, 7.2, SKIN.darkened(0.15))
	draw_circle(head + Vector2(-0.6, -0.6), 6.4, SKIN)
	draw_line(head + Vector2(-5, 4), head + Vector2(5, 4), SKIN.darkened(0.3), 1.0)  # hard jaw line
	# slick black hair with a widow's peak
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-7.4, -1), head + Vector2(-6.5, -6.5), head + Vector2(0, -8.5),
		head + Vector2(6.5, -6.5), head + Vector2(7.4, -1), head + Vector2(0, -3.5)
	]), Color("131118"))
	draw_line(head + Vector2(-4, -6.5), head + Vector2(1, -7.5), Color(1, 1, 1, 0.18), 0.8)
	# glowing eyes under a heavy brow
	var ex := 2.5 * f
	draw_line(head + Vector2(ex - 4, -0.8), head + Vector2(ex + 4, -0.8), SKIN.darkened(0.45), 1.2)
	for dx in [-2.0, 2.0]:
		draw_circle(head + Vector2(ex + dx, 1), 2.4, Color(1.0, 0.82, 0.25, 0.25))
		draw_circle(head + Vector2(ex + dx, 1), 1.3, Color("ffd23f"))


func _iso_ring(c: Vector2, r: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.5))
	draw_polyline(pts, color, width)
