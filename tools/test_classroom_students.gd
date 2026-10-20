extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/classroom_3d_pixel.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var room = scene.get_node("View/SubViewport/Room")
	var students = room.get_node("SeatedStudents")
	assert(students.get_child_count() == 30, "Each of the 30 chairs needs one occupant")
	var leads := {}
	for student in students.get_children():
		var seat: int = student.get_meta("seat")
		var chair = room.get_node("StudentDesks/Desk%02d/Chair" % seat)
		var error: Vector3 = student.global_position - chair.global_position
		assert(Vector2(error.x, error.z).length() < 0.001, "Student drifted away from their chair")
		assert(student.texture != null and student.hframes == 4)
		assert(student.texture.get_width() == 640 and student.texture.get_height() == 192)
		assert(student.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD and not student.no_depth_test, "Desks must occlude the seated body")
		var id: String = student.get_meta("character")
		if id in ["sun", "saifon"]:
			assert(not leads.has(id), "Duplicate lead")
			leads[id] = student
	assert(leads.saifon.get_meta("row") == 4 and leads.saifon.get_meta("column") == 0)
	assert(leads.sun.get_meta("row") == 3 and leads.sun.get_meta("column") == 0)
	assert(leads.sun.position.z < leads.saifon.position.z)
	var camera = room.get_node("Camera3D")
	var target = leads.saifon
	for sample in [[Vector3(0, 0, -3), 0], [Vector3(0, 0, 3), 1], [Vector3(-3, 0, 0), 2], [Vector3(3, 0, 0), 3]]:
		camera.global_position = target.global_position + sample[0]
		students._update_views()
		assert(target.frame == sample[1], "Wrong front/back/profile drawing")
	print("PASS: 30 seated occupants; unique leads at seats 25/19; chair anchors, depth occlusion and four viewing directions")
	quit()
