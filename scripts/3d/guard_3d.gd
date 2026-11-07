extends CharacterBody3D
## A prison guard (or a security drone) in 3D. Waits until Victor comes
## close, then walks around walls to reach him and shoves on contact.

signal defeated(at: Vector3)

const Look := preload("res://scripts/3d/look_3d.gd")
const WAKE_DISTANCE := 10.0

var kind := "guard"   # "guard" or "robot"
var target: Node3D
var hp := 3.0
var active := false
var speed := 2.6

var _knock := Vector3.ZERO
var _flash := 0.0
var _touch_cooldown := 0.0
var _walk := 0.0
var _t := randf() * 5.0
var _dead := false
var _body: Node3D
var _mats: Array[StandardMaterial3D] = []
var _waypoint := Vector3.INF
var _repath := 0.0


func _ready() -> void:
	add_to_group("enemies")
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)
	_body = Node3D.new()
	add_child(_body)
	if kind == "robot":
		hp = 4.0
		speed = 2.2
		_build_robot()
	else:
		_build_guard()


func _mat(c: Color) -> StandardMaterial3D:
	var m := Look.matte(c).duplicate() as StandardMaterial3D
	_mats.append(m)
	return m


func _build_guard() -> void:
	var navy := _mat(Color("1f2c4a"))
	var navy_dark := _mat(Color("121a2e"))
	var armour := _mat(Color("2c3d63"))
	for side: int in [-1, 1]:
		Look.capsule(_body, 0.13, 0.9, Vector3(0.15 * side, 0.45, 0), navy_dark)
		Look.capsule(_body, 0.1, 0.75, Vector3(0.38 * side, 1.2, 0), navy).rotation.z = 0.15 * side
	Look.box(_body, Vector3(0.62, 0.7, 0.38), Vector3(0, 1.25, 0), navy)
	Look.box(_body, Vector3(0.56, 0.4, 0.42), Vector3(0, 1.35, 0), armour)          # vest
	Look.box(_body, Vector3(0.1, 0.07, 0.03), Vector3(0.14, 1.45, 0.22), Look.glow(Color("e0b03a"), 1.5))  # badge
	Look.sphere(_body, 0.17, Vector3(0, 1.78, 0), _mat(Color("c9a58a")))
	Look.sphere(_body, 0.19, Vector3(0, 1.84, -0.02), navy_dark).scale = Vector3(1, 0.8, 1)  # helmet
	Look.box(_body, Vector3(0.3, 0.07, 0.05), Vector3(0, 1.79, 0.16), Look.glow(Color("ff3b3b"), 3.0))  # visor
	var baton := Look.cylinder(_body, 0.03, 0.55, Vector3(0.45, 0.95, 0.15), _mat(Color("1a1a1a")))
	baton.rotation.x = 0.6
	Look.sphere(_body, 0.05, Vector3(0.45, 0.72, 0.32), Look.glow(Color("ffd060"), 4.0))


func _build_robot() -> void:
	var steel := Look.steel(Color("6b7280")).duplicate() as StandardMaterial3D
	_mats.append(steel)
	Look.box(_body, Vector3(0.7, 0.75, 0.6), Vector3(0, 1.0, 0), steel)
	Look.box(_body, Vector3(0.72, 0.08, 0.62), Vector3(0, 1.15, 0), Look.hazard())
	Look.box(_body, Vector3(0.42, 0.3, 0.38), Vector3(0, 1.55, 0), steel)
	Look.sphere(_body, 0.07, Vector3(0, 1.56, 0.2), Look.glow(Color("ff2020"), 6.0))
	Look.sphere(_body, 0.18, Vector3(0, 0.45, 0), Look.glow(Color("ff7a30"), 2.0)).scale = Vector3(1, 0.4, 1)  # thruster
	for side: int in [-1, 1]:
		Look.box(_body, Vector3(0.12, 0.5, 0.12), Vector3(0.45 * side, 0.95, 0.1), steel)


func take_hit(from: Vector3, damage := 1.0, force := 6.0) -> void:
	if _dead:
		return
	active = true
	hp -= damage
	_flash = 0.15
	var away := global_position - from
	away.y = 0
	_knock = away.normalized() * force
	if hp <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 1
	defeated.emit(global_position)
	# topple over backwards, then sink through the floor
	var tween := create_tween()
	tween.tween_property(_body, "rotation:x", -PI / 2.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(1.2)
	tween.tween_property(_body, "position:y", -0.6, 0.8)
	tween.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	_touch_cooldown -= delta
	for m in _mats:
		m.emission_enabled = _flash > 0.0
		m.emission = Color(1, 0.9, 0.85)
		m.emission_energy_multiplier = _flash * 20.0
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	var move := Vector3.ZERO
	if not _dead and is_instance_valid(target) and not target.dead:
		var to := target.global_position - global_position
		to.y = 0
		var level := get_tree().current_scene
		if not active and to.length() < WAKE_DISTANCE and (not level.has_method("path_length") or level.path_length(global_position, target.global_position) < 9):
			active = true
		if active:
			_repath -= delta
			if _repath <= 0.0 and level.has_method("path_next"):
				_repath = 0.3
				_waypoint = level.path_next(global_position, target.global_position)
			if to.length() > 0.95:
				var goal := to
				if _waypoint != Vector3.INF and to.length() > 2.5:
					goal = _waypoint - global_position
					goal.y = 0
				move = goal.normalized() * speed
			elif _touch_cooldown <= 0.0:
				target.hit(global_position, 1)
				_touch_cooldown = 1.0
			_body.rotation.y = lerp_angle(_body.rotation.y, atan2(to.x, to.z), minf(1.0, delta * 10.0))
	var flat := move + _knock
	_knock = _knock.move_toward(Vector3.ZERO, 25.0 * delta)
	velocity = Vector3(flat.x, velocity.y, flat.z)
	move_and_slide()
	if _dead:
		return
	_walk = _walk + delta * 10.0 if move != Vector3.ZERO else 0.0
	if kind == "robot":
		_body.position.y = 0.15 + sin(_t * 3.0) * 0.06
	else:
		_body.position.y = absf(sin(_walk)) * 0.04
		_body.rotation.z = sin(_walk) * 0.05
