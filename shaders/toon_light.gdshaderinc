// Shared toon lighting (GAME_SPEC 5.3). Included by every lit stylized shader.
// 3 soft bands, blue-shifted shadow tint (never black), tiny toy-like specular.
uniform vec3 shadow_tint : source_color = vec3(0.52, 0.58, 0.86);
uniform float band_softness : hint_range(0.001, 0.3) = 0.05;
uniform float spec_strength : hint_range(0.0, 2.0) = 0.25;
uniform vec3 rim_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.35;
uniform float light_intensity : hint_range(0.0, 2.0) = 0.92;

void light() {
	// Use the light's hue at a fixed intensity so the look is identical on
	// Vulkan (Mobile) and the OpenGL fallback regardless of energy scaling.
	vec3 lc = LIGHT_COLOR / max(max(LIGHT_COLOR.r, LIGHT_COLOR.g), max(LIGHT_COLOR.b, 0.0001));
	lc *= light_intensity;
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(0.0, band_softness, ndl) * 0.6
			+ smoothstep(0.5, 0.5 + band_softness, ndl) * 0.4;
	lit *= ATTENUATION;
	vec3 band_col = mix(shadow_tint, vec3(1.0), lit);
	DIFFUSE_LIGHT += band_col * lc;
	vec3 h = normalize(LIGHT + VIEW);
	float s = smoothstep(0.93, 0.95, dot(NORMAL, h)) * spec_strength * ATTENUATION;
	SPECULAR_LIGHT += s * lc;
}

float toon_rim(vec3 normal, vec3 view) {
	float f = 1.0 - clamp(dot(normal, view), 0.0, 1.0);
	return smoothstep(0.55, 0.85, f) * rim_strength;
}
