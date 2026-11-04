class_name HubBackground
extends Control
## Animated gradient backdrop with slowly drifting soft shapes.

var _t: float = 0.0
var _seeds: PackedVector3Array = PackedVector3Array()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 14:
		_seeds.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(40.0, 160.0)))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var top := Color("#2F6FE0")
	var bottom := Color("#1B1F2A")
	var steps: int = 16
	for i: int in steps:
		var k: float = float(i) / float(steps - 1)
		draw_rect(Rect2(0, size.y * float(i) / float(steps), size.x, size.y / float(steps) + 1.0), top.lerp(bottom, pow(k, 0.8)))
	var cols: Array[Color] = [Palette.PLAYER_LIGHT, Palette.GOLD, Palette.UI_ACCENT, Palette.ENEMY_LIGHT]
	for i: int in _seeds.size():
		var s: Vector3 = _seeds[i]
		var y: float = fmod(s.y * size.y - _t * (20.0 + s.z * 0.2), size.y + 400.0)
		if y < -200.0:
			y += size.y + 400.0
		var x: float = s.x * size.x + sin(_t * 0.4 + float(i)) * 40.0
		draw_circle(Vector2(x, y), s.z, Color(cols[i % cols.size()], 0.07))
