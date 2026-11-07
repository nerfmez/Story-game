extends RefCounted
## Anime trees, simple but pretty (shaders/konbini_foliage.gdshader). A crown is a few
## clump blobs, each covered in camera-facing leaf cards cut into scalloped leaf
## clusters, lit with spherized normals in three flat tones. Trunks and branches use the
## toon kit so they get the ink line like everything else.
##   broadleaf(k, scene, base, size)  round deciduous tree (zelkova, cherry in leaf)
##   pine(k, scene, base, size)       Japanese black pine with flat needle pads

const Kit := preload("res://scripts/konbini_kit.gd")
const FOLIAGE := preload("res://shaders/konbini_foliage.gdshader")


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

# --- trunks ------------------------------------------------------------------------
# Trunks, limbs and roots are smooth swept tubes collected into one mesh per tree and
# painted by shaders/konbini_bark.gdshader, with the kit's ink outline as next pass.

const BARK_SHADER := preload("res://shaders/konbini_bark.gdshader")
const OUTLINE := preload("res://shaders/konbini_outline.gdshader")

## Catmull-Rom through pts, `steps` points per segment, for smooth bends.
static func smooth(pts: Array, steps := 4) -> Array:
	var out: Array = []
	var n := pts.size()
	for i in n - 1:
		var p0: Vector3 = pts[maxi(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(i + 2, n - 1)]
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[n - 1])
	return out

## Adds a tube through pts to the bark mesh data in `m`: radius from r0 to r1 along
## its length, shade (crown shade) from s0 to s1, ink weight `line`.
static func tube(m: Dictionary, pts: Array, r0: float, r1: float, s0: float, s1: float, line := 1.0, sides := 9, flare := 0.0) -> void:
	var path := smooth(pts)
	var n := path.size()
	var ground: float = m.get("ground", -100.0)
	var u := Vector3.ZERO
	var base: int = m["v"].size()
	for i in n:
		var p: Vector3 = path[i]
		var t: Vector3 = ((path[mini(i + 1, n - 1)] as Vector3) - (path[maxi(i - 1, 0)] as Vector3)).normalized()
		var carried := u - t * u.dot(t)
		if i == 0 or carried.length() < 0.001:
			# start a frame (or restart one when the path turns onto the old side vector)
			u = t.cross(Vector3.FORWARD if absf(t.y) > 0.9 else Vector3.UP).normalized()
		else:
			u = carried.normalized()
		var v := t.cross(u)
		var f := float(i) / (n - 1)
		var r := lerpf(r0, r1, f)
		if flare > 0.0:   # the foot of a trunk widens smoothly into the ground
			r *= 1.0 + flare * exp(-maxf(p.y - (pts[0] as Vector3).y, 0.0) / (r0 * 2.4))
		var sh := lerpf(s0, s1, f)
		for k in sides + 1:
			var a := TAU * k / sides
			var d := u * cos(a) + v * sin(a)
			m["v"].append(p + d * r)
			m["n"].append(d)
			# no ink where the tube goes into the ground (it would draw a dark ring there)
			# (never exactly 0: the outline shader collapses weight-0 vertices to the origin)
			var w := maxf(line * clampf((p.y - ground) / 0.12, 0.0, 1.0), 0.002)
			m["c0"].append_array([d.x, d.y, d.z, w])
			m["c1"].append_array([sh, 0.0, 0.0, 0.0])
	for i in n - 1:
		for k in sides:
			var a0 := base + i * (sides + 1) + k
			var b0 := a0 + sides + 1
			m["i"].append_array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1])

static func bark_data() -> Dictionary:
	return {"v": PackedVector3Array(), "n": PackedVector3Array(), "c0": PackedFloat32Array(), "c1": PackedFloat32Array(), "i": PackedInt32Array()}

## Turns the collected tubes into a mesh instance with the bark look.
static func bark_mesh(scene: Node3D, m: Dictionary, sun: Vector3, colors: Dictionary, name := "Bark") -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = m["v"]
	arrays[Mesh.ARRAY_NORMAL] = m["n"]
	var cols := PackedColorArray()
	cols.resize((m["v"] as PackedVector3Array).size())
	cols.fill(colors.get("mid_col", Color(0.47, 0.34, 0.28)))
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_CUSTOM0] = m["c0"]
	arrays[Mesh.ARRAY_CUSTOM1] = m["c1"]
	arrays[Mesh.ARRAY_INDEX] = m["i"]
	var fmt := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, fmt)
	var mat := ShaderMaterial.new()
	mat.shader = BARK_SHADER
	mat.set_shader_parameter("sun_dir", sun)
	for key in colors:
		mat.set_shader_parameter(key, colors[key])
	var ink := ShaderMaterial.new()
	ink.shader = OUTLINE
	mat.next_pass = ink
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	scene.add_child(mi)
	return mi

## A trunk through pts with a flared foot and a few short buttress roots that sink into
## the ground. shade_from: the height (0..1 along the trunk) where the crown shade starts.
static func trunk(m: Dictionary, pts: Array, r0: float, r1: float, rng: RandomNumberGenerator, shade_from := 0.55) -> void:
	var base: Vector3 = pts[0]
	m["ground"] = base.y
	# one tube from just under the ground, flaring at the foot, so there is no seam;
	# extra points low down so the flare curves smoothly
	var up: Vector3 = (pts[1] as Vector3) - base
	var full: Array = [base + Vector3(0, -0.08, 0), base + up * 0.12, base + up * 0.3]
	full.append_array(pts.slice(1))
	tube(m, full, r0, r1, 0.0, 1.0, 1.0, 11, 0.8)
	# a few buttress roots: low ridges that start up on the flare and sink into the ground
	var roots := 3 + rng.randi() % 2
	for i in roots:
		var a := i * TAU / roots + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(a), 0, sin(a))
		var reach := rng.randf_range(1.8, 2.3) * r0
		tube(m, [base + out * r0 * 0.3 + Vector3(0, r0 * 1.5, 0), base + out * r0 * 1.0 + Vector3(0, r0 * 0.55, 0), base + out * reach * 0.8 + Vector3(0, r0 * 0.05, 0), base + out * reach + Vector3(0, -0.08, 0)], r0 * 0.5, r0 * 0.18, 0.0, 0.0, 0.6, 7)
	m["shade_from"] = shade_from

## A limb from a through mid points to b, thinning from r0 to r1, in crown shade.
static func limb(m: Dictionary, pts: Array, r0: float, r1: float, line := 1.0) -> void:
	tube(m, pts, r0, r1, 0.8, 1.0, line, 7)

## A round broadleaf tree: a gently bending trunk with a flared, rooted foot that forks
## into curving limbs, each limb carrying a clump of the crown.
static func broadleaf(k: Kit, scene: Node3D, base: Vector3, size := 1.0, opts := {}) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = opts.get("seed", 3)
	var h := 3.2 * size
	var fork_h := h * 0.48
	var bend := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.2, 0.2)) * size
	var pts: Array = []
	for i in 4:
		var t := i / 3.0
		pts.append(base + Vector3(0, fork_h * t, 0) + bend * sin(t * PI * 0.9))
	var m := bark_data()
	trunk(m, pts, 0.19 * size, 0.14 * size, rng)
	var fork: Vector3 = pts[3]
	var top := base + Vector3(0, h, 0)
	var clumps: Array = [[top, Vector3(1.25, 0.95, 1.15) * size]]
	var limbs := 5
	for i in limbs:
		var a := i * TAU / limbs + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0, sin(a))
		var tip := fork + out * rng.randf_range(0.8, 1.1) * size + Vector3(0, rng.randf_range(0.6, 1.3) * size, 0)
		var start := fork + Vector3(0, -0.15 * size, 0) + out * 0.03 * size
		var d := tip - start
		var mid := start + Vector3(d.x * 0.35, d.y * 0.6, d.z * 0.35)
		limb(m, [start, mid, tip], 0.1 * size, 0.035 * size)
		var twig := mid + (out.rotated(Vector3.UP, rng.randf_range(-0.9, 0.9)) * 0.45 + Vector3(0, 0.35, 0)) * size
		limb(m, [mid, mid.lerp(twig, 0.5) + Vector3(0, 0.05, 0), twig], 0.035 * size, 0.012 * size, 0.5)
		clumps.append([tip + out * 0.25 * size + Vector3(0, 0.15 * size, 0), Vector3(0.85, 0.7, 0.8) * size * rng.randf_range(0.85, 1.1)])
	limb(m, [fork + Vector3(0, -0.1 * size, 0), fork + Vector3(0.05, 0.5, 0) * size, top - Vector3(0, 0.4 * size, 0)], 0.12 * size, 0.05 * size)
	var sun: Vector3 = opts.get("sun_dir", Vector3(0.45, 0.72, 0.53))
	bark_mesh(scene, m, sun, opts.get("bark", {}))
	var o := opts.duplicate()
	o.erase("bark")
	o["leaf"] = opts.get("leaf", 0.32 * size)
	o["seed"] = opts.get("seed", 3)
	crown(scene, top - Vector3(0, 0.45 * size, 0), clumps, o)

## A Japanese black pine: a leaning, bending trunk with a rooted foot, long branches
## that dip and rise again, and flat needle pads, each pad lit on its own (high
## clump_mix) so they read as separate layers.
static func pine(k: Kit, scene: Node3D, base: Vector3, size := 1.0, opts := {}) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = opts.get("seed", 5)
	var lean: float = opts.get("lean", 0.4)
	var height := 4.4 * size
	var pts: Array = []
	for i in 7:
		var t := i / 6.0
		pts.append(base + Vector3(lean * t * t * 2.0 + sin(t * 5.0 + base.x) * 0.2 * size, height * t, 0.5 * t * t * size))
	var m := bark_data()
	trunk(m, pts, 0.17 * size, 0.06 * size, rng)
	var clumps: Array = []
	for j in 4:
		var at: Vector3 = (pts[2 + j % 4] as Vector3).lerp(pts[3 + j % 4], rng.randf_range(0.2, 0.8))
		var a := rng.randf_range(0.0, TAU)
		var length := rng.randf_range(0.8, 1.4) * size
		var out := Vector3(cos(a), 0, sin(a) * 0.7)
		var tip := at + out * length + Vector3(0, rng.randf_range(0.15, 0.4) * size, 0)
		# pine limbs droop a little and lift again toward the pad
		limb(m, [at, at + out * length * 0.45 + Vector3(0, -0.08 * size, 0), tip], 0.065 * size, 0.022 * size)
		clumps.append([tip, Vector3(0.85, 0.26, 0.7) * size * rng.randf_range(0.75, 1.0)])
	clumps.append([pts[6] + Vector3(0, 0.1, 0), Vector3(1.0, 0.3, 0.8) * size])
	var sun: Vector3 = opts.get("sun_dir", Vector3(0.45, 0.72, 0.53))
	var bark: Dictionary = opts.get("bark", {"light_col": Color(0.62, 0.52, 0.45), "mid_col": Color(0.42, 0.34, 0.31), "shadow_col": Color(0.24, 0.2, 0.24)})
	bark_mesh(scene, m, sun, bark)
	var o := opts.duplicate()
	o.erase("bark")
	o["leaf"] = opts.get("leaf", 0.2 * size)
	o["clump_mix"] = opts.get("clump_mix", 0.85)
	o["density"] = opts.get("density", 60.0)
	o["high_col"] = opts.get("high_col", Color(0.55, 0.78, 0.46))
	o["light_col"] = opts.get("light_col", Color(0.4, 0.66, 0.4))
	o["mid_col"] = opts.get("mid_col", Color(0.2, 0.44, 0.33))
	o["shadow_col"] = opts.get("shadow_col", Color(0.09, 0.24, 0.27))
	o["glow_col"] = opts.get("glow_col", Color(0.6, 0.8, 0.45))
	crown(scene, pts[5], clumps, o)
