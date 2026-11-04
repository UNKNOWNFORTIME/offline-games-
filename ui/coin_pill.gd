class_name CoinPill
extends PanelContainer
## Coin balance pill (top-right everywhere). Ticks toward the real balance
## instead of jumping, and punches when it grows. Registers itself in the
## group "coin_target" so flying coins know where to go.

var _label: Label
var _icon: IconDraw
var _shown: float = 0.0
var _target: float = 0.0
var _tick_cooldown: float = 0.0


func _init() -> void:
	var sb: StyleBoxFlat = UiKit.box(Color(Palette.UI_DARK, 0.72), 60)
	sb.content_margin_left = 18
	sb.content_margin_right = 36
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	add_theme_stylebox_override("panel", sb)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(h)
	_icon = IconDraw.new()
	_icon.kind = "coin"
	_icon.custom_minimum_size = Vector2(84, 84)
	h.add_child(_icon)
	_label = UiKit.label("0", 58, Color.WHITE, 8)
	_label.custom_minimum_size = Vector2(150, 0)
	h.add_child(_label)


func _ready() -> void:
	add_to_group("coin_target")
	_shown = float(Economy.coins)
	_target = _shown
	_label.text = Economy.format(int(_shown))
	Economy.coins_changed.connect(_on_coins)


func icon_global_center() -> Vector2:
	return _icon.global_position + _icon.size * 0.5


func _on_coins(total: int, delta: int) -> void:
	_target = float(total)
	if delta > 0:
		Juice.punch_scale(_icon, 0.25, 0.3)


func _process(delta: float) -> void:
	if _shown != _target:
		var before: int = int(_shown)
		_shown = Juice.tick_number(_shown, _target, delta, 6.0)
		_label.text = Economy.format(int(_shown))
		_tick_cooldown -= delta
		if int(_shown) != before and _tick_cooldown <= 0.0 and _target > _shown - 1.0:
			AudioManager.play("coin_count_tick", 0.06, -6.0, 0.05)
			_tick_cooldown = 0.06
