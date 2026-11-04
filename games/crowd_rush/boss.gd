class_name CrowdBoss
extends Node3D
## Big red brute built from primitives (~4.5 m tall, ~5x a runner).
## Idle breathing, stomp attack (signal on impact), hit flash, punch, death.

signal stomped
signal died

var hp_max: int = 30
var hp: int = 30
var dead: bool = false

var _rig: Node3D
var _body_mat: ShaderMaterial
var _dark_mat: ShaderMaterial
var _arm_l: Node3D
var _arm_r: Node3D
var _idle_tween: Tween
var _hp_bar: MeshInstance3D
var _hp_mat: ShaderMaterial
var _hp_label: Label3D
var _shown_hp: float = 30.0


func build(p_hp: int) -> void:
	hp_max = maxi(1, p_hp)
	hp = hp_max
	_shown_hp = float(hp)
	_body_mat = Toon.unique(Palette.ENEMY, 0.05, 0.5)
	_dark_mat = Toon.unique(Color("#9E1F2A"), 0.05, 0.4)
	var light_mat: ShaderMaterial = Toon.mat(Palette.ENEMY_LIGHT, 0.0, 0.4)
	var white_mat: ShaderMaterial = Toon.mat(Color.WHITE, 0.0, 0.2)
	var black_mat: ShaderMaterial = Toon.mat(Palette.UI_DARK, 0.0, 0.1)
	var horn_mat: ShaderMaterial = Toon.mat(Color("#FFE7B8"), 0.04, 0.5)

	_rig = Node3D.new()
	add_child(_rig)
	# Legs.
	for sx: float in [-1.0, 1.0]:
		_part(_capsule(0.48, 1.5), _dark_mat, Vector3(sx * 0.6, 0.75, 0), Vector3.ZERO, Vector3.ONE)
	# Torso + belly.
	_part(_sphere(1.2, 2.5), _body_mat, Vector3(0, 2.35, 0), Vector3.ZERO, Vector3(1.15, 1.0, 0.85))
	_part(_sphere(0.8, 1.5), light_mat, Vector3(0, 2.15, 0.45), Vector3.ZERO, Vector3(1.0, 1.0, 0.6))
	# Belt.
	var belt := CylinderMesh.new()
	belt.top_radius = 1.12
	belt.bottom_radius = 1.12
	belt.height = 0.35
	belt.radial_segments = 16
	belt.rings = 1
	_part(belt, _dark_mat, Vector3(0, 1.45, 0), Vector3.ZERO, Vector3(1.05, 1.0, 0.82))
	# Arms (pivot at shoulder so they can swing).
	_arm_l = _arm(-1.0)
	_arm_r = _arm(1.0)
	# Head.
	var head := Node3D.new()
	head.position = Vector3(0, 3.85, 0.1)
	_rig.add_child(head)
	var hb := BoxMesh.new()
	hb.size = Vector3(1.15, 0.95, 1.0)
	_part(hb, _body_mat, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, head)
	for sx: float in [-1.0, 1.0]:
		_part(_sphere(0.17, 0.34), white_mat, Vector3(sx * 0.27, 0.05, 0.5), Vector3.ZERO, Vector3.ONE, head)
		_part(_sphere(0.08, 0.16), black_mat, Vector3(sx * 0.25, 0.03, 0.64), Vector3.ZERO, Vector3.ONE, head)
		var brow := BoxMesh.new()
		brow.size = Vector3(0.4, 0.1, 0.12)
		_part(brow, black_mat, Vector3(sx * 0.27, 0.27, 0.52), Vector3(0, 0, -sx * 0.45), Vector3.ONE, head)
		var horn := CylinderMesh.new()
		horn.top_radius = 0.0
		horn.bottom_radius = 0.16
		horn.height = 0.6
		horn.radial_segments = 8
		horn.rings = 1
		_part(horn, horn_mat, Vector3(sx * 0.45, 0.65, 0), Vector3(0, 0, -sx * 0.5), Vector3.ONE, head)
	var mouth := BoxMesh.new()
	mouth.size = Vector3(0.5, 0.1, 0.1)
	_part(mouth, black_mat, Vector3(0, -0.25, 0.51), Vector3.ZERO, Vector3.ONE, head)
	for sx: float in [-1.0, 1.0]:
		var tusk := CylinderMesh.new()
		tusk.top_radius = 0.0
		tusk.bottom_radius = 0.06
		tusk.height = 0.22
		tusk.radial_segments = 6
		tusk.rings = 1
		_part(tusk, white_mat, Vector3(sx * 0.18, -0.12, 0.53), Vector3.ZERO, Vector3.ONE, head)

	_build_hp_bar()
	_start_idle()


func _arm(sx: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(sx * 1.3, 3.05, 0)
	_rig.add_child(pivot)
	_part(_sphere(0.55, 1.1), _body_mat, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, pivot)
	_part(_capsule(0.38, 1.7), _body_mat, Vector3(sx * 0.15, -0.85, 0), Vector3(0, 0, sx * 0.12), Vector3.ONE, pivot)
	_part(_sphere(0.55, 1.1), _dark_mat, Vector3(sx * 0.28, -1.85, 0.05), Vector3.ZERO, Vector3.ONE, pivot)
	return pivot


func _build_hp_bar() -> void:
	_hp_bar = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(3.2, 0.42)
	_hp_bar.mesh = q
	_hp_mat = ShaderMaterial.new()
	_hp_mat.shader = preload("res://shaders/badge.gdshader")
	_hp_mat.set_shader_parameter("color", Palette.UI_DARK_SOFT)
	_hp_mat.set_shader_parameter("fill_color", Palette.ENEMY)
	_hp_mat.set_shader_parameter("size", q.size)
	_hp_mat.set_shader_parameter("radius", 0.21)
	_hp_mat.set_shader_parameter("border", 0.06)
	_hp_mat.set_shader_parameter("fill", 1.0)
	_hp_mat.render_priority = 3
	_hp_bar.material_override = _hp_mat
	_hp_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hp_bar.position = Vector3(0, 5.6, 0)
	add_child(_hp_bar)
	_hp_label = Label3D.new()
	_hp_label.font = UiKit.font()
	_hp_label.font_size = 90
	_hp_label.outline_size = 22
	_hp_label.pixel_size = 0.006
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label.no_depth_test = true
	_hp_label.render_priority = 5
	_hp_label.outline_render_priority = 4
	_hp_label.outline_modulate = Palette.UI_DARK
	_hp_label.position = Vector3(0, 6.15, 0)
	_hp_label.text = str(hp)
	_hp_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hp_label)


func _part(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3, scl: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Settings.shadows_enabled() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else _rig).add_child(mi)
	return mi


func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 12
	m.rings = 3
	return m


func _sphere(r: float, h: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 14
	m.rings = 7
	return m


func _start_idle() -> void:
	if _idle_tween != null:
		_idle_tween.kill()
	_idle_tween = create_tween().set_loops()
	_idle_tween.set_parallel(false)
	_idle_tween.tween_property(_rig, "scale", Vector3(1.04, 0.96, 1.04), 0.55).set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_property(_rig, "scale", Vector3(0.98, 1.03, 0.98), 0.55).set_trans(Tween.TRANS_SINE)
	var arms: Tween = create_tween().set_loops()
	arms.tween_property(_arm_l, "rotation:z", -0.18, 0.55).set_trans(Tween.TRANS_SINE)
	arms.parallel().tween_property(_arm_r, "rotation:z", 0.18, 0.55).set_trans(Tween.TRANS_SINE)
	arms.tween_property(_arm_l, "rotation:z", 0.0, 0.55).set_trans(Tween.TRANS_SINE)
	arms.parallel().tween_property(_arm_r, "rotation:z", 0.0, 0.55).set_trans(Tween.TRANS_SINE)


## Ground slam: arms up, jump, slam. Emits `stomped` at impact.
func stomp() -> void:
	if dead:
		return
	var t: Tween = create_tween()
	t.tween_property(_rig, "position:y", 0.7, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_arm_l, "rotation:x", -2.4, 0.18)
	t.parallel().tween_property(_arm_r, "rotation:x", -2.4, 0.18)
	t.tween_property(_rig, "position:y", 0.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_arm_l, "rotation:x", 0.5, 0.1)
	t.parallel().tween_property(_arm_r, "rotation:x", 0.5, 0.1)
	t.tween_callback(func() -> void:
		if not dead:
			stomped.emit())
	t.tween_property(_arm_l, "rotation:x", 0.0, 0.3)
	t.parallel().tween_property(_arm_r, "rotation:x", 0.0, 0.3)


func damage(amount: int) -> void:
	if dead:
		return
	hp = maxi(0, hp - amount)
	_hp_mat.set_shader_parameter("fill", float(hp) / float(hp_max))
	if hp <= 0:
		_die()


## Visual-only hit reaction (throttled by the caller).
func hit_react() -> void:
	Juice.flash(_body_mat, 0.06)
	Juice.flash(_dark_mat, 0.06)
	var t: Tween = create_tween()
	_rig.rotation.x = -0.08
	t.tween_property(_rig, "rotation:x", 0.0, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _hp_label != null and _hp_label.visible:
		_shown_hp = Juice.tick_number(_shown_hp, float(hp), delta, 14.0)
		_hp_label.text = str(int(_shown_hp))


func _die() -> void:
	dead = true
	if _idle_tween != null:
		_idle_tween.kill()
	_hp_bar.visible = false
	_hp_label.visible = false
	Juice.flash(_body_mat, 0.15)
	Juice.flash(_dark_mat, 0.15)
	var t: Tween = create_tween()
	t.tween_property(_rig, "scale", Vector3(1.25, 0.8, 1.25), 0.1)
	t.tween_property(_rig, "scale", Vector3.ONE, 0.15)
	t.tween_property(_rig, "rotation:x", -1.45, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_rig, "position:z", -1.4, 0.55)
	t.tween_callback(func() -> void:
		Juice.burst(global_position + Vector3(0, 1.0, -2.0), Palette.ENEMY_LIGHT, 1.6)
		Juice.screen_shake(0.5, 0.4)
		AudioManager.play("stomp")
		died.emit())
	t.tween_interval(0.6)
	t.tween_property(_rig, "scale", Vector3(1.0, 0.01, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
