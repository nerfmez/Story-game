extends SceneTree
## Captures the actual game viewport; SCHOOL_REVIEW_OUT selects the directory.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var view = load("res://scripts/school_building_view.gd").new()
	root.add_child(view)
	var output := OS.get_environment("SCHOOL_REVIEW_OUT")
	if output.is_empty():
		output = ProjectSettings.globalize_path("user://school-review")
	DirAccess.make_dir_recursive_absolute(output)
	var shots := [
		["front", Vector3(4, 5.8, 39), Vector3(0, 4.5, 0), 60.0],
		["entrance", Vector3(0, 1.9, 9), Vector3(-0.5, 2.2, -3.0), 60.0],
		["angle", Vector3(26, 9, 18), Vector3(0, 4, -2), 60.0],
		["corridor", Vector3(4.4, 5.35, -1.25), Vector3(16, 5.05, -1.25), 65.0],
		["facade", Vector3(1, 5.4, 29), Vector3(0, 5.2, -1), 55.0],
		["yard", Vector3(11, 5.35, -0.4), Vector3(6, 0.6, 10), 60.0],
		["roof", Vector3(-25, 17, 23), Vector3(0, 7, -3), 60.0],
		["wall_ground", Vector3(-6.9, 1.9, -0.8), Vector3(-8.42, 1.9, -2.5), 65.0],
		["wall_2f", Vector3(-12.3, 5.35, -0.7), Vector3(-14, 5.15, -2.5), 65.0],
		["wall_3f", Vector3(15.5, 8.64, -0.8), Vector3(13.96, 8.64, -2.5), 65.0],
		["wall_hall", Vector3(1.4, 1.9, 0.8), Vector3(2.8, 1.9, -2.5), 65.0]
	]
	for shot in shots:
		view.camera.fov = shot[3]
		view.look(shot[1], shot[2])
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var frame: Image = view.get_child(0).get_texture().get_image()
		var path := output.path_join(str(shot[0]) + ".png")
		if frame.save_png(path) != OK:
			quit(1)
			return
		print("SCHOOL_REVIEW ", path)
	quit(0)
