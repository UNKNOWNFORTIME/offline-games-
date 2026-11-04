class_name GatePair
extends Node3D
## A pair of math gates spanning the track (left half / right half).
## Ops: "+N", "-N", "xN", "/N". Positive = blue, negative = red.
## The crowd's center passing through consumes one gate and disables the other.

const PANEL_HEIGHT: float = 2.7
const POST_HEIGHT: float = 3.3

var z_pos: float = 0.0
var ops: Array[String] = ["+1", "+1"]
var consumed: bool = false
var _panels: Array[MeshInstance3D] = []
var _labels: Array[Label3D] = []
var _mats: Array[ShaderMaterial] = []
var _half_w: float = 4.0
static var _post_mesh_cache: ArrayMesh = null
static var _post_cache_w: float = -1.0


func build(p_z: float, left_op: String, right_op: String, half_width: float) -> void:
	z_pos = p_z
	ops = [left_op, right_op]
	_half_w = half_width
	position = Vector3(0, 0, p_z)
	var panel_shader: Shader = preload("res://shaders/gate_panel.gdshader")
	var gap: float = 0.12
	var w: float = half_width - gap
	for side: int in 2:
		var op: String = ops[side]
		var positive: bool = is_positive(op)
		var x: float = (-1.0 if side == 0 else 1.0) * (half_width * 0.5)
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(w, PANEL_HEIGHT)
		mi.mesh = q
		var m := ShaderMaterial.new()
		m.shader = panel_shader
		m.set_shader_parameter("tint", Palette.PLAYER if positive else Palette.ENEMY)
		m.set_shader_parameter("alpha", 0.42)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(x, PANEL_HEIGHT * 0.5 + 0.15, 0)
		add_child(mi)
		_panels.append(mi)
		_mats.append(m)

		var l := Label3D.new()
		l.font = UiKit.font()
		l.text = pretty(op)
		l.font_size = 190
		l.outline_size = 34
		l.pixel_size = 0.0068
		l.modulate = Color.WHITE
		l.outline_modulate = Palette.shade(Palette.PLAYER if positive else Palette.ENEMY, 0.55)
		l.position = Vector3(x, PANEL_HEIGHT * 0.55 + 0.15, 0.06)
		l.double_sided = false
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		l.render_priority = 2
		l.outline_render_priority = 1
		l.set_meta("base_scale", 1.0)
		add_child(l)
		_labels.append(l)

	# Posts + gold caps, baked into ONE mesh (1 draw call per gate).
	var tmp := Node3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.16
	post_mesh.bottom_radius = 0.18
	post_mesh.height = POST_HEIGHT
	post_mesh.radial_segments = 10
	post_mesh.rings = 1
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.26
	cap_mesh.height = 0.52
	cap_mesh.radial_segments = 10
	cap_mesh.rings = 5
	var post_mat: ShaderMaterial = Toon.mat(Palette.WHITE, 0.0, 0.3)
	var cap_mat: ShaderMaterial = Toon.mat(Palette.GOLD, 0.0, 0.5)
	for px: float in [-half_width, 0.0, half_width]:
		var p := MeshInstance3D.new()
		p.mesh = post_mesh
		p.material_override = post_mat
		p.position = Vector3(px, POST_HEIGHT * 0.5, 0)
		tmp.add_child(p)
		var cap := MeshInstance3D.new()
		cap.mesh = cap_mesh
		cap.material_override = cap_mat
		cap.position = Vector3(px, POST_HEIGHT + 0.05, 0)
		tmp.add_child(cap)
	if _post_mesh_cache == null or not is_equal_approx(_post_cache_w, half_width):
		_post_mesh_cache = MeshBaker.bake(tmp)
		_post_cache_w = half_width
	tmp.free()
	var posts := MeshInstance3D.new()
	posts.mesh = _post_mesh_cache
	posts.material_override = MeshBaker.material(0.035)
	posts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(posts)


## side: 0 left, 1 right. Returns the new count.
func consume(side: int, count: int) -> int:
	consumed = true
	var chosen: int = side
	var other: int = 1 - side
	var result: int = apply(ops[chosen], count)
	var chosen_mat: ShaderMaterial = _mats[chosen]
	var chosen_panel: MeshInstance3D = _panels[chosen]
	var chosen_label: Label3D = _labels[chosen]
	# Chosen: flash + swell + fade away.
	var t: Tween = create_tween().set_parallel(true)
	t.tween_method(func(v: float) -> void: chosen_mat.set_shader_parameter("glow", v), 1.6, 0.0, 0.35)
	t.tween_method(func(v: float) -> void: chosen_mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.45).set_delay(0.1)
	t.tween_property(chosen_panel, "scale", Vector3(1.15, 1.25, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(chosen_label, "scale", Vector3(1.6, 1.6, 1.6), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(chosen_label, "modulate:a", 0.0, 0.3).set_delay(0.15)
	t.tween_property(chosen_label, "outline_modulate:a", 0.0, 0.3).set_delay(0.15)
	# Other: greys out.
	var other_mat: ShaderMaterial = _mats[other]
	t.tween_method(func(v: float) -> void: other_mat.set_shader_parameter("disabled", v), 0.0, 1.0, 0.25)
	t.tween_property(_labels[other], "modulate", Color(0.75, 0.75, 0.75, 0.55), 0.25)
	var col: Color = Palette.PLAYER_LIGHT if is_positive(ops[chosen]) else Palette.ENEMY_LIGHT
	Juice.burst(chosen_panel.global_position, col, 1.0)
	Juice.burst(chosen_panel.global_position + Vector3(0, 0.9, 0), Color.WHITE, 0.7)
	return result


func side_center_x(side: int) -> float:
	return (-1.0 if side == 0 else 1.0) * (_half_w * 0.5)


static func is_positive(op: String) -> bool:
	var c: String = op.substr(0, 1)
	return c == "+" or c == "x" or c == "*"


static func op_value(op: String) -> int:
	return maxi(1, int(op.substr(1)))


static func apply(op: String, n: int) -> int:
	var v: int = op_value(op)
	match op.substr(0, 1):
		"+":
			return n + v
		"-":
			return maxi(0, n - v)
		"x", "*":
			return n * v
		"/":
			return n / v
	return n


## Display: "x3" -> "×3", "/2" -> "÷2".
static func pretty(op: String) -> String:
	var v: String = op.substr(1)
	match op.substr(0, 1):
		"x", "*":
			return "×" + v
		"/":
			return "÷" + v
		"-":
			return "-" + v
	return "+" + v
