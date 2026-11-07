extends StaticBody2D
## Turkey: a scrawny old lifer who has been in solitary so long he runs a
## business out of his cell. Walk up and press E to see his stash.
## Nobody remembers his real name. Nobody asks.

signal trade_requested

const FX := preload("res://scripts/fx.gd")
const TALK_RANGE := 70.0
const GREETINGS := [
	"\"Psst. Big fella. You got smokes? I got merchandise.\"",
	"\"Name's Turkey. Don't ask why. Nobody likes the answer.\"",
	"\"Quake knocked my door clean off. Best day of business in years.\"",
	"\"Everything's genuine. Mostly. Some of it.\"",
]

var player: Node2D
var near := false
var _t := 0.0
var _bob := 0.0
var _e_was_down := false


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	add_child(shape)
	# a bare bulb over his little shop, warm against the cold steel
	var bulb := FX.make_light(Color(1.0, 0.75, 0.45), 0.9, 0.9)
	bulb.position = Vector2(0, -60)
	add_child(bulb)


func greeting() -> String:
	return GREETINGS[randi() % GREETINGS.size()]


func _process(delta: float) -> void:
	_t += delta
	_bob = sin(_t * 2.2)
	queue_redraw()
	if not is_instance_valid(player) or player.dead:
		return
	var d := player.global_position - global_position
	near = Vector2(d.x, d.y * 2.0).length() < TALK_RANGE
	var down := Input.is_key_pressed(KEY_E)
	if near and down and not _e_was_down:
		trade_requested.emit()
	_e_was_down = down


func _draw() -> void:
	FX.draw_character_shadow(self, 16.0, 30.0)
	# his wares, laid out on a grey blanket
	var blanket := PackedVector2Array([Vector2(-30, 6), Vector2(-4, -6), Vector2(22, 6), Vector2(-4, 18)])
	draw_colored_polygon(blanket, Color("3a3d45"))
	draw_polyline(PackedVector2Array([blanket[0], blanket[1], blanket[2], blanket[3], blanket[0]]), Color("50545e"), 1.0)
	draw_rect(Rect2(-22, 2, 5, 7), Color("c8402e"))          # smokes
	draw_rect(Rect2(-12, 7, 7, 3), Color("b9c2cf"))          # spoon
	draw_circle(Vector2(4, 10), 2.5, Color("e8e1cf"))         # soap dice
	draw_rect(Rect2(8, 2, 6, 5), Color("d9b46a"))            # photo
	draw_rect(Rect2(-6, -1, 4, 7), Color("8a3b2a"))          # hot sauce

	# Turkey himself, sitting cross-legged behind the blanket
	var o := Vector2(10, -2)
	var sway := _bob * 1.2
	# crossed legs
	draw_line(o + Vector2(-9, 0), o + Vector2(8, -2), Color("9b5a26"), 6.0)
	draw_line(o + Vector2(-7, -3), o + Vector2(9, 1), Color("b5692c"), 5.0)
	# skinny torso in a faded, patched jumpsuit
	var hip := o + Vector2(0, -6)
	var neck := o + Vector2(sway, -26)
	draw_line(hip, neck, Color("9b5a26"), 10.0)
	draw_line(hip + Vector2(-1, 0), neck + Vector2(-1, 0), Color("c47a3a"), 7.0)
	draw_rect(Rect2(hip + Vector2(-4, -10), Vector2(5, 4)), Color("7d8a6a"))  # patch
	# long arms: one resting, one beckoning
	draw_line(neck + Vector2(-4, 3), o + Vector2(-8, -6), Color("c47a3a"), 3.0)
	var wave := sin(_t * 5.0) * 3.0 if near else 0.0
	var hand := neck + Vector2(10, -2 + wave)
	draw_line(neck + Vector2(4, 3), neck + Vector2(8, 8), Color("c47a3a"), 3.0)
	draw_line(neck + Vector2(8, 8), hand, Color("c47a3a"), 3.0)
	draw_circle(hand, 2.0, Color("c9a58a"))
	# the long, wobbly neck that earned the name, with a saggy wattle
	var head := neck + Vector2(3 + sway, -11)
	draw_line(neck, head + Vector2(0, 3), Color("c9a58a"), 4.0)
	draw_circle(head + Vector2(1.5, 5), 2.5, Color("d98b78"))
	# bald head, liver spots, tiny round glasses, toothy grin
	draw_circle(head, 6.5, Color("c9a58a"))
	draw_circle(head + Vector2(-3, -3), 1.0, Color("a5806a"))
	draw_circle(head + Vector2(2.5, -1), 1.7, Color(0.9, 0.95, 1.0, 0.7))
	draw_arc(head + Vector2(2.5, -1), 1.9, 0, TAU, 10, Color("2a2a2a"), 0.8)
	draw_line(head + Vector2(0.5, 3), head + Vector2(4.5, 2.5), Color("3a2220"), 1.2)
	draw_rect(Rect2(head + Vector2(2, 2.3), Vector2(1.2, 1.2)), Color("e6d48a"))  # gold tooth
	# a beanie knitted from unravelled socks
	draw_arc(head + Vector2(0, -1), 6.5, PI, TAU, 12, Color("4a6a7a"), 4.0)

	if near:
		# floating prompt
		var p := Vector2(-4, -70 - absf(sin(_t * 3.0)) * 3.0)
		draw_rect(Rect2(p + Vector2(-34, -10), Vector2(68, 18)), Color(0.04, 0.05, 0.08, 0.85))
		draw_rect(Rect2(p + Vector2(-34, -10), Vector2(68, 18)), Color(1.0, 0.78, 0.3, 0.8), false, 1.0)
		draw_string(FX.mono_font(), p + Vector2(-28, 3), "[E] TRADE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.5))
