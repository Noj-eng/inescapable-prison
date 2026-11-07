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
