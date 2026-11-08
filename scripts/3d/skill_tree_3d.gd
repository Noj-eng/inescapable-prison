extends CanvasLayer
## The PRISON REP screen: shown after Victor goes down. Spend smokes on
## skills that last for every run after this one, then press R (or click
## NEW RUN) to start again from floor 1.

const Skills := preload("res://scripts/3d/skills_3d.gd")
const FX := preload("res://scripts/fx.gd")

const BRANCH_COLOR := {
	"MUSCLE": Color("ff5a4a"),
	"HUSTLE": Color("ffd23f"),
	"GANG": Color("4dd8ff"),
}

signal new_run

var _buttons := {}        # skill id -> Button
var _smokes_label: Label
var _font: Font


func _ready() -> void:
	layer = 5
	_font = FX.mono_font()
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.04, 1.0)
	bg.size = Vector2(1280, 720)
	add_child(bg)
	_label("CONTAINED.  FOR NOW.", Vector2(0, 26), Vector2(1280, 40), 34, Color("ff3d5a"), true)
	_label("Your reputation inside grows. Spend smokes on skills. They stay for every run after this.",
			Vector2(0, 72), Vector2(1280, 20), 13, Color(0.62, 0.7, 0.82), true)
	_smokes_label = _label("", Vector2(0, 98), Vector2(1280, 30), 22, Color("ffd23f"), true)
	var col_x := {"MUSCLE": 70, "HUSTLE": 490, "GANG": 910}
	var row := {"MUSCLE": 0, "HUSTLE": 0, "GANG": 0}
	for b in col_x:
		_label(b, Vector2(col_x[b], 150), Vector2(300, 24), 20, BRANCH_COLOR[b], true)
	for s: Dictionary in Skills.TREE:
		var b: String = s["branch"]
		var pos := Vector2(col_x[b], 186 + row[b] * 138)
		row[b] += 1
		if s.has("needs"):
			# a short line up to the skill it needs
			var line := ColorRect.new()
			line.color = Color(BRANCH_COLOR[b], 0.5)
			line.position = pos + Vector2(148, -16)
			line.size = Vector2(4, 16)
			add_child(line)
		var btn := Button.new()
		btn.position = pos
		btn.size = Vector2(300, 120)
		btn.focus_mode = Control.FOCUS_NONE
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.clip_text = true
		btn.add_theme_font_override("font", _font)
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_buy.bind(s["id"]))
		add_child(btn)
		_buttons[s["id"]] = btn
	var again := Button.new()
	again.text = "NEW RUN  [R]"
	again.position = Vector2(540, 640)
	again.size = Vector2(200, 46)
	again.focus_mode = Control.FOCUS_NONE
	again.add_theme_font_override("font", _font)
	again.add_theme_font_size_override("font_size", 18)
	_style(again, Color("4dff88"), true)
	again.pressed.connect(func(): new_run.emit())
	add_child(again)
	_refresh()


func _label(text: String, pos: Vector2, box: Vector2, size: int, c: Color, centred := false) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = box
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	if centred:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	return l


func _style(btn: Button, c: Color, lit: bool) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(c, 0.18 if state == "hover" else 0.08) if lit else Color(0.1, 0.1, 0.12, 0.8)
		sb.border_color = Color(c, 0.9 if lit else 0.25)
		sb.set_border_width_all(2 if lit else 1)
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", c.lightened(0.4) if lit else Color(0.5, 0.52, 0.58))
	btn.add_theme_color_override("font_hover_color", Color.WHITE if lit else Color(0.5, 0.52, 0.58))
	btn.add_theme_color_override("font_disabled_color", c.lightened(0.2) if lit else Color(0.45, 0.47, 0.52))


func _refresh() -> void:
	_smokes_label.text = "SMOKES  %d" % Skills.smokes + ("      (+%d this run)" % Skills.run_smokes if Skills.run_smokes > 0 else "")
	for s: Dictionary in Skills.TREE:
		var id: String = s["id"]
		var btn: Button = _buttons[id]
		var lvl := Skills.level_of(id)
		var why := Skills.why_not(id)
		var pips := ""
		for i in int(s["max"]):
			pips += "■" if i < lvl else "□"
		var price := "MAXED" if why == "MAXED" else ("%d SMOKES" % Skills.cost(id) if why == "" or why == "NOT ENOUGH SMOKES" else why)
		btn.text = "%s\n%s\n%s\n%s" % [s["name"], pips, s["desc"], price]
		var owned_or_buyable := lvl > 0 or why == ""
		_style(btn, BRANCH_COLOR[s["branch"]], owned_or_buyable)
		btn.disabled = why != ""


func _buy(id: String) -> void:
	if Skills.buy(id):
		_refresh()

