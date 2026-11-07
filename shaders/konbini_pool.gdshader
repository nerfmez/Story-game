shader_type spatial;
// Still sea water left in a tide pool on the rock shelf (scripts/konbini_headland.gd),
// painted like the shallows of shaders/konbini_sea.gdshader so it belongs to the same
// sea: clear at the edge where it is shallow, turquoise toward the deep middle, a few
// slow ripples, a faint net of light on the bottom and a glint now and then.
// The surface is a flat square at the water level; the rock around the hollow is higher
// and hides it, so the pool takes the real outline of the hollow.
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

#include "res://shaders/konbini_beach.gdshaderinc"

uniform vec3 shallow : source_color = vec3(0.45, 0.88, 0.84);
uniform vec3 deep : source_color = vec3(0.16, 0.55, 0.66);
uniform vec2 centre = vec2(0.0);
uniform float radius = 0.6;

varying vec3 world_pos;

float cell_edge(vec2 p, float t) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 h = vec2(beach_hash(i + o), beach_hash(i + o + vec2(17.3, 5.1)));
			vec2 pt = o + 0.5 + 0.38 * sin(t * (0.6 + 0.5 * h) + 6.2831 * h);
			float d = length(pt - f);
			if (d < f1) {
				f2 = f1;
				f1 = d;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return f2 - f1;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// a bowl: shallow at the rim, deepest in the middle
	float r = clamp(length(world_pos.xz - centre) / radius, 0.0, 1.0);
	float depth = 1.0 - r * r;
	vec3 col = mix(shallow, deep, smoothstep(0.1, 0.9, depth));
	// slow ripples crossing the still water
	float n = beach_noise(world_pos.xz * 3.0 + vec2(TIME * 0.15, -TIME * 0.1));
	col += smoothstep(0.62, 0.7, n) * 0.08;
	// the net of light on the bottom, faint, as in the shallows of the sea
	float net = 1.0 - smoothstep(0.025, 0.06, cell_edge(world_pos.xz * 2.2, TIME * 0.3));
	col = mix(col, vec3(0.62, 1.0, 0.86), net * 0.22 * smoothstep(0.15, 0.6, depth));
	// a glint that forms and fades
	float g = beach_noise(world_pos.xz * 9.0 + vec2(0.0, TIME * 0.05));
	float w = 0.5 + 0.5 * sin(TIME * 0.55 + beach_noise(world_pos.xz * 1.3) * 12.0);
	float glint = smoothstep(0.9, 0.93, mix(g, beach_noise(world_pos.xz * 9.0 + 7.3), w));
	ALBEDO = mix(col, vec3(1.0), glint * 0.9);
	ALPHA = max(mix(0.15, 0.82, smoothstep(0.0, 0.7, depth)), glint);
}
