shader_type spatial;
// Translucent gate panel with animated vertical shimmer and bright edges.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.184, 0.502, 1.0, 1.0);
uniform float alpha = 0.5;
uniform float disabled : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float glow : hint_range(0.0, 2.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	float ex = smoothstep(0.43, 0.5, abs(uv.x - 0.5));
	float ey = smoothstep(0.43, 0.5, abs(uv.y - 0.5));
	float edge = max(ex, ey);
	float sh = 0.5 + 0.5 * sin(uv.y * 16.0 - TIME * 4.5 + uv.x * 4.0);
	sh = smoothstep(0.65, 1.0, sh);
	float sweep = smoothstep(0.08, 0.0, abs(fract(TIME * 0.45) * 1.6 - 0.3 - uv.x - uv.y * 0.3));
	vec3 c = tint.rgb * (0.85 + sh * 0.3) + vec3(edge * 0.55 + sweep * 0.35 + glow * 0.5);
	vec3 grey = vec3(dot(c, vec3(0.3, 0.59, 0.11)));
	c = mix(c, grey * 0.75, disabled);
	ALBEDO = c;
	ALPHA = clamp((alpha + edge * 0.4 + sh * 0.12 + sweep * 0.2 + glow * 0.3) * fade * (1.0 - disabled * 0.55), 0.0, 1.0);
}
