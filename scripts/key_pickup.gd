extends Node2D
## Captain Brask's master key card. Walk over it to pick it up; it opens the
## way down to Solitary Confinement.

signal picked_up

var player: Node2D
var _t := 0.0


func _ready() -> void:
	var light: PointLight2D = preload("res://scripts/fx.gd").make_light(Color(1.0, 0.82, 0.3), 0.7, 0.8)
	add_child(light)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if is_instance_valid(player) and not player.dead:
		var d := player.global_position - global_position
		if Vector2(d.x, d.y * 2.0).length() < 22.0:
			picked_up.emit()
			queue_free()


func _draw() -> void:
	var glow := 0.5 + 0.5 * sin(_t * 4.0)
	# glow pool on the floor
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 18.0, Color(1.0, 0.8, 0.3, 0.12 + 0.12 * glow))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var o := Vector2(0, -12 - glow * 3.0)
	# a heavy key card on a lanyard ring, slowly turning
	var w := 12.0 * absf(cos(_t * 1.6)) + 2.0
	var card := Rect2(o + Vector2(-w * 0.5, -8), Vector2(w, 16))
	draw_rect(card.grow(1.0), Color("15171d"))
	draw_rect(card, Color("c9a23a"))
	draw_rect(Rect2(card.position + Vector2(0, 3), Vector2(w, 3)), Color("2a2a30"))  # mag stripe
	if w > 7.0:
		draw_rect(Rect2(card.position + Vector2(w * 0.25, 9), Vector2(w * 0.5, 4)), Color("ff4d4d"))
	draw_arc(o + Vector2(0, -11), 3.0, 0.0, TAU, 12, Color("8a8f9a"), 1.5)
