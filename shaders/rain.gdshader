shader_type canvas_item;
// Falling rain over the whole screen, in whole game pixels (pixel-art streaks).
// Two layers: far (short, faint, slower) and near (longer, brighter, faster).
// Each column of cells holds one drop at a random x, falling and wrapping around.

uniform vec2 screen_size = vec2(640.0, 360.0);
uniform vec4 colour : source_color = vec4(0.78, 0.84, 0.96, 1.0);
uniform float slant = 0.22;          // pixels sideways per pixel down
uniform float wind = 0.0;            // extra sideways drift (pixels per second)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 1 where a drop of this layer covers pixel p, else 0
float drops(vec2 p, vec2 cell, float len, float speed, float density, float seed) {
	p.x += p.y * slant + TIME * wind;
	vec2 c = floor(vec2(p.x / cell.x, 0.0));
	float h = hash(c + seed);
	if (h > density) {
		return 0.0;
	}
	float x = floor(hash(c + seed + 7.0) * cell.x);
	float local_x = p.x - c.x * cell.x;
	if (abs(local_x - x) > 0.5) {
		return 0.0;
	}
	float period = cell.y * (0.8 + hash(c + seed + 3.0) * 0.6);
	float y = mod(p.y - TIME * speed * (0.85 + h * 0.3) + hash(c + seed + 5.0) * period, period);
	return step(y, len);
}

void fragment() {
	vec2 p = floor(SCREEN_UV * screen_size);
	float far = drops(p, vec2(3.0, 90.0), 4.0, 210.0, 0.55, 1.0);
	float near = drops(p, vec2(7.0, 150.0), 9.0, 380.0, 0.5, 11.0);
	float a = max(far * 0.22, near * 0.4);
	COLOR = vec4(colour.rgb, a * colour.a);
}
