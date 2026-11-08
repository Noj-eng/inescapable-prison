extends RefCounted
## Themed floors in 3D. Each floor has one theme (picked here), and this file
## builds that theme's props from the map letters theme_gen.gd puts down:
##   cell block: single beds, bunk beds, toilets, sinks, posters and photos
##   mess hall:  the kitchen and lunch line up top, long lunch tables below
##   armory:     weapon racks, lockers and vault doors Victor punches open
##   solitary:   heavy steel doors with a small peephole
##   yard:       weight benches, dumbbells, picnic tables, corner towers
## Plus panicking prisoners everywhere (prisoner_3d.gd).
## Everything is made from simple boxes and code-made textures: no files.

const Look := preload("res://scripts/3d/look_3d.gd")
const Tune := preload("res://scripts/3d/tuning_3d.gd")
const PrisonerScript := preload("res://scripts/3d/prisoner_3d.gd")
const THEMES := ["cellblock", "cafeteria", "armory", "solitary", "yard"]

## Letters that block path finding. D (vault door) is solid until smashed.
const SOLID := "sknlwfSLHhWYD"

const CELL := 2.0
const WALL_H := 3.2

static var _poster_cache := {}


# --- choosing and naming --------------------------------------------------------------

## Floor 1 is always Victor's Cell Block. After that the player picks the
## next floor's theme at each lift (choose_next_floor).
static var next_theme := ""

## What each theme can reward when you pick it at the lift: its stat perk or
## a themed piece of gear (skills_3d.gd / equipment_3d.gd apply them).
const REWARDS := {
	"cellblock": ["rally", "shoulders", "gauntlets"],
	"cafeteria": ["max_hp", "shiv"],
	"armory": ["damage", "pipe", "vest"],
	"solitary": ["powerup_luck", "helmet"],
	"yard": ["speed", "chain", "boots"],
}
const Skills := preload("res://scripts/3d/skills_3d.gd")
const Equipment := preload("res://scripts/3d/equipment_3d.gd")


static func pick(depth: int, last: String) -> String:
	if Tune.FLOOR_THEME != "":
		return Tune.FLOOR_THEME
	if depth <= 1:
		next_theme = ""
		return "cellblock"
	if next_theme != "":
		var t := next_theme
		next_theme = ""
		return t
	var options := THEMES.duplicate()
	options.erase(last)
	return options[randi() % options.size()]


static func title(theme: String, depth := 2) -> String:
	match theme:
		"cellblock": return "VICTOR'S CELL BLOCK" if depth <= 1 else "CELL BLOCK"
		"cafeteria": return "MESS HALL"
		"armory": return "ARMORY"
		"solitary": return "SOLITARY"
		"yard": return "THE YARD"
	return "THE PRISON"


static func floor_mat(level, m: StandardMaterial3D) -> StandardMaterial3D:
	match level.theme:
		"cafeteria":
			var t := StandardMaterial3D.new()
			t.albedo_texture = _checker_tiles()
			t.uv1_world_triplanar = true
			t.uv1_triplanar = true
			t.uv1_scale = Vector3(0.25, 0.25, 0.25)
			t.roughness = 0.55
			return t
		"armory": return _floor(Color("5a5e63"))
		"solitary": return _floor(Color("4a4c50"))
		"yard": return _floor(Color("3d3f42"), 0.6)
	return m


static func wall_mat(level, m: StandardMaterial3D) -> StandardMaterial3D:
	match level.theme:
		"cafeteria": return Look.concrete(Color("6d7a6b"), 0.25)   # institutional green
		"armory": return Look.concrete(Color("525a66"), 0.25)      # cold blue-grey
		"solitary": return Look.concrete(Color("4c4a49"), 0.25)
		"yard": return Look.concrete(Color("7b7466"), 0.25)        # sun-bleached
	return m


static func _floor(tint: Color, uv := 0.3) -> StandardMaterial3D:
	var m := Look.concrete(tint, uv).duplicate() as StandardMaterial3D
	m.uv1_world_triplanar = true
	return m


# --- building one map letter ------------------------------------------------------------

static func build(level, ch: String, x: int, y: int, at: Vector3) -> void:
	match ch:
		"s": _single_bed(level, at)
		"k": _bunk_bed(level, at)
		"n": _sink(level, at)
		"l": _lockers(level, at, x, y)
		"w": _weapon_rack(level, at, x, y)
		"f": _stove(level, at)
		"S": _serving_line(level, at, x)
		"L": _long_table(level, at, x, y)
		"H": _solitary_door(level, at, x)
		"h": _weight_bench(level, at)
		"W": _dumbbell_rack(level, at)
		"Y": _tower(level, at)
		"D":
			if not level.has_meta("vault_tiles"):
				level.set_meta("vault_tiles", [])
			level.get_meta("vault_tiles").append(Vector2i(x, y))
		"p": _prisoner(level, at)


## After the whole floor is built.
static func finish(level) -> void:
	_posters(level)
	_vault_doors(level)
	# the lamps take on the theme's colour
	var tint := Color(0.85, 0.92, 1.0)
	match level.theme:
		"cafeteria": tint = Color(1.0, 0.93, 0.78)
		"armory": tint = Color(0.75, 0.85, 1.0)
		"solitary": tint = Color(0.7, 0.9, 0.78)
		"yard": tint = Color(1.0, 0.72, 0.42)
	for l in level._lamps:
		l.light_color = tint
	if level.theme == "armory" and level.has_meta("vault_tiles"):
		level.get_tree().create_timer(4.6).timeout.connect(func():
			if is_instance_valid(level):
				level._say("The lift is sealed behind a vault door.\nPunch it open.", Color("ff9a3b"), 3.0))


# --- cell block --------------------------------------------------------------------------

static func _blanket() -> Color:
	return [Color("5b6470"), Color("6b5a4a"), Color("8a4b2a"), Color("4a5a48"), Color("7a7a72")][randi() % 5]


static func _single_bed(level, at: Vector3) -> void:
	var frame := Look.steel(Color("3a3d44"))
	var b := at + Vector3(0, 0, -0.35)
	Look.box(level, Vector3(1.9, 0.08, 0.85), b + Vector3(0, 0.45, 0), frame, true)
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			Look.box(level, Vector3(0.06, 0.45, 0.06), b + Vector3(0.9 * sx, 0.22, 0.38 * sz), frame)
	Look.box(level, Vector3(1.8, 0.12, 0.78), b + Vector3(0, 0.55, 0), Look.matte(Color("8b8a78")))
	var blanket := Look.box(level, Vector3(1.2, 0.06, 0.82), b + Vector3(0.25, 0.63, 0.01), Look.matte(_blanket()))
	blanket.rotation.y = randf_range(-0.12, 0.12)
	Look.box(level, Vector3(0.38, 0.1, 0.55), b + Vector3(-0.68, 0.66, 0), Look.matte(Color("c9c6b8")))


static func _bunk_bed(level, at: Vector3) -> void:
	var frame := Look.steel(Color("3a3d44"))
	var b := at + Vector3(0, 0, -0.35)
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			Look.box(level, Vector3(0.07, 1.9, 0.07), b + Vector3(0.92 * sx, 0.95, 0.38 * sz), frame)
	for h: float in [0.42, 1.45]:
		Look.box(level, Vector3(1.9, 0.08, 0.85), b + Vector3(0, h, 0), frame, h < 1.0)
		Look.box(level, Vector3(1.8, 0.12, 0.78), b + Vector3(0, h + 0.1, 0), Look.matte(Color("8b8a78")))
		var blanket := Look.box(level, Vector3(1.15, 0.06, 0.82), b + Vector3(0.3, h + 0.18, 0.01), Look.matte(_blanket()))
		blanket.rotation.y = randf_range(-0.15, 0.15)
		Look.box(level, Vector3(0.36, 0.1, 0.52), b + Vector3(-0.68, h + 0.2, 0), Look.matte(Color("c9c6b8")))
	# a ladder up the end, and a guard rail on the top bunk
	for k in 4:
		Look.box(level, Vector3(0.05, 0.04, 0.5), b + Vector3(0.96, 0.45 + k * 0.32, 0.1), frame)
	Look.box(level, Vector3(1.4, 0.05, 0.05), b + Vector3(-0.2, 1.85, 0.4), frame)


static func _sink(level, at: Vector3) -> void:
	var steel := Look.steel(Color("8a9099"), 0.9)
	Look.box(level, Vector3(0.6, 0.2, 0.45), at + Vector3(0, 0.85, -0.7), steel, true)
	Look.box(level, Vector3(0.5, 0.05, 0.35), at + Vector3(0, 0.96, -0.68), Look.matte(Color("1d2024")))
	Look.box(level, Vector3(0.2, 0.75, 0.2), at + Vector3(0, 0.38, -0.85), steel)
	# a scratched steel mirror (no glass: prison rules)
	var mirror := Look.box(level, Vector3(0.5, 0.6, 0.02), at + Vector3(0, 1.6, -0.98), Look.steel(Color("b8bec6"), 1.0))
	mirror.rotation.z = randf_range(-0.05, 0.05)


# --- posters, photos and notices -------------------------------------------------------

## Pictures on the walls Victor can see: lots near the beds in a cell block,
## a few official notices on every other floor.
static func _posters(level) -> void:
	var near_bed := 0.75 if level.theme == "cellblock" else 0.0
	var anywhere := 0.07 if level.theme == "cellblock" else 0.035
	var notice_lines := {
		"cellblock": ["LIGHTS OUT\n22:00", "NO\nCONTRABAND", "COUNT TIME\nSTAND BY\nYOUR BUNK"],
		"cafeteria": ["TODAY:\nSLOP", "ONE TRAY\nPER INMATE", "WASH\nYOUR HANDS", "NO TALKING\nIN LINE"],
		"armory": ["AUTHORIZED\nPERSONNEL\nONLY", "SIGN OUT\nALL WEAPONS", "LIVE\nAMMUNITION"],
		"solitary": ["SILENCE", "DO NOT\nFEED\nTHE INMATES", "23 HOURS\nA DAY"],
		"yard": ["NO\nLOITERING", "YARD TIME\n1 HOUR", "STAY BEHIND\nTHE LINE"],
	}
	var lines: Array = notice_lines.get(level.theme, ["NO RUNNING"])
	for y in range(1, level.rows - 1):
		for x in range(1, level.cols - 1):
			var ch: String = level._ch(x, y)
			if ch == "#" or ch == "B" or ch == "H":
				continue
			var bed := ch == "s" or ch == "k"
			var chance := near_bed if bed else anywhere
			if level._rng.randf() >= chance:
				continue
			var at: Vector3 = level.cell_pos(x, y)
			var north: bool = level._ch(x, y - 1) == "#"
			var west: bool = level._ch(x - 1, y) == "#"
			if not north and not west:
				continue
			var face: Vector3
			var rot := 0.0
			var along := Vector3.RIGHT
			if north and (not west or level._rng.randf() < 0.5):
				face = at + Vector3(0, 0, -CELL * 0.5 + 0.015)
			else:
				face = at + Vector3(-CELL * 0.5 + 0.015, 0, 0)
				rot = PI / 2
				along = Vector3.BACK
			var h: float = 2.35 if ch == "k" else (1.25 if ch == "s" else level._rng.randf_range(1.5, 2.1))
			var shift: Vector3 = along * level._rng.randf_range(-0.5, 0.5)
			if level.theme == "cellblock":
				# a cluster: one or two pictures, sometimes a little photo too
				_picture(level, face + shift + Vector3(0, h, 0), rot, level._rng.randi() % 8)
				if level._rng.randf() < 0.45:
					_picture(level, face + shift + along * 0.55 + Vector3(0, h - 0.2, 0), rot, 3, 0.55)
			else:
				_notice(level, face + shift + Vector3(0, h, 0), rot, lines[level._rng.randi() % lines.size()])


static func _picture(level, pos: Vector3, rot_y: float, design: int, scale := 1.0) -> void:
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.55, 0.75) * scale if design != 3 else Vector2(0.42, 0.5) * scale
	quad.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _poster_tex(design)
	mat.roughness = 0.85
	quad.material_override = mat
	quad.position = pos
	quad.rotation = Vector3(0, rot_y, randf_range(-0.09, 0.09))
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(quad)
	var words := {4: ["IRON\nRIOT", "NO\nPAROLE", "LOCK\nDOWN", "BLACK\nSITE"], 6: ["MISS YOU\nDAD", "COME\nHOME", "LOVE U"]}
	if words.has(design):
		var label := Label3D.new()
		var pick: Array = words[design]
		label.text = pick[randi() % pick.size()]
		label.font_size = 64
		label.pixel_size = 0.0022 * scale
		label.modulate = Color(1, 0.95, 0.85) if design == 4 else Color(0.85, 0.15, 0.2)
		label.outline_size = 0
		label.shaded = true
		label.position = Vector3(0, -0.22 * scale if design == 4 else 0.24 * scale, 0.004)
		quad.add_child(label)


static func _notice(level, pos: Vector3, rot_y: float, text: String) -> void:
	var plate := Look.box(level, Vector3(0.8, 0.55, 0.02), pos, Look.matte(Color("c9b98a") if randf() < 0.5 else Color("b8bcb6")))
	plate.rotation = Vector3(0, rot_y, randf_range(-0.04, 0.04))
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var band := Look.box(plate, Vector3(0.8, 0.08, 0.005), Vector3(0, 0.235, 0.012), Look.matte(Color("8a1d18")))
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.0028
	label.modulate = Color(0.08, 0.08, 0.08)
	label.outline_size = 0
	label.shaded = true
	label.position = Vector3(0, -0.03, 0.013)
	plate.add_child(label)


## Small painted pictures, drawn pixel by pixel once and reused.
static func _poster_tex(design: int) -> ImageTexture:
	if _poster_cache.has(design):
		return _poster_cache[design]
	var w := 64
	var h := 88
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + design
	match design:
		0:  # sunset over the sea, with a palm tree
			for y in h:
				var t := float(y) / h
				img.fill_rect(Rect2i(0, y, w, 1), Color("3a1f5c").lerp(Color("ff7a3a"), clampf(t * 1.6, 0, 1)))
			_disc(img, 32, 50, 12, Color("ffd36b"))
			for y in range(58, h):
				img.fill_rect(Rect2i(0, y, w, 1), Color("1d3550").lerp(Color("0d1a2a"), float(y - 58) / 30.0))
			for y in range(60, h, 4):
				img.fill_rect(Rect2i(20 + (y % 7), y, 24 - (y % 5), 1), Color("ff9a55"))
			for k in 40:
				img.fill_rect(Rect2i(46 + int(k * 0.15), 20 + k, 2, 1), Color("140c12"))
			for k in 5:
				var a := -2.6 + k * 0.6
				for r in 14:
					img.fill_rect(Rect2i(46 + int(cos(a) * r), 20 + int(sin(a) * r * 0.6 + r * 0.25), 2, 1), Color("140c12"))
		1:  # a red muscle car
			for y in h:
				img.fill_rect(Rect2i(0, y, w, 1), Color("12303a").lerp(Color("05090c"), float(y) / h))
			img.fill_rect(Rect2i(0, 64, w, 24), Color("1a1a1c"))
			img.fill_rect(Rect2i(0, 76, w, 2), Color("e8c83a"))
			img.fill_rect(Rect2i(6, 50, 52, 12), Color("c4231c"))
			img.fill_rect(Rect2i(18, 42, 26, 9), Color("a51c17"))
			img.fill_rect(Rect2i(21, 44, 20, 6), Color("7fb2c8"))
			img.fill_rect(Rect2i(6, 55, 52, 2), Color("e8e8e8"))
			_disc(img, 17, 62, 6, Color("0b0b0b"))
			_disc(img, 47, 62, 6, Color("0b0b0b"))
			_disc(img, 17, 62, 2, Color("9a9a9a"))
			_disc(img, 47, 62, 2, Color("9a9a9a"))
		2:  # a calendar with the days crossed off
			img.fill(Color("ece6d6"))
			img.fill_rect(Rect2i(0, 0, w, 16), Color("a8241c"))
			var crossed := rng.randi_range(18, 29)
			for i in 35:
				var cx := 4 + (i % 7) * 8
				var cy := 22 + (i / 7) * 12
				img.fill_rect(Rect2i(cx, cy, 7, 10), Color("d7d0bd"))
				if i < crossed:
					for k in 7:
						img.set_pixel(cx + k, cy + int(k * 1.4), Color("c0201a"))
						img.set_pixel(cx + 6 - k, cy + int(k * 1.4), Color("c0201a"))
		3:  # a family photo
			img.fill(Color("f2efe6"))
			img.fill_rect(Rect2i(5, 5, 54, 60), Color("8fb7d6"))
			img.fill_rect(Rect2i(5, 45, 54, 20), Color("5d8a4a"))
			for k in 3:
				var fx := 16 + k * 15
				var tall := 22 - (8 if k == 2 else 0)
				img.fill_rect(Rect2i(fx - 4, 62 - tall, 9, tall - 6), [Color("a8433a"), Color("3a5aa8"), Color("e0b23a")][k])
				_disc(img, fx, 62 - tall - 3, 4, Color("d9a983"))
		4:  # a band / fight poster
			img.fill(Color("0e0e10"))
			for y in h:
				img.fill_rect(Rect2i(clampi(y - 30, 0, w), y, 18, 1), Color("e8b12a"))
			_disc(img, 32, 30, 14, Color("e6e2d6"))
			_disc(img, 26, 28, 4, Color("0e0e10"))
			_disc(img, 38, 28, 4, Color("0e0e10"))
			img.fill_rect(Rect2i(26, 38, 12, 3), Color("0e0e10"))
		5:  # snowy mountains
			for y in h:
				img.fill_rect(Rect2i(0, y, w, 1), Color("a9cbe6").lerp(Color("e6eef2"), float(y) / 50.0))
			_mountain(img, 20, 22, 28, Color("5d6670"))
			_mountain(img, 44, 30, 24, Color("4a535c"))
			img.fill_rect(Rect2i(0, 62, w, 26), Color("2f5a4a"))
		6:  # a kid's crayon drawing
			img.fill(Color("f4f1ea"))
			_disc(img, 50, 14, 7, Color("f2c230"))
			img.fill_rect(Rect2i(10, 48, 26, 20), Color("d9493a"))
			_mountain(img, 23, 34, 14, Color("6a3a2a"))
			img.fill_rect(Rect2i(20, 56, 6, 12), Color("6a3a2a"))
			for k in 2:
				var sx := 44 + k * 9
				img.fill_rect(Rect2i(sx, 52, 1, 12), Color("2a2a8a"))
				_disc(img, sx, 49, 3, Color("2a2a8a"))
				img.fill_rect(Rect2i(sx - 3, 56, 7, 1), Color("2a2a8a"))
			img.fill_rect(Rect2i(0, 70, w, 2), Color("4aa84a"))
		_:  # magazine cut-outs taped up
			img.fill(Color("2a2622"))
			for k in 9:
				img.fill_rect(Rect2i(rng.randi_range(0, 44), rng.randi_range(0, 70), rng.randi_range(12, 24), rng.randi_range(10, 20)),
						Color.from_hsv(rng.randf(), rng.randf_range(0.3, 0.8), rng.randf_range(0.5, 0.95)))
	# age it: grime, a fold, tape on the corners
	for k in 400:
		var px := rng.randi_range(0, w - 1)
		var py := rng.randi_range(0, h - 1)
		img.set_pixel(px, py, img.get_pixel(px, py).darkened(rng.randf_range(0.05, 0.3)))
	img.fill_rect(Rect2i(0, h / 2, w, 1), img.get_pixel(5, h / 2).darkened(0.25))
	for c in [Vector2i(0, 0), Vector2i(w - 7, 0), Vector2i(0, h - 5), Vector2i(w - 7, h - 5)]:
		img.fill_rect(Rect2i(c.x, c.y, 7, 5), Color(0.85, 0.83, 0.75))
	var tex := ImageTexture.create_from_image(img)
	_poster_cache[design] = tex
	return tex


static func _disc(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + y * y <= r * r and cx + x >= 0 and cy + y >= 0 and cx + x < img.get_width() and cy + y < img.get_height():
				img.set_pixel(cx + x, cy + y, c)


static func _mountain(img: Image, cx: int, top: int, half: int, c: Color) -> void:
	for y in range(top, top + half * 2):
		var spread := (y - top) / 2
		var snow := y < top + 8
		img.fill_rect(Rect2i(clampi(cx - spread, 0, 63), y, mini(spread * 2 + 1, 64), 1), Color("eef2f4") if snow else c)


static func _checker_tiles() -> ImageTexture:
	if _poster_cache.has("checker"):
		return _poster_cache["checker"]
	var img := Image.create(128, 128, true, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for ty in 8:
		for tx in 8:
			var base := Color("5e2a24") if (tx + ty) % 2 == 0 else Color("8a8474")
			base = base.darkened(rng.randf_range(0.0, 0.18))
			img.fill_rect(Rect2i(tx * 16, ty * 16, 16, 16), base)
			img.fill_rect(Rect2i(tx * 16, ty * 16, 16, 1), Color("3a3833"))
			img.fill_rect(Rect2i(tx * 16, ty * 16, 1, 16), Color("3a3833"))
	for k in 2500:
		var px := rng.randi_range(0, 127)
		var py := rng.randi_range(0, 127)
		img.set_pixel(px, py, img.get_pixel(px, py).darkened(rng.randf_range(0.05, 0.35)))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_poster_cache["checker"] = tex
	return tex


# --- mess hall -------------------------------------------------------------------------

static func _long_table(level, at: Vector3, x: int, y: int) -> void:
	var yard: bool = level.theme == "yard"
	var top := Look.matte(Color("6a4a30")) if yard else Look.steel(Color("7a8088"), 0.6)
	var seat := Look.matte(Color("5a3e28")) if yard else Look.steel(Color("4a5058"), 0.6)
	# one 2 m piece of a long table: neighbours join up into one long run
	Look.box(level, Vector3(CELL, 0.07, 0.9), at + Vector3(0, 0.78, 0), top, true)
	for sz: int in [-1, 1]:
		Look.box(level, Vector3(CELL, 0.06, 0.32), at + Vector3(0, 0.45, 0.72 * sz), seat)
	var ends := [level._ch(x - 1, y) != "L", level._ch(x + 1, y) != "L"]
	for i in 2:
		if ends[i]:
			var sx := -1.0 if i == 0 else 1.0
			Look.box(level, Vector3(0.08, 0.78, 1.6), at + Vector3(0.85 * sx, 0.39, 0), seat)
	if not yard:
		# trays and spilled slop, left behind when the quake hit
		for k in randi_range(0, 3):
			var tray := Look.box(level, Vector3(0.42, 0.03, 0.3), at + Vector3(randf_range(-0.7, 0.7), 0.83, 0.2 * (1 if randf() < 0.5 else -1)), Look.matte(Color("5e6a74")))
			tray.rotation.y = randf_range(-0.4, 0.4)
			Look.box(tray, Vector3(0.18, 0.03, 0.14), Vector3(0.06, 0.025, 0), Look.matte(Color("8c7a3a")))


static func _stove(level, at: Vector3) -> void:
	var steel := Look.steel(Color("7d838b"), 0.85)
	var b := at + Vector3(0, 0, -0.3)
	Look.box(level, Vector3(1.9, 0.95, 1.1), b + Vector3(0, 0.47, 0), steel, true)
	Look.box(level, Vector3(1.9, 0.06, 1.1), b + Vector3(0, 0.97, 0), Look.steel(Color("2b2e33")))
	for k in 2:
		var burner := Look.cylinder(level, 0.22, 0.03, b + Vector3(-0.45 + k * 0.9, 1.01, 0), Look.glow(Color(1.0, 0.35, 0.1), 1.8), 16)
		burner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# a huge pot on one burner
	Look.cylinder(level, 0.32, 0.5, b + Vector3(-0.45, 1.28, 0), Look.steel(Color("9aa0a8"), 0.9), 16)
	if randf() < 0.5:
		var steam := Look.steam()
		steam.position = b + Vector3(-0.45, 1.55, 0)
		level.add_child(steam)
	# extractor hood on the wall
	Look.box(level, Vector3(1.9, 0.4, 0.8), b + Vector3(0, 2.4, -0.15), Look.steel(Color("5a6068"), 0.8))
	Look.box(level, Vector3(1.9, 0.6, 0.06), b + Vector3(0, 0.45, 0.56), Look.steel(Color("3a3e44")))


static func _serving_line(level, at: Vector3, x: int) -> void:
	var steel := Look.steel(Color("8a9099"), 0.85)
	Look.box(level, Vector3(CELL, 1.0, 0.9), at + Vector3(0, 0.5, 0), steel, true)
	Look.box(level, Vector3(CELL, 0.05, 0.3), at + Vector3(0, 0.95, 0.6), Look.steel(Color("5a6068")))   # tray rail
	# steaming food pans under a sneeze guard
	for k in 3:
		var food: Color = [Color("8c7a3a"), Color("6a7a3a"), Color("9a5a2a"), Color("b8b09a")][randi() % 4]
		Look.box(level, Vector3(0.5, 0.06, 0.5), at + Vector3(-0.62 + k * 0.62, 1.02, 0), Look.glow(food, 0.4))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.85, 0.9, 0.15)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	var pane := Look.box(level, Vector3(CELL, 0.04, 0.6), at + Vector3(0, 1.5, 0.1), glass)
	pane.rotation.x = -0.35
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Look.box(level, Vector3(0.04, 0.55, 0.04), at + Vector3(-0.95, 1.27, 0.3), steel)
	Look.box(level, Vector3(CELL, 0.05, 0.12), at + Vector3(0, 1.75, -0.1), Look.glow(Color(1.0, 0.55, 0.25), 2.0))
	if x % 2 == 0:
		var heat := OmniLight3D.new()
		heat.light_color = Color(1.0, 0.6, 0.3)
		heat.light_energy = 1.2
		heat.omni_range = 3.5
		heat.position = at + Vector3(0, 1.6, 0.3)
		level.add_child(heat)
		level._glass_lights.append(heat)


# --- armory ----------------------------------------------------------------------------

static func _weapon_rack(level, at: Vector3, x: int, y: int) -> void:
	var frame := Look.steel(Color("2c3036"))
	var against_wall: bool = level._ch(x, y - 1) == "#"
	var b := at + Vector3(0, 0, -0.55 if against_wall else 0.0)
	Look.box(level, Vector3(1.9, 2.0, 0.12), b + Vector3(0, 1.0, 0), Look.steel(Color("3c424a"), 0.6), true)
	Look.box(level, Vector3(1.9, 0.08, 0.5), b + Vector3(0, 0.12, 0.2), frame)
	Look.box(level, Vector3(1.9, 0.06, 0.25), b + Vector3(0, 1.75, 0.1), frame)
	var gun := Look.steel(Color("16181b"), 0.5)
	for k in 6:
		var sx := -0.75 + k * 0.3
		var roll := randf()
		if roll < 0.25:
			continue     # already grabbed
		elif roll < 0.75:
			# a rifle standing on its stock
			var r := Look.box(level, Vector3(0.07, 1.2, 0.12), b + Vector3(sx, 0.75, 0.16), gun)
			r.rotation.z = randf_range(-0.05, 0.05)
			Look.box(r, Vector3(0.09, 0.3, 0.16), Vector3(0, -0.45, 0.02), Look.matte(Color("3a2a1e")))
			Look.box(r, Vector3(0.05, 0.18, 0.06), Vector3(0, 0.05, 0.09), gun)
		else:
			# a riot baton on a hook
			Look.cylinder(level, 0.03, 0.6, b + Vector3(sx, 1.35, 0.12), Look.matte(Color("101012")), 6)
	if randf() < 0.5:
		# a riot shield leaning on the rack
		var shield := Look.box(level, Vector3(0.55, 0.9, 0.03), b + Vector3(randf_range(-0.5, 0.5), 0.5, 0.35), Look.matte(Color(0.55, 0.65, 0.75)))
		shield.rotation.x = -0.18


static func _lockers(level, at: Vector3, x: int, y: int) -> void:
	var north: bool = level._ch(x, y - 1) == "#"
	var steel := Look.steel([Color("4b5a6a"), Color("5a5a4e"), Color("3e4a40")][(x + y) % 3], 0.6)
	var body := Look.box(level, Vector3(1.9, 2.0, 0.55), Vector3.ZERO, steel, true)
	if north:
		body.position = at + Vector3(0, 1.0, -0.7)
	else:
		body.position = at + Vector3(-0.7, 1.0, 0)
		body.rotation.y = PI / 2
	for k in 3:
		var dx := -0.62 + k * 0.62
		if randf() < 0.2:
			# a door hanging open
			var door := Look.box(body, Vector3(0.58, 1.9, 0.03), Vector3(dx - 0.29, 0, 0.3), steel)
			door.rotation.y = -1.1
			door.position += Vector3(0.29 * cos(1.1), 0, 0.29 * sin(1.1))
			Look.box(body, Vector3(0.56, 1.88, 0.02), Vector3(dx, 0, 0.27), Look.matte(Color("101114")))
		else:
			for v in 3:
				Look.box(body, Vector3(0.36, 0.025, 0.01), Vector3(dx, 0.75 - v * 0.06, 0.28), Look.matte(Color("15171a")))
			Look.box(body, Vector3(0.025, 1.9, 0.01), Vector3(dx + 0.3, 0, 0.28), Look.matte(Color("15171a")))
			Look.box(body, Vector3(0.05, 0.12, 0.03), Vector3(dx + 0.2, 0.0, 0.29), Look.steel(Color("9a9a9a")))


## Vault doors: each straight run of D tiles becomes one huge steel door.
static func _vault_doors(level) -> void:
	if not level.has_meta("vault_tiles"):
		return
	var left: Dictionary = {}
	for t in level.get_meta("vault_tiles"):
		left[t] = true
	var number := 1
	for t: Vector2i in level.get_meta("vault_tiles"):
		if not left.has(t):
			continue
		var along := Vector2i(1, 0) if (left.has(t + Vector2i(1, 0)) or left.has(t - Vector2i(1, 0))) else Vector2i(0, 1)
		var a := t
		while left.has(a - along):
			a -= along
		var run: Array[Vector2i] = []
		var c := a
		while left.has(c):
			run.append(c)
			left.erase(c)
			c += along
		var door := VaultDoor.new()
		door.setup(level, run, along, number)
		door.has_punk = number <= 3 and randf() < 0.7
		number += 1


class VaultDoor extends Node3D:
	## A massive armored door. Victor punches it; it dents, sparks, and after
	## enough hits blows off its frame and crashes to the floor.
	const Look := preload("res://scripts/3d/look_3d.gd")
	const Tune := preload("res://scripts/3d/tuning_3d.gd")
	var level
	var tiles: Array[Vector2i] = []
	var hp := 8.0
	var slab: MeshInstance3D
	var body: StaticBody3D
	var mat: StandardMaterial3D
	var beacon: OmniLight3D
	var flash := 0.0
	var _broken := false
	var _cool := 0.0
	var has_punk := false
	var _punk: Node3D
	var _punk_side := 0.0
	var _jab_in := 2.0
	var _baton: MeshInstance3D

	func setup(lvl, run: Array[Vector2i], along: Vector2i, number: int) -> void:
		level = lvl
		tiles = run
		hp = Tune.VAULT_DOOR_HITS
		var n := run.size()
		var mid: Vector2 = (Vector2(run[0]) + Vector2(run[n - 1])) * 0.5
		position = level.cell_pos(mid.x, mid.y)
		if along == Vector2i(0, 1):
			rotation.y = PI / 2
		level.add_child(self)
		var width := n * 2.0
		var h := 3.2
		mat = Look.steel(Color("59606a"), 0.8).duplicate()
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.5, 0.2)
		mat.emission_energy_multiplier = 0.0
		slab = Look.box(self, Vector3(width, h - 0.3, 0.5), Vector3(0, (h - 0.3) * 0.5, 0), mat)
		body = StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(width, h, 0.8)
		shape.shape = bs
		shape.position.y = h * 0.5
		body.add_child(shape)
		add_child(body)
		# armour plates, hazard stripes, the big locking wheel, rivets
		for k in n:
			var px := -width * 0.5 + 1.0 + k * 2.0
			Look.box(slab, Vector3(1.7, 2.3, 0.06), Vector3(px, 0.05, 0.27), Look.steel(Color("4a5058"), 0.8))
			for ry in [-1.1, 1.1]:
				for rx in [-0.75, 0.75]:
					Look.sphere(slab, 0.04, Vector3(px + rx, ry, 0.31), Look.steel(Color("8a9099"), 0.9))
		var stripe := Look.box(slab, Vector3(width, 0.35, 0.04), Vector3(0, -(h - 0.3) * 0.5 + 0.2, 0.28), Look.hazard())
		stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var wheel := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.42
		torus.outer_radius = 0.52
		wheel.mesh = torus
		wheel.material_override = Look.steel(Color("9a8a5a"), 0.9)
		wheel.rotation.x = PI / 2
		wheel.position = Vector3(0, 0.1, 0.36)
		slab.add_child(wheel)
		for k in 3:
			var spoke := Look.box(slab, Vector3(0.9, 0.06, 0.05), Vector3(0, 0.1, 0.36), Look.steel(Color("9a8a5a"), 0.9))
			spoke.rotation.z = k * PI / 3
		# the frame round it, and a warning beacon on top
		var frame := Look.steel(Color("23262b"))
		for sx in [-1, 1]:
			Look.box(self, Vector3(0.3, h, 0.9), Vector3(sx * (width * 0.5 + 0.1), h * 0.5, 0), frame)
		Look.box(self, Vector3(width + 0.5, 0.35, 0.9), Vector3(0, h - 0.15, 0), frame)
		Look.sphere(self, 0.14, Vector3(0, h + 0.1, 0.35), Look.glow(Color(1.0, 0.45, 0.1), 5.0))
		beacon = OmniLight3D.new()
		beacon.light_color = Color(1.0, 0.45, 0.1)
		beacon.light_energy = 2.0
		beacon.omni_range = 6.0
		beacon.position = Vector3(0, h, 1.0)
		add_child(beacon)
		var label := Label3D.new()
		label.text = "VAULT %02d" % number
		label.font_size = 96
		label.pixel_size = 0.004
		label.modulate = Color(0.9, 0.85, 0.7, 0.85)
		label.outline_size = 0
		label.shaded = true
		label.position = Vector3(0, 0.95, 0.31)
		slab.add_child(label)
		# one punch target per tile, so a hit anywhere along the door counts
		for k in n:
			var target := VaultSpot.new()
			target.door = self
			target.position = Vector3(-width * 0.5 + 1.0 + k * 2.0, 0, 0)
			add_child(target)

	func _process(delta: float) -> void:
		if has_punk and not _broken:
			_punk_think(delta)
		_cool = maxf(0.0, _cool - delta)
		flash = maxf(0.0, flash - delta * 3.0)
		if mat:
			mat.emission_energy_multiplier = flash * 2.0 + (1.0 - hp / Tune.VAULT_DOOR_HITS) * 0.6
		if beacon and not _broken:
			beacon.light_energy = 1.0 + 1.5 * absf(sin(Time.get_ticks_msec() * 0.006))

	func take_hit(from: Vector3, damage := 1.0, _force := 6.0) -> void:
		if _broken or _cool > 0.0:
			return
		_cool = 0.1        # one punch hits several spots: count it once
		hp -= damage
		flash = 1.0
		level.shake(0.12)
		_sparks(from)
		# dent and rattle
		var push := (global_position - from)
		push.y = 0
		var tw := create_tween()
		tw.tween_property(slab, "position:z", -0.08 if to_local(from).z > 0 else 0.08, 0.04)
		tw.tween_property(slab, "position:z", 0.0, 0.12)
		if hp <= 0.0:
			_break(from)

	func _sparks(from: Vector3) -> void:
		var p := CPUParticles3D.new()
		p.one_shot = true
		p.amount = 18
		p.lifetime = 0.5
		p.explosiveness = 1.0
		p.direction = Vector3(0, 1, 0)
		p.spread = 70.0
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 6.0
		p.gravity = Vector3(0, -14, 0)
		p.scale_amount_min = 0.04
		p.scale_amount_max = 0.08
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		m.material = Look.glow(Color(1.0, 0.7, 0.3), 6.0)
		p.mesh = m
		var hit := global_position.lerp(from, 0.0)
		hit.y = 1.3
		var toward := from - global_position
		toward.y = 0
		var local := to_local(from)
		p.position = Vector3(clampf(local.x, -9, 9), 1.3, 0.4 if local.z > 0 else -0.4)
		add_child(p)
		p.emitting = true
		get_tree().create_timer(1.0).timeout.connect(p.queue_free)

	func _break(from: Vector3) -> void:
		_broken = true
		body.queue_free()
		for c in get_children():
			if c is VaultSpot:
				c.remove_from_group("breakables")
		for t in tiles:
			level._astar.set_point_solid(t, false)
		if _punk:
			# the punk from the window: no glass to hide behind now
			var spot := _punk.global_position
			spot.y = 0.1
			_punk.queue_free()
			_punk = null
			level._spawn_enemy("guard", spot)
			var e = level.get_child(level.get_child_count() - 1)
			if e and e.is_in_group("enemies"):
				e.target = level.player
				e.active = true
				e.hp = 1.0
			_taunt("UH OH.", Vector3(0, 2.6, -_punk_side * 0.9))
		level.shake(0.5)
		level._say("VAULT DOOR DOWN", Color("ff9a3b"), 1.5)
		beacon.light_energy = 0.0
		# blown off its hinges: falls flat, away from Victor
		var away := -1.0 if to_local(from).z > 0 else 1.0
		var tw := create_tween().set_parallel()
		tw.tween_property(slab, "rotation:x", PI / 2 * -away, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(slab, "position", Vector3(0, 0.3, away * 1.45), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		for k in 3:
			_sparks(global_position + Vector3(randf_range(-1, 1), 0, away))

	# --- the punk guard at the door controls ------------------------------------
	const TAUNTS := ["HEH. TOO SLOW, MEATHEAD.", "NICE TRY, BIG GUY!", "YOU'LL NEVER GET IN HERE!",
			"THIS DOOR'S RATED FOR TANKS, PAL.", "KNOCK KNOCK!", "AWW, IS VICTOR MAD?"]

	func _punk_think(delta: float) -> void:
		var victor: Node3D = level.player
		if not is_instance_valid(victor):
			return
		var local := to_local(victor.global_position)
		var near := absf(local.x) < tiles.size() + 0.6 and absf(local.z) < 9.0
		if _punk == null:
			if near:
				_make_punk(-signf(local.z) if local.z != 0.0 else 1.0)
			return
		_jab_in -= delta
		# he slides along behind the window to stay in front of Victor
		_punk.position.x = move_toward(_punk.position.x, clampf(local.x, -tiles.size() + 0.7, tiles.size() - 0.7), delta * 2.0)
		if _jab_in <= 0.0:
			_jab_in = randf_range(2.2, 3.8)
			var reach := Vector2(local.x - _punk.position.x, local.z).length()
			if reach < 2.4 and local.z * _punk_side < 0.0:
				_jab(victor)
			elif randf() < 0.4:
				_taunt(TAUNTS[randi() % TAUNTS.size()], _punk.position + Vector3(0, 1.3, 0))

	func _make_punk(side: float) -> void:
		has_punk = true
		_punk_side = side
		_punk = Node3D.new()
		_punk.position = Vector3(0, 0, side * 0.75)
		_punk.rotation.y = 0.0 if side < 0 else PI   # faces the window
		add_child(_punk)
		var navy := Look.matte(Color("1f2a3d"))
		Look.box(_punk, Vector3(0.5, 0.65, 0.3), Vector3(0, 1.3, 0), navy)
		Look.box(_punk, Vector3(0.5, 0.95, 0.3), Vector3(0, 0.48, 0), Look.matte(Color("15161a")))
		Look.sphere(_punk, 0.15, Vector3(0, 1.8, 0), Look.matte(Color("d9a983")))
		Look.box(_punk, Vector3(0.34, 0.07, 0.38), Vector3(0, 1.93, 0.04), navy)       # cap
		Look.box(_punk, Vector3(0.12, 0.02, 0.02), Vector3(0.03, 1.75, 0.15), Look.matte(Color("3a1a1a"))).rotation.z = 0.25   # smirk
		# the window he looks through, and the control panel he hides behind
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(0.6, 0.85, 1.0, 0.18)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.emission_enabled = true
		glass.emission = Color(0.3, 0.6, 0.8)
		glass.emission_energy_multiplier = 0.3
		var win := Look.box(slab, Vector3(1.1, 0.5, 0.52), Vector3(0, 0.95 - 0.0, 0), glass)
		win.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var panel := Look.box(_punk, Vector3(0.9, 0.9, 0.3), Vector3(0, 0.45, 0.45), Look.steel(Color("2b2f36")))
		Look.box(panel, Vector3(0.6, 0.2, 0.02), Vector3(0, 0.3, 0.16), Look.glow(Color(0.2, 1.0, 0.6), 2.0))
		_baton = Look.cylinder(_punk, 0.035, 0.7, Vector3(0.25, 1.55, 0.1), Look.glow(Color(0.4, 0.8, 1.0), 3.0), 6)
		_baton.rotation.x = PI / 2
		_taunt("HEY, MEATHEAD! OVER HERE!", Vector3(_punk.position.x, 3.0, _punk.position.z))

	func _jab(victor: Node3D) -> void:
		# a stun baton shoved through the window slot
		var tw := create_tween()
		tw.tween_property(_baton, "position:z", 1.3, 0.08)
		tw.tween_property(_baton, "position:z", 0.1, 0.25)
		if victor.has_method("hit"):
			victor.hit(global_position, 1, 4.0)
		if randf() < 0.6:
			_taunt(["ZAP! HAHA!", "GOTCHA!", "STAY BACK, FREAK!"][randi() % 3], _punk.position + Vector3(0, 1.3, 0))

	func _taunt(text: String, at: Vector3) -> void:
		var label := Label3D.new()
		label.text = text
		label.font_size = 56
		label.pixel_size = 0.006
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = Color(0.55, 0.8, 1.0)
		label.outline_size = 12
		label.outline_modulate = Color(0, 0, 0, 0.8)
		label.position = at + Vector3(0, 1.0, 0)
		add_child(label)
		var tw := create_tween()
		tw.tween_property(label, "position:y", at.y + 1.6, 1.8)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 1.8).set_delay(0.8)
		tw.tween_callback(label.queue_free)


class SearchTower extends Node3D:
	## Yard tower searchlight: if its beam lands on Victor, the alarm goes off.
	const Tune := preload("res://scripts/3d/tuning_3d.gd")
	var level
	var beam: SpotLight3D
	var _cool := 0.0

	func _process(delta: float) -> void:
		_cool = maxf(0.0, _cool - delta)
		if beam == null or level == null or not is_instance_valid(level.player):
			return
		var dir := -beam.global_basis.z
		if dir.y >= -0.05:
			return
		var o := beam.global_position
		var ground := o + dir * (-o.y / dir.y)
		var gap: Vector3 = level.player.global_position - ground
		gap.y = 0
		var spotted := gap.length() < 2.8
		beam.light_color = Color(1.0, 0.25, 0.15) if _cool > 4.0 else Color(1.0, 0.95, 0.82)
		if spotted and _cool <= 0.0:
			_cool = 6.0
			level.calm = false
			level._alarm = 3.0
			level.shake(0.2)
			level._say("SPOTTED BY THE TOWER!\nEvery guard nearby is coming.", Color("ff3b3b"), 2.0)
			for e in level.get_tree().get_nodes_in_group("enemies"):
				if e.global_position.distance_to(level.player.global_position) < Tune.ALARM_RADIUS:
					e.active = true


class VaultSpot extends Node3D:
	## An invisible punch target on a vault door (Victor hits "breakables").
	var door
	var active := false
	var target: Node3D

	func _ready() -> void:
		add_to_group("breakables")

	func take_hit(from: Vector3, damage := 1.0, force := 6.0) -> void:
		door.take_hit(from, damage, force)


# --- solitary --------------------------------------------------------------------------

static func _solitary_door(level, at: Vector3, x: int) -> void:
	var wall := Look.concrete(Color("4c4a49"), 0.25)
	var steel := Look.steel(Color("4d5157"), 0.75)
	# the doorway: wall either side and above, a thick steel door in it
	for sx: int in [-1, 1]:
		Look.box(level, Vector3(0.35, WALL_H, CELL), at + Vector3(sx * 0.825, WALL_H * 0.5, 0), wall, true)
	Look.box(level, Vector3(1.3, WALL_H - 2.4, CELL), at + Vector3(0, 2.4 + (WALL_H - 2.4) * 0.5, 0), wall)
	var door := Look.box(level, Vector3(1.3, 2.4, 0.22), at + Vector3(0, 1.2, 0.55), steel, true)
	# frame, hinges, a food hatch
	Look.box(level, Vector3(1.45, 0.1, 0.3), at + Vector3(0, 2.42, 0.55), Look.steel(Color("23262b")))
	for hy in [0.5, 1.9]:
		Look.cylinder(door, 0.05, 0.3, Vector3(-0.66, hy - 1.2, 0.08), Look.steel(Color("23262b")), 8)
	Look.box(door, Vector3(0.5, 0.18, 0.03), Vector3(0, -0.25, 0.12), Look.steel(Color("2f3237")))
	# the small peephole: a dark slot with bars, and sometimes eyes in the dark
	Look.box(door, Vector3(0.36, 0.14, 0.03), Vector3(0, 0.6, 0.115), Look.matte(Color("050506")))
	for k in 3:
		Look.box(door, Vector3(0.02, 0.14, 0.02), Vector3(-0.09 + k * 0.09, 0.6, 0.13), Look.steel(Color("8a9099")))
	if randf() < 0.4:
		for ex: float in [-0.05, 0.05]:
			Look.sphere(door, 0.012, Vector3(ex, 0.61, 0.12), Look.glow(Color(1.0, 0.85, 0.6), 4.0))
	var lamp := Look.sphere(level, 0.05, at + Vector3(0.75, 2.55, 0.7), Look.glow(Color(1.0, 0.1, 0.05), 5.0))
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var label := Label3D.new()
	label.text = "S-%02d" % (x % 97)
	label.font_size = 80
	label.pixel_size = 0.003
	label.modulate = Color(0.85, 0.8, 0.6, 0.8)
	label.outline_size = 0
	label.shaded = true
	label.position = Vector3(0, 0.95, 0.115)
	door.add_child(label)
	# somebody inside is hammering on the door
	if randf() < 0.35:
		var tw: Tween = level.create_tween().set_loops()
		var rest := door.position
		tw.tween_interval(randf_range(1.5, 5.0))
		for k in 4:
			tw.tween_property(door, "position", rest + Vector3(0, 0, 0.035), 0.05)
			tw.tween_property(door, "position", rest, 0.07)


# --- yard ------------------------------------------------------------------------------

static func _weight_bench(level, at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = [0.0, PI / 2][randi() % 2] + randf_range(-0.2, 0.2)
	level.add_child(root)
	var frame := Look.steel(Color("2a2c30"))
	Look.box(root, Vector3(0.35, 0.1, 1.3), Vector3(0, 0.45, 0), Look.matte(Color("1d1d20")), true)
	Look.box(root, Vector3(0.08, 0.42, 0.08), Vector3(0, 0.2, 0.5), frame)
	Look.box(root, Vector3(0.08, 0.42, 0.08), Vector3(0, 0.2, -0.5), frame)
	for sx: int in [-1, 1]:
		Look.box(root, Vector3(0.06, 1.1, 0.06), Vector3(0.35 * sx, 0.55, -0.55), frame)
	# the barbell on the rack, or dropped on the floor
	var dropped := randf() < 0.4
	var bar := Look.cylinder(root, 0.025, 1.8, Vector3(0, 0.08 if dropped else 1.05, 0.2 if dropped else -0.55), Look.steel(Color("b0b4ba"), 0.95), 8)
	bar.rotation.z = PI / 2
	for sx: int in [-1, 1]:
		for k in 2:
			var plate := Look.cylinder(bar, 0.2 - k * 0.04, 0.06, Vector3(0, (0.62 + k * 0.07) * sx, 0), Look.matte(Color("151517")), 16)
			plate.position.y = (0.62 + k * 0.07) * sx


static func _dumbbell_rack(level, at: Vector3) -> void:
	var frame := Look.steel(Color("2a2c30"))
	var b := at + Vector3(0, 0, -0.5)
	Look.box(level, Vector3(1.8, 0.06, 0.5), b + Vector3(0, 0.45, 0), frame, true)
	Look.box(level, Vector3(1.8, 0.06, 0.5), b + Vector3(0, 0.8, -0.1), frame)
	for sx: int in [-1, 1]:
		Look.box(level, Vector3(0.06, 0.8, 0.5), b + Vector3(0.88 * sx, 0.4, 0), frame)
	for row in 2:
		for k in 5:
			if randf() < 0.2:
				continue
			var db := Look.cylinder(level, 0.02, 0.32, b + Vector3(-0.7 + k * 0.35, 0.53 + row * 0.35, -row * 0.1), Look.steel(Color("8a8e94")), 6)
			db.rotation.x = PI / 2
			for e: float in [-0.13, 0.13]:
				Look.cylinder(db, 0.06 + row * 0.01, 0.06, Vector3(0, e, 0), Look.matte(Color("151517")), 10)


## Placeholder guard tower: tall legs, a cabin, and a searchlight that sweeps
## the yard. Nobody shoots from it yet (Jon is still deciding).
static func _tower(level, at: Vector3) -> void:
	var steel := Look.steel(Color("3a3e44"))
	var h := 7.0
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			var leg := Look.box(level, Vector3(0.18, h, 0.18), at + Vector3(0.65 * sx, h * 0.5, 0.65 * sz), steel)
			leg.rotation = Vector3(0.04 * sz, 0, -0.04 * sx)
	Look.box(level, Vector3(1.4, 0.4, 1.4), at + Vector3(0, 0.2, 0), Look.concrete(Color("6a6c70"), 0.3), true)
	for k in 3:
		Look.box(level, Vector3(1.5, 0.06, 0.06), at + Vector3(0, 1.8 + k * 1.8, 0.7), steel).rotation.z = 0.7 * (1 if k % 2 == 0 else -1)
	var cabin := Look.box(level, Vector3(2.2, 1.6, 2.2), at + Vector3(0, h + 0.8, 0), Look.concrete(Color("5d5f63"), 0.25))
	Look.box(cabin, Vector3(2.25, 0.5, 2.25), Vector3(0, 0.15, 0), Look.glow(Color(1.0, 0.8, 0.45), 1.2))
	Look.box(cabin, Vector3(2.6, 0.15, 2.6), Vector3(0, 0.85, 0), steel)
	var pivot := SearchTower.new()
	pivot.level = level
	pivot.position = at + Vector3(0, h + 1.2, 0)
	level.add_child(pivot)
	Look.cylinder(pivot, 0.22, 0.4, Vector3(0, 0, 0.9), Look.glow(Color(1.0, 0.95, 0.8), 6.0), 12).rotation.x = PI / 2
	var beam := SpotLight3D.new()
	beam.light_color = Color(1.0, 0.95, 0.82)
	beam.light_energy = 18.0
	beam.spot_range = 28.0
	beam.spot_angle = 14.0
	beam.light_volumetric_fog_energy = 3.0
	beam.position = Vector3(0, 0, 1.0)
	beam.rotation = Vector3(-0.55, PI, 0)     # spotlights point down -Z: turn it to look out and down
	pivot.add_child(beam)
	pivot.beam = beam
	var start := randf() * TAU
	pivot.rotation.y = start
	var tw: Tween = level.create_tween().set_loops()
	tw.tween_property(pivot, "rotation:y", start + 1.6, randf_range(3.5, 5.0)).set_trans(Tween.TRANS_SINE)
	tw.tween_property(pivot, "rotation:y", start - 1.6, randf_range(3.5, 5.0)).set_trans(Tween.TRANS_SINE)


# --- prisoners -------------------------------------------------------------------------

static func _prisoner(level, at: Vector3) -> void:
	var p := CharacterBody3D.new()
	p.set_script(PrisonerScript)
	p.level = level
	p.position = at + Vector3(randf_range(-0.5, 0.5), 0.1, randf_range(-0.5, 0.5))
	level.add_child(p)


# --- arriving and leaving -----------------------------------------------------------

## Deeper floors: Victor arrives on a lift platform instead of the rig.
static func arrival_lift(level, at: Vector3) -> void:
	Look.box(level, Vector3(3.6, 0.12, 3.6), at + Vector3(0, 0.06, 0.6), Look.steel(Color("2b2e33")))
	Look.box(level, Vector3(3.7, 0.04, 0.2), at + Vector3(0, 0.13, 2.4), Look.hazard())
	var rail := Look.steel(Color("4a4f57"), 0.8)
	for sx: int in [-1, 1]:
		Look.box(level, Vector3(0.1, 1.1, 3.6), at + Vector3(1.8 * sx, 0.55, 0.6), rail)
		Look.box(level, Vector3(0.2, 6.0, 0.2), at + Vector3(1.8 * sx, 3.0, -1.2), Look.steel(Color("23262b")))
	Look.box(level, Vector3(3.8, 0.3, 0.3), at + Vector3(0, 6.0, -1.2), Look.steel(Color("23262b")))
	var o := OmniLight3D.new()
	o.light_color = Color(1.0, 0.6, 0.3)
	o.light_energy = 1.5
	o.omni_range = 5.0
	o.position = at + Vector3(0, 2.5, 0.6)
	level.add_child(o)
	level._glass_lights.append(o)


## At the lift: the player picks the next floor's theme (three choices),
## and each theme gives a bonus for the rest of the run.
static func choose_next_floor(level) -> void:
	var tree: SceneTree = level.get_tree()
	var options := THEMES.duplicate()
	options.erase(level.theme)
	options.shuffle()
	options.resize(3)
	var rewards := {}
	for t: String in options:
		var pool: Array = REWARDS[t].filter(func(id): return not Skills.gear.has(id))
		rewards[t] = pool[randi() % pool.size()] if pool.size() > 0 else REWARDS[t][0]
	var layer := CanvasLayer.new()
	layer.layer = 30
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	level.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(640, 0)
	box.position = Vector2(-320, -220)
	box.add_theme_constant_override("separation", 14)
	dim.add_child(box)
	var head := Label.new()
	head.text = "THE LIFT GOES DOWN.  WHERE TO?\nPress 1, 2 or 3, or click."
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", Color("ffd23f"))
	box.add_child(head)
	var go := func(t: String) -> void:
		if layer.has_meta("done"):
			return
		layer.set_meta("done", true)
		next_theme = t
		Skills.add_run_bonus(rewards[t])
		tree.paused = false
		level.depth += 1
		level.shake(0.3)
		level._say("GOING DOWN.\nFloor -%d: %s." % [level.depth, title(t)], Color("ff7a4a"), 2.0)
		layer.queue_free()
		tree.create_timer(1.4).timeout.connect(tree.reload_current_scene)
	for i in options.size():
		var t: String = options[i]
		var b := Button.new()
		var id: String = rewards[t]
		var desc: String = Equipment.GEAR[id]["desc"] if Equipment.is_gear(id) else ""
		b.text = "%d.  %s   >   %s%s" % [i + 1, title(t), Skills.reward_name(id), ("\n" + desc) if desc != "" else ""]
		b.add_theme_font_size_override("font_size", 20)
		b.custom_minimum_size = Vector2(640, 80)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.11, 0.14, 0.95)
		sb.border_color = Color(1.0, 0.48, 0.29)
		sb.set_border_width_all(2)
		sb.set_content_margin_all(10)
		b.add_theme_stylebox_override("normal", sb)
		var hov := sb.duplicate() as StyleBoxFlat
		hov.bg_color = Color(0.28, 0.12, 0.08, 0.95)
		b.add_theme_stylebox_override("hover", hov)
		b.add_theme_stylebox_override("focus", hov)
		b.pressed.connect(go.bind(t))
		box.add_child(b)
	var keys := PickKeys.new()
	keys.choose = func(i: int) -> void:
		if i < options.size():
			go.call(options[i])
	layer.add_child(keys)
	tree.paused = true


class PickKeys extends Node:
	var choose: Callable

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			var k: int = event.keycode
			if k >= KEY_1 and k <= KEY_3:
				choose.call(k - KEY_1)
