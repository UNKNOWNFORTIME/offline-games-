shader_type spatial;
// Inverted-hull outline, used as next_pass. Disabled on Low quality.
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform vec4 outline_color : source_color = vec4(0.106, 0.122, 0.165, 1.0);
uniform float outline_width = 0.03;

void vertex() {
	VERTEX += normalize(NORMAL) * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
