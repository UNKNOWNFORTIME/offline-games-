class_name SafeArea
extends MarginContainer
## Full-screen container whose margins follow the device safe area
## (notches, punch holes, rounded corners, gesture bar) + a base padding.

@export var base_padding: float = 28.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_update)
	_update()


func _update() -> void:
	var left: float = 0.0
	var top: float = 0.0
	var right: float = 0.0
	var bottom: float = 0.0
	if OS.has_feature("mobile"):
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var win: Vector2i = DisplayServer.window_get_size()
		var vp: Vector2 = get_viewport().get_visible_rect().size
		if win.x > 0 and win.y > 0 and safe.size.x > 0:
			var sx: float = vp.x / float(win.x)
			var sy: float = vp.y / float(win.y)
			left = float(safe.position.x) * sx
			top = float(safe.position.y) * sy
			right = float(win.x - safe.end.x) * sx
			bottom = float(win.y - safe.end.y) * sy
	add_theme_constant_override("margin_left", int(left + base_padding))
	add_theme_constant_override("margin_top", int(top + base_padding))
	add_theme_constant_override("margin_right", int(right + base_padding))
	add_theme_constant_override("margin_bottom", int(bottom + base_padding))
