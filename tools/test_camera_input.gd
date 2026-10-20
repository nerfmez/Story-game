extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/classroom_3d_pixel.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var camera = scene.get_node("View/SubViewport/Room/Camera3D")
	var start: Vector3 = camera.rotation
	scene._web_control(["look", 100.0, -20.0])
	if not is_equal_approx(camera.rotation.y, start.y - 0.4) or not is_equal_approx(camera.rotation.x, start.x + 0.08):
		push_error("Drag command did not rotate the camera by the expected amount")
		quit(1)
		return
	scene._web_control(["look", 0.0, -10000.0])
	if not is_equal_approx(camera.rotation.x, 1.1):
		quit(1)
		return
	scene._web_control(["look", 0.0, 10000.0])
	if not is_equal_approx(camera.rotation.x, -1.1):
		quit(1)
		return
	scene._web_control(["view", 0])
	if not camera.rotation.is_equal_approx(start):
		quit(1)
		return
	scene._web_control(["view", 3])
	if scene.shot_index != 3 or camera.position.x > -3.0:
		push_error("Outside window preset is unreachable")
		quit(1)
		return
	scene._web_control(["view", 0])
	print("PASS: web look command rotates camera, limits vertical rotation, preset restores view")
	quit(0)
