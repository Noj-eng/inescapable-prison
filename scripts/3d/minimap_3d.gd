extends CanvasLayer
## The prison map, with fog of war. Only what Victor has actually seen is
## drawn: walls he had a clear line of sight to, the rooms he walked through,
## the exit lift once he's spotted it, and contraband lying on the floor.
## Every floor starts dark again (the map is rebuilt with the floor).
##
##   Small map: top right corner, turned to match the isometric camera.
##   Big map:   press M or Tab (Esc or M/Tab again to close).
##
## The cellblock calls Minimap.make(level) once the floor is built.
## Numbers (how far he sees, zoom) are in tuning_3d.gd under "Map".

const Tune := preload("res://scripts/3d/tuning_3d.gd")
const PowerupScript := preload("res://scripts/3d/powerup_3d.gd")
const NeonBarScript := preload("res://scripts/neon_bar.gd")
const FX := preload("res://scripts/fx.gd")

const ROT := PI / 4.0       # the camera looks down the diagonal, so the map is a diamond
const STEEL := Color(0.62, 0.7, 0.82)
const AMBER := Color("ffd23f")
const LIFT_GREEN := Color(0.3, 1.0, 0.5)
const FOG := Color(0.035, 0.04, 0.055, 0.92)

const MINI_POS := Vector2(1078, 66)
const MINI_SIZE := Vector2(190, 190)

var level: Node             # the cellblock_3d level
var _img: Image
var _tex: ImageTexture
var _seen := PackedByteArray()   # 1 = Victor has seen this square
var _walkable := 0
var _seen_walkable := 0
var _cols := 0
var _rows := 0
var _lift_cell := Vector2i(-1, -1)
var _lift_seen := false
var _powerups: Array = []
var _scan_t := 0.0
var _reveal_t := 0.0
var _t := 0.0
var _dirty := false

var _mini: Control
var _big: Control
var _big_title: Label
var _big_info: Label
var _dash_bar: Control
var _paused_by_map := false


static func make(lvl: Node) -> CanvasLayer:
	var m := CanvasLayer.new()
	m.set_script(load("res://scripts/3d/minimap_3d.gd"))
	m.level = lvl
	lvl.add_child(m)
	return m


func _ready() -> void:
	layer = 4                                   # over the HUD, under the level-up, picker and scanlines
	process_mode = Node.PROCESS_MODE_ALWAYS     # so the big map can be closed while paused
	_rows = level.rows
	_cols = level.cols
	_img = Image.create(_cols, _rows, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0, 0, 0, 0))
	_tex = ImageTexture.create_from_image(_img)
	_seen.resize(_cols * _rows)
	for y in _rows:
		for x in _cols:
			var ch: String = level.map[y][x]
			if ch == "E":
				_lift_cell = Vector2i(x, y)
			if not _blocks_sight(ch):
				_walkable += 1

	_mini = Control.new()
	_mini.position = MINI_POS
	_mini.size = MINI_SIZE
	_mini.clip_contents = true
	_mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mini.draw.connect(_draw_mini)
	add_child(_mini)
	_label("MAP [M]", MINI_POS + Vector2(0, MINI_SIZE.y + 4), 10, Color(STEEL, 0.75))
	# the dash meter sits under the map: full = ready
	_label("DASH [SPACE]", MINI_POS + Vector2(0, MINI_SIZE.y + 22), 10, Color(STEEL, 0.75))
	_dash_bar = Control.new()
	_dash_bar.set_script(NeonBarScript)
	_dash_bar.position = MINI_POS + Vector2(0, MINI_SIZE.y + 38)
	_dash_bar.size = Vector2(MINI_SIZE.x, 9)
	_dash_bar.color = Color("ff9a3c")
	_dash_bar.segments = 10
	_dash_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dash_bar)

	_big = Control.new()
	_big.size = Vector2(1280, 720)
	_big.visible = false
	_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_big.draw.connect(_draw_big)
	add_child(_big)
	_big_title = _label("", Vector2(0, 26), 22, AMBER, _big)
	_big_title.size.x = 1280
	_big_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big_info = _label("", Vector2(0, 676), 12, Color(STEEL, 0.8), _big)
	_big_info.size.x = 1280
	_big_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reveal()


func _label(text: String, pos: Vector2, font_size: int, color: Color, parent: Node = null) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(MINI_SIZE.x, font_size + 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", FX.mono_font())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	(parent if parent else self).add_child(l)
	return l


# --- fog of war ----------------------------------------------------------------

static func _blocks_sight(ch: String) -> bool:
	return ch == "#" or ch == "H"      # solid wall, solitary door


## What colour a square is on the map once it's been seen.
func _colour(x: int, y: int) -> Color:
	var ch: String = level.map[y][x]
	match ch:
		"#":
			return Color(STEEL, 0.95) if level._touches_floor(x, y) else Color(0, 0, 0, 0)
		"B": return Color(0.3, 0.85, 1.0, 0.95)      # electrified glass
		"D": return Color(1.0, 0.55, 0.2, 0.95)      # vault door
		"H": return Color(0.85, 0.3, 0.28, 0.95)     # solitary door
		"E": return Color(LIFT_GREEN, 0.95)
		".", "p", "R", "G", "M", "T", "v":
			return Color(0.15, 0.17, 0.22, 0.94)     # open floor
	return Color(0.3, 0.33, 0.4, 0.94)               # furniture and props


## Marks everything Victor can see from where he stands.
func _reveal() -> void:
	var p: Node3D = level.player
	if not is_instance_valid(p):
		return
	var c := Vector2i(roundi(p.global_position.x / level.CELL), roundi(p.global_position.z / level.CELL))
	var r := Tune.MAP_SIGHT
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy > r * r:
				continue
			var x := c.x + dx
			var y := c.y + dy
			if x < 0 or y < 0 or x >= _cols or y >= _rows or _seen[y * _cols + x] == 1:
				continue
			if _clear_line(c, Vector2i(x, y)):
				_mark(x, y)


func _mark(x: int, y: int) -> void:
	_seen[y * _cols + x] = 1
	_img.set_pixel(x, y, _colour(x, y))
	if not _blocks_sight(level.map[y][x]):
		_seen_walkable += 1
	if Vector2i(x, y) == _lift_cell and not _lift_seen:
		_lift_seen = true
		if level.has_method("_say"):
			level._say("EXIT LIFT SPOTTED.\nIt's on your map.", LIFT_GREEN, 2.0)
	_dirty = true


## True when nothing solid stands between the two squares (the far square
## itself may be a wall: that's how walls get drawn).
func _clear_line(a: Vector2i, b: Vector2i) -> bool:
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var x := a.x
	var y := a.y
	while true:
		if x == b.x and y == b.y:
			return true
		if (x != a.x or y != a.y) and _blocks_sight(level.map[y][x]):
			return false
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	return true


func _process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(level) or not is_instance_valid(level.player):
		return
	if level.get("_game_over") and _big.visible:
		_toggle_big()
	if not get_tree().paused:
		_reveal_t -= delta
		if _reveal_t <= 0.0:
			_reveal_t = 0.1
			_reveal()
		_scan_t -= delta
		if _scan_t <= 0.0:
			_scan_t = 0.5
			_find_powerups()
	if _dirty:
		_dirty = false
		_tex.update(_img)
	var p = level.player
	if p.has_method("dash_ready"):
		_dash_bar.value = p.dash_ready()
	_mini.queue_redraw()
	if _big.visible:
		_big.queue_redraw()


## Contraband on the floor (some is dropped later by beaten guards).
func _find_powerups() -> void:
	_powerups.clear()
	for n in level.get_children():
		if n.get_script() == PowerupScript and not n.get("_taken"):
			_powerups.append(n)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: Key = event.keycode
	if k == KEY_M or k == KEY_TAB or (k == KEY_ESCAPE and _big.visible):
		_toggle_big()
		get_viewport().set_input_as_handled()


func _toggle_big() -> void:
	if not _big.visible:
		# don't open over the lift picker, a level-up or the game over screen
		if get_tree().paused or level.get("_game_over") or level.get("_descending"):
			return
		_big.visible = true
		_mini.visible = false
		if Tune.MAP_PAUSES:
			get_tree().paused = true
			_paused_by_map = true
	else:
		_big.visible = false
		_mini.visible = true
		if _paused_by_map:
			get_tree().paused = false
			_paused_by_map = false


# --- drawing ----------------------------------------------------------------------

func _cell_of(n: Node3D) -> Vector2:
	return Vector2(n.global_position.x, n.global_position.z) / level.CELL


## A map square (or point between squares) to a screen spot.
func _to_screen(cell: Vector2, centre_cell: Vector2, centre: Vector2, scale: float) -> Vector2:
	return centre + (cell - centre_cell).rotated(ROT) * scale


func _draw_map(c: Control, centre_cell: Vector2, centre: Vector2, scale: float) -> void:
	# the floor's whole footprint is fog: you can see how much is still unknown
	c.draw_set_transform(centre - centre_cell.rotated(ROT) * scale, ROT, Vector2(scale, scale))
	c.draw_rect(Rect2(Vector2(-0.5, -0.5), Vector2(_cols, _rows)), FOG)
	# faint survey grid across the fog, one line per room block
	for gx in range(0, _cols, 13):
		c.draw_line(Vector2(gx - 0.5, -0.5), Vector2(gx - 0.5, _rows - 0.5), Color(STEEL, 0.05), 1.0 / scale)
	for gy in range(0, _rows, 13):
		c.draw_line(Vector2(-0.5, gy - 0.5), Vector2(_cols - 0.5, gy - 0.5), Color(STEEL, 0.05), 1.0 / scale)
	c.draw_texture(_tex, Vector2(-0.5, -0.5))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# contraband he's seen, glowing in its own colour
	for pu in _powerups:
		if not is_instance_valid(pu) or pu.get("_taken"):
			continue
		var pc := _cell_of(pu)
		var gi := Vector2i(roundi(pc.x), roundi(pc.y))
		if gi.x < 0 or gi.y < 0 or gi.x >= _cols or gi.y >= _rows or _seen[gi.y * _cols + gi.x] == 0:
			continue
		var tint: Color = PowerupScript.TYPES[pu.kind]["tint"]
		var at := _to_screen(pc, centre_cell, centre, scale)
		c.draw_circle(at, maxf(2.0, scale * 0.6) + 1.5, Color(tint, 0.25))
		c.draw_circle(at, maxf(1.5, scale * 0.45), tint)
	# the exit lift: a pulsing green square once he's seen it
	if _lift_seen:
		var at := _to_screen(Vector2(_lift_cell), centre_cell, centre, scale)
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		var r := maxf(4.0, scale * 1.4)
		c.draw_rect(Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), Color(LIFT_GREEN, 0.15 + 0.2 * pulse))
		c.draw_rect(Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), LIFT_GREEN, false, 1.5)
		c.draw_rect(Rect2(at - Vector2(r, r) * (1.4 + pulse * 0.6), Vector2(r, r) * 2.0 * (1.4 + pulse * 0.6)), Color(LIFT_GREEN, 0.5 * (1.0 - pulse)), false, 1.0)
	# Victor: an amber arrow pointing the way he faces
	var p = level.player
	var vat := _to_screen(_cell_of(p), centre_cell, centre, scale)
	var f: Vector3 = p.facing
	var dir := Vector2(f.x, f.z).rotated(ROT).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	var side := Vector2(-dir.y, dir.x)
	var s := maxf(5.0, scale * 1.2)
	c.draw_circle(vat, s * 1.6, Color(AMBER, 0.12 + 0.08 * sin(_t * 6.0)))
	var tri := PackedVector2Array([vat + dir * s * 1.3, vat - dir * s * 0.8 + side * s * 0.8, vat - dir * s * 0.4, vat - dir * s * 0.8 - side * s * 0.8])
	c.draw_colored_polygon(tri, AMBER)
	c.draw_polyline(tri + PackedVector2Array([tri[0]]), Color(0, 0, 0, 0.8), 1.0)


func _draw_mini() -> void:
	var size := _mini.size
	_mini.draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.012, 0.018, 0.78))
	_draw_map(_mini, _cell_of(level.player), size * 0.5, Tune.MAP_ZOOM)
	_frame(_mini, Rect2(Vector2.ZERO, size), STEEL)
	# a slow radar sweep line for that security-monitor feel
	var sweep := fmod(_t * 0.35, 1.3) - 0.15
	_mini.draw_rect(Rect2(Vector2(0, size.y * sweep), Vector2(size.x, 2)), Color(STEEL, 0.07))


func _draw_big() -> void:
	_big.draw_rect(Rect2(Vector2.ZERO, _big.size), Color(0.01, 0.012, 0.02, 0.95))
	var span := (_cols + _rows) / sqrt(2.0)       # the diamond is this many squares across
	var scale := minf(1180.0 / span, 590.0 / span)
	var centre_cell := Vector2(_cols - 1, _rows - 1) * 0.5
	_draw_map(_big, centre_cell, Vector2(640, 364), scale)
	_frame(_big, Rect2(Vector2(40, 64), Vector2(1200, 600)), STEEL)
	_big_title.text = level._title()
	var pct := 100.0 * _seen_walkable / maxf(1.0, _walkable)
	var lift := "EXIT LIFT: FOUND" if _lift_seen else "EXIT LIFT: NOT FOUND YET"
	_big_info.text = "EXPLORED %d%%     %s     [M] CLOSE" % [roundi(pct), lift]


## Corner brackets, like the HUD meters.
func _frame(c: Control, r: Rect2, col: Color) -> void:
	var b := 10.0
	var a := r.position
	var z := r.end
	for corner in [a, Vector2(z.x, a.y), Vector2(a.x, z.y), z]:
		var dx := b if corner.x == a.x else -b
		var dy := b if corner.y == a.y else -b
		c.draw_line(corner, corner + Vector2(dx, 0), Color(col, 0.8), 1.5)
		c.draw_line(corner, corner + Vector2(0, dy), Color(col, 0.8), 1.5)
	c.draw_rect(r, Color(col, 0.15), false, 1.0)
