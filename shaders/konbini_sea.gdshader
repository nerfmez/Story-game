shader_type spatial;
// The sea of the beach block (scripts/konbini_beach.gd). The water is a moving surface
// over sand that slopes down under it, and it is clear where it is shallow, so there
// is no drawn waterline: the edge is simply where the surface meets the sand.
// Waves come in one at a time every PERIOD seconds: a crest builds as it nears the
// beach, turns white and breaks, then the water near the shore rises and runs up the
// slope (the swash), slows and draws back down past the still-water line. The foam
// fringe and the wet sand it leaves are shaders/konbini_swash.gdshader.
render_mode blend_mix, depth_draw_opaque, cull_back;

#include "res://shaders/konbini_beach.gdshaderinc"

uniform vec3 shallow : source_color = vec3(0.36, 0.86, 0.84);
uniform vec3 deep : source_color = vec3(0.1, 0.4, 0.74);
uniform vec3 foam : source_color = vec3(0.97, 0.99, 1.0);

varying vec3 world_pos;
varying float crest;

// Height of the incoming wave at (x, distance from shore d). The crest travels
// toward the beach at SPEED, grows as the water shallows and collapses at d < 0.6.
float wave_height(float x, float d, float t, out float c) {
	float lag = wave_lag(x);
	float phase = fract((t + lag) / PERIOD + d / (SPEED * PERIOD));
	float dist = min(phase, 1.0 - phase) * SPEED * PERIOD;   // metres from the crest
	float shape = exp(-dist * dist * 2.2);
	float grow = mix(0.06, 0.2, 1.0 - smoothstep(1.0, 6.0, d)) * smoothstep(0.35, 1.1, d);
	c = shape * (1.0 - smoothstep(1.4, 3.0, d)) * smoothstep(0.3, 0.8, d);
	float ripple = sin(d * 3.1 - t * 1.7 + x * 0.4) * 0.012 * smoothstep(0.5, 2.0, d);
	return shape * grow + ripple;
}

// Distance between the nearest and second-nearest of a field of slowly wandering
// points: small along the borders between cells, which makes a net of thin lines.
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
			float dist = length(pt - f);
			if (dist < f1) {
				f2 = f1;
				f1 = dist;
			} else if (dist < f2) {
				f2 = dist;
			}
		}
	}
	return f2 - f1;
}

// Sunlight focused by the ripples into a shifting net of bright lines on the sand of
// the shallows (caustics), drawn as crisp cel lines, wobbling as the surface moves.
float caustics(vec2 xz, float t) {
	vec2 warp = vec2(beach_noise(xz * 1.3 + t * 0.07), beach_noise(xz * 1.3 + vec2(4.0, 1.0) - t * 0.07)) - 0.5;
	vec2 p = xz * 1.15 + warp * 0.7;
	float a = 1.0 - smoothstep(0.025, 0.06, cell_edge(p, t * 0.3));
	// in drifting patches rather than everywhere, so it stays a quiet detail
	// and the patches come and go: two fields morph into each other with a phase that
	// differs from place to place, so the net fades in here while it fades out there
	vec2 q = xz * 0.45 + vec2(t * 0.02, -t * 0.012);
	float w = 0.5 + 0.5 * sin(t * 0.22 + beach_noise(xz * 0.6 + vec2(9.0, 2.0)) * 9.0);
	float patch = smoothstep(0.42, 0.72, mix(beach_noise(q), beach_noise(q + vec2(23.1, 7.9)), w));
	return a * patch;
}

// Sun glints: the irregular specks of a thresholded noise, but instead of scrolling
// the pattern slowly morphs between two fields with a phase that differs from place
// to place, so specks grow out of nothing and dissolve again, here and there in turn.
float glints(vec2 xz, float t) {
	vec2 p = xz * 7.0 + vec2(t * 0.05, -t * 0.04);
	float a = beach_noise(p);
	float b = beach_noise(p + vec2(31.7, 12.3));
	float w = 0.5 + 0.5 * sin(t * 0.55 + beach_noise(xz * 1.3) * 12.0);
	float g = mix(a, b, w);
	// keep the specks as crisp as the old ones even where the two fields are mixed
	g = (g - 0.5) / mix(1.0, 0.72, 1.0 - abs(w * 2.0 - 1.0)) + 0.5;
	return smoothstep(0.92, 0.95, g);
}

// The rocky outcrop (scripts/konbini_beach.gd _sea): its outline at the waterline as
// three ellipses. Returns roughly how many metres out from the rock a point is.
float rock_dist(vec2 xz) {
	float a = (length((xz - vec2(7.0, 6.0)) / vec2(0.8, 0.7)) - 1.0) * 0.72;
	float b = (length((xz - vec2(7.7, 6.5)) / vec2(0.6, 0.55)) - 1.0) * 0.56;
	float c = (length((xz - vec2(6.4, 6.6)) / vec2(0.43, 0.38)) - 1.0) * 0.4;
	return min(a, min(b, c));
}

// Seconds since the last wave crest went past this point.
float since_crest(float x, float d, float t) {
	return fract((t + wave_lag(x)) / PERIOD + d / (SPEED * PERIOD)) * PERIOD;
}

// The water surface: the open-sea waves, and near the shore a sheet whose edge sits
// exactly on the sand at the swash front, sloping gently down toward the sea.
float surface(float x, float d, float t, out float c) {
	float open_sea = SEA_Y + wave_height(x, d, t, c);
	float s;
	float reach;
	float fall;
	float rise;
	float front = swash_front(x, t, s, reach, fall, rise);
	float sheet = ground_u(-front) + 0.002 - 0.014 * (d + front);
	float near = 1.0 - smoothstep(0.5, 1.8, d);
	float h = mix(open_sea, sheet, near);
	// a wave hitting the rocks heaps up against them and drains back off
	float rd = max(rock_dist(vec2(x, d + shore(x))), 0.0);
	float since = since_crest(x, d, t);
	h += 0.07 * exp(-rd * 3.5) * smoothstep(0.0, 0.25, since) * exp(-since * 1.6);
	return h;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float c;
	float d = world_pos.z - shore(world_pos.x);
	float h = surface(world_pos.x, d, TIME, c);
	float cx;
	float hx = surface(world_pos.x + 0.1, d, TIME, cx);
	float hz = surface(world_pos.x, d + 0.1, TIME, cx);
	VERTEX.y += h - world_pos.y;
	world_pos.y = h;
	NORMAL = normalize(vec3(-(hx - h) / 0.1, 1.0, -(hz - h) / 0.1));
	crest = c;
}

void fragment() {
	float d = world_pos.z - shore(world_pos.x);
	float depth = world_pos.y - ground_u(d);   // water over the sand here
	float far = smoothstep(0.0, 5.0, d);
	vec3 col = mix(shallow, deep, far);
	// light ripples over the sandy shallows
	float n = beach_noise(world_pos.xz * 1.6 + vec2(TIME * 0.3, TIME * 0.2));
	col += (1.0 - far) * smoothstep(0.62, 0.7, n) * 0.12;
	// the face of a building wave is greener, its top breaks into foam
	col = mix(col, shallow * 1.08, smoothstep(0.2, 0.6, crest) * 0.5);
	float lace = beach_noise(vec2(world_pos.x * 2.2, d * 4.0 + TIME * 0.6));
	float cap = smoothstep(0.55, 0.75, crest) * smoothstep(0.3, 0.55, lace + crest * 0.4);
	// once it has broken the white water rolls on toward the beach and what it leaves
	// behind thins into patches of foam that break up and fade
	float since = fract((TIME + wave_lag(world_pos.x)) / PERIOD + d / (SPEED * PERIOD)) * PERIOD;   // seconds since the crest passed here
	float zone = smoothstep(0.15, 0.6, d) * (1.0 - smoothstep(1.6, 2.8, d));
	float drift = since * 0.25;
	float patches = beach_noise(vec2(world_pos.x * 2.6, d * 3.2 - drift)) * 0.65 + beach_noise(world_pos.xz * 7.0 + vec2(0.0, -drift * 2.0)) * 0.35;
	float thin = mix(0.32, 0.9, clamp(since / 3.2, 0.0, 1.0));
	float spent = smoothstep(thin, thin + 0.08, patches) * zone * (1.0 - smoothstep(2.6, 3.4, since)) * step(0.05, since);
	cap = max(cap, spent * 0.9);
	// around the rocks: a gentle lap of foam always at their foot, and when a crest
	// hits, white water bursts against them, spreads out and breaks up into patches
	float rd = rock_dist(world_pos.xz);
	float since_r = since_crest(world_pos.x, d, TIME);
	float ang = atan(world_pos.z - 6.2, world_pos.x - 7.1);
	float lap_w = 0.05 + 0.04 * sin(TIME * 1.1 + ang * 3.0) + 0.03 * beach_noise(world_pos.xz * 6.0 + TIME * 0.3);
	float lap = 1.0 - smoothstep(lap_w * 0.6, lap_w, rd);
	float reach_r = 0.12 + 0.9 * (1.0 - exp(-since_r * 1.4));
	float spread = (1.0 - smoothstep(reach_r * 0.7, reach_r, rd)) * (1.0 - smoothstep(0.6, 3.2, since_r));
	float bits = beach_noise(world_pos.xz * 5.0 + vec2(0.0, since_r * 0.4)) * 0.7 + beach_noise(world_pos.xz * 13.0) * 0.3;
	float breakup = mix(0.2, 0.85, clamp(since_r / 2.8, 0.0, 1.0));
	float wash = spread * smoothstep(breakup, breakup + 0.07, bits);
	cap = max(cap, max(lap, wash) * step(-0.02, rd));
	col = mix(col, foam, cap);
	// sun glints on the open water
	float glint = glints(world_pos.xz, TIME) * far;
	// the net of light on the sand, only where the water is shallow and clear
	// (not in the swash at the edge of the beach: only out where the water is a little deeper)
	float net = caustics(world_pos.xz, TIME) * smoothstep(0.9, 1.7, d) * (1.0 - smoothstep(2.8, 4.2, d)) * smoothstep(0.06, 0.12, depth) * (1.0 - cap);
	col = mix(col, vec3(0.62, 1.0, 0.86), net * 0.28);
	ALBEDO = col;
	EMISSION = foam * glint * 1.4 + col * 0.06;
	// clear where shallow: the sand shows through and the edge fades out to nothing
	ALPHA = max(max(mix(0.05, 0.92, smoothstep(0.0, 0.32, depth)), cap), net * 0.2);
	ROUGHNESS = 0.2;
	SPECULAR = 0.0;
}

void light() {
	float lit = 0.6 + 0.4 * smoothstep(0.0, 0.08, dot(NORMAL, LIGHT));
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * lit * ATTENUATION;
}
