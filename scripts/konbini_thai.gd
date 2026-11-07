extends RefCounted
## The Thai street corner: what replaces or joins the Japanese pieces when the
## diorama's country is "thailand". Parked scooters, a coin-operated drinking-water
## machine and a top-up kiosk, a shophouse with its shutter down, the tangle of
## cables between the poles, and vertical traffic lights with a countdown.
## Called from scripts/konbini_exterior.gd with that builder's kit.

const Kit := preload("res://scripts/konbini_kit.gd")

const LOT := 0.12
const STEEL := Color(0.78, 0.8, 0.85)
const WIRE := Color(0.07, 0.07, 0.11)

static func street_corner(k: Kit, _scene: Node3D) -> void:
	_water_machine(k)
	_topup_kiosk(k)
	_scooter(k, Vector3(3.35, LOT, -2.1), 0.0, Color(0.85, 0.2, 0.22), true)
	_scooter(k, Vector3(3.35, LOT, -1.2), 6.0, Color(0.95, 0.88, 0.8), false)
	_scooter(k, Vector3(-3.7, LOT, 2.7), -90.0, Color(0.3, 0.55, 0.85), false)

static func _water_machine(k: Kit) -> void:
	var c := Vector3(2.77, LOT, -4.5)
	var blue := Color(0.18, 0.45, 0.82)
	k.box(c + Vector3(0, 1.0, 0), Vector3(0.7, 2.0, 0.95), blue, {"gloss": 0.5})
	k.box(c + Vector3(0.05, 2.04, 0), Vector3(0.84, 0.06, 1.05), blue * 0.8, {"gloss": 0.5})
	var face := c + Vector3(0.36, 0, 0)
	var turn := Vector3(0, 90, 0)
	k.box(face + Vector3(0, 1.78, 0), Vector3(0.02, 0.36, 0.85), Color(0.96, 0.98, 1.0), {"emit": 1.0, "line": 0.3})
	k.text("น้ำดื่ม", face + Vector3(0.015, 1.84, 0), 0.16, Color(0.1, 0.35, 0.8), {"rot": turn, "outline": 4})
	k.text("1 บาท / 1 ลิตร", face + Vector3(0.015, 1.68, 0), 0.06, Color(0.85, 0.15, 0.15), {"rot": turn})
	# window onto the glowing filter tubes
	k.box(face + Vector3(0, 1.2, 0), Vector3(0.02, 0.55, 0.7), Color(0.55, 0.85, 1.0), {"emit": 0.7, "line": 0.3})
	for i in 4:
		k.cyl(face + Vector3(0.02, 1.2, -0.24 + i * 0.16), 0.045, 0.48, Color(0.95, 0.97, 1.0), {"seg": 10, "line": 0.3, "emit": 0.3})
	# dispenser bay with its nozzle, coin slot and buttons
	k.box(face + Vector3(-0.08, 0.55, 0.12), Vector3(0.18, 0.45, 0.4), Color(0.06, 0.06, 0.1), {"line": 0.4})
	k.rod(face + Vector3(-0.08, 0.76, 0.12), face + Vector3(-0.08, 0.66, 0.12), 0.02, STEEL)
	k.box(face + Vector3(-0.02, 0.36, 0.12), Vector3(0.2, 0.02, 0.36), STEEL, {"gloss": 0.7})
	k.box(face + Vector3(0.01, 0.62, -0.28), Vector3(0.02, 0.2, 0.14), Color(0.85, 0.87, 0.92), {"line": 0.3})
	k.box(face + Vector3(0.02, 0.66, -0.28), Vector3(0.01, 0.03, 0.06), Color(0.3, 1.0, 0.5), {"emit": 1.5, "line": 0.0})
	# empty bottles waiting to be filled
	for i in 2:
		k.cyl(Vector3(3.3, LOT + 0.2, -4.75 + i * 0.3), 0.12, 0.4, Color(0.6, 0.8, 0.95), {"seg": 12, "gloss": 0.9, "emit": 0.1})
		k.cyl(Vector3(3.3, LOT + 0.43, -4.75 + i * 0.3), 0.04, 0.06, Color(0.2, 0.4, 0.85), {"seg": 8})

static func _topup_kiosk(k: Kit) -> void:
	var c := Vector3(2.64, LOT, -3.6)
	k.box(c + Vector3(0, 0.72, 0), Vector3(0.42, 1.44, 0.5), Color(0.98, 0.82, 0.2), {"gloss": 0.5})
	k.box(c + Vector3(0.215, 1.05, 0), Vector3(0.01, 0.28, 0.36), Color(0.35, 0.7, 1.0), {"emit": 1.0, "line": 0.3})
	k.box(c + Vector3(0.22, 0.72, 0), Vector3(0.04, 0.12, 0.3), Color(0.15, 0.15, 0.2), {"line": 0.3})
	k.text("เติมเงิน", c + Vector3(0.216, 1.32, 0), 0.08, Color(0.75, 0.1, 0.1), {"rot": Vector3(0, 90, 0)})

## Step-through scooter, local X along its length, front at +X.
static func _scooter(k: Kit, at: Vector3, yaw: float, color: Color, helmet: bool) -> void:
	var turn := Basis(Vector3.UP, deg_to_rad(yaw))
	var p := func(x: float, y: float, z: float = 0.0) -> Vector3: return at + turn * Vector3(x, y, z)
	var o := {"basis": turn}
	var tyre := Color(0.08, 0.08, 0.1)
	var wheel := turn * Basis(Vector3.RIGHT, PI * 0.5)
	for x in [-0.52, 0.55]:
		k.torus(p.call(x, 0.25), 0.18, 0.065, tyre, {"basis": wheel})
		k.cyl(p.call(x, 0.25), 0.11, 0.08, STEEL, {"basis": wheel, "seg": 10})
	k.box(p.call(0.1, 0.33), Vector3(0.5, 0.06, 0.28), Color(0.15, 0.15, 0.18), o)
	k.box(p.call(-0.38, 0.52), Vector3(0.62, 0.34, 0.34), color, {"basis": turn, "gloss": 0.7})
	k.box(p.call(-0.38, 0.73), Vector3(0.56, 0.08, 0.3), Color(0.12, 0.1, 0.1), {"basis": turn, "gloss": 0.3})
	k.box(p.call(0.42, 0.62), Vector3(0.1, 0.62, 0.36), color, {"basis": turn * Basis(Vector3.BACK, deg_to_rad(15)), "gloss": 0.7})
	k.box(p.call(0.58, 0.44), Vector3(0.28, 0.06, 0.16), color, {"basis": turn, "gloss": 0.7})
	k.rod(p.call(0.52, 0.32), p.call(0.47, 1.02), 0.025, STEEL)
	k.rod(p.call(0.45, 1.02, -0.3), p.call(0.45, 1.02, 0.3), 0.018, Color(0.15, 0.15, 0.18))
	k.box(p.call(0.5, 0.98), Vector3(0.12, 0.1, 0.2), color, {"basis": turn, "gloss": 0.7})
	k.box(p.call(0.57, 0.98), Vector3(0.02, 0.06, 0.14), Color(0.95, 0.95, 0.9), {"basis": turn, "line": 0.3})
	for side in [-0.24, 0.24]:
		k.rod(p.call(0.45, 1.02, side), p.call(0.4, 1.22, side * 1.3), 0.008, STEEL)
		k.ball(p.call(0.4, 1.24, side * 1.3), Vector3(0.08, 0.05, 0.08), Color(0.15, 0.15, 0.18), {"basis": turn, "seg": 8})
	k.box(p.call(-0.7, 0.6), Vector3(0.04, 0.05, 0.14), Color(1.0, 0.2, 0.2), {"basis": turn, "emit": 0.4, "line": 0.3})
	k.rod(p.call(-0.1, 0.3, 0.15), p.call(-0.2, LOT - at.y, 0.3), 0.012, STEEL)
	if helmet:
		k.ball(p.call(-0.35, 0.86), Vector3(0.26, 0.24, 0.26), Color(0.98, 0.95, 0.9), {"basis": turn, "gloss": 0.8})
		k.box(p.call(-0.24, 0.84), Vector3(0.04, 0.08, 0.2), Color(0.2, 0.25, 0.35), {"basis": turn, "line": 0.3})

## Thai shophouse ground floor: shutter rolled down, phone-repair signboard, plants.
static func shophouse_front(k: Kit) -> void:
	var shutter := Color(0.6, 0.62, 0.68)
	k.slab(Vector3(-8.9, LOT, 2.4), Vector3(-6.85, 2.5, 2.47), shutter, {"mat": "siding", "gloss": 0.5})
	k.slab(Vector3(-8.9, LOT, 2.4), Vector3(-6.85, LOT + 0.08, 2.5), shutter * 0.8)
	k.slab(Vector3(-8.95, 2.5, 2.4), Vector3(-6.8, 2.62, 2.56), shutter * 0.85, {"gloss": 0.4})
	k.box(Vector3(-7.87, LOT + 0.12, 2.52), Vector3(0.12, 0.08, 0.06), Color(0.25, 0.25, 0.3))
	k.slab(Vector3(-8.85, 2.64, 2.45), Vector3(-6.9, 2.96, 2.52), Color(0.98, 0.97, 0.95), {"emit": 0.45})
	k.text("ร้านซ่อมมือถือ", Vector3(-7.75, 2.8, 2.525), 0.16, Color(0.8, 0.12, 0.12), {"outline": 4})
	k.box(Vector3(-8.65, 2.8, 2.53), Vector3(0.12, 0.2, 0.02), Color(0.2, 0.45, 0.85), {"line": 0.3})
	for x in [-8.6, -7.1]:
		k.cyl(Vector3(x, LOT + 0.2, 3.0), 0.18, 0.4, Color(0.5, 0.35, 0.3), {"seg": 12, "top": 1.15})
		k.ball(Vector3(x, LOT + 0.62, 3.0), Vector3(0.36, 0.5, 0.36), Color(0.22, 0.5, 0.32))
	k.cyl(Vector3(-7.85, LOT + 0.22, 3.3), 0.15, 0.44, Color(0.2, 0.45, 0.85), {"top": 0.8, "seg": 10, "gloss": 0.6})

## Bundles of sagging communication cables between the poles, with coiled spares
## and junction boxes, as on any Thai street.
static func cable_tangle(b: RefCounted, poles: Array) -> void:
	var k: Kit = b.k
	var rng := RandomNumberGenerator.new()
	rng.seed = 66
	var spans := [[poles[0], poles[1]], [poles[1], poles[2]]]
	for span in spans:
		var a: Vector3 = span[0]
		var c: Vector3 = span[1]
		for i in 9:
			var h := rng.randf_range(4.5, 6.1)
			var off := Vector3(rng.randf_range(-0.14, 0.14), 0, rng.randf_range(-0.14, 0.14))
			var sag := rng.randf_range(0.45, 1.2)
			b._wire(a + Vector3(0, h, 0) + off, c + Vector3(0, h + rng.randf_range(-0.3, 0.3), 0) + off, sag, rng.randf_range(0.012, 0.03))
		for t in [0.3, 0.62]:
			var p := a.lerp(c, t) + Vector3(0, 5.3 - 0.8 * 4.0 * t * (1.0 - t), 0)
			k.box(p, Vector3(0.22, 0.14, 0.14), Color(0.1, 0.1, 0.13), {"gloss": 0.4})
	# cables running off the base, and spare loops hanging on every pole
	var leaving := [[poles[0], Vector3(-9.0, 0, poles[0].z)], [poles[2], Vector3(poles[2].x, 0, -9.0)], [poles[1], Vector3(9.0, 0, poles[1].z)], [poles[1], Vector3(poles[1].x, 0, 9.0)]]
	for pair in leaving:
		var from: Vector3 = pair[0]
		var to: Vector3 = pair[1]
		for i in 4:
			var h := rng.randf_range(4.6, 5.9)
			b._wire(from + Vector3(0, h, 0), Vector3(to.x, h - rng.randf_range(0.2, 0.6), to.z), rng.randf_range(0.2, 0.5), 0.016)
	for pole in poles:
		for i in 2:
			var yaw := rng.randf() * TAU
			var dir := Vector3(cos(yaw), 0, sin(yaw))
			k.torus(pole + Vector3(0, 4.7 + i * 0.5, 0) + dir * 0.3, 0.28 - i * 0.05, 0.03, WIRE, {"basis": Basis(Vector3.UP, -yaw) * Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.BACK, 0.0), "line": 0.4})

## Thai vertical signal head (red over amber over green) with a countdown box
## beside it. Returns the [green, amber, red] lens materials and adds the
## countdown label to scene.countdowns.
static func signal_head(k: Kit, scene: Node3D, center: Vector3, face: Basis, prefix: String) -> Array:
	var body := Color(0.22, 0.24, 0.28)
	k.box(center, Vector3(0.36, 1.12, 0.26), body, {"basis": face, "gloss": 0.5})
	k.box(center + face * Vector3(0, 0, -0.13), Vector3(0.48, 1.24, 0.02), Color(0.08, 0.08, 0.1), {"basis": face})
	k.rod(center + Vector3(0, 0.56, 0), center + Vector3(0, 0.66, 0), 0.04, Color(0.55, 0.6, 0.66))
	var colors := [Color(0.15, 0.95, 0.45), Color(1.0, 0.7, 0.1), Color(1.0, 0.18, 0.15)]
	var mats := []
	for i in 3:
		var mat_name := "%s_%d" % [prefix, i]
		mats.append(k.material(mat_name, 0, {"emit_energy": 0.0}))
		var lens := center + face * Vector3(0, -0.36 + i * 0.36, 0.135)
		k.cyl(lens, 0.13, 0.02, colors[i], {"basis": face * Basis(Vector3.RIGHT, PI * 0.5), "seg": 16, "mat": mat_name, "emit": 1.0, "line": 0.4})
		k.box(lens + face * Vector3(0, 0.15, 0.08), Vector3(0.3, 0.02, 0.18), body, {"basis": face})
	var box_at := center + face * Vector3(0.46, 0.2, 0)
	k.box(box_at, Vector3(0.44, 0.36, 0.22), body, {"basis": face, "gloss": 0.5})
	k.box(box_at + face * Vector3(0, 0, 0.112), Vector3(0.38, 0.3, 0.01), Color(0.03, 0.03, 0.04), {"basis": face, "line": 0.0})
	k.rod(box_at + face * Vector3(-0.22, 0, 0), center + face * Vector3(-0.0, 0.2, 0), 0.02, body)
	var label := k.text("--", box_at + face * Vector3(0, 0, 0.12), 0.22, Color(1.0, 0.2, 0.15) * 1.6, {"outline": 2})
	label.basis = face
	scene.countdowns.append(label)
	return mats
