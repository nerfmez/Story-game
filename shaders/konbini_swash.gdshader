shader_type spatial;
// The swash on the beach (scripts/konbini_beach.gd): after each wave breaks, a thin
// sheet of water runs up the sand with a line of foam at its front, slows, and
// slides back, leaving the sand dark and wet where it reached until it dries.
// Lies just above the sand from below the waterline up the beach. Timing and
// shore() match shaders/konbini_sea.gdshader.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec3 water : source_color = vec3(0.22, 0.74, 0.8);
uniform vec3 foam : source_color = vec3(0.98, 0.99, 1.0);
uniform vec3 wet : source_color = vec3(0.5, 0.38, 0.26);
uniform float period = 7.0;
uniform float speed = 1.5;

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
}

void fragment() {
	float x = world_pos.x;
	float up = shore(x) - world_pos.z;   // metres up the beach from the waterline
	if (up < -0.15) {
		discard;
	}
	// seconds since this stretch of beach was hit by the last wave (the sea's crest
	// reaches the shoreline when its phase wraps)
	float lag = sin(x * 0.25) * 0.6;
	float cycle = (TIME + lag) / period;
	float s = fract(cycle) * period;
	float wave_no = floor(cycle);
	float reach = (1.25 + 0.45 * noise(vec2(x * 0.5, wave_no * 3.7))) * (0.85 + 0.15 * sin(x * 0.7 + wave_no));
	float rise = 1.0 - pow(1.0 - clamp(s / 1.3, 0.0, 1.0), 2.0);
	float fall = smoothstep(1.3, 4.6, s);
	float front = reach * rise * (1.0 - fall) - 0.25 * fall;
	front += (noise(vec2(x * 3.0, wave_no)) - 0.5) * 0.12;
	vec4 out_col = vec4(0.0);
	if (up < front) {
		float thin = 1.0 - smoothstep(front - 0.7, front, up);
		// clear and thin at the front, deeper turquoise back toward the sea
		out_col = vec4(mix(water, water * 0.85 + vec3(0.0, 0.05, 0.08), smoothstep(0.0, -0.15, up)), mix(0.35, 0.8, 1.0 - thin * 0.75));
		float lace = noise(vec2(x * 6.0, up * 6.0 - s * 2.0));
		float line = (1.0 - smoothstep(0.04, 0.16 + 0.12 * (1.0 - fall), front - up)) * (1.0 - smoothstep(0.6, 1.0, fall));
		float bubbles = smoothstep(0.62, 0.7, lace) * (1.0 - smoothstep(0.0, 0.5, front - up));
		out_col = mix(out_col, vec4(foam, 0.95), clamp(line + bubbles, 0.0, 1.0));
	} else if (up < reach) {
		// sand the water has just left stays dark until it dries
		float dry = smoothstep(1.3, period * 0.95, s);
		out_col = vec4(wet, 0.45 * (1.0 - dry));
	}
	if (out_col.a <= 0.001) {
		discard;
	}
	ALBEDO = out_col.rgb;
	ALPHA = out_col.a;
}
