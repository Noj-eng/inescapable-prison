extends RefCounted
## Themed floors in 3D: picks each floor's theme and builds its props.
## (Filled in by the themed-floors work; stub for now.)

const SOLID := ""   # extra map letters that block path finding


static func pick(_depth: int, _last: String) -> String:
	return ""


static func title(_theme: String) -> String:
	return "THE PRISON"


static func floor_mat(_level, m: StandardMaterial3D) -> StandardMaterial3D:
	return m


static func wall_mat(_level, m: StandardMaterial3D) -> StandardMaterial3D:
	return m


static func build(_level, _ch: String, _x: int, _y: int, _at: Vector3) -> void:
	pass


static func finish(_level) -> void:
	pass
