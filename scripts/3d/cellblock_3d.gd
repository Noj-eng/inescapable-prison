extends Node3D
## 3D TEST: a prison floor in 3D, built from a text map. By default the map is
## made fresh by prison_gen.gd (see tuning_3d.gd); the hand-made Cell Block C
## map below is the fallback. Originally rebuilt from the same text map as the 2D game,
## in the gritty look of Jon's concept art: cracked concrete, electrified
## glass cells, red caged warning lights, steam grates, a catwalk edge over
## a dark drop, loose cables and rubble, real lights, shadows, fog and SSAO.
## Fixed isometric camera. Victor walks and punches; guards close in.
##
## Run it by opening scenes/cellblock_3d.tscn and pressing F6.

const Tune := preload("res://scripts/3d/tuning_3d.gd")
const PrisonGen := preload("res://scripts/3d/prison_gen.gd")
const LIGHT_RANGE := 30.0   # metres around Victor where lamps are switched on
const Look := preload("res://scripts/3d/look_3d.gd")
const VictorScript := preload("res://scripts/3d/victor_3d.gd")
const GuardScript := preload("res://scripts/3d/guard_3d.gd")
## The 3D Cell Block C: about twice the size of the 2D one, built for running.
## # wall  . floor  b bunk  t toilet  B electrified glass cell front
## R Victor's broken rig (start)  E lift  G guard  M robot  o pillar
## v steam grate  x crate  d table  c console
const MAP := [
	"################################################",
	"#b..#b..#b..#b..#b..#b..#b..#b..#b..#b..#b..####",
	"#...#...#...#...#...#...#...#...#...#...#...####",
	"#t..#t..#t..#t..#t..#t..#t..#t..#t..#t..#t..####",
	"#BBB#BBB#B.B#BBB#BBB#BBB#BBB#BBB#BBB#BBB#BBB####",
	"#..............................................#",
	"#................v............G.............xx.#",
	"#...........o.........o.........o.........o..x.#",
	"#.....R...................G....................#",
	"#...................................G.......G..#",
	"#.................G..................v.........#",
	"#..d.....d..o.........o.........o........Mo....#",
	"#..........................v...................#",
	"#####...###############..###############...#####",
	"#####...###############..###############...#####",
	"#............######################............#",
	"#..cc....c...##b..#b..#b..#b..#b..#...xx...xx..#",
	"#....G.......##...#...#...#...#...#...x.....x..#",
	"#.....o......##t..#t..#t..#t..#t..#.....G......#",
	"#.............#BBB#BBB#BBB#BBB#BBB#.......v....#",
	"#..................................#........M..#",
	"#..d....d....#......G..........G...#....xx.....#",
	"#......M.....#..............G................x.#",
	"#.........G..#..........M..........#..G......x.#",
	"#............#.....................#...........#",
	"####...###########....###########..#########..##",
	"#..............................................#",
	"#..xx...............xx........G................#",
	"#.......G......v....x....................M.....#",
	"#.........o.............o.............o........#",
	"#.....v...............M....xx.......G..........#",
	"#.............G...............v...........G.E..#",
	"#..............................................#",
	"################################################",
]

const GLASS_SHADER := preload("res://shaders/electric_glass.gdshader")
const ChromaLabelScript := preload("res://scripts/chroma_label.gd")
const NeonBarScript := preload("res://scripts/neon_bar.gd")
const SCANLINES := preload("res://shaders/scanlines.gdshader")

const CELL := 2.0           # metres per map square
const WALL_H := 3.2         # inner walls
const BACK_WALL_H := 5.0    # walls along the back edges
const SOLID := "#Bbtdxoc"

var map: Array = []
var rows := 0
var cols := 0
var player: CharacterBody3D
var camera: Camera3D
var enemies_left := 0
var total_enemies := 0
var _astar: AStarGrid2D
var _fade_walls: Array[MeshInstance3D] = []
var _red_lights: Array[OmniLight3D] = []
var _glass_lights: Array[OmniLight3D] = []
var _shake := 0.0
var _lift_at := Vector3.INF
var _descending := false
var _cull_t := 0.0
var calm := true            # nobody moves until Victor leaves the start
var _start_at := Vector3.ZERO
var _alarm := 0.0
static var depth := 1      # how many floors deep Victor is (survives reloads)
var _lamps: Array[SpotLight3D] = []
var _aftershock_in := 6.0
var _quake := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _lift_mat: StandardMaterial3D
var _game_over := false

var _hud: CanvasLayer
var _health_bar: Control
var _hostiles: Control
var _message: Control
var _message_tween: Tween
var _over_panel: ColorRect


func _ready() -> void:
	if Tune.LEVEL_PROCEDURAL:
		var seed_value := Tune.LEVEL_SEED + depth if Tune.LEVEL_SEED != 0 else randi()
		map = PrisonGen.new().generate(seed_value, Tune.LEVEL_BLOCKS_X, Tune.LEVEL_BLOCKS_Y,
				Tune.LEVEL_WINDING, Tune.ENEMY_DENSITY, Tune.ROBOT_SHARE)
		print("Prison floor %d, seed %d" % [depth, seed_value])
		_rng.seed = seed_value
	else:
		map = MAP
		_rng.seed = 1977
	rows = map.size()
	cols = map[0].length()
	_build_environment()
	_build_level()
	_build_paths()
	_build_hud()
	_say("%s\nWASD to move.  Click, Space or J to punch.  Find the lift." % _title(), Color("ffd23f"), 4.0)


func cell_pos(x: float, y: float) -> Vector3:
	return Vector3(x * CELL, 0.0, y * CELL)


func _ch(x: int, y: int) -> String:
	if y < 0 or y >= rows or x < 0 or x >= cols:
		return "#"
	return map[y][x]


# --- environment ------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.017, 0.024)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.68)
	env.ambient_light_energy = Tune.AMBIENT_LIGHT
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = Tune.EXPOSURE
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.8
	env.ssao_power = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.16, 0.18, 0.24)
	env.fog_density = 0.008
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.75, 0.78, 0.85)
	env.volumetric_fog_length = 80.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# faint cold light from high above, for long soft shadows
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.7, 0.9)
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-62, -30, 0)
	add_child(moon)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 17.0
	camera.far = 300.0
	add_child(camera)


# --- the level ----------------------------------------------------------------------

func _build_level() -> void:
	var floor_mat := Look.concrete(Color("6b6d70"), 0.3).duplicate() as StandardMaterial3D
	floor_mat.uv1_world_triplanar = true
	var wall_mat := Look.concrete(Color("5d5f63"), 0.25)
	var back_mat := Look.concrete(Color("4d4f54"), 0.2)
	var dark_steel := Look.steel(Color("2d3036"))
	var start := Vector3.ZERO
	var cell_number := 4

	# one big floor collider; the visible slabs are separate so they can tilt
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var fb := BoxShape3D.new()
	fb.size = Vector3(cols * CELL, 1.0, rows * CELL)
	floor_shape.shape = fb
	floor_shape.position = Vector3((cols - 1) * CELL * 0.5, -0.5, (rows - 1) * CELL * 0.5)
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	for y in rows:
		for x in cols:
			var ch: String = map[y][x]
			var at := cell_pos(x, y)
			var front := x == cols - 1 or y == rows - 1
			var back := x == 0 or y == 0
			if ch != "#" or front:
				# floor slab, a little uneven
				var slab := Look.box(self, Vector3(CELL - 0.04, 0.3, CELL - 0.04), at + Vector3(0, -0.15 + _rng.randf_range(-0.015, 0.015), 0), floor_mat)
				slab.rotation = Vector3(_rng.randf_range(-0.01, 0.01), 0, _rng.randf_range(-0.01, 0.01))
			match ch:
				"#":
					if not _touches_floor(x, y):
						continue    # solid rock between rooms: nothing to see or touch
					if front:
						_catwalk_edge(x, y)
					else:
						var h := BACK_WALL_H if back else WALL_H
						var wall := Look.box(self, Vector3(CELL, h, CELL), at + Vector3(0, h * 0.5, 0), back_mat if back else wall_mat, true)
						if not back:
							_fade_walls.append(wall)
						if back and _touches_floor(x, y):
							_wall_trim(at, h, x, y)
				"B":
					_glass_cell_front(at, x)
				"b": _bunk(at)
				"t": _toilet(at)
				"d": _table(at)
				"x": _crate(at)
				"c": _console(at)
				"o": _pillar(at)
				"v": _grate(at)
				"E":
					_lift(at)
					_lift_at = at
				"R":
					_broken_rig(at)
					start = at + Vector3(0, 0, CELL)
				"G", "M":
					_spawn_enemy("robot" if ch == "M" else "guard", at)
			if ch == "." and _ch(x - 1, y) == "B" and _ch(x + 1, y) == "B":
				_smashed_glass(at)   # cell 7: the quake already blew this one out
	# lintels and cell numbers above every row of glass fronts
	for gy in rows:
		if not (map[gy] as String).contains("B"):
			continue
		var x0 := 1
		while x0 < cols:
			if _ch(x0, gy) == "B":
				var x1 := x0
				while _ch(x1 + 1, gy) != "#":
					x1 += 1
				var mid := (x0 + x1) * 0.5
				Look.box(self, Vector3((x1 - x0 + 1) * CELL, WALL_H - 2.5, CELL), cell_pos(mid, gy) + Vector3(0, 2.5 + (WALL_H - 2.5) * 0.5, 0), wall_mat)
				var label := Label3D.new()
				label.text = str(cell_number)
				cell_number += 1
				label.font_size = 160
				label.pixel_size = 0.004
				label.modulate = Color(0.1, 0.1, 0.1, 0.9)
				label.outline_size = 0
				label.shaded = true
				label.position = cell_pos(mid, gy) + Vector3(0, 2.85, CELL * 0.5 + 0.01)
				add_child(label)
				# red caged warning lights either side of the cell
				for side: int in [-1, 1]:
					_red_caged_light(cell_pos((x0 if side < 0 else x1) + 0.5 * side, gy) + Vector3(0, 2.0, CELL * 0.5 + 0.12))
				x0 = x1 + 1
			x0 += 1
	_overhead_lamps()
	_scatter_cracks_rubble_cables()
	_the_drop()

	player = CharacterBody3D.new()
	player.set_script(VictorScript)
	player.camera = camera
	player.position = start + Vector3(0, 0.1, 0)
	_start_at = start
	add_child(player)
	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.target = player


func _touches_floor(x: int, y: int) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if _ch(x + dx, y + dy) != "#":
				return true
	return false


## Pipes and a dark steel skirting along the back walls.
func _wall_trim(at: Vector3, h: float, x: int, y: int) -> void:
	var pipe := Look.steel(Color("3b3f46"))
	if y == 0:
		Look.box(self, Vector3(CELL, 0.25, 0.08), at + Vector3(0, 0.12, CELL * 0.5 + 0.02), Look.steel(Color("23262b")))
		var p := Look.cylinder(self, 0.08, CELL, at + Vector3(0, h - 0.6, CELL * 0.5 + 0.12), pipe)
		p.rotation.z = PI / 2
	if x == 0:
		Look.box(self, Vector3(0.08, 0.25, CELL), at + Vector3(CELL * 0.5 + 0.02, 0.12, 0), Look.steel(Color("23262b")))
		var p2 := Look.cylinder(self, 0.08, CELL, at + Vector3(CELL * 0.5 + 0.12, h - 0.6, 0), pipe)
		p2.rotation.x = PI / 2


## The open front edges are a catwalk over a dark drop: a railing and an
## invisible wall to stop anyone falling off.
func _catwalk_edge(x: int, y: int) -> void:
	var at := cell_pos(x, y)
	var rail := Look.steel(Color("4a4f57"), 0.8)
	var along_x := y == rows - 1
	var edge := at + (Vector3(0, 0, CELL * 0.5 - 0.1) if along_x else Vector3(CELL * 0.5 - 0.1, 0, 0))
	var length := Vector3(CELL, 0, 0) if along_x else Vector3(0, 0, CELL)
	for k in 2:
		Look.box(self, Vector3(0.08, 1.1, 0.08), edge - length * 0.5 + length * (k * 0.5) + Vector3(0, 0.55, 0), rail)
	for hgt in [0.55, 1.1]:
		Look.box(self, Vector3(CELL, 0.05, 0.05) if along_x else Vector3(0.05, 0.05, CELL), edge + Vector3(0, hgt, 0), rail)
	Look.box(self, Vector3(CELL, 0.12, 0.04) if along_x else Vector3(0.04, 0.12, CELL), edge + Vector3(0, 0.06, 0), Look.hazard())
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(CELL, 3, 0.2) if along_x else Vector3(0.2, 3, CELL)
	shape.shape = bs
	body.position = edge + Vector3(0, 1.5, 0)
	body.add_child(shape)
	add_child(body)


## Far below the catwalk: darkness, a few red glows, and a slab of floor
## so the drop reads as deep.
func _the_drop() -> void:
	var c := cell_pos(cols * 0.5, rows * 0.5)
	Look.box(self, Vector3(cols * CELL * 3, 0.5, rows * CELL * 3), c + Vector3(0, -14, 0), Look.concrete(Color("222428"), 0.1))
	for p in [Vector3(cols * CELL + 4, -11, rows * CELL * 0.5), Vector3(cols * CELL * 0.5, -11, rows * CELL + 4)]:
		var o := OmniLight3D.new()
		o.light_color = Color(1.0, 0.2, 0.12)
		o.light_energy = 3.0
		o.omni_range = 14.0
		o.position = p
		add_child(o)


func _glass_cell_front(at: Vector3, x: int) -> void:
	var frame := Look.steel(Color("2a2d33"))
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(CELL, 2.5)
	quad.mesh = qm
	var mat := ShaderMaterial.new()
	mat.shader = GLASS_SHADER
	mat.set_shader_parameter("seed", float(x) * 1.7)
	quad.material_override = mat
	quad.position = at + Vector3(0, 1.25, 0)
	add_child(quad)
	# a faint real pane of glass behind the energy
	var pane := Look.box(self, Vector3(CELL, 2.5, 0.04), at + Vector3(0, 1.25, -0.03), _glass_mat(), true)
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Look.box(self, Vector3(CELL, 0.12, 0.2), at + Vector3(0, 0.06, 0), frame)
	Look.box(self, Vector3(0.1, 2.5, 0.2), at + Vector3(-CELL * 0.5 + 0.05, 1.25, 0), frame)
	if x % 2 == 0:
		var light := OmniLight3D.new()
		light.light_color = Color(0.45, 0.75, 1.0)
		light.light_energy = 1.4
		light.omni_range = 4.5
		light.position = at + Vector3(0, 1.3, 0.6)
		add_child(light)
		_glass_lights.append(light)


func _glass_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.8, 1.0, 0.08)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.2
	m.roughness = 0.05
	return m


func _smashed_glass(at: Vector3) -> void:
	for i in 14:
		var shard := Look.box(self, Vector3(_rng.randf_range(0.1, 0.35), 0.02, _rng.randf_range(0.08, 0.25)),
			at + Vector3(_rng.randf_range(-1.2, 1.2), 0.02, _rng.randf_range(-0.2, 1.4)), _glass_mat())
		shard.rotation.y = _rng.randf() * TAU
	var spark := OmniLight3D.new()
	spark.light_color = Color(0.5, 0.8, 1.0)
	spark.light_energy = 0.8
	spark.omni_range = 3.0
	spark.position = at + Vector3(0, 1.5, 0)
	add_child(spark)
	_glass_lights.append(spark)


func _red_caged_light(p: Vector3) -> void:
	Look.sphere(self, 0.11, p, Look.glow(Color(1.0, 0.12, 0.08), 6.0)).scale = Vector3(1, 1.4, 1)
	var cage := Look.steel(Color("1c1d21"))
	for k in 4:
		var bar := Look.box(self, Vector3(0.02, 0.36, 0.02), p + Vector3(cos(k * PI / 2) * 0.13, 0, sin(k * PI / 2) * 0.13), cage)
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Look.box(self, Vector3(0.3, 0.05, 0.3), p + Vector3(0, 0.2, 0), cage)
	Look.box(self, Vector3(0.3, 0.05, 0.3), p + Vector3(0, -0.2, 0), cage)
	var o := OmniLight3D.new()
	o.light_color = Color(1.0, 0.15, 0.1)
	o.light_energy = 1.8
	o.omni_range = 5.0
	o.position = p + Vector3(0, 0, 0.3)
	add_child(o)
	_red_lights.append(o)


func _overhead_lamps() -> void:
	var count := 0
	for y in rows:
		for x in cols:
			if _ch(x, y) == "#" or x % 5 != 2 or y % 4 != 2:
				continue
			var at := cell_pos(x, y)
			var spot := SpotLight3D.new()
			spot.light_color = Color(0.85, 0.92, 1.0)
			spot.light_energy = Tune.LAMP_BRIGHTNESS
			spot.spot_range = 12.0
			spot.spot_angle = 58.0
			spot.spot_attenuation = 0.5
			spot.spot_angle_attenuation = 2.5
			spot.light_volumetric_fog_energy = 1.6
			spot.shadow_enabled = count < 10
			spot.position = at + Vector3(0, 5.6, 0)
			spot.rotation_degrees = Vector3(-90, 0, 0)
			add_child(spot)
			_lamps.append(spot)
			count += 1
			# the fixture itself, hanging on a cable out of the dark
			Look.box(self, Vector3(0.7, 0.15, 0.3), at + Vector3(0, 5.75, 0), Look.steel(Color("2a2c31")))
			Look.box(self, Vector3(0.6, 0.04, 0.22), at + Vector3(0, 5.66, 0), Look.glow(Color(0.9, 0.95, 1.0), 5.0))
			Look.cylinder(self, 0.015, 4.0, at + Vector3(0, 7.8, 0), Look.steel(Color("111111")), 4)


func _bunk(at: Vector3) -> void:
	var frame := Look.steel(Color("3a3d44"))
	Look.box(self, Vector3(1.8, 0.1, 0.9), at + Vector3(0, 0.55, -0.35), frame, true)
	Look.box(self, Vector3(1.7, 0.12, 0.8), at + Vector3(0, 0.66, -0.35), Look.matte(Color("5a6050")))
	for sx: int in [-1, 1]:
		Look.box(self, Vector3(0.06, 0.55, 0.06), at + Vector3(0.85 * sx, 0.27, -0.05), frame)


func _toilet(at: Vector3) -> void:
	var steel := Look.steel(Color("8a9099"), 0.9)
	Look.cylinder(self, 0.25, 0.45, at + Vector3(0, 0.22, -0.4), steel)
	Look.box(self, Vector3(0.5, 0.5, 0.2), at + Vector3(0, 0.45, -0.7), steel, true)


func _table(at: Vector3) -> void:
	var steel := Look.steel(Color("6e747c"), 0.8)
	Look.box(self, Vector3(1.8, 0.08, 1.0), at + Vector3(0, 0.8, 0), steel, true)
	for sx: int in [-1, 1]:
		Look.box(self, Vector3(0.08, 0.8, 0.8), at + Vector3(0.8 * sx, 0.4, 0), steel)


func _crate(at: Vector3) -> void:
	var size := _rng.randf_range(1.1, 1.4)
	var crate := Look.box(self, Vector3(size, size * 0.8, size), at + Vector3(0, size * 0.4, 0), Look.matte(Color("4f5a34")), true)
	crate.rotation.y = _rng.randf_range(-0.2, 0.2)
	Look.box(crate, Vector3(size + 0.02, 0.1, size + 0.02), Vector3(0, size * 0.2, 0), Look.matte(Color("2c3220")))
	Look.box(crate, Vector3(size + 0.02, 0.1, size + 0.02), Vector3(0, -size * 0.2, 0), Look.matte(Color("2c3220")))


func _console(at: Vector3) -> void:
	var body := Look.box(self, Vector3(1.4, 1.3, 0.7), at + Vector3(0, 0.65, -0.3), Look.steel(Color("2b2f36")), true)
	var screen := Look.box(body, Vector3(1.1, 0.5, 0.02), Vector3(0, 0.25, 0.36), Look.glow(Color(0.2, 1.0, 0.65), 2.5))
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var o := OmniLight3D.new()
	o.light_color = Color(0.3, 1.0, 0.7)
	o.light_energy = 0.6
	o.omni_range = 2.5
	o.position = at + Vector3(0, 1.0, 0.4)
	add_child(o)


func _pillar(at: Vector3) -> void:
	var p := Look.box(self, Vector3(1.0, 6.0, 1.0), at + Vector3(0, 3.0, 0), Look.concrete(Color("6a6c70"), 0.35), true)
	_fade_walls.append(p)
	Look.box(self, Vector3(1.06, 0.7, 1.06), at + Vector3(0, 0.35, 0), Look.hazard())
	# exposed rebar and a sparking wire where the quake split it
	for k in 3:
		var bar := Look.cylinder(self, 0.025, 0.6, at + Vector3(0.3 - k * 0.15, 4.1, 0.52), Look.steel(Color("6b3d22")), 6)
		bar.rotation.x = _rng.randf_range(-0.6, 0.6)


func _grate(at: Vector3) -> void:
	var steel := Look.steel(Color("1d1f23"), 0.8)
	Look.box(self, Vector3(1.6, 0.05, 1.6), at + Vector3(0, -0.05, 0), Look.matte(Color("050505")))
	for k in 7:
		Look.box(self, Vector3(1.6, 0.06, 0.07), at + Vector3(0, 0.01, -0.7 + k * 0.23), steel)
	var steam := Look.steam()
	steam.position = at + Vector3(0, 0.1, 0)
	add_child(steam)


func _lift(at: Vector3) -> void:
	Look.cylinder(self, 1.0, 0.1, at + Vector3(0, 0.05, 0), Look.steel(Color("23262c")), 24)
	_lift_mat = Look.glow(Color(1.0, 0.2, 0.2), 3.0).duplicate()
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 0.92
	ring.mesh = torus
	ring.material_override = _lift_mat
	ring.position = at + Vector3(0, 0.12, 0)
	add_child(ring)


## The containment rig Victor broke out of: a cracked upright ring.
func _broken_rig(at: Vector3) -> void:
	Look.cylinder(self, 1.5, 0.25, at + Vector3(0, 0.12, 0), Look.steel(Color("2a2d33")), 32)
	Look.cylinder(self, 1.52, 0.06, at + Vector3(0, 0.27, 0), Look.hazard(), 32)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.6
	torus.outer_radius = 1.85
	torus.rings = 48
	ring.mesh = torus
	ring.material_override = Look.steel(Color("3a3e46"))
	ring.position = at + Vector3(0, 2.0, -0.2)
	ring.rotation = Vector3(PI / 2, 0, 0.12)   # stands upright, knocked slightly askew
	add_child(ring)
	var core := OmniLight3D.new()
	core.light_color = Color(0.3, 0.9, 1.0)
	core.light_energy = 1.2
	core.omni_range = 4.0
	core.position = at + Vector3(0, 1.0, 0)
	add_child(core)
	_glass_lights.append(core)
	for k in 6:
		var d := Decal.new()
		d.texture_albedo = Look.crack_texture(100 + k)
		d.size = Vector3(4, 1, 4)
		d.position = at + Vector3(_rng.randf_range(-2, 2), 0, _rng.randf_range(-2, 2))
		d.rotation.y = _rng.randf() * TAU
		add_child(d)


func _scatter_cracks_rubble_cables() -> void:
	var floor_cells: Array[Vector2i] = []
	for y in rows:
		for x in cols:
			if map[y][x] == "." and x < cols - 1 and y < rows - 1:
				floor_cells.append(Vector2i(x, y))
	# cracks in the floor
	for i in 26:
		var c: Vector2i = floor_cells[_rng.randi() % floor_cells.size()]
		var d := Decal.new()
		d.texture_albedo = Look.crack_texture(_rng.randi() % 12)
		d.size = Vector3(_rng.randf_range(2.0, 4.0), 1, _rng.randf_range(2.0, 4.0))
		d.position = cell_pos(c.x, c.y) + Vector3(_rng.randf_range(-0.8, 0.8), 0, _rng.randf_range(-0.8, 0.8))
		d.rotation.y = _rng.randf() * TAU
		add_child(d)
	# cracks up the walls (projected sideways onto the faces we can see)
	for i in 18:
		var c: Vector2i = floor_cells[_rng.randi() % floor_cells.size()]
		var toward := Vector2i(0, -1) if _rng.randf() < 0.5 else Vector2i(-1, 0)
		if _ch(c.x + toward.x, c.y + toward.y) != "#":
			continue
		var d := Decal.new()
		d.texture_albedo = Look.crack_texture(20 + i)
		d.size = Vector3(2.5, 2.0, 2.5)
		d.position = cell_pos(c.x, c.y) + Vector3(toward.x, 0, toward.y) * (CELL * 0.5) + Vector3(0, _rng.randf_range(1.2, 2.6), 0)
		d.rotation = Vector3(PI / 2, 0, 0) if toward.y != 0 else Vector3(0, 0, -PI / 2)
		add_child(d)
	# rubble: broken chunks of concrete near the walls
	var chunk := Look.concrete(Color("6f7175"), 0.6)
	for i in 70:
		var c: Vector2i = floor_cells[_rng.randi() % floor_cells.size()]
		var s := _rng.randf_range(0.08, 0.3)
		var r := Look.box(self, Vector3(s, s * 0.7, s * 1.2), cell_pos(c.x, c.y) + Vector3(_rng.randf_range(-0.9, 0.9), s * 0.3, _rng.randf_range(-0.9, 0.9)), chunk)
		r.rotation = Vector3(_rng.randf() * 0.6, _rng.randf() * TAU, _rng.randf() * 0.6)
	# loose cables snaking across the floor
	var cable := Look.matte(Color("141416"))
	for i in 12:
		var c: Vector2i = floor_cells[_rng.randi() % floor_cells.size()]
		var p := cell_pos(c.x, c.y) + Vector3(_rng.randf_range(-0.8, 0.8), 0.04, _rng.randf_range(-0.8, 0.8))
		var heading := _rng.randf() * TAU
		for seg in 9:
			heading += _rng.randf_range(-0.6, 0.6)
			var step := Vector3(cos(heading), 0, sin(heading)) * 0.45
			var piece := Look.cylinder(self, 0.035, 0.48, p + step * 0.5, cable, 6)
			piece.look_at_from_position(p + step * 0.5, p + step, Vector3.UP)
			piece.rotate_object_local(Vector3.RIGHT, PI / 2)
			p += step


func _spawn_enemy(kind: String, at: Vector3) -> void:
	var e := CharacterBody3D.new()
	e.set_script(GuardScript)
	e.kind = kind
	e.position = at + Vector3(0, 0.1, 0)
	add_child(e)
	e.defeated.connect(_on_enemy_defeated)
	enemies_left += 1
	total_enemies += 1


# --- path finding (same idea as the 2D game) -------------------------------------------

func _build_paths() -> void:
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, cols, rows)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for y in rows:
		for x in cols:
			if SOLID.contains(map[y][x]):
				_astar.set_point_solid(Vector2i(x, y))


func _to_grid(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / CELL), roundi(p.z / CELL))


func path_next(from: Vector3, to: Vector3) -> Vector3:
	var a := _to_grid(from)
	var b := _to_grid(to)
	if a == b or not _astar.is_in_boundsv(a) or not _astar.is_in_boundsv(b) or _astar.is_point_solid(a) or _astar.is_point_solid(b):
		return to
	var path := _astar.get_id_path(a, b)
	if path.size() <= 2:
		return to
	return cell_pos(path[1].x, path[1].y)


func path_length(from: Vector3, to: Vector3) -> int:
	var a := _to_grid(from)
	var b := _to_grid(to)
	if not _astar.is_in_boundsv(a) or not _astar.is_in_boundsv(b) or _astar.is_point_solid(a) or _astar.is_point_solid(b):
		return 999
	var path := _astar.get_id_path(a, b)
	return path.size() if path.size() > 0 else 999


# --- every frame ------------------------------------------------------------------

func _title() -> String:
	if Tune.LEVEL_PROCEDURAL:
		return "THE PRISON  //  FLOOR -%d" % depth
	return "CELL BLOCK C  //  3D TEST"


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(player):
		return
	# isometric camera: fixed angle, follows Victor smoothly
	var offset := Vector3(1.0, 1.25, 1.0).normalized() * 60.0
	var goal := player.global_position + Vector3(0, 1.0, 0)
	var focus := goal if _t < 0.1 else camera.global_position - offset
	focus = focus.lerp(goal, minf(1.0, delta * 6.0)) if _t >= 0.1 else goal
	camera.global_position = focus + offset
	camera.look_at(focus, Vector3.UP)
	# aftershocks: the quake that freed Victor isn't finished
	_aftershock_in -= delta
	if _aftershock_in <= 0.0 and not _game_over:
		_aftershock_in = _rng.randf_range(Tune.AFTERSHOCK_MIN_GAP, Tune.AFTERSHOCK_MAX_GAP)
		_quake = 1.4
		shake(Tune.AFTERSHOCK_SHAKE)
	_quake = maxf(0.0, _quake - delta)
	for i in _lamps.size():
		var flicker := _quake > 0.0 and _rng.randf() < 0.35 + 0.1 * (i % 3)
		_lamps[i].light_energy = Tune.LAMP_BRIGHTNESS * (0.12 if flicker else 1.0)
	_shake = move_toward(_shake, 0.0, delta * 1.5)
	# a moment to get his bearings; a few steps out and the alarm goes off
	if calm and not _game_over:
		var from_start := player.global_position - _start_at
		from_start.y = 0
		if from_start.length() > Tune.CALM_RADIUS:
			calm = false
			_alarm = 3.0
			shake(0.2)
			_say("ALARM.\nEvery guard on the floor knows where you are.", Color("ff3b3b"), 2.5)
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.global_position.distance_to(player.global_position) < Tune.ALARM_RADIUS:
					e.active = true
	_alarm = maxf(0.0, _alarm - delta)
	# only light what's near Victor: a big floor has hundreds of lamps
	_cull_t -= delta
	if _cull_t <= 0.0:
		_cull_t = 0.25
		var here := player.global_position
		for group in [_lamps, _red_lights, _glass_lights]:
			for l: Light3D in group:
				l.visible = l.global_position.distance_squared_to(here) < LIGHT_RANGE * LIGHT_RANGE
	# the lift: step on it to drop to a deeper, freshly built floor
	if _lift_at != Vector3.INF and not _descending and not _game_over:
		var to_lift := player.global_position - _lift_at
		to_lift.y = 0
		if to_lift.length() < 1.1:
			_descending = true
			depth += 1
			shake(0.3)
			_say("GOING DOWN.\nFloor -%d. Still no way out." % depth, Color("ff7a4a"), 2.0)
			get_tree().create_timer(1.6).timeout.connect(get_tree().reload_current_scene)
	camera.h_offset = _rng.randf_range(-1, 1) * _shake
	camera.v_offset = _rng.randf_range(-1, 1) * _shake
	# red warning lights pulse, the containment glass flickers
	for i in _red_lights.size():
		_red_lights[i].light_energy = 1.2 + 1.0 * (0.5 + 0.5 * sin(_t * 3.0 + i)) + (3.0 if _alarm > 0.0 and fmod(_t, 0.4) < 0.2 else 0.0)
	for i in _glass_lights.size():
		_glass_lights[i].light_energy = 0.9 + _rng.randf() * 0.9
	# walls and pillars between the camera and Victor turn see-through
	var toward_cam := Vector3(1, 0, 1).normalized()
	var across := Vector3(1, 0, -1).normalized()
	for w in _fade_walls:
		var rel := w.global_position - player.global_position
		rel.y = 0
		var depth := rel.dot(toward_cam)
		var side := absf(rel.dot(across))
		var hide := depth > 0.6 and depth < 16.0 and side < 4.5
		w.transparency = move_toward(w.transparency, 0.75 if hide else 0.0, delta * 4.0)


func _unhandled_input(event: InputEvent) -> void:
	if _game_over and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()


func _on_enemy_defeated(_at: Vector3) -> void:
	enemies_left -= 1
	_hostiles.text = "HOSTILES  %02d / %02d" % [enemies_left, total_enemies]
	if enemies_left == 0:
		_lift_mat.albedo_color = Color(0.3, 1.0, 0.5)
		_lift_mat.emission = Color(0.3, 1.0, 0.5)
		_say("FLOOR CLEAR.\nNot a guard left standing.", Color("4dff88"), 4.0)


func _on_health_changed(hp: int, max_hp: int) -> void:
	_health_bar.value = float(hp) / max_hp


func _on_player_died() -> void:
	_game_over = true
	await get_tree().create_timer(1.0).timeout
	_over_panel.visible = true


# --- HUD (same neon style as the 2D game) ---------------------------------------------

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)
	_chroma(_title(), Vector2(28, 20), Vector2(600, 30), 20, Color("ffd23f"))
	_chroma("MOVE [WASD]   PUNCH [CLICK/SPACE]", Vector2(28, 48), Vector2(600, 20), 12, Color(0.62, 0.7, 0.82, 0.75))
	_chroma("VITALS", Vector2(28, 76), Vector2(200, 16), 11, Color(0.62, 0.7, 0.82, 0.75))
	_health_bar = Control.new()
	_health_bar.set_script(NeonBarScript)
	_health_bar.position = Vector2(28, 94)
	_health_bar.size = Vector2(220, 16)
	_health_bar.color = Color("ff3d6e")
	_health_bar.segments = 20
	_hud.add_child(_health_bar)
	_hostiles = _chroma("HOSTILES  %02d / %02d" % [enemies_left, total_enemies], Vector2(1068, 20), Vector2(200, 16), 11, Color("ff7a4a"))
	_message = _chroma("", Vector2(0, 600), Vector2(1280, 90), 20, Color.WHITE)
	for l in _message.get_children():
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_panel = ColorRect.new()
	_over_panel.color = Color(0.03, 0.01, 0.03, 0.82)
	_over_panel.size = Vector2(1280, 720)
	_over_panel.visible = false
	_hud.add_child(_over_panel)
	var big := _chroma("CONTAINED", Vector2(0, 270), Vector2(1280, 80), 64, Color("ff3d5a"), _over_panel)
	for l in big.get_children():
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _chroma("> PRESS R TO RETRY_", Vector2(0, 360), Vector2(1280, 30), 18, Color(0.62, 0.7, 0.82, 0.75), _over_panel)
	for l in hint.get_children():
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var crt_layer := CanvasLayer.new()
	crt_layer.layer = 10
	add_child(crt_layer)
	var crt := ColorRect.new()
	crt.size = Vector2(1280, 720)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SCANLINES
	m.set_shader_parameter("vignette", 0.45)
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
	(parent if parent else _hud).add_child(label)
	return label


func _say(text: String, color: Color, seconds: float) -> void:
	if _message_tween:
		_message_tween.kill()
	_message.text = text
	_message.color = color
	_message.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(seconds)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.8)
