class_name MeshBaker
extends RefCounted
## Bakes a tree of MeshInstance3D(PrimitiveMesh + Toon material) into ONE
## ArrayMesh with per-part vertex colors -> 1 draw call. Use with
## [method material] (toon shader reading vertex colors).

static var _mats: Dictionary = {}


static func bake(root: Node3D) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_bake_node(st, root, Transform3D.IDENTITY)
	st.index()
	return st.commit()


## Shared vertex-color toon material (optional outline on High quality).
static func material(outline_width: float = 0.0) -> ShaderMaterial:
	var key: String = "%.3f|%s" % [outline_width, str(Settings.outlines_enabled())]
	if _mats.has(key):
		return _mats[key]
	var m: ShaderMaterial = Toon.unique(Color.WHITE, outline_width, 0.4)
	m.set_shader_parameter("use_vertex_color", true)
	_mats[key] = m
	return m


static func _bake_node(st: SurfaceTool, node: Node, parent_xf: Transform3D) -> void:
	for child: Node in node.get_children():
		var n3: Node3D = child as Node3D
		if n3 == null:
			continue
		var xf: Transform3D = parent_xf * n3.transform
		var mi: MeshInstance3D = n3 as MeshInstance3D
		if mi != null and mi.mesh is PrimitiveMesh:
			var col: Color = Color.WHITE
			var sm: ShaderMaterial = mi.material_override as ShaderMaterial
			if sm != null:
				var bc: Variant = sm.get_shader_parameter("base_color")
				if bc != null:
					col = bc
				var es: Variant = sm.get_shader_parameter("emission_strength")
				if es != null and float(es) > 0.0:
					col = col.lightened(0.35)
			var arrays: Array = (mi.mesh as PrimitiveMesh).get_mesh_arrays()
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var nb: Basis = xf.basis.inverse().transposed()
			for idx: int in indices:
				st.set_color(col)
				st.set_normal((nb * normals[idx]).normalized())
				st.add_vertex(xf * verts[idx])
		_bake_node(st, n3, xf)
