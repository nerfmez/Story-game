extends RefCounted
## A backscene for the back of a diorama: thin painted flats standing one behind the
## other on the table behind the plinth, like the scenery of a stage or a model railway.
## From the front the wooded hills, the mountains and the summer clouds read as a
## landscape kilometres deep against the real sky; each is hazier and closer to the sky
## colour than the one in front (forced perspective). From the side or above you see they
## are only boards on feet.
## Painted by shaders/konbini_flat.gdshader, or by images in assets/backdrop/ (see PAINTED).

const Kit := preload("res://scripts/konbini_kit.gd")
const FLAT := preload("res://shaders/konbini_flat.gdshader")
const Foliage := preload("res://scripts/konbini_foliage.gd")

## Where the opening camera of the coast stands (distance 46 m, yaw -18, pitch 30): how far
## in front of the look-at point along z, and how high. A flat moved back is scaled up by
## the ratio of its distances from this eye, and lowered along the line of sight, so from
## the opening view it covers the same part of the picture as before.
const EYE := 38.7
const EYE_Y := 23.6

## Builds the flats behind a plinth whose back edge is at z = back, half_width wide on each
## side of x = 0. Each flat stands on a slim foot rail with braces behind it, like a stage
## flat; the nearest stands on the table (y = -1, where the plinth stands). The farther back a flat stands, the
## larger it is made, by the ratio of its distance from the opening camera, so it looks the
## same size from the front but moves less as the camera turns: real parallax between the
## layers, and a deeper view.
static func build(k: Kit, scene: Node3D, half_width: float, back := -9.45) -> void:
	var sun := Foliage.sun_from(Vector3(-48, -32, 0))   # the day sun of konbini_diorama.gd
	var floor_y := -1.0
	var base := EYE - back   # distance from the camera to the plinth's back edge
	# [name, kind, distance behind the plinth, centre x, height of the foot above the
	# table, width (clouds) and height as seen at the back edge, shader params]; back to front
	var layers := [
		["Cloud", 4, 10.0, -11.0, 6.0, 11.0, 7.5, {"haze": 0.12, "seed": 4.0}],
		["Cloud2", 4, 9.0, 10.0, 6.6, 6.5, 4.4, {"haze": 0.2, "seed": 9.0}],
		["FarPeaks", 1, 7.0, 0.0, 0.0, 0.0, 6.6, {"haze": 0.62, "seed": 1.0, "feature": 9.0, "lit": Color(0.58, 0.68, 0.84), "shade": Color(0.42, 0.52, 0.74)}],
		["Mountains", 1, 3.2, 0.0, 0.0, 0.0, 5.0, {"haze": 0.38, "seed": 2.0, "feature": 6.0, "lit": Color(0.5, 0.64, 0.74), "shade": Color(0.32, 0.45, 0.62)}],
		["Hills", 1, 0.4, 0.0, 0.0, 0.0, 3.4, {"haze": 0.12, "seed": 3.0, "feature": 4.5, "roughness": 1.0, "lit": Color(0.5, 0.7, 0.42), "shade": Color(0.2, 0.42, 0.38)}],
	]
	for l in layers:
		var dz: float = l[2]
		var s := (base + dz) / base
		var z := back - dz
		var w: float = l[5] if int(l[1]) == 4 else (half_width + 2.0) * 2.0
		var size := Vector2(w, float(l[6])) * s
		var foot := Vector3(float(l[3]) * s, EYE_Y + (floor_y + float(l[4]) - EYE_Y) * s, z)
		size = _flat(scene, l[0], l[1], foot, size, l[7], sun)
		if int(l[1]) == 4:
			# a cloud hangs on a rod from the table
			k.rod(Vector3(foot.x, minf(floor_y, foot.y), z - 0.08), Vector3(foot.x, foot.y + size.y * 0.5, z - 0.08), 0.03 * s, Color(0.55, 0.45, 0.35), {"line": 0.3})
		else:
			# the foot rail along the bottom and braces behind, every few metres
			k.box(Vector3(foot.x, foot.y + 0.05, z - 0.06), Vector3(size.x, 0.1, 0.12), Color(0.45, 0.36, 0.28), {"line": 0.3})
			var n := int(size.x / 6.0)
			for i in n + 1:
				var bx := foot.x - size.x * 0.5 + size.x * i / maxf(n, 1)
				k.rod(Vector3(bx, foot.y, z - 0.9 * s), Vector3(bx, foot.y + minf(size.y * 0.45, 2.5), z - 0.07), 0.035, Color(0.55, 0.45, 0.35), {"line": 0.3})

## Painted images can replace the procedural painting of any flat: put a PNG with a
## transparent background at assets/backdrop/<file>.png (names in PAINTED, made for
## example with the brief in docs/konbini-diorama/chatgpt-backdrop-brief.md). A range image
## is repeated across the board, so it must join left to right; trim empty sky off the top.
## The number of repeats is worked out from the image's proportions so it is not
## stretched; a cloud keeps its width and takes its height from the image.
const PAINTED := {
	"FarPeaks": "far_peaks", "Mountains": "mountains", "Hills": "hills",
	"Cloud": "cloud", "Cloud2": "cloud_small",
}

static func _flat(scene: Node3D, name: String, kind: int, foot: Vector3, size: Vector2, params: Dictionary, sun: Vector3) -> Vector2:
	if PAINTED.has(name):
		var path := "res://assets/backdrop/%s.png" % PAINTED[name]
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path)
			var aspect := float(tex.get_width()) / tex.get_height()
			params = params.duplicate()
			params["painting"] = tex
			if kind == 4:
				size.y = size.x / aspect
				params["tiles"] = 1.0
			else:
				params["tiles"] = maxf(roundf(size.x / (size.y * aspect)), 1.0)
			kind = 5
	var quad := QuadMesh.new()
	quad.size = size
	var mat := ShaderMaterial.new()
	mat.shader = FLAT
	mat.set_shader_parameter("kind", kind)
	mat.set_shader_parameter("size", size)
	mat.set_shader_parameter("sun_dir", sun)
	for key in params:
		mat.set_shader_parameter(key, params[key])
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = quad
	mi.material_override = mat
	mi.position = foot + Vector3(0, size.y * 0.5, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(mi)
	return size
