extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/classroom_3d_pixel.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("HUD").visible = false
	var out := OS.get_environment("CAMPUS_REVIEW_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	for i in [0,1,3]:
		scene._set_shot(i)
		await _capture(scene,out.path_join("preset-%d.png" % i))
	# Cover the extremities of all four real window apertures, including
	# glancing views and the permitted pitch limits, not only a centre shot.
	for shot in [
		["front-left",-4.5,-75.0,0.0],
		["front-right",-4.5,75.0,0.0],
		["rear-left",4.5,-75.0,0.0],
		["rear-right",4.5,75.0,0.0],
		["window-up",-1.5,0.0,42.0],
		["window-down",-1.5,0.0,-48.0],
		["window-down-left",1.5,-50.0,-38.0],
		["window-down-right",1.5,50.0,-38.0],
		["pitch-limit-up",-1.5,0.0,63.0],
		["pitch-limit-down",-1.5,0.0,-63.0]
	]:
		scene.camera.position = Vector3(-4.68,1.8,shot[1])
		var yaw := deg_to_rad(float(shot[2]))
		var pitch := deg_to_rad(float(shot[3]))
		var direction := Vector3(-cos(pitch)*cos(yaw),sin(pitch),cos(pitch)*sin(yaw))
		scene.camera.look_at(scene.camera.position+direction)
		await _capture(scene,out.path_join(shot[0]+".png"))
	quit()

func _capture(scene: Node,path: String) -> void:
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = scene.viewport.get_texture().get_image()
	if not scene._has_scene_pixels(frame) or frame.save_png(path)!=OK:
		push_error("Coverage capture failed: "+path)
		quit(1)
		return
	print("WINDOW_COVERAGE ",path)
