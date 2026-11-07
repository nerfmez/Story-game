extends RefCounted
## A backscene for the back of a diorama: thin painted flats standing one behind the
## other on a shelf added to the plinth, like the scenery of a stage or a model
## railway. From the front the town, the wooded hills, the mountains, a summer cloud
## and the sky read as a landscape kilometres deep; they stand only centimetres apart,
## each one shorter, hazier and closer to the sky colour than the one in front
## (forced perspective). From the side or above you see they are only boards.
## Painted by shaders/konbini_flat.gdshader.

const Kit := preload("res://scripts/konbini_kit.gd")
const Exterior := preload("res://scripts/konbini_exterior.gd")
const FLAT := preload("res://shaders/konbini_flat.gdshader")

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
	# back to front: sky, cloud, mountains, wooded hills, the town
	_flat(scene, "SkyBoard", 0, Vector3(0, -0.05, back - shelf + 0.12), Vector2(width, 9.0), 0.0, 0.0)
	_flat(scene, "Cloud", 4, Vector3(-6.0, 1.6, back - shelf + 0.4), Vector2(10.0, 7.0), 0.35, 4.0)
	_flat(scene, "Cloud2", 4, Vector3(11.0, 2.4, back - shelf + 0.45), Vector2(6.0, 4.0), 0.4, 9.0)
	_flat(scene, "Mountains", 1, Vector3(0, -0.05, back - shelf + 0.65), Vector2(width, 5.0), 0.55, 1.0)
	_flat(scene, "Hills", 2, Vector3(0, -0.05, back - shelf + 0.95), Vector2(width, 3.4), 0.28, 2.0)
	_flat(scene, "Town", 3, Vector3(0, -0.05, back - shelf + 1.25), Vector2(width, 2.5), 0.12, 3.0)
	# little struts behind the flats, as on a real backscene
	for x in range(-int(half_width), int(half_width) + 1, 6):
		for zz in [0.65, 0.95, 1.25]:
			k.box(Vector3(x, 0.25, back - shelf + zz - 0.08), Vector3(0.05, 0.6, 0.14), Color(0.55, 0.45, 0.35), {"line": 0.3})

static func _flat(scene: Node3D, name: String, kind: int, foot: Vector3, size: Vector2, haze: float, seed: float) -> void:
	var quad := QuadMesh.new()
	quad.size = size
	var mat := ShaderMaterial.new()
	mat.shader = FLAT
	mat.set_shader_parameter("kind", kind)
	mat.set_shader_parameter("size", size)
	mat.set_shader_parameter("haze", haze)
	mat.set_shader_parameter("seed", seed)
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = quad
	mi.material_override = mat
	mi.position = foot + Vector3(0, size.y * 0.5, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(mi)
