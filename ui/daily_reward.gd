class_name DailyReward
extends CanvasLayer
## 7-day streak calendar (GAME_SPEC 8). Claim once per local calendar day;
## missing a day resets the streak to day 1. Day 7 is the big chest.

signal closed

const REWARDS: Array = [50, 75, 100, 150, 200, 300, 500]

var _root: Control


## Local day number (days since epoch in the device's time zone).
static func today() -> int:
	var bias_min: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return int(floorf((Time.get_unix_time_from_system() + float(bias_min) * 60.0) / 86400.0))


static func _data() -> Dictionary:
	var d: Dictionary = SaveSystem.data["daily"]
	return d


static func can_claim() -> bool:
	return int(_data().get("last_day", -1)) != today()


## Index (0..6) of the day that would be claimed now.
static func next_index() -> int:
	var d: Dictionary = _data()
	var last: int = int(d.get("last_day", -1))
	var streak: int = int(d.get("streak", 0))
	if last == today():
		return (streak - 1) % 7
	if last != today() - 1:
		streak = 0
	return streak % 7


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_to_group("touch_block")
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var card: PanelContainer = UiKit.panel(Palette.UI_DARK, 56, 16)
	card.custom_minimum_size = Vector2(960, 0)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	card.add_child(col)
	col.add_child(UiKit.label("DAILY REWARD", 84, Palette.GOLD, 12))
	var claimable: bool = can_claim()
	var idx: int = next_index()
	col.add_child(UiKit.label("Come back every day - miss one and the streak resets!", 34, Palette.UI_MUTED, 0))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(grid)
	for i: int in 7:
		grid.add_child(_day_tile(i, idx, claimable))
	var btn: Button = UiKit.button("CLAIM" if claimable else "COME BACK TOMORROW", Palette.UI_ACCENT if claimable else Palette.UI_MUTED, 60 if claimable else 44, Vector2(640, 160))
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.disabled = not claimable
	col.add_child(btn)
	btn.pressed.connect(func() -> void:
		btn.disabled = true
		_claim())
	var later: Button = UiKit.link("Close", 44)
	later.pressed.connect(_close)
	col.add_child(later)
	card.pivot_offset = card.custom_minimum_size * 0.5
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "modulate:a", 1.0, 0.15)


func _day_tile(i: int, idx: int, claimable: bool) -> Control:
	var done: bool = i < idx or (not claimable and i == idx)
	var current: bool = i == idx and claimable
	var color: Color = Palette.UI_DARK_SOFT
	if done:
		color = Palette.UI_ACCENT.darkened(0.35)
	elif current:
		color = Palette.GOLD_SHADOW
	var tile := PanelContainer.new()
	var sb: StyleBoxFlat = UiKit.box(color, 28, 10, Palette.shade(color, 0.35))
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	tile.add_theme_stylebox_override("panel", sb)
	tile.custom_minimum_size = Vector2(196 if i < 6 else 196, 210)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	tile.add_child(v)
	v.add_child(UiKit.label("DAY %d" % (i + 1), 34, Color.WHITE, 6))
	var ic := IconDraw.new()
	ic.kind = "star" if done or i == 6 else "coin"
	ic.color = Color.WHITE if done else Palette.GOLD
	ic.custom_minimum_size = Vector2(84, 84)
	v.add_child(ic)
	v.add_child(UiKit.label(str(REWARDS[i]), 40, Palette.GOLD if not done else Color(1, 1, 1, 0.7), 6))
	if current:
		var t: Tween = tile.create_tween().set_loops()
		t.tween_property(tile, "scale", Vector2(1.06, 1.06), 0.5).set_trans(Tween.TRANS_SINE)
		t.tween_property(tile, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
		tile.resized.connect(func() -> void: tile.pivot_offset = tile.size * 0.5)
	return tile


func _claim() -> void:
	if not can_claim():
		return
	var idx: int = next_index()
	var d: Dictionary = _data()
	d["streak"] = idx + 1
	d["last_day"] = today()
	var amount: int = int(REWARDS[idx])
	Economy.add(amount, "daily")
	SaveSystem.save_game()
	AudioManager.play("win")
	Haptics.heavy()
	Confetti.spawn(_root)
	await get_tree().create_timer(1.2).timeout
	_close()


func _close() -> void:
	var t: Tween = create_tween()
	t.tween_property(_root, "modulate:a", 0.0, 0.15)
	await t.finished
	closed.emit()
	queue_free()
