extends Node2D
## Draws the concrete floor as isometric diamond tiles.

const TILE_W := 64.0
const TILE_H := 32.0

const COLOR_A := Color("3a4254")
const COLOR_B := Color("343b4b")
const GROUT := Color("272c38")

var cells: Array[Vector2] = []:
	set(value):
		cells = value
		queue_redraw()


var cracks: Array[PackedVector2Array] = []


## Splits the floor with jagged cracks spreading out from a point (the earthquake).
func add_cracks(center: Vector2, count: int) -> void:
	for i in count:
		var angle := randf() * TAU
		var p := center
		var line := PackedVector2Array([p])
		for step in randi_range(4, 7):
			angle += randf_range(-0.6, 0.6)
			p += Vector2(cos(angle), sin(angle) * 0.5) * randf_range(10, 20)
			line.append(p)
		cracks.append(line)
	queue_redraw()


func _draw() -> void:
	for cell in cells:
		var c := Vector2((cell.x - cell.y) * TILE_W * 0.5, (cell.x + cell.y) * TILE_H * 0.5)
		var pts := PackedVector2Array([
			c + Vector2(0, -TILE_H * 0.5),
			c + Vector2(TILE_W * 0.5, 0),
			c + Vector2(0, TILE_H * 0.5),
			c + Vector2(-TILE_W * 0.5, 0),
		])
		var checker := int(cell.x + cell.y) % 2 == 0
		draw_colored_polygon(pts, COLOR_A if checker else COLOR_B)
		pts.append(pts[0])
		draw_polyline(pts, GROUT, 1.0)
	for line in cracks:
		draw_polyline(line, Color("15181f"), 2.5)
		draw_polyline(line, Color("4c566c"), 0.8)
