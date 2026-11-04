shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// Shambling enemy (one baked mesh). Vertex COLOR.rgb = part color (sRGB),
// COLOR.a = part mask: 1 body, 0.6 left arm, 0.3 right arm.
// Arms swing out of phase; noise dissolve with a glowing edge on defeat.
#include "res://shaders/toon_light.gdshaderinc"

uniform vec4 tint : source_color = vec4(1.0);
uniform float phase = 0.0;
uniform float walk : hint_range(0.0, 1.0) = 1.0;
uniform float attack : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec3 dissolve_edge : source_color = vec3(0.6, 1.0, 0.55);

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
	float m = COLOR.a;
	float t = TIME * 3.2 + phase;
	if (m < 0.8) {
		float side = m > 0.45 ? 1.0 : -1.0;
		float swing = (sin(t) * side * 0.35 * walk) - attack * 1.3 - 0.9;
		float d = 1.32 - VERTEX.y;
		VERTEX.z += sin(swing) * d * -1.0;
		VERTEX.y += (1.0 - cos(swing)) * d;
	}
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
			mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
			mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void fragment() {
	float n = noise3(v_local * 6.0);
	if (dissolve > 0.0 && n < dissolve) {
		discard;
	}
	vec3 c = pow(COLOR.rgb, vec3(2.2)) * tint.rgb;
	c = mix(c, vec3(1.0), flash);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float edge = dissolve > 0.0 ? smoothstep(0.08, 0.0, n - dissolve) : 0.0;
	EMISSION = rim_color * toon_rim(NORMAL, VIEW) * 0.4 * c + vec3(flash) * 0.8 + dissolve_edge * edge * 2.0;
}
