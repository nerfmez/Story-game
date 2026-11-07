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
uniform vec3 high_col : source_color = vec3(0.78, 0.9, 0.48);
uniform vec3 light_col : source_color = vec3(0.62, 0.8, 0.38);
uniform vec3 mid_col : source_color = vec3(0.3, 0.58, 0.36);
uniform vec3 shadow_col : source_color = vec3(0.13, 0.32, 0.33);
uniform vec3 glow_col : source_color = vec3(0.78, 0.9, 0.42);
uniform float clump_mix = 0.55;    // 0 = one sphere for the whole crown, 1 = each clump its own
uniform float wind = 1.0;
uniform float brightness = 1.0;

varying vec3 n_sphere;
varying vec3 n_clump;
varying vec3 world_pos;
varying float card;
varying float seed;
varying vec2 corner;

#include "res://shaders/konbini_clouds.gdshaderinc"

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash1(i), hash1(i + vec2(1.0, 0.0)), f.x), mix(hash1(i + vec2(0.0, 1.0)), hash1(i + vec2(1.0, 1.0)), f.x), f.y);
}

// The outline of a leaf card: a ragged clump edge that differs card to card. The
// radius at each angle is a sum of two bumps of random count, size and phase, the
// card is squashed by a random amount, and part of it may be bitten away, so no two
// cards share a shape and many are not a whole closed blob.
float card_edge(vec2 q, float sd) {
	float aspect = 0.7 + 0.3 * fract(sd * 3.31);
	q.y /= aspect;
	float ang = atan(q.y, q.x);
	float k1 = 3.0 + floor(fract(sd * 5.17) * 4.0);
	float k2 = 7.0 + floor(fract(sd * 8.73) * 5.0);
	float a1 = 0.06 + 0.12 * fract(sd * 2.71);
	float a2 = 0.03 + 0.06 * fract(sd * 6.11);
	float e = 0.72 + a1 * cos(ang * k1 + sd * 31.0) + a2 * cos(ang * k2 + sd * 17.0);
	// some cards lose a side, so only a few bumps of them show at the crown edge
	float bite = step(0.55, fract(sd * 4.49));
	vec2 bd = vec2(cos(sd * 41.0), sin(sd * 41.0));
	e = mix(e, min(e, 0.35 + dot(normalize(q + 1e-4), bd) * -0.9 + 0.6), bite);
	return e - length(q);   // > 0 inside
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
	n_clump = normalize(p - clump);
	n_sphere = normalize(mix(normalize(p - crown + vec3(0.0, 0.25, 0.0)), normalize(p - clump), clump_mix));
	if (card > 0.0) {
		// leaf card: spread the four corners in the camera plane, turned by a random angle
		// the turn comes from the card's own seed only: hashing its (wind-moved) position
		// re-rolled the angle every frame and made the leaves jitter
		float a = seed * 6.2831 * 7.0;
		vec2 c = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * corner;
		vec3 right = INV_VIEW_MATRIX[0].xyz;
		vec3 up = INV_VIEW_MATRIX[1].xyz;
		p += (right * c.x + up * c.y) * card;
	}
	world_pos = p;
	VERTEX = p;
}

void fragment() {
	if (card > 0.0) {
		if (card_edge(corner, seed) < 0.0) {
			discard;
		}
	}
	// spherized lighting in three flat tones, band edges wobbled like brush work
	float l = dot(n_sphere, normalize(sun_dir));
	l -= cloud_cover(world_pos, TIME) * 0.75;   // a cloud shadow passing over the tree
	l += (noise2(world_pos.xz * 2.2 + world_pos.y * 1.7) - 0.5) * 0.35;
	vec3 col = l > 0.32 ? light_col : (l > -0.12 ? mid_col : shadow_col);
	// on the lit side, each clump gets its own brighter cap facing the sun, so the lit
	// mass reads as several rounded clumps instead of one flat shape
	float lc = dot(n_clump, normalize(sun_dir)) + (noise2(world_pos.xz * 3.1 - world_pos.y * 2.3) - 0.5) * 0.3;
	if (l > 0.32 && lc > 0.58) {
		col = high_col;
	}
	// light through the leaves on the rim of the side away from the sun
	vec3 v = normalize(CAMERA_POSITION_WORLD - world_pos);
	float rim = pow(1.0 - abs(dot(n_sphere, v)), 3.0);
	float back = smoothstep(0.0, 0.6, dot(-v, normalize(sun_dir)));
	col = mix(col, glow_col, step(0.55, rim * (0.35 + back)) * 0.6);
	// a darker band of the same hue along the cut edge of each card
	if (card > 0.0) {
		col *= mix(1.0, 0.72, (1.0 - smoothstep(0.03, 0.09, card_edge(corner, seed))) * step(l, 0.32));
	}
	ALBEDO = col * brightness;
}
