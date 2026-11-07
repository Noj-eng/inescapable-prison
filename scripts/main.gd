extends Node2D
## Builds Cell Block C from the text map below and runs the opening:
## the villain hangs in the containment rig, an earthquake shorts it out,
## alarms blare, and guards and robots close in.
##
## Map legend:
##   #  wall          B  cell bars       .  floor
##   b  bunk          t  toilet          d  table
##   R  the containment rig, where the villain starts the game
##   G  a guard comes in here     M  a security robot comes in here
##
## Edit the map, press Play, and the room rebuilds itself.

const TILE_W := 64.0  # width of one diamond tile in pixels
const TILE_H := 32.0  # height of one diamond tile in pixels

const QUAKE_DELAY := 4.0   # seconds of calm before the earthquake hits

const MAP := [
	"###############",
	"#b..#b..#b..#G#",
	"#...#...#...#.#",
	"#t..#t..#t..#.#",
	"#BBB#B.B#BBB#.#",
	"#.............#",
	"#.....R.......#",
	"#..d.....d....#",
	"#G...........M#",
	"###############",
]

const BlockScript := preload("res://scripts/block.gd")
const FloorScript := preload("res://scripts/floor.gd")
const PlayerScript := preload("res://scripts/player.gd")
const RigScript := preload("res://scripts/rig.gd")
const EnemyScript := preload("res://scripts/enemy.gd")

var world: Node2D
var floor_node: Node2D
var rig: StaticBody2D
var player: CharacterBody2D
var spawns: Array = []         # [kind, screen position] for each enemy entrance
var enemies_left := 0

var hud: CanvasLayer
var message: Label
var restraint_pips: Array[ColorRect] = []
var alarm: ColorRect


## Converts a grid cell (column, row) into the screen position of that tile's centre.
static func grid_to_screen(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * TILE_W * 0.5, (cell.x + cell.y) * TILE_H * 0.5)


func _ready() -> void:
	_build_level()
	_build_hud()
	_run_opening()


func _build_level() -> void:
	var rows := MAP.size()
	var cols: int = MAP[0].length()

	# The floor is drawn first, underneath everything.
	floor_node = Node2D.new()
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
					# Back walls stand tall, inner walls are half height, and walls on
					# the front edge are kept short so they never hide the villain.
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
				"R":
					start = cell
				"G":
					spawns.append(["guard", grid_to_screen(cell)])
				"M":
					spawns.append(["robot", grid_to_screen(cell)])
	floor_node.cells = floor_cells

	# The containment rig sits a hair "behind" the villain so it draws first.
	rig = StaticBody2D.new()
	rig.set_script(RigScript)
	rig.name = "ContainmentRig"
	rig.position = grid_to_screen(start) + Vector2(0, -1)
	world.add_child(rig)

	player = CharacterBody2D.new()
	player.set_script(PlayerScript)
	player.name = "Villain"
	player.position = grid_to_screen(start)
	world.add_child(player)
	player.casing_broken.connect(_on_casing_broken)


func _add_block(kind: String, cell: Vector2) -> void:
	var block := StaticBody2D.new()
	block.set_script(BlockScript)
	block.kind = kind
	block.name = "%s_%d_%d" % [kind, cell.x, cell.y]
	block.position = grid_to_screen(cell)
	world.add_child(block)


# --- The opening sequence -----------------------------------------------------

func _run_opening() -> void:
	_say("Day 1.  No one has ever escaped.\n...Then again, who said anything about leaving?", Color(0.92, 0.9, 1.0), 3.5)
	await get_tree().create_timer(QUAKE_DELAY).timeout

	# The earthquake: everything shakes, the floor splits, the rig shorts out.
	player.shake(7.0, 2.0)
	floor_node.add_cracks(rig.position, 7)
	rig.fail()
	_say("!!  SEISMIC EVENT  !!", Color("ffd23f"), 1.4)
	await get_tree().create_timer(0.8).timeout
	player.drop()

	await get_tree().create_timer(1.0).timeout
	_start_alarm()
	_say("CONTAINMENT FAILURE.  ALL UNITS TO CELL BLOCK C.", Color("ff5a5a"), 2.5)

	await get_tree().create_timer(1.5).timeout
	for spawn in spawns:
		_spawn_enemy(spawn[0], spawn[1])


func _spawn_enemy(kind: String, at: Vector2) -> void:
	var enemy := CharacterBody2D.new()
	enemy.set_script(EnemyScript)
	enemy.kind = kind
	enemy.target = player
	enemy.position = at
	world.add_child(enemy)
	enemy.defeated.connect(_on_enemy_defeated)
	enemies_left += 1


func _on_enemy_defeated() -> void:
	enemies_left -= 1
	player.break_next_casing()
	if enemies_left == 0:
		await get_tree().create_timer(1.2).timeout
		_say("One casing left.  It won't crack for small fry.\nSomething big is coming...", Color("5ff3ff"), 4.0)


func _on_casing_broken(piece: int) -> void:
	restraint_pips[piece].color = Color("2a2f3a")
	_say("CASING CRACKED", Color("5ff3ff"), 1.0)


func _start_alarm() -> void:
	alarm.visible = true
	var tween := create_tween().set_loops()
	tween.tween_property(alarm, "color:a", 0.16, 0.5)
	tween.tween_property(alarm, "color:a", 0.0, 0.5)


# --- HUD ------------------------------------------------------------------------

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)

	alarm = ColorRect.new()
	alarm.color = Color(1, 0.1, 0.1, 0.0)
	alarm.size = Vector2(1280, 720)
	alarm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alarm.visible = false
	hud.add_child(alarm)

	var title := _label("CELL BLOCK C", Vector2(24, 18), 22, Color("ffd23f"))
	title.size = Vector2(300, 30)
	_label("Move: WASD or arrow keys     Slam: Space", Vector2(24, 50), 14, Color(0.75, 0.78, 0.85, 0.8))

	# Restraint gauge: one pip per casing, cyan while it's still locked on.
	_label("RESTRAINTS", Vector2(1080, 18), 14, Color(0.75, 0.78, 0.85, 0.8))
	var names := ["L ARM", "R ARM", "L LEG", "R LEG"]
	for i in 4:
		var pip := ColorRect.new()
		pip.color = Color("5ff3ff")
		pip.position = Vector2(1080 + i * 44, 40)
		pip.size = Vector2(38, 10)
		hud.add_child(pip)
		restraint_pips.append(pip)
		_label(names[i], Vector2(1080 + i * 44, 52), 10, Color(0.75, 0.78, 0.85, 0.7))

	message = _label("", Vector2(0, 580), 20, Color.WHITE)
	message.size = Vector2(1280, 80)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	message.add_theme_constant_override("outline_size", 6)


func _label(text: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	hud.add_child(label)
	return label


var _message_tween: Tween

## Shows a line of text at the bottom of the screen, then fades it out.
func _say(text: String, color: Color, seconds: float) -> void:
	if _message_tween:
		_message_tween.kill()
	message.text = text
	message.add_theme_color_override("font_color", color)
	message.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(seconds)
	_message_tween.tween_property(message, "modulate:a", 0.0, 0.8)
