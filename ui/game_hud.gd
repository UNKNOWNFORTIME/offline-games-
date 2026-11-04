class_name GameHud
extends CanvasLayer
## Shared in-run HUD for every game: pause (top-left), level + progress (top-center), coins
## (top-right), "drag to start" hint with animated finger, banner toasts.

signal pause_pressed

var _level_label: Label
var _progress: ProgressStrip
var _hint: Control
var _finger: Control
var _toast: Label
var _hint_t: float = 0.0
var _hint_label: Label
var _right_slot: HBoxContainer


class ProgressStrip:
	extends Control
	var value: float = 0.0
	var _shown: float = 0.0

	func _ready() -> void:
		custom_minimum_size = Vector2(520, 44)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		var nv: float = lerpf(_shown, value, 1.0 - exp(-10.0 * delta))
		if absf(nv - _shown) > 0.0005:
			_shown = nv
			queue_redraw()

	func _draw() -> void:
		var r: float = size.y * 0.5
		var full := Rect2(Vector2.ZERO, size)
		draw_style_box(_sb(Color(Palette.UI_DARK, 0.6), r), full)
		var w: float = maxf(size.y, size.x * clampf(_shown, 0.0, 1.0))
		draw_style_box(_sb(Palette.UI_ACCENT, r), Rect2(Vector2.ZERO, Vector2(w, size.y)).grow(-6))
		# Boss skull marker at the end.
		draw_circle(Vector2(size.x - r, r), r * 0.62, Palette.ENEMY)
		draw_circle(Vector2(size.x - r - 5, r - 2), 3.5, Color.WHITE)
		draw_circle(Vector2(size.x - r + 5, r - 2), 3.5, Color.WHITE)

	func _sb(c: Color, r: float) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(int(r))
		return sb


func _ready() -> void:
	layer = 10
	var safe := SafeArea.new()
	add_child(safe)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 12)
	safe.add_child(col)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var pause: Button = UiKit.icon_button("pause", Color(Palette.UI_DARK_SOFT, 0.9), 124)
	pause.pressed.connect(func() -> void: pause_pressed.emit())
	top.add_child(pause)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(center)
	_level_label = UiKit.label("LEVEL 1", 64, Color.WHITE, 12)
	center.add_child(_level_label)
	_progress = ProgressStrip.new()
	_progress.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(_progress)
	top.add_child(CoinPill.new())

	# Start hint.
	_hint = Control.new()
	_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	var hl: Label = UiKit.label("HOLD & DRAG TO RUN", 70, Color.WHITE, 14)
	_hint_label = hl
	hl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hl.anchor_left = 0.0
	hl.anchor_right = 1.0
	hl.offset_top = -470
	hl.offset_bottom = -380
	_hint.add_child(hl)
	_finger = _make_finger()
	_hint.add_child(_finger)

	_toast = UiKit.label("", 110, Palette.GOLD, 16)
	_toast.set_anchors_preset(Control.PRESET_CENTER)
	_toast.anchor_left = 0.0
	_toast.anchor_right = 1.0
	_toast.offset_top = -420
	_toast.offset_bottom = -280
	_toast.modulate.a = 0.0
	add_child(_toast)


func _make_finger() -> Control:
	var f := Control.new()
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.size = Vector2(160, 200)
	f.draw.connect(func() -> void:
		f.draw_circle(Vector2(80, 60), 46, Color(1, 1, 1, 0.25))
		f.draw_circle(Vector2(80, 60), 30, Color(1, 1, 1, 0.9))
		f.draw_rect(Rect2(62, 60, 36, 110), Color(1, 1, 1, 0.9))
		f.draw_circle(Vector2(80, 170), 22, Color(1, 1, 1, 0.9)))
	return f


func set_hint_text(t: String) -> void:
	_hint_label.text = t


## Hide the drag finger (games with tap/swipe controls draw their own hint).
func set_finger_visible(on: bool) -> void:
	_finger.visible = on


func set_title(t: String) -> void:
	_level_label.text = t


func set_progress_visible(on: bool) -> void:
	_progress.visible = on


func set_level(n: int) -> void:
	_level_label.text = "LEVEL %d" % n


func set_progress(k: float) -> void:
	_progress.value = k


func show_hint(on: bool) -> void:
	if on:
		_hint.visible = true
		_hint.modulate.a = 1.0
	else:
		var t: Tween = create_tween()
		t.tween_property(_hint, "modulate:a", 0.0, 0.2)
		t.tween_callback(func() -> void: _hint.visible = false)


func toast(text: String, color: Color = Palette.GOLD) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.pivot_offset = _toast.size * 0.5
	_toast.scale = Vector2(0.4, 0.4)
	_toast.modulate.a = 1.0
	var t: Tween = create_tween()
	t.tween_property(_toast, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.7)
	t.tween_property(_toast, "modulate:a", 0.0, 0.3)


func _process(delta: float) -> void:
	if _hint.visible:
		_hint_t += delta
		var vp: Vector2 = get_viewport().get_visible_rect().size
		_finger.position = Vector2(vp.x * 0.5 - 80.0 + sin(_hint_t * 3.2) * vp.x * 0.25, vp.y - 360.0)
