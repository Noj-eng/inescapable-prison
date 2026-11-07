extends RefCounted
## Materials, textures and small props for the 3D cell block, all made in
## code: gritty concrete, worn steel, hazard paint, crack decals, steam.

static var _cache := {}


static func _noise_tex(freq: float, octaves: int, kind: int, seed_value: int, normal := false, lo := Color.BLACK, hi := Color.WHITE) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = kind
	noise.frequency = freq
	noise.fractal_octaves = octaves
	noise.seed = seed_value
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = noise
	if normal:
		tex.as_normal_map = true
		tex.bump_strength = 8.0
	else:
		var ramp := Gradient.new()
		ramp.set_color(0, lo)
		ramp.set_color(1, hi)
		tex.color_ramp = ramp
	return tex


## Stained, pitted concrete. Triplanar, so it wraps any box without stretching.
static func concrete(tint: Color, uv_scale := 0.35) -> StandardMaterial3D:
	var key := "concrete%s%s" % [tint.to_html(), uv_scale]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = _noise_tex(0.012, 6, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 7, false, tint.darkened(0.55), tint.lightened(0.08))
	m.normal_enabled = true
	m.normal_texture = _noise_tex(0.03, 4, FastNoiseLite.TYPE_CELLULAR, 3, true)
	m.normal_scale = 0.7
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * uv_scale
	_cache[key] = m
	return m


static func steel(tint: Color, metal := 0.7) -> StandardMaterial3D:
	var key := "steel%s%s" % [tint.to_html(), metal]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = _noise_tex(0.02, 4, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 11, false, tint.darkened(0.4), tint)
	m.metallic = metal
	m.roughness = 0.6
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.5
	_cache[key] = m
	return m


## Flat, matte colour (cloth, skin, paint): no shiny highlights.
static func matte(c: Color) -> StandardMaterial3D:
	var key := "matte%s" % c.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	_cache[key] = m
	return m


static func glow(c: Color, energy := 3.0) -> StandardMaterial3D:
	var key := "glow%s%s" % [c.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	_cache[key] = m
	return m


## Black and yellow diagonal hazard stripes.
static func hazard() -> StandardMaterial3D:
	if _cache.has("hazard"):
		return _cache["hazard"]
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var stripe := ((x + y) / 16) % 2 == 0
			img.set_pixel(x, y, Color("e0b03a") if stripe else Color("16161a"))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.9
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 1.5
	_cache["hazard"] = m
	return m


## A crack decal texture: jagged dark lines branching from the middle.
static func crack_texture(seed_value: int) -> ImageTexture:
	var key := "crack%d" % seed_value
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for branch in 5:
		var p := Vector2(128, 128) + Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20))
		var dir := Vector2.from_angle(rng.randf() * TAU)
		var width := rng.randf_range(2.0, 4.0)
		for step in 70:
			dir = dir.rotated(rng.randf_range(-0.5, 0.5))
			p += dir * 2.0
			if p.x < 3 or p.y < 3 or p.x > 252 or p.y > 252:
				break
			var w := maxf(0.6, width * (1.0 - step / 70.0))
			for oy in range(-2, 3):
				for ox in range(-2, 3):
					if Vector2(ox, oy).length() <= w:
						img.set_pixel(int(p.x) + ox, int(p.y) + oy, Color(0.02, 0.02, 0.02, 0.9))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func soft_dot() -> GradientTexture2D:
	if _cache.has("dot"):
		return _cache["dot"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	_cache["dot"] = tex
	return tex


## Steam rising out of a floor grate.
static func steam() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.2, 1.2)
	var m := StandardMaterial3D.new()
	m.albedo_texture = soft_dot()
	m.albedo_color = Color(0.75, 0.78, 0.82, 0.16)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	quad.material = m
	p.mesh = quad
	p.amount = 40
	p.lifetime = 3.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.6, 0.05, 0.6)
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0.15, 0.25, 0.0)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.1
	p.scale_amount_min = 0.8
	p.scale_amount_max = 2.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	return p


## A box mesh instance with a material, optionally with a matching collider.
static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, solid := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		shape.shape = bs
		body.add_child(shape)
		mi.add_child(body)
	parent.add_child(mi)
	return mi


static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material, sides := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func capsule(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi
