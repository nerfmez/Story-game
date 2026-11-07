shader_type spatial;
// Little impact rings where drops hit the ground. Flat quads in a MultiMesh,
// INSTANCE_CUSTOM.xy = (phase, period in seconds).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec3 tint : source_color = vec3(0.62, 0.72, 0.95);
uniform float strength = 0.55;
uniform float life = 0.3;

varying float age;

void vertex() {
	age = fract(TIME / INSTANCE_CUSTOM.y + INSTANCE_CUSTOM.x) * INSTANCE_CUSTOM.y;
}

void fragment() {
	float t = age / life;
	if (t > 1.0) {
		discard;
	}
	float d = length(UV - 0.5) * 2.0;
	float ring = 1.0 - smoothstep(0.0, 0.09, abs(d - t));
	float hit = (1.0 - smoothstep(0.05, 0.22, d)) * (1.0 - smoothstep(0.0, 0.3, t));
	ALBEDO = tint;
	ALPHA = max(ring * (1.0 - t), hit) * strength;
}
