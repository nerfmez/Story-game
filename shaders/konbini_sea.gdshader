shader_type spatial;
// The sea of the beach block (scripts/konbini_beach.gd). Waves come in one at a
// time every `period` seconds: a crest builds as it nears the shore, turns white
// and breaks just off the beach, and the swash then runs up the sand (that part is
// shaders/konbini_swash.gdshader, which uses the same timing). Between waves the
// water is shallow turquoise at the shore turning deep blue, with glints further out.
// shore(x) is the waterline and must match SHORE in the beach builder.
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 shallow : source_color = vec3(0.36, 0.86, 0.84);
uniform vec3 deep : source_color = vec3(0.1, 0.4, 0.74);
uniform vec3 foam : source_color = vec3(0.97, 0.99, 1.0);
uniform float period = 7.0;
uniform float speed = 1.5;

varying vec3 world_pos;
varying float crest;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float shore(float x) {
	return 3.0 + 0.45 * sin(x * 0.35 + 0.6) + 0.25 * sin(x * 0.93 + 2.0);
}

// Height of the incoming wave at (x, distance from shore d). The crest travels
// toward the beach at `speed`, grows as the water shallows and collapses at d < 0.6.
float wave_height(float x, float d, float t, out float c) {
	float lag = sin(x * 0.25) * 0.6;
	float phase = fract((t + lag) / period + d / (speed * period));
	float dist = min(phase, 1.0 - phase) * speed * period;   // metres from the crest
	float shape = exp(-dist * dist * 2.2);
	float grow = mix(0.06, 0.2, 1.0 - smoothstep(1.0, 6.0, d)) * smoothstep(0.35, 1.1, d);
	c = shape * (1.0 - smoothstep(1.4, 3.0, d)) * smoothstep(0.3, 0.8, d);
	float ripple = sin(d * 3.1 - t * 1.7 + x * 0.4) * 0.012 * smoothstep(0.0, 2.0, d);
	return shape * grow + ripple;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float c;
	float d = world_pos.z - shore(world_pos.x);
	float h = wave_height(world_pos.x, d, TIME, c);
	float cx;
	float hx = wave_height(world_pos.x + 0.1, d, TIME, cx);
	float hz = wave_height(world_pos.x, d + 0.1, TIME, cx);
	VERTEX.y += h;
	NORMAL = normalize(vec3(-(hx - h) / 0.1, 1.0, -(hz - h) / 0.1));
	crest = c;
}

void fragment() {
	float d = world_pos.z - shore(world_pos.x);
	float depth = smoothstep(0.0, 5.0, d);
	vec3 col = mix(shallow, deep, depth);
	// light ripples over the sandy shallows
	float n = noise(world_pos.xz * 1.6 + vec2(TIME * 0.3, TIME * 0.2));
	col += (1.0 - depth) * smoothstep(0.62, 0.7, n) * 0.12;
	// the face of a building wave is greener, its top breaks into foam
	col = mix(col, shallow * 1.08, smoothstep(0.2, 0.6, crest) * 0.5);
	float lace = noise(vec2(world_pos.x * 2.2, d * 4.0 + TIME * 0.6));
	float cap = smoothstep(0.55, 0.75, crest) * smoothstep(0.3, 0.55, lace + crest * 0.4);
	// a little foam always clinging to the very edge of the water
	float edge = (1.0 - smoothstep(0.02, 0.12, d + (lace - 0.5) * 0.1)) * 0.7;
	col = mix(col, foam, max(cap, edge));
	// sun glints on the open water
	float g = noise(world_pos.xz * 7.0 + TIME * vec2(0.8, -0.6));
	float glint = smoothstep(0.92, 0.95, g) * depth;
	ALBEDO = col;
	EMISSION = foam * glint * 1.4 + col * 0.06;
	ROUGHNESS = 0.2;
	SPECULAR = 0.0;
}

void light() {
	float lit = 0.6 + 0.4 * smoothstep(0.0, 0.08, dot(NORMAL, LIGHT));
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * lit * ATTENUATION;
}
