class_name RunnerMesh
extends RefCounted
## Builds the single shared runner mesh (~260 tris) from primitives:
## capsule body, sphere head, flattened-sphere helmet, capsule limbs.
## Vertex colors carry part masks for the crowd shader (see crowd_unit.gdshader).
## Swap for an imported model later by returning a different Mesh here.

static var _mesh: ArrayMesh = null

const HEIGHT: float = 0.95


static func get_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Color channels: r team mask, g limb flag, b side, a brightness.
	var leg := CapsuleMesh.new()
	leg.radius = 0.075
	leg.height = 0.38
	leg.radial_segments = 6
	leg.rings = 1
	_append(st, leg, Transform3D(Basis(), Vector3(-0.085, 0.19, 0.0)), Color(1.0, 1.0, 0.0, 0.3))
	_append(st, leg, Transform3D(Basis(), Vector3(0.085, 0.19, 0.0)), Color(1.0, 1.0, 1.0, 0.3))
	var body := CapsuleMesh.new()
	body.radius = 0.17
	body.height = 0.5
	body.radial_segments = 8
	body.rings = 2
	_append(st, body, Transform3D(Basis(), Vector3(0.0, 0.52, 0.0)), Color(1.0, 0.0, 0.0, 0.68))
	var arm := CapsuleMesh.new()
	arm.radius = 0.055
	arm.height = 0.34
	arm.radial_segments = 6
	arm.rings = 1
	var arm_basis_l := Basis(Vector3.FORWARD, -0.18)
	var arm_basis_r := Basis(Vector3.FORWARD, 0.18)
	_append(st, arm, Transform3D(arm_basis_l, Vector3(-0.215, 0.53, 0.0)), Color(1.0, 0.5, 0.0, 0.55))
	_append(st, arm, Transform3D(arm_basis_r, Vector3(0.215, 0.53, 0.0)), Color(1.0, 0.5, 1.0, 0.55))
	var head := SphereMesh.new()
	head.radius = 0.15
	head.height = 0.3
	head.radial_segments = 10
	head.rings = 5
	_append(st, head, Transform3D(Basis(), Vector3(0.0, 0.85, 0.0)), Color(0.0, 0.0, 0.0, 0.8))
	var helmet := SphereMesh.new()
	helmet.radius = 0.165
	helmet.height = 0.2
	helmet.radial_segments = 10
	helmet.rings = 4
	helmet.is_hemisphere = true
	_append(st, helmet, Transform3D(Basis(), Vector3(0.0, 0.87, 0.0)), Color(1.0, 0.0, 0.0, 0.95))
	st.index()
	_mesh = st.commit()
	return _mesh


static func _append(st: SurfaceTool, prim: PrimitiveMesh, xf: Transform3D, col: Color) -> void:
	var arrays: Array = prim.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var nb: Basis = xf.basis.inverse().transposed()
	for idx: int in indices:
		st.set_color(col)
		st.set_normal((nb * normals[idx]).normalized())
		st.add_vertex(xf * verts[idx])
