// Shadows of fair-weather clouds drifting over a sunny scene (scripts/konbini_summer.gd).
// Big soft-edged blobs a few metres to ten metres across slide slowly over everything
// lit by the sun: the toon shader darkens the sun's light under them, and the painted
// shaders (sea, foliage, bark, swash) step down a tone. The global uniform
// cloud_shadow (0 or 1, project setting) is turned on only for clear daytime scenes.

global uniform float cloud_shadow;

float cloud_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float cloud_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(cloud_hash(i), cloud_hash(i + vec2(1.0, 0.0)), f.x), mix(cloud_hash(i + vec2(0.0, 1.0)), cloud_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// 1 under a cloud's shadow, 0 in the sun, soft at the edge. t is TIME.
float cloud_cover(vec3 wp, float t) {
	if (cloud_shadow <= 0.0) {
		return 0.0;
	}
	// shadows fall along the sun, so shift by height a little; drift with the wind
	vec2 p = (wp.xz + wp.y * vec2(0.6, 0.4)) * 0.075 + t * vec2(0.032, 0.011);
	float n = cloud_noise(p) * 0.68 + cloud_noise(p * 2.3 + 5.2) * 0.32;
	return smoothstep(0.56, 0.64, n) * cloud_shadow;
}
