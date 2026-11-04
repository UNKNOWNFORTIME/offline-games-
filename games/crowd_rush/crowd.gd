class_name CrowdSwarm
extends Node3D
## A crowd rendered as ONE MultiMeshInstance3D (one draw call).
## Formation: sunflower / Fibonacci spiral around the leader; units glide to
## their slots, pop in with a 0 -> 1.15 -> 1.0 scale over 0.2 s (staggered
## from the center outward), and pop out with a particle puff.
## The real count can exceed the visible cap; the label shows the real count.
## Animation (run cycle, bob) is in the shader. Zero allocations per frame.

signal count_changed(new_count: int, delta: int)

const GOLDEN_ANGLE: float = 2.39996323
const FLOATS_PER_INSTANCE: int = 16  # 12 transform + 4 custom
const POP_TIME: float = 0.2
const MAX_PUFFS_PER_CHANGE: int = 8
const MAX_COUNT: int = 99_999

var team_color: Color = Palette.PLAYER
var max_visible: int = 300
var spacing: float = 0.42
var count: int = 0
var visible_count: int = 0
## Max half-width (local X) the blob may occupy; the formation squeezes
## sideways and stretches in depth to fit (e.g. against rails).
var squeeze_half_width: float = 100.0
var celebrate: bool = false

var _mm: MultiMesh
var _mmi: MultiMeshInstance3D
var _mat: ShaderMaterial
var _buf: PackedFloat32Array = PackedFloat32Array()
var _slots: PackedVector2Array = PackedVector2Array()
var _pos: PackedVector3Array = PackedVector3Array()
var _age: PackedFloat32Array = PackedFloat32Array()
var _phase: PackedFloat32Array = PackedFloat32Array()
var _tint: PackedFloat32Array = PackedFloat32Array()
var _label: Label3D
var _label_bg: MeshInstance3D
var _shown_count: float = 0.0
var _run_amount: float = 1.0
var _sx: float = 1.0
var _sz: float = 1.0


func setup(p_team_color: Color, p_max_visible: int, show_label: bool = true) -> void:
	team_color = p_team_color
	max_visible = maxi(1, p_max_visible)
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/crowd_unit.gdshader")
	_mat.set_shader_parameter("team_color", team_color)
	_mat.set_shader_parameter("skin_color", Palette.SKIN)
	_mat.set_shader_parameter("shadow_tint", Color(0.5, 0.56, 0.9))
	_mat.set_shader_parameter("rim_strength", 0.45)

	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = RunnerMesh.get_mesh()
	_mm.instance_count = max_visible
	_mm.visible_instance_count = 0

	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = _mm
	_mmi.material_override = _mat
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Settings.shadows_enabled() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Generous AABB so frustum culling never pops the crowd.
	_mmi.custom_aabb = AABB(Vector3(-12, -2, -14), Vector3(24, 6, 28))
	add_child(_mmi)

	_buf.resize(max_visible * FLOATS_PER_INSTANCE)
	_slots.resize(max_visible)
	_pos.resize(max_visible)
	_age.resize(max_visible)
	_phase.resize(max_visible)
	_tint.resize(max_visible)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(team_color.to_rgba32())
	for i: int in max_visible:
		var r: float = spacing * sqrt(float(i) + 0.35)
		var a: float = float(i) * GOLDEN_ANGLE
		_slots[i] = Vector2(cos(a) * r, sin(a) * r)
		_phase[i] = rng.randf()
		_tint[i] = rng.randf()

	if show_label:
		_build_label()


func _build_label() -> void:
	_label = Label3D.new()
	_label.font = UiKit.font()
	_label.font_size = 120
	_label.outline_size = 28
	_label.pixel_size = 0.0065
	_label.modulate = Color.WHITE
	_label.outline_modulate = Palette.shade(team_color, 0.45)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.render_priority = 5
	_label.outline_render_priority = 4
	_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_label.position = Vector3(0, 2.1, 0)
	_label.set_meta("base_scale", 1.0)
	add_child(_label)
	# Rounded "pill" behind the number for readability on any background.
	_label_bg = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.5, 0.95)
	_label_bg.mesh = q
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/badge.gdshader")
	m.set_shader_parameter("color", team_color)
	m.set_shader_parameter("border_color", Palette.shade(team_color, 0.5))
	m.set_shader_parameter("size", q.size)
	m.render_priority = 3
	_label_bg.material_override = m
	_label_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_label_bg.position = Vector3(0, 2.1, 0)
	_label_bg.set_meta("base_scale", 1.0)
	add_child(_label_bg)


var run_amount: float:
	get:
		return _run_amount
	set(v):
		_run_amount = clampf(v, 0.0, 1.0)
		if _mat != null:
			_mat.set_shader_parameter("run_amount", _run_amount)


func material() -> ShaderMaterial:
	return _mat


## Blob radius in local units after squeeze (X half-width, Z half-depth).
func extent_x() -> float:
	return spacing * sqrt(float(maxi(visible_count, 1))) * _sx + 0.2


func extent_z() -> float:
	return spacing * sqrt(float(maxi(visible_count, 1))) * _sz + 0.2


func natural_radius() -> float:
	return spacing * sqrt(float(maxi(visible_count, 1))) + 0.2


func show_label(on: bool) -> void:
	if _label != null:
		_label.visible = on
		_label_bg.visible = on


## Sets the real count. New visible units pop in; removed ones pop out with
## a puff (rate-limited so a ÷10 gate doesn't spawn hundreds of emitters).
func set_count(n: int, animate: bool = true) -> void:
	n = clampi(n, 0, MAX_COUNT)
	var old: int = count
	count = n
	var new_visible: int = mini(n, max_visible)
	if new_visible > visible_count:
		for i: int in range(visible_count, new_visible):
			var s: Vector2 = _slots[i]
			_pos[i] = Vector3(s.x * _sx, 0.0, s.y * _sz)
			# Stagger: inner units first -> the blob "blooms" outward.
			_age[i] = -float(i - visible_count) * 0.0025 if animate else POP_TIME
	elif new_visible < visible_count:
		if animate:
			var removed: int = visible_count - new_visible
			var stride: int = maxi(1, removed / MAX_PUFFS_PER_CHANGE)
			var i: int = visible_count - 1
			while i >= new_visible:
				if (visible_count - 1 - i) % stride == 0:
					Juice.puff(to_global(_pos[i] + Vector3(0, 0.45, 0)), team_color.lightened(0.35))
				i -= 1
	visible_count = new_visible
	_mm.visible_instance_count = visible_count
	if old != n:
		count_changed.emit(n, n - old)
		if animate and _label != null:
			Juice.punch_scale(_label, 0.35 if n > old else 0.2, 0.3)
			Juice.punch_scale(_label_bg, 0.3 if n > old else 0.15, 0.3)
	if not animate:
		_shown_count = float(n)


## World position of a unit near the front (for effects).
func front_world_point(forward_sign: float = -1.0) -> Vector3:
	return to_global(Vector3(0, 0.5, extent_z() * forward_sign))


func _process(delta: float) -> void:
	if _mm == null:
		return
	# Squeeze formation to the allowed width, stretch depth to keep density.
	var r: float = spacing * sqrt(float(maxi(visible_count, 1)))
	var target_sx: float = 1.0
	if r > squeeze_half_width and r > 0.01:
		target_sx = maxf(squeeze_half_width / r, 0.25)
	_sx = lerpf(_sx, target_sx, 1.0 - exp(-8.0 * delta))
	_sz = minf(1.0 / _sx, 3.0)
	var k: float = 1.0 - exp(-11.0 * delta)
	var cel: float = 1.0 if celebrate else 0.0
	for i: int in visible_count:
		var s: Vector2 = _slots[i]
		var tgt := Vector3(s.x * _sx, 0.0, s.y * _sz)
		var p: Vector3 = _pos[i].lerp(tgt, k)
		_pos[i] = p
		var age: float = _age[i] + delta
		_age[i] = age
		var sc: float = _pop_scale(age)
		var o: int = i * FLOATS_PER_INSTANCE
		_buf[o] = sc
		_buf[o + 1] = 0.0
		_buf[o + 2] = 0.0
		_buf[o + 3] = p.x
		_buf[o + 4] = 0.0
		_buf[o + 5] = sc
		_buf[o + 6] = 0.0
		_buf[o + 7] = p.y
		_buf[o + 8] = 0.0
		_buf[o + 9] = 0.0
		_buf[o + 10] = sc
		_buf[o + 11] = p.z
		_buf[o + 12] = _phase[i]
		_buf[o + 13] = _tint[i]
		_buf[o + 14] = cel
		_buf[o + 15] = 0.0
	_mm.buffer = _buf
	_update_label(delta)


func _pop_scale(age: float) -> float:
	if age <= 0.0:
		return 0.0
	if age >= POP_TIME:
		return 1.0
	var t: float = age / POP_TIME
	if t < 0.6:
		return lerpf(0.0, 1.15, t / 0.6)
	return lerpf(1.15, 1.0, (t - 0.6) / 0.4)


func _update_label(delta: float) -> void:
	if _label == null or not _label.visible:
		return
	if _shown_count != float(count):
		_shown_count = Juice.tick_number(_shown_count, float(count), delta, 12.0)
	var txt: String = str(int(_shown_count))
	if _label.text != txt:
		_label.text = txt
		var w: float = 0.9 + 0.38 * float(txt.length())
		(_label_bg.mesh as QuadMesh).size = Vector2(w, 0.95)
		(_label_bg.material_override as ShaderMaterial).set_shader_parameter("size", Vector2(w, 0.95))
	var h: float = 1.9 + minf(extent_z() * 0.1, 0.8)
	_label.position = Vector3(0, h, 0)
	_label_bg.position = Vector3(0, h, -0.01)
