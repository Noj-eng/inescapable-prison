extends CharacterBody2D
## Captain Brask, the huge guard captain and first boss.
## Swings a shock maul when you're close and charges when you keep away.
## Bait a charge into a wall and he's stunned: hits then do double damage.
## Beating him breaks the villain's last casing and drops the plasma rifle.

signal defeated(at: Vector2)
signal health_changed(hp: int, max_hp: int)

const MAX_HP := 24
const WALK_SPEED := 48.0
const CHARGE_SPEED := 300.0
const SWING_REACH := 60.0     # floor distance the maul swing covers
const SWING_WINDUP := 0.6
const CHARGE_WINDUP := 0.8
const STUN_TIME := 1.6

var target: Node2D
var hp := MAX_HP
var hit_radius := 14.0        # big body, easier to hit

var _state := "chase"
var _state_time := 0.0
var _charge_dir := Vector2.ZERO
var _until_charge := 3.0
var _knock := Vector2.ZERO
var _flash := 0.0
var _walk := 0.0
var _facing := -1.0
var _t := 0.0
var _dead := false


func _ready() -> void:
	add_to_group("enemies")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 13.0
	shape.shape = circle
	add_child(shape)


func take_hit(from: Vector2) -> void:
	if _dead:
		return
	hp = maxi(0, hp - (2 if _state == "stunned" else 1))
	health_changed.emit(hp, MAX_HP)
	_flash = 0.12
	_knock = (global_position - from).normalized() * 60.0
	if hp == 0:
		_die()


func _die() -> void:
	_dead = true
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	defeated.emit(global_position)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 1.2)
	tween.tween_callback(queue_free)


func _set_state(state: String) -> void:
	_state = state
	_state_time = 0.0


## Distance on the flat floor, with the isometric squash undone.
func _floor_distance() -> float:
	var d := target.global_position - global_position
	return Vector2(d.x, d.y * 2.0).length()


func _physics_process(delta: float) -> void:
	_t += delta
	_state_time += delta
	_flash = maxf(0.0, _flash - delta)
	queue_redraw()
	if _dead or not is_instance_valid(target):
		return
	if target.dead:
		_set_state("idle")

	var to := target.global_position - global_position
	var move := Vector2.ZERO
	match _state:
		"chase":
			if absf(to.x) > 2.0:
				_facing = signf(to.x)
			_until_charge -= delta
			if _floor_distance() < SWING_REACH * 0.8:
				_set_state("swing_windup")
			elif _until_charge <= 0.0:
				_charge_dir = Vector2(to.x, to.y * 2.0).normalized()
				_set_state("charge_windup")
			else:
				var dir := Vector2(to.x, to.y * 2.0).normalized()
				move = Vector2(dir.x, dir.y * 0.5).normalized() * WALK_SPEED
		"swing_windup":
			if _state_time >= SWING_WINDUP:
				if _floor_distance() < SWING_REACH + 6.0:
					target.hit(global_position, 2, 360.0)
				target.shake(4.0, 0.2)
				_set_state("recover")
		"charge_windup":
			if _state_time >= CHARGE_WINDUP:
				_set_state("charge")
		"charge":
			move = Vector2(_charge_dir.x, _charge_dir.y * 0.5).normalized() * CHARGE_SPEED
			if _floor_distance() < 30.0:
				target.hit(global_position, 2, 420.0)
				_set_state("recover")
			elif _state_time > 1.1:
				_set_state("recover")
		"stunned":
			if _state_time >= STUN_TIME:
				_set_state("chase")
		"recover":
			if _state_time >= 0.7:
				_until_charge = randf_range(2.5, 4.0)
				_set_state("chase")

	velocity = move + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 400.0 * delta)
	move_and_slide()

	# Slammed into a wall or furniture mid-charge? He's stunned.
	if _state == "charge" and get_slide_collision_count() > 0:
		var collider := get_slide_collision(0).get_collider()
		if collider is StaticBody2D:
			target.shake(6.0, 0.35)
			_set_state("stunned")

	_walk = _walk + delta * (16.0 if _state == "charge" else 7.0) if move != Vector2.ZERO else 0.0


func _draw() -> void:
	# Telegraphs: a red ring before the swing, a red lane before the charge.
	if _state == "swing_windup":
		var k := _state_time / SWING_WINDUP
		_iso_ring(Vector2.ZERO, SWING_REACH * 0.5, Color(1, 0.2, 0.2, 0.3 + 0.5 * k), 3.0)
		_iso_ring(Vector2.ZERO, SWING_REACH * 0.5 * k, Color(1, 0.2, 0.2, 0.25), 2.0)
	elif _state == "charge_windup":
		var lane := Vector2(_charge_dir.x, _charge_dir.y * 0.5).normalized() * 160.0
		var alpha := 0.25 + 0.35 * absf(sin(_t * 18.0))
		draw_line(Vector2.ZERO, lane, Color(1, 0.2, 0.2, alpha), 22.0)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	self_modulate = Color(3, 3, 3) if _flash > 0.0 else Color.WHITE

	# Everything below is drawn at double size: he's huge.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2.0, 2.0))
	var f := _facing
	var o := Vector2(0, -absf(sin(_walk)) * 1.0)
	var stride := sin(_walk) * 2.5
	var navy := Color("1b2742")
	var navy_dark := Color("0f1729")
	var red := Color("a8262e")
	var gold := Color("e0b03a")

	draw_line(o + Vector2(-4, -14), o + Vector2(-4 + stride, 0), navy_dark, 5.0)
	draw_line(o + Vector2(4, -14), o + Vector2(4 - stride, 0), navy_dark, 5.0)
	# barrel chest with armour plates
	draw_colored_polygon(PackedVector2Array([
		o + Vector2(-12, -33), o + Vector2(12, -33), o + Vector2(9, -13), o + Vector2(-9, -13)
	]), navy)
	draw_rect(Rect2(o + Vector2(-9, -30), Vector2(18, 9)), Color("2b3d66"))
	draw_rect(Rect2(o + Vector2(3 * f - 2, -29), Vector2(4, 4)), gold)
	draw_rect(Rect2(o + Vector2(-9, -15), Vector2(18, 3)), Color("0a0f1c"))
	# red shoulder pads
	draw_circle(o + Vector2(-12, -32), 4.0, red)
	draw_circle(o + Vector2(12, -32), 4.0, red)

	# shock maul: raised during the swing wind-up, low otherwise
	var hand: Vector2
	var maul_dir: Vector2
	if _state == "swing_windup":
		hand = o + Vector2(6 * f, -44)
		maul_dir = Vector2(-0.3 * f, -1)
	elif _state == "recover" and _state_time < 0.2:
		hand = o + Vector2(16 * f, -16)
		maul_dir = Vector2(f, 0.6)
	else:
		hand = o + Vector2(14 * f, -20)
		maul_dir = Vector2(0.4 * f, -1)
	draw_line(o + Vector2(-12, -31), o + Vector2(-14, -16), navy, 5.0)
	draw_line(o + Vector2(12 * f, -31), hand, navy, 5.0)
	var head_end := hand + maul_dir.normalized() * 14.0
	draw_line(hand, head_end, Color("222"), 3.0)
	draw_rect(Rect2(head_end - Vector2(4, 4), Vector2(8, 8)), Color("4a4f5c"))
	draw_circle(head_end, 2.5, Color(1.0, 0.85, 0.3, 0.6 + 0.4 * sin(_t * 25.0)))

	# head: square jaw, peaked cap with a gold badge, red visor
	var head := o + Vector2(0, -39)
	draw_circle(head, 6.5, Color("c9a78c"))
	draw_rect(Rect2(head + Vector2(-5, 1), Vector2(10, 5)), Color("c9a78c"))
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-8, -2), head + Vector2(-6, -8), head + Vector2(6, -8), head + Vector2(8, -2)
	]), navy_dark)
	draw_line(head + Vector2(-9, -2), head + Vector2(9, -2), Color("0a0f1c"), 2.0)
	draw_circle(head + Vector2(0, -6), 1.5, gold)
	draw_rect(Rect2(head + Vector2(-5 + 2 * f, -1), Vector2(10, 2.5)), Color("e84a4a"))

	if _state == "stunned":
		for i in 3:
			var a := _t * 5.0 + TAU * i / 3.0
			draw_circle(head + Vector2(cos(a) * 9.0, -12 + sin(a) * 3.0), 1.5, gold)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _iso_ring(c: Vector2, r: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * r * 2.0, sin(a) * r))
	draw_polyline(pts, color, width)
