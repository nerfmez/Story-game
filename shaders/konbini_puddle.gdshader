shader_type spatial;
// Standing water: dark mirror tint, sky sheen at grazing angles, rain rings,
// and a sharp highlight for every lamp. With flow > 0 it streams along flow_dir
// (the road gutters). COLOR.a fades the puddle edge.
render_mode blend_mix, depth_draw_never, cull_disabled;

uniform vec3 deep : source_color = vec3(0.04, 0.05, 0.11);
uniform vec3 sky : source_color = vec3(0.2, 0.24, 0.42);
uniform vec3 ring_color : source_color = vec3(0.55, 0.65, 0.9);
uniform float ring_cell = 0.34;
uniform float flow = 0.0;
uniform vec2 flow_dir = vec2(1.0, 0.0);

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float rings(vec2 p) {
	float acc = 0.0;
	vec2 cell = floor(p / ring_cell);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = cell + vec2(float(x), float(y));
			vec2 center = (c + vec2(hash(c), hash(c + 3.1))) * ring_cell;
			float ph = hash(c + 7.7);
			float t = fract(TIME * (0.55 + ph * 0.5) + ph);
			float d = length(p - center);
			acc += (1.0 - smoothstep(0.0, 0.012, abs(d - t * ring_cell * 0.9))) * (1.0 - t);
		}
	}
	return clamp(acc, 0.0, 1.0);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 col = mix(deep, sky, 0.12 + fres * 0.8);
	float lines = rings(world_pos.xz);
	if (flow > 0.0) {
		vec2 across = vec2(-flow_dir.y, flow_dir.x);
		float along = dot(world_pos.xz, flow_dir);
		float lane = floor(dot(world_pos.xz, across) / 0.05);
		float streak = fract(along * 1.6 - TIME * flow * (0.8 + hash(vec2(lane, 2.0)) * 0.6) + hash(vec2(lane, 9.0)));
		lines = max(lines * 0.4, smoothstep(0.8, 0.97, streak) * 0.7);
	}
	ALBEDO = col;
	EMISSION = ring_color * lines * 0.5;
	ROUGHNESS = 0.02;
	SPECULAR = 0.0;
	ALPHA = COLOR.a * 0.9;
}

void light() {
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * smoothstep(0.0, 0.05, dot(NORMAL, LIGHT) * ATTENUATION) * 0.15;
	vec3 h = normalize(VIEW + LIGHT);
	float s = pow(clamp(dot(NORMAL, h), 0.0, 1.0), 500.0);
	SPECULAR_LIGHT += LIGHT_COLOR / PI * smoothstep(0.25, 0.32, s) * smoothstep(0.0, 0.05, ATTENUATION) * SPECULAR_AMOUNT;
}
