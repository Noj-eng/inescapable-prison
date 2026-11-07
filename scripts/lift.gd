extends Node2D
## The lift pad that takes the villain up to the next level of the prison.
## Locked (red) until every enemy on the level is down, then it turns green.

signal entered

var player: Node2D
var unlocked := false
var _t := 0.0
var _used := false
var _light: PointLight2D


func _ready() -> void:
	_light = preload("res://scripts/fx.gd").make_light(Color(1.0, 0.25, 0.25), 0.8, 0.5)
	_light.position = Vector2(0, -10)
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	_light.color = Color(0.3, 1.0, 0.5) if unlocked else Color(1.0, 0.25, 0.25)
	queue_redraw()
	if unlocked and not _used and is_instance_valid(player) and not player.dead:
		var d := player.global_position - global_position
		if Vector2(d.x, d.y * 2.0).length() < 24.0:
			_used = true
			entered.emit()


func _draw() -> void:
	var color := Color("4dff88") if unlocked else Color("ff4a4a")
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	_iso_disc(26.0, Color("1d2129"))
	_iso_ring(26.0, Color(color, 0.5 + 0.4 * pulse), 2.5)
	_iso_ring(18.0, Color(color, 0.3), 1.5)
	# chevrons pointing up
	for i in 3:
		var y := -4.0 - i * 6.0 - (pulse * 4.0 if unlocked else 0.0)
		draw_polyline(PackedVector2Array([Vector2(-7, y + 4), Vector2(0, y), Vector2(7, y + 4)]), Color(color, 0.9 - i * 0.25), 2.0)
	if unlocked:
		# light column
		draw_rect(Rect2(Vector2(-20, -70), Vector2(40, 70)), Color(color, 0.06 + 0.05 * pulse))


func _iso_disc(r: float, color: Color) -> void:
	draw_colored_polygon(_points(r), color)


func _iso_ring(r: float, color: Color, width: float) -> void:
	var pts := _points(r)
	pts.append(pts[0])
	draw_polyline(pts, color, width)


func _points(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.5))
	return pts
