shader_type spatial;
// Painted backdrop flats behind a diorama (scripts/konbini_backdrop.gd), following how
// model railway backscenes, anime background painters and stylized games fake distance:
//  - few layers, each a simple silhouette in a narrow range of values (value grouping)
//  - atmospheric perspective: the farther the layer, the lower its contrast, until lit
//    and shadowed faces nearly meet; shadows turn toward the blue of the sky, and the
//    haze is a little brighter and warmer than the sky, not the same colour
//  - layered valley mist: every range fades into a bright band of haze at its foot, so
//    the layers separate cleanly and no board edge is seen against the next
//  - no ink lines on far things; the skyline is the drawing
//  - painted, not printed: poster-colour brush strokes that follow the slopes, dry-brush
//    edges where the tones meet, a feathered skyline, mist laid in dabs, and a fine
//    paper grain over everything (as anime backgrounds are painted)
// The back of every board is plain plywood.
//   kind 1 a range (mountains or wooded hills), 4 a summer cloud
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

uniform int kind = 1;
uniform vec2 size = vec2(38.0, 4.0);     // width and height of the board in metres
uniform float haze = 0.0;                // 0 near, 1 lost in the sky
uniform float seed = 0.0;
uniform float roughness = 0.0;           // 0 smooth mountain ridges, 1 tree-line bumps
uniform float feature = 6.0;             // typical width of a peak or hill, metres
uniform vec3 sun_dir = vec3(0.45, 0.72, 0.53);   // toward the sun, world space
uniform vec3 lit : source_color = vec3(0.5, 0.6, 0.75);
uniform vec3 shade : source_color = vec3(0.36, 0.45, 0.66);
uniform vec3 sky : source_color = vec3(0.78, 0.89, 0.98);
uniform vec3 mist : source_color = vec3(0.9, 0.94, 0.97);

float h1(float x) {
	return fract(sin(x * 127.1 + seed * 31.7) * 43758.5453);
}

float h2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.3) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), f.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Brush strokes: noise stretched along a direction, so it reads as short strokes of
// paint laid that way. Returns 0..1.
float strokes(vec2 p, vec2 dir, float len, float width) {
	vec2 d = normalize(dir);
	vec2 q = vec2(dot(p, d) / len, dot(p, vec2(-d.y, d.x)) / width);
	return vnoise(q) * 0.65 + vnoise(q * 2.1 + 5.3) * 0.35;
}

// paper grain: fine, slightly blotchy
float grain(vec2 p) {
	return vnoise(p * 38.0) * 0.6 + vnoise(p * 9.0 + 3.0) * 0.4;
}

// the skyline: overlapping rounded peaks of varied width and height, plus small notches
// (or, for wooded hills, a soft scallop of tree crowns)
float skyline(float x) {
	float H = size.y;
	float h = H * 0.15;
	float n = ceil(size.x / feature) + 2.0;
	for (int k = 0; k < 16; k++) {
		float a = float(k);
		if (a >= n) {
			break;
		}
		float px = (a - 0.5) * feature + (h1(a) - 0.5) * feature * 0.8;
		float ph = H * (0.45 + 0.5 * h1(a + 4.0));
		float w = feature * (0.45 + 0.4 * h1(a + 8.0));
		float d = (x - px) / w;
		h = max(h, ph * (1.0 - d * d * (0.6 + 0.4 * smoothstep(0.0, 1.0, abs(d)))));
	}
	h += (vnoise(vec2(x / feature * 3.0, 0.0)) - 0.5) * H * 0.08;
	float crowns = abs(sin(x * 2.6 + vnoise(vec2(x * 0.7, 2.0)) * 3.0));
	return h + roughness * (crowns * 0.12 - 0.06) * min(H, 3.0);
}

vec4 range_color(vec2 p) {
	float e = 0.15;
	// a feathered skyline: the brush leaves a slightly ragged, uneven edge
	float rag = (vnoise(vec2(p.x * 9.0, 1.0)) - 0.5) * 0.06 + (vnoise(vec2(p.x * 26.0, 4.0)) - 0.5) * 0.025;
	float h = skyline(p.x) + rag;
	if (p.y > h) {
		return vec4(0.0);
	}
	float dh = (skyline(p.x + e) - skyline(p.x - e)) / (2.0 * e);
	// the face under the skyline leans like the ridge above it; folds and gullies
	// break it up lower down
	float fold = (vnoise(vec2(p.x / feature * 4.0, p.y * 0.35)) - 0.5) * 1.4 * (1.0 - roughness * 0.6);
	vec3 n = normalize(vec3(-dh * 1.1 + fold, 0.5, 1.0));
	// strokes run down the slope the way a painter drags the brush, and break the line
	// between light and shade into a dry-brush edge
	vec2 down = normalize(vec2(sign(dh + 1e-4) * 0.6, -1.0));
	float st = strokes(p, down, 0.55, 0.08);
	float l = dot(n, normalize(sun_dir)) + (st - 0.5) * 0.32;
	vec3 c = l > 0.42 ? lit : shade;
	// paint is never one flat colour: each stroke a touch lighter or darker, a little warmer
	// or cooler
	float v = strokes(p + 7.0, down, 0.4, 0.06) - 0.5;
	c *= 1.0 + v * 0.1;
	c += vec3(0.02, 0.0, -0.02) * v;
	// atmospheric perspective: contrast collapses and both tones go toward the sky
	c = mix(c, sky, haze);
	// valley mist laid in horizontal dabs, not a smooth gradient
	float dab = strokes(p, vec2(1.0, 0.04), 0.9, 0.12);
	float m = 1.0 - smoothstep(0.0, size.y * 0.32 + 0.3, p.y + (vnoise(vec2(p.x * 0.35, 9.0)) - 0.5) * 0.5 + (dab - 0.5) * 0.45);
	m = floor(m * 3.0 + dab * 0.8) / 3.0;
	c = mix(c, mist, clamp(m, 0.0, 1.0) * (0.55 + 0.3 * haze));
	// a thin lighter rim along the lit parts of the skyline, as painters catch the sun
	if (h - p.y < 0.05 + v * 0.03 && l > 0.42) {
		c = mix(c, mist, 0.35);
	}
	return vec4(c, 1.0);
}

// a towering summer cloud: puffs on a flat base, bright on top, blue-grey underneath
vec4 cloud_color(vec2 p) {
	float W = size.x;
	float H = size.y;
	float best = -1e3;
	vec3 n = vec3(0.0, 0.0, 1.0);
	for (int i = 0; i < 26; i++) {
		float a = float(i);
		vec2 c;
		float r;
		if (i < 9) {
			c = vec2(W * 0.12 + W * 0.76 * (a / 8.0) + (h1(a) - 0.5) * W * 0.05, H * 0.2 + h1(a + 3.0) * H * 0.05);
			r = H * (0.12 + h1(a + 7.0) * 0.05);
		} else {
			float t = (a - 9.0) / 16.0;
			c = vec2(W * 0.5 + (h1(a) - 0.5) * W * 0.5 * (1.0 - t * 0.6), H * (0.28 + t * 0.58) + h1(a + 2.0) * H * 0.04);
			r = H * (0.16 - t * 0.07 + h1(a + 5.0) * 0.04);
		}
		vec2 d = (p - c) / r;
		float dd = dot(d, d);
		if (dd < 1.0) {
			float z = sqrt(1.0 - dd) * r + c.y * 0.3;
			if (z > best) {
				best = z;
				n = normalize(vec3(d, sqrt(1.0 - dd) * 1.3));
			}
		}
	}
	if (best <= -1e3 || p.y < H * 0.13) {
		return vec4(0.0);
	}
	// strokes curl round each puff, roughly across the light
	float st = strokes(p, vec2(n.y, -n.x) + vec2(0.01), 0.35, 0.07);
	float l = dot(n, normalize(sun_dir)) - smoothstep(H * 0.34, H * 0.13, p.y) * 0.7 + (st - 0.5) * 0.3;
	vec3 c = l > 0.5 ? vec3(1.0, 1.0, 0.98) : (l > 0.1 ? vec3(0.92, 0.95, 0.99) : vec3(0.74, 0.82, 0.94));
	c *= 1.0 + (st - 0.5) * 0.05;
	return vec4(mix(c, sky, haze), 1.0);
}

void fragment() {
	vec2 p = vec2(UV.x * size.x, (1.0 - UV.y) * size.y);   // metres from the bottom left
	if (!FRONT_FACING) {
		vec3 ply = vec3(0.66, 0.56, 0.44) * (0.92 + 0.08 * vnoise(vec2(p.x * 3.0, 0.0)));
		ALBEDO = p.y < 0.12 ? ply * 0.75 : ply;
	} else {
		vec4 c = kind == 4 ? cloud_color(p) : range_color(p);
		if (c.a < 0.5) {
			discard;
		}
		// paper grain under the paint
		ALBEDO = c.rgb * (0.965 + 0.06 * grain(p));
	}
}
