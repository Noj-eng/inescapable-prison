extends Control
## A thin segmented neon meter, like a readout on an industrial monitor.

var value := 1.0:            # 0..1
	set(v):
		value = clampf(v, 0.0, 1.0)
		_flash = 0.25 if v < _shown else _flash
var color := Color("ff3d6e")
var segments := 20

var _shown := 1.0
var _flash := 0.0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	_shown = move_toward(_shown, value, delta * 1.5)
	_flash = maxf(0.0, _flash - delta)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	# corner brackets
	var b := 5.0
	var frame := Color(color, 0.55)
	for corner in [Vector2(0, 0), Vector2(w, 0), Vector2(0, h), Vector2(w, h)]:
		var dx := b if corner.x == 0 else -b
		var dy := b if corner.y == 0 else -b
		draw_line(corner, corner + Vector2(dx, 0), frame, 1.0)
		draw_line(corner, corner + Vector2(0, dy), frame, 1.0)
	var cell_w := (w - 6.0) / segments
	for i in segments:
		var r := Rect2(Vector2(3 + i * cell_w, 3), Vector2(cell_w - 2.0, h - 6))
		var fill := (i + 1) / float(segments) <= value + 0.001
		var draining := not fill and (i + 1) / float(segments) <= _shown + 0.001
		if fill:
			draw_rect(r.grow(1.5), Color(color, 0.22))
			draw_rect(r, color.lightened(0.4) if _flash > 0.0 else color)
		elif draining:
			draw_rect(r, Color(1, 1, 1, 0.55))
		else:
			draw_rect(r, Color(color, 0.12), false, 1.0)
	# a slow sweep of light along the meter
	var sweep := fmod(_t * 0.4, 1.4) - 0.2
	draw_rect(Rect2(Vector2(w * sweep, 2), Vector2(10, h - 4)), Color(1, 1, 1, 0.06))
