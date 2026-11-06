extends RefCounted
## The ramen shop that stands in the middle of the base when the diorama's shop is
## "ramen": a one-storey wooden shop with a tiled gable roof, a steamy lattice window,
## an indigo noren over the sliding door, two red lanterns, a lit standing sign and a
## chalk menu outside; inside a long counter with stools, stock pots and the noodle
## boiler, wooden menu plaques, a ticket machine and a half-finished bowl.
## Same footprint as the konbini (X -5.0..2.4, Z -5.2..0.0) so the street around it is shared.

const Kit := preload("res://scripts/konbini_kit.gd")

const LOT := 0.12
const FLOOR := 0.2
const WALL_H := 3.4
const X0 := -5.0
const X1 := 2.4
const Z0 := -5.2

const WOOD_DARK := Color(0.3, 0.19, 0.13)
const WOOD := Color(0.55, 0.36, 0.22)
const WOOD_LIGHT := Color(0.82, 0.66, 0.46)
const PLASTER := Color(0.9, 0.86, 0.78)
const TILE := Color(0.24, 0.27, 0.37)
const INDIGO := Color(0.13, 0.18, 0.4)
const LANTERN := Color(0.95, 0.22, 0.14)
const STEEL := Color(0.78, 0.8, 0.85)
const SNOW := Color(0.9, 0.93, 1.0)
const INK := Color(0.08, 0.06, 0.06)

# --- outside ------------------------------------------------------------------------

static func exterior(b: RefCounted) -> void:
	var k: Kit = b.k
	var scene: Node3D = b.scene
	_shell(k, scene)
	_front(k, scene)
	_roof(k, scene.weather_kind == "snow")
	_door(k, scene)
	_street_things(k, scene)

static func _shell(k: Kit, scene: Node3D) -> void:
	var wall := {"gloss": 0.1}
	k.slab(Vector3(X0, FLOOR - 0.01, Z0), Vector3(X0 + 0.15, WALL_H, -0.15), PLASTER, wall)
	k.slab(Vector3(X0 + 0.15, FLOOR - 0.01, Z0), Vector3(X1, WALL_H, Z0 + 0.15), PLASTER, wall)
	k.slab(Vector3(X1 - 0.15, FLOOR - 0.01, Z0 + 0.15), Vector3(X1, WALL_H, -0.15), PLASTER, wall)
	# dark timber skirting and corner posts, a beam under the eaves
	for side in [[X0 - 0.02, X0 + 0.02], [X1 - 0.02, X1 + 0.02]]:
		k.slab(Vector3(side[0], FLOOR - 0.01, Z0 - 0.02), Vector3(side[1], 0.75, 0.02), WOOD_DARK)
	k.slab(Vector3(X0 + 0.02, FLOOR - 0.01, Z0 - 0.02), Vector3(X1 - 0.02, 0.75, Z0 + 0.02), WOOD_DARK)
	for x in [X0, X1 - 0.18]:
		k.slab(Vector3(x, FLOOR - 0.01, -0.2), Vector3(x + 0.18, WALL_H, 0.02), WOOD_DARK)
		k.slab(Vector3(x, FLOOR - 0.01, Z0 - 0.02), Vector3(x + 0.18, WALL_H, Z0 + 0.16), WOOD_DARK)
	k.slab(Vector3(X0, WALL_H - 0.12, Z0 - 0.03), Vector3(X1, WALL_H, Z0 + 0.03), WOOD_DARK)
	# lit kitchen window on the side, back door with its lamp, exhaust duct breathing steam
	k.slab(Vector3(X1 - 0.01, 1.4, -3.6), Vector3(X1 + 0.02, 2.1, -2.8), Color(1.0, 0.76, 0.45), {"emit": 1.0, "line": 0.3})
	for z in [-3.4, -3.2, -3.0]:
		k.box(Vector3(X1 + 0.04, 1.75, z), Vector3(0.03, 0.72, 0.03), WOOD_DARK)
	k.slab(Vector3(X1, 1.36, -3.64), Vector3(X1 + 0.05, 1.4, -2.76), WOOD_DARK)
	k.slab(Vector3(-2.1, FLOOR - 0.01, Z0 - 0.05), Vector3(-1.2, 2.2, Z0), Color(0.42, 0.33, 0.26), {"gloss": 0.3})
	k.box(Vector3(-1.65, 2.5, Z0 - 0.08), Vector3(0.2, 0.12, 0.12), Color(1.0, 0.85, 0.6), {"emit": 1.3})
	k.slab(Vector3(-2.3, LOT, Z0 - 0.7), Vector3(-1.0, FLOOR - 0.01, Z0), Color(0.5, 0.5, 0.56))
	k.slab(Vector3(X0 - 0.28, 1.5, -3.45), Vector3(X0, 3.95, -2.95), STEEL, {"gloss": 0.6})
	k.slab(Vector3(X0 - 0.36, 3.95, -3.55), Vector3(X0 + 0.08, 4.05, -2.85), STEEL * 0.85, {"gloss": 0.6})
	scene.add_steam(Vector3(X0 - 0.14, 4.0, -3.2), Vector2(0.9, 1.6), 0.38)

static func _front(k: Kit, scene: Node3D) -> void:
	var z := -0.15
	# lower slatted panel under the big window, posts either side of the door
	k.slab(Vector3(-4.82, FLOOR - 0.01, z), Vector3(-1.0, 0.8, 0.0), WOOD_DARK, {"gloss": 0.2})
	for i in 13:
		k.box(Vector3(-4.7 + i * 0.3, 0.5, 0.01), Vector3(0.05, 0.56, 0.03), WOOD, {"line": 0.4})
	k.slab(Vector3(-1.0, FLOOR - 0.01, z), Vector3(-0.45, 2.3, 0.02), WOOD_DARK)
	k.slab(Vector3(1.2, FLOOR - 0.01, z), Vector3(2.22, 1.2, 0.0), WOOD_DARK, {"gloss": 0.2})
	k.slab(Vector3(1.2, 1.2, z), Vector3(1.45, 2.3, 0.0), WOOD_DARK)
	k.slab(Vector3(2.15, 1.2, z), Vector3(2.22, 2.3, 0.0), WOOD_DARK)
	k.slab(Vector3(1.45, 2.0, z), Vector3(2.15, 2.3, 0.0), WOOD_DARK)
	# plaster band above, dark beam, lit name board
	k.slab(Vector3(X0 + 0.18, 2.3, z), Vector3(X1 - 0.18, WALL_H, 0.0), PLASTER)
	k.slab(Vector3(X0, 2.3, -0.18), Vector3(X1, 2.42, 0.04), WOOD_DARK)
	var board := Vector3(-1.3, 3.08, 0.05)
	k.box(board, Vector3(4.2, 0.5, 0.08), WOOD_DARK, {"gloss": 0.3})
	k.box(board + Vector3(0, 0, 0.042), Vector3(4.05, 0.4, 0.01), Color(0.2, 0.13, 0.09), {"line": 0.0})
	k.text("麺屋  ゆきあかり", board + Vector3(0, 0.0, 0.05), 0.3, Color(1.0, 0.95, 0.85), {"jp": true})
	for x in [-2.9, 0.3]:
		k.rod(Vector3(x, 3.38, 0.02), Vector3(x, 3.42, 0.35), 0.015, INK)
		k.cyl(Vector3(x, 3.38, 0.38), 0.06, 0.08, Color(1.0, 0.92, 0.7), {"emit": 1.5, "top": 1.3})
	# big window with a wooden lattice over steamy glass
	var frame := {"line": 0.4}
	k.slab(Vector3(-4.82, 0.78, -0.1), Vector3(-1.0, 0.86, 0.03), WOOD_DARK, frame)
	k.slab(Vector3(-4.82, 2.24, -0.1), Vector3(-1.0, 2.32, 0.03), WOOD_DARK, frame)
	for i in 13:
		k.box(Vector3(-4.65 + i * 0.3, 1.55, 0.01), Vector3(0.03, 1.38, 0.03), WOOD, {"line": 0.3})
	for y in [1.3, 1.8]:
		k.box(Vector3(-2.9, y, 0.01), Vector3(3.8, 0.03, 0.03), WOOD, {"line": 0.3})
	_steamy(scene.add_glass(Vector3(-2.91, 1.55, -0.07), Vector2(3.8, 1.4), Basis.IDENTITY, 0.6))
	_steamy(scene.add_glass(Vector3(1.8, 1.6, -0.07), Vector2(0.7, 0.8), Basis.IDENTITY, 0.6))
	for x in [1.62, 1.8, 1.98]:
		k.box(Vector3(x, 1.6, 0.01), Vector3(0.025, 0.8, 0.025), WOOD, {"line": 0.3})
	# eave over the front: dark tiles on a timber edge
	var slope := Basis(Vector3.RIGHT, deg_to_rad(18))
	k.box(Vector3(-1.3, 2.62, 0.5), Vector3(7.7, 0.08, 1.15), TILE, {"basis": slope, "gloss": 0.4})
	k.box(Vector3(-1.3, 2.45, 1.06), Vector3(7.7, 0.1, 0.06), WOOD_DARK, {"basis": slope})
	if scene.weather_kind == "snow":
		k.box(Vector3(-1.3, 2.69, 0.48), Vector3(7.6, 0.07, 1.08), SNOW, {"basis": slope, "gloss": 0.1, "line": 0.3})
		for i in 9:
			k.ball(Vector3(-4.9 + i * 0.9, 2.47, 1.06), Vector3(0.5, 0.09, 0.14), SNOW, {"gloss": 0.1, "line": 0.3})

static func _steamy(glass: MeshInstance3D) -> void:
	# fogged on the inside: warm, half opaque, with condensation running down
	var mat: ShaderMaterial = glass.material_override
	mat.set_shader_parameter("tint", Color(1.0, 0.86, 0.66))
	mat.set_shader_parameter("base_alpha", 0.34)
	mat.set_shader_parameter("drop_color", Color(1.0, 0.95, 0.88))

static func _roof(k: Kit, snowy: bool) -> void:
	var ridge := Basis(Vector3.UP, PI * 0.5)
	var c := Vector3((X0 + X1) * 0.5, WALL_H + 0.65, Z0 * 0.5)
	k.prism(c, Vector3(6.1, 1.3, 8.1), TILE, {"basis": ridge, "gloss": 0.5})
	k.box(c + Vector3(0, 0.66, 0), Vector3(8.2, 0.12, 0.16), TILE * 0.7, {"gloss": 0.5})
	for x in [X0 - 0.35, X1 + 0.35]:
		k.prism(Vector3(x, WALL_H + 0.62, Z0 * 0.5), Vector3(5.6, 1.15, 0.06), PLASTER, {"basis": ridge})
	for z in [0.4, Z0 - 0.4]:
		k.box(Vector3(c.x, WALL_H + 0.02, z), Vector3(8.1, 0.1, 0.08), WOOD_DARK)
	if snowy:
		k.prism(c + Vector3(0, 0.1, 0), Vector3(5.7, 1.22, 8.0), SNOW, {"basis": ridge, "gloss": 0.1, "line": 0.4})
		for z in [0.2, Z0 - 0.2]:
			k.rod(Vector3(X0 - 0.3, WALL_H + 0.14, z), Vector3(X1 + 0.3, WALL_H + 0.14, z), 0.06, SNOW, {"seg": 6, "line": 0.3})
		# a few icicles along the front eave
		for i in 14:
			var x := X0 - 0.2 + i * 0.58
			k.cyl(Vector3(x, WALL_H - 0.08, 0.42), 0.025, 0.12 + (i % 3) * 0.06, Color(0.8, 0.9, 1.0), {"top": 0.0, "rot": Vector3(180, 0, 0), "seg": 5, "gloss": 0.8, "line": 0.2})

static func _door(k: Kit, scene: Node3D) -> void:
	# two lattice panels: the left one stays, the right one slides behind it
	for i in 2:
		var panel := Node3D.new()
		panel.name = "DoorPanel%d" % i
		panel.position = Vector3(-0.03 + i * 0.8, 1.2, -0.06 - i * 0.06)
		panel.set_meta("travel", 0.0 if i == 0 else -0.78)
		scene.add_child(panel)
		scene.door_panels.append(panel)
		var o := {"node": panel, "gloss": 0.2}
		for x in [-0.4, 0.4]:
			k.box(Vector3(x, 0, 0), Vector3(0.05, 2.0, 0.05), WOOD_DARK, o)
		k.box(Vector3(0, 0.98, 0), Vector3(0.85, 0.05, 0.05), WOOD_DARK, o)
		k.box(Vector3(0, -0.72, 0), Vector3(0.8, 0.56, 0.04), WOOD, o)
		k.box(Vector3(0, -0.43, 0), Vector3(0.85, 0.05, 0.05), WOOD_DARK, o)
		for x in [-0.2, 0.0, 0.2]:
			k.box(Vector3(x, 0.28, 0.02), Vector3(0.02, 1.36, 0.02), WOOD, {"node": panel, "line": 0.3})
		for y in [0.0, 0.5]:
			k.box(Vector3(0, y, 0.02), Vector3(0.78, 0.02, 0.02), WOOD, {"node": panel, "line": 0.3})
		_steamy(scene.add_glass(Vector3(0, 0.28, 0), Vector2(0.76, 1.36), Basis.IDENTITY, 0.5, false, panel))
	# noren: an indigo curtain on a rod, split into three, swaying a little
	k.rod(Vector3(-0.5, 2.24, 0.1), Vector3(1.25, 2.24, 0.1), 0.02, WOOD_DARK)
	var noren := Node3D.new()
	noren.name = "Noren"
	noren.position = Vector3(0.38, 2.24, 0.1)
	noren.set_meta("amp", 0.03)
	noren.set_meta("speed", 1.6)
	noren.set_meta("phase", 0.4)
	scene.add_child(noren)
	scene.sway_nodes.append(noren)
	for i in 3:
		k.box(Vector3(-0.56 + i * 0.56, -0.36, 0), Vector3(0.53, 0.72, 0.02), INDIGO, {"node": noren, "line": 0.6})
	k.box(Vector3(0, -0.66, 0.012), Vector3(1.65, 0.04, 0.005), Color(0.95, 0.95, 0.95), {"node": noren, "line": 0.0})
	k.text("らーめん", Vector3(0, -0.32, 0.015), 0.22, Color(0.97, 0.97, 0.95), {"node": noren, "jp": true})
	# red paper lanterns hanging from the eave, lit, swaying
	var lit := k.material("sign_band")
	scene.sign_band_material = lit
	for x in [-0.72, 1.62]:
		var lantern := Node3D.new()
		lantern.name = "Lantern"
		lantern.position = Vector3(x, 2.55, 0.55)
		lantern.set_meta("amp", 0.05)
		lantern.set_meta("speed", 1.2 + x * 0.1)
		lantern.set_meta("phase", x)
		scene.add_child(lantern)
		scene.sway_nodes.append(lantern)
		var o := {"node": lantern}
		k.rod(Vector3(0, 0.0, 0), Vector3(0, -0.16, 0), 0.008, INK, o)
		k.cyl(Vector3(0, -0.19, 0), 0.15, 0.06, INK, {"node": lantern, "seg": 14})
		k.cyl(Vector3(0, -0.48, 0), 0.21, 0.52, LANTERN, {"node": lantern, "seg": 16, "mat": "sign_band", "emit": 1.0})
		for y in [-0.33, -0.48, -0.63]:
			k.torus(Vector3(0, y, 0), 0.212, 0.006, LANTERN * 0.7, {"node": lantern, "line": 0.0})
		k.cyl(Vector3(0, -0.77, 0), 0.15, 0.06, INK, {"node": lantern, "seg": 14})
		k.text("麺", Vector3(0, -0.48, 0.215), 0.24, INK, {"node": lantern, "jp": true})

static func _street_things(k: Kit, scene: Node3D) -> void:
	# lit standing sign by the door
	var stand := k.material("pole_sign")
	scene.pole_sign_material = stand
	var a := Vector3(2.0, LOT, 0.7)
	for c in [Vector2(-0.18, -0.18), Vector2(0.18, -0.18), Vector2(-0.18, 0.18), Vector2(0.18, 0.18)]:
		k.box(a + Vector3(c.x, 0.55, c.y), Vector3(0.04, 1.1, 0.04), WOOD_DARK)
	k.box(a + Vector3(0, 0.7, 0), Vector3(0.33, 0.8, 0.33), Color(1.0, 0.97, 0.9), {"mat": "pole_sign", "emit": 1.0})
	k.box(a + Vector3(0, 1.13, 0), Vector3(0.44, 0.05, 0.44), WOOD_DARK)
	var open_sign := k.text("営\n業\n中", a + Vector3(0, 0.72, 0.17), 0.18, INK, {"jp": true})
	open_sign.line_spacing = -10
	# chalk menu board
	var m := Vector3(-1.6, LOT, 0.72)
	# an A-frame: both boards lean in toward each other at the top
	for s in [-1.0, 1.0]:
		k.box(m + Vector3(0, 0.45, s * 0.1), Vector3(0.52, 0.85, 0.03), WOOD, {"rot": Vector3(-s * 12, 0, 0)})
	var face := Basis(Vector3.RIGHT, deg_to_rad(-12))
	k.box(m + Vector3(0, 0.47, 0.12), Vector3(0.44, 0.7, 0.01), Color(0.12, 0.17, 0.15), {"basis": face, "line": 0.0})
	var chalk := k.text("おすすめ\n味噌\n醤油\n塩\n餃子", m + Vector3(0, 0.47, 0.13) + face * Vector3(0, 0, 0.01), 0.065, Color(0.95, 0.95, 0.9), {"jp": true})
	chalk.basis = face
	# an umbrella left against the post, a snow shovel, potted pines, a snowman
	var umb := Vector3(-0.62, LOT, 0.12)
	k.rod(umb, umb + Vector3(0.06, 0.9, -0.05), 0.008, STEEL)
	k.cyl(umb + Vector3(0.03, 0.5, -0.025), 0.06, 0.62, Color(0.85, 0.92, 0.98), {"basis": Kit.aim(Vector3(-0.06, -0.9, 0.05)), "top": 0.25, "seg": 8, "gloss": 0.8})
	k.rod(Vector3(-4.75, LOT, 0.2), Vector3(-4.7, 1.2, 0.05), 0.02, WOOD)
	k.box(Vector3(-4.76, LOT + 0.14, 0.24), Vector3(0.32, 0.26, 0.04), Color(0.85, 0.2, 0.2), {"rot": Vector3(-12, 0, 0), "gloss": 0.5})
	var pine := Vector3(-4.25, LOT, 0.5)
	k.cyl(pine + Vector3(0, 0.18, 0), 0.18, 0.36, Color(0.45, 0.3, 0.22), {"seg": 10, "top": 1.15})
	k.cyl(pine + Vector3(0, 0.75, 0), 0.26, 0.8, Color(0.18, 0.38, 0.28), {"seg": 8, "top": 0.15})
	if scene.weather_kind == "snow":
		k.cyl(pine + Vector3(0, 0.82, 0), 0.2, 0.08, SNOW, {"seg": 8, "top": 0.6, "line": 0.3})
	if scene.weather_kind == "snow":
		var s := Vector3(-4.3, LOT + 0.04, 3.2)
		k.ball(s + Vector3(0, 0.25, 0), Vector3(0.28, 0.25, 0.28), SNOW, {"gloss": 0.1})
		k.ball(s + Vector3(0, 0.62, 0), Vector3(0.19, 0.18, 0.19), SNOW, {"gloss": 0.1})
		k.ball(s + Vector3(0, 0.9, 0), Vector3(0.13, 0.13, 0.13), SNOW, {"gloss": 0.1})
		for x in [-0.045, 0.045]:
			k.ball(s + Vector3(x, 0.94, 0.11), Vector3.ONE * 0.018, INK, {"line": 0.0, "seg": 6})
		k.cyl(s + Vector3(0, 0.9, 0.16), 0.022, 0.1, Color(1.0, 0.5, 0.15), {"rot": Vector3(90, 0, 0), "top": 0.0, "seg": 6})
		k.torus(s + Vector3(0, 0.78, 0), 0.12, 0.03, Color(0.85, 0.2, 0.2), {"line": 0.4})
		for side in [-1.0, 1.0]:
			k.rod(s + Vector3(side * 0.17, 0.66, 0), s + Vector3(side * 0.42, 0.84, 0.05), 0.01, WOOD_DARK)
		k.cyl(s + Vector3(0, 1.04, 0), 0.09, 0.1, Color(0.3, 0.5, 0.85), {"seg": 10, "top": 0.8})

# --- inside -------------------------------------------------------------------------

## Options for indoor parts: layer 2 plus a warm fill.
static func o(extra := {}) -> Dictionary:
	var opts := {"indoor": true, "lit": 0.32}
	opts.merge(extra, true)
	return opts

static func interior(k: Kit, scene: Node3D) -> void:
	var xi0 := X0 + 0.15
	var xi1 := X1 - 0.15
	var zb := Z0 + 0.15
	var ceil := WALL_H - 0.2
	var cream := Color(0.95, 0.85, 0.7)
	k.slab(Vector3(xi0, FLOOR - 0.01, zb), Vector3(xi1, FLOOR, -0.15), Color(0.55, 0.4, 0.28), o({"mat": "wood", "line": 0.0, "lit": 0.28, "gloss": 0.25}))
	var wall := o({"line": 0.3})
	k.slab(Vector3(xi0 - 0.01, FLOOR, zb), Vector3(xi0 + 0.01, ceil, -0.15), cream, wall)
	k.slab(Vector3(xi0, FLOOR, zb - 0.01), Vector3(xi1, ceil, zb + 0.01), cream, wall)
	k.slab(Vector3(xi1 - 0.01, FLOOR, zb), Vector3(xi1 + 0.01, ceil, -0.15), cream, wall)
	k.slab(Vector3(xi0, 2.3, -0.17), Vector3(xi1, ceil, -0.15), cream, wall)
	k.slab(Vector3(xi0, FLOOR, -0.17), Vector3(-1.0, 0.8, -0.15), WOOD, wall)
	k.slab(Vector3(1.2, FLOOR, -0.17), Vector3(xi1, 1.2, -0.15), WOOD, wall)
	k.slab(Vector3(xi0, ceil, zb), Vector3(xi1, ceil + 0.04, -0.15), Color(0.6, 0.45, 0.32), o({"line": 0.0}))
	for x in [-4.0, -2.5, -1.0, 0.5, 1.8]:
		k.slab(Vector3(x - 0.07, ceil - 0.14, zb), Vector3(x + 0.07, ceil, -0.15), WOOD_DARK, o())
	_counter(k, scene)
	_kitchen(k, scene)
	_corners(k, scene)

static func _counter(k: Kit, scene: Node3D) -> void:
	var z0 := -2.35
	var z1 := -1.85
	# counter with a raised ledge on the kitchen side, seven stools facing the kitchen
	k.slab(Vector3(-4.6, FLOOR, z0), Vector3(1.0, 1.0, z1), WOOD_DARK, o({"gloss": 0.2}))
	k.slab(Vector3(-4.65, 1.0, z0 - 0.02), Vector3(1.05, 1.06, z1 + 0.06), WOOD_LIGHT, o({"mat": "wood", "gloss": 0.35}))
	k.slab(Vector3(-4.6, 1.06, z0 - 0.02), Vector3(1.0, 1.22, z0 + 0.12), WOOD_LIGHT * 0.9, o({"mat": "wood"}))
	for i in 7:
		var x := -4.2 + i * 0.8
		k.cyl(Vector3(x, FLOOR + 0.33, -1.42), 0.03, 0.66, Color(0.2, 0.2, 0.24), o({"seg": 8}))
		k.cyl(Vector3(x, FLOOR + 0.01, -1.42), 0.16, 0.02, Color(0.2, 0.2, 0.24), o({"seg": 12}))
		k.cyl(Vector3(x, FLOOR + 0.7, -1.42), 0.18, 0.08, Color(0.78, 0.18, 0.14), o({"seg": 14, "gloss": 0.3, "lit": 0.45}))
		# condiments and a chopstick box every other seat
		if i % 2 == 0:
			var c := Vector3(x, 1.22, z0 + 0.06)
			for j in 3:
				k.cyl(c + Vector3(-0.08 + j * 0.08, 0.05, 0), 0.025, 0.1, [Color(0.85, 0.15, 0.1), Color(0.15, 0.12, 0.1), Color(0.95, 0.92, 0.85)][j], o({"seg": 8, "line": 0.3}))
			k.box(c + Vector3(0.22, 0.04, 0), Vector3(0.14, 0.08, 0.07), WOOD, o({"line": 0.3}))
	# the bowl someone is halfway through, chopsticks across it, a glass of water
	var bowl := Vector3(-2.6, 1.06, -2.08)
	k.cyl(bowl + Vector3(0, 0.06, 0), 0.14, 0.12, Color(0.12, 0.08, 0.08), o({"top": 1.35, "seg": 16, "gloss": 0.5}))
	k.cyl(bowl + Vector3(0, 0.115, 0), 0.165, 0.008, Color(0.85, 0.55, 0.25), o({"seg": 16, "line": 0.0, "emit": 0.2}))
	for i in 5:
		k.rod(bowl + Vector3(-0.1 + i * 0.04, 0.12, -0.08), bowl + Vector3(-0.08 + i * 0.04, 0.125, 0.08), 0.006, Color(1.0, 0.88, 0.5), o({"line": 0.0}))
	k.ball(bowl + Vector3(0.06, 0.125, 0.04), Vector3(0.06, 0.012, 0.05), Color(0.95, 0.9, 0.85), o({"line": 0.0, "seg": 8}))
	k.ball(bowl + Vector3(-0.06, 0.125, 0.05), Vector3(0.05, 0.012, 0.05), Color(0.9, 0.7, 0.4), o({"line": 0.0, "seg": 8}))
	k.rod(bowl + Vector3(-0.17, 0.14, 0.05), bowl + Vector3(0.17, 0.14, 0.07), 0.006, WOOD_LIGHT, o({"line": 0.3}))
	k.rod(bowl + Vector3(-0.17, 0.14, 0.09), bowl + Vector3(0.17, 0.14, 0.1), 0.006, WOOD_LIGHT, o({"line": 0.3}))
	k.cyl(bowl + Vector3(0.3, 0.06, 0.05), 0.035, 0.12, Color(0.8, 0.9, 0.95), o({"seg": 10, "gloss": 0.9}))
	scene.add_steam(bowl + Vector3(0, 0.12, 0), Vector2(0.3, 0.35), 0.22)
	k.box(Vector3(-1.4, 1.07, -2.05), Vector3(0.1, 0.01, 0.05), Color(0.98, 0.95, 0.85), o({"line": 0.2, "rot": Vector3(0, 20, 0)}))
	# pendant lamps over the counter
	for x in [-3.8, -2.6, -1.4, -0.2]:
		var top := Vector3(x, WALL_H - 0.2, -2.0)
		k.rod(top, top + Vector3(0, -0.55, 0), 0.006, INK, o({"line": 0.0}))
		k.cyl(top + Vector3(0, -0.62, 0), 0.16, 0.14, Color(0.2, 0.16, 0.12), o({"top": 0.35, "seg": 12}))
		k.ball(top + Vector3(0, -0.72, 0), Vector3.ONE * 0.08, Color(1.0, 0.85, 0.55), o({"emit": 1.6, "seg": 8, "line": 0.0}))
	# the soffit over the counter carries the wooden menu plaques, read from the window
	k.slab(Vector3(-4.85, 2.5, -2.45), Vector3(1.1, WALL_H - 0.2, -2.3), WOOD_DARK, o())
	var plaques := [["醤\n油", "800"], ["味\n噌", "850"], ["塩", "800"], ["餃\n子", "350"], ["ビ\nー\nル", "500"], ["替\n玉", "150"], ["大\n盛\nり", "100"]]
	for i in plaques.size():
		var p := Vector3(-4.3 + i * 0.62, 2.82, -2.29)
		k.box(p, Vector3(0.2, 0.56, 0.015), Color(0.93, 0.85, 0.66), o({"line": 0.4, "lit": 0.5}))
		var t := k.text(plaques[i][0], p + Vector3(0, 0.05, 0.01), 0.1, INK, {"indoor": true, "jp": true})
		t.line_spacing = -8
		k.text(plaques[i][1], p + Vector3(0, -0.22, 0.01), 0.055, Color(0.7, 0.1, 0.1), {"indoor": true, "jp": true})

static func _kitchen(k: Kit, scene: Node3D) -> void:
	var zb := Z0 + 0.15
	k.slab(Vector3(-4.8, FLOOR, zb), Vector3(1.9, 0.95, zb + 0.6), STEEL, o({"gloss": 0.5}))
	k.slab(Vector3(-4.8, 0.95, zb), Vector3(1.9, 0.98, zb + 0.62), STEEL * 1.05, o({"gloss": 0.6}))
	# stock pots on the range, the noodle boiler with its baskets
	for x in [-4.1, -3.3]:
		k.cyl(Vector3(x, 1.26, zb + 0.32), 0.3, 0.56, STEEL, o({"seg": 16, "gloss": 0.7, "lit": 0.45}))
		k.cyl(Vector3(x, 1.545, zb + 0.32), 0.27, 0.01, Color(0.85, 0.6, 0.3), o({"seg": 16, "line": 0.0, "emit": 0.25}))
		k.rod(Vector3(x - 0.1, 1.5, zb + 0.32), Vector3(x + 0.05, 1.9, zb + 0.45), 0.012, STEEL, o())
		scene.add_steam(Vector3(x, 1.55, zb + 0.32), Vector2(0.7, 1.0), 0.32)
	k.box(Vector3(-2.0, 1.12, zb + 0.32), Vector3(1.0, 0.3, 0.55), STEEL, o({"gloss": 0.6}))
	k.box(Vector3(-2.0, 1.275, zb + 0.32), Vector3(0.92, 0.01, 0.48), Color(0.75, 0.82, 0.88), o({"line": 0.0, "emit": 0.15}))
	for i in 6:
		var b := Vector3(-2.35 + (i % 3) * 0.35, 1.3, zb + 0.2 + (i / 3) * 0.24)
		k.torus(b, 0.07, 0.01, STEEL * 0.8, o({"line": 0.3}))
		k.rod(b + Vector3(0, 0, 0.07), b + Vector3(0.0, 0.25, 0.32), 0.01, WOOD, o({"line": 0.3}))
	scene.add_steam(Vector3(-2.0, 1.3, zb + 0.32), Vector2(0.9, 0.8), 0.28)
	# hood, bowl shelves, ladles, a prep table
	k.slab(Vector3(-4.6, 2.3, zb), Vector3(-1.4, 2.75, zb + 0.75), STEEL * 0.9, o({"gloss": 0.5}))
	for y in [1.55, 1.95]:
		k.slab(Vector3(-0.9, y, zb), Vector3(1.8, y + 0.03, zb + 0.3), WOOD, o())
		for i in 7:
			var stack := Vector3(-0.7 + i * 0.36, y + 0.03, zb + 0.15)
			for j in 3:
				k.cyl(stack + Vector3(0, 0.03 + j * 0.05, 0), 0.12, 0.05, [Color(0.95, 0.93, 0.88), Color(0.75, 0.15, 0.12)][i % 2], o({"top": 1.3, "seg": 12, "line": 0.3, "lit": 0.45}))
	k.rod(Vector3(-0.9, 2.45, zb + 0.05), Vector3(1.8, 2.45, zb + 0.05), 0.01, STEEL, o())
	for i in 5:
		var h := Vector3(-0.6 + i * 0.5, 2.45, zb + 0.06)
		k.rod(h, h + Vector3(0, -0.3, 0), 0.008, STEEL, o({"line": 0.0}))
		k.ball(h + Vector3(0, -0.34, 0.02), Vector3(0.1, 0.05, 0.1), STEEL, o({"seg": 8}))
	k.box(Vector3(0.6, 1.0, zb + 0.32), Vector3(0.5, 0.06, 0.4), WOOD_LIGHT, o({"line": 0.3}))
	k.box(Vector3(0.5, 1.06, zb + 0.32), Vector3(0.3, 0.05, 0.16), Color(0.95, 0.85, 0.6), o({"line": 0.3}))
	# the doorway to the back room with its own small noren
	k.slab(Vector3(1.05, FLOOR, zb + 0.01), Vector3(1.75, 2.1, zb + 0.02), Color(0.25, 0.2, 0.16), o({"line": 0.0, "lit": 0.1}))
	for i in 2:
		k.box(Vector3(1.23 + i * 0.35, 1.8, zb + 0.04), Vector3(0.33, 0.6, 0.01), INDIGO, o({"line": 0.4, "lit": 0.4}))

static func _corners(k: Kit, _scene: Node3D) -> void:
	# ticket machine by the door
	var tm := Vector3(X1 - 0.4, FLOOR, -0.75)
	k.box(tm + Vector3(0, 0.8, 0), Vector3(0.4, 1.6, 0.7), Color(0.85, 0.86, 0.9), o({"gloss": 0.4}))
	k.box(tm + Vector3(-0.205, 1.25, 0), Vector3(0.01, 0.4, 0.6), Color(0.15, 0.15, 0.2), o({"line": 0.3}))
	for r in 4:
		for c in 4:
			k.box(tm + Vector3(-0.21, 1.1 + r * 0.08, -0.2 + c * 0.13), Vector3(0.01, 0.06, 0.11), [Color(1.0, 0.85, 0.3), Color(1.0, 0.55, 0.3), Color(0.5, 0.85, 1.0), Color(0.9, 0.95, 1.0)][(r + c) % 4], o({"emit": 0.8, "line": 0.0}))
	k.box(tm + Vector3(-0.21, 0.8, 0.15), Vector3(0.02, 0.12, 0.2), Color(0.2, 0.2, 0.25), o({"line": 0.3}))
	k.text("食券", tm + Vector3(-0.211, 1.5, 0), 0.08, Color(0.75, 0.1, 0.1), {"indoor": true, "jp": true, "rot": Vector3(0, -90, 0)})
	# water jug with a note, a shelf with the beckoning cat and a small television
	var jug := Vector3(0.4, 1.22, -2.28)
	k.cyl(jug + Vector3(0, 0.12, 0), 0.07, 0.24, Color(0.75, 0.88, 0.95), o({"seg": 10, "gloss": 0.9}))
	var shelf := Vector3(-4.7, 2.25, -0.9)
	k.box(shelf, Vector3(0.28, 0.03, 0.6), WOOD, o())
	var cat := shelf + Vector3(0.02, 0.02, 0)
	k.ball(cat + Vector3(0, 0.1, 0), Vector3(0.18, 0.2, 0.16), Color(0.98, 0.97, 0.94), o({"seg": 10, "lit": 0.5}))
	k.ball(cat + Vector3(0, 0.27, 0), Vector3(0.17, 0.15, 0.15), Color(0.98, 0.97, 0.94), o({"seg": 10, "lit": 0.5}))
	for s in [-1.0, 1.0]:
		k.prism(cat + Vector3(0, 0.36, s * 0.05), Vector3(0.05, 0.06, 0.04), Color(0.98, 0.97, 0.94), o({"rot": Vector3(0, 90, 0), "lit": 0.5}))
	k.ball(cat + Vector3(0.04, 0.32, -0.1), Vector3(0.06, 0.08, 0.06), Color(0.98, 0.97, 0.94), o({"seg": 8, "lit": 0.5}))
	k.torus(cat + Vector3(0, 0.19, 0), 0.07, 0.012, Color(0.85, 0.15, 0.15), o({"line": 0.0}))
	k.ball(cat + Vector3(0.08, 0.15, 0), Vector3(0.06, 0.06, 0.03), Color(0.95, 0.75, 0.2), o({"seg": 8, "line": 0.3}))
	var tv := Vector3(-4.62, 2.6, -1.6)
	k.box(tv, Vector3(0.08, 0.36, 0.6), Color(0.1, 0.1, 0.12), o({"rot": Vector3(0, -25, 0)}))
	k.box(tv + Vector3(0.045, 0, 0), Vector3(0.01, 0.3, 0.54), Color(0.45, 0.7, 0.95), o({"rot": Vector3(0, -25, 0), "emit": 0.7, "line": 0.0}))
	k.text("お水 ご自由にどうぞ", Vector3(0.4, 1.32, -2.3), 0.035, INK, {"indoor": true, "jp": true})
