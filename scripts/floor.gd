extends Node2D
## Draws the floor as isometric tiles: stained concrete slabs, diamond-plate
## steel, or vent grating, plus earthquake cracks and the shadows cast by
## everything standing in the level.

const TILE_W := 64.0
const TILE_H := 32.0

var theme := "concrete"            # concrete, steel or mixed
var vents: Array[Vector2] = []     # grid cells drawn as steam-vent grating
var cells: Array[Vector2] = []:
	set(value):
		cells = value
		queue_redraw()
var cracks: Array[PackedVector2Array] = []

var _shadow_group: CanvasGroup
var _shadow_drawer: Node2D
var _shadows: Array[PackedVector2Array] = []


var _ripple: ShaderMaterial
var _ripple_age := 100.0


## Start an aftershock ring rolling across the floor from a point.
func ripple(origin: Vector2, strength: float) -> void:
	_ripple_age = 0.0
	_ripple.set_shader_parameter("origin", origin)
	_ripple.set_shader_parameter("strength", strength)


func _process(delta: float) -> void:
	_ripple_age += delta
	_ripple.set_shader_parameter("age", _ripple_age)


func _ready() -> void:
	_ripple = ShaderMaterial.new()
	_ripple.shader = preload("res://shaders/floor_ripple.gdshader")
	material = _ripple
	# Shadows are drawn solid into a group, then the whole group is faded, so
	# overlapping shadows don't stack into dark blotches.
	_shadow_group = CanvasGroup.new()
	_shadow_group.self_modulate = Color(1, 1, 1, 0.45)
	add_child(_shadow_group)
	_shadow_drawer = Node2D.new()
	_shadow_drawer.draw.connect(_draw_shadows)
	_shadow_group.add_child(_shadow_drawer)


func add_shadow(poly: PackedVector2Array) -> void:
	_shadows.append(poly)
	_shadow_drawer.queue_redraw()


func _draw_shadows() -> void:
	for poly in _shadows:
		_shadow_drawer.draw_colored_polygon(poly, Color(0.0, 0.0, 0.03))


## Splits the floor with jagged cracks spreading out from a point (the earthquake).
func add_cracks(center: Vector2, count: int) -> void:
	for i in count:
		var angle := randf() * TAU
		var p := center
		var line := PackedVector2Array([p])
		for step in randi_range(4, 7):
			angle += randf_range(-0.6, 0.6)
			p += Vector2(cos(angle), sin(angle) * 0.5) * randf_range(10, 20)
			line.append(p)
		cracks.append(line)
	queue_redraw()


static func _to_screen(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * TILE_W * 0.5, (cell.x + cell.y) * TILE_H * 0.5)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	for cell in cells:
		rng.seed = hash(cell)
		var c := _to_screen(cell)
		var top := c + Vector2(0, -TILE_H * 0.5)
		var right := c + Vector2(TILE_W * 0.5, 0)
		var bottom := c + Vector2(0, TILE_H * 0.5)
		var left := c + Vector2(-TILE_W * 0.5, 0)
		var pts := PackedVector2Array([top, right, bottom, left])
		var surface := theme
		if theme == "mixed":
			surface = "steel" if (floori(cell.x / 3.0) + floori(cell.y / 3.0)) % 2 == 0 else "concrete"
		if cell in vents:
			surface = "grating"
		match surface:
			"concrete": _concrete(pts, rng)
			"steel": _steel(pts, rng)
			"grating": _grating(pts)
		# oil stains and scuffs
		if rng.randf() < 0.22:
			var sc := c + Vector2(rng.randf_range(-12, 12), rng.randf_range(-5, 5))
			for k in 3:
				var off := Vector2(rng.randf_range(-5, 5), rng.randf_range(-2, 2))
				var r := rng.randf_range(4, 9)
				draw_colored_polygon(_ellipse(sc + off, r), Color(0.02, 0.02, 0.03, 0.22))
		if rng.randf() < 0.35:
			var sp := c + Vector2(rng.randf_range(-14, 14), rng.randf_range(-6, 6))
			draw_line(sp, sp + Vector2(rng.randf_range(4, 10), rng.randf_range(-2, 2)), Color(1, 1, 1, 0.06), 1.0)
	for line in cracks:
		draw_polyline(line, Color("0c0d11"), 3.0)
		draw_polyline(line, Color("555c6a"), 0.8)


func _concrete(pts: PackedVector2Array, rng: RandomNumberGenerator) -> void:
	var shade := rng.randf_range(-0.04, 0.04)
	var base := Color(0.27 + shade, 0.28 + shade, 0.30 + shade)
	draw_colored_polygon(pts, base)
	# slab edges: light on the top-left, dark on the bottom-right
	draw_polyline(PackedVector2Array([pts[3], pts[0], pts[1]]), base.lightened(0.12), 1.0)
	draw_polyline(PackedVector2Array([pts[1], pts[2], pts[3]]), base.darkened(0.45), 1.5)
	# speckled aggregate
	for i in 7:
		var p := _inside(pts, rng.randf(), rng.randf())
		draw_circle(p, rng.randf_range(0.5, 1.2), Color(1, 1, 1, 0.07) if i % 2 == 0 else Color(0, 0, 0, 0.12))


func _steel(pts: PackedVector2Array, rng: RandomNumberGenerator) -> void:
	var shade := rng.randf_range(-0.02, 0.02)
	var base := Color(0.24 + shade, 0.26 + shade, 0.29 + shade)
	draw_colored_polygon(pts, base)
	# raised diamond-plate pattern
	for i in 5:
		for j in 5:
			var p := _inside(pts, (i + 0.5) / 5.0, (j + 0.5) / 5.0)
			var d := Vector2(2.5, 1.2) if (i + j) % 2 == 0 else Vector2(2.5, -1.2)
			draw_line(p - d, p + d, base.lightened(0.18), 1.0)
	draw_polyline(PackedVector2Array([pts[3], pts[0], pts[1]]), base.lightened(0.22), 1.0)
	draw_polyline(PackedVector2Array([pts[1], pts[2], pts[3]]), Color(0, 0, 0, 0.6), 1.5)
	for k in 4:  # rivets in the corners
		var corner := pts[k].lerp((pts[0] + pts[2]) * 0.5, 0.18)
		draw_circle(corner, 1.3, base.lightened(0.3))


func _grating(pts: PackedVector2Array) -> void:
	draw_colored_polygon(pts, Color("101216"))
	for i in 9:
		var t := (i + 0.5) / 9.0
		draw_line(pts[0].lerp(pts[1], t), pts[3].lerp(pts[2], t), Color("3b4049"), 1.5)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color("4a505b"), 1.5)


## A point inside the diamond: u runs top→right, v runs top→left.
func _inside(pts: PackedVector2Array, u: float, v: float) -> Vector2:
	return pts[0] + (pts[1] - pts[0]) * u + (pts[3] - pts[0]) * v


func _ellipse(c: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		out.append(c + Vector2(cos(a) * r, sin(a) * r * 0.5))
	return out
