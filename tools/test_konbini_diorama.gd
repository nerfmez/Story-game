extends SceneTree
## Run with Godot 4.3 --headless --path . --script tools/test_konbini_diorama.gd
## Builds the konbini diorama and checks that it has no UI, that the camera
## turns, zooms and pans within its limits, and that the small loops move.

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _run() -> void:
	var scene: Node3D = load("res://scenes/konbini_diorama.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	if not scene.find_children("*", "Control", true, false).is_empty() or not scene.find_children("*", "CanvasLayer", true, false).is_empty():
		return _fail("The diorama must not contain UI nodes")
	var meshes := scene.find_children("*", "MeshInstance3D", true, false).size()
	var primitives: int = scene.get_meta("primitive_count")
	if primitives < 1500:
		return _fail("Expected a detailed model, got %d primitives" % primitives)
	print("konbini: %d primitives merged into %d mesh instances" % [primitives, meshes])
	var rig = scene.rig
	rig.set_view(Vector3.ZERO, 0.0, 30.0, 20.0)
	rig.orbit(Vector2(100, 0))
	if not is_equal_approx(rig._goal_yaw, -30.0):
		return _fail("Dragging sideways should turn the camera")
	rig.orbit(Vector2(0, 10000))
	if not is_equal_approx(rig._goal_pitch, rig.PITCH_LIMITS.y):
		return _fail("Camera must stop above the model")
	rig.orbit(Vector2(0, -10000))
	if not is_equal_approx(rig._goal_pitch, rig.PITCH_LIMITS.x):
		return _fail("Camera must not go under the base")
	rig.zoom(0.001)
	if not is_equal_approx(rig._goal_distance, rig.DISTANCE_LIMITS.x):
		return _fail("Zoom in limit")
	rig.zoom(1000.0)
	if not is_equal_approx(rig._goal_distance, rig.DISTANCE_LIMITS.y):
		return _fail("Zoom out limit")
	rig.pan(Vector2(-100000, 0))
	if absf(rig._goal_target.x) > rig.PAN_LIMIT + 0.001 or rig._goal_target.length() < 1.0:
		return _fail("Panning should move the look-at point and stay over the base")
	# touch: one finger turns, two fingers pinch
	rig.set_view(Vector3.ZERO, 0.0, 30.0, 20.0)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = Vector2(100, 100)
	rig._unhandled_input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(150, 100)
	drag.relative = Vector2(50, 0)
	rig._unhandled_input(drag)
	if not is_equal_approx(rig._goal_yaw, -15.0):
		return _fail("One-finger drag should turn the camera")
	var second := InputEventScreenTouch.new()
	second.index = 1
	second.pressed = true
	second.position = Vector2(250, 100)
	rig._unhandled_input(second)
	var spread := InputEventScreenDrag.new()
	spread.index = 1
	spread.position = Vector2(350, 100)
	spread.relative = Vector2(100, 0)
	rig._unhandled_input(spread)
	if rig._goal_distance >= 20.0:
		return _fail("Spreading two fingers should zoom in")
	# the door, signs and signals keep moving
	var door: Node3D = scene.door_panels[0]
	var closed := door.position.x
	var traffic: OmniLight3D = scene.lights["Traffic"]
	var colour := traffic.light_color
	var moved := false
	var changed := false
	for i in 400:
		scene._process(0.05)
		moved = moved or absf(door.position.x - closed) > 0.5
		changed = changed or not traffic.light_color.is_equal_approx(colour)
	if not moved:
		return _fail("The automatic door never opened")
	if not changed:
		return _fail("The traffic light never changed")
	for preset in scene.VIEWS.size():
		scene.show_view(preset)
	scene.queue_free()
	await process_frame
	print("PASS: konbini diorama builds without UI; orbit, zoom, pan, touch, door and signals work")
	quit(0)
