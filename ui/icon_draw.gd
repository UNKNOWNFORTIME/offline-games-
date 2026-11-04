@tool
class_name IconDraw
extends Control
## Vector icons drawn in code (no image assets): gear, pause, coin, lock,
## play, home, retry, close, sound, music, vibrate, ad, star.

@export var kind: String = "coin":
	set(v):
		kind = v
		queue_redraw()
@export var color: Color = Color.WHITE:
	set(v):
		color = v
		queue_redraw()
@export var spin: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _process(_delta: float) -> void:
	if spin and kind == "coin":
		queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var c: Vector2 = size * 0.5
	var u: float = s / 100.0
	match kind:
		"coin":
			_coin(c, s * 0.42)
		"gear":
			_gear(c, u)
		"pause":
			draw_rect(Rect2(c + Vector2(-20, -24) * u, Vector2(13, 48) * u), color)
			draw_rect(Rect2(c + Vector2(7, -24) * u, Vector2(13, 48) * u), color)
		"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-14, -24) * u, c + Vector2(24, 0) * u, c + Vector2(-14, 24) * u]), color)
		"lock":
			draw_arc(c + Vector2(0, -8) * u, 15 * u, PI, TAU, 16, color, 8 * u, true)
			draw_rect(Rect2(c + Vector2(-24, -8) * u, Vector2(48, 38) * u), color)
			draw_circle(c + Vector2(0, 8) * u, 5 * u, Palette.UI_DARK)
		"home":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-28, -2) * u, c + Vector2(0, -28) * u, c + Vector2(28, -2) * u]), color)
			draw_rect(Rect2(c + Vector2(-19, -4) * u, Vector2(38, 30) * u), color)
			draw_rect(Rect2(c + Vector2(-6, 8) * u, Vector2(12, 18) * u), Palette.UI_DARK_SOFT)
		"retry":
			draw_arc(c, 22 * u, -PI * 0.15, PI * 1.45, 24, color, 9 * u, true)
			var tip: Vector2 = c + Vector2(cos(-PI * 0.15), sin(-PI * 0.15)) * 22 * u
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-12, -10) * u, tip + Vector2(10, -12) * u, tip + Vector2(4, 10) * u]), color)
		"close":
			draw_line(c + Vector2(-20, -20) * u, c + Vector2(20, 20) * u, color, 10 * u, true)
			draw_line(c + Vector2(20, -20) * u, c + Vector2(-20, 20) * u, color, 10 * u, true)
		"sound":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-26, -10) * u, c + Vector2(-12, -10) * u, c + Vector2(4, -24) * u, c + Vector2(4, 24) * u, c + Vector2(-12, 10) * u, c + Vector2(-26, 10) * u]), color)
			draw_arc(c + Vector2(6, 0) * u, 14 * u, -0.9, 0.9, 10, color, 6 * u, true)
			draw_arc(c + Vector2(6, 0) * u, 24 * u, -0.9, 0.9, 12, color, 6 * u, true)
		"music":
			draw_circle(c + Vector2(-14, 18) * u, 9 * u, color)
			draw_circle(c + Vector2(16, 12) * u, 9 * u, color)
			draw_line(c + Vector2(-6, 18) * u, c + Vector2(-6, -22) * u, color, 6 * u)
			draw_line(c + Vector2(24, 12) * u, c + Vector2(24, -28) * u, color, 6 * u)
			draw_line(c + Vector2(-6, -22) * u, c + Vector2(24, -28) * u, color, 9 * u)
		"vibrate":
			draw_rect(Rect2(c + Vector2(-12, -24) * u, Vector2(24, 48) * u), color, false, 6 * u)
			draw_line(c + Vector2(-24, -10) * u, c + Vector2(-24, 10) * u, color, 5 * u)
			draw_line(c + Vector2(24, -10) * u, c + Vector2(24, 10) * u, color, 5 * u)
		"ad":
			var r := Rect2(c + Vector2(-30, -20) * u, Vector2(60, 40) * u)
			draw_rect(r, color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -11) * u, c + Vector2(12, 0) * u, c + Vector2(-8, 11) * u]), Palette.GOLD_SHADOW)
		"star":
			var pts := PackedVector2Array()
			for i: int in 10:
				var a: float = -PI * 0.5 + float(i) * PI / 5.0
				var rr: float = 30.0 if i % 2 == 0 else 13.0
				pts.append(c + Vector2(cos(a), sin(a)) * rr * u)
			draw_colored_polygon(pts, color)


func _coin(c: Vector2, r: float) -> void:
	var squash: float = 1.0
	if spin:
		squash = absf(cos(Time.get_ticks_msec() / 1000.0 * 3.0)) * 0.7 + 0.3
	var sx := Vector2(squash, 1.0)
	_ellipse(c + Vector2(0, r * 0.12), r, sx, Palette.GOLD_SHADOW)
	_ellipse(c, r, sx, Palette.GOLD)
	_ellipse(c, r * 0.72, sx, Palette.GOLD_SHADOW.lerp(Palette.GOLD, 0.45))
	_ellipse(c, r * 0.6, sx, Palette.GOLD)
	_ellipse(c + Vector2(-r * 0.3 * squash, -r * 0.35), r * 0.16, sx, Color(1, 1, 1, 0.75))


func _ellipse(c: Vector2, r: float, sx: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in 24:
		var a: float = float(i) / 24.0 * TAU
		pts.append(c + Vector2(cos(a) * r * sx.x, sin(a) * r * sx.y))
	draw_colored_polygon(pts, col)


func _gear(c: Vector2, u: float) -> void:
	var pts := PackedVector2Array()
	var teeth: int = 8
	for i: int in teeth * 4:
		var a: float = float(i) / float(teeth * 4) * TAU
		var phase: int = i % 4
		var r: float = 34.0 if phase == 1 or phase == 2 else 25.0
		pts.append(c + Vector2(cos(a), sin(a)) * r * u)
	draw_colored_polygon(pts, color)
	draw_circle(c, 11 * u, Palette.UI_DARK_SOFT)
