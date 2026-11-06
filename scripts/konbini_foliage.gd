extends RefCounted
## Anime trees, simple but pretty (shaders/konbini_foliage.gdshader). A crown is a few
## clump blobs, each covered in camera-facing leaf cards cut into scalloped leaf
## clusters, lit with spherized normals in three flat tones. Trunks and branches use the
## toon kit so they get the ink line like everything else.
##   broadleaf(k, scene, base, size)  round deciduous tree (zelkova, cherry in leaf)
##   pine(k, scene, base, size)       Japanese black pine with flat needle pads

const Kit := preload("res://scripts/konbini_kit.gd")
const FOLIAGE := preload("res://shaders/konbini_foliage.gdshader")

const BARK := Color(0.4, 0.3, 0.25)

## The sun direction the foliage is lit from (toward the sun), from a light's rotation.
static func sun_from(rotation_degrees: Vector3) -> Vector3:
	return Basis.from_euler(rotation_degrees * (PI / 180.0)).z

## One crown: clumps is an array of [centre, radii]. Returns the MeshInstance3D.
static func crown(scene: Node3D, centre: Vector3, clumps: Array, opts := {}) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = opts.get("seed", 1)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	var idx := PackedInt32Array()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var sa := sphere.get_mesh_arrays()
	var sv: PackedVector3Array = sa[Mesh.ARRAY_VERTEX]
	var si: PackedInt32Array = sa[Mesh.ARRAY_INDEX]
	var leaf: float = opts.get("leaf", 0.3)
	var density: float = opts.get("density", 34.0)
	for cl in clumps:
		var c: Vector3 = cl[0]
		var r: Vector3 = cl[1]
		var s := rng.randf()
		# the body: a slightly shrunk blob so no gap shows between the cards
		var base := verts.size()
		for v in sv:
			verts.append(c + v * r * 0.86)
			normals.append(v)
			uvs.append(Vector2.ZERO)
			c0.append_array([c.x, c.y, c.z, 0.0])
			c1.append_array([centre.x, centre.y, centre.z, s])
		for i in si:
			idx.append(base + i)
		# leaf cards over its surface
		var count := int(clampf(density * (r.x * r.z + r.y * (r.x + r.z) * 0.5), 8.0, 90.0))
		for n in count:
			var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.7, 1), rng.randf_range(-1, 1)).normalized()
			var p := c + d * r * rng.randf_range(0.82, 1.02)
			var size := leaf * rng.randf_range(0.75, 1.2)
			var cs := rng.randf()
			base = verts.size()
			for uv in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				verts.append(p)
				normals.append(d)
				uvs.append(uv)
				c0.append_array([c.x, c.y, c.z, size])
				c1.append_array([centre.x, centre.y, centre.z, cs])
			idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_CUSTOM0] = c0
	arrays[Mesh.ARRAY_CUSTOM1] = c1
	arrays[Mesh.ARRAY_INDEX] = idx
	var fmt := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, fmt)
	# the cards are moved in the shader, so give the culling box room for them
	mesh.custom_aabb = mesh.get_aabb().grow(leaf * 1.5 + 0.3)
	var mat := ShaderMaterial.new()
	mat.shader = FOLIAGE
	for key in ["sun_dir", "high_col", "light_col", "mid_col", "shadow_col", "glow_col", "clump_mix", "brightness", "wind"]:
		if opts.has(key):
			mat.set_shader_parameter(key, opts[key])
	var mi := MeshInstance3D.new()
	mi.name = opts.get("name", "Crown")
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	scene.add_child(mi)
	return mi

## A round broadleaf tree: a short trunk forking into a few limbs, one big crown made of
## a central mass and smaller clumps around and below it.
static func broadleaf(k: Kit, scene: Node3D, base: Vector3, size := 1.0, opts := {}) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = opts.get("seed", 3)
	var h := 3.2 * size
	var fork := base + Vector3(0, h * 0.45, 0)
	k.cyl(base + Vector3(0, 0.1 * size, 0), 0.26 * size, 0.2 * size, BARK, {"top": 0.7, "seg": 8})
	k.rod(base, fork, 0.14 * size, BARK, {"seg": 8})
	var top := base + Vector3(0, h, 0)
	var clumps: Array = [[top, Vector3(1.25, 0.95, 1.15) * size]]
	var limbs := 5
	for i in limbs:
		var a := i * TAU / limbs + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0, sin(a))
		var tip := fork + out * rng.randf_range(0.8, 1.1) * size + Vector3(0, rng.randf_range(0.6, 1.3) * size, 0)
		k.rod(fork, tip, 0.07 * size, BARK, {"seg": 6})
		clumps.append([tip + out * 0.25 * size + Vector3(0, 0.15 * size, 0), Vector3(0.85, 0.7, 0.8) * size * rng.randf_range(0.85, 1.1)])
	k.rod(fork, top - Vector3(0, 0.4 * size, 0), 0.09 * size, BARK, {"seg": 6})
	var o := opts.duplicate()
	o["leaf"] = opts.get("leaf", 0.32 * size)
	o["seed"] = opts.get("seed", 3)
	crown(scene, top - Vector3(0, 0.45 * size, 0), clumps, o)

## A Japanese black pine: a leaning, bending trunk, long branches and flat needle pads,
## each pad lit on its own (high clump_mix) so they read as separate layers.
static func pine(k: Kit, scene: Node3D, base: Vector3, size := 1.0, opts := {}) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = opts.get("seed", 5)
	var lean: float = opts.get("lean", 0.4)
	var height := 4.4 * size
	var pts: Array[Vector3] = [base]
	for i in range(1, 6):
		var t := i / 5.0
		pts.append(base + Vector3(lean * t * t * 2.0 + sin(t * 5.0 + base.x) * 0.2 * size, height * t, 0.5 * t * t * size))
	k.cyl(base + Vector3(0, 0.12, 0), 0.24 * size, 0.24, Color(0.36, 0.27, 0.23), {"top": 0.62, "seg": 8})
	for i in 5:
		k.rod(pts[i], pts[i + 1], lerpf(0.15, 0.07, i / 4.0) * size, Color(0.36, 0.27, 0.23), {"seg": 8})
	var clumps: Array = []
	for j in 4:
		var at: Vector3 = pts[2 + j % 3].lerp(pts[3 + j % 3], rng.randf_range(0.2, 0.8))
		var a := rng.randf_range(0.0, TAU)
		var length := rng.randf_range(0.8, 1.4) * size
		var tip := at + Vector3(cos(a) * length, rng.randf_range(0.15, 0.4) * size, sin(a) * length * 0.7)
		k.rod(at, tip, 0.05 * size, Color(0.36, 0.27, 0.23), {"seg": 6})
		clumps.append([tip, Vector3(0.85, 0.26, 0.7) * size * rng.randf_range(0.75, 1.0)])
	clumps.append([pts[5] + Vector3(0, 0.1, 0), Vector3(1.0, 0.3, 0.8) * size])
	var o := opts.duplicate()
	o["leaf"] = opts.get("leaf", 0.2 * size)
	o["clump_mix"] = opts.get("clump_mix", 0.85)
	o["density"] = opts.get("density", 60.0)
	o["high_col"] = opts.get("high_col", Color(0.55, 0.78, 0.46))
	o["light_col"] = opts.get("light_col", Color(0.4, 0.66, 0.4))
	o["mid_col"] = opts.get("mid_col", Color(0.2, 0.44, 0.33))
	o["shadow_col"] = opts.get("shadow_col", Color(0.09, 0.24, 0.27))
	o["glow_col"] = opts.get("glow_col", Color(0.6, 0.8, 0.45))
	crown(scene, pts[4], clumps, o)
