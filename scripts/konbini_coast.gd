extends RefCounted
## The coast on a summer afternoon (layout = "coast"): the rocky headland with its
## lighthouse (scripts/konbini_headland.gd) and the beach with its beach hut
## (scripts/konbini_beach.gd) joined into one diorama, 36 x 18 m on one long plinth.
## Nothing shows where the two blocks meet: the coast road, its wall and rail run the
## whole length in one piece, one sea surface and one swash cover both halves with the
## same waterline and wave timing, and the cut faces on the seam are left out.
## Each block is built in its own coordinates under a node shifted to its half (the
## headland at x = -9, the beach at x = +9); shaders that work in world space get the
## shift (shore_offset, the rock list, the tunnel cut-out).

const Kit := preload("res://scripts/konbini_kit.gd")
const Exterior := preload("res://scripts/konbini_exterior.gd")
const Beach := preload("res://scripts/konbini_beach.gd")
const Headland := preload("res://scripts/konbini_headland.gd")

const HALF := 18.0             # half the length of the coast
const HEAD_X := -9.0           # where the headland block sits
const BEACH_X := 9.0           # where the beach block sits

## Where the summer air goes on a clear day (scripts/konbini_summer.gd).
const SUMMER := {
	"heat": [[Vector3(3.5, 0.0, -8.15), 28.5], [Vector3(13.5, 0.12, -2.5), 8.0]],
}

## look-at point, yaw, pitch, distance
const VIEWS := [
	[Vector3(0.0, 0.6, 0.8), -18.0, 30.0, 46.0],       # the whole coast
	[Vector3(-15.0, 4.8, -2.6), 35.0, 12.0, 13.0],     # the lighthouse
	[Vector3(0.0, 0.0, 0.0), 20.0, 62.0, 48.0],        # from above
	[Vector3(-2.5, 0.6, 2.5), -12.0, 26.0, 13.0],      # where the headland meets the beach
	[Vector3(3.9, 1.5, -3.0), 14.0, 9.0, 9.5],         # the beach hut
	[Vector3(-14.0, 2.3, 1.6), -40.0, 22.0, 9.0],      # the bench, looking along the coast
]

static func build(kit: Kit, scene: Node3D) -> void:
	scene.plate_text = "海の家なぎさ  ·  夏の午後"
	var b := Exterior.new()
	b.k = kit
	b.scene = scene
	_base(kit, scene)
	_road(kit, b)
	scene.set_meta("joined", true)
	_block(scene, "Headland", HEAD_X, Headland)
	_block(scene, "Beach", BEACH_X, Beach)
	_sea(scene)
	# one line of floats strung along the whole coast, clear of the boulders at the far left
	Beach.float_line(kit, -15.0, HALF - 2.0, 7.3)

## A plinth twice the usual length, in the same wood and brass as the single blocks.
static func _base(k: Kit, scene: Node3D) -> void:
	k.material("wood", 4)
	var w := HALF + 0.45
	k.slab(Vector3(-w, -1.0, -9.45), Vector3(w, -0.92, 9.45), Color(0.18, 0.11, 0.08), {"mat": "wood"})
	k.slab(Vector3(-HALF - 0.38, -0.92, -9.38), Vector3(HALF + 0.38, -0.25, 9.38), Exterior.WOOD, {"mat": "wood", "gloss": 0.25})
	k.slab(Vector3(-HALF - 0.41, -0.33, -9.41), Vector3(HALF + 0.41, -0.29, 9.41), Exterior.BRASS, {"gloss": 0.7, "line": 0.5})
	k.box(Vector3(0, -0.6, 9.4), Vector3(3.4, 0.32, 0.04), Exterior.BRASS, {"gloss": 0.8})
	k.text(scene.plate_text, Vector3(0, -0.6, 9.425), 0.12, Color(0.25, 0.16, 0.1), {"jp": true})

## The coast road in one piece from the tunnel portal to the right end, its sea wall
## and rail, with the gap in the rail where the boardwalk comes down from the road.
static func _road(k: Kit, b: RefCounted) -> void:
	k.material("asphalt", 3)
	var from := HEAD_X + Headland.PORTAL_X
	k.slab(Vector3(from, -0.25, -9), Vector3(HALF, -0.02, -6.9), Color(0.42, 0.42, 0.47), {"line": 0.4})
	k.slab(Vector3(from, -0.02, -9), Vector3(HALF, 0.0, -7.3), Color(0.36, 0.38, 0.45), {"mat": "asphalt", "gloss": 0.1})
	k.quad(Vector3((from + HALF) * 0.5, 0.004, -8.15), Vector2(HALF - from, 0.1), Color(0.95, 0.95, 0.9))
	k.slab(Vector3(from, -0.02, -7.3), Vector3(HALF, 0.55, -6.9), Color(0.78, 0.78, 0.8))
	b._rail_run(Vector3(from + 0.4, 0.55, -7.1), Vector3(BEACH_X - 1.4, 0.55, -7.1))
	b._rail_run(Vector3(BEACH_X + 0.6, 0.55, -7.1), Vector3(HALF - 0.2, 0.55, -7.1))

## Builds one block in its own coordinates under a node shifted to its half. The block
## builders add some nodes (sea props, trees, flags, steam, gulls) straight to the
## diorama; those are moved under the block's node afterwards, keeping their local
## placement, so they land in the right half too.
static func _block(scene: Node3D, name: String, x: float, builder: GDScript) -> void:
	var node := Node3D.new()
	node.name = name
	node.position = Vector3(x, 0, 0)
	scene.add_child(node)
	var before := {}
	for c in scene.get_children():
		before[c] = true
	var k := Kit.new(node)
	k.shadows = true
	scene.set_meta("block_x", x)
	builder.build(k, scene)
	k.finish()
	for c in scene.get_children():
		if not before.has(c):
			c.reparent(node, false)
	scene.set_meta("block_x", 0.0)
	scene.set_meta("primitive_count_" + name, k.primitive_count)

## One sea and one swash over the whole front, so the water has no seam. Both blocks
## take their waterline from Beach.shore in their own coordinates, which in the world
## is Beach.shore(x - 9) for either of them.
static func _sea(scene: Node3D) -> void:
	var rocks: Array = []
	for r: Vector4 in Headland.surf_rocks():
		rocks.append(r + Vector4(HEAD_X, 0, 0, 0))
	for r: Vector4 in Beach.surf_rocks():
		rocks.append(r + Vector4(BEACH_X, 0, 0, 0))
	var plane := PlaneMesh.new()
	plane.size = Vector2(HALF * 2.0, 8.7)
	plane.subdivide_width = 180
	plane.subdivide_depth = 58
	var mat := ShaderMaterial.new()
	mat.shader = Beach.SEA
	mat.set_shader_parameter("shore_offset", -BEACH_X)
	mat.set_shader_parameter("rocks", rocks)
	mat.set_shader_parameter("rock_count", rocks.size())
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = plane
	sea.material_override = mat
	sea.position = Vector3(0, 0.0, 4.65)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(sea)
	var swash_plane := PlaneMesh.new()
	swash_plane.size = Vector2(HALF * 2.0, 3.6)
	swash_plane.subdivide_width = 180
	swash_plane.subdivide_depth = 24
	var swash_mat := ShaderMaterial.new()
	swash_mat.shader = Beach.SWASH
	swash_mat.render_priority = -1
	swash_mat.set_shader_parameter("shore_offset", -BEACH_X)
	var swash := MeshInstance3D.new()
	swash.name = "Swash"
	swash.mesh = swash_plane
	swash.material_override = swash_mat
	swash.position = Vector3(0, 0.0, 2.7)
	swash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(swash)

## The gulls fly over the beach half (they were built there); the flags sway on their own.
static func animate(scene: Node3D, clock: float) -> void:
	Beach.animate(scene, clock)

static func lights(_scene: Node3D) -> void:
	pass
