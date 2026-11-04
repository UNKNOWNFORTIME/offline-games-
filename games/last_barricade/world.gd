class_name BarricadeWorld
extends Node3D
## Forest dirt road with tall pines, a rocky cliff on the left, drifting
## ground mist and the wooden barricade the player defends.

const BARRICADE_Z: float = -2.6

var planks: Node3D


func build(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = preload("res://shaders/track.gdshader")
	floor_mat.set_shader_parameter("color_a", Color("#4E7148"))
	floor_mat.set_shader_parameter("color_b", Color("#476A42"))
	floor_mat.set_shader_parameter("side_color", Color("#3A5536"))
	floor_mat.set_shader_parameter("band_length", 9.0)
	_box(Vector3(160, 0.4, 160), Vector3(0, -0.21, -70), floor_mat)
	var dirt := ShaderMaterial.new()
	dirt.shader = preload("res://shaders/track.gdshader")
	dirt.set_shader_parameter("color_a", Color("#8C7150"))
	dirt.set_shader_parameter("color_b", Color("#836848"))
	dirt.set_shader_parameter("side_color", Color("#6E573B"))
	dirt.set_shader_parameter("band_length", 2.5)
	_box(Vector3(7.5, 0.2, 110), Vector3(0, -0.08, -52), dirt)
	# Wheel ruts.
	for s: float in [-1.0, 1.0]:
		_box(Vector3(0.5, 0.02, 108), Vector3(s * 1.3, 0.025, -52), Toon.mat(Color("#76603F"), 0.0, 0.1))

	# Pines (two shades) + trunks, densest near the road edges.
	var pines_a: Array[Transform3D] = []
	var pines_b: Array[Transform3D] = []
	var trunks: Array[Transform3D] = []
	for i: int in 170:
		var side: float = -1.0 if rng.randf() < 0.45 else 1.0
		var x: float = side * rng.randf_range(4.6, 45.0)
		if side < 0.0 and x > -16.0 and x < -8.0:
			x -= 10.0  # leave room for the cliff
		var z: float = rng.randf_range(-105.0, 6.0)
		if absf(x) < 7.0 and z > -6.0:
			continue
		var h: float = rng.randf_range(9.0, 17.0)
		var w: float = h * rng.randf_range(0.2, 0.26)
		var xf := Transform3D(Basis().scaled(Vector3(w, h, w)), Vector3(x, h * 0.5 + 1.6, z))
		if rng.randf() < 0.5:
			pines_a.append(xf)
		else:
			pines_b.append(xf)
		trunks.append(Transform3D(Basis().scaled(Vector3(1.6, 3.2, 1.6)), Vector3(x, 1.6, z)))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 7
	cone.rings = 1
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.24
	trunk.height = 1.0
	trunk.radial_segments = 6
	trunk.rings = 1
	_multimesh(cone, Toon.mat(Color("#2F5A3B"), 0.0, 0.25), pines_a)
	_multimesh(cone, Toon.mat(Color("#3B6B45"), 0.0, 0.25), pines_b)
	_multimesh(trunk, Toon.mat(Color("#5E432C"), 0.0, 0.1), trunks)

	# Rocky cliff wall on the left: stacked stretched rocks.
	var rocks: Array[Transform3D] = []
	var z: float = 4.0
	while z > -105.0:
		for k: int in 3:
			var sx: float = rng.randf_range(3.0, 6.0)
			var sy: float = rng.randf_range(4.0, 11.0) + float(k) * 3.0
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sx, sy, rng.randf_range(3.0, 6.0)))
			rocks.append(Transform3D(b, Vector3(-9.5 - float(k) * 3.0 - rng.randf_range(0.0, 2.0), sy * 0.35, z + rng.randf_range(-3.0, 3.0))))
		z -= 6.5
	for i: int in 26:
		var s: float = -1.0 if rng.randf() < 0.5 else 1.0
		var r: float = rng.randf_range(0.3, 1.1)
		rocks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(r * 1.4, r, r)), Vector3(s * rng.randf_range(4.2, 9.0), 0.1, rng.randf_range(-90.0, -4.0))))
	var rock := SphereMesh.new()
	rock.radius = 1.0
	rock.height = 2.0
	rock.radial_segments = 7
	rock.rings = 4
	_multimesh(rock, Toon.mat(Color("#8E979C"), 0.0, 0.3), rocks)

	# Ground mist cards.
	var mist_mat := ShaderMaterial.new()
	mist_mat.shader = preload("res://shaders/mist.gdshader")
	mist_mat.set_shader_parameter("opacity", 0.28 if Settings.is_high() else 0.2)
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var cards: int = 9 if Settings.is_high() else 5
	for i: int in cards:
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = mist_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(rng.randf_range(-6.0, 6.0), 0.55, -8.0 - float(i) * 8.5)
		mi.scale = Vector3(rng.randf_range(9.0, 15.0), rng.randf_range(1.6, 2.6), 1.0)
		add_child(mi)

	_build_barricade()


func _build_barricade() -> void:
	planks = Node3D.new()
	planks.position = Vector3(0, 0, BARRICADE_Z)
	add_child(planks)
	var wood: ShaderMaterial = Toon.mat(Color("#A0784E"), 0.02, 0.35)
	var wood_d: ShaderMaterial = Toon.mat(Color("#7D5A37"), 0.02, 0.3)
	var nail: ShaderMaterial = Toon.mat(Color("#3B4252"), 0.0, 0.4)
	for s: float in [-1.0, 1.0]:
		var p: MeshInstance3D = _box_in(planks, Vector3(0.3, 1.6, 0.3), Vector3(s * 3.4, 0.8, 0), wood_d)
		p.rotation.z = s * 0.04
	var ys: Array = [0.3, 0.72, 1.12]
	for i: int in ys.size():
		var pl: MeshInstance3D = _box_in(planks, Vector3(7.2, 0.3, 0.12), Vector3(0, float(ys[i]), 0.2), wood if i % 2 == 0 else wood_d)
		pl.rotation.z = [0.03, -0.025, 0.015][i]
		for s: float in [-1.0, 1.0]:
			_box_in(planks, Vector3(0.05, 0.05, 0.04), Vector3(s * 3.35, float(ys[i]), 0.27), nail)
	var cross: MeshInstance3D = _box_in(planks, Vector3(4.2, 0.24, 0.1), Vector3(-1.0, 0.7, 0.3), wood)
	cross.rotation.z = 0.3
	# Sandbags in front.
	var bag := SphereMesh.new()
	bag.radius = 0.35
	bag.height = 0.4
	bag.radial_segments = 10
	bag.rings = 4
	var bag_mat: ShaderMaterial = Toon.mat(Color("#C8B58A"), 0.02, 0.2)
	for i: int in 9:
		var mi := MeshInstance3D.new()
		mi.mesh = bag
		mi.material_override = bag_mat
		mi.scale = Vector3(1.3, 1.0, 0.9)
		mi.position = Vector3(-3.2 + float(i) * 0.8, 0.18, -0.35)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		planks.add_child(mi)


## Wobble the planks when hit.
func shake_barricade() -> void:
	var t: Tween = planks.create_tween()
	planks.position.x = 0.06
	t.tween_property(planks, "position:x", 0.0, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	return _box_in(self, size, pos, mat)


func _box_in(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _multimesh(mesh: Mesh, mat: Material, xfs: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i: int in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
