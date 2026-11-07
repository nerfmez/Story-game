shader_type sky;
// Backdrop behind the diorama: a dark rainy-night gradient with a faint city glow low down.

uniform vec3 top_color : source_color = vec3(0.025, 0.03, 0.08);
uniform vec3 horizon_color : source_color = vec3(0.1, 0.09, 0.2);
uniform vec3 glow_color : source_color = vec3(0.2, 0.13, 0.26);
uniform float day = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void sky() {
	float y = EYEDIR.y;
	vec3 col = mix(horizon_color, top_color, smoothstep(-0.25, 0.7, y));
	col += glow_color * exp(-abs(y + 0.05) * 9.0) * 0.6;
	if (day > 0.0) {
		// summer sky: deep blue overhead, pale at the horizon, flat-shaded cumulus drifting
		col = mix(vec3(0.78, 0.9, 0.98), vec3(0.28, 0.58, 0.92), smoothstep(-0.1, 0.6, y));
		vec2 q = EYEDIR.xz / max(EYEDIR.y + 0.25, 0.05) * 1.4 + vec2(TIME * 0.01, 0.0);
		float c = noise(q) * 0.6 + noise(q * 2.3) * 0.3 + noise(q * 5.1) * 0.1;
		float cloud = smoothstep(0.55, 0.6, c) * smoothstep(-0.05, 0.15, y);
		float shade = smoothstep(0.62, 0.75, c);
		col = mix(col, mix(vec3(1.0), vec3(0.82, 0.86, 0.95), 1.0 - shade), cloud);
	}
	COLOR = col;
}
