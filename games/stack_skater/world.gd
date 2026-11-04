class_name SkaterWorld
extends Node3D
## Builds Stack Skater's world: a narrow concrete sky-track high above a
## foggy city of box skyscrapers, plus every level feature (pickups, gates,
## spike strips, narrow walls) and the x1..x10 finish ramp.

const HALF: float = SkaterLevels.TRACK_HALF
const STEP_COUNT: int = 10
const STEP_DEPTH: float = 2.4
const STEP_RISE: float = 0.38
const START_PAD: float = 16.0

var length: float = 160.0
var pickups: Array[Dictionary] = []   # {node, label, x, z, amount, taken}
var gates: Array[GatePair] = []
var spikes: Array[Dictionary] = []    # {z0, z1, side, inner}
var narrows: Array[Dictionary] = []   # {z0, z1, half}
var step_piles: Array[MeshInstance3D] = []


func build(level: Dictionary, seed_value: int) -> void:
	length = float(level["length"])
	var track_mat := ShaderMaterial.new()
	track_mat.shader = preload("res://shaders/track.gdshader")
	track_mat.set_shader_parameter("color_a", Palette.TRACK)
	track_mat.set_shader_parameter("color_b", Palette.TRACK.darkened(0.06))
	track_mat.set_shader_parameter("side_color", Color("#8E98AE"))
	track_mat.set_shader_parameter("band_length", 3.0)
	var total: float = length + START_PAD
	_box(Vector3(HALF * 2.0, 0.8, total), Vector3(0, -0.4, START_PAD - total * 0.5), track_mat)
	# Edge stripes + low rails (below bar height so the bar passes over them).
	var edge_mat: ShaderMaterial = Toon.mat(Palette.GOLD, 0.0, 0.3)
	var rail_mat: ShaderMaterial = Toon.mat(Palette.METAL.lightened(0.2), 0.0, 0.5)
	for sx: float in [-1.0, 1.0]:
		_box(Vector3(0.2, 0.05, total), Vector3(sx * (HALF - 0.25), 0.025, START_PAD - total * 0.5), edge_mat)
		_box(Vector3(0.12, 0.35, total), Vector3(sx * (HALF + 0.04), 0.17, START_PAD - total * 0.5), rail_mat)
	# Support pillars plunging into the fog.
	var pillar := CylinderMesh.new()
	pillar.top_radius = 0.5
	pillar.bottom_radius = 0.9
	pillar.height = 70.0
	pillar.radial_segments = 8
	pillar.rings = 1
	var pxf: Array[Transform3D] = []
	var z: float = START_PAD - 8.0
	while z > -length - 30.0:
		pxf.append(Transform3D(Basis(), Vector3(0, -35.6, z)))
		z -= 26.0
	_multimesh(pillar, Toon.mat(Color("#9AA5B8"), 0.0, 0.2), pxf, false)
	_build_city(seed_value)
	_build_features(level)
	_build_ramp()


func _build_city(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var groups: Array = [[], [], []]
	var z: float = 60.0
	while z > -length - 160.0:
		for i: int in 6:
			var side: float = -1.0 if rng.randf() < 0.5 else 1.0
			var x: float = side * rng.randf_range(9.0, 90.0)
			var w: float = rng.randf_range(5.0, 12.0)
			var top: float = rng.randf_range(-45.0, -6.0)
			if absf(x) > 28.0 and rng.randf() < 0.35:
				top = rng.randf_range(-4.0, 22.0)  # a few towers rise past the track
			var h: float = top + 120.0
			var xf := Transform3D(Basis().scaled(Vector3(w, h, rng.randf_range(5.0, 12.0))), Vector3(x, top - h * 0.5, z + rng.randf_range(-8.0, 8.0)))
			(groups[rng.randi_range(0, 2)] as Array).append(xf)
		z -= 22.0
	var cube := BoxMesh.new()
	var walls: Array[Color] = [Color("#A9B6CB"), Color("#8E9DB6"), Color("#C2CBDA")]
	for gi: int in 3:
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/building.gdshader")
		m.set_shader_parameter("wall", walls[gi])
		m.set_shader_parameter("window_color", walls[gi].darkened(0.3))
		var xfs: Array[Transform3D] = []
		for x: Variant in groups[gi]:
			xfs.append(x as Transform3D)
		_multimesh(cube, m, xfs, false)


func _build_features(level: Dictionary) -> void:
	var coin_mat := ShaderMaterial.new()
	coin_mat.shader = preload("res://shaders/coin.gdshader")
	coin_mat.set_shader_parameter("glow", 0.35)
	var spike_mat: ShaderMaterial = Toon.mat(Palette.METAL.lightened(0.3), 0.03, 0.7)
	var danger: ShaderMaterial = Toon.mat(Palette.ENEMY, 0.03, 0.4)
	var wall_mat: ShaderMaterial = Toon.mat(Color("#E9EEF6"), 0.03, 0.4)
	var wall_stripe: ShaderMaterial = Toon.mat(Palette.ENEMY, 0.0, 0.3)
	for f: Variant in level["features"]:
		var fd: Dictionary = f
		var fz: float = -float(fd["d"])
		match str(fd["type"]):
			"pickup":
				var amount: int = int(fd["amount"])
				var root := Node3D.new()
				root.position = Vector3(float(fd["x"]), 0.0, fz)
				add_child(root)
				var stack := CylinderMesh.new()
				stack.top_radius = 0.28
				stack.bottom_radius = 0.28
				var hgt: float = 0.25 + minf(float(amount) * 0.045, 0.7)
				stack.height = hgt
				stack.radial_segments = 14
				stack.rings = maxi(1, int(hgt / 0.07))
				var mi := MeshInstance3D.new()
				mi.mesh = stack
				mi.material_override = coin_mat
				mi.position = Vector3(0, 0.35 + hgt * 0.5, 0)
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(mi)
				var l := Label3D.new()
				l.font = UiKit.font()
				l.text = "+%d" % amount
				l.font_size = 120
				l.outline_size = 26
				l.pixel_size = 0.006
				l.modulate = Palette.GOLD.lightened(0.4)
				l.outline_modulate = Palette.shade(Palette.GOLD_SHADOW, 0.5)
				l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				l.position = Vector3(0, 0.75 + hgt + 0.35, 0)
				l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(l)
				Toon.limit_range(root, 60.0)
				pickups.append({"node": root, "x": float(fd["x"]), "z": fz, "amount": amount, "taken": false})
			"gate":
				var gp := GatePair.new()
				add_child(gp)
				gp.build(fz, str(fd["left"]), str(fd["right"]), HALF - 0.05)
				gates.append(gp)
				Toon.limit_range(gp, 70.0)
			"spikes":
				var side: float = float(fd["side"])
				var inner: float = float(fd["inner"])
				var ln: float = float(fd["len"])
				var w: float = HALF - inner
				_box(Vector3(w, 0.12, ln), Vector3(side * (inner + w * 0.5), 0.06, fz - ln * 0.5), danger)
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = 0.17
				cone.height = 1.55
				cone.radial_segments = 6
				cone.rings = 1
				var xfs: Array[Transform3D] = []
				var zz: float = 0.3
				while zz < ln:
					var xx: float = inner + 0.2
					while xx < HALF:
						xfs.append(Transform3D(Basis(), Vector3(side * xx, 0.85, fz - zz)))
						xx += 0.42
					zz += 0.55
				_multimesh(cone, spike_mat, xfs, true)
				spikes.append({"z0": fz, "z1": fz - ln, "side": side, "inner": inner})
			"narrow":
				var half: float = float(fd["half"])
				var ln: float = float(fd["len"])
				for sx: float in [-1.0, 1.0]:
					var wx: float = sx * (half + 0.2)
					_box(Vector3(0.4, 1.7, ln), Vector3(wx, 0.85, fz - ln * 0.5), wall_mat)
					_box(Vector3(0.42, 0.22, ln), Vector3(wx, 1.4, fz - ln * 0.5), wall_stripe)
					# Floor fill between wall and rail so it reads as a choke point.
					var fill: float = HALF - half - 0.4
					if fill > 0.05:
						_box(Vector3(fill, 1.0, ln), Vector3(sx * (half + 0.4 + fill * 0.5), 0.5, fz - ln * 0.5), Toon.mat(Color("#B9C3D3"), 0.0, 0.2))
				narrows.append({"z0": fz, "z1": fz - ln, "half": half})


func _build_ramp() -> void:
	var z0: float = -length
	for i: int in STEP_COUNT:
		var k: float = float(i) / float(STEP_COUNT - 1)
		var col: Color = Palette.PLAYER.lerp(Palette.GOLD, k)
		var top: float = float(i + 1) * STEP_RISE
		var zc: float = z0 - STEP_DEPTH * (float(i) + 0.5)
		_box(Vector3(HALF * 2.0 + 0.8, top + 0.8, STEP_DEPTH), Vector3(0, top * 0.5 - 0.4, zc), Toon.mat(col, 0.03, 0.35))
		var l := Label3D.new()
		l.font = UiKit.font()
		l.text = "×%d" % (i + 1)
		l.font_size = 160
		l.outline_size = 30
		l.pixel_size = 0.006
		l.modulate = Color.WHITE
		l.outline_modulate = Palette.shade(col, 0.5)
		l.position = Vector3(0, top - 0.22, zc + STEP_DEPTH * 0.5 + 0.02)
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(l)
		# Coin pile left on the step when the skater pays for it (hidden until then).
		var pile := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.18
		pm.bottom_radius = 0.45
		pm.height = 0.35
		pm.radial_segments = 12
		pm.rings = 2
		pile.mesh = pm
		var cm := ShaderMaterial.new()
		cm.shader = preload("res://shaders/coin.gdshader")
		pile.material_override = cm
		pile.position = Vector3(1.8 if i % 2 == 0 else -1.8, top + 0.17, zc)
		pile.visible = false
		pile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pile)
		step_piles.append(pile)
	# Trophy platform past the last step.
	var end_top: float = float(STEP_COUNT) * STEP_RISE
	_box(Vector3(HALF * 2.0 + 0.8, end_top + 0.8, 8.0), Vector3(0, end_top * 0.5 - 0.4, z0 - STEP_DEPTH * float(STEP_COUNT) - 4.0), Toon.mat(Palette.GOLD, 0.03, 0.5))


## Z of the start of ramp step i, and its top height.
func step_z(i: int) -> float:
	return -length - STEP_DEPTH * float(i)


func step_top(i: int) -> float:
	return float(i + 1) * STEP_RISE


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _multimesh(mesh: Mesh, mat: Material, xfs: Array[Transform3D], shadow: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i: int in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow and Settings.shadows_enabled() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi
