// Shared by the beach shaders (konbini_sea, konbini_swash) and mirrored in
// scripts/konbini_beach.gd: the waterline, the shape of the sand under and above the
// water, and the timing of the swash that runs up the beach after each wave.

const float SAND_Y = 0.12;     // the dry beach
const float SEA_Y = 0.08;      // still-water level
const float PERIOD = 7.0;      // seconds between waves
const float SPEED = 1.5;       // how fast a crest travels toward the beach (m/s)

float beach_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float beach_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(beach_hash(i), beach_hash(i + vec2(1.0, 0.0)), f.x), mix(beach_hash(i + vec2(0.0, 1.0)), beach_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float shore(float x) {
	return 3.0 + 0.45 * sin(x * 0.35 + 0.6) + 0.25 * sin(x * 0.93 + 2.0);
}

// Height of the sand at a distance u seaward of the waterline (negative = up the beach):
// flat dry beach, a gentle slope down to the water, then a steeper shelf under the sea.
float ground_u(float u) {
	if (u < -1.0) {
		return SAND_Y;
	}
	if (u < 0.0) {
		return SEA_Y - u * 0.04;
	}
	if (u < 2.0) {
		return SEA_Y - u * 0.1;
	}
	return max(SEA_Y - 0.2 - (u - 2.0) * 0.03, -0.23);
}

// A small offset in the wave timing along the beach, so a wave does not reach every
// point at once. Kept small and wiggly: a large smooth offset reads as the breaker
// sliding sideways along the shore instead of rolling in toward it.
float wave_lag(float x) {
	return 0.12 * sin(x * 0.9 + 1.0) + 0.08 * sin(x * 0.37 + 2.0);
}

// Where the swash front is (metres up the beach from the waterline, negative while the
// backwash draws the water below it) and how many seconds since this wave broke.
float swash_front(float x, float t, out float s, out float reach, out float fall) {
	float lag = wave_lag(x);
	float cycle = (t + lag) / PERIOD;
	s = fract(cycle) * PERIOD;
	float wave_no = floor(cycle);
	reach = (0.6 + 0.3 * beach_noise(vec2(x * 0.5, wave_no * 3.7))) * (0.85 + 0.15 * sin(x * 0.7 + wave_no));
	float rise = 1.0 - pow(1.0 - clamp(s / 1.4, 0.0, 1.0), 2.0);
	fall = smoothstep(1.4, 4.8, s);
	float front = reach * rise * (1.0 - fall) - 0.3 * fall;
	return front + (beach_noise(vec2(x * 3.0, wave_no)) - 0.5) * 0.1;
}
