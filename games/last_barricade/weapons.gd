class_name BarricadeWeapons
extends RefCounted
## Weapon stats + primitive-built models (used for the first-person view
## model and the floating pickups).
## fire_rate: shots/s, damage per pellet, pellets, spread (degrees).

const STATS: Dictionary = {
	"pistol": {"name": "PISTOL", "fire_rate": 3.2, "damage": 1.0, "pellets": 1, "spread": 0.6, "sfx": "gun_pistol", "kick": 0.06, "shake": 0.05},
	"smg": {"name": "SMG", "fire_rate": 11.0, "damage": 0.55, "pellets": 1, "spread": 2.6, "sfx": "gun_smg", "kick": 0.03, "shake": 0.04},
	"shotgun": {"name": "SHOTGUN", "fire_rate": 1.5, "damage": 0.75, "pellets": 7, "spread": 6.5, "sfx": "gun_shotgun", "kick": 0.14, "shake": 0.2},
	"rifle": {"name": "RIFLE", "fire_rate": 4.5, "damage": 2.3, "pellets": 1, "spread": 0.25, "sfx": "gun_rifle", "kick": 0.09, "shake": 0.1},
}
const ORDER: Array = ["pistol", "smg", "shotgun", "rifle"]


static func rank(id: String) -> int:
	return ORDER.find(id)


## Model faces -Z (barrel forward). Origin = grip. Meta "muzzle" = Vector3.
static func build_model(id: String) -> Node3D:
	var root := Node3D.new()
	var metal: ShaderMaterial = Toon.mat(Color("#3B4252"), 0.0, 0.5)
	var metal_l: ShaderMaterial = Toon.mat(Color("#6B7385"), 0.0, 0.6)
	var wood: ShaderMaterial = Toon.mat(Color("#8B5E3C"), 0.0, 0.3)
	var accent: ShaderMaterial = Toon.mat(Palette.UI_ACCENT, 0.0, 0.5)
	var muzzle := Vector3(0, 0.06, -0.3)
	match id:
		"pistol":
			_box(root, Vector3(0.07, 0.07, 0.3), Vector3(0, 0.06, -0.13), metal_l)
			_box(root, Vector3(0.06, 0.16, 0.08), Vector3(0, -0.04, 0.0), metal).rotation.x = 0.25
			_box(root, Vector3(0.072, 0.02, 0.2), Vector3(0, 0.1, -0.12), accent)
			muzzle = Vector3(0, 0.06, -0.29)
		"smg":
			_box(root, Vector3(0.08, 0.1, 0.42), Vector3(0, 0.05, -0.15), metal)
			_box(root, Vector3(0.05, 0.05, 0.16), Vector3(0, 0.06, -0.42), metal_l)
			_box(root, Vector3(0.05, 0.2, 0.06), Vector3(0, -0.1, -0.22), metal_l)
			_box(root, Vector3(0.06, 0.14, 0.07), Vector3(0, -0.05, 0.0), metal).rotation.x = 0.25
			_box(root, Vector3(0.04, 0.06, 0.22), Vector3(0, 0.03, 0.15), metal_l)
			_box(root, Vector3(0.082, 0.02, 0.3), Vector3(0, 0.11, -0.15), accent)
			muzzle = Vector3(0, 0.06, -0.51)
		"shotgun":
			_cyl(root, 0.03, 0.62, Vector3(0, 0.08, -0.32), metal_l)
			_cyl(root, 0.026, 0.5, Vector3(0, 0.02, -0.28), metal)
			_box(root, Vector3(0.08, 0.07, 0.16), Vector3(0, 0.02, -0.3), wood)
			_box(root, Vector3(0.08, 0.11, 0.24), Vector3(0, 0.05, 0.0), metal)
			_box(root, Vector3(0.07, 0.12, 0.3), Vector3(0, -0.02, 0.24), wood).rotation.x = -0.15
			muzzle = Vector3(0, 0.08, -0.64)
		"rifle":
			_box(root, Vector3(0.08, 0.1, 0.5), Vector3(0, 0.05, -0.15), metal)
			_cyl(root, 0.022, 0.4, Vector3(0, 0.07, -0.58), metal_l)
			_cyl(root, 0.04, 0.24, Vector3(0, 0.16, -0.12), metal_l)
			_box(root, Vector3(0.05, 0.16, 0.07), Vector3(0, -0.08, -0.22), metal_l)
			_box(root, Vector3(0.07, 0.13, 0.28), Vector3(0, 0.02, 0.22), wood)
			_box(root, Vector3(0.082, 0.02, 0.36), Vector3(0, 0.105, -0.2), accent)
			muzzle = Vector3(0, 0.07, -0.79)
	root.set_meta("muzzle", muzzle)
	return root


static func _box(root: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


static func _cyl(root: Node3D, r: float, length: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = length
	m.radial_segments = 8
	m.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation.x = PI * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi
