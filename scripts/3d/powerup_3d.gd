extends Node3D
## A pickup lying on the prison floor: contraband Victor grabs by walking
## over it. Each one floats over a glowing ring so it can be spotted from
## across a room. Some are placed when a floor is built; beaten enemies
## sometimes drop one too.
##
##   Powerup.scatter(level, map, rng, count)   place some on a new floor
##   Powerup.drop(level, at, rng)              maybe drop one where a guard fell

const Look := preload("res://scripts/3d/look_3d.gd")
const Tune := preload("res://scripts/3d/tuning_3d.gd")
const SOLID := "#BbtdxocT"

## name: shown when picked up    tint: colour of the glow and ring
## weight: how common it is      say: the line shown on pickup
const TYPES := {
	"medkit": {
		"name": "STOLEN MED KIT", "tint": Color(1.0, 0.25, 0.3), "weight": 4.0,
		"say": "+%d health." % Tune.MEDKIT_HEAL,
	},
	"knuckles": {
		"name": "BRASS KNUCKLES", "tint": Color(1.0, 0.8, 0.25), "weight": 2.0,
		"say": "Punches hit twice as hard for %d seconds." % int(Tune.KNUCKLES_TIME),
	},
	"coffee": {
		"name": "CONTRABAND COFFEE", "tint": Color(1.0, 0.55, 0.2), "weight": 2.0,
		"say": "Faster on your feet for %d seconds." % int(Tune.COFFEE_TIME),
	},
	"mattress": {
		"name": "MATTRESS ARMOUR", "tint": Color(0.35, 0.7, 1.0), "weight": 2.0,
		"say": "Soaks up the next %d hits." % Tune.MATTRESS_HITS,
	},
	"hooch": {
		"name": "JAILHOUSE HOOCH", "tint": Color(0.5, 1.0, 0.3), "weight": 1.2,
		"say": "RAGE for %d seconds: wide, heavy swings, and darts can't slow you." % int(Tune.HOOCH_TIME),
	},
}

var kind := "medkit"
var level: Node
var _item: Node3D
var _light: OmniLight3D
var _ring: MeshInstance3D
var _t := 0.0
var _taken := false


static func make(parent: Node, at: Vector3, kind_name: String) -> Node3D:
	var p := Node3D.new()
	p.set_script(load("res://scripts/3d/powerup_3d.gd"))
	p.kind = kind_name
	p.level = parent
	p.position = at
	parent.add_child(p)
	return p


static func pick_kind(rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in TYPES:
		total += TYPES[k]["weight"]
	var roll := rng.randf() * total
	for k in TYPES:
		roll -= TYPES[k]["weight"]
		if roll <= 0.0:
			return k
	return "medkit"


## Sprinkles pickups over a new floor: open spots in the middle of rooms,
## well away from where Victor starts.
static func scatter(parent: Node, map: Array, rng: RandomNumberGenerator, count: int, cell: float, start: Vector3) -> void:
	var spots: Array[Vector2i] = []
	for y in range(1, map.size() - 1):
		for x in range(1, (map[y] as String).length() - 1):
			if map[y][x] != ".":
				continue
			var open := true
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if SOLID.contains(map[y + dy][x + dx]) or map[y + dy][x + dx] == "B":
						open = false
			var at := Vector3(x * cell, 0, y * cell)
			if open and at.distance_to(start) > 14.0:
				spots.append(Vector2i(x, y))
	var placed: Array[Vector3] = []
	var tries := 0
	while placed.size() < count and spots.size() > 0 and tries < count * 40:
		tries += 1
		var s := spots[rng.randi() % spots.size()]
		var at := Vector3(s.x * cell, 0, s.y * cell)
		var crowded := false
		for p in placed:
			if p.distance_to(at) < 18.0:     # spread them out over the floor
				crowded = true
		if crowded:
			continue
		placed.append(at)
		make(parent, at, pick_kind(rng))


## Called when an enemy goes down: now and then it leaves something behind.
static func drop(parent: Node, at: Vector3, rng: RandomNumberGenerator) -> void:
	if rng.randf() < Tune.POWERUP_DROP_CHANCE:
		make(parent, Vector3(at.x, 0, at.z), pick_kind(rng))


func _ready() -> void:
	var c: Color = TYPES[kind]["tint"]
	# glowing ring on the floor
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.68
	_ring.mesh = torus
	_ring.material_override = Look.glow(c, 1.1)
	_ring.position.y = 0.03
	_ring.scale = Vector3(1, 0.3, 1)
	add_child(_ring)
	# a faint column of light, so it shows up across a dark room
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.5
	cyl.height = 3.0
	beam.mesh = cyl
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.albedo_color = Color(c, 0.12)
	beam.material_override = bm
	beam.position.y = 1.5
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	_light = OmniLight3D.new()
	_light.light_color = c
	_light.light_energy = 1.6
	_light.omni_range = 3.5
	_light.position.y = 1.2
	add_child(_light)
	_item = Node3D.new()
	_item.position.y = 1.0
	_item.scale = Vector3.ONE * 1.7
	add_child(_item)
	_build_item(c)
	# pop in (enemy drops appear where the guard fell)
	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_item(c: Color) -> void:
	match kind:
		"medkit":
			Look.box(_item, Vector3(0.5, 0.36, 0.22), Vector3.ZERO, Look.matte(Color(0.92, 0.92, 0.9)))
			Look.box(_item, Vector3(0.28, 0.08, 0.24), Vector3.ZERO, Look.glow(c, 2.0))
			Look.box(_item, Vector3(0.08, 0.28, 0.24), Vector3.ZERO, Look.glow(c, 2.0))
			Look.box(_item, Vector3(0.18, 0.05, 0.05), Vector3(0, 0.21, 0), Look.steel(Color(0.3, 0.3, 0.32)))
		"knuckles":
			var gold := Look.steel(Color(1.0, 0.78, 0.3), 0.9)
			gold.emission_enabled = true
			gold.emission = c
			gold.emission_energy_multiplier = 0.4
			for i in 4:
				var ring := MeshInstance3D.new()
				var t := TorusMesh.new()
				t.inner_radius = 0.06
				t.outer_radius = 0.1
				ring.mesh = t
				ring.material_override = gold
				ring.rotation.x = PI / 2
				ring.position = Vector3(-0.27 + i * 0.18, 0, 0)
				_item.add_child(ring)
			Look.box(_item, Vector3(0.66, 0.08, 0.06), Vector3(0, -0.12, 0), gold)
		"coffee":
			var tin := Look.steel(Color(0.55, 0.32, 0.18), 0.4)
			Look.cylinder(_item, 0.15, 0.32, Vector3.ZERO, tin)
			Look.cylinder(_item, 0.155, 0.08, Vector3(0, 0.02, 0), Look.glow(c, 1.5))
			var handle := MeshInstance3D.new()
			var t := TorusMesh.new()
			t.inner_radius = 0.06
			t.outer_radius = 0.1
			handle.mesh = t
			handle.material_override = tin
			handle.rotation.z = PI / 2
			handle.position = Vector3(0.17, 0, 0)
			_item.add_child(handle)
			# steam
			var steam := Look.steam()
			steam.position.y = 0.2
			steam.scale = Vector3.ONE * 0.25
			_item.add_child(steam)
		"mattress":
			var cloth := Look.matte(Color(0.75, 0.82, 0.9))
			var stripe := Look.glow(c, 1.2)
			for i in 3:
				Look.box(_item, Vector3(0.62, 0.12, 0.4), Vector3(0, -0.14 + i * 0.13, 0), cloth)
				Look.box(_item, Vector3(0.63, 0.03, 0.41), Vector3(0, -0.1 + i * 0.13, 0), stripe)
			Look.box(_item, Vector3(0.66, 0.04, 0.06), Vector3(0, 0.0, 0.0), Look.matte(Color(0.25, 0.2, 0.15)))
		"hooch":
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color(c.r * 0.5, c.g * 0.8, c.b * 0.4, 0.75)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.emission_enabled = true
			glass.emission = c
			glass.emission_energy_multiplier = 1.2
			glass.roughness = 0.1
			Look.cylinder(_item, 0.13, 0.36, Vector3(0, -0.04, 0), glass)
			Look.cylinder(_item, 0.05, 0.16, Vector3(0, 0.22, 0), glass)
			Look.cylinder(_item, 0.055, 0.05, Vector3(0, 0.32, 0), Look.matte(Color(0.45, 0.3, 0.2)))
			Look.box(_item, Vector3(0.2, 0.14, 0.01), Vector3(0, -0.04, 0.13), Look.matte(Color(0.85, 0.8, 0.65)))


func _process(delta: float) -> void:
	if _taken:
		return
	_t += delta
	_item.rotation.y += delta * 1.8
	_item.position.y = 1.0 + sin(_t * 2.5) * 0.12
	_ring.scale = Vector3(1, 0.3, 1) * (1.0 + 0.08 * sin(_t * 4.0))
	var player: Node3D = level.get("player")
	if not is_instance_valid(player):
		return
	var to := player.global_position - global_position
	to.y = 0
	var d := to.length()
	_light.visible = d < 30.0
	if d < 1.3 and not player.get("dead") and player.has_method("power_up"):
		_take(player)


func _take(player: Node3D) -> void:
	_taken = true
	player.power_up(kind)
	var info: Dictionary = TYPES[kind]
	if level.has_method("_say"):
		level._say("%s\n%s" % [info["name"], info["say"]], (info["tint"] as Color).lightened(0.3), 2.2)
	if level.has_method("shake"):
		level.shake(0.08)
	_light.light_energy = 6.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_item, "position:y", 2.6, 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector3(1.6, 0.01, 1.6), 0.3).set_delay(0.05)
	tw.tween_property(_light, "light_energy", 0.0, 0.35)
	tw.chain().tween_callback(queue_free)
