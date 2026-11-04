class_name OvertakeGarage
extends CanvasLayer
## Between-runs screen: run results (distance, earnings, x3 ad) and the three
## upgrade cards side by side (Stamina / Power / Income), then DRIVE.

signal drive_pressed
signal home_pressed

const UPGRADES: Array = [
	{"key": "stamina", "name": "STAMINA", "icon": "bolt", "base": 35, "color": Color("#36D399")},
	{"key": "power", "name": "POWER", "icon": "power", "base": 45, "color": Color("#FF3B3B")},
	{"key": "income", "name": "INCOME", "icon": "income", "base": 50, "color": Color("#FFC531")},
]

var _root: Control
var _cards: Array[Dictionary] = []
var _earned: int = 0
var _bonus_claimed: bool = false


static func upgrades() -> Dictionary:
	var g: Dictionary = SaveSystem.game("overtake")
	if not g.has("upgrades"):
		g["upgrades"] = {"stamina": 0, "power": 0, "income": 0}
	return g["upgrades"]


static func level_of(key: String) -> int:
	return int(upgrades().get(key, 0))


static func cost_of(key: String) -> int:
	for u: Dictionary in UPGRADES:
		if str(u["key"]) == key:
			return Economy.upgrade_cost(int(u["base"]), level_of(key), 1.15)
	return 999999


static func stamina_max(l: int) -> float:
	return 2.0 + 0.45 * float(l)


static func top_speed_mph(l: int) -> float:
	return 80.0 + 5.0 * float(l)


static func income_mult(l: int) -> float:
	return 1.0 + 0.2 * float(l)


static func effect_text(key: String, l: int) -> String:
	match key:
		"stamina":
			return "%.1fs" % stamina_max(l)
		"power":
			return "%d mph" % int(top_speed_mph(l))
	return "x%.1f" % income_mult(l)


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("end_screen_like")


## results: {} for the first visit, else {distance, earned, best, new_best}.
func open(results: Dictionary) -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_to_group("touch_block")
	add_child(_root)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(Palette.UI_DARK, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	var safe := SafeArea.new()
	_root.add_child(safe)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)
	safe.add_child(col)

	var top := HBoxContainer.new()
	col.add_child(top)
	var home: Button = UiKit.icon_button("home", Color(Palette.UI_DARK_SOFT, 0.9), 124)
	home.pressed.connect(func() -> void: home_pressed.emit())
	top.add_child(home)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(fill)
	top.add_child(CoinPill.new())

	if results.is_empty():
		col.add_child(UiKit.label("OVERTAKE", 120, Color.WHITE, 16))
		col.add_child(UiKit.label("Swipe to change lanes  -  hold to boost\nNear misses pay!", 40, Palette.PLAYER_LIGHT, 6))
	else:
		_earned = int(results.get("earned", 0))
		var head: Label = UiKit.label("NEW BEST!" if bool(results.get("new_best", false)) else "CRASHED!", 120, Palette.GOLD if bool(results.get("new_best", false)) else Color.WHITE, 16)
		col.add_child(head)
		Juice.punch_scale(head, 0.3, 0.5)
		var card: PanelContainer = UiKit.panel(Color(Palette.UI_DARK, 0.85), 44)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.custom_minimum_size = Vector2(820, 0)
		col.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 10)
		card.add_child(v)
		v.add_child(UiKit.label("%.2f km   (best %.2f km)" % [float(results.get("distance", 0.0)) / 1000.0, float(results.get("best", 0.0)) / 1000.0], 46, Color.WHITE, 6))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 18)
		v.add_child(row)
		var ic := IconDraw.new()
		ic.kind = "coin"
		ic.custom_minimum_size = Vector2(90, 90)
		row.add_child(ic)
		var earned_l: Label = UiKit.label("+%d" % _earned, 84, Palette.GOLD, 10)
		row.add_child(earned_l)
		if _earned > 0:
			var x3: Button = UiKit.button("x3  (AD)", Palette.GOLD, 46, Vector2(300, 120), Palette.UI_DARK)
			row.add_child(x3)
			x3.disabled = not AdService.is_rewarded_ready()
			x3.pressed.connect(func() -> void:
				if _bonus_claimed:
					return
				_bonus_claimed = true
				x3.disabled = true
				AdService.show_rewarded(func(ok: bool) -> void:
					if ok:
						Economy.add(_earned * 2, "overtake_x3")
						earned_l.text = "+%d" % (_earned * 3)
						Juice.punch_scale(earned_l, 0.4, 0.4)
						AudioManager.play("coin_pick")))

	col.add_child(UiKit.spacer(6))
	col.add_child(UiKit.label("UPGRADES", 50, Palette.UI_MUTED, 6))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 20)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(cards)
	for u: Dictionary in UPGRADES:
		cards.add_child(_make_card(u))
	_refresh()
	Economy.coins_changed.connect(_on_coins_changed)

	var spring := Control.new()
	spring.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spring)
	var drive: Button = UiKit.button("DRIVE", Palette.UI_ACCENT, 84, Vector2(700, 190))
	drive.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(drive)
	var t: Tween = drive.create_tween().set_loops()
	t.tween_property(drive, "scale", Vector2(1.05, 1.05), 0.45).set_trans(Tween.TRANS_SINE)
	t.tween_property(drive, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	drive.resized.connect(func() -> void: drive.pivot_offset = drive.size * 0.5)
	drive.pressed.connect(_on_drive)
	col.add_child(UiKit.spacer(30))

	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.25)


func _make_card(u: Dictionary) -> Control:
	var accent: Color = u["color"]
	var card := PanelContainer.new()
	var sb: StyleBoxFlat = UiKit.box(Color.WHITE, 36, 14, Palette.shade(accent, 0.3))
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 18
	sb.content_margin_bottom = 26
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(310, 470)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(v)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiKit.box(accent, 60))
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(badge)
	var ic := IconDraw.new()
	ic.kind = str(u["icon"])
	ic.color = Color.WHITE
	ic.custom_minimum_size = Vector2(110, 110)
	badge.add_child(ic)
	var name_l: Label = UiKit.label(str(u["name"]), 44, Palette.UI_DARK, 0)
	name_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	v.add_child(name_l)
	var lvl_l: Label = UiKit.label("", 34, Palette.UI_MUTED, 0)
	lvl_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	v.add_child(lvl_l)
	var eff_l: Label = UiKit.label("", 52, accent.darkened(0.25), 0)
	eff_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	v.add_child(eff_l)
	var buy: Button = UiKit.button("", Palette.UI_ACCENT, 44, Vector2(270, 120))
	v.add_child(buy)
	var coin := IconDraw.new()
	coin.kind = "coin"
	coin.position = Vector2(12, 22)
	coin.size = Vector2(56, 56)
	buy.add_child(coin)
	var key: String = str(u["key"])
	buy.pressed.connect(func() -> void:
		var cost: int = cost_of(key)
		if Economy.spend(cost):
			upgrades()[key] = level_of(key) + 1
			SaveSystem.save_game()
			AudioManager.play("pickup")
			Haptics.medium()
			Juice.punch_scale(card, 0.1, 0.35)
			_refresh())
	_cards.append({"key": key, "lvl": lvl_l, "eff": eff_l, "buy": buy})
	return card


func _on_coins_changed(_total: int, _delta: int) -> void:
	_refresh()


func _refresh() -> void:
	for c: Dictionary in _cards:
		var key: String = str(c["key"])
		var l: int = level_of(key)
		(c["lvl"] as Label).text = "LV %d" % (l + 1)
		(c["eff"] as Label).text = effect_text(key, l)
		var b: Button = c["buy"]
		var cost: int = cost_of(key)
		b.text = "  " + Economy.format(cost)
		b.disabled = not Economy.can_afford(cost)


func _on_drive() -> void:
	var t: Tween = create_tween()
	t.tween_property(_root, "modulate:a", 0.0, 0.2)
	t.tween_callback(func() -> void:
		drive_pressed.emit()
		queue_free())
