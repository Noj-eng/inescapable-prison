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
##   v  a steam vent in the floor
##
## Edit a map, press Play, and the level rebuilds itself.

const TILE_W := 64.0  # width of one diamond tile in pixels
const TILE_H := 32.0  # height of one diamond tile in pixels

const LEVELS := [
	{
		"name": "CELL BLOCK C",
		"floor": "concrete",
		"map": [
			"###############",
			"#b..#b..#b..#E#",
			"#...#...#...#G#",
			"#t..#t..#t..#v#",
			"#BBB#B.B#BBB#.#",
			"#.............#",
			"#.....R...v...#",
			"#..d.....d....#",
			"#G...........M#",
			"###############",
		],
	},
	{
		"name": "LEVEL 2:  MESS HALL",
		"floor": "concrete",
		"map": [
			"###############",
			"#P............#",
			"#.dd..dd..dd.G#",
			"#......v......#",
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
		"floor": "steel",
		"map": [
			"###############",
			"#P....x...x...#",
			"#..o.....o..M.#",
			"#.....xx......#",
			"#M....v....c..#",
			"#..o..c..o....#",
			"#.....xx....G.#",
			"#.G...........#",
			"#.....M.....ME#",
			"###############",
		],
	},
	{
		"name": "LEVEL 4:  THE CAPTAIN'S YARD",
		"floor": "mixed",
		"map": [
			"#################",
			"#P..............#",
			"#...............#",
			"#..o.........o..#",
			"#.......v.......#",
			"#.........C.....#",
			"#...............#",
			"#..o.........o..#",
			"#.......v.......#",
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
const AtmosphereScript := preload("res://scripts/atmosphere.gd")
const NeonBarScript := preload("res://scripts/neon_bar.gd")
const ChromaLabelScript := preload("res://scripts/chroma_label.gd")
const SCANLINES := preload("res://shaders/scanlines.gdshader")

var level_index := 0
var world: Node2D
var floor_node: Node2D
var rig: StaticBody2D
var lift: Node2D
var atmosphere: Node2D
var player: CharacterBody2D
var spawns: Array = []          # [kind, screen position] for each enemy entrance
var enemies_left := 0
var game_over := false
var casings_at_level_start: Array = []
var _level_token := 0           # changes on every level load, so old timers know to stop

var hud: CanvasLayer
var title_label: Control
var message: Control
var restraint_pips: Array = []
var health_bar: Control
var boss_bar: Control
var boss_meter: Control
var alarm: ColorRect
var fade: ColorRect
var game_over_panel: Control


## Converts a grid cell (column, row) into the screen position of that tile's centre.
static func grid_to_screen(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * TILE_W * 0.5, (cell.x + cell.y) * TILE_H * 0.5)


func _ready() -> void:
	# Darken the whole world so the lamps, beacons and glows do the lighting.
	var dark := CanvasModulate.new()
	dark.color = Color(0.36, 0.38, 0.47)
	add_child(dark)

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
	if atmosphere:
		atmosphere.queue_free()

	var level: Dictionary = LEVELS[index]
	var map: Array = level["map"]
	var rows := map.size()
	var cols: int = map[0].length()

	# The floor is drawn first, underneath everything.
	floor_node = Node2D.new()
	floor_node.set_script(FloorScript)
	floor_node.z_index = -10
	floor_node.theme = level.get("floor", "concrete")
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
	var vents: Array = []
	var lamps: Array = []
	var bounds := Rect2(grid_to_screen(Vector2(0, 0)), Vector2.ZERO)
	for y in rows:
		for x in cols:
			var ch: String = map[y][x]
			var cell := Vector2(x, y)
			var at := grid_to_screen(cell)
			if ch != "#":
				floor_cells.append(cell)
				bounds = bounds.expand(at)
				if x % 5 == 2 and y % 4 == 2:
					lamps.append(at)
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
				"v":
					floor_node.vents.append(cell)
					vents.append(at)
	floor_node.cells = floor_cells

	atmosphere = Node2D.new()
	atmosphere.set_script(AtmosphereScript)
	add_child(atmosphere)
	var beacons := [grid_to_screen(Vector2(1, 1)) + Vector2(0, -60), grid_to_screen(Vector2(cols - 2, rows - 2)) + Vector2(0, -20)]
	atmosphere.setup(bounds, lamps, vents, beacons, index > 0)

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
	block.seed_value = hash(at)
	block.position = at
	world.add_child(block)
	floor_node.add_shadow(block.shadow_polygon())


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
	boss_meter.value = 1.0
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
	boss_meter.value = float(hp) / max_hp


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
	restraint_pips[piece].value = 0.0
	_say("CASING CRACKED", Color("5ff3ff"), 1.0)


func _on_health_changed(hp: int, max_hp: int) -> void:
	health_bar.value = float(hp) / max_hp


func _on_player_died() -> void:
	game_over = true
	await get_tree().create_timer(1.0).timeout
	game_over_panel.visible = true


func _retry() -> void:
	game_over = false
	game_over_panel.visible = false
	player.revive(player.MAX_HP, casings_at_level_start)
	for i in 4:
		restraint_pips[i].value = 0.0 if player.broken[i] else 1.0
	_on_health_changed(player.hp, player.MAX_HP)
	_load_level(level_index)


func _start_alarm() -> void:
	atmosphere.set_alarm(true)
	alarm.visible = true
	var tween := create_tween().set_loops()
	tween.tween_property(alarm, "color:a", 0.06, 0.6)
	tween.tween_property(alarm, "color:a", 0.0, 0.6)


# --- HUD ------------------------------------------------------------------------
## A sleek monitor-style HUD: thin segmented neon meters, monospace text with a
## slight colour split, and faint scanlines over the whole screen.

const HUD_DIM := Color(0.62, 0.7, 0.82, 0.75)
const NEON_CYAN := Color("4ff0ff")


func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)

	alarm = ColorRect.new()
	alarm.color = Color(1, 0.1, 0.1, 0.0)
	alarm.size = Vector2(1280, 720)
	alarm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alarm.visible = false
	hud.add_child(alarm)

	title_label = _chroma("", Vector2(28, 20), Vector2(600, 30), 20, Color("ffd23f"))
	_chroma("MOVE [WASD]   SLAM [SPACE]   FIRE [CLICK/F]", Vector2(28, 48), Vector2(600, 20), 12, HUD_DIM)

	# Health meter
	_chroma("VITALS", Vector2(28, 76), Vector2(200, 16), 11, HUD_DIM)
	health_bar = _neon_bar(Vector2(28, 94), Vector2(220, 16), Color("ff3d6e"), 20)

	# Restraint gauge: one segment per casing, lit while it's still locked on.
	_chroma("RESTRAINTS", Vector2(1068, 20), Vector2(190, 16), 11, HUD_DIM)
	var names := ["L.ARM", "R.ARM", "L.LEG", "R.LEG"]
	for i in 4:
		var pip := _neon_bar(Vector2(1068 + i * 48, 40), Vector2(44, 14), NEON_CYAN, 1)
		restraint_pips.append(pip)
		_chroma(names[i], Vector2(1068 + i * 48, 56), Vector2(44, 14), 10, HUD_DIM)

	# Boss meter, top centre, hidden until the captain shows up.
	boss_bar = Control.new()
	boss_bar.position = Vector2(390, 18)
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(boss_bar)
	var boss_name := _chroma("// CAPTAIN BRASK //", Vector2.ZERO, Vector2(500, 20), 15, Color("ff7a4a"), boss_bar)
	boss_name.align = HORIZONTAL_ALIGNMENT_CENTER
	for l in boss_name.get_children():
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_meter = _neon_bar(Vector2(0, 24), Vector2(500, 14), Color("ff5a2e"), 40, boss_bar)
	boss_bar.visible = false

	message = _chroma("", Vector2(0, 570), Vector2(1280, 90), 20, Color.WHITE)
	for l in message.get_children():
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Black fade used between levels
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.size = Vector2(1280, 720)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fade)

	# Game over screen
	game_over_panel = ColorRect.new()
	game_over_panel.color = Color(0.03, 0.01, 0.03, 0.82)
	game_over_panel.size = Vector2(1280, 720)
	game_over_panel.visible = false
	hud.add_child(game_over_panel)
	var big := _chroma("CONTAINED", Vector2(0, 270), Vector2(1280, 80), 64, Color("ff3d5a"), game_over_panel)
	for l in big.get_children():
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _chroma("> PRESS R TO RETRY THIS LEVEL_", Vector2(0, 360), Vector2(1280, 30), 18, HUD_DIM, game_over_panel)
	for l in hint.get_children():
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Scanlines and vignette over everything (its own layer, on top).
	var crt_layer := CanvasLayer.new()
	crt_layer.layer = 10
	add_child(crt_layer)
	var crt := ColorRect.new()
	crt.size = Vector2(1280, 720)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SCANLINES
	crt.material = m
	crt_layer.add_child(crt)


func _chroma(text: String, pos: Vector2, box: Vector2, font_size: int, color: Color, parent: Node = null) -> Control:
	var label := Control.new()
	label.set_script(ChromaLabelScript)
	label.position = pos
	label.size = box
	label.font_size = font_size
	label.color = color
	label.text = text
	(parent if parent else hud).add_child(label)
	return label


func _neon_bar(pos: Vector2, box: Vector2, color: Color, segments: int, parent: Node = null) -> Control:
	var bar := Control.new()
	bar.set_script(NeonBarScript)
	bar.position = pos
	bar.size = box
	bar.color = color
	bar.segments = segments
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else hud).add_child(bar)
	return bar


var _message_tween: Tween

## Shows a line of text at the bottom of the screen, then fades it out.
func _say(text: String, color: Color, seconds: float) -> void:
	if _message_tween:
		_message_tween.kill()
	message.text = text
	message.color = color
	message.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(seconds)
	_message_tween.tween_property(message, "modulate:a", 0.0, 0.8)
