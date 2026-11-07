extends CharacterBody2D
## The villain. Walk with WASD or the arrow keys, punch with Space or J.
## Starts suspended in the containment rig until the earthquake drops them.
## Arms and shins are locked in heavy mechanical casings that crack off level
## by level; the last one is saved for the first boss.
## Knockouts drop XP. Every level-up offers a choice of new abilities.

signal casing_broken(piece: int)
signal health_changed(hp: int, max_hp: int)
signal xp_changed(xp: int, needed: int, level: int)
signal leveled_up
signal died

const FX := preload("res://scripts/fx.gd")
const CHARACTER_SHADER := preload("res://shaders/character.gdshader")

const HOVER := 16.0              # how high the rig holds the villain off the floor
const PUNCH_REACH := 34.0        # how far a punch lands in front of him (floor distance)
const PUNCH_ARC := 0.55          # how wide the punch hits (dot product with aim)
const PUNCH_ANIM := 0.13         # seconds a punch is on screen
const INVULNERABLE_TIME := 0.8   # seconds of safety after taking a hit

const SUIT := Color("ee7a2b")
const SUIT_DARK := Color("b85a1c")
const CASING := Color("5a6272")
const CASING_DARK := Color("2f3540")
const CASING_LIGHT := Color("8790a3")
const SEAM := Color("5ff3ff")
const SKIN := Color("9fb0a4")

enum Piece { LEFT_ARM, RIGHT_ARM, LEFT_LEG, RIGHT_LEG }

## Every upgrade you can pick when levelling up. Each can be taken up to 5 times.
const ABILITIES := {
	"iron_knuckles": {"name": "TITAN FISTS", "text": "Your punches land like wrecking balls. +30% damage."},
	"quick_hands": {"name": "HYPER REFLEXES", "text": "Your nerves fire like a machine. Punch 15% faster."},
	"shockwave_fist": {"name": "SEISMIC SLAM", "text": "Every 3rd punch splits the floor with a shockwave."},
	"static_discharge": {"name": "STORM CALLER", "text": "Lightning arcs from you to the nearest enemy every few seconds."},
	"shrapnel_orbit": {"name": "TELEKINETIC STORM", "text": "Your mind spins shards of broken casing around you."},
	"thick_skin": {"name": "IRON HIDE", "text": "Your skin hardens like steel. +3 max health, heal 3."},
	"fleet_feet": {"name": "BLUR STEP", "text": "Move 12% faster than the guards can follow."},
	"magnet": {"name": "MAGNETIC PULL", "text": "Drag XP toward you from much further away."},
	"bloodlust": {"name": "DARK VITALITY", "text": "Feed on fear. Heal 1 health every 6 knockouts."},
}
const MAX_ABILITY_LEVEL := 5

# --- state ---
var held := true
var hover := HOVER
var facing := 1.0
var aim := Vector2(1, 0)          # direction he's facing on the flat floor
var walk_time := 0.0
var broken := [false, false, false, false]
var max_hp := 10
var hp := 10
var dead := false

# --- progression ---
var level := 1
var xp := 0
var abilities := {}              # ability id -> how many times taken
var _knockouts := 0

var _t := 0.0
var _knock := Vector2.ZERO
var _hurt_flash := 0.0
var _invulnerable := 0.0
var _punch_time := 0.0           # counts down while a punch is out
var _punch_cooldown := 0.0
var _punch_side := 1             # alternates left/right jabs
var _combo := 0                  # 0,1 = jabs, 2 = heavy hook
var _combo_timer := 0.0
var _punch_was_down := false
var _impact := 0.0               # squash after landing a hit
var _zap_timer := 2.0
var _zap_line := PackedVector2Array()
var _zap_time := 0.0
var _shard_hit := {}             # enemy id -> cooldown, so shards don't hit every frame
var _shake_time := 0.0
var _shake_amount := 0.0
var _cam: Camera2D
var _glow: PointLight2D
var _mat: ShaderMaterial


func _ready() -> void:
	add_to_group("player")
	# A small circle at the villain's feet is what bumps into walls.
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)

	_mat = ShaderMaterial.new()
	_mat.shader = CHARACTER_SHADER
	_mat.set_shader_parameter("body_height", 52.0)
	_mat.set_shader_parameter("flash_color", Color(1.0, 0.3, 0.3))
	material = _mat

	# The casings' cyan seams glow faintly; the glow fades as they break off.
	_glow = FX.make_light(Color(0.3, 0.95, 1.0), 0.45, 0.45)
	_glow.position = Vector2(0, -24)
	add_child(_glow)

	_cam = Camera2D.new()
	_cam.zoom = Vector2(1.8, 1.8)
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 6.0
	add_child(_cam)


# --- stats from abilities ------------------------------------------------------

func rank(id: String) -> int:
	return abilities.get(id, 0)

func punch_damage() -> float:
	return 1.0 * (1.0 + 0.3 * rank("iron_knuckles"))

func punch_cooldown() -> float:
	return 0.22 * pow(0.85, rank("quick_hands"))

func move_speed() -> float:
	return 120.0 * (1.0 + 0.12 * rank("fleet_feet"))

func pickup_radius() -> float:
	return 45.0 + 45.0 * rank("magnet")

func xp_needed() -> int:
	return 6 + (level - 1) * 5


## Three different upgrades to choose from (ones not yet maxed out).
func roll_choices() -> Array:
	var pool := []
	for id in ABILITIES:
		if rank(id) < MAX_ABILITY_LEVEL:
			pool.append(id)
	pool.shuffle()
	return pool.slice(0, 3)


func take_ability(id: String) -> void:
	abilities[id] = rank(id) + 1
	if id == "thick_skin":
		max_hp += 3
		heal(3)
	health_changed.emit(hp, max_hp)


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		leveled_up.emit()
	xp_changed.emit(xp, xp_needed(), level)


## Everything needed to put the villain back as they were (for retrying a level).
func snapshot() -> Dictionary:
	return {"broken": broken.duplicate(), "level": level, "xp": xp,
		"abilities": abilities.duplicate(), "max_hp": max_hp}


func restore(s: Dictionary) -> void:
	broken = s["broken"].duplicate()
	level = s["level"]
	xp = s["xp"]
	abilities = s["abilities"].duplicate()
	max_hp = s["max_hp"]
	dead = false
	held = false
	hover = 0.0
	hp = max_hp
	_knock = Vector2.ZERO
	_invulnerable = 1.0
	health_changed.emit(hp, max_hp)
	xp_changed.emit(xp, xp_needed(), level)


# --- events --------------------------------------------------------------------

## Called by the earthquake: the rig fails and the villain falls to the floor.
func drop() -> void:
	held = false
	var tween := create_tween()
	tween.tween_property(self, "hover", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(shake.bind(4.0, 0.25))
	tween.tween_callback(func(): _impact = 0.6)


## Jump the camera straight to the villain (used when a new level loads).
func snap_camera() -> void:
	_cam.reset_smoothing()


## Keep the camera inside the level so it doesn't show empty space.
func set_camera_limits(r: Rect2) -> void:
	_cam.limit_left = int(r.position.x)
	_cam.limit_top = int(r.position.y)
	_cam.limit_right = int(r.end.x)
	_cam.limit_bottom = int(r.end.y)


func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)
	health_changed.emit(hp, max_hp)


func shake(amount: float, duration: float) -> void:
	_shake_amount = amount
	_shake_time = duration


## An enemy hit us: lose health, get shoved back, and flash red.
func hit(from: Vector2, damage: int = 1, force: float = 220.0) -> void:
	if dead or held or _invulnerable > 0.0:
		return
	hp = maxi(0, hp - damage)
	health_changed.emit(hp, max_hp)
	_knock = (global_position - from).normalized() * force
	_hurt_flash = 0.3
	_invulnerable = INVULNERABLE_TIME
	shake(3.0 + damage * 2.0, 0.25)
	if hp == 0:
		dead = true
		died.emit()


## Count a knockout (for Bloodlust).
func on_knockout() -> void:
	_knockouts += 1
	if rank("bloodlust") > 0 and _knockouts % maxi(2, 7 - rank("bloodlust")) == 0:
		heal(1)


## Breaks the next casing. Returns false if only the boss's piece is left.
func break_next_casing() -> bool:
	for i in 3:  # the 4th piece (right leg) is saved for the first boss
		if not broken[i]:
			broken[i] = true
			casing_broken.emit(i)
			shake(5.0, 0.3)
			return true
	return false


## Only beating the guard captain breaks the last casing.
func break_final_casing() -> void:
	broken[Piece.RIGHT_LEG] = true
	casing_broken.emit(Piece.RIGHT_LEG)
	shake(8.0, 0.5)


func _read_input() -> Vector2:
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y += 1
	return input.normalized()


func _punch_pressed() -> bool:
	return Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_J)


# --- every frame -----------------------------------------------------------------

func _process(delta: float) -> void:
	if _shake_time > 0.0:
		_shake_time -= delta
		_cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_amount
	else:
		_cam.offset = Vector2.ZERO

	# Feed the attack and damage animation into the vertex shader.
	var punching := _punch_time > 0.0
	var lean := 0.0
	var squash := _impact
	if held:
		lean = 0.0
	elif punching:
		var k := _punch_time / PUNCH_ANIM
		lean = facing * (0.45 if _combo == 0 else 0.3) * k   # throw the body into it
		if k > 0.75:
			squash = -0.18                                    # tiny wind-up stretch
	else:
		lean = velocity.x / move_speed() * 0.1
	_mat.set_shader_parameter("lean", lean)
	_mat.set_shader_parameter("squash", squash)
	_mat.set_shader_parameter("hit", clampf(_hurt_flash * 3.0, 0.0, 1.0))
	_impact = move_toward(_impact, 0.0, delta * 3.0)


func _physics_process(delta: float) -> void:
	_t += delta
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	_punch_time = maxf(0.0, _punch_time - delta)
	_punch_cooldown = maxf(0.0, _punch_cooldown - delta)
	_combo_timer = maxf(0.0, _combo_timer - delta)
	_invulnerable = maxf(0.0, _invulnerable - delta)
	_zap_time = maxf(0.0, _zap_time - delta)
	_glow.energy = 0.12 * broken.count(false)
	queue_redraw()
	if held:
		return
	if dead:
		velocity = _knock
		_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		return

	var input := _read_input()
	if input != Vector2.ZERO:
		aim = input
		if absf(input.x) > 0.1:
			facing = signf(input.x)

	# Punch on each press (holding the key keeps punching at the cooldown rate).
	var down := _punch_pressed()
	if down and _punch_cooldown <= 0.0:
		_punch()
	_punch_was_down = down

	_passive_abilities(delta)

	# Squash vertical movement by half so it matches the isometric floor.
	var move := Vector2(input.x, input.y * 0.5).normalized() * move_speed() if input != Vector2.ZERO else Vector2.ZERO
	if _punch_time > 0.0:
		move *= 0.55
	velocity = move + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 1100.0 * delta)
	move_and_slide()
	walk_time = walk_time + delta * 9.0 if input != Vector2.ZERO else 0.0


# --- the punch ----------------------------------------------------------------------

## A snappy jab-jab-hook combo. Each punch lands instantly in front of him;
## a hit freezes the action for a split second (hit-stop) and sends the
## enemy flying.
func _punch() -> void:
	if _combo_timer <= 0.0:
		_combo = 0
	var heavy := _combo == 2
	_punch_time = PUNCH_ANIM
	_punch_cooldown = punch_cooldown() * (1.6 if heavy else 1.0)
	_punch_side = -_punch_side
	_combo_timer = 0.55
	_knock += Vector2(aim.x, aim.y * 0.5).normalized() * 90.0   # small lunge forward

	var landed := false
	var reach := PUNCH_REACH * (1.25 if heavy else 1.0)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var d: Vector2 = enemy.global_position - global_position
		var flat := Vector2(d.x, d.y * 2.0)
		var dist: float = flat.length() - enemy.hit_radius
		if dist < reach and (flat.length() < 10.0 or flat.normalized().dot(aim) > PUNCH_ARC):
			var dmg := punch_damage() * (2.0 if heavy else 1.0)
			enemy.take_hit(global_position, dmg, 420.0 if heavy else 260.0)
			landed = true
	if landed:
		_impact = 0.35 if heavy else 0.15
		shake(4.0 if heavy else 2.0, 0.1)
		_hit_stop(0.09 if heavy else 0.05)
	if heavy and rank("shockwave_fist") > 0:
		_shockwave_fist()
	_combo = (_combo + 1) % 3


func _hit_stop(seconds: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


func _shockwave_fist() -> void:
	var radius := 60.0 + 12.0 * rank("shockwave_fist")
	var center := global_position + Vector2(aim.x, aim.y * 0.5) * 20.0
	var level_root := get_tree().current_scene
	if level_root.has_method("shockwave"):
		level_root.shockwave(center, 5.0, radius * 1.5)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var d: Vector2 = enemy.global_position - center
		if Vector2(d.x, d.y * 2.0).length() < radius:
			enemy.take_hit(center, 0.8 + 0.4 * rank("shockwave_fist"), 300.0)


# --- passive abilities ----------------------------------------------------------------

func _passive_abilities(delta: float) -> void:
	# Static discharge: arc to the nearest enemy every few seconds.
	if rank("static_discharge") > 0:
		_zap_timer -= delta
		if _zap_timer <= 0.0:
			_zap_timer = 3.2 - 0.4 * rank("static_discharge")
			var best: Node2D = null
			var best_d := 220.0
			for enemy in get_tree().get_nodes_in_group("enemies"):
				var dd: float = enemy.global_position.distance_to(global_position)
				if dd < best_d:
					best_d = dd
					best = enemy
			if best:
				best.take_hit(global_position, 1.0 + 0.5 * rank("static_discharge"), 120.0)
				var rng := RandomNumberGenerator.new()
				rng.randomize()
				_zap_line = FX.jagged(Vector2(0, -26), best.global_position - global_position + Vector2(0, -20), 8, 6.0, rng)
				_zap_time = 0.15

	# Shrapnel orbit: shards of broken casing circling him.
	var shards := _shard_count()
	if shards > 0:
		for id in _shard_hit.keys():
			_shard_hit[id] -= delta
		for i in shards:
			var p := global_position + _shard_offset(i, shards)
			for enemy in get_tree().get_nodes_in_group("enemies"):
				var d: Vector2 = enemy.global_position - p
				if Vector2(d.x, d.y * 2.0).length() < 14.0 + enemy.hit_radius and _shard_hit.get(enemy.get_instance_id(), 0.0) <= 0.0:
					enemy.take_hit(p, 0.6 + 0.2 * rank("shrapnel_orbit"), 140.0)
					_shard_hit[enemy.get_instance_id()] = 0.5


func _shard_count() -> int:
	return 0 if rank("shrapnel_orbit") == 0 else 1 + rank("shrapnel_orbit")


func _shard_offset(i: int, count: int) -> Vector2:
	var a := _t * 3.2 + TAU * i / count
	return Vector2(cos(a) * 34.0, sin(a) * 17.0)


# --- drawing --------------------------------------------------------------------------

func _draw() -> void:
	# long shadow (shrinks while floating)
	FX.draw_character_shadow(self, 13.0 * (1.0 - hover / HOVER * 0.35), 46.0)

	if dead:
		modulate = Color(0.55, 0.55, 0.6)
	elif _invulnerable > 0.0 and _hurt_flash <= 0.0 and int(_t * 20.0) % 2 == 0:
		modulate = Color(1, 1, 1, 0.45)  # blink while invulnerable
	else:
		modulate = Color.WHITE

	# shrapnel shards behind him (the ones on the far side of the orbit)
	var shards := _shard_count()
	for i in shards:
		var off := _shard_offset(i, shards)
		if off.y < 0.0:
			_draw_shard(off)

	if dead:
		draw_set_transform(Vector2(0, -4), PI * 0.5 * facing, Vector2.ONE)
		_draw_free()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif held:
		_draw_held()
	else:
		_draw_free()

	for i in shards:
		var off := _shard_offset(i, shards)
		if off.y >= 0.0:
			_draw_shard(off)

	if _zap_time > 0.0 and _zap_line.size() > 1:
		draw_polyline(_zap_line, Color(0.4, 1.0, 1.0, 0.5), 4.0)
		draw_polyline(_zap_line, Color(0.9, 1.0, 1.0), 1.5)


func _draw_shard(off: Vector2) -> void:
	var p := off + Vector2(0, -18)
	var spin := _t * 9.0
	var pts := PackedVector2Array()
	for k in 3:
		var a := spin + TAU * k / 3.0
		pts.append(p + Vector2(cos(a), sin(a)) * (5.0 if k == 0 else 3.0))
	draw_colored_polygon(pts, CASING_LIGHT)
	draw_polyline(pts, SEAM, 1.0)


## Suspended in the rig: arms spread wide inside heavy casings, legs locked together.
func _draw_held() -> void:
	var lift := -hover + sin(_t * 2.0) * 1.5
	var o := Vector2(0, lift)
	_leg(o + Vector2(-3, 0), 0.0, Piece.LEFT_LEG)
	_leg(o + Vector2(3, 0), 0.0, Piece.RIGHT_LEG)
	_torso(o)
	for side: int in [-1, 1]:
		var shoulder := o + Vector2(9 * side, -33)
		var hand := o + Vector2(38 * side, -56 - lift)  # hands stay pinned in the clamps
		_arm(shoulder, hand, Piece.LEFT_ARM if side < 0 else Piece.RIGHT_ARM)
	_head(o + Vector2(0, 1), 1.0)


func _draw_free() -> void:
	var o := Vector2(0, -hover - absf(sin(walk_time)) * 1.5)
	var stride := sin(walk_time) * 3.0
	_leg(o + Vector2(-4, 0), stride, Piece.LEFT_LEG)
	_leg(o + Vector2(4, 0), -stride, Piece.RIGHT_LEG)
	_torso(o)
	var screen_aim := Vector2(aim.x, aim.y * 0.5).normalized()
	for side: int in [-1, 1]:
		var shoulder := o + Vector2(12 * side, -33)
		var hand: Vector2
		var punching_arm := _punch_time > 0.0 and side == _punch_side
		if _punch_time > 0.0 and side == _punch_side:
			# the punching arm snaps straight out toward the target
			var k := 1.0 - _punch_time / PUNCH_ANIM
			var extend := 30.0 * (1.0 - absf(k * 2.0 - 1.0) * 0.3)
			hand = o + Vector2(4 * side, -27) + screen_aim * extend
			if _combo == 0:  # the heavy hook (combo already advanced) swings wider
				hand += Vector2(0, -6)
		elif _punch_time > 0.0:
			hand = o + Vector2(8 * side, -30)                    # guard hand up by the face
		else:
			hand = o + Vector2(15 * side - stride * side * 0.8, -14)
		_arm(shoulder, hand, Piece.LEFT_ARM if side < 0 else Piece.RIGHT_ARM)
		if punching_arm and _punch_time > PUNCH_ANIM * 0.5:
			# impact flash at the fist
			draw_circle(hand, 9.0, Color(1.0, 0.95, 0.8, 0.25))
	_head(o, facing)


func _leg(foot: Vector2, stride: float, piece: int) -> void:
	var hip := foot + Vector2(0, -18)
	var knee := foot + Vector2(stride, -10)
	draw_line(hip, knee, SUIT_DARK, 6.5)
	draw_line(hip + Vector2(-1, 0), knee + Vector2(-1, 0), SUIT, 3.5)
	if broken[piece]:
		# torn trouser leg, bare shin, and the broken ankle cuff with dangling wires
		var ankle := foot + Vector2(stride * 0.5, -3)
		draw_line(knee, ankle, SUIT_DARK, 5.5)
		_torn_edge(knee + Vector2(-3.5, 1), knee + Vector2(3.5, 1))
		draw_line(knee + Vector2(0, 2), ankle, SKIN.darkened(0.2), 3.0)
		_cuff_remnant(ankle, 6.0, piece)
		draw_rect(Rect2(foot + Vector2(stride * 0.5 - 3.5, -2), Vector2(7, 3)), Color("141318"))
		return
	var shin := Rect2(knee + Vector2(-5.5, -1), Vector2(11, 13))
	draw_rect(shin.grow(1), CASING_DARK)
	FX.gradient_quad(self, PackedVector2Array([shin.position, shin.position + Vector2(shin.size.x, 0), shin.end, shin.position + Vector2(0, shin.size.y)]), CASING_LIGHT, CASING_DARK)
	draw_line(shin.position + Vector2(0, 5), shin.position + Vector2(11, 5), SEAM, 1.5)
	draw_line(shin.position + Vector2(5.5, 6), shin.position + Vector2(5.5, 13), Color(0, 0, 0, 0.35), 1.0)
	draw_circle(shin.position + Vector2(2, 2), 0.8, CASING_LIGHT.lightened(0.3))
	draw_circle(shin.position + Vector2(9, 2), 0.8, CASING_LIGHT.lightened(0.3))


func _arm(shoulder: Vector2, hand: Vector2, piece: int) -> void:
	if broken[piece]:
		# torn sleeve to the elbow, bare muscular forearm, cuff remnant at the wrist
		var elbow := shoulder.lerp(hand, 0.45)
		draw_line(shoulder, elbow, SUIT_DARK, 7.5)
		draw_line(shoulder, elbow, SUIT, 5.0)
		_torn_edge(elbow + (hand - shoulder).orthogonal().normalized() * 3.5, elbow - (hand - shoulder).orthogonal().normalized() * 3.5)
		draw_line(elbow, hand, SKIN.darkened(0.25), 5.5)
		draw_line(elbow, hand, SKIN, 3.5)
		draw_line(elbow.lerp(hand, 0.2), elbow.lerp(hand, 0.7), SKIN.lightened(0.2), 1.0)  # muscle highlight
		_cuff_remnant(elbow.lerp(hand, 0.8), 7.0, piece)
		draw_circle(hand, 3.8, SKIN.darkened(0.1))
		draw_circle(shoulder, 4.5, CASING_DARK)  # jagged stump of the shoulder mount
		return
	_casing(shoulder, hand, 13.0)


## A ragged fabric edge where the jumpsuit has been torn.
func _torn_edge(a: Vector2, b: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		var p := a.lerp(b, i / 5.0)
		pts.append(p + Vector2(0, 2.0 if i % 2 == 0 else -0.5))
	draw_polyline(pts, SUIT_DARK.darkened(0.3), 1.5)


## What's left of a casing once it breaks: a jagged steel band with torn-out wires.
func _cuff_remnant(at: Vector2, radius: float, piece: int) -> void:
	var band := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0
		var r := radius + (1.2 if i % 3 == 0 else 0.0)
		band.append(at + Vector2(cos(a) * r, sin(a) * r * 0.45))
	draw_colored_polygon(band, CASING_DARK)
	draw_polyline(band, CASING_LIGHT, 1.0)
	# broken teeth sticking out
	for k in 3:
		var a := TAU * (k + 0.3 * piece) / 3.0
		var base := at + Vector2(cos(a) * radius, sin(a) * radius * 0.45)
		draw_line(base, base + Vector2(cos(a) * 3.0, -2.5), CASING_LIGHT, 1.2)
	# dangling wires swinging as he moves
	var sway := sin(_t * 3.0 + piece) * 2.0 + sin(walk_time) * 1.5
	var colors := [Color("c23b2e"), Color("2f7fd1"), Color("d9c23a")]
	for k in 3:
		var start := at + Vector2(-2.5 + k * 2.5, 1.5)
		var end := start + Vector2(sway + k - 1, 7.0 + k * 2.0)
		draw_polyline(PackedVector2Array([start, start.lerp(end, 0.5) + Vector2(1.5, 0), end]), colors[k], 0.9)
	# the odd spark from a severed seam
	if fmod(_t * 2.0 + piece * 1.3, 3.0) < 0.1:
		draw_circle(at + Vector2(sway, 9), 2.5, Color(0.6, 1.0, 1.0, 0.9))


func _torso(o: Vector2) -> void:
	# broad, hunched shoulders tapering to the waist
	FX.gradient_quad(self, PackedVector2Array([
		o + Vector2(-13, -36), o + Vector2(13, -36), o + Vector2(7.5, -15), o + Vector2(-7.5, -15)
	]), SUIT.lightened(0.08), SUIT_DARK)
	draw_line(o + Vector2(0, -35), o + Vector2(0, -16), SUIT_DARK.darkened(0.2), 1.0)  # zip
	for fold in [[Vector2(-9, -27), Vector2(-5, -24)], [Vector2(5, -22), Vector2(8, -19)]]:
		draw_line(o + fold[0], o + fold[1], Color(0, 0, 0, 0.3), 0.8)
	# a rip in the suit across the ribs
	draw_polyline(PackedVector2Array([o + Vector2(3, -30), o + Vector2(5, -28.5), o + Vector2(7, -30), o + Vector2(9, -28)]), SKIN.darkened(0.3), 1.4)
	draw_rect(Rect2(o + Vector2(-9, -32), Vector2(7, 4)), Color("efe8d6"))  # prisoner number
	draw_line(o + Vector2(-8, -30), o + Vector2(-3.5, -30), Color(0, 0, 0, 0.6), 0.8)
	draw_rect(Rect2(o + Vector2(-8.5, -19), Vector2(17, 4)), CASING_DARK)  # restraint belt
	draw_rect(Rect2(o + Vector2(-2, -19), Vector2(4, 4)), SEAM)


## A heavy mechanical sleeve from a to b, with a big cuff block at the end.
func _casing(a: Vector2, b: Vector2, thickness: float) -> void:
	var n := (b - a).orthogonal().normalized() * thickness * 0.5
	draw_line(a, b, CASING_DARK, thickness + 2.0)
	draw_polygon(PackedVector2Array([a - n, b - n, b + n, a + n]),
		PackedColorArray([CASING_LIGHT, CASING_LIGHT, CASING_DARK, CASING_DARK]))
	draw_line(a - n * 0.7, b - n * 0.7, CASING_LIGHT.lightened(0.25), 1.0)
	for t in [0.33, 0.66]:
		var p: Vector2 = a.lerp(b, t)
		draw_line(p - n, p + n, SEAM, 1.5)
		draw_circle(p - n * 0.6 + (b - a).normalized() * 2.5, 0.8, CASING_LIGHT.lightened(0.3))
	var cuff := Rect2(b - Vector2(7.5, 7.5), Vector2(15, 15))
	draw_rect(cuff.grow(1), CASING_DARK)
	FX.gradient_quad(self, PackedVector2Array([cuff.position, cuff.position + Vector2(cuff.size.x, 0), cuff.end, cuff.position + Vector2(0, cuff.size.y)]), CASING_LIGHT, CASING_DARK)
	draw_rect(Rect2(cuff.position + Vector2(2, 2), Vector2(11, 2)), Color(0, 0, 0, 0.3))
	draw_circle(b, 2.2, SEAM)
	draw_circle(b, 4.0, Color(SEAM, 0.25))


func _head(o: Vector2, f: float) -> void:
	# restraint collar
	draw_rect(Rect2(o + Vector2(-7.5, -40), Vector2(15, 5)), CASING_DARK)
	draw_rect(Rect2(o + Vector2(-6.5, -39), Vector2(13, 2)), CASING_LIGHT)
	draw_circle(o + Vector2(0, -37.5), 1.3, SEAM)
	var head := o + Vector2(0, -46)
	draw_circle(head, 7.2, SKIN.darkened(0.15))
	draw_circle(head + Vector2(-0.6, -0.6), 6.4, SKIN)
	draw_line(head + Vector2(-5, 4), head + Vector2(5, 4), SKIN.darkened(0.3), 1.0)  # hard jaw line
	# slick black hair with a widow's peak
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-7.4, -1), head + Vector2(-6.5, -6.5), head + Vector2(0, -8.5),
		head + Vector2(6.5, -6.5), head + Vector2(7.4, -1), head + Vector2(0, -3.5)
	]), Color("131118"))
	draw_line(head + Vector2(-4, -6.5), head + Vector2(1, -7.5), Color(1, 1, 1, 0.18), 0.8)
	# glowing eyes under a heavy brow
	var ex := 2.5 * f
	draw_line(head + Vector2(ex - 4, -0.8), head + Vector2(ex + 4, -0.8), SKIN.darkened(0.45), 1.2)
	for dx in [-2.0, 2.0]:
		draw_circle(head + Vector2(ex + dx, 1), 2.4, Color(1.0, 0.82, 0.25, 0.25))
		draw_circle(head + Vector2(ex + dx, 1), 1.3, Color("ffd23f"))


func _iso_ring(c: Vector2, r: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.5))
	draw_polyline(pts, color, width)
