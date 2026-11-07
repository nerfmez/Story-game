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
	# back to front: two clouds hung high, mountains, wooded hills, the town. The real sky
	# shows behind them, so there is no board edge against it.
	_flat(scene, "Cloud", 4, Vector3(-9.0, 2.2, z0 + 0.15), Vector2(12.0, 8.0), 0.18, 4.0, sun)
	_flat(scene, "Cloud2", 4, Vector3(12.0, 3.4, z0 + 0.2), Vector2(7.0, 4.6), 0.25, 9.0, sun)
	_flat(scene, "Mountains", 1, Vector3(0, -0.05, z0 + 0.45), Vector2(width, 5.6), 0.42, 1.0, sun)
	_flat(scene, "Hills", 2, Vector3(0, -0.05, z0 + 0.8), Vector2(width, 3.4), 0.2, 2.0, sun)
	_flat(scene, "Town", 3, Vector3(0, -0.05, z0 + 1.15), Vector2(width, 2.2), 0.06, 3.0, sun)
	# struts behind the standing flats, and thin rods carrying the hung clouds
	for x in range(-int(half_width), int(half_width) + 1, 6):
		for zz in [0.45, 0.8, 1.15]:
			k.box(Vector3(x, 0.25, z0 + zz - 0.08), Vector3(0.05, 0.6, 0.14), Color(0.55, 0.45, 0.35), {"line": 0.3})
	for c in [[-9.0, 2.2, 0.15], [12.0, 3.4, 0.2]]:
		k.rod(Vector3(c[0], -0.05, z0 + c[2] - 0.05), Vector3(c[0], c[1] + 1.0, z0 + c[2] - 0.05), 0.025, Color(0.55, 0.45, 0.35), {"line": 0.3})

static func _flat(scene: Node3D, name: String, kind: int, foot: Vector3, size: Vector2, haze: float, seed: float, sun: Vector3) -> void:
	var quad := QuadMesh.new()
	quad.size = size
	var mat := ShaderMaterial.new()
	mat.shader = FLAT
	mat.set_shader_parameter("kind", kind)
	mat.set_shader_parameter("size", size)
	mat.set_shader_parameter("haze", haze)
	mat.set_shader_parameter("seed", seed)
	mat.set_shader_parameter("sun_dir", sun)
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = quad
	mi.material_override = mat
	mi.position = foot + Vector3(0, size.y * 0.5, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(mi)
