shader_type spatial;
render_mode unshaded, cull_disabled;
// A patch cut from the author's painting, laid on a face in world space (for the parts of the school
// the camera walks into, which no picture shows from there): texel = (along, down) from `origin`
// times `density`, repeated. The face's direction picks the plane: floors/ceilings use x and z,
// walls facing along z use x and y, walls facing along x use z and y. Read sharp-bilinear like
// projected_paint.gdshader, so it stays pixel art at any distance. A light falloff from the
// fluorescent lamps, stepped (pixel-art banding), keeps the painted lighting's mood.

uniform sampler2D tile : source_color, filter_linear, repeat_enable;
uniform float density = 50.0;              // texels per metre
uniform vec2 origin = vec2(0.0);           // world (along, up) of the patch's top-left corner
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 lamps[8];
uniform int lamp_count = 0;
uniform float lamp_light = 0.3;
uniform float ambient = 0.78;              // the patches carry the painting's own light already
uniform float fade = 1.0;

const float BAYER[16] = {0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0};

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	ivec2 sp = ivec2(mod(floor(FRAGCOORD.xy), 4.0));
	float bayer = BAYER[sp.y * 4 + sp.x] / 16.0;
	if (fade < 1.0 && bayer >= fade) {
		discard;
	}
	vec3 n = abs(normalize(world_normal));
	vec2 uv;
	if (n.y > n.x && n.y > n.z) {
		uv = vec2(world_pos.x - origin.x, world_pos.z - origin.y);
	} else if (n.x > n.z) {
		uv = vec2(world_pos.z - origin.x, origin.y - world_pos.y);
	} else {
		uv = vec2(world_pos.x - origin.x, origin.y - world_pos.y);
	}
	vec2 px = uv * density;
	vec2 seam = floor(px + 0.5);
	px = seam + clamp((px - seam) / max(fwidth(px), vec2(1e-4)), -0.5, 0.5);
	vec3 c = texture(tile, px / vec2(textureSize(tile, 0))).rgb;
	float light = ambient;
	for (int i = 0; i < lamp_count; i++) {
		vec3 d = lamps[i] - world_pos;
		light += lamp_light / (1.0 + dot(d, d) * 0.35);
	}
	light = floor(light * 8.0 + bayer) / 8.0;
	ALBEDO = c * tint * light;
}
