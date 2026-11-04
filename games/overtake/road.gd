class_name OvertakeRoad
extends Node3D
## Endless country highway in ~10 draw calls total:
## - road / shoulders / verges are long strips that follow the player
##   (markings are world-space in the shader, so they don't slide);
## - pines, trunks, rocks, hills and posts are 5 global MultiMeshes whose
##   instances are grouped in segments; a segment that falls behind is
##   recycled to the front by rewriting only its instances (no allocations).

const SEG_LEN: float = 40.0
const SEG_COUNT: int = 8
const ROAD_HALF: float = 4.4

var _strips: Array[Node3D] = []
var _mms: Array[MultiMesh] = []
var _local: Array = []        # per multimesh: Array of local Transform3D
var _seg_of: Array = []       # per multimesh: PackedInt32Array segment index per instance
var _seg_z: PackedFloat32Array = PackedFloat32Array()


func build(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var total: float = SEG_LEN * float(SEG_COUNT)
	var road_mat := ShaderMaterial.new()
	road_mat.shader = preload("res://shaders/road.gdshader")
	var grass := ShaderMaterial.new()
	grass.shader = preload("res://shaders/track.gdshader")
	grass.set_shader_parameter("color_a", Palette.GRASS)
	grass.set_shader_parameter("color_b", Palette.GRASS.darkened(0.06))
	grass.set_shader_parameter("side_color", Palette.GRASS.darkened(0.2))
	grass.set_shader_parameter("band_length", 8.0)
	_strip(Vector3(ROAD_HALF * 2.0, 0.3, total), 0.0, -0.15, road_mat)
	for s: float in [-1.0, 1.0]:
		_strip(Vector3(1.2, 0.3, total), s * (ROAD_HALF + 0.6), -0.17, Toon.mat(Color("#C9B98F"), 0.0, 0.1))
		_strip(Vector3(90.0, 0.3, total), s * (ROAD_HALF + 1.2 + 45.0), -0.2, grass)

	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 7
	cone.rings = 1
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.24
	trunk.height = 1.0
	trunk.radial_segments = 6
	trunk.rings = 1
	var rock := SphereMesh.new()
	rock.radius = 1.0
	rock.height = 2.0
	rock.radial_segments = 6
	rock.rings = 3
	var hill := SphereMesh.new()
	hill.radius = 1.0
	hill.height = 2.0
	hill.radial_segments = 16
	hill.rings = 6
	var post := BoxMesh.new()
	post.size = Vector3(0.12, 0.8, 0.12)

	var pines: Array = []
	var trunks: Array = []
	var rocks: Array = []
	var hills: Array = []
	var posts: Array = []
	var pine_seg := PackedInt32Array()
	var rock_seg := PackedInt32Array()
	var hill_seg := PackedInt32Array()
	var post_seg := PackedInt32Array()
	for i: int in SEG_COUNT:
		_seg_z.append(-float(i) * SEG_LEN)
		for k: int in 4:
			for s: float in [-1.0, 1.0]:
				posts.append(Transform3D(Basis(), Vector3(s * (ROAD_HALF + 0.9), 0.4, -float(k) * 10.0 - 2.0)))
				post_seg.append(i)
		for k: int in rng.randi_range(10, 15):
			var s: float = -1.0 if rng.randf() < 0.5 else 1.0
			var x: float = s * rng.randf_range(ROAD_HALF + 3.0, 36.0)
			var z: float = -rng.randf_range(0.0, SEG_LEN)
			var h: float = rng.randf_range(4.0, 9.0)
			var w: float = h * rng.randf_range(0.28, 0.36)
			pines.append(Transform3D(Basis().scaled(Vector3(w, h, w)), Vector3(x, h * 0.5 + 0.9, z)))
			trunks.append(Transform3D(Basis().scaled(Vector3(1, 1.4, 1)), Vector3(x, 0.5, z)))
			pine_seg.append(i)
		for k: int in rng.randi_range(1, 3):
			var s: float = -1.0 if rng.randf() < 0.5 else 1.0
			var r: float = rng.randf_range(0.5, 1.4)
			rocks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(r * 1.3, r * 0.8, r)), Vector3(s * rng.randf_range(ROAD_HALF + 2.0, 12.0), 0.1, -rng.randf_range(0.0, SEG_LEN))))
			rock_seg.append(i)
		for k: int in 2:
			var s: float = -1.0 if k == 0 else 1.0
			var r: float = rng.randf_range(16.0, 30.0)
			hills.append(Transform3D(Basis().scaled(Vector3(r * 1.4, r * rng.randf_range(0.35, 0.6), r)), Vector3(s * rng.randf_range(55.0, 85.0), -2.0, -rng.randf_range(0.0, SEG_LEN))))
			hill_seg.append(i)
	_add_mm(cone, Toon.mat(Palette.FOREST.lightened(0.15), 0.0, 0.3), pines, pine_seg)
	_add_mm(trunk, Toon.mat(Color("#7A5232"), 0.0, 0.1), trunks, pine_seg)
	_add_mm(rock, Toon.mat(Color("#A7AEBB"), 0.0, 0.25), rocks, rock_seg)
	_add_mm(hill, Toon.mat(Palette.GRASS.lightened(0.08), 0.0, 0.2), hills, hill_seg)
	_add_mm(post, Toon.mat(Color.WHITE, 0.0, 0.2), posts, post_seg)


func follow(player_z: float) -> void:
	# Strips: snap to the dash length so world-space markings stay put.
	var total: float = SEG_LEN * float(SEG_COUNT)
	var sz: float = snappedf(player_z, 8.0) - total * 0.5 + 60.0
	for st: Node3D in _strips:
		st.position.z = sz
	# Recycle scenery segments that fell behind the camera.
	for i: int in SEG_COUNT:
		if _seg_z[i] - SEG_LEN > player_z + 25.0:
			_seg_z[i] -= total
			_rewrite_segment(i)


func _rewrite_segment(seg: int) -> void:
	var off := Vector3(0, 0, _seg_z[seg])
	for m: int in _mms.size():
		var segs: PackedInt32Array = _seg_of[m]
		var locs: Array = _local[m]
		var mm: MultiMesh = _mms[m]
		for k: int in segs.size():
			if segs[k] == seg:
				var xf: Transform3D = locs[k]
				mm.set_instance_transform(k, Transform3D(xf.basis, xf.origin + off))


func _strip(size: Vector3, x: float, y: float, mat: Material) -> void:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.position = Vector3(x, y, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_strips.append(mi)


func _add_mm(mesh: Mesh, mat: Material, locs: Array, segs: PackedInt32Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = locs.size()
	for k: int in locs.size():
		var xf: Transform3D = locs[k]
		mm.set_instance_transform(k, Transform3D(xf.basis, xf.origin + Vector3(0, 0, _seg_z[segs[k]])))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The ring moves forever; never cull it on a stale AABB.
	mmi.custom_aabb = AABB(Vector3(-200, -50, -100000), Vector3(400, 150, 200000))
	add_child(mmi)
	_mms.append(mm)
	_local.append(locs)
	_seg_of.append(segs)
