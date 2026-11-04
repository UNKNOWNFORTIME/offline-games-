class_name EndScreen
extends CanvasLayer
## Shared end-of-level screen (GAME_SPEC 4.1 / 5.7):
## banner drops in with overshoot, coins count up, big rewarded "x3" button,
## "No thanks" link after 1.5 s; flying coins into the coin pill on collect.
## Fail variant: RETRY + Hub.

signal next_pressed
signal retry_pressed
signal home_pressed
signal revive_granted

var _root: Control
var _dim: ColorRect
var _banner: Control
var _coin_label: Label
var _coin_icon: IconDraw
var _coins: int = 0
var _shown_coins: float = 0.0
var _counting: bool = false
var _collected: bool = false
var _buttons: VBoxContainer
var _col: VBoxContainer
var _upgrade_refresh: Callable = Callable()
var _tick_cd: float = 0.0


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("end_screen")


## win: show success layout. coins: reward before multipliers.
## subtitle: small line under the banner (e.g. "Boss defeated!").
func open(win: bool, coins: int, subtitle: String = "") -> void:
	_coins = coins
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_to_group("touch_block")
	add_child(_root)

	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(Palette.UI_DARK, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)
	create_tween().tween_property(_dim, "color:a", 0.55, 0.3)

	var safe := SafeArea.new()
	_root.add_child(safe)
	var col := VBoxContainer.new()
	_col = col
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 34)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(col)

	# Banner ribbon.
	_banner = _make_banner(win)
	col.add_child(_banner)
	if subtitle != "":
		var sub: Label = UiKit.label(subtitle, 52, Color(1, 1, 1, 0.92), 8)
		col.add_child(sub)

	# Coin card.
	var card: PanelContainer = UiKit.panel(Color(Palette.UI_DARK, 0.85), 48)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.custom_minimum_size = Vector2(620, 0)
	col.add_child(card)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 22)
	card.add_child(h)
	_coin_icon = IconDraw.new()
	_coin_icon.kind = "coin"
	_coin_icon.spin = true
	_coin_icon.custom_minimum_size = Vector2(130, 130)
	h.add_child(_coin_icon)
	_coin_label = UiKit.label("+0", 104, Palette.GOLD, 12)
	_coin_label.custom_minimum_size = Vector2(300, 0)
	h.add_child(_coin_label)

	col.add_child(UiKit.spacer(30))
	_buttons = VBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 26)
	_buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_buttons)

	if win:
		_build_win_buttons()
		Confetti.spawn(_root)
		AudioManager.play("win")
		Haptics.heavy()
	else:
		_build_fail_buttons()
		AudioManager.play("fail")
		Haptics.medium()

	# Count-up starts after the banner lands.
	var t: Tween = create_tween()
	t.tween_interval(0.45)
	t.tween_callback(func() -> void: _counting = true)


func _make_banner(win: bool) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 240)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ribbon := PanelContainer.new()
	var color: Color = Palette.UI_ACCENT if win else Palette.ENEMY
	var sb: StyleBoxFlat = UiKit.box(color, 36, 18, Palette.shade(color, 0.35))
	sb.skew = Vector2(-0.08, 0)
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	ribbon.add_theme_stylebox_override("panel", sb)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: Label = UiKit.label("LEVEL COMPLETE!" if win else "FAILED", 78 if win else 120, Color.WHITE, 14)
	ribbon.add_child(l)
	holder.add_child(ribbon)
	# Drop-in with overshoot.
	ribbon.modulate.a = 0.0
	ribbon.rotation = -0.12 if win else 0.08
	ribbon.position.y = -700.0
	var t: Tween = ribbon.create_tween()
	t.set_parallel(true)
	t.tween_property(ribbon, "position:y", 16.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(ribbon, "modulate:a", 1.0, 0.2)
	t.tween_property(ribbon, "rotation", -0.03 if win else 0.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var center_x: Callable = func() -> void:
		ribbon.pivot_offset = ribbon.size * 0.5
		ribbon.position.x = (holder.size.x - ribbon.size.x) * 0.5
	ribbon.resized.connect(center_x)
	holder.resized.connect(center_x)
	return holder


func _build_win_buttons() -> void:
	var x3: Button = UiKit.button("  x3 COINS", Palette.GOLD, 70, Vector2(680, 170), Palette.UI_DARK)
	var ad_icon := IconDraw.new()
	ad_icon.kind = "ad"
	ad_icon.color = Palette.UI_DARK
	ad_icon.custom_minimum_size = Vector2(90, 90)
	ad_icon.position = Vector2(46, 30)
	ad_icon.size = Vector2(90, 90)
	x3.add_child(ad_icon)
	_buttons.add_child(x3)
	_pulse(x3)
	x3.disabled = not AdService.is_rewarded_ready()
	var no_thanks: Button = UiKit.link("No thanks", 48)
	no_thanks.modulate.a = 0.0
	no_thanks.disabled = true
	_buttons.add_child(no_thanks)
	var t: Tween = create_tween()
	t.tween_interval(1.5)
	t.tween_callback(func() -> void: no_thanks.disabled = false)
	t.tween_property(no_thanks, "modulate:a", 1.0, 0.3)

	x3.pressed.connect(_on_x3.bind(x3, no_thanks))
	no_thanks.pressed.connect(_on_no_thanks.bind(x3, no_thanks))


func _on_x3(x3: Button, no_thanks: Button) -> void:
	if _collected:
		return
	_collected = true
	x3.disabled = true
	no_thanks.disabled = true
	AdService.show_rewarded(_on_rewarded)


func _on_rewarded(ok: bool) -> void:
	_collect(_coins * 3 if ok else _coins)


func _on_no_thanks(x3: Button, no_thanks: Button) -> void:
	if _collected:
		return
	_collected = true
	x3.disabled = true
	no_thanks.disabled = true
	_collect(_coins)


## Fail screen: big rewarded REVIVE button above RETRY (once per level).
func add_revive() -> void:
	var rv: Button = UiKit.button("  REVIVE", Palette.GOLD, 72, Vector2(680, 170), Palette.UI_DARK)
	var ad_icon := IconDraw.new()
	ad_icon.kind = "ad"
	ad_icon.color = Palette.UI_DARK
	ad_icon.position = Vector2(60, 30)
	ad_icon.size = Vector2(90, 90)
	rv.add_child(ad_icon)
	_buttons.add_child(rv)
	_buttons.move_child(rv, 0)
	_pulse(rv)
	rv.disabled = not AdService.is_rewarded_ready()
	rv.pressed.connect(func() -> void:
		if _collected:
			return
		rv.disabled = true
		AdService.show_rewarded(_on_revive_ad))


func _on_revive_ad(ok: bool) -> void:
	if not ok or _collected:
		return
	_collected = true
	revive_granted.emit()
	var t: Tween = create_tween()
	t.tween_property(_root, "modulate:a", 0.0, 0.2)
	t.tween_callback(queue_free)


## Small upgrade card under the buttons. title_fn() -> String, cost_fn() -> int,
## buy_fn() performs the upgrade after coins were spent.
func add_upgrade(title_fn: Callable, cost_fn: Callable, buy_fn: Callable) -> void:
	var card: PanelContainer = UiKit.panel(Color(Palette.UI_DARK, 0.85), 40)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.custom_minimum_size = Vector2(760, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	card.add_child(row)
	var l: Label = UiKit.label(str(title_fn.call()), 44, Color.WHITE, 6)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	var buy: Button = UiKit.button("", Palette.UI_ACCENT, 46, Vector2(260, 120))
	row.add_child(buy)
	var refresh: Callable = func() -> void:
		var cost: int = int(cost_fn.call())
		l.text = str(title_fn.call())
		buy.text = "%s" % Economy.format(cost)
		buy.disabled = not Economy.can_afford(cost)
	refresh.call()
	_upgrade_refresh = refresh
	Economy.coins_changed.connect(_on_coins_changed)
	buy.pressed.connect(func() -> void:
		var cost: int = int(cost_fn.call())
		if Economy.spend(cost):
			buy_fn.call()
			AudioManager.play("pickup")
			Haptics.medium()
			Juice.punch_scale(card, 0.12, 0.3)
			refresh.call())
	var coin := IconDraw.new()
	coin.kind = "coin"
	coin.position = Vector2(14, 24)
	coin.size = Vector2(56, 56)
	buy.add_child(coin)
	_col.add_child(card)


func _on_coins_changed(_total: int, _delta: int) -> void:
	if _upgrade_refresh.is_valid():
		_upgrade_refresh.call()


func _build_fail_buttons() -> void:
	var retry: Button = UiKit.button("RETRY", Palette.UI_ACCENT, 72, Vector2(620, 170))
	_buttons.add_child(retry)
	_pulse(retry)
	var home: Button = UiKit.link("Back to games", 46)
	_buttons.add_child(home)
	retry.pressed.connect(func() -> void:
		if _collected:
			return
		_collected = true
		_award(_coins)
		retry_pressed.emit())
	home.pressed.connect(func() -> void:
		if _collected:
			return
		_collected = true
		_award(_coins)
		home_pressed.emit())


func _collect(amount: int) -> void:
	_coins = amount
	_counting = true
	Juice.punch_scale(_coin_label, 0.35, 0.4)
	await _fly_coins(amount)
	next_pressed.emit()


func _award(amount: int) -> void:
	if amount > 0:
		Economy.add(amount, "level_end")


## Coins fly along a curve from the card to the coin pill, then the balance
## ticks up. Spec 5.6 "coin flies toward the UI counter".
func _fly_coins(amount: int) -> void:
	var target: Vector2 = Vector2(get_viewport().get_visible_rect().size.x - 120.0, 120.0)
	var pills: Array[Node] = get_tree().get_nodes_in_group("coin_target")
	for n: Node in pills:
		var pill: CoinPill = n as CoinPill
		if pill != null and pill.is_visible_in_tree():
			target = pill.icon_global_center()
	var start: Vector2 = _coin_icon.global_position + _coin_icon.size * 0.5
	var count: int = 10
	var each: int = amount / count
	var remainder: int = amount - each * count
	var last_tween: Tween = null
	for i: int in count:
		var c := IconDraw.new()
		c.kind = "coin"
		c.size = Vector2(90, 90)
		c.position = start - c.size * 0.5
		_root.add_child(c)
		var mid: Vector2 = start.lerp(target, 0.5) + Vector2(randf_range(-320, 320), randf_range(-200, 120))
		var award: int = each + (remainder if i == count - 1 else 0)
		var t: Tween = c.create_tween()
		t.tween_interval(float(i) * 0.06)
		t.tween_method(_coin_path.bind(c, start, mid, target), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_callback(_coin_arrived.bind(c, award))
		last_tween = t
	if last_tween != null:
		await last_tween.finished
	await get_tree().create_timer(0.35).timeout


func _coin_path(k: float, c: Control, a: Vector2, m: Vector2, b: Vector2) -> void:
	var p: Vector2 = a.lerp(m, k).lerp(m.lerp(b, k), k)
	c.position = p - c.size * 0.5
	c.scale = Vector2.ONE * lerpf(1.0, 0.6, k)


func _coin_arrived(c: Control, award: int) -> void:
	if award > 0:
		Economy.add(award, "level_end")
	AudioManager.play("coin_pick", 0.08, -4.0, 0.02)
	Haptics.light()
	c.queue_free()


func _pulse(c: Control) -> void:
	var t: Tween = c.create_tween().set_loops()
	t.tween_property(c, "scale", Vector2(1.05, 1.05), 0.45).set_trans(Tween.TRANS_SINE)
	t.tween_property(c, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	c.resized.connect(func() -> void: c.pivot_offset = c.size * 0.5)


func _process(delta: float) -> void:
	if _counting and _coin_label != null:
		var target: float = float(_coins)
		if _shown_coins != target:
			_shown_coins = Juice.tick_number(_shown_coins, target, delta, 5.0)
			_coin_label.text = "+" + Economy.format(int(_shown_coins))
			_tick_cd -= delta
			if _tick_cd <= 0.0:
				AudioManager.play("coin_count_tick", 0.05, -4.0, 0.04)
				_tick_cd = 0.05
