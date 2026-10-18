shader_type canvas_item;
// Leaves rustling in a light breeze, for the railway layer. Nothing is displaced
// (moving pixels made the trees ripple like water): instead single leaf pixels
// (2x2 art pixels) catch the light for a moment, more often where a gust is passing,
// and gusts travel slowly along the tree line. Only lit foliage reacts; the viaduct,
// rails and trunks stay as they are. Sharp-bilinear sampling (needs linear filtering)
// keeps the slow layer gliding.

uniform float amount = 0.16;       // how much a rustling leaf brightens
uniform float density = 0.06;      // share of leaf pixels lit at a gust's peak
uniform float gust_speed = 0.5;
uniform float art_pixel = 2.0;     // the layer's chunky pixel size, in texels

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 texel = UV * size;
	vec2 seam = floor(texel + 0.5);
	vec2 per_px = max(fwidth(texel), vec2(1e-4));
	vec4 c = texture(TEXTURE, (seam + clamp((texel - seam) / per_px, -0.5, 0.5)) / size);
	bool leaf = c.a > 0.5 && c.g > c.r && c.g >= c.b - 0.04 && c.g > 0.25;
	if (leaf) {
		vec2 cell = floor(texel / art_pixel);
		float n = hash(cell);
		float gust = 0.5 + 0.5 * sin(TIME * gust_speed - texel.x * 0.012);
		// each leaf pixel blinks on its own slow clock; gusts make more of them blink
		float phase = fract(TIME * (0.35 + 0.5 * n) + n * 7.0);
		float on = step(1.0 - density * gust * gust, hash(cell + floor(TIME * (0.35 + 0.5 * n) + n * 7.0)))
			* step(phase, 0.5);
		c.rgb += on * amount * vec3(0.55, 0.75, 0.35);
	}
	COLOR = c * modulate;
}
