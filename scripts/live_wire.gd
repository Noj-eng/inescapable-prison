extends Node2D
## A severed high-voltage cable hanging from the ceiling. The vertex shader
## makes the loose end whip and snap around; the tip throws sparks.
## (Decoration for now: it doesn't hurt anyone yet.)

const FX := preload("res://scripts/fx.gd")
const LENGTH := 130.0
const TIP := -14.0     # how far above the floor the loose end hangs

var _t := 0.0
var _seed := randf() * 100.0
var _light: PointLight2D


func _ready() -> void:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/live_wire.gdshader")
	m.set_shader_parameter("length_px", LENGTH)
	m.set_shader_parameter("seed", _seed)
	material = m
	_light = FX.make_light(Color(0.5, 0.85, 1.0), 0.8, 0.5)
	_light.position = Vector2(0, TIP - 10)
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	_light.energy = 0.3 + randf() * 1.2 if fmod(_t * 7.0 + _seed, 1.0) < 0.5 else 0.25
	queue_redraw()


func _draw() -> void:
	# The cable: drawn from the anchor (y = -LENGTH + TIP) down to the tip, in many
	# short segments so the shader has plenty of vertices to bend.
	var pts := PackedVector2Array()
	var steps := 28
	for i in steps + 1:
		var k := float(i) / steps
		var y := lerpf(-LENGTH, 0.0, k) + TIP
		pts.append(Vector2(sin(k * 3.0) * 4.0 * k, y))
	draw_polyline(pts, Color("0c0d10"), 4.0)
	draw_polyline(pts, Color("2a2d33"), 2.0)
	# exposed copper and a crackling arc at the loose end
	var tip := pts[pts.size() - 1]
	draw_line(tip + Vector2(0, -6), tip, Color("c87a3a"), 2.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_t * 25.0)
	for k in 3:
		var a := rng.randf() * TAU
		draw_polyline(FX.jagged(tip, tip + Vector2(cos(a), sin(a) * 0.6) * rng.randf_range(6, 14), 4, 2.0, rng), Color(0.7, 0.95, 1.0, 0.9), 1.0)
	draw_circle(tip, 3.0, Color(0.8, 1.0, 1.0, 0.6 + 0.4 * sin(_t * 50.0)))
