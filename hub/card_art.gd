class_name CardArt
extends Control
## Animated, stylized 2D illustration for each game card, drawn in code
## (no textures, near-zero cost). Each one previews the core mechanic.

var game_id: String = "crowd_rush"
var locked: bool = false
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


func _draw() -> void:
	match game_id:
		"crowd_rush":
			_draw_crowd_rush()
		"stack_skater":
			_draw_stack_skater()
		"overtake":
			_draw_overtake()
		"last_barricade":
			_draw_barricade()
	if locked:
		draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.UI_DARK, 0.45))


func _sky(top: Color, bottom: Color) -> void:
	var steps: int = 8
	for i: int in steps:
		var y0: float = size.y * float(i) / float(steps)
		draw_rect(Rect2(0, y0, size.x, size.y / float(steps) + 1.0), top.lerp(bottom, float(i) / float(steps - 1)))


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([a, b, c, d]), col)


## Perspective helper: track coordinates (x -1..1, depth 0 near..1 far).
func _persp(x: float, depth: float, horizon: float, near_w: float, far_w: float) -> Vector2:
	var cx: float = size.x * 0.5
	var y: float = lerpf(size.y, horizon, depth)
	var w: float = lerpf(near_w, far_w, depth)
	return Vector2(cx + x * w * 0.5, y)


func _person(p: Vector2, s: float, col: Color, phase: float) -> void:
	var bob: float = absf(sin(_t * 9.0 + phase)) * 3.0 * s
	var base: Vector2 = p - Vector2(0, bob)
	draw_circle(base + Vector2(0, 0), 6.0 * s, Palette.shade(col, 0.25))
	draw_circle(base + Vector2(0, -8.0 * s), 7.0 * s, col)
	draw_circle(base + Vector2(0, -18.0 * s), 5.5 * s, Palette.SKIN)
	draw_arc(base + Vector2(0, -19.0 * s), 5.6 * s, PI, TAU, 8, Palette.lighten(col, 0.2), 3.0 * s)


func _draw_crowd_rush() -> void:
	_sky(Color("#3E9BF0"), Palette.SKY_HORIZON)
	var hz: float = size.y * 0.3
	draw_rect(Rect2(0, hz, size.x, size.y - hz), Palette.WATER_DEEP)
	for i: int in 6:
		var wx: float = fmod(float(i) * 190.0 + _t * 20.0, size.x + 100.0) - 50.0
		draw_line(Vector2(wx, hz + 30 + i * 22), Vector2(wx + 60, hz + 30 + i * 22), Color(1, 1, 1, 0.3), 4.0)
	draw_circle(Vector2(size.x * 0.12, hz + 4), 60, Palette.GRASS)
	draw_circle(Vector2(size.x * 0.9, hz + 10), 80, Palette.GRASS.darkened(0.1))
	var nw: float = size.x * 1.1
	var fw: float = size.x * 0.16
	_quad(_persp(-1, 0, hz, nw, fw), _persp(1, 0, hz, nw, fw), _persp(1, 1, hz, nw, fw), _persp(-1, 1, hz, nw, fw), Palette.TRACK)
	# Speed bands.
	for i: int in 10:
		var d0: float = fmod(float(i) * 0.1 + _t * 0.35, 1.0)
		var d1: float = minf(1.0, d0 + 0.05)
		var k0: float = pow(d0, 0.5)
		var k1: float = pow(d1, 0.5)
		_quad(_persp(-1, k0, hz, nw, fw), _persp(1, k0, hz, nw, fw), _persp(1, k1, hz, nw, fw), _persp(-1, k1, hz, nw, fw), Palette.TRACK.darkened(0.06))
	# Gate pair.
	var gd: float = 0.42
	var gl: Vector2 = _persp(-1, gd, hz, nw, fw)
	var gm: Vector2 = _persp(0, gd, hz, nw, fw)
	var gr: Vector2 = _persp(1, gd, hz, nw, fw)
	var gh: float = 120.0
	draw_rect(Rect2(gl.x, gl.y - gh, gm.x - gl.x - 4, gh), Color(Palette.PLAYER, 0.6))
	draw_rect(Rect2(gm.x + 4, gm.y - gh, gr.x - gm.x - 4, gh), Color(Palette.ENEMY, 0.6))
	var f: Font = UiKit.font()
	draw_string_outline(f, Vector2(gl.x + 40, gl.y - 34), "x3", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, 10, Palette.UI_DARK)
	draw_string(f, Vector2(gl.x + 40, gl.y - 34), "x3", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Color.WHITE)
	draw_string_outline(f, Vector2(gm.x + 40, gm.y - 34), "-10", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, 10, Palette.UI_DARK)
	draw_string(f, Vector2(gm.x + 40, gm.y - 34), "-10", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Color.WHITE)
	# Red crowd far.
	for i: int in 14:
		var a: float = float(i) * 2.4
		var r: float = sqrt(float(i)) * 9.0
		_person(_persp(0, 0.86, hz, nw, fw) + Vector2(cos(a) * r * 1.6, sin(a) * r * 0.5), 1.1, Palette.ENEMY, float(i))
	# Blue crowd near, swaying.
	var sway: float = sin(_t * 1.3) * size.x * 0.12
	for i: int in 34:
		var a: float = float(i) * 2.39996
		var r: float = sqrt(float(i)) * 15.0
		var p: Vector2 = Vector2(size.x * 0.5 + sway + cos(a) * r * 1.5, size.y * 0.84 + sin(a) * r * 0.55)
		_person(p, 2.3, Palette.PLAYER, float(i) * 1.7)


func _draw_stack_skater() -> void:
	_sky(Color("#8FA6C6"), Palette.FOG_CITY)
	var hz: float = size.y * 0.35
	for i: int in 12:
		var bx: float = float(i) * size.x / 11.0 - 30.0
		var bh: float = 90.0 + fmod(float(i) * 73.0, 160.0)
		draw_rect(Rect2(bx, hz + 120 - bh, 70, bh + size.y), Color("#9AA9C0").lerp(Palette.FOG_CITY, 0.3))
	for i: int in 8:
		var bx: float = float(i) * size.x / 7.0 - 10.0
		var bh: float = 160.0 + fmod(float(i) * 97.0, 200.0)
		draw_rect(Rect2(bx, size.y - bh + 60, 110, bh), Color("#7F8EA8"))
	var nw: float = size.x * 0.75
	var fw: float = size.x * 0.12
	_quad(_persp(-1, 0, hz, nw, fw), _persp(1, 0, hz, nw, fw), _persp(1, 1, hz, nw, fw), _persp(-1, 1, hz, nw, fw), Palette.TRACK)
	var c: Vector2 = Vector2(size.x * 0.5 + sin(_t * 1.5) * 50.0, size.y * 0.78)
	var n: int = 6 + int(absf(sin(_t * 0.8)) * 6.0)
	for i: int in n:
		for sgn: int in [-1, 1]:
			var x: float = c.x + float(sgn) * (30.0 + float(i) * 22.0)
			draw_rect(Rect2(x - 10, c.y - 70, 20, 34), Palette.GOLD_SHADOW)
			draw_rect(Rect2(x - 10, c.y - 74, 20, 30), Palette.GOLD)
	draw_circle(c + Vector2(0, -100), 22, Palette.ENEMY)
	draw_rect(Rect2(c.x - 22, c.y - 80, 44, 70), Palette.PLAYER)
	draw_rect(Rect2(c.x - 50, c.y - 8, 100, 14), Palette.UI_DARK)


func _draw_overtake() -> void:
	_sky(Color("#3E9BF0"), Palette.SKY_HORIZON)
	var hz: float = size.y * 0.32
	draw_rect(Rect2(0, hz, size.x, size.y), Palette.GRASS)
	draw_circle(Vector2(size.x * 0.25, hz + 50), 110, Palette.GRASS.lightened(0.1))
	draw_circle(Vector2(size.x * 0.8, hz + 40), 90, Palette.GRASS.lightened(0.05))
	var nw: float = size.x * 1.0
	var fw: float = size.x * 0.08
	_quad(_persp(-1, 0, hz, nw, fw), _persp(1, 0, hz, nw, fw), _persp(1, 1, hz, nw, fw), _persp(-1, 1, hz, nw, fw), Color("#4A4F5C"))
	for i: int in 8:
		var d0: float = fmod(float(i) * 0.125 + _t * 0.6, 1.0)
		var k0: float = pow(d0, 0.6)
		var k1: float = pow(minf(1.0, d0 + 0.04), 0.6)
		_quad(_persp(-0.03, k0, hz, nw, fw), _persp(0.03, k0, hz, nw, fw), _persp(0.03, k1, hz, nw, fw), _persp(-0.03, k1, hz, nw, fw), Color.WHITE)
	var cars: Array = [[-0.5, 0.55, Palette.GOLD], [0.45, 0.35, Palette.PLAYER_LIGHT], [-0.45, 0.2, Palette.UI_ACCENT]]
	for car: Array in cars:
		var p: Vector2 = _persp(float(car[0]), float(car[1]), hz, nw, fw)
		var s: float = lerpf(1.0, 0.25, float(car[1]))
		draw_rect(Rect2(p.x - 60 * s, p.y - 70 * s, 120 * s, 70 * s), car[2] as Color)
		draw_rect(Rect2(p.x - 45 * s, p.y - 100 * s, 90 * s, 34 * s), (car[2] as Color).darkened(0.2))
	var px: float = size.x * 0.5 + sin(_t * 2.0) * 120.0
	var py: float = size.y * 0.86
	draw_rect(Rect2(px - 60, py - 50, 120, 70), Color("#B5652B"))
	draw_rect(Rect2(px - 80, py - 70, 160, 18), Palette.UI_DARK)
	draw_rect(Rect2(px - 90, py - 10, 34, 40), Palette.UI_DARK)
	draw_rect(Rect2(px + 56, py - 10, 34, 40), Palette.UI_DARK)


func _draw_barricade() -> void:
	_sky(Color("#7E9A8E"), Color("#C9D6CC"))
	var hz: float = size.y * 0.42
	draw_rect(Rect2(0, hz, size.x, size.y), Color("#6B5A44"))
	for i: int in 14:
		var tx: float = float(i) * size.x / 13.0 + fmod(float(i) * 37.0, 30.0)
		var th: float = 260.0 + fmod(float(i) * 61.0, 120.0)
		var base: Vector2 = Vector2(tx, hz + 30)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-50, 0), base + Vector2(0, -th), base + Vector2(50, 0)]), Palette.FOREST.lerp(Color("#C9D6CC"), 0.25))
	for i: int in 5:
		var ex: float = size.x * (0.2 + 0.15 * float(i)) + sin(_t * 2.0 + float(i)) * 10.0
		var ey: float = hz + 90 + float(i % 2) * 30.0
		draw_circle(Vector2(ex, ey - 60), 16, Color("#8FA08A"))
		draw_rect(Rect2(ex - 18, ey - 46, 36, 50), Color("#6F7F6C"))
	for i: int in 4:
		var y: float = size.y - 70.0 - float(i) * 46.0
		draw_rect(Rect2(-20, y, size.x + 40, 36), Color("#8A6440").darkened(float(i % 2) * 0.1))
	var cx: float = size.x * 0.5 + sin(_t) * 80.0
	draw_arc(Vector2(cx, size.y * 0.55), 34, 0, TAU, 24, Palette.UI_ACCENT, 6.0)
	draw_line(Vector2(cx - 50, size.y * 0.55), Vector2(cx + 50, size.y * 0.55), Palette.UI_ACCENT, 4.0)
	draw_line(Vector2(cx, size.y * 0.55 - 50), Vector2(cx, size.y * 0.55 + 50), Palette.UI_ACCENT, 4.0)
