class_name PauseMenu
extends CanvasLayer
## Shared pause menu. Pauses the tree while open.

signal resumed
signal restart_requested
signal home_requested

var _root: Control


func _ready() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_to_group("touch_block")
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(Palette.UI_DARK, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 34)
	center.add_child(col)
	col.add_child(UiKit.label("PAUSED", 120, Color.WHITE, 14))
	col.add_child(UiKit.spacer(20))
	var resume: Button = UiKit.button("RESUME", Palette.UI_ACCENT, 66, Vector2(620, 170))
	resume.pressed.connect(_resume)
	col.add_child(resume)
	var restart: Button = UiKit.button("RESTART", Palette.PLAYER, 60, Vector2(620, 150))
	restart.pressed.connect(func() -> void:
		get_tree().paused = false
		restart_requested.emit())
	col.add_child(restart)
	var home: Button = UiKit.button("HOME", Palette.UI_DARK_SOFT, 60, Vector2(620, 150))
	home.pressed.connect(func() -> void:
		get_tree().paused = false
		home_requested.emit())
	col.add_child(home)
	var toggles := HBoxContainer.new()
	toggles.alignment = BoxContainer.ALIGNMENT_CENTER
	toggles.add_theme_constant_override("separation", 30)
	col.add_child(UiKit.spacer(10))
	col.add_child(toggles)
	toggles.add_child(_quick_toggle("sound", "sound"))
	toggles.add_child(_quick_toggle("music", "music"))
	toggles.add_child(_quick_toggle("vibrate", "haptics"))
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.15)


func _quick_toggle(icon: String, key: String) -> Button:
	var b: Button = UiKit.icon_button(icon, Palette.UI_ACCENT if Settings.get_bool(key) else Palette.UI_MUTED, 140)
	b.pressed.connect(func() -> void:
		var v: bool = not Settings.get_bool(key)
		Settings.set_value(key, v)
		UiKit.style_button(b, Palette.UI_ACCENT if v else Palette.UI_MUTED, 40))
	return b


func _resume() -> void:
	get_tree().paused = false
	resumed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_resume()
		get_viewport().set_input_as_handled()
