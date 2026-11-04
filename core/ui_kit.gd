class_name UiKit
extends RefCounted
## Factory for the shared chunky UI: pressable rounded buttons with a thick
## bottom shadow, outlined labels, rounded panels. Every button gets press
## animation (scale 0.94 / 0.08 s) + light haptic + click SFX.

const RADIUS: int = 28
const BUTTON_DEPTH: int = 14
const FONT_CANDIDATES: Array = [
	"res://ui/fonts/LilitaOne-Regular.ttf",
	"res://ui/fonts/Baloo2-ExtraBold.ttf",
	"res://ui/fonts/Baloo2-Bold.ttf",
	"res://ui/fonts/Baloo2-VariableFont_wght.ttf",
]

static var _font: Font = null


## The game font: Lilita One / Baloo 2 if present in ui/fonts, otherwise
## the engine default made chunky with synthetic emboldening.
static func font() -> Font:
	if _font != null:
		return _font
	var fv := FontVariation.new()
	var base: Font = null
	for p: Variant in FONT_CANDIDATES:
		if ResourceLoader.exists(p):
			base = load(p) as Font
			break
	if base != null:
		fv.base_font = base
	else:
		fv.base_font = ThemeDB.fallback_font
		fv.variation_embolden = 0.9
		fv.spacing_glyph = 1
	_font = fv
	return _font


static func box(color: Color, radius: int = RADIUS, depth: int = 0, depth_color: Color = Color.BLACK) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 6
	sb.anti_aliasing = true
	if depth > 0:
		sb.border_width_bottom = depth
		sb.border_color = depth_color
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14 + depth
	return sb


## Big pressable button. `color` is the face; the bottom edge is a darker
## shade so it reads as a physical, pushable toy button.
static func button(text: String, color: Color = Palette.UI_ACCENT, font_size: int = 60, min_size: Vector2 = Vector2(0, 150), text_color: Color = Color.WHITE) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	style_button(b, color, font_size, text_color)
	wire_press_feedback(b)
	b.add_to_group("touch_block")
	return b


static func style_button(b: Button, color: Color, font_size: int = 60, text_color: Color = Color.WHITE) -> void:
	var edge: Color = Palette.shade(color, 0.32)
	var normal: StyleBoxFlat = box(color, RADIUS, BUTTON_DEPTH, edge)
	var hover: StyleBoxFlat = box(color.lightened(0.06), RADIUS, BUTTON_DEPTH, edge)
	var pressed: StyleBoxFlat = box(color.darkened(0.06), RADIUS, 4, edge)
	pressed.content_margin_top = 14 + BUTTON_DEPTH - 4
	pressed.expand_margin_top = -float(BUTTON_DEPTH - 4)
	var disabled: StyleBoxFlat = box(Palette.UI_MUTED, RADIUS, BUTTON_DEPTH, Palette.shade(Palette.UI_MUTED, 0.3))
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", text_color)
	b.add_theme_color_override("font_hover_color", text_color)
	b.add_theme_color_override("font_pressed_color", text_color)
	b.add_theme_color_override("font_hover_pressed_color", text_color)
	b.add_theme_color_override("font_outline_color", Color(edge, 0.9))
	b.add_theme_constant_override("outline_size", 10 if text_color == Color.WHITE else 0)


static func wire_press_feedback(c: Control) -> void:
	var b: BaseButton = c as BaseButton
	if b == null:
		return
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		var t: Tween = b.create_tween()
		t.tween_property(b, "scale", Vector2(0.94, 0.94), 0.08).set_trans(Tween.TRANS_QUAD)
		Haptics.light()
		AudioManager.play("ui_click", 0.05))
	b.button_up.connect(func() -> void:
		var t: Tween = b.create_tween()
		t.tween_property(b, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))


## Flat text-only link button ("No thanks").
static func link(text: String, font_size: int = 44, color: Color = Color(1, 1, 1, 0.75)) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for s: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Palette.UI_DARK)
	b.add_theme_constant_override("outline_size", 8)
	wire_press_feedback(b)
	b.add_to_group("touch_block")
	return b


## Label with the thick dark outline used for all big numbers.
static func label(text: String, font_size: int = 56, color: Color = Color.WHITE, outline: int = 8) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Palette.UI_DARK)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))
	l.add_theme_constant_override("shadow_offset_y", 6)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func panel(color: Color = Palette.UI_DARK, radius: int = 40, depth: int = 0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb: StyleBoxFlat = box(color, radius, depth, Palette.shade(color, 0.4))
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 32
	sb.content_margin_bottom = 32 + depth
	p.add_theme_stylebox_override("panel", sb)
	return p


## Square icon button (pause, settings...).
static func icon_button(kind: String, color: Color = Palette.UI_DARK_SOFT, size: float = 128.0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	style_button(b, color, 40)
	for s: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(s) as StyleBoxFlat
		if sb != null:
			sb.content_margin_left = 0
			sb.content_margin_right = 0
	var icon := IconDraw.new()
	icon.kind = kind
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_bottom = -float(BUTTON_DEPTH)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	wire_press_feedback(b)
	b.add_to_group("touch_block")
	return b


static func spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
