class_name UiTheme
extends RefCounted
## Builds the shared theme in code from the palette and applies it to the
## root window, so every Control in every scene inherits it. (Code-built
## instead of a hand-edited theme.tres so it always matches Palette.)

static var _theme: Theme = null


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = UiKit.font()
	t.default_font_size = 48
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_color("font_outline_color", "Label", Palette.UI_DARK)
	t.set_constant("outline_size", "Label", 6)
	var normal: StyleBoxFlat = UiKit.box(Palette.UI_ACCENT, UiKit.RADIUS, UiKit.BUTTON_DEPTH, Palette.shade(Palette.UI_ACCENT, 0.32))
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", normal)
	t.set_stylebox("pressed", "Button", UiKit.box(Palette.UI_ACCENT.darkened(0.06), UiKit.RADIUS, 4, Palette.shade(Palette.UI_ACCENT, 0.32)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font_size("font_size", "Button", 56)
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_stylebox("panel", "PanelContainer", UiKit.box(Palette.UI_DARK, 40))
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(1, 1, 1, 0.25)
	grabber.set_corner_radius_all(8)
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	t.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	_theme = t
	return t
