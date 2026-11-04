extends Node3D
## Overtake: weave an open-wheel racer through two-way highway traffic.
## Swipe = change lane (0.18 s, with tilt). Hold = boost (drains stamina).
## Near misses pay coins; a crash ends the run -> garage upgrades -> drive.

enum State { GARAGE, READY, DRIVE, CRASH }

const GAME_ID: String = "overtake"
const LANES: Array = [-2.6, 0.0, 2.6]   # lane 0 = oncoming traffic
const LANE_TIME: float = 0.18
const MPH: float = 0.44704
const POOL_SIZE: int = 16
const SPAWN_AHEAD: float = 165.0
const NEAR_MISS_DX: float = 3.1
const BOOST_MULT: float = 1.32


class TrafficCar:
	extends RefCounted
	var node: MeshInstance3D
	var active: bool = false
	var lane: int = 1
	var z: float = 0.0
	var speed: float = 20.0
	var half_len: float = 2.2
	var half_w: float = 0.9
	var passed: bool = false


var state: State = State.GARAGE
var road: OvertakeRoad
var car: Node3D
var cam: FollowCamera
var hud: GameHud
var light: DirectionalLight3D

var _lane: int = 1
var _x: float = 0.0
var _z: float = 0.0
var _speed: float = 0.0
var _stamina: float = 0.0
var _boosting: bool = false
var _distance: float = 0.0
var _earned_f: float = 0.0
var _combo: int = 0
var _combo_timer: float = 0.0
var _spawn_timer: float = 0.0
var _lane_tween: Tween
var _cars: Array[TrafficCar] = []
var _wheels: Array[Node] = []
var _kinds: Array[Dictionary] = []
var _speed_lines: ColorRect
var _speed_mat: ShaderMaterial
var _flash: float = 0.0
var _speed_label: Label
var _stamina_bar: Control
var _earn_label: Label
var _orbit: float = 0.0
var _run: int = 1
var _rng := RandomNumberGenerator.new()
var _autopilot: bool = false
var _pause_menu: PauseMenu = null
var _lane_last_spawn: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0])

# Upgrade-derived stats for this run.
var _top_speed: float = 35.0
var _stamina_max: float = 2.0
var _income: float = 1.0


func _ready() -> void:
	_rng.seed = Time.get_ticks_usec()
	_run = maxi(1, SaveSystem.get_int(SaveSystem.game(GAME_ID), "level", 1))
	light = EnvBuilder.build(self, "sunny")
	road = OvertakeRoad.new()
	add_child(road)
	road.build(4242)

	car = VehicleFactory.player_car()
	add_child(car)
	_wheels = []
	_collect_wheels(car)
	if Settings.shadows_enabled():
		for c: Node in car.get_children():
			if c is GeometryInstance3D:
				(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# Pre-bake every traffic variant now so spawning never allocates.
	var kinds: Array = [VehicleFactory.Kind.SEDAN, VehicleFactory.Kind.SEDAN, VehicleFactory.Kind.VAN, VehicleFactory.Kind.TRUCK, VehicleFactory.Kind.PICKUP]
	for k: Variant in kinds:
		for ci: int in 6:
			_kinds.append(VehicleFactory.traffic_baked(k as VehicleFactory.Kind, VehicleFactory.TRAFFIC_COLORS[ci] as Color))
	for i: int in POOL_SIZE:
		var tc := TrafficCar.new()
		tc.node = MeshInstance3D.new()
		tc.node.material_override = VehicleFactory.baked_material()
		tc.node.visible = false
		tc.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tc.node)
		_cars.append(tc)

	cam = FollowCamera.new()
	add_child(cam)
	cam.offset = Vector3(0, 3.0, 7.2)
	cam.look_offset = Vector3(0, 0.9, -12.0)
	cam.base_fov = 64.0
	cam.lateral_follow = 0.6
	cam.follow_speed = 9.0
	cam.current = true

	_build_hud()
	TouchInput.swiped.connect(_on_swipe)
	TouchInput.tapped.connect(_on_tap)
	AudioManager.play_music(GAME_ID)
	_reset_run()
	_open_garage({})


func _exit_tree() -> void:
	AudioManager.set_loop("engine_loop", false)
	for sig: Array in [[TouchInput.swiped, _on_swipe], [TouchInput.tapped, _on_tap]]:
		var s: Signal = sig[0]
		if s.is_connected(sig[1]):
			s.disconnect(sig[1])


func _collect_wheels(n: Node) -> void:
	for c: Node in n.get_children():
		if c.is_in_group("wheel"):
			_wheels.append(c)
		_collect_wheels(c)


func _build_hud() -> void:
	hud = GameHud.new()
	add_child(hud)
	hud.set_title("RUN %d" % _run)
	hud.set_progress_visible(false)
	hud.set_hint_text("SWIPE: LANES   HOLD: BOOST")
	hud.set_finger_visible(false)
	hud.pause_pressed.connect(_open_pause)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_speed_lines = ColorRect.new()
	_speed_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	_speed_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed_mat = ShaderMaterial.new()
	_speed_mat.shader = preload("res://shaders/speed_lines.gdshader")
	_speed_lines.material = _speed_mat
	layer.add_child(_speed_lines)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.offset_top = -380
	bottom.offset_bottom = -90
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 0)
	hud.add_child(bottom)
	_earn_label = UiKit.label("", 54, Palette.GOLD, 10)
	bottom.add_child(_earn_label)
	_speed_label = UiKit.label("0", 190, Color.WHITE, 18)
	var digital := FontVariation.new()
	digital.base_font = UiKit.font()
	digital.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.22, 1), Vector2.ZERO)
	digital.spacing_glyph = 4
	_speed_label.add_theme_font_override("font", digital)
	_speed_label.add_theme_color_override("font_outline_color", Palette.UI_DARK)
	bottom.add_child(_speed_label)
	var mph: Label = UiKit.label("MPH", 44, Palette.PLAYER_LIGHT, 8)
	bottom.add_child(mph)
	_stamina_bar = Control.new()
	_stamina_bar.custom_minimum_size = Vector2(560, 40)
	_stamina_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_bar.draw.connect(_draw_stamina)
	bottom.add_child(_stamina_bar)


func _draw_stamina() -> void:
	var sz: Vector2 = _stamina_bar.size
	var k: float = clampf(_stamina / maxf(_stamina_max, 0.01), 0.0, 1.0)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(Palette.UI_DARK, 0.7)
	bg.set_corner_radius_all(20)
	_stamina_bar.draw_style_box(bg, Rect2(Vector2.ZERO, sz))
	var fg := StyleBoxFlat.new()
	fg.bg_color = Palette.ENEMY.lerp(Palette.UI_ACCENT, k)
	fg.set_corner_radius_all(16)
	if k > 0.02:
		_stamina_bar.draw_style_box(fg, Rect2(Vector2(5, 5), Vector2((sz.x - 10.0) * k, sz.y - 10.0)))


func _reset_run() -> void:
	_top_speed = OvertakeGarage.top_speed_mph(OvertakeGarage.level_of("power")) * MPH
	_stamina_max = OvertakeGarage.stamina_max(OvertakeGarage.level_of("stamina"))
	_income = OvertakeGarage.income_mult(OvertakeGarage.level_of("income"))
	_stamina = _stamina_max
	_lane = 1
	_x = LANES[1]
	_z = 0.0
	_speed = 0.0
	_distance = 0.0
	_earned_f = 0.0
	_combo = 0
	_spawn_timer = 1.0
	_lane_last_spawn = PackedFloat32Array([0.0, 0.0, 0.0])
	car.rotation = Vector3.ZERO
	car.position = Vector3(_x, 0, _z)
	for tc: TrafficCar in _cars:
		tc.active = false
		tc.node.visible = false
	_earn_label.text = ""
	_speed_label.text = "0"
	_stamina_bar.queue_redraw()
	road.follow(_z)


# ---------------------------------------------------------------- flow ---

func _open_garage(results: Dictionary) -> void:
	state = State.GARAGE
	AudioManager.set_loop("engine_loop", false)
	hud.show_hint(false)
	var g := OvertakeGarage.new()
	add_child(g)
	g.open(results)
	g.drive_pressed.connect(_on_drive)
	g.home_pressed.connect(GameState.go_hub)


func _on_drive() -> void:
	if AdService.should_show_interstitial(_run):
		await AdService.show_interstitial()
	_reset_run()
	hud.set_title("RUN %d" % _run)
	state = State.READY
	hud.show_hint(true)
	cam.offset = Vector3(0, 3.0, 7.2)
	cam.look_offset = Vector3(0, 0.9, -12.0)
	cam.snap()
	if _autopilot:
		_start_drive()


func smoke_start() -> void:
	_autopilot = true
	for g: Node in get_tree().get_nodes_in_group("end_screen_like"):
		(g as OvertakeGarage)._on_drive()


func _on_tap(_p: Vector2) -> void:
	if state == State.READY:
		_start_drive()


func _start_drive() -> void:
	state = State.DRIVE
	hud.show_hint(false)
	AdService.notify_gameplay()
	AudioManager.play("whoosh")
	Haptics.light()


func _on_swipe(dir: Vector2i) -> void:
	if state == State.READY:
		_start_drive()
	if state != State.DRIVE or dir.x == 0:
		return
	_change_lane(_lane + dir.x)


func _change_lane(to: int) -> void:
	to = clampi(to, 0, 2)
	if to == _lane:
		car.rotation.z = -0.08 * float(signi(to - 1))
		return
	var dir: float = signf(float(to - _lane))
	_lane = to
	if _lane_tween != null and _lane_tween.is_valid():
		_lane_tween.kill()
	_lane_tween = create_tween().set_parallel(true)
	_lane_tween.tween_property(self, "_x", LANES[to], LANE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	car.rotation.z = -dir * 0.2
	car.rotation.y = -dir * 0.12
	_lane_tween.tween_property(car, "rotation:z", 0.0, LANE_TIME * 1.8).set_delay(LANE_TIME * 0.4)
	_lane_tween.tween_property(car, "rotation:y", 0.0, LANE_TIME * 1.6).set_delay(LANE_TIME * 0.3)
	AudioManager.play("whoosh", 0.1, -8.0, 0.05)
	Haptics.light()


# -------------------------------------------------------------- update ---

func _process(delta: float) -> void:
	match state:
		State.GARAGE:
			_orbit += delta * 0.35
			cam.offset = Vector3(sin(_orbit) * 6.5, 2.4, cos(_orbit) * 6.5)
			cam.look_offset = Vector3(0, 0.6, 0)
		State.DRIVE:
			_drive(delta)
	car.position = Vector3(_x, 0.0, _z)
	cam.target = Vector3(_x, 0.0, _z)
	road.follow(_z)
	for w: Node in _wheels:
		(w as Node3D).rotate_x(-_speed * delta / 0.33)
	_flash = move_toward(_flash, 0.0, delta * 2.5)
	var lines: float = maxf(_flash, 0.75 if _boosting else 0.0)
	_speed_mat.set_shader_parameter("intensity", lines)
	_speed_label.text = str(int(roundf(_speed / MPH)))
	_stamina_bar.queue_redraw()


func _drive(delta: float) -> void:
	var want_boost: bool = TouchInput.is_holding() and TouchInput.travel() < 40.0 and _stamina > 0.05
	if _autopilot:
		want_boost = _stamina > _stamina_max * 0.5
	if want_boost and not _boosting:
		AudioManager.play("boost", 0.05)
		cam.kick_fov(6.0)
		Haptics.light()
	_boosting = want_boost
	if _boosting:
		_stamina = maxf(0.0, _stamina - delta)
		cam.kick_fov(4.0)
	else:
		_stamina = minf(_stamina_max, _stamina + delta * 0.45)
	var target: float = _top_speed * (BOOST_MULT if _boosting else 1.0)
	var accel: float = (8.0 + 0.6 * float(OvertakeGarage.level_of("power"))) * (1.8 if _boosting else 1.0)
	_speed = move_toward(_speed, target, accel * delta)
	_z -= _speed * delta
	_distance += _speed * delta
	_earned_f += _income * (_speed / 30.0) * delta
	_earn_label.text = "+%d" % int(_earned_f)
	AudioManager.set_loop("engine_loop", true, 0.7 + _speed / _top_speed * 0.9, -6.0)
	_combo_timer -= delta
	if _combo_timer <= 0.0:
		_combo = 0
	if _autopilot:
		_autopilot_steer()
	_update_traffic(delta)


func _update_traffic(delta: float) -> void:
	var difficulty: float = clampf(_distance / 5000.0, 0.0, 1.0)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = lerpf(1.25, 0.5, difficulty) * _rng.randf_range(0.7, 1.3) * (30.0 / maxf(_speed, 10.0))
		_spawn()
	var car_hl: float = float(car.get_meta("half_len"))
	var car_hw: float = float(car.get_meta("half_w"))
	for tc: TrafficCar in _cars:
		if not tc.active:
			continue
		var dir: float = 1.0 if tc.lane == 0 else -1.0
		tc.z += dir * tc.speed * delta
		var lx: float = LANES[tc.lane]
		tc.node.position = Vector3(lx, 0.0, tc.z)
		var dz: float = tc.z - _z
		# Collision (slightly forgiving boxes).
		if absf(lx - _x) < tc.half_w + car_hw - 0.15 and absf(dz) < tc.half_len + car_hl - 0.2:
			_crash(tc)
			return
		# Near miss: the car passed us in an adjacent lane.
		if not tc.passed and dz > tc.half_len + car_hl:
			tc.passed = true
			var dx: float = absf(lx - _x)
			if dx < NEAR_MISS_DX and dx > 0.5:
				_near_miss(tc)
		if dz > 25.0:
			tc.active = false
			tc.node.visible = false


func _spawn() -> void:
	var tc: TrafficCar = null
	for c: TrafficCar in _cars:
		if not c.active:
			tc = c
			break
	if tc == null:
		return
	# Oncoming lane is used less often and gets more dangerous later.
	var lane: int = _rng.randi_range(1, 2)
	if _rng.randf() < 0.3 + clampf(_distance / 8000.0, 0.0, 0.2):
		lane = 0
	var spawn_z: float = _z - SPAWN_AHEAD - (60.0 if lane == 0 else 0.0)
	# Keep spacing in the lane and never wall off all three lanes.
	if absf(_lane_last_spawn[lane] - spawn_z) < 22.0:
		return
	var blocked: int = 0
	for c: TrafficCar in _cars:
		if c.active and absf(c.z - spawn_z) < 16.0:
			blocked += 1
	if blocked >= 2:
		return
	var info: Dictionary = _kinds[_rng.randi_range(0, _kinds.size() - 1)]
	tc.node.mesh = info["mesh"]
	tc.half_len = float(info["half_len"])
	tc.half_w = float(info["half_w"])
	tc.lane = lane
	tc.z = spawn_z
	tc.speed = _rng.randf_range(19.0, 25.0) if lane == 0 else _rng.randf_range(15.0, 23.0)
	tc.passed = false
	tc.active = true
	tc.node.rotation = Vector3(0, PI if lane == 0 else 0.0, 0)
	tc.node.position = Vector3(LANES[lane], 0.0, spawn_z)
	tc.node.visible = true
	_lane_last_spawn[lane] = spawn_z


func _near_miss(tc: TrafficCar) -> void:
	_combo += 1
	_combo_timer = 2.2
	var reward: int = int(roundf((6.0 if tc.lane != 0 else 10.0) * _income * float(mini(_combo, 5))))
	_earned_f += float(reward)
	_flash = 1.0
	Juice.floating_text(Vector3(LANES[tc.lane], 2.0, _z - 1.0), "$%d" % reward, Palette.GOLD.lightened(0.2), 1.3, 1.4, 0.7)
	if _combo >= 2:
		hud.toast("NEAR MISS x%d" % _combo, Palette.GOLD)
	AudioManager.play("near_miss", 0.08, 0.0, 0.05, 1.0 + float(mini(_combo, 6)) * 0.05)
	Haptics.light()
	cam.kick_fov(3.0)


func _crash(tc: TrafficCar) -> void:
	state = State.CRASH
	_boosting = false
	AudioManager.set_loop("engine_loop", false)
	AudioManager.play("crash")
	Haptics.heavy()
	Juice.hit_stop(0.08, 0.05)
	Juice.screen_shake(0.8, 0.6)
	var hit_pos: Vector3 = Vector3(_x, 0.8, _z - 1.5)
	Juice.burst(hit_pos, Color("#FF9A3D"), 1.5)
	Juice.burst(hit_pos, Palette.UI_DARK_SOFT, 1.1)
	Juice.burst(hit_pos, Color.WHITE, 0.9)
	var spin: float = -1.0 if _rng.randf() < 0.5 else 1.0
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(car, "rotation", Vector3(-0.4, spin * 2.6, spin * 0.9), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "_z", _z + 3.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var nt: Tween = tc.node.create_tween()
	nt.tween_property(tc.node, "rotation:y", tc.node.rotation.y + spin * 0.6, 0.5)
	_speed = 0.0
	var earned: int = int(_earned_f)
	var save: Dictionary = SaveSystem.game(GAME_ID)
	var best: float = float(save.get("best_distance", 0.0))
	var new_best: bool = _distance > best
	if new_best:
		save["best_distance"] = _distance
	_run += 1
	save["level"] = _run
	Economy.add(earned, "overtake_run")
	SaveSystem.save_game()
	await get_tree().create_timer(1.5).timeout
	_open_garage({"distance": _distance, "earned": earned, "best": maxf(best, _distance), "new_best": new_best})
	if _autopilot:
		await get_tree().create_timer(0.1).timeout
		add_to_group("end_screen")  # tells the smoke test the run ended


func _autopilot_steer() -> void:
	# Dodge: if something is ahead in our lane, move to the clearest lane.
	var danger: PackedFloat32Array = PackedFloat32Array([999.0, 999.0, 999.0])
	for tc: TrafficCar in _cars:
		if tc.active:
			var ahead: float = _z - tc.z
			if ahead > -tc.half_len - 3.0 and ahead < 45.0:
				danger[tc.lane] = minf(danger[tc.lane], ahead)
	if danger[_lane] < 40.0:
		var best: int = _lane
		for l: int in 3:
			if absi(l - _lane) == 1 and danger[l] > danger[best]:
				best = l
		if best != _lane:
			_change_lane(best)


func _open_pause() -> void:
	if _pause_menu != null or state != State.DRIVE:
		return
	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)
	_pause_menu.resumed.connect(func() -> void: _pause_menu = null)
	_pause_menu.restart_requested.connect(GameState.reload)
	_pause_menu.home_requested.connect(GameState.go_hub)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if state == State.DRIVE:
			_open_pause()
