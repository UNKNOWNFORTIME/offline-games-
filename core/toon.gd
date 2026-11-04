class_name Toon
extends RefCounted
## Material factory for the stylized look. Materials are cached by key so
## identical props share one material (fewer state changes on mobile GPUs).

const TOON_SHADER: Shader = preload("res://shaders/toon.gdshader")
const OUTLINE_SHADER: Shader = preload("res://shaders/outline.gdshader")
const PARTICLE_SHADER: Shader = preload("res://shaders/particle.gdshader")

static var _cache: Dictionary = {}
static var _outline_cache: Dictionary = {}
static var _particle_mat: ShaderMaterial = null


## Shared cached material. Do NOT use for anything that changes per-object
## parameters at runtime (hit flash etc.); use [method unique] instead.
static func mat(color: Color, outline_width: float = 0.0, rim: float = 0.35) -> ShaderMaterial:
	var key: String = "%s|%.3f|%.2f|%s" % [color.to_html(), outline_width, rim, str(Settings.outlines_enabled())]
	if _cache.has(key):
		return _cache[key]
	var m: ShaderMaterial = unique(color, outline_width, rim)
	_cache[key] = m
	return m


static func unique(color: Color, outline_width: float = 0.0, rim: float = 0.35) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON_SHADER
	m.set_shader_parameter("base_color", color)
	m.set_shader_parameter("shadow_tint", _shadow_tint_for(color))
	m.set_shader_parameter("rim_strength", rim)
	if outline_width > 0.0 and Settings.outlines_enabled():
		m.next_pass = outline(outline_width)
	return m


static func emissive(color: Color, strength: float = 1.0) -> ShaderMaterial:
	var m: ShaderMaterial = unique(color, 0.0, 0.2)
	m.set_shader_parameter("emission_color", color)
	m.set_shader_parameter("emission_strength", strength)
	return m


static func outline(width: float, color: Color = Palette.UI_DARK) -> ShaderMaterial:
	var key: String = "%.3f|%s" % [width, color.to_html()]
	if _outline_cache.has(key):
		return _outline_cache[key]
	var m := ShaderMaterial.new()
	m.shader = OUTLINE_SHADER
	m.set_shader_parameter("outline_width", width)
	m.set_shader_parameter("outline_color", color)
	_outline_cache[key] = m
	return m


static func particle() -> ShaderMaterial:
	if _particle_mat == null:
		_particle_mat = ShaderMaterial.new()
		_particle_mat.shader = PARTICLE_SHADER
	return _particle_mat


## Cel shadows are a darker, cooler version of the surface color multiplied
## into the light, so a saturated toy never turns muddy grey.
static func _shadow_tint_for(c: Color) -> Color:
	var hsv_s: float = c.s
	var base := Color(0.5, 0.56, 0.86)
	return base.lerp(Color(0.62, 0.6, 0.85), 1.0 - hsv_s)


## Hides every mesh under `node` beyond `dist` meters from the camera
## (GPU-free culling of far props that fog would hide anyway).
static func limit_range(node: Node, dist: float) -> void:
	if node is GeometryInstance3D:
		var g: GeometryInstance3D = node as GeometryInstance3D
		g.visibility_range_end = dist
		g.visibility_range_end_margin = 4.0
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	for c: Node in node.get_children():
		limit_range(c, dist)


## Call after quality changes so cached materials pick up outline state.
static func clear_cache() -> void:
	_cache.clear()
