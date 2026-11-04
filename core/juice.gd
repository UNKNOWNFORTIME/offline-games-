extends Node
## Shared game-feel toolkit (GAME_SPEC 6): screen shake, hit stop, punch
## scale, floating text, hit flash, particle bursts. All spawned things are
## pooled. Cameras read [method shake_offset] each frame.

const MAX_SHAKE_OFFSET: float = 0.55
const MAX_SHAKE_ROLL: float = 0.035

var trauma: float = 0.0
var _trauma_decay: float = 1.6
var _time: float = 0.0
var _hit_stop_until_ms: int = 0
var _shake_offset: Vector3 = Vector3.ZERO
var _shake_roll: float = 0.0

var _text_pool: Pool
var _burst_pool: Pool
var _puff_pool: Pool
var _expiring: Array[Node] = []
var _expire_at: PackedFloat32Array = PackedFloat32Array()
var _flash_tweens: Dictionary = {}
var _font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = UiKit.font()
	_text_pool = Pool.new("float_text", _make_text, self, 12, 32)
	_burst_pool = Pool.new("burst", _make_burst, self, 6, 16)
	_puff_pool = Pool.new("puff", _make_puff, self, 12, 28)


# --------------------------------------------------------------- shake ---

## intensity 0..1 (adds trauma); duration controls how fast it decays.
func screen_shake(intensity: float, duration: float = 0.35) -> void:
	trauma = clampf(maxf(trauma, intensity), 0.0, 1.0)
	_trauma_decay = maxf(intensity / maxf(duration, 0.05), 0.8)


func shake_offset() -> Vector3:
	return _shake_offset


func shake_roll() -> float:
	return _shake_roll


# ------------------------------------------------------------ hit stop ---

func hit_stop(duration: float = 0.05, time_scale: float = 0.1) -> void:
	Engine.time_scale = time_scale
	_hit_stop_until_ms = Time.get_ticks_msec() + int(duration * 1000.0)


# --------------------------------------------------------------- punch ---

func punch_scale(node: Node, amount: float = 0.2, duration: float = 0.25) -> void:
	if node == null or not is_instance_valid(node):
		return
	var t: Tween = node.create_tween()
	if node is Node3D:
		var n3: Node3D = node as Node3D
		var base3: Vector3 = Vector3.ONE * n3.get_meta("base_scale", 1.0)
		n3.scale = base3 * (1.0 + amount)
		t.tween_property(n3, "scale", base3, duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	elif node is Control:
		var c: Control = node as Control
		c.pivot_offset = c.size * 0.5
		c.scale = Vector2.ONE * (1.0 + amount)
		t.tween_property(c, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# --------------------------------------------------------------- flash ---

## White hit flash. Target: a ShaderMaterial with a "flash" uniform, or a
## GeometryInstance3D whose material_override is one.
func flash(target: Object, duration: float = 0.06) -> void:
	var mat: ShaderMaterial = null
	if target is ShaderMaterial:
		mat = target as ShaderMaterial
	elif target is GeometryInstance3D:
		mat = (target as GeometryInstance3D).material_override as ShaderMaterial
	if mat == null:
		return
	var key: int = mat.get_instance_id()
	var old: Tween = _flash_tweens.get(key, null)
	if old != null and old.is_valid():
		old.kill()
	mat.set_shader_parameter("flash", 1.0)
	var t: Tween = create_tween()
	t.tween_interval(duration)
	t.tween_callback(mat.set_shader_parameter.bind("flash", 0.0))
	_flash_tweens[key] = t


# -------------------------------------------------------- floating text ---

func floating_text(world_pos: Vector3, text: String, color: Color = Color.WHITE, size: float = 1.0, rise: float = 1.6, life: float = 0.8) -> void:
	var l: Label3D = _text_pool.acquire() as Label3D
	l.text = text
	l.modulate = color
	l.outline_modulate = Color(Palette.UI_DARK, 1.0)
	l.position = world_pos
	var base: float = size
	l.scale = Vector3.ONE * base * 0.4
	var t: Tween = l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "scale", Vector3.ONE * base, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "position", world_pos + Vector3(0, rise, 0), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, life * 0.4).set_delay(life * 0.6)
	t.chain().tween_callback(_text_pool.release.bind(l))


func _make_text() -> Node:
	var l := Label3D.new()
	l.font = _font
	l.font_size = 96
	l.outline_size = 22
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	l.outline_render_priority = 9
	l.double_sided = true
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return l


# ----------------------------------------------------------- particles ---

## Burst of small cubes (gate pass, boss hit, big events).
func burst(world_pos: Vector3, color: Color, strength: float = 1.0) -> void:
	var p: CPUParticles3D = _burst_pool.acquire() as CPUParticles3D
	p.global_position = world_pos
	p.color = color
	p.initial_velocity_min = 3.5 * strength
	p.initial_velocity_max = 8.0 * strength
	p.restart()
	_expire(p, p.lifetime + 0.15)


## Small soft puff (unit pop, enemy defeat).
func puff(world_pos: Vector3, color: Color) -> void:
	var p: CPUParticles3D = _puff_pool.acquire() as CPUParticles3D
	p.global_position = world_pos
	p.color = color
	p.restart()
	_expire(p, p.lifetime + 0.1)


func _make_burst() -> Node:
	var p := CPUParticles3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.16, 0.16, 0.16)
	p.mesh = m
	p.material_override = Toon.particle()
	p.amount = maxi(6, int(18.0 * Settings.particle_scale()))
	p.lifetime = 0.75
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.95
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 70.0
	p.gravity = Vector3(0, -16, 0)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.scale_amount_curve = _shrink_curve()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _make_puff() -> Node:
	var p := CPUParticles3D.new()
	var m := SphereMesh.new()
	m.radius = 0.12
	m.height = 0.24
	m.radial_segments = 6
	m.rings = 3
	p.mesh = m
	p.material_override = Toon.particle()
	p.amount = maxi(3, int(6.0 * Settings.particle_scale()))
	p.lifetime = 0.35
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 1.0
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.8
	p.gravity = Vector3(0, 1.5, 0)
	p.damping_min = 3.0
	p.damping_max = 5.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.4
	p.scale_amount_curve = _shrink_curve()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _shrink_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(0.6, 0.8))
	c.add_point(Vector2(1.0, 0.0))
	return c


func _expire(n: Node, after: float) -> void:
	var at: float = _time + after
	var i: int = _expiring.find(n)
	if i != -1:
		_expire_at[i] = at
		return
	_expiring.append(n)
	_expire_at.append(at)


# ------------------------------------------------------------- update ---

func _process(delta: float) -> void:
	var real_dt: float = delta / maxf(Engine.time_scale, 0.001)
	_time += real_dt
	if _hit_stop_until_ms > 0 and Time.get_ticks_msec() >= _hit_stop_until_ms:
		_hit_stop_until_ms = 0
		Engine.time_scale = 1.0
	# Trauma-based shake: offset ~ trauma^2 for a nice falloff.
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - _trauma_decay * real_dt)
		var s: float = trauma * trauma
		var t: float = _time * 31.0
		_shake_offset = Vector3(
			sin(t * 1.13) * 0.6 + sin(t * 2.71) * 0.4,
			sin(t * 1.37 + 1.7) * 0.6 + sin(t * 3.1) * 0.4,
			0.0) * s * MAX_SHAKE_OFFSET
		_shake_roll = sin(t * 0.91 + 4.0) * s * MAX_SHAKE_ROLL
	else:
		_shake_offset = Vector3.ZERO
		_shake_roll = 0.0
	var i: int = _expiring.size() - 1
	while i >= 0:
		if _time >= _expire_at[i]:
			var n: Node = _expiring[i]
			_expiring.remove_at(i)
			_expire_at.remove_at(i)
			_burst_pool.release(n)
			_puff_pool.release(n)
		i -= 1


## Called on scene change so nothing from the old scene lingers.
func clear() -> void:
	trauma = 0.0
	Engine.time_scale = 1.0
	_hit_stop_until_ms = 0
	_text_pool.release_all()
	_burst_pool.release_all()
	_puff_pool.release_all()
	_expiring.clear()
	_expire_at.clear()


## Smoothly ticks a displayed number toward its target (never jumps).
static func tick_number(shown: float, target: float, delta: float, speed: float = 10.0) -> float:
	var diff: float = target - shown
	if absf(diff) < 0.5:
		return target
	var step: float = maxf(absf(diff) * speed * delta, 20.0 * delta)
	return move_toward(shown, target, step)
