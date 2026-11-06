shader_type spatial;
// What the swash leaves on the sand of the beach (scripts/konbini_beach.gd): a broken
// fringe of bubbles riding the front of the water as it runs up the slope and draws
// back, and sand that stays dark and wet where the water reached until it dries.
// The water itself is the sea surface (shaders/konbini_sea.gdshader); this sheet lies
// on the sand just under it, drawn first, and shares its timing through the include.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

#include "res://shaders/konbini_beach.gdshaderinc"

uniform vec3 foam : source_color = vec3(0.98, 0.99, 1.0);
uniform vec3 wet : source_color = vec3(0.5, 0.38, 0.26);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = ground_u(world_pos.z - shore(world_pos.x)) + 0.006;
	VERTEX.y += h - world_pos.y;
	world_pos.y = h;
}

void fragment() {
	float x = world_pos.x;
	float up = shore(x) - world_pos.z;   // metres up the beach from the still-water line
	float s;
	float reach;
	float fall;
	float rise;
	float front = swash_front(x, TIME, s, reach, fall, rise);
	vec4 out_col = vec4(0.0);
	// sand under the water and where it has just been is darker, drying from the top
	float dry = smoothstep(1.4, PERIOD * 0.95, s) * smoothstep(front, front + 0.6, up);
	// (only on the beach: under the sea the water colour already does this, and a
	// sheet that ends out there would show its straight edge through the water)
	// wet only as far as this wave has run so far (the last one has dried by now), so
	// the dark sand spreads up behind the water instead of appearing all at once
	float reached = -0.3 + (reach + 0.3) * rise;
	float soaked = (1.0 - smoothstep(reached - 0.1, reached + 0.05, up)) * smoothstep(-0.6, -0.1, up);
	out_col = vec4(wet, 0.4 * soaked * (1.0 - dry));
	// the fringe of bubbles at the front of the water: lacy, never a solid line,
	// thinning out as the water slows and slides back
	float ahead = front - up;
	float lace = beach_noise(vec2(x * 5.0, up * 7.0 - s * 1.5));
	float band = 1.0 - smoothstep(0.0, 0.08 + 0.18 * (1.0 - fall), abs(ahead - 0.04));
	float holes = smoothstep(0.38, 0.62, lace);
	float fringe = band * holes * (1.0 - smoothstep(0.3, 0.9, fall)) * step(-0.02, ahead);
	// bubbles left behind in the water on the way up
	float trail = smoothstep(0.66, 0.74, lace) * (1.0 - smoothstep(0.0, 0.5, ahead)) * step(0.0, ahead) * (1.0 - fall);
	float f = clamp(fringe + trail, 0.0, 1.0);
	out_col = mix(out_col, vec4(foam, 0.9), f);
	if (out_col.a <= 0.002) {
		discard;
	}
	ALBEDO = out_col.rgb;
	ALPHA = out_col.a;
}
