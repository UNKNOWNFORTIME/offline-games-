shader_type canvas_item;
// Full-screen radial speed lines for boost / near miss (GAME_SPEC 5.3 #5).
// Cheap: one hash per pixel, no texture reads.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.85);
uniform vec2 center = vec2(0.5, 0.42);

float hash(float n) {
	return fract(sin(n * 91.3458) * 47453.5453);
}

void fragment() {
	vec2 uv = UV - center;
	uv.y *= 1.6;
	float r = length(uv);
	float ang = atan(uv.y, uv.x);
	float slice = floor(ang * 38.0);
	float t = floor(TIME * 18.0);
	float on = step(0.72, hash(slice + t * 13.0));
	float len_mask = smoothstep(0.28 + 0.2 * hash(slice * 3.1 + t), 0.75, r);
	float a = on * len_mask * intensity;
	COLOR = vec4(line_color.rgb, a * line_color.a);
}
