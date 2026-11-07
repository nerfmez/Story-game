extends RefCounted
## A block under a railway viaduct (layout = "viaduct"): a brick viaduct runs across
## the base on four arches. In the arches: an izakaya, the ramen shop "Menya Yukiakari",
## a yakitori stand and a bicycle park. A train crosses the deck now and then. In front
## a narrow street, a sidewalk with poles and wires, a small coin parking lot; behind,
## a back lane and the backs of apartment buildings.
## Edges: left and right carry the viaduct and the street on through; front and back are
## buildings and the lot, closed.
## Reuses the street helpers of scripts/konbini_exterior.gd (plinth, poles, wires, bikes).

const Kit := preload("res://scripts/konbini_kit.gd")
const Exterior := preload("res://scripts/konbini_exterior.gd")

const LOT := 0.12
const PIERS := [-9.0, -4.5, 0.0, 4.5, 9.0]
const PIER_HALF := 0.3
const Z_FRONT := 1.6       # arch faces
const Z_BACK := -4.6
const FACADE := 0.9        # shop fronts sit back under the arch: a sheltered porch in front
const SPRING := 2.6        # where the arch curve starts
const CROWN := 4.0         # top of the arch opening
const DECK_BOT := 4.2
const DECK_TOP := 5.0
const TRACKS := [-2.75, -0.45]

const BRICK := Color(0.58, 0.27, 0.21)
const STONE := Color(0.8, 0.76, 0.68)
const CONCRETE := Color(0.55, 0.56, 0.62)
const WOOD_DARK := Color(0.3, 0.19, 0.13)
const WOOD := Color(0.55, 0.36, 0.22)
const PLASTER := Color(0.88, 0.84, 0.76)
const INDIGO := Color(0.13, 0.18, 0.4)
const LANTERN := Color(0.95, 0.22, 0.14)
const STEEL := Color(0.78, 0.8, 0.85)
const SNOW := Color(0.9, 0.93, 1.0)
const SLUSH := Color(0.56, 0.6, 0.74)
const INK := Color(0.08, 0.06, 0.06)

## look-at point, yaw, pitch, distance
const VIEWS := [
	[Vector3(0.0, 2.2, 0.8), -24.0, 25.0, 27.0],      # the whole block, the viaduct across it
	[Vector3(-2.25, 1.7, 0.6), 0.0, 7.0, 8.5],        # straight at the ramen shop
	[Vector3(0.0, 0.0, 0.0), 30.0, 60.0, 30.0],       # from above
	[Vector3(-2.0, 2.6, 2.4), 76.0, 9.0, 12.0],       # down the street, arches on the right
	[Vector3(-1.95, 1.3, 1.2), 18.0, 7.0, 5.0],       # at the ramen door
	[Vector3(-1.0, 1.9, -5.45), 88.0, 12.0, 9.5],     # down the back lane
]
## Roofs the snow does not get under: the viaduct deck and the buildings at the back.
const SHELTERS := [
	[Vector4(-9.3, -4.7, 9.3, 1.7), DECK_BOT + 0.8],
	[Vector4(-9.2, -9.2, 9.2, -6.3), 7.8],
]
## Lamps that light up the falling snow: position, radius, colour.
const RAIN_LAMPS := [
	[Vector3(-1.9, 2.5, 1.3), 2.4, Color(0.55, 0.2, 0.12)],
	[Vector3(-7.8, 2.5, 1.3), 2.4, Color(0.55, 0.2, 0.12)],
	[Vector3(2.0, 1.6, 1.4), 2.4, Color(0.5, 0.35, 0.18)],
	[Vector3(-6.0, 4.6, 5.4), 4.0, Color(0.45, 0.55, 0.65)],
	[Vector3(4.5, 4.6, 5.4), 4.0, Color(0.45, 0.55, 0.65)],
	[Vector3(6.75, 3.5, 0.6), 3.0, Color(0.35, 0.45, 0.38)],
	[Vector3(5.8, 1.2, 1.8), 2.2, Color(0.35, 0.45, 0.55)],
]

static func build(kit: Kit, scene: Node3D) -> void:
	scene.plate_text = "麺屋ゆきあかり  ·  高架下の雪の夜"
	var b := Exterior.new()
	b.k = kit
	b.scene = scene
	b._base()
	_ground(kit)
	_viaduct(kit)
	_train(kit, scene)
	_ramen(kit, scene)
	_ramen_inside(kit, scene)
	_izakaya(kit, scene)
	_yakitori(kit, scene)
	_bike_park(kit, b)
	_back(kit, b, scene)
	_street(kit, b)
	if scene.weather_kind == "snow":
		_snow(kit)

## Bottom of the arch opening's curve at x within a bay.
static func _curve(x: float, left: float, right: float) -> float:
	var t := (x - (left + right) * 0.5) / ((right - left) * 0.5)
	return SPRING + (CROWN - SPRING) * sqrt(maxf(0.0, 1.0 - t * t))

static func _bay(i: int) -> Vector2:
	return Vector2(PIERS[i] + PIER_HALF, PIERS[i + 1] - PIER_HALF)

## Fills the arch opening of a bay above `from_y`, between z0 and z1, following the curve.
static func _infill(k: Kit, bay: Vector2, from_y: float, z0: float, z1: float, color: Color, opts := {}) -> void:
	var n := 14
	var w := (bay.y - bay.x) / n
	for j in n:
		var xa := bay.x + j * w
		var top := _curve(xa + w * 0.5, bay.x, bay.y)
		if top > from_y + 0.01:
			k.slab(Vector3(xa, from_y, z0), Vector3(xa + w, top + 0.02, z1), color, opts)

## The arch above a shop front: dark boards with thin battens, the way shops under
## old viaducts close the top of their arch.
static func _fan(k: Kit, bay: Vector2, from_y: float, z: float, color: Color) -> void:
	_infill(k, bay, from_y, z - 0.1, z, color)
	var n := 9
	for j in range(1, n):
		var x := bay.x + j * (bay.y - bay.x) / n
		var top := _curve(x, bay.x, bay.y)
		k.box(Vector3(x, (from_y + top) * 0.5, z + 0.015), Vector3(0.04, top - from_y, 0.03), color * 0.7, {"line": 0.3})

## Fills from the curve up to the deck (the brick spandrel of an arch face).
static func _spandrel(k: Kit, bay: Vector2, z0: float, z1: float) -> void:
	var n := 14
	var w := (bay.y - bay.x) / n
	for j in n:
		var xa := bay.x + j * w
		k.slab(Vector3(xa, _curve(xa + w * 0.5, bay.x, bay.y), z0), Vector3(xa + w, DECK_BOT, z1), BRICK, {"mat": "brick"})
	var prev := Vector3(bay.x, SPRING, 0)
	for j in range(1, n + 1):
		var x := bay.x + j * w
		var p := Vector3(x, _curve(x, bay.x, bay.y), 0)
		for z in [z1 + 0.02, z0 - 0.02]:
			k.rod(Vector3(prev.x, prev.y, z), Vector3(p.x, p.y, z), 0.07, STONE, {"seg": 6, "line": 0.4})
		prev = p

# --- ground ---------------------------------------------------------------------------

static func _ground(k: Kit) -> void:
	k.material("asphalt", 3)
	k.material("paver", 1)
	k.material("brick", 5)
	k.material("siding", 6)
	var pave := {"mat": "paver", "gloss": 0.4}
	k.slab(Vector3(-9, -0.02, Z_BACK), Vector3(9, LOT, 2.6), Color(0.46, 0.42, 0.46), pave)
	k.slab(Vector3(-9, -0.02, 2.45), Vector3(9, LOT + 0.015, 2.6), Color(0.58, 0.6, 0.68), {"gloss": 0.4})
	k.slab(Vector3(-9, -0.02, 2.6), Vector3(9, 0.0, 6.0), Color(0.16, 0.17, 0.25), {"mat": "asphalt", "gloss": 0.6})
	for z in [2.85, 5.75]:
		k.quad(Vector3(0, 0.004, z), Vector2(18, 0.1), Color(0.86, 0.88, 0.94), {"gloss": 0.6})
	k.slab(Vector3(-9, -0.02, 6.0), Vector3(9, LOT, 7.0), Color(0.46, 0.42, 0.46), pave)
	k.slab(Vector3(-9, -0.02, 6.0), Vector3(9, LOT + 0.015, 6.15), Color(0.58, 0.6, 0.68), {"gloss": 0.4})
	k.slab(Vector3(-9, -0.02, 7.0), Vector3(9, 0.06, 9.0), Color(0.2, 0.21, 0.28), {"mat": "asphalt", "gloss": 0.5})
	for i in 8:
		k.quad(Vector3(-8.0 + i * 2.5, 0.064, 8.1), Vector2(0.08, 1.7), Color(0.86, 0.88, 0.94))
	k.slab(Vector3(-9, -0.02, -6.3), Vector3(9, LOT, Z_BACK), Color(0.34, 0.35, 0.42), {"gloss": 0.4})
	k.slab(Vector3(-9, -0.02, -9), Vector3(9, LOT, -6.3), Color(0.3, 0.31, 0.36))

# --- the viaduct ------------------------------------------------------------------------

static func _viaduct(k: Kit) -> void:
	var brick := {"mat": "brick"}
	for p in PIERS:
		var x0 := maxf(p - PIER_HALF, -9.0)
		var x1 := minf(p + PIER_HALF, 9.0)
		k.slab(Vector3(x0, LOT, Z_BACK), Vector3(x1, DECK_BOT, Z_FRONT), BRICK, brick)
		k.slab(Vector3(x0 - 0.04, SPRING - 0.12, Z_BACK - 0.05), Vector3(x1 + 0.04, SPRING + 0.04, Z_FRONT + 0.05), STONE)
		k.slab(Vector3(x0 - 0.04, LOT, Z_BACK - 0.05), Vector3(x1 + 0.04, LOT + 0.35, Z_FRONT + 0.05), STONE * 0.9)
	for i in 4:
		var bay := _bay(i)
		_spandrel(k, bay, Z_FRONT - 0.45, Z_FRONT)
		_spandrel(k, bay, Z_BACK, Z_BACK + 0.45)
		k.slab(Vector3(bay.x, DECK_BOT - 0.06, Z_BACK + 0.45), Vector3(bay.y, DECK_BOT, Z_FRONT - 0.45), Color(0.4, 0.32, 0.3))
	k.slab(Vector3(-9, DECK_BOT, Z_BACK - 0.1), Vector3(9, DECK_TOP, Z_FRONT + 0.1), CONCRETE, {"gloss": 0.2})
	for z in [[Z_FRONT + 0.1, Z_FRONT + 0.24], [Z_BACK - 0.24, Z_BACK - 0.1]]:
		k.slab(Vector3(-9, DECK_TOP - 0.16, z[0]), Vector3(9, DECK_TOP + 0.02, z[1]), STONE)
	k.slab(Vector3(-9, DECK_TOP, Z_FRONT - 0.12), Vector3(9, DECK_TOP + 0.8, Z_FRONT + 0.08), CONCRETE)
	k.slab(Vector3(-9, DECK_TOP, Z_BACK - 0.08), Vector3(9, DECK_TOP + 0.8, Z_BACK + 0.12), CONCRETE)
	for x in [-6.75, -2.25, 2.25, 6.75]:
		k.box(Vector3(x, DECK_TOP + 0.4, Z_FRONT + 0.09), Vector3(0.04, 0.8, 0.02), CONCRETE * 0.85, {"line": 0.0})
	# ballast, sleepers and rails
	k.slab(Vector3(-9, DECK_TOP, Z_BACK + 0.3), Vector3(9, DECK_TOP + 0.12, Z_FRONT - 0.3), Color(0.33, 0.31, 0.33), {"line": 0.0})
	for tz in TRACKS:
		for i in 30:
			k.box(Vector3(-8.7 + i * 0.6, DECK_TOP + 0.15, tz), Vector3(0.2, 0.06, 1.5), Color(0.4, 0.36, 0.34), {"line": 0.3})
		for side in [-0.53, 0.53]:
			k.rod(Vector3(-9, DECK_TOP + 0.21, tz + side), Vector3(9, DECK_TOP + 0.21, tz + side), 0.035, STEEL, {"gloss": 0.8, "seg": 6, "line": 0.4})
	# overhead line: H-beam poles on the front parapet, arms over both tracks
	for x in [-6.75, -2.25, 2.25, 6.75]:
		var foot := Vector3(x, DECK_TOP, Z_FRONT - 0.05)
		k.box(foot + Vector3(0, 1.8, 0), Vector3(0.16, 3.6, 0.16), Color(0.5, 0.52, 0.58), {"gloss": 0.3})
		k.rod(foot + Vector3(0, 3.35, 0), Vector3(x, DECK_TOP + 3.35, Z_BACK + 0.4), 0.045, Color(0.5, 0.52, 0.58))
		for tz in TRACKS:
			k.rod(Vector3(x, DECK_TOP + 3.35, tz), Vector3(x, DECK_TOP + 3.05, tz), 0.01, INK, {"line": 0.0})
	for tz in TRACKS:
		k.rod(Vector3(-9, DECK_TOP + 3.05, tz), Vector3(9, DECK_TOP + 3.05, tz), 0.012, INK, {"seg": 4, "line": 0.3})
		k.rod(Vector3(-9, DECK_TOP + 3.3, tz), Vector3(9, DECK_TOP + 3.3, tz), 0.012, INK, {"seg": 4, "line": 0.3})

# --- the train ----------------------------------------------------------------------------

static func _train(k: Kit, scene: Node3D) -> void:
	k.material("train", 0, {"clip_x": 9.0})
	var train := Node3D.new()
	train.name = "Train"
	train.position = Vector3(100, 0, TRACKS[1])
	scene.add_child(train)
	scene.set_meta("train", train)
	var o := {"node": train, "mat": "train"}
	var base := DECK_TOP + 0.25
	for c in 3:
		var cx := (c - 1) * 6.2
		k.box(Vector3(cx, base + 1.35, 0), Vector3(6.0, 2.2, 2.4), Color(0.9, 0.88, 0.82), {"node": train, "mat": "train", "gloss": 0.5})
		k.box(Vector3(cx, base + 0.7, 0), Vector3(6.02, 0.18, 2.42), Color(0.15, 0.4, 0.8), o)
		k.box(Vector3(cx, base + 1.7, 0), Vector3(5.6, 0.62, 2.42), Color(1.0, 0.9, 0.7), {"node": train, "mat": "train", "emit": 1.0, "line": 0.0})
		for i in 7:
			k.box(Vector3(cx - 2.7 + i * 0.9, base + 1.7, 0), Vector3(0.08, 0.64, 2.44), Color(0.25, 0.27, 0.32), {"node": train, "mat": "train", "line": 0.0})
		for d in [-1.6, 1.6]:
			k.box(Vector3(cx + d, base + 1.2, 0), Vector3(0.8, 1.8, 2.43), Color(0.8, 0.79, 0.75), {"node": train, "mat": "train", "line": 0.4})
			k.box(Vector3(cx + d, base + 1.7, 0), Vector3(0.6, 0.5, 2.44), Color(1.0, 0.9, 0.7), {"node": train, "mat": "train", "emit": 1.0, "line": 0.0})
		k.box(Vector3(cx, base + 2.5, 0), Vector3(6.0, 0.14, 2.2), Color(0.55, 0.57, 0.62), o)
		for bg in [-2.0, 2.0]:
			k.box(Vector3(cx + bg, base + 0.12, 0), Vector3(1.6, 0.3, 1.8), Color(0.15, 0.15, 0.18), o)
	# pantograph on the middle car, head- and tail-lights
	k.rod(Vector3(-0.4, base + 2.57, 0), Vector3(0.0, base + 2.78, 0), 0.02, INK, o)
	k.rod(Vector3(0.4, base + 2.57, 0), Vector3(0.0, base + 2.78, 0), 0.02, INK, o)
	k.box(Vector3(0, base + 2.79, 0), Vector3(0.1, 0.03, 1.2), INK, o)
	k.box(Vector3(9.31, base + 0.95, 0.7), Vector3(0.03, 0.15, 0.3), Color(1.0, 0.98, 0.9), {"node": train, "mat": "train", "emit": 2.0, "line": 0.0})
	k.box(Vector3(9.31, base + 0.95, -0.7), Vector3(0.03, 0.15, 0.3), Color(1.0, 0.98, 0.9), {"node": train, "mat": "train", "emit": 2.0, "line": 0.0})
	k.box(Vector3(-9.31, base + 0.95, 0.7), Vector3(0.03, 0.12, 0.25), Color(1.0, 0.2, 0.15), {"node": train, "mat": "train", "emit": 1.5, "line": 0.0})

## Moves the train across every 24 s and lets its windows light the street below.
static func animate(scene: Node3D, clock: float) -> void:
	var train: Node3D = scene.get_meta("train")
	var t := fmod(clock + 6.0, 24.0)
	train.position.x = -30.0 + t * 9.0 if t < 7.0 else 100.0
	var glow: OmniLight3D = scene.lights["TrainGlow"]
	glow.position.x = clampf(train.position.x, -8.5, 8.5)
	glow.light_energy = 1.1 * clampf(1.0 - (absf(train.position.x) - 9.0) / 9.0, 0.0, 1.0)

# --- the ramen shop in the second arch -------------------------------------------------------

static func _steamy(glass: MeshInstance3D) -> void:
	var mat: ShaderMaterial = glass.material_override
	mat.set_shader_parameter("tint", Color(1.0, 0.86, 0.66))
	mat.set_shader_parameter("base_alpha", 0.3)
	mat.set_shader_parameter("drop_color", Color(1.0, 0.95, 0.88))

static func _lantern(k: Kit, scene: Node3D, at: Vector3, letter: String, radius: float, mat: String) -> void:
	var lantern := Node3D.new()
	lantern.name = "Lantern"
	lantern.position = at
	lantern.set_meta("amp", 0.05)
	lantern.set_meta("speed", 1.1 + absf(at.x) * 0.05)
	lantern.set_meta("phase", at.x)
	scene.add_child(lantern)
	scene.sway_nodes.append(lantern)
	var o := {"node": lantern}
	k.rod(Vector3.ZERO, Vector3(0, -0.14, 0), 0.008, INK, o)
	k.cyl(Vector3(0, -0.17, 0), radius * 0.72, 0.06, INK, {"node": lantern, "seg": 14})
	k.cyl(Vector3(0, -0.2 - radius * 1.25, 0), radius, radius * 2.5, LANTERN, {"node": lantern, "seg": 16, "mat": mat, "emit": 1.0})
	for f in [0.3, 0.5, 0.7]:
		k.torus(Vector3(0, -0.2 - radius * 2.5 * f, 0), radius + 0.002, 0.006, LANTERN * 0.7, {"node": lantern, "line": 0.0})
	k.cyl(Vector3(0, -0.23 - radius * 2.5, 0), radius * 0.72, 0.06, INK, {"node": lantern, "seg": 14})
	k.text(letter, Vector3(0, -0.2 - radius * 1.25, radius + 0.005), radius * 1.1, INK, {"node": lantern, "jp": true})

static func _ramen(k: Kit, scene: Node3D) -> void:
	var bay := _bay(1)
	var xc := (bay.x + bay.y) * 0.5
	var z := FACADE
	_fan(k, bay, 2.9, z, Color(0.36, 0.24, 0.17))
	# shop front: posts, lattice window, sliding door, small side window
	for x in [bay.x + 0.05, -2.6, -1.3, bay.y - 0.05]:
		k.box(Vector3(x, LOT + 1.4, z + 0.03), Vector3(0.1, 2.8, 0.1), WOOD_DARK)
	k.slab(Vector3(bay.x, 2.25, z - 0.1), Vector3(bay.y, 2.9, z + 0.04), WOOD_DARK)
	k.slab(Vector3(bay.x, LOT, z - 0.1), Vector3(-2.6, 0.8, z), WOOD_DARK)
	for i in 5:
		k.box(Vector3(bay.x + 0.25 + i * 0.3, 0.48, z + 0.01), Vector3(0.05, 0.6, 0.03), WOOD, {"line": 0.4})
	for i in 5:
		k.box(Vector3(bay.x + 0.25 + i * 0.3, 1.52, z + 0.02), Vector3(0.03, 1.44, 0.03), WOOD, {"line": 0.3})
	for y in [1.25, 1.75]:
		k.box(Vector3((bay.x - 2.6) * 0.5, y, z + 0.02), Vector3(1.55, 0.03, 0.03), WOOD, {"line": 0.3})
	_steamy(scene.add_glass(Vector3((bay.x - 2.6) * 0.5, 1.52, z - 0.03), Vector2(1.55, 1.44), Basis.IDENTITY, 0.6))
	k.slab(Vector3(-1.3, LOT, z - 0.1), Vector3(bay.y, 1.15, z), WOOD_DARK)
	k.slab(Vector3(-1.3, 2.0, z - 0.1), Vector3(bay.y, 2.25, z), WOOD_DARK)
	_steamy(scene.add_glass(Vector3((-1.3 + bay.y) * 0.5, 1.58, z - 0.03), Vector2(0.95, 0.85), Basis.IDENTITY, 0.6))
	for x in [-1.05, -0.8, -0.55]:
		k.box(Vector3(x, 1.58, z + 0.02), Vector3(0.025, 0.85, 0.025), WOOD, {"line": 0.3})
	for i in 2:
		var panel := Node3D.new()
		panel.name = "DoorPanel%d" % i
		panel.position = Vector3(-2.27 + i * 0.64, LOT + 1.03, z - 0.04 - i * 0.05)
		panel.set_meta("travel", 0.0 if i == 0 else -0.6)
		scene.add_child(panel)
		scene.door_panels.append(panel)
		var o := {"node": panel, "gloss": 0.2}
		for x in [-0.3, 0.3]:
			k.box(Vector3(x, 0, 0), Vector3(0.05, 2.06, 0.05), WOOD_DARK, o)
		k.box(Vector3(0, 1.0, 0), Vector3(0.65, 0.05, 0.05), WOOD_DARK, o)
		k.box(Vector3(0, -0.72, 0), Vector3(0.58, 0.6, 0.04), WOOD, o)
		k.box(Vector3(0, 0.3, 0.02), Vector3(0.02, 1.35, 0.02), WOOD, {"node": panel, "line": 0.3})
		_steamy(scene.add_glass(Vector3(0, 0.3, 0), Vector2(0.56, 1.35), Basis.IDENTITY, 0.5, false, panel))
	# name board, noren, lanterns, stand sign, chalk menu, an umbrella left by the door
	k.box(Vector3(xc, 2.6, z + 0.08), Vector3(3.7, 0.42, 0.08), Color(0.2, 0.13, 0.09), {"gloss": 0.3})
	k.text("麺屋  ゆきあかり", Vector3(xc, 2.6, z + 0.125), 0.24, Color(1.0, 0.95, 0.85), {"jp": true})
	k.rod(Vector3(-2.65, 2.2, z + 0.12), Vector3(-1.25, 2.2, z + 0.12), 0.02, WOOD_DARK)
	var noren := Node3D.new()
	noren.name = "Noren"
	noren.position = Vector3(-1.95, 2.2, z + 0.12)
	noren.set_meta("amp", 0.03)
	noren.set_meta("speed", 1.6)
	noren.set_meta("phase", 0.4)
	scene.add_child(noren)
	scene.sway_nodes.append(noren)
	for i in 2:
		k.box(Vector3(-0.33 + i * 0.66, -0.32, 0), Vector3(0.63, 0.64, 0.02), INDIGO, {"node": noren, "line": 0.6})
	k.text("らーめん", Vector3(0, -0.3, 0.015), 0.17, Color(0.97, 0.97, 0.95), {"node": noren, "jp": true})
	scene.sign_band_material = k.material("sign_band")
	_lantern(k, scene, Vector3(-2.85, 2.75, 1.3), "麺", 0.17, "sign_band")
	_lantern(k, scene, Vector3(-0.95, 2.75, 1.3), "麺", 0.17, "sign_band")
	scene.pole_sign_material = k.material("pole_sign")
	var a := Vector3(-0.62, LOT, 1.35)
	for c in [Vector2(-0.15, -0.15), Vector2(0.15, -0.15), Vector2(-0.15, 0.15), Vector2(0.15, 0.15)]:
		k.box(a + Vector3(c.x, 0.5, c.y), Vector3(0.04, 1.0, 0.04), WOOD_DARK)
	k.box(a + Vector3(0, 0.62, 0), Vector3(0.28, 0.72, 0.28), Color(1.0, 0.97, 0.9), {"mat": "pole_sign", "emit": 1.0})
	k.box(a + Vector3(0, 1.02, 0), Vector3(0.38, 0.05, 0.38), WOOD_DARK)
	var open_sign := k.text("営\n業\n中", a + Vector3(0, 0.64, 0.145), 0.15, INK, {"jp": true})
	open_sign.line_spacing = -10
	var m := Vector3(-3.55, LOT, 1.3)
	for s in [-1.0, 1.0]:
		k.box(m + Vector3(0, 0.42, s * 0.09), Vector3(0.46, 0.78, 0.03), WOOD, {"rot": Vector3(-s * 12, 0, 0)})
	var face := Basis(Vector3.RIGHT, deg_to_rad(-12))
	k.box(m + Vector3(0, 0.44, 0.11), Vector3(0.39, 0.64, 0.01), Color(0.12, 0.17, 0.15), {"basis": face, "line": 0.0})
	var chalk := k.text("おすすめ\n味噌\n醤油\n塩\n餃子", m + Vector3(0, 0.44, 0.12) + face * Vector3(0, 0, 0.01), 0.06, Color(0.95, 0.95, 0.9), {"jp": true})
	chalk.basis = face
	var umb := Vector3(-1.2, LOT, 1.05)
	k.rod(umb, umb + Vector3(0.05, 0.88, -0.08), 0.008, STEEL)
	k.cyl(umb + Vector3(0.025, 0.48, -0.04), 0.06, 0.6, Color(0.85, 0.92, 0.98), {"basis": Kit.aim(Vector3(-0.05, -0.88, 0.08)), "top": 0.25, "seg": 8, "gloss": 0.8})

## Options for indoor parts: layer 2 plus a warm fill.
static func o(extra := {}) -> Dictionary:
	var opts := {"indoor": true, "lit": 0.32}
	opts.merge(extra, true)
	return opts

static func _ramen_inside(k: Kit, scene: Node3D) -> void:
	var bay := _bay(1)
	var zb := -2.7
	var ceil := 2.9
	var cream := Color(0.95, 0.85, 0.7)
	k.slab(Vector3(bay.x, LOT, zb), Vector3(bay.y, LOT + 0.03, FACADE - 0.1), Color(0.55, 0.4, 0.28), o({"mat": "wood", "line": 0.0, "lit": 0.28, "gloss": 0.25}))
	for x in [bay.x, bay.y]:
		k.slab(Vector3(x - 0.01, LOT, zb), Vector3(x + 0.01, ceil, FACADE - 0.1), cream, o({"line": 0.3}))
	k.slab(Vector3(bay.x, LOT, zb - 0.02), Vector3(bay.y, ceil, zb), cream, o({"line": 0.3}))
	k.slab(Vector3(bay.x, ceil, zb), Vector3(bay.y, ceil + 0.04, FACADE - 0.1), Color(0.6, 0.45, 0.32), o({"line": 0.0}))
	k.slab(Vector3(bay.x, 2.25, FACADE - 0.12), Vector3(bay.y, ceil, FACADE - 0.1), cream, o())
	k.slab(Vector3(bay.x, LOT, FACADE - 0.12), Vector3(-2.6, 0.8, FACADE - 0.1), WOOD, o())
	# counter facing the kitchen, four stools, the bowl someone is halfway through
	var cz := -0.55
	k.slab(Vector3(bay.x + 0.1, LOT, cz - 0.22), Vector3(bay.y - 0.25, 1.0, cz + 0.22), WOOD_DARK, o({"gloss": 0.2}))
	k.slab(Vector3(bay.x + 0.05, 1.0, cz - 0.26), Vector3(bay.y - 0.2, 1.06, cz + 0.28), Color(0.82, 0.66, 0.46), o({"mat": "wood", "gloss": 0.35}))
	k.slab(Vector3(bay.x + 0.1, 1.06, cz - 0.26), Vector3(bay.y - 0.25, 1.2, cz - 0.14), Color(0.74, 0.6, 0.42), o({"mat": "wood"}))
	for x in [-3.7, -2.9, -2.1, -1.3]:
		k.cyl(Vector3(x, LOT + 0.33, 0.05), 0.03, 0.66, Color(0.2, 0.2, 0.24), o({"seg": 8}))
		k.cyl(Vector3(x, LOT + 0.7, 0.05), 0.17, 0.08, Color(0.78, 0.18, 0.14), o({"seg": 14, "gloss": 0.3, "lit": 0.45}))
	var bowl := Vector3(-3.0, 1.06, cz + 0.05)
	k.cyl(bowl + Vector3(0, 0.06, 0), 0.13, 0.12, Color(0.12, 0.08, 0.08), o({"top": 1.35, "seg": 16, "gloss": 0.5}))
	k.cyl(bowl + Vector3(0, 0.115, 0), 0.155, 0.008, Color(0.85, 0.55, 0.25), o({"seg": 16, "line": 0.0, "emit": 0.2}))
	for i in 5:
		k.rod(bowl + Vector3(-0.09 + i * 0.04, 0.12, -0.07), bowl + Vector3(-0.07 + i * 0.04, 0.125, 0.07), 0.006, Color(1.0, 0.88, 0.5), o({"line": 0.0}))
	k.rod(bowl + Vector3(-0.16, 0.14, 0.05), bowl + Vector3(0.16, 0.14, 0.07), 0.006, Color(0.82, 0.66, 0.46), o({"line": 0.3}))
	k.rod(bowl + Vector3(-0.16, 0.14, 0.09), bowl + Vector3(0.16, 0.14, 0.1), 0.006, Color(0.82, 0.66, 0.46), o({"line": 0.3}))
	k.cyl(bowl + Vector3(0.28, 0.06, 0.05), 0.035, 0.12, Color(0.8, 0.9, 0.95), o({"seg": 10, "gloss": 0.9}))
	scene.add_steam(bowl + Vector3(0, 0.12, 0), Vector2(0.3, 0.35), 0.22)
	for x in [-3.6, -2.0]:
		for j in 3:
			k.cyl(Vector3(x + j * 0.08, 1.25, cz - 0.2), 0.025, 0.1, [Color(0.85, 0.15, 0.1), Color(0.15, 0.12, 0.1), Color(0.95, 0.92, 0.85)][j], o({"seg": 8, "line": 0.3}))
	# kitchen along the back: stock pots, noodle boiler, bowls, hood, menu plaques over the counter
	k.slab(Vector3(bay.x + 0.05, LOT, zb), Vector3(bay.y - 0.05, 0.95, zb + 0.55), STEEL, o({"gloss": 0.5}))
	for x in [-3.6, -2.95]:
		k.cyl(Vector3(x, 1.22, zb + 0.28), 0.27, 0.5, STEEL, o({"seg": 16, "gloss": 0.7, "lit": 0.45}))
		k.cyl(Vector3(x, 1.475, zb + 0.28), 0.24, 0.01, Color(0.85, 0.6, 0.3), o({"seg": 16, "line": 0.0, "emit": 0.25}))
		scene.add_steam(Vector3(x, 1.48, zb + 0.28), Vector2(0.6, 0.9), 0.3)
	k.box(Vector3(-1.9, 1.1, zb + 0.28), Vector3(0.8, 0.3, 0.5), STEEL, o({"gloss": 0.6}))
	for i in 4:
		var bsk := Vector3(-2.15 + (i % 2) * 0.5, 1.27, zb + 0.18 + (i / 2) * 0.22)
		k.torus(bsk, 0.07, 0.01, STEEL * 0.8, o({"line": 0.3}))
		k.rod(bsk + Vector3(0, 0, 0.07), bsk + Vector3(0, 0.22, 0.3), 0.01, WOOD, o({"line": 0.3}))
	scene.add_steam(Vector3(-1.9, 1.27, zb + 0.28), Vector2(0.7, 0.7), 0.26)
	k.slab(Vector3(bay.x + 0.05, 2.2, zb), Vector3(-2.4, 2.6, zb + 0.65), STEEL * 0.9, o({"gloss": 0.5}))
	for y in [1.6, 2.0]:
		k.slab(Vector3(-1.4, y, zb), Vector3(bay.y - 0.05, y + 0.03, zb + 0.28), WOOD, o())
		for i in 3:
			for j in 3:
				k.cyl(Vector3(-1.2 + i * 0.32, y + 0.06 + j * 0.05, zb + 0.14), 0.11, 0.05, [Color(0.95, 0.93, 0.88), Color(0.75, 0.15, 0.12)][i % 2], o({"top": 1.3, "seg": 12, "line": 0.3, "lit": 0.45}))
	k.slab(Vector3(bay.x, 2.45, cz - 0.38), Vector3(bay.y, ceil, cz - 0.24), WOOD_DARK, o())
	var plaques := [["醤\n油", "800"], ["味\n噌", "850"], ["塩", "800"], ["餃\n子", "350"], ["ビ\nー\nル", "500"]]
	for i in plaques.size():
		var p := Vector3(-3.85 + i * 0.72, 2.66, cz - 0.23)
		k.box(p, Vector3(0.2, 0.42, 0.015), Color(0.93, 0.85, 0.66), o({"line": 0.4, "lit": 0.5}))
		var t := k.text(plaques[i][0], p + Vector3(0, 0.04, 0.01), 0.08, INK, {"indoor": true, "jp": true})
		t.line_spacing = -8
		k.text(plaques[i][1], p + Vector3(0, -0.16, 0.01), 0.045, Color(0.7, 0.1, 0.1), {"indoor": true, "jp": true})
	for x in [-3.3, -2.25, -1.2]:
		k.rod(Vector3(x, ceil, -0.1), Vector3(x, 2.45, -0.1), 0.006, INK, o({"line": 0.0}))
		k.cyl(Vector3(x, 2.4, -0.1), 0.14, 0.12, Color(0.2, 0.16, 0.12), o({"top": 0.35, "seg": 12}))
		k.ball(Vector3(x, 2.31, -0.1), Vector3.ONE * 0.07, Color(1.0, 0.85, 0.55), o({"emit": 1.6, "seg": 8, "line": 0.0}))
	# ticket machine by the door, a beckoning cat on a high shelf
	var tm := Vector3(bay.y - 0.22, LOT, 0.35)
	k.box(tm + Vector3(0, 0.75, 0), Vector3(0.38, 1.5, 0.6), Color(0.85, 0.86, 0.9), o({"gloss": 0.4}))
	for r in 3:
		for c in 3:
			k.box(tm + Vector3(-0.195, 1.1 + r * 0.08, -0.15 + c * 0.15), Vector3(0.01, 0.06, 0.12), [Color(1.0, 0.85, 0.3), Color(1.0, 0.55, 0.3), Color(0.5, 0.85, 1.0)][(r + c) % 3], o({"emit": 0.8, "line": 0.0}))
	k.text("食券", tm + Vector3(-0.196, 1.42, 0), 0.07, Color(0.75, 0.1, 0.1), {"indoor": true, "jp": true, "rot": Vector3(0, -90, 0)})
	var cat := Vector3(bay.x + 0.15, 2.28, -0.1)
	k.box(cat + Vector3(0, -0.02, 0), Vector3(0.26, 0.03, 0.4), WOOD, o())
	k.ball(cat + Vector3(0, 0.09, 0), Vector3(0.09, 0.1, 0.08), Color(0.98, 0.97, 0.94), o({"seg": 10, "lit": 0.5}))
	k.ball(cat + Vector3(0, 0.24, 0), Vector3(0.085, 0.075, 0.075), Color(0.98, 0.97, 0.94), o({"seg": 10, "lit": 0.5}))
	k.ball(cat + Vector3(0.03, 0.29, -0.08), Vector3(0.03, 0.04, 0.03), Color(0.98, 0.97, 0.94), o({"seg": 8, "lit": 0.5}))
	k.torus(cat + Vector3(0, 0.17, 0), 0.07, 0.012, Color(0.85, 0.15, 0.15), o({"line": 0.0}))
	# the back room behind a small noren
	k.slab(Vector3(-1.0, LOT, zb + 0.56), Vector3(-0.4, 2.0, zb + 0.57), Color(0.25, 0.2, 0.16), o({"line": 0.0, "lit": 0.1}))

# --- the neighbours under the arches -------------------------------------------------------

static func _izakaya(k: Kit, scene: Node3D) -> void:
	var bay := _bay(0)
	var xc := (bay.x + bay.y) * 0.5
	var z := FACADE
	_infill(k, bay, 2.5, z - 0.1, z, Color(0.36, 0.26, 0.2))
	k.slab(Vector3(bay.x, 2.3, z - 0.1), Vector3(bay.y, 2.5, z + 0.04), WOOD_DARK)
	for i in 5:
		var x := bay.x + 0.1 + i * (bay.y - bay.x - 0.2) / 4.0
		k.box(Vector3(x, LOT + 1.1, z + 0.02), Vector3(0.06, 2.2, 0.06), WOOD_DARK)
	k.slab(Vector3(bay.x, LOT, z - 0.08), Vector3(bay.y, 0.95, z - 0.04), Color(0.82, 0.8, 0.74), {"emit": 0.15})
	var glass: MeshInstance3D = scene.add_glass(Vector3(xc, 1.62, z - 0.05), Vector2(bay.y - bay.x - 0.1, 1.3), Basis.IDENTITY, 0.4)
	_steamy(glass)
	(glass.material_override as ShaderMaterial).set_shader_parameter("base_alpha", 0.45)
	# warm room behind the glass: a counter, bottles on a shelf
	k.slab(Vector3(bay.x, LOT, -2.4), Vector3(bay.y, 2.4, -2.38), Color(1.0, 0.72, 0.42), o({"emit": 0.7, "line": 0.0}))
	k.slab(Vector3(bay.x + 0.2, LOT, -1.2), Vector3(bay.y - 0.2, 1.0, -0.8), WOOD_DARK, o())
	for i in 10:
		k.cyl(Vector3(bay.x + 0.4 + i * 0.32, 1.75, -2.3), 0.05, 0.3, [Color(0.2, 0.5, 0.3), Color(0.6, 0.35, 0.15), Color(0.85, 0.85, 0.8)][i % 3], o({"seg": 8, "line": 0.3, "lit": 0.5}))
	k.slab(Vector3(bay.x, 1.58, -2.38), Vector3(bay.y, 1.61, -2.15), WOOD, o())
	# red noren, the big red lantern, beer crates as tables outside
	for i in 3:
		k.box(Vector3(xc - 0.6 + i * 0.6, 2.05, z + 0.1), Vector3(0.57, 0.45, 0.02), Color(0.7, 0.15, 0.12), {"line": 0.5})
	k.text("居酒屋", Vector3(xc, 2.05, z + 0.115), 0.2, Color(1, 1, 1), {"jp": true})
	k.material("izakaya_lantern")
	_lantern(k, scene, Vector3(bay.x + 0.7, 2.85, 1.3), "酒", 0.26, "izakaya_lantern")
	for i in 2:
		var c := Vector3(bay.y - 0.6, LOT + 0.16 + i * 0.32, 1.25)
		k.box(c, Vector3(0.45, 0.3, 0.35), Color(0.95, 0.75, 0.2), {"gloss": 0.5})
	k.box(Vector3(bay.y - 1.2, LOT + 0.16, 1.25), Vector3(0.45, 0.3, 0.35), Color(0.85, 0.25, 0.25), {"gloss": 0.5})
	k.box(Vector3(xc - 0.4, LOT + 0.55, 1.2), Vector3(0.4, 0.6, 0.03), Color(0.12, 0.17, 0.15))
	k.text("とりあえず\n生", Vector3(xc - 0.4, LOT + 0.58, 1.22), 0.06, Color(0.95, 0.95, 0.9), {"jp": true})

static func _yakitori(k: Kit, scene: Node3D) -> void:
	var bay := _bay(2)
	var z := FACADE
	_fan(k, bay, 2.5, z, Color(0.42, 0.3, 0.21))
	k.slab(Vector3(bay.x, 2.3, z - 0.1), Vector3(bay.y, 2.5, z + 0.04), WOOD_DARK)
	# lower wall and an open serving window with a ledge and stools outside
	k.slab(Vector3(bay.x, LOT, z - 0.1), Vector3(3.1, 1.0, z), WOOD)
	k.slab(Vector3(bay.x, 2.0, z - 0.1), Vector3(3.1, 2.3, z), WOOD)
	k.slab(Vector3(bay.x, 0.98, z), Vector3(3.1, 1.04, z + 0.32), WOOD_DARK)
	for x in [1.0, 1.8, 2.6]:
		k.cyl(Vector3(x, LOT + 0.3, z + 0.65), 0.15, 0.06, Color(0.85, 0.2, 0.18), {"seg": 12})
		k.cyl(Vector3(x, LOT + 0.15, z + 0.65), 0.025, 0.3, Color(0.2, 0.2, 0.24), {"seg": 8})
	var grill := Vector3(1.85, 0.95, z - 0.5)
	k.box(grill, Vector3(1.4, 0.2, 0.4), Color(0.2, 0.2, 0.22), o({"gloss": 0.4}))
	k.box(grill + Vector3(0, 0.11, 0), Vector3(1.3, 0.02, 0.32), Color(1.0, 0.4, 0.1), o({"emit": 1.6, "line": 0.0}))
	for i in 9:
		var s := grill + Vector3(-0.55 + i * 0.14, 0.15, 0)
		k.rod(s + Vector3(0, 0, -0.18), s + Vector3(0, 0, 0.2), 0.004, WOOD, o({"line": 0.0}))
		k.box(s, Vector3(0.05, 0.04, 0.18), Color(0.7, 0.4, 0.2), o({"line": 0.3, "lit": 0.5}))
	k.slab(Vector3(bay.x, LOT, -2.4), Vector3(bay.y, 2.4, -2.38), Color(1.0, 0.68, 0.38), o({"emit": 0.6, "line": 0.0}))
	scene.add_steam(Vector3(1.85, 1.15, z - 0.4), Vector2(1.2, 1.6), 0.32)
	# door with a short red noren, lantern
	k.slab(Vector3(3.15, LOT, z - 0.08), Vector3(bay.y - 0.05, 2.2, z - 0.04), Color(0.4, 0.3, 0.22), {"gloss": 0.2})
	for i in 2:
		k.box(Vector3(3.37 + i * 0.4, 1.95, z + 0.1), Vector3(0.38, 0.4, 0.02), Color(0.75, 0.15, 0.12), {"line": 0.5})
	k.text("やきとり", Vector3(3.57, 1.95, z + 0.115), 0.11, Color(1, 1, 1), {"jp": true})
	k.material("yakitori_lantern")
	_lantern(k, scene, Vector3(bay.x + 0.35, 2.85, 1.3), "焼鳥", 0.17, "yakitori_lantern")

static func _bike_park(k: Kit, b: RefCounted) -> void:
	var bay := _bay(3)
	k.box(Vector3((bay.x + bay.y) * 0.5, DECK_BOT - 0.12, -1.5), Vector3(1.6, 0.05, 0.14), Color(0.85, 1.0, 0.92), {"emit": 1.8, "line": 0.3})
	k.box(Vector3((bay.x + bay.y) * 0.5, 3.15, 1.3), Vector3(1.3, 0.38, 0.05), Color(0.2, 0.4, 0.75), {"emit": 0.3})
	k.text("駐輪場", Vector3((bay.x + bay.y) * 0.5, 3.15, 1.33), 0.22, Color(1, 1, 1), {"jp": true})
	for z in [-1.0, -2.9]:
		k.rod(Vector3(bay.x + 0.3, LOT + 0.45, z), Vector3(bay.y - 0.3, LOT + 0.45, z), 0.025, STEEL)
	var colors := [Color(0.55, 0.82, 0.76), Color(0.94, 0.88, 0.74), Color(0.85, 0.35, 0.35), Color(0.4, 0.5, 0.8)]
	for i in 4:
		b._bicycle(Vector3(bay.x + 0.6 + i * 0.85, LOT, -1.6), 90.0 + (i % 2) * 6.0, colors[i])
	# two vending machines at the front of the bay
	for m in 2:
		var x := bay.x + 0.5 + m * 0.9
		var body: Color = [Color(0.86, 0.2, 0.26), Color(0.9, 0.92, 0.96)][m]
		k.box(Vector3(x, LOT + 0.92, 1.0), Vector3(0.84, 1.84, 0.7), body, {"gloss": 0.6})
		k.box(Vector3(x, LOT + 1.33, 1.36), Vector3(0.7, 0.8, 0.02), Color(0.95, 0.97, 1.0), {"emit": 1.2, "line": 0.3})
		for row in 3:
			for col in 6:
				k.cyl(Vector3(x - 0.27 + col * 0.108, LOT + 1.06 + row * 0.25, 1.37), 0.035, 0.15, [Color(0.95, 0.3, 0.3), Color(0.2, 0.55, 0.95), Color(0.98, 0.8, 0.2), Color(0.55, 0.35, 0.2)][(row + col + m) % 4], {"seg": 8, "line": 0.25, "emit": 0.25})
		k.box(Vector3(x, LOT + 0.3, 1.36), Vector3(0.6, 0.2, 0.04), Color(0.06, 0.06, 0.09), {"line": 0.4})
	k.text("あったか〜い", Vector3(bay.x + 0.5, LOT + 0.82, 1.37), 0.05, Color(0.9, 0.2, 0.15), {"jp": true})

# --- behind the viaduct --------------------------------------------------------------------

static func _back(k: Kit, b: RefCounted, scene: Node3D) -> void:
	# the arches' back walls, with kitchen windows, doors, exhaust, outdoor units
	for i in 3:
		var bay := _bay(i)
		_infill(k, bay, LOT, Z_BACK + 0.45, Z_BACK + 0.55, Color(0.62, 0.6, 0.6))
		var xc := (bay.x + bay.y) * 0.5
		k.slab(Vector3(xc + 0.6, LOT, Z_BACK + 0.4), Vector3(xc + 1.4, 2.0, Z_BACK + 0.45), Color(0.45, 0.4, 0.36), {"gloss": 0.3})
		k.slab(Vector3(xc - 1.2, 1.4, Z_BACK + 0.42), Vector3(xc - 0.3, 2.0, Z_BACK + 0.45), Color(1.0, 0.78, 0.48), {"emit": 0.9})
		b._ac_unit(Vector3(xc - 0.6, LOT + 0.33, Z_BACK - 0.4))
	var duct := Vector3(-2.25, 2.4, Z_BACK + 0.3)
	k.box(duct, Vector3(0.4, 0.4, 0.6), STEEL, {"gloss": 0.6})
	scene.add_steam(duct + Vector3(0, 0.15, -0.4), Vector2(0.9, 1.4), 0.35)
	for i in 3:
		k.box(Vector3(5.6 + i * 0.8, LOT + 0.45, -5.5), Vector3(0.7, 0.9, 0.6), Color(0.25, 0.48, 0.38), {"gloss": 0.5})
	# buildings at the back of the base, windows lit here and there
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var blocks := [[-9.0, -3.6, 7.6, Color(0.72, 0.66, 0.6)], [-3.4, 2.8, 5.4, Color(0.62, 0.66, 0.7)], [3.0, 9.0, 7.0, Color(0.78, 0.7, 0.58)]]
	for blk in blocks:
		var x0: float = blk[0]
		var x1: float = blk[1]
		var h: float = blk[2]
		k.slab(Vector3(x0, LOT, -9.0), Vector3(x1, h, -6.3), blk[3], {"mat": "siding"})
		k.slab(Vector3(x0 - 0.05, h, -9.05), Vector3(x1 + 0.05, h + 0.15, -6.25), Color(0.3, 0.3, 0.38))
		var floors := int((h - 0.5) / 2.5)
		for f in floors:
			var n := int((x1 - x0) / 1.7)
			for w in n:
				var wx := x0 + (w + 0.5) * (x1 - x0) / n
				var wy := 1.4 + f * 2.5
				var lit := rng.randf() < 0.4
				k.slab(Vector3(wx - 0.45, wy - 0.45, -6.32), Vector3(wx + 0.45, wy + 0.45, -6.29), Color(1.0, 0.78, 0.48) if lit else Color(0.14, 0.17, 0.3), {"emit": 1.0 if lit else 0.0, "gloss": 0.0 if lit else 0.9, "line": 0.3})
				if f > 0 and w % 2 == 0:
					k.slab(Vector3(wx - 0.6, wy - 0.95, -6.3), Vector3(wx + 0.6, wy - 0.9, -5.85), Color(0.6, 0.6, 0.66))
					k.rod(Vector3(wx - 0.6, wy - 0.4, -5.87), Vector3(wx + 0.6, wy - 0.4, -5.87), 0.015, Color(0.8, 0.82, 0.86))
	k.slab(Vector3(-3.3, LOT, -6.34), Vector3(2.7, 2.5, -6.29), Color(0.6, 0.62, 0.68), {"mat": "siding", "gloss": 0.4})
	var pole: Array = b._utility_pole(Vector3(-0.5, LOT, -5.0), 0.0, false)
	for i in pole.size():
		var p: Vector3 = pole[i]
		b._wire(p, Vector3(-9.0, p.y - 0.1, p.z), 0.3, 0.012 if i < 4 else 0.02)
		b._wire(p, Vector3(9.0, p.y - 0.1, p.z), 0.3, 0.012 if i < 4 else 0.02)

# --- the street in front ---------------------------------------------------------------------

static func _street(k: Kit, b: RefCounted) -> void:
	var poles := [b._utility_pole(Vector3(-6.0, LOT, 6.6), 0.0, true), b._utility_pole(Vector3(4.5, LOT, 6.6), 0.0, false)]
	for i in poles[0].size():
		var a: Vector3 = poles[0][i]
		var c: Vector3 = poles[1][i]
		b._wire(a, c, 0.4 + i * 0.05)
		b._wire(a, Vector3(-9.0, a.y - 0.05, a.z), 0.04)
		b._wire(c, Vector3(9.0, c.y - 0.05, c.z), 0.08)
	for pole in [Vector3(-6.0, LOT, 6.6), Vector3(4.5, LOT, 6.6)]:
		var arm: Vector3 = pole + Vector3(0, 4.7, 0)
		k.rod(arm, arm + Vector3(0, 0.2, -1.2), 0.03, Color(0.5, 0.53, 0.6))
		k.box(arm + Vector3(0, 0.16, -1.35), Vector3(0.14, 0.08, 0.5), Color(0.86, 0.88, 0.92), {"gloss": 0.4})
		k.box(arm + Vector3(0, 0.11, -1.35), Vector3(0.1, 0.02, 0.44), Color(0.9, 0.97, 1.0), {"emit": 1.8, "line": 0.3})
	b._rail_run(Vector3(-8.8, LOT, 6.2), Vector3(-1.6, LOT, 6.2))
	b._rail_run(Vector3(1.6, LOT, 6.2), Vector3(8.8, LOT, 6.2))
	b._round_sign(Vector3(-6.0, 2.7, 6.78), Color(0.97, 0.97, 1.0), Color(0.85, 0.12, 0.16), "30", Basis.IDENTITY)
	for i in 6:
		b._grate(Vector3(-7.5 + i * 3.0, 0.008, 2.75), false)
	# coin parking: chain fence, a kei car, the sign and pay machine
	for i in 7:
		var x := -8.6 + i * 2.85
		k.cyl(Vector3(x, LOT + 0.3, 7.05), 0.03, 0.6, Color(0.95, 0.8, 0.2), {"seg": 8})
		if i < 6 and i != 3:
			b._wire(Vector3(x, LOT + 0.5, 7.05), Vector3(x + 2.85, LOT + 0.5, 7.05), 0.12, 0.012)
	_kei_car(k, Vector3(-3.6, 0.06, 8.05), Color(0.62, 0.84, 0.8))
	var sign := Vector3(7.4, 0.06, 7.4)
	k.rod(sign, sign + Vector3(0, 2.2, 0), 0.04, Color(0.5, 0.52, 0.58))
	k.box(sign + Vector3(0, 2.3, 0), Vector3(0.7, 0.7, 0.12), Color(0.98, 0.82, 0.15), {"emit": 0.5})
	k.text("P", sign + Vector3(0, 2.38, 0.065), 0.4, Color(0.15, 0.3, 0.75), {"jp": true})
	k.box(sign + Vector3(0, 1.8, 0), Vector3(0.5, 0.26, 0.1), Color(0.12, 0.12, 0.15))
	k.text("空", sign + Vector3(0, 1.8, 0.055), 0.18, Color(0.3, 1.0, 0.5) * 1.5, {"jp": true})
	k.box(Vector3(5.8, 0.06 + 0.6, 7.3), Vector3(0.4, 1.2, 0.3), Color(0.85, 0.86, 0.9), {"gloss": 0.4})
	k.box(Vector3(5.8, 0.06 + 0.95, 7.46), Vector3(0.26, 0.18, 0.01), Color(0.4, 0.75, 1.0), {"emit": 0.8, "line": 0.0})
	k.text("時間 300円", Vector3(5.8, 0.06 + 0.7, 7.46), 0.05, INK, {"jp": true})

## A boxy little kei car, nose toward +X.
static func _kei_car(k: Kit, at: Vector3, paint: Color) -> void:
	var glass := Color(0.12, 0.16, 0.28)
	k.box(at + Vector3(0, 0.5, 0), Vector3(3.3, 0.62, 1.45), paint, {"gloss": 0.7})
	k.box(at + Vector3(-0.35, 1.15, 0), Vector3(2.3, 0.7, 1.38), paint, {"gloss": 0.7})
	k.box(at + Vector3(-0.35, 1.17, 0), Vector3(2.12, 0.52, 1.4), glass, {"gloss": 0.9, "line": 0.0})
	k.box(at + Vector3(0.82, 1.08, 0), Vector3(0.06, 0.5, 1.3), glass, {"rot": Vector3(0, 0, -28), "gloss": 0.9})
	for x in [-0.9, 0.2]:
		k.box(at + Vector3(x, 1.17, 0), Vector3(0.08, 0.54, 1.41), paint, {"line": 0.0})
	k.box(at + Vector3(0, 0.2, 0), Vector3(3.36, 0.14, 1.48), Color(0.25, 0.25, 0.3))
	for x in [-1.05, 1.05]:
		for z in [-0.68, 0.68]:
			k.cyl(at + Vector3(x, 0.27, z), 0.26, 0.18, Color(0.08, 0.08, 0.1), {"rot": Vector3(90, 0, 0), "seg": 14})
			k.cyl(at + Vector3(x, 0.27, z * 1.02), 0.13, 0.19, Color(0.75, 0.77, 0.82), {"rot": Vector3(90, 0, 0), "seg": 10, "line": 0.0})
	for z in [-0.5, 0.5]:
		k.box(at + Vector3(1.66, 0.6, z), Vector3(0.03, 0.14, 0.3), Color(0.95, 0.95, 0.85), {"line": 0.0})
		k.box(at + Vector3(-1.66, 0.6, z), Vector3(0.03, 0.12, 0.22), Color(0.85, 0.2, 0.2), {"line": 0.0})
	for z in [-0.75, 0.75]:
		k.box(at + Vector3(0.75, 1.0, z), Vector3(0.12, 0.08, 0.06), paint, {})

# --- snow ----------------------------------------------------------------------------------------

static func _snow(k: Kit) -> void:
	var snow := {"gloss": 0.1, "line": 0.3}
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	# out in the open only: the porch under the arches stays dry
	for area in [[-9.0, Z_FRONT + 0.05, 9.0, 2.45], [-9.0, 6.15, 9.0, 7.0], [-9.0, -6.3, 9.0, Z_BACK - 0.05]]:
		k.slab(Vector3(area[0], LOT, area[1]), Vector3(area[2], LOT + 0.045, area[3]), SNOW, snow)
	k.slab(Vector3(-9.0, 0.06, 7.0), Vector3(9.0, 0.1, 9.0), SNOW, snow)
	for x in [-3.6]:
		k.slab(Vector3(x - 1.75, 0.06, 7.25), Vector3(x + 1.75, 0.11, 8.85), SNOW * 0.92, {"line": 0.0})
	# footprints from the street into the ramen shop and along the sidewalk
	var step := Vector3(-1.95, LOT + 0.048, 2.35)
	while step.z > Z_FRONT + 0.1:
		k.quad(step + Vector3(0.08 if int(step.z * 4.0) % 2 == 0 else -0.08, 0, 0), Vector2(0.1, 0.22), Color(0.6, 0.65, 0.8), {"rot": Vector3(0, rng.randf_range(-10, 10), 0)})
		step.z -= 0.32
	for i in 26:
		k.quad(Vector3(-8.6 + i * 0.68, LOT + 0.048, 2.05 + (0.07 if i % 2 == 0 else -0.07)), Vector2(0.22, 0.1), Color(0.6, 0.65, 0.8), {"rot": Vector3(0, rng.randf_range(-8, 8), 0)})
	# slush lumps along the kerbs and between the tyre tracks
	var road := {"gloss": 0.35, "line": 0.0}
	for edge in [2.8, 5.8, 4.3]:
		var x := -9.0
		while x < 9.0:
			var length := rng.randf_range(0.4, 1.4)
			k.box(Vector3(x + length * 0.5, 0.016, edge + rng.randf_range(-0.08, 0.08)), Vector3(length, 0.032, rng.randf_range(0.15, 0.32) if edge != 4.3 else rng.randf_range(0.08, 0.18)), SLUSH, road)
			x += length + rng.randf_range(0.1, 0.8 if edge != 4.3 else 1.6)
	# caps on what faces the sky
	k.slab(Vector3(-9.0, DECK_TOP + 0.12, Z_BACK + 0.3), Vector3(9.0, DECK_TOP + 0.17, Z_FRONT - 0.3), SNOW, {"gloss": 0.1, "line": 0.0})
	for z in [[Z_FRONT - 0.12, Z_FRONT + 0.08], [Z_BACK - 0.08, Z_BACK + 0.12]]:
		k.slab(Vector3(-9.0, DECK_TOP + 0.8, z[0]), Vector3(9.0, DECK_TOP + 0.86, z[1]), SNOW, snow)
	for blk in [[-9.0, -3.6, 7.75], [-3.4, 2.8, 5.55], [3.0, 9.0, 7.15]]:
		k.slab(Vector3(blk[0], blk[2], -9.0), Vector3(blk[1], blk[2] + 0.08, -6.3), SNOW, snow)
	k.box(Vector3(-3.95, 1.56, 8.05), Vector3(2.2, 0.08, 1.32), SNOW, snow)
	k.box(Vector3(-2.35, 0.86, 8.05), Vector3(0.9, 0.06, 1.38), SNOW, snow)
	for run in [[-8.8, -1.6], [1.6, 8.8]]:
		k.rod(Vector3(run[0], 0.97 + LOT, 6.2), Vector3(run[1], 0.97 + LOT, 6.2), 0.03, SNOW, {"seg": 6, "line": 0.3})
	k.box(Vector3(7.4, 2.7, 7.4), Vector3(0.7, 0.06, 0.12), SNOW, snow)

# --- light ----------------------------------------------------------------------------------------

static func lights(scene: Node3D) -> void:
	var inside := Color(1.0, 0.72, 0.42)
	scene._omni("Shop", Vector3(-2.25, 2.5, -0.2), inside, 0.9, 3.8, Kit.LAYER_IN, true)
	scene._omni("Shop", Vector3(-2.25, 2.4, -2.0), inside, 0.7, 3.4, Kit.LAYER_IN, true)
	scene._omni("Izakaya", Vector3(-6.75, 2.0, -1.2), inside, 0.8, 3.6, Kit.LAYER_IN, true)
	scene._omni("YakitoriIn", Vector3(2.25, 2.0, -1.2), inside, 0.8, 3.6, Kit.LAYER_IN, true)
	scene._omni("WindowLeft", Vector3(-2.6, 1.3, 2.3), Color(1.0, 0.62, 0.3), 0.9, 3.8, Kit.LAYER_OUT, true)
	scene._omni("SignBand", Vector3(-1.9, 2.3, 1.6), Color(1.0, 0.42, 0.28), 1.0, 3.6)
	scene._omni("PoleSign", Vector3(-0.62, 1.0, 1.7), Color(1.0, 0.88, 0.65), 0.6, 2.2, Kit.LAYER_OUT, true)
	scene._omni("IzakayaLantern", Vector3(-8.05, 2.3, 1.6), Color(1.0, 0.38, 0.25), 1.2, 4.0)
	scene._omni("Yakitori", Vector3(1.9, 1.5, 1.8), Color(1.0, 0.6, 0.3), 1.1, 3.8, Kit.LAYER_OUT, true)
	scene._omni("BikePark", Vector3(6.75, 3.6, -1.2), Color(0.82, 1.0, 0.9), 0.9, 5.0, Kit.LAYER_OUT, true)
	scene._omni("Vending", Vector3(5.75, 1.2, 1.9), Color(0.8, 0.92, 1.0), 1.0, 3.0, Kit.LAYER_OUT, true)
	# the strips in reflections() already show these lamps on the wet road
	scene._omni("StreetLampA", Vector3(-6.0, 4.6, 5.3), Color(0.75, 0.88, 1.0), 1.8, 7.0, Kit.LAYER_OUT, true)
	scene._omni("StreetLampB", Vector3(4.5, 4.6, 5.3), Color(0.75, 0.88, 1.0), 1.8, 7.0, Kit.LAYER_OUT, true)
	scene._omni("BackWindows", Vector3(0.0, 4.0, -5.6), Color(1.0, 0.75, 0.45), 0.6, 6.0, Kit.LAYER_OUT, true)
	scene._omni("Parking", Vector3(7.4, 2.4, 7.6), Color(1.0, 0.9, 0.5), 0.5, 2.5, Kit.LAYER_OUT, true)
	scene._omni("TrainGlow", Vector3(0.0, DECK_TOP + 1.6, 1.8), Color(1.0, 0.9, 0.7), 0.0, 7.0, Kit.LAYER_OUT, true)

static func reflections(scene: Node3D) -> void:
	for x in [-6.0, 4.5]:
		scene.weather.add_reflection(Vector3(x, 0.0, 5.3), Color(0.75, 0.88, 1.0), 0.5, 4.7, 0.25, 2.0)
	scene.weather.add_reflection(Vector3(-2.0, 0.0, 2.75), Color(1.0, 0.5, 0.3), 0.8, 2.4, 0.2, 1.5)
