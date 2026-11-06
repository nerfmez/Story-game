extends RefCounted
## A rocky headland on a summer afternoon (layout = "headland"), the block to the left
## of the beach (scripts/konbini_beach.gd). The sand of the beach runs out against a
## terraced rock hill with black pines and a white lighthouse on top; stone steps climb
## to a viewpoint bench by a rope fence on the cliff edge; in front a low rock shelf
## holds tide pools, and the surf breaks around it and its boulders. The coast road
## from the beach runs into a tunnel through the hill.
## Edges: the right edge continues the beach exactly (road, wall, sand, waterline,
## seabed and wave timing); the left edge cuts through the hill, the tunnel and the
## sea, ready for a next block; the front is open sea; the back is the hill and road.

const Kit := preload("res://scripts/konbini_kit.gd")
const Exterior := preload("res://scripts/konbini_exterior.gd")
const Beach := preload("res://scripts/konbini_beach.gd")
const Foliage := preload("res://scripts/konbini_foliage.gd")

const OFFSET := -18.0          # this block sits one block to the left of the beach
const SAND_Y := Beach.SAND_Y
const SEA_Y := Beach.SEA_Y
const STRATUM := 0.42          # height of one rock terrace
const ROCK_A := Color(0.6, 0.52, 0.45)
const ROCK_B := Color(0.49, 0.43, 0.4)
const ROCK_WET := Color(0.36, 0.37, 0.39)
const GRASS := Color(0.5, 0.67, 0.37)
const WHITE := Color(0.96, 0.96, 0.94)
const WOOD := Color(0.6, 0.45, 0.32)
const PORTAL_X := -2.0         # face of the tunnel portal
const LIGHTHOUSE := Vector2(-6.0, -2.6)
const BENCH := Vector2(-3.6, 0.9)
const STAIR_FROM := Vector2(0.8, -4.6)
const STAIR_TO := Vector2(-2.9, -2.2)

## look-at point, yaw, pitch, distance
const VIEWS := [
	[Vector3(-1.0, 1.0, 0.5), -28.0, 30.0, 28.0],      # the whole headland, the sea in front
	[Vector3(-6.0, 3.6, -2.6), 35.0, 12.0, 9.0],       # the lighthouse
	[Vector3(0.0, 0.0, 0.0), 30.0, 62.0, 30.0],        # from above
	[Vector3(-4.8, 0.3, 4.2), -12.0, 28.0, 7.5],       # the tide pools
	[Vector3(-1.2, 1.3, -3.6), 62.0, 16.0, 8.5],       # the steps up the hill
	[Vector3(-2.2, 0.3, 5.5), -166.0, 32.0, 9.5],      # from behind the bench, out over the tide pools to sea
]

# --- the shape of the land -------------------------------------------------------

static func shore(x: float) -> float:
	return Beach.shore(x + OFFSET)

static func _wobble(x: float, z: float) -> float:
	# broad bends only: fine wiggles zigzag against the grid and the ledges turn to teeth
	return sin(x * 1.3 + z * 0.4) * 0.35 + sin(z * 1.9 - x * 0.7 + 1.3) * 0.25

static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return Vector2(p.distance_to(a + ab * t), t)

## Rock terraces, kept soft: only a hint of ledges in the shape. Steep risers turn into
## saw teeth on a height field grid; the crisp strata are drawn by the toon shader
## (pattern 7) as bands of rock colour instead.
static func _terrace(h: float) -> float:
	var q := floorf(h / STRATUM)
	var f := h / STRATUM - q
	return lerpf(h, (q + smoothstep(0.15, 1.0, f)) * STRATUM, 0.45)

## The hill: a spine running from the back toward the sea, and a ridge along the back
## over the road. Returns its height before terracing.
static func _hill(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var w := _wobble(x, z)
	var spine := _seg_dist(p, Vector2(-6.2, -8.6), Vector2(-5.2, 0.6))
	var top := lerpf(2.9, 2.0, spine.y)
	var h := top * (1.0 - smoothstep(1.7, 4.3, spine.x + w))
	var ridge := _seg_dist(p, Vector2(-9.5, -8.2), Vector2(-2.4, -8.2))
	h = maxf(h, 2.5 * (1.0 - smoothstep(0.9, 2.3, ridge.x + w * 0.6)))
	return h

## The low rock shelf in front, a little above the still water, with tide pools in it.
static func _shelf(x: float, z: float) -> float:
	var w := _wobble(x * 1.4, z * 1.4) * 0.5
	var e := Vector2((x + 4.8) / 4.3, (z - 3.6) / 2.3).length() + w * 0.25
	# (drops well below the seabed outside, so it never lifts the sea floor elsewhere)
	var h := lerpf(SEA_Y + 0.13, -0.6, smoothstep(0.86, 1.12, e))
	for pool: Vector3 in [Vector3(-6.4, 3.9, 0.62), Vector3(-4.1, 4.7, 0.72), Vector3(-2.9, 3.2, 0.5)]:
		var d := Vector2(x - pool.x, z - pool.y).length() / pool.z + w * 0.15
		h = minf(h, lerpf(SEA_Y - 0.02, h, smoothstep(0.75, 1.0, d)))
	return h

static func _stair_level(t: float) -> float:
	return lerpf(SAND_Y, _terrace(_hill(STAIR_TO.x, STAIR_TO.y)) + 0.02, t)

## Height of the ground and what it is made of: 0 sand, 1 hill rock or grass, 2 shelf.
static func ground_kind(x: float, z: float) -> Vector2:
	var sand := Beach.ground_u(z - shore(x))
	if z < -6.9 and x > PORTAL_X:
		sand = -0.05   # under the road
	var hill := _hill(x, z)
	var h := sand
	var kind := 0.0
	if hill > 0.02:
		var ht := _terrace(hill) + sand * (1.0 - smoothstep(0.0, 0.5, hill))
		if ht > h:
			h = ht
			kind = 1.0
	# the cut for the steps: the hill is dug down to the stair line along its path
	var sd := _seg_dist(Vector2(x, z), STAIR_FROM, STAIR_TO)
	if sd.x < 0.85 and kind == 1.0:
		var cut := _stair_level(sd.y) - 0.04
		h = lerpf(minf(h, cut), h, smoothstep(0.5, 0.85, sd.x))
	var shelf := _shelf(x, z)
	if shelf > h:
		h = shelf
		kind = 2.0
	# the road keeps its bed clear right up to the tunnel portal
	if z < -6.9 and x > PORTAL_X:
		h = -0.05
		kind = 0.0
	return Vector2(h, kind)

static func ground(x: float, z: float) -> float:
	return ground_kind(x, z).x

static func _ground_color(x: float, z: float, y: float) -> Color:
	var gk := ground_kind(x, z)
	var kind := int(gk.y)
	if kind == 0:
		return Beach._sand_color(x + OFFSET, z, y) if z > -6.9 else Color(0.45, 0.42, 0.4)
	if y < SEA_Y - 0.01:
		return ROCK_WET.lerp(Color(0.33, 0.42, 0.36), 0.4)
	if kind == 2:
		# the shelf: bare rock, greener with weed toward the water
		var c := ROCK_A.lerp(ROCK_B, 0.5 + 0.5 * sin(x * 2.1 + z * 1.7))
		return c.lerp(Color(0.42, 0.5, 0.38), smoothstep(SEA_Y + 0.1, SEA_Y + 0.02, y) * 0.6)
	# the hill is grass-coloured everywhere; the toon shader (pattern 7) turns the steep
	# parts into banded rock per pixel, which keeps those edges clean
	return GRASS.lerp(Color(0.58, 0.72, 0.4), 0.5 + 0.5 * sin(x * 1.3 - z * 0.9))

# --- building -----------------------------------------------------------------------

static func build(kit: Kit, scene: Node3D) -> void:
	scene.plate_text = "夏の午後"
	var b := Exterior.new()
	b.k = kit
	b.scene = scene
	b._base()
	_ground(kit, b)
	_sea(kit, scene)
	_tunnel(kit)
	_lighthouse(kit)
	_steps_and_viewpoint(kit)
	_tide_pools(kit)
	_trees(kit, scene)
	Beach._gulls(kit, scene)

static func _ground(k: Kit, b: RefCounted) -> void:
	k.material("asphalt", 3)
	k.material("sand", 3)
	k.flat_materials["sand"] = true
	k.material("rock", 7, {"rock_a": ROCK_A, "rock_b": ROCK_B, "stratum": STRATUM})
	k.flat_materials["rock"] = true
	# the coast road from the beach, its wall and rail, up to the tunnel portal
	k.slab(Vector3(PORTAL_X, -0.25, -9), Vector3(9, -0.02, -6.9), Color(0.42, 0.42, 0.47), {"line": 0.4})
	k.slab(Vector3(PORTAL_X, -0.02, -9), Vector3(9, 0.0, -7.3), Color(0.36, 0.38, 0.45), {"mat": "asphalt", "gloss": 0.1})
	k.quad(Vector3((PORTAL_X + 9.0) * 0.5, 0.004, -8.15), Vector2(9.0 - PORTAL_X, 0.1), Color(0.95, 0.95, 0.9))
	k.slab(Vector3(PORTAL_X, -0.02, -7.3), Vector3(9, 0.55, -6.9), Color(0.78, 0.78, 0.8))
	b._rail_run(Vector3(PORTAL_X + 0.4, 0.55, -7.1), Vector3(8.8, 0.55, -7.1))
	# one height field for sand, hill, steps and shelf
	k.grid(-9.0, -9.0, 9.0, 9.0, 160, 160, ground, _ground_color, {"mat": "rock"})
	# the cut through the land and the sea at the sides and front of the base
	var cuts: Array = []
	for i in 180:
		cuts.append([Vector3(-9.0 + i * 0.1, 0, 9.0), Vector3(-9.0 + (i + 1) * 0.1, 0, 9.0)])
	for i in 180:
		cuts.append([Vector3(-9.0, 0, -9.0 + i * 0.1), Vector3(-9.0, 0, -9.0 + (i + 1) * 0.1)])
	for i in 90:
		cuts.append([Vector3(9.0, 0, i * 0.1), Vector3(9.0, 0, (i + 1) * 0.1)])
	for c in cuts:
		var a: Vector3 = c[0]
		var e: Vector3 = c[1]
		var mid := (a + e) * 0.5
		var g := ground(mid.x, mid.z)
		var lo := Vector3(minf(a.x, e.x) - 0.005, 0, minf(a.z, e.z) - 0.005)
		var hi := Vector3(maxf(a.x, e.x) + 0.005, 0, maxf(a.z, e.z) + 0.005)
		var face := Color(0.66, 0.52, 0.36) if g < 0.25 else ROCK_B.darkened(0.12 if int(floorf(g / STRATUM)) % 2 == 0 else 0.2)
		if mid.x < -8.9 and mid.z < -7.2 and mid.z > -9.0:
			# the tunnel seen in section on the left edge: road bed, a dark bore, rock above
			k.slab(Vector3(lo.x, -0.25, lo.z), Vector3(hi.x, 0.0, hi.z), Color(0.42, 0.42, 0.47), {"line": 0.0})
			k.slab(Vector3(lo.x, 0.0, lo.z), Vector3(hi.x, 1.9, hi.z), Color(0.08, 0.08, 0.1), {"line": 0.0})
			k.slab(Vector3(lo.x, 1.9, lo.z), Vector3(hi.x, g, hi.z), face, {"line": 0.0})
			continue
		k.slab(Vector3(lo.x, -0.25, lo.z), Vector3(hi.x, g, hi.z), face, {"line": 0.0})
		if g < SEA_Y - 0.01:
			k.slab(Vector3(lo.x, g, lo.z), Vector3(hi.x, SEA_Y - 0.01, hi.z), Color(0.16, 0.5, 0.72).lerp(Color(0.08, 0.3, 0.58), clampf((SEA_Y - g) / 0.3, 0.0, 1.0)), {"line": 0.0})

## The sea and swash of the beach, run on across the seam (shore_offset), with the
## shelf, the headland and the boulders as rocks the surf breaks around.
static func _sea(k: Kit, scene: Node3D) -> void:
	var boulders := [[Vector3(-1.1, 0.0, 5.3), Vector3(0.55, 0.4, 0.5)], [Vector3(-0.4, -0.05, 5.9), Vector3(0.35, 0.25, 0.32)], [Vector3(-8.3, 0.0, 6.2), Vector3(0.6, 0.45, 0.55)], [Vector3(-7.5, -0.05, 6.8), Vector3(0.4, 0.3, 0.35)]]
	for r in boulders:
		k.ball(r[0], r[1], ROCK_B, {"seg": 9, "gloss": 0.3})
	var rocks: Array = []
	for r in boulders:
		var c: Vector3 = r[0]
		var s: Vector3 = r[1]
		rocks.append(Vector4(c.x, c.z, s.x * 0.95, s.z * 0.95))
	# the shelf and the foot of the headland at the waterline, a little inside the
	# real edge so the lapping foam sits right against the rock
	rocks.append(Vector4(-4.8, 3.6, 4.0, 2.05))
	rocks.append(Vector4(-6.6, 0.9, 2.2, 1.8))
	rocks.append(Vector4(-8.6, 2.6, 1.2, 1.6))
	var plane := PlaneMesh.new()
	plane.size = Vector2(18, 8.7)
	plane.subdivide_width = 90
	plane.subdivide_depth = 58
	var mat := ShaderMaterial.new()
	mat.shader = Beach.SEA
	mat.set_shader_parameter("shore_offset", OFFSET)
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
	swash_plane.size = Vector2(18, 3.6)
	swash_plane.subdivide_width = 90
	swash_plane.subdivide_depth = 24
	var swash_mat := ShaderMaterial.new()
	swash_mat.shader = Beach.SWASH
	swash_mat.render_priority = -1
	swash_mat.set_shader_parameter("shore_offset", OFFSET)
	var swash := MeshInstance3D.new()
	swash.name = "Swash"
	swash.mesh = swash_plane
	swash.material_override = swash_mat
	swash.position = Vector3(0, 0.0, 2.7)
	swash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(swash)

## The road runs into the hill through an arched concrete portal.
static func _tunnel(k: Kit) -> void:
	var x := PORTAL_X
	var concrete := Color(0.74, 0.73, 0.7)
	# the face: two piers and a lintel wall around a dark arch, a cornice on top
	k.box(Vector3(x - 0.2, 1.35, -9.2), Vector3(0.4, 2.7, 0.4), concrete)
	k.box(Vector3(x - 0.2, 1.35, -6.75), Vector3(0.4, 2.7, 0.5), concrete)
	k.box(Vector3(x - 0.2, 2.35, -8.0), Vector3(0.4, 0.7, 2.2), concrete)
	k.box(Vector3(x - 0.45, 1.0, -8.0), Vector3(0.1, 2.0, 2.0), Color(0.07, 0.07, 0.09), {"line": 0.0})
	for s in [-1.0, 1.0]:
		k.prism(Vector3(x - 0.02, 1.88, -8.0 + s * 0.78), Vector3(0.44, 0.45, 0.45), concrete, {"rot": Vector3(0, 90, 0 if s < 0 else 180)})
	k.box(Vector3(x - 0.2, 2.75, -8.0), Vector3(0.55, 0.12, 3.0), concrete.darkened(0.08))
	k.box(Vector3(x - 0.2, 2.45, -8.0), Vector3(0.42, 0.24, 0.9), Color(0.25, 0.3, 0.45), {"line": 0.4})
	# a lamp inside, glowing in the dark of the bore
	k.box(Vector3(x - 0.6, 1.75, -8.0), Vector3(0.12, 0.06, 0.4), Color(1.0, 0.9, 0.65), {"emit": 1.2, "line": 0.0})

## A white lighthouse with a gallery, a lantern room and a red dome, on the hill top.
static func _lighthouse(k: Kit) -> void:
	var base := Vector3(LIGHTHOUSE.x, ground(LIGHTHOUSE.x, LIGHTHOUSE.y), LIGHTHOUSE.y)
	k.cyl(base + Vector3(0, -0.15, 0), 0.95, 0.4, Color(0.7, 0.69, 0.66), {"seg": 16})
	var h := 2.6
	k.cyl(base + Vector3(0, h * 0.5, 0), 0.5, h, WHITE, {"top": 0.76, "seg": 16, "gloss": 0.2})
	var top := base + Vector3(0, h, 0)
	k.cyl(top + Vector3(0, 0.05, 0), 0.62, 0.1, WHITE, {"seg": 16})
	for i in 12:
		var a := i * TAU / 12.0
		k.rod(top + Vector3(cos(a) * 0.58, 0.1, sin(a) * 0.58), top + Vector3(cos(a) * 0.58, 0.42, sin(a) * 0.58), 0.012, Color(0.2, 0.22, 0.25), {"line": 0.0})
	k.torus(top + Vector3(0, 0.42, 0), 0.58, 0.02, Color(0.2, 0.22, 0.25), {"line": 0.0})
	k.cyl(top + Vector3(0, 0.38, 0), 0.34, 0.56, Color(0.85, 0.95, 1.0), {"seg": 16, "gloss": 0.9, "emit": 0.25, "line": 0.5})
	k.cyl(top + Vector3(0, 0.38, 0), 0.14, 0.3, Color(1.0, 0.92, 0.6), {"seg": 10, "emit": 0.8, "line": 0.0})
	k.cyl(top + Vector3(0, 0.71, 0), 0.4, 0.1, Color(0.22, 0.24, 0.28), {"seg": 16})
	k.ball(top + Vector3(0, 0.78, 0), Vector3(0.38, 0.3, 0.38), Color(0.82, 0.26, 0.22), {"seg": 12, "gloss": 0.4})
	k.cyl(top + Vector3(0, 1.12, 0), 0.03, 0.16, Color(0.22, 0.24, 0.28), {"seg": 6})
	k.ball(top + Vector3(0, 1.22, 0), Vector3.ONE * 0.05, Color(0.22, 0.24, 0.28), {"seg": 6})
	# a door and small windows facing the steps
	k.box(base + Vector3(0.47, 0.42, 0.12), Vector3(0.06, 0.8, 0.4), Color(0.22, 0.32, 0.5), {"rot": Vector3(0, -12, 0)})
	for y in [1.2, 1.9]:
		k.box(base + Vector3(0.42 - y * 0.03, y, 0.08), Vector3(0.05, 0.22, 0.14), Color(0.2, 0.25, 0.35), {"rot": Vector3(0, -12, 0), "line": 0.0})

## Stone steps climbing from the sand to the hill top, with a rope rail on posts, and
## at the top a bench looking out to sea behind a rope fence on the cliff edge.
static func _steps_and_viewpoint(k: Kit) -> void:
	var stone := Color(0.72, 0.7, 0.66)
	var dir := (STAIR_TO - STAIR_FROM)
	var length := dir.length()
	var yaw := rad_to_deg(atan2(dir.x, dir.y))
	var count := int(length / 0.32)
	for i in count:
		var t := (i + 0.5) / count
		var p := STAIR_FROM.lerp(STAIR_TO, t)
		var top := _stair_level(t)
		var bottom := minf(ground(p.x, p.y), top) - 0.3
		k.box(Vector3(p.x, (top + bottom) * 0.5, p.y), Vector3(0.95, top - bottom, 0.34), stone.darkened(0.04 * (i % 2)), {"rot": Vector3(0, yaw, 0), "line": 0.6})
	var side := Vector2(dir.y, -dir.x).normalized() * 0.55
	var posts: Array = []
	for i in 6:
		var t := i / 5.0
		var p := STAIR_FROM.lerp(STAIR_TO, t) + side
		var y := _stair_level(t)
		posts.append(Vector3(p.x, y + 0.75, p.y))
		k.rod(Vector3(p.x, y - 0.1, p.y), Vector3(p.x, y + 0.8, p.y), 0.035, WOOD, {"seg": 6})
	for i in posts.size() - 1:
		k.rod(posts[i], posts[i + 1], 0.015, Color(0.85, 0.78, 0.6), {"line": 0.0})
	# the viewpoint
	var b := Vector3(BENCH.x, ground(BENCH.x, BENCH.y), BENCH.y)
	var face := -20.0   # the sitter looks out to sea, toward the beach
	var basis := Basis(Vector3.UP, deg_to_rad(face))
	for s in [-0.5, 0.5]:
		k.box(b + basis * Vector3(s, 0.22, 0), Vector3(0.08, 0.44, 0.4), Color(0.4, 0.4, 0.42), {"basis": basis})
	k.box(b + basis * Vector3(0, 0.46, 0), Vector3(1.3, 0.06, 0.42), WOOD, {"basis": basis})
	k.box(b + basis * Vector3(0, 0.75, -0.2), Vector3(1.3, 0.3, 0.05), WOOD, {"basis": basis})
	for i in 7:
		var a := deg_to_rad(110.0 + i * 15.0)
		var p := Vector2(BENCH.x, BENCH.y) + Vector2(cos(a), sin(a)) * 1.5
		var y := ground(p.x, p.y)
		k.rod(Vector3(p.x, y - 0.1, p.y), Vector3(p.x, y + 0.65, p.y), 0.035, WOOD, {"seg": 6})
		if i > 0:
			var q := Vector2(BENCH.x, BENCH.y) + Vector2(cos(a - deg_to_rad(15.0)), sin(a - deg_to_rad(15.0))) * 1.5
			var qy := ground(q.x, q.y)
			k.rod(Vector3(q.x, qy + 0.6, q.y), Vector3(p.x, y + 0.6, p.y), 0.014, Color(0.85, 0.78, 0.6), {"line": 0.0})

## Tide pools: still water in the hollows of the shelf, with weed, a starfish, shells
## and a crab on the rock.
static func _tide_pools(k: Kit) -> void:
	for pool: Vector3 in [Vector3(-6.4, 3.9, 0.62), Vector3(-4.1, 4.7, 0.72), Vector3(-2.9, 3.2, 0.5)]:
		k.cyl(Vector3(pool.x, SEA_Y + 0.085, pool.y), pool.z * 0.9, 0.01, Color(0.35, 0.7, 0.72), {"seg": 16, "gloss": 0.9, "line": 0.0})
		for j in 3:
			var a := j * 2.1 + pool.x
			k.ball(Vector3(pool.x + cos(a) * pool.z * 0.5, SEA_Y + 0.07, pool.y + sin(a) * pool.z * 0.5), Vector3(0.09, 0.03, 0.07), Color(0.3, 0.5, 0.3), {"seg": 6, "line": 0.0})
	# a starfish in the middle pool, shells and a crab on the shelf
	var star := Vector3(-4.0, SEA_Y + 0.08, 4.6)
	for i in 5:
		var a := i * TAU / 5.0
		k.box(star + Vector3(cos(a), 0, sin(a)) * 0.07, Vector3(0.14, 0.02, 0.05), Color(0.95, 0.5, 0.3), {"rot": Vector3(0, -rad_to_deg(a), 0), "line": 0.4})
	for s: Vector2 in [Vector2(-5.3, 3.0), Vector2(-3.4, 4.0), Vector2(-7.1, 4.6)]:
		k.ball(Vector3(s.x, ground(s.x, s.y) + 0.02, s.y), Vector3(0.05, 0.03, 0.04), Color(0.95, 0.88, 0.8), {"seg": 6, "line": 0.4})
	var crab := Vector3(-5.6, ground(-5.6, 4.6) + 0.04, 4.6)
	k.ball(crab, Vector3(0.09, 0.04, 0.07), Color(0.85, 0.3, 0.2), {"seg": 8, "line": 0.5})
	for s in [-1.0, 1.0]:
		k.ball(crab + Vector3(s * 0.1, 0.0, 0.06), Vector3(0.03, 0.025, 0.025), Color(0.85, 0.3, 0.2), {"seg": 6, "line": 0.4})

## Black pines on the hill and two more on the sand by the seam, a few round shrubs.
static func _trees(k: Kit, scene: Node3D) -> void:
	var sun := Foliage.sun_from(Vector3(-48, -32, 0))
	var i := 0
	for t in [[Vector2(-7.9, -5.2), 0.35], [Vector2(-4.4, -5.4), -0.3], [Vector2(-7.6, -0.4), 0.25], [Vector2(5.0, -6.45), -0.2], [Vector2(8.1, -6.4), 0.3]]:
		var p: Vector2 = t[0]
		Foliage.pine(k, scene, Vector3(p.x, ground(p.x, p.y), p.y), (0.75 if p.x < 0.0 else 0.95) + 0.05 * (i % 3), {"sun_dir": sun, "seed": 70 + i, "lean": t[1], "name": "Pine%d" % i})
		i += 1
	for s: Vector2 in [Vector2(-8.3, -2.6), Vector2(-2.6, -0.2), Vector2(-5.0, -6.6), Vector2(-1.6, -5.6)]:
		Foliage.broadleaf(k, scene, Vector3(s.x, ground(s.x, s.y) - 0.1, s.y), 0.42, {"sun_dir": sun, "seed": 90 + i, "name": "Shrub%d" % i})
		i += 1

static func animate(scene: Node3D, clock: float) -> void:
	Beach.animate(scene, clock)

static func lights(_scene: Node3D) -> void:
	pass
