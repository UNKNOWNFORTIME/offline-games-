shader_type spatial;
// Cheap stylized water: two sine fields, foam bands, no textures.
render_mode unshaded, cull_back, shadows_disabled;

uniform vec4 deep : source_color = vec4(0.16, 0.56, 0.85, 1.0);
uniform vec4 shallow : source_color = vec4(0.36, 0.78, 0.94, 1.0);
uniform vec4 foam : source_color = vec4(0.9, 0.97, 1.0, 1.0);
uniform float scale = 1.0;

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz * scale;
	float w = sin(wp.x * 0.21 + TIME * 0.9) * sin(wp.z * 0.17 - TIME * 0.7);
	float w2 = sin((wp.x * 0.6 + wp.z * 0.45) + TIME * 1.6) * 0.5 + 0.5;
	float w3 = sin((wp.x * -0.5 + wp.z * 0.7) - TIME * 1.3) * 0.5 + 0.5;
	float f = smoothstep(0.86, 0.94, w2 * w3 + w * 0.15);
	vec3 c = mix(deep.rgb, shallow.rgb, 0.5 + 0.5 * w);
	c = mix(c, foam.rgb, f * 0.55);
	ALBEDO = c;
}
