extends RefCounted
## Builds the konbini diorama out of vertex-coloured primitives merged into a few
## meshes per material and area. Per vertex:
##   COLOR   = albedo rgb, emission in alpha
##   UV2     = (wet gloss, indoor fill light)
##   CUSTOM0 = ink line push direction (xyz) and line weight (w)
## Options for every primitive: rot (degrees) or basis, emit, gloss, lit,
## line (ink weight, 0 = none), mat (material name), node (parent to merge into),
## indoor (render layer 2, lit only by the shop lights).

const TOON := preload("res://shaders/konbini_toon.gdshader")
const OUTLINE := preload("res://shaders/konbini_outline.gdshader")
const FONT := preload("res://assets/fonts/Sarabun-Regular.ttf")
const CELL := 6.0
const LAYER_OUT := 1
const LAYER_IN := 2

class Batch:
	var node: Node3D
	var layer := 1
	var material: Material
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv2 := PackedVector2Array()
	var push := PackedFloat32Array()
	var indices := PackedInt32Array()

var root: Node3D
var materials := {}
var outline: ShaderMaterial
var primitive_count := 0
var _batches := {}
var _shapes := {}

func _init(parent: Node3D) -> void:
	root = parent
	outline = ShaderMaterial.new()
	outline.shader = OUTLINE

func material(name: String, pattern := 0, params := {}) -> ShaderMaterial:
	if materials.has(name):
		return materials[name]
	var mat := ShaderMaterial.new()
	mat.shader = TOON
	mat.set_shader_parameter("pattern", pattern)
	for key in params:
		mat.set_shader_parameter(key, params[key])
	mat.next_pass = outline
	materials[name] = mat
	return mat

# --- primitives ---------------------------------------------------------------

func box(center: Vector3, size: Vector3, color: Color, opts := {}) -> void:
	add("box", _xf(center, size, opts), color, opts)

## Box given by its two opposite corners, for ground slabs and walls.
func slab(from: Vector3, to: Vector3, color: Color, opts := {}) -> void:
	box((from + to) * 0.5, (to - from).abs(), color, opts)

func cyl(center: Vector3, radius: float, height: float, color: Color, opts := {}) -> void:
	var key := "cyl:%d:%.2f" % [opts.get("seg", 12), opts.get("top", 1.0)]
	add(key, _xf(center, Vector3(radius * 2.0, height, radius * 2.0), opts), color, opts)

## Cylinder from a to b, for poles, rails, pipes and wires.
func rod(a: Vector3, b: Vector3, radius: float, color: Color, opts := {}) -> void:
	var d := b - a
	if d.length() < 0.0001:
		return
	var o := opts.duplicate()
	o["basis"] = aim(d)
	if not o.has("seg"):
		o["seg"] = 6
	cyl((a + b) * 0.5, radius, d.length(), color, o)

func ball(center: Vector3, radius: Vector3, color: Color, opts := {}) -> void:
	add("ball:%d" % opts.get("seg", 10), _xf(center, radius * 2.0, opts), color, opts)

func prism(center: Vector3, size: Vector3, color: Color, opts := {}) -> void:
	add("prism", _xf(center, size, opts), color, opts)

## Ring lying in the XZ plane (bike tyres when rotated, mirror rims).
func torus(center: Vector3, ring: float, tube: float, color: Color, opts := {}) -> void:
	var outer := ring + tube
	add("torus:%.3f" % ((ring - tube) / outer * 0.5), _xf(center, Vector3.ONE * outer * 2.0, opts), color, opts)

## Flat quad facing +Y (decals, floor stickers). No ink line.
func quad(center: Vector3, size: Vector2, color: Color, opts := {}) -> void:
	var o := opts.duplicate()
	o["line"] = 0.0
	add("quad", _xf(center, Vector3(size.x, 1.0, size.y), o), color, o)

func text(value: String, pos: Vector3, height: float, color: Color, opts := {}) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.font = FONT
	label.font_size = 64
	label.pixel_size = height / 64.0
	label.modulate = color
	label.outline_size = opts.get("outline", 0)
	label.outline_modulate = opts.get("outline_color", color)
	label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	label.shaded = false
	label.double_sided = false
	label.position = pos
	label.rotation_degrees = opts.get("rot", Vector3.ZERO)
	label.layers = LAYER_IN if opts.get("indoor", false) else LAYER_OUT
	if opts.has("width"):
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.width = opts["width"] / label.pixel_size
	opts.get("node", root).add_child(label)
	return label

# --- helpers -------------------------------------------------------------------

## Basis whose Y axis points along dir.
static func aim(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var helper := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(helper).normalized()
	return Basis(x, y, x.cross(y))

func _xf(center: Vector3, scale: Vector3, opts: Dictionary) -> Transform3D:
	var basis := Basis.IDENTITY
	if opts.has("basis"):
		basis = opts["basis"]
	elif opts.has("rot"):
		basis = Basis.from_euler(opts["rot"] * (PI / 180.0))
	return Transform3D(basis * Basis.from_scale(scale), center)

func add(kind: String, xf: Transform3D, color: Color, opts := {}) -> void:
	var shape: Dictionary = _shape(kind)
	var target: Node3D = opts.get("node", root)
	var layer := LAYER_IN if opts.get("indoor", false) else LAYER_OUT
	var mat_name: String = opts.get("mat", "toon")
	var key := "%s|%d|%d" % [mat_name, layer, target.get_instance_id()]
	if target == root:
		key += "|%d|%d" % [floori((xf.origin.x + 9.0) / CELL), floori((xf.origin.z + 9.0) / CELL)]
	var b: Batch = _batches.get(key)
	if b == null:
		b = Batch.new()
		b.node = target
		b.layer = layer
		b.material = material(mat_name)
		_batches[key] = b
	var normal_basis := xf.basis.inverse().transposed()
	var turn := xf.basis.orthonormalized()
	var c := Color(color.r, color.g, color.b, opts.get("emit", 0.0))
	var uv := Vector2(opts.get("gloss", 0.0), opts.get("lit", 0.0))
	var line: float = opts.get("line", 1.0)
	var verts: PackedVector3Array = shape["v"]
	var normals: PackedVector3Array = shape["n"]
	var push: PackedVector3Array = shape["p"]
	var base := b.verts.size()
	for i in verts.size():
		b.verts.append(xf * verts[i])
		b.normals.append((normal_basis * normals[i]).normalized())
		b.colors.append(c)
		b.uv2.append(uv)
		var p := turn * push[i]
		b.push.append_array([p.x, p.y, p.z, line])
	for i in shape["i"]:
		b.indices.append(base + i)
	primitive_count += 1

func _shape(kind: String) -> Dictionary:
	if _shapes.has(kind):
		return _shapes[kind]
	var parts := kind.split(":")
	var mesh: PrimitiveMesh
	match parts[0]:
		"box":
			mesh = BoxMesh.new()
		"cyl":
			var cylinder := CylinderMesh.new()
			cylinder.radial_segments = int(parts[1])
			cylinder.rings = 0
			cylinder.height = 1.0
			cylinder.bottom_radius = 0.5
			cylinder.top_radius = 0.5 * float(parts[2])
			mesh = cylinder
		"ball":
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			sphere.radial_segments = int(parts[1])
			sphere.rings = maxi(int(parts[1]) / 2, 3)
			mesh = sphere
		"prism":
			mesh = PrismMesh.new()
		"torus":
			var ring := TorusMesh.new()
			ring.inner_radius = float(parts[1])
			ring.outer_radius = 0.5
			ring.rings = 18
			ring.ring_segments = 8
			mesh = ring
		"quad":
			var plane := PlaneMesh.new()
			plane.size = Vector2.ONE
			mesh = plane
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var push := PackedVector3Array()
	for i in verts.size():
		var v := verts[i]
		match parts[0]:
			"box":
				push.append(Vector3(signf(v.x), signf(v.y), signf(v.z)))
			"cyl":
				var r := Vector2(v.x, v.z)
				var radial := r.normalized() if r.length() > 0.0001 else Vector2.ZERO
				push.append(Vector3(radial.x, signf(v.y), radial.y))
			"prism":
				var d := Vector2(v.x, v.y + 1.0 / 6.0).normalized() * 1.2
				push.append(Vector3(d.x, d.y, signf(v.z)))
			"quad":
				push.append(Vector3.ZERO)
			_:
				push.append(normals[i])
	var shape := {"v": verts, "n": normals, "i": arrays[Mesh.ARRAY_INDEX], "p": push}
	_shapes[kind] = shape
	return shape

## Turns every batch into a MeshInstance3D under its node. Call once after building.
func finish() -> void:
	for key in _batches:
		var b: Batch = _batches[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = b.verts
		arrays[Mesh.ARRAY_NORMAL] = b.normals
		arrays[Mesh.ARRAY_COLOR] = b.colors
		arrays[Mesh.ARRAY_TEX_UV2] = b.uv2
		arrays[Mesh.ARRAY_CUSTOM0] = b.push
		arrays[Mesh.ARRAY_INDEX] = b.indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		mesh.surface_set_material(0, b.material)
		var instance := MeshInstance3D.new()
		instance.name = "Merged"
		instance.mesh = mesh
		instance.layers = b.layer
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.node.add_child(instance)
	_batches.clear()
