shader_type spatial;
// Cel shading for the konbini diorama. Geometry is merged per material, so the
// look of each part rides on vertex data (see scripts/konbini_kit.gd):
//   COLOR.rgb  albedo        COLOR.a  self-emission (signs, lamps, screens)
//   UV2.x      wet gloss     UV2.y    indoor fill light (bright shop interior)
// Lighting is cut into flat bands and wet surfaces get a hard-edged highlight,
// which on the ground reads as the painted light reflections of anime rain scenes.
// Fill lights with light_specular = 0 (light spilling from the windows) add no highlight.
render_mode blend_mix, depth_draw_opaque, cull_back;

// 0 plain, 1 sidewalk pavers, 2 shop floor tiles, 3 asphalt, 4 wood, 5 concrete blocks, 6 wall siding,
// 7 terraced rock hill (grass-coloured vertices turn to banded rock where the ground is steep)
uniform int pattern = 0;
uniform float emit_energy = 1.6;
uniform vec3 indoor_light : source_color = vec3(1.0, 0.88, 0.72);
uniform vec3 sky_sheen : source_color = vec3(0.07, 0.09, 0.18);
// Parts that move past the edge of the base (a train) are cut off there.
uniform float clip_x = 1000.0;
// pattern 7: the rock of the strata and the height of one stratum
uniform vec3 rock_a : source_color = vec3(0.6, 0.52, 0.45);
uniform vec3 rock_b : source_color = vec3(0.49, 0.43, 0.4);
uniform float stratum = 0.42;
// pattern 7: a tunnel bore running toward -x from a portal (portal x, centre z, radius,
// height of the springing); ground inside it is cut away
uniform vec4 tunnel = vec4(-1000.0, 0.0, 0.0, 0.0);

varying vec3 world_pos;

#include "res://shaders/konbini_clouds.gdshaderinc"

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// 1 on the joints of a running-bond grid, 0 on the faces
float joints(vec2 p, vec2 cell, float offset, float width) {
	float row = floor(p.y / cell.y);
	p.x += mod(row, 2.0) * cell.x * offset;
	vec2 d = abs(fract(p / cell) - 0.5) * cell;
	vec2 edge = 0.5 * cell - d;
	return 1.0 - step(width, min(edge.x, edge.y));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (abs(world_pos.x) > clip_x) {
		discard;
	}
	if (pattern == 7 && world_pos.x < tunnel.x) {
		float dz = abs(world_pos.z - tunnel.y);
		if (dz < tunnel.z && world_pos.y < tunnel.w + sqrt(max(tunnel.z * tunnel.z - dz * dz, 0.0))) {
			discard;
		}
	}
	vec3 albedo = COLOR.rgb;
	float gloss = UV2.x;
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	bool top = wn.y > 0.7;
	vec2 face = abs(wn.x) > abs(wn.z) ? vec2(world_pos.z, world_pos.y) : vec2(world_pos.x, world_pos.y);
	if (pattern == 1 && top) {
		vec2 cell = vec2(0.4, 0.2);
		float tile = hash(floor(vec2(world_pos.x + mod(floor(world_pos.z / cell.y), 2.0) * 0.2, world_pos.z) / cell));
		albedo *= mix(0.94, 1.05, tile) * mix(1.0, 0.72, joints(world_pos.xz, cell, 0.5, 0.012));
	} else if (pattern == 2 && top) {
		vec2 t = floor(world_pos.xz / 0.45);
		albedo *= (mod(t.x + t.y, 2.0) < 1.0 ? 1.0 : 0.95) * mix(1.0, 0.82, joints(world_pos.xz, vec2(0.45), 0.0, 0.008));
	} else if (pattern == 3 && top) {
		float grain = noise(world_pos.xz * 9.0) * 0.5 + noise(world_pos.xz * 31.0) * 0.5;
		albedo *= 0.9 + grain * 0.18;
		gloss *= 0.55 + 0.45 * smoothstep(0.3, 0.6, noise(world_pos.xz * 0.55 + 4.0));
	} else if (pattern == 4) {
		vec2 g = top ? world_pos.xz : face;
		float grain = noise(vec2(g.x * 1.2, g.y * 26.0)) * 0.6 + noise(vec2(g.x * 5.0, g.y * 70.0)) * 0.4;
		albedo *= 0.86 + grain * 0.24;
	} else if (pattern == 5 && !top) {
		albedo *= mix(1.0, 0.74, joints(face, vec2(0.4, 0.2), 0.5, 0.01)) * (0.95 + 0.08 * hash(floor(face / vec2(0.4, 0.2))));
	} else if (pattern == 7 && COLOR.g > COLOR.r + 0.12) {
		// decided per pixel, not per vertex, so the grass edge and the rock strata are
		// clean lines instead of the zigzags vertex colours make on a height field
		float wob = (noise(world_pos.xz * 1.7) - 0.5) * 0.12;
		float steep = 1.0 - smoothstep(0.62, 0.78, wn.y + wob);
		float band = mod(floor((world_pos.y + (noise(world_pos.xz * 0.9) - 0.5) * 0.18) / stratum), 2.0);
		vec3 rock = band < 1.0 ? rock_a : rock_b;
		rock *= 0.92 + 0.12 * noise(vec2(world_pos.x + world_pos.z, world_pos.y * 6.0) * 2.0);
		albedo = mix(albedo, rock, step(0.5, steep));
	} else if (pattern == 6 && !top) {
		albedo *= mix(1.0, 0.86, step(0.9, fract(face.y / 0.18)));
	}
	ALBEDO = albedo;
	ROUGHNESS = 1.0 - gloss;
	SPECULAR = 0.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = albedo * COLOR.a * emit_energy + albedo * indoor_light * UV2.y + sky_sheen * gloss * rim;
}

void light() {
	float e = dot(NORMAL, LIGHT) * ATTENUATION;
	if (LIGHT_IS_DIRECTIONAL) {
		e *= 1.0 - 0.8 * cloud_cover(world_pos, TIME);   // a cloud passing over the sun
	}
	float lit = smoothstep(0.02, 0.05, e) * 0.3 + smoothstep(0.18, 0.21, e) * 0.35 + smoothstep(0.5, 0.53, e) * 0.35;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * lit;
	float gloss = 1.0 - ROUGHNESS;
	if (gloss > 0.02) {
		vec3 h = normalize(VIEW + LIGHT);
		float s = pow(clamp(dot(NORMAL, h), 0.0, 1.0), mix(30.0, 700.0, gloss));
		float shine = smoothstep(0.3, 0.38, s) * smoothstep(0.0, 0.06, ATTENUATION);
		SPECULAR_LIGHT += LIGHT_COLOR / PI * shine * gloss * 0.7 * SPECULAR_AMOUNT;
	}
}
