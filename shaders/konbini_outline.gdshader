shader_type spatial;
// Inverted-hull ink lines for konbini_toon. CUSTOM0.xyz holds the direction a
// vertex is pushed (box corners, cylinder rims), CUSTOM0.w the line weight.
// The push grows with camera distance so lines keep about the same width on screen.
render_mode unshaded, cull_front, depth_draw_opaque;

uniform float width = 0.0011;
uniform vec3 ink : source_color = vec3(0.06, 0.06, 0.14);
uniform float tint = 0.35;

varying vec3 base_color;

void vertex() {
	base_color = COLOR.rgb;
	if (CUSTOM0.w < 0.001) {
		VERTEX = vec3(0.0);
	} else {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float d = clamp(length(CAMERA_POSITION_WORLD - wp), 1.5, 45.0);
		VERTEX += CUSTOM0.xyz * width * d * CUSTOM0.w;
	}
}

void fragment() {
	ALBEDO = mix(ink, base_color * 0.28, tint);
}
