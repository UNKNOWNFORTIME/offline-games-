shader_type spatial;
// Particles: unshaded, colored by the emitter's per-particle color.
render_mode unshaded, cull_back, shadows_disabled;

void fragment() {
	ALBEDO = COLOR.rgb;
}
