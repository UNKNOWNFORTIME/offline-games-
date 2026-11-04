extends Control
## Hub: game cards, coin balance, settings. Also runs the first-launch
## performance probe that auto-picks Low quality on slow devices.

const PROBE_SECONDS: float = 5.0
const PROBE_SLOW_MS: float = 25.0

var _probe_time: float = 0.0
var _probe_frames: int = 0
var _probing: bool = false
var _title: Label
var _gift_dot: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(HubBackground.new())
	var safe := SafeArea.new()
	add_child(safe)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	safe.add_child(col)

	var top := HBoxContainer.new()
	col.add_child(top)
	var gear: Button = UiKit.icon_button("gear", Palette.UI_DARK_SOFT, 128)
	gear.pressed.connect(_open_settings)
	top.add_child(gear)
	var gift: Button = UiKit.icon_button("gift", Palette.GOLD_SHADOW, 128)
	gift.pressed.connect(_open_daily)
	top.add_child(gift)
	_gift_dot = Control.new()
	_gift_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gift_dot.position = Vector2(100, 4)
	_gift_dot.size = Vector2(30, 30)
	_gift_dot.draw.connect(func() -> void:
		_gift_dot.draw_circle(Vector2(15, 15), 15, Palette.ENEMY)
		_gift_dot.draw_circle(Vector2(15, 15), 15, Color.WHITE, false, 4.0, true))
	gift.add_child(_gift_dot)
	_gift_dot.visible = DailyReward.can_claim()
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(fill)
	top.add_child(CoinPill.new())

	_title = UiKit.label(AppInfo.GAME_NAME.to_upper(), 132, Color.WHITE, 18)
	_title.add_theme_color_override("font_outline_color", Palette.shade(Palette.PLAYER, 0.5))
	col.add_child(_title)
	_title.resized.connect(func() -> void: _title.pivot_offset = _title.size * 0.5)
	var tt: Tween = _title.create_tween().set_loops()
	tt.tween_property(_title, "rotation", 0.025, 1.2).set_trans(Tween.TRANS_SINE)
	tt.tween_property(_title, "rotation", -0.025, 1.2).set_trans(Tween.TRANS_SINE)
	var sub: Label = UiKit.label("Pick a game", 44, Palette.PLAYER_LIGHT, 6)
	col.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 24
	col.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	pad.add_theme_constant_override("margin_top", 16)
	pad.add_theme_constant_override("margin_bottom", 60)
	scroll.add_child(pad)
	var cards := VBoxContainer.new()
	cards.add_theme_constant_override("separation", 44)
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(cards)
	var i: int = 0
	for g: Dictionary in AppInfo.GAMES:
		var card := GameCard.new()
		card.setup(g)
		card.play_requested.connect(_play)
		cards.add_child(card)
		card.modulate.a = 0.0
		var t: Tween = card.create_tween()
		t.tween_interval(0.08 + 0.09 * float(i))
		t.tween_property(card, "modulate:a", 1.0, 0.25)
		i += 1

	AudioManager.play_music("hub")
	_probing = not Settings.quality_checked()
	# Title drops in (doubles as the animated splash after the boot screen).
	_title.modulate.a = 0.0
	var tw: Tween = _title.create_tween().set_parallel(true)
	tw.tween_property(_title, "modulate:a", 1.0, 0.3)
	if DailyReward.can_claim() and not OS.get_cmdline_user_args().has("--smoke"):
		await get_tree().create_timer(0.7).timeout
		_open_daily()


func _play(id: String) -> void:
	Haptics.medium()
	GameState.start_game(id)


func _open_daily() -> void:
	var d := DailyReward.new()
	add_child(d)
	d.closed.connect(func() -> void: _gift_dot.visible = DailyReward.can_claim())


func _open_settings() -> void:
	var panel := SettingsPanel.new()
	add_child(panel)


func _process(delta: float) -> void:
	if not _probing:
		return
	_probe_time += delta
	if _probe_time < 0.5:
		return  # ignore load hitches
	_probe_frames += 1
	if _probe_time >= PROBE_SECONDS + 0.5:
		_probing = false
		var avg_ms: float = (_probe_time - 0.5) / float(maxi(_probe_frames, 1)) * 1000.0
		Settings.mark_quality_checked()
		if avg_ms > PROBE_SLOW_MS:
			Settings.set_quality(false)
			print("Quality probe: %.1f ms avg -> LOW" % avg_ms)
		else:
			print("Quality probe: %.1f ms avg -> keep HIGH" % avg_ms)
