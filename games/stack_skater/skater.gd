class_name SkaterRig
extends Node3D
## Procedural skater (body, capsule limbs, helmet, backpack, skateboard with
## spinning wheels) holding a horizontal bar of stacked coins in both hands.
## The bar is ONE MultiMesh: coins extend sideways per stack size, then
## start a second layer on top once a side is full.

const COIN_RADIUS: float = 0.2
const COIN_THICK: float = 0.07
const COIN_SPACING: float = 0.078
const PER_ROW_SIDE: int = 40
const MAX_VISIBLE: int = 400
const GRIP: float = 0.22
const BAR_Y: float = 1.08
const BAR_Z: float = -0.42

var stack: int = 0
var _body: Node3D
var _bar: Node3D
var _mm: MultiMesh
var _wheels: Array[Node3D] = []
var _lean: float = 0.0
var _t: float = 0.0
var _bar_wobble: float = 0.0
var celebrating: bool = false


func build() -> void:
	_body = Node3D.new()
	add_child(_body)
	var shirt: ShaderMaterial = Toon.mat(Palette.PLAYER, 0.03, 0.45)
	var pants: ShaderMaterial = Toon.mat(Palette.UI_DARK_SOFT.lightened(0.15), 0.03, 0.3)
	var skin: ShaderMaterial = Toon.mat(Palette.SKIN, 0.03, 0.3)
	var helmet: ShaderMaterial = Toon.mat(Palette.UI_ACCENT, 0.03, 0.6)
	var white: ShaderMaterial = Toon.mat(Color.WHITE, 0.0, 0.3)
	var deck_mat: ShaderMaterial = Toon.mat(Palette.ENEMY, 0.03, 0.4)
	var dark: ShaderMaterial = Toon.mat(Palette.UI_DARK, 0.0, 0.2)
	var pack: ShaderMaterial = Toon.mat(Palette.GOLD_SHADOW, 0.03, 0.4)

	# Skateboard.
	var deck := BoxMesh.new()
	deck.size = Vector3(0.48, 0.06, 1.15)
	_part(deck, deck_mat, Vector3(0, 0.16, 0), _body)
	for zx: Vector2 in [Vector2(-0.17, -0.38), Vector2(0.17, -0.38), Vector2(-0.17, 0.38), Vector2(0.17, 0.38)]:
		var w := Node3D.new()
		w.position = Vector3(zx.x, 0.07, zx.y)
		_body.add_child(w)
		var wheel := CylinderMesh.new()
		wheel.top_radius = 0.07
		wheel.bottom_radius = 0.07
		wheel.height = 0.07
		wheel.radial_segments = 10
		wheel.rings = 1
		var wm: MeshInstance3D = _part(wheel, white, Vector3.ZERO, w)
		wm.rotation.z = PI * 0.5
		_wheels.append(w)
	# Legs (wide skate stance).
	for s: float in [-1.0, 1.0]:
		var leg := _capsule(0.085, 0.75)
		var l: MeshInstance3D = _part(leg, pants, Vector3(0.0, 0.55, s * 0.2), _body)
		l.rotation.x = -s * 0.28
		var shoe := BoxMesh.new()
		shoe.size = Vector3(0.16, 0.08, 0.26)
		_part(shoe, dark, Vector3(0, 0.22, s * 0.3), _body)
	# Torso, backpack, head, helmet.
	_part(_capsule(0.21, 0.62), shirt, Vector3(0, 1.12, 0), _body)
	var bp := BoxMesh.new()
	bp.size = Vector3(0.34, 0.4, 0.2)
	_part(bp, pack, Vector3(0, 1.18, 0.24), _body)
	_part(_sphere(0.17), skin, Vector3(0, 1.58, -0.02), _body)
	var hm := SphereMesh.new()
	hm.radius = 0.2
	hm.height = 0.26
	hm.is_hemisphere = true
	hm.radial_segments = 14
	hm.rings = 5
	_part(hm, helmet, Vector3(0, 1.63, -0.02), _body)
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.06, 0.05, 0.4)
	_part(stripe, white, Vector3(0, 1.82, -0.02), _body)
	# Arms reaching forward to the bar.
	for s: float in [-1.0, 1.0]:
		var arm: MeshInstance3D = _part(_capsule(0.06, 0.5), shirt, Vector3(s * GRIP, BAR_Y + 0.12, BAR_Z * 0.5), _body)
		arm.rotation.x = PI * 0.5 - 0.35
		_part(_sphere(0.07), skin, Vector3(s * GRIP, BAR_Y, BAR_Z), _body)

	# Coin bar.
	_bar = Node3D.new()
	_bar.position = Vector3(0, BAR_Y, BAR_Z)
	_body.add_child(_bar)
	var coin := CylinderMesh.new()
	coin.top_radius = COIN_RADIUS
	coin.bottom_radius = COIN_RADIUS
	coin.height = COIN_THICK
	coin.radial_segments = 12
	coin.rings = 1
	var coin_mat := ShaderMaterial.new()
	coin_mat.shader = preload("res://shaders/coin.gdshader")
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = coin
	_mm.instance_count = MAX_VISIBLE
	_mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.material_override = coin_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Settings.shadows_enabled() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-6, -1, -1), Vector3(12, 6, 2))
	_bar.add_child(mmi)
	var rod := CylinderMesh.new()
	rod.top_radius = 0.03
	rod.bottom_radius = 0.03
	rod.height = GRIP * 2.0 + 0.1
	rod.radial_segments = 6
	rod.rings = 1
	var r: MeshInstance3D = _part(rod, dark, Vector3.ZERO, _bar)
	r.rotation.z = PI * 0.5


## Half-length of the bar (from skater center to outer coin edge).
func bar_half_width() -> float:
	var per_side: int = mini((stack + 1) / 2, PER_ROW_SIDE)
	return GRIP + float(per_side) * COIN_SPACING + 0.05


## Coin index i -> local position on the bar.
static func coin_local(i: int) -> Vector3:
	var side: float = -1.0 if i % 2 == 0 else 1.0
	var k: int = i / 2
	var col: int = k % PER_ROW_SIDE
	var layer: int = k / PER_ROW_SIDE
	return Vector3(side * (GRIP + 0.04 + float(col) * COIN_SPACING), float(layer) * (COIN_RADIUS * 2.0 + 0.02), 0.0)


func set_stack(n: int) -> void:
	var old: int = stack
	stack = maxi(0, n)
	var vis: int = mini(stack, MAX_VISIBLE)
	var basis := Basis(Vector3.FORWARD, PI * 0.5)
	for i: int in range(mini(old, vis), vis):
		_mm.set_instance_transform(i, Transform3D(basis, coin_local(i)))
	_mm.visible_instance_count = vis
	if n != old:
		_bar_wobble = 1.0 if n > old else -0.7


## World position of a coin slot (for falling coins / effects).
func coin_world(i: int) -> Vector3:
	return _bar.to_global(coin_local(i))


## Local X of the coin edge for a given side (-1/1) and coin count.
func set_lean(target: float) -> void:
	_lean = target


func _process(delta: float) -> void:
	_t += delta
	for w: Node3D in _wheels:
		w.rotate_x(-delta * 22.0)
	var bob: float = sin(_t * 9.0) * 0.015
	if celebrating:
		bob = absf(sin(_t * 6.0)) * 0.35
	_body.position.y = bob
	_body.rotation.z = lerpf(_body.rotation.z, -_lean * 0.32, 1.0 - exp(-10.0 * delta))
	_body.rotation.y = lerpf(_body.rotation.y, -_lean * 0.15, 1.0 - exp(-8.0 * delta))
	_bar_wobble = move_toward(_bar_wobble, 0.0, delta * 4.0)
	_bar.rotation.z = sin(_t * 30.0) * 0.04 * _bar_wobble
	_bar.scale = Vector3.ONE * (1.0 + absf(_bar_wobble) * 0.06)


func _part(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Settings.shadows_enabled() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 10
	m.rings = 2
	return m


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 12
	m.rings = 6
	return m
