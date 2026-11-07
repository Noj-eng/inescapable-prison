extends RefCounted
## Loads a rigged Meshy (Mixamo-style) character and drives it: plays its
## walk/run clip while moving, holds a natural standing frame when still,
## and lets game code bend bones on top of the animation (punches, swings).
##
## Use:  rig = MeshyRig.load_into(parent_node, "res://models/x.glb", 2.2)
##       each physics frame: rig.update(delta, moving, speed_scale)
##       then: rig.turn("arm_r", Vector3.RIGHT, -1.2)  # model-space axis

var model: Node3D
var skel: Skeleton3D
var anim: AnimationPlayer
var bones := {}            # "arm_r", "fore_r", "hand_r", "arm_l", ..., "spine", "hips"
var move_clip := ""
var stand_time := 0.0
var overlay: StandardMaterial3D
var freeze_legs := false   # one-wheel robot: its "legs" are the wheel, never bend them
var _leg_bones: Array[int] = []
var _hips_rest := Vector3.ZERO
static var _announced: Array[String] = []


## Finds res://models/<name>, ignoring upper/lower case (Windows doesn't care
## about "Wheel_unit.glb" vs "wheel_unit.glb", but Godot does). "" if missing.
static func find(file_name: String) -> String:
	var want := file_name.to_lower()
	var dir := DirAccess.open("res://models")
	if dir == null:
		return ""
	for f in dir.get_files():
		var n := f.to_lower().trim_suffix(".import").trim_suffix(".remap")
		if n == want:
			return "res://models/" + f.trim_suffix(".import").trim_suffix(".remap")
	return ""


static func load_into(parent: Node3D, path: String, height: float) -> RefCounted:
	var rig = load("res://scripts/3d/meshy_rig.gd").new()
	rig._load(parent, path, height)
	return rig


func _load(parent: Node3D, path: String, height: float) -> void:
	var scene: PackedScene = load(path)
	if _announced.find(path) < 0:
		_announced.append(path)
		print("Meshy model loaded: ", path)
	model = scene.instantiate()
	parent.add_child(model)
	# size it: feet on the floor, `height` metres tall
	var box := AABB()
	var first := true
	for c in model.find_children("*", "VisualInstance3D", true, false):
		var vi := c as VisualInstance3D
		var b := vi.global_transform * vi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	box = parent.global_transform.affine_inverse() * box
	if box.size.y > 0.01:
		var s := height / box.size.y
		model.scale = Vector3.ONE * s
		model.position.y = -box.position.y * s
	# a see-through white layer over every mesh, for the hit flash
	overlay = StandardMaterial3D.new()
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.albedo_color = Color(1, 0.95, 0.9, 0.0)
	for g in model.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).material_overlay = overlay
	var skels := model.find_children("*", "Skeleton3D", true, false)
	if skels.size() > 0:
		skel = skels[0]
		_find_bones()
		if bones.has("hips"):
			_hips_rest = skel.get_bone_pose_position(bones["hips"])
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.size() > 0:
		anim = players[0]
		# we step the animation ourselves so bone tweaks land on top of it
		anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip in anim.get_animation_list():
			var n := String(clip).to_lower()
			if move_clip == "" and (n.contains("walk") or n.contains("run")):
				move_clip = clip
		if move_clip == "" and anim.get_animation_list().size() > 0:
			move_clip = anim.get_animation_list()[0]
		if move_clip != "":
			anim.get_animation(move_clip).loop_mode = Animation.LOOP_LINEAR
			anim.play(move_clip)
			_pick_stand_time()


func _pick_stand_time() -> void:
	# Find the moment in the walk cycle where the feet pass each other:
	# that frame makes the most natural "standing" pose.
	if not skel or not bones.has("foot_l") or not bones.has("foot_r"):
		return
	var length := anim.get_animation(move_clip).length
	var best := 1e9
	for i in 24:
		var t := length * i / 24.0
		anim.seek(t, true)
		var a := skel.get_bone_global_pose(bones["foot_l"]).origin
		var b := skel.get_bone_global_pose(bones["foot_r"]).origin
		var gap := absf(a.z - b.z)
		if gap < best:
			best = gap
			stand_time = t


func update(delta: float, moving: bool, speed := 1.0) -> void:
	if anim and move_clip != "":
		if moving:
			anim.speed_scale = speed
			anim.advance(delta)
		else:
			anim.seek(stand_time, true)
	if skel and freeze_legs:
		for i in _leg_bones:
			skel.reset_bone_pose(i)
	elif skel and bones.has("hips"):
		# keep the hips over the feet: no drifting from the clip's root motion
		var p := skel.get_bone_pose_position(bones["hips"])
		skel.set_bone_pose_position(bones["hips"], Vector3(_hips_rest.x, p.y, _hips_rest.z))


func flash(amount: float, tint := Color(1, 0.95, 0.9)) -> void:
	overlay.albedo_color = Color(tint, clampf(amount, 0.0, 0.85))


## Bends a bone about an axis in the model's own space (+Z forward, +X to the
## model's left), on top of whatever the animation did this frame.
func turn(key: String, axis_model: Vector3, angle: float) -> void:
	if not skel or not bones.has(key) or absf(angle) < 0.0001:
		return
	var i: int = bones[key]
	var parent := skel.get_bone_parent(i)
	var parent_rot := Quaternion.IDENTITY
	if parent >= 0:
		parent_rot = skel.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	var t := Quaternion(axis_model.normalized(), angle)
	skel.set_bone_pose_rotation(i, (parent_rot.inverse() * t * parent_rot) * skel.get_bone_pose_rotation(i))


func bone_world(key: String) -> Vector3:
	return skel.global_transform * skel.get_bone_global_pose(bones[key]).origin


func _bone_named(parts: Array, side: String) -> int:
	var best := -1
	var best_len := 9999
	for i in skel.get_bone_count():
		var n := skel.get_bone_name(i).to_lower().replace("mixamorig:", "").replace("mixamorig_", "")
		if side == "r" and not (n.contains("right") or n.ends_with("_r") or n.ends_with(".r") or n.begins_with("r_")):
			continue
		if side == "l" and not (n.contains("left") or n.ends_with("_l") or n.ends_with(".l") or n.begins_with("l_")):
			continue
		var hit := false
		for p: String in parts:
			if n.contains(p):
				hit = true
		if not hit or n.contains("finger") or n.contains("thumb") or n.contains("index") \
				or n.contains("middle") or n.contains("twist") or n.contains("end"):
			continue
		if n.length() < best_len:
			best = i
			best_len = n.length()
	return best


func _find_bones() -> void:
	for side in ["r", "l"]:
		var fore := _bone_named(["forearm", "lowerarm"], side)
		var hand := _bone_named(["hand", "wrist"], side)
		if fore >= 0:
			bones["fore_" + side] = fore
			var arm := skel.get_bone_parent(fore)
			if arm >= 0:
				bones["arm_" + side] = arm
		if hand >= 0: bones["hand_" + side] = hand
		var foot := _bone_named(["foot", "ankle"], side)
		if foot >= 0:
			bones["foot_" + side] = foot
			if skel.get_bone_parent(foot) >= 0:
				bones["knee_" + side] = skel.get_bone_parent(foot)
	for i in skel.get_bone_count():
		var n := skel.get_bone_name(i).to_lower()
		if n.contains("leg") or n.contains("foot") or n.contains("toe") or n.contains("hips") or n.contains("pelvis"):
			_leg_bones.append(i)
	var hips := _bone_named(["hips", "pelvis"], "")
	if hips >= 0: bones["hips"] = hips
	for name in ["spine2", "spine02", "chest", "spine1", "spine01", "spine"]:
		var s := _bone_named([name], "")
		if s >= 0 and skel.get_bone_name(s).to_lower().ends_with(name):
			bones["spine"] = s
			break
