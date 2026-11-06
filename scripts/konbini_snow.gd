extends RefCounted
## Snow lying on the diorama when weather_kind is "snow": a blanket on the lot and
## sidewalks (with footprints to the door and none under the eaves), slush along the
## kerbs and between the tyre tracks on the roads, and white caps on roofs, walls,
## rails, machines, lamps, signals and the parked bicycles.
## Called last from scripts/konbini_exterior.gd with that builder.

const Kit := preload("res://scripts/konbini_kit.gd")

const LOT := 0.12
const SNOW := Color(0.9, 0.93, 1.0)
const SLUSH := Color(0.56, 0.6, 0.74)
const TRACK := Color(0.6, 0.65, 0.8)

static func cover(b: RefCounted) -> void:
	var k: Kit = b.k
	var ramen: bool = b.ramen
	var snow := {"gloss": 0.1, "line": 0.3}
	var deep := LOT + 0.045
	var eave := 1.05 if ramen else 1.45
	# ground: everything raised except under the eaves in front of the shop
	for area in [
		[-9.0, 4.0, 5.05, 5.06], [4.0, -9.0, 5.06, 4.0], [-6.6, eave, 4.0, 4.0], [2.4, -9.0, 4.0, 0.0],
		[-6.6, -9.0, -5.0, eave], [-5.0, -9.0, 2.4, -5.2], [-9.0, -9.0, -6.6, 4.0],
		[-9.0, 8.75, 9.0, 9.0], [8.75, -9.0, 9.0, 8.75],
	]:
		k.slab(Vector3(area[0], LOT, area[1]), Vector3(area[2], deep, area[3]), SNOW, snow)
	k.slab(Vector3(-6.6, LOT, eave - 0.25), Vector3(4.0, LOT + 0.02, eave), SNOW * 0.95, {"gloss": 0.1, "line": 0.0})
	# footprints: along the sidewalk and in to the door
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var step := Vector3(0.4, deep + 0.003, 4.5)
	while step.z > eave + 0.1:
		var side := 0.09 if int(step.z * 3.0) % 2 == 0 else -0.09
		k.quad(step + Vector3(side, 0, 0), Vector2(0.11, 0.24), TRACK, {"rot": Vector3(0, rng.randf_range(-12, 12), 0)})
		step.z -= 0.36
	for i in 22:
		var x := -8.6 + i * 0.62
		k.quad(Vector3(x, deep + 0.003, 4.45 + (0.08 if i % 2 == 0 else -0.08)), Vector2(0.24, 0.11), TRACK, {"rot": Vector3(0, rng.randf_range(-10, 10), 0)})
	# roads: slush along both kerbs and between the tyre tracks of each lane
	var road := {"gloss": 0.35, "line": 0.0}
	# banks of slush along the kerbs, broken into lumps so they do not read as paint
	for edge in [5.62, 8.42]:
		var x := -9.0
		while x < 9.0:
			var length := rng.randf_range(0.5, 1.6)
			var w := rng.randf_range(0.18, 0.36)
			k.box(Vector3(x + length * 0.5, 0.018, edge + rng.randf_range(-0.06, 0.06)), Vector3(length, 0.036, w), SLUSH, road)
			x += length + rng.randf_range(0.05, 0.5)
		var z := -9.0
		while z < 5.0:
			var length := rng.randf_range(0.5, 1.6)
			var w := rng.randf_range(0.18, 0.36)
			k.box(Vector3(edge + rng.randf_range(-0.06, 0.06), 0.018, z + length * 0.5), Vector3(w, 0.036, length), SLUSH, road)
			z += length + rng.randf_range(0.05, 0.5)
	# a few lumps left between the tyre tracks
	for i in 26:
		k.box(Vector3(rng.randf_range(-8.8, 8.8), 0.015, rng.randf_range(6.7, 7.1)), Vector3(rng.randf_range(0.2, 0.6), 0.03, rng.randf_range(0.1, 0.22)), SLUSH, road)
		k.box(Vector3(rng.randf_range(6.7, 7.1), 0.015, rng.randf_range(-8.8, 5.0)), Vector3(rng.randf_range(0.1, 0.22), 0.03, rng.randf_range(0.2, 0.6)), SLUSH, road)
	# caps on everything that faces the sky
	var caps := [
		[Vector3(-9.05, 5.76, -6.1), Vector3(-6.62, 5.86, 2.5)],        # neighbour roof
		[Vector3(-8.75, 2.28, 2.4), Vector3(-7.65, 2.34, 2.85)],        # its door canopy
		[Vector3(-6.62, 1.41, -8.97), Vector3(4.02, 1.48, -8.73)],      # back wall
		[Vector3(-9.02, 1.21, 3.73), Vector3(-8.58, 1.28, 3.97)],       # yard walls
		[Vector3(-7.87, 1.21, 3.73), Vector3(-6.73, 1.28, 3.97)],
		[Vector3(-6.75, 1.15, -6.0), Vector3(-6.6, 1.21, 2.4)],         # alley wall
		[Vector3(2.42, LOT + 1.885, -4.96), Vector3(3.16, LOT + 1.95, -3.29)],  # vending machines
		[Vector3(-5.35, LOT + 0.63, -1.7), Vector3(-5.05, LOT + 0.68, -0.9)],   # air-conditioner units
		[Vector3(-5.35, LOT + 0.63, -2.8), Vector3(-5.05, LOT + 0.68, -2.0)],
		[Vector3(-5.35, 2.3, -2.25), Vector3(-5.05, 2.35, -1.45)],
		[Vector3(-7.82, 1.85, 4.0), Vector3(-6.78, 1.9, 4.16)],         # notice board roof
		[Vector3(-6.14, 5.43, 5.68), Vector3(-5.86, 5.47, 6.22)],       # street lamp head
		[Vector3(8.45, 5.18, 6.3), Vector3(8.75, 5.23, 7.5)],           # signal heads
		[Vector3(6.3, 5.18, 8.45), Vector3(7.5, 5.23, 8.75)],
		[Vector3(-8.9, 3.08, 2.5), Vector3(-6.85, 3.1, 3.12)],          # balcony floor
	]
	if not ramen:
		caps.append([Vector3(-5.0, 4.18, -5.2), Vector3(2.4, 4.24, 0.0)])      # konbini roof
		caps.append([Vector3(-5.05, 2.88, 0.0), Vector3(2.45, 2.94, 1.32)])    # awning
	for cap in caps:
		k.slab(cap[0], cap[1], SNOW, snow)
	for rail in [[Vector3(-8.9, 0.97, 4.95), Vector3(-3.4, 0.97, 4.95)], [Vector3(4.95, 0.97, -8.9), Vector3(4.95, 0.97, -0.4)]]:
		k.rod(rail[0], rail[1], 0.03, SNOW, {"seg": 6, "line": 0.3})
	k.rod(Vector3(-8.9, 3.89, 3.12), Vector3(-6.85, 3.89, 3.12), 0.028, SNOW, {"seg": 6, "line": 0.3})
	# the bicycles' saddles and baskets
	for z in [-1.95, -1.15]:
		k.box(Vector3(3.48, 1.0, z), Vector3(0.24, 0.04, 0.16), SNOW, snow)
		k.ball(Vector3(2.68, 1.11, z), Vector3(0.15, 0.04, 0.17), SNOW, snow)
