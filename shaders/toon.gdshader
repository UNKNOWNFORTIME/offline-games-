shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// General stylized cel shader with rim light, optional emission and hit flash.
#include "res://shaders/toon_light.gdshaderinc"

uniform vec4 base_color : source_color = vec4(1.0);
uniform bool use_vertex_color = false;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_strength = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 c = base_color.rgb;
	if (use_vertex_color) {
		c *= COLOR.rgb;
	}
	c = mix(c, vec3(1.0), flash);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = emission_color * emission_strength
			+ rim_color * toon_rim(NORMAL, VIEW) * (0.35 + 0.65 * c)
			+ vec3(flash * 0.9);
}
