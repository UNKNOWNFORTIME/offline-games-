class_name CrowdObstacle
extends Node3D
## Track hazards (level 3+): spinning bar, sliding saw blade, side pusher.
## Units are tested individually against a simple 2D (XZ) shape, so a
## careful player can steer the blob around them.

enum Kind { SPINNER, SAW, PUSHER }

var kind: Kind = Kind.SPINNER
var z_pos: float = 0.0
var reach_z: float = 1.0  # half-depth of the danger zone along Z
var _t: float = 0.0
var _speed: float = 1.0
var _phase: float = 0.0
var _side: float = 1.0
var _half_w: float = 4.0
var _rot_node: Node3D
var _move_node: Node3D

# Current shape state (world space XZ).
var _bar_angle: float = 0.0
var _saw_x: float = 0.0
var _push_depth: float = 0.0

const BAR_HALF: float = 3.4
const BAR_THICK: float = 0.32
const SAW_R: float = 0.95
const PUSH_THICK: float = 0.75


static func kind_from_string(s: String) -> Kind:
	match s:
		"saw":
			return Kind.SAW
		"pusher":
			return Kind.PUSHER
	return Kind.SPINNER


func build(p_kind: Kind, p_z: float, half_width: float, seed_value: int) -> void:
	kind = p_kind
	z_pos = p_z
	_half_w = half_width
	position = Vector3(0, 0, p_z)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_phase = rng.randf() * TAU
	_side = -1.0 if rng.randf() < 0.5 else 1.0
	var danger: ShaderMaterial = Toon.mat(Palette.ENEMY, 0.04, 0.5)
	var white: ShaderMaterial = Toon.mat(Color.WHITE, 0.04, 0.3)
	var metal: ShaderMaterial = Toon.mat(Palette.METAL.lightened(0.15), 0.04, 0.6)
	match kind:
		Kind.SPINNER:
			_speed = rng.randf_range(1.6, 2.4) * _side
			reach_z = BAR_HALF + 0.4
			_add(_cyl(0.32, 0.4, 1.3, 12), metal, Vector3(0, 0.65, 0))
			_rot_node = Node3D.new()
			_rot_node.position = Vector3(0, 0.55, 0)
			add_child(_rot_node)
			var bar := BoxMesh.new()
			bar.size = Vector3(BAR_HALF * 2.0, 0.34, 0.34)
			_add(bar, danger, Vector3.ZERO, _rot_node)
			for i: int in 4:
				var stripe := BoxMesh.new()
				stripe.size = Vector3(0.35, 0.36, 0.36)
				_add(stripe, white, Vector3(-2.4 + float(i) * 1.6, 0, 0), _rot_node)
			_add(_cyl(0.42, 0.42, 0.2, 12), Toon.mat(Palette.GOLD, 0.03, 0.5), Vector3(0, 0.75, 0))
		Kind.SAW:
			_speed = rng.randf_range(1.4, 2.0)
			reach_z = SAW_R + 0.3
			var rail := BoxMesh.new()
			rail.size = Vector3(half_width * 2.0 - 0.6, 0.12, 0.3)
			_add(rail, Toon.mat(Palette.UI_DARK_SOFT, 0.0, 0.2), Vector3(0, 0.06, 0))
			_move_node = Node3D.new()
			add_child(_move_node)
			_rot_node = Node3D.new()
			_rot_node.position = Vector3(0, 0.75, 0)
			_rot_node.rotation.x = PI * 0.5
			_move_node.add_child(_rot_node)
			_add(_cyl(SAW_R, SAW_R, 0.1, 18), metal, Vector3.ZERO, _rot_node)
			for i: int in 10:
				var a: float = float(i) / 10.0 * TAU
				var tooth := BoxMesh.new()
				tooth.size = Vector3(0.26, 0.11, 0.26)
				var mi: MeshInstance3D = _add(tooth, danger, Vector3(cos(a) * SAW_R, 0, sin(a) * SAW_R), _rot_node)
				mi.rotation.y = -a + PI * 0.25
			_add(_cyl(0.25, 0.25, 0.14, 10), danger, Vector3.ZERO, _rot_node)
		Kind.PUSHER:
			_speed = rng.randf_range(1.6, 2.3)
			reach_z = PUSH_THICK + 0.25
			_move_node = Node3D.new()
			add_child(_move_node)
			var block := BoxMesh.new()
			block.size = Vector3(3.4, 1.1, PUSH_THICK * 2.0)
			_add(block, danger, Vector3(_side * 1.7, 0.55, 0), _move_node)
			for i: int in 3:
				var stripe := BoxMesh.new()
				stripe.size = Vector3(0.4, 1.12, PUSH_THICK * 2.02)
				var s: MeshInstance3D = _add(stripe, white, Vector3(_side * (0.6 + float(i) * 1.0), 0.55, 0), _move_node)
				s.rotation.z = 0.5
			var housing := BoxMesh.new()
			housing.size = Vector3(0.9, 1.6, PUSH_THICK * 2.4)
			_add(housing, metal, Vector3(_side * (half_width + 0.35), 0.8, 0))


func _process(delta: float) -> void:
	_t += delta
	match kind:
		Kind.SPINNER:
			_bar_angle = _t * _speed + _phase
			_rot_node.rotation.y = _bar_angle
		Kind.SAW:
			_saw_x = sin(_t * _speed + _phase) * (_half_w - 1.1)
			_move_node.position.x = _saw_x
			_rot_node.rotate_object_local(Vector3.UP, delta * 14.0)
		Kind.PUSHER:
			# Smooth slam-out, hold, retract cycle.
			var c: float = 0.5 + 0.5 * sin(_t * _speed + _phase)
			_push_depth = smoothstep(0.25, 0.75, c) * (_half_w * 2.0 * 0.62)
			_move_node.position.x = _side * (_half_w - _push_depth)


## Is a world XZ point (unit foot position) inside the hazard right now?
func hits(p: Vector3) -> bool:
	var lz: float = p.z - z_pos
	if absf(lz) > reach_z:
		return false
	match kind:
		Kind.SPINNER:
			# Distance to the rotating segment.
			var dir := Vector2(cos(_bar_angle), -sin(_bar_angle))
			var v := Vector2(p.x, lz)
			var t: float = clampf(v.dot(dir), -BAR_HALF, BAR_HALF)
			return v.distance_to(dir * t) < BAR_THICK + 0.12
		Kind.SAW:
			return Vector2(p.x - _saw_x, lz).length() < SAW_R + 0.1 and absf(lz) < 0.35
		Kind.PUSHER:
			if absf(lz) > PUSH_THICK + 0.1:
				return false
			var edge: float = _side * (_half_w - _push_depth)
			return p.x * _side > edge * _side - 0.1
	return false


func _cyl(top: float, bottom: float, h: float, seg: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m


func _add(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Settings.shadows_enabled() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else self).add_child(mi)
	return mi
