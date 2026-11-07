shader_type spatial;
// Water dripping off an edge: each instance starts at its edge point and falls
// with gravity once per period. INSTANCE_CUSTOM = (phase, period, drop height, -).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform;

uniform vec3 tint : source_color = vec3(0.75, 0.85, 1.0);
uniform float strength = 0.75;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float period = INSTANCE_CUSTOM.y;
	float t = fract(TIME / period + INSTANCE_CUSTOM.x) * period;
	float fall_time = sqrt(2.0 * INSTANCE_CUSTOM.z / 9.8);
	float swell = 0.35;
	vec3 p = origin;
	float len = 0.035;
	if (t < swell) {
		// the drop gathers on the edge before letting go
		len = 0.02 + 0.03 * (t / swell);
	} else {
		float f = t - swell;
		p.y -= 4.9 * f * f;
		len = 0.05 + 9.8 * f * 0.035;
	}
	vec3 to_cam = CAMERA_POSITION_WORLD - p;
	vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), to_cam));
	float w = max(0.018, length(to_cam) * 0.0016);
	vec3 wp = p + side * VERTEX.x * w + vec3(0.0, (VERTEX.y - 0.5) * len, 0.0);
	bool hidden = t > swell + fall_time;
	VERTEX = hidden ? vec3(0.0) : (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
}

void fragment() {
	ALBEDO = tint;
	ALPHA = strength * mix(0.4, 1.0, UV.y);
}
