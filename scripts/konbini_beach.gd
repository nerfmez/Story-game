extends RefCounted
## A beach on a summer afternoon (layout = "beach"): a road and a row of black pines
## at the back, a sandy beach with a beach hut "Umi no ie Nagisa" selling shaved ice,
## ramune and yakisoba, a boardwalk down to the sea, parasols, a lifeguard tower,
## a shower hut, and the sea taking up the front with waves, foam and glints.
## Gulls circle overhead. Edges: left and right carry the shore, the beach and the
## road on through; the front is open sea; the back is the road.

const Kit := preload("res://scripts/konbini_kit.gd")
const Exterior := preload("res://scripts/konbini_exterior.gd")
const SEA := preload("res://shaders/konbini_sea.gdshader")
const SWASH := preload("res://shaders/konbini_swash.gdshader")
const Foliage := preload("res://scripts/konbini_foliage.gd")

const SAND_Y := 0.12
const SEA_Y := 0.08
const SAND := Color(0.9, 0.76, 0.52)
const WET_SAND := Color(0.72, 0.58, 0.42)
const SAND_CUT := Color(0.66, 0.52, 0.36)
const WOOD := Color(0.72, 0.52, 0.34)
const WOOD_DARK := Color(0.45, 0.3, 0.2)
const WHITE := Color(0.97, 0.97, 0.95)
const TEAL := Color(0.3, 0.72, 0.74)
const RED := Color(0.9, 0.25, 0.25)
const INK := Color(0.08, 0.06, 0.06)

## look-at point, yaw, pitch, distance
const VIEWS := [
	[Vector3(0.0, 0.8, 0.5), -28.0, 30.0, 28.0],     # the whole beach, the sea in front
	[Vector3(-5.1, 1.5, -3.0), 14.0, 9.0, 9.5],       # the beach hut
	[Vector3(0.0, 0.0, 0.0), 30.0, 62.0, 30.0],       # from above
	[Vector3(1.0, 0.6, 3.0), 72.0, 8.0, 10.5],        # along the waterline
	[Vector3(2.4, 0.8, 0.6), -24.0, 15.0, 7.5],       # among the parasols
	[Vector3(0.0, 0.8, 2.5), 180.0, 14.0, 12.5],      # from the road, out to sea
]

## The still-water line; shore() and ground_u() must match
## shaders/konbini_beach.gdshaderinc, which the sea and swash shaders share.
static func shore(x: float) -> float:
	return 3.0 + 0.45 * sin(x * 0.35 + 0.6) + 0.25 * sin(x * 0.93 + 2.0)

## Height of the sand u metres seaward of the still-water line: the flat dry beach,
## a gentle slope down to the water, then a steeper shelf under the sea.
static func ground_u(u: float) -> float:
	if u < -1.0:
		return SAND_Y
	if u < 0.0:
		return SEA_Y - u * 0.04
	if u < 2.0:
		return SEA_Y - u * 0.1
	return maxf(SEA_Y - 0.2 - (u - 2.0) * 0.03, -0.23)

static func ground(x: float, z: float) -> float:
	return ground_u(z - shore(x))

static func build(kit: Kit, scene: Node3D) -> void:
	scene.plate_text = "海の家なぎさ  ·  夏の午後"
	var b := Exterior.new()
	b.k = kit
	b.scene = scene
	if not scene.get_meta("joined", false):
		b._base()
	_ground(kit, b, scene.get_meta("joined", false))
	_sea(kit, scene, not scene.get_meta("joined", false))
	_pines(kit, scene)
	_beach_hut(kit, scene)
	_boardwalk_and_huts(kit)
	_beach_life(kit, scene)
	_lifeguard(kit, scene)
	_gulls(kit, scene)

## joined: built as half of the coast scene (scripts/konbini_coast.gd), which lays the
## road and its wall once along the whole length and leaves out the cut on the seam.
static func _ground(k: Kit, b: RefCounted, joined := false) -> void:
	k.material("asphalt", 3)
	k.material("sand", 3)
	k.flat_materials["sand"] = true
	k.material("siding", 6)
	if not joined:
		k.slab(Vector3(-9, -0.02, -9), Vector3(9, 0.0, -7.3), Color(0.36, 0.38, 0.45), {"mat": "asphalt", "gloss": 0.1})
		k.quad(Vector3(0, 0.004, -8.15), Vector2(18, 0.1), Color(0.95, 0.95, 0.9))
		k.slab(Vector3(-9, -0.02, -7.3), Vector3(9, 0.55, -6.9), Color(0.78, 0.78, 0.8))
		b._rail_run(Vector3(-8.8, 0.55, -7.1), Vector3(-1.4, 0.55, -7.1))
		b._rail_run(Vector3(0.6, 0.55, -7.1), Vector3(8.8, 0.55, -7.1))
		k.slab(Vector3(-9, -0.25, -9), Vector3(9, -0.02, -6.9), Color(0.42, 0.42, 0.47), {"line": 0.4})
	# the flat dry beach, then a height field that slopes down under the sea so the
	# water's edge is wherever the water meets the sand
	k.slab(Vector3(-9, -0.25, -6.9), Vector3(9, -0.06, 0.0), SAND_CUT, {"line": 0.4})
	k.slab(Vector3(-9, -0.06, -6.9), Vector3(9, SAND_Y, 0.0), SAND, {"mat": "sand", "line": 0.0})
	k.grid(-9.0, 0.0, 9.0, 9.0, 90, 60, ground, _sand_color, {"mat": "sand"})
	# the cut through the beach and the sea at the sides and front of the base
	var cuts: Array = []
	for i in 180:
		cuts.append([Vector3(-9.0 + i * 0.1, 0, 9.0), Vector3(-9.0 + (i + 1) * 0.1, 0, 9.0)])
	for i in 90:
		for side in ([9.0] if joined else [-9.0, 9.0]):
			cuts.append([Vector3(side, 0, i * 0.1), Vector3(side, 0, (i + 1) * 0.1)])
	for c in cuts:
		var a: Vector3 = c[0]
		var e: Vector3 = c[1]
		var mid := (a + e) * 0.5
		var g := ground(mid.x, mid.z)
		var lo := Vector3(minf(a.x, e.x) - 0.005, -0.25, minf(a.z, e.z) - 0.005)
		var hi := Vector3(maxf(a.x, e.x) + 0.005, 0.0, maxf(a.z, e.z) + 0.005)
		k.slab(Vector3(lo.x, -0.25, lo.z), Vector3(hi.x, g, hi.z), SAND_CUT, {"line": 0.0})
		if g < SEA_Y - 0.01:
			k.slab(Vector3(lo.x, g, lo.z), Vector3(hi.x, SEA_Y - 0.01, hi.z), Color(0.16, 0.5, 0.72).lerp(Color(0.08, 0.3, 0.58), clampf((SEA_Y - g) / 0.3, 0.0, 1.0)), {"line": 0.0})
	# footprints wandering from the boardwalk to the parasols and the water
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for trail in [[Vector3(0.6, 0, -1.0), Vector3(2.4, 0, 0.4)], [Vector3(0.6, 0, 1.6), Vector3(3.6, 0, 2.6)], [Vector3(-1.4, 0, 0.6), Vector3(-4.5, 0, 1.6)]]:
		var a: Vector3 = trail[0]
		var c: Vector3 = trail[1]
		var steps := int(a.distance_to(c) / 0.3)
		for i in steps:
			var p := a.lerp(c, float(i) / steps) + Vector3(0, 0.003, 0.07 if i % 2 == 0 else -0.07)
			p.y += ground(p.x, p.z)
			k.quad(p, Vector2(0.09, 0.2), SAND * 0.86, {"rot": Vector3(0, rad_to_deg(atan2(c.x - a.x, c.z - a.z)) + rng.randf_range(-8, 8), 0)})

## Dry sand up the beach, darker damp sand near the water, and under the water the
## sand turns wetter and a little green as it gets deeper.
static func _sand_color(x: float, z: float, y: float) -> Color:
	var u := z - shore(x)
	var damp := smoothstep(-0.9, 0.0, u)
	var c := SAND.lerp(WET_SAND, damp * 0.6)
	return c.lerp(Color(0.5, 0.55, 0.45), clampf((SEA_Y - y) / 0.25, 0.0, 1.0) * 0.7)

## The rocks the surf breaks around, each (centre x, z, radius x, z) at the waterline.
static func surf_rocks() -> Array:
	return [Vector4(7.0, 6.0, 0.8, 0.7), Vector4(7.7, 6.5, 0.6, 0.55), Vector4(6.4, 6.6, 0.43, 0.38)]

## planes: false when the coast scene lays one sea over both blocks instead.
static func _sea(k: Kit, scene: Node3D, planes := true) -> void:
	if planes:
		_sea_planes(scene)
	_sea_props(k)

static func _sea_planes(scene: Node3D) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(18, 8.7)
	plane.subdivide_width = 90
	plane.subdivide_depth = 58
	var mat := ShaderMaterial.new()
	mat.shader = SEA
	# the outcrop's three rocks at the waterline, for the surf around them
	mat.set_shader_parameter("rocks", surf_rocks())
	mat.set_shader_parameter("rock_count", 3)
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = plane
	sea.material_override = mat
	sea.position = Vector3(0, 0.0, 4.65)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(sea)
	# the swash: a sheet of water that runs up the sand after each wave and slides back
	var swash_plane := PlaneMesh.new()
	swash_plane.size = Vector2(18, 3.6)
	swash_plane.subdivide_width = 90
	swash_plane.subdivide_depth = 24
	var swash_mat := ShaderMaterial.new()
	swash_mat.shader = SWASH
	swash_mat.render_priority = -1
	var swash := MeshInstance3D.new()
	swash.name = "Swash"
	swash.mesh = swash_plane
	swash.material_override = swash_mat
	swash.position = Vector3(0, 0.0, 2.7)
	swash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(swash)

static func _sea_props(k: Kit) -> void:
	# a line of swimming-area floats and a rocky outcrop with surf around it
	for i in 15:
		k.ball(Vector3(-7.0 + i * 1.0, SEA_Y + 0.04, 7.3), Vector3.ONE * 0.09, Color(1.0, 0.55, 0.15), {"seg": 8, "line": 0.4})
	k.rod(Vector3(-7.2, SEA_Y + 0.05, 7.3), Vector3(7.2, SEA_Y + 0.05, 7.3), 0.01, Color(0.95, 0.95, 0.9), {"line": 0.0})
	for r in [[Vector3(7.0, 0.1, 6.0), Vector3(0.8, 0.55, 0.7)], [Vector3(7.7, 0.05, 6.5), Vector3(0.6, 0.4, 0.55)], [Vector3(6.4, 0.0, 6.6), Vector3(0.45, 0.3, 0.4)]]:
		k.ball(r[0], r[1], Color(0.48, 0.46, 0.48), {"seg": 9, "gloss": 0.3})

## Japanese black pines along the back of the beach, leaning toward the sea: the anime
## trees of scripts/konbini_foliage.gd (smooth painted trunks, flat needle pads made of
## leaf cards with spherized lighting, swaying a little in the sea breeze).
static func _pines(k: Kit, scene: Node3D) -> void:
	var sun := Foliage.sun_from(Vector3(-48, -32, 0))   # the day sun of konbini_diorama.gd
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var i := 0
	# trees at the ends lean inward so no pad hangs off the base; the one by the shower
	# hut stays clear of the view from the road
	for t in [[Vector3(-7.9, SAND_Y, -6.5), 0.45], [Vector3(-5.8, SAND_Y, -6.6), -0.2], [Vector3(-3.4, SAND_Y, -6.5), 0.3], [Vector3(3.3, SAND_Y, -6.45), 0.35], [Vector3(5.7, SAND_Y, -6.5), -0.15], [Vector3(7.8, SAND_Y, -6.3), -0.5]]:
		Foliage.pine(k, scene, t[0], rng.randf_range(0.95, 1.1), {"sun_dir": sun, "seed": 40 + i, "lean": t[1], "name": "Pine%d" % i})
		i += 1

static func _beach_hut(k: Kit, scene: Node3D) -> void:
	var x0 := -7.8
	var x1 := -2.4
	var z0 := -5.8
	var z1 := -1.8
	k.slab(Vector3(x0, SAND_Y, z0), Vector3(x1, 0.5, z1), WOOD, {"mat": "wood"})
	for i in 6:
		k.box(Vector3(x1 - 0.3 - i * 0.9, 0.32, z1 + 0.25), Vector3(0.8, 0.06, 0.5), WOOD * 0.95)
	for x in [x0 + 0.1, (x0 + x1) * 0.5, x1 - 0.1]:
		for z in [z0 + 0.1, z1 - 0.1]:
			k.box(Vector3(x, 1.75, z), Vector3(0.14, 2.5, 0.14), WOOD_DARK)
	# back wall with the kitchen, the slanted teal roof
	k.slab(Vector3(x0, 0.5, z0), Vector3(x1, 3.0, z0 + 0.12), Color(0.9, 0.86, 0.78))
	var roof := Basis(Vector3.RIGHT, deg_to_rad(9))
	k.box(Vector3((x0 + x1) * 0.5, 3.2, (z0 + z1) * 0.5 + 0.2), Vector3(x1 - x0 + 0.6, 0.1, z1 - z0 + 1.2), TEAL, {"basis": roof, "mat": "siding", "gloss": 0.3})
	k.box(Vector3((x0 + x1) * 0.5, 3.07, z1 + 0.55), Vector3(x1 - x0 + 0.6, 0.3, 0.06), WHITE, {"basis": roof})
	k.text("海の家  なぎさ", Vector3((x0 + x1) * 0.5, 3.07, z1 + 0.6), 0.22, Color(0.15, 0.4, 0.7), {"jp": true})
	# counter with the shaved-ice machine, a cooler of ramune, a griddle
	var cz := z1 - 0.5
	k.slab(Vector3(x0 + 0.3, 0.5, cz - 0.3), Vector3(-5.0, 1.45, cz + 0.3), WHITE)
	k.slab(Vector3(x0 + 0.3, 1.0, cz + 0.3), Vector3(-5.0, 1.12, cz + 0.31), RED, {"line": 0.0})
	k.slab(Vector3(x0 + 0.25, 1.45, cz - 0.35), Vector3(-4.95, 1.5, cz + 0.35), WOOD)
	var ice := Vector3(-7.0, 1.5, cz)
	k.box(ice + Vector3(0, 0.25, 0), Vector3(0.35, 0.5, 0.35), Color(0.55, 0.75, 0.95), {"gloss": 0.5})
	k.cyl(ice + Vector3(0.22, 0.4, 0), 0.12, 0.04, Color(0.85, 0.2, 0.2), {"rot": Vector3(0, 0, 90), "seg": 12})
	for i in 3:
		var cup := Vector3(-6.5 + i * 0.25, 1.5, cz + 0.12)
		k.cyl(cup + Vector3(0, 0.06, 0), 0.06, 0.12, WHITE, {"top": 1.3, "seg": 10})
		k.ball(cup + Vector3(0, 0.15, 0), Vector3(0.07, 0.06, 0.07), [Color(0.95, 0.3, 0.35), Color(0.4, 0.75, 0.3), Color(0.35, 0.6, 0.95)][i], {"seg": 8})
	var cooler := Vector3(-5.6, 0.5, cz - 0.05)
	k.box(cooler + Vector3(0, 0.3, 0), Vector3(0.7, 0.6, 0.45), Color(0.3, 0.55, 0.85), {"gloss": 0.5})
	for i in 5:
		k.cyl(cooler + Vector3(-0.24 + i * 0.12, 0.68, 0), 0.03, 0.18, Color(0.6, 0.85, 0.95), {"seg": 8, "gloss": 0.9, "line": 0.3})
	k.box(Vector3(-6.2, 1.55, z0 + 0.5), Vector3(0.9, 0.1, 0.6), Color(0.2, 0.2, 0.22), {"gloss": 0.5})
	k.ball(Vector3(-6.2, 1.62, z0 + 0.5), Vector3(0.35, 0.05, 0.22), Color(0.75, 0.5, 0.25), {"seg": 8})
	scene.add_steam(Vector3(-6.2, 1.62, z0 + 0.5), Vector2(0.6, 0.9), 0.25)
	# menu board on the back wall, shelves of snacks
	k.box(Vector3(-4.3, 2.2, z0 + 0.14), Vector3(1.6, 0.9, 0.04), Color(0.12, 0.17, 0.15))
	k.text("かき氷\nラムネ\n焼きそば", Vector3(-4.3, 2.2, z0 + 0.17), 0.14, Color(0.97, 0.97, 0.92), {"jp": true})
	for y in [1.4, 1.8]:
		k.slab(Vector3(x0 + 0.3, y, z0 + 0.12), Vector3(-5.4, y + 0.04, z0 + 0.4), WOOD_DARK)
		for i in 6:
			k.box(Vector3(x0 + 0.5 + i * 0.32, y + 0.14, z0 + 0.26), Vector3(0.22, 0.24, 0.16), [Color(1.0, 0.6, 0.2), Color(0.95, 0.35, 0.4), Color(0.4, 0.7, 0.95), Color(0.98, 0.85, 0.3)][i % 4])
	# tables and benches on the deck, rental rings on a post
	for tx in [-4.4, -3.1]:
		k.box(Vector3(tx, 1.0, -3.6), Vector3(0.9, 0.06, 1.3), WOOD)
		k.box(Vector3(tx, 0.75, -3.6), Vector3(0.1, 0.5, 0.1), WOOD_DARK)
		for s in [-0.6, 0.6]:
			k.box(Vector3(tx + s, 0.75, -3.6), Vector3(0.3, 0.05, 1.2), WOOD_DARK)
	for i in 4:
		k.torus(Vector3(x1 + 0.12, 2.3 - i * 0.42, z1 - 1.2), 0.24, 0.08, [Color(1.0, 0.45, 0.6), Color(0.35, 0.75, 1.0), Color(1.0, 0.85, 0.2), Color(0.4, 0.85, 0.5)][i], {"rot": Vector3(0, 0, 90), "gloss": 0.7})
	k.box(Vector3(x1 + 0.13, 2.65, z1 - 1.2), Vector3(0.02, 0.18, 0.5), WHITE)
	k.text("うきわ", Vector3(x1 + 0.145, 2.65, z1 - 1.2), 0.1, RED, {"jp": true, "rot": Vector3(0, 90, 0)})
	# the shaved-ice flag on its pole, swaying
	var pole := Vector3(-2.0, SAND_Y, -1.4)
	k.rod(pole, pole + Vector3(0, 2.6, 0), 0.03, WOOD_DARK)
	var flag := Node3D.new()
	flag.name = "IceFlag"
	flag.position = pole + Vector3(0.05, 2.55, 0)
	flag.set_meta("amp", 0.08)
	flag.set_meta("speed", 2.2)
	flag.set_meta("phase", 0.0)
	scene.add_child(flag)
	scene.sway_nodes.append(flag)
	k.box(Vector3(0.36, -0.42, 0), Vector3(0.7, 0.8, 0.02), WHITE, {"node": flag})
	k.box(Vector3(0.36, -0.75, 0.012), Vector3(0.7, 0.14, 0.004), Color(0.3, 0.55, 0.95), {"node": flag, "line": 0.0})
	k.text("氷", Vector3(0.36, -0.36, 0.014), 0.42, RED, {"node": flag, "jp": true})

static func _boardwalk_and_huts(k: Kit) -> void:
	for i in 31:
		var z := -6.9 + i * 0.3
		k.box(Vector3(-0.4, SAND_Y + 0.05, z), Vector3(1.5, 0.06, 0.26), WOOD, {"line": 0.3})
	for z in [-6.8, -2.0, 2.0]:
		k.box(Vector3(-0.4, SAND_Y + 0.02, z), Vector3(1.6, 0.04, 0.1), WOOD_DARK, {"line": 0.0})
	for i in 3:
		k.box(Vector3(-0.4, 0.2 + i * 0.13, -7.15 - i * 0.18), Vector3(1.5, 0.08, 0.2), Color(0.78, 0.78, 0.8))
	# shower hut with a foot-wash tap, surfboards leaning on it
	var h := Vector3(3.6, SAND_Y, -5.0)
	k.box(h + Vector3(0, 1.1, 0), Vector3(2.0, 2.2, 1.6), WHITE)
	k.box(h + Vector3(0, 2.25, 0), Vector3(2.2, 0.1, 1.8), Color(0.3, 0.55, 0.85))
	for x in [-0.5, 0.5]:
		k.box(h + Vector3(x, 0.9, 0.81), Vector3(0.7, 1.7, 0.02), Color(0.3, 0.55, 0.85), {"line": 0.4})
	k.rod(h + Vector3(1.3, 0, 0.5), h + Vector3(1.3, 2.0, 0.5), 0.03, Color(0.7, 0.72, 0.76))
	k.rod(h + Vector3(1.3, 2.0, 0.5), h + Vector3(1.0, 2.0, 0.5), 0.025, Color(0.7, 0.72, 0.76))
	k.cyl(h + Vector3(0.98, 1.95, 0.5), 0.07, 0.04, Color(0.7, 0.72, 0.76), {"seg": 10})
	for i in 2:
		var board := h + Vector3(-1.3 - i * 0.25, 1.0, 0.4 + i * 0.3)
		k.box(board, Vector3(0.08, 2.0, 0.5), [Color(0.98, 0.6, 0.3), Color(0.4, 0.8, 0.85)][i], {"rot": Vector3(0, 0, -12), "gloss": 0.6})

static func _parasol(k: Kit, scene: Node3D, at: Vector3, color: Color) -> void:
	var top := at + Vector3(0.1, 2.2, 0.05)
	k.rod(at, top, 0.025, WHITE)
	k.cyl(top + Vector3(0, -0.12, 0), 1.15, 0.38, color, {"top": 0.05, "seg": 8, "gloss": 0.3})
	for i in 4:
		var a := i * PI * 0.5 + PI / 8.0
		k.prism(top + Vector3(cos(a) * 0.55, -0.11, sin(a) * 0.55), Vector3(0.42, 0.36, 0.01), WHITE, {"basis": Basis(Vector3.UP, -a + PI * 0.5) * Basis(Vector3.RIGHT, deg_to_rad(-71)), "line": 0.0})
	k.ball(top + Vector3(0, 0.1, 0), Vector3.ONE * 0.06, WHITE, {"seg": 8})

static func _beach_life(k: Kit, scene: Node3D) -> void:
	var spots := [[Vector3(2.2, SAND_Y, 0.6), Color(0.92, 0.32, 0.38)], [Vector3(4.6, SAND_Y, -0.6), Color(0.98, 0.78, 0.25)], [Vector3(-4.9, SAND_Y, 1.0), Color(0.3, 0.6, 0.92)], [Vector3(5.4, SAND_Y, 1.9), Color(0.4, 0.8, 0.55)]]
	for s in spots:
		var at: Vector3 = s[0]
		_parasol(k, scene, at, s[1])
		k.quad(at + Vector3(0.6, 0.004, 0.3), Vector2(0.8, 1.7), (s[1] as Color).lightened(0.5), {"rot": Vector3(0, 15, 0)})
		k.quad(at + Vector3(0.6, 0.006, 0.3), Vector2(0.8, 0.2), WHITE, {"rot": Vector3(0, 15, 0)})
	# a cooler, sandals and a book on the mats, a sand castle, a bucket, a beach ball
	k.box(Vector3(2.9, SAND_Y + 0.18, 1.6), Vector3(0.5, 0.36, 0.34), Color(0.3, 0.55, 0.9), {"gloss": 0.5})
	k.box(Vector3(2.9, SAND_Y + 0.38, 1.6), Vector3(0.52, 0.06, 0.36), WHITE)
	for sx in [-0.08, 0.08]:
		k.box(Vector3(1.6 + sx, SAND_Y + 0.015, 1.3), Vector3(0.1, 0.03, 0.24), Color(1.0, 0.45, 0.55))
	k.box(Vector3(2.75, SAND_Y + 0.02, 0.2), Vector3(0.3, 0.03, 0.22), Color(0.95, 0.9, 0.8), {"rot": Vector3(0, 30, 0)})
	var castle := Vector3(0.9, SAND_Y, 1.9)
	k.cyl(castle + Vector3(0, 0.12, 0), 0.32, 0.24, SAND * 0.9, {"seg": 10, "top": 0.85})
	for a in 4:
		var t := castle + Vector3(cos(a * PI * 0.5) * 0.24, 0.34, sin(a * PI * 0.5) * 0.24)
		k.cyl(t, 0.08, 0.2, SAND * 0.9, {"seg": 8})
	k.cyl(castle + Vector3(0, 0.4, 0), 0.12, 0.3, SAND * 0.9, {"seg": 8, "top": 0.2})
	k.cyl(castle + Vector3(0.55, 0.12, 0.2), 0.12, 0.22, Color(0.95, 0.3, 0.3), {"top": 1.3, "seg": 10, "gloss": 0.5})
	k.rod(castle + Vector3(-0.5, 0.0, 0.1), castle + Vector3(-0.3, 0.25, 0.25), 0.015, Color(0.98, 0.8, 0.2))
	var ball := Vector3(1.6, ground(1.6, 2.3) + 0.21, 2.3)
	k.ball(ball, Vector3.ONE * 0.22, WHITE, {"seg": 10, "gloss": 0.5})
	k.ball(ball + Vector3(0, 0.003, 0), Vector3(0.223, 0.223, 0.12), Color(0.95, 0.3, 0.35), {"seg": 10, "line": 0.0})
	k.ball(ball + Vector3(0, 0.003, 0), Vector3(0.12, 0.223, 0.223), Color(0.3, 0.6, 0.95), {"seg": 10, "line": 0.0})
	# a surfboard lying where the boardwalk ends
	k.box(Vector3(-1.2, SAND_Y + 0.04, 2.0), Vector3(0.5, 0.06, 1.9), Color(0.98, 0.95, 0.9), {"rot": Vector3(0, 35, 0), "gloss": 0.6})
	k.box(Vector3(-1.2, SAND_Y + 0.075, 2.0), Vector3(0.08, 0.01, 1.8), RED, {"rot": Vector3(0, 35, 0), "line": 0.0})

## A white lifeguard tower: four splayed legs braced on the sand, a platform with a
## rail, a chair under a yellow parasol, a ladder whose rails run from the sand to
## the platform edge, a flag on the front corner and a rescue board on the sand.
static func _lifeguard(k: Kit, scene: Node3D) -> void:
	var at := Vector3(7.3, SAND_Y, 0.4)
	var deck := 1.9
	var foot := 0.62
	var top := 0.45
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		k.rod(at + Vector3(c.x * foot, 0, c.y * foot), at + Vector3(c.x * top, deck, c.y * top), 0.05, WHITE)
		k.box(at + Vector3(c.x * foot, 0.02, c.y * foot), Vector3(0.18, 0.04, 0.18), WHITE * 0.9)
	# a cross brace on each side and a ring of rails halfway up
	var mid := 0.95
	var mw := lerpf(foot, top, mid / deck)
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for i in 4:
		var c0: Vector2 = corners[i]
		var c1: Vector2 = corners[(i + 1) % 4]
		k.rod(at + Vector3(c0.x * mw, mid, c0.y * mw), at + Vector3(c1.x * mw, mid, c1.y * mw), 0.03, WHITE)
		k.rod(at + Vector3(c0.x * foot * 0.97, 0.12, c0.y * foot * 0.97), at + Vector3(c1.x * mw, mid, c1.y * mw), 0.022, WHITE, {"line": 0.5})
	k.box(at + Vector3(0, deck + 0.04, 0), Vector3(1.2, 0.08, 1.2), WOOD)
	# rail on the sides and front, with a red board on the front
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		k.rod(at + Vector3(c.x * 0.56, deck + 0.08, c.y * 0.56), at + Vector3(c.x * 0.56, deck + 0.6, c.y * 0.56), 0.025, WHITE)
	for side in [[Vector2(-1, -1), Vector2(-1, 1)], [Vector2(1, -1), Vector2(1, 1)], [Vector2(-1, 1), Vector2(1, 1)]]:
		var a: Vector2 = side[0]
		var b: Vector2 = side[1]
		k.rod(at + Vector3(a.x * 0.56, deck + 0.6, a.y * 0.56), at + Vector3(b.x * 0.56, deck + 0.6, b.y * 0.56), 0.025, WHITE)
	k.box(at + Vector3(0, deck + 0.34, 0.57), Vector3(1.0, 0.36, 0.03), RED)
	k.text("監視員", at + Vector3(0, deck + 0.34, 0.59), 0.17, WHITE, {"jp": true})
	# the chair, facing the sea
	var seat := at + Vector3(0, deck + 0.08, -0.1)
	for c in [Vector2(-0.22, -0.18), Vector2(0.22, -0.18), Vector2(-0.22, 0.18), Vector2(0.22, 0.18)]:
		k.rod(seat + Vector3(c.x, 0, c.y), seat + Vector3(c.x, 0.4, c.y), 0.02, WOOD_DARK)
	k.box(seat + Vector3(0, 0.43, 0), Vector3(0.52, 0.06, 0.44), RED)
	k.box(seat + Vector3(0, 0.75, -0.21), Vector3(0.52, 0.55, 0.05), RED, {"rot": Vector3(-8, 0, 0)})
	# the parasol pole is clamped to the back of the chair
	_parasol(k, scene, at + Vector3(-0.1, deck + 0.08, -0.3), Color(0.98, 0.85, 0.2))
	# the ladder on the beach side: two rails from the sand to the deck edge, rungs between them
	var lb := at + Vector3(0, 0, -1.35)
	var lt := at + Vector3(0, deck + 0.06, -0.6)
	for x in [-0.24, 0.24]:
		k.rod(lb + Vector3(x, 0, 0), lt + Vector3(x, 0, 0), 0.03, WHITE)
		k.rod(lt + Vector3(x, 0, 0), lt + Vector3(x, 0.55, 0.06), 0.025, WHITE)
	var rungs := 6
	for i in rungs:
		var p := lb.lerp(lt, (i + 1.0) / (rungs + 1.0))
		k.rod(p + Vector3(-0.24, 0, 0), p + Vector3(0.24, 0, 0), 0.022, WHITE, {"line": 0.5})
	k.box(lt + Vector3(0, -0.02, 0.0), Vector3(0.48, 0.05, 0.12), WOOD)
	# flag on the front corner
	var fp := at + Vector3(0.56, deck + 0.6, 0.56)
	k.rod(fp, fp + Vector3(0, 1.2, 0), 0.02, WHITE)
	var flag := Node3D.new()
	flag.name = "LifeguardFlag"
	flag.position = fp + Vector3(0, 1.18, 0)
	flag.set_meta("amp", 0.1)
	flag.set_meta("speed", 2.6)
	flag.set_meta("phase", 1.0)
	scene.add_child(flag)
	scene.sway_nodes.append(flag)
	k.box(Vector3(0.3, -0.18, 0), Vector3(0.6, 0.36, 0.02), RED, {"node": flag})
	k.box(Vector3(0.3, -0.27, 0.012), Vector3(0.6, 0.18, 0.004), Color(1.0, 0.85, 0.2), {"node": flag, "line": 0.0})
	# a red rescue board lying on the sand beside the tower, a rescue tube on it
	k.box(at + Vector3(1.2, 0.045, 0.2), Vector3(0.45, 0.07, 1.9), RED, {"rot": Vector3(0, 8, 0), "gloss": 0.5})
	k.box(at + Vector3(1.2, 0.082, 0.2), Vector3(0.06, 0.006, 1.7), WHITE, {"rot": Vector3(0, 8, 0), "line": 0.0})
	k.box(at + Vector3(1.22, 0.13, 0.3), Vector3(0.16, 0.1, 0.75), Color(1.0, 0.5, 0.15), {"rot": Vector3(0, 25, 0), "gloss": 0.5})

static func _gulls(k: Kit, scene: Node3D) -> void:
	var gulls: Array[Node3D] = []
	for i in 3:
		var gull := Node3D.new()
		gull.name = "Gull%d" % i
		scene.add_child(gull)
		for side in [-1.0, 1.0]:
			var wing := Node3D.new()
			wing.name = "Wing"
			wing.set_meta("side", side)
			gull.add_child(wing)
			k.box(Vector3(side * 0.28, 0, 0), Vector3(0.56, 0.02, 0.16), WHITE, {"node": wing, "line": 0.6})
		k.ball(Vector3.ZERO, Vector3(0.07, 0.06, 0.18), WHITE, {"node": gull, "seg": 8})
		gulls.append(gull)
	scene.set_meta("gulls", gulls)

## Gulls circle over the sea, flapping now and then.
static func animate(scene: Node3D, clock: float) -> void:
	var gulls: Array = scene.get_meta("gulls")
	for i in gulls.size():
		var gull: Node3D = gulls[i]
		var r := 3.0 + i * 1.2
		var a := clock * (0.35 + i * 0.07) + i * 2.1
		gull.position = Vector3(cos(a) * r + (i - 1) * 2.0, 5.2 + i * 0.8 + sin(clock * 0.7 + i) * 0.3, 5.0 + sin(a) * r * 0.5)
		gull.rotation.y = -a
		var flap := sin(clock * 9.0 + i) * 0.5 if fmod(clock + i * 1.7, 5.0) < 1.6 else 0.15
		for wing in gull.get_children():
			if wing.has_meta("side"):
				wing.rotation.z = flap * float(wing.get_meta("side"))

static func lights(_scene: Node3D) -> void:
	pass
