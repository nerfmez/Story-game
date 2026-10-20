extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/classroom_3d_pixel.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("HUD").visible = false
	var out := OS.get_environment("CAMPUS_REVIEW_OUT")
	if out.is_empty(): out = ProjectSettings.globalize_path("user://classroom-review")
	DirAccess.make_dir_recursive_absolute(out)
	for i in scene.SHOTS.size():
		scene._set_shot(i)
		await _capture(scene,out.path_join("view-%d.png" % (i+1)))
	for shot in [
		["bookshelf",Vector3(-3.4,1.5,-3.1),Vector3(-4.55,1.10,-5.54)],
		["clock",Vector3(2.6,2.4,-2.9),Vector3(3.5,2.6,-5.8)],
		["corridor-window",Vector3(2.7,1.9,0),Vector3(5.3,1.92,1.4)],
		["courtyard-window",Vector3(-3.3,1.8,-3),Vector3(-8,1.65,-3)]
	]:
		scene.camera.position = shot[1]
		scene.camera.look_at(shot[2])
		await _capture(scene,out.path_join(shot[0]+".png"))
	# Deterministic consecutive frames, 1/12s apart, inspect actual rotor motion.
	scene.camera.position = Vector3(1.8,2.0,0.8)
	scene.camera.look_at(Vector3(0,3.1,-2.2))
	scene.set_process(false)
	for i in 4:
		await _capture(scene,out.path_join("fan-%d.png" % i))
		scene._animate_fans(1.0/12.0)
	quit(0)

func _capture(scene: Node, path: String) -> void:
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = scene.viewport.get_texture().get_image()
	if not scene._has_scene_pixels(frame):
		push_error("Blank classroom review frame")
		quit(1)
		return
	if frame.save_png(path) != OK:
		quit(1)
		return
	print("CLASSROOM_CAPTURE ",path)
