extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/classroom_3d_pixel.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("HUD").visible = false
	var out := OS.get_environment("CLASSROOM_STUDENTS_OUT")
	if out.is_empty(): out = ProjectSettings.globalize_path("user://classroom-students")
	DirAccess.make_dir_recursive_absolute(out)
	for shot in [
		["rear", Vector3(0.35,1.82,5.65), Vector3(0.25,1.42,-4.8)],
		["front", Vector3(0.1,1.7,-4.1), Vector3(-0.3,1.0,3.2)],
		["diagonal", Vector3(4.45,2.05,4.6), Vector3(-0.65,1.25,-0.4)],
		["leads-front", Vector3(-4.1,1.5,-0.6), Vector3(-4.05,0.85,3.2)],
		["leads-side", Vector3(-1.9,1.4,2.5), Vector3(-4.05,0.75,2.5)],
		["seating-overview", Vector3(0,3.15,5.6), Vector3(-0.1,0.45,-0.3)]
	]:
		scene.camera.position = shot[1]
		scene.camera.look_at(shot[2])
		for i in 6: await process_frame
		await RenderingServer.frame_post_draw
		var frame: Image = scene.viewport.get_texture().get_image()
		assert(scene._has_scene_pixels(frame), "Blank classroom render")
		assert(frame.save_png(out.path_join(shot[0]+".png")) == OK)
		print("STUDENTS_CAPTURE ", shot[0])
	quit()
