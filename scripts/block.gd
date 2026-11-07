extends StaticBody2D
## One solid thing in the prison: a wall, cell bars, or a piece of furniture.
## It draws itself with simple shapes and adds its own collision, so the
## villain bumps into it. Swap the drawing for real sprites later.

const TILE_W := 64.0
const TILE_H := 32.0

var kind := "wall"


func _ready() -> void:
	var footprint := 1.0
	match kind:
		"bunk": footprint = 0.8
		"toilet": footprint = 0.45
		"table": footprint = 0.7
	var shape := CollisionPolygon2D.new()
	shape.polygon = _diamond(footprint, 0.0)
	add_child(shape)
	queue_redraw()


func _draw() -> void:
	match kind:
		"wall":
			_draw_box(1.0, 56.0, Color("4b5468"), Color("2b3141"), Color("373e51"))
			_draw_top_edge(1.0, 56.0, Color("5d6780"))
		"wall_mid":
			_draw_box(1.0, 30.0, Color("4b5468"), Color("2b3141"), Color("373e51"))
			_draw_top_edge(1.0, 30.0, Color("5d6780"))
		"wall_low":
			_draw_box(1.0, 10.0, Color("4b5468"), Color("2b3141"), Color("373e51"))
		"bars":
			_draw_bars()
		"bunk":
			_draw_box(0.8, 12.0, Color("5b4636"), Color("3c2e24"), Color("4a392c"))
			_draw_box(0.7, 18.0, Color("7d2f3c"), Color("57202a"), Color("6a2833"))
			# pillow
			var p := Vector2(-12, -21)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4), p + Vector2(8, 0), p + Vector2(0, 4), p + Vector2(-8, 0)]), Color("d9d6cf"))
		"toilet":
			_draw_box(0.45, 12.0, Color("c9ccd3"), Color("8e939e"), Color("a9aeb8"))
			draw_circle(Vector2(0, -12), 4.0, Color("6c7380"))
		"table":
			_draw_box(0.7, 18.0, Color("8a6a48"), Color("5e4630"), Color("72563b"))


## A diamond the shape of a tile, scaled by s, lifted up by h pixels.
func _diamond(s: float, h: float) -> PackedVector2Array:
	var hw := TILE_W * 0.5 * s
	var hh := TILE_H * 0.5 * s
	return PackedVector2Array([
		Vector2(0, -hh - h), Vector2(hw, -h), Vector2(0, hh - h), Vector2(-hw, -h)
	])


func _draw_box(s: float, h: float, top: Color, left: Color, right: Color) -> void:
	var base := _diamond(s, 0.0)
	var lid := _diamond(s, h)
	# left face: left corner -> bottom corner
	draw_colored_polygon(PackedVector2Array([base[3], base[2], lid[2], lid[3]]), left)
	# right face: bottom corner -> right corner
	draw_colored_polygon(PackedVector2Array([base[2], base[1], lid[1], lid[2]]), right)
	draw_colored_polygon(lid, top)


func _draw_top_edge(s: float, h: float, color: Color) -> void:
	var lid := _diamond(s, h)
	draw_polyline(PackedVector2Array([lid[3], lid[2], lid[1]]), color, 1.5)


func _draw_bars() -> void:
	# Bars run along the row, from the tile's upper-left edge to its lower-right edge.
	var a := Vector2(-TILE_W * 0.25, -TILE_H * 0.25)
	var b := Vector2(TILE_W * 0.25, TILE_H * 0.25)
	var h := 56.0
	var steel := Color("8a93a6")
	var shade := Color("1c2029")
	# floor rail and top rail
	draw_line(a + Vector2(-16, -8), b + Vector2(16, 8), shade, 5.0)
	draw_line(a + Vector2(-16, -8 - h), b + Vector2(16, 8 - h), shade, 6.0)
	draw_line(a + Vector2(-16, -8 - h), b + Vector2(16, 8 - h), steel, 3.0)
	for i in 5:
		var t := float(i) / 4.0
		var p := (a + Vector2(-16, -8)).lerp(b + Vector2(16, 8), t * 0.9 + 0.05)
		draw_line(p, p + Vector2(0, -h), shade, 4.0)
		draw_line(p + Vector2(-0.5, 0), p + Vector2(-0.5, -h), steel, 2.0)
