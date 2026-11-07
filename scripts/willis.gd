extends CharacterBody2D
## Captain Willis, boss of Mess Hall B, and his cafeteria guard squad.
## While his squad is standing he hides behind a steel serving tray (your
## punches just clang off), lobs slop from his ladle, and smacks you if you
## get too close. Knock out the whole squad and he's exposed for a few
## seconds: that's your window. Then he calls in the next squad.

signal defeated(at: Vector2)
signal health_changed(hp: float, max_hp: float)
signal call_squad(wave: int)

const FX := preload("res://scripts/fx.gd")
const SlopScript := preload("res://scripts/slop.gd")
const MAX_HP := 42
const WINDOW_DAMAGE := 15.0   # most he'll take per opening, so it lasts about three squads
const WALK_SPEED := 52.0
const LOB_EVERY := 2.4
const SMACK_REACH := 46.0
const SMACK_WINDUP := 0.5
const EXPOSED_TIME := 5.0
const RALLY_TIME := 1.6

var target: Node2D
var hp := float(MAX_HP)
var hit_radius := 10.0
var wave := 0
var _window_taken := 0.0

var _state := "rally"
var _state_time := 0.0
var _lob_timer := 1.5
var _knock := Vector2.ZERO
var _flash := 0.0
var _clang := 0.0
var _walk := 0.0
var _facing := -1.0
var _t := 0.0
var _dead := false
var _mat: ShaderMaterial
var _light: PointLight2D


func _ready() -> void:
	add_to_group("enemies")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	add_child(shape)
	_light = FX.make_light(Color(1.0, 0.85, 0.55), 0.6, 0.8)
	_light.position = Vector2(0, -40)
	add_child(_light)
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/character.gdshader")
	_mat.set_shader_parameter("body_height", 66.0)
	material = _mat


func exposed() -> bool:
	return _state == "exposed"


## Main tells him when his whole squad is down.
func squad_down() -> void:
	if _dead:
		return
	_window_taken = 0.0
	_set_state("exposed")


func take_hit(from: Vector2, damage_taken: float = 1.0, force: float = 280.0) -> void:
	if _dead:
		return
	if _state != "exposed":
		# blocked by the tray: a loud clang and nothing else
		_clang = 0.2
		_knock = (global_position - from).normalized() * force * 0.15
		return
	var dealt := minf(damage_taken, WINDOW_DAMAGE - _window_taken)
	_window_taken += dealt
	hp = maxf(0.0, hp - dealt)
	health_changed.emit(hp, MAX_HP)
	if _window_taken >= WINDOW_DAMAGE and hp > 0.0:
		# he's had enough: tray back up and whistle for the next squad
		_set_state("rally")
	_flash = 0.12
	_knock = (global_position - from).normalized() * force * 0.3
	if hp <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	defeated.emit(global_position)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 1.2)
	tween.tween_callback(queue_free)


func _set_state(state: String) -> void:
	_state = state
	_state_time = 0.0


func _floor_vec() -> Vector2:
	var d := target.global_position - global_position
	return Vector2(d.x, d.y * 2.0)


func _physics_process(delta: float) -> void:
	_t += delta
	_state_time += delta
	_flash = maxf(0.0, _flash - delta)
	_clang = maxf(0.0, _clang - delta)
	queue_redraw()
	_mat.set_shader_parameter("hit", clampf(maxf(_flash, _clang) * 6.0, 0.0, 1.0))
	_mat.set_shader_parameter("flash_color", Color(1, 1, 1) if _clang > 0.0 else Color(1, 0.3, 0.3))
	_mat.set_shader_parameter("squash", 0.25 if _state == "exposed" else (0.2 * _state_time / SMACK_WINDUP if _state == "smack_windup" else 0.0))
	if _dead or not is_instance_valid(target):
		return
	var to := _floor_vec()
	if absf(to.x) > 4.0 and _state != "exposed":
		_facing = signf(to.x)
	var move := Vector2.ZERO
	match _state:
		"rally":
			# blows his whistle and the next squad pours out of the kitchen
			if _state_time >= RALLY_TIME:
				wave += 1
				call_squad.emit(wave)
				_set_state("command")
		"command":
			# keep a table or two between himself and the villain
			var dist := to.length()
			if dist < 130.0:
				move = -to.normalized()
			elif dist > 220.0:
				move = to.normalized()
			_lob_timer -= delta
			if _lob_timer <= 0.0:
				_lob_timer = LOB_EVERY - minf(0.8, wave * 0.2)
				_lob()
			if dist < SMACK_REACH:
				_set_state("smack_windup")
		"smack_windup":
			if _state_time >= SMACK_WINDUP:
				if to.length() < SMACK_REACH + 6.0:
					target.hit(global_position, 2, 320.0)
				_set_state("command")
		"exposed":
			if _state_time >= EXPOSED_TIME:
				_set_state("rally")
	if move != Vector2.ZERO:
		move = Vector2(move.x, move.y * 0.5).normalized() * WALK_SPEED
	velocity = move + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()
	_walk = _walk + delta * 8.0 if move != Vector2.ZERO else 0.0


func _lob() -> void:
	var slop := Node2D.new()
	slop.set_script(SlopScript)
	slop.start = global_position + Vector2(18 * _facing, -40)
	# aim a little ahead of where the villain is walking
	var lead: Vector2 = target.velocity * 0.4 if "velocity" in target else Vector2.ZERO
	slop.landing = target.global_position + lead
	slop.player = target
	get_parent().add_child(slop)


func _draw() -> void:
	FX.draw_character_shadow(self, 15.0, 60.0)
	if _state == "smack_windup":
		var k := _state_time / SMACK_WINDUP
		var pts := PackedVector2Array()
		for i in 25:
			var a := TAU * i / 24.0
			pts.append(Vector2(cos(a), sin(a) * 0.5) * SMACK_REACH)
		draw_polyline(pts, Color(1, 0.2, 0.1, 0.3 + 0.6 * k), 4.0)
	var f := _facing
	var o := Vector2(0, -absf(sin(_walk)) * 1.5)
	var stride := sin(_walk) * 4.0
	var navy := Color("223152")
	var navy_dark := Color("141e36")
	var apron := Color("e9e6dc")
	# stocky legs and boots
	for side: int in [-1, 1]:
		var s := stride * side
		draw_line(o + Vector2(5 * side, -22), o + Vector2(5 * side + s, -2), navy_dark, 7.0)
		draw_rect(Rect2(o + Vector2(5 * side + s - 4.5, -4), Vector2(9, 4)), Color("101014"))
	# barrel body: navy uniform under a stained white apron
	var body := PackedVector2Array([o + Vector2(-15, -50), o + Vector2(15, -50), o + Vector2(17, -30), o + Vector2(12, -18), o + Vector2(-12, -18), o + Vector2(-17, -30)])
	draw_colored_polygon(body, navy)
	draw_colored_polygon(PackedVector2Array([o + Vector2(-10, -44), o + Vector2(10, -44), o + Vector2(12, -19), o + Vector2(-12, -19)]), apron)
	draw_circle(o + Vector2(-4, -30), 3.0, Color(0.55, 0.6, 0.25, 0.5))   # slop stain
	draw_circle(o + Vector2(5, -24), 2.0, Color(0.6, 0.3, 0.2, 0.4))      # gravy stain
	draw_line(o + Vector2(-10, -44), o + Vector2(-13, -50), apron, 2.0)    # apron straps
	draw_line(o + Vector2(10, -44), o + Vector2(13, -50), apron, 2.0)
	# captain's shoulder boards and a gold whistle on a cord
	for side: int in [-1, 1]:
		draw_rect(Rect2(o + Vector2(15 * side - 5, -52), Vector2(10, 4)), Color("e0b03a"))
	draw_line(o + Vector2(-4, -50), o + Vector2(2, -42), Color("c0392b"), 1.0)
	draw_circle(o + Vector2(2, -41), 2.0, Color("ffd23f"))
	# the ladle arm (toward the villain) and the tray-shield arm
	var shoulder_l := o + Vector2(14 * f, -47)
	var ladle_hand := o + Vector2(22 * f, -36)
	if _state == "smack_windup":
		ladle_hand = o + Vector2(10 * f, -70)
	draw_line(shoulder_l, ladle_hand, navy, 6.0)
	draw_circle(ladle_hand, 3.5, Color("d8b49a"))
	var ladle_tip := ladle_hand + (Vector2(16 * f, 14) if _state != "smack_windup" else Vector2(14 * f, -8))
	draw_line(ladle_hand, ladle_tip, Color("9aa3ad"), 2.5)
	draw_circle(ladle_tip, 5.0, Color("9aa3ad"))
	draw_circle(ladle_tip + Vector2(0, -1), 3.5, Color("8c9a3c"))     # a scoop of slop, ready to go
	# steel serving tray held up as a shield (dropped when exposed)
	var tray_c := o + Vector2(-14 * f, -36)
	if _state == "exposed":
		tray_c = o + Vector2(-20 * f, -4)
		draw_colored_polygon(PackedVector2Array([tray_c + Vector2(-12, 0), tray_c + Vector2(0, -5), tray_c + Vector2(12, 0), tray_c + Vector2(0, 5)]), Color("8d96a3"))
	else:
		var tray := Rect2(tray_c + Vector2(-5, -15), Vector2(10, 28))
		draw_rect(tray.grow(1), Color("4a525e"))
		draw_rect(tray, Color("aab3bf") if _clang <= 0.0 else Color.WHITE)
		draw_line(tray.position + Vector2(2, 3), tray.position + Vector2(2, 24), Color(1, 1, 1, 0.5), 1.0)
	# big head: jowls, walrus moustache, hairnet over the peaked cap
	var head := o + Vector2(2 * f, -60)
	draw_circle(head, 10.0, Color("d8b49a"))
	draw_circle(head + Vector2(-4, 6), 4.5, Color("cfa78c"))
	draw_circle(head + Vector2(4, 6), 4.5, Color("cfa78c"))
	draw_colored_polygon(PackedVector2Array([head + Vector2(-8, 2), head + Vector2(0, 0), head + Vector2(8, 2), head + Vector2(6, 6), head + Vector2(0, 4), head + Vector2(-6, 6)]), Color("6b5a4a"))
	if _state == "exposed":
		# dazed: x-eyes and little stars circling
		for side: int in [-1, 1]:
			var e := head + Vector2(4 * side, -3)
			draw_line(e + Vector2(-1.5, -1.5), e + Vector2(1.5, 1.5), Color("1a1a1a"), 1.2)
			draw_line(e + Vector2(-1.5, 1.5), e + Vector2(1.5, -1.5), Color("1a1a1a"), 1.2)
		for i in 3:
			var a := _t * 4.0 + TAU * i / 3.0
			draw_circle(head + Vector2(cos(a) * 14.0, -16 + sin(a) * 5.0), 2.0, Color("ffd23f"))
	else:
		for side: int in [-1, 1]:
			draw_circle(head + Vector2(4 * side, -3), 1.3, Color("1a1a1a"))
	draw_colored_polygon(PackedVector2Array([head + Vector2(-11, -6), head + Vector2(-8, -14), head + Vector2(8, -14), head + Vector2(11, -6)]), navy_dark)
	draw_rect(Rect2(head + Vector2(-12, -7), Vector2(24, 3)), Color("101014"))   # cap peak
	draw_rect(Rect2(head + Vector2(-3, -13), Vector2(6, 4)), Color("e0b03a"))    # cap badge
	for i in 5:   # hairnet mesh
		draw_line(head + Vector2(-10 + i * 5, -15), head + Vector2(-8 + i * 4, -6), Color(1, 1, 1, 0.25), 0.8)
	draw_arc(head + Vector2(0, -9), 11.0, PI, TAU, 14, Color(1, 1, 1, 0.3), 1.0)
	if _clang > 0.0:
		draw_string(FX.mono_font(), o + Vector2(-20 * f - 14, -70), "CLANG", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, _clang * 5.0))
