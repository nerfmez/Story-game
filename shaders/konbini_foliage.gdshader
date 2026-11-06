shader_type spatial;
// Anime foliage (scripts/konbini_foliage.gd). A crown is a few clump blobs covered in
// leaf cards: small quads that always face the camera and are cut into a scalloped
// leaf-cluster shape, so the silhouette is a bumpy painted edge, not a sphere.
// Lighting ignores the real geometry: every normal points out from its clump centre
// blended with the crown centre ("spherized" normals), so the whole crown takes one
// big, soft-edged light / shadow split the way a background painter blocks a tree,
// in three flat tones with a warm light and a cool blue-green shadow. Noise wobbles
// the band edges like brush strokes; the side away from the sun glows a little where
// light comes through the leaves. No ink line: card edges get a darker band of the
// same hue instead, as in painted anime backgrounds.
//   CUSTOM0.xyz  clump centre (world)   CUSTOM0.w  card size (0 = clump body)
//   CUSTOM1.xyz  crown centre (world)   CUSTOM1.w  random seed
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform vec3 sun_dir = vec3(0.45, 0.72, 0.53);     // toward the sun
uniform vec3 light_col : source_color = vec3(0.62, 0.8, 0.38);
uniform vec3 mid_col : source_color = vec3(0.3, 0.58, 0.36);
uniform vec3 shadow_col : source_color = vec3(0.13, 0.32, 0.33);
uniform vec3 glow_col : source_color = vec3(0.78, 0.9, 0.42);
uniform float clump_mix = 0.55;    // 0 = one sphere for the whole crown, 1 = each clump its own
uniform float wind = 1.0;
uniform float brightness = 1.0;

varying vec3 n_sphere;
varying vec3 world_pos;
varying float card;
varying float seed;
varying vec2 corner;
varying float low;   // how far below the crown centre (the underside is in its own shade)

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
	vec3 clump = CUSTOM0.xyz;
	vec3 crown = CUSTOM1.xyz;
	card = CUSTOM0.w;
	seed = CUSTOM1.w;
	corner = UV * 2.0 - 1.0;
	vec3 p = VERTEX;
	// a slow sway, more toward the top and the outside of the crown
	float reach = max(p.y - crown.y + 1.5, 0.0) * 0.25 + length((p - crown).xz) * 0.15;
	float t = TIME * 1.1 + crown.x * 0.7 + crown.z * 0.4;
	p.x += (sin(t) * 0.035 + sin(t * 2.3 + p.y * 2.0) * 0.012) * reach * wind;
	p.z += sin(t * 0.8 + 1.3) * 0.02 * reach * wind;
	n_sphere = normalize(mix(normalize(p - crown + vec3(0.0, 0.25, 0.0)), normalize(p - clump), clump_mix));
	if (card > 0.0) {
		// leaf card: spread the four corners in the camera plane, turned by a random angle
		float a = seed * 6.2831 + hash1(clump.xz + p.xy) * 6.2831;
		vec2 c = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * corner;
		vec3 right = INV_VIEW_MATRIX[0].xyz;
		vec3 up = INV_VIEW_MATRIX[1].xyz;
		p += (right * c.x + up * c.y) * card;
	}
	low = crown.y - p.y;
	world_pos = p;
	VERTEX = p;
}

void fragment() {
	if (card > 0.0) {
		// a cluster of five or six rounded leaf tips, cut out of the quad
		float r = length(corner);
		float ang = atan(corner.y, corner.x);
		float lobes = 5.0 + floor(seed * 2.0);
		float edge = 0.78 + 0.16 * cos(ang * lobes + seed * 20.0);
		if (r > edge) {
			discard;
		}
	}
	// spherized lighting in three flat tones, band edges wobbled like brush work
	float l = dot(n_sphere, normalize(sun_dir));
	l += (noise2(world_pos.xz * 2.2 + world_pos.y * 1.7) - 0.5) * 0.35;
	l -= clamp(low, 0.0, 2.0) * 0.28;   // the underside of the crown sits in shade
	vec3 col = l > 0.42 ? light_col : (l > 0.0 ? mid_col : shadow_col);
	// each leaf cluster a touch lighter or darker, so the masses read as many clusters
	if (card > 0.0) {
		col *= 0.95 + 0.08 * fract(seed * 7.13);
	}
	// light through the leaves on the rim of the side away from the sun
	vec3 v = normalize(CAMERA_POSITION_WORLD - world_pos);
	float rim = pow(1.0 - abs(dot(n_sphere, v)), 3.0);
	float back = smoothstep(0.0, 0.6, dot(-v, normalize(sun_dir)));
	col = mix(col, glow_col, step(0.55, rim * (0.35 + back)) * 0.6);
	// a darker band of the same hue along the cut edge of each card
	if (card > 0.0) {
		float r = length(corner);
		float ang = atan(corner.y, corner.x);
		float edge = 0.78 + 0.16 * cos(ang * (5.0 + floor(seed * 2.0)) + seed * 20.0);
		col *= mix(1.0, l > 0.42 ? 0.93 : 0.74, smoothstep(edge - 0.12, edge - 0.04, r));
	}
	ALBEDO = col * brightness;
}
