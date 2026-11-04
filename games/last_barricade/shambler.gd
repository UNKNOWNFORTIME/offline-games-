class_name Shambler
extends Node3D
## Chunky, non-gory forest shambler (pooled). One baked mesh with its own
## material (flash/dissolve/arm swing), optional wooden plank shield that
## absorbs frontal hits. Faces +Z (toward the barricade/camera).

signal defeated(s: Shambler, headshot: bool)

static var _body_mesh: ArrayMesh = null
static var _shield_mesh: ArrayMesh = null

var alive: bool = false
var hp: float = 2.0
var speed: float = 1.4
var shield_hp: float = 0.0
var attacking: bool = false
var size_k: float = 1.0
var _attack_timer: float = 0.0
var _t: float = 0.0
var _phase: float = 0.0
var _mat: ShaderMaterial
var _mi: MeshInstance3D
var _shield: MeshInstance3D
var _wander: float = 0.0


func setup() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/enemy.gdshader")
	_mat.set_shader_parameter("shadow_tint", Color(0.55, 0.62, 0.66))
	_mat.set_shader_parameter("rim_strength", 0.3)
	_mi = MeshInstance3D.new()
	_mi.mesh = body_mesh()
	_mi.material_override = _mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)
	_shield = MeshInstance3D.new()
	_shield.mesh = shield_mesh()
	var sm: ShaderMaterial = Toon.unique(Color.WHITE, 0.0, 0.3)
	sm.set_shader_parameter("use_vertex_color", true)
	_shield.material_override = sm
	_shield.position = Vector3(0, 1.0, 0.55)
	_shield.rotation.x = -0.12
	_shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shield)
	visible = false


func spawn(pos: Vector3, p_hp: float, p_speed: float, shielded: bool, tint: Color) -> void:
	position = pos
	hp = p_hp
	speed = p_speed * randf_range(0.85, 1.15)
	shield_hp = 4.0 if shielded else 0.0
	_shield.visible = shielded
	_shield.position = Vector3(0, 1.0, 0.55)
	_shield.rotation = Vector3(-0.12, 0, 0)
	alive = true
	attacking = false
	_attack_timer = randf_range(0.3, 1.0)
	_phase = randf() * TAU
	_wander = randf() * TAU
	size_k = randf_range(0.92, 1.15)
	scale = Vector3.ONE * size_k
	rotation = Vector3.ZERO
	_mat.set_shader_parameter("phase", _phase)
	_mat.set_shader_parameter("dissolve", 0.0)
	_mat.set_shader_parameter("flash", 0.0)
	_mat.set_shader_parameter("walk", 1.0)
	_mat.set_shader_parameter("attack", 0.0)
	_mat.set_shader_parameter("tint", tint)
	visible = true


## Moves toward the barricade; returns damage dealt this frame.
func step(delta: float, stop_z: float) -> float:
	if not alive:
		return 0.0
	_t += delta
	if not attacking:
		position.z += speed * delta
		position.x += sin(_t * 0.7 + _wander) * 0.25 * delta - position.x * 0.04 * delta
		# Shuffle: heavy side-to-side sway and a limping bob.
		rotation.z = sin(_t * 3.2 + _phase) * 0.12
		rotation.y = sin(_t * 1.6 + _phase) * 0.15
		position.y = absf(sin(_t * 3.2 + _phase)) * 0.08
		if position.z >= stop_z:
			position.z = stop_z
			attacking = true
			_mat.set_shader_parameter("walk", 0.3)
		return 0.0
	_attack_timer -= delta
	var a: float = clampf(1.0 - _attack_timer / 0.25, 0.0, 1.0) if _attack_timer < 0.25 else 0.0
	_mat.set_shader_parameter("attack", a)
	if _attack_timer <= 0.0:
		_attack_timer = randf_range(1.0, 1.4)
		var t: Tween = create_tween()
		t.tween_property(self, "position:z", stop_z + 0.35, 0.08)
		t.tween_property(self, "position:z", stop_z, 0.2)
		return randf_range(4.0, 7.0)
	return 0.0


## Ray test against shield (box), head and body (spheres). Returns
## {"t": float, "part": String} for the nearest hit, or {} for a miss.
func ray_test(ro: Vector3, rd: Vector3) -> Dictionary:
	if not alive:
		return {}
	var best_t: float = INF
	var part: String = ""
	var k: float = size_k
	var base: Vector3 = global_position
	var head: Vector3 = base + Vector3(0, 1.52 * k, 0.2 * k)
	var t_head: float = _ray_sphere(ro, rd, head, 0.27 * k)
	if t_head < best_t:
		best_t = t_head
		part = "head"
	var t_body: float = _ray_sphere(ro, rd, base + Vector3(0, 1.0 * k, 0.05), 0.42 * k)
	if t_body < best_t:
		best_t = t_body
		part = "body"
	var t_legs: float = _ray_sphere(ro, rd, base + Vector3(0, 0.42 * k, 0), 0.32 * k)
	if t_legs < best_t:
		best_t = t_legs
		part = "body"
	if shield_hp > 0.0:
		var c: Vector3 = base + Vector3(0, 1.0 * k, 0.55 * k)
		var t_sh: float = _ray_box(ro, rd, c - Vector3(0.48, 0.58, 0.1) * k, c + Vector3(0.48, 0.58, 0.1) * k)
		if t_sh < best_t:
			best_t = t_sh
			part = "shield"
	if part == "":
		return {}
	return {"t": best_t, "part": part}


## Applies a hit. Returns true if the shambler was defeated.
func take_hit(dmg: float, part: String, from_dir: Vector3) -> bool:
	if not alive:
		return false
	if part == "shield":
		shield_hp -= dmg
		Juice.punch_scale(_shield, 0.15, 0.15)
		if shield_hp <= 0.0:
			_drop_shield(from_dir)
		return false
	var mult: float = 2.0 if part == "head" else 1.0
	hp -= dmg * mult
	Juice.flash(_mat, 0.06)
	# Small knockback stagger.
	position.z -= 0.12 * dmg
	rotation.x = -0.25
	create_tween().tween_property(self, "rotation:x", 0.0, 0.25)
	if hp <= 0.0:
		_die(part == "head")
		return true
	return false


func _drop_shield(from_dir: Vector3) -> void:
	AudioManager.play("barricade_hit", 0.1, -4.0)
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(_shield, "position", _shield.position + Vector3(from_dir.x * 0.4, -0.95, 0.5), 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.tween_property(_shield, "rotation", Vector3(-1.5, randf_range(-0.6, 0.6), 0), 0.4)
	Juice.burst(_shield.global_position, Color("#A0784E"), 0.6)


func _die(headshot: bool) -> void:
	alive = false
	attacking = false
	defeated.emit(self, headshot)
	Juice.puff(global_position + Vector3(0, 1.2 * size_k, 0), Color("#B9C7B4"))
	Juice.puff(global_position + Vector3(0, 0.6 * size_k, 0), Color("#8FA08A"))
	var t: Tween = create_tween()
	t.tween_method(func(v: float) -> void: _mat.set_shader_parameter("dissolve", v), 0.0, 1.0, 0.55)
	t.parallel().tween_property(self, "position:y", position.y + 0.25, 0.55)
	t.tween_callback(func() -> void: visible = false)


static func _ray_sphere(ro: Vector3, rd: Vector3, c: Vector3, r: float) -> float:
	var oc: Vector3 = ro - c
	var b: float = oc.dot(rd)
	var cc: float = oc.dot(oc) - r * r
	var h: float = b * b - cc
	if h < 0.0:
		return INF
	var t: float = -b - sqrt(h)
	return t if t > 0.0 else INF


static func _ray_box(ro: Vector3, rd: Vector3, bmin: Vector3, bmax: Vector3) -> float:
	var t0: float = -INF
	var t1: float = INF
	for i: int in 3:
		var d: float = rd[i]
		if absf(d) < 0.00001:
			if ro[i] < bmin[i] or ro[i] > bmax[i]:
				return INF
			continue
		var ta: float = (bmin[i] - ro[i]) / d
		var tb: float = (bmax[i] - ro[i]) / d
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
	if t1 < t0 or t1 < 0.0:
		return INF
	return t0 if t0 > 0.0 else INF


# ------------------------------------------------------------ meshes ---

static func body_mesh() -> ArrayMesh:
	if _body_mesh != null:
		return _body_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pants := Color("#4D5446")
	var shirt := Color("#6E7D68")
	var skin := Color("#A3B597")
	var dark := Color("#2E3329")
	for s: float in [-1.0, 1.0]:
		_add(st, _capsule(0.11, 0.72), Transform3D(Basis(), Vector3(s * 0.14, 0.36, 0)), Color(pants, 1.0))
		_add(st, _box(Vector3(0.18, 0.1, 0.3)), Transform3D(Basis(), Vector3(s * 0.14, 0.05, 0.05)), Color(dark, 1.0))
	# Hunched torso leaning toward the barricade.
	_add(st, _capsule(0.28, 0.85), Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, 1.0, 0.05)), Color(shirt, 1.0))
	_add(st, _box(Vector3(0.5, 0.12, 0.42)), Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, 0.72, 0.0)), Color(pants.darkened(0.2), 1.0))
	_add(st, _sphere(0.23), Transform3D(Basis(), Vector3(0, 1.52, 0.2)), Color(skin, 1.0))
	_add(st, _sphere(0.25), Transform3D(Basis().scaled(Vector3(1.0, 0.45, 1.0)), Vector3(0, 1.66, 0.17)), Color(Color("#5A4B3A"), 1.0))
	for s: float in [-1.0, 1.0]:
		_add(st, _sphere(0.045), Transform3D(Basis(), Vector3(s * 0.08, 1.55, 0.41)), Color(Color("#E8F0D8"), 1.0))
		_add(st, _sphere(0.025), Transform3D(Basis(), Vector3(s * 0.08, 1.55, 0.45)), Color(dark, 1.0))
	# Mismatched arms (left longer), hanging from the shoulders at y=1.32.
	var left_len: float = 0.78
	var right_len: float = 0.58
	_add(st, _capsule(0.08, left_len), Transform3D(Basis(), Vector3(-0.36, 1.32 - left_len * 0.5, 0.12)), Color(shirt.lightened(0.05), 0.6))
	_add(st, _sphere(0.1), Transform3D(Basis(), Vector3(-0.36, 1.32 - left_len, 0.12)), Color(skin, 0.6))
	_add(st, _capsule(0.08, right_len), Transform3D(Basis(), Vector3(0.36, 1.32 - right_len * 0.5, 0.12)), Color(shirt.lightened(0.05), 0.3))
	_add(st, _sphere(0.1), Transform3D(Basis(), Vector3(0.36, 1.32 - right_len, 0.12)), Color(skin, 0.3))
	st.index()
	_body_mesh = st.commit()
	return _body_mesh


static func shield_mesh() -> ArrayMesh:
	if _shield_mesh != null:
		return _shield_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := Color("#A0784E")
	for i: int in 3:
		_add(st, _box(Vector3(0.3, 1.1, 0.07)), Transform3D(Basis(), Vector3(-0.31 + float(i) * 0.31, 0.0, 0.0)), wood.darkened(float(i % 2) * 0.12))
	_add(st, _box(Vector3(0.98, 0.14, 0.05)), Transform3D(Basis(), Vector3(0, 0.3, 0.06)), wood.darkened(0.3))
	_add(st, _box(Vector3(0.98, 0.14, 0.05)), Transform3D(Basis(), Vector3(0, -0.3, 0.06)), wood.darkened(0.3))
	st.index()
	_shield_mesh = st.commit()
	return _shield_mesh


static func _add(st: SurfaceTool, prim: PrimitiveMesh, xf: Transform3D, col: Color) -> void:
	var arrays: Array = prim.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var nb: Basis = xf.basis.inverse().transposed()
	for idx: int in indices:
		st.set_color(col)
		st.set_normal((nb * normals[idx]).normalized())
		st.add_vertex(xf * verts[idx])


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 8
	m.rings = 2
	return m


static func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 5
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m
