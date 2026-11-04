shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// Asphalt with white edge lines and dashed lane lines, all procedural.
#include "res://shaders/toon_light.gdshaderinc"

uniform vec4 asphalt : source_color = vec4(0.29, 0.31, 0.36, 1.0);
uniform vec4 line_color : source_color = vec4(0.97, 0.97, 0.95, 1.0);
uniform vec4 center_color : source_color = vec4(1.0, 0.82, 0.25, 1.0);
uniform float edge_x = 3.9;
uniform float lane_x = 1.3;
uniform float dash = 6.0;

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float ax = abs(wp.x);
	float edge = step(abs(ax - edge_x), 0.12);
	float dashed = step(0.45, fract(wp.z / dash));
	float lane_r = step(abs(wp.x - lane_x), 0.09) * dashed;
	float center = step(abs(wp.x + lane_x), 0.09) * dashed;
	// Subtle asphalt grain from world position.
	float grain = fract(sin(dot(floor(wp.xz * 3.0), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 c = asphalt.rgb * (0.96 + grain * 0.06);
	c = mix(c, line_color.rgb, max(edge, lane_r));
	c = mix(c, center_color.rgb, center);
	c = mix(vec3(0.45, 0.47, 0.5), c, step(0.5, wn.y));
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
