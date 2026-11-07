extends Node2D
## The mood of a level: overhead lamps, rotating red alarm beacons,
## drifting fog, floating dust that catches the light, and steam vents.

const FX := preload("res://scripts/fx.gd")
const FOG_SHADER := preload("res://shaders/fog.gdshader")

var _lamps: Array[PointLight2D] = []
var _beacons: Array[PointLight2D] = []
var _flicker_lamp := -1
var _t := 0.0


## bounds: the level's screen rectangle. lamps/vents/beacons: screen positions.
func setup(bounds: Rect2, lamps: Array, vents: Array, beacons: Array, alarm_on: bool) -> void:
	for p in lamps:
		var light := FX.make_light(Color(0.70, 0.80, 1.0), 0.75, 1.35)
		light.position = p
		add_child(light)
		_lamps.append(light)
	if _lamps.size() > 1:
		_flicker_lamp = randi() % _lamps.size()

	for p in beacons:
		var beacon := PointLight2D.new()
		beacon.texture = FX.cone_texture()
		beacon.texture_scale = 3.2
		beacon.color = Color(1.0, 0.15, 0.1)
		beacon.energy = 1.4
		beacon.position = p
		beacon.rotation = randf() * TAU
		beacon.visible = alarm_on
		add_child(beacon)
		_beacons.append(beacon)

	for p in vents:
		add_child(_steam(p))

	# Dust motes: lit by the lamps, so they only show up where light falls.
	var dust := CPUParticles2D.new()
	dust.texture = FX.soft_texture()
	dust.material = FX.additive()
	dust.amount = 90
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.position = bounds.get_center() + Vector2(0, -30)
	dust.emission_rect_extents = bounds.size * 0.5
	dust.direction = Vector2(0.3, -1)
	dust.spread = 180.0
	dust.gravity = Vector2(0, -1.5)
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 5.0
	dust.scale_amount_min = 0.06
	dust.scale_amount_max = 0.16
	dust.color_ramp = _ramp(Color(0.95, 0.95, 1.0, 0.0), Color(0.95, 0.95, 1.0, 0.55))
	dust.z_index = 30
	add_child(dust)

	# Fog over everything in the level.
	var fog := Polygon2D.new()
	var r := bounds.grow(220)
	fog.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var m := ShaderMaterial.new()
	m.shader = FOG_SHADER
	fog.material = m
	fog.z_index = 40
	add_child(fog)


func set_alarm(on: bool) -> void:
	for b in _beacons:
		b.visible = on


func _process(delta: float) -> void:
	_t += delta
	for b in _beacons:
		b.rotation += delta * 2.4
	if _flicker_lamp >= 0:
		# one tired lamp that stutters now and then
		var on := fmod(_t, 5.0) > 0.4 or randf() < 0.5
		_lamps[_flicker_lamp].energy = 0.75 if on else 0.1


func _steam(at: Vector2) -> CPUParticles2D:
	var steam := CPUParticles2D.new()
	steam.texture = FX.soft_texture()
	steam.position = at
	steam.amount = 22
	steam.lifetime = 2.0
	steam.preprocess = 2.0
	steam.direction = Vector2(0, -1)
	steam.spread = 14.0
	steam.gravity = Vector2(4, -10)
	steam.initial_velocity_min = 22.0
	steam.initial_velocity_max = 40.0
	steam.scale_amount_min = 0.5
	steam.scale_amount_max = 0.9
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 2.6))
	steam.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, Color(0.8, 0.85, 0.9, 0.0))
	g.set_color(1, Color(0.8, 0.85, 0.9, 0.0))
	g.add_point(0.2, Color(0.8, 0.85, 0.9, 0.32))
	steam.color_ramp = g
	steam.z_index = 35
	return steam


func _ramp(edge: Color, middle: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, edge)
	g.set_color(1, edge)
	g.add_point(0.5, middle)
	return g
