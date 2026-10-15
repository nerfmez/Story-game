shader_type canvas_item;
render_mode blend_add;
// Additive light shafts that slowly breathe, each shaft at its own pace.

uniform float speed = 0.5;
uniform float depth = 0.35;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float s = 1.0 - depth + depth * sin(TIME * speed + UV.x * 37.0);
	COLOR = vec4(c.rgb, c.a * s);
}
