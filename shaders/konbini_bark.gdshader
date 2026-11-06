shader_type spatial;
// Anime bark for the trees of scripts/konbini_foliage.gd. Trunks and limbs are smooth
// swept tubes; this paints them like a background artist would: a warm lit side, a mid
// tone and a cool purple-brown shadow side from the sun direction, with the band edges
// broken by long vertical strokes of bark, and the whole trunk pushed one tone darker
// as it rises into the shade of the crown (CUSTOM1.x, 0 at the foot, 1 inside).
// Ink outline: konbini_outline as next pass (CUSTOM0 = push direction and weight).
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform vec3 sun_dir = vec3(0.45, 0.72, 0.53);
uniform vec3 light_col : source_color = vec3(0.72, 0.55, 0.4);
uniform vec3 mid_col : source_color = vec3(0.47, 0.34, 0.28);
uniform vec3 shadow_col : source_color = vec3(0.27, 0.2, 0.25);
uniform vec3 stroke_col : source_color = vec3(0.2, 0.14, 0.17);
uniform float brightness = 1.0;

varying vec3 n_world;
varying vec3 world_pos;
varying float shade;

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash1(i), hash1(i + vec2(1.0, 0.0)), f.x), mix(hash1(i + vec2(0.0, 1.0)), hash1(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	n_world = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	shade = CUSTOM1.x;
}

void fragment() {
	vec3 n = normalize(n_world);
	// bark runs along the trunk: stretch the noise vertically
	float around = atan(n.z, n.x) * 1.6;
	float streak = noise2(vec2(around * 1.4 + world_pos.x * 2.0, world_pos.y * 0.8));
	// under the crown the trunk is in its shade, with a few dapples of light coming through
	float dapple = noise2(vec2(around * 1.2 + world_pos.z, world_pos.y * 2.2)) - 0.5;
	float in_shade = smoothstep(0.55, 0.85, shade + dapple * 0.45);
	float l = dot(n, normalize(sun_dir)) + (streak - 0.5) * 0.25 - in_shade * 0.8;
	vec3 col = l > 0.25 ? light_col : (l > -0.25 ? mid_col : shadow_col);
	// a few long dark cracks of bark, only out of the full light
	float crack = noise2(vec2(around * 5.0 + world_pos.z * 4.0, world_pos.y * 0.9 + around));
	if (l < 0.25 && abs(crack - 0.5) < 0.035) {
		col = mix(col, stroke_col, 0.7);
	}
	ALBEDO = col * brightness;
}
