extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/classroom_3d_pixel.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var result := _count(scene)
	if result.x > 300 or scene.get_meta("interior_part_count", 0) < 900 or result.y != scene.get_meta("interior_part_count",0):
		push_error("Web instance budget or visible part count failed: %s" % result)
		quit(1)
		return
	if scene.fan_rotors.size() != 2:
		push_error("Missing independent ceiling-fan rotors")
		quit(1)
		return
	scene.set_process(false)
	for rotor in scene.fan_rotors:
		var angle: float = rotor.rotation.y
		var stem: Transform3D = rotor.get_parent().transform
		if rotor.get_child_count()!=3:
			push_error("Fan blades lost to static batching")
			quit(1)
			return
		scene._animate_fans(0.1)
		if absf(angle_difference(angle,rotor.rotation.y))<0.4 or rotor.get_parent().transform!=stem:
			push_error("Fan fails to rotate independently of fixed stem")
			quit(1)
			return
	var room = scene.get_node("View/SubViewport/Room")
	var environment: Environment = room.get_node("Lighting/MorningEnvironment").environment
	if environment.background_mode != Environment.BG_SKY or environment.sky == null or not environment.sky.sky_material is PanoramaSkyMaterial or room.get_node_or_null("OutsideWindow/PaintedSchoolCourtyard") != null:
		push_error("The courtyard must cover every viewing direction, without finite card edges")
		quit(1)
		return
	var clock = room.get_node("TeachingArea/WallClock")
	if clock.position.x-0.24 <= 0.45+6.8/2:
		push_error("Clock overlaps board bounds")
		quit(1)
		return
	var frame := Image.create(640,360,false,Image.FORMAT_RGB8)
	frame.fill(Color("a2b4c5"))
	if scene._has_scene_pixels(frame):
		push_error("Blank environment frame was accepted as ready")
		quit(1)
		return
	for y in range(120,240):
		for x in range(100,500): frame.set_pixel(x,y,Color("224b42"))
	if not scene._has_scene_pixels(frame):
		push_error("Nonblank scene frame was rejected")
		quit(1)
		return
	print("PASS: ",result.x," render instances preserve all ",result.y," parts; blank frames cannot report ready")
	quit(0)

func _count(node: Node) -> Vector2i:
	var total := Vector2i.ZERO
	if node is Sprite3D:
		total += Vector2i(1,0)
	if node is MeshInstance3D:
		total += Vector2i(1,1)
	if node is MultiMeshInstance3D:
		var transforms: Array = node.get_meta("instance_transforms",[])
		if transforms.size() != node.multimesh.instance_count:
			push_error("Batch transforms were lost in scene serialization")
			quit(1)
		for transform: Transform3D in transforms:
			if not transform.is_finite() or absf(transform.basis.determinant()) < 0.5:
				push_error("Invalid instance transform")
				quit(1)
		if node.multimesh.custom_aabb.size.length() <= 0.0:
			push_error("Empty MultiMesh culling bounds")
			quit(1)
		total += Vector2i(1,node.multimesh.instance_count)
	for child in node.get_children(): total += _count(child)
	return total
