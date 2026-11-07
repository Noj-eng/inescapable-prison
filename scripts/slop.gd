extends Node2D
## A ladleful of mystery slop that Captain Willis lobs across the mess hall.
## A shadow on the floor shows where it will land. Direct hits hurt, and it
## leaves a slick puddle that slows the villain down for a while.

const FLIGHT_TIME := 0.9
const SPLASH_RADIUS := 20.0
const PUDDLE_RADIUS := 26.0
const PUDDLE_TIME := 7.0
const SLOP := Color("8c9a3c")
const SLOP_DARK := Color("4f5a1e")

var start := Vector2.ZERO
var landing := Vector2.ZERO
var player: Node2D
var _t := 0.0
var _landed := false
var _blobs: Array = []


func _ready() -> void:
	global_position = landing
	z_index = 2
	for i in 6:
		_blobs.append(Vector2(randf_range(-1, 1), randf_range(-0.5, 0.5)) * PUDDLE_RADIUS * 0.6)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if not _landed:
		if _t >= FLIGHT_TIME:
			_land()
		return
	if _t > PUDDLE_TIME:
		queue_free()
		return
	if is_instance_valid(player) and _flat_dist() < PUDDLE_RADIUS:
		player.slowed = 0.15


func _flat_dist() -> float:
	var d := player.global_position - global_position
	return Vector2(d.x, d.y * 2.0).length()


func _land() -> void:
	_landed = true
	_t = 0.0
	z_index = -5   # under everyone's feet, above the floor
	if is_instance_valid(player) and _flat_dist() < SPLASH_RADIUS:
		player.hit(global_position, 1, 120.0)


func _draw() -> void:
	if not _landed:
		var k := _t / FLIGHT_TIME
		# landing marker: a shadow that grows as the slop comes down
		_ellipse(Vector2.ZERO, SPLASH_RADIUS * (0.4 + 0.6 * k), Color(0, 0, 0, 0.18 + 0.3 * k))
		_ellipse_outline(Vector2.ZERO, SPLASH_RADIUS, Color(0.9, 0.95, 0.4, 0.25 + 0.4 * k))
		# the blob itself, flying in an arc from Willis's ladle
		var from := start - landing
		var p := from.lerp(Vector2.ZERO, k) + Vector2(0, -sin(k * PI) * 90.0 - 20.0 * (1.0 - k))
		draw_circle(p, 6.0, SLOP_DARK)
		draw_circle(p + Vector2(-1, -1), 4.5, SLOP)
		draw_circle(p + Vector2(-2, -2.5), 1.5, Color(1, 1, 0.8, 0.6))
		return
	var fade := clampf((PUDDLE_TIME - _t) / 1.0, 0.0, 1.0)
	var grow := minf(1.0, _t * 6.0)
	_ellipse(Vector2.ZERO, PUDDLE_RADIUS * grow, Color(SLOP_DARK, 0.85 * fade))
	for b: Vector2 in _blobs:
		_ellipse(b * grow, PUDDLE_RADIUS * 0.45 * grow, Color(SLOP, 0.8 * fade))
	# slow bubbles and a wet sheen
	for i in 3:
		var bp := Vector2(sin(_t * 1.3 + i * 2.1) * 12.0, cos(_t * 0.9 + i) * 4.0)
		draw_arc(bp, 1.5 + fmod(_t * 2.0 + i, 2.0), 0, TAU, 8, Color(0.9, 0.95, 0.6, 0.5 * fade), 1.0)
	draw_line(Vector2(-10, -3), Vector2(4, -5), Color(1, 1, 0.9, 0.25 * fade), 1.5)


func _ellipse(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.5))
	draw_colored_polygon(pts, color)


func _ellipse_outline(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 21:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.5))
	draw_polyline(pts, color, 1.5)
