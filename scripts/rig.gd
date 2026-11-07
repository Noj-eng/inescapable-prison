extends StaticBody2D
## The containment rig: a heavy upright ring that holds the villain in the air,
## arms spread, limbs locked in mechanical casings and pinned by energy.
## The villain starts the game inside it, until an earthquake shorts it out.

const STEEL := Color("4a5160")
const STEEL_DARK := Color("272c36")
const STEEL_LIGHT := Color("6c7486")
const HAZARD := Color("d9a521")
const ENERGY := Color("5ff3ff")

const RING_CENTER := Vector2(0, -52)
const RING_RADIUS := Vector2(48, 50)

var powered := true
var _sparking := 0.0  # seconds of shorting-out sparks left
var _t := 0.0
var _arc_timer := 0.0
var _arc_seed := 0


func _ready() -> void:
	# The two side pillars are solid. The middle stays open so the villain can step out.
	for side: int in [-1, 1]:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 7.0
		shape.shape = circle
		shape.position = Vector2(46 * side, 0)
		add_child(shape)


## The earthquake hits: the rig shorts out in a shower of sparks and goes dark.
func fail() -> void:
	powered = false
	_sparking = 1.6


func _process(delta: float) -> void:
	_t += delta
	_sparking = maxf(0.0, _sparking - delta)
	_arc_timer -= delta
	if _arc_timer <= 0.0:
		_arc_timer = 0.06
		_arc_seed += 1
	queue_redraw()


func _draw() -> void:
	var glow := ENERGY if powered else Color(ENERGY, 0.15)
	var pulse := 0.6 + 0.4 * sin(_t * 4.0) if powered else 0.2

	# Base plate: an iso disc with hazard trim and a glowing ring.
	_iso_disc(Vector2(0, 2), 54, STEEL_DARK)
	_iso_disc(Vector2.ZERO, 54, STEEL)
	_iso_ring(Vector2.ZERO, 50, HAZARD.darkened(0.3), 2.0)
	_iso_ring(Vector2.ZERO, 30, Color(glow, pulse), 3.0)
	_iso_disc(Vector2.ZERO, 22, STEEL_DARK)

	# The big upright ring behind the villain.
	_ellipse(RING_CENTER, RING_RADIUS + Vector2(6, 6), STEEL_DARK, 12.0)
	_ellipse(RING_CENTER, RING_RADIUS, STEEL, 8.0)
	_ellipse(RING_CENTER, RING_RADIUS - Vector2(5, 5), Color(glow, pulse * 0.8), 2.0)

	# Side pillars from the base up to the arm clamps.
	for side: int in [-1, 1]:
		var x := 46.0 * side
		draw_rect(Rect2(Vector2(x - 6, -60), Vector2(12, 60)), STEEL_DARK)
		draw_rect(Rect2(Vector2(x - 4, -58), Vector2(8, 56)), STEEL)
		draw_line(Vector2(x - 4, -58), Vector2(x - 4, -2), STEEL_LIGHT, 1.0)
		# hazard stripes near the floor
		for i in 3:
			draw_line(Vector2(x - 4, -8 - i * 5), Vector2(x + 4, -12 - i * 5), HAZARD, 2.0)
		# arm clamp housing
		draw_rect(Rect2(Vector2(x - 9, -66), Vector2(18, 20)), STEEL_DARK)
		draw_rect(Rect2(Vector2(x - 7, -64), Vector2(14, 16)), STEEL_LIGHT)
		draw_circle(Vector2(x, -56), 3.0, glow)

	# Crackling energy: clamps to ring, and feet to the floor emitter.
	if powered:
		var rng := RandomNumberGenerator.new()
		rng.seed = _arc_seed
		for side: int in [-1, 1]:
			_arc(rng, Vector2(36 * side, -56), Vector2(30 * side, -92), 5)
			_arc(rng, Vector2(36 * side, -56), Vector2(48 * side, -30), 4)
		_arc(rng, Vector2(-3, -16), Vector2(-6, 0), 4)
		_arc(rng, Vector2(3, -16), Vector2(6, 0), 4)
	elif _sparking > 0.0:
		# shorting out: wild arcs and sparks jumping off the clamps and ring
		var rng := RandomNumberGenerator.new()
		rng.seed = _arc_seed
		for i in 4:
			var side := -1 if rng.randf() < 0.5 else 1
			var from := Vector2(36 * side, -56)
			var to := from + Vector2(rng.randf_range(-30, 30), rng.randf_range(-40, 30))
			_arc(rng, from, to, 4)
		for i in 10:
			var p := RING_CENTER + Vector2(rng.randf_range(-50, 50), rng.randf_range(-50, 50))
			draw_circle(p, rng.randf_range(0.8, 2.0), Color(1.0, 0.9, 0.5))


func _arc(rng: RandomNumberGenerator, from: Vector2, to: Vector2, segments: int) -> void:
	var pts := PackedVector2Array()
	for i in segments + 1:
		var p := from.lerp(to, float(i) / segments)
		if i != 0 and i != segments:
			p += Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
		pts.append(p)
	draw_polyline(pts, Color(ENERGY, 0.35), 4.0)
	draw_polyline(pts, Color(0.85, 1.0, 1.0), 1.2)


func _iso_disc(c: Vector2, r: float, color: Color) -> void:
	draw_colored_polygon(_iso_points(c, r), color)


func _iso_ring(c: Vector2, r: float, color: Color, width: float) -> void:
	var pts := _iso_points(c, r)
	pts.append(pts[0])
	draw_polyline(pts, color, width)


func _iso_points(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.5))
	return pts


func _ellipse(c: Vector2, r: Vector2, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var a := TAU * i / 40.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_polyline(pts, color, width)
