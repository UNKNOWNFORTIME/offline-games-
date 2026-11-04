shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// Track surface: world-space bands along Z make speed readable; side faces
// use a darker tone; optional checker for finish lines.
#include "res://shaders/toon_light.gdshaderinc"

uniform vec4 color_a : source_color = vec4(0.85, 0.83, 0.8, 1.0);
uniform vec4 color_b : source_color = vec4(0.8, 0.78, 0.75, 1.0);
uniform vec4 side_color : source_color = vec4(0.55, 0.6, 0.7, 1.0);
uniform float band_length = 4.0;
uniform float checker = 0.0;
uniform float checker_size = 1.0;

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float top = step(0.5, wn.y);
	float b = step(0.5, fract(wp.z / band_length));
	vec3 c = mix(color_a.rgb, color_b.rgb, b);
	if (checker > 0.5) {
		vec2 g = floor(wp.xz / checker_size);
		float k = mod(g.x + g.y, 2.0);
		c = mix(vec3(0.1, 0.11, 0.15), vec3(1.0), k);
	}
	c = mix(side_color.rgb, c, top);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = rim_color * toon_rim(NORMAL, VIEW) * 0.25 * c;
}
