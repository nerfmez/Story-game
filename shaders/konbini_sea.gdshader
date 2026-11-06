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
	float lag = sin(x * 0.25) * 0.6;
	float phase = fract((t + lag) / PERIOD + d / (SPEED * PERIOD));
	float dist = min(phase, 1.0 - phase) * SPEED * PERIOD;   // metres from the crest
	float shape = exp(-dist * dist * 2.2);
	float grow = mix(0.06, 0.2, 1.0 - smoothstep(1.0, 6.0, d)) * smoothstep(0.35, 1.1, d);
	c = shape * (1.0 - smoothstep(1.4, 3.0, d)) * smoothstep(0.3, 0.8, d);
	float ripple = sin(d * 3.1 - t * 1.7 + x * 0.4) * 0.012 * smoothstep(0.5, 2.0, d);
	return shape * grow + ripple;
}

// The water surface: the open-sea waves, and near the shore a sheet whose edge sits
// exactly on the sand at the swash front, sloping gently down toward the sea.
float surface(float x, float d, float t, out float c) {
	float open_sea = SEA_Y + wave_height(x, d, t, c);
	float s;
	float reach;
	float fall;
	float front = swash_front(x, t, s, reach, fall);
	float sheet = ground_u(-front) + 0.002 - 0.014 * (d + front);
	float near = 1.0 - smoothstep(0.5, 1.8, d);
	return mix(open_sea, sheet, near);
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
	col = mix(col, foam, cap);
	// sun glints on the open water
	float g = beach_noise(world_pos.xz * 7.0 + TIME * vec2(0.8, -0.6));
	float glint = smoothstep(0.92, 0.95, g) * far;
	ALBEDO = col;
	EMISSION = foam * glint * 1.4 + col * 0.06;
	// clear where shallow: the sand shows through and the edge fades out to nothing
	ALPHA = max(mix(0.05, 0.92, smoothstep(0.0, 0.32, depth)), cap);
	ROUGHNESS = 0.2;
	SPECULAR = 0.0;
}

void light() {
	float lit = 0.6 + 0.4 * smoothstep(0.0, 0.08, dot(NORMAL, LIGHT));
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * lit * ATTENUATION;
}
