class_name EnvBuilder
extends RefCounted
## Builds sky, fog, ambient and the single sun light for a game scene.
## Presets per GAME_SPEC 5.5: sunny, hazy_city, misty_forest.

static func build(parent: Node, preset: String = "sunny") -> DirectionalLight3D:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	var light := DirectionalLight3D.new()
	var fog_color: Color = Palette.SKY_HORIZON
	var fog_density: float = 0.006
	match preset:
		"hazy_city":
			sky_mat.sky_top_color = Color("#8FA6C6")
			sky_mat.sky_horizon_color = Palette.FOG_CITY
			sky_mat.ground_horizon_color = Palette.FOG_CITY
			sky_mat.ground_bottom_color = Color("#7A879C")
			fog_color = Palette.FOG_CITY
			fog_density = 0.012
			light.light_color = Color("#FFF1DE")
		"misty_forest":
			sky_mat.sky_top_color = Color("#7E9A8E")
			sky_mat.sky_horizon_color = Color("#C9D6CC")
			sky_mat.ground_horizon_color = Color("#C9D6CC")
			sky_mat.ground_bottom_color = Palette.FOREST
			fog_color = Color("#A9BAAE")
			fog_density = 0.011
			light.light_color = Color("#F3F1E4")
		_:
			sky_mat.sky_top_color = Color("#3E9BF0")
			sky_mat.sky_horizon_color = Palette.SKY_HORIZON
			sky_mat.ground_horizon_color = Palette.SKY_HORIZON
			sky_mat.ground_bottom_color = Color("#4FA8E8")
			fog_color = Color("#CBEBFF")
			fog_density = 0.0065
			light.light_color = Color("#FFF4E0")
	sky_mat.sky_curve = 0.12
	sky_mat.ground_curve = 0.05
	sky_mat.sun_angle_max = 25.0
	sky_mat.sun_curve = 0.1
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#B7CCF2")
	env.ambient_light_energy = 0.3
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_density = fog_density
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0
	if Settings.is_high():
		env.glow_enabled = true
		env.glow_intensity = 0.55
		env.glow_strength = 0.9
		env.glow_bloom = 0.0
		env.glow_hdr_threshold = 1.3
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)

	light.light_energy = 1.25
	light.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	light.shadow_enabled = Settings.shadows_enabled()
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance = 38.0
	light.shadow_bias = 0.06
	light.shadow_normal_bias = 1.2
	light.shadow_opacity = 0.75
	light.shadow_blur = 1.5
	light.light_specular = 0.4
	parent.add_child(light)
	return light
