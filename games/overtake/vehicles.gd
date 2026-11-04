class_name VehicleFactory
extends RefCounted
## Procedural vehicles built from boxes and cylinders.
## Every vehicle faces -Z. Root node carries meta "half_len" / "half_w".

const TRAFFIC_COLORS: Array = [
	Color("#2F80FF"), Color("#FF3B3B"), Color("#36D399"), Color("#FFC531"),
	Color("#F4F4F4"), Color("#7DB7FF"), Color("#9B6BFF"), Color("#FF8A3D"),
]

enum Kind { SEDAN, VAN, TRUCK, PICKUP }


## Open-wheel racer: needle nose, side pods, exposed wheels, rear wing.
## Returns the root; wheels are in the group "wheel" for spinning.
static func player_car(body_color: Color = Color("#B5652B")) -> Node3D:
	var root := Node3D.new()
	root.set_meta("half_len", 1.9)
	root.set_meta("half_w", 0.85)
	var body: ShaderMaterial = Toon.mat(body_color, 0.03, 0.6)
	var dark: ShaderMaterial = Toon.mat(Palette.UI_DARK, 0.02, 0.25)
	var accent: ShaderMaterial = Toon.mat(Palette.GOLD, 0.02, 0.5)
	var white: ShaderMaterial = Toon.mat(Color.WHITE, 0.02, 0.3)
	var helmet: ShaderMaterial = Toon.mat(Palette.PLAYER, 0.02, 0.6)
	# Chassis + tapered nose.
	_box(root, Vector3(0.62, 0.32, 2.4), Vector3(0, 0.36, -0.1), body)
	var nose := CylinderMesh.new()
	nose.top_radius = 0.09
	nose.bottom_radius = 0.3
	nose.height = 1.3
	nose.radial_segments = 8
	nose.rings = 1
	var n: MeshInstance3D = _mesh(root, nose, Vector3(0, 0.33, -1.85), body)
	n.rotation.x = -PI * 0.5
	n.scale = Vector3(1.0, 1.0, 0.65)
	# Side pods.
	for s: float in [-1.0, 1.0]:
		_box(root, Vector3(0.36, 0.3, 1.25), Vector3(s * 0.48, 0.32, 0.3), body)
		_box(root, Vector3(0.05, 0.12, 1.0), Vector3(s * 0.66, 0.38, 0.3), accent)
	# Cockpit + driver.
	_box(root, Vector3(0.44, 0.14, 0.7), Vector3(0, 0.55, 0.05), dark)
	_mesh(root, _sphere(0.2), Vector3(0, 0.7, 0.05), helmet)
	_box(root, Vector3(0.3, 0.06, 0.05), Vector3(0, 0.72, -0.14), dark)
	# Engine cover + air intake.
	_box(root, Vector3(0.4, 0.34, 0.9), Vector3(0, 0.6, 0.75), body)
	# Front wing.
	_box(root, Vector3(1.75, 0.05, 0.38), Vector3(0, 0.16, -2.35), accent)
	for s: float in [-1.0, 1.0]:
		_box(root, Vector3(0.05, 0.22, 0.42), Vector3(s * 0.87, 0.24, -2.35), body)
	# Rear wing on struts.
	_box(root, Vector3(1.4, 0.07, 0.45), Vector3(0, 1.0, 1.55), body)
	_box(root, Vector3(1.42, 0.03, 0.2), Vector3(0, 1.05, 1.45), white)
	for s: float in [-1.0, 1.0]:
		_box(root, Vector3(0.05, 0.6, 0.42), Vector3(s * 0.7, 0.75, 1.55), dark)
	# Exposed wheels (bigger at the rear).
	for w: Array in [[-0.82, -1.3, 0.3, 0.3], [0.82, -1.3, 0.3, 0.3], [-0.86, 1.05, 0.36, 0.42], [0.86, 1.05, 0.36, 0.42]]:
		_wheel(root, Vector3(float(w[0]), float(w[2]), float(w[1])), float(w[2]), float(w[3]), dark, accent)
	return root


static func traffic(kind: Kind, color: Color) -> Node3D:
	var root := Node3D.new()
	var paint: ShaderMaterial = Toon.mat(color, 0.03, 0.45)
	var glass: ShaderMaterial = Toon.mat(Color("#2A3A55"), 0.0, 0.7)
	var dark: ShaderMaterial = Toon.mat(Palette.UI_DARK, 0.0, 0.2)
	var light_mat: ShaderMaterial = Toon.emissive(Color("#FFE9A8"), 0.6)
	var tail: ShaderMaterial = Toon.emissive(Palette.ENEMY, 0.8)
	var len: float = 4.4
	var wid: float = 1.85
	match kind:
		Kind.SEDAN:
			_box(root, Vector3(wid, 0.62, len), Vector3(0, 0.62, 0), paint)
			_box(root, Vector3(wid - 0.2, 0.5, 2.2), Vector3(0, 1.17, 0.2), paint)
			_box(root, Vector3(wid - 0.16, 0.38, 2.0), Vector3(0, 1.17, 0.2), glass)
		Kind.VAN:
			len = 5.0
			_box(root, Vector3(wid, 1.75, len - 0.9), Vector3(0, 1.2, 0.45), paint)
			_box(root, Vector3(wid, 0.95, 1.1), Vector3(0, 0.82, -len * 0.5 + 0.55), paint)
			_box(root, Vector3(wid - 0.1, 0.5, 0.06), Vector3(0, 1.55, -len * 0.5 + 0.88), glass)
		Kind.TRUCK:
			len = 9.0
			wid = 2.3
			_box(root, Vector3(wid, 1.9, 2.0), Vector3(0, 1.45, -len * 0.5 + 1.0), paint)
			_box(root, Vector3(wid - 0.15, 0.7, 0.06), Vector3(0, 1.9, -len * 0.5 - 0.01), glass)
			var container: ShaderMaterial = Toon.mat(TRAFFIC_COLORS[(int(color.to_rgba32()) >> 8) % TRAFFIC_COLORS.size()].darkened(0.15), 0.03, 0.3)
			_box(root, Vector3(wid + 0.05, 2.5, len - 2.3), Vector3(0, 1.85, 1.15), container)
			for i: int in 5:
				_box(root, Vector3(wid + 0.08, 2.3, 0.08), Vector3(0, 1.85, -1.6 + float(i) * 1.35), dark)
			_box(root, Vector3(wid - 0.3, 0.3, len - 0.5), Vector3(0, 0.45, 0.2), dark)
		Kind.PICKUP:
			len = 4.9
			_box(root, Vector3(wid, 0.7, len), Vector3(0, 0.7, 0), paint)
			_box(root, Vector3(wid - 0.1, 0.62, 1.7), Vector3(0, 1.36, -0.55), paint)
			_box(root, Vector3(wid - 0.06, 0.4, 1.5), Vector3(0, 1.36, -0.55), glass)
			_box(root, Vector3(wid - 0.3, 0.3, 1.8), Vector3(0, 1.12, 1.25), dark)
	# Lights.
	for s: float in [-1.0, 1.0]:
		_box(root, Vector3(0.36, 0.16, 0.06), Vector3(s * (wid * 0.5 - 0.3), 0.75, -len * 0.5 - 0.01), light_mat)
		_box(root, Vector3(0.36, 0.16, 0.06), Vector3(s * (wid * 0.5 - 0.3), 0.75, len * 0.5 + 0.01), tail)
	# Wheels.
	var axle_z: Array = [-len * 0.5 + 0.9, len * 0.5 - 0.9]
	if kind == Kind.TRUCK:
		axle_z = [-len * 0.5 + 1.0, len * 0.5 - 2.2, len * 0.5 - 1.0]
	for az: Variant in axle_z:
		for s: float in [-1.0, 1.0]:
			_wheel(root, Vector3(s * (wid * 0.5 - 0.05), 0.4, float(az)), 0.4, 0.3, dark, dark)
	root.set_meta("half_len", len * 0.5)
	root.set_meta("half_w", wid * 0.5)
	return root


static func _wheel(root: Node3D, pos: Vector3, r: float, w: float, tire: Material, hub: Material) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.add_to_group("wheel")
	root.add_child(pivot)
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = w
	c.radial_segments = 12
	c.rings = 1
	var t: MeshInstance3D = _mesh(pivot, c, Vector3.ZERO, tire)
	t.rotation.z = PI * 0.5
	var hc := CylinderMesh.new()
	hc.top_radius = r * 0.45
	hc.bottom_radius = r * 0.45
	hc.height = w + 0.02
	hc.radial_segments = 8
	hc.rings = 1
	var h: MeshInstance3D = _mesh(pivot, hc, Vector3.ZERO, hub)
	h.rotation.z = PI * 0.5
	# A stripe so the spin reads.
	var b := BoxMesh.new()
	b.size = Vector3(w + 0.03, r * 1.6, 0.08)
	_mesh(pivot, b, Vector3.ZERO, hub)


static func _box(root: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(root, b, pos, mat)


static func _mesh(root: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


static func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 5
	return m



static var _baked: Dictionary = {}


## Traffic vehicle as ONE mesh (vertex colors per part) -> 1 draw call.
## Returns {mesh: ArrayMesh, half_len, half_w}; cached per kind+color.
static func traffic_baked(kind: Kind, color: Color) -> Dictionary:
	var key: String = "%d|%s" % [kind, color.to_html()]
	if _baked.has(key):
		return _baked[key]
	var root: Node3D = traffic(kind, color)
	var info: Dictionary = {"mesh": MeshBaker.bake(root), "half_len": float(root.get_meta("half_len")), "half_w": float(root.get_meta("half_w"))}
	root.free()
	_baked[key] = info
	return info


static func baked_material() -> ShaderMaterial:
	return MeshBaker.material(0.0)
