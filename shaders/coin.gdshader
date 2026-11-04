shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// Gold coin: toon bands + a fake specular streak sweeping across over time.
#include "res://shaders/toon_light.gdshaderinc"

uniform vec4 gold : source_color = vec4(1.0, 0.773, 0.192, 1.0);
uniform vec4 gold_shadow : source_color = vec4(0.878, 0.604, 0.0, 1.0);
uniform float glow = 0.18;
uniform float sweep_speed = 0.8;

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	// Coin faces (axis X) slightly lighter than the ridged edge.
	float face = smoothstep(0.6, 0.8, abs(wn.x));
	vec3 c = mix(gold_shadow.rgb, gold.rgb, 0.55 + 0.45 * face);
	float sweep = fract((wp.x + wp.y * 0.7 + wp.z * 0.3) * 0.18 - TIME * sweep_speed);
	float streak = smoothstep(0.0, 0.04, sweep) * (1.0 - smoothstep(0.04, 0.1, sweep));
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = c * glow + vec3(1.0, 0.95, 0.8) * streak * 0.9
			+ rim_color * toon_rim(NORMAL, VIEW) * 0.6;
}
