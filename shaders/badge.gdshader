shader_type spatial;
// Billboarded rounded-rectangle badge (crowd counter background, HP bars).
// fill (0..1) draws a progress bar using fill_color for the filled part.
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled, fog_disabled, blend_mix;

uniform vec4 color : source_color = vec4(0.18, 0.5, 1.0, 1.0);
uniform vec4 fill_color : source_color = vec4(1.0);
uniform vec4 border_color : source_color = vec4(0.106, 0.122, 0.165, 1.0);
uniform vec2 size = vec2(1.5, 0.9);
uniform float radius = 0.45;
uniform float border = 0.07;
uniform float fill = -1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
}

float sd_round_rect(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = (UV - 0.5) * size;
	float r = min(radius, min(size.x, size.y) * 0.5);
	float d = sd_round_rect(p, size * 0.5, r);
	float aa = fwidth(d) * 1.2;
	float a = 1.0 - smoothstep(-aa, aa, d);
	float inner = 1.0 - smoothstep(-aa, aa, d + border);
	vec3 c = color.rgb;
	if (fill >= 0.0) {
		c = (UV.x <= fill) ? fill_color.rgb : color.rgb;
	}
	// Soft top highlight for a glossy toy look.
	c += vec3(0.12) * smoothstep(0.1, -0.35, p.y / size.y);
	ALBEDO = mix(border_color.rgb, c, inner);
	ALPHA = a * color.a;
}
