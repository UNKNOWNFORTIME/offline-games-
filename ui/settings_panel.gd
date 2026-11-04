class_name SettingsPanel
extends CanvasLayer
## Modal settings: sound, music, haptics, graphics quality, language
## placeholder. Changes save immediately (Settings -> SaveSystem).

signal closed

var _root: Control
var _card: PanelContainer


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_to_group("touch_block")
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			close())

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_card = UiKit.panel(Palette.UI_DARK, 56, 16)
	_card.custom_minimum_size = Vector2(900, 0)
	center.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)
	_card.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title: Label = UiKit.label("SETTINGS", 80, Color.WHITE, 10)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_child(title)
	var x: Button = UiKit.icon_button("close", Palette.ENEMY, 110)
	x.pressed.connect(close)
	head.add_child(x)
	col.add_child(UiKit.spacer(6))

	col.add_child(_toggle_row("sound", "Sound", "sound"))
	col.add_child(_toggle_row("music", "Music", "music"))
	col.add_child(_toggle_row("vibrate", "Vibration", "haptics"))

	col.add_child(UiKit.spacer(4))
	var ql: Label = UiKit.label("GRAPHICS", 46, Palette.UI_MUTED, 0)
	ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(ql)
	var q := HBoxContainer.new()
	q.add_theme_constant_override("separation", 20)
	col.add_child(q)
	var low: Button = UiKit.button("LOW", Palette.UI_DARK_SOFT, 54, Vector2(0, 130))
	var high: Button = UiKit.button("HIGH", Palette.UI_DARK_SOFT, 54, Vector2(0, 130))
	low.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	high.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q.add_child(low)
	q.add_child(high)
	var refresh_q: Callable = func() -> void:
		UiKit.style_button(low, Palette.PLAYER if not Settings.is_high() else Palette.UI_DARK_SOFT, 54)
		UiKit.style_button(high, Palette.PLAYER if Settings.is_high() else Palette.UI_DARK_SOFT, 54)
	refresh_q.call()
	low.pressed.connect(func() -> void:
		Settings.set_quality(false)
		refresh_q.call())
	high.pressed.connect(func() -> void:
		Settings.set_quality(true)
		refresh_q.call())
	var hint: Label = UiKit.label("Low: faster on older phones (no shadows/outlines, 75% render scale)", 30, Palette.UI_MUTED, 0)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(hint)

	var lang := HBoxContainer.new()
	col.add_child(lang)
	var ll: Label = UiKit.label("Language", 50, Color.WHITE, 0)
	ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lang.add_child(ll)
	var lv: Label = UiKit.label("English", 50, Palette.UI_MUTED, 0)
	lang.add_child(lv)

	var ver: Label = UiKit.label("%s v%s" % [AppInfo.GAME_NAME, AppInfo.VERSION], 28, Palette.UI_MUTED, 0)
	col.add_child(ver)

	_card.pivot_offset = _card.custom_minimum_size * 0.5
	_card.scale = Vector2(0.85, 0.85)
	_card.modulate.a = 0.0
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_card, "modulate:a", 1.0, 0.15)


func _toggle_row(icon: String, text: String, key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var ic := IconDraw.new()
	ic.kind = icon
	ic.custom_minimum_size = Vector2(90, 90)
	row.add_child(ic)
	var l: Label = UiKit.label(text, 54, Color.WHITE, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(l)
	var b: Button = UiKit.button("", Palette.UI_ACCENT, 50, Vector2(230, 120))
	row.add_child(b)
	_style_toggle(b, Settings.get_bool(key))
	b.pressed.connect(func() -> void:
		var v: bool = not Settings.get_bool(key)
		Settings.set_value(key, v)
		_style_toggle(b, v)
		if key == "haptics" and v:
			Haptics.medium())
	return row


func _style_toggle(b: Button, on: bool) -> void:
	b.text = "ON" if on else "OFF"
	UiKit.style_button(b, Palette.UI_ACCENT if on else Palette.UI_MUTED, 50)


func close() -> void:
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(_card, "scale", Vector2(0.9, 0.9), 0.12)
	t.tween_property(_root, "modulate:a", 0.0, 0.12)
	await t.finished
	closed.emit()
	queue_free()
