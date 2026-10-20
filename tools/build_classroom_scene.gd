extends SceneTree
## Run with Godot 4.3 --headless --path . --script tools/build_classroom_scene.gd
## Bakes an editable scene: all visible classroom objects are real MeshInstance3D.

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
	_ceiling()
	_outdoors()
	_lighting()
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
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
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
	_material("bag", "26394f")
	_material("curtain", "b9c3bf", "plaster")
	_material("leaf", "4f7168")
	_material("leaf_light", "739576")
	_material("leaf_dark", "365969")
	_material("bark", "5d6464")
	_material("outside", "8396a6")
	_material("silver", "8d9eab")

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

func _tube(parent: Node3D, name: String, a: Vector3, b: Vector3, radius: float, material: String) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 8
	mesh.material = mats[material]
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	instance.position = (a + b) * 0.5
	instance.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	parent.add_child(instance)
	return instance

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
	# Corridor wall with real openings for its three windows (glass y 1.3-2.7), so the corridor shows through.
	_box(a, "RightWallLower", Vector3(0.18, 1.3, 12), Vector3(5.4, 0.65, 0), "plaster")
	_box(a, "RightWallUpper", Vector3(0.18, 0.9, 12), Vector3(5.4, 3.15, 0), "plaster")
	for span in [[-6.0, -2.475], [-0.325, 0.325], [2.475, 3.075], [5.225, 6.0]]:
		var length: float = span[1] - span[0]
		_box(a, "RightWallPier", Vector3(0.18, 1.4, length), Vector3(5.4, 2.0, (span[0] + span[1]) * 0.5), "plaster")
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

func _windows() -> void:
	var a := _group("WindowsAndDoor")
	for bay in 4:
		var z: float = -4.5 + bay * 3.0
		_box(a, "WindowSill", Vector3(0.32, 0.07, 2.76), Vector3(-5.28, 0.98, z), "frame")
		_box(a, "WindowTop", Vector3(0.12, 0.06, 2.76), Vector3(-5.27, 3.1, z), "frame")
		for section in 3:
			var sz: float = z - 0.9 + section * 0.9
			_box(a, "WindowMullion", Vector3(0.1, 2.12, 0.04), Vector3(-5.25, 2.04, sz - 0.43), "frame")
			for slat in 7:
				var y: float = 1.13 + slat * 0.28
				var glass := _box(a, "LouverGlass", Vector3(0.018, 0.23, 0.82), Vector3(-5.31, y, sz), "glass")
				# Glass is mostly clear; geometry still shows its thickness at an angle.
				if not mats.has("clear_glass"):
					var g: StandardMaterial3D = mats["glass"].duplicate()
					g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					g.albedo_color.a = 0.14
					g.cull_mode = BaseMaterial3D.CULL_DISABLED
					mats["clear_glass"] = g
				glass.material_override = mats["clear_glass"]
				glass.rotation.z = -0.18 if bay % 2 == 0 else -0.38
				_box(a, "SlatEdge", Vector3(0.025, 0.018, 0.84), Vector3(-5.26, y - 0.11, sz), "frame")
		if bay == 0 or bay == 3:
			for fold in 5:
				_box(a, "CurtainFold", Vector3(0.06 + (fold % 2) * 0.04, 1.84, 0.11), Vector3(-5.05, 2.06, z + 0.85 + fold * 0.1), "curtain")
	# Right wall is on the open-corridor side of a Thai school.
	for z in [-1.4, 1.4, 4.15]:
		for y in [1.32, 2.68]:
			_box(a, "CorridorWindowFrame", Vector3(0.12, 0.08, 2.15), Vector3(5.3, y, z), "frame")
		for dz in [-1.035, 1.035]:
			_box(a, "CorridorWindowFrame", Vector3(0.12, 1.4, 0.08), Vector3(5.3, 2.0, z + dz), "frame")
		var pane := _box(a, "CorridorWindowGlass", Vector3(0.05, 1.24, 1.99), Vector3(5.24, 2.0, z), "glass")
		pane.material_override = mats["clear_glass"]
		for dz in [-0.68, 0.0, 0.68]:
			_box(a, "CorridorWindowDivider", Vector3(0.08, 1.35, 0.035), Vector3(5.18, 2.0, z + dz), "frame")
		for y in [1.62, 2.33]:
			_box(a, "CorridorWindowCrossbar", Vector3(0.08, 0.035, 2.08), Vector3(5.18, y, z), "frame")
	_box(a, "DoorFrame", Vector3(0.12, 2.58, 1.08), Vector3(5.22, 1.29, -4.65), "frame")
	_box(a, "DoorLeaf", Vector3(0.13, 2.42, 0.91), Vector3(5.15, 1.21, -4.65), "trim")
	_box(a, "DoorVisionGlass", Vector3(0.14, 0.83, 0.18), Vector3(5.11, 1.8, -4.65), "glass")
	_tube(a, "DoorHandle", Vector3(5.02, 0.95, -4.37), Vector3(5.02, 1.18, -4.37), 0.025, "silver")

func _classroom_front() -> void:
	var a := _group("TeachingArea")
	_box(a, "BoardFrame", Vector3(6.8, 1.65, 0.09), Vector3(0.45, 2.02, -5.84), "frame")
	_box(a, "GreenChalkboard", Vector3(6.62, 1.47, 0.035), Vector3(0.45, 2.02, -5.77), "board")
	_box(a, "ChalkTray", Vector3(6.75, 0.045, 0.18), Vector3(0.45, 1.19, -5.69), "silver")
	for i in 3:
		_box(a, "Chalk", Vector3(0.09, 0.02, 0.025), Vector3(-1.8 + i * 0.14, 1.22, -5.66), "chalk")
	_box(a, "Eraser", Vector3(0.21, 0.06, 0.08), Vector3(2.85, 1.25, -5.66), "wood_dark")
	# Narrow storage cabinet, noticeboard and a few paper shapes.
	_box(a, "Cabinet", Vector3(0.8, 1.7, 0.42), Vector3(-4.37, 0.85, -5.53), "lower")
	for y in [0.25, 0.7, 1.15, 1.6]:
		_box(a, "Shelf", Vector3(0.72, 0.035, 0.43), Vector3(-4.37, y, -5.5), "frame")
	for i in 12:
		_box(a, "Book", Vector3(0.04, 0.28 + (i % 3) * 0.03, 0.19), Vector3(-4.68 + i * 0.05, 1.3, -5.31), "paper_blue" if i % 2 == 0 else "wood_dark")
	_box(a, "NoticeFrame", Vector3(1.0, 1.48, 0.07), Vector3(-3.65, 2.03, -5.82), "wood_dark")
	_box(a, "NoticeCork", Vector3(0.9, 1.38, 0.05), Vector3(-3.65, 2.03, -5.77), "cork")
	for i in 5:
		_box(a, "NoticePaper", Vector3(0.3, 0.38, 0.01), Vector3(-3.88 + (i % 2) * 0.45, 2.48 - (i / 2) * 0.42, -5.73), "paper_blue" if i % 2 else "paper")
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
	clock.position = Vector3(3.5, 3.0, -5.77)
	a.add_child(clock)
	for i in 12:
		var angle := i * TAU / 12.0
		_box(a, "ClockTick", Vector3(0.018, 0.028, 0.015), Vector3(3.5 + sin(angle) * 0.19, 3.0 + cos(angle) * 0.19, -5.73), "frame")
	_box(a, "HourHand", Vector3(0.015, 0.13, 0.025), Vector3(3.49, 3.05, -5.70), "frame").rotation.z = -0.3
	_box(a, "MinuteHand", Vector3(0.16, 0.012, 0.025), Vector3(3.57, 3.0, -5.7), "frame")
	_box(a, "Speaker", Vector3(0.36, 0.38, 0.14), Vector3(-0.2, 3.05, -5.77), "frame")
	# Staff table and chair, facing the class.
	_box(a, "TeacherTableTop", Vector3(1.5, 0.08, 0.72), Vector3(0.6, 0.79, -4.7), "wood")
	_box(a, "TeacherTableFront", Vector3(1.4, 0.63, 0.07), Vector3(0.6, 0.4, -4.31), "lower")
	for x in [-0.05, 1.25]:
		_box(a, "TeacherTableLeg", Vector3(0.06, 0.75, 0.06), Vector3(x, 0.375, -4.95), "metal")
	_box(a, "TeacherChairBack", Vector3(0.44, 0.34, 0.06), Vector3(0.6, 0.78, -5.25), "frame")
	# Student work on the rear wall keeps the reverse camera useful as well.
	_box(a, "RearNoticeFrame", Vector3(4.8, 1.35, 0.08), Vector3(0.0, 2.0, 5.85), "wood_dark")
	_box(a, "RearNoticeBoard", Vector3(4.64, 1.18, 0.04), Vector3(0.0, 2.0, 5.79), "board")
	for i in 10:
		_box(a, "StudentWork", Vector3(0.55, 0.4, 0.02), Vector3(-1.8 + (i % 5) * 0.9, 2.28 - int(i / 5) * 0.55, 5.75), ["paper", "paper_blue", "paper_coral"][i % 3])

func _desk(parent: Node3D, index: int, x: float, z: float) -> void:
	var d := _group("Desk%02d" % index, parent)
	d.position = Vector3(x, 0, z)
	var wood := "wood_light" if index % 7 == 0 else ("wood_dark" if index % 9 == 0 else "wood")
	_box(d, "DeskTop", Vector3(0.85, 0.055, 0.58), Vector3(0, 0.76, 0), wood)
	_box(d, "DeskRim", Vector3(0.86, 0.022, 0.59), Vector3(0, 0.724, 0), "wood_dark")
	_box(d, "StorageShelf", Vector3(0.69, 0.025, 0.38), Vector3(0, 0.57, 0), "metal")
	for lx in [-0.34, 0.34]:
		for lz in [-0.21, 0.21]:
			_tube(d, "DeskLeg", Vector3(lx, 0.02, lz), Vector3(lx, 0.72, lz), 0.017, "metal")
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

func _furniture() -> void:
	var a := _group("StudentDesks")
	var index := 1
	for row in 5:
		for x in [-4.05, -2.8, -0.8, 0.45, 2.45, 3.7]:
			_desk(a, index, x, -2.9 + row * 1.42)
			index += 1

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
		for i in 3:
			var blade := _group("Blade", fan)
			blade.rotation.y = i * TAU / 3 + 0.25
			_box(blade, "BladeMesh", Vector3(0.65, 0.025, 0.14), Vector3(0.42, 0, 0), "silver")

## What the windows look out on: two views rendered from the school model (PR12,
## tools/render_classroom_views.gd), the classroom being a 2nd-floor room of its left wing. Each is a flat
## card CARD_DISTANCE from the room's middle, the size it was rendered at, so it lines up from there:
## over the corridor (parapet, pillars, the courtyard) on the right, behind the building on the left.
const CARD_DISTANCE := 9.4
const CARD_SIZE := Vector2(16.0, 7.0)
const CARD_EYE := 2.0

func _outdoors() -> void:
	var a := _group("OutsideWindow")
	for v in [["view_corridor", 1.0], ["view_back", -1.0]]:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = load("res://assets/classroom/" + str(v[0]) + ".png")
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		var quad := QuadMesh.new()
		quad.size = CARD_SIZE
		quad.material = mat
		var card := MeshInstance3D.new()
		card.name = "View" + str(v[0]).capitalize().replace(" ", "")
		card.mesh = quad
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var side: float = v[1]
		card.position = Vector3(side * CARD_DISTANCE, CARD_EYE, 0.0)
		card.rotation.y = -side * PI * 0.5                    # facing the room, its right edge on the viewer's right
		a.add_child(card)

func _lighting() -> void:
	var a := _group("Lighting")
	var env_node := WorldEnvironment.new()
	env_node.name = "MorningEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a2b4c5")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b4c3d0")
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env_node.environment = env
	a.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.name = "OvercastWindowLight"
	sun.rotation_degrees = Vector3(-42, -62, 0)
	sun.light_color = Color("c6d7e5")
	sun.light_energy = 0.38
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 24
	sun.shadow_bias = 0.04
	a.add_child(sun)
	for z in [-3.8, 0.0, 3.8]:
		var light := OmniLight3D.new()
		light.name = "CeilingFill"
		light.position = Vector3(0, 3.1, z)
		light.light_color = Color("fff0d3")
		light.light_energy = 0.5
		light.omni_range = 6.8
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
