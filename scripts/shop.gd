extends CanvasLayer
## Turkey's stash: the game pauses and you can trade smokes for relics and
## powers. Keys 1/2/3 (or click) buy, R restocks, E or Esc leaves.

signal bought(kind: String, id: String)
signal restocked
signal closed

const FX := preload("res://scripts/fx.gd")
const AMBER := Color("ffc24a")
const POWER_COST := 15
const RESTOCK_COST := 5

var player: Node
var stock: Array = []           # [{kind, id, name, text, cost, sold}]
var _root: Control
var _cards: Array[Control] = []
var _quote := ""
var _note := ""


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.size = Vector2(1280, 720)
	add_child(_root)
	visible = false


## Fill the shelves: two relics he doesn't own yet and one power.
func roll_stock() -> void:
	stock.clear()
	var pool: Array = []
	for id in player.RELICS:
		var needs: String = player.RELICS[id].get("requires", "")
		if not player.has_relic(id) and (needs == "" or player.has_relic(needs)):
			pool.append(id)
	pool.shuffle()
	for id in pool.slice(0, 2):
		var r: Dictionary = player.RELICS[id]
		stock.append({"kind": "relic", "id": id, "name": r["name"], "text": r["text"], "cost": _price(r["cost"]), "sold": false})
	var powers: Array = player.roll_choices()
	if powers.size() > 0:
		var id: String = powers[0]
		var a: Dictionary = player.ABILITIES[id]
		var rank: int = player.rank(id)
		stock.append({"kind": "power", "id": id, "name": a["name"], "text": a["text"], "cost": _price(POWER_COST + 5 * rank), "sold": false,
			"rank": rank})


## The Law Degree knows its rights: 30% off.
func _price(base: int) -> int:
	return maxi(1, roundi(base * (0.7 if player.has_relic("law_degree") else 1.0)))


func open(quote: String) -> void:
	_quote = quote
	_note = ""
	if stock.is_empty():
		roll_stock()
	_rebuild()
	visible = true
	get_tree().paused = true


func _rebuild() -> void:
	for c in _root.get_children():
		c.queue_free()
	_cards.clear()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.0, 0.78)
	dim.size = Vector2(1280, 720)
	_root.add_child(dim)
	_text("TURKEY'S STASH", Vector2(0, 110), Vector2(1280, 50), 34, AMBER, true)
	_text(_quote, Vector2(0, 160), Vector2(1280, 30), 15, Color(0.85, 0.8, 0.7), true)
	_text("SMOKES  x %d" % player.smokes, Vector2(0, 196), Vector2(1280, 24), 16, Color("ff8a5a"), true)

	var w := 300.0
	var gap := 30.0
	var x0 := (1280.0 - (w * stock.size() + gap * (stock.size() - 1))) * 0.5
	for i in stock.size():
		var item: Dictionary = stock[i]
		var card := Button.new()
		card.flat = true
		card.position = Vector2(x0 + i * (w + gap), 240)
		card.size = Vector2(w, 250)
		card.focus_mode = Control.FOCUS_NONE
		card.pressed.connect(_buy.bind(i))
		card.draw.connect(_draw_card.bind(card, item))
		_root.add_child(card)
		_cards.append(card)
		var kind_text := "RELIC" if item["kind"] == "relic" else ("POWER  RANK %d > %d" % [item["rank"], item["rank"] + 1] if item["rank"] > 0 else "POWER  NEW")
		_text("[%d]" % (i + 1), Vector2(18, 16), Vector2(60, 24), 14, Color(0.8, 0.75, 0.65), false, card)
		_text(kind_text, Vector2(70, 16), Vector2(w - 88, 24), 12, Color("4ff0ff") if item["kind"] == "power" else AMBER, false, card)
		_text(item["name"], Vector2(18, 52), Vector2(w - 36, 30), 19, Color.WHITE, false, card)
		_text(item["text"], Vector2(18, 92), Vector2(w - 36, 100), 14, Color(0.86, 0.84, 0.8), false, card, true)
		var price := "SOLD" if item["sold"] else "%d SMOKES" % item["cost"]
		var afford: bool = player.smokes >= item["cost"]
		_text(price, Vector2(18, 210), Vector2(w - 36, 24), 16, Color(0.5, 0.5, 0.5) if item["sold"] else (Color("ff8a5a") if afford else Color(0.6, 0.3, 0.25)), false, card)
	_text("[1] [2] [3] BUY     [R] RESTOCK FOR %d SMOKES     [E] LEAVE" % RESTOCK_COST, Vector2(0, 520), Vector2(1280, 24), 14, Color(0.75, 0.72, 0.65), true)
	if _note != "":
		_text(_note, Vector2(0, 556), Vector2(1280, 24), 15, AMBER, true)


func _draw_card(card: Control, item: Dictionary) -> void:
	var r := Rect2(Vector2.ZERO, card.size)
	var hot: bool = card.get_global_rect().has_point(card.get_global_mouse_position()) and not item["sold"]
	var edge := Color("4ff0ff") if item["kind"] == "power" else AMBER
	card.draw_rect(r, Color(0.08, 0.06, 0.04, 0.94))
	card.draw_rect(r, Color(edge, 0.9 if hot else (0.2 if item["sold"] else 0.45)), false, 2.0 if hot else 1.0)
	card.draw_rect(r.grow(3), Color(edge, 0.12), false, 3.0)
	# a strip of tape holding the card up, like a note stuck to a cell wall
	card.draw_rect(Rect2(r.size.x * 0.5 - 24, -6, 48, 12), Color(0.85, 0.8, 0.6, 0.55))


func _process(_delta: float) -> void:
	if not visible:
		return
	for c in _cards:
		c.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1, KEY_KP_1: _buy(0)
		KEY_2, KEY_KP_2: _buy(1)
		KEY_3, KEY_KP_3: _buy(2)
		KEY_R: _restock()
		KEY_E, KEY_ESCAPE: close()
	get_viewport().set_input_as_handled()


func _buy(i: int) -> void:
	if i >= stock.size():
		return
	var item: Dictionary = stock[i]
	if item["sold"]:
		_note = "\"Already sold that one, pal.\""
	elif player.smokes < item["cost"]:
		_note = "\"No smokes, no deal. Go knock out a guard or two.\""
	else:
		player.add_smokes(-item["cost"])
		item["sold"] = true
		_note = "\"Pleasure doing business.\""
		bought.emit(item["kind"], item["id"])
	_rebuild()


func _restock() -> void:
	if player.smokes < RESTOCK_COST:
		_note = "\"Restocking ain't free, pal.\""
	else:
		player.add_smokes(-RESTOCK_COST)
		roll_stock()
		_note = "\"Let me check under the mattress...\""
		restocked.emit()
	_rebuild()


func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()


func _text(t: String, pos: Vector2, box: Vector2, font_size: int, color: Color, centered := false, parent: Control = null, wrap_lines := false) -> Label:
	var l := Label.new()
	# Wrapping has to be on before the text goes in, or the label stretches
	# to fit one long line and runs off the card.
	if wrap_lines:
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
