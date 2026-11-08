extends CharacterBody3D
## A fellow prisoner, loose after the earthquake. Not hostile, and guards
## ignore them: they panic, run about, shout, and cower when the ground
## shakes or a fight gets close.
##
## Rallying (Victor's ability): call recruit(victor). The prisoner joins his
## gang (group "gang"): follows him and punches any guard that comes near.
## `power` scales their punches and toughness (raise it with ability levels).
## Uses res://models/prisoner.glb if it exists; otherwise a simple stand-in.

const Look := preload("res://scripts/3d/look_3d.gd")
const Tune := preload("res://scripts/3d/tuning_3d.gd")
const MeshyRig := preload("res://scripts/3d/meshy_rig.gd")

const SHOUTS := ["EARTHQUAKE!", "LET ME OUT!", "THE WALLS ARE COMING DOWN!", "I DIDN'T DO NOTHIN'!",
		"WE'RE ALL GONNA DIE!", "GUARDS! HELP!", "MA?!", "WHICH WAY IS OUT?!", "NOT AGAIN!"]
const VICTOR_SHOUTS := ["IT'S HIM! RUN!", "THAT'S VICTOR!", "DON'T HURT ME, MAN!", "GO GET 'EM, BIG GUY!"]
const GANG_SHOUTS := ["WE'RE WITH YOU!", "LET'S RIOT!", "FOR THE BLOCK!", "TAKE 'EM DOWN!"]

var level: Node                # the floor (cellblock_3d.gd)
var recruited := false
var leader: Node3D
var power := 1.0
var hp := 3.0
var state := "panic"           # panic, cower, follow, fight, down

var _goal := Vector3.INF
var _state_t := 0.0
var _waypoint := Vector3.INF
var _repath := 0.0
var _speed := Tune.PRISONER_SPEED
var _t := 0.0
var _shout_in := randf_range(2.0, 12.0)
var _punch_cd := 0.0
var _foe: Node3D
var _slot := randf() * TAU
var _body: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _armband: MeshInstance3D
var _mrig: RefCounted
var _flash := 0.0


func _ready() -> void:
	add_to_group("prisoners")
	collision_layer = 4          # nobody bumps into prisoners: they never block a corridor
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	shape.shape = cap
	shape.position.y = 0.85
	add_child(shape)
	_body = Node3D.new()
	add_child(_body)
	_speed *= randf_range(0.8, 1.1)
	if MeshyRig.find("prisoner.glb") != "":
		_mrig = MeshyRig.load_into(_body, MeshyRig.find("prisoner.glb"), randf_range(1.7, 1.95))
	else:
		_build_stand_in()
	_armband = Look.box(_body, Vector3(0.2, 0.08, 0.2), Vector3(0.32, 1.45, 0), Look.glow(Color(1.0, 0.15, 0.1), 3.0))
	_armband.visible = false


## Victor's rally ability calls this.
func recruit(by: Node3D) -> void:
	if state == "down":
		return
	recruited = true
	leader = by
	hp = 3.0 * power
	state = "follow"
	add_to_group("gang")
	_armband.visible = true
	_say(GANG_SHOUTS[randi() % GANG_SHOUTS.size()], Color(1.0, 0.45, 0.35))


## Only gang members get hit (guards ignore everyone else).
func take_hit(from: Vector3, damage := 1.0, force := 6.0) -> void:
	if state == "down":
		return
	hp -= damage
	_flash = 1.0
	var push := global_position - from
	push.y = 0
	velocity += push.normalized() * force
	if hp <= 0.0:
		state = "down"
		remove_from_group("gang")
		remove_from_group("prisoners")
		collision_layer = 0
		var tw := create_tween()
		tw.tween_property(_body, "rotation:x", -PI / 2, 0.35)
		tw.tween_property(_body, "position:y", 0.15, 0.2)


func _build_stand_in() -> void:
	var tall := randf_range(0.92, 1.06)
	var wide := randf_range(0.9, 1.2)
	_body.scale = Vector3(wide, tall, wide)
	var jumpsuit := Look.matte([Color("d4621f"), Color("c8571a"), Color("d98a4a"), Color("b85a2a")][randi() % 4])
	var skin := Look.matte([Color("e0b08a"), Color("c48a62"), Color("8d5a3c"), Color("5e3a26"), Color("f0c8a8")][randi() % 5])
	var tank := randf() < 0.3    # jumpsuit tied round the waist, white vest on top
	for sx: int in [-1, 1]:
		var hip := Node3D.new()
		hip.position = Vector3(0.12 * sx, 0.9, 0)
		_body.add_child(hip)
		Look.capsule(hip, 0.11, 0.9, Vector3(0, -0.45, 0), jumpsuit)
		Look.box(hip, Vector3(0.16, 0.1, 0.26), Vector3(0, -0.87, 0.05), Look.matte(Color("1a1a1c")))
		_legs.append(hip)
	Look.box(_body, Vector3(0.48, 0.62, 0.28), Vector3(0, 1.22, 0), Look.matte(Color("e8e4da")) if tank else jumpsuit)
	Look.box(_body, Vector3(0.5, 0.12, 0.3), Vector3(0, 0.95, 0), jumpsuit)
	if not tank:
		Look.box(_body, Vector3(0.16, 0.08, 0.02), Vector3(-0.1, 1.38, 0.145), Look.matte(Color("e8e4da")))   # number patch
	Look.capsule(_body, 0.07, 0.16, Vector3(0, 1.58, 0), skin)
	Look.sphere(_body, 0.14, Vector3(0, 1.74, 0), skin)
	match randi() % 4:
		0: pass                                               # shaved
		1: Look.sphere(_body, 0.145, Vector3(0, 1.77, -0.01), Look.matte(Color("1c1814"))).scale = Vector3(1, 0.7, 1)
		2: Look.sphere(_body, 0.15, Vector3(0, 1.8, 0), Look.matte(Color("3a3e44"))).scale = Vector3(1, 0.65, 1)   # beanie
		3: Look.box(_body, Vector3(0.22, 0.12, 0.08), Vector3(0, 1.64, 0.1), Look.matte(Color("2a2420")))       # beard
	for sx: int in [-1, 1]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(0.31 * sx, 1.48, 0)
		_body.add_child(shoulder)
		Look.capsule(shoulder, 0.075, 0.62, Vector3(0, -0.3, 0), skin if tank else jumpsuit)
		Look.sphere(shoulder, 0.065, Vector3(0, -0.64, 0), skin)
		_arms.append(shoulder)
	for m in _body.find_children("*", "GeometryInstance3D", true, false):
		(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _physics_process(delta: float) -> void:
	_t += delta
	if level == null or not is_instance_valid(level.player) or state == "down":
		return
	var victor: Node3D = level.player
	var to_v := victor.global_position - global_position
	to_v.y = 0
	var dist_v := to_v.length()
	if dist_v > 45.0 and not recruited:
		return          # far away: asleep, saves time on a huge floor
	_state_t -= delta
	_punch_cd = maxf(0.0, _punch_cd - delta)
	_flash = maxf(0.0, _flash - delta * 4.0)
	var move := Vector3.ZERO
	var run := _speed

	if recruited:
		if not is_instance_valid(leader):
			recruited = false
			state = "panic"
		else:
			move = _gang(delta)
	else:
		match state:
			"panic":
				if level._quake > 0.0 and randf() < delta * 3.0:
					_cower(randf_range(1.0, 2.0))
				elif dist_v < 2.5 and randf() < delta * 2.0:
					_cower(randf_range(1.0, 2.2))
					_say(VICTOR_SHOUTS[randi() % VICTOR_SHOUTS.size()], Color(1, 0.9, 0.7))
				else:
					if _goal == Vector3.INF or _state_t <= 0.0 or _flat(global_position - _goal) < 0.8:
						_pick_goal(victor, dist_v)
					move = _steer(_goal, delta)
			"cower":
				if _state_t <= 0.0:
					state = "panic"
					_goal = Vector3.INF
	# shouting
	_shout_in -= delta
	if _shout_in <= 0.0:
		_shout_in = randf_range(7.0, 16.0)
		if dist_v < 14.0 and not recruited:
			_say(SHOUTS[randi() % SHOUTS.size()], Color(1, 0.9, 0.7))

	velocity.x = move.x * run
	velocity.z = move.z * run
	velocity.y = -9.0 if not is_on_floor() else -0.5
	move_and_slide()
	if move.length() > 0.1:
		_body.rotation.y = lerp_angle(_body.rotation.y, atan2(move.x, move.z), minf(1.0, delta * 10.0))
	_animate(delta, move.length() > 0.1)


func _gang(delta: float) -> Vector3:
	# pick a fight with the nearest active guard near Victor
	if _foe == null or not is_instance_valid(_foe) or not _foe.is_in_group("enemies"):
		_foe = null
		var best := 7.0
		for e in get_tree().get_nodes_in_group("enemies"):
			var d: float = e.global_position.distance_to(leader.global_position)
			if d < best and e.get("active"):
				best = d
				_foe = e
	if _foe:
		var gap := _flat(_foe.global_position - global_position)
		if gap < 1.3:
			if _punch_cd <= 0.0:
				_punch_cd = 0.75
				_foe.take_hit(global_position, 0.5 * power, 3.5)
				if _arms.size() == 2:
					_arms[randi() % 2].rotation.x = -1.6
			var face := _foe.global_position - global_position
			face.y = 0
			_body.rotation.y = atan2(face.x, face.z)
			return Vector3.ZERO
		return _steer(_foe.global_position, delta)
	# otherwise stay close behind the boss
	var spot := leader.global_position + Vector3(cos(_slot), 0, sin(_slot)) * 2.2
	if _flat(spot - global_position) < 0.9:
		return Vector3.ZERO
	return _steer(spot, delta)


func _pick_goal(victor: Node3D, dist_v: float) -> void:
	_state_t = randf_range(2.0, 5.0)
	var away := Vector3.ZERO
	if dist_v < 6.0:
		away = (global_position - victor.global_position).normalized() * 6.0   # get away from the big man
	for attempt in 12:
		var p := global_position + away + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
		var gx := roundi(p.x / 2.0)
		var gy := roundi(p.z / 2.0)
		if level._ch(gx, gy) == ".":
			_goal = level.cell_pos(gx, gy)
			return
	_goal = global_position


func _cower(seconds: float) -> void:
	state = "cower"
	_state_t = seconds


func _steer(to: Vector3, delta: float) -> Vector3:
	_repath -= delta
	if _repath <= 0.0 or _waypoint == Vector3.INF:
		_repath = 0.45
		_waypoint = level.path_next(global_position, to)
	var d := _waypoint - global_position
	d.y = 0
	if d.length() < 0.3:
		_repath = 0.0
		return Vector3.ZERO
	return d.normalized()


func _flat(v: Vector3) -> float:
	v.y = 0
	return v.length()


func _animate(delta: float, moving: bool) -> void:
	if _mrig:
		_mrig.update(delta, moving, _speed if moving else 0.0)
		_mrig.flash(_flash)
		_body.scale.y = 0.8 if state == "cower" else 1.0
		return
	var cower := state == "cower"
	var swing := sin(_t * 13.0) * (0.8 if moving else 0.0)
	_body.position.y = lerpf(_body.position.y, -0.35 if cower else 0.0, minf(1.0, delta * 10.0))
	if _legs.size() == 2:
		_legs[0].rotation.x = swing if not cower else -1.2
		_legs[1].rotation.x = -swing if not cower else -1.2
	if _arms.size() == 2:
		if cower:
			# hands on head, shaking
			_arms[0].rotation = Vector3(-2.6, 0, -0.5 + sin(_t * 30) * 0.05)
			_arms[1].rotation = Vector3(-2.6, 0, 0.5 + sin(_t * 31) * 0.05)
		elif recruited:
			_arms[0].rotation.x = lerpf(_arms[0].rotation.x, -swing * 0.6 - 0.5, minf(1.0, delta * 8.0))
			_arms[1].rotation.x = lerpf(_arms[1].rotation.x, swing * 0.6 - 0.5, minf(1.0, delta * 8.0))
			_arms[0].rotation.z = 0.0
			_arms[1].rotation.z = 0.0
		else:
			# panicking: arms flailing over their heads
			_arms[0].rotation = Vector3(-2.3 + sin(_t * 9.0) * 0.5, 0, -0.3)
			_arms[1].rotation = Vector3(-2.3 + sin(_t * 9.0 + 2.0) * 0.5, 0, 0.3)


func _say(text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 56
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = color
	label.outline_size = 12
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.position = Vector3(0, 2.3, 0)
	add_child(label)
	var tw := create_tween()
	tw.tween_property(label, "position:y", 2.9, 1.6)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 1.6).set_delay(0.6)
	tw.tween_callback(label.queue_free)
