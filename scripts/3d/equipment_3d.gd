extends RefCounted
## Victor's gear: armour pieces and weapons he picks up during a run (floor
## rewards). Each piece is fixed to a bone of his skeleton with a
## BoneAttachment3D, so it moves with the run and punch animations.
##
## Until Jon makes the real pieces in Meshy, each piece is built from simple
## shapes. To swap in a Meshy model, drop it in res://models/gear/ named
## after the piece id (e.g. models/gear/helmet.glb). It's sized to `fit`
## metres and placed where the stand-in was; nudge it with `offset`.
##
##   slot:   where it goes; a new piece replaces the old one in the same slot
##   bones:  the skeleton bones it rides on (one copy per bone)
##   stats:  added to Victor's stats (same names as skills_3d.gd)
##     block        chance a hit does no damage at all
##     stun_resist  shorter taser / shock slowdowns
##     knock_resist less knockback
##     reach, arc, punch_speed   for weapons

const GEAR := {
	# --- armour --------------------------------------------------------------
	"helmet": {
		"slot": "head", "name": "RIOT HELMET", "bones": ["head"], "fit": 0.42, "offset": Vector3(0, 0.2, 0.01),
		"stats": {"block": 0.08, "stun_resist": 0.5},
		"desc": "8% of hits bounce off. Taser darts slow you half as long.",
	},
	"shoulders": {
		"slot": "shoulders", "name": "SHOULDER PADS", "bones": ["arm_l", "arm_r"], "fit": 0.32, "offset": Vector3(0, 0.03, 0),
		"stats": {"block": 0.06, "knock_resist": 0.5},
		"desc": "Half the knockback. 6% of hits bounce off.",
	},
	"vest": {
		"slot": "chest", "name": "STAB VEST", "bones": ["spine"], "fit": 0.62, "offset": Vector3(0, 0.0, 0.02),
		"stats": {"max_hp": 3.0, "block": 0.06},
		"desc": "+3 max health. 6% of hits bounce off.",
	},
	"gauntlets": {
		"slot": "hands", "name": "STEEL GAUNTLETS", "bones": ["fore_l", "fore_r"], "fit": 0.3, "offset": Vector3(0, 0.16, 0),
		"stats": {"damage": 0.25},
		"desc": "+25% punch damage.",
	},
	"boots": {
		"slot": "feet", "name": "STEEL-TOE BOOTS", "bones": ["foot_l", "foot_r"], "fit": 0.3, "offset": Vector3(0, 0.05, 0),
		"stats": {"speed": 0.08, "stun_resist": 0.25},
		"desc": "+8% speed. Shrug off slowdowns faster.",
	},
	# --- weapons (one at a time, held in the right hand) -----------------------
	"shiv": {
		"slot": "weapon", "name": "SHIV", "bones": ["hand_r"], "fit": 0.4, "offset": Vector3(0, 0.1, 0.02),
		"stats": {"damage": 0.3, "punch_speed": 0.25, "reach": -0.15},
		"desc": "Quick, nasty jabs: +30% damage, 25% faster, a bit shorter.",
	},
	"chain": {
		"slot": "weapon", "name": "BIKE CHAIN", "bones": ["hand_r"], "fit": 0.9, "offset": Vector3(0, 0.08, 0),
		"stats": {"reach": 0.6, "arc": 0.25},
		"desc": "Hits much further out and wider.",
	},
	"pipe": {
		"slot": "weapon", "name": "LEAD PIPE", "bones": ["hand_r"], "fit": 0.95, "offset": Vector3(0, 0.08, 0),
		"stats": {"damage": 0.7, "knockback": 0.6, "punch_speed": -0.2},
		"desc": "Slow, brutal swings: +70% damage and big knockback.",
	},
}


static func is_gear(id: String) -> bool:
	return GEAR.has(id)


## Adds a piece to a gear list (a new piece replaces the one in its slot).
static func equip(gear: Array, id: String) -> void:
	var slot: String = GEAR[id]["slot"]
	for g in gear.duplicate():
		if GEAR[g]["slot"] == slot:
			gear.erase(g)
	gear.append(id)


static func stat(gear: Array, name: String) -> float:
	var v := 0.0
	for g in gear:
		v += float(GEAR[g]["stats"].get(name, 0.0))
	return v


# --- looks ---------------------------------------------------------------------

## Puts every piece in `gear` on the rig (a MeshyRig). Returns the nodes made,
## so they can be removed again. Each one rides a bone via BoneAttachment3D.
static func dress(rig: RefCounted, gear: Array) -> Array:
	var made := []
	if rig == null or rig.skel == null:
		return made
	for id: String in gear:
		var info: Dictionary = GEAR[id]
		for key: String in info["bones"]:
			if not rig.bones.has(key):
				continue
			var att := BoneAttachment3D.new()
			att.bone_name = rig.skel.get_bone_name(rig.bones[key])
			rig.skel.add_child(att)
			# the bone space is scaled by the model import: undo that so the
			# piece can be built in plain metres
			var fit := Node3D.new()
			fit.name = "Fit"
			att.add_child(fit)
			var side := -1.0 if key.ends_with("_l") else 1.0
			var piece := _model_piece(id, info) if _has_model(id) else _stand_in(id, side)
			piece.position = info["offset"]
			fit.add_child(piece)
			made.append(att)
	return made


## Call each frame after the animation: keeps the pieces at their real size.
static func keep_scale(made: Array) -> void:
	for att: BoneAttachment3D in made:
		if not is_instance_valid(att):
			continue
		var s := att.global_basis.get_scale()
		if s.x > 0.0001:
			(att.get_child(0) as Node3D).scale = Vector3(1.0 / s.x, 1.0 / s.y, 1.0 / s.z)


static func _has_model(id: String) -> bool:
	return ResourceLoader.exists("res://models/gear/%s.glb" % id)


static func _model_piece(id: String, info: Dictionary) -> Node3D:
	var m: Node3D = (load("res://models/gear/%s.glb" % id) as PackedScene).instantiate()
	var box := AABB()
	var first := true
	for c in m.find_children("*", "VisualInstance3D", true, false):
		var b: AABB = (c as VisualInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	var holder := Node3D.new()
	holder.add_child(m)
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if longest > 0.0001:
		m.scale = Vector3.ONE * float(info["fit"]) / longest
		m.position = -box.get_center() * m.scale.x
	return holder


# Stand-ins: salvaged riot gear, gunmetal plates with a stencilled orange
# "prison property" stripe. In bone space +Y runs along the bone.
static func _plate() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.22, 0.24, 0.27)
	m.metallic = 0.75
	m.roughness = 0.45
	return m


static func _trim() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.45, 0.1)
	m.roughness = 0.7
	m.emission_enabled = true
	m.emission = Color(0.95, 0.45, 0.1)
	m.emission_energy_multiplier = 0.25
	return m


static func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


static func _cyl(r_top: float, r_bot: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = 16
	return c


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s


static func _stand_in(id: String, side: float) -> Node3D:
	var n := Node3D.new()
	var plate := _plate()
	var trim := _trim()
	match id:
		"helmet":
			# a riot helmet: dome, brim and a dark visor
			_mesh(n, _sphere(0.19), Vector3(0, 0.02, 0), plate, Vector3.ZERO, Vector3(1.0, 0.85, 1.08))
			_mesh(n, _cyl(0.195, 0.205, 0.04), Vector3(0, -0.04, 0), trim)
			var visor := StandardMaterial3D.new()
			visor.albedo_color = Color(0.05, 0.08, 0.12, 0.8)
			visor.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			visor.metallic = 0.9
			visor.roughness = 0.1
			_mesh(n, _box(Vector3(0.3, 0.08, 0.03)), Vector3(0, -0.1, 0.16), visor, Vector3(0.2, 0, 0))
		"shoulders":
			# a curved pad over the top of the upper arm
			_mesh(n, _sphere(0.16), Vector3(0, 0.02, 0), plate, Vector3.ZERO, Vector3(1.0, 0.65, 1.1))
			_mesh(n, _cyl(0.15, 0.16, 0.035), Vector3(0, -0.02, 0), trim, Vector3.ZERO, Vector3(1.0, 1.0, 1.1))
		"vest":
			# stab vest: front and back plates over the chest, straps between
			_mesh(n, _box(Vector3(0.52, 0.42, 0.06)), Vector3(0, 0.05, 0.2), plate, Vector3(-0.08, 0, 0))
			_mesh(n, _box(Vector3(0.52, 0.42, 0.06)), Vector3(0, 0.05, -0.2), plate)
			_mesh(n, _box(Vector3(0.54, 0.05, 0.42)), Vector3(0, -0.1, 0), trim)
			_mesh(n, _box(Vector3(0.18, 0.08, 0.02)), Vector3(0, 0.16, 0.235), trim, Vector3(-0.08, 0, 0))
		"gauntlets":
			# a steel sleeve along the forearm with a knuckle bar at the end
			_mesh(n, _cyl(0.11, 0.095, 0.26), Vector3.ZERO, plate)
			_mesh(n, _cyl(0.115, 0.115, 0.03), Vector3(0, 0.09, 0), trim)
			_mesh(n, _box(Vector3(0.16, 0.05, 0.08)), Vector3(0, 0.17, 0), plate)
		"boots":
			# steel toe caps and an ankle cuff
			_mesh(n, _cyl(0.085, 0.09, 0.1), Vector3(0, -0.02, 0), plate)
			_mesh(n, _box(Vector3(0.15, 0.16, 0.09)), Vector3(0, 0.1, -0.04), plate)
			_mesh(n, _box(Vector3(0.155, 0.03, 0.095)), Vector3(0, 0.03, -0.04), trim)
		"shiv":
			# a toothbrush-handle shiv: taped grip and a ground-down blade
			var tape := StandardMaterial3D.new()
			tape.albedo_color = Color(0.85, 0.82, 0.7)
			tape.roughness = 0.9
			_mesh(n, _cyl(0.02, 0.02, 0.12), Vector3.ZERO, tape)
			var blade := _plate()
			blade.albedo_color = Color(0.7, 0.72, 0.75)
			blade.metallic = 1.0
			blade.roughness = 0.2
			_mesh(n, _box(Vector3(0.035, 0.22, 0.008)), Vector3(0, 0.17, 0), blade)
		"chain":
			# a bike chain swinging from the fist
			var steel := _plate()
			steel.albedo_color = Color(0.5, 0.5, 0.52)
			for i in 9:
				var link := TorusMesh.new()
				link.inner_radius = 0.022
				link.outer_radius = 0.038
				_mesh(n, link, Vector3(0, 0.05 + i * 0.06, 0), steel, Vector3(PI / 2, 0, PI / 2 if i % 2 else 0.0))
			_mesh(n, _box(Vector3(0.05, 0.07, 0.03)), Vector3(0, 0.6, 0), trim)
		"pipe":
			# a length of lead pipe with a threaded elbow on the end
			var lead := _plate()
			lead.albedo_color = Color(0.36, 0.38, 0.4)
			lead.metallic = 0.6
			lead.roughness = 0.6
			_mesh(n, _cyl(0.035, 0.035, 0.85), Vector3(0, 0.3, 0), lead)
			_mesh(n, _cyl(0.05, 0.05, 0.1), Vector3(0, 0.72, 0), lead)
			_mesh(n, _cyl(0.04, 0.04, 0.12), Vector3(0, -0.06, 0), trim)
	return n
