extends RefCounted
## Everything outside the shop: the square base, the corner of two narrow roads,
## the shop shell and the street furniture around it.
## Units are metres. The base spans -9..9 on X and Z; roads run along +Z (road A)
## and +X (road B) and meet at the far corner, the shop stands in the middle.

const Kit := preload("res://scripts/konbini_kit.gd")

const LOT := 0.12          # top of the raised lot and sidewalks (road top is 0)
const FLOOR := 0.2         # shop floor
const SHOP_X := Vector2(-5.0, 2.4)
const SHOP_Z := Vector2(-5.2, 0.0)

const WOOD := Color(0.33, 0.2, 0.14)
const BRASS := Color(0.85, 0.66, 0.32)
const SOIL := Color(0.3, 0.24, 0.24)
const ASPHALT := Color(0.16, 0.17, 0.25)
const LOT_TOP := Color(0.22, 0.23, 0.31)
const CONCRETE := Color(0.34, 0.35, 0.42)
const PAVER := Color(0.46, 0.4, 0.46)
const CURB := Color(0.58, 0.6, 0.68)
const PAINT := Color(0.86, 0.88, 0.94)
const WALL := Color(0.88, 0.89, 0.93)
const TRIM := Color(0.2, 0.23, 0.3)
const TEAL := Color(0.08, 0.66, 0.64)
const ORANGE := Color(1.0, 0.55, 0.24)
const POLE := Color(0.66, 0.66, 0.7)
const WIRE := Color(0.07, 0.07, 0.11)
const RAIL := Color(0.9, 0.92, 0.96)

var k: Kit
var scene: Node3D

static func build(kit: Kit, diorama: Node3D) -> void:
	var b := new()
	b.k = kit
	b.scene = diorama
	b._base()
	b._roads()
	b._lot()
	b._shop_shell()
	b._shop_front()
	b._side_yard()
	b._alley()
	b._neighbour()
	b._back()
	b._poles_and_wires()
	b._street_lamp()
	b._guard_rails()
	b._signs()
	b._traffic_signals()

# --- base and ground -------------------------------------------------------------

func _base() -> void:
	k.material("wood", 4)
	k.slab(Vector3(-9.45, -1.0, -9.45), Vector3(9.45, -0.92, 9.45), Color(0.18, 0.11, 0.08), {"mat": "wood"})
	k.slab(Vector3(-9.38, -0.92, -9.38), Vector3(9.38, -0.25, 9.38), WOOD, {"mat": "wood", "gloss": 0.25})
	k.slab(Vector3(-9.41, -0.33, -9.41), Vector3(9.41, -0.29, 9.41), BRASS, {"gloss": 0.7, "line": 0.5})
	k.slab(Vector3(-9.0, -0.25, -9.0), Vector3(9.0, -0.06, 9.0), SOIL)
	k.slab(Vector3(-9.0, -0.06, -9.0), Vector3(9.0, -0.02, 9.0), Color(0.42, 0.42, 0.47), {"line": 0.4})
	# name plate on the front of the plinth
	k.box(Vector3(0, -0.6, 9.4), Vector3(2.6, 0.32, 0.04), BRASS, {"gloss": 0.8})
	k.text("HOSHI MART  ·  RAINY NIGHT", Vector3(0, -0.6, 9.425), 0.12, Color(0.25, 0.16, 0.1))

func _roads() -> void:
	k.material("asphalt", 3)
	k.material("paver", 1)
	var wet := {"mat": "asphalt", "gloss": 0.85, "line": 0.6}
	k.slab(Vector3(-9, -0.02, 5.2), Vector3(9, 0.0, 8.6), ASPHALT, wet)
	k.slab(Vector3(5.2, -0.02, -9), Vector3(8.6, 0.0, 5.2), ASPHALT, wet)
	# far sidewalks: just a sliver so the roads read as streets with another side
	var pave := {"mat": "paver", "gloss": 0.55}
	k.slab(Vector3(-9, -0.02, 8.75), Vector3(9, LOT, 9), PAVER, pave)
	k.slab(Vector3(8.75, -0.02, -9), Vector3(9, LOT, 8.75), PAVER, pave)
	k.slab(Vector3(-9, -0.02, 8.6), Vector3(9, LOT + 0.01, 8.75), CURB, {"gloss": 0.5})
	k.slab(Vector3(8.6, -0.02, -9), Vector3(8.75, LOT + 0.01, 8.6), CURB, {"gloss": 0.5})
	var paint := {"gloss": 0.75}
	# edge lines
	_line(Vector3(-9, 0, 5.82), Vector3(0.7, 0, 5.82), 0.12, paint)
	_line(Vector3(-9, 0, 8.25), Vector3(4.9, 0, 8.25), 0.12, paint)
	_line(Vector3(5.82, 0, -9), Vector3(5.82, 0, 0.5), 0.12, paint)
	_line(Vector3(8.25, 0, -9), Vector3(8.25, 0, 0.5), 0.12, paint)
	# zebra crossings over both roads, stop lines before them
	for i in 4:
		k.quad(Vector3(2.8, 0.004, 5.6 + i * 0.9), Vector2(3.0, 0.45), PAINT, paint)
		k.quad(Vector3(5.6 + i * 0.9, 0.004, 2.5), Vector2(0.45, 3.0), PAINT, paint)
	_line(Vector3(0.75, 0, 5.95), Vector3(0.75, 0, 6.85), 0.3, paint)
	_line(Vector3(6.95, 0, 0.6), Vector3(8.15, 0, 0.6), 0.3, paint)
	# diamond: crossing ahead
	var c := Vector3(-4.6, 0.004, 6.4)
	for corner in [[Vector3(-1.1, 0, 0), Vector3(0, 0, -0.38)], [Vector3(0, 0, -0.38), Vector3(1.1, 0, 0)], [Vector3(1.1, 0, 0), Vector3(0, 0, 0.38)], [Vector3(0, 0, 0.38), Vector3(-1.1, 0, 0)]]:
		_line(c + corner[0], c + corner[1], 0.1, paint)
	# gutters with grated covers along both kerbs
	k.slab(Vector3(-9, -0.02, 5.2), Vector3(5.2, 0.006, 5.5), Color(0.4, 0.41, 0.48), {"gloss": 0.6, "line": 0.3})
	k.slab(Vector3(5.2, -0.02, -9), Vector3(5.5, 0.006, 5.2), Color(0.4, 0.41, 0.48), {"gloss": 0.6, "line": 0.3})
	for i in 6:
		_grate(Vector3(-7.8 + i * 2.4, 0.008, 5.35), false)
		_grate(Vector3(5.35, 0.008, -7.8 + i * 2.4), true)
	# manhole
	k.cyl(Vector3(-1.6, 0.004, 7.2), 0.34, 0.012, Color(0.2, 0.2, 0.26), {"seg": 20, "gloss": 0.8, "line": 0.5})
	k.torus(Vector3(-1.6, 0.012, 7.2), 0.25, 0.012, Color(0.3, 0.3, 0.36), {"line": 0.0})
	k.torus(Vector3(-1.6, 0.012, 7.2), 0.13, 0.01, Color(0.3, 0.3, 0.36), {"line": 0.0})

func _line(a: Vector3, b: Vector3, width: float, opts: Dictionary) -> void:
	var d := b - a
	var o := opts.duplicate()
	o["rot"] = Vector3(0, rad_to_deg(atan2(-d.z, d.x)), 0)
	k.quad((a + b) * 0.5 + Vector3(0, 0.004, 0), Vector2(d.length(), width), PAINT, o)

func _grate(center: Vector3, along_z: bool) -> void:
	var size := Vector3(0.28, 0.012, 0.6) if along_z else Vector3(0.6, 0.012, 0.28)
	k.box(center, size, Color(0.13, 0.13, 0.17), {"gloss": 0.7, "line": 0.5})
	for j in 7:
		var off := -0.24 + j * 0.08
		var p := center + (Vector3(0, 0.007, off) if along_z else Vector3(off, 0.007, 0))
		k.quad(p, Vector2(0.22, 0.025) if along_z else Vector2(0.025, 0.22), Color(0.03, 0.03, 0.05))

func _lot() -> void:
	var pave := {"mat": "paver", "gloss": 0.55}
	k.slab(Vector3(-9, -0.02, 4.0), Vector3(5.05, LOT, 5.05), PAVER, pave)
	k.slab(Vector3(4.0, -0.02, -9), Vector3(5.05, LOT, 4.0), PAVER, pave)
	k.slab(Vector3(-9, -0.02, 5.05), Vector3(5.2, LOT + 0.015, 5.2), CURB, {"gloss": 0.5})
	k.slab(Vector3(5.05, -0.02, -9), Vector3(5.2, LOT + 0.015, 5.05), CURB, {"gloss": 0.5})
	var lot := {"mat": "asphalt", "gloss": 0.8}
	k.slab(Vector3(-6.6, -0.02, 0.0), Vector3(4.0, LOT, 4.0), LOT_TOP, lot)
	k.slab(Vector3(2.4, -0.02, -9), Vector3(4.0, LOT, 0.0), LOT_TOP, lot)
	var concrete := {"gloss": 0.6}
	k.slab(Vector3(-6.6, -0.02, -9), Vector3(-5.0, LOT, 0.0), CONCRETE, concrete)
	k.slab(Vector3(-5.0, -0.02, -9), Vector3(2.4, LOT, -5.2), CONCRETE, concrete)
	k.slab(Vector3(-9, -0.02, -9), Vector3(-6.6, LOT, 4.0), Color(0.3, 0.33, 0.36), concrete)
	k.slab(Vector3(SHOP_X.x, -0.02, SHOP_Z.x), Vector3(SHOP_X.y, FLOOR - 0.01, SHOP_Z.y), Color(0.55, 0.56, 0.62))
	# parking bays in front of the windows, wheel stops
	var paint := {"gloss": 0.7}
	for x in [-4.9, -2.45, 0.0]:
		k.quad(Vector3(x, LOT + 0.004, 2.75), Vector2(0.1, 2.3), PAINT, paint)
	for x in [-3.675, -1.225]:
		for side in [-0.45, 0.45]:
			k.box(Vector3(x + side, LOT + 0.05, 2.0), Vector3(0.55, 0.1, 0.13), Color(0.62, 0.62, 0.66), {"gloss": 0.4})
			k.box(Vector3(x + side, LOT + 0.101, 2.0), Vector3(0.12, 0.002, 0.131), Color(0.95, 0.8, 0.2), {"line": 0.0})

# --- shop ------------------------------------------------------------------------------

func _shop_shell() -> void:
	var x0 := SHOP_X.x
	var x1 := SHOP_X.y
	var z0 := SHOP_Z.x
	k.material("siding", 6)
	var wall := {"mat": "siding"}
	# left (alley) and back walls are solid
	k.slab(Vector3(x0, FLOOR - 0.01, z0), Vector3(x0 + 0.15, 3.25, -0.2), WALL, wall)
	k.slab(Vector3(x0 + 0.15, FLOOR - 0.01, z0), Vector3(x1, 3.25, z0 + 0.15), WALL, wall)
	# right wall: solid behind the vending machines, glass toward the corner
	k.slab(Vector3(x1 - 0.15, FLOOR - 0.01, z0 + 0.15), Vector3(x1, 3.25, -2.75), WALL, wall)
	# front: corner posts, kick plates, mullions, door, spandrel
	k.slab(Vector3(x0, FLOOR - 0.01, -0.2), Vector3(x0 + 0.2, 3.25, 0.0), TRIM, {"gloss": 0.4})
	k.slab(Vector3(1.6, FLOOR - 0.01, -0.15), Vector3(x1, 2.7, 0.0), WALL, wall)
	k.slab(Vector3(x1 - 0.2, FLOOR - 0.01, -0.2), Vector3(x1, 3.25, 0.0), TRIM, {"gloss": 0.4})
	var kick := Color(0.2, 0.4, 0.48)
	k.slab(Vector3(x0 + 0.2, FLOOR - 0.01, -0.15), Vector3(-0.1, 0.55, 0.0), kick, {"gloss": 0.5})
	k.slab(Vector3(x1 - 0.15, FLOOR - 0.01, -2.75), Vector3(x1, 0.55, -0.2), kick, {"gloss": 0.5})
	for x in [-4.8, -3.55, -2.3, -1.05, -0.16]:
		k.box(Vector3(x, 1.6, -0.07), Vector3(0.08, 2.1, 0.1), TRIM, {"gloss": 0.5})
	for z in [-2.75, -1.48, -0.2]:
		k.box(Vector3(x1 - 0.07, 1.6, z), Vector3(0.1, 2.1, 0.08), TRIM, {"gloss": 0.5})
	k.slab(Vector3(x0 + 0.2, 2.6, -0.13), Vector3(1.6, 2.72, -0.01), TRIM, {"gloss": 0.5})
	k.slab(Vector3(x1 - 0.13, 2.6, -2.75), Vector3(x1 - 0.01, 2.72, -0.2), TRIM, {"gloss": 0.5})
	k.slab(Vector3(-0.1, 2.45, -0.13), Vector3(1.6, 2.6, -0.01), TRIM, {"gloss": 0.5})
	k.slab(Vector3(-0.12, FLOOR - 0.01, -0.13), Vector3(1.6, FLOOR + 0.01, -0.03), Color(0.5, 0.52, 0.58), {"gloss": 0.7, "line": 0.3})
	k.slab(Vector3(x0, 2.72, -0.15), Vector3(x1, 3.25, 0.0), WALL, wall)
	k.slab(Vector3(x1 - 0.15, 2.72, -2.75), Vector3(x1, 3.25, -0.15), WALL, wall)
	# roof block, parapet coping and rooftop plant
	k.slab(Vector3(x0, 3.25, z0), Vector3(x1, 4.05, 0.0), Color(0.78, 0.79, 0.84), wall)
	var coping := Color(0.55, 0.57, 0.64)
	k.slab(Vector3(x0 - 0.03, 4.05, z0 - 0.03), Vector3(x1 + 0.03, 4.18, z0 + 0.12), coping, {"gloss": 0.6})
	k.slab(Vector3(x0 - 0.03, 4.05, -0.12), Vector3(x1 + 0.03, 4.18, 0.03), coping, {"gloss": 0.6})
	k.slab(Vector3(x0 - 0.03, 4.05, z0), Vector3(x0 + 0.12, 4.18, 0.0), coping, {"gloss": 0.6})
	k.slab(Vector3(x1 - 0.12, 4.05, z0), Vector3(x1 + 0.03, 4.18, 0.0), coping, {"gloss": 0.6})
	for i in 2:
		var c := Vector3(-3.6 + i * 1.3, 4.5, -3.8)
		k.box(c, Vector3(1.0, 0.9, 0.7), Color(0.84, 0.85, 0.88), {"gloss": 0.5})
		k.cyl(c + Vector3(0, 0, 0.36), 0.3, 0.02, Color(0.15, 0.16, 0.2), {"rot": Vector3(90, 0, 0), "seg": 16})
		k.torus(c + Vector3(0, 0, 0.37), 0.3, 0.025, Color(0.6, 0.62, 0.68), {"rot": Vector3(90, 0, 0)})
	k.rod(Vector3(-3.6, 4.05, -3.4), Vector3(-3.6, 4.3, -2.6), 0.04, Color(0.85, 0.82, 0.72))
	k.rod(Vector3(1.4, 4.05, -4.3), Vector3(1.4, 4.6, -4.3), 0.07, Color(0.6, 0.62, 0.68), {"seg": 10})
	k.cyl(Vector3(1.4, 4.65, -4.3), 0.12, 0.1, Color(0.6, 0.62, 0.68), {"top": 0.2})
	k.rod(Vector3(0.4, 4.05, -1.5), Vector3(0.4, 5.1, -1.5), 0.012, Color(0.3, 0.3, 0.35))
	# downpipe at the back corner (water pours from its foot, see konbini_weather.gd)
	k.rod(Vector3(x0 - 0.08, 4.1, z0 - 0.08), Vector3(x0 - 0.08, 0.32, z0 - 0.08), 0.05, Color(0.7, 0.72, 0.76), {"seg": 8, "gloss": 0.5})
	k.rod(Vector3(x0 - 0.08, 0.32, z0 - 0.08), Vector3(x0 - 0.3, 0.22, z0 - 0.08), 0.05, Color(0.7, 0.72, 0.76), {"seg": 8, "gloss": 0.5})
	_sign_band()
	_awning()

func _sign_band() -> void:
	var sign := k.material("sign_band")
	scene.sign_band_material = sign
	var lit := {"mat": "sign_band", "emit": 1.0}
	# front band
	k.slab(Vector3(SHOP_X.x - 0.05, 3.25, -0.15), Vector3(SHOP_X.y + 0.05, 4.05, 0.14), Color(0.96, 0.98, 1.0), lit)
	k.slab(Vector3(SHOP_X.x - 0.06, 3.3, 0.14), Vector3(SHOP_X.y + 0.06, 3.42, 0.15), TEAL, lit)
	k.slab(Vector3(SHOP_X.x - 0.06, 3.42, 0.14), Vector3(SHOP_X.y + 0.06, 3.5, 0.15), ORANGE, lit)
	# side band
	k.slab(Vector3(SHOP_X.y - 0.15, 3.25, SHOP_Z.x - 0.05), Vector3(SHOP_X.y + 0.14, 4.05, -0.15), Color(0.96, 0.98, 1.0), lit)
	k.slab(Vector3(SHOP_X.y + 0.14, 3.3, SHOP_Z.x - 0.06), Vector3(SHOP_X.y + 0.15, 3.42, 0.06), TEAL, lit)
	k.slab(Vector3(SHOP_X.y + 0.14, 3.42, SHOP_Z.x - 0.06), Vector3(SHOP_X.y + 0.15, 3.5, 0.06), ORANGE, lit)
	_star(Vector3(-3.55, 3.76, 0.155), 0.26, Basis.IDENTITY, "sign_band")
	_star(Vector3(SHOP_X.y + 0.155, 3.76, -3.9), 0.26, Basis(Vector3.UP, PI * 0.5), "sign_band")
	var ink := Color(0.04, 0.42, 0.44) * 1.4
	k.text("HOSHI MART", Vector3(-0.9, 3.76, 0.16), 0.42, ink, {"outline": 10})
	k.text("HOSHI MART", Vector3(SHOP_X.y + 0.16, 3.76, -2.3), 0.42, ink, {"outline": 10, "rot": Vector3(0, 90, 0)})
	k.text("24H", Vector3(1.75, 3.76, 0.16), 0.3, Color(1.0, 0.45, 0.18) * 1.3, {"outline": 8})

## Five-pointed star logo lying in the plane of the given basis (facing its +Z).
func _star(center: Vector3, radius: float, basis: Basis, mat: String) -> void:
	var gold := Color(1.0, 0.72, 0.18)
	k.cyl(center, radius * 0.42, 0.02, gold, {"basis": basis * Basis(Vector3.RIGHT, PI * 0.5), "seg": 5, "mat": mat, "emit": 1.0, "line": 0.4})
	for i in 5:
		var a := i * TAU / 5.0
		var dir := Vector3(sin(a), cos(a), 0)
		var point_basis := basis * Basis(Vector3.BACK, -a)
		k.prism(center + basis * (dir * radius * 0.6), Vector3(radius * 0.48, radius * 0.62, 0.02), gold, {"basis": point_basis, "mat": mat, "emit": 1.0, "line": 0.4})

func _awning() -> void:
	var metal := Color(0.2, 0.22, 0.3)
	k.slab(Vector3(SHOP_X.x - 0.05, 2.72, 0.0), Vector3(SHOP_X.y + 0.05, 2.84, 1.32), metal, {"gloss": 0.6})
	k.slab(Vector3(SHOP_X.x - 0.06, 2.66, 1.3), Vector3(SHOP_X.y + 0.06, 2.88, 1.4), TEAL * 0.8, {"gloss": 0.6, "emit": 0.15})
	for i in 5:
		k.cyl(Vector3(-4.2 + i * 1.5, 2.713, 0.7), 0.1, 0.014, Color(1.0, 0.95, 0.85), {"emit": 1.0, "line": 0.3})

func _shop_front() -> void:
	# recycling bins, umbrella stand and door mat under the awning
	var bins := [[Color(0.24, 0.45, 0.78), "CANS"], [Color(0.28, 0.62, 0.42), "PET"], [Color(0.55, 0.56, 0.62), "TRASH"]]
	for i in 3:
		var x := -1.4 + i * 0.38
		k.box(Vector3(x, LOT + 0.47, 0.3), Vector3(0.36, 0.94, 0.42), bins[i][0], {"gloss": 0.5})
		k.box(Vector3(x, LOT + 0.96, 0.3), Vector3(0.37, 0.05, 0.43), bins[i][0] * 0.75, {"gloss": 0.5})
		k.cyl(Vector3(x, LOT + 0.8, 0.515), 0.08, 0.01, Color(0.05, 0.05, 0.08), {"rot": Vector3(90, 0, 0), "seg": 14, "line": 0.0})
		k.text(bins[i][1], Vector3(x, LOT + 0.55, 0.516), 0.07, Color(0.95, 0.96, 1.0))
	k.box(Vector3(1.95, LOT + 0.25, 0.28), Vector3(0.42, 0.04, 0.28), Color(0.6, 0.62, 0.68), {"gloss": 0.6})
	for corner in [Vector2(1.75, 0.15), Vector2(2.15, 0.15), Vector2(1.75, 0.41), Vector2(2.15, 0.41)]:
		k.rod(Vector3(corner.x, LOT, corner.y), Vector3(corner.x, LOT + 0.55, corner.y), 0.012, Color(0.6, 0.62, 0.68))
	k.box(Vector3(1.95, LOT + 0.55, 0.28), Vector3(0.42, 0.03, 0.28), Color(0.6, 0.62, 0.68), {"gloss": 0.6})
	var umbrellas := [Color(0.82, 0.9, 0.96), Color(0.2, 0.24, 0.45), Color(0.85, 0.3, 0.35), Color(0.8, 0.88, 0.95)]
	for i in umbrellas.size():
		var foot := Vector3(1.82 + (i % 2) * 0.24, LOT + 0.05, 0.2 + (i / 2) * 0.16)
		var tip := foot + Vector3(-0.05 + (i % 3) * 0.04, 0.85, 0.06 - (i % 2) * 0.1)
		k.rod(foot, tip, 0.008, Color(0.7, 0.7, 0.75))
		var canopy_mid := foot.lerp(tip, 0.5)
		k.cyl(canopy_mid, 0.06, 0.6, umbrellas[i], {"basis": Kit.aim(foot - tip), "top": 0.25, "seg": 8, "gloss": 0.8})
		k.rod(tip, tip + Vector3(0.06, 0.04, 0), 0.012, Color(0.3, 0.2, 0.15))
	k.slab(Vector3(-0.05, LOT, 0.05), Vector3(1.55, LOT + 0.012, 0.95), Color(0.16, 0.2, 0.22), {"line": 0.3})
	k.quad(Vector3(0.75, LOT + 0.014, 0.85), Vector2(1.5, 0.08), TEAL * 0.7)
	k.text("WELCOME", Vector3(0.75, LOT + 0.015, 0.5), 0.14, Color(0.4, 0.55, 0.55), {"rot": Vector3(-90, 0, 0)})
	_pole_sign()

func _pole_sign() -> void:
	var sign := k.material("pole_sign")
	scene.pole_sign_material = sign
	var at := Vector3(3.3, LOT, 3.3)
	var turn := Basis(Vector3.UP, deg_to_rad(15))
	k.box(at + Vector3(0, 1.9, 0), Vector3(0.2, 3.8, 0.2), TRIM, {"gloss": 0.4, "basis": turn})
	k.box(at + Vector3(0, 0.08, 0), Vector3(0.5, 0.16, 0.5), Color(0.5, 0.52, 0.58), {"basis": turn})
	var head := at + Vector3(0, 4.55, 0)
	k.box(head, Vector3(1.5, 1.7, 0.34), TRIM, {"basis": turn, "gloss": 0.5})
	var lit := {"mat": "pole_sign", "emit": 1.0, "basis": turn}
	k.box(head, Vector3(1.38, 1.58, 0.36), Color(0.96, 0.98, 1.0), lit)
	k.box(head + Vector3(0, -0.5, 0), Vector3(1.39, 0.16, 0.37), TEAL, lit)
	k.box(head + Vector3(0, -0.62, 0), Vector3(1.39, 0.08, 0.37), ORANGE, lit)
	for side in [1.0, -1.0]:
		var normal := turn * Vector3(0, 0, side)
		var face_basis := turn if side > 0 else turn * Basis(Vector3.UP, PI)
		_star(head + Vector3(0, 0.28, 0) + normal * 0.19, 0.3, face_basis, "pole_sign")
		var label := k.text("HOSHI\nMART", head + Vector3(0, -0.12, 0) + normal * 0.19, 0.2, Color(0.04, 0.42, 0.44) * 1.4, {"outline": 8})
		label.basis = face_basis
		label.line_spacing = -18

func _side_yard() -> void:
	# two vending machines against the solid side wall
	var bodies := [[Color(0.86, 0.2, 0.26), Color(0.95, 0.95, 0.98)], [Color(0.9, 0.92, 0.96), Color(0.18, 0.4, 0.8)]]
	var drinks := [Color(0.95, 0.3, 0.3), Color(0.2, 0.55, 0.95), Color(0.98, 0.8, 0.2), Color(0.3, 0.8, 0.5), Color(0.95, 0.95, 0.95), Color(0.55, 0.35, 0.2), Color(0.95, 0.55, 0.75), Color(0.15, 0.2, 0.3)]
	for m in 2:
		var z := -4.55 + m * 0.86
		var body: Color = bodies[m][0]
		var accent: Color = bodies[m][1]
		k.box(Vector3(2.79, LOT + 0.92, z), Vector3(0.72, 1.84, 0.82), body, {"gloss": 0.6})
		k.box(Vector3(2.79, LOT + 1.86, z), Vector3(0.74, 0.05, 0.84), body * 0.8, {"gloss": 0.6})
		k.box(Vector3(3.155, LOT + 1.33, z), Vector3(0.02, 0.8, 0.7), Color(0.95, 0.97, 1.0), {"emit": 1.2, "line": 0.3})
		for row in 3:
			for col in 6:
				var drink: Color = drinks[(row * 3 + col + m * 2) % drinks.size()]
				var p := Vector3(3.15, LOT + 1.06 + row * 0.25, z - 0.27 + col * 0.108)
				k.cyl(p, 0.035, 0.15, drink, {"seg": 8, "line": 0.25, "emit": 0.25})
				k.cyl(p + Vector3(0, 0.09, 0), 0.018, 0.03, drink * 0.7, {"seg": 6, "line": 0.0})
				k.box(Vector3(3.17, LOT + 0.96 + row * 0.25, z - 0.27 + col * 0.108), Vector3(0.02, 0.025, 0.06), Color(0.3, 1.0, 0.5), {"emit": 1.0, "line": 0.0})
		k.box(Vector3(3.15, LOT + 0.72, z), Vector3(0.03, 0.22, 0.76), accent, {"gloss": 0.5, "emit": 0.15})
		k.box(Vector3(3.16, LOT + 0.7, z + 0.25), Vector3(0.03, 0.16, 0.14), Color(0.2, 0.22, 0.28), {"line": 0.3})
		k.box(Vector3(3.17, LOT + 0.74, z + 0.25), Vector3(0.01, 0.03, 0.06), Color(0.3, 0.6, 1.0), {"emit": 1.5, "line": 0.0})
		k.box(Vector3(3.15, LOT + 0.3, z), Vector3(0.04, 0.2, 0.6), Color(0.06, 0.06, 0.09), {"line": 0.4})
	# can bin next to them
	k.cyl(Vector3(2.75, LOT + 0.38, -3.05), 0.2, 0.76, Color(0.25, 0.45, 0.85), {"seg": 14, "gloss": 0.5})
	k.cyl(Vector3(2.75, LOT + 0.78, -3.05), 0.21, 0.05, Color(0.85, 0.87, 0.92), {"seg": 14})
	k.cyl(Vector3(2.75, LOT + 0.81, -3.05), 0.07, 0.01, Color(0.05, 0.05, 0.08), {"seg": 12, "line": 0.0})
	# two parked bicycles under the side window
	_bicycle(Vector3(3.3, LOT, -1.95), 0.0, Color(0.55, 0.82, 0.76))
	_bicycle(Vector3(3.3, LOT, -1.15), -8.0, Color(0.94, 0.88, 0.74))

func _bicycle(at: Vector3, yaw: float, color: Color) -> void:
	var turn := Basis(Vector3.UP, deg_to_rad(yaw))
	var p := func(x: float, y: float, z: float = 0.0) -> Vector3: return at + turn * Vector3(x, y, z)
	var metal := Color(0.75, 0.77, 0.82)
	var tyre := Color(0.08, 0.08, 0.1)
	var wheel_basis := turn * Basis(Vector3.RIGHT, PI * 0.5)
	for wx in [-0.52, 0.5]:
		k.torus(p.call(wx, 0.33), 0.3, 0.025, tyre, {"basis": wheel_basis})
		k.torus(p.call(wx, 0.33), 0.27, 0.01, metal, {"basis": wheel_basis, "line": 0.3})
		for s in 4:
			var a := s * PI / 4.0
			k.rod(p.call(wx - cos(a) * 0.27, 0.33 - sin(a) * 0.27), p.call(wx + cos(a) * 0.27, 0.33 + sin(a) * 0.27), 0.004, metal, {"line": 0.0, "seg": 4})
	var r := 0.018
	k.rod(p.call(0.5, 0.33), p.call(0.05, 0.36), r, color)
	k.rod(p.call(0.05, 0.36), p.call(-0.33, 0.62), r, color)
	k.rod(p.call(-0.33, 0.62), p.call(-0.4, 0.82), r, color)
	k.rod(p.call(0.05, 0.36), p.call(0.16, 0.8), r, color)
	k.rod(p.call(0.5, 0.33), p.call(0.18, 0.78), r * 0.8, color)
	k.rod(p.call(-0.52, 0.33), p.call(-0.42, 0.85), r, color)
	k.rod(p.call(-0.42, 0.85), p.call(-0.38, 1.0), r * 0.8, metal)
	k.rod(p.call(-0.36, 1.0, -0.27), p.call(-0.36, 1.0, 0.27), 0.014, metal)
	k.box(p.call(0.18, 0.84), Vector3(0.24, 0.07, 0.16), Color(0.15, 0.13, 0.13), {"basis": turn})
	k.box(p.call(-0.62, 0.86), Vector3(0.3, 0.24, 0.36), metal * 0.9, {"basis": turn, "gloss": 0.4})
	k.box(p.call(-0.62, 0.86), Vector3(0.26, 0.2, 0.32), Color(0.1, 0.1, 0.13), {"basis": turn, "line": 0.0})
	k.box(p.call(0.5, 0.7), Vector3(0.36, 0.03, 0.16), metal, {"basis": turn})
	k.box(p.call(0.27, 0.38), Vector3(0.42, 0.1, 0.03), color * 0.85, {"basis": turn})
	k.rod(p.call(0.3, 0.33), p.call(0.4, LOT - at.y + 0.0, 0.12), 0.01, metal)

func _alley() -> void:
	# outdoor air-conditioner units on the shop's alley wall
	for spot in [Vector3(-5.2, LOT + 0.33, -1.3), Vector3(-5.2, LOT + 0.33, -2.4), Vector3(-5.2, 2.0, -1.85)]:
		_ac_unit(spot)
	k.rod(Vector3(-5.3, 1.7, -2.15), Vector3(-5.0, 1.7, -2.15), 0.03, TRIM)
	k.rod(Vector3(-5.3, 1.7, -1.55), Vector3(-5.0, 1.7, -1.55), 0.03, TRIM)
	var pipe := Color(0.9, 0.87, 0.78)
	for z in [-1.3, -2.4]:
		k.rod(Vector3(-5.25, LOT + 0.66, z + 0.25), Vector3(-5.25, 1.55, z + 0.25), 0.035, pipe)
		k.rod(Vector3(-5.25, 1.55, z + 0.25), Vector3(-5.0, 1.55, z + 0.25), 0.035, pipe)
	k.rod(Vector3(-5.25, 2.33, -1.6), Vector3(-5.25, 2.7, -1.6), 0.035, pipe)
	k.rod(Vector3(-5.25, 2.7, -1.6), Vector3(-5.0, 2.7, -1.6), 0.035, pipe)
	# drinks crates
	var crates := [Color(0.95, 0.75, 0.2), Color(0.85, 0.25, 0.25), Color(0.95, 0.75, 0.2), Color(0.25, 0.5, 0.85)]
	for i in crates.size():
		var c := Vector3(-5.85 + (i / 3) * 0.5, LOT + 0.16 + (i % 3) * 0.32, -4.3 + (i / 3) * 0.1)
		k.box(c, Vector3(0.45, 0.3, 0.35), crates[i], {"gloss": 0.5})
		k.box(c + Vector3(0, 0.0, 0.176), Vector3(0.36, 0.14, 0.005), crates[i] * 0.55, {"line": 0.0})
	# convex traffic mirror at the alley mouth with a stop sign below
	var base := Vector3(-6.45, LOT, 3.8)
	k.rod(base, base + Vector3(0, 2.75, 0), 0.04, Color(0.95, 0.45, 0.15))
	var mirror_basis := Basis(Vector3.UP, deg_to_rad(30)) * Basis(Vector3.RIGHT, PI * 0.5)
	var mirror := base + Vector3(0.0, 2.8, 0.12)
	k.torus(mirror, 0.32, 0.035, Color(0.95, 0.45, 0.15), {"basis": mirror_basis})
	k.cyl(mirror, 0.31, 0.02, Color(0.55, 0.68, 0.85), {"basis": mirror_basis, "seg": 20, "gloss": 1.0, "emit": 0.12})
	k.box(mirror + Vector3(0, 0.33, -0.02), Vector3(0.55, 0.03, 0.18), Color(0.95, 0.45, 0.15), {"rot": Vector3(0, 30, 0)})
	k.prism(base + Vector3(0, 1.9, 0.06), Vector3(0.62, 0.52, 0.03), Color(0.85, 0.12, 0.16), {"rot": Vector3(0, 0, 180)})
	k.text("STOP", base + Vector3(0, 1.96, 0.08), 0.1, Color(1, 1, 1))

func _ac_unit(center: Vector3) -> void:
	k.box(center, Vector3(0.3, 0.6, 0.8), Color(0.86, 0.86, 0.84), {"gloss": 0.4})
	var face := center + Vector3(-0.16, 0.0, -0.1)
	var basis := Basis(Vector3.BACK, PI * 0.5)
	k.cyl(face, 0.22, 0.01, Color(0.15, 0.16, 0.2), {"basis": basis, "seg": 16, "line": 0.0})
	k.torus(face + Vector3(-0.01, 0, 0), 0.22, 0.015, Color(0.6, 0.6, 0.62), {"basis": basis, "line": 0.3})
	for a in [0.0, PI * 0.5]:
		k.box(face + Vector3(-0.012, 0, 0), Vector3(0.01, 0.44, 0.012), Color(0.6, 0.6, 0.62), {"basis": Basis(Vector3.RIGHT, a), "line": 0.0})
	k.box(center + Vector3(-0.16, 0, 0.28), Vector3(0.01, 0.4, 0.14), Color(0.7, 0.7, 0.7), {"line": 0.0})

func _neighbour() -> void:
	k.material("block", 5)
	var siding := {"mat": "siding"}
	var house := Color(0.72, 0.62, 0.54)
	k.slab(Vector3(-9.0, LOT, -6.0), Vector3(-6.75, 5.6, 2.4), house, siding)
	k.slab(Vector3(-9.05, 5.6, -6.1), Vector3(-6.62, 5.76, 2.5), Color(0.3, 0.3, 0.38), {"gloss": 0.6})
	k.slab(Vector3(-9.0, 2.85, 2.4), Vector3(-6.75, 2.95, 2.5), Color(0.6, 0.55, 0.5))
	# the far sides get a few dark windows and a drainpipe so no wall is blank
	for spot in [Vector2(-4.6, 1.5), Vector2(-1.4, 1.5), Vector2(-4.6, 4.0), Vector2(-1.4, 4.0), Vector2(1.2, 4.0)]:
		k.slab(Vector3(-9.02, spot.y - 0.5, spot.x - 0.5), Vector3(-8.99, spot.y + 0.5, spot.x + 0.5), Color(0.14, 0.17, 0.3), {"gloss": 0.9})
		k.slab(Vector3(-9.04, spot.y - 0.56, spot.x - 0.56), Vector3(-9.01, spot.y - 0.5, spot.x + 0.56), Color(0.6, 0.55, 0.5))
	k.slab(Vector3(-9.02, 3.5, 0.7), Vector3(-8.99, 4.5, 1.7), Color(0.9, 0.7, 0.45), {"emit": 0.6})
	for spot in [Vector2(-8.2, 4.0), Vector2(-7.4, 1.5)]:
		k.slab(Vector3(spot.x - 0.4, spot.y - 0.45, -6.02), Vector3(spot.x + 0.4, spot.y + 0.45, -5.99), Color(0.14, 0.17, 0.3), {"gloss": 0.9})
	k.rod(Vector3(-9.06, 5.6, -5.9), Vector3(-9.06, LOT, -5.9), 0.045, Color(0.6, 0.6, 0.65), {"seg": 8})
	# front door with a little lamp, two windows (upstairs one lit behind curtains)
	k.slab(Vector3(-8.55, LOT, 2.4), Vector3(-7.85, 2.1, 2.46), Color(0.36, 0.25, 0.2), {"gloss": 0.3})
	k.box(Vector3(-7.95, 1.05, 2.48), Vector3(0.04, 0.12, 0.04), BRASS, {"gloss": 0.8})
	k.slab(Vector3(-8.75, 2.2, 2.4), Vector3(-7.65, 2.28, 2.85), Color(0.3, 0.3, 0.38))
	k.box(Vector3(-7.6, 1.9, 2.47), Vector3(0.1, 0.16, 0.08), Color(1.0, 0.82, 0.5), {"emit": 1.2})
	k.slab(Vector3(-7.5, 1.1, 2.4), Vector3(-6.95, 2.0, 2.44), Color(0.12, 0.16, 0.28), {"gloss": 0.9})
	k.slab(Vector3(-7.55, 1.05, 2.4), Vector3(-6.9, 1.1, 2.48), Color(0.6, 0.55, 0.5))
	k.slab(Vector3(-8.5, 3.4, 2.4), Vector3(-7.2, 4.6, 2.42), Color(1.0, 0.78, 0.48), {"emit": 1.3})
	k.slab(Vector3(-8.5, 3.4, 2.42), Vector3(-8.15, 4.6, 2.43), Color(0.95, 0.62, 0.55), {"emit": 0.5, "line": 0.3})
	k.slab(Vector3(-7.55, 3.4, 2.42), Vector3(-7.2, 4.6, 2.43), Color(0.95, 0.62, 0.55), {"emit": 0.5, "line": 0.3})
	k.slab(Vector3(-8.55, 3.35, 2.4), Vector3(-7.15, 3.4, 2.5), Color(0.6, 0.55, 0.5))
	for x in [-8.5, -7.85, -7.2]:
		k.box(Vector3(x, 4.0, 2.44), Vector3(0.04, 1.2, 0.04), Color(0.5, 0.45, 0.4))
	# little balcony with railing and an outdoor unit
	k.slab(Vector3(-8.9, 3.0, 2.5), Vector3(-6.85, 3.08, 3.15), Color(0.6, 0.6, 0.66))
	for i in 12:
		k.rod(Vector3(-8.85 + i * 0.18, 3.08, 3.12), Vector3(-8.85 + i * 0.18, 3.85, 3.12), 0.012, RAIL, {"line": 0.5})
	k.rod(Vector3(-8.9, 3.85, 3.12), Vector3(-6.85, 3.85, 3.12), 0.025, RAIL)
	k.box(Vector3(-7.15, 3.35, 2.75), Vector3(0.5, 0.5, 0.25), Color(0.86, 0.86, 0.84), {"gloss": 0.4})
	k.cyl(Vector3(-7.15, 3.35, 2.885), 0.17, 0.01, Color(0.15, 0.16, 0.2), {"rot": Vector3(90, 0, 0), "seg": 14, "line": 0.0})
	k.cyl(Vector3(-8.5, 3.2, 2.85), 0.12, 0.22, Color(0.7, 0.45, 0.3), {"seg": 10})
	k.ball(Vector3(-8.5, 3.42, 2.85), Vector3(0.18, 0.16, 0.18), Color(0.3, 0.55, 0.38))
	# alley side: frosted window, gas meter, water heater, a warm bracket lamp
	k.slab(Vector3(-6.77, 1.6, -2.1), Vector3(-6.72, 2.25, -1.4), Color(0.9, 0.95, 0.85), {"emit": 0.55})
	for z in [-1.98, -1.75, -1.52]:
		k.box(Vector3(-6.7, 1.92, z), Vector3(0.03, 0.7, 0.03), Color(0.55, 0.57, 0.62))
	k.box(Vector3(-6.66, 1.2, -3.2), Vector3(0.18, 0.4, 0.3), Color(0.8, 0.82, 0.85), {"gloss": 0.4})
	k.box(Vector3(-6.6, 1.0, -0.2), Vector3(0.3, 0.8, 0.5), Color(0.9, 0.9, 0.92), {"gloss": 0.4})
	k.rod(Vector3(-6.6, 0.6, -0.1), Vector3(-6.6, LOT, -0.1), 0.02, Color(0.6, 0.6, 0.65))
	k.rod(Vector3(-6.75, 2.55, -1.0), Vector3(-6.45, 2.55, -1.0), 0.02, TRIM)
	k.ball(Vector3(-6.4, 2.48, -1.0), Vector3(0.12, 0.14, 0.12), Color(1.0, 0.8, 0.5), {"emit": 1.4})
	# front yard: block wall with gate gap, potted plants, mailbox, the community notice board
	k.slab(Vector3(-9.0, LOT, 3.75), Vector3(-8.6, 1.15, 3.95), Color(0.58, 0.58, 0.62), {"mat": "block"})
	k.slab(Vector3(-7.85, LOT, 3.75), Vector3(-6.75, 1.15, 3.95), Color(0.58, 0.58, 0.62), {"mat": "block"})
	k.slab(Vector3(-6.75, LOT, -6.0), Vector3(-6.6, 1.15, 3.95), Color(0.58, 0.58, 0.62), {"mat": "block"})
	k.slab(Vector3(-9.02, 1.15, 3.73), Vector3(-8.58, 1.21, 3.97), Color(0.45, 0.45, 0.5))
	k.slab(Vector3(-7.87, 1.15, 3.73), Vector3(-6.73, 1.21, 3.97), Color(0.45, 0.45, 0.5))
	k.box(Vector3(-8.75, 0.95, 3.99), Vector3(0.24, 0.3, 0.1), Color(0.85, 0.22, 0.2), {"gloss": 0.5})
	for p in [Vector3(-8.85, LOT, 3.2), Vector3(-7.4, LOT, 3.3), Vector3(-7.05, LOT, 3.0)]:
		k.cyl(p + Vector3(0, 0.15, 0), 0.16, 0.3, Color(0.55, 0.32, 0.22), {"seg": 10, "top": 1.15})
		k.ball(p + Vector3(0, 0.45, 0), Vector3(0.26, 0.3, 0.26), Color(0.26, 0.5, 0.36))
	var board := Vector3(-7.3, 1.45, 4.08)
	for x in [-0.42, 0.42]:
		k.box(board + Vector3(x, -0.7, 0), Vector3(0.06, 1.4, 0.06), Color(0.4, 0.28, 0.2))
	k.box(board, Vector3(0.95, 0.65, 0.05), Color(0.42, 0.3, 0.2))
	k.box(board + Vector3(0, 0, 0.03), Vector3(0.85, 0.55, 0.01), Color(0.72, 0.62, 0.45), {"line": 0.0})
	k.box(board + Vector3(0, 0.38, 0.03), Vector3(1.05, 0.04, 0.16), Color(0.3, 0.3, 0.36))
	var papers := [[Vector3(-0.24, 0.08, 0), Vector2(0.28, 0.34), Color(0.98, 0.95, 0.85), "BON\nODORI"], [Vector3(0.12, 0.12, 0), Vector2(0.24, 0.2), Color(0.75, 0.88, 0.98), "NOTICE"], [Vector3(0.18, -0.13, 0), Vector2(0.3, 0.2), Color(0.98, 0.82, 0.86), "LOST\nCAT"], [Vector3(-0.22, -0.17, 0), Vector2(0.26, 0.14), Color(0.88, 0.96, 0.82), "GARBAGE\nDAYS"]]
	for paper in papers:
		k.box(board + paper[0] + Vector3(0, 0, 0.04), Vector3(paper[1].x, paper[1].y, 0.004), paper[2], {"line": 0.3})
		k.text(paper[3], board + paper[0] + Vector3(0, 0, 0.044), 0.045, Color(0.2, 0.2, 0.3))
		k.ball(board + paper[0] + Vector3(0, paper[1].y * 0.42, 0.045), Vector3.ONE * 0.012, Color(0.9, 0.2, 0.2), {"line": 0.0, "seg": 6})

func _back() -> void:
	var block := {"mat": "block"}
	k.slab(Vector3(-6.6, LOT, -8.95), Vector3(4.0, 1.35, -8.75), Color(0.58, 0.58, 0.62), block)
	k.slab(Vector3(-6.62, 1.35, -8.97), Vector3(4.02, 1.41, -8.73), Color(0.45, 0.45, 0.5))
	# back door with its lamp, a pair of big condensers, garbage carts
	k.slab(Vector3(-2.1, FLOOR - 0.01, -5.25), Vector3(-1.2, 2.2, -5.2), Color(0.45, 0.5, 0.58), {"gloss": 0.5})
	k.box(Vector3(-1.35, 1.1, -5.27), Vector3(0.06, 0.04, 0.05), Color(0.8, 0.8, 0.85))
	k.box(Vector3(-1.65, 2.5, -5.28), Vector3(0.22, 0.12, 0.12), Color(1.0, 0.85, 0.6), {"emit": 1.3})
	k.slab(Vector3(-2.3, LOT, -5.9), Vector3(-1.0, FLOOR - 0.01, -5.2), Color(0.5, 0.5, 0.56))
	for x in [0.55, 1.65]:
		k.box(Vector3(x, LOT + 0.45, -5.62), Vector3(1.0, 0.9, 0.38), Color(0.84, 0.85, 0.88), {"gloss": 0.4})
		k.cyl(Vector3(x - 0.15, LOT + 0.5, -5.82), 0.3, 0.01, Color(0.15, 0.16, 0.2), {"rot": Vector3(90, 0, 0), "seg": 16, "line": 0.0})
		k.torus(Vector3(x - 0.15, LOT + 0.5, -5.83), 0.3, 0.02, Color(0.6, 0.6, 0.62), {"rot": Vector3(90, 0, 0), "line": 0.3})
	for i in 2:
		var c := Vector3(-3.6 + i * 0.8, LOT + 0.5, -7.9)
		k.box(c, Vector3(0.7, 0.9, 0.6), Color(0.25, 0.48, 0.38), {"gloss": 0.5})
		k.box(c + Vector3(0, 0.47, 0), Vector3(0.74, 0.06, 0.64), Color(0.2, 0.38, 0.3), {"gloss": 0.5})
		for x in [-0.25, 0.25]:
			k.cyl(c + Vector3(x, -0.45, 0.2), 0.06, 0.05, Color(0.1, 0.1, 0.12), {"rot": Vector3(0, 0, 90), "seg": 10})

# --- street ------------------------------------------------------------------------

const P1 := Vector3(-8.3, LOT, 4.7)
const P2 := Vector3(4.7, LOT, 4.7)
const P3 := Vector3(4.7, LOT, -8.3)

func _poles_and_wires() -> void:
	var tops := {}
	tops["p1"] = _utility_pole(P1, 0.0, true)
	tops["p2"] = _utility_pole(P2, 45.0, false)
	tops["p3"] = _utility_pole(P3, 90.0, false)
	for i in tops["p1"].size():
		_wire(tops["p1"][i], tops["p2"][i], 0.35 + i * 0.05)
		_wire(tops["p2"][i], tops["p3"][i], 0.35 + i * 0.05)
		var w: Vector3 = tops["p1"][i]
		_wire(w, Vector3(-9.0, w.y - 0.05, w.z), 0.02)
		var s: Vector3 = tops["p3"][i]
		_wire(s, Vector3(s.x, s.y - 0.05, -9.0), 0.02)
	# wires leaving the base across both roads, and the service drops
	for i in 3:
		var a: Vector3 = tops["p2"][i]
		_wire(a, Vector3(9.0, a.y - 0.4, a.z + 0.3), 0.15)
		_wire(a, Vector3(a.x - 0.2, a.y - 0.3, 9.0), 0.15)
	_wire(P2 + Vector3(0, 6.6, 0), Vector3(2.3, 4.0, -0.1), 0.5, 0.02)
	_wire(P1 + Vector3(0, 6.6, 0), Vector3(-7.0, 5.0, 2.4), 0.45, 0.02)
	_wire(P2 + Vector3(0, 5.2, 0), Vector3(8.75, 5.4, 8.75), 0.35, 0.018)

## Concrete pole with cross-arms; returns the wire attachment points.
func _utility_pole(at: Vector3, yaw: float, transformer: bool) -> Array:
	var turn := Basis(Vector3.UP, deg_to_rad(yaw))
	k.cyl(at + Vector3(0, 4.4, 0), 0.15, 8.8, POLE, {"top": 0.72, "seg": 12})
	# yellow and black guard sleeve at the foot
	for i in 6:
		var color := Color(0.98, 0.8, 0.15) if i % 2 == 0 else Color(0.1, 0.1, 0.12)
		k.cyl(at + Vector3(0, 0.15 + i * 0.3, 0), 0.165, 0.3, color, {"seg": 12, "line": 0.4 if i == 0 or i == 5 else 0.0})
	k.box(at + turn * Vector3(0, 2.4, 0.16), Vector3(0.18, 0.35, 0.02), Color(0.9, 0.92, 0.95), {"basis": turn})
	k.box(at + turn * Vector3(0, 2.45, 0.172), Vector3(0.14, 0.08, 0.01), Color(0.2, 0.35, 0.7), {"basis": turn, "line": 0.0})
	for i in 10:
		var side := 1.0 if i % 2 == 0 else -1.0
		k.rod(at + Vector3(0, 2.9 + i * 0.42, 0), at + Vector3(0, 2.9 + i * 0.42, 0) + turn * Vector3(side * 0.28, 0, 0), 0.015, Color(0.4, 0.4, 0.45), {"line": 0.5})
	var points := []
	var arms := [[8.55, 0.85], [7.6, 0.55]]
	for arm in arms:
		var y: float = arm[0]
		var half: float = arm[1]
		k.box(at + Vector3(0, y, 0), Vector3(half * 2.0, 0.09, 0.09), Color(0.5, 0.52, 0.56), {"basis": turn * Basis(Vector3.UP, PI * 0.5)})
		for s in [-1.0, 1.0]:
			var tip := at + Vector3(0, y, 0) + turn * Vector3(0, 0, s * half * 0.9)
			k.cyl(tip + Vector3(0, 0.1, 0), 0.04, 0.14, Color(0.92, 0.92, 0.95), {"seg": 8, "gloss": 0.6})
			points.append(tip + Vector3(0, 0.15, 0))
	points.append(at + Vector3(0, 5.6, 0))
	points.append(at + Vector3(0, 5.25, 0))
	if transformer:
		k.cyl(at + turn * Vector3(0.38, 6.4, 0), 0.26, 0.85, Color(0.6, 0.62, 0.66), {"seg": 14, "gloss": 0.4})
		k.cyl(at + turn * Vector3(0.38, 6.86, 0), 0.27, 0.06, Color(0.5, 0.52, 0.56), {"seg": 14})
		k.rod(at + Vector3(0, 6.2, 0), at + turn * Vector3(0.3, 6.2, 0), 0.03, Color(0.45, 0.45, 0.5))
	return points

## Sagging cable between a and b, drawn as a chain of thin rods.
func _wire(a: Vector3, b: Vector3, sag: float, radius := 0.012) -> void:
	var steps := 12
	var prev := a
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var p := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		k.rod(prev, p, radius, WIRE, {"seg": 4, "line": 0.3})
		prev = p

func _street_lamp() -> void:
	var foot := Vector3(-6.0, LOT, 4.75)
	var grey := Color(0.5, 0.53, 0.6)
	k.cyl(foot + Vector3(0, 2.5, 0), 0.07, 5.0, grey, {"top": 0.7, "seg": 10, "gloss": 0.4})
	k.cyl(foot + Vector3(0, 0.2, 0), 0.11, 0.4, grey, {"seg": 10})
	k.rod(foot + Vector3(0, 4.95, 0), foot + Vector3(0, 5.3, 0.5), 0.045, grey)
	k.rod(foot + Vector3(0, 5.3, 0.5), foot + Vector3(0, 5.36, 1.05), 0.045, grey)
	k.box(foot + Vector3(0, 5.38, 1.2), Vector3(0.28, 0.1, 0.55), grey, {"gloss": 0.4})
	k.box(foot + Vector3(0, 5.325, 1.22), Vector3(0.22, 0.02, 0.42), Color(0.88, 0.96, 1.0), {"emit": 2.0, "line": 0.3})
	# security light on the back pole
	var lamp := P3 + Vector3(0, 4.7, 0)
	k.rod(lamp, lamp + Vector3(0.2, 0.15, 0.5), 0.03, grey)
	k.box(lamp + Vector3(0.22, 0.12, 0.62), Vector3(0.12, 0.08, 0.5), Color(0.86, 0.88, 0.92), {"gloss": 0.4})
	k.box(lamp + Vector3(0.22, 0.075, 0.62), Vector3(0.08, 0.02, 0.44), Color(0.85, 1.0, 0.9), {"emit": 1.8, "line": 0.3})

func _guard_rails() -> void:
	_rail_run(Vector3(-8.9, LOT, 4.95), Vector3(-3.4, LOT, 4.95))
	_rail_run(Vector3(4.95, LOT, -8.9), Vector3(4.95, LOT, -0.4))

func _rail_run(a: Vector3, b: Vector3) -> void:
	var count := maxi(int(ceil(a.distance_to(b) / 1.8)), 1)
	for i in count + 1:
		var p := a.lerp(b, float(i) / count)
		k.cyl(p + Vector3(0, 0.47, 0), 0.03, 0.94, RAIL, {"seg": 8, "gloss": 0.6})
		k.cyl(p + Vector3(0, 0.95, 0), 0.034, 0.03, RAIL, {"seg": 8})
		k.cyl(p + Vector3(0, 0.75, 0), 0.02, 0.07, Color(1.0, 0.5, 0.15), {"seg": 8, "emit": 0.4, "line": 0.0})
	for y in [0.92, 0.55]:
		k.rod(a + Vector3(0, y, 0), b + Vector3(0, y, 0), 0.025, RAIL, {"gloss": 0.6, "seg": 8})

func _signs() -> void:
	# blue pedestrian-crossing sign beside crossing A
	var post := Vector3(1.0, LOT, 4.85)
	k.rod(post, post + Vector3(0, 2.6, 0), 0.03, Color(0.6, 0.62, 0.68))
	var face := Basis(Vector3.UP, deg_to_rad(-20))
	k.box(post + Vector3(0, 2.6, 0.04), Vector3(0.6, 0.6, 0.02), Color(0.15, 0.35, 0.8), {"basis": face, "emit": 0.15})
	k.prism(post + Vector3(0, 2.62, 0.056), Vector3(0.48, 0.42, 0.01), Color(0.95, 0.96, 1.0), {"basis": face, "line": 0.0})
	k.box(post + Vector3(0, 2.58, 0.063), Vector3(0.05, 0.13, 0.005), Color(0.1, 0.1, 0.15), {"basis": face, "line": 0.0})
	k.ball(post + Vector3(0, 2.68, 0.063), Vector3(0.05, 0.05, 0.01), Color(0.1, 0.1, 0.15), {"basis": face, "line": 0.0, "seg": 8})
	# speed limit 30 on the back pole, no parking on the front-left pole
	_round_sign(P3 + Vector3(0, 2.7, 0.18), Color(0.97, 0.97, 1.0), Color(0.85, 0.12, 0.16), "30", Basis.IDENTITY)
	_round_sign(P1 + Vector3(0.12, 2.7, 0.14), Color(0.15, 0.35, 0.8), Color(0.85, 0.12, 0.16), "", Basis(Vector3.UP, deg_to_rad(35)))
	k.box(P1 + Vector3(0.12, 2.7, 0.14) + Basis(Vector3.UP, deg_to_rad(35)) * Vector3(0, 0, 0.02), Vector3(0.05, 0.5, 0.005), Color(0.85, 0.12, 0.16), {"basis": Basis(Vector3.UP, deg_to_rad(35)) * Basis(Vector3.BACK, deg_to_rad(45)), "line": 0.0})

func _round_sign(center: Vector3, fill: Color, ring: Color, label: String, face: Basis) -> void:
	var disc := face * Basis(Vector3.RIGHT, PI * 0.5)
	k.cyl(center, 0.3, 0.02, ring, {"basis": disc, "seg": 24})
	k.cyl(center + face * Vector3(0, 0, 0.012), 0.23, 0.01, fill, {"basis": disc, "seg": 24, "line": 0.0})
	if label != "":
		var t := k.text(label, center + face * Vector3(0, 0, 0.02), 0.22, Color(0.15, 0.3, 0.75))
		t.basis = face

func _traffic_signals() -> void:
	var foot := Vector3(8.82, LOT, 8.82)
	var grey := Color(0.55, 0.6, 0.66)
	k.cyl(foot + Vector3(0, 2.8, 0), 0.12, 5.6, grey, {"seg": 12, "top": 0.8})
	# arm over road A, head facing traffic coming along +X; arm over road B facing +Z traffic
	k.rod(foot + Vector3(0, 5.2, 0), Vector3(8.82, 5.2, 6.4), 0.05, grey)
	k.rod(foot + Vector3(0, 5.2, 0), Vector3(6.4, 5.2, 8.82), 0.05, grey)
	scene.signal_a = _signal_head(Vector3(8.6, 5.0, 6.9), Basis(Vector3.UP, -PI * 0.5), "sig_a")
	scene.signal_b = _signal_head(Vector3(6.9, 5.0, 8.6), Basis(Vector3.UP, PI), "sig_b")
	scene.walk_a = _walk_signal(Vector3(2.0, LOT, 8.88), Basis(Vector3.UP, PI), "walk_a")
	scene.walk_b = _walk_signal(Vector3(8.88, LOT, 1.9), Basis(Vector3.UP, -PI * 0.5), "walk_b")

## Horizontal Japanese signal: green, amber, red from the driver's left. Returns its three lens materials.
func _signal_head(center: Vector3, face: Basis, prefix: String) -> Array:
	k.box(center, Vector3(1.2, 0.36, 0.26), Color(0.4, 0.44, 0.5), {"basis": face, "gloss": 0.5})
	k.box(center + face * Vector3(0, 0, -0.13), Vector3(1.26, 0.42, 0.02), Color(0.35, 0.38, 0.44), {"basis": face})
	k.rod(center + Vector3(0, 0.18, 0), center + Vector3(0, 0.2, 0), 0.04, Color(0.55, 0.6, 0.66))
	var colors := [Color(0.1, 0.95, 0.75), Color(1.0, 0.7, 0.1), Color(1.0, 0.18, 0.15)]
	var mats := []
	for i in 3:
		var mat_name := "%s_%d" % [prefix, i]
		mats.append(k.material(mat_name, 0, {"emit_energy": 0.0}))
		var lens := center + face * Vector3(-0.4 + i * 0.4, 0, 0.135)
		k.cyl(lens, 0.13, 0.02, colors[i], {"basis": face * Basis(Vector3.RIGHT, PI * 0.5), "seg": 16, "mat": mat_name, "emit": 1.0, "line": 0.4})
		k.box(lens + face * Vector3(0, 0.15, 0.08), Vector3(0.3, 0.02, 0.18), Color(0.35, 0.38, 0.44), {"basis": face})
	return mats

## Pedestrian signal on its own post: red over green. Returns [red, green] lens materials.
func _walk_signal(foot: Vector3, face: Basis, prefix: String) -> Array:
	k.rod(foot, foot + Vector3(0, 2.9, 0), 0.05, Color(0.55, 0.6, 0.66))
	var head := foot + Vector3(0, 2.55, 0) + face * Vector3(0, 0, 0.12)
	k.box(head, Vector3(0.36, 0.72, 0.2), Color(0.4, 0.44, 0.5), {"basis": face, "gloss": 0.5})
	var mats := []
	var colors := [Color(1.0, 0.2, 0.18), Color(0.15, 0.95, 0.8)]
	for i in 2:
		var mat_name := "%s_%d" % [prefix, i]
		mats.append(k.material(mat_name, 0, {"emit_energy": 0.0}))
		var lens := head + face * Vector3(0, 0.17 - i * 0.34, 0.105)
		k.box(lens, Vector3(0.26, 0.26, 0.01), colors[i], {"basis": face, "mat": mat_name, "emit": 1.0, "line": 0.3})
		k.box(lens + face * Vector3(0, 0.02, 0.008), Vector3(0.05, 0.13, 0.004), Color(0.05, 0.05, 0.08), {"basis": face, "line": 0.0})
		k.ball(lens + face * Vector3(0, 0.11, 0.008), Vector3(0.05, 0.05, 0.005), Color(0.05, 0.05, 0.08), {"basis": face, "line": 0.0, "seg": 6})
	return mats
