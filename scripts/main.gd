extends Node2D
## Runs the whole game: builds each level of the prison from a text map,
## plays the earthquake opening, sends in guards and robots, and moves the
## villain up level by level until the guard captain.
##
## Map legend:
##   #  wall          B  cell bars       .  floor
##   b  bunk          t  toilet          d  table
##   x  crate         o  pillar          c  security console
##   P  where the villain starts the level
##   R  the containment rig (the villain starts inside it)
##   E  the lift to the next level (unlocks when the level is clear)
##   G  a guard comes in here     M  a security robot comes in here
##   C  Captain Brask, the first boss
##
## Edit a map, press Play, and the level rebuilds itself.

const TILE_W := 64.0  # width of one diamond tile in pixels
const TILE_H := 32.0  # height of one diamond tile in pixels

const LEVELS := [
	{
		"name": "CELL BLOCK C",
		"map": [
			"###############",
			"#b..#b..#b..#E#",
			"#...#...#...#G#",
			"#t..#t..#t..#.#",
			"#BBB#B.B#BBB#.#",
			"#.............#",
			"#.....R.......#",
			"#..d.....d....#",
			"#G...........M#",
			"###############",
		],
	},
	{
		"name": "LEVEL 2:  MESS HALL",
		"map": [
			"###############",
			"#P............#",
			"#.dd..dd..dd.G#",
			"#.............#",
			"#.dd..dd..dd..#",
			"#M............#",
			"#.dd..dd..dd..#",
			"#.......G.....#",
			"#G..........ME#",
			"###############",
		],
	},
	{
		"name": "LEVEL 3:  SECURITY WING",
		"map": [
			"###############",
			"#P....x...x...#",
			"#..o.....o..M.#",
			"#.....xx......#",
			"#M.........c..#",
			"#..o..c..o....#",
			"#.....xx....G.#",
			"#.G...........#",
			"#.....M.....ME#",
			"###############",
		],
	},
	{
		"name": "LEVEL 4:  THE CAPTAIN'S YARD",
		"map": [
			"#################",
			"#P..............#",
			"#...............#",
			"#..o.........o..#",
			"#...............#",
			"#.........C.....#",
			"#...............#",
			"#..o.........o..#",
			"#...............#",
			"#...............#",
			"#################",
		],
	},
]

const BlockScript := preload("res://scripts/block.gd")
const FloorScript := preload("res://scripts/floor.gd")
const PlayerScript := preload("res://scripts/player.gd")
const RigScript := preload("res://scripts/rig.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const BossScript := preload("res://scripts/boss.gd")
const LiftScript := preload("res://scripts/lift.gd")
const RiflePickupScript := preload("res://scripts/rifle_pickup.gd")

var level_index := 0
var world: Node2D
var floor_node: Node2D
var rig: StaticBody2D
var lift: Node2D
var player: CharacterBody2D
var spawns: Array = []          # [kind, screen position] for each enemy entrance
var enemies_left := 0
var game_over := false
var casings_at_level_start: Array = []
var _level_token := 0           # changes on every level load, so old timers know to stop

var hud: CanvasLayer
var title_label: Label
var message: Label
var restraint_pips: Array[ColorRect] = []
var health_fill: ColorRect
var boss_bar: Control
var boss_fill: ColorRect
var alarm: ColorRect
var fade: ColorRect
var game_over_panel: Control


## Converts a grid cell (column, row) into the screen position of that tile's centre.
static func grid_to_screen(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * TILE_W * 0.5, (cell.x + cell.y) * TILE_H * 0.5)


func _ready() -> void:
	player = CharacterBody2D.new()
	player.set_script(PlayerScript)
	player.name = "Villain"
	player.casing_broken.connect(_on_casing_broken)
	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	_build_hud()
	_load_level(0)


func _unhandled_input(event: InputEvent) -> void:
	if game_over and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_retry()


# --- Building a level -----------------------------------------------------------

func _load_level(index: int) -> void:
	level_index = index
	_level_token += 1
	enemies_left = 0
	spawns.clear()
	rig = null
	lift = null
	casings_at_level_start = player.broken.duplicate()

	if player.get_parent():
		player.get_parent().remove_child(player)
	if world:
		world.queue_free()
	if floor_node:
		floor_node.queue_free()

	var level: Dictionary = LEVELS[index]
	var map: Array = level["map"]
	var rows := map.size()
	var cols: int = map[0].length()

	# The floor is drawn first, underneath everything.
	floor_node = Node2D.new()
	floor_node.set_script(FloorScript)
	floor_node.z_index = -10
	add_child(floor_node)

	# Everything that stands up goes in a Y-sorted world, so things lower on
	# the screen are drawn in front of things higher up.
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)

	var floor_cells: Array[Vector2] = []
	var start := Vector2.ZERO
	var boss_at := Vector2.ZERO
	var has_boss := false
	var lift_at := Vector2.INF
	for y in rows:
		for x in cols:
			var ch: String = map[y][x]
			var cell := Vector2(x, y)
			var at := grid_to_screen(cell)
			if ch != "#":
				floor_cells.append(cell)
			match ch:
				"#":
					# Back walls stand tall, inner walls are half height, and walls on
					# the front edge are kept short so they never hide the villain.
					var front := x == cols - 1 or y == rows - 1
					var back := x == 0 or y == 0
					_add_block("wall_low" if front else ("wall" if back else "wall_mid"), at)
				"B": _add_block("bars", at)
				"b": _add_block("bunk", at)
				"t": _add_block("toilet", at)
				"d": _add_block("table", at)
				"x": _add_block("crate", at)
				"o": _add_block("pillar", at)
				"c": _add_block("console", at)
				"P", "R": start = at
				"G": spawns.append(["guard", at])
				"M": spawns.append(["robot", at])
				"C":
					boss_at = at
					has_boss = true
				"E": lift_at = at
	floor_node.cells = floor_cells

	if lift_at != Vector2.INF:
		# The lift lives on the floor layer, so it is cleared away with the level.
		lift = Node2D.new()
		lift.set_script(LiftScript)
		lift.position = lift_at
		lift.player = player
		lift.entered.connect(_on_lift_entered)
		floor_node.add_child(lift)

	if index == 0:
		# The containment rig sits a hair "behind" the villain so it draws first.
		rig = StaticBody2D.new()
		rig.set_script(RigScript)
		rig.name = "ContainmentRig"
		rig.position = start + Vector2(0, -1)
		world.add_child(rig)

	player.position = start
	if index > 0:
		player.held = false
		player.hover = 0.0
	world.add_child(player)
	player.snap_camera()

	title_label.text = level["name"]
	boss_bar.visible = false

	if index == 0:
		_run_opening()
	elif has_boss:
		_run_boss_intro(boss_at)
	else:
		_run_level_intro()


func _add_block(kind: String, at: Vector2) -> void:
	var block := StaticBody2D.new()
	block.set_script(BlockScript)
	block.kind = kind
	block.position = at
	world.add_child(block)


# --- Level scripts ----------------------------------------------------------------

## Waits, then returns false if the level changed while we were waiting.
func _wait(seconds: float) -> bool:
	var token := _level_token
	await get_tree().create_timer(seconds).timeout
	return token == _level_token and not game_over


func _run_opening() -> void:
	player.held = true
	player.hover = player.HOVER
	_say("Day 1.  No one has ever escaped.\n...Then again, who said anything about leaving?", Color(0.92, 0.9, 1.0), 3.5)
	if not await _wait(4.0): return

	# The earthquake: everything shakes, the floor splits, the rig shorts out.
	player.shake(7.0, 2.0)
	floor_node.add_cracks(rig.position, 7)
	rig.fail()
	_say("!!  SEISMIC EVENT  !!", Color("ffd23f"), 1.4)
	if not await _wait(0.8): return
	player.drop()

	if not await _wait(1.0): return
	_start_alarm()
	_say("CONTAINMENT FAILURE.  ALL UNITS TO CELL BLOCK C.", Color("ff5a5a"), 2.5)
	if not await _wait(1.5): return
	_spawn_wave()


func _run_level_intro() -> void:
	_say(LEVELS[level_index]["name"], Color("ffd23f"), 2.0)
	if not await _wait(1.5): return
	_spawn_wave()


func _run_boss_intro(at: Vector2) -> void:
	_say(LEVELS[level_index]["name"], Color("ffd23f"), 2.0)
	if not await _wait(2.5): return
	player.shake(5.0, 0.6)
	var boss := CharacterBody2D.new()
	boss.set_script(BossScript)
	boss.target = player
	boss.position = at
	world.add_child(boss)
	boss.health_changed.connect(_on_boss_health_changed)
	boss.defeated.connect(_on_boss_defeated)
	boss_fill.size.x = 496
	boss_bar.visible = true
	_say("CAPTAIN BRASK:  \"Back in the rig, inmate.\"\n(Lure his charge into a pillar to stun him.)", Color("ff8a5a"), 3.5)


func _spawn_wave() -> void:
	for spawn in spawns:
		var enemy := CharacterBody2D.new()
		enemy.set_script(EnemyScript)
		enemy.kind = spawn[0]
		enemy.target = player
		enemy.position = spawn[1]
		world.add_child(enemy)
		enemy.defeated.connect(_on_enemy_defeated)
		enemies_left += 1


func _on_enemy_defeated() -> void:
	enemies_left -= 1
	if enemies_left > 0:
		return
	# Level clear: a casing cracks off, the villain catches their breath, and the lift opens.
	player.break_next_casing()
	player.heal(4)
	if lift:
		lift.unlocked = true
	if not await _wait(1.2): return
	if level_index == LEVELS.size() - 2:
		_say("One casing left.  It won't crack for small fry.\nThe lift is open.  The captain is waiting.", Color("5ff3ff"), 4.0)
	else:
		_say("Level clear.  The lift is open.", Color("4dff88"), 3.0)


func _on_lift_entered() -> void:
	var token := _level_token
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.5)
	await tween.finished
	if token != _level_token:
		return
	_load_level(level_index + 1)
	create_tween().tween_property(fade, "color:a", 0.0, 0.6)


func _on_boss_health_changed(hp: int, max_hp: int) -> void:
	boss_fill.size.x = 496.0 * hp / max_hp


func _on_boss_defeated(at: Vector2) -> void:
	boss_bar.visible = false
	player.break_final_casing()
	_say("CAPTAIN BRASK IS DOWN.\nThe last casing shatters.", Color("5ff3ff"), 3.0)
	var rifle := Node2D.new()
	rifle.set_script(RiflePickupScript)
	rifle.position = at
	rifle.player = player
	rifle.picked_up.connect(_on_rifle_picked_up)
	world.add_child(rifle)


func _on_rifle_picked_up() -> void:
	_say("PLASMA RIFLE ACQUIRED\nClick or press F to fire.", Color("d9a8ff"), 4.0)
	if not await _wait(6.0): return
	_say("END OF DEMO\nThe second boss is still out there...", Color("ffd23f"), 6.0)


func _on_casing_broken(piece: int) -> void:
	restraint_pips[piece].color = Color("2a2f3a")
	_say("CASING CRACKED", Color("5ff3ff"), 1.0)


func _on_health_changed(hp: int, max_hp: int) -> void:
	health_fill.size.x = 196.0 * hp / max_hp


func _on_player_died() -> void:
	game_over = true
	await get_tree().create_timer(1.0).timeout
	game_over_panel.visible = true


func _retry() -> void:
	game_over = false
	game_over_panel.visible = false
	player.revive(player.MAX_HP, casings_at_level_start)
	for i in 4:
		restraint_pips[i].color = Color("2a2f3a") if player.broken[i] else Color("5ff3ff")
	_on_health_changed(player.hp, player.MAX_HP)
	_load_level(level_index)


func _start_alarm() -> void:
	alarm.visible = true
	var tween := create_tween().set_loops()
	tween.tween_property(alarm, "color:a", 0.12, 0.6)
	tween.tween_property(alarm, "color:a", 0.0, 0.6)


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

	title_label = _label("", Vector2(24, 18), 22, Color("ffd23f"))
	_label("Move: WASD or arrow keys     Slam: Space", Vector2(24, 50), 14, Color(0.75, 0.78, 0.85, 0.8))

	# Health bar
	_label("HEALTH", Vector2(24, 76), 12, Color(0.75, 0.78, 0.85, 0.8))
	var health_back := ColorRect.new()
	health_back.color = Color("1a1d24")
	health_back.position = Vector2(24, 96)
	health_back.size = Vector2(200, 14)
	hud.add_child(health_back)
	health_fill = ColorRect.new()
	health_fill.color = Color("e8574a")
	health_fill.position = Vector2(26, 98)
	health_fill.size = Vector2(196, 10)
	hud.add_child(health_fill)

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

	# Boss bar, top centre, hidden until the captain shows up.
	boss_bar = Control.new()
	boss_bar.position = Vector2(390, 22)
	hud.add_child(boss_bar)
	var boss_name := Label.new()
	boss_name.text = "CAPTAIN BRASK"
	boss_name.size = Vector2(500, 20)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name.add_theme_font_size_override("font_size", 16)
	boss_name.add_theme_color_override("font_color", Color("ff8a5a"))
	boss_bar.add_child(boss_name)
	var boss_back := ColorRect.new()
	boss_back.color = Color("1a1d24")
	boss_back.position = Vector2(0, 26)
	boss_back.size = Vector2(500, 14)
	boss_bar.add_child(boss_back)
	boss_fill = ColorRect.new()
	boss_fill.color = Color("d93a3a")
	boss_fill.position = Vector2(2, 28)
	boss_fill.size = Vector2(496, 10)
	boss_bar.add_child(boss_fill)
	boss_bar.visible = false

	message = _label("", Vector2(0, 580), 20, Color.WHITE)
	message.size = Vector2(1280, 80)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	message.add_theme_constant_override("outline_size", 6)

	# Black fade used between levels
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.size = Vector2(1280, 720)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fade)

	# Game over screen
	game_over_panel = ColorRect.new()
	game_over_panel.color = Color(0.03, 0.02, 0.04, 0.8)
	game_over_panel.size = Vector2(1280, 720)
	game_over_panel.visible = false
	hud.add_child(game_over_panel)
	var big := Label.new()
	big.text = "CONTAINED"
	big.position = Vector2(0, 270)
	big.size = Vector2(1280, 80)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_font_size_override("font_size", 64)
	big.add_theme_color_override("font_color", Color("ff4a4a"))
	game_over_panel.add_child(big)
	var hint := Label.new()
	hint.text = "Press R to try this level again"
	hint.position = Vector2(0, 360)
	hint.size = Vector2(1280, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	game_over_panel.add_child(hint)


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
