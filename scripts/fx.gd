extends RefCounted
## Shared look-and-feel helpers: light textures, soft particles, shaded shapes.
## Everything is generated in code, so there are no image files to manage.

const SHADOW_DIR := Vector2(0.9, 0.35)  # which way shadows fall, per pixel of height
const SHADOW_COLOR := Color(0.0, 0.0, 0.02, 0.42)

static var _light_tex: Texture2D
static var _soft_tex: Texture2D
static var _cone_tex: Texture2D
static var _mono_font: Font


## A soft round light: bright centre fading to nothing at the edge.
static func light_texture() -> Texture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 256
		t.height = 256
		_light_tex = t
	return _light_tex


## A small soft dot used for dust, steam and sparks.
static func soft_texture() -> Texture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_soft_tex = t
	return _soft_tex


## A wedge of light pointing right, for rotating warning beacons.
static func cone_texture() -> Texture2D:
	if _cone_tex == null:
		var size := 256
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c := Vector2(size, size) * 0.5
		for y in size:
			for x in size:
				var d := Vector2(x, y) - c
				var r := d.length() / (size * 0.5)
				var ang := absf(d.angle())
				var a := 0.0
				if r < 1.0 and ang < 0.32:
					a = (1.0 - r) * (1.0 - ang / 0.32)
				a = maxf(a, maxf(0.0, 1.0 - r * 6.0))  # bright hub at the beacon itself
				img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
		_cone_tex = ImageTexture.create_from_image(img)
	return _cone_tex


static func make_light(color: Color, energy: float, scale: float, shadows := false) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = light_texture()
	light.color = color
	light.energy = energy
	light.texture_scale = scale
	light.shadow_enabled = shadows
	return light


## Crisp monospace font for the HUD (uses what the computer has installed).
static func mono_font() -> Font:
	if _mono_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "JetBrains Mono", "DejaVu Sans Mono", "Liberation Mono", "Courier New", "monospace"])
		f.font_weight = 600
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_mono_font = f
	return _mono_font


static func additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


static func unshaded_additive() -> CanvasItemMaterial:
	var m := additive()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return m


## Polygon with one colour along its top edge fading to another at the bottom.
## Points go: top-left, top-right, bottom-right, bottom-left.
static func gradient_quad(ci: CanvasItem, pts: PackedVector2Array, top: Color, bottom: Color) -> void:
	ci.draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))


## The shadow an upright box of the given footprint and height casts on the floor.
static func box_shadow(footprint: PackedVector2Array, height: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in footprint:
		pts.append(p)
		pts.append(p + SHADOW_DIR * height)
	return Geometry2D.convex_hull(pts)


## A jagged line, for cracks, torn edges and electric arcs.
static func jagged(from: Vector2, to: Vector2, segments: int, roughness: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := (to - from).orthogonal().normalized()
	for i in segments + 1:
		var p := from.lerp(to, float(i) / segments)
		if i != 0 and i != segments:
			p += n * rng.randf_range(-roughness, roughness)
		pts.append(p)
	return pts


static func iso_ellipse(c: Vector2, r: float, points := 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points:
		var a := TAU * i / points
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.5))
	return pts


## A character's shadow: a soft ellipse stretched away from the light.
static func draw_character_shadow(ci: CanvasItem, radius: float, height: float, lift := 0.0) -> void:
	var stretch := SHADOW_DIR * height * 0.5
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		var p := Vector2(cos(a) * radius, sin(a) * radius * 0.45)
		# points on the far side of the light get pushed out to make the long shadow
		var along := maxf(0.0, p.normalized().dot(SHADOW_DIR.normalized()))
		pts.append(p + stretch * along + Vector2(0, lift))
	ci.draw_colored_polygon(pts, Color(0, 0, 0.02, 0.38))
	ci.draw_colored_polygon(iso_ellipse(Vector2.ZERO, radius * 0.7, 16), Color(0, 0, 0.02, 0.25))
