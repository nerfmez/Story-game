shader_type spatial;
// Shop glass: mostly clear so the interior reads from outside, two painted sheen
// bands, and (rain > 0) beads plus drops that slide down and leave a trail.
// UV covers the pane; size is the pane in metres so the drops keep their scale.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec3 tint : source_color = vec3(0.55, 0.7, 0.82);
uniform float base_alpha = 0.08;
uniform vec2 size = vec2(1.0, 2.0);
uniform float rain = 1.0;
uniform vec3 drop_color : source_color = vec3(0.82, 0.88, 1.0);
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = vec2(UV.x * size.x, (1.0 - UV.y) * size.y);
	float drops = 0.0;
	if (rain > 0.0) {
		float col_w = 0.075;
		float ci = floor(p.x / col_w) + seed * 31.0;
		float h = hash(vec2(ci, 1.3));
		if (h > 0.4) {
			float lx = (fract(p.x / col_w) - 0.5) * col_w;
			float wob = sin(p.y * 6.0 + h * 40.0) * 0.008;
			float travel = size.y + 0.8;
			float head = travel - fract(TIME * (0.05 + h * 0.08) + h * 7.0) * travel - 0.4;
			float dx = lx - wob;
			float head_d = length(vec2(dx, (p.y - head) * 0.75));
			drops = max(drops, 1.0 - smoothstep(0.007, 0.011, head_d));
			float above = p.y - head;
			if (above > 0.0 && above < 0.7) {
				drops = max(drops, (1.0 - smoothstep(0.0015, 0.0035, abs(dx))) * (1.0 - above / 0.7) * 0.7);
			}
		}
		vec2 cell = floor(p / 0.04);
		float bead_seed = hash(cell + seed);
		float gen = floor(TIME * 0.15 + bead_seed * 5.0);
		if (hash(cell + gen * 1.7 + seed) > 0.72) {
			vec2 c = (cell + 0.25 + 0.5 * vec2(hash(cell + 1.1 + gen), hash(cell + 2.3 + gen))) * 0.04;
			float r = 0.003 + 0.004 * hash(cell + 4.4 + gen);
			drops = max(drops, (1.0 - smoothstep(r * 0.6, r, length(p - c))) * 0.85);
		}
		drops *= rain;
	}
	float diag = fract((p.x * 0.7 + p.y * 0.45) / 2.6 + seed * 0.37);
	float sheen = step(0.1, diag) * step(diag, 0.2) + step(0.25, diag) * step(diag, 0.27);
	ALBEDO = mix(tint, drop_color, clamp(drops + sheen * 0.6, 0.0, 1.0));
	ALPHA = clamp(base_alpha + sheen * 0.09 + drops * 0.6, 0.0, 1.0);
}
