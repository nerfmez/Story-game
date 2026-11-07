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
const TUNNEL_Z := -7.97        # centre line of the bore, over the road
const TUNNEL_R := 1.0          # half width of the bore, and the radius of its vault
const TUNNEL_SPRING := 1.0     # height where the vault starts
const LIGHTHOUSE := Vector2(-6.0, -2.6)
const POOLS := [Vector3(-6.4, 3.9, 0.62), Vector3(-4.1, 4.7, 0.72), Vector3(-2.9, 3.2, 0.5)]   # x, z, radius
const POOL := preload("res://shaders/konbini_pool.gdshader")
const BENCH := Vector2(-5.2, 0.6)
const STAIR_FROM := Vector2(-1.0, -4.5)
const STAIR_TO := Vector2(-4.0, -2.9)

## look-at point, yaw, pitch, distance
const VIEWS := [
	[Vector3(-1.0, 1.0, 0.5), -28.0, 30.0, 28.0],      # the whole headland, the sea in front
	[Vector3(-6.0, 4.8, -2.6), 35.0, 12.0, 13.0],      # the lighthouse
	[Vector3(0.0, 0.0, 0.0), 30.0, 62.0, 30.0],        # from above
	[Vector3(-4.8, 0.3, 4.2), -12.0, 28.0, 7.5],       # the tide pools
	[Vector3(-2.4, 1.3, -3.7), 62.0, 16.0, 9.0],       # the steps up the hill
	[Vector3(-5.0, 2.3, 1.6), -20.0, 24.0, 7.5],       # the bench and its fence, the tide pools and the sea beyond
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
	for pool: Vector3 in POOLS:
		var d := Vector2(x - pool.x, z - pool.y).length() / pool.z + w * 0.15
		h = minf(h, lerpf(SEA_Y - 0.02, h, smoothstep(0.75, 1.0, d)))
	return h

static func _stair_level(t: float) -> float:
	return lerpf(SAND_Y, _terrace(_hill(STAIR_TO.x, STAIR_TO.y)) + 0.02, t)

## Height of the ground and what it is made of: 0 sand, 1 hill rock or grass, 2 shelf.
static func ground_kind(x: float, z: float) -> Vector2:
	var sand := Beach.ground_u(z - shore(x))
	if z < -6.9 and x > PORTAL_X - 0.12:
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
	if z < -6.9 and x > PORTAL_X - 0.12:
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
	var joined: bool = scene.get_meta("joined", false)
	if not joined:
		b._base()
	_ground(kit, b, joined, scene.get_meta("block_x", 0.0))
	_sea(kit, scene, not joined)
	_tunnel(kit)
	_lighthouse(kit)
	_steps_and_viewpoint(kit)
	_tide_pools(kit, scene)
	_trees(kit, scene)
	if not joined:
		Beach._gulls(kit, scene)

## joined / block_x: built as the left half of the coast scene (scripts/konbini_coast.gd),
## which lays the road once and leaves out the cut on the seam; block_x is where this
## block sits in the world, for the tunnel cut-out the toon shader makes in world space.
static func _ground(k: Kit, b: RefCounted, joined := false, block_x := 0.0) -> void:
	k.material("asphalt", 3)
	k.material("sand", 3)
	k.flat_materials["sand"] = true
	# (the tunnel uniforms let the shader cut the ground away inside the bore: a height
	# field cannot have the hole, so the step it makes behind the portal is discarded)
	k.material("rock", 7, {"rock_a": ROCK_A, "rock_b": ROCK_B, "stratum": STRATUM, "tunnel": Vector4(PORTAL_X + block_x, TUNNEL_Z, TUNNEL_R, TUNNEL_SPRING)})
	k.flat_materials["rock"] = true
	# the coast road from the beach, its wall and rail, up to the tunnel portal
	if not joined:
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
	if not joined:
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
		if mid.x < -8.9 and absf(mid.z - TUNNEL_Z) < TUNNEL_R + 0.01:
			# the tunnel seen in section on the left edge: road bed, a dark bore, rock above
			k.slab(Vector3(lo.x, -0.25, lo.z), Vector3(hi.x, 0.0, hi.z), Color(0.42, 0.42, 0.47), {"line": 0.0})
			var top := maxf(_arch_top(mid.z), 0.0)
			if top > 0.0:
				k.slab(Vector3(lo.x, 0.0, lo.z), Vector3(hi.x, top, hi.z), Color(0.08, 0.08, 0.1), {"line": 0.0})
			k.slab(Vector3(lo.x, top, lo.z), Vector3(hi.x, g, hi.z), face, {"line": 0.0})
			continue
		k.slab(Vector3(lo.x, -0.25, lo.z), Vector3(hi.x, g, hi.z), face, {"line": 0.0})
		if g < SEA_Y - 0.01:
			k.slab(Vector3(lo.x, g, lo.z), Vector3(hi.x, SEA_Y - 0.01, hi.z), Color(0.16, 0.5, 0.72).lerp(Color(0.08, 0.3, 0.58), clampf((SEA_Y - g) / 0.3, 0.0, 1.0)), {"line": 0.0})

## The sea and swash of the beach, run on across the seam (shore_offset), with the
## shelf, the headland and the boulders as rocks the surf breaks around.
const BOULDERS := [[Vector3(-1.1, 0.0, 5.3), Vector3(0.55, 0.4, 0.5)], [Vector3(-0.4, -0.05, 5.9), Vector3(0.35, 0.25, 0.32)], [Vector3(-8.3, 0.0, 6.2), Vector3(0.6, 0.45, 0.55)], [Vector3(-7.5, -0.05, 6.8), Vector3(0.4, 0.3, 0.35)]]

## The rocks the surf breaks around, each (centre x, z, radius x, z) at the waterline:
## the boulders, and the shelf and the foot of the headland, a little inside the real
## edge so the lapping foam sits right against the rock.
static func surf_rocks() -> Array:
	var rocks: Array = []
	for r in BOULDERS:
		var c: Vector3 = r[0]
		var sz: Vector3 = r[1]
		rocks.append(Vector4(c.x, c.z, sz.x * 0.95, sz.z * 0.95))
	rocks.append(Vector4(-4.8, 3.6, 4.0, 2.05))
	rocks.append(Vector4(-6.6, 0.9, 2.2, 1.8))
	rocks.append(Vector4(-8.6, 2.6, 1.2, 1.6))
	return rocks

## planes: false when the coast scene lays one sea over both blocks instead.
static func _sea(k: Kit, scene: Node3D, planes := true) -> void:
	for r in BOULDERS:
		k.ball(r[0], r[1], ROCK_B, {"seg": 9, "gloss": 0.3})
	if not planes:
		return
	var rocks := surf_rocks()
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

## The road runs into the hill through a tunnel: a concrete portal with a round arch
## and a ring of darker voussoirs, and inside a vaulted bore with the road running on,
## lamps along the vault, getting darker the deeper it goes.
static func _tunnel(k: Kit) -> void:
	var x := PORTAL_X
	var concrete := Color(0.76, 0.75, 0.72)
	var face_top := 3.0
	# the face, sliced across the opening so the arch is a clean half circle
	var z0 := maxf(TUNNEL_Z - TUNNEL_R - 0.55, -9.0)
	var z1 := TUNNEL_Z + TUNNEL_R + 0.55
	var slices := 90
	for i in slices:
		var za := lerpf(z0, z1, float(i) / slices)
		var zb := lerpf(z0, z1, float(i + 1) / slices)
		var zm := (za + zb) * 0.5
		var arch := _arch_top(zm)
		var from_y := 0.0 if arch < 0.0 else arch
		k.slab(Vector3(x - 0.45, from_y, za), Vector3(x, face_top, zb), concrete, {"line": 0.0})
		if arch >= 0.0:
			# the voussoir ring just above the opening
			k.slab(Vector3(x - 0.02, arch, za), Vector3(x + 0.03, arch + 0.16, zb), concrete.darkened(0.18), {"line": 0.0})
	# a cornice along the top and a name plate above the arch
	k.box(Vector3(x - 0.2, face_top + 0.06, (z0 + z1) * 0.5), Vector3(0.6, 0.12, z1 - z0 + 0.2), concrete.darkened(0.08))
	k.box(Vector3(x + 0.03, TUNNEL_SPRING + TUNNEL_R + 0.45, TUNNEL_Z), Vector3(0.04, 0.24, 0.9), Color(0.25, 0.3, 0.45), {"line": 0.4})
	# the bore: road, side walls and a vault of planks, darker in steps toward the back
	var depth_steps := 5
	for j in depth_steps:
		var xa := lerpf(x - 0.45, -9.0, float(j) / depth_steps)
		var xb := lerpf(x - 0.45, -9.0, float(j + 1) / depth_steps)
		var shade := 0.55 - j * 0.1
		var wall := Color(0.62, 0.62, 0.6) * shade
		for s in [-1.0, 1.0]:
			k.slab(Vector3(xb, 0.0, TUNNEL_Z + s * TUNNEL_R - 0.05), Vector3(xa, TUNNEL_SPRING, TUNNEL_Z + s * TUNNEL_R + 0.05), wall, {"line": 0.0})
		var segs := 10
		for q in segs:
			var a0 := PI * q / segs
			var a1 := PI * (q + 1) / segs
			var am := (a0 + a1) * 0.5
			var c := Vector3((xa + xb) * 0.5, TUNNEL_SPRING + sin(am) * TUNNEL_R, TUNNEL_Z - cos(am) * TUNNEL_R)
			k.box(c, Vector3(xa - xb, 0.1, TUNNEL_R * (a1 - a0) * 1.05), wall * 0.95, {"basis": Basis(Vector3.RIGHT, -(am - PI * 0.5)), "line": 0.0})
		k.slab(Vector3(xb, -0.02, TUNNEL_Z - TUNNEL_R), Vector3(xa, 0.0, TUNNEL_Z + TUNNEL_R), Color(0.36, 0.38, 0.45) * (shade + 0.35), {"line": 0.0})
		k.quad(Vector3((xa + xb) * 0.5, 0.004, TUNNEL_Z), Vector2(xa - xb, 0.08), Color(0.95, 0.95, 0.9) * (shade + 0.3))
		# a lamp on the vault in each stretch
		k.box(Vector3((xa + xb) * 0.5, TUNNEL_SPRING + TUNNEL_R - 0.08, TUNNEL_Z), Vector3(0.4, 0.06, 0.12), Color(1.0, 0.88, 0.6), {"emit": 1.4, "line": 0.0})

## Height of the tunnel arch at z across the opening (-1 outside it).
static func _arch_top(z: float) -> float:
	var d := absf(z - TUNNEL_Z)
	if d >= TUNNEL_R:
		return -1.0
	return TUNNEL_SPRING + sqrt(TUNNEL_R * TUNNEL_R - d * d)

## A white lighthouse with a gallery, a lantern room and a red dome, on the hill top.
static func _lighthouse(k: Kit) -> void:
	# built at 1.6 x its first size: it is the landmark of the coast and has to read
	# from across the whole diorama
	var S := 1.6
	var base := Vector3(LIGHTHOUSE.x, ground(LIGHTHOUSE.x, LIGHTHOUSE.y), LIGHTHOUSE.y)
	var iron := Color(0.2, 0.22, 0.25)
	k.cyl(base + Vector3(0, -0.15, 0), 0.95 * S, 0.4, Color(0.7, 0.69, 0.66), {"seg": 18})
	var h := 2.6 * S
	k.cyl(base + Vector3(0, h * 0.5, 0), 0.5 * S, h, WHITE, {"top": 0.76, "seg": 18, "gloss": 0.2})
	# a red band round the tower, as on many Japanese lighthouses
	k.cyl(base + Vector3(0, h * 0.62, 0), 0.5 * S * 0.86 + 0.01, 0.35 * S, Color(0.82, 0.26, 0.22), {"top": 0.97, "seg": 18, "line": 0.0})
	var top := base + Vector3(0, h, 0)
	k.cyl(top + Vector3(0, 0.05 * S, 0), 0.62 * S, 0.1 * S, WHITE, {"seg": 18})
	for i in 14:
		var a := i * TAU / 14.0
		var r := 0.58 * S
		k.rod(top + Vector3(cos(a) * r, 0.1 * S, sin(a) * r), top + Vector3(cos(a) * r, 0.42 * S, sin(a) * r), 0.016, iron, {"line": 0.0})
	k.torus(top + Vector3(0, 0.42 * S, 0), 0.58 * S, 0.025, iron, {"line": 0.0})
	k.cyl(top + Vector3(0, 0.38 * S, 0), 0.34 * S, 0.56 * S, Color(0.85, 0.95, 1.0), {"seg": 18, "gloss": 0.9, "emit": 0.25, "line": 0.5})
	k.cyl(top + Vector3(0, 0.38 * S, 0), 0.14 * S, 0.3 * S, Color(1.0, 0.92, 0.6), {"seg": 10, "emit": 0.8, "line": 0.0})
	k.cyl(top + Vector3(0, 0.71 * S, 0), 0.4 * S, 0.1 * S, iron, {"seg": 18})
	k.ball(top + Vector3(0, 0.78 * S, 0), Vector3(0.38, 0.3, 0.38) * S, Color(0.82, 0.26, 0.22), {"seg": 14, "gloss": 0.4})
	k.cyl(top + Vector3(0, 1.12 * S, 0), 0.03 * S, 0.16 * S, iron, {"seg": 6})
	k.ball(top + Vector3(0, 1.22 * S, 0), Vector3.ONE * 0.05 * S, iron, {"seg": 6})
	# a door and small windows facing the steps, on the surface of the tapering tower
	var face := Basis(Vector3.UP, deg_to_rad(-12))
	var out := face * Vector3(1, 0, 0)
	var r0 := 0.5 * S
	k.box(base + out * (r0 - 0.01) + Vector3(0, 0.45 * S, 0), Vector3(0.06, 0.8 * S, 0.4 * S), Color(0.22, 0.32, 0.5), {"basis": face})
	for y in [1.25, 1.95]:
		var ry := r0 * lerpf(1.0, 0.76, y * S / h)
		k.box(base + out * (ry - 0.005) + Vector3(0, y * S, 0), Vector3(0.05, 0.22 * S, 0.14 * S), Color(0.2, 0.25, 0.35), {"basis": face, "line": 0.0})

## A flight of stone steps from the sand to the hill top, set into a cut in the hill
## between two low retaining walls, each tread level and each riser the same height,
## with landings at the foot and the top and a rope rail on posts.
static func _steps_and_viewpoint(k: Kit) -> void:
	var stone := Color(0.74, 0.72, 0.68)
	var wall := Color(0.6, 0.58, 0.55)
	var dir := (STAIR_TO - STAIR_FROM).normalized()
	var length := STAIR_FROM.distance_to(STAIR_TO)
	var yaw := rad_to_deg(atan2(dir.x, dir.y))
	var basis := Basis(Vector3.UP, deg_to_rad(yaw))
	var bottom := SAND_Y
	var top := _stair_level(1.0)
	var count := maxi(int(ceil((top - bottom) / 0.18)), 2)
	var rise := (top - bottom) / count
	var tread := length / count
	var side := Vector2(dir.y, -dir.x)
	for i in count:
		var t := (i + 0.5) / count
		var p := STAIR_FROM.lerp(STAIR_TO, t)
		var y := bottom + rise * (i + 1)
		k.box(Vector3(p.x, (y + bottom - 0.3) * 0.5, p.y), Vector3(1.0, y - bottom + 0.3, tread), stone.darkened(0.05 * (i % 2)), {"basis": basis, "line": 0.7})
	# landings at the foot and the top
	var foot := STAIR_FROM - dir * 0.35
	k.box(Vector3(foot.x, bottom - 0.05, foot.y), Vector3(1.4, 0.14, 0.7), stone, {"basis": basis})
	var head := STAIR_TO + dir * 0.45
	k.box(Vector3(head.x, top - 0.08, head.y), Vector3(1.4, 0.2, 0.9), stone, {"basis": basis})
	# retaining walls along both sides of the cut, their tops stepping with the stairs
	for sgn in [-1.0, 1.0]:
		for i in count:
			var t := (i + 0.5) / count
			var p: Vector2 = STAIR_FROM.lerp(STAIR_TO, t) + side * 0.62 * sgn
			var y := bottom + rise * (i + 1)
			var g := ground(p.x, p.y)
			var h := maxf(g + 0.05, y + 0.22)
			k.box(Vector3(p.x, (h + bottom - 0.3) * 0.5, p.y), Vector3(0.24, h - bottom + 0.3, tread + 0.01), wall.darkened(0.04 * ((i + 1) % 2)), {"basis": basis, "line": 0.5})
	# the rope rail on posts standing on the right-hand wall
	var posts: Array = []
	for i in range(0, count + 1, 3):
		var t := clampf(float(i) / count, 0.04, 0.96)
		var p: Vector2 = STAIR_FROM.lerp(STAIR_TO, t) + side * 0.62
		var y := maxf(ground(p.x, p.y) + 0.05, bottom + rise * clampf(i + 1, 1, count) + 0.22)
		posts.append(Vector3(p.x, y + 0.7, p.y))
		k.rod(Vector3(p.x, y - 0.05, p.y), Vector3(p.x, y + 0.75, p.y), 0.035, WOOD, {"seg": 6})
	for i in posts.size() - 1:
		k.rod(posts[i], posts[i + 1], 0.016, Color(0.85, 0.78, 0.6), {"line": 0.0})
	_viewpoint(k)

## A bench looking out to sea, standing level on the hill top, and a rope fence that
## follows the edge of the cliff in front of it.
static func _viewpoint(k: Kit) -> void:
	var b := Vector3(BENCH.x, ground(BENCH.x, BENCH.y), BENCH.y)
	var face := -20.0   # the sitter looks out to sea, toward the beach
	var basis := Basis(Vector3.UP, deg_to_rad(face))
	var seat_y := 0.46
	# two end frames: a front leg and a back post that runs on up to carry the backrest
	for s in [-0.55, 0.55]:
		var front: Vector3 = b + basis * Vector3(s, 0, 0.16)
		var back: Vector3 = b + basis * Vector3(s, 0, -0.18)
		var gf := ground(front.x, front.z)
		var gb := ground(back.x, back.z)
		k.slab(Vector3(front.x - 0.04, gf - 0.08, front.z - 0.04), Vector3(front.x + 0.04, b.y + seat_y, front.z + 0.04), Color(0.38, 0.38, 0.4))
		k.slab(Vector3(back.x - 0.04, gb - 0.08, back.z - 0.04), Vector3(back.x + 0.04, b.y + 0.98, back.z + 0.04), Color(0.38, 0.38, 0.4))
		k.box(b + basis * Vector3(s, seat_y - 0.03, -0.01), Vector3(0.07, 0.06, 0.42), Color(0.38, 0.38, 0.4), {"basis": basis})
	k.box(b + basis * Vector3(0, seat_y + 0.03, 0), Vector3(1.3, 0.06, 0.42), WOOD, {"basis": basis})
	for y in [0.66, 0.86]:
		k.box(b + basis * Vector3(0, y, -0.2), Vector3(1.3, 0.12, 0.04), WOOD, {"basis": basis})
	# the fence: one even arc in front of the bench, just back from the brow of the cliff
	# (the nearest point where the ground starts to fall away, along any of the rays)
	var start := ground(BENCH.x, BENCH.y)
	var brow := 4.0
	for i in 13:
		var a := deg_to_rad(-60.0 + i * 10.0 + face)
		var out := Vector2(sin(a), cos(a))
		var r := 0.8
		while r < brow:
			var q := Vector2(BENCH.x, BENCH.y) + out * r
			if ground(q.x, q.y) < start - 0.35:
				break
			r += 0.05
		brow = minf(brow, r)
	var radius := maxf(brow - 0.15, 1.4)
	var posts: Array = []
	for i in 9:
		var a := deg_to_rad(-72.0 + i * 18.0 + face)
		var p := Vector2(BENCH.x, BENCH.y) + Vector2(sin(a), cos(a)) * radius
		var y := ground(p.x, p.y)
		posts.append(Vector3(p.x, y + 0.62, p.y))
		k.rod(Vector3(p.x, y - 0.1, p.y), Vector3(p.x, y + 0.68, p.y), 0.035, WOOD, {"seg": 6})
	for i in posts.size() - 1:
		k.rod(posts[i], posts[i + 1], 0.015, Color(0.85, 0.78, 0.6), {"line": 0.0})

## Tide pools: sea water left in the hollows of the shelf, drawn with the same clear
## water as the sea (shaders/konbini_pool.gdshader), with weed, a starfish, shells and
## a crab on the rock.
static func _tide_pools(k: Kit, scene: Node3D) -> void:
	for pool: Vector3 in POOLS:
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE * pool.z * 2.4
		var mat := ShaderMaterial.new()
		mat.shader = POOL
		mat.set_shader_parameter("radius", pool.z)
		var water := MeshInstance3D.new()
		water.name = "TidePool"
		water.mesh = plane
		water.material_override = mat
		water.position = Vector3(pool.x, SEA_Y + 0.09, pool.y)
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scene.add_child(water)
		for j in 3:
			var a := j * 2.1 + pool.x
			var w := Vector2(pool.x + cos(a) * pool.z * 0.55, pool.y + sin(a) * pool.z * 0.55)
			k.ball(Vector3(w.x, ground(w.x, w.y) + 0.02, w.y), Vector3(0.08, 0.03, 0.06), Color(0.3, 0.5, 0.3), {"seg": 6, "line": 0.0})
	# a starfish on the floor of the middle pool, shells and a crab on the shelf
	var star := Vector3(-4.0, ground(-4.0, 4.6) + 0.015, 4.6)
	for i in 5:
		var a := i * TAU / 5.0
		k.box(star + Vector3(cos(a), 0, sin(a)) * 0.07, Vector3(0.14, 0.02, 0.05), Color(0.95, 0.5, 0.3), {"rot": Vector3(0, -rad_to_deg(a), 0), "line": 0.4})
	for s: Vector2 in [Vector2(-5.3, 3.0), Vector2(-3.4, 4.0), Vector2(-7.1, 4.6)]:
		k.ball(Vector3(s.x, ground(s.x, s.y) + 0.02, s.y), Vector3(0.05, 0.03, 0.04), Color(0.95, 0.88, 0.8), {"seg": 6, "line": 0.4})
	var crab := Vector3(-5.6, ground(-5.6, 4.6) + 0.04, 4.6)
	k.ball(crab, Vector3(0.09, 0.04, 0.07), Color(0.85, 0.3, 0.2), {"seg": 8, "line": 0.5})
	for sx in [-1.0, 1.0]:
		k.ball(crab + Vector3(sx * 0.1, 0.0, 0.06), Vector3(0.03, 0.025, 0.025), Color(0.85, 0.3, 0.2), {"seg": 6, "line": 0.4})

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
