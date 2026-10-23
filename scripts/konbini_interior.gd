extends RefCounted
## The inside of the shop, seen through the big windows: drinks coolers, bento and
## onigiri case, shelves of snacks, the counter with coffee, oden and hot snacks,
## magazines, freezer, lockers, eat-in counter and the half-open staff door.
## Everything is on render layer 2 so only the warm shop lights reach it.

const Kit := preload("res://scripts/konbini_kit.gd")

const FLOOR := 0.2
const CEIL := 3.1
const X0 := -4.85
const X1 := 2.25
const Z_BACK := -4.3        # partition in front of the stockroom
const Z_FRONT := -0.15

const CREAM := Color(0.97, 0.91, 0.82)
const FRAME := Color(0.32, 0.35, 0.42)
const STEEL := Color(0.78, 0.8, 0.85)
const TEAL := Color(0.08, 0.66, 0.64)
const ORANGE := Color(1.0, 0.55, 0.24)
const PRODUCT := [
	Color(0.95, 0.3, 0.32), Color(0.2, 0.55, 0.95), Color(0.98, 0.8, 0.22), Color(0.3, 0.78, 0.5),
	Color(0.96, 0.96, 0.96), Color(0.6, 0.38, 0.22), Color(0.95, 0.55, 0.75), Color(0.55, 0.4, 0.85),
	Color(1.0, 0.6, 0.2), Color(0.35, 0.8, 0.85), Color(0.2, 0.25, 0.35),
]

var k: Kit
var scene: Node3D
var rng := RandomNumberGenerator.new()

static func build(kit: Kit, diorama: Node3D) -> void:
	var b := new()
	b.k = kit
	b.scene = diorama
	b.rng.seed = 7_2024
	b._room()
	b._coolers()
	b._bento_case()
	b._lockers()
	b._magazines()
	b._gondola(-1.55)
	b._gondola(-2.65)
	b._freezer()
	b._counter()
	b._eat_in()
	b._signs_and_posters()
	b._entrance_bits()
	b._stockroom()

## Options for indoor parts: layer 2 plus the warm fill light.
func o(extra := {}) -> Dictionary:
	var opts := {"indoor": true, "lit": 0.32}
	opts.merge(extra, true)
	return opts

func _pick() -> Color:
	return PRODUCT[rng.randi() % PRODUCT.size()]

func _room() -> void:
	k.material("shop_floor", 2)
	k.slab(Vector3(X0, FLOOR - 0.01, Z_BACK - 0.75), Vector3(X1, FLOOR, Z_FRONT), Color(0.9, 0.86, 0.8), o({"mat": "shop_floor", "gloss": 0.35, "line": 0.0, "lit": 0.3}))
	var wall := o({"line": 0.3})
	k.slab(Vector3(X0 - 0.01, FLOOR, Z_BACK - 0.75), Vector3(X0 + 0.01, CEIL, Z_FRONT), CREAM, wall)
	k.slab(Vector3(X0, FLOOR, Z_BACK - 0.02), Vector3(1.4, CEIL, Z_BACK + 0.02), CREAM, wall)
	k.slab(Vector3(1.4, 2.3, Z_BACK - 0.02), Vector3(X1, CEIL, Z_BACK + 0.02), CREAM, wall)
	k.slab(Vector3(X1 - 0.01, FLOOR, Z_BACK - 0.75), Vector3(X1 + 0.01, CEIL, -2.75), CREAM, wall)
	k.slab(Vector3(X1 - 0.01, 2.6, -2.75), Vector3(X1 + 0.01, CEIL, Z_FRONT), CREAM, wall)
	k.slab(Vector3(X1 - 0.01, FLOOR, -2.75), Vector3(X1 + 0.01, 0.55, Z_FRONT), CREAM, wall)
	k.slab(Vector3(1.6, FLOOR, Z_FRONT - 0.01), Vector3(X1, CEIL, Z_FRONT + 0.01), CREAM, wall)
	k.slab(Vector3(X0, 2.6, Z_FRONT - 0.01), Vector3(1.6, CEIL, Z_FRONT + 0.01), CREAM, wall)
	k.slab(Vector3(X0, FLOOR, Z_FRONT - 0.01), Vector3(-0.1, 0.55, Z_FRONT + 0.01), CREAM, wall)
	# skirting and ceiling with its light panels
	k.slab(Vector3(X0, FLOOR, Z_BACK + 0.02), Vector3(1.4, FLOOR + 0.1, Z_BACK + 0.04), TEAL * 0.8, o({"line": 0.0}))
	k.slab(Vector3(X0, CEIL, Z_BACK - 0.75), Vector3(X1, CEIL + 0.04, Z_FRONT), Color(0.97, 0.97, 0.96), o({"line": 0.0, "lit": 0.42}))
	for z in [-1.0, -2.2, -3.4]:
		for x in [-3.6, -2.0, -0.4, 1.2]:
			k.box(Vector3(x, CEIL - 0.015, z), Vector3(1.2, 0.03, 0.26), Color(1.0, 0.99, 0.95), o({"emit": 1.0, "line": 0.3}))

func _coolers() -> void:
	var x_from := X0 + 0.02
	var bays := 4
	var bay := 0.9
	var depth := 0.62
	var front := Z_BACK + depth
	k.slab(Vector3(x_from, FLOOR, Z_BACK), Vector3(x_from + bays * bay, FLOOR + 0.18, front), FRAME, o())
	k.slab(Vector3(x_from, 2.2, Z_BACK), Vector3(x_from + bays * bay, 2.6, front + 0.02), FRAME, o())
	k.slab(Vector3(x_from + 0.05, 2.27, front + 0.02), Vector3(x_from + bays * bay - 0.05, 2.53, front + 0.03), Color(0.85, 0.96, 1.0), o({"emit": 1.0, "line": 0.0}))
	k.text("COLD  DRINKS", Vector3(x_from + bays * bay * 0.5, 2.4, front + 0.035), 0.16, Color(0.1, 0.45, 0.75) * 1.2, {"indoor": true, "outline": 6})
	var shelf_y := [0.42, 0.78, 1.14, 1.5, 1.86]
	for b in bays:
		var bx := x_from + b * bay
		k.slab(Vector3(bx + 0.03, FLOOR + 0.18, Z_BACK + 0.01), Vector3(bx + bay - 0.03, 2.2, Z_BACK + 0.03), Color(0.85, 0.94, 1.0), o({"emit": 0.45, "line": 0.0}))
		k.box(Vector3(bx + bay * 0.5, 2.15, front - 0.12), Vector3(bay - 0.1, 0.03, 0.05), Color(0.95, 1.0, 1.0), o({"emit": 1.2, "line": 0.0}))
		for i in shelf_y.size():
			var y: float = shelf_y[i]
			k.box(Vector3(bx + bay * 0.5, y, Z_BACK + depth * 0.5), Vector3(bay - 0.06, 0.02, depth - 0.08), STEEL, o({"line": 0.3, "gloss": 0.4}))
			k.box(Vector3(bx + bay * 0.5, y - 0.005, front - 0.05), Vector3(bay - 0.06, 0.035, 0.01), Color(0.98, 0.98, 0.9), o({"line": 0.0}))
			var cans := i == 0 or i == 3
			var cols := 9 if cans else 7
			for c in cols:
				var color := _pick()
				var x := bx + 0.08 + c * (bay - 0.16) / (cols - 1)
				for row in 2:
					var z := front - 0.13 - row * 0.16
					if cans:
						k.cyl(Vector3(x, y + 0.07, z), 0.032, 0.12, color, o({"seg": 8, "line": 0.25, "lit": 0.45, "gloss": 0.5}))
					else:
						k.cyl(Vector3(x, y + 0.1, z), 0.036, 0.17, color, o({"seg": 8, "line": 0.25, "lit": 0.45, "gloss": 0.5}))
						k.cyl(Vector3(x, y + 0.205, z), 0.016, 0.04, color.darkened(0.3), o({"seg": 6, "line": 0.0}))
		# glass door with its frame and handle
		var glass: MeshInstance3D = scene.add_glass(Vector3(bx + bay * 0.5, 1.19, front + 0.015), Vector2(bay - 0.08, 1.98), Basis.IDENTITY, 0.0, true)
		glass.layers = Kit.LAYER_IN
		k.box(Vector3(bx + 0.02, 1.19, front + 0.01), Vector3(0.04, 2.02, 0.04), FRAME, o())
		k.rod(Vector3(bx + bay - 0.12, 0.9, front + 0.06), Vector3(bx + bay - 0.12, 1.5, front + 0.06), 0.012, STEEL, o({"gloss": 0.7}))
	k.box(Vector3(x_from + bays * bay - 0.02, 1.19, front + 0.01), Vector3(0.04, 2.02, 0.04), FRAME, o())

func _bento_case() -> void:
	var x_back := X0 + 0.02
	var z0 := -3.5
	var z1 := -1.3
	var zc := (z0 + z1) * 0.5
	var length := z1 - z0
	k.slab(Vector3(x_back, FLOOR, z0), Vector3(x_back + 0.66, 0.78, z1), Color(0.92, 0.94, 0.96), o())
	k.slab(Vector3(x_back + 0.64, 0.3, z0), Vector3(x_back + 0.67, 0.6, z1), TEAL, o({"line": 0.0}))
	k.slab(Vector3(x_back, 0.78, z0), Vector3(x_back + 0.08, 2.05, z1), Color(0.86, 0.9, 0.95), o({"emit": 0.25}))
	k.slab(Vector3(x_back, 1.98, z0), Vector3(x_back + 0.5, 2.08, z1), FRAME, o())
	k.box(Vector3(x_back + 0.4, 1.96, zc), Vector3(0.06, 0.03, length - 0.1), Color(1.0, 0.98, 0.9), o({"emit": 1.2, "line": 0.0}))
	for side in [z0, z1]:
		k.slab(Vector3(x_back, 0.78, side - 0.02), Vector3(x_back + 0.66, 2.05, side + 0.02), FRAME, o())
	# deck 1: bento boxes
	for row in 2:
		for i in 9:
			var p := Vector3(x_back + 0.45 - row * 0.2, 0.83, z0 + 0.15 + i * 0.24)
			k.box(p, Vector3(0.17, 0.05, 0.21), Color(0.12, 0.12, 0.14), o({"line": 0.3}))
			k.box(p + Vector3(0, 0.03, -0.045), Vector3(0.15, 0.012, 0.1), Color(0.98, 0.98, 0.95), o({"line": 0.0, "lit": 0.42}))
			k.box(p + Vector3(0.02, 0.03, 0.05), Vector3(0.1, 0.014, 0.08), [Color(1.0, 0.55, 0.4), Color(0.85, 0.55, 0.25), Color(0.95, 0.75, 0.35)][i % 3], o({"line": 0.0, "lit": 0.42}))
			k.ball(p + Vector3(-0.04, 0.04, 0.07), Vector3(0.035, 0.02, 0.035), Color(0.35, 0.75, 0.35), o({"line": 0.0, "seg": 6}))
	# deck 2: sandwiches
	k.box(Vector3(x_back + 0.3, 1.18, zc), Vector3(0.44, 0.02, length - 0.06), STEEL, o())
	for i in 14:
		var p := Vector3(x_back + 0.38, 1.25, z0 + 0.12 + i * 0.15)
		k.prism(p, Vector3(0.11, 0.11, 0.05), Color(0.98, 0.94, 0.8), o({"rot": Vector3(0, 90, 0), "line": 0.4}))
		k.box(p + Vector3(0.0, -0.02, 0), Vector3(0.056, 0.035, 0.08), [Color(0.95, 0.85, 0.3), Color(0.4, 0.75, 0.4), Color(0.95, 0.5, 0.5)][i % 3], o({"line": 0.0}))
	# deck 3: onigiri, rice triangles with a strip of nori
	k.box(Vector3(x_back + 0.25, 1.55, zc), Vector3(0.36, 0.02, length - 0.06), STEEL, o())
	for row in 2:
		for i in 18:
			var p := Vector3(x_back + 0.34 - row * 0.12, 1.605, z0 + 0.1 + i * 0.118)
			k.prism(p, Vector3(0.09, 0.085, 0.035), Color(0.99, 0.99, 0.97), o({"rot": Vector3(0, 90, 0), "line": 0.4, "lit": 0.42}))
			k.box(p + Vector3(0.019, -0.02, 0), Vector3(0.002, 0.045, 0.04), Color(0.08, 0.12, 0.1), o({"line": 0.0}))
			k.box(p + Vector3(0.019, 0.022, 0), Vector3(0.002, 0.012, 0.02), [Color(0.9, 0.2, 0.2), Color(0.2, 0.6, 0.3), Color(0.95, 0.6, 0.1)][i % 3], o({"line": 0.0}))
	for y in [0.81, 1.19, 1.56]:
		k.box(Vector3(x_back + 0.6 - (y - 0.8) * 0.4, y - 0.03, zc), Vector3(0.01, 0.035, length - 0.08), Color(0.99, 0.98, 0.9), o({"line": 0.0}))

func _lockers() -> void:
	var x := X0 + 0.22
	var z0 := -1.2
	var z1 := -0.4
	k.slab(Vector3(X0 + 0.02, FLOOR, z0), Vector3(X0 + 0.42, 2.0, z1), Color(0.92, 0.93, 0.95), o())
	for r in 5:
		for c in 3:
			if r == 2 and c == 1:
				continue
			k.box(Vector3(X0 + 0.425, 0.45 + r * 0.33, z0 + 0.14 + c * 0.26), Vector3(0.01, 0.29, 0.22), Color(0.82, 0.86, 0.9), o({"line": 0.5}))
			k.box(Vector3(X0 + 0.432, 0.45 + r * 0.33, z0 + 0.22 + c * 0.26), Vector3(0.01, 0.06, 0.015), FRAME, o({"line": 0.0}))
	k.box(Vector3(X0 + 0.43, 1.11, z0 + 0.4), Vector3(0.01, 0.2, 0.16), Color(0.35, 0.7, 1.0), o({"emit": 1.0, "line": 0.4}))
	k.slab(Vector3(X0 + 0.02, 2.0, z0), Vector3(X0 + 0.44, 2.12, z1), TEAL, o())
	k.text("PARCEL LOCKER", Vector3(x + 0.23, 2.06, (z0 + z1) * 0.5), 0.07, Color(1, 1, 1), {"indoor": true, "rot": Vector3(0, 90, 0)})

func _magazines() -> void:
	var x0 := -4.3
	var x1 := -0.55
	var z_back := -0.32
	k.slab(Vector3(x0, FLOOR, z_back - 0.42), Vector3(x1, 0.45, z_back), Color(0.88, 0.9, 0.93), o())
	k.slab(Vector3(x0, 0.45, z_back - 0.04), Vector3(x1, 1.08, z_back), Color(0.88, 0.9, 0.93), o())
	for s in [x0, x1]:
		k.slab(Vector3(s - 0.02, FLOOR, z_back - 0.42), Vector3(s + 0.02, 1.1, z_back), FRAME, o())
	var tiers := [[0.5, -0.36], [0.74, -0.24], [0.96, -0.12]]
	for tier in tiers:
		var y: float = tier[0]
		var dz: float = tier[1]
		k.box(Vector3((x0 + x1) * 0.5, y - 0.02, z_back + dz + 0.03), Vector3(x1 - x0 - 0.04, 0.02, 0.1), STEEL, o())
		var x := x0 + 0.14
		while x < x1 - 0.12:
			var cover := _pick()
			var p := Vector3(x, y + 0.12, z_back + dz)
			k.box(p, Vector3(0.21, 0.28, 0.012), cover, o({"rot": Vector3(-14, 0, 0), "line": 0.3, "lit": 0.42}))
			k.box(p + Vector3(0, 0.07, -0.008), Vector3(0.17, 0.06, 0.002), cover.lightened(0.6), o({"rot": Vector3(-14, 0, 0), "line": 0.0}))
			k.box(p + Vector3(0.03, -0.04, -0.008), Vector3(0.1, 0.1, 0.002), _pick(), o({"rot": Vector3(-14, 0, 0), "line": 0.0}))
			x += 0.235

## Double-sided island of shelves centred on z, running along X.
func _gondola(zc: float) -> void:
	var x0 := -3.7
	var x1 := -1.0
	var depth := 0.55
	k.slab(Vector3(x0, FLOOR, zc - depth * 0.5), Vector3(x1, 0.3, zc + depth * 0.5), FRAME, o())
	k.slab(Vector3(x0, 0.3, zc - 0.02), Vector3(x1, 1.45, zc + 0.02), Color(0.9, 0.9, 0.92), o())
	k.slab(Vector3(x0 - 0.03, FLOOR, zc - depth * 0.5), Vector3(x0, 1.45, zc + depth * 0.5), Color(0.9, 0.9, 0.92), o())
	k.slab(Vector3(x1, FLOOR, zc - depth * 0.5), Vector3(x1 + 0.03, 1.45, zc + depth * 0.5), Color(0.9, 0.9, 0.92), o())
	for side in [1.0, -1.0]:
		for level in 4:
			var y := 0.32 + level * 0.36
			var shelf_z: float = zc + side * depth * 0.25
			k.box(Vector3((x0 + x1) * 0.5, y, shelf_z), Vector3(x1 - x0, 0.02, depth * 0.5 - 0.02), Color(0.86, 0.87, 0.9), o())
			k.box(Vector3((x0 + x1) * 0.5, y - 0.01, zc + side * (depth * 0.5 - 0.005)), Vector3(x1 - x0, 0.04, 0.01), Color(0.99, 0.98, 0.9), o({"line": 0.0}))
			_fill_shelf(x0 + 0.08, x1 - 0.08, y + 0.01, zc + side * depth * 0.3, side, level)
		# little shelf talkers sticking out into the aisle
		for i in 2:
			var t := Vector3(lerpf(x0, x1, 0.3 + i * 0.45), 0.32 + (i + 1) * 0.36 - 0.06, zc + side * (depth * 0.5 + 0.05))
			k.box(t, Vector3(0.12, 0.09, 0.006), [Color(1.0, 0.85, 0.15), Color(1.0, 0.35, 0.35)][i], o({"rot": Vector3(0, 90, 0), "lit": 0.5}))
	# end cap facing the door: stacked cases with a SALE board
	for i in 3:
		for j in 3 - i:
			k.box(Vector3(x1 + 0.2, 0.32 + i * 0.2, zc - 0.17 + j * 0.24 + i * 0.12), Vector3(0.3, 0.19, 0.22), [ORANGE, Color(0.95, 0.85, 0.3), Color(0.9, 0.3, 0.35)][(i + j) % 3], o({"lit": 0.42}))
	k.rod(Vector3(x1 + 0.2, 0.9, zc), Vector3(x1 + 0.2, 1.35, zc), 0.01, STEEL, o())
	k.box(Vector3(x1 + 0.2, 1.42, zc), Vector3(0.02, 0.2, 0.34), Color(1.0, 0.9, 0.2), o({"lit": 0.5}))
	k.text("SALE", Vector3(x1 + 0.215, 1.42, zc), 0.1, Color(0.85, 0.1, 0.1), {"indoor": true, "rot": Vector3(0, 90, 0), "outline": 4})

func _fill_shelf(x0: float, x1: float, y: float, z: float, side: float, level: int) -> void:
	var kind := (level + (1 if side > 0 else 0) + int(z * 3.0)) % 4
	var x := x0
	while x < x1:
		var color := _pick()
		match kind:
			0: # bags of snacks
				k.box(Vector3(x + 0.08, y + 0.12, z), Vector3(0.15, 0.23, 0.07), color, o({"line": 0.35, "lit": 0.42, "gloss": 0.3}))
				k.box(Vector3(x + 0.08, y + 0.15, z + side * 0.036), Vector3(0.09, 0.07, 0.002), color.lightened(0.5), o({"line": 0.0}))
				x += 0.17
			1: # cup noodles in stacks of two
				for s in 2:
					k.cyl(Vector3(x + 0.06, y + 0.055 + s * 0.11, z), 0.05, 0.1, Color(0.97, 0.96, 0.92), o({"top": 1.25, "seg": 10, "line": 0.3, "lit": 0.42}))
					k.cyl(Vector3(x + 0.06, y + 0.06 + s * 0.11, z), 0.056, 0.03, color, o({"seg": 10, "line": 0.0}))
				x += 0.13
			2: # boxes
				k.box(Vector3(x + 0.06, y + 0.09, z), Vector3(0.1, 0.17, 0.12), color, o({"line": 0.35, "lit": 0.42}))
				x += 0.115
			_: # bottles and household goods
				k.cyl(Vector3(x + 0.04, y + 0.1, z), 0.035, 0.2, color, o({"seg": 8, "line": 0.3, "lit": 0.42, "gloss": 0.4}))
				k.cyl(Vector3(x + 0.04, y + 0.215, z), 0.015, 0.03, Color(0.95, 0.95, 0.95), o({"seg": 6, "line": 0.0}))
				x += 0.085

func _freezer() -> void:
	var c := Vector3(0.5, FLOOR, -1.95)
	k.box(c + Vector3(0, 0.4, 0), Vector3(1.6, 0.8, 0.62), Color(0.95, 0.96, 0.98), o({"gloss": 0.3}))
	k.box(c + Vector3(0, 0.55, 0.312), Vector3(1.5, 0.12, 0.01), Color(0.35, 0.6, 0.95), o({"line": 0.0, "emit": 0.3}))
	k.text("ICE CREAM", c + Vector3(0, 0.55, 0.32), 0.07, Color(1, 1, 1), {"indoor": true})
	k.box(c + Vector3(0, 0.77, 0), Vector3(1.48, 0.04, 0.5), Color(0.6, 0.78, 0.95), o({"emit": 0.3, "line": 0.0}))
	for i in 18:
		var p := c + Vector3(-0.66 + (i % 9) * 0.165, 0.83, -0.12 + (i / 9) * 0.24)
		if i % 2 == 0:
			k.cyl(p, 0.055, 0.07, _pick(), o({"seg": 10, "line": 0.3, "lit": 0.42}))
		else:
			k.box(p, Vector3(0.12, 0.06, 0.18), _pick(), o({"line": 0.3, "lit": 0.42}))
	k.box(c + Vector3(0, 0.8, 0), Vector3(1.6, 0.03, 0.62), FRAME, o({"line": 0.0}))
	var lid: MeshInstance3D = scene.add_glass(c + Vector3(0, 0.885, 0), Vector2(1.5, 0.54), Basis(Vector3.RIGHT, -PI * 0.5), 0.0, true)
	lid.layers = Kit.LAYER_IN
	for x in [-0.8, 0.0, 0.8]:
		k.box(c + Vector3(x, 0.89, 0), Vector3(0.03, 0.03, 0.62), FRAME, o())
	for z in [-0.3, 0.3]:
		k.box(c + Vector3(0, 0.89, z), Vector3(1.6, 0.03, 0.03), FRAME, o())

func _counter() -> void:
	var x0 := -0.6
	var x1 := 1.65
	var z0 := -3.55
	var z1 := -2.95
	var top := 1.2
	k.slab(Vector3(x0, FLOOR, z0), Vector3(x1, top - 0.04, z1), Color(0.95, 0.95, 0.97), o())
	k.slab(Vector3(x0 - 0.03, top - 0.04, z0 - 0.02), Vector3(x1 + 0.03, top, z1 + 0.04), Color(0.78, 0.58, 0.4), o({"gloss": 0.4, "mat": "wood"}))
	k.slab(Vector3(x0, 0.3, z1), Vector3(x1, 0.42, z1 + 0.01), TEAL, o({"line": 0.0}))
	k.slab(Vector3(x0, 0.42, z1), Vector3(x1, 0.47, z1 + 0.01), ORANGE, o({"line": 0.0}))
	k.box(Vector3(0.9, 0.82, z1 + 0.01), Vector3(0.5, 0.4, 0.01), Color(1.0, 0.92, 0.6), o({"lit": 0.5}))
	k.text("FRIED\nCHICKEN", Vector3(0.9, 0.86, z1 + 0.018), 0.07, Color(0.75, 0.25, 0.1), {"indoor": true})
	k.ball(Vector3(0.9, 0.7, z1 + 0.016), Vector3(0.1, 0.07, 0.01), Color(0.9, 0.6, 0.2), o({"line": 0.3, "seg": 8}))
	# self-serve coffee
	var cm := Vector3(-0.35, top, -3.3)
	k.box(cm + Vector3(0, 0.32, -0.05), Vector3(0.38, 0.64, 0.4), Color(0.18, 0.18, 0.22), o({"gloss": 0.5}))
	k.box(cm + Vector3(0, 0.55, 0.151), Vector3(0.24, 0.1, 0.01), Color(0.4, 0.8, 1.0), o({"emit": 1.0, "line": 0.3}))
	k.box(cm + Vector3(0, 0.2, 0.08), Vector3(0.3, 0.02, 0.2), STEEL, o())
	k.cyl(cm + Vector3(0, 0.08, 0.08), 0.04, 0.1, Color(0.97, 0.97, 0.95), o({"top": 1.2, "seg": 10}))
	k.cyl(cm + Vector3(0.3, 0.12, 0.05), 0.045, 0.24, Color(0.97, 0.97, 0.95), o({"seg": 10}))
	k.box(cm + Vector3(0, 0.73, 0), Vector3(0.36, 0.14, 0.02), Color(0.4, 0.22, 0.12), o({"lit": 0.5}))
	k.text("COFFEE", cm + Vector3(0, 0.73, 0.012), 0.07, Color(1.0, 0.95, 0.85), {"indoor": true})
	scene.add_steam(cm + Vector3(0, 0.25, 0.08), Vector2(0.12, 0.3), 0.25)
	# oden: a steel bath of broth with eggs, daikon, konnyaku and chikuwa
	var od := Vector3(0.28, top, -3.25)
	k.box(od + Vector3(0, 0.08, 0), Vector3(0.56, 0.16, 0.44), STEEL, o({"gloss": 0.7}))
	k.box(od + Vector3(0, 0.155, 0), Vector3(0.5, 0.01, 0.38), Color(0.8, 0.55, 0.22), o({"emit": 0.25, "line": 0.0, "gloss": 0.6}))
	for x in [-0.08, 0.08]:
		k.box(od + Vector3(x, 0.15, 0), Vector3(0.012, 0.04, 0.38), STEEL, o({"line": 0.0}))
	k.box(od + Vector3(0, 0.15, 0), Vector3(0.5, 0.04, 0.012), STEEL, o({"line": 0.0}))
	for i in 3:
		var cell := od + Vector3(-0.17, 0.17, -0.1 + i * 0.1)
		k.ball(cell, Vector3(0.05, 0.04, 0.04), [Color(0.95, 0.85, 0.65), Color(0.97, 0.95, 0.9), Color(0.8, 0.6, 0.35)][i], o({"line": 0.4, "seg": 8}))
	for i in 3:
		k.cyl(od + Vector3(0.0, 0.17, -0.12 + i * 0.12), 0.04, 0.035, Color(0.95, 0.88, 0.72), o({"seg": 10, "line": 0.4}))
	for i in 2:
		k.prism(od + Vector3(0.17, 0.18, -0.1 + i * 0.13), Vector3(0.08, 0.06, 0.02), Color(0.55, 0.55, 0.6), o({"rot": Vector3(-90, 0, 0), "line": 0.4}))
	k.rod(od + Vector3(0.12, 0.17, 0.13), od + Vector3(0.22, 0.17, 0.13), 0.02, Color(0.85, 0.65, 0.4), o({"line": 0.4}))
	k.rod(od + Vector3(-0.2, 0.17, 0.15), od + Vector3(-0.05, 0.3, 0.15), 0.004, Color(0.85, 0.75, 0.55), o({"line": 0.0}))
	k.box(od + Vector3(0, 0.36, -0.18), Vector3(0.24, 0.14, 0.01), ORANGE, o({"lit": 0.5}))
	k.rod(od + Vector3(0, 0.16, -0.18), od + Vector3(0, 0.29, -0.18), 0.006, STEEL, o())
	k.text("ODEN", od + Vector3(0, 0.36, -0.172), 0.08, Color(1, 1, 1), {"indoor": true})
	scene.add_steam(od + Vector3(0, 0.35, 0), Vector2(0.45, 0.5), 0.3)
	# hot snack case
	var hs := Vector3(0.9, top, -3.28)
	k.box(hs + Vector3(0, 0.03, 0), Vector3(0.48, 0.06, 0.4), FRAME, o())
	k.box(hs + Vector3(0, 0.42, 0), Vector3(0.48, 0.04, 0.4), FRAME, o())
	k.box(hs + Vector3(0, 0.23, -0.19), Vector3(0.46, 0.36, 0.01), Color(1.0, 0.8, 0.5), o({"emit": 1.0, "line": 0.0}))
	k.box(hs + Vector3(0, 0.22, 0), Vector3(0.44, 0.012, 0.36), STEEL, o({"line": 0.0}))
	for i in 5:
		k.ball(hs + Vector3(-0.17 + i * 0.085, 0.1, 0.02), Vector3(0.07, 0.05, 0.06), Color(0.85, 0.55, 0.2), o({"seg": 8, "line": 0.4, "lit": 0.5}))
		k.box(hs + Vector3(-0.17 + i * 0.085, 0.26, 0.02), Vector3(0.07, 0.02, 0.1), Color(0.95, 0.75, 0.35), o({"line": 0.4, "lit": 0.5}))
	for x in [-0.23, 0.23]:
		k.box(hs + Vector3(x, 0.22, 0.19), Vector3(0.02, 0.4, 0.02), FRAME, o())
	var front: MeshInstance3D = scene.add_glass(hs + Vector3(0, 0.22, 0.2), Vector2(0.44, 0.36), Basis.IDENTITY, 0.0, true)
	front.layers = Kit.LAYER_IN
	# register
	var rg := Vector3(1.38, top, -3.3)
	k.box(rg + Vector3(0, 0.06, 0), Vector3(0.4, 0.12, 0.36), Color(0.2, 0.2, 0.24), o())
	k.box(rg + Vector3(0, 0.27, -0.06), Vector3(0.34, 0.24, 0.03), Color(0.18, 0.18, 0.22), o({"rot": Vector3(-15, 0, 0)}))
	k.box(rg + Vector3(0, 0.27, -0.08), Vector3(0.3, 0.2, 0.01), Color(0.4, 0.75, 1.0), o({"rot": Vector3(-15, 0, 0), "emit": 0.8, "line": 0.0}))
	k.box(rg + Vector3(0.0, 0.3, 0.16), Vector3(0.18, 0.08, 0.03), Color(0.18, 0.18, 0.22), o())
	k.box(rg + Vector3(0.0, 0.3, 0.176), Vector3(0.15, 0.05, 0.005), Color(0.45, 1.0, 0.6), o({"emit": 1.0, "line": 0.0}))
	k.rod(rg + Vector3(0, 0.12, 0.16), rg + Vector3(0, 0.26, 0.16), 0.01, FRAME, o())
	k.box(rg + Vector3(-0.28, 0.04, 0.12), Vector3(0.1, 0.08, 0.14), Color(0.25, 0.25, 0.3), o())
	# staff side: back counter, microwave, cigarette wall, menu board, coffee cups
	k.slab(Vector3(-0.5, FLOOR, Z_BACK + 0.02), Vector3(1.35, 1.1, Z_BACK + 0.36), Color(0.9, 0.9, 0.93), o())
	k.box(Vector3(1.05, 1.24, Z_BACK + 0.2), Vector3(0.45, 0.28, 0.32), Color(0.85, 0.86, 0.9), o())
	k.box(Vector3(1.0, 1.24, Z_BACK + 0.361), Vector3(0.28, 0.18, 0.01), Color(0.25, 0.25, 0.3), o({"line": 0.0, "emit": 0.2}))
	k.slab(Vector3(-0.5, 1.4, Z_BACK + 0.02), Vector3(1.3, 2.2, Z_BACK + 0.2), Color(0.25, 0.27, 0.32), o())
	k.slab(Vector3(-0.47, 1.43, Z_BACK + 0.19), Vector3(1.27, 2.17, Z_BACK + 0.2), Color(0.95, 0.95, 1.0), o({"emit": 0.6, "line": 0.0}))
	for r in 6:
		for c in 14:
			k.box(Vector3(-0.4 + c * 0.12, 1.5 + r * 0.12, Z_BACK + 0.22), Vector3(0.08, 0.1, 0.03), _pick(), o({"line": 0.0, "lit": 0.45}))
	k.slab(Vector3(-0.5, 2.3, Z_BACK + 0.02), Vector3(1.3, 2.75, Z_BACK + 0.06), Color(0.15, 0.15, 0.2), o())
	var menu := [[Color(1.0, 0.75, 0.3), "KARAAGE"], [Color(0.95, 0.85, 0.5), "KOROKKE"], [Color(0.85, 0.45, 0.25), "NIKUMAN"], [Color(0.55, 0.35, 0.2), "COFFEE"]]
	for i in menu.size():
		var p := Vector3(-0.28 + i * 0.44, 2.55, Z_BACK + 0.065)
		k.box(p, Vector3(0.4, 0.4, 0.01), Color(1.0, 0.98, 0.92), o({"emit": 0.9, "line": 0.0}))
		k.ball(p + Vector3(0, 0.05, 0.008), Vector3(0.18, 0.14, 0.01), menu[i][0], o({"emit": 0.5, "line": 0.0, "seg": 10}))
		k.text(menu[i][1], p + Vector3(0, -0.13, 0.012), 0.05, Color(0.2, 0.15, 0.1), {"indoor": true})

func _eat_in() -> void:
	var x0 := 1.85
	k.slab(Vector3(x0, 1.0, -2.6), Vector3(X1, 1.05, -0.5), Color(0.78, 0.58, 0.4), o({"gloss": 0.3, "mat": "wood"}))
	for z in [-2.5, -0.6]:
		k.box(Vector3(2.15, 0.6, z), Vector3(0.05, 0.8, 0.05), FRAME, o())
	for z in [-2.15, -1.55, -0.95]:
		k.cyl(Vector3(1.62, 0.45, z), 0.03, 0.5, FRAME, o({"seg": 8}))
		k.cyl(Vector3(1.62, FLOOR + 0.01, z), 0.17, 0.02, FRAME, o({"seg": 12}))
		k.cyl(Vector3(1.62, 0.73, z), 0.17, 0.06, Color(0.9, 0.4, 0.3), o({"seg": 14, "gloss": 0.3}))
	# a forgotten coffee, a shopping bag and a vinyl umbrella against the counter
	k.cyl(Vector3(2.0, 1.11, -1.2), 0.04, 0.12, Color(0.98, 0.98, 0.96), o({"top": 1.2, "seg": 10}))
	k.cyl(Vector3(2.0, 1.175, -1.2), 0.048, 0.015, Color(0.35, 0.22, 0.15), o({"seg": 10}))
	k.box(Vector3(2.05, 1.16, -1.8), Vector3(0.18, 0.2, 0.1), Color(0.96, 0.97, 1.0), o({"rot": Vector3(0, 20, 8), "lit": 0.42}))
	k.rod(Vector3(1.86, FLOOR, -0.75), Vector3(1.9, 0.95, -0.8), 0.008, STEEL, o())
	k.cyl(Vector3(1.875, 0.45, -0.77), 0.05, 0.55, Color(0.82, 0.9, 0.96), o({"basis": Kit.aim(Vector3(-0.04, -0.95, 0.05)), "top": 0.3, "seg": 8, "gloss": 0.8}))

func _signs_and_posters() -> void:
	# hanging aisle signs
	var hangers := [[Vector3(-2.35, 2.62, -3.3), "DRINKS"], [Vector3(-2.35, 2.62, -2.1), "SNACKS · FOOD"], [Vector3(-4.2, 2.62, -2.4), "BENTO"], [Vector3(0.5, 2.62, -2.75), "REGISTER"]]
	for h in hangers:
		var p: Vector3 = h[0]
		var vertical: bool = h[1] == "BENTO"
		var size := Vector3(0.08, 0.26, 0.9) if vertical else Vector3(0.9, 0.26, 0.08)
		k.box(p, size, Color(0.97, 0.99, 1.0), o({"emit": 0.6}))
		k.box(p + Vector3(0, -0.11, 0), size + Vector3(0.01, -0.22, 0.01), TEAL, o({"emit": 0.5, "line": 0.0}))
		for s in [-0.35, 0.35]:
			var off := Vector3(0, 0, s) if vertical else Vector3(s, 0, 0)
			k.rod(p + off + Vector3(0, 0.13, 0), p + off + Vector3(0, CEIL - p.y, 0), 0.006, STEEL, o({"line": 0.0}))
		for face in [1.0, -1.0]:
			var rot := Vector3(0, 90 * face, 0) if vertical else Vector3(0, 0 if face > 0 else 180, 0)
			var n := Vector3(face * 0.045, 0, 0) if vertical else Vector3(0, 0, face * 0.045)
			k.text(h[1], p + n + Vector3(0, 0.03, 0), 0.1, Color(0.06, 0.35, 0.4), {"indoor": true, "rot": rot})
	# posters facing out through the glass (read from the street)
	_poster(Vector3(-4.35, 1.05, -0.1), Vector2(0.6, 0.8), Color(1.0, 0.72, 0.82), "SWEETS\nFAIR", Color(0.75, 0.2, 0.4), Basis.IDENTITY)
	_poster(Vector3(-1.62, 1.0, -0.1), Vector2(0.62, 0.78), Color(1.0, 0.7, 0.35), "ODEN\n70 YEN", Color(0.5, 0.15, 0.05), Basis.IDENTITY)
	_oden_skewer(Vector3(-1.62, 1.2, -0.088))
	_poster(Vector3(X1 + 0.03, 1.05, -2.25), Vector2(0.5, 0.7), Color(0.55, 0.32, 0.2), "HOT\nCOFFEE\n100", Color(1.0, 0.92, 0.8), Basis(Vector3.UP, PI * 0.5))
	# indoor posters
	_poster(Vector3(X0 + 0.03, 2.5, -2.4), Vector2(0.7, 0.4), Color(0.35, 0.75, 0.95), "SUMMER\nCAMPAIGN", Color(1, 1, 1), Basis(Vector3.UP, PI * 0.5))

func _poster(center: Vector3, size: Vector2, paper: Color, label: String, ink: Color, face: Basis) -> void:
	k.box(center, Vector3(size.x, size.y, 0.008), paper, o({"basis": face, "lit": 0.55, "line": 0.4}))
	k.box(center + face * Vector3(0, -size.y * 0.42, 0.005), Vector3(size.x, size.y * 0.12, 0.002), paper.darkened(0.25), o({"basis": face, "lit": 0.55, "line": 0.0}))
	var t := k.text(label, center + face * Vector3(0, 0.03, 0.006), size.x * 0.22, ink, {"indoor": true})
	t.basis = face
	t.line_spacing = -16

func _oden_skewer(at: Vector3) -> void:
	k.rod(at + Vector3(0, -0.16, 0), at + Vector3(0, 0.17, 0), 0.006, Color(0.85, 0.75, 0.55), o({"line": 0.3}))
	k.ball(at + Vector3(0, 0.12, 0.004), Vector3(0.06, 0.06, 0.01), Color(0.95, 0.85, 0.6), o({"line": 0.4, "seg": 10, "lit": 0.55}))
	k.prism(at + Vector3(0, 0.03, 0.004), Vector3(0.09, 0.08, 0.01), Color(0.55, 0.55, 0.62), o({"line": 0.4, "lit": 0.55}))
	k.box(at + Vector3(0, -0.07, 0.004), Vector3(0.08, 0.08, 0.01), Color(0.98, 0.92, 0.75), o({"line": 0.4, "lit": 0.55}))

func _entrance_bits() -> void:
	# basket stack, umbrella bag stand and a wet-floor sign just inside the door
	for i in 4:
		var p := Vector3(-0.35, FLOOR + 0.11 + i * 0.07, -0.55)
		k.box(p, Vector3(0.44, 0.2, 0.32), [Color(0.85, 0.2, 0.25), Color(0.2, 0.4, 0.8)][i % 2], o({"lit": 0.55}))
		k.box(p + Vector3(0, 0.1, 0), Vector3(0.38, 0.01, 0.26), Color(0.1, 0.1, 0.12), o({"line": 0.0}))
	var stand := Vector3(1.55, FLOOR, -0.5)
	k.rod(stand, stand + Vector3(0, 0.95, 0), 0.02, STEEL, o())
	k.cyl(stand + Vector3(0, 0.01, 0), 0.15, 0.02, STEEL, o({"seg": 12}))
	k.box(stand + Vector3(0, 0.95, 0), Vector3(0.3, 0.3, 0.12), Color(0.95, 0.96, 1.0), o({"lit": 0.42}))
	k.box(stand + Vector3(0, 0.75, 0.01), Vector3(0.22, 0.4, 0.02), Color(0.85, 0.92, 0.98), o({"line": 0.3}))
	k.text("UMBRELLA\nBAGS", stand + Vector3(0, 0.95, 0.065), 0.04, TEAL, {"indoor": true})
	var sign := Vector3(0.9, FLOOR, -0.65)
	for s in [-1.0, 1.0]:
		k.box(sign + Vector3(0, 0.3, s * 0.08), Vector3(0.3, 0.6, 0.02), Color(1.0, 0.85, 0.1), o({"rot": Vector3(s * 14, 0, 0), "lit": 0.5}))
	k.text("CAUTION\nWET FLOOR", sign + Vector3(0, 0.38, 0.165), 0.045, Color(0.1, 0.1, 0.1), {"indoor": true, "rot": Vector3(-14, 0, 0)})
	# queue footprints and an arrow on the floor in front of the register
	for i in 2:
		var f := Vector3(1.2, FLOOR + 0.002, -2.55 + i * 0.5)
		for s in [-0.07, 0.07]:
			k.quad(f + Vector3(s, 0, 0), Vector2(0.08, 0.18), TEAL, o({"lit": 0.42}))
	k.quad(Vector3(0.5, FLOOR + 0.002, -0.9), Vector2(0.12, 0.5), ORANGE, o({"lit": 0.42}))
	k.prism(Vector3(0.5, FLOOR + 0.003, -1.25), Vector3(0.28, 0.2, 0.002), ORANGE, o({"rot": Vector3(-90, 0, 0), "lit": 0.42, "line": 0.0}))
	k.text("WAIT HERE", Vector3(1.2, FLOOR + 0.004, -2.0), 0.06, TEAL * 0.8, {"indoor": true, "rot": Vector3(-90, 0, 0)})

func _stockroom() -> void:
	var dim := {"indoor": true, "lit": 0.18}
	k.slab(Vector3(X0, FLOOR, -5.06), Vector3(X1, CEIL, -5.04), Color(0.7, 0.7, 0.72), dim)
	for i in 6:
		var p := Vector3(1.6 + (i % 2) * 0.3, FLOOR + 0.18 + (i / 2) * 0.36, -4.75)
		k.box(p, Vector3(0.28, 0.34, 0.4), Color(0.72, 0.55, 0.38), dim)
	k.slab(Vector3(0.5, FLOOR, -5.0), Vector3(1.3, 2.0, -4.6), Color(0.6, 0.62, 0.66), dim)
	# the staff door, swung part-way open
	var hinge := Vector3(X1 - 0.05, FLOOR, Z_BACK)
	var door := Basis(Vector3.UP, deg_to_rad(-28))
	k.box(hinge + door * Vector3(-0.4, 1.05, -0.02), Vector3(0.8, 2.1, 0.04), Color(0.65, 0.72, 0.8), o({"basis": door}))
	k.box(hinge + door * Vector3(-0.4, 1.55, 0.005), Vector3(0.3, 0.3, 0.01), Color(0.3, 0.32, 0.35), o({"basis": door, "line": 0.3}))
	k.box(hinge + door * Vector3(-0.4, 1.2, 0.006), Vector3(0.36, 0.1, 0.01), Color(0.95, 0.95, 0.98), o({"basis": door, "line": 0.0}))
	var t := k.text("STAFF ONLY", hinge + door * Vector3(-0.4, 1.2, 0.013), 0.05, Color(0.75, 0.15, 0.15), {"indoor": true})
	t.basis = door
	k.box(hinge + door * Vector3(-0.72, 1.0, 0.03), Vector3(0.1, 0.03, 0.04), STEEL, o({"basis": door}))
	k.slab(Vector3(1.38, FLOOR, Z_BACK - 0.03), Vector3(1.42, 2.32, Z_BACK + 0.03), FRAME, o())
	k.slab(Vector3(1.38, 2.28, Z_BACK - 0.03), Vector3(X1, 2.32, Z_BACK + 0.03), FRAME, o())
