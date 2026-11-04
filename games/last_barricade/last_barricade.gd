extends Node3D
## Last Barricade: first-person defense. Drag to aim (crosshair follows the
## finger's motion with smoothing), weapon auto-fires while a finger is
## down, tap floating weapons to grab them, survive the wave.

enum State { READY, FIGHT, CLEARED, FAIL }

const GAME_ID: String = "last_barricade"
const WAVES_PATH: String = "res://data/barricade_waves.json"
const POOL_SIZE: int = 30
const AIM_SENS: float = 1.25
const BARRICADE_MAX: float = 100.0
const STOP_Z: float = BarricadeWorld.BARRICADE_Z - 1.1

var state: State = State.READY
var wave_num: int = 1
var wave: Dictionary = {}
var world: BarricadeWorld
var cam: Camera3D
var hud: GameHud

var _enemies: Array[Shambler] = []
var _spawned: int = 0
var _kills: int = 0
var _headshots: int = 0
var _spawn_timer: float = 1.2
var _barricade: float = BARRICADE_MAX
var _weapon: String = "pistol"
var _cooldown: float = 0.0
var _view_holder: Node3D
var _view_model: Node3D
var _muzzle: Vector3 = Vector3.ZERO
var _flash_mesh: MeshInstance3D
var _flash_light: OmniLight3D
var _flash_time: float = 0.0
var _tracers: Array[MeshInstance3D] = []
var _tracer_life: PackedFloat32Array = PackedFloat32Array()
var _tracer_next: int = 0
var _pickups: Array[Dictionary] = []
var _pending_pickups: Array = []
var _cross_target: Vector2 = Vector2.ZERO
var _cross: Vector2 = Vector2.ZERO
var _crosshair: Control
var _hp_bar: Control
var _weapon_label: Label
var _vignette: ColorRect
var _cam_base: Transform3D
var _revive_used: bool = false
var _autopilot: bool = false
var _pause_menu: PauseMenu = null
var _haptic_cd: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	wave_num = maxi(1, SaveSystem.get_int(SaveSystem.game(GAME_ID), "level", 1))
	wave = _wave_def(wave_num)
	EnvBuilder.build(self, "misty_forest")
	world = BarricadeWorld.new()
	add_child(world)
	world.build(1337 + wave_num)

	cam = Camera3D.new()
	cam.fov = 66.0
	cam.near = 0.05
	cam.far = 140.0
	add_child(cam)
	cam.position = Vector3(0, 1.75, 0.9)
	cam.look_at(Vector3(0, 1.1, -30), Vector3.UP)
	cam.current = true
	_cam_base = cam.transform

	for i: int in POOL_SIZE:
		var s := Shambler.new()
		add_child(s)
		s.setup()
		s.defeated.connect(_on_defeated)
		_enemies.append(s)

	_build_view_model()
	_build_tracers()
	_build_hud()
	_set_weapon("pistol", false)
	TouchInput.pressed.connect(_on_press)
	TouchInput.dragged.connect(_on_drag)
	AudioManager.play_music(GAME_ID)


func _exit_tree() -> void:
	if TouchInput.pressed.is_connected(_on_press):
		TouchInput.pressed.disconnect(_on_press)
	if TouchInput.dragged.is_connected(_on_drag):
		TouchInput.dragged.disconnect(_on_drag)


func _wave_def(n: int) -> Dictionary:
	var waves: Array = []
	var f: FileAccess = FileAccess.open(WAVES_PATH, FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			waves = (parsed as Dictionary).get("waves", [])
	if waves.is_empty():
		waves = [{"count": 10, "interval": 1.5, "speed": 1.5, "hp": 2.0, "shield": 0.1, "pickups": []}]
	if n <= waves.size():
		return waves[n - 1]
	# Endless mode: scale the last wave.
	var k: float = float(n - waves.size())
	var last: Dictionary = waves[waves.size() - 1]
	return {
		"count": int(last["count"]) + int(k * 3.0),
		"interval": maxf(0.5, float(last["interval"]) - k * 0.02),
		"speed": minf(2.7, float(last["speed"]) + k * 0.04),
		"hp": float(last["hp"]) + k * 0.3,
		"shield": minf(0.55, float(last["shield"]) + k * 0.01),
		"pickups": [{"kill": 1, "weapon": "smg"}, {"kill": 8, "weapon": "rifle"}, {"kill": 20, "weapon": "shotgun"}],
	}


# ------------------------------------------------------------ building ---

func _build_view_model() -> void:
	_view_holder = Node3D.new()
	_view_holder.position = Vector3(0.3, -0.3, -0.55)
	cam.add_child(_view_holder)
	_flash_mesh = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.32, 0.32)
	_flash_mesh.mesh = q
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.albedo_color = Color(1.0, 0.8, 0.35)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.no_depth_test = true
	_flash_mesh.material_override = fm
	_flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash_mesh.visible = false
	_view_holder.add_child(_flash_mesh)
	if Settings.is_high():
		_flash_light = OmniLight3D.new()
		_flash_light.light_color = Color(1.0, 0.75, 0.4)
		_flash_light.omni_range = 7.0
		_flash_light.light_energy = 0.0
		_flash_light.shadow_enabled = false
		_view_holder.add_child(_flash_light)


func _build_tracers() -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.85, 0.5)
	var b := BoxMesh.new()
	b.size = Vector3(1, 1, 1)
	for i: int in 14:
		var t := MeshInstance3D.new()
		t.mesh = b
		t.material_override = m
		t.visible = false
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(t)
		_tracers.append(t)
		_tracer_life.append(0.0)


func _build_hud() -> void:
	hud = GameHud.new()
	add_child(hud)
	hud.set_title("WAVE %d" % wave_num)
	hud.set_hint_text("DRAG TO AIM  -  HOLD TO FIRE")
	hud.pause_pressed.connect(_open_pause)
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.color = Color(Palette.ENEMY, 0.0)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_vignette)
	hud.move_child(_vignette, 0)
	_crosshair = Control.new()
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.size = Vector2(140, 140)
	_crosshair.draw.connect(_draw_crosshair)
	hud.add_child(_crosshair)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_cross = Vector2(vp.x * 0.5, vp.y * 0.47)
	_cross_target = _cross

	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.offset_top = -230
	bottom.offset_bottom = -70
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bottom)
	_weapon_label = UiKit.label("PISTOL", 56, Palette.UI_ACCENT, 10)
	bottom.add_child(_weapon_label)
	_hp_bar = Control.new()
	_hp_bar.custom_minimum_size = Vector2(640, 54)
	_hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar.draw.connect(_draw_hp)
	bottom.add_child(_hp_bar)


func _draw_crosshair() -> void:
	var c: Vector2 = _crosshair.size * 0.5
	var col: Color = Palette.UI_ACCENT
	var gap: float = 14.0 + (6.0 if _cooldown > 0.0 else 0.0)
	_crosshair.draw_arc(c, 34.0, 0.0, TAU, 32, Color(Palette.UI_DARK, 0.6), 9.0, true)
	_crosshair.draw_arc(c, 34.0, 0.0, TAU, 32, col, 5.0, true)
	for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		_crosshair.draw_line(c + d * gap, c + d * (gap + 26.0), Color(Palette.UI_DARK, 0.6), 9.0)
		_crosshair.draw_line(c + d * gap, c + d * (gap + 26.0), col, 5.0)
	_crosshair.draw_circle(c, 4.0, col)


func _draw_hp() -> void:
	var sz: Vector2 = _hp_bar.size
	var k: float = clampf(_barricade / BARRICADE_MAX, 0.0, 1.0)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(Palette.UI_DARK, 0.75)
	bg.set_corner_radius_all(26)
	_hp_bar.draw_style_box(bg, Rect2(Vector2.ZERO, sz))
	var fg := StyleBoxFlat.new()
	fg.bg_color = Palette.ENEMY.lerp(Color("#C9A26B"), k)
	fg.set_corner_radius_all(22)
	if k > 0.01:
		_hp_bar.draw_style_box(fg, Rect2(Vector2(6, 6), Vector2((sz.x - 12.0) * k, sz.y - 12.0)))
	var f: Font = UiKit.font()
	_hp_bar.draw_string_outline(f, Vector2(0, sz.y * 0.5 + 12.0), "BARRICADE  %d" % int(ceilf(_barricade)), HORIZONTAL_ALIGNMENT_CENTER, sz.x, 32, 8, Palette.UI_DARK)
	_hp_bar.draw_string(f, Vector2(0, sz.y * 0.5 + 12.0), "BARRICADE  %d" % int(ceilf(_barricade)), HORIZONTAL_ALIGNMENT_CENTER, sz.x, 32, Color.WHITE)


# -------------------------------------------------------------- input ---

func smoke_start() -> void:
	_autopilot = true
	_begin()


func _on_press(pos: Vector2) -> void:
	if state == State.READY:
		_begin()
		return
	if state == State.FIGHT:
		_try_grab_pickup(pos)


func _on_drag(delta: Vector2, _pos: Vector2) -> void:
	if state == State.READY:
		_begin()
	if state != State.FIGHT:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_cross_target = (_cross_target + delta * AIM_SENS).clamp(Vector2(40, 260), vp - Vector2(40, 320))


func _begin() -> void:
	if state != State.READY or get_tree().paused:
		return
	state = State.FIGHT
	hud.show_hint(false)
	hud.toast("WAVE %d" % wave_num, Palette.UI_ACCENT)
	AdService.notify_gameplay()
	Haptics.light()


# ------------------------------------------------------------- update ---

func _process(delta: float) -> void:
	_cooldown -= delta
	_haptic_cd -= delta
	_cross = _cross.lerp(_cross_target, 1.0 - exp(-14.0 * delta))
	_crosshair.position = _cross - _crosshair.size * 0.5
	_crosshair.queue_redraw()
	_update_camera(delta)
	_update_flash(delta)
	_update_tracers(delta)
	_update_pickups(delta)
	_vignette.color.a = move_toward(_vignette.color.a, 0.0, delta * 1.5)
	_hp_bar.queue_redraw()
	if state != State.FIGHT:
		return
	if _autopilot:
		_autopilot_aim()
	_spawn_timer -= delta
	if _spawned < int(wave["count"]) and _spawn_timer <= 0.0:
		_spawn_timer = float(wave["interval"]) * _rng.randf_range(0.7, 1.3)
		_spawn()
	var dmg: float = 0.0
	for s: Shambler in _enemies:
		if s.alive:
			dmg += s.step(delta, STOP_Z)
	if dmg > 0.0:
		_damage_barricade(dmg)
	var firing: bool = TouchInput.is_down or _autopilot
	if firing and _cooldown <= 0.0:
		_fire()
	hud.set_progress(float(_kills) / float(maxi(1, int(wave["count"]))))


func _update_camera(delta: float) -> void:
	# The view leans a few degrees toward the crosshair for a sense of aim.
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var off: Vector2 = (_cross - vp * Vector2(0.5, 0.47)) / vp
	var t: Transform3D = _cam_base
	t.basis = t.basis * Basis(Vector3.UP, -off.x * 0.12) * Basis(Vector3.RIGHT, -off.y * 0.08)
	var shake: Vector3 = Juice.shake_offset()
	t.origin += shake * 0.4
	cam.transform = cam.transform.interpolate_with(t, 1.0 - exp(-10.0 * delta))
	# Weapon follows the crosshair a bit and idles.
	var bob: float = sin(Time.get_ticks_msec() / 1000.0 * 2.0) * 0.006
	_view_holder.position = _view_holder.position.lerp(Vector3(0.3 + off.x * 0.12, -0.3 - off.y * 0.06 + bob, -0.55), 1.0 - exp(-12.0 * delta))
	if _view_model != null:
		var aim_dir: Vector3 = cam.project_local_ray_normal(_cross)
		var look := Basis.looking_at(aim_dir, Vector3.UP)
		_view_model.basis = _view_model.basis.slerp(look, 1.0 - exp(-18.0 * delta))


# ------------------------------------------------------------ shooting ---

func _fire() -> void:
	var ws: Dictionary = BarricadeWeapons.STATS[_weapon]
	_cooldown = 1.0 / float(ws["fire_rate"])
	var origin: Vector3 = cam.project_ray_origin(_cross)
	var base_dir: Vector3 = cam.project_ray_normal(_cross)
	var muzzle_world: Vector3 = _view_model.to_global(_muzzle) if _view_model != null else origin
	var pellets: int = int(ws["pellets"])
	var spread: float = deg_to_rad(float(ws["spread"]))
	var any_hit: bool = false
	for p: int in pellets:
		var dir: Vector3 = base_dir
		if spread > 0.0:
			var axis: Vector3 = base_dir.cross(Vector3.UP).normalized().rotated(base_dir, _rng.randf() * TAU)
			dir = base_dir.rotated(axis, _rng.randf_range(0.0, spread))
		var best_t: float = INF
		var best: Shambler = null
		var part: String = ""
		for s: Shambler in _enemies:
			if not s.alive:
				continue
			var r: Dictionary = s.ray_test(origin, dir)
			if not r.is_empty() and float(r["t"]) < best_t:
				best_t = float(r["t"])
				best = s
				part = str(r["part"])
		var end: Vector3
		if best != null:
			end = origin + dir * best_t
			any_hit = true
			var killed: bool = best.take_hit(float(ws["damage"]), part, dir)
			if part == "shield":
				Juice.burst(end, Color("#C9A26B"), 0.35)
			elif not killed:
				Juice.puff(end, Color("#C4D3BC"))
				if p == 0:
					Juice.floating_text(end + Vector3(0, 0.3, 0), "%s" % ("CRIT" if part == "head" else str(snappedf(float(ws["damage"]), 0.1))), Palette.GOLD if part == "head" else Color.WHITE, 0.55, 0.8, 0.45)
		else:
			# Hit the ground (y=0) or fly off into the trees.
			if dir.y < -0.001:
				var tg: float = -origin.y / dir.y
				end = origin + dir * minf(tg, 90.0)
				if tg < 90.0:
					Juice.puff(end + Vector3(0, 0.05, 0), Color("#A08868"))
			else:
				end = origin + dir * 90.0
		_tracer(muzzle_world, end)
	# Feedback: sound, recoil, flash, shake, haptic.
	AudioManager.play(str(ws["sfx"]), 0.08, -2.0, 0.0)
	_recoil(float(ws["kick"]))
	_flash_time = 0.05
	Juice.screen_shake(float(ws["shake"]), 0.12)
	if _haptic_cd <= 0.0:
		Haptics.light()
		_haptic_cd = 0.09
	if any_hit:
		_crosshair.scale = Vector2(1.15, 1.15)
		_crosshair.pivot_offset = _crosshair.size * 0.5
		_crosshair.create_tween().tween_property(_crosshair, "scale", Vector2.ONE, 0.1)


func _recoil(kick: float) -> void:
	if _view_model == null:
		return
	var t: Tween = _view_model.create_tween()
	_view_model.position = Vector3(0, kick * 0.3, kick)
	t.tween_property(_view_model, "position", Vector3.ZERO, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_view_holder.rotation.x = kick * 1.6
	_view_holder.create_tween().tween_property(_view_holder, "rotation:x", 0.0, 0.14)


func _update_flash(delta: float) -> void:
	_flash_time -= delta
	var on: bool = _flash_time > 0.0
	_flash_mesh.visible = on
	if on:
		_flash_mesh.position = _view_model.position + _view_model.basis * _muzzle if _view_model != null else Vector3.ZERO
		_flash_mesh.rotation.z = _rng.randf() * TAU
		_flash_mesh.scale = Vector3.ONE * _rng.randf_range(0.8, 1.3)
	if _flash_light != null:
		_flash_light.position = _flash_mesh.position
		_flash_light.light_energy = 2.2 if on else 0.0


func _tracer(a: Vector3, b: Vector3) -> void:
	var t: MeshInstance3D = _tracers[_tracer_next]
	_tracer_life[_tracer_next] = 0.05
	_tracer_next = (_tracer_next + 1) % _tracers.size()
	var mid: Vector3 = (a + b) * 0.5
	var len: float = a.distance_to(b)
	if len < 0.01:
		return
	t.visible = true
	t.global_transform = Transform3D(Basis.looking_at((b - a).normalized(), Vector3.UP) * Basis.from_scale(Vector3(0.025, 0.025, len)), mid)


func _update_tracers(delta: float) -> void:
	for i: int in _tracers.size():
		if _tracer_life[i] > 0.0:
			_tracer_life[i] -= delta
			if _tracer_life[i] <= 0.0:
				_tracers[i].visible = false


# ------------------------------------------------------------ enemies ---

func _spawn() -> void:
	for s: Shambler in _enemies:
		if not s.alive and not s.visible:
			var shielded: bool = _rng.randf() < float(wave["shield"])
			var tint: Color = Color.WHITE.lerp(Color(0.85, 0.95, 0.85), _rng.randf())
			s.spawn(Vector3(_rng.randf_range(-3.0, 3.0), 0.0, _rng.randf_range(-64.0, -56.0)), float(wave["hp"]), float(wave["speed"]), shielded, tint)
			_spawned += 1
			return


func _on_defeated(s: Shambler, headshot: bool) -> void:
	_kills += 1
	if headshot:
		_headshots += 1
		Juice.floating_text(s.global_position + Vector3(0, 2.2, 0), "HEADSHOT!", Palette.GOLD, 0.8, 1.0, 0.6)
	AudioManager.play("enemy_pop", 0.1, 0.0, 0.03)
	Juice.punch_scale(_crosshair, 0.3, 0.2)
	for pu: Variant in wave.get("pickups", []):
		var pd: Dictionary = pu
		if int(pd["kill"]) == _kills:
			_spawn_pickup(str(pd["weapon"]))
	if state == State.FIGHT and _kills >= int(wave["count"]):
		_cleared()


func _damage_barricade(dmg: float) -> void:
	_barricade = maxf(0.0, _barricade - dmg)
	world.shake_barricade()
	_vignette.color.a = 0.28
	AudioManager.play("barricade_hit", 0.1, 0.0, 0.08)
	Haptics.medium()
	Juice.screen_shake(0.18, 0.2)
	if _barricade <= 0.0:
		_fail()


# ------------------------------------------------------------- pickups ---

func _spawn_pickup(id: String) -> void:
	if id == _weapon:
		return
	var root := Node3D.new()
	var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
	root.position = Vector3(side * _rng.randf_range(1.4, 2.6), 1.5, _rng.randf_range(-15.0, -10.0))
	add_child(root)
	var model: Node3D = BarricadeWeapons.build_model(id)
	model.scale = Vector3.ONE * 2.6
	root.add_child(model)
	var outline: ShaderMaterial = Toon.outline(0.012, Palette.UI_ACCENT.lightened(0.2))
	for c: Node in model.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).material_overlay = outline
	# Soft green beam so it reads from far away.
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.35
	cyl.height = 6.0
	cyl.radial_segments = 12
	cyl.rings = 1
	beam.mesh = cyl
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.albedo_color = Color(Palette.UI_ACCENT, 0.18)
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = bm
	beam.position = Vector3(0, 1.5, 0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beam)
	var l := Label3D.new()
	l.font = UiKit.font()
	l.text = "TAP!  " + str(BarricadeWeapons.STATS[id]["name"])
	l.font_size = 90
	l.outline_size = 22
	l.pixel_size = 0.007
	l.modulate = Palette.UI_ACCENT.lightened(0.3)
	l.outline_modulate = Palette.UI_DARK
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = Vector3(0, 0.9, 0)
	root.add_child(l)
	root.scale = Vector3(0.1, 0.1, 0.1)
	root.create_tween().tween_property(root, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pickups.append({"node": root, "model": model, "id": id})
	AudioManager.play("pickup", 0.0, -6.0)
	hud.toast(str(BarricadeWeapons.STATS[id]["name"]) + "!", Palette.UI_ACCENT)


func _update_pickups(delta: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	for p: Dictionary in _pickups:
		var m: Node3D = p["model"]
		m.rotate_y(delta * 1.2)
		m.position.y = sin(t * 2.0) * 0.12


func _try_grab_pickup(pos: Vector2) -> bool:
	for i: int in _pickups.size():
		var p: Dictionary = _pickups[i]
		var node: Node3D = p["node"]
		var sp: Vector2 = cam.unproject_position(node.global_position)
		if sp.distance_to(pos) < 150.0:
			_pickups.remove_at(i)
			_set_weapon(str(p["id"]), true)
			var tw: Tween = node.create_tween().set_parallel(true)
			tw.tween_property(node, "position", cam.global_position + cam.global_basis * Vector3(0.3, -0.3, -1.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(node, "scale", Vector3(0.2, 0.2, 0.2), 0.25)
			tw.chain().tween_callback(node.queue_free)
			return true
	return false


func _set_weapon(id: String, announce: bool) -> void:
	_weapon = id
	if _view_model != null:
		_view_model.queue_free()
	_view_model = BarricadeWeapons.build_model(id)
	_muzzle = _view_model.get_meta("muzzle")
	_view_holder.add_child(_view_model)
	_weapon_label.text = str(BarricadeWeapons.STATS[id]["name"])
	if announce:
		# Raise animation for the new weapon.
		_view_model.position = Vector3(0, -0.4, 0.1)
		_view_model.create_tween().tween_property(_view_model, "position", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		AudioManager.play("pickup")
		Haptics.medium()
		Juice.punch_scale(_weapon_label, 0.4, 0.4)


# ---------------------------------------------------------- end states ---

func _cleared() -> void:
	state = State.CLEARED
	Haptics.heavy()
	hud.toast("WAVE CLEARED!", Palette.UI_ACCENT)
	var coins: int = 15 + wave_num * 6 + int(_barricade / 5.0) + _headshots
	var save: Dictionary = SaveSystem.game(GAME_ID)
	save["level"] = wave_num + 1
	save["best_level"] = maxi(SaveSystem.get_int(save, "best_level", 1), wave_num + 1)
	var stats: Dictionary = SaveSystem.data["stats"]
	stats["levels_completed"] = int(stats.get("levels_completed", 0)) + 1
	SaveSystem.save_game()
	await get_tree().create_timer(1.4).timeout
	var es := EndScreen.new()
	add_child(es)
	es.open(true, coins, "%d headshots" % _headshots if _headshots > 0 else "The line holds!")
	es.next_pressed.connect(_next_wave)


func _fail() -> void:
	if state != State.FIGHT:
		return
	state = State.FAIL
	Juice.screen_shake(0.7, 0.6)
	Haptics.heavy()
	AudioManager.play("crash")
	var t: Tween = world.planks.create_tween().set_parallel(true)
	t.tween_property(world.planks, "rotation:x", -1.3, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.tween_property(world.planks, "position:y", -0.3, 0.6)
	await get_tree().create_timer(1.2).timeout
	var es := EndScreen.new()
	add_child(es)
	es.open(false, 3 + _kills, "The barricade fell!")
	es.retry_pressed.connect(GameState.reload)
	es.home_pressed.connect(GameState.go_hub)
	if not _revive_used:
		es.add_revive()
		es.revive_granted.connect(_revive)


func _revive() -> void:
	_revive_used = true
	_barricade = BARRICADE_MAX * 0.6
	world.planks.rotation.x = 0.0
	world.planks.position.y = 0.0
	# Shockwave: shamblers at the barricade are knocked back.
	for s: Shambler in _enemies:
		if s.alive and s.position.z > -12.0:
			s.position.z -= 14.0
			s.attacking = false
			Juice.puff(s.global_position + Vector3(0, 1, 0), Color("#C4D3BC"))
	state = State.FIGHT
	Juice.screen_shake(0.4, 0.3)
	hud.toast("REBUILT!", Palette.GOLD)
	AudioManager.play("pickup")


func _next_wave() -> void:
	if AdService.should_show_interstitial(wave_num):
		await AdService.show_interstitial()
	GameState.reload()


# ------------------------------------------------------------ autopilot ---

func _autopilot_aim() -> void:
	if not _pickups.is_empty():
		var node: Node3D = _pickups[0]["node"]
		_try_grab_pickup(cam.unproject_position(node.global_position))
	var best: Shambler = null
	for s: Shambler in _enemies:
		if s.alive and (best == null or s.position.z > best.position.z):
			best = s
	if best != null:
		var aim: Vector3 = best.global_position + Vector3(0, 1.45 * best.size_k, 0.2)
		_cross_target = cam.unproject_position(aim)


func _open_pause() -> void:
	if _pause_menu != null or state == State.CLEARED or state == State.FAIL:
		return
	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)
	_pause_menu.resumed.connect(func() -> void: _pause_menu = null)
	_pause_menu.restart_requested.connect(GameState.reload)
	_pause_menu.home_requested.connect(GameState.go_hub)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if state == State.FIGHT:
			_open_pause()
