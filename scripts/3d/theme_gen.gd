extends RefCounted
## Theme dressing for prison_gen.gd: what each room of a themed floor holds.
## (Filled in by the themed-floors work; stub for now.)

const SOLID := ""   # extra map letters that block walking


static func dress_room(_gen, _theme: String, _b: Vector2i, _r: Rect2i, _north_free: bool) -> bool:
	return false     # false = use the old mixed room dressing


static func finish(_gen, _theme: String, _rooms: Dictionary, _far: Vector2i) -> void:
	pass
