extends StaticBody2D
## One solid thing in the prison: a wall, cell bars, a pillar, or furniture.
## It draws itself in code (shaded concrete, steel, hazard paint) and adds its
## own collision, so the villain bumps into it.

const FX := preload("res://scripts/fx.gd")
const TILE_W := 64.0
const TILE_H := 32.0

## kind: [footprint scale, height]
const SHAPES := {
	"wall": [1.0, 60.0], "wall_mid": [1.0, 32.0], "wall_low": [1.0, 10.0],
	"bars": [1.0, 56.0], "bunk": [0.8, 18.0], "toilet": [0.45, 12.0],
	"table": [0.7, 18.0], "crate": [0.75, 26.0], "pillar": [0.55, 84.0],
	"console": [0.6, 24.0],
}

const CONCRETE_TOP := Color("6a6f78")
const CONCRETE_L := Color("3a3e46")
const CONCRETE_R := Color("4a4f58")
const HAZARD := Color("e0ae1e")
const RUST := Color("8a4a2a")

var kind := "wall"
var seed_value := 0
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var shape := CollisionPolygon2D.new()
	shape.polygon = _diamond(SHAPES[kind][0], 0.0)
	add_child(shape)
	# Tall things fade out when the villain walks behind them; pillars and
	# consoles also animate (sparking wires, blinking screens).
	set_process(kind in ["pillar", "console", "wall_mid", "crate", "bars"])
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if kind == "pillar" or kind == "console":
		queue_redraw()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		var d := player.global_position - global_position
		var height: float = SHAPES[kind][1]
		var behind: bool = d.y < 0.0 and d.y > -height - 10.0 and absf(d.x) < 30.0
		modulate.a = move_toward(modulate.a, 0.4 if behind else 1.0, delta * 4.0)


## The floor shadow this block casts, in level coordinates.
func shadow_polygon() -> PackedVector2Array:
	var s: Array = SHAPES[kind]
	var pts := FX.box_shadow(_diamond(s[0], 0.0), s[1])
	for i in pts.size():
		pts[i] += position
	return pts


func _draw() -> void:
	_rng.seed = seed_value
	match kind:
		"wall": _draw_wall(60.0, true)
		"wall_mid": _draw_wall(32.0, false)
		"wall_low": _draw_box(1.0, 10.0, CONCRETE_TOP, CONCRETE_L, CONCRETE_R)
		"bars": _draw_bars()
		"bunk": _draw_bunk()
		"toilet":
			_draw_box(0.45, 12.0, Color("b9bec6"), Color("6e737d"), Color("8f949e"))
			draw_circle(Vector2(0, -12), 4.0, Color("4a505a"))
		"table": _draw_table()
		"crate": _draw_crate()
		"pillar": _draw_pillar()
		"console": _draw_console()


# --- shapes ------------------------------------------------------------------

## A diamond the shape of a tile, scaled by s, lifted up by h pixels.
## Order: top, right, bottom, left.
func _diamond(s: float, h: float) -> PackedVector2Array:
	var hw := TILE_W * 0.5 * s
	var hh := TILE_H * 0.5 * s
	return PackedVector2Array([
		Vector2(0, -hh - h), Vector2(hw, -h), Vector2(0, hh - h), Vector2(-hw, -h)
	])


## Shaded box: faces darken toward the floor, with a lit top edge.
func _draw_box(s: float, h: float, top: Color, left: Color, right: Color) -> void:
	var base := _diamond(s, 0.0)
	var lid := _diamond(s, h)
	FX.gradient_quad(self, PackedVector2Array([lid[3], lid[2], base[2], base[3]]), left, left.darkened(0.45))
	FX.gradient_quad(self, PackedVector2Array([lid[2], lid[1], base[1], base[2]]), right, right.darkened(0.45))
	draw_colored_polygon(lid, top)
	draw_polyline(PackedVector2Array([lid[3], lid[0], lid[1]]), top.lightened(0.25), 1.0)
	draw_polyline(PackedVector2Array([lid[3], lid[2], lid[1]]), top.lightened(0.12), 1.0)


## A point on the left (side=-1) or right (side=1) face: t runs along the face, up is height.
func _face_point(s: float, side: int, t: float, up: float) -> Vector2:
	var base := _diamond(s, 0.0)
	var a := base[3] if side < 0 else base[2]
	var b := base[2] if side < 0 else base[1]
	return a.lerp(b, t) + Vector2(0, -up)


func _draw_wall(h: float, back: bool) -> void:
	_draw_box(1.0, h, CONCRETE_TOP, CONCRETE_L, CONCRETE_R)
	# formwork panel joints and tie holes, like cast concrete
	for side: int in [-1, 1]:
		draw_line(_face_point(1.0, side, 0.5, 0), _face_point(1.0, side, 0.5, h), Color(0, 0, 0, 0.25), 1.0)
		draw_line(_face_point(1.0, side, 0.0, h * 0.5), _face_point(1.0, side, 1.0, h * 0.5), Color(0, 0, 0, 0.15), 1.0)
		for t in [0.25, 0.75]:
			for u in [0.25, 0.75]:
				draw_circle(_face_point(1.0, side, t, h * u), 1.0, Color(0, 0, 0, 0.35))
		# grime streaks running down from the top
		for i in 2:
			var t := _rng.randf_range(0.1, 0.9)
			var len := _rng.randf_range(h * 0.2, h * 0.7)
			draw_line(_face_point(1.0, side, t, h), _face_point(1.0, side, t, h - len), Color(0.05, 0.04, 0.03, 0.22), _rng.randf_range(1.5, 3.0))
	if back:
		# a pair of service pipes along the top of the back walls
		for side: int in [-1, 1]:
			for k in 2:
				var up := h - 8.0 - k * 6.0
				draw_line(_face_point(1.0, side, 0.0, up), _face_point(1.0, side, 1.0, up), Color("23272e"), 4.0)
				draw_line(_face_point(1.0, side, 0.0, up + 1.0), _face_point(1.0, side, 1.0, up + 1.0), Color("5c626d"), 1.0)
	# hazard stripes along the base of the inner walls
	if not back:
		_hazard_band(1.0, 6.0)


## Black-and-yellow warning paint around the bottom of a block.
func _hazard_band(s: float, height: float) -> void:
	for side: int in [-1, 1]:
		var stripes := 8
		for i in stripes:
			var t0 := float(i) / stripes
			var t1 := float(i + 1) / stripes
			var color := HAZARD if i % 2 == 0 else Color("16161a")
			draw_colored_polygon(PackedVector2Array([
				_face_point(s, side, t0, height), _face_point(s, side, t1, height),
				_face_point(s, side, t1 - 0.06, 0), _face_point(s, side, t0 - 0.06, 0),
			]), color.darkened(0.15 if side < 0 else 0.0))


func _draw_pillar() -> void:
	var s := 0.55
	var h := 84.0
	_draw_box(0.72, 6.0, Color("50555e"), Color("2e3138"), Color("3a3e46"))  # footing
	_draw_box(s, h, Color("737881"), Color("3d414a"), Color("4e535d"))
	_hazard_band(s, 12.0)
	# chipped top corner with rusty rebar poking out
	var lid := _diamond(s, h)
	var chip := lid[2]
	draw_colored_polygon(PackedVector2Array([chip + Vector2(-7, -2), chip + Vector2(6, -2), chip + Vector2(0, 9)]), Color("2b2e34"))
	for i in 3:
		var p := chip + Vector2(-4 + i * 4, 1)
		draw_line(p, p + Vector2(_rng.randf_range(-3, 3), -_rng.randf_range(7, 12)), RUST, 1.5)
	# cracks down both faces
	for side: int in [-1, 1]:
		var crack := FX.jagged(_face_point(s, side, _rng.randf_range(0.3, 0.7), h - 4), _face_point(s, side, _rng.randf_range(0.2, 0.8), h * 0.45), 6, 3.0, _rng)
		draw_polyline(crack, Color(0.05, 0.05, 0.07, 0.8), 1.5)
		draw_line(_face_point(s, side, 0.0, h * 0.62), _face_point(s, side, 1.0, h * 0.62), Color(0, 0, 0, 0.2), 1.0)
	# exposed wiring hanging out of a broken panel, with the odd spark
	var hole := _face_point(s, 1, 0.55, h * 0.55)
	draw_rect(Rect2(hole - Vector2(4, 4), Vector2(8, 8)), Color("15171b"))
	var sway := sin(_t * 1.7 + seed_value) * 1.5
	var wire_colors := [Color("c23b2e"), Color("2f7fd1"), Color("d9c23a")]
	for i in 3:
		var end := hole + Vector2(-2 + i * 2 + sway, 12 + i * 3)
		var mid := hole.lerp(end, 0.5) + Vector2(3, 0)
		draw_polyline(PackedVector2Array([hole + Vector2(-2 + i * 2, 0), mid, end]), wire_colors[i], 1.2)
	if fmod(_t * 3.0 + seed_value * 0.37, 4.0) < 0.12:
		var spark := hole + Vector2(sway, 15)
		draw_circle(spark, 3.0, Color(1.0, 0.9, 0.5, 0.8))
		for i in 4:
			var a := _rng.randf() * TAU
			draw_line(spark, spark + Vector2(cos(a), sin(a)) * 6.0, Color(1.0, 0.85, 0.4), 1.0)


func _draw_bars() -> void:
	# Bars run along the row, from the tile's upper-left edge to its lower-right edge.
	var a := Vector2(-TILE_W * 0.25 - 16, -TILE_H * 0.25 - 8)
	var b := Vector2(TILE_W * 0.25 + 16, TILE_H * 0.25 + 8)
	var h := 56.0
	var steel := Color("8c95a6")
	var shade := Color("15181e")
	draw_line(a, b, shade, 6.0)
	draw_line(a + Vector2(0, -h), b + Vector2(0, -h), shade, 7.0)
	draw_line(a + Vector2(0, -h), b + Vector2(0, -h), steel.darkened(0.2), 4.0)
	draw_line(a + Vector2(0, -h - 1.5), b + Vector2(0, -h - 1.5), steel.lightened(0.2), 1.0)
	draw_line(a + Vector2(0, -h * 0.5), b + Vector2(0, -h * 0.5), shade, 4.0)
	for i in 5:
		var t := float(i) / 4.0 * 0.9 + 0.05
		var p := a.lerp(b, t)
		draw_line(p, p + Vector2(0, -h), shade, 4.5)
		draw_line(p + Vector2(-0.6, 0), p + Vector2(-0.6, -h), steel, 2.0)
		draw_line(p + Vector2(-1.2, -4), p + Vector2(-1.2, -h + 4), steel.lightened(0.35), 0.8)
		draw_line(p + Vector2(0, -2), p + Vector2(0, -9), RUST, 2.0)  # rust where it meets the floor


func _draw_bunk() -> void:
	_draw_box(0.8, 12.0, Color("4a4d55"), Color("2a2c32"), Color("373a41"))
	_draw_box(0.7, 18.0, Color("6e2a33"), Color("471a21"), Color("5a222a"))
	var p := Vector2(-12, -21)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4), p + Vector2(8, 0), p + Vector2(0, 4), p + Vector2(-8, 0)]), Color("c9c5bc"))
	draw_line(Vector2(-4, -22), Vector2(14, -14), Color(0, 0, 0, 0.25), 1.0)  # blanket fold


func _draw_table() -> void:
	_draw_box(0.7, 18.0, Color("8a8e96"), Color("4a4d55"), Color("5d616a"))  # steel mess table
	var lid := _diamond(0.7, 18.0)
	draw_line(lid[3].lerp(lid[0], 0.5), lid[2].lerp(lid[1], 0.5), Color(0, 0, 0, 0.2), 1.0)
	# a tray and a dented cup
	draw_colored_polygon(PackedVector2Array([Vector2(-4, -22), Vector2(6, -18), Vector2(2, -15), Vector2(-8, -19)]), Color("6d7480"))
	draw_circle(Vector2(8, -22), 2.0, Color("b8bcc4"))


func _draw_crate() -> void:
	_draw_box(0.75, 26.0, Color("5c5a33"), Color("3a3922"), Color("4a4929"))
	for side: int in [-1, 1]:
		draw_line(_face_point(0.75, side, 0.0, 0), _face_point(0.75, side, 1.0, 26), Color(0, 0, 0, 0.3), 2.0)
		draw_line(_face_point(0.75, side, 0.0, 26), _face_point(0.75, side, 1.0, 0), Color(0, 0, 0, 0.3), 2.0)
		draw_rect(Rect2(_face_point(0.75, side, 0.5, 15) - Vector2(4, 2), Vector2(8, 4)), Color("1b1b14"))
	var lid := _diamond(0.75, 26.0)
	draw_line(lid[0].lerp(lid[3], 0.5), lid[1].lerp(lid[2], 0.5), Color(HAZARD, 0.5), 2.0)


func _draw_console() -> void:
	_draw_box(0.6, 24.0, Color("262a33"), Color("16191f"), Color("1e222a"))
	var flicker := 0.75 + 0.25 * sin(_t * 9.0 + seed_value)
	var screen := PackedVector2Array([
		_face_point(0.6, 1, 0.15, 20), _face_point(0.6, 1, 0.85, 20),
		_face_point(0.6, 1, 0.85, 9), _face_point(0.6, 1, 0.15, 9),
	])
	draw_colored_polygon(screen, Color(0.2, 1.0, 0.55, 0.55 * flicker))
	for i in 3:
		var y := 18.0 - i * 3.0
		draw_line(_face_point(0.6, 1, 0.2, y), _face_point(0.6, 1, 0.2 + _rng.randf_range(0.2, 0.6), y), Color(0.7, 1.0, 0.8, 0.8), 1.0)
	draw_circle(_face_point(0.6, -1, 0.3, 14), 1.5, Color(1, 0.2, 0.2) if fmod(_t, 1.0) < 0.5 else Color(0.3, 0.05, 0.05))
