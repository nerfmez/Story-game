shader_type spatial;
// Specks of dust and pollen drifting in the sunlight (scripts/konbini_summer.gd): small
// soft dots, one per MultiMesh instance, that wander slowly round where they were put
// and brighten and fade on their own rhythm (phase in INSTANCE_CUSTOM.x).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.96, 0.82);
uniform float size = 0.05;

varying float glow;
varying vec2 corner;

void vertex() {
	float ph = INSTANCE_CUSTOM.x * 6.2831;
	vec3 home = MODEL_MATRIX[3].xyz;
	float t = TIME * (0.18 + INSTANCE_CUSTOM.y * 0.12);
	vec3 drift = vec3(sin(t + ph) * 0.6 + sin(t * 2.3 + ph * 1.7) * 0.15, sin(t * 0.7 + ph * 2.1) * 0.35, cos(t * 0.8 + ph) * 0.5);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 wp = home + drift + (right * VERTEX.x + up * VERTEX.y) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
	glow = pow(0.5 + 0.5 * sin(TIME * (0.6 + INSTANCE_CUSTOM.z) + ph * 3.0), 3.0);
	corner = VERTEX.xy * 2.0;
}

void fragment() {
	float d = length(corner);
	if (d > 1.0) {
		discard;
	}
	ALBEDO = tint * (1.0 - d * d) * glow * 0.55;
}
