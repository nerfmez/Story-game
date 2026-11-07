extends RefCounted
## A backscene for the back of a diorama: thin painted flats standing one behind the
## other on a shelf added to the plinth, like the scenery of a stage or a model
## railway. From the front the town, the wooded hills, the mountains and the summer
## clouds read as a landscape kilometres deep against the real sky; they stand only centimetres apart,
## each one shorter, hazier and closer to the sky colour than the one in front
## (forced perspective). From the side or above you see they are only boards.
## Painted by shaders/konbini_flat.gdshader.

const Kit := preload("res://scripts/konbini_kit.gd")
const Exterior := preload("res://scripts/konbini_exterior.gd")
const FLAT := preload("res://shaders/konbini_flat.gdshader")
const Foliage := preload("res://scripts/konbini_foliage.gd")

## Builds the shelf and the flats behind a plinth whose back edge is at z = back,
## half_width wide on each side of x = 0.
static func build(k: Kit, scene: Node3D, half_width: float, back := -9.45) -> void:
	var w := half_width + 0.45
	var shelf := 1.6
	# the shelf: the plinth carried on backwards in the same wood and brass
	k.slab(Vector3(-w, -1.0, back - shelf), Vector3(w, -0.92, back), Color(0.18, 0.11, 0.08), {"mat": "wood"})
	k.slab(Vector3(-w + 0.07, -0.92, back - shelf + 0.07), Vector3(w - 0.07, -0.25, back), Exterior.WOOD, {"mat": "wood", "gloss": 0.25})
	k.slab(Vector3(-w + 0.04, -0.33, back - shelf + 0.04), Vector3(w - 0.04, -0.29, back), Exterior.BRASS, {"gloss": 0.7, "line": 0.5})
	k.slab(Vector3(-w + 0.07, -0.25, back - shelf + 0.07), Vector3(w - 0.07, -0.05, back), Color(0.42, 0.42, 0.47), {"line": 0.4})
	var width := (w - 0.1) * 2.0
	var sun := Foliage.sun_from(Vector3(-48, -32, 0))   # the day sun of konbini_diorama.gd
	var z0 := back - shelf
	# few layers, back to front, each fainter than the one in front (atmospheric
	# perspective) and fading into a band of valley mist at its foot; the real sky shows
	# behind. Colours: [lit, shade].
	_flat(scene, "Cloud", 4, Vector3(-10.0, 2.6, z0 + 0.12), Vector2(11.0, 7.5), {"haze": 0.12, "seed": 4.0}, sun)
	_flat(scene, "Cloud2", 4, Vector3(11.5, 3.4, z0 + 0.16), Vector2(6.5, 4.4), {"haze": 0.2, "seed": 9.0}, sun)
	_flat(scene, "FarPeaks", 1, Vector3(0, -0.05, z0 + 0.3), Vector2(width, 6.2), {"haze": 0.62, "seed": 1.0, "feature": 9.0, "lit": Color(0.58, 0.68, 0.84), "shade": Color(0.42, 0.52, 0.74)}, sun)
	_flat(scene, "Mountains", 1, Vector3(0, -0.05, z0 + 0.6), Vector2(width, 4.4), {"haze": 0.38, "seed": 2.0, "feature": 6.0, "lit": Color(0.5, 0.64, 0.74), "shade": Color(0.32, 0.45, 0.62)}, sun)
	_flat(scene, "Hills", 1, Vector3(0, -0.05, z0 + 0.9), Vector2(width, 2.6), {"haze": 0.12, "seed": 3.0, "feature": 4.5, "roughness": 1.0, "lit": Color(0.5, 0.7, 0.42), "shade": Color(0.2, 0.42, 0.38)}, sun)
	# struts behind the standing flats, and thin rods carrying the hung clouds
	for x in range(-int(half_width), int(half_width) + 1, 6):
		for zz in [0.3, 0.6, 0.9]:
			k.box(Vector3(x, 0.25, z0 + zz - 0.08), Vector3(0.05, 0.6, 0.14), Color(0.55, 0.45, 0.35), {"line": 0.3})
	for c in [[-10.0, 2.6, 0.12], [11.5, 3.4, 0.16]]:
		k.rod(Vector3(c[0], -0.05, z0 + c[2] - 0.05), Vector3(c[0], c[1] + 1.0, z0 + c[2] - 0.05), 0.025, Color(0.55, 0.45, 0.35), {"line": 0.3})
	# the join from 3D to 2D: a row of real, low-relief trees and a few house fronts
	# along the front of the shelf hides where the painted hills stand on it
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var x := -half_width + 0.6
	var i := 0
	while x < half_width - 0.5:
		var at := Vector3(x, -0.05, back - shelf + 1.15 + rng.randf_range(-0.12, 0.12))
		if i % 5 == 2:
			_house_front(k, at, rng)
		else:
			Foliage.broadleaf(k, scene, at, rng.randf_range(0.32, 0.45), {"sun_dir": sun, "seed": 200 + i, "name": "BackTree%d" % i})
		x += rng.randf_range(1.0, 1.6)
		i += 1

## A house front only 0.3 m deep (low relief): white walls, a coloured gable roof.
static func _house_front(k: Kit, at: Vector3, rng: RandomNumberGenerator) -> void:
	var wdt := rng.randf_range(0.8, 1.1)
	var wall := rng.randf_range(0.55, 0.75)
	var roof: Color = [Color(0.78, 0.33, 0.28), Color(0.3, 0.46, 0.68), Color(0.42, 0.45, 0.5)][rng.randi() % 3]
	k.box(at + Vector3(0, wall * 0.5, 0), Vector3(wdt, wall, 0.3), Color(0.95, 0.93, 0.88))
	k.prism(at + Vector3(0, wall + 0.16, 0), Vector3(wdt + 0.12, 0.32, 0.36), roof)
	for s in [-0.22, 0.22]:
		k.box(at + Vector3(s * wdt, wall * 0.6, 0.152), Vector3(0.14, 0.16, 0.01), Color(0.3, 0.42, 0.55), {"line": 0.0})

static func _flat(scene: Node3D, name: String, kind: int, foot: Vector3, size: Vector2, params: Dictionary, sun: Vector3) -> void:
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
