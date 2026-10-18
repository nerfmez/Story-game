shader_type spatial;
render_mode unshaded, cull_disabled;
// Paints a face with the author's flat picture, projected from the design camera.
// Each fragment finds where the ray from the design camera through it meets the picture plane
// (z = 0) and takes that pixel, so seen from the design camera the model looks exactly like the
// picture; from anywhere else the faces sit at their own depths and slide over each other.
// (scripts/school_building_3d.gd sets the uniforms.)

// pixel art, read "sharp bilinear" (as shaders/smooth_pixel.gdshader): flat texels with only a
// one-screen-pixel blend at their edges, so layers sliding by part of a pixel never double a texel
uniform sampler2D paint : source_color, filter_linear, repeat_disable;
uniform vec3 design_camera;          // world position the picture is "seen" from (metres)
uniform vec2 origin_px;              // paint pixel of world x = 0, y = 0 (ground, building centre)
uniform float px_per_m = 24.0;       // paint pixels per metre
// side faces of pillars etc. are darkened a little (the picture only has their front light)
uniform vec3 tint : source_color = vec3(1.0);
// a picture with its own camera (the author's close view of the entrance): plain pinhole,
// paint px = principal + focal * (x, -y) / distance in front of design_camera
uniform bool pinhole = false;
uniform vec2 principal;
uniform float focal = 1.0;
// plain colour instead of the picture (a face the picture never shows)
uniform bool solid = false;
uniform vec3 solid_colour : source_color = vec3(0.3);
// fade in/out with an ordered-dither cut (pixel art: no half-transparent pixels)
uniform float fade = 1.0;

const float BAYER[16] = {0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0};

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec4 picture(vec3 pos) {
	vec2 px;
	if (pinhole) {
		vec3 d = pos - design_camera;
		px = principal + focal * vec2(d.x, -d.y) / -d.z;
	} else {
		float t = design_camera.z / (design_camera.z - pos.z);
		vec2 p = design_camera.xy + (pos.xy - design_camera.xy) * t;
		px = vec2(origin_px.x + p.x * px_per_m, origin_px.y - p.y * px_per_m);
	}
	vec2 seam = floor(px + 0.5);
	px = seam + clamp((px - seam) / max(fwidth(px), vec2(1e-4)), -0.5, 0.5);
	return texture(paint, px / vec2(textureSize(paint, 0)));
}

void fragment() {
	if (fade < 1.0) {
		ivec2 sp = ivec2(mod(floor(FRAGCOORD.xy), 4.0));
		if (BAYER[sp.y * 4 + sp.x] / 16.0 >= fade) {
			discard;
		}
	}
	if (solid) {
		ALBEDO = solid_colour;
	} else {
		vec4 c = picture(world_pos);
		if (c.a < 0.5) {
			discard;
		}
		ALBEDO = c.rgb * tint;
	}
}
