shader_type spatial;
// Soft drifting ground-mist card (billboarded, very cheap).
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform vec4 color : source_color = vec4(0.85, 0.9, 0.87, 1.0);
uniform float opacity = 0.35;
uniform float drift = 0.05;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 uv = UV - 0.5;
	float r = length(uv * vec2(1.0, 2.2));
	float soft = smoothstep(0.5, 0.0, r);
	float wav = 0.75 + 0.25 * sin(UV.x * 9.0 + TIME * drift * 20.0) * sin(UV.y * 5.0 - TIME * drift * 13.0);
	ALBEDO = color.rgb;
	ALPHA = soft * wav * opacity;
}
