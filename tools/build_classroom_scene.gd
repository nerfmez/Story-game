extends SceneTree
## Run with Godot 4.3 --headless --path . --script tools/build_classroom_scene.gd
## Bakes a native 3D scene, with repeated static parts instanced in MultiMeshes.

var scene: Control
var room: Node3D
var mats: Dictionary = {}
var meshes: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	rng.seed = 431915
	scene = Control.new()
	scene.name = "ClassroomPixel"
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene.set_script(load("res://scripts/classroom_pixel.gd"))
	var view := Node.new()
	view.name = "View"
	scene.add_child(view)
	var viewport := SubViewport.new()
	viewport.name = "SubViewport"
	view.add_child(viewport)
	viewport.size = Vector2i(480, 270)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.positional_shadow_atlas_size = 1024
	# TextureRect presents a fixed low-resolution viewport. No interpolation.
	var image := TextureRect.new()
	image.name = "PixelOutput"
	scene.add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var viewport_texture := ViewportTexture.new()
	viewport_texture.resource_local_to_scene = true
	viewport_texture.viewport_path = NodePath("View/SubViewport")
	image.texture = viewport_texture
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room = Node3D.new()
	room.name = "Room"
	viewport.add_child(room)
	_materials()
	_architecture()
	_windows()
	_classroom_front()
	_furniture()
	_lived_in_details()
	_ceiling()
	scene.set_meta("interior_part_count", _geometry_count(room))
	_outdoors()
	_lighting()
	_batch_static_parts()
	_seated_students()
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.position = Vector3(0.35, 1.95, 5.65)
	cam.fov = 51.0
	cam.near = 0.05
	cam.current = true
	room.add_child(cam)
	_hud()
	_own(scene)
	var packed := PackedScene.new()
	var result := packed.pack(scene)
	if result != OK:
		push_error("Cannot pack classroom: %d" % result)
		quit(1)
		return
	result = ResourceSaver.save(packed, "res://scenes/classroom_3d_pixel.tscn")
	print("CLASSROOM_BAKED ", result, " meshes=", meshes.size(), " nodes=", _count(scene))
	scene.free()
	quit(0 if result == OK else 1)

func _own(node: Node) -> void:
	for child in node.get_children():
		child.owner = scene
		_own(child)

func _count(node: Node) -> int:
	var total := 1
	for child in node.get_children(): total += _count(child)
	return total

func _group(name: String, parent: Node = null) -> Node3D:
	var node := Node3D.new()
	node.name = name
	(parent if parent != null else room).add_child(node)
	return node

func _material(key: String, color: String, tex: String = "", emission: float = 0.0) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color)
	mat.roughness = 0.86
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not tex.is_empty():
		mat.albedo_texture = load("res://assets/classroom/" + tex + ".png")
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3.ONE * 1.5
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = Color(color)
		mat.emission_energy_multiplier = emission
	mats[key] = mat

func _materials() -> void:
	_material("plaster", "d0d1c6", "plaster")
	_material("lower", "929eaa", "plaster")
	_material("trim", "50677e")
	_material("frame", "3c546b")
	_material("metal", "3f4e59")
	_material("wood", "c49250", "wood")
	_material("wood_light", "d7a566", "wood")
	_material("wood_dark", "9f713b", "wood")
	_material("floor", "a9b4bc", "terrazzo")
	_material("grout", "929fa9")
	_material("board", "244c48", "chalkboard")
	_material("chalk", "deddd0")
	_material("ceiling", "b6c0c6", "plaster")
	_material("lamp", "fff1cc", "", 1.1)
	_material("lamp_case", "75818e")
	_material("paper", "d9d4b9")
	_material("paper_blue", "99b5c9")
	_material("paper_coral", "bd9b85")
	_material("cork", "816d4f")
	_material("glass", "99b5c1")
	_material("corridor_glass", "8da4b1", "window")
	_material("bag", "26394f")
	_material("curtain", "b9c3bf", "plaster")
	_material("leaf", "4f7168")
	_material("leaf_light", "739576")
	_material("leaf_dark", "365969")
	_material("bark", "5d6464")
	_material("outside", "8396a6")
	_material("silver", "8d9eab")
	# Painted albedo carries the small details; meshes retain real depth and
	# perspective when the player walks or turns. Pixelation happens at output.
	for key in ["wood", "wood_light", "wood_dark"]:
		mats[key].albedo_texture = load("res://assets/classroom/painted-wood.png")
		mats[key].uv1_triplanar = false
		mats[key].uv1_scale = Vector3.ONE
		mats[key].albedo_color = Color({"wood":"f1e4ce", "wood_light":"fff2db", "wood_dark":"c7b69d"}[key])
		mats[key].emission_enabled = true
		mats[key].emission_texture = mats[key].albedo_texture
		mats[key].emission = Color("fff1dc")
		mats[key].emission_energy_multiplier = 0.12
	_material("notebook", "e7e3d2")
	_material("ink", "678494")
	_material("cover", "677f85")
	_material("pencil", "ce9853")
	_material("rubber", "303e49")
	_material("cloth", "c8d5d7")
	mats["cloth"].cull_mode = BaseMaterial3D.CULL_DISABLED
	_material("bottle", "6c99a0")
	_material("bottle_cap", "d3dcda")
	_material("plant_pot", "a47f69")
	var shadow := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, cull_disabled, depth_draw_never; void fragment(){ float d=length((UV-vec2(0.5))*vec2(1.0,1.0)); ALBEDO=vec3(0.08,0.13,0.17); ALPHA=(1.0-smoothstep(0.12,0.5,d))*0.20; }"
	shadow.shader = shader
	mats["contact"] = shadow
	# Quiet variations instead of high-contrast noise on every surface.
	mats["plaster"].albedo_color = Color("e4e3d5")
	mats["lower"].albedo_color = Color("9caeb6")
	mats["floor"].albedo_color = Color("b5c1c4")
	mats["ceiling"].albedo_color = Color("c3ced0")
	mats["curtain"].albedo_color = Color("c7d4d2")
	mats["grout"].albedo_color = Color("a1afb4")

func _panel(parent: Node3D, name: String, size: Vector2, pos: Vector3, mat: Material, rotation_y: float = 0.0) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.rotation.y = rotation_y
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func _picture_material(path: String, unlit: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(path)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if unlit: mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _contact(parent: Node3D, pos: Vector3, size: Vector2) -> void:
	var card := _panel(parent, "SoftContactShadow", size, pos, mats["contact"])
	card.rotation.x = -PI / 2.0

func _curtain(parent: Node3D, z: float) -> void:
	# Continuous folded cloth, not a row of rectangular blocks.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 8:
		for col in 16:
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var u: float = (col + corner.x) / 16.0
				var v: float = (row + corner.y) / 8.0
				st.set_uv(Vector2(u,v))
				st.add_vertex(Vector3(-5.02 + sin(u * TAU * 3.0) * (0.025 + 0.025 * v), 3.06 - v * (1.87 + sin(u * PI) * 0.04), z + (u - 0.5) * 0.55))
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "FoldedFabricCurtain"
	node.mesh = st.commit()
	node.material_override = mats["cloth"]
	parent.add_child(node)

func _box(parent: Node3D, name: String, size: Vector3, pos: Vector3, material: String) -> MeshInstance3D:
	var key := str(size) + material
	if not meshes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh.material = mats[material]
		meshes[key] = mesh
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = meshes[key]
	instance.position = pos
	parent.add_child(instance)
	return instance

func _desk_surface(parent: Node3D, name: String, size: Vector3, pos: Vector3, material: String) -> void:
	# A continuous wooden slab, with lightly chamfered corners and an edge
	# catching the light. Proper top-face UVs show the whole painted grain.
	var key := "chamfer" + str(size) + material
	if not meshes.has(key):
		var w := size.x * 0.5
		var h := size.y * 0.5
		var d := size.z * 0.5
		var c := 0.035
		var points := [Vector2(-w+c,-d),Vector2(w-c,-d),Vector2(w,-d+c),Vector2(w,d-c),Vector2(w-c,d),Vector2(-w+c,d),Vector2(-w,d-c),Vector2(-w,-d+c)]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 8:
			var p: Vector2 = points[i]
			var q: Vector2 = points[(i+1)%8]
			for v in [Vector3(0,h,0),Vector3(q.x*0.985,h,q.y*0.985),Vector3(p.x*0.985,h,p.y*0.985)]:
				st.set_uv(Vector2(v.x/size.x+0.5,v.z/size.z+0.5))
				st.add_vertex(v)
			for v in [Vector3(0,-h,0),Vector3(p.x,-h,p.y),Vector3(q.x,-h,q.y)]:
				st.set_uv(Vector2(v.x/size.x+0.5,v.z/size.z+0.5))
				st.add_vertex(v)
			for pair in [[h,h-0.007], [h-0.007,-h]]:
				var scale_top := 0.985 if pair[0] == h else 1.0
				var scale_bottom := 1.0
				var a := Vector3(p.x*scale_top,pair[0],p.y*scale_top)
				var b := Vector3(q.x*scale_top,pair[0],q.y*scale_top)
				var cc := Vector3(p.x*scale_bottom,pair[1],p.y*scale_bottom)
				var dd := Vector3(q.x*scale_bottom,pair[1],q.y*scale_bottom)
				for v in [a,b,cc,b,dd,cc]:
					st.set_uv(Vector2(v.x/size.x+0.5,v.z/size.z+0.5))
					st.add_vertex(v)
		st.generate_normals()
		var mesh := st.commit()
		mesh.surface_set_material(0,mats[material])
		meshes[key] = mesh
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = meshes[key]
	instance.position = pos
	parent.add_child(instance)

func _tube(parent: Node3D, name: String, a: Vector3, b: Vector3, radius: float, material: String) -> MeshInstance3D:
	var key := "tube:%.6f:%.6f:%s" % [radius,a.distance_to(b),material]
	if not meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = a.distance_to(b)
		mesh.radial_segments = 8
		mesh.material = mats[material]
		meshes[key] = mesh
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = meshes[key]
	instance.position = (a + b) * 0.5
	instance.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	parent.add_child(instance)
	return instance

func _batch_static_parts() -> void:
	# Godot 4.3 Web/Compatibility can fail to render an oversized instance
	# list on mobile. Keep the exact meshes, textures, positions and shadows,
	# but submit repeated desks/legs/window parts with instanced draws.
	var groups: Dictionary = {}
	_gather_meshes(room,groups)
	var parent := _group("StaticBatches")
	var before := 0
	var after := 0
	for nodes: Array in groups.values():
		before += nodes.size()
		if nodes.size() < 3:
			after += nodes.size()
			continue
		var source: MeshInstance3D = nodes[0]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = source.mesh
		mm.instance_count = nodes.size()
		var bounds := AABB()
		var transforms: Array[Transform3D] = []
		for i in nodes.size():
			var node: MeshInstance3D = nodes[i]
			var transform := Transform3D.IDENTITY
			var cursor: Node = node
			while cursor != room:
				if cursor is Node3D: transform = cursor.transform * transform
				cursor = cursor.get_parent()
			mm.set_instance_transform(i,transform)
			transforms.append(transform)
			var box: AABB = transform * node.mesh.get_aabb()
			bounds = box if i == 0 else bounds.merge(box)
		mm.custom_aabb = bounds.grow(0.01)
		var batch := MultiMeshInstance3D.new()
		batch.name = "Batch%03d_%s" % [after,source.name]
		batch.multimesh = mm
		batch.material_override = source.material_override
		batch.cast_shadow = source.cast_shadow
		# Keep an ordinary serializable CPU copy: the headless dummy renderer
		# cannot return GPU MultiMesh buffers while baking/exporting a scene.
		batch.set_meta("instance_transforms",transforms)
		parent.add_child(batch)
		for node: MeshInstance3D in nodes: node.free()
		after += 1
	print("CLASSROOM_BATCHED instances=",before," -> ",after," (same visible parts)")
	if after > 300:
		push_error("Classroom exceeded the web render-instance budget")
		quit(1)

func _gather_meshes(parent: Node, groups: Dictionary) -> void:
	for node in parent.get_children():
		if node.get_meta("animated_rotor", false): continue
		if node is MeshInstance3D:
			var key := "%d:%d:%d" % [node.mesh.get_instance_id(),node.material_override.get_instance_id() if node.material_override else 0,node.cast_shadow]
			if not groups.has(key): groups[key] = []
			groups[key].append(node)
		_gather_meshes(node,groups)

func _architecture() -> void:
	var a := _group("Architecture")
	_box(a, "TerrazzoFloor", Vector3(10.8, 0.16, 12.0), Vector3(0, -0.08, 0), "floor")
	for x in range(-9, 10):
		_box(a, "FloorJointX", Vector3(0.012, 0.002, 12), Vector3(x * 0.6, 0.002, 0), "grout")
	for z in range(-10, 11):
		_box(a, "FloorJointZ", Vector3(10.8, 0.002, 0.012), Vector3(0, 0.002, z * 0.6), "grout")
	_box(a, "FrontWall", Vector3(10.8, 3.6, 0.18), Vector3(0, 1.8, -6), "plaster")
	_box(a, "FrontDado", Vector3(10.8, 0.85, 0.025), Vector3(0, 0.425, -5.9), "lower")
	_box(a, "RearWall", Vector3(10.8, 3.6, 0.18), Vector3(0, 1.8, 6), "plaster")
	_box(a, "CorridorLowerWall", Vector3(0.18,1.12,12), Vector3(5.4,0.56,0), "plaster")
	_box(a, "CorridorUpperWall", Vector3(0.18,0.88,12), Vector3(5.4,3.16,0), "plaster")
	for span in [Vector2(-6,-2.52),Vector2(-0.28,0.28),Vector2(2.52,3.03),Vector2(5.27,6)]:
		_box(a,"CorridorWindowPier",Vector3(0.18,1.60,span.y-span.x),Vector3(5.4,1.92,(span.x+span.y)/2),"plaster")
	# A real open corridor behind the new panes gives them depth.
	_box(a,"CorridorFloor",Vector3(2.1,0.14,12),Vector3(6.45,-0.07,0),"floor")
	_box(a,"CorridorRoof",Vector3(2.2,0.14,12),Vector3(6.45,3.6,0),"ceiling")
	_box(a,"CorridorParapet",Vector3(0.16,1.05,12),Vector3(7.45,0.525,0),"plaster")
	for z in [-5.8,0,5.8]:
		_box(a,"CorridorColumn",Vector3(0.2,3.6,0.2),Vector3(7.45,1.8,z),"plaster")
	_box(a, "RightDado", Vector3(0.03, 0.85, 12), Vector3(5.29, 0.425, 0), "lower")
	_box(a, "LeftWindowSillWall", Vector3(0.18, 0.95, 12), Vector3(-5.4, 0.475, 0), "plaster")
	_box(a, "LeftUpperWall", Vector3(0.18, 0.48, 12), Vector3(-5.4, 3.36, 0), "plaster")
	for z in [-5.9, -3.0, 0.0, 3.0, 5.9]:
		_box(a, "WindowPier", Vector3(0.26, 2.3, 0.2), Vector3(-5.32, 2.05, z), "plaster")
	_box(a, "LeftDado", Vector3(0.025, 0.85, 12), Vector3(-5.29, 0.425, 0), "lower")
	_box(a, "Ceiling", Vector3(10.8, 0.12, 12), Vector3(0, 3.66, 0), "ceiling")
	for z in [-5.8, -2, 2, 5.8]:
		_box(a, "Beam", Vector3(10.8, 0.13, 0.17), Vector3(0, 3.51, z), "ceiling")
	for x in [-5.25, 5.25]:
		_box(a, "Skirting", Vector3(0.04, 0.13, 12), Vector3(x, 0.065, 0), "frame")

func _sliding_window(parent: Node3D, name: String, center: Vector3, width: float, height: float, opened: bool) -> void:
	var w := _group(name, parent)
	w.position = center
	# Slim painted aluminium frames, two sliding leaves and a fixed transom.
	for edge in [-1.0,1.0]:
		_box(w,"OuterJamb",Vector3(0.10,height,0.055),Vector3(0,0,edge*(width/2-0.028)),"frame")
		_box(w,"OuterTrack",Vector3(0.13,0.055,width),Vector3(0,edge*(height/2-0.028),0),"frame")
	var transom_y := height/2-0.34
	_box(w,"TransomRail",Vector3(0.075,0.035,width),Vector3(0,transom_y,0),"silver")
	_box(w,"TransomGlass",Vector3(0.012,0.27,width-0.11),Vector3(0,transom_y+0.15,0),"clear_glass").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var leaf_h := height-0.43
	for leaf in 2:
		var pane := _group("SlidingLeaf%d" % leaf,w)
		pane.position = Vector3((leaf-0.5)*0.035,-0.17,(-width/4 if leaf==0 else width/4)-(width*0.29 if opened and leaf==1 else 0.0))
		for edge in [-1.0,1.0]:
			_box(pane,"LeafStile",Vector3(0.035,leaf_h,0.032),Vector3(0,0,edge*(width/4-0.025)),"silver")
			_box(pane,"LeafRail",Vector3(0.035,0.032,width/2-0.025),Vector3(0,edge*(leaf_h/2-0.016),0),"silver")
		_box(pane,"ClearPane",Vector3(0.009,leaf_h-0.065,width/2-0.10),Vector3.ZERO,"clear_glass").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_box(pane,"RecessedHandle",Vector3(0.045,0.15,0.035),Vector3(-0.03,0,(1 if leaf==0 else -1)*(width/4-0.06)),"frame")
	_box(w,"ProjectingSill",Vector3(0.25,0.055,width+0.10),Vector3(0,-height/2-0.015,0),"silver")

func _windows() -> void:
	var a := _group("WindowsAndDoor")
	var glass: StandardMaterial3D = mats["glass"].duplicate()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.69,0.82,0.86,0.08)
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats["clear_glass"] = glass
	for bay in 4:
		var z: float = -4.5 + bay*3.0
		_sliding_window(a,"CourtyardWindow%d" % bay,Vector3(-5.27,2.04,z),2.76,2.12,bay%2==0)
		_tube(a,"CurtainRail",Vector3(-5.05,3.16,z-1.32),Vector3(-5.05,3.16,z+1.32),0.015,"silver")
		_curtain(a,z+1.05)
	for z in [-1.4,1.4,4.15]:
		_sliding_window(a,"CorridorWindow",Vector3(5.27,1.92,z),2.24,1.60,true)
	_box(a,"DoorFrame",Vector3(0.12,2.58,1.08),Vector3(5.22,1.29,-4.65),"frame")
	_box(a,"DoorLeaf",Vector3(0.13,2.42,0.91),Vector3(5.15,1.21,-4.65),"trim")
	_box(a,"DoorVisionGlass",Vector3(0.14,0.83,0.18),Vector3(5.11,1.8,-4.65),"glass")
	_tube(a,"DoorHandle",Vector3(5.02,0.95,-4.37),Vector3(5.02,1.18,-4.37),0.025,"silver")

func _classroom_front() -> void:
	var a := _group("TeachingArea")
	_box(a, "BoardFrame", Vector3(6.8, 1.65, 0.09), Vector3(0.45, 2.02, -5.84), "frame")
	_box(a, "GreenChalkboard", Vector3(6.62, 1.47, 0.035), Vector3(0.45, 2.02, -5.77), "board")
	_panel(a, "PaintedChalkAndErasure", Vector2(6.60,1.45), Vector3(0.45,2.02,-5.747), _picture_material("res://assets/classroom/painted-board.png"))
	# Larger chalk strokes remain legible after pixel-camera minification;
	# the painted image underneath supplies the erasure and hand-worked surface.
	var chalk_paths := [
		[Vector2(-2.70,1.61),Vector2(-2.13,2.53),Vector2(-1.45,1.61),Vector2(-2.70,1.61)],
		[Vector2(-0.85,1.61),Vector2(0.90,1.61)],
		[Vector2(-0.64,1.50),Vector2(-0.64,2.57)]
	]
	var curve: Array[Vector2] = []
	for i in 13:
		var u := i / 12.0
		curve.append(Vector2(-0.61+u*1.34,1.65+sqrt(u)*0.74))
	chalk_paths.append(curve)
	for path in chalk_paths:
		for i in path.size()-1:
			var p: Vector2 = path[i]
			var q: Vector2 = path[i+1]
			var stroke := _tube(a,"ChalkDiagram",Vector3(p.x,p.y,-5.729),Vector3(q.x,q.y,-5.729),0.011,"chalk")
			stroke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var math := Label3D.new()
	math.name = "ChalkEquation"
	math.text = "x + y = 12\nx = 12 − y"
	math.font = load("res://assets/fonts/Sarabun-Regular.ttf")
	math.font_size = 72
	math.pixel_size = 0.003
	math.position = Vector3(2.20,2.12,-5.727)
	math.modulate = Color("bdcbc5")
	math.outline_size = 0
	a.add_child(math)
	_box(a, "ChalkTray", Vector3(6.75, 0.045, 0.18), Vector3(0.45, 1.19, -5.69), "silver")
	for i in 3:
		_box(a, "Chalk", Vector3(0.09, 0.02, 0.025), Vector3(-1.8 + i * 0.14, 1.22, -5.66), "chalk")
	_box(a, "Eraser", Vector3(0.21, 0.06, 0.08), Vector3(2.85, 1.25, -5.66), "wood_dark")
	# Open wooden bookcase: side panels and a recessed back, never a solid box.
	var shelf := _group("OpenBookcase",a)
	shelf.position = Vector3(-4.65,0,-5.54)
	_box(shelf,"RecessedBack",Vector3(1.02,1.71,0.035),Vector3(0,0.94,-0.185),"wood_dark")
	for x in [-0.49,0.49]:
		_box(shelf,"SidePanel",Vector3(0.055,1.82,0.40),Vector3(x,0.94,0),"wood")
	for y in [0.09,0.52,0.95,1.38,1.83]:
		_box(shelf,"ShelfBoard",Vector3(1.04,0.045,0.42),Vector3(0,y,0),"wood")
	for level in 3:
		var x := -0.40
		for i in (7 if level!=1 else 4):
			var h := 0.26+(i%3)*0.035
			var cover: String = ["paper_blue","cover","paper_coral","wood_dark"][ (i+level)%4 ]
			_box(shelf,"BookSpine",Vector3(0.055,h,0.23),Vector3(x,0.545+level*0.43+h/2,0.04),cover)
			_box(shelf,"SpineLabel",Vector3(0.038,0.027,0.003),Vector3(x,0.61+level*0.43,0.157),"paper")
			x += 0.065
	for i in 3:
		_box(shelf,"StackedWorkbook",Vector3(0.27,0.035,0.24),Vector3(0.24,1.0+i*0.04,0.04),"paper_blue" if i%2 else "paper")
	_box(shelf,"LowerStorageBox",Vector3(0.34,0.27,0.28),Vector3(0.19,0.25,0.015),"cover")
	_box(shelf,"BoxLabel",Vector3(0.16,0.07,0.004),Vector3(0.19,0.25,0.157),"paper")
	_box(a, "NoticeFrame", Vector3(1.0, 1.48, 0.07), Vector3(-3.60, 2.03, -5.82), "wood_dark")
	_box(a, "NoticeCork", Vector3(0.9, 1.38, 0.05), Vector3(-3.60, 2.03, -5.77), "cork")
	for i in 5:
		_box(a, "NoticePaper", Vector3(0.3, 0.38, 0.01), Vector3(-3.83 + (i % 2) * 0.45, 2.48 - (i / 2) * 0.42, -5.73), "paper_blue" if i % 2 else "paper")
	var clock_group := _group("WallClock",a)
	clock_group.position = Vector3(4.47,2.98,-5.77)
	var clock_mesh := CylinderMesh.new()
	clock_mesh.top_radius = 0.24
	clock_mesh.bottom_radius = 0.24
	clock_mesh.height = 0.04
	clock_mesh.radial_segments = 32
	clock_mesh.material = mats["paper"]
	var clock := MeshInstance3D.new()
	clock.name = "Clock"
	clock.mesh = clock_mesh
	clock.rotation.x = PI / 2.0
	clock.position = Vector3.ZERO
	clock_group.add_child(clock)
	for i in 12:
		var angle := i * TAU / 12.0
		_box(clock_group, "ClockTick", Vector3(0.018, 0.028, 0.015), Vector3(sin(angle) * 0.19, cos(angle) * 0.19, 0.04), "frame")
	_box(clock_group, "HourHand", Vector3(0.015, 0.13, 0.025), Vector3(-0.01, 0.05, 0.07), "frame").rotation.z = -0.3
	_box(clock_group, "MinuteHand", Vector3(0.16, 0.012, 0.025), Vector3(0.07, 0.0, 0.07), "frame")
	_box(a, "Speaker", Vector3(0.36, 0.38, 0.14), Vector3(-0.2, 3.05, -5.77), "frame")
	for i in 5:
		_box(a, "SpeakerGrille", Vector3(0.27,0.012,0.01), Vector3(-0.2,2.94+i*0.05,-5.69), "metal")
	# Staff table and chair, facing the class.
	_desk_surface(a, "TeacherTableTop", Vector3(1.5, 0.08, 0.72), Vector3(0.6, 0.79, -4.7), "wood")
	_box(a, "TeacherTableFront", Vector3(1.4, 0.63, 0.07), Vector3(0.6, 0.4, -4.31), "lower")
	for x in [-0.05, 1.25]:
		_box(a, "TeacherTableLeg", Vector3(0.06, 0.75, 0.06), Vector3(x, 0.375, -4.95), "metal")
	_box(a, "TeacherChairBack", Vector3(0.44, 0.34, 0.06), Vector3(0.6, 0.78, -5.25), "frame")
	# Student work on the rear wall keeps the reverse camera useful as well.
	_box(a, "RearNoticeFrame", Vector3(4.8, 1.35, 0.08), Vector3(0.0, 2.0, 5.85), "wood_dark")
	_box(a, "RearNoticeBoard", Vector3(4.64, 1.18, 0.04), Vector3(0.0, 2.0, 5.79), "board")
	_panel(a,"PaintedStudentScienceDisplay",Vector2(4.62,1.16),Vector3(0,2,5.764),_picture_material("res://assets/classroom/painted-notice.png"),PI)

func _desk(parent: Node3D, index: int, x: float, z: float) -> void:
	var d := _group("Desk%02d" % index, parent)
	d.position = Vector3(x, 0, z)
	d.rotation.y = (index % 5 - 2) * 0.006
	var wood := "wood_light" if index % 7 == 0 else ("wood_dark" if index % 9 == 0 else "wood")
	_desk_surface(d, "DeskTop", Vector3(0.85, 0.055, 0.58), Vector3(0, 0.76, 0), wood)
	_box(d, "DeskRim", Vector3(0.86, 0.022, 0.59), Vector3(0, 0.724, 0), "wood_dark")
	_box(d, "StorageShelf", Vector3(0.69, 0.025, 0.38), Vector3(0, 0.57, 0), "metal")
	_contact(d, Vector3(0,0.008,0.25), Vector2(1.3,1.6))
	for lx in [-0.34, 0.34]:
		for lz in [-0.21, 0.21]:
			_tube(d, "DeskLeg", Vector3(lx, 0.02, lz), Vector3(lx, 0.72, lz), 0.017, "metal")
			_box(d, "RubberFoot", Vector3(0.042,0.035,0.042), Vector3(lx,0.02,lz), "rubber")
		_tube(d, "DeskSideBrace", Vector3(lx, 0.22, -0.21), Vector3(lx, 0.22, 0.21), 0.013, "metal")
	var c := _group("Chair", d)
	c.position.z = 0.52 + (0.09 if index % 8 == 0 else 0.0)
	c.rotation.y = 0.08 if index % 11 == 0 else 0.0
	_box(c, "Seat", Vector3(0.41, 0.045, 0.39), Vector3(0, 0.435, 0), wood)
	_box(c, "BackBoard", Vector3(0.41, 0.25, 0.035), Vector3(0, 0.72, 0.17), wood)
	for lx in [-0.17, 0.17]:
		_tube(c, "RearLegAndBack", Vector3(lx, 0.015, 0.17), Vector3(lx, 0.86, 0.17), 0.016, "metal")
		_tube(c, "FrontLeg", Vector3(lx, 0.015, -0.15), Vector3(lx, 0.44, -0.15), 0.016, "metal")
		_tube(c, "SeatBrace", Vector3(lx, 0.41, -0.15), Vector3(lx, 0.41, 0.17), 0.014, "metal")
	if index in [4, 17, 28]:
		_box(c, "SchoolBag", Vector3(0.3, 0.36, 0.13), Vector3(0.08, 0.32, 0.28), "bag")
		_tube(c, "BagHandle", Vector3(-0.02, 0.49, 0.28), Vector3(-0.02, 0.7, 0.2), 0.012, "bag")
		_box(c,"BagFrontPocket",Vector3(0.24,0.18,0.025),Vector3(0.08,0.26,0.357),"frame")
		_box(c,"BagZip",Vector3(0.22,0.008,0.01),Vector3(0.08,0.35,0.375),"silver")
	if index in [2,5,9,13,19,24,27,29]:
		_notebook(d, Vector3(-0.07,0.795,-0.02), index % 3 == 0)
		_tube(d,"Pencil",Vector3(0.19,0.805,-0.08),Vector3(0.26,0.805,0.10),0.006,"pencil")
	if index in [8,18,25]:
		_box(d,"PencilCase",Vector3(0.22,0.055,0.08),Vector3(0.17,0.815,-0.12),"cover")
		_box(d,"CaseZip",Vector3(0.20,0.003,0.008),Vector3(0.17,0.845,-0.12),"silver")
	if index in [5,19]:
		_tube(d,"WaterBottle",Vector3(0.28,0.80,-0.13),Vector3(0.28,1.02,-0.13),0.037,"bottle")
		_tube(d,"BottleCap",Vector3(0.28,1.02,-0.13),Vector3(0.28,1.05,-0.13),0.028,"bottle_cap")

func _notebook(parent: Node3D, pos: Vector3, open: bool) -> void:
	var a := _group("StudentNotebook",parent)
	a.position = pos
	a.rotation.y = -0.12
	_box(a,"Cover",Vector3(0.33 if open else 0.18,0.008,0.24),Vector3.ZERO,"cover")
	_box(a,"PaperBlock",Vector3(0.32 if open else 0.17,0.009,0.23),Vector3(0,0.008,0),"notebook")
	if open:
		_box(a,"CenterFold",Vector3(0.003,0.001,0.23),Vector3(0,0.014,0),"cover")
		for i in 7:
			for x in [-0.08,0.08]:
				_box(a,"WrittenLine",Vector3(0.095-(i%3)*0.013,0.001,0.002),Vector3(x,0.014,-0.075+i*0.022),"ink")
	else:
		_box(a,"FrontCover",Vector3(0.18,0.002,0.24),Vector3(0,0.014,0),"cover")
		_box(a,"NameLabel",Vector3(0.10,0.001,0.045),Vector3(0,0.016,-0.045),"notebook")

func _lived_in_details() -> void:
	var a := _group("RoomDetails")
	_notebook(a,Vector3(0.75,0.84,-4.65),true)
	for i in 3:
		_box(a,"TeacherBooks",Vector3(0.29,0.025,0.22),Vector3(0.13,0.85+i*0.027,-4.62),["cover","paper_coral","paper_blue"][i])
	_contact(a,Vector3(0.6,0.009,-4.6),Vector2(2.0,1.4))
	# Three real-dimensional cupboard doors, hooks and stored umbrellas.
	for x in [-1.0,0.0,1.0]:
		_box(a,"RearStorageCabinet",Vector3(0.88,0.78,0.37),Vector3(x,0.39,5.58),"lower")
		_box(a,"CabinetDoor",Vector3(0.81,0.65,0.025),Vector3(x,0.4,5.37),"ceiling")
		_box(a,"CabinetPull",Vector3(0.13,0.02,0.025),Vector3(x,0.65,5.34),"frame")
	_box(a,"UmbrellaStand",Vector3(0.36,0.46,0.32),Vector3(4.72,0.23,-5.4),"frame")
	for i in 3:
		var umbrella := _box(a,"FoldedUmbrella",Vector3(0.055,0.59,0.055),Vector3(4.63+i*0.08,0.65,-5.4),["bag","paper_coral","cover"][i])
		umbrella.rotation.z = (i-1)*0.10
		_tube(a,"UmbrellaHandle",Vector3(4.63+i*0.08,0.94,-5.4),Vector3(4.63+i*0.08,1.04,-5.4),0.014,"wood_dark")
	var label := Label3D.new()
	label.name = "RoomNumber"
	label.text = "ม.4 / 5"
	label.font = load("res://assets/fonts/Sarabun-Regular.ttf")
	label.font_size = 64
	label.pixel_size = 0.004
	label.position = Vector3(1.5,3.13,-5.88)
	label.modulate = Color("526975")
	label.outline_size = 0
	a.add_child(label)

func _furniture() -> void:
	var a := _group("StudentDesks")
	var index := 1
	for row in 5:
		for x in [-4.05, -2.8, -0.8, 0.45, 2.45, 3.7]:
			_desk(a, index, x, -2.9 + row * 1.42)
			index += 1

func _seated_students() -> void:
	var students := _group("SeatedStudents")
	students.set_script(load("res://scripts/classroom_students.gd"))
	var textures: Dictionary = {}
	for id in ["sun", "saifon", "boy_short", "boy_glasses", "girl_bob", "girl_ponytail"]:
		textures[id] = load("res://assets/classroom/students/" + id + ".png")
	var variants := ["boy_short", "girl_bob", "boy_glasses", "girl_ponytail"]
	for row in 5:
		for column in 6:
			var index := row * 6 + column + 1
			var desk: Node3D = room.get_node("StudentDesks/Desk%02d" % index)
			var chair: Node3D = desk.get_node("Chair")
			var id: String = variants[(column + row * 3) % variants.size()]
			if column == 0 and row == 4: id = "saifon"
			if column == 0 and row == 3: id = "sun"
			var student := Sprite3D.new()
			student.name = "Seat%02d_%s" % [index, id]
			student.texture = textures[id]
			student.hframes = 4
			student.pixel_size = 1.28 / 180.0
			student.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			student.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			student.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			student.alpha_scissor_threshold = 0.5
			student.no_depth_test = false
			student.shaded = false
			student.double_sided = true
			student.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			student.set_meta("seat", index)
			student.set_meta("row", row)
			student.set_meta("column", column)
			student.set_meta("character", id)
			student.set_meta("mirror_left", id == "girl_bob")
			# Match each chair's pulled-out offset and slight rotation exactly.
			student.transform = desk.transform * chair.transform
			student.position += Vector3(0, (184.0 - 96.0) * student.pixel_size + 0.025, 0)
			students.add_child(student)

func _ceiling() -> void:
	var a := _group("CeilingFixtures")
	for z in [-3.8, 0.0, 3.8]:
		for x in [-2.65, 2.65]:
			_box(a, "FluorescentHousing", Vector3(1.5, 0.09, 0.25), Vector3(x, 3.4, z), "lamp_case")
			_box(a, "LightDiffuser", Vector3(1.35, 0.025, 0.16), Vector3(x, 3.345, z), "lamp")
	for z in [-2.2, 2.2]:
		var fan := _group("CeilingFan", a)
		fan.position = Vector3(0, 3.1, z)
		_tube(fan, "Stem", Vector3(0, 0, 0), Vector3(0, 0.45, 0), 0.035, "metal")
		_tube(fan, "Motor", Vector3(0, -0.03, 0), Vector3(0, 0.06, 0), 0.14, "metal")
		var rotor := _group("Rotor",fan)
		rotor.set_meta("animated_rotor",true)
		rotor.set_meta("speed",TAU*(1.05 if z<0 else 0.97))
		rotor.rotation.y = z*0.6
		for i in 3:
			var blade := _group("Blade", rotor)
			blade.rotation.y = i * TAU / 3 + 0.25
			_box(blade, "BladeMesh", Vector3(0.65, 0.025, 0.14), Vector3(0.42, 0, 0), "silver")

func _geometry_count(node: Node) -> int:
	var total := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		total += _geometry_count(child)
	return total

func _outdoors() -> void:
	# The expanded spherical background in _lighting covers every visible ray.
	# A finite scenic card leaves holes when looking sideways or downward.
	_group("OutsideWindow")

func _lighting() -> void:
	var a := _group("Lighting")
	var env_node := WorldEnvironment.new()
	env_node.name = "MorningEnvironment"
	var env := Environment.new()
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = load("res://assets/classroom/courtyard-surround.png")
	panorama.filter = false
	var sky := Sky.new()
	sky.sky_material = panorama
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Align the panorama's central courtyard with the classroom's left windows.
	env.sky_rotation = Vector3(0,-PI/2.0,0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b4c3d0")
	env.ambient_light_energy = 0.64
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env_node.environment = env
	a.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.name = "OvercastWindowLight"
	sun.rotation_degrees = Vector3(-42, -62, 0)
	sun.light_color = Color("c6d7e5")
	sun.light_energy = 0.52
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 24
	sun.shadow_bias = 0.04
	a.add_child(sun)
	for z in [-3.8, 0.0, 3.8]:
		var light := OmniLight3D.new()
		light.name = "CeilingFill"
		light.position = Vector3(0, 3.1, z)
		light.light_color = Color("fff0d3")
		light.light_energy = 0.42
		light.omni_range = 6.8
		a.add_child(light)
	for z in [-3.0,3.0]:
		var light := OmniLight3D.new()
		light.name = "SoftWindowBounce"
		light.position = Vector3(-4.5,2.3,z)
		light.light_color = Color("c6deea")
		light.light_energy = 0.32
		light.omni_range = 6.0
		a.add_child(light)

func _hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	scene.add_child(hud)
	var status := Label.new()
	status.name = "Status"
	status.position = Vector2(14, 12)
	status.add_theme_color_override("font_color", Color("f1eee0"))
	status.add_theme_color_override("font_shadow_color", Color("142435"))
	status.add_theme_constant_override("shadow_offset_x", 1)
	status.add_theme_constant_override("shadow_offset_y", 1)
	status.add_theme_font_size_override("font_size", 14)
	hud.add_child(status)
