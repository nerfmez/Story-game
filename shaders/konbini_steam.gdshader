shader_type spatial;
// Soft rising wisps (oden pot, coffee, the manhole). The quad faces the camera.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.97, 0.92);
uniform float strength = 0.35;
uniform float speed = 0.35;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float rise = 1.0 - UV.y;
	vec2 q = vec2(UV.x * 2.5 + sin(rise * 4.0 + TIME * 0.8) * 0.25, rise * 2.2 - TIME * speed);
	float n = noise(q * 2.0) * 0.65 + noise(q * 5.0) * 0.35;
	float column = 1.0 - smoothstep(0.15, 0.5, abs(UV.x - 0.5));
	float fade = smoothstep(0.0, 0.2, rise) * (1.0 - smoothstep(0.55, 1.0, rise));
	ALBEDO = tint;
	ALPHA = smoothstep(0.45, 0.75, n) * column * fade * strength;
}
