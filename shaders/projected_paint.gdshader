shader_type spatial;
render_mode unshaded, cull_disabled;
// Paints a face with the author's flat picture, projected from the design camera.
// Each fragment finds where the ray from the design camera through it meets the picture plane
// (z = 0) and takes that pixel, so seen from the design camera the model looks exactly like the
// picture; from anywhere else the faces sit at their own depths and slide over each other.
// (scripts/school_building_3d.gd sets the uniforms.)

uniform sampler2D paint : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 design_camera;          // world position the picture is "seen" from (metres)
uniform vec2 origin_px;              // picture pixel of world x = 0, y = 0 (ground, building centre)
uniform float px_per_m = 50.0;
// side faces of pillars etc. are darkened a little (the picture only has their front light)
uniform vec3 tint : source_color = vec3(1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = design_camera.z / (design_camera.z - world_pos.z);
	vec2 p = design_camera.xy + (world_pos.xy - design_camera.xy) * t;
	vec2 px = vec2(origin_px.x + p.x * px_per_m, origin_px.y - p.y * px_per_m);
	vec4 c = texture(paint, px / vec2(textureSize(paint, 0)));
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb * tint;
}
