extends Node3D
## Rain over the diorama and everything the water does: falling streaks, impact
## rings, drips off the edges, puddles, the gutters running, and the smeared
## reflections of every lamp on the wet ground (turned toward the camera each frame).

const RAIN := preload("res://shaders/konbini_rain.gdshader")
const SPLASH := preload("res://shaders/konbini_splash.gdshader")
const DRIP := preload("res://shaders/konbini_drip.gdshader")
const PUDDLE := preload("res://shaders/konbini_puddle.gdshader")
const REFLECTION := preload("res://shaders/konbini_reflection.gdshader")

const HALF := 9.0
const LOT := 0.12
## Roofs the rain does not get under: x0, z0, x1, z1 and the roof height.
const SHELTERS := [
	[Vector4(-5.1, -5.3, 2.55, 0.05), 4.2],     # shop
	[Vector4(-5.1, 0.0, 2.5, 1.42), 2.86],      # awning
	[Vector4(-9.1, -6.1, -6.6, 2.5), 5.8],      # neighbour house
	[Vector4(-8.95, 2.5, -6.85, 3.15), 3.08],   # balcony
	[Vector4(2.4, -5.0, 3.2, -3.25), 1.9],      # vending machines
	[Vector4(2.6, 2.6, 4.0, 4.0), 5.45],        # pole sign
	[Vector4(-8.75, 2.4, -7.65, 2.85), 2.28],   # neighbour door canopy
	[Vector4(0, 0, 0, 0), 0.0],
]

var rain_material: ShaderMaterial
var lamps: Array = []          # [position, radius, color] fed to the rain shader
var reflections: Array = []    # {node, base, width, length}
var _rng := RandomNumberGenerator.new()
var _strip: ArrayMesh

func setup(lamp_list: Array) -> void:
	_rng.seed = 2405
	lamps = lamp_list
	_rain()
	_splashes()
	_drips()
	_puddles()
	_gutters()

static func sheltered(x: float, z: float) -> bool:
	for s in SHELTERS:
		var r: Vector4 = s[0]
		if x > r.x and x < r.z and z > r.y and z < r.w:
			return true
	return false

## Height of the ground at x, z (roads sit 12 cm below the lot and sidewalks).
static func ground(x: float, z: float) -> float:
	var on_road := (z > 5.2 and z < 8.6) or (x > 5.2 and x < 8.6 and z < 8.6)
	return 0.0 if on_road else LOT

func _rain() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = 3600
	for i in mm.instance_count:
		var x := _rng.randf_range(-HALF + 0.1, HALF - 0.1)
		var z := _rng.randf_range(-HALF + 0.1, HALF - 0.1)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x, 0.0, z)))
		mm.set_instance_custom_data(i, Color(_rng.randf(), _rng.randf(), 0, 0))
	rain_material = ShaderMaterial.new()
	rain_material.shader = RAIN
	var rects := []
	var tops := PackedFloat32Array()
	for s in SHELTERS:
		rects.append(s[0])
		tops.append(s[1])
	rain_material.set_shader_parameter("shelters", rects)
	rain_material.set_shader_parameter("shelter_top", tops)
	update_lamps()
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Rain"
	mmi.multimesh = mm
	mmi.material_override = rain_material
	mmi.custom_aabb = AABB(Vector3(-11, -1, -11), Vector3(22, 14, 22))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

## Pushes lamp positions and colours (the traffic light changes) to the rain.
func update_lamps() -> void:
	var pos := []
	var col := []
	for i in 10:
		if i < lamps.size():
			var lamp: Array = lamps[i]
			var p: Vector3 = lamp[0]
			var c: Color = lamp[2]
			pos.append(Vector4(p.x, p.y, p.z, lamp[1]))
			col.append(Vector4(c.r, c.g, c.b, 1.0))
		else:
			pos.append(Vector4(0, -100, 0, 0.001))
			col.append(Vector4.ZERO)
	rain_material.set_shader_parameter("lamps", pos)
	rain_material.set_shader_parameter("lamp_colors", col)

func _ring_multimesh(spots: Array, strength: float, name_: String) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	mm.mesh = plane
	mm.instance_count = spots.size()
	for i in spots.size():
		var s: Array = spots[i]
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * s[1]), s[0]))
		mm.set_instance_custom_data(i, Color(s[2], s[3], 0, 0))
	var mat := ShaderMaterial.new()
	mat.shader = SPLASH
	mat.set_shader_parameter("strength", strength)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name_
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.custom_aabb = AABB(Vector3(-10, -1, -10), Vector3(20, 8, 20))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _splashes() -> void:
	var spots := []
	while spots.size() < 520:
		var x := _rng.randf_range(-HALF + 0.15, HALF - 0.15)
		var z := _rng.randf_range(-HALF + 0.15, HALF - 0.15)
		if sheltered(x, z):
			continue
		spots.append([Vector3(x, ground(x, z) + 0.008, z), _rng.randf_range(0.16, 0.3), _rng.randf(), _rng.randf_range(0.45, 1.3)])
	# rain also lands on the roofs and the awning
	for i in 70:
		var x := _rng.randf_range(-4.9, 2.3)
		var z := _rng.randf_range(-5.1, -0.1)
		spots.append([Vector3(x, 4.06, z), _rng.randf_range(0.16, 0.28), _rng.randf(), _rng.randf_range(0.45, 1.3)])
	for i in 24:
		spots.append([Vector3(_rng.randf_range(-4.9, 2.3), 2.846, _rng.randf_range(0.1, 1.25)), 0.18, _rng.randf(), _rng.randf_range(0.5, 1.3)])
	for i in 30:
		spots.append([Vector3(_rng.randf_range(-8.9, -6.7), 5.77, _rng.randf_range(-6.0, 2.4)), 0.22, _rng.randf(), _rng.randf_range(0.5, 1.3)])
	_ring_multimesh(spots, 0.5, "Splashes")

func _drips() -> void:
	var sources := []  # [edge point, landing height, period]
	for i in 15:
		sources.append([Vector3(-4.95 + i * 0.5 + _rng.randf_range(-0.12, 0.12), 2.66, 1.41), LOT, _rng.randf_range(0.9, 2.2)])
	for i in 6:
		sources.append([Vector3(-8.8 + i * 0.36, 3.0, 3.16), LOT, _rng.randf_range(1.0, 2.4)])
	for i in 6:
		sources.append([Vector3(-6.61, 5.6, -5.4 + i * 1.3), LOT, _rng.randf_range(0.8, 1.8)])
	for i in 3:
		sources.append([Vector3(3.19, 1.97, -4.8 + i * 0.7), LOT, _rng.randf_range(1.1, 2.0)])
	for i in 2:
		sources.append([Vector3(3.3 + (i - 0.5) * 0.6, 3.72, 3.3 + (0.5 - i) * 0.6), LOT, _rng.randf_range(1.2, 2.2)])
	# the downpipe outlet runs steadily
	for i in 7:
		sources.append([Vector3(-5.3 + _rng.randf_range(-0.02, 0.02), 0.22, -5.28 + _rng.randf_range(-0.02, 0.02)), LOT, _rng.randf_range(0.42, 0.5)])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = sources.size()
	var rings := []
	for i in sources.size():
		var s: Array = sources[i]
		var edge: Vector3 = s[0]
		var period: float = s[2]
		var height: float = edge.y - s[1]
		var phase := _rng.randf()
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, edge))
		mm.set_instance_custom_data(i, Color(phase, period, height, 0))
		var land := (0.35 + sqrt(2.0 * height / 9.8)) / period
		rings.append([Vector3(edge.x, s[1] + 0.01, edge.z), 0.32, fposmod(phase - land, 1.0), period])
	var mat := ShaderMaterial.new()
	mat.shader = DRIP
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Drips"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.custom_aabb = AABB(Vector3(-10, -1, -10), Vector3(20, 8, 20))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_ring_multimesh(rings, 0.8, "DripRings")

func _puddles() -> void:
	var blobs := [
		[Vector3(-1.4, LOT, 3.0), Vector2(1.0, 0.55)], [Vector3(0.9, LOT, 1.75), Vector2(0.55, 0.3)],
		[Vector3(-6.0, LOT, 4.55), Vector2(0.7, 0.32)], [Vector3(4.3, LOT, 4.45), Vector2(0.55, 0.4)],
		[Vector3(-4.0, 0.0, 5.95), Vector2(1.3, 0.42)], [Vector3(2.4, 0.0, 7.5), Vector2(0.9, 0.5)],
		[Vector3(7.4, 0.0, -3.4), Vector2(0.5, 1.1)], [Vector3(6.6, 0.0, 6.4), Vector2(1.0, 0.75)],
		[Vector3(-5.8, LOT, -2.6), Vector2(0.35, 0.8)], [Vector3(3.5, LOT, -0.35), Vector2(0.45, 0.3)],
		[Vector3(-3.2, LOT, 1.9), Vector2(0.45, 0.28)], [Vector3(-1.0, 0.0, 8.0), Vector2(0.8, 0.35)],
		[Vector3(1.5, LOT, -7.0), Vector2(0.8, 0.5)], [Vector3(-5.3, LOT, -5.5), Vector2(0.45, 0.35)],
	]
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for b in blobs:
		var c: Vector3 = b[0] + Vector3(0, 0.006, 0)
		var r: Vector2 = b[1]
		var n := 24
		var phase := _rng.randf() * TAU
		var base := verts.size()
		verts.append(c)
		colors.append(Color(1, 1, 1, 1))
		for i in n:
			var a := TAU * i / n
			var wobble := 1.0 + 0.14 * sin(a * 3.0 + phase) + 0.08 * sin(a * 5.0 + phase * 2.0)
			var edge := Vector3(cos(a) * r.x * wobble, 0, sin(a) * r.y * wobble)
			verts.append(c + edge * 0.78)
			colors.append(Color(1, 1, 1, 1))
			verts.append(c + edge)
			colors.append(Color(1, 1, 1, 0))
		for i in n:
			var inner := base + 1 + i * 2
			var next_inner := base + 1 + ((i + 1) % n) * 2
			indices.append_array([base, next_inner, inner])
			indices.append_array([inner, next_inner, next_inner + 1, inner, next_inner + 1, inner + 1])
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	_add_water("Puddles", verts, normals, colors, indices, 0.0, Vector2.RIGHT)

func _gutters() -> void:
	_water_strip("GutterA", Vector3(-9.0, 0.009, 5.27), Vector3(5.2, 0.009, 5.43), Vector2(1, 0))
	_water_strip("GutterB", Vector3(5.27, 0.009, -9.0), Vector3(5.43, 0.009, 5.2), Vector2(0, 1))

func _water_strip(name_: String, a: Vector3, b: Vector3, flow_dir: Vector2) -> void:
	var verts := PackedVector3Array([Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z), Vector3(a.x, a.y, b.z)])
	var normals := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	var colors := PackedColorArray([Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.8)])
	_add_water(name_, verts, normals, colors, PackedInt32Array([0, 2, 1, 0, 3, 2]), 1.0, flow_dir)

func _add_water(name_: String, verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, flow: float, flow_dir: Vector2) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = PUDDLE
	mat.set_shader_parameter("flow", flow)
	mat.set_shader_parameter("flow_dir", flow_dir)
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

## A smeared reflection on the ground below a light that hangs height metres up.
## Returns its material so the caller can change the colour (traffic lights).
func add_reflection(base: Vector3, color: Color, width: float, height: float, energy := 0.6, sharpness := 2.0) -> ShaderMaterial:
	if _strip == null:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 0, 1), Vector3(-0.5, 0, 1)])
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
		_strip = ArrayMesh.new()
		_strip.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = REFLECTION
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("energy", energy)
	mat.set_shader_parameter("sharpness", sharpness)
	mat.set_shader_parameter("seed", float(reflections.size()))
	var mi := MeshInstance3D.new()
	mi.name = "Reflection"
	mi.mesh = _strip
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = base
	add_child(mi)
	reflections.append({"node": mi, "material": mat, "base": base + Vector3(0, 0.012, 0), "width": width, "height": height})
	return mat

func face_camera(camera: Camera3D) -> void:
	var eye := camera.global_position
	for r in reflections:
		var base: Vector3 = r["base"]
		var flat := Vector3(eye.x - base.x, 0, eye.z - base.z)
		var reach := flat.length()
		if reach < 0.01:
			continue
		var dir := flat / reach
		# the light's mirror image lies this far from its foot, toward the eye
		var height: float = r["height"]
		var mirror := reach * height / (maxf(eye.y - base.y, 0.05) + height)
		var length := clampf(mirror * 2.0 + 0.4, 0.5, reach * 0.95)
		r["material"].set_shader_parameter("peak", clampf(mirror / length, 0.08, 0.9))
		var side := Vector3.UP.cross(dir)
		r["node"].transform = Transform3D(Basis(side * r["width"], Vector3.UP, dir * length), base)
