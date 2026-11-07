shader_type spatial;
// Painted backdrop flats for the back of a diorama (scripts/konbini_backdrop.gd): thin
// cut-out boards standing one behind the other, like the scenery of a stage or a model
// railway backscene. They are painted the way the rest of the scene is lit, so they
// belong to it: every shape is made of round masses (cloud puffs, tree clumps, rock
// faces) with their own normals, lit by the same sun in the same flat cel tones as the
// trees (shaders/konbini_foliage.gdshader), with a darker band of the same hue where
// one mass overlaps another instead of black ink. The farther back a board stands,
// the more its colours fade toward the sky (haze), so boards a few tens of centimetres
// apart read as kilometres. The back of every board is plain plywood.
//   kind 1 far mountains, 2 wooded hills, 3 seaside town, 4 summer cloud
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

uniform int kind = 1;
uniform vec2 size = vec2(38.0, 4.0);     // width and height of the board in metres
uniform float haze = 0.0;                // 0 near, 1 lost in the sky
uniform float seed = 0.0;
uniform vec3 sun_dir = vec3(0.45, 0.72, 0.53);   // toward the sun, world space
uniform vec3 sky : source_color = vec3(0.8, 0.89, 0.97);

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

// four flat tones from a light value, as the trees use
vec3 tone(float l, vec3 high, vec3 lit, vec3 mid, vec3 dark) {
	return l > 0.62 ? high : (l > 0.3 ? lit : (l > -0.1 ? mid : dark));
}

vec3 hazed(vec3 c, float extra) {
	return mix(c, sky, clamp(haze + extra, 0.0, 1.0));
}

// --- a summer cloud: puffs stacked into a tower on a flat base ------------------------
vec4 cloud(vec2 p, out bool hit) {
	float W = size.x;
	float H = size.y;
	float best = -1e3;
	vec3 n = vec3(0.0, 0.0, 1.0);
	float rim = 1.0;
	for (int i = 0; i < 30; i++) {
		float a = float(i);
		vec2 c;
		float r;
		float lift;
		if (i < 10) {
			// the broad base
			c = vec2(W * 0.1 + W * 0.8 * (a / 9.0) + (h1(a) - 0.5) * W * 0.06, H * 0.2 + h1(a + 3.0) * H * 0.06);
			r = H * (0.12 + h1(a + 7.0) * 0.05);
			lift = 0.0;
		} else {
			// the tower, narrowing as it climbs
			float t = (a - 10.0) / 19.0;
			c = vec2(W * 0.5 + (h1(a) - 0.5) * W * 0.5 * (1.0 - t * 0.55), H * (0.28 + t * 0.58) + h1(a + 2.0) * H * 0.04);
			r = H * (0.15 - t * 0.06 + h1(a + 5.0) * 0.04);
			lift = r * 0.4;
		}
		vec2 d = (p - c) / r;
		float dd = dot(d, d);
		if (dd < 1.0) {
			float z = sqrt(1.0 - dd) * r + lift + h1(a + 11.0) * r * 0.3;
			if (z > best) {
				best = z;
				n = normalize(vec3(d, sqrt(1.0 - dd) * 1.2));
				rim = (1.0 - sqrt(dd)) * r;
			}
		}
	}
	hit = best > -1e3 && p.y > H * 0.13;
	// the underside is flat and in shade
	float l = dot(n, normalize(sun_dir)) + (vnoise(p * 1.4) - 0.5) * 0.2 - smoothstep(H * 0.3, H * 0.13, p.y) * 0.6;
	vec3 c = tone(l, vec3(1.0, 1.0, 0.99), vec3(0.95, 0.97, 1.0), vec3(0.79, 0.85, 0.95), vec3(0.64, 0.72, 0.88));
	c *= mix(1.0, 0.9, 1.0 - smoothstep(0.0, 0.05, rim));
	return vec4(c, 1.0);
}

// --- mountains: sharp peaks with lit and shaded faces and gullies ----------------------
float peaks(float x, out float slope) {
	float W = size.x;
	float H = size.y;
	float h = 0.0;
	slope = 0.0;
	for (int k = 0; k < 7; k++) {
		float a = float(k);
		float px = W * (a + 0.5) / 7.0 + (h1(a) - 0.5) * W / 7.0;
		float ph = H * (0.45 + 0.5 * h1(a + 4.0));
		float s = ph / (W * 0.12 * (0.7 + 0.7 * h1(a + 8.0)));
		// a rounded summit and slopes that are not straight: steeper near the top
		float dx = x - px;
		float v = ph - sqrt(dx * dx + 0.25) * s * (0.75 + 0.35 * smoothstep(0.0, ph / s, abs(dx)));
		if (v > h) {
			h = v;
			slope = dx < 0.0 ? s : -s;
		}
	}
	// shoulders and notches along the skyline
	h += (vnoise(vec2(x * 0.45, 0.0)) - 0.5) * H * 0.16 + (vnoise(vec2(x * 1.6, 3.0)) - 0.5) * H * 0.05;
	return h;
}

// --- clumps of trees covering a hill, rounded like the crowns of the scene's trees --------
float hill_top(float x, float base, float amp) {
	return base + amp * (vnoise(vec2(x / 5.0, 1.0)) * 0.7 + vnoise(vec2(x / 2.1, 2.0)) * 0.3);
}

vec4 clumps(vec2 p, float top_base, float amp, float cw, out bool hit, out float behind) {
	float best = -1e3;
	vec3 n = vec3(0.0, 0.0, 1.0);
	float rim = 1.0;
	vec2 cell = floor(p / vec2(cw, cw * 0.7));
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 ci = cell + vec2(float(i), float(j));
			vec2 c = (ci + vec2(0.5) + (vec2(h2(ci), h2(ci + 9.1)) - 0.5) * 0.6) * vec2(cw, cw * 0.7);
			float r = cw * (0.62 + 0.3 * h2(ci + 4.4));
			if (c.y > hill_top(c.x, top_base, amp) - r * 0.2) {
				continue;
			}
			vec2 d = (p - c) / r;
			float dd = dot(d, d);
			if (dd < 1.0) {
				float z = sqrt(1.0 - dd) * r - c.y * 0.6;   // lower clumps stand in front
				if (z > best) {
					best = z;
					n = normalize(vec3(d.x, d.y + 0.25, sqrt(1.0 - dd)));
					rim = (1.0 - sqrt(dd)) * r;
				}
			}
		}
	}
	hit = best > -1e3;
	behind = rim;
	return vec4(n, rim);
}

void fragment() {
	vec2 p = vec2(UV.x * size.x, (1.0 - UV.y) * size.y);   // metres from the bottom left
	if (!FRONT_FACING) {
		// the back of the flat: plywood with a batten along the foot
		vec3 ply = vec3(0.66, 0.56, 0.44) * (0.92 + 0.08 * vnoise(vec2(p.x * 3.0, 0.0)));
		ALBEDO = p.y < 0.12 ? ply * 0.75 : ply;
	} else if (kind == 4) {
		bool hit;
		vec4 c = cloud(p, hit);
		if (!hit) {
			discard;
		}
		ALBEDO = hazed(c.rgb, 0.0);
	} else if (kind == 1) {
		float slope;
		float h = peaks(p.x, slope);
		if (p.y > h) {
			discard;
		}
		// faces turn with the slope, broken by gullies running down from the ridges
		float gully = (vnoise(vec2(p.x * 2.2 + p.y * 0.6 * sign(slope), p.y * 0.25)) - 0.5) * 1.6;
		vec3 n = normalize(vec3(-slope * 0.8 + gully, 0.45, 1.0));
		float l = dot(n, normalize(sun_dir));
		vec3 c = tone(l, vec3(0.6, 0.7, 0.82), vec3(0.5, 0.6, 0.76), vec3(0.4, 0.49, 0.67), vec3(0.33, 0.4, 0.6));
		// a band of forest along the foot
		c = mix(c, vec3(0.3, 0.44, 0.5), step(p.y, size.y * 0.16 + vnoise(vec2(p.x * 1.3, 5.0)) * 0.3) * 0.7);
		c = hazed(c, (1.0 - p.y / size.y) * 0.18);
		ALBEDO = h - p.y < 0.035 ? c * 0.9 : c;
	} else if (kind == 2) {
		bool hit;
		float rim;
		vec4 nr = clumps(p, size.y * 0.45, size.y * 0.45, 0.55, hit, rim);
		if (!hit) {
			if (p.y > hill_top(p.x, size.y * 0.45, size.y * 0.45) - 0.4) {
				discard;
			}
			ALBEDO = hazed(vec3(0.13, 0.3, 0.3), 0.0);
		} else {
			float l = dot(nr.xyz, normalize(sun_dir)) + (vnoise(p * 2.5) - 0.5) * 0.2;
			vec3 c = tone(l, vec3(0.7, 0.85, 0.46), vec3(0.5, 0.72, 0.4), vec3(0.28, 0.52, 0.36), vec3(0.14, 0.33, 0.32));
			c *= mix(1.0, 0.8, 1.0 - smoothstep(0.0, 0.05, rim));
			ALBEDO = hazed(c, 0.0);
		}
	} else {
		// a seaside town on a low hill: white houses with coloured gable roofs among trees
		float ground = hill_top(p.x, size.y * 0.18, size.y * 0.22);
		float cw = 0.78;
		float cell = floor(p.x / cw);
		float fx = p.x / cw - cell;
		float hw = 0.32 + 0.1 * h1(cell * 3.1);            // half width of the house
		float cx = 0.5 + (h1(cell * 1.7) - 0.5) * 0.15;
		float ux = (fx - cx) * cw;                          // metres from the house centre
		float base_y = hill_top((cell + cx) * cw, size.y * 0.18, size.y * 0.22) - 0.1;
		float wall_h = 0.38 + 0.22 * h1(cell * 5.3);
		float roof_h = 0.24;
		bool house = h1(cell * 7.7) > 0.25;
		float eave = base_y + wall_h;
		float roof_line = eave + roof_h * (1.0 - abs(ux) / (hw + 0.06));
		bool in_wall = house && abs(ux) < hw && p.y > base_y && p.y < eave;
		bool in_roof = house && abs(ux) < hw + 0.06 && p.y >= eave - 0.02 && p.y < roof_line;
		vec3 c;
		bool shaded_side = dot(vec2(sign(ux), 0.0), normalize(sun_dir.xz)) < 0.0;
		if (in_roof) {
			float r = h1(cell * 9.2);
			vec3 rc = r < 0.35 ? vec3(0.8, 0.33, 0.28) : (r < 0.7 ? vec3(0.3, 0.47, 0.7) : vec3(0.42, 0.45, 0.52));
			c = shaded_side ? rc * 0.78 : rc;
			c = roof_line - p.y < 0.03 || p.y < eave + 0.025 ? c * 0.75 : c;
		} else if (in_wall) {
			c = vec3(0.96, 0.94, 0.88);
			c = shaded_side && abs(ux) > hw * 0.55 ? c * 0.8 : c;
			// two windows and a door
			float wy = p.y - base_y;
			bool win = abs(abs(ux) - hw * 0.5) < 0.07 && wy > wall_h * 0.5 && wy < wall_h * 0.78;
			bool door = abs(ux + hw * 0.1) < 0.06 && wy < wall_h * 0.42 && h1(cell * 2.3) > 0.5;
			c = win ? vec3(0.32, 0.43, 0.56) : (door ? vec3(0.42, 0.33, 0.27) : c);
			c = abs(ux) > hw - 0.025 ? c * 0.82 : c;
		} else {
			// trees in the gaps and along the foot, as clumps
			bool hit;
			float rim;
			vec4 nr = clumps(p, ground - 0.05, 0.25, 0.32, hit, rim);
			if (!hit) {
				if (p.y > ground - 0.25) {
					discard;
				}
				c = vec3(0.16, 0.34, 0.3);
			} else {
				float l = dot(nr.xyz, normalize(sun_dir));
				c = tone(l, vec3(0.7, 0.85, 0.46), vec3(0.5, 0.72, 0.4), vec3(0.28, 0.52, 0.36), vec3(0.14, 0.33, 0.32));
				c *= mix(1.0, 0.8, 1.0 - smoothstep(0.0, 0.03, rim));
			}
		}
		ALBEDO = hazed(c, 0.0);
	}
}
