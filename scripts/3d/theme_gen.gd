extends RefCounted
## Theme dressing for prison_gen.gd. Each floor has ONE theme (Jon), and the
## theme decides what every room on that floor holds. New map letters:
##   s single bed   k bunk bed    n steel sink   l lockers     w weapon rack
##   f stove        S serving line (lunch counter)             L long lunch table
##   H solitary door (heavy, with a peephole)    D armory vault door (punch it open)
##   h weight bench W dumbbell rack  Y yard tower (placeholder)  p prisoner
## Everything here is just letters on the text map: themes_3d.gd builds the 3D.

## Letters nobody can walk through. D is missing on purpose: vault doors can be
## smashed, so the "is there a way through?" check treats them as open.
const SOLID := "sknlwfSLHhWY"

const Tune := preload("res://scripts/3d/tuning_3d.gd")
const THEMES := ["cellblock", "cafeteria", "armory", "solitary", "yard"]


## Dresses one room. Returns true when it did (false = use the old dressing).
static func dress_room(gen, theme: String, b: Vector2i, r: Rect2i, north_free: bool) -> bool:
	var roll: float = gen._rng.randf()
	var cells_fit: bool = north_free and r.size.x >= 9 and r.size.y >= 8 \
			and not gen._corridor_in(Rect2i(r.position.x - 1, r.position.y - 1, r.size.x + 2, 6))
	match theme:
		"cellblock":
			if roll < 0.45 and cells_fit:
				_cell_row(gen, r)
			elif roll < 0.8:
				_dormitory(gen, r)
			else:
				_common_room(gen, r)
		"cafeteria":
			if b.y == 0:
				_kitchen(gen, r)          # the top of the floor is the kitchen and lunch line
			else:
				_dining_hall(gen, r)
		"armory":
			if roll < 0.55:
				_weapon_store(gen, r)
			else:
				_locker_room(gen, r)
		"solitary":
			if roll < 0.75 and r.size.y >= 7:
				_solitary_row(gen, r)
			else:
				gen._dress_guard_post(r)
		"yard":
			_yard(gen, r)
		_:
			return false
	return true


## After every room is dressed: vault doors, prisoners.
static func finish(gen, theme: String, rooms: Dictionary, far: Vector2i) -> void:
	if theme == "armory":
		# the lift sits behind the vault, plus a couple of other sealed rooms
		_vault(gen, rooms[far])
		var keys := rooms.keys()
		for i in 2:
			var b: Vector2i = keys[gen._rng.randi() % keys.size()]
			if b != Vector2i(0, 0) and b != far:
				_vault(gen, rooms[b])
	# panicking prisoners: more where people gather
	var per_room := {"cellblock": 1.8, "cafeteria": 2.4, "armory": 0.5, "solitary": 0.6, "yard": 2.6}
	var n: float = per_room.get(theme, 1.0) * Tune.PRISONER_AMOUNT
	for b in rooms:
		var count := int(n) + (1 if gen._rng.randf() < n - int(n) else 0)
		if b == Vector2i(0, 0):
			count = mini(count, 1)
		for i in count:
			var spot := _loose_spot(gen, rooms[b])
			if spot.x >= 0:
				gen._put(spot, "p")


## Any open floor tile in the room (prisoners squeeze in between tables).
static func _loose_spot(gen, r: Rect2i) -> Vector2i:
	for attempt in 30:
		var p := Vector2i(gen._rng.randi_range(r.position.x, r.end.x - 1), gen._rng.randi_range(r.position.y, r.end.y - 1))
		if gen._tile(p) == ".":
			return p
	return Vector2i(-1, -1)


# --- cell block ---------------------------------------------------------------------

## Cells along the north wall behind electrified glass: a bed (bunk or
## single), a steel toilet and a sink in each. One glass front is blown out.
static func _cell_row(gen, r: Rect2i) -> void:
	var y0 := r.position.y
	var n := (r.size.x - 1) / 4
	var start := r.position.x + (r.size.x - (n * 4 + 1)) / 2
	for y in range(y0, y0 + 4):
		for x in range(r.position.x, r.end.x):
			gen._put(Vector2i(x, y), "#")
	var broken: int = gen._rng.randi() % n
	for i in n:
		var x := start + 1 + i * 4
		for k in 3:
			gen._put(Vector2i(x + k, y0), ".")
			gen._put(Vector2i(x + k, y0 + 1), ".")
			gen._put(Vector2i(x + k, y0 + 2), ".")
			gen._put(Vector2i(x + k, y0 + 3), "." if (i == broken and k == 1) else "B")
		gen._put(Vector2i(x, y0), "k" if gen._rng.randf() < 0.6 else "s")
		gen._put(Vector2i(x + 2, y0), "t")
		gen._put(Vector2i(x + 2, y0 + 1), "n")
	gen._scatter(Rect2i(r.position.x, y0 + 5, r.size.x, r.size.y - 5), "v", 1)


## An open dormitory: bunks and single beds in rows, head to the wall.
static func _dormitory(gen, r: Rect2i) -> void:
	for x in range(r.position.x, r.end.x, 2):
		gen._prop(Vector2i(x, r.position.y), "k" if gen._rng.randf() < 0.65 else "s")
	for y in range(r.position.y + 4, r.end.y - 1, 4):
		for x in range(r.position.x + 1, r.end.x - 1, 2):
			if gen._rng.randf() < 0.75:
				gen._prop(Vector2i(x, y), "k" if gen._rng.randf() < 0.5 else "s")
	gen._scatter(r, "t", gen._rng.randi_range(0, 1))


## The block's day room: steel tables, a toilet and sink in the corner.
static func _common_room(gen, r: Rect2i) -> void:
	gen._prop(Vector2i(r.position.x, r.position.y), "t")
	gen._prop(Vector2i(r.position.x + 1, r.position.y), "n")
	gen._scatter(r, "d", gen._rng.randi_range(2, 4))
	gen._scatter(r, "v", 1)


# --- cafeteria ----------------------------------------------------------------------

## Kitchen: stoves and prep tables along the back wall, the lunch line
## (a long serving counter) across the front with gaps to walk round.
static func _kitchen(gen, r: Rect2i) -> void:
	for x in range(r.position.x, r.end.x):
		gen._prop(Vector2i(x, r.position.y), "f" if (x - r.position.x) % 3 != 2 else "d")
	# the lunch line: the lowest row a corridor doesn't cross
	for ly in range(r.end.y - 2, r.position.y + 2, -1):
		var placed := 0
		for x in range(r.position.x + 2, r.end.x - 2):
			var p := Vector2i(x, ly)
			if gen._tile(p) == "." and not gen._corr.has(p) and not gen._corr.has(p + Vector2i(0, 1)) and not gen._corr.has(p - Vector2i(0, 1)):
				gen._put(p, "S")
				placed += 1
		if placed >= 3:
			break
	gen._scatter(r, "x", 1)


## Rows of long lunch tables with benches, aisles between them.
static func _dining_hall(gen, r: Rect2i) -> void:
	for y in range(r.position.y + 1, r.end.y - 1, 4):
		var x := r.position.x + 1
		while x < r.end.x - 1:
			var length: int = gen._rng.randi_range(3, 4)
			for k in length:
				if x + k < r.end.x - 1:
					gen._prop(Vector2i(x + k, y), "L")
			x += length + 1
	gen._scatter(r, "v", 1)


# --- armory -------------------------------------------------------------------------

static func _weapon_store(gen, r: Rect2i) -> void:
	for x in range(r.position.x, r.end.x):
		if gen._rng.randf() < 0.8:
			gen._prop(Vector2i(x, r.position.y), "w")
	for y in range(r.position.y + 4, r.end.y - 1, 4):
		for x in range(r.position.x + 2, r.end.x - 2):
			if (x - r.position.x) % 4 != 1:
				gen._prop(Vector2i(x, y), "w")
	gen._scatter(r, "x", gen._rng.randi_range(1, 3))


static func _locker_room(gen, r: Rect2i) -> void:
	for x in range(r.position.x, r.end.x):
		gen._prop(Vector2i(x, r.position.y), "l")
	for y in range(r.position.y, r.end.y):
		if gen._rng.randf() < 0.6:
			gen._prop(Vector2i(r.position.x, y), "l")
	gen._scatter(r, "c", 1)
	gen._scatter(r, "d", 1)
	if gen._rng.randf() < gen.turret_chance:
		gen._scatter(r, "T", 1)


## Seals a room: every way in gets a heavy vault door (the floor tiles in
## the ring just outside the room). Victor punches them open.
static func _vault(gen, r: Rect2i) -> void:
	var ring := Rect2i(r.position.x - 1, r.position.y - 1, r.size.x + 2, r.size.y + 2)
	for y in range(ring.position.y, ring.end.y):
		for x in range(ring.position.x, ring.end.x):
			var on_edge := x == ring.position.x or x == ring.end.x - 1 or y == ring.position.y or y == ring.end.y - 1
			if on_edge and gen._tile(Vector2i(x, y)) == ".":
				gen._put(Vector2i(x, y), "D")


# --- solitary -----------------------------------------------------------------------

## A row of tiny 1-wide cells along the north wall, each behind a heavy
## steel door with a small peephole: a bed and a toilet inside.
static func _solitary_row(gen, r: Rect2i) -> void:
	# columns a corridor runs through stay open; the rest become wall and cells
	var y0 := r.position.y
	var free := {}
	for x in range(r.position.x, r.end.x):
		var ok := true
		for y in range(y0 - 1, y0 + 3):
			for dx in [-1, 0, 1]:
				if gen._corr.has(Vector2i(x + dx, y)):
					ok = false
		free[x] = ok
	for x in range(r.position.x, r.end.x):
		if not free[x]:
			continue
		var cell: bool = (x - r.position.x) % 2 == 1 and free.get(x - 1, false) and free.get(x + 1, false)
		for y in range(y0, y0 + 3):
			gen._put(Vector2i(x, y), "#")
		if cell:
			gen._put(Vector2i(x, y0), "s")
			gen._put(Vector2i(x, y0 + 1), ".")
			gen._put(Vector2i(x, y0 + 2), "H")
	gen._scatter(Rect2i(r.position.x, y0 + 4, r.size.x, r.size.y - 4), "v", 1)
	if gen._rng.randf() < 0.5:
		gen._scatter(Rect2i(r.position.x, y0 + 4, r.size.x, r.size.y - 4), "c", 1)


# --- yard ---------------------------------------------------------------------------

static func _yard(gen, r: Rect2i) -> void:
	var roll: float = gen._rng.randf()
	if roll < 0.5:
		# the weight pit
		for i in gen._rng.randi_range(3, 5):
			gen._scatter(r, "h", 1)
		gen._prop(Vector2i(r.position.x + 1, r.position.y), "W")
		gen._prop(Vector2i(r.position.x + 2, r.position.y), "W")
	elif roll < 0.8:
		# picnic tables
		for i in gen._rng.randi_range(2, 4):
			var p: Vector2i = gen._free_spot(r)
			if p.x >= 0:
				gen._prop(p, "L")
				gen._prop(p + Vector2i(1, 0), "L")
	# a guard tower in a corner (placeholder: searchlight only, no sniper yet)
	if gen._rng.randf() < 0.45:
		var corners := [r.position, Vector2i(r.end.x - 1, r.position.y), Vector2i(r.position.x, r.end.y - 1), r.end - Vector2i.ONE]
		gen._prop(corners[gen._rng.randi() % 4], "Y")
