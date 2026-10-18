shader_type canvas_item;
// Reflection of a sprite in a wet road: drawn upside down, with a gentle
// horizontal ripple, tinted to the sky and fading out away from the feet.

// ripple size in texels (not UV: with sprite sheets UV spans the whole sheet, so a UV
// amount grew with the frame count and dragged the reflection sideways)
uniform float wobble = 1.0;
uniform float speed = 2.5;
uniform vec4 tint : source_color = vec4(0.62, 0.56, 0.82, 0.7);
uniform float fade_length = 0.85;

void fragment() {
	float d = UV.y;  // 0 at the feet, 1 at the reflected head
	float ripple = round(sin(d * 70.0 + TIME * speed) * wobble * d);   // whole pixels
	vec2 uv = vec2(UV.x + ripple * TEXTURE_PIXEL_SIZE.x, 1.0 - d);
	vec4 c = texture(TEXTURE, uv);
	c.rgb *= tint.rgb;
	c.a *= tint.a * clamp(1.0 - d / fade_length, 0.0, 1.0);
	COLOR = c;
}
