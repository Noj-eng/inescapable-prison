extends Node2D
## Builds the starter cell block from the text map below.
##
## Map legend:
##   #  wall          B  cell bars       .  floor
##   b  bunk          t  toilet          d  table
##   P  where the villain starts (on floor)
##
## Edit the map, press Play, and the room rebuilds itself.

const TILE_W := 64.0  # width of one diamond tile in pixels
const TILE_H := 32.0  # height of one diamond tile in pixels

const MAP := [
	"###############",
	"#b..#b..#b..#.#",
	"#...#...#...#.#",
	"#t..#tP.#t..#.#",
	"#BBB#B.B#BBB#.#",
	"#.............#",
	"#.............#",
	"#..d.....d....#",
	"#.............#",
	"###############",
]

const BlockScript := preload("res://scripts/block.gd")
const FloorScript := preload("res://scripts/floor.gd")
const PlayerScript := preload("res://scripts/player.gd")

var world: Node2D


## Converts a grid cell (column, row) into the screen position of that tile's centre.
static func grid_to_screen(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * TILE_W * 0.5, (cell.x + cell.y) * TILE_H * 0.5)


func _ready() -> void:
	var rows := MAP.size()
	var cols: int = MAP[0].length()

	# The floor is drawn first, underneath everything.
	var floor_node := Node2D.new()
	floor_node.set_script(FloorScript)
	floor_node.name = "Floor"
	floor_node.z_index = -10
	add_child(floor_node)

	# Everything that stands up goes in a Y-sorted world, so things lower on
	# the screen are drawn in front of things higher up.
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)

	var floor_cells: Array[Vector2] = []
	var start := Vector2.ZERO
	for y in rows:
		for x in cols:
			var ch: String = MAP[y][x]
			var cell := Vector2(x, y)
			if ch != "#":
				floor_cells.append(cell)
			match ch:
				"#":
					# Walls on the front edge are kept short so they never hide the villain.
					# Back walls stand tall, inner walls are half height.
					var front := x == cols - 1 or y == rows - 1
					var back := x == 0 or y == 0
					_add_block("wall_low" if front else ("wall" if back else "wall_mid"), cell)
				"B":
					_add_block("bars", cell)
				"b":
					_add_block("bunk", cell)
				"t":
					_add_block("toilet", cell)
				"d":
					_add_block("table", cell)
				"P":
					start = cell
	floor_node.cells = floor_cells

	var player := CharacterBody2D.new()
	player.set_script(PlayerScript)
	player.name = "Villain"
	player.position = grid_to_screen(start)
	world.add_child(player)

	_build_hud()


func _add_block(kind: String, cell: Vector2) -> void:
	var block := StaticBody2D.new()
	block.set_script(BlockScript)
	block.kind = kind
	block.name = "%s_%d_%d" % [kind, cell.x, cell.y]
	block.position = grid_to_screen(cell)
	world.add_child(block)


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	var title := Label.new()
	title.text = "CELL BLOCK C"
	title.position = Vector2(24, 18)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("ffd23f"))
	hud.add_child(title)

	var help := Label.new()
	help.text = "Move: WASD or arrow keys"
	help.position = Vector2(24, 50)
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85, 0.8))
	hud.add_child(help)

	var intro := Label.new()
	intro.text = "Day 1.  No one has ever escaped.\n...Then again, who said anything about leaving?"
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.position = Vector2(0, 590)
	intro.size = Vector2(1280, 80)
	intro.add_theme_font_size_override("font_size", 20)
	intro.add_theme_color_override("font_color", Color(0.92, 0.9, 1.0))
	intro.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	intro.add_theme_constant_override("outline_size", 6)
	hud.add_child(intro)

	var tween := create_tween()
	intro.modulate.a = 0.0
	tween.tween_property(intro, "modulate:a", 1.0, 1.2)
	tween.tween_interval(3.5)
	tween.tween_property(intro, "modulate:a", 0.0, 1.5)
	tween.tween_callback(intro.queue_free)
