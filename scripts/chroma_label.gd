extends Control
## Text with a slight red/cyan colour split (chromatic aberration),
## drawn in the HUD's monospace font.

const FX := preload("res://scripts/fx.gd")

var text := "":
	set(v):
		text = v
		for l in _labels:
			l.text = v
var color := Color.WHITE:
	set(v):
		color = v
		if _labels.size() == 3:
			_labels[2].add_theme_color_override("font_color", v)
var font_size := 18
var align := HORIZONTAL_ALIGNMENT_LEFT

var _labels: Array[Label] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var offsets := [Vector2(-1.5, 0), Vector2(1.5, 0), Vector2.ZERO]
	var colors := [Color(1.0, 0.1, 0.25, 0.55), Color(0.1, 0.9, 1.0, 0.5), color]
	for i in 3:
		var l := Label.new()
		l.text = text
		l.position = offsets[i]
		l.size = size
		l.horizontal_alignment = align
		l.add_theme_font_override("font", FX.mono_font())
		l.add_theme_font_size_override("font_size", font_size)
		l.add_theme_color_override("font_color", colors[i])
		if i == 2:
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
			l.add_theme_constant_override("outline_size", 5)
		add_child(l)
		_labels.append(l)
