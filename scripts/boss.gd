extends CharacterBody2D
## Captain Brask, the huge guard captain and first boss.
## Swings a shock maul when you're close and charges when you keep away.
## Bait a charge into a wall and he's stunned: hits then do double damage.
## Beating him breaks the villain's last casing and drops the plasma rifle.

signal defeated(at: Vector2)
signal health_changed(hp: int, max_hp: int)

const FX := preload("res://scripts/fx.gd")
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
var _spot: PointLight2D
var _danger: PointLight2D
var _baton_light: PointLight2D
var _beam: Node2D


func _ready() -> void:
	add_to_group("enemies")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 13.0
	shape.shape = circle
	add_child(shape)

	# A harsh spotlight follows him around the yard, with a visible beam.
	_spot = FX.make_light(Color(1.0, 0.9, 0.75), 0.85, 1.1)
	_spot.position = Vector2(0, -20)
	add_child(_spot)
	_danger = FX.make_light(Color(1.0, 0.15, 0.1), 0.0, 1.0)
	add_child(_danger)
	_baton_light = FX.make_light(Color(1.0, 0.8, 0.35), 0.5, 0.35)
	add_child(_baton_light)
	_beam = Node2D.new()
	_beam.material = FX.unshaded_additive()
	_beam.draw.connect(_draw_beam)
	add_child(_beam)


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
	_beam.queue_redraw()
	# lights: red danger glow builds during wind-ups, baton flickers
	var warn := 0.0
	if _state == "swing_windup":
		warn = _state_time / SWING_WINDUP
	elif _state == "charge_windup":
		warn = _state_time / CHARGE_WINDUP
	_danger.energy = warn * 2.2
	_spot.color = Color(1.0, 0.9, 0.75).lerp(Color(1.0, 0.3, 0.2), warn)
	_baton_light.position = Vector2(30 * _facing, -60)
	_baton_light.energy = 0.35 + randf() * 0.35
	if _dead:
		_spot.energy = move_toward(_spot.energy, 0.0, delta)
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
	# Telegraphs: a glowing red ring before the swing, a red lane before the charge.
	if _state == "swing_windup":
		var k := _state_time / SWING_WINDUP
		_iso_ring(Vector2.ZERO, SWING_REACH * 0.5, Color(1, 0.15, 0.1, 0.25 + 0.55 * k), 5.0)
		_iso_ring(Vector2.ZERO, SWING_REACH * 0.5, Color(1, 0.6, 0.5, 0.4 * k), 1.5)
		_iso_ring(Vector2.ZERO, SWING_REACH * 0.5 * k, Color(1, 0.2, 0.1, 0.3), 2.0)
	elif _state == "charge_windup":
		var lane := Vector2(_charge_dir.x, _charge_dir.y * 0.5).normalized() * 170.0
		var alpha := 0.2 + 0.3 * absf(sin(_t * 18.0))
		draw_line(Vector2.ZERO, lane, Color(1, 0.15, 0.1, alpha), 24.0)
		draw_line(Vector2.ZERO, lane, Color(1, 0.6, 0.5, alpha), 2.0)

	FX.draw_character_shadow(self, 22.0, 90.0)
	self_modulate = Color(2.2, 2.2, 2.2) if _flash > 0.0 else Color.WHITE

	# Everything below is drawn at double size: he's huge.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2.0, 2.0))
	var f := _facing
	var o := Vector2(0, -absf(sin(_walk)) * 1.0)
	var stride := sin(_walk) * 2.5
	var navy := Color("1e2a47")
	var navy_dark := Color("0e1528")
	var navy_light := Color("34466e")
	var vest := Color("23252b")
	var vest_light := Color("3a3d45")
	var red := Color("a3222b")
	var gold := Color("e3b23c")
	var steel := Color("5d6470")

	# --- exo-suit backpack (behind the body) ---
	var pack := o + Vector2(-4 * f, -34)
	draw_rect(Rect2(pack + Vector2(-9, -2), Vector2(18, 20)), Color("16181d"))
	draw_rect(Rect2(pack + Vector2(-8, -1), Vector2(16, 18)), steel.darkened(0.3))
	for side: int in [-1, 1]:
		# pistons up to the shoulders
		draw_line(pack + Vector2(7 * side, 0), o + Vector2(12 * side, -33), Color("2b2f36"), 2.5)
		draw_line(pack + Vector2(7 * side, 0), o + Vector2(12 * side, -33), steel.lightened(0.2), 0.8)
	var vent_glow := 0.6 + 0.4 * sin(_t * 6.0)
	draw_rect(Rect2(pack + Vector2(-6, -6), Vector2(4, 5)), Color(1.0, 0.5, 0.15, vent_glow))
	draw_rect(Rect2(pack + Vector2(2, -6), Vector2(4, 5)), Color(1.0, 0.5, 0.15, vent_glow))

	# --- legs: armoured trousers, knee plates, heavy boots ---
	for side: int in [-1, 1]:
		var hip := o + Vector2(4.5 * side, -14)
		var foot := o + Vector2(4.5 * side + stride * side, 0)
		draw_line(hip, foot, navy_dark, 6.0)
		draw_line(hip + Vector2(-1, 0), foot + Vector2(-1, -3), navy, 3.0)
		draw_rect(Rect2(hip.lerp(foot, 0.5) - Vector2(3, 2), Vector2(6, 4)), vest_light)
		draw_rect(Rect2(foot + Vector2(-4, -3), Vector2(8, 4)), Color("0b0c10"))
		draw_line(foot + Vector2(-4, -3), foot + Vector2(4, -3), Color(1, 1, 1, 0.25), 0.6)

	# --- torso: rumpled uniform shirt under a tactical vest ---
	FX.gradient_quad(self, PackedVector2Array([
		o + Vector2(-13, -34), o + Vector2(13, -34), o + Vector2(9, -13), o + Vector2(-9, -13)
	]), navy_light, navy_dark)
	for fold in [[Vector2(-8, -20), Vector2(-4, -17)], [Vector2(6, -22), Vector2(9, -18)], [Vector2(-10, -28), Vector2(-7, -25)]]:
		draw_line(o + fold[0], o + fold[1], Color(0, 0, 0, 0.35), 0.8)
	FX.gradient_quad(self, PackedVector2Array([
		o + Vector2(-10, -31), o + Vector2(10, -31), o + Vector2(8, -15), o + Vector2(-8, -15)
	]), vest_light, vest)
	for i in 3:  # pouches
		var px := -7.5 + i * 5.5
		draw_rect(Rect2(o + Vector2(px, -21), Vector2(4.5, 5)), Color("1a1c21"))
		draw_line(o + Vector2(px, -19.5), o + Vector2(px + 4.5, -19.5), vest_light, 0.6)
	for side: int in [-1, 1]:  # vest straps
		draw_line(o + Vector2(6 * side, -31), o + Vector2(9 * side, -35), vest, 2.0)
	# metal badge: a star that catches the light
	var badge := o + Vector2(4 * f, -27)
	var star := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + TAU * i / 10.0
		star.append(badge + Vector2(cos(a), sin(a)) * (2.6 if i % 2 == 0 else 1.1))
	draw_colored_polygon(star, gold)
	var glint := 0.5 + 0.5 * sin(_t * 2.3)
	draw_circle(badge + Vector2(-0.7, -0.8), 0.8, Color(1, 1, 1, glint))
	draw_rect(Rect2(o + Vector2(-8 * f - 3, -28), Vector2(6, 1.6)), Color("c9c2a6"))  # name tape
	draw_rect(Rect2(o + Vector2(-9, -16), Vector2(18, 3)), Color("0a0d16"))      # belt
	draw_rect(Rect2(o + Vector2(-1.5, -16), Vector2(3, 3)), gold.darkened(0.2))

	# shoulder pads
	for side: int in [-1, 1]:
		var sp := o + Vector2(12 * side, -32)
		draw_circle(sp, 4.2, red.darkened(0.3))
		draw_circle(sp + Vector2(-0.6, -0.8), 3.4, red)
		draw_arc(sp, 3.4, PI * 1.1, PI * 1.6, 6, Color(1, 0.6, 0.6, 0.5), 0.8)

	# --- arms and the heavy stun baton ---
	var hand: Vector2
	var baton_dir: Vector2
	if _state == "swing_windup":
		hand = o + Vector2(6 * f, -46)
		baton_dir = Vector2(-0.3 * f, -1)
	elif _state == "recover" and _state_time < 0.2:
		hand = o + Vector2(17 * f, -15)
		baton_dir = Vector2(f, 0.6)
	else:
		hand = o + Vector2(15 * f, -19)
		baton_dir = Vector2(0.45 * f, -1)
	var off_hand := o + Vector2(-14 * f, -16)
	draw_line(o + Vector2(-12 * f, -31), off_hand, navy_dark, 6.0)
	draw_line(o + Vector2(-12 * f, -31), off_hand, navy, 4.0)
	draw_circle(off_hand, 2.6, Color("15161a"))
	draw_line(o + Vector2(12 * f, -31), hand, navy_dark, 6.0)
	draw_line(o + Vector2(12 * f, -31), hand, navy, 4.0)
	var tip := hand + baton_dir.normalized() * 17.0
	draw_line(hand - baton_dir.normalized() * 3.0, tip, Color("111215"), 3.5)
	draw_line(hand, tip, steel, 1.2)
	for k in 3:  # emitter coils
		var cp := hand.lerp(tip, 0.65 + k * 0.12)
		draw_line(cp - baton_dir.orthogonal().normalized() * 2.2, cp + baton_dir.orthogonal().normalized() * 2.2, Color("c98a2a"), 1.2)
	draw_circle(hand, 2.6, Color("15161a"))  # glove
	# crackling arcs around the baton head
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_t * 20.0)
	var crackle := 1.0 if _state.ends_with("windup") else 0.55
	for k in 3:
		var a := rng.randf() * TAU
		var arc := FX.jagged(tip, tip + Vector2(cos(a), sin(a)) * rng.randf_range(4, 9) * crackle * 1.4, 3, 1.5, rng)
		draw_polyline(arc, Color(1.0, 0.9, 0.5, 0.9), 0.8)
	draw_circle(tip, 2.4, Color(1.0, 0.85, 0.35, 0.7 + 0.3 * sin(_t * 40.0)))

	# --- head: thick neck, square stubbled jaw, scar, peaked cap, red visor ---
	var head := o + Vector2(0, -40)
	draw_rect(Rect2(head + Vector2(-4, 3), Vector2(8, 4)), Color("b08f75"))
	draw_circle(head, 6.6, Color("c9a68a"))
	draw_rect(Rect2(head + Vector2(-5.5, 0.5), Vector2(11, 6)), Color("c9a68a"))
	draw_rect(Rect2(head + Vector2(-5.5, 3.5), Vector2(11, 3)), Color("8f7562"))  # stubble
	draw_line(head + Vector2(2 * f, 2), head + Vector2(4 * f, 5), Color("7a4a3a"), 0.7)  # scar
	FX.gradient_quad(self, PackedVector2Array([
		head + Vector2(-6.5, -8.5), head + Vector2(6.5, -8.5), head + Vector2(8, -2.5), head + Vector2(-8, -2.5)
	]), navy_light, navy_dark)
	draw_line(head + Vector2(-9, -2.2), head + Vector2(9, -2.2), Color("07090f"), 2.0)  # brim
	draw_line(head + Vector2(-8, -3.2), head + Vector2(8, -3.2), Color(1, 1, 1, 0.18), 0.6)
	draw_circle(head + Vector2(0, -6), 1.6, gold)
	draw_circle(head + Vector2(-0.4, -6.4), 0.5, Color(1, 1, 1, glint))
	draw_rect(Rect2(head + Vector2(-5 + 2 * f, -1), Vector2(10, 2.4)), Color("ff4848"))
	draw_rect(Rect2(head + Vector2(-5 + 2 * f, -1), Vector2(10, 0.8)), Color(1, 0.8, 0.8, 0.8))

	if _state == "stunned":
		for i in 3:
			var a := _t * 5.0 + TAU * i / 3.0
			draw_circle(head + Vector2(cos(a) * 9.0, -13 + sin(a) * 3.0), 1.5, gold)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The overhead spotlight beam pinning Brask, drawn as glowing light.
func _draw_beam() -> void:
	var sway := sin(_t * 0.9) * 26.0
	var col := Color(1.0, 0.92, 0.78)
	if _state.ends_with("windup"):
		col = Color(1.0, 0.25, 0.15)
	var pts := PackedVector2Array([Vector2(-14 + sway, -520), Vector2(14 + sway, -520), Vector2(46, 0), Vector2(-46, 0)])
	_beam.draw_polygon(pts, PackedColorArray([Color(col, 0.0), Color(col, 0.0), Color(col, 0.09), Color(col, 0.09)]))
	_beam.draw_colored_polygon(FX.iso_ellipse(Vector2.ZERO, 46.0), Color(col, 0.10))
	_beam.draw_colored_polygon(FX.iso_ellipse(Vector2.ZERO, 30.0), Color(col, 0.08))


func _iso_ring(c: Vector2, r: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * r * 2.0, sin(a) * r))
	draw_polyline(pts, color, width)
