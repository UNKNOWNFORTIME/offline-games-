extends Node3D
## Stack Skater: ride a sky-high track, widen your coin bar with pickups,
## protect it from spikes and narrow walls, then climb the x1..x10 ramp.

enum State { READY, RIDE, RAMP, WIN, FAIL }

const GAME_ID: String = "stack_skater"
const SPEED: float = 10.0
const RAMP_SPEED: float = 6.5
const DRAG_SENS: float = 0.0105
const HALF: float = SkaterLevels.TRACK_HALF
const MAX_FALLING: int = 40

var state: State = State.READY
var level_num: int = 1
var level: Dictionary = {}
var world: SkaterWorld
var skater: SkaterRig
var cam: FollowCamera
var hud: GameHud

var _x: float = 0.0
var _target_x: float = 0.0
var _z: float = 0.0
var _y: float = 0.0
var _pending_dx: float = 0.0
var _next_gate: int = 0
var _label: Label3D
var _shown: float = 0.0
var _scrape_cd: float = 0.0
var _coin_cd: float = 0.0
var _ramp_step: int = -1
var _mult: int = 1
var _stack_at_ramp: int = 0
var _fall_pool: Pool
var _autopilot: bool = false
var _pause_menu: PauseMenu = null
var _pick_streak: int = 0
var _coin_mesh: CylinderMesh
var _coin_mat: ShaderMaterial
var _streak_timer: float = 0.0


func _ready() -> void:
	level_num = maxi(1, SaveSystem.get_int(SaveSystem.game(GAME_ID), "level", 1))
	level = SkaterLevels.generate(level_num)
	EnvBuilder.build(self, "hazy_city")
	world = SkaterWorld.new()
	add_child(world)
	world.build(level, level_num * 977 + 3)

	skater = SkaterRig.new()
	add_child(skater)
	skater.build()
	skater.set_stack(4)

	_label = Label3D.new()
	_label.font = UiKit.font()
	_label.font_size = 130
	_label.outline_size = 28
	_label.pixel_size = 0.006
	_label.modulate = Palette.GOLD.lightened(0.5)
	_label.outline_modulate = Palette.shade(Palette.GOLD_SHADOW, 0.6)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.render_priority = 5
	_label.outline_render_priority = 4
	_label.position = Vector3(0, 2.5, 0)
	_label.set_meta("base_scale", 1.0)
	skater.add_child(_label)
	_shown = 4.0

	_coin_mesh = CylinderMesh.new()
	_coin_mesh.top_radius = SkaterRig.COIN_RADIUS
	_coin_mesh.bottom_radius = SkaterRig.COIN_RADIUS
	_coin_mesh.height = SkaterRig.COIN_THICK
	_coin_mesh.radial_segments = 10
	_coin_mesh.rings = 1
	_coin_mat = ShaderMaterial.new()
	_coin_mat.shader = preload("res://shaders/coin.gdshader")
	_fall_pool = Pool.new("falling_coins", _make_falling_coin, self, 24, MAX_FALLING)

	cam = FollowCamera.new()
	add_child(cam)
	cam.offset = Vector3(0, 5.2, 8.0)
	cam.look_offset = Vector3(0, 1.2, -9.0)
	cam.base_fov = 62.0
	cam.lateral_follow = 0.55
	cam.current = true
	cam.snap()

	hud = GameHud.new()
	add_child(hud)
	hud.set_level(level_num)
	hud.set_hint_text("DRAG TO STEER")
	hud.pause_pressed.connect(_open_pause)
	TouchInput.pressed.connect(_on_press)
	TouchInput.dragged.connect(_on_drag)
	AudioManager.play_music(GAME_ID)


func _make_falling_coin() -> Node:
	var mi := MeshInstance3D.new()
	mi.mesh = _coin_mesh
	mi.material_override = _coin_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _exit_tree() -> void:
	if TouchInput.pressed.is_connected(_on_press):
		TouchInput.pressed.disconnect(_on_press)
	if TouchInput.dragged.is_connected(_on_drag):
		TouchInput.dragged.disconnect(_on_drag)


func smoke_start() -> void:
	_autopilot = true
	_begin()


func _on_press(_p: Vector2) -> void:
	if state == State.READY:
		_begin()


func _on_drag(d: Vector2, _p: Vector2) -> void:
	if state == State.READY:
		_begin()
	if state == State.RIDE:
		_pending_dx += d.x


func _begin() -> void:
	if state != State.READY or get_tree().paused:
		return
	state = State.RIDE
	hud.show_hint(false)
	AdService.notify_gameplay()
	AudioManager.play("whoosh")
	Haptics.light()


# --------------------------------------------------------------- update ---

func _process(delta: float) -> void:
	_scrape_cd -= delta
	_coin_cd -= delta
	_streak_timer -= delta
	if _streak_timer <= 0.0:
		_pick_streak = 0
	match state:
		State.RIDE:
			_ride(delta)
		State.RAMP:
			_ramp(delta)
		State.WIN:
			skater.celebrating = true
	skater.position = Vector3(_x, _y, _z)
	_update_label(delta)
	cam.target = Vector3(_x, _y, _z)
	cam.zoom = lerpf(cam.zoom, 1.0 + clampf(skater.bar_half_width() - 1.5, 0.0, 3.0) * 0.12, 1.0 - exp(-2.0 * delta))
	hud.set_progress(clampf(-_z / world.length, 0.0, 1.0))


func _ride(delta: float) -> void:
	_z -= SPEED * delta
	if _autopilot:
		_autopilot_steer()
	_target_x = clampf(_target_x + _pending_dx * DRAG_SENS, -(HALF - 0.45), HALF - 0.45)
	_pending_dx = 0.0
	var prev: float = _x
	_x = lerpf(_x, _target_x, 1.0 - exp(-12.0 * delta))
	skater.set_lean(clampf((_x - prev) / maxf(delta, 0.001) * 0.25, -1.0, 1.0))
	_check_pickups()
	_check_gates()
	_check_spikes()
	_check_narrows()
	if _z <= -world.length:
		state = State.RAMP
		_stack_at_ramp = skater.stack
		_ramp_step = -1
		hud.toast("CLIMB!", Palette.GOLD)
		AudioManager.play("whoosh")
		if _stack_at_ramp <= 0:
			_fail()


func _check_pickups() -> void:
	var reach: float = skater.bar_half_width() + 0.3
	for p: Dictionary in world.pickups:
		if bool(p["taken"]):
			continue
		var pz: float = float(p["z"])
		if pz < _z - 1.0:
			continue
		if pz > _z + 0.6:
			continue
		if absf(float(p["x"]) - _x) <= reach:
			p["taken"] = true
			var amount: int = int(p["amount"])
			skater.set_stack(skater.stack + amount)
			var node: Node3D = p["node"]
			var t: Tween = node.create_tween()
			t.set_parallel(true)
			t.tween_property(node, "position", Vector3(_x, 1.1, _z - 0.6), 0.16).set_trans(Tween.TRANS_QUAD)
			t.tween_property(node, "scale", Vector3(0.2, 0.2, 0.2), 0.16)
			t.chain().tween_callback(func() -> void: node.visible = false)
			_pick_streak += 1
			_streak_timer = 1.2
			# Rising pitch on streaks: a classic satisfying collection cue.
			AudioManager.play("coin_pick", 0.0, -2.0, 0.02, 1.0 + float(mini(_pick_streak, 10)) * 0.06)
			Haptics.light()
			Juice.floating_text(node.global_position + Vector3(0, 1.6, 0), "+%d" % amount, Palette.GOLD.lightened(0.3), 1.0)
			Juice.burst(node.global_position + Vector3(0, 0.6, 0), Palette.GOLD, 0.6)
			Juice.punch_scale(_label, 0.3, 0.25)


func _check_gates() -> void:
	var gates: Array[GatePair] = world.gates
	while _next_gate < gates.size() and _z <= gates[_next_gate].z_pos:
		var g: GatePair = gates[_next_gate]
		var before: int = skater.stack
		var after: int = g.consume(0 if _x < 0.0 else 1, before)
		skater.set_stack(after)
		var diff: int = after - before
		if diff >= 0:
			AudioManager.play("gate_good", 0.04)
			Haptics.light()
			Juice.floating_text(skater.global_position + Vector3(0, 3.0, -1.0), "+%d" % diff, Palette.PLAYER_LIGHT, 1.2)
			if diff >= 8:
				cam.kick_fov(6.0)
		else:
			AudioManager.play("gate_bad", 0.04)
			Haptics.medium()
			Juice.screen_shake(0.3, 0.3)
			_drop_side_coins(-diff, 0.0)
			Juice.floating_text(skater.global_position + Vector3(0, 3.0, -1.0), "%d" % diff, Palette.ENEMY_LIGHT, 1.2)
		_next_gate += 1


## Coins beyond `edge_x` on `side` break off the bar.
func _cut(side: float, edge_x: float) -> int:
	var lost: int = _coins_beyond(side, edge_x)
	if lost <= 0:
		return 0
	_drop_side_coins(lost, side)
	skater.set_stack(skater.stack - lost)
	return lost


## How many coins of the bar on `side` lie past world X `edge_x`.
func _coins_beyond(side: float, edge_x: float) -> int:
	var per_side: int = (skater.stack + (1 if side < 0.0 else 0)) / 2
	if per_side <= 0:
		return 0
	var reach_local: float = (edge_x - _x) * side - SkaterRig.GRIP - 0.04
	var keep_cols: int = clampi(int(floorf(reach_local / SkaterRig.COIN_SPACING)), 0, SkaterRig.PER_ROW_SIDE)
	var layers: int = (per_side + SkaterRig.PER_ROW_SIDE - 1) / SkaterRig.PER_ROW_SIDE
	var lost: int = 0
	for layer: int in layers:
		var in_layer: int = mini(SkaterRig.PER_ROW_SIDE, per_side - layer * SkaterRig.PER_ROW_SIDE)
		lost += maxi(0, in_layer - keep_cols)
	return lost


func _check_spikes() -> void:
	for s: Dictionary in world.spikes:
		if _z > float(s["z0"]) + 0.3 or _z < float(s["z1"]) - 0.3:
			continue
		var side: float = float(s["side"])
		var lost: int = _cut(side, side * float(s["inner"]))
		if lost > 0:
			AudioManager.play("spike_break", 0.1)
			Haptics.medium()
			Juice.screen_shake(0.25, 0.25)
			Juice.floating_text(skater.global_position + Vector3(side * 1.5, 2.6, -0.5), "-%d" % lost, Palette.ENEMY_LIGHT, 1.0)


func _check_narrows() -> void:
	for n: Dictionary in world.narrows:
		if _z > float(n["z0"]) + 0.2 or _z < float(n["z1"]):
			continue
		var half: float = float(n["half"])
		# The skater body itself is kept inside the walls.
		_target_x = clampf(_target_x, -half + 0.45, half - 0.45)
		_x = clampf(_x, -half + 0.45, half - 0.45)
		var lost: int = _cut(1.0, half) + _cut(-1.0, -half)
		if lost > 0 and _scrape_cd <= 0.0:
			_scrape_cd = 0.12
			AudioManager.play("spike_break", 0.15, -4.0)
			Haptics.light()
			Juice.burst(skater.global_position + Vector3(half, 1.1, -0.4), Color.WHITE, 0.4)
			Juice.burst(skater.global_position + Vector3(-half, 1.1, -0.4), Color.WHITE, 0.4)


## Visual: coins tumble off the bar end(s) and fall into the fog.
func _drop_side_coins(count: int, side: float) -> void:
	var n: int = mini(count, 14)
	var top: int = skater.stack
	for i: int in n:
		var idx: int = maxi(0, top - 1 - i * 2)
		if side > 0.0 and idx % 2 == 0:
			idx = maxi(1, idx - 1)
		elif side < 0.0 and idx % 2 == 1:
			idx = maxi(0, idx - 1)
		var start: Vector3 = skater.coin_world(idx)
		var c: MeshInstance3D = _fall_pool.acquire() as MeshInstance3D
		c.global_position = start
		var dir: float = side if side != 0.0 else (-1.0 if i % 2 == 0 else 1.0)
		var vel := Vector3(dir * randf_range(2.0, 5.0), randf_range(2.0, 5.0), randf_range(-1.0, 2.0) + SPEED * 0.4)
		var spin := Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12))
		var t: Tween = c.create_tween()
		t.tween_method(_fall_step.bind(c, start, vel, spin), 0.0, 1.6, 1.6)
		t.tween_callback(_fall_pool.release.bind(c))


func _fall_step(t: float, c: MeshInstance3D, p0: Vector3, v: Vector3, spin: Vector3) -> void:
	c.global_position = p0 + v * t + Vector3(0, -14.0, 0) * (0.5 * t * t)
	c.rotation = spin * t


# ----------------------------------------------------------------- ramp ---

func _ramp(delta: float) -> void:
	_x = lerpf(_x, 0.0, 1.0 - exp(-6.0 * delta))
	skater.set_lean(0.0)
	_z -= RAMP_SPEED * delta
	var cost: int = int(level["step_cost"])
	var next: int = _ramp_step + 1
	if next < SkaterWorld.STEP_COUNT and _z <= world.step_z(next):
		if next == 0 or skater.stack >= cost:
			_ramp_step = next
			_mult = next + 1
			if next > 0:
				skater.set_stack(skater.stack - cost)
				_drop_side_coins(mini(cost, 6), 0.0)
				var pile: MeshInstance3D = world.step_piles[next]
				pile.visible = true
				pile.scale = Vector3(0.1, 0.1, 0.1)
				pile.create_tween().tween_property(pile, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			AudioManager.play("coin_pick", 0.0, -1.0, 0.0)
			Haptics.light()
			Juice.floating_text(Vector3(0, world.step_top(next) + 2.6, world.step_z(next) - 1.0), "×%d" % _mult, Palette.GOLD.lightened(0.3), 1.4)
			cam.kick_fov(2.0)
			if _mult == SkaterWorld.STEP_COUNT:
				_finish()
				return
		else:
			_finish()
			return
	# Hop up onto the current step.
	var target_y: float = world.step_top(_ramp_step) if _ramp_step >= 0 else 0.0
	_y = lerpf(_y, target_y, 1.0 - exp(-14.0 * delta))


func _finish() -> void:
	if state == State.WIN or state == State.FAIL:
		return
	state = State.WIN
	skater.set_lean(0.0)
	Juice.screen_shake(0.3, 0.3)
	Haptics.heavy()
	var coins: int = 10 + int(float(_stack_at_ramp) * float(_mult) * 0.35)
	var save: Dictionary = SaveSystem.game(GAME_ID)
	save["level"] = level_num + 1
	save["best_level"] = maxi(SaveSystem.get_int(save, "best_level", 1), level_num + 1)
	var stats: Dictionary = SaveSystem.data["stats"]
	stats["levels_completed"] = int(stats.get("levels_completed", 0)) + 1
	SaveSystem.save_game()
	cam.offset = Vector3(3.5, 3.5, 6.0)
	await get_tree().create_timer(1.3).timeout
	var es := EndScreen.new()
	add_child(es)
	es.open(true, coins, "×%d multiplier!" % _mult)
	es.next_pressed.connect(_next_level)


func _fail() -> void:
	if state == State.WIN or state == State.FAIL:
		return
	state = State.FAIL
	Haptics.heavy()
	await get_tree().create_timer(0.8).timeout
	var es := EndScreen.new()
	add_child(es)
	es.open(false, 3, "No coins left!")
	es.retry_pressed.connect(GameState.reload)
	es.home_pressed.connect(GameState.go_hub)


func _next_level() -> void:
	if AdService.should_show_interstitial(level_num):
		await AdService.show_interstitial()
	GameState.reload()


func _update_label(delta: float) -> void:
	_shown = Juice.tick_number(_shown, float(skater.stack), delta, 12.0)
	_label.text = str(int(_shown))
	_label.position.y = 2.4 + float(skater.stack / (SkaterRig.PER_ROW_SIDE * 2)) * 0.42


# ------------------------------------------------------------- autopilot ---

func _autopilot_steer() -> void:
	var goal: float = 0.0
	var best_d: float = 25.0
	for p: Dictionary in world.pickups:
		var dz: float = _z - float(p["z"])
		if not bool(p["taken"]) and dz > 0.0 and dz < best_d:
			best_d = dz
			goal = float(p["x"])
	for s: Dictionary in world.spikes:
		var dz: float = _z - float(s["z0"])
		if dz > -5.0 and dz < 12.0:
			goal = -float(s["side"]) * 1.6
	var gates: Array[GatePair] = world.gates
	if _next_gate < gates.size() and _z - gates[_next_gate].z_pos < 14.0:
		var g: GatePair = gates[_next_gate]
		var l: int = GatePair.apply(g.ops[0], skater.stack)
		var r: int = GatePair.apply(g.ops[1], skater.stack)
		goal = g.side_center_x(0 if l >= r else 1) * 0.6
	_target_x = goal


func _open_pause() -> void:
	if _pause_menu != null or state == State.WIN or state == State.FAIL:
		return
	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)
	_pause_menu.resumed.connect(func() -> void: _pause_menu = null)
	_pause_menu.restart_requested.connect(GameState.reload)
	_pause_menu.home_requested.connect(GameState.go_hub)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if state == State.RIDE or state == State.RAMP:
			_open_pause()
