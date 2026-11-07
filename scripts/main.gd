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
##   K  Turkey, the merchant in solitary
##   N  Nurse Greta, who patches you up
##   W  Captain Willis (boss of Mess Hall B). On his level, G and M mark
##      where his squad pours in from the kitchen.
##   v  a steam vent in the floor
##   w  a severed live wire hanging from the ceiling
##
## Levels are bigger than the screen: the camera follows the villain, and
## enemies wait in their own area until he gets close.
##
## Edit a map, press Play, and the level rebuilds itself.

const TILE_W := 64.0  # width of one diamond tile in pixels
const TILE_H := 32.0  # height of one diamond tile in pixels

const LEVELS := [
	{
		"name": "CELL BLOCK C",
		"floor": "concrete",
		"map": [
			"################################",
			"#b..#b..#b..#b..################",
			"#...#...#...#...#####..........#",
			"#t..#t..#t..#t..#####..........#",
			"#BBB#BBB#BBB#B.B#####..cc..c...#",
			"#................####..........#",
			"#..............v.####.......G..#",
			"#..G.............####...Go.....#",
			"#..............................#",
			"#.......R.................v....#",
			"#.............M........x.....x.#",
			"#...d.......d....####......Mxx.#",
			"#................####..........#",
			"######...################..#####",
			"#..............######..........#",
			"#......o....G..######......x.M.#",
			"#..xx.....xx...######..xx......#",
			"#......v...............x..o....#",
			"#..xx..........................#",
			"#....M...M..v..######.G..G..xE.#",
			"#..............######..........#",
			"################################",
		],
	},
	{
		"name": "LEVEL 2:  MESS HALL",
		"floor": "concrete",
		"map": [
			"##################################",
			"#......##................##......#",
			"#.P...................v..##.dddd.#",
			"#..........dddd..dddd....##......#",
			"#......##....................GM..#",
			"#########...G....................#",
			"#########..dddd..dddd....##...cc.#",
			"#########................##......#",
			"#########......o...M..o..##.v..M.#",
			"#########..dddd..dddd....##...c..#",
			"#########................##....x.#",
			"#########....G...........##......#",
			"#########..dddd..dddd....####..###",
			"#########............G...####..###",
			"#########........................#",
			"############..########.....G...x.#",
			"############..########..xx..xx...#",
			"#.......................x........#",
			"#..G.....x........G.......v......#",
			"#...xx.........xx...........xx...#",
			"#......M....v...........x........#",
			"#.E......x.............G......M..#",
			"#................................#",
			"##################################",
		],
	},
	{
		"name": "LEVEL 3:  SECURITY WING",
		"floor": "steel",
		"map": [
			"##################################",
			"#.....####.......................#",
			"#.P...####......M..............x.#",
			"#...........c.c.c.c....xx..xx....#",
			"#.....####.............x......M..#",
			"#.....####........M..........c...#",
			"##..######..G..o..........M......#",
			"##..######.........v...G...x...x.#",
			"##..######.......................#",
			"##..##########..#####............#",
			"##..##########..############..####",
			"##..####...............#####..####",
			"##.G####..o..o..o..o...#####..####",
			"##..####.M...M...................#",
			"##..####........v...G.......G....#",
			"##..####..o..o..o..o...###.......#",
			"##..####...............###.BB.BB.#",
			"#................................#",
			"#............o.....v........o....#",
			"#....o........G......o........M..#",
			"#........o.......o............v..#",
			"#.E...M....v........M......G.....#",
			"#................................#",
			"##################################",
		],
	},
	{
		"name": "THE CAPTAIN'S YARD",
		"floor": "mixed",
		"boss": true,
		"map": [
			"########################",
			"#......................#",
			"#.P....................#",
			"#..........v...........#",
			"#....o............o....#",
			"#......................#",
			"#.......v.......w......#",
			"#......................#",
			"#..........o...........#",
			"#......w.....C.........#",
			"#......................#",
			"#..............v.......#",
			"#......................#",
			"#....o............o....#",
			"#........v....w........#",
			"#......................#",
			"#.....................E#",
			"########################",
		],
	},
	{
		"name": "SOLITARY CONFINEMENT",
		"floor": "steel",
		"map": [
			"######################################",
			"#b..t#b..t#b..t#b..t#b..t#b..t#b..t#b#",
			"#....#....#..G.#....#....#.M..#....#.#",
			"#....#....#....#....#....#....#....#.#",
			"##BB###BB###..###BB###BB###..###BB####",
			"#.........w..........................#",
			"#.......o.......o....G..o........w...#",
			"#..........G.................G.......#",
			"#.P................v................E#",
			"#.....v.......M........G..v..........#",
			"#.......o.......o.......o.....G......#",
			"#.....................w..............#",
			"##BB###BB###BB###..###BB###BB###....##",
			"#....#....#....#....#....#....#......#",
			"#....#....#....#..G.#....#....#...K..#",
			"#b..t#b..t#b..t#b..t#b..t#b..t#b.x..t#",
			"######################################",
		],
	},
	{
		"name": "THE MEDICAL WING",
		"floor": "concrete",
		"map": [
			"####################################",
			"#.c..c..c..c#.c..c..c..c#.c..c..c..#",
			"#.b..b..b..b#.b..b..b..b#.b..b..b..#",
			"#...G.......#....G......#.....G....#",
			"#..v........#.......M...#...G......#",
			"#.b..b..b..b#.b..b..b..b#.b..b..b..#",
			"#...........#...........#..........#",
			"#####..##########..##########..#####",
			"#...................w..............#",
			"#......v.o....G......o.....o.......#",
			"#.P......................v.....G...#",
			"#..........w...........M...........#",
			"#..................................#",
			"#####..##########..##########..#####",
			"#...........#...........#..........#",
			"#.xx........#..c...M.c..#........c.#",
			"#.x.........#...........#..dddd....#",
			"#.....G.....#....dd.....#...N......#",
			"#.........x.#...G.......#..........#",
			"#...x....xx.#..c...w.c..#.b..E..b..#",
			"#...........#...........#..........#",
			"####################################",
		],
	},
	{
		"name": "MESS HALL B",
		"floor": "mixed",
		"boss": true,
		"map": [
			"################################",
			"#..xx.....xx.......xx......xx..#",
			"#....M..v....v........v...M....#",
			"#.....G........G........G......#",
			"#..............................#",
			"#xcxcx..cxcxcxc..xcxcxcx..cxcxc#",
			"#..............................#",
			"#...........G...W...G..........#",
			"#..............................#",
			"#..ddddddd..ddddddd..ddddddd...#",
			"#........................w.....#",
			"#.v.......o.........o..........#",
			"#..............................#",
			"#..ddddddd..ddddddd..ddddddd...#",
			"#..............................#",
			"#.........o.........o........v.#",
			"#..............................#",
			"#..ddddddd..ddddddd..ddddddd...#",
			"#..............................#",
			"#...............v..............#",
			"#.......w......................#",
			"#..P........................E..#",
			"#..............................#",
			"################################",
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
const KeyPickupScript := preload("res://scripts/key_pickup.gd")
const AtmosphereScript := preload("res://scripts/atmosphere.gd")
const NeonBarScript := preload("res://scripts/neon_bar.gd")
const ChromaLabelScript := preload("res://scripts/chroma_label.gd")
const SCANLINES := preload("res://shaders/scanlines.gdshader")
const LiveWireScript := preload("res://scripts/live_wire.gd")
const XpOrbScript := preload("res://scripts/xp_orb.gd")
const LevelUpScript := preload("res://scripts/level_up.gd")
const TurkeyScript := preload("res://scripts/turkey.gd")
const ShopScript := preload("res://scripts/shop.gd")
const GretaScript := preload("res://scripts/greta.gd")
const WillisScript := preload("res://scripts/willis.gd")

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
var player_at_level_start: Dictionary = {}
var level_up_screen: CanvasLayer
var shop: CanvasLayer
var turkey: Node2D
var greta: Node2D
var willis: Node2D
var boss_name_label: Control
var smokes_label: Control
var _pending_level_ups := 0
var _aftershock_timer := 20.0
var _total_enemies := 0
var hostiles_label: Control
var xp_bar: Control
var level_label: Control
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
	player.xp_changed.connect(_on_xp_changed)
	player.leveled_up.connect(_on_leveled_up)
	level_up_screen = CanvasLayer.new()
	level_up_screen.set_script(LevelUpScript)
	level_up_screen.chosen.connect(_on_ability_chosen)
	add_child(level_up_screen)
	player.smokes_changed.connect(_on_smokes_changed)
	shop = CanvasLayer.new()
	shop.set_script(ShopScript)
	shop.player = player
	shop.bought.connect(_on_shop_bought)
	add_child(shop)
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
	turkey = null
	greta = null
	willis = null
	shop.stock.clear()
	_total_enemies = 0
	_aftershock_timer = randf_range(16.0, 24.0)
	player_at_level_start = player.snapshot()

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
	var willis_at := Vector2.INF
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
					# Solid rock with no floor next to it is never seen, so skip it.
					if not _touches_floor(map, x, y):
						continue
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
				"W": willis_at = at
				"N":
					greta = StaticBody2D.new()
					greta.set_script(GretaScript)
					greta.position = at
					greta.player = player
					greta.patch_requested.connect(_on_patch_requested)
					world.add_child(greta)
				"K":
					turkey = StaticBody2D.new()
					turkey.set_script(TurkeyScript)
					turkey.position = at
					turkey.player = player
					turkey.trade_requested.connect(_on_trade_requested)
					world.add_child(turkey)
				"v":
					floor_node.vents.append(cell)
					vents.append(at)
				"w":
					var wire := Node2D.new()
					wire.set_script(LiveWireScript)
					wire.position = at
					world.add_child(wire)
	floor_node.cells = floor_cells

	atmosphere = Node2D.new()
	atmosphere.set_script(AtmosphereScript)
	add_child(atmosphere)
	var beacons := []
	for corner in [Vector2(1, 1), Vector2(cols - 2, 1), Vector2(1, rows - 2), Vector2(cols - 2, rows - 2), Vector2(cols / 2.0, rows / 2.0).floor()]:
		beacons.append(grid_to_screen(corner) + Vector2(0, -50))
	atmosphere.setup(bounds, lamps, vents, beacons, index > 0)
	_build_paths(map)

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
	player.set_camera_limits(bounds.grow(160))
	player.snap_camera()

	title_label.text = level["name"]
	boss_bar.visible = false
	_update_hostiles()

	if index == 0:
		_run_opening()
	elif turkey:
		_run_solitary_intro()
	elif greta:
		_say("THE MEDICAL WING\nThe drones here sedate first and ask questions never.", Color("ffd23f"), 3.5)
		_spawn_wave()
	elif willis_at != Vector2.INF:
		_run_willis_intro(willis_at)
	elif has_boss:
		_run_boss_intro(boss_at)
	else:
		_run_level_intro()


# --- Path finding: lets enemies walk around walls between rooms ------------------

const SOLID := "#Bbtdxoc"
var _astar: AStarGrid2D


func _build_paths(map: Array) -> void:
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, map[0].length(), map.size())
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for y in map.size():
		for x in map[0].length():
			if SOLID.contains(map[y][x]):
				_astar.set_point_solid(Vector2i(x, y))


static func screen_to_grid(p: Vector2) -> Vector2i:
	var gx := (p.x / (TILE_W * 0.5) + p.y / (TILE_H * 0.5)) * 0.5
	var gy := (p.y / (TILE_H * 0.5) - p.x / (TILE_W * 0.5)) * 0.5
	return Vector2i(roundi(gx), roundi(gy))


## Where to walk next to get from one point to another around the walls.
## Returns the goal itself when it's close or there is no path.
func path_next(from: Vector2, to: Vector2) -> Vector2:
	if _astar == null:
		return to
	var a := screen_to_grid(from)
	var b := screen_to_grid(to)
	if a == b or not _astar.is_in_boundsv(a) or not _astar.is_in_boundsv(b) or _astar.is_point_solid(a) or _astar.is_point_solid(b):
		return to
	var path := _astar.get_id_path(a, b)
	if path.size() <= 2:
		return to
	return grid_to_screen(Vector2(path[1]))


## How many steps apart two points are on foot (a big number if unreachable).
func path_length(from: Vector2, to: Vector2) -> int:
	if _astar == null:
		return 0
	var a := screen_to_grid(from)
	var b := screen_to_grid(to)
	if not _astar.is_in_boundsv(a) or not _astar.is_in_boundsv(b) or _astar.is_point_solid(a) or _astar.is_point_solid(b):
		return 999
	var path := _astar.get_id_path(a, b)
	return path.size() if path.size() > 0 else 999


func _touches_floor(map: Array, x: int, y: int) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var yy: int = y + dy
			var xx: int = x + dx
			if yy >= 0 and yy < map.size() and xx >= 0 and xx < map[0].length() and map[yy][xx] != "#":
				return true
	return false


func _add_block(kind: String, at: Vector2) -> void:
	var block := StaticBody2D.new()
	block.set_script(BlockScript)
	block.kind = kind
	block.seed_value = hash(at)
	block.position = at
	world.add_child(block)
	floor_node.add_shadow(block.shadow_polygon())


# --- Level scripts ----------------------------------------------------------------

## A shockwave: the floor ripples out from a point, and nearby walls and
## pillars shake (closer ones harder).
func shockwave(at: Vector2, strength: float, radius: float) -> void:
	floor_node.ripple(at, strength)
	for block in get_tree().get_nodes_in_group("shakeable"):
		var d: Vector2 = block.global_position - at
		var dist: float = Vector2(d.x, d.y * 2.0).length()
		if dist < radius * 2.5:
			block.impact(1.0 - dist / (radius * 2.5))


func _process(delta: float) -> void:
	if game_over or get_tree().paused or not floor_node:
		return
	# Every so often the earthquake rumbles on: an aftershock rolls through.
	_aftershock_timer -= delta
	if _aftershock_timer <= 0.0 and not player.held:
		var boss_level: bool = LEVELS[level_index].get("boss", false)
		_aftershock_timer = randf_range(10.0, 14.0) if boss_level else randf_range(18.0, 26.0)
		var at: Vector2 = player.global_position + Vector2(randf_range(-160, 160), randf_range(-80, 80))
		shockwave(at, 7.0, 320.0)
		player.shake(3.0, 0.8)
		_say("// AFTERSHOCK //", Color("ffd23f"), 1.0)


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
	shockwave(rig.position, 12.0, 600.0)
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
	_say(LEVELS[level_index]["name"] + "\nClear every area to open the lift.", Color("ffd23f"), 3.0)
	_spawn_wave()


func _run_solitary_intro() -> void:
	_say("SOLITARY CONFINEMENT\nThe quiet cells. Somebody down here is whistling.", Color("ffd23f"), 3.5)
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
	boss_name_label.text = "// CAPTAIN BRASK //"
	boss_bar.visible = true
	_say("CAPTAIN BRASK:  \"Back in the rig, inmate.\"\n(Lure his charge into a pillar to stun him.)", Color("ff8a5a"), 3.5)


func _run_willis_intro(at: Vector2) -> void:
	_say("MESS HALL B\nThe lunch rush is over.  Something smells wrong.", Color("ffd23f"), 2.5)
	if not await _wait(2.5): return
	willis = CharacterBody2D.new()
	willis.set_script(WillisScript)
	willis.target = player
	willis.position = at
	world.add_child(willis)
	willis.health_changed.connect(_on_boss_health_changed)
	willis.defeated.connect(_on_willis_defeated)
	willis.call_squad.connect(_on_willis_call_squad)
	boss_meter.value = 1.0
	boss_name_label.text = "// CAPTAIN WILLIS & THE LUNCH SQUAD //"
	boss_bar.visible = true
	_say("CAPTAIN WILLIS:  \"Nobody skips the line in MY mess hall.\"\n(His tray blocks everything. Take out his squad to expose him.)", Color("ff8a5a"), 4.5)


## Willis blows his whistle: a squad of cooks (and later kitchen robots)
## pours out of the kitchen. Each wave is a little bigger.
func _on_willis_call_squad(wave: int) -> void:
	var cooks := 0
	var robots := 0
	var cook_limit := mini(3 + wave, 6)
	var robot_limit := mini(wave - 1, 2)
	for spawn in spawns:
		if spawn[0] == "guard" and cooks < cook_limit:
			cooks += 1
			_spawn_enemy("cook", spawn[1])
		elif spawn[0] == "robot" and robots < robot_limit:
			robots += 1
			_spawn_enemy("robot", spawn[1])
	_update_hostiles()
	if wave > 1:
		_say("WILLIS:  *whistle*  \"SECOND SERVING!\"" if wave == 2 else "WILLIS:  *whistle*  \"EVERYBODY OUT HERE!\"", Color("ff8a5a"), 1.8)


func _spawn_enemy(kind: String, at: Vector2) -> void:
	var enemy := CharacterBody2D.new()
	enemy.set_script(EnemyScript)
	enemy.kind = kind
	enemy.target = player
	enemy.position = at
	world.add_child(enemy)
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.active = true
	enemies_left += 1
	_total_enemies += 1


func _on_willis_defeated(at: Vector2) -> void:
	boss_bar.visible = false
	for e in get_tree().get_nodes_in_group("enemies"):
		e.take_hit(at, 99.0, 300.0)   # the squad scatters
	_say("CAPTAIN WILLIS IS DOWN.\nThe lunch squad scatters.  The lift is open.", Color("5ff3ff"), 4.0)
	_drop_xp(at, 25)
	_drop_smokes(at, 12)
	if lift:
		lift.unlocked = true


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
		_total_enemies += 1
	_update_hostiles()


func _on_enemy_defeated(at: Vector2, xp: int) -> void:
	enemies_left -= 1
	player.on_knockout()
	_drop_xp(at, xp)
	_drop_smokes(at, 2 if player.has_relic("photo") else 1)
	_update_hostiles()
	if willis:
		# On Willis's level, a cleared squad exposes him instead of ending the level.
		if enemies_left == 0 and is_instance_valid(willis) and not willis._dead:
			willis.squad_down()
			_say("THE SQUAD IS DOWN.  WILLIS DROPPED HIS TRAY.\nHIT HIM NOW!", Color("4dff88"), 2.0)
		return
	if enemies_left > 0:
		return
	# Level clear: a casing cracks off, the villain catches their breath, and the lift opens.
	player.break_next_casing()
	player.heal(4)
	if player.has_relic("keyring"):
		player.add_smokes(5)
	if lift:
		lift.unlocked = true
	if not await _wait(1.2): return
	if greta:
		_say("Ward clear.  Nurse Greta is at her station, if you need patching up.\nThe lift is open.", Color("8fffd0"), 4.0)
	elif turkey:
		_say("Corridor clear.  Turkey's open for business.\nThe lift is open when you're ready.", Color("ffc24a"), 4.0)
	elif level_index + 1 < LEVELS.size() and LEVELS[level_index + 1].get("boss", false):
		_say("One casing left.  It won't crack for small fry.\nThe lift is open.  The captain is waiting.", Color("5ff3ff"), 4.0)
	else:
		_say("Level clear.  The lift is open.", Color("4dff88"), 3.0)


func _on_lift_entered() -> void:
	if level_index + 1 >= LEVELS.size():
		_say("NEXT: CELL BLOCK A\n(coming soon)", Color("ffd23f"), 6.0)
		return
	var token := _level_token
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.5)
	await tween.finished
	if token != _level_token:
		return
	_load_level(level_index + 1)
	create_tween().tween_property(fade, "color:a", 0.0, 0.6)


func _on_boss_health_changed(hp: float, max_hp: float) -> void:
	boss_meter.value = float(hp) / max_hp


func _drop_xp(at: Vector2, amount: int) -> void:
	for i in amount:
		var orb := Node2D.new()
		orb.set_script(XpOrbScript)
		orb.position = at
		orb.player = player
		world.add_child(orb)


func _update_hostiles() -> void:
	if hostiles_label:
		hostiles_label.text = "HOSTILES  %02d / %02d" % [enemies_left, _total_enemies] if _total_enemies > 0 else ""


func _on_xp_changed(xp: int, needed: int, lvl: int) -> void:
	xp_bar.value = float(xp) / needed
	level_label.text = "LV %02d" % lvl


func _on_leveled_up() -> void:
	_pending_level_ups += 1
	if _pending_level_ups == 1:
		_open_level_up.call_deferred()


func _open_level_up() -> void:
	if game_over:
		_pending_level_ups = 0
		return
	level_up_screen.open(player.roll_choices(), player.ABILITIES, player.abilities, player.level - _pending_level_ups + 1)


func _on_ability_chosen(id: String) -> void:
	player.take_ability(id)
	_say(player.ABILITIES[id]["name"] + " ACQUIRED", Color("4ff0ff"), 1.5)
	_pending_level_ups -= 1
	if _pending_level_ups > 0:
		_open_level_up.call_deferred()


func _on_boss_defeated(at: Vector2) -> void:
	boss_bar.visible = false
	player.break_final_casing()
	_say("CAPTAIN BRASK IS DOWN.\nThe last casing shatters.", Color("5ff3ff"), 3.0)
	var key := Node2D.new()
	key.set_script(KeyPickupScript)
	key.position = at
	key.player = player
	key.picked_up.connect(_on_key_picked_up)
	world.add_child(key)
	_drop_xp(at, 20)
	_drop_smokes(at, 10)


func _on_key_picked_up() -> void:
	if lift:
		lift.unlocked = true
	_say("BRASK'S MASTER KEY ACQUIRED\nThe lift down to Solitary Confinement is open.", Color("ffd23f"), 4.0)


func _drop_smokes(at: Vector2, amount: int) -> void:
	for i in amount:
		var pack := Node2D.new()
		pack.set_script(XpOrbScript)
		pack.smokes = true
		pack.position = at
		pack.player = player
		world.add_child(pack)


func _on_smokes_changed(n: int) -> void:
	smokes_label.text = "SMOKES  x %d" % n


func _on_patch_requested() -> void:
	if game_over:
		return
	if not greta.used and player.hp < player.max_hp:
		var said: String = greta.line()
		greta.used = true
		player.heal(player.max_hp)
		_say("NURSE GRETA:  " + said + "\nHealth fully restored.", Color("8fffd0"), 3.0)
	elif not greta.used:
		_say("NURSE GRETA:  \"You're not even hurt. Next.\"", Color("8fffd0"), 2.5)
	else:
		_say("NURSE GRETA:  " + greta.line(), Color("8fffd0"), 2.5)


func on_remote_used() -> void:
	_say("// CLICK //   EVERYONE FREEZES", Color("8fd8ff"), 1.2)


func _on_trade_requested() -> void:
	if game_over or level_up_screen.visible:
		return
	shop.open(turkey.greeting())


func _on_shop_bought(kind: String, id: String) -> void:
	if kind == "relic":
		player.take_relic(id)
	else:
		player.take_ability(id)


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
	Engine.time_scale = 1.0
	player.restore(player_at_level_start)
	for i in 4:
		restraint_pips[i].value = 0.0 if player.broken[i] else 1.0
	_on_health_changed(player.hp, player.max_hp)
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
	_chroma("MOVE [WASD]   PUNCH [CLICK/SPACE]   PICK POWER [1/2/3]   TALK [E]   REMOTE [Q]", Vector2(28, 48), Vector2(600, 20), 12, HUD_DIM)

	# Health meter
	_chroma("VITALS", Vector2(28, 76), Vector2(200, 16), 11, HUD_DIM)
	health_bar = _neon_bar(Vector2(28, 94), Vector2(220, 16), Color("ff3d6e"), 20)

	# Experience meter and level
	level_label = _chroma("LV 01", Vector2(28, 118), Vector2(80, 16), 11, Color("4ff0ff"))
	xp_bar = _neon_bar(Vector2(28, 136), Vector2(220, 10), Color("3dffb0"), 30)
	xp_bar.value = 0.0
	hostiles_label = _chroma("", Vector2(1068, 76), Vector2(200, 16), 11, Color("ff7a4a"))
	smokes_label = _chroma("SMOKES  x 0", Vector2(28, 154), Vector2(200, 16), 11, Color("ff8a5a"))

	# Restraint gauge: one segment per casing, lit while it's still locked on.
	_chroma("RESTRAINTS", Vector2(1068, 20), Vector2(190, 16), 11, HUD_DIM)
	var names := ["L.ARM", "R.ARM", "L.LEG", "R.LEG"]
	for i in 4:
		var pip := _neon_bar(Vector2(1068 + i * 48, 40), Vector2(44, 14), NEON_CYAN, 1)
		restraint_pips.append(pip)
		_chroma(names[i], Vector2(1068 + i * 48, 56), Vector2(44, 14), 10, HUD_DIM)

	# Boss meter, top centre, hidden until the captain shows up.
	boss_bar = Control.new()
	boss_bar.position = Vector2(390, 668)
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(boss_bar)
	boss_name_label = _chroma("// CAPTAIN BRASK //", Vector2.ZERO, Vector2(500, 20), 15, Color("ff7a4a"), boss_bar)
	boss_name_label.align = HORIZONTAL_ALIGNMENT_CENTER
	for l in boss_name_label.get_children():
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
