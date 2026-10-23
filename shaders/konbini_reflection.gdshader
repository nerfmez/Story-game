shader_type spatial;
// A light's smeared reflection on the wet ground. The quad starts under the light
// (UV.y = 0) and the script keeps it pointing at the camera, the way reflections
// on a rainy street stretch toward whoever is looking. peak is where along the
// strip the mirror image of the light falls; the smear is brightest there.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec3 color : source_color = vec3(1.0);
uniform float energy = 1.0;
uniform float sharpness = 2.0;
uniform float peak = 0.4;
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// the model ends at the edge of its base
	if (abs(world_pos.x) > 9.0 || abs(world_pos.z) > 9.0) {
		discard;
	}
	float u = UV.x - 0.5;
	float v = UV.y;
	float across = pow(clamp(1.0 - abs(u) * 2.0, 0.0, 1.0), sharpness);
	float along = v < peak ? smoothstep(0.0, peak, v) : 1.0 - smoothstep(peak, 1.0, v);
	// ripples break the smear into short sideways dashes that drift toward the viewer
	float row = v * 34.0 - TIME * 1.3 + seed * 0.37;
	float id = floor(row) + seed * 17.0;
	float f = fract(row);
	float shift = (hash(vec2(id, 1.0)) - 0.5) * 0.45;
	float half_width = 0.12 + 0.34 * hash(vec2(id, 2.0));
	float dash = smoothstep(0.0, 0.25, f) * (1.0 - smoothstep(0.55, 0.85, f)) * (1.0 - smoothstep(half_width * 0.6, half_width, abs(u - shift)));
	dash *= mix(0.35, 1.0, hash(vec2(id, 3.0)));
	float shimmer = 0.75 + 0.25 * noise(vec2(u * 5.0, v * 8.0 - TIME * 0.6));
	ALBEDO = color * energy;
	ALPHA = clamp(across * along * mix(0.2, 1.0, dash) * shimmer, 0.0, 1.0);
}
