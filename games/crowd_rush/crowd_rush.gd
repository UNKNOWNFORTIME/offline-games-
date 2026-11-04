extends Node3D
## Crowd Rush: drag through math gates to grow the crowd, clash 1:1 with the
## red crowd, then pour the survivors into the boss.
## Scene is built entirely in code from level data (no hand-placed nodes).

enum State { READY, RUN, CLASH, BOSS_RUN, BOSS_FIGHT, WIN, FAIL }

const GAME_ID: String = "crowd_rush"
const RUN_SPEED: float = 9.5
const DRAG_SENS: float = 0.0118  # meters per screen pixel (1080-wide canvas)
const STEER_SHARPNESS: float = 12.0
const BOSS_REACH: float = 2.4
const CLASH_MIN_TIME: float = 0.8
const CLASH_MAX_TIME: float = 1.6

var state: State = State.READY
var level_num: int = 1
var level: Dictionary = {}

var track: CrowdTrack
var crowd: CrowdSwarm
var enemy: CrowdSwarm
var boss: CrowdBoss
var cam: FollowCamera
var hud: CrowdHud
var gates: Array[GatePair] = []

var _next_gate: int = 0
var _crowd_x: float = 0.0
var _target_x: float = 0.0
var _crowd_z: float = 0.0
var _pending_dx: float = 0.0
var _enemy_active: bool = false
var _clash_started: bool = false
var _kill_rate: float = 0.0
var _kill_acc: float = 0.0
var _clash_sfx_cd: float = 0.0
var _hit_acc: float = 0.0
var _stomp_timer: float = 0.0
var _dmg_accum: int = 0
var _dmg_text_cd: float = 0.0
var _react_cd: float = 0.0
var _orbit: float = 0.0
var _peak_count: int = 1
var _pause_menu: PauseMenu = null
var _autopilot: bool = false


func _ready() -> void:
	var save: Dictionary = SaveSystem.game(GAME_ID)
	level_num = maxi(1, SaveSystem.get_int(save, "level", 1))
	level = CrowdLevels.get_level(level_num)

	EnvBuilder.build(self, "sunny")
	track = CrowdTrack.new()
	add_child(track)
	track.build(float(level["length"]), level_num * 7919 + 17)

	var gate_half: float = CrowdTrack.HALF_WIDTH - 0.05
	for g: Variant in level["gates"]:
		var gd: Dictionary = g
		var gp := GatePair.new()
		add_child(gp)
		gp.build(-float(gd["d"]), str(gd["left"]), str(gd["right"]), gate_half)
		gates.append(gp)

	crowd = CrowdSwarm.new()
	add_child(crowd)
	crowd.setup(Palette.PLAYER, Settings.max_crowd_visible(), true)
	crowd.set_count(_start_count(), false)
	crowd.run_amount = 0.0

	enemy = CrowdSwarm.new()
	add_child(enemy)
	enemy.setup(Palette.ENEMY, mini(Settings.max_crowd_visible(), 220), true)
	enemy.position = Vector3(0, 0, track.enemy_z)
	enemy.rotation.y = PI
	enemy.squeeze_half_width = CrowdTrack.ARENA_HALF_WIDTH - 0.8
	enemy.set_count(int(level["enemy"]), false)
	enemy.run_amount = 0.0

	boss = CrowdBoss.new()
	add_child(boss)
	boss.position = Vector3(0, 0.5, track.boss_z)
	boss.build(int(level["boss_hp"]))
	boss.stomped.connect(_on_boss_stomp)

	cam = FollowCamera.new()
	add_child(cam)
	cam.current = true
	cam.target = Vector3(0, 0, 0)
	cam.snap()

	hud = CrowdHud.new()
	add_child(hud)
	hud.set_level(level_num)
	hud.pause_pressed.connect(_open_pause)

	TouchInput.pressed.connect(_on_press)
	TouchInput.dragged.connect(_on_drag)
	AudioManager.play_music(GAME_ID)


func _exit_tree() -> void:
	if TouchInput.pressed.is_connected(_on_press):
		TouchInput.pressed.disconnect(_on_press)
	if TouchInput.dragged.is_connected(_on_drag):
		TouchInput.dragged.disconnect(_on_drag)


func _start_count() -> int:
	return 1 + SaveSystem.get_int(SaveSystem.game(GAME_ID), "start_crowd", 0)


# ---------------------------------------------------------------- input ---

func _on_press(_pos: Vector2) -> void:
	if state == State.READY:
		_begin_run()


func _on_drag(delta: Vector2, _pos: Vector2) -> void:
	if state == State.READY:
		_begin_run()
	if state == State.RUN:
		_pending_dx += delta.x


## CI smoke test: start and steer toward the better gate automatically.
func smoke_start() -> void:
	_autopilot = true
	_begin_run()


func _begin_run() -> void:
	if state != State.READY or get_tree().paused:
		return
	state = State.RUN
	hud.show_hint(false)
	AdService.notify_gameplay()
	Haptics.light()
	AudioManager.play("whoosh", 0.05)
	var t: Tween = create_tween()
	t.tween_property(crowd, "run_amount", 1.0, 0.25)


# --------------------------------------------------------------- update ---

func _process(delta: float) -> void:
	_react_cd -= delta
	_clash_sfx_cd -= delta
	match state:
		State.RUN:
			_update_run(delta)
		State.CLASH:
			_update_clash(delta)
		State.BOSS_RUN:
			_update_boss_run(delta)
		State.BOSS_FIGHT:
			_update_boss_fight(delta)
		State.WIN:
			_orbit += delta * 0.45
			cam.offset = Vector3(sin(_orbit) * 9.0, 6.5, cos(_orbit) * 9.0)
			cam.look_offset = Vector3(0, 1.0, 0)
	crowd.position = Vector3(_crowd_x, 0.0, _crowd_z)
	_update_camera(delta)
	track.follow(cam.global_position.z)
	hud.set_progress(clampf(-_crowd_z / float(level["length"]), 0.0, 1.0))


func _update_run(delta: float) -> void:
	_crowd_z -= RUN_SPEED * delta
	_steer(delta, CrowdTrack.HALF_WIDTH)
	while _next_gate < gates.size() and _crowd_z <= gates[_next_gate].z_pos:
		_pass_gate(gates[_next_gate])
		_next_gate += 1
	if crowd.count <= 0:
		_fail("Your crowd was wiped out!")
		return
	if _crowd_z <= track.finish_z:
		state = State.CLASH
		AudioManager.play("whoosh", 0.05)


func _steer(delta: float, half_width: float) -> void:
	if _autopilot and _next_gate < gates.size():
		var g: GatePair = gates[_next_gate]
		var l: int = GatePair.apply(g.ops[0], crowd.count)
		var r: int = GatePair.apply(g.ops[1], crowd.count)
		_target_x = g.side_center_x(0 if l >= r else 1) * 0.7
	_target_x += _pending_dx * DRAG_SENS
	_pending_dx = 0.0
	var r: float = crowd.natural_radius()
	var limit: float = maxf(half_width - 0.35 - r, half_width - 1.6)
	_target_x = clampf(_target_x, -limit, limit)
	_crowd_x = lerpf(_crowd_x, _target_x, 1.0 - exp(-STEER_SHARPNESS * delta))
	crowd.squeeze_half_width = maxf(1.0, half_width - 0.35 - absf(_crowd_x))


func _pass_gate(g: GatePair) -> void:
	var side: int = 0 if _crowd_x < 0.0 else 1
	var before: int = crowd.count
	var after: int = g.consume(side, before)
	crowd.set_count(after)
	_peak_count = maxi(_peak_count, after)
	var above: Vector3 = crowd.global_position + Vector3(0, 3.0, -1.0)
	var diff: int = after - before
	if diff > 0:
		AudioManager.play("gate_good", 0.04)
		Haptics.light()
		Juice.floating_text(above, "+%d" % diff, Palette.PLAYER_LIGHT, 1.3)
		if after >= before * 2 and diff >= 6:
			cam.kick_fov(6.0)
			Juice.screen_shake(0.12, 0.2)
	elif diff < 0:
		AudioManager.play("gate_bad", 0.04)
		Haptics.medium()
		Juice.screen_shake(0.32, 0.3)
		Juice.floating_text(above, "%d" % diff, Palette.ENEMY_LIGHT, 1.3)


func _update_clash(delta: float) -> void:
	# Crowd funnels to the arena center; arena is wider so it can spread.
	_pending_dx = 0.0
	_target_x = 0.0
	_crowd_x = lerpf(_crowd_x, 0.0, 1.0 - exp(-4.0 * delta))
	crowd.squeeze_half_width = CrowdTrack.ARENA_HALF_WIDTH - 0.8
	var p_front: float = _crowd_z - crowd.extent_z()
	var e_front: float = enemy.position.z + enemy.extent_z()
	var gap: float = p_front - e_front
	if not _enemy_active and gap < 16.0:
		_enemy_active = true
		enemy.run_amount = 1.0
	if gap > 0.15:
		_crowd_z -= RUN_SPEED * delta
		if _enemy_active:
			enemy.position.z += 3.5 * delta
		return
	if not _clash_started:
		_clash_started = true
		var total: int = mini(crowd.count, enemy.count)
		var dur: float = clampf(0.5 + float(total) * 0.012, CLASH_MIN_TIME, CLASH_MAX_TIME)
		_kill_rate = float(maxi(total, 1)) / dur
		Juice.hit_stop(0.04, 0.15)
		Juice.screen_shake(0.28, 0.3)
		Haptics.medium()
	# Keep both fronts pressed together while they annihilate.
	_crowd_z -= 1.2 * delta
	enemy.position.z += 1.2 * delta
	_kill_acc += _kill_rate * delta
	var kills: int = mini(int(_kill_acc), mini(crowd.count, enemy.count))
	_kill_acc -= float(int(_kill_acc))
	if kills > 0:
		crowd.set_count(crowd.count - kills)
		enemy.set_count(enemy.count - kills)
		var contact_z: float = (p_front + e_front) * 0.5
		var spread: float = minf(crowd.extent_x(), enemy.extent_x())
		for i: int in mini(kills, 3):
			var px: float = randf_range(-spread, spread)
			Juice.puff(Vector3(px, 0.5, contact_z), Palette.PLAYER_LIGHT if i % 2 == 0 else Palette.ENEMY_LIGHT)
		if _clash_sfx_cd <= 0.0:
			AudioManager.play("unit_pop", 0.1, -3.0, 0.0)
			Haptics.light()
			_clash_sfx_cd = 0.07
	if crowd.count <= 0:
		_fail("The red crowd was too big!")
	elif enemy.count <= 0:
		enemy.show_label(false)
		enemy.visible = false
		state = State.BOSS_RUN
		hud.toast("BOSS FIGHT!", Palette.ENEMY_LIGHT)
		AudioManager.play("gate_good", 0.0)
		Haptics.medium()


func _update_boss_run(delta: float) -> void:
	_crowd_x = lerpf(_crowd_x, 0.0, 1.0 - exp(-4.0 * delta))
	crowd.squeeze_half_width = CrowdTrack.ARENA_HALF_WIDTH - 0.8
	_crowd_z -= RUN_SPEED * 1.15 * delta
	if _crowd_z - crowd.extent_z() <= boss.position.z + BOSS_REACH:
		state = State.BOSS_FIGHT
		_stomp_timer = 1.0
		Juice.screen_shake(0.2, 0.2)


func _update_boss_fight(delta: float) -> void:
	# Survivors keep pressing into the boss.
	var hold_z: float = boss.position.z + BOSS_REACH + crowd.extent_z()
	_crowd_z = lerpf(_crowd_z, hold_z, 1.0 - exp(-6.0 * delta))
	var hps: float = maxf(CrowdLevels.BOSS_HITS_PER_SEC_MIN, float(boss.hp_max) / CrowdLevels.FIGHT_TIME)
	_hit_acc += hps * delta
	var hits: int = mini(int(_hit_acc), mini(crowd.count, boss.hp))
	_hit_acc -= float(int(_hit_acc))
	if hits > 0:
		crowd.set_count(crowd.count - hits)
		boss.damage(hits)
		_dmg_accum += hits
		var front: Vector3 = boss.global_position + Vector3(randf_range(-1.2, 1.2), randf_range(1.2, 3.0), 1.2)
		Juice.puff(front, Palette.PLAYER_LIGHT)
		AudioManager.play("boss_hit", 0.12, -3.0, 0.06)
		if _react_cd <= 0.0:
			boss.hit_react()
			Haptics.light()
			Juice.screen_shake(0.1, 0.12)
			_react_cd = 0.12
	_dmg_text_cd -= delta
	if _dmg_text_cd <= 0.0 and _dmg_accum > 0:
		Juice.floating_text(boss.global_position + Vector3(randf_range(-1.0, 1.0), 4.8, 1.5), "-%d" % _dmg_accum, Color.WHITE, 1.4, 1.4, 0.7)
		_dmg_accum = 0
		_dmg_text_cd = 0.16
	if boss.dead:
		_win()
		return
	_stomp_timer -= delta
	if _stomp_timer <= 0.0:
		_stomp_timer = 1.6
		boss.stomp()
	if crowd.count <= 0:
		_fail("The boss was too strong!")


func _on_boss_stomp() -> void:
	if state != State.BOSS_FIGHT:
		return
	var k: int = mini(CrowdLevels.stomp_kills(level_num), crowd.count)
	crowd.set_count(crowd.count - k)
	Juice.screen_shake(0.45, 0.35)
	Juice.hit_stop(0.05, 0.1)
	Juice.burst(boss.global_position + Vector3(0, 0.2, 1.8), Color("#E8E2D6"), 0.8)
	AudioManager.play("stomp", 0.05)
	Haptics.heavy()
	if crowd.count <= 0:
		_fail("The boss was too strong!")


func _update_camera(delta: float) -> void:
	var target := Vector3(_crowd_x, 0.0, _crowd_z)
	var want_zoom: float = 1.0 + clampf(crowd.natural_radius() - 1.5, 0.0, 6.0) * 0.07
	match state:
		State.CLASH:
			if _clash_started:
				target.z = (_crowd_z + enemy.position.z) * 0.5
			want_zoom += 0.12
		State.BOSS_RUN, State.BOSS_FIGHT:
			target.z = (_crowd_z + boss.position.z) * 0.5
			want_zoom = maxf(want_zoom, 1.25)
		State.WIN:
			target = Vector3(_crowd_x, 0.0, _crowd_z)
			want_zoom = 1.0
	cam.target = target
	cam.zoom = lerpf(cam.zoom, want_zoom, 1.0 - exp(-2.5 * delta))


# ------------------------------------------------------------ end states ---

func _win() -> void:
	if state == State.WIN or state == State.FAIL:
		return
	state = State.WIN
	crowd.run_amount = 0.0
	crowd.celebrate = true
	Juice.hit_stop(0.08, 0.08)
	Juice.screen_shake(0.6, 0.5)
	Haptics.heavy()
	AudioManager.play("boss_die")
	var survivors: int = crowd.count
	var coins: int = 20 + level_num * 5 + mini(survivors * 2, 400)
	var save: Dictionary = SaveSystem.game(GAME_ID)
	save["level"] = level_num + 1
	save["best_level"] = maxi(SaveSystem.get_int(save, "best_level", 1), level_num + 1)
	var stats: Dictionary = SaveSystem.data["stats"]
	stats["levels_completed"] = int(stats.get("levels_completed", 0)) + 1
	SaveSystem.save_game()
	await get_tree().create_timer(1.6).timeout
	var es := EndScreen.new()
	add_child(es)
	es.open(true, coins, "%d survivors!" % survivors if survivors > 0 else "Boss defeated!")
	es.next_pressed.connect(_next_level)


func _fail(reason: String) -> void:
	if state == State.WIN or state == State.FAIL:
		return
	state = State.FAIL
	crowd.run_amount = 0.0
	enemy.run_amount = 0.0
	Juice.screen_shake(0.4, 0.4)
	Haptics.heavy()
	var progress: float = clampf(-_crowd_z / float(level["length"]), 0.0, 1.0)
	var coins: int = 2 + int(progress * float(5 + level_num))
	await get_tree().create_timer(1.0).timeout
	var es := EndScreen.new()
	add_child(es)
	es.open(false, coins, reason)
	es.retry_pressed.connect(GameState.reload)
	es.home_pressed.connect(GameState.go_hub)


func _next_level() -> void:
	if AdService.should_show_interstitial(level_num):
		await AdService.show_interstitial()
	GameState.reload()


# ---------------------------------------------------------------- pause ---

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
		if state == State.RUN or state == State.CLASH or state == State.BOSS_RUN or state == State.BOSS_FIGHT:
			_open_pause()
