extends RefCounted
## Builds a random, winding prison floor as a text map (same letters the 3D
## level builder reads):
##   # wall  . floor  b bunk  t toilet  B electrified glass cell front
##   R Victor's broken rig (start)  E lift (exit)  G guard  M robot
##   o pillar  v steam grate  x crate  d table  c console
##
## How it works: the floor is split into a grid of blocks. A random maze is
## dug through the blocks (that is what makes it winding), with a few extra
## shortcuts. Every block becomes a room (a cell block, an open hall, a guard
## post or a storeroom), and the maze links become 3-wide corridors.
## Victor starts in the first room; the lift is in the room furthest away.

const BLOCK_W := 13      # map tiles per block, across
const BLOCK_H := 11      # ...and down

var _rng := RandomNumberGenerator.new()
var _g: Array = []       # rows of single-letter strings
var _w := 0
var _h := 0


## blocks_x, blocks_y: size in blocks. winding: 0 = lots of shortcuts,
## 1 = a pure maze with one route. density: enemies per room, on average.
## robot_share: 0..1 of enemies that are robots.
func generate(seed_value: int, blocks_x: int, blocks_y: int, winding: float, density: float, robot_share: float) -> Array:
	_rng.seed = seed_value
	_w = blocks_x * BLOCK_W + 1
	_h = blocks_y * BLOCK_H + 1
	_g = []
	for y in _h:
		var row := []
		row.resize(_w)
		row.fill("#")
		_g.append(row)

	# 1. a maze through the blocks (randomised depth-first search)
	var links := {}                        # "ax,ay|bx,by" -> true
	var seen := {}
	var stack: Array[Vector2i] = [Vector2i(0, 0)]
	seen[Vector2i(0, 0)] = true
	while stack.size() > 0:
		var cur: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if n.x >= 0 and n.y >= 0 and n.x < blocks_x and n.y < blocks_y and not seen.has(n):
				options.append(n)
		if options.is_empty():
			stack.pop_back()
			continue
		var nxt: Vector2i = options[_rng.randi() % options.size()]
		seen[nxt] = true
		links[_key(cur, nxt)] = true
		stack.append(nxt)
	# a few shortcuts so it isn't one single path (fewer when more winding)
	for by in blocks_y:
		for bx in blocks_x:
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var a := Vector2i(bx, by)
				var b: Vector2i = a + d
				if b.x < blocks_x and b.y < blocks_y and _rng.randf() > 0.35 + 0.6 * winding:
					links[_key(a, b)] = true

	# 2. how far each block is from the start, to place the lift
	var dist := {Vector2i(0, 0): 0}
	var queue: Array[Vector2i] = [Vector2i(0, 0)]
	var far := Vector2i(0, 0)
	while queue.size() > 0:
		var c: Vector2i = queue.pop_front()
		if dist[c] > dist[far]:
			far = c
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if links.has(_key(c, n)) and not dist.has(n):
				dist[n] = dist[c] + 1
				queue.append(n)

	# 3. rooms
	var rooms := {}                        # block -> Rect2i (inside, floor)
	for by in blocks_y:
		for bx in blocks_x:
			var b := Vector2i(bx, by)
			var rw := _rng.randi_range(7, BLOCK_W - 3)
			var rh := _rng.randi_range(6, BLOCK_H - 3)
			var rx := bx * BLOCK_W + 2 + _rng.randi_range(0, BLOCK_W - 3 - rw)
			var ry := by * BLOCK_H + 2 + _rng.randi_range(0, BLOCK_H - 3 - rh)
			rooms[b] = Rect2i(rx, ry, rw, rh)
			_carve(rooms[b])

	# 4. corridors between linked rooms: 3 wide, with a bend
	for k in links:
		var parts: PackedStringArray = (k as String).split("|")
		var a := _unkey(parts[0])
		var b := _unkey(parts[1])
		var ca := _centre(rooms[a])
		var cb := _centre(rooms[b])
		if _rng.randf() < 0.5:
			_corridor(ca, Vector2i(cb.x, ca.y))
			_corridor(Vector2i(cb.x, ca.y), cb)
		else:
			_corridor(ca, Vector2i(ca.x, cb.y))
			_corridor(Vector2i(ca.x, cb.y), cb)

	# 5. dress each room by type, then start, lift and enemies
	for b in rooms:
		var r: Rect2i = rooms[b]
		var north_free := not links.has(_key(b, b + Vector2i(0, -1)))
		if b == Vector2i(0, 0):
			_dress_hall(r)
			_clear_around(_centre(r) + Vector2i(-1, -1))
			_put(_centre(r) + Vector2i(-1, -1), "R")
			continue
		if b == far:
			_dress_hall(r)
			_clear_around(_centre(r))
			_put(_centre(r), "E")
			continue
		var roll := _rng.randf()
		if roll < 0.35 and north_free and r.size.x >= 9 and r.size.y >= 8:
			_dress_cells(r)
		elif roll < 0.6:
			_dress_hall(r)
		elif roll < 0.8:
			_dress_guard_post(r)
		else:
			_dress_storage(r)
	for b in rooms:
		if b == Vector2i(0, 0):
			continue
		var r: Rect2i = rooms[b]
		var count := int(density) + (1 if _rng.randf() < density - int(density) else 0)
		for i in count:
			var spot := _free_spot(r)
			if spot.x >= 0:
				_put(spot, "M" if _rng.randf() < robot_share else "G")

	var out := []
	for row in _g:
		out.append("".join(row))
	return out


# --- room dressing ----------------------------------------------------------------

## A row of cells along the room's north wall, each with a bunk and a toilet
## behind electrified glass. One cell's glass is already blown out.
func _dress_cells(r: Rect2i) -> void:
	var y0 := r.position.y
	var n := (r.size.x - 1) / 4
	var start := r.position.x + (r.size.x - (n * 4 + 1)) / 2
	for y in range(y0, y0 + 4):
		for x in range(r.position.x, r.end.x):
			_put(Vector2i(x, y), "#")
	var broken := _rng.randi() % n
	for i in n:
		var x := start + 1 + i * 4
		for k in 3:
			_put(Vector2i(x + k, y0), ".")
			_put(Vector2i(x + k, y0 + 1), ".")
			_put(Vector2i(x + k, y0 + 2), ".")
			_put(Vector2i(x + k, y0 + 3), "." if (i == broken and k == 1) else "B")
		_put(Vector2i(x, y0), "b")
		_put(Vector2i(x, y0 + 2), "t")
	_scatter(Rect2i(r.position.x, y0 + 5, r.size.x, r.size.y - 5), "v", 1)


func _dress_hall(r: Rect2i) -> void:
	# pillars in a loose grid, a steam grate or two
	for y in range(r.position.y + 2, r.end.y - 1, 4):
		for x in range(r.position.x + 2, r.end.x - 1, 5):
			if _rng.randf() < 0.7:
				_put(Vector2i(x, y), "o")
	_scatter(r, "v", 2)
	_scatter(r, "x", _rng.randi_range(0, 2))


func _dress_guard_post(r: Rect2i) -> void:
	var y := r.position.y
	for x in range(r.position.x + 1, mini(r.end.x - 1, r.position.x + 6)):
		if _rng.randf() < 0.7:
			_put(Vector2i(x, y), "c")
	_scatter(r, "d", 2)
	_scatter(r, "v", 1)


func _dress_storage(r: Rect2i) -> void:
	for i in _rng.randi_range(3, 6):
		var p := Vector2i(_rng.randi_range(r.position.x + 1, r.end.x - 3), _rng.randi_range(r.position.y + 1, r.end.y - 3))
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			if _rng.randf() < 0.8 and _tile(p + d) == ".":
				_put(p + d, "x")


# --- helpers --------------------------------------------------------------------

func _scatter(r: Rect2i, ch: String, count: int) -> void:
	for i in count:
		var p := _free_spot(r)
		if p.x >= 0:
			_put(p, ch)


func _free_spot(r: Rect2i) -> Vector2i:
	# a floor tile with open floor all round, so nothing blocks a doorway
	for attempt in 30:
		var p := Vector2i(_rng.randi_range(r.position.x + 1, r.end.x - 2), _rng.randi_range(r.position.y + 1, r.end.y - 2))
		var ok := true
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if _tile(p + Vector2i(dx, dy)) != ".":
					ok = false
		if ok:
			return p
	return Vector2i(-1, -1)


func _clear_around(p: Vector2i) -> void:
	for dy in [-1, 0, 1, 2]:
		for dx in [-1, 0, 1]:
			_put(p + Vector2i(dx, dy), ".")


func _carve(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_put(Vector2i(x, y), ".")


func _corridor(a: Vector2i, b: Vector2i) -> void:
	var lo := Vector2i(mini(a.x, b.x) - 1, mini(a.y, b.y) - 1)
	var hi := Vector2i(maxi(a.x, b.x) + 1, maxi(a.y, b.y) + 1)
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			if x > 0 and y > 0 and x < _w - 1 and y < _h - 1 and _tile(Vector2i(x, y)) == "#":
				_put(Vector2i(x, y), ".")


func _centre(r: Rect2i) -> Vector2i:
	return r.position + r.size / 2


func _tile(p: Vector2i) -> String:
	if p.x < 0 or p.y < 0 or p.x >= _w or p.y >= _h:
		return "#"
	return _g[p.y][p.x]


func _put(p: Vector2i, ch: String) -> void:
	if p.x > 0 and p.y > 0 and p.x < _w - 1 and p.y < _h - 1:
		_g[p.y][p.x] = ch


func _key(a: Vector2i, b: Vector2i) -> String:
	if a.x > b.x or (a.x == b.x and a.y > b.y):
		var t := a
		a = b
		b = t
	return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]


func _unkey(s: String) -> Vector2i:
	var p := s.split(",")
	return Vector2i(int(p[0]), int(p[1]))
