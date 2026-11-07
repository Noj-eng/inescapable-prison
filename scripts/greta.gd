extends StaticBody2D
## Nurse Greta. Thirty years on the night shift in the worst prison in the
## world. She doesn't care who you are or what you did; she's just doing her
## job. Walk up and press E and she patches you back to full health, once
## per visit.

signal patch_requested

const FX := preload("res://scripts/fx.gd")
const TALK_RANGE := 70.0
const PATCH_LINES := [
	"\"Sit. Don't bleed on my floor.\"",
	"\"I don't care what you did. Arm.\"",
	"\"Hold still. ...There. Next.\"",
	"\"You're the fourth super-villain this week. Hold still.\"",
	"\"Stitches. Don't pick at them. I won't do them twice.\"",
]
const DONE_LINES := [
	"\"One patch-up per visit. Rules are rules.\"",
	"\"You're fine. Go away.\"",
	"\"I'm on break.\"",
]

var player: Node2D
var near := false
var used := false
var _t := 0.0
var _e_was_down := false
var _gum := 0.0


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	add_child(shape)
	# the cold white light over the nurse's station
	var lamp := FX.make_light(Color(0.85, 1.0, 0.95), 0.8, 1.0)
	lamp.position = Vector2(0, -60)
	add_child(lamp)


func line() -> String:
	var pool: Array = DONE_LINES if used else PATCH_LINES
	return pool[randi() % pool.size()]


func _process(delta: float) -> void:
	_t += delta
	# every so often she blows a bubble of gum, out of sheer boredom
	_gum = maxf(0.0, sin(_t * 0.9) * 1.6 - 0.6)
	queue_redraw()
	if not is_instance_valid(player) or player.dead:
		return
	var d := player.global_position - global_position
	near = Vector2(d.x, d.y * 2.0).length() < TALK_RANGE
	var down := Input.is_key_pressed(KEY_E)
	if near and down and not _e_was_down:
		patch_requested.emit()
	_e_was_down = down


func _draw() -> void:
	FX.draw_character_shadow(self, 15.0, 40.0)
	var o := Vector2.ZERO
	var breathe := sin(_t * 1.5) * 0.6
	# sturdy legs, white clogs
	for side: int in [-1, 1]:
		draw_line(o + Vector2(5 * side, -14), o + Vector2(5 * side, -2), Color("6f8c94"), 5.0)
		draw_rect(Rect2(o + Vector2(5 * side - 3.5, -3), Vector2(7, 3.5)), Color("e8ecee"))
	# broad body in teal scrubs, cardigan over the top
	var body := Rect2(o + Vector2(-11, -38 + breathe), Vector2(22, 26 - breathe))
	draw_rect(body.grow(1), Color("2c4a50"))
	draw_rect(body, Color("5f9aa3"))
	draw_rect(Rect2(body.position, Vector2(5, body.size.y)), Color("8a7c99"))           # cardigan, left
	draw_rect(Rect2(body.position + Vector2(17, 0), Vector2(5, body.size.y)), Color("8a7c99"))  # cardigan, right
	draw_line(body.position + Vector2(8, 4), body.position + Vector2(14, 4), Color("2c4a50"), 1.0)  # v-neck
	# badge with a red cross and a pen in the pocket
	draw_rect(Rect2(body.position + Vector2(6, 10), Vector2(6, 7)), Color("e8ecee"))
	draw_line(body.position + Vector2(9, 11), body.position + Vector2(9, 16), Color("d33a3a"), 1.4)
	draw_line(body.position + Vector2(7, 13.5), body.position + Vector2(11, 13.5), Color("d33a3a"), 1.4)
	draw_line(body.position + Vector2(14, 9), body.position + Vector2(14, 14), Color("2a2a30"), 1.2)
	# arms: one holds a clipboard, one hangs with a roll of tape
	draw_line(body.position + Vector2(1, 3), o + Vector2(-14, -18), Color("8a7c99"), 5.0)
	draw_circle(o + Vector2(-14, -17), 2.6, Color("d8b49a"))
	draw_line(body.position + Vector2(21, 3), o + Vector2(10, -22), Color("8a7c99"), 5.0)
	draw_rect(Rect2(o + Vector2(4, -30), Vector2(11, 14)), Color("a0764a"))   # clipboard
	draw_rect(Rect2(o + Vector2(5.5, -28), Vector2(8, 11)), Color("f2f0e8"))
	for i in 3:
		draw_line(o + Vector2(7, -25 + i * 3), o + Vector2(12, -25 + i * 3), Color(0.4, 0.4, 0.45), 0.8)
	# head: tight grey bun, half-moon glasses, flat unimpressed mouth
	var head := o + Vector2(0, -46 + breathe)
	draw_circle(head, 7.5, Color("d8b49a"))
	draw_circle(head + Vector2(0, -6), 5.0, Color("9a9aa2"))   # bun
	draw_arc(head + Vector2(0, -1), 7.5, PI * 1.05, PI * 1.95, 12, Color("9a9aa2"), 3.0)
	draw_line(head + Vector2(-5, 0), head + Vector2(-1, 0), Color("2a2a30"), 1.2)
	draw_line(head + Vector2(1, 0), head + Vector2(5, 0), Color("2a2a30"), 1.2)
	draw_line(head + Vector2(-3, 4), head + Vector2(2, 4), Color("8a5a4a"), 1.2)
	# the nurse's cap, slightly crooked
	draw_rect(Rect2(head + Vector2(-5, -12), Vector2(9, 4)), Color("f2f4f5"))
	draw_line(head + Vector2(-1, -11.5), head + Vector2(-1, -8.5), Color("d33a3a"), 1.0)
	if _gum > 0.0:
		draw_circle(head + Vector2(3, 5), 1.5 + _gum * 2.5, Color(1.0, 0.6, 0.8, 0.85))

	if near:
		var p := Vector2(0, -80 - absf(sin(_t * 3.0)) * 3.0)
		var label := "[E] PATCHED" if used else "[E] PATCH UP"
		draw_rect(Rect2(p + Vector2(-44, -10), Vector2(88, 18)), Color(0.04, 0.05, 0.08, 0.85))
		draw_rect(Rect2(p + Vector2(-44, -10), Vector2(88, 18)), Color(0.6, 1.0, 0.85, 0.8), false, 1.0)
		draw_string(FX.mono_font(), p + Vector2(-38, 3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 1.0, 0.9))
