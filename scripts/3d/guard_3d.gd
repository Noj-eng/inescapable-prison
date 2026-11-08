extends CharacterBody3D
## A prison guard, or a one-wheeled Detention Unit robot, in 3D. Waits until
## Victor comes close, then moves around walls to reach him. Guards shove on
## contact; the robot rolls in, raises its stun baton and brings it down.
##
## The robot uses Jon's Meshy model at res://models/wheel_unit.glb when it is
## there. Only its spine and arm bones are used: the "legs" of its rig sit on
## either side of the wheel and are never animated. The whole body rolls and
## leans in code, and glowing hubs on the wheel spin to show it turning.

signal defeated(at: Vector3)

const Look := preload("res://scripts/3d/look_3d.gd")
const Tune := preload("res://scripts/3d/tuning_3d.gd")
const WAKE_DISTANCE := Tune.GUARD_WAKE_DISTANCE
const GUARD_HEIGHT := 1.95
const MeshyRig := preload("res://scripts/3d/meshy_rig.gd")
const Types := preload("res://scripts/3d/enemy_types_3d.gd")
const ROBOT_HEIGHT := 2.5          # metres: a head taller than Victor
const SWING_RANGE := 1.5
const SWING_WINDUP := Tune.ROBOT_SWING_WINDUP
const SWING_STRIKE := 0.12
const SWING_RECOVER := 0.5

var kind := "guard"   # body: "guard" or "robot" (set from the variant)
var variant := ""     # an id from enemy_types_3d.gd, e.g. "riot", "bomb"
var depth := 1        # floor number: deeper = tougher
var _ability_t := 0.0     # cooldown / timer for the variant's trick
var _ability_phase := 0   # 0 idle, 1 winding up, 2 doing it
var _dash_dir := Vector3.ZERO
var _fx: Node3D           # shield, warning ring, etc.
var _fx_mat: StandardMaterial3D
var _met := false
var _laser: MeshInstance3D   # gunner / turret aiming line
var _aim := Vector3.ZERO
var target: Node3D
var hp := 3.0
var active := false
var speed := Tune.GUARD_SPEED

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

# robot parts
var _wheel_r := 0.45               # wheel radius, metres
var _wheel_y := 0.45               # wheel centre height
var _wheel_spin := 0.0
var _hubs: Array[Node3D] = []
var _lean := 0.0
var _baton: Node3D
var _baton_tip: MeshInstance3D
var _baton_mat: StandardMaterial3D
var _baton_light: OmniLight3D
var _swing := -1.0                 # seconds into the current swing; < 0 = not swinging
var _swing_hit := false
var _arm_raise := 0.0              # 0 = arm hanging, 1 = baton overhead
# stand-in arm pivots
var _shoulder_r: Node3D
var _elbow_r: Node3D
var _shoulder_l: Node3D
# Meshy model bones
var _model: Node3D
var _skel: Skeleton3D
var _bones := {}                   # "arm_r", "fore_r", "hand_r", "arm_l", "spine" -> bone index
var _mrig: RefCounted              # MeshyRig when a Meshy model is loaded


func _ready() -> void:
	add_to_group("enemies")
	if variant == "":
		variant = kind
	var info: Dictionary = Types.TYPES[variant]
	kind = info["base"]
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
		speed = Tune.ROBOT_SPEED
		cap.radius = 0.45
		cap.height = 2.2
		shape.position.y = 1.1
		if MeshyRig.find("wheel_unit.glb") != "":
			_load_robot_model()
		else:
			_build_robot()
		_build_baton()
		if variant == "bomb":
			_baton.visible = false
	elif kind == "turret":
		hp = Tune.TURRET_HP
		speed = 0.0
		cap.radius = 0.5
		_build_turret()
	elif MeshyRig.find("guard.glb") != "":
		_mrig = MeshyRig.load_into(_body, MeshyRig.find("guard.glb"), GUARD_HEIGHT)
	else:
		_build_guard()
	# the variant: tougher, faster or slower, recoloured, plus its gear
	var floor_boost := 1.0 + Tune.ENEMY_HP_PER_FLOOR * (depth - 1)
	hp *= info["hp"] * floor_boost
	speed *= info["speed"] * minf(1.35, 1.0 + Tune.ENEMY_SPEED_PER_FLOOR * (depth - 1))
	if _mrig:
		_mrig.tint(info["tint"])
	else:
		for m in _mats:
			m.albedo_color = m.albedo_color * info["tint"]
	if variant == "enforcer":
		_body.scale = Vector3.ONE * 1.25
	_build_variant_gear(info["tint"])
	if _mrig:
		# Meshy textures are dark: a faint light up front keeps the shape readable
		var rim := OmniLight3D.new()
		rim.light_color = Color(1.0, 0.35, 0.3) if kind == "robot" else Color(0.75, 0.85, 1.0)
		if info["tint"] != Color(1, 1, 1):
			rim.light_color = info["tint"]
		rim.light_energy = 1.4
		rim.omni_range = 3.0
		rim.position = Vector3(0, (ROBOT_HEIGHT if kind == "robot" else GUARD_HEIGHT) * 0.8, 0.9)
		_body.add_child(rim)


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
	# Stand-in for the Detention Unit until wheel_unit.glb is saved.
	var rust := _mat(Color("6e4a32"))
	var dark := Look.steel(Color("2a2b2f")).duplicate() as StandardMaterial3D
	_mats.append(dark)
	var tyre := _mat(Color("151515"))
	# the wheel, with a fork either side
	var wheel := Node3D.new()
	wheel.position.y = _wheel_y
	_body.add_child(wheel)
	var t := Look.cylinder(wheel, _wheel_r, 0.24, Vector3.ZERO, tyre, 20)
	t.rotation.z = PI / 2
	for side: int in [-1, 1]:
		Look.box(_body, Vector3(0.08, 0.9, 0.3), Vector3(0.2 * side, 0.75, 0), dark)
	# hips, torso with chest plate, head with red visor
	Look.box(_body, Vector3(0.55, 0.3, 0.42), Vector3(0, 1.2, 0), dark)
	Look.box(_body, Vector3(0.8, 0.7, 0.5), Vector3(0, 1.7, 0), rust)
	Look.box(_body, Vector3(0.5, 0.35, 0.06), Vector3(0, 1.75, 0.26), dark)
	Look.box(_body, Vector3(0.3, 0.32, 0.3), Vector3(0, 2.25, 0), dark)
	Look.box(_body, Vector3(0.26, 0.05, 0.04), Vector3(0, 2.28, 0.16), Look.glow(Color("ff2020"), 6.0))
	# arms on pivots so the baton arm can swing
	for side: int in [-1, 1]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(0.52 * side, 1.95, 0)
		_body.add_child(shoulder)
		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.2
		cone.height = 0.4
		cone.radial_segments = 4
		spike.mesh = cone
		spike.material_override = dark
		spike.position = Vector3(0.08 * side, 0.15, 0)
		spike.rotation.z = -0.5 * side
		shoulder.add_child(spike)
		Look.box(shoulder, Vector3(0.2, 0.45, 0.2), Vector3(0, -0.25, 0), rust)
		var elbow := Node3D.new()
		elbow.position.y = -0.5
		shoulder.add_child(elbow)
		Look.box(elbow, Vector3(0.26, 0.42, 0.26), Vector3(0, -0.2, 0), rust)
		Look.box(elbow, Vector3(0.18, 0.16, 0.2), Vector3(0, -0.5, 0), dark)   # fist
		# model's right hand is on its -X side (it faces +Z)
		if side == -1:
			_shoulder_r = shoulder
			_elbow_r = elbow
		else:
			_shoulder_l = shoulder
	_add_hubs()


func _load_robot_model() -> void:
	_mrig = MeshyRig.load_into(_body, MeshyRig.find("wheel_unit.glb"), ROBOT_HEIGHT)
	_mrig.freeze_legs = true       # its "legs" are the wheel
	_model = _mrig.model
	_skel = _mrig.skel
	_bones = _mrig.bones
	# the tyre takes up roughly the bottom 40% of the model
	_wheel_r = ROBOT_HEIGHT * 0.2
	_wheel_y = _wheel_r
	if _skel and _bones.has("foot_r") and _bones.has("knee_r"):
		# Jon put the knee and foot markers on the wheel: use them to find its centre
		_mrig.update(0.0, false)
		var centre := _body.to_local((_mrig.bone_world("knee_r") + _mrig.bone_world("foot_r")) * 0.5)
		if centre.y > 0.2 and centre.y < ROBOT_HEIGHT * 0.4:
			_wheel_y = centre.y
			_wheel_r = clampf(centre.y, 0.3, 0.8)
	_add_hubs()


func _bone_world(i: int) -> Vector3:
	return _skel.global_transform * _skel.get_bone_global_pose(i).origin


func _add_hubs() -> void:
	# Glowing hub discs on both faces of the wheel. They spin as it rolls,
	# which reads as the tyre turning without touching the model.
	var hub_mat := Look.glow(Color("ff3a1e"), 2.5)
	var spoke_mat := Look.steel(Color("1c1c1e"))
	for side: int in [-1, 1]:
		var hub := Node3D.new()
		hub.position = Vector3(0.2 * side, _wheel_y, 0)
		_body.add_child(hub)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = _wheel_r * 0.42
		torus.outer_radius = _wheel_r * 0.5
		torus.rings = 24
		ring.mesh = torus
		ring.material_override = hub_mat
		ring.rotation.z = PI / 2
		hub.add_child(ring)
		for k in 3:
			var spoke := Look.box(hub, Vector3(0.03, _wheel_r * 0.9, 0.06), Vector3.ZERO, spoke_mat)
			spoke.rotation.x = k * PI / 3.0
		_hubs.append(hub)


func _build_baton() -> void:
	_baton = Node3D.new()
	add_child(_baton)
	Look.cylinder(_baton, 0.035, 0.25, Vector3(0, 0.12, 0), Look.matte(Color("111111")), 8)   # grip
	_baton_mat = Look.glow(Color("5ad8ff"), 3.0).duplicate() as StandardMaterial3D
	_baton_tip = Look.cylinder(_baton, 0.045, 0.6, Vector3(0, 0.55, 0), _baton_mat, 8)
	_baton_light = OmniLight3D.new()
	_baton_light.light_color = Color("5ad8ff")
	_baton_light.light_energy = 0.8
	_baton_light.omni_range = 2.5
	_baton_light.position.y = 0.7
	_baton.add_child(_baton_light)


# --- the baton swing -----------------------------------------------------------

func _start_swing() -> void:
	_swing = 0.0
	_swing_hit = false


func _update_swing(delta: float, to: Vector3) -> void:
	# Raise (wind-up), crash down (strike), recover. Sets _arm_raise 0..1.
	if _swing < 0.0:
		_arm_raise = move_toward(_arm_raise, 0.0, delta * 3.0)
		return
	_swing += delta
	if _swing < SWING_WINDUP:
		_arm_raise = ease(_swing / SWING_WINDUP, 0.5)
	elif _swing < SWING_WINDUP + SWING_STRIKE:
		_arm_raise = 1.0 - (_swing - SWING_WINDUP) / SWING_STRIKE * 1.25
		if not _swing_hit and _swing > SWING_WINDUP + SWING_STRIKE * 0.6:
			_swing_hit = true
			var fwd := Vector3(sin(_body.rotation.y), 0, cos(_body.rotation.y))
			if to.length() < SWING_RANGE + 0.3 and fwd.dot(to.normalized()) > 0.3:
				target.hit(global_position, 2, 8.0)
	elif _swing < SWING_WINDUP + SWING_STRIKE + SWING_RECOVER:
		_arm_raise = move_toward(_arm_raise, 0.0, delta * 2.0)
	else:
		_swing = -1.0


func _pose_arms() -> void:
	# _arm_raise 0 = hanging, 1 = baton overhead, a little below 0 = follow-through
	var shoulder := lerpf(-0.35, -2.6, _arm_raise)     # radians about the body's right axis
	var elbow := -0.5 - 0.6 * clampf(_arm_raise, 0.0, 1.0)
	if _shoulder_r:
		_shoulder_r.rotation.x = shoulder
		_elbow_r.rotation.x = elbow
		_shoulder_l.rotation.x = -0.2 + 0.25 * _arm_raise
	if _skel:
		_mrig.update(get_physics_process_delta_time(), false)
		_rotate_bone("arm_r", Vector3.RIGHT, shoulder + 0.35)
		_rotate_bone("fore_r", Vector3.RIGHT, elbow + 0.5)
		_rotate_bone("arm_l", Vector3.RIGHT, 0.25 * _arm_raise)
		_rotate_bone("spine", Vector3.UP, 0.25 * _arm_raise)
		_rotate_bone("spine", Vector3.RIGHT, -0.15 * _arm_raise)
	_place_baton()


func _rotate_bone(key: String, axis_model: Vector3, angle: float) -> void:
	# Turns a bone about an axis given in the model's own space (+Z forward),
	# so it works whatever way the rig's bones happen to point.
	if not _bones.has(key) or absf(angle) < 0.0001:
		return
	var i: int = _bones[key]
	var parent := _skel.get_bone_parent(i)
	var parent_rot := Quaternion.IDENTITY
	if parent >= 0:
		parent_rot = _skel.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	var turn := Quaternion(axis_model.normalized(), angle)
	var local := _skel.get_bone_pose_rotation(i)
	_skel.set_bone_pose_rotation(i, (parent_rot.inverse() * turn * parent_rot) * local)


func _place_baton() -> void:
	# Put the baton in the right fist, pointing on from the forearm.
	var hand: Vector3
	var dir: Vector3
	if _skel and _bones.has("hand_r") and _bones.has("fore_r"):
		hand = _bone_world(_bones["hand_r"])
		dir = hand - _bone_world(_bones["fore_r"])
		hand += dir.normalized() * 0.08
	elif _elbow_r:
		hand = _elbow_r.to_global(Vector3(0, -0.5, 0.05))
		dir = _elbow_r.to_global(Vector3(0, -1, 0)) - _elbow_r.global_position
	else:
		return
	# the baton sticks out forward from the fist, tipping up as the arm rises
	var fwd := _body.global_basis.z
	var up_dir := (dir.normalized() * 0.4 + fwd * 0.8 + Vector3.UP * 0.2).normalized()
	_baton.global_position = hand
	var side := up_dir.cross(fwd)
	if side.length() < 0.01:
		side = _body.global_basis.x
	_baton.global_basis = Basis(side.normalized(), up_dir, side.normalized().cross(up_dir)).orthonormalized()
	var charge := clampf(_arm_raise, 0.0, 1.0)
	_baton_mat.emission_energy_multiplier = 2.5 + 10.0 * charge + randf() * 1.5 * charge
	_baton_light.light_energy = 0.6 + 3.0 * charge


# --- variant tricks -------------------------------------------------------------

func _build_variant_gear(c: Color) -> void:
	match variant:
		"riot":
			# a tall steel shield with yellow hazard stripes, held out front
			_fx = Node3D.new()
			_body.add_child(_fx)
			var shield := Look.box(_fx, Vector3(0.9, 1.4, 0.08), Vector3(0.1, 1.0, 0.55), Look.steel(Color("3a3d42")))
			shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			Look.box(_fx, Vector3(0.92, 0.12, 0.09), Vector3(0.1, 1.45, 0.56), Look.hazard())
			Look.box(_fx, Vector3(0.6, 0.12, 0.02), Vector3(0.1, 1.15, 0.6), Look.glow(c, 1.5))
		"shock", "enforcer", "bomb":
			# a warning ring on the floor that lights up while it charges
			_fx = MeshInstance3D.new()
			var torus := TorusMesh.new()
			var r := 3.2 if variant != "bomb" else Tune.BOMB_RADIUS
			torus.inner_radius = r - 0.12
			torus.outer_radius = r
			torus.rings = 48
			(_fx as MeshInstance3D).mesh = torus
			_fx_mat = Look.glow(c, 4.0).duplicate() as StandardMaterial3D
			_fx_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_fx_mat.albedo_color.a = 0.0
			(_fx as MeshInstance3D).material_override = _fx_mat
			_fx.position.y = 0.06
			_fx.visible = variant != "enforcer"
			add_child(_fx)
			_ability_t = randf_range(1.0, 2.5)


## Runs the variant's special move. Returns how it wants to move this frame,
## or Vector3.INF to fall back to the normal chase.
func _ability(delta: float, to: Vector3, level: Node) -> Vector3:
	var dist := to.length()
	var dir := to.normalized() if dist > 0.01 else Vector3.FORWARD
	_ability_t -= delta
	match variant:
		"taser":
			# hang back at dart range, fire, sidestep
			if _ability_t <= 0.0 and dist < 9.0 and dist > 2.0:
				_ability_t = Tune.TASER_RELOAD
				_shoot(_muzzle(), (target.global_position + Vector3(0, 1.2, 0) - _muzzle()).normalized(), 15.0, 1, Color(0.4, 1.0, 0.9), Tune.TASER_SLOW, level)
			if dist < 4.5:
				return -dir * speed * 0.7 + dir.cross(Vector3.UP) * speed * 0.4 * sin(_t)
			if dist < 7.0:
				return dir.cross(Vector3.UP) * speed * 0.5 * signf(sin(_t * 0.7))
		"enforcer":
			if _ability_phase == 0 and _ability_t <= 0.0 and dist > 3.0 and dist < 10.0:
				_ability_phase = 1
				_ability_t = 0.6                  # wind-up: glows, stands still
				_dash_dir = dir
			if _ability_phase == 1:
				_flash = 0.05 + 0.05 * sin(_t * 40.0)
				_dash_dir = _dash_dir.lerp(dir, delta * 2.0).normalized()
				if _ability_t <= 0.0:
					_ability_phase = 2
					_ability_t = 0.5
				return Vector3.ZERO
			if _ability_phase == 2:
				if dist < 1.3 and _touch_cooldown <= 0.0:
					target.hit(global_position, 2, 14.0)
					_touch_cooldown = 1.0
				if _ability_t <= 0.0:
					_ability_phase = 0
					_ability_t = Tune.ENFORCER_COOLDOWN
				return _dash_dir * speed * 3.0
		"gunner", "turret":
			var turret := variant == "turret"
			if _ability_phase == 0 and _ability_t <= 0.0 and dist > 1.5 and dist < (14.0 if turret else 11.0):
				_ability_phase = 1
				_ability_t = Tune.GUNNER_AIM
				_aim = to
			if _ability_phase == 1:
				# the laser sight drifts onto Victor, then locks and fires
				_aim = _aim.lerp(to, minf(1.0, delta * 3.0))
				_show_laser(_aim)
				if _ability_t <= 0.0:
					_ability_phase = 0
					_ability_t = Tune.GUNNER_RELOAD * (0.8 if turret else 1.0)
					_laser.visible = false
					_shoot(_muzzle(), _aim.normalized(), 26.0, 1, Color(1.0, 0.3, 0.25), 0.0, level)
				return Vector3.ZERO
			if turret:
				return Vector3.ZERO
			if dist < 5.0:
				return -dir * speed * 0.7
			if dist < 9.0:
				return dir.cross(Vector3.UP) * speed * 0.5 * signf(sin(_t * 0.6))
		"grenadier":
			if _ability_t <= 0.0 and dist < 9.0 and dist > 2.0:
				_ability_t = Tune.GRENADE_RELOAD
				_throw_grenade(target.global_position + Vector3(target.velocity.x, 0, target.velocity.z) * 0.4, level)
			if dist < 5.0:
				return -dir * speed * 0.6 + dir.cross(Vector3.UP) * speed * 0.4
		"shock":
			if _ability_phase == 0 and _ability_t <= 0.0 and dist < 4.0:
				_ability_phase = 1
				_ability_t = 0.9
			if _ability_phase == 1:
				var k := 1.0 - _ability_t / 0.9
				_fx_mat.albedo_color.a = 0.2 + 0.8 * k
				_fx_mat.emission_energy_multiplier = 2.0 + 10.0 * k
				if _ability_t <= 0.0:
					_ability_phase = 0
					_ability_t = Tune.SHOCK_COOLDOWN
					_fx_mat.albedo_color.a = 0.0
					_burst(Color(0.5, 0.75, 1.0), 3.2)
					if dist < 3.2:
						target.hit(global_position, 1, 9.0)
						target.slow(1.0)
				return Vector3.ZERO
		"bomb":
			if _ability_phase == 0 and dist < 1.8:
				_ability_phase = 1
				_ability_t = 0.9
			if _ability_phase == 1:
				var k := 1.0 - _ability_t / 0.9
				_flash = 0.12 if fmod(_t, 0.18 - 0.12 * k) < 0.06 else 0.0
				_fx_mat.albedo_color.a = 0.3 + 0.7 * k
				if _ability_t <= 0.0:
					_explode()
				return Vector3.ZERO
	return Vector3.INF


func _muzzle() -> Vector3:
	return global_position + Vector3(0, 1.55 if kind == "turret" else 1.3, 0)


func _show_laser(aim: Vector3) -> void:
	if not _laser:
		_laser = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.03, 0.03, 1.0)
		_laser.mesh = bm
		var m := Look.glow(Color(1.0, 0.1, 0.1), 6.0).duplicate() as StandardMaterial3D
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = 0.8
		_laser.material_override = m
		_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_laser.top_level = true
		add_child(_laser)
	var from := _muzzle()
	var length := 16.0
	# stop the beam at the first wall
	var level := get_tree().current_scene
	if level.has_method("is_wall"):
		for i in 32:
			var p := from + aim.normalized() * (i * 0.5)
			if level.is_wall(p):
				length = i * 0.5
				break
	_laser.visible = true
	_laser.global_transform = Transform3D(Basis.looking_at(aim.normalized(), Vector3.UP), from + aim.normalized() * length * 0.5)
	_laser.scale = Vector3(1, 1, length)


func _shoot(from: Vector3, dir: Vector3, spd: float, dmg: int, c: Color, slow_s: float, level: Node) -> void:
	var shot := Node3D.new()
	var bolt := Look.cylinder(shot, 0.05, 0.6, Vector3.ZERO, Look.glow(c, 9.0), 6)
	bolt.rotation.x = PI / 2
	var light := OmniLight3D.new()
	light.light_color = c
	light.light_energy = 1.5
	light.omni_range = 2.5
	shot.add_child(light)
	level.add_child(shot)
	shot.global_position = from
	shot.look_at(from + dir, Vector3.UP)
	_fly(shot, dir * spd, dmg, slow_s, level)


func _fly(shot: Node3D, vel: Vector3, dmg: int, slow_s: float, level: Node) -> void:
	var life := [1.2]
	var victim := target
	var t := Timer.new()
	t.wait_time = 1.0 / 60.0
	t.autostart = true
	shot.add_child(t)
	t.timeout.connect(func() -> void:
		life[0] -= t.wait_time
		shot.global_position += vel * t.wait_time
		var done: bool = life[0] <= 0.0
		if is_instance_valid(victim) and shot.global_position.distance_to(victim.global_position + Vector3(0, 1.2, 0)) < 0.75:
			victim.hit(shot.global_position, dmg, 4.0)
			if slow_s > 0.0:
				victim.slow(slow_s)
			done = true
		if level.has_method("is_wall") and level.is_wall(shot.global_position):
			done = true
		if done:
			shot.queue_free())


func _throw_grenade(at: Vector3, level: Node) -> void:
	# lobbed in an arc; lands, blinks inside a warning ring, then goes off
	var g := Node3D.new()
	Look.sphere(g, 0.14, Vector3.ZERO, Look.steel(Color("3b4a2a")))
	var blink := Look.sphere(g, 0.06, Vector3(0, 0.14, 0), Look.glow(Color(1, 0.2, 0.1), 8.0))
	level.add_child(g)
	var start := global_position + Vector3(0, 1.6, 0)
	g.global_position = start
	at.y = 0.15
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = Tune.GRENADE_RADIUS - 0.1
	torus.outer_radius = Tune.GRENADE_RADIUS
	torus.rings = 48
	ring.mesh = torus
	var rm := Look.glow(Color(1, 0.25, 0.1), 5.0).duplicate() as StandardMaterial3D
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color.a = 0.0
	ring.material_override = rm
	level.add_child(ring)
	ring.global_position = Vector3(at.x, 0.06, at.z)
	var tw := g.create_tween()
	tw.tween_method(func(k: float) -> void:
		g.global_position = start.lerp(at, k) + Vector3(0, sin(k * PI) * 2.0, 0), 0.0, 1.0, 0.6)
	tw.parallel().tween_property(rm, "albedo_color:a", 0.7, 0.6)
	# blink faster and faster through the fuse
	var steps := 8
	for i in steps:
		var gap := Tune.GRENADE_FUSE / steps
		tw.tween_callback(func() -> void: blink.visible = not blink.visible)
		tw.tween_interval(gap)
	tw.tween_callback(func() -> void:
		var victim := target
		if is_instance_valid(victim) and Vector2(victim.global_position.x - at.x, victim.global_position.z - at.z).length() < Tune.GRENADE_RADIUS:
			victim.hit(at, 2, 12.0)
		for e in get_tree().get_nodes_in_group("enemies"):
			if Vector2(e.global_position.x - at.x, e.global_position.z - at.z).length() < Tune.GRENADE_RADIUS:
				e.take_hit(at, 2.0, 10.0)
		_burst_at(at, Color(1.0, 0.5, 0.15), Tune.GRENADE_RADIUS, level)
		if level.has_method("shake"):
			level.shake(0.35)
		ring.queue_free()
		g.queue_free())


func _build_turret() -> void:
	# stand-in until Jon saves models/turret.glb: a squat armoured base with
	# a turning head, a barrel and a red eye
	if MeshyRig.find("turret.glb") != "":
		var mrig = MeshyRig.load_into(_body, MeshyRig.find("turret.glb"), 2.0)
		_mrig = null
		mrig.model.set_meta("rig", mrig)
		return
	var dark := Look.steel(Color("2a2c31")).duplicate() as StandardMaterial3D
	_mats.append(dark)
	var plate := Look.steel(Color("4a4d52")).duplicate() as StandardMaterial3D
	_mats.append(plate)
	Look.cylinder(_body, 0.55, 0.3, Vector3(0, 0.15, 0), dark, 8)
	Look.box(_body, Vector3(0.6, 0.15, 0.6), Vector3(0, 0.33, 0), Look.hazard())
	Look.cylinder(_body, 0.18, 0.9, Vector3(0, 0.85, 0), dark, 8)
	Look.box(_body, Vector3(0.75, 0.45, 0.7), Vector3(0, 1.5, 0), plate)
	var barrel := Look.cylinder(_body, 0.07, 0.8, Vector3(0, 1.5, 0.65), dark, 8)
	barrel.rotation.x = PI / 2
	Look.sphere(_body, 0.08, Vector3(0.22, 1.6, 0.36), Look.glow(Color(1, 0.1, 0.1), 6.0))


func _explode() -> void:
	_ability_phase = 2
	var at := global_position
	_burst(Color(1.0, 0.55, 0.15), Tune.BOMB_RADIUS)
	var level := get_tree().current_scene
	if level and level.has_method("shake"):
		level.shake(0.5)
	if is_instance_valid(target) and target.global_position.distance_to(at) < Tune.BOMB_RADIUS:
		target.hit(at, Tune.BOMB_DAMAGE, 14.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and e.global_position.distance_to(at) < Tune.BOMB_RADIUS:
			e.take_hit(at, 4.0, 12.0)
	if not _dead:
		hp = 0.0
		_die()


func _burst(c: Color, radius: float) -> void:
	_burst_at(global_position, c, radius, get_tree().current_scene)


func _burst_at(at: Vector3, c: Color, radius: float, level: Node) -> void:
	# a flash of light and an expanding ring on the floor
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	ring.mesh = torus
	var m := Look.glow(c, 8.0).duplicate() as StandardMaterial3D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = m
	level.add_child(ring)
	ring.global_position = Vector3(at.x, 0.1, at.z)
	ring.scale = Vector3.ONE * 0.3
	var flash := OmniLight3D.new()
	flash.light_color = c
	flash.light_energy = 6.0
	flash.omni_range = radius * 2.0
	ring.add_child(flash)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * radius, 0.25)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.4)
	tw.tween_property(flash, "light_energy", 0.0, 0.4)
	tw.chain().tween_callback(ring.queue_free)


func _shield_spark() -> void:
	if _fx:
		var tw := create_tween()
		_fx.scale = Vector3(1.08, 1.08, 1.08)
		tw.tween_property(_fx, "scale", Vector3.ONE, 0.12)


func take_hit(from: Vector3, damage := 1.0, force := 6.0) -> void:
	if _dead:
		return
	active = true
	if variant == "riot":
		# the shield soaks most of a punch from the front
		var facing := Vector3(sin(_body.rotation.y), 0, cos(_body.rotation.y))
		var toward := from - global_position
		toward.y = 0
		if toward.length() > 0.01 and facing.dot(toward.normalized()) > 0.35:
			damage *= 0.25
			force *= 0.4
			_shield_spark()
	hp -= damage
	_flash = 0.15
	var away := global_position - from
	away.y = 0
	_knock = away.normalized() * force if kind != "turret" else Vector3.ZERO
	if hp <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 1
	defeated.emit(global_position)
	if _fx:
		_fx.queue_free()
		_fx = null
	if _laser:
		_laser.queue_free()
		_laser = null
	if variant == "bomb" and _ability_phase != 2:
		_explode()
	if _baton:
		_baton.queue_free()
		_baton = null
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
	if _mrig:
		_mrig.flash(_flash * 6.0)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	var move := Vector3.ZERO
	if not _dead and is_instance_valid(target) and not target.dead:
		var to := target.global_position - global_position
		to.y = 0
		var level := get_tree().current_scene
		if not active and not level.get("calm") and to.length() < WAKE_DISTANCE and (not level.has_method("path_length") or level.path_length(global_position, target.global_position) < 9):
			active = true
		if active:
			_repath -= delta
			if _repath <= 0.0 and level.has_method("path_next"):
				_repath = 0.3
				_waypoint = level.path_next(global_position, target.global_position)
			var reach := 0.95
			if kind == "robot" and variant != "bomb":
				reach = SWING_RANGE * 0.8
				if _swing < 0.0 and to.length() < SWING_RANGE and _touch_cooldown <= 0.0:
					_start_swing()
					_touch_cooldown = SWING_WINDUP + SWING_STRIKE + SWING_RECOVER + 0.4
			if not _met:
				_met = true
				if level.has_method("meet"):
					level.meet(variant)
			var special := _ability(delta, to, level)
			if special != Vector3.INF:
				move = special      # the variant's trick decides how it moves
			elif _swing >= 0.0 and _swing < SWING_WINDUP + SWING_STRIKE:
				pass   # planted while swinging
			elif to.length() > reach:
				var goal := to
				if _waypoint != Vector3.INF and to.length() > 2.5:
					goal = _waypoint - global_position
					goal.y = 0
				move = goal.normalized() * speed
			elif kind != "robot" and variant != "taser" and _touch_cooldown <= 0.0:
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
		var to_target := Vector3.ZERO
		if is_instance_valid(target):
			to_target = target.global_position - global_position
			to_target.y = 0
		if is_instance_valid(target) and not target.dead:
			_update_swing(delta, to_target)
		else:
			_update_swing(delta, Vector3(999, 0, 0))
		# roll: spin the wheel by the distance covered, lean into the speed,
		# rock back when knocked, and wobble to keep balance
		var fwd := Vector3(sin(_body.rotation.y), 0, cos(_body.rotation.y))
		var along := Vector3(velocity.x, 0, velocity.z).dot(fwd)
		_wheel_spin += along * delta / _wheel_r
		for hub in _hubs:
			hub.rotation.x = _wheel_spin
		var want_lean := clampf(along * 0.07, -0.3, 0.3) - 0.12 * _arm_raise
		_lean = lerpf(_lean, want_lean, minf(1.0, delta * 6.0))
		_body.rotation.x = _lean
		_body.rotation.z = sin(_t * 2.3) * 0.035
		_pose_arms()
	elif _mrig:
		_mrig.update(delta, move != Vector3.ZERO, Vector2(velocity.x, velocity.z).length())
	else:
		_body.position.y = absf(sin(_walk)) * 0.04
		_body.rotation.z = sin(_walk) * 0.05
