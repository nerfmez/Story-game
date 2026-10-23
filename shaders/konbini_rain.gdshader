shader_type spatial;
// Rain streaks for a MultiMesh of quads. Each instance holds where its drop lands
// (transform origin) and INSTANCE_CUSTOM.xy = (phase, speed variation).
// Drops are hidden under roofs and brighten as they pass near the lamps.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform;

uniform float fall_height = 11.0;
uniform float speed = 10.0;
uniform float drop_length = 0.45;
uniform vec2 wind = vec2(0.9, 0.35);
uniform vec3 tint : source_color = vec3(0.5, 0.6, 0.82);
uniform float strength = 0.32;
uniform vec4 shelters[8];
uniform float shelter_top[8];
uniform vec4 lamps[10];
uniform vec4 lamp_colors[10];

varying float glow_mix;
varying vec3 glow;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float s = speed * (0.85 + INSTANCE_CUSTOM.y * 0.3);
	float y = mod(INSTANCE_CUSTOM.x * fall_height - TIME * s, fall_height);
	vec3 p = vec3(origin.x, origin.y + y, origin.z);
	p.xz -= wind * (y / s);
	bool hidden = false;
	for (int i = 0; i < 8; i++) {
		vec4 r = shelters[i];
		if (p.x > r.x && p.x < r.z && p.z > r.y && p.z < r.w && p.y < shelter_top[i]) {
			hidden = true;
		}
	}
	glow = vec3(0.0);
	for (int i = 0; i < 10; i++) {
		float k = clamp(1.0 - length(p - lamps[i].xyz) / max(lamps[i].w, 0.001), 0.0, 1.0);
		glow += lamp_colors[i].rgb * k * k;
	}
	vec3 dir = normalize(vec3(-wind.x, -s, -wind.y));
	vec3 to_cam = CAMERA_POSITION_WORLD - p;
	vec3 side = normalize(cross(dir, to_cam));
	float w = max(0.01, length(to_cam) * 0.0012);
	vec3 wp = p + side * VERTEX.x * w - dir * (VERTEX.y + 0.5) * drop_length;
	VERTEX = hidden ? vec3(0.0) : (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
}

void fragment() {
	float a = mix(0.15, 1.0, UV.y);
	ALBEDO = tint * strength + glow;
	ALPHA = a * clamp(strength + length(glow) * 0.5, 0.0, 1.0);
}
