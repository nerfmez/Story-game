shader_type spatial;
// The sea of the beach block (scripts/konbini_beach.gd): shallow turquoise at the
// shore turning deep blue, a gentle swell, a band of foam at the waterline that
// runs up and back, lines of breakers rolling in, and sun glints further out.
// shore(x) is the waterline and must match SHORE in the beach builder.
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 shallow : source_color = vec3(0.36, 0.86, 0.84);
uniform vec3 deep : source_color = vec3(0.1, 0.4, 0.74);
uniform vec3 foam : source_color = vec3(0.97, 0.99, 1.0);

varying vec3 world_pos;

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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = world_pos.z - shore(world_pos.x);
	float swell = sin(d * 1.8 - TIME * 1.4 + world_pos.x * 0.2) * 0.035 * smoothstep(0.0, 2.0, d);
	VERTEX.y += swell;
}

void fragment() {
	float d = world_pos.z - shore(world_pos.x);
	float depth = smoothstep(0.0, 5.0, d);
	vec3 col = mix(shallow, deep, depth);
	// light ripples over the sandy shallows
	float n = noise(world_pos.xz * 1.6 + vec2(TIME * 0.3, TIME * 0.2));
	col += (1.0 - depth) * smoothstep(0.62, 0.7, n) * 0.12;
	// swash: the foam edge creeping up the sand and sliding back
	float reach = 0.3 + 0.22 * sin(TIME * 0.8 + world_pos.x * 0.15);
	float edge = 1.0 - smoothstep(reach - 0.06, reach, d);
	// breakers rolling toward the beach
	float wave = fract(-TIME * 0.12 + d * 0.25 + noise(vec2(world_pos.x * 0.3, 0.0)) * 0.2);
	float crest = smoothstep(0.93, 0.98, wave) * (1.0 - smoothstep(4.0, 5.5, d)) * smoothstep(0.4, 0.9, d);
	crest *= smoothstep(0.35, 0.6, noise(vec2(world_pos.x * 1.3, d * 2.0 + TIME * 0.2)));
	col = mix(col, foam, max(edge, crest));
	// sun glints on the open water
	float g = noise(world_pos.xz * 7.0 + TIME * vec2(0.8, -0.6));
	float glint = smoothstep(0.92, 0.95, g) * depth;
	ALBEDO = col;
	EMISSION = foam * glint * 1.4 + col * 0.06;
	ROUGHNESS = 0.2;
	SPECULAR = 0.0;
}

void light() {
	float lit = 0.65 + 0.35 * smoothstep(0.0, 0.05, dot(NORMAL, LIGHT));
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * lit * ATTENUATION;
}
