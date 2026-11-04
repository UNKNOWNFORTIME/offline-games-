class_name CrowdTrack
extends Node3D
## Builds the Crowd Rush world: floating track over stylized water, side
## curbs + low rails, support pillars, start/finish checker lines, the clash
## arena with boss podium, and instanced scenery (islands, pines, clouds).
## Scenery is MultiMesh-instanced: ~15 draw calls for the whole world.

const HALF_WIDTH: float = 4.0
const ARENA_HALF_WIDTH: float = 7.0
const ARENA_LENGTH: float = 52.0
const START_PAD: float = 18.0
const THICKNESS: float = 0.9

var length: float = 140.0
var water: MeshInstance3D
var enemy_z: float = 0.0
var boss_z: float = 0.0
var finish_z: float = 0.0


func build(p_length: float, seed_value: int) -> void:
	length = p_length
	finish_z = -length
	enemy_z = -length - 14.0
	boss_z = -length - 36.0
	var track_mat := ShaderMaterial.new()
	track_mat.shader = preload("res://shaders/track.gdshader")
	track_mat.set_shader_parameter("color_a", Palette.TRACK)
	track_mat.set_shader_parameter("color_b", Palette.TRACK.darkened(0.05))
	track_mat.set_shader_parameter("side_color", Color("#9AA6BC"))
	track_mat.set_shader_parameter("band_length", 4.0)
	track_mat.set_shader_parameter("shadow_tint", Color(0.55, 0.6, 0.86))

	# Main track slab.
	var total: float = length + START_PAD
	_box(Vector3(HALF_WIDTH * 2.0, THICKNESS, total), Vector3(0, -THICKNESS * 0.5, START_PAD - total * 0.5), track_mat)
	# Arena slab (wider).
	_box(Vector3(ARENA_HALF_WIDTH * 2.0, THICKNESS, ARENA_LENGTH), Vector3(0, -THICKNESS * 0.5 - 0.001, -length - ARENA_LENGTH * 0.5 + 0.5), track_mat)
	# Flared connection wedges (simple boxes rotated).
	for sx: float in [-1.0, 1.0]:
		var wedge := _box(Vector3(3.2, THICKNESS, 5.0), Vector3(sx * (HALF_WIDTH + 1.2), -THICKNESS * 0.5 - 0.002, -length + 1.8), track_mat)
		wedge.rotation.y = sx * 0.55

	# Curbs: striped blue/white strips on the track edges.
	var curb_mat := ShaderMaterial.new()
	curb_mat.shader = preload("res://shaders/track.gdshader")
	curb_mat.set_shader_parameter("color_a", Palette.PLAYER)
	curb_mat.set_shader_parameter("color_b", Color.WHITE)
	curb_mat.set_shader_parameter("side_color", Palette.shade(Palette.PLAYER, 0.3))
	curb_mat.set_shader_parameter("band_length", 2.0)
	for sx: float in [-1.0, 1.0]:
		_box(Vector3(0.45, 0.12, total), Vector3(sx * (HALF_WIDTH - 0.22), 0.06, START_PAD - total * 0.5), curb_mat)

	# Low rails on posts.
	var rail_mat: ShaderMaterial = Toon.mat(Palette.METAL.lightened(0.25), 0.0, 0.5)
	var post_xf: Array[Transform3D] = []
	var post_spacing: float = 3.0
	var z: float = START_PAD
	while z > -length:
		for sx: float in [-1.0, 1.0]:
			post_xf.append(Transform3D(Basis(), Vector3(sx * (HALF_WIDTH + 0.08), 0.35, z)))
		z -= post_spacing
	var post := BoxMesh.new()
	post.size = Vector3(0.14, 0.7, 0.14)
	_multimesh(post, rail_mat, post_xf)
	for sx: float in [-1.0, 1.0]:
		_box(Vector3(0.18, 0.16, total), Vector3(sx * (HALF_WIDTH + 0.08), 0.72, START_PAD - total * 0.5), rail_mat)
		_box(Vector3(0.12, 0.1, ARENA_LENGTH), Vector3(sx * (ARENA_HALF_WIDTH + 0.05), 0.55, -length - ARENA_LENGTH * 0.5 + 0.5), rail_mat)

	# Support pillars into the water.
	var pillar := CylinderMesh.new()
	pillar.top_radius = 0.55
	pillar.bottom_radius = 0.75
	pillar.height = 14.0
	pillar.radial_segments = 10
	pillar.rings = 1
	var pillar_xf: Array[Transform3D] = []
	z = START_PAD - 6.0
	while z > -length - ARENA_LENGTH:
		var hw: float = HALF_WIDTH if z > -length else ARENA_HALF_WIDTH
		for sx: float in [-1.0, 1.0]:
			pillar_xf.append(Transform3D(Basis(), Vector3(sx * (hw - 1.0), -7.5, z)))
		z -= 22.0
	_multimesh(pillar, Toon.mat(Color("#B9C3D3"), 0.0, 0.2), pillar_xf)

	# Start + finish checker lines.
	var checker := ShaderMaterial.new()
	checker.shader = preload("res://shaders/track.gdshader")
	checker.set_shader_parameter("checker", 1.0)
	checker.set_shader_parameter("checker_size", 0.8)
	checker.set_shader_parameter("side_color", Palette.UI_DARK)
	_box(Vector3(HALF_WIDTH * 2.0 - 0.9, 0.04, 1.6), Vector3(0, 0.02, 2.0), checker)
	_box(Vector3(HALF_WIDTH * 2.0 - 0.9, 0.04, 2.4), Vector3(0, 0.02, -length + 1.0), checker)

	# Enemy zone + boss podium.
	var zone := CylinderMesh.new()
	zone.top_radius = 5.0
	zone.bottom_radius = 5.0
	zone.height = 0.06
	zone.radial_segments = 32
	zone.rings = 1
	_mesh(zone, Toon.mat(Palette.ENEMY_LIGHT.lerp(Palette.TRACK, 0.45), 0.0, 0.0), Vector3(0, 0.03, enemy_z))
	var podium := CylinderMesh.new()
	podium.top_radius = 4.2
	podium.bottom_radius = 4.6
	podium.height = 0.5
	podium.radial_segments = 32
	podium.rings = 1
	_mesh(podium, Toon.mat(Palette.ENEMY.darkened(0.15), 0.04, 0.3), Vector3(0, 0.25, boss_z))
	var ring := CylinderMesh.new()
	ring.top_radius = 4.25
	ring.bottom_radius = 4.25
	ring.height = 0.08
	ring.radial_segments = 32
	ring.rings = 1
	_mesh(ring, Toon.mat(Palette.GOLD, 0.0, 0.4), Vector3(0, 0.52, boss_z))

	_build_water()
	_build_scenery(seed_value)


func _build_water() -> void:
	water = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(520, 520)
	water.mesh = plane
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/water.gdshader")
	m.set_shader_parameter("deep", Palette.WATER_DEEP)
	m.set_shader_parameter("shallow", Palette.WATER_SHALLOW)
	water.material_override = m
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position = Vector3(0, -6.0, 0)
	add_child(water)


func _build_scenery(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var island_xf: Array[Transform3D] = []
	var sand_xf: Array[Transform3D] = []
	var tree_xf: Array[Transform3D] = []
	var rock_xf: Array[Transform3D] = []
	var cloud_xf: Array[Transform3D] = []
	var z: float = 40.0
	var z_end: float = -length - ARENA_LENGTH - 120.0
	while z > z_end:
		for sx: float in [-1.0, 1.0]:
			if rng.randf() < 0.75:
				var x: float = sx * rng.randf_range(22.0, 80.0)
				var r: float = rng.randf_range(6.0, 16.0)
				var c := Vector3(x, -6.0, z + rng.randf_range(-12.0, 12.0))
				var ys: float = rng.randf_range(0.35, 0.6)
				island_xf.append(Transform3D(Basis().scaled(Vector3(r, r * ys, r)), c))
				sand_xf.append(Transform3D(Basis().scaled(Vector3(r * 1.12, 0.6, r * 1.12)), c + Vector3(0, 0.15, 0)))
				var trees: int = rng.randi_range(2, 6)
				for i: int in trees:
					var a: float = rng.randf() * TAU
					var d: float = rng.randf_range(0.0, r * 0.55)
					var th: float = rng.randf_range(2.5, 5.5)
					var surface: float = ys * r * sqrt(maxf(0.0, 1.0 - (d / r) * (d / r)))
					var tp := c + Vector3(cos(a) * d, surface + th * 0.5 - 0.3, sin(a) * d)
					tree_xf.append(Transform3D(Basis().scaled(Vector3(th * 0.42, th, th * 0.42)), tp))
				if rng.randf() < 0.5:
					var rr: float = rng.randf_range(1.0, 2.6)
					rock_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rr, rr * 0.7, rr)), c + Vector3(r * 0.9, 0.0, 0.0)))
		if rng.randf() < 0.6:
			var cs: float = rng.randf_range(4.0, 9.0)
			cloud_xf.append(Transform3D(Basis().scaled(Vector3(cs * 2.2, cs * 0.7, cs)), Vector3(rng.randf_range(-90.0, 90.0), rng.randf_range(26.0, 46.0), z)))
		z -= 28.0

	var island := SphereMesh.new()
	island.radius = 1.0
	island.height = 2.0
	island.radial_segments = 14
	island.rings = 6
	_multimesh(island, Toon.mat(Palette.GRASS, 0.0, 0.25), island_xf)
	var sand := CylinderMesh.new()
	sand.top_radius = 1.0
	sand.bottom_radius = 1.0
	sand.height = 1.0
	sand.radial_segments = 16
	sand.rings = 1
	_multimesh(sand, Toon.mat(Color("#F4E1A6"), 0.0, 0.1), sand_xf)
	var tree := CylinderMesh.new()
	tree.top_radius = 0.0
	tree.bottom_radius = 1.0
	tree.height = 1.0
	tree.radial_segments = 7
	tree.rings = 1
	_multimesh(tree, Toon.mat(Palette.FOREST.lightened(0.12), 0.0, 0.3), tree_xf)
	var rock := SphereMesh.new()
	rock.radius = 1.0
	rock.height = 2.0
	rock.radial_segments = 6
	rock.rings = 3
	_multimesh(rock, Toon.mat(Color("#A9B0BE"), 0.0, 0.2), rock_xf)
	var cloud := SphereMesh.new()
	cloud.radius = 1.0
	cloud.height = 2.0
	cloud.radial_segments = 10
	cloud.rings = 5
	var cloud_mat: ShaderMaterial = Toon.mat(Color.WHITE, 0.0, 0.1)
	_multimesh(cloud, cloud_mat, cloud_xf)


## Keep the water centered under the camera so it looks infinite.
func follow(z: float) -> void:
	if water != null:
		water.position.z = snappedf(z, 20.0)


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(b, mat, pos)


func _mesh(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _multimesh(mesh: Mesh, mat: Material, xfs: Array[Transform3D]) -> MultiMeshInstance3D:
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
	return mmi
