class_name GameCard
extends PanelContainer
## Big hub card: animated illustration + title + level + PLAY / locked.

signal play_requested(id: String)

var info: Dictionary = {}


func setup(p_info: Dictionary) -> void:
	info = p_info
	var id: String = str(info["id"])
	var locked: bool = str(info["scene"]) == ""
	var accent: Color = info["color"]
	var sb: StyleBoxFlat = UiKit.box(Color.WHITE, 52, 18, Palette.shade(accent, 0.25))
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 18
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(0, 640)
	mouse_filter = Control.MOUSE_FILTER_PASS

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	# Illustration inside a rounded top area.
	var art_holder := PanelContainer.new()
	var art_sb := StyleBoxFlat.new()
	art_sb.bg_color = accent
	art_sb.corner_radius_top_left = 52
	art_sb.corner_radius_top_right = 52
	art_holder.add_theme_stylebox_override("panel", art_sb)
	art_holder.custom_minimum_size = Vector2(0, 430)
	art_holder.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	art_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(art_holder)
	var art := CardArt.new()
	art.game_id = id
	art.locked = locked
	art_holder.add_child(art)
	if locked:
		var lock_box := CenterContainer.new()
		lock_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_holder.add_child(lock_box)
		var badge: PanelContainer = UiKit.panel(Color(Palette.UI_DARK, 0.85), 60)
		lock_box.add_child(badge)
		var bh := HBoxContainer.new()
		bh.add_theme_constant_override("separation", 14)
		badge.add_child(bh)
		var li := IconDraw.new()
		li.kind = "lock"
		li.custom_minimum_size = Vector2(70, 70)
		bh.add_child(li)
		bh.add_child(UiKit.label("COMING SOON", 46, Color.WHITE, 0))

	var bottom := MarginContainer.new()
	for side: String in ["left", "right"]:
		bottom.add_theme_constant_override("margin_" + side, 40)
	bottom.add_theme_constant_override("margin_top", 24)
	bottom.add_theme_constant_override("margin_bottom", 18)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bottom)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	var title: Label = UiKit.label(str(info["title"]).to_upper(), 66, Palette.UI_DARK, 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	texts.add_child(title)
	var sub_text: String = str(info["tagline"])
	if not locked:
		sub_text = "Level %d  -  %s" % [SaveSystem.get_int(SaveSystem.game(id), "level", 1), sub_text]
	var sub: Label = UiKit.label(sub_text, 34, Palette.UI_MUTED, 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(sub)
	if not locked:
		var play: Button = UiKit.button("PLAY", Palette.UI_ACCENT, 60, Vector2(250, 140))
		play.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		play.pressed.connect(func() -> void: play_requested.emit(id))
		row.add_child(play)
		_pulse(play)
	else:
		modulate = Color(0.92, 0.92, 0.95)


func _pulse(c: Control) -> void:
	var t: Tween = c.create_tween().set_loops()
	t.tween_property(c, "rotation", 0.04, 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(c, "rotation", -0.04, 0.5).set_trans(Tween.TRANS_SINE)
	c.resized.connect(func() -> void: c.pivot_offset = c.size * 0.5)

