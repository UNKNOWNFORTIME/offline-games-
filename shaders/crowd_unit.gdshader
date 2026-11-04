shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// Crowd runner. All animation is in the vertex shader so 300 units cost
// one draw call and almost no CPU. Vertex color encodes body parts:
//   R = team mask (0 skin, 1 team color)
//   G = limb flag (1 leg, 0.5 arm, 0 rigid)
//   B = side (0 left, 1 right)
//   A = brightness (0..1 -> 0.55..1.15)
// INSTANCE_CUSTOM.r = animation phase, .g = tint variation, .b = celebrate.
#include "res://shaders/toon_light.gdshaderinc"

uniform vec4 team_color : source_color = vec4(0.184, 0.502, 1.0, 1.0);
uniform vec4 skin_color : source_color = vec4(1.0, 0.82, 0.65, 1.0);
uniform float run_amount : hint_range(0.0, 1.0) = 1.0;
uniform float run_speed = 13.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

varying float v_tint;

void vertex() {
	float phase = INSTANCE_CUSTOM.r * 6.28318;
	float t = TIME * run_speed + phase;
	float limb = COLOR.g;
	float side = COLOR.b * 2.0 - 1.0;
	float ra = run_amount;
	if (limb > 0.75) {
		float sw = sin(t) * side * 0.75 * ra;
		float d = 0.36 - VERTEX.y;
		VERTEX.z += sin(sw) * d;
		VERTEX.y += (1.0 - cos(sw)) * d;
	} else if (limb > 0.25) {
		float sw = -sin(t) * side * 0.9 * ra;
		float d = 0.68 - VERTEX.y;
		VERTEX.z += sin(sw) * d;
		VERTEX.y += (1.0 - cos(sw)) * d;
	}
	float celebrate = INSTANCE_CUSTOM.b;
	VERTEX.y += abs(sin(t)) * 0.07 * ra;
	VERTEX.y += (1.0 - ra) * sin(TIME * 3.0 + phase) * 0.012;
	VERTEX.y += celebrate * abs(sin(TIME * 7.0 + phase)) * 0.45;
	VERTEX.z -= VERTEX.y * 0.16 * ra;
	v_tint = INSTANCE_CUSTOM.g;
}

void fragment() {
	vec3 c = mix(skin_color.rgb, team_color.rgb, COLOR.r);
	c *= 0.55 + 0.6 * COLOR.a;
	c *= 0.9 + 0.2 * v_tint;
	c = mix(c, vec3(1.0), flash);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = rim_color * toon_rim(NORMAL, VIEW) * (0.3 + 0.7 * c) + vec3(flash * 0.8);
}
