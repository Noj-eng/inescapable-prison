extends CanvasLayer
## The level-up screen: the game pauses and you pick one of three upgrades
## with 1, 2 or 3 (or a click).

signal chosen(id: String)

const FX := preload("res://scripts/fx.gd")
const NEON := Color("4ff0ff")

var _choices: Array = []
var _cards: Array[Control] = []
var _root: Control


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.size = Vector2(1280, 720)
	add_child(_root)
	visible = false


## abilities: the full table from the villain; ranks: what they already have.
func open(choices: Array, abilities: Dictionary, ranks: Dictionary, new_level: int) -> void:
	_choices = choices
	for c in _root.get_children():
		c.queue_free()
	_cards.clear()

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.03, 0.72)
	dim.size = Vector2(1280, 720)
	_root.add_child(dim)
	_text("LEVEL UP  //  LV %d" % new_level, Vector2(0, 150), Vector2(1280, 50), 34, NEON, true)
	_text("CHOOSE AN UPGRADE   [1] [2] [3]", Vector2(0, 200), Vector2(1280, 30), 15, Color(0.7, 0.78, 0.9), true)

	var w := 300.0
	var gap := 30.0
	var x0 := (1280.0 - (w * choices.size() + gap * (choices.size() - 1))) * 0.5
	for i in choices.size():
		var id: String = choices[i]
		var card := Button.new()
		card.flat = true
		card.position = Vector2(x0 + i * (w + gap), 260)
		card.size = Vector2(w, 220)
		card.focus_mode = Control.FOCUS_NONE
		card.pressed.connect(_pick.bind(i))
		card.draw.connect(_draw_card.bind(card))
		_root.add_child(card)
		_cards.append(card)
		var rank: int = ranks.get(id, 0)
		_text("[%d]" % (i + 1), Vector2(18, 16), Vector2(60, 24), 14, Color(0.7, 0.78, 0.9), false, card)
		_text(abilities[id]["name"], Vector2(18, 52), Vector2(w - 36, 30), 20, Color.WHITE, false, card)
		_text("RANK %d > %d" % [rank, rank + 1] if rank > 0 else "NEW", Vector2(18, 84), Vector2(w - 36, 20), 13, NEON, false, card)
		_text(abilities[id]["text"], Vector2(18, 118), Vector2(w - 36, 90), 15, Color(0.82, 0.86, 0.94), false, card, true)
	visible = true
	get_tree().paused = true


func _draw_card(card: Control) -> void:
	var r := Rect2(Vector2.ZERO, card.size)
	var hot := card.get_global_rect().has_point(card.get_global_mouse_position())
	card.draw_rect(r, Color(0.04, 0.07, 0.1, 0.92))
	card.draw_rect(r, Color(NEON, 0.9 if hot else 0.45), false, 2.0 if hot else 1.0)
	card.draw_rect(r.grow(3), Color(NEON, 0.15), false, 3.0)
	for i in 8:  # little tick marks along the top like a monitor readout
		card.draw_line(Vector2(r.size.x - 20 - i * 7, 8), Vector2(r.size.x - 20 - i * 7, 14), Color(NEON, 0.5), 1.0)


func _process(_delta: float) -> void:
	if not visible:
		return
	for c in _cards:
		c.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed:
		return
	var idx := -1
	match event.keycode:
		KEY_1, KEY_KP_1: idx = 0
		KEY_2, KEY_KP_2: idx = 1
		KEY_3, KEY_KP_3: idx = 2
	if idx >= 0 and idx < _choices.size():
		_pick(idx)


func _pick(i: int) -> void:
	visible = false
	get_tree().paused = false
	chosen.emit(_choices[i])


func _text(t: String, pos: Vector2, box: Vector2, font_size: int, color: Color, centered := false, parent: Control = null, wrap := false) -> Label:
	var l := Label.new()
	# Wrapping has to be on before the text goes in, or the label stretches
	# to fit one long line and runs off the card.
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(box.x, 0)
	else:
		l.clip_text = true
	l.text = t
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FX.mono_font())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	(parent if parent else _root).add_child(l)
	l.size = box
	return l
