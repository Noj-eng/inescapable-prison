extends Node3D
## A glowing scrap of XP dropped by a beaten enemy. It bobs over the floor
## until Victor comes close, then flies into him.

var value := 1
var level: Node
var _t := randf() * 3.0
var _speed := 0.0
var _scatter := Vector3.ZERO
var _core: MeshInstance3D


static func drop(parent: Node, at: Vector3, amount: int) -> void:
	for i in amount:
		var o := Node3D.new()
		o.set_script(load("res://scripts/3d/xp_orb_3d.gd"))
		o.level = parent
		o.position = Vector3(at.x, 0.6, at.z)
		parent.add_child(o)


func _ready() -> void:
	_scatter = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(1.5, 3.5)
	_core = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.11
	s.height = 0.22
	s.radial_segments = 8
	s.rings = 4
	_core.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.6, 1.0, 0.85)
	_core.material_override = m
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)
	var halo := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.26
	hs.height = 0.52
	hs.radial_segments = 8
	hs.rings = 4
	halo.mesh = hs
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.albedo_color = Color(0.2, 1.0, 0.7, 0.25)
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_core.add_child(halo)


func _process(delta: float) -> void:
	_t += delta
	position += _scatter * delta
	_scatter = _scatter.move_toward(Vector3.ZERO, 6.0 * delta)
	_core.position.y = absf(sin(_t * 3.0)) * 0.15
	var player: Node3D = level.get("player")
	if not is_instance_valid(player) or player.get("dead"):
		return
	var to := player.global_position + Vector3(0, 1.0, 0) - global_position
	if to.length() < player.pickup_radius() or _speed > 0.0:
		_speed = minf(_speed + 40.0 * delta, 22.0)
		global_position += to.normalized() * minf(_speed * delta, to.length())
		if to.length() < 0.4:
			player.add_xp(value)
			queue_free()
