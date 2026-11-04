shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// Simple skyscraper: world-space window grid, some windows lit, roof band.
#include "res://shaders/toon_light.gdshaderinc"

uniform vec4 wall : source_color = vec4(0.62, 0.68, 0.78, 1.0);
uniform vec4 window_color : source_color = vec4(0.35, 0.45, 0.62, 1.0);
uniform vec4 lit_color : source_color = vec4(1.0, 0.86, 0.55, 1.0);
uniform float lit_amount = 0.18;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float side_x = step(0.5, abs(wn.x));
	float u = mix(wp.x, wp.z, side_x);
	vec2 cell = vec2(u / 2.2, wp.y / 3.0);
	vec2 f = fract(cell);
	float win = step(0.18, f.x) * step(f.x, 0.82) * step(0.25, f.y) * step(f.y, 0.8);
	win *= 1.0 - step(0.5, abs(wn.y));
	float lit = step(1.0 - lit_amount, hash(floor(cell) + floor(wp.xz * 0.05)));
	vec3 c = mix(wall.rgb, mix(window_color.rgb, lit_color.rgb, lit), win);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = lit_color.rgb * win * lit * 0.6;
}
