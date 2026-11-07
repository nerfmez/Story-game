shader_type spatial;
// Painted backdrop flats for the back of a diorama (scripts/konbini_backdrop.gd): thin
// cut-out boards standing one behind the other, like the scenery flats of a stage or a
// model railway backscene. Each board is painted, not lit: a silhouette cut out of the
// quad with an ink line along its edge, flat cel tones with the light from one side,
// and colours that fade toward the sky the farther back the board stands, so a few
// centimetres of real depth read as kilometres. The back of every board is plain
// painted plywood, which gives the trick away when you look from behind.
//   kind 0 sky board, 1 far mountains, 2 hills with pines, 3 seaside town, 4 summer cloud
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

uniform int kind = 0;
uniform vec2 size = vec2(38.0, 4.0);     // width and height of the board in metres
uniform float haze = 0.0;                // 0 near, 1 lost in the sky
uniform float seed = 0.0;
uniform vec3 sky_top : source_color = vec3(0.36, 0.62, 0.93);
uniform vec3 sky_low : source_color = vec3(0.78, 0.89, 0.97);
uniform vec3 ink : source_color = vec3(0.12, 0.16, 0.26);

float hash1(float x) {
	return fract(sin(x * 127.1 + seed * 31.7) * 43758.5453);
}

float vnoise(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash1(i), hash1(i + 1.0), f);
}

// the skyline of a range: broad swells with sharper peaks on top
float ridge(float x, float base, float amp, float scale) {
	float n = vnoise(x / scale) * 0.6 + vnoise(x / scale * 2.3 + 7.0) * 0.3 + vnoise(x / scale * 5.1 + 3.0) * 0.1;
	return base + amp * n;
}

vec3 hazed(vec3 c, float y) {
	vec3 sky = mix(sky_low, sky_top, clamp(y / 9.0, 0.0, 1.0));
	return mix(c, sky, haze);
}

void fragment() {
	float x = UV.x * size.x;
	float y = (1.0 - UV.y) * size.y;   // metres up from the foot of the board
	if (!FRONT_FACING) {
		// the back of the flat: plywood with a batten along the foot
		vec3 ply = vec3(0.66, 0.56, 0.44) * (0.92 + 0.08 * vnoise(x * 3.0));
		ALBEDO = y < 0.12 ? ply * 0.75 : ply;
	} else if (kind == 0) {
		// the sky board: a soft gradient with a few flat streaks of high cloud
		vec3 c = mix(sky_low, sky_top, smoothstep(0.0, size.y, y));
		float streak = smoothstep(0.72, 0.8, vnoise(x * 0.15 + floor(y * 1.2) * 3.1)) * step(size.y * 0.55, y) * step(fract(y * 1.2), 0.22);
		ALBEDO = mix(c, vec3(1.0), streak * 0.6);
	} else if (kind == 1 || kind == 2) {
		// a range of mountains or wooded hills, lit from the left
		float amp = kind == 1 ? size.y * 0.75 : size.y * 0.55;
		float sc = kind == 1 ? 6.0 : 3.2;
		float h = ridge(x, size.y * 0.2, amp, sc);
		if (y > h) {
			discard;
		}
		float slope = ridge(x + 0.2, size.y * 0.2, amp, sc) - ridge(x - 0.2, size.y * 0.2, amp, sc);
		vec3 lit = kind == 1 ? vec3(0.38, 0.52, 0.66) : vec3(0.35, 0.55, 0.36);
		vec3 shade = kind == 1 ? vec3(0.28, 0.39, 0.55) : vec3(0.2, 0.38, 0.3);
		vec3 c = slope < 0.0 ? lit : shade;
		if (kind == 2) {
			// clumps of pine along the crest: a scalloped line of darker tree crowns
			float crowns = h - 0.12 - 0.1 * abs(sin(x * 3.4 + seed));
			c = y > crowns ? shade * 0.85 : c;
			// a few lighter patches of field and terraced slope lower down
			c = mix(c, vec3(0.55, 0.68, 0.4), step(0.8, vnoise(x * 0.6 + 11.0)) * step(y, h * 0.45) * 0.6);
		} else {
			// snow-free summer peaks: a lighter cap where the ridge is high
			c = mix(c, lit * 1.12, step(size.y * 0.8, y) * 0.5);
		}
		c = hazed(c, y + 3.0);
		ALBEDO = h - y < 0.05 ? mix(c, ink, 0.55 * (1.0 - haze)) : c;
	} else if (kind == 3) {
		// a seaside town climbing a low hill: white walls, coloured roofs, a few windows
		float hill = ridge(x, size.y * 0.25, size.y * 0.3, 5.0);
		float cell = floor(x / 0.55);
		float fx = fract(x / 0.55);
		float has = step(0.25, hash1(cell * 1.7));
		float wall = hill - 0.15 + 0.35 * hash1(cell * 3.3);
		float roof_h = 0.22;
		float roof = wall + roof_h * (1.0 - abs(fx - 0.5) * 2.2);
		bool in_house = has > 0.5 && fx > 0.06 && fx < 0.94 && y < max(roof, wall) && y > hill - 0.6;
		if (!in_house && y > hill) {
			discard;
		}
		vec3 c;
		if (in_house && y > wall) {
			float r = hash1(cell * 5.9);
			c = r < 0.33 ? vec3(0.78, 0.32, 0.28) : (r < 0.66 ? vec3(0.3, 0.45, 0.68) : vec3(0.45, 0.47, 0.52));
			c *= fx < 0.5 ? 1.0 : 0.82;
		} else if (in_house) {
			c = vec3(0.93, 0.91, 0.86) * (fx < 0.15 ? 0.85 : 1.0);
			float win = step(0.3, fract(fx * 3.0)) * step(fract(fx * 3.0), 0.7) * step(wall - 0.18, y) * step(y, wall - 0.08);
			c = mix(c, vec3(0.32, 0.42, 0.55), win);
		} else {
			c = mix(vec3(0.38, 0.56, 0.34), vec3(0.3, 0.46, 0.3), step(0.5, vnoise(x * 1.3)));
		}
		c = hazed(c, y + 1.5);
		bool edge = (!in_house && hill - y < 0.04) || (in_house && (y > wall ? max(roof, wall) - y < 0.03 : (fx < 0.09 || fx > 0.91)));
		ALBEDO = edge ? mix(c, ink, 0.5) : c;
	} else {
		// a towering summer cloud: billows stacked into a column, lit from upper left
		float cx = size.x * 0.5;
		float d = abs(x - cx);
		float width = size.x * 0.45 * (1.0 - smoothstep(0.0, size.y, y) * 0.55);
		float bil = 0.35 * sin(y * 2.2 + seed) + 0.25 * sin(y * 4.7 + seed * 2.0);
		float outline = width + bil;
		float top = size.y * 0.92 + 0.4 * sin(x * 1.7);
		if (d > outline || y > top) {
			discard;
		}
		float shade = smoothstep(-0.2, 0.5, (x - cx) / max(width, 0.1) + (0.4 - y / size.y));
		vec3 c = mix(vec3(1.0, 1.0, 0.98), vec3(0.78, 0.84, 0.94), step(0.55, shade));
		c = hazed(c, y + 4.0);
		ALBEDO = (outline - d < 0.06 || top - y < 0.06) ? mix(c, vec3(0.62, 0.7, 0.86), 0.6) : c;
	}
}
