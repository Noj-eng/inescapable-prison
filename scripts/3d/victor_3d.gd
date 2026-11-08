extends CharacterBody3D
## Victor in 3D. WASD moves (relative to the camera), left click, Space or J
## punches: a snappy jab, jab, hook combo that hits everything in a
## 120-degree arc in front of him.
## Uses res://models/victor.glb (the rigged Meshy model) if it's there,
## otherwise a stand-in built from simple shapes.

signal health_changed(hp: int, max_hp: int)
signal died
signal xp_changed(xp: int, needed: int, level: int)
signal leveled_up

const Look := preload("res://scripts/3d/look_3d.gd")
const ARC_SHADER := preload("res://shaders/punch_arc_3d.gdshader")
const MeshyRig := preload("res://scripts/3d/meshy_rig.gd")
const HEIGHT := 2.2               # metres: Victor is a big man
const Tune := preload("res://scripts/3d/tuning_3d.gd")
const SPEED := Tune.VICTOR_SPEED
const Skills := preload("res://scripts/3d/skills_3d.gd")
const Equipment := preload("res://scripts/3d/equipment_3d.gd")
const RunXP := preload("res://scripts/3d/run_xp_3d.gd")
const RALLY_RADIUS := 10.0      # metres: prisoners this close hear the shout
const PUNCH_REACH := 1.9
const PUNCH_ARC := 0.5            # cos(60 degrees) -> 120-degree arc
const PUNCH_COOLDOWN := 0.24
const PUNCH_ANIM := 0.16

var max_hp := 10
var hp := 10
var dead := false
var facing := Vector3(0, 0, 1)     # flat direction he's facing
var camera: Camera3D

var _knock := Vector3.ZERO
var _punch_time := 0.0
var _punch_cooldown := 0.0
var _combo := 0
var _combo_timer := 0.0
var _punch_side := 1
var _hurt := 0.0
var _invulnerable := 0.0
var _slow_t := 0.0                # seconds left of being slowed (taser darts, shocks)
# powerups (scripts/3d/powerup_3d.gd): seconds left on each, and armour hits left
var knuckles_t := 0.0
var coffee_t := 0.0
var rage_t := 0.0
var armour := 0
var _armour_shell: MeshInstance3D
var _rally_cooldown := 0.0
var _gear_nodes := []       # armour/weapon pieces riding his bones
# level-up abilities (run_xp_3d.gd)
var _storm_t := 2.0
var _shards: Array[MeshInstance3D] = []
var _shard_hit := {}        # enemy -> seconds until a shard can cut it again
var _shard_angle := 0.0
var _armour_mat: StandardMaterial3D
var _walk := 0.0
var _t := 0.0

# stand-in body parts (animated by hand)
var _rig: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _skin_mat: StandardMaterial3D
# the Meshy model, if present
var _model: Node3D
var _mrig: RefCounted   # MeshyRig, when the Meshy model is loaded

var _swipe: MeshInstance3D
var _swipe_mat: ShaderMaterial
var _swipe_t := 1.0
var _swipe_len := 0.12


func _ready() -> void:
	add_to_group("player")
	# skills from the PRISON REP tree, plus this run's perks
	max_hp = 10 + int(Skills.value("max_hp"))
	hp = max_hp
	armour = int(Skills.value("armour_start"))
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = HEIGHT
	shape.shape = cap
	shape.position.y = HEIGHT * 0.5
	add_child(shape)

	_rig = Node3D.new()
	add_child(_rig)
	# a soft warm light that travels with Victor, so he reads in the dark
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.85, 0.7)
	glow.light_energy = Tune.VICTOR_LIGHT
	glow.omni_range = 6.0
	glow.omni_attenuation = 1.2
	glow.position = Vector3(1.2, 3.2, 1.2)    # up and toward the camera
	add_child(glow)
	if MeshyRig.find("victor.glb") != "":
		_load_model()
	else:
		_build_stand_in()
	_build_shards()        # Telekinetic Storm carries over between floors

	# a see-through blue shell while Mattress Armour is soaking hits
	_armour_shell = MeshInstance3D.new()
	var shell := SphereMesh.new()
	shell.radius = 0.95
	shell.height = HEIGHT * 1.1
	_armour_shell.mesh = shell
	_armour_mat = StandardMaterial3D.new()
	_armour_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_armour_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_armour_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_armour_mat.albedo_color = Color(0.35, 0.7, 1.0, 0.12)
	_armour_shell.material_override = _armour_mat
	_armour_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_armour_shell.position.y = HEIGHT * 0.5
	_armour_shell.visible = false
	add_child(_armour_shell)

	_swipe = MeshInstance3D.new()
	_swipe.mesh = _arc_mesh()
	_swipe_mat = ShaderMaterial.new()
	_swipe_mat.shader = ARC_SHADER
	_swipe.material_override = _swipe_mat
	_swipe.position.y = 1.25
	_swipe.visible = false
	add_child(_swipe)


# --- body ----------------------------------------------------------------------

func _load_model() -> void:
	# Jon's Meshy model. Its walk/run clip plays while moving; punches bend
	# the arm and spine bones on top of it, so no punch clip is needed.
	_mrig = MeshyRig.load_into(_rig, MeshyRig.find("victor.glb"), HEIGHT)
	_model = _mrig.model
	_gear_nodes = Equipment.dress(_mrig, Skills.gear)


## Put on a new piece of gear mid-floor (and refresh the look).
func wear(id: String) -> void:
	Skills.add_run_bonus(id)
	for n in _gear_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_gear_nodes = Equipment.dress(_mrig, Skills.gear) if _mrig else []
	_refresh_max_hp()


func _refresh_max_hp() -> void:
	var new_max := 10 + int(Skills.value("max_hp"))
	hp += maxi(0, new_max - max_hp)
	max_hp = new_max
	health_changed.emit(hp, max_hp)


# --- experience and level-up abilities -------------------------------------------

func pickup_radius() -> float:
	return 2.5 + 2.0 * Skills.value("magnet")


func add_xp(amount: int) -> void:
	var gained := RunXP.add(amount)
	xp_changed.emit(RunXP.xp, RunXP.needed(), RunXP.level)
	if gained > 0:
		leveled_up.emit()


## Picked on the level-up screen.
func learn(id: String) -> void:
	RunXP.take(id)
	_refresh_max_hp()     # Iron Hide raises max health and heals the difference
	_build_shards()


## Every beaten enemy: Dark Vitality heals now and then.
func on_knockout() -> void:
	RunXP.knockouts += 1
	var v := int(Skills.value("vitality"))
	if v > 0 and RunXP.knockouts % maxi(2, 7 - v) == 0 and hp < max_hp:
		hp += 1
		health_changed.emit(hp, max_hp)


func _enemies_near(radius: float) -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(global_position) < radius:
			out.append(e)
	return out


## Seismic Slam: the heavy hook cracks the floor all around him.
func _seismic() -> void:
	var r := 2.6 + 0.5 * Skills.value("seismic")
	for e in _enemies_near(r):
		e.take_hit(global_position, 1.0 + 0.3 * Skills.value("seismic"), 7.0)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	ring.mesh = torus
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.6, 0.25, 0.9)
	ring.material_override = m
	ring.position = global_position + Vector3(0, 0.08, 0)
	ring.scale = Vector3(0.5, 0.15, 0.5)
	get_tree().current_scene.add_child(ring)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(r, 0.15, r), 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(ring.queue_free)
	_shake(0.25)


## Storm Caller: every few seconds a bolt jumps to the nearest enemy.
func _storm(delta: float) -> void:
	var rank := Skills.value("storm")
	if rank <= 0.0:
		return
	_storm_t -= delta
	if _storm_t > 0.0:
		return
	_storm_t = maxf(0.8, 3.6 - 0.5 * rank)
	var best: Node3D = null
	var best_d := 9.0
	for e in _enemies_near(9.0):
		var d: float = e.global_position.distance_to(global_position)
		if d < best_d:
			best = e
			best_d = d
	if best == null:
		_storm_t = 0.3
		return
	best.take_hit(global_position, 1.0 + 0.25 * rank, 3.0)
	_bolt(global_position + Vector3(0, 1.8, 0), best.global_position + Vector3(0, 1.0, 0))


func _bolt(a: Vector3, b: Vector3) -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var steps := 8
	for i in steps + 1:
		var t := float(i) / steps
		var p := a.lerp(b, t)
		if i > 0 and i < steps:
			p += Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		im.surface_add_vertex(p)
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.6, 0.85, 1.0)
	mi.material_override = m
	get_tree().current_scene.add_child(mi)
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.5, 0.8, 1.0)
	flash.light_energy = 4.0
	flash.omni_range = 4.0
	flash.position = b
	get_tree().current_scene.add_child(flash)
	get_tree().create_timer(0.12).timeout.connect(func():
		mi.queue_free()
		flash.queue_free())


## Telekinetic Storm: shards of casing orbiting him (one more per rank).
func _build_shards() -> void:
	var want := int(Skills.value("shards")) + (1 if Skills.value("shards") > 0.0 else 0)
	while _shards.size() < want:
		var s := MeshInstance3D.new()
		var b := PrismMesh.new()
		b.size = Vector3(0.22, 0.35, 0.08)
		s.mesh = b
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.3, 0.32, 0.36)
		m.metallic = 0.8
		m.roughness = 0.35
		m.emission_enabled = true
		m.emission = Color(0.55, 0.4, 1.0)
		m.emission_energy_multiplier = 1.2
		s.material_override = m
		s.top_level = true
		add_child(s)
		_shards.append(s)


func _spin_shards(delta: float) -> void:
	if _shards.is_empty():
		return
	_shard_angle += delta * 3.2
	for e in _shard_hit.keys():
		_shard_hit[e] -= delta
		if _shard_hit[e] <= 0.0:
			_shard_hit.erase(e)
	var r := 1.7
	for i in _shards.size():
		var a := _shard_angle + TAU * i / _shards.size()
		var p := global_position + Vector3(cos(a) * r, 1.2 + 0.15 * sin(_t * 4.0 + i), sin(a) * r)
		_shards[i].global_position = p
		_shards[i].rotation = Vector3(_t * 5.0 + i, a, 0.4)
		for e in _enemies_near(r + 1.0):
			if _shard_hit.has(e):
				continue
			var d: Vector3 = e.global_position - p
			d.y = 0
			if d.length() < 0.8:
				e.take_hit(p, 0.5 + 0.15 * Skills.value("shards"), 2.5)
				_shard_hit[e] = 0.5


## A placeholder Victor: a huge bald brute in a torn orange jumpsuit, arms
## bare and tattooed. Replaced automatically by the Meshy model.
func _build_stand_in() -> void:
	var suit := Look.matte(Color("d9692a"))
	var suit_dark := Look.matte(Color("a14b1c"))
	_skin_mat = Look.matte(Color("b48a6e")).duplicate()
	var ink := Look.matte(Color("2c2a33"))
	# legs (pivot at the hips so they can swing)
	_leg_l = Node3D.new()
	_leg_l.position = Vector3(-0.22, 1.0, 0)
	_rig.add_child(_leg_l)
	_leg_r = Node3D.new()
	_leg_r.position = Vector3(0.22, 1.0, 0)
	_rig.add_child(_leg_r)
	for leg in [_leg_l, _leg_r]:
		Look.capsule(leg, 0.17, 1.0, Vector3(0, -0.5, 0), suit)
		Look.box(leg, Vector3(0.3, 0.14, 0.42), Vector3(0, -0.95, 0.06), Look.matte(Color("1a1a1e")))
	# torso: a broad wedge, jumpsuit torn open at the chest
	var torso := Look.box(_rig, Vector3(0.95, 0.85, 0.55), Vector3(0, 1.45, 0), suit)
	torso.scale = Vector3(1.0, 1.0, 1.0)
	Look.box(_rig, Vector3(0.7, 0.3, 0.5), Vector3(0, 1.08, 0), suit_dark)          # belt line
	Look.box(_rig, Vector3(0.36, 0.5, 0.05), Vector3(0, 1.62, 0.27), _skin_mat)     # bare chest in the tear
	Look.box(_rig, Vector3(0.08, 0.4, 0.06), Vector3(0, 1.6, 0.29), ink)           # chest tattoo
	# shoulders and bare, tattooed arms (pivot at the shoulder)
	_arm_l = Node3D.new()
	_arm_l.position = Vector3(-0.6, 1.78, 0)
	_rig.add_child(_arm_l)
	_arm_r = Node3D.new()
	_arm_r.position = Vector3(0.6, 1.78, 0)
	_rig.add_child(_arm_r)
	for arm in [_arm_l, _arm_r]:
		Look.sphere(arm, 0.24, Vector3.ZERO, suit)                                  # torn sleeve stump
		Look.capsule(arm, 0.16, 0.85, Vector3(0, -0.45, 0), _skin_mat)
		Look.cylinder(arm, 0.165, 0.08, Vector3(0, -0.3, 0), ink)                   # tattoo bands
		Look.cylinder(arm, 0.165, 0.05, Vector3(0, -0.5, 0), ink)
		Look.sphere(arm, 0.17, Vector3(0, -0.92, 0), _skin_mat)                     # fist
	# bald head, heavy brow, thick neck
	Look.cylinder(_rig, 0.17, 0.2, Vector3(0, 1.95, 0), _skin_mat)
	Look.sphere(_rig, 0.24, Vector3(0, 2.15, 0.02), _skin_mat)
	Look.box(_rig, Vector3(0.36, 0.06, 0.1), Vector3(0, 2.2, 0.2), Look.matte(Color("8e6a52")))


# --- combat --------------------------------------------------------------------

func slow(seconds: float) -> void:
	if rage_t > 0.0:
		return             # hooch: too angry to notice
	_slow_t = maxf(_slow_t, seconds * maxf(0.2, 1.0 - Skills.value("stun_resist")))


## Picking up a powerup (see powerup_3d.gd for what each one is).
func power_up(kind: String) -> void:
	match kind:
		"medkit":
			hp = mini(max_hp, hp + Tune.MEDKIT_HEAL)
			health_changed.emit(hp, max_hp)
		"knuckles":
			knuckles_t = Tune.KNUCKLES_TIME * _pockets()
		"coffee":
			coffee_t = Tune.COFFEE_TIME * _pockets()
		"mattress":
			armour = maxi(armour, Tune.MATTRESS_HITS)
		"hooch":
			rage_t = Tune.HOOCH_TIME * _pockets()
			_slow_t = 0.0


func _mrig_flash(c: Color) -> void:
	if _mrig:
		_mrig.flash(0.7, c)


func _pockets() -> float:
	return 1.0 + Skills.value("powerup_time")      # Deep Pockets skill


## F: shout for the prisoners nearby to join Victor's gang.
func _rally() -> void:
	_rally_cooldown = 1.0
	var level := get_tree().current_scene
	if not Skills.can_rally():
		if level.has_method("_say"):
			level._say("Nobody listens to you yet.\nBuy RALLY THE PRISONERS in the skill tree.", Color(0.62, 0.7, 0.82), 2.0)
		return
	var room := Skills.gang_size()
	for g in get_tree().get_nodes_in_group("prisoners"):
		if g.get("recruited"):
			room -= 1
	var near := []
	for g in get_tree().get_nodes_in_group("prisoners"):
		if not g.get("recruited") and g.has_method("recruit") and g.global_position.distance_to(global_position) < RALLY_RADIUS:
			near.append(g)
	near.sort_custom(func(a, b): return a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position))
	var joined := 0
	for g in near:
		if joined >= room:
			break
		g.power = 1.0 + Skills.value("recruit_power")     # Hardened Recruits skill
		g.recruit(self)
		joined += 1
	_shake(0.12)
	_shout_ring()
	if level.has_method("_say"):
		if joined > 0:
			level._say("%d JOINED THE GANG." % joined, Color("4dd8ff"), 1.6)
		elif room <= 0:
			level._say("Your gang is full (%d)." % Skills.gang_size(), Color("4dd8ff"), 1.6)
		else:
			level._say("No prisoners close enough to hear you.", Color(0.62, 0.7, 0.82), 1.6)


func _shout_ring() -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	ring.mesh = torus
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.3, 0.85, 1.0, 0.8)
	ring.material_override = m
	ring.position = global_position + Vector3(0, 0.1, 0)
	ring.scale = Vector3(1, 0.2, 1)
	get_tree().current_scene.add_child(ring)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(RALLY_RADIUS, 0.2, RALLY_RADIUS), 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(ring.queue_free)


## What's active right now, for the HUD: e.g. "KNUCKLES 8  ARMOUR x2".
func buff_text() -> String:
	var parts: Array[String] = []
	if knuckles_t > 0.0: parts.append("KNUCKLES %d" % ceili(knuckles_t))
	if coffee_t > 0.0: parts.append("COFFEE %d" % ceili(coffee_t))
	if rage_t > 0.0: parts.append("RAGE %d" % ceili(rage_t))
	if armour > 0: parts.append("ARMOUR x%d" % armour)
	return "   ".join(parts)


func hit(from: Vector3, damage := 1, force := 6.0) -> void:
	if dead or _invulnerable > 0.0:
		return
	if armour > 0:
		# the mattress takes it: a light shove and no damage
		armour -= 1
		var push := global_position - from
		push.y = 0
		_knock = push.normalized() * force * 0.4
		_invulnerable = 0.5
		_armour_mat.albedo_color.a = 0.6
		_shake(0.1)
		return
	if randf() < Skills.value("block"):
		# armour: the hit glances off, a shove and a spark but no damage
		var glance := global_position - from
		glance.y = 0
		_knock = glance.normalized() * force * 0.3
		_invulnerable = 0.4
		_mrig_flash(Color(0.8, 0.9, 1.0))
		_shake(0.08)
		return
	hp = maxi(0, hp - damage)
	health_changed.emit(hp, max_hp)
	var away := global_position - from
	away.y = 0
	_knock = away.normalized() * force * maxf(0.2, 1.0 - Skills.value("knock_resist"))
	_hurt = 0.25
	_invulnerable = 0.8
	_shake(0.25)
	if hp == 0:
		dead = true
		died.emit()


func _shake(amount: float) -> void:
	var level := get_tree().current_scene
	if level.has_method("shake"):
		level.shake(amount)


func _punch() -> void:
	if _combo_timer <= 0.0:
		_combo = 0
	var heavy := _combo == 2
	_punch_time = PUNCH_ANIM
	_punch_cooldown = PUNCH_COOLDOWN * (1.6 if heavy else 1.0)
	_punch_side = -_punch_side
	_combo_timer = 0.55
	_knock += facing * 3.0     # small lunge forward

	var raging := rage_t > 0.0
	if raging:
		_punch_cooldown *= 0.8
	_punch_cooldown /= maxf(0.4, 1.0 + Skills.value("punch_speed"))   # shiv: faster, pipe: slower
	var reach := PUNCH_REACH * (1.25 if heavy else 1.0) * (1.4 if raging else 1.0) * (1.0 + Skills.value("reach"))
	var arc := (0.26 if raging else PUNCH_ARC) - Skills.value("arc")   # rage or chain: wider
	var power := (2.0 if heavy else 1.0) * (2.0 if knuckles_t > 0.0 else 1.0) * (1.0 + Skills.value("damage"))
	var force := (9.0 if heavy else 5.5) * (1.8 if raging else 1.0) * (1.0 + Skills.value("knockback"))
	_start_swipe(reach, heavy)
	var landed := false
	# "breakables": things he can smash, like the armory vault doors
	for enemy in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("breakables"):
		var d: Vector3 = enemy.global_position - global_position
		d.y = 0
		var dist := d.length()
		if dist < reach + 0.4 and (dist < 0.5 or d.normalized().dot(facing) > arc):
			enemy.take_hit(global_position, power, force)
			landed = true
	if landed:
		_shake(0.18 if heavy else 0.08)
		_hit_stop(0.09 if heavy else 0.05)
	if heavy and Skills.value("seismic") > 0.0:
		_seismic()
	_combo = (_combo + 1) % 3


func _hit_stop(seconds: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


func _arc_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		var t := float(i) / steps
		var a := lerpf(-PI / 3.0, PI / 3.0, t)
		var d := Vector3(sin(a), 0, cos(a))   # centred on +Z (forward)
		verts.append(d * 0.35)
		uvs.append(Vector2(t, 0.0))
		verts.append(d * 1.0)
		uvs.append(Vector2(t, 1.0))
	var idx := PackedInt32Array()
	for i in steps:
		var k := i * 2
		idx.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _start_swipe(reach: float, heavy: bool) -> void:
	_swipe_t = 0.0
	_swipe_len = 0.16 if heavy else 0.11
	_swipe.visible = true
	_swipe.basis = Basis.looking_at(-facing, Vector3.UP).scaled(Vector3.ONE * (reach + 0.3))
	_swipe_mat.set_shader_parameter("sweep_dir", float(_punch_side))
	_swipe_mat.set_shader_parameter("heavy", 1.0 if heavy else 0.0)
	var tint := Color(1.0, 0.62, 0.3) if heavy else Color(0.75, 0.95, 1.0)
	if knuckles_t > 0.0:
		tint = Color(1.0, 0.82, 0.3)
	if rage_t > 0.0:
		tint = Color(0.55, 1.0, 0.3)
	_swipe_mat.set_shader_parameter("tint", tint)
	_swipe_mat.set_shader_parameter("progress", 0.0)


# --- every frame -----------------------------------------------------------------

func _move_input() -> Vector3:
	var x := 0.0
	var y := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): y += 1.0
	if x == 0.0 and y == 0.0 or not camera:
		return Vector3.ZERO
	# screen directions flattened onto the floor
	var right := camera.global_basis.x
	right.y = 0
	var down := camera.global_basis.z
	down.y = 0
	return (right.normalized() * x + down.normalized() * y).normalized()


func _mouse_on_floor() -> Vector3:
	var mp := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mp)
	var dir := camera.project_ray_normal(mp)
	if absf(dir.y) < 0.001:
		return global_position
	var t := (global_position.y + 1.0 - from.y) / dir.y
	return from + dir * t


func _physics_process(delta: float) -> void:
	_t += delta
	_hurt = maxf(0.0, _hurt - delta)
	_invulnerable = maxf(0.0, _invulnerable - delta)
	_slow_t = maxf(0.0, _slow_t - delta)
	knuckles_t = maxf(0.0, knuckles_t - delta)
	coffee_t = maxf(0.0, coffee_t - delta)
	rage_t = maxf(0.0, rage_t - delta)
	_armour_shell.visible = armour > 0 and not dead
	_armour_mat.albedo_color.a = move_toward(_armour_mat.albedo_color.a, 0.08 + 0.04 * armour, delta * 2.0)
	_punch_time = maxf(0.0, _punch_time - delta)
	_punch_cooldown = maxf(0.0, _punch_cooldown - delta)
	_combo_timer = maxf(0.0, _combo_timer - delta)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	if dead:
		_knock = _knock.move_toward(Vector3.ZERO, 30.0 * delta)
		velocity = Vector3(_knock.x, velocity.y, _knock.z)
		move_and_slide()
		_rig.rotation.x = move_toward(_rig.rotation.x, -PI / 2.2, delta * 4.0)
		return

	var move := _move_input()
	if move != Vector3.ZERO:
		facing = move
	var clicking := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if clicking and camera:
		var to := _mouse_on_floor() - global_position
		to.y = 0
		if to.length() > 0.2:
			facing = to.normalized()
	var punching := clicking or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_J)
	if punching and _punch_cooldown <= 0.0:
		_punch()
	_rally_cooldown = maxf(0.0, _rally_cooldown - delta)
	if Input.is_key_pressed(KEY_F) and _rally_cooldown <= 0.0:
		_rally()

	var speed := SPEED * (Tune.VICTOR_PUNCH_SLOWDOWN if _punch_time > 0.0 else 1.0) * (0.5 if _slow_t > 0.0 else 1.0) \
			* (Tune.COFFEE_SPEED if coffee_t > 0.0 else 1.0) * (1.0 + Skills.value("speed"))
	var flat := move * speed + _knock
	_knock = _knock.move_toward(Vector3.ZERO, 30.0 * delta)
	velocity = Vector3(flat.x, velocity.y, flat.z)
	move_and_slide()

	# turn to face where he's going / punching
	var target_yaw := atan2(facing.x, facing.z)
	_rig.rotation.y = lerp_angle(_rig.rotation.y, target_yaw, minf(1.0, delta * 18.0))
	_walk = _walk + delta * 9.0 if move != Vector3.ZERO else move_toward(_walk, roundf(_walk / PI) * PI, delta * 6.0)
	_animate(move != Vector3.ZERO)

	Equipment.keep_scale(_gear_nodes)
	_storm(delta)
	_spin_shards(delta)
	if _swipe_t < 1.0:
		_swipe_t = minf(1.0, _swipe_t + delta / _swipe_len)
		_swipe_mat.set_shader_parameter("progress", _swipe_t)
		_swipe.visible = _swipe_t < 1.0


func _animate(walking: bool) -> void:
	if _mrig:
		_mrig.update(get_physics_process_delta_time(), walking, Vector2(velocity.x, velocity.z).length())
		# the punch: throw the arm forward, twist the shoulders into it
		var pk := 1.0 - _punch_time / PUNCH_ANIM if _punch_time > 0.0 else 0.0
		var throw := sin(pk * PI) if _punch_time > 0.0 else 0.0
		var side := "r" if _punch_side > 0 else "l"
		var heavy := 1.3 if _combo == 0 and _punch_time > 0.0 else 1.0   # combo has already advanced
		_mrig.turn("spine", Vector3.UP, 0.45 * throw * _punch_side * heavy)
		_mrig.turn("arm_" + side, Vector3.RIGHT, -1.5 * throw)
		_mrig.turn("fore_" + side, Vector3.RIGHT, -0.9 * throw)
		# guard up between punches
		if _combo_timer > 0.0:
			_mrig.turn("fore_l", Vector3.RIGHT, -0.5 * (1.0 - throw))
			_mrig.turn("fore_r", Vector3.RIGHT, -0.5 * (1.0 - throw))
		if _hurt > 0.0:
			_mrig.flash(_hurt * 3.0, Color(1, 0.2, 0.15))
		elif rage_t > 0.0:
			_mrig.flash(0.18 + 0.1 * sin(_t * 12.0), Color(0.5, 1.0, 0.3))
		else:
			_mrig.flash(0.3 + 0.15 * sin(_t * 20.0) if _slow_t > 0.0 else 0.0, Color(0.3, 0.9, 1.0))
		return
	# stand-in: swing legs, pump the punching arm forward, flash red when hurt
	var swing := sin(_walk) * 0.6
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	var k := 1.0 - _punch_time / PUNCH_ANIM if _punch_time > 0.0 else 0.0
	var thrust := sin(k * PI) * 1.5 if _punch_time > 0.0 else 0.0
	var guard := 0.5 if _combo_timer > 0.0 else 0.0
	var punch_l := thrust if _punch_side < 0 else 0.0
	var punch_r := thrust if _punch_side > 0 else 0.0
	_arm_l.rotation.x = -swing * 0.5 - punch_l - guard * 0.6
	_arm_r.rotation.x = swing * 0.5 - punch_r - guard * 0.6
	_arm_l.rotation.z = -0.15
	_arm_r.rotation.z = 0.15
	_rig.position.y = absf(sin(_walk)) * 0.05
	_rig.scale = Vector3.ONE * (1.0 + sin(_t * 2.0) * 0.01)
	_skin_mat.emission_enabled = _hurt > 0.0
	_skin_mat.emission = Color(1, 0.15, 0.1)
	_skin_mat.emission_energy_multiplier = _hurt * 8.0
