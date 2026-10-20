extends Control
## Godot 4.3 classroom. Opened on its own it is a free-camera preview; the story (scripts/classroom_scene.gd)
## sets scripted before adding it, which turns off the preview's camera keys, touch look and web bridge.

@onready var viewport: SubViewport = $View/SubViewport
@onready var camera: Camera3D = $View/SubViewport/Room/Camera3D
@onready var status: Label = $HUD/Status

const SHOTS := [
	[Vector3(0.35, 1.82, 5.65), Vector3(0.25, 1.42, -4.8)],
	[Vector3(4.45, 2.05, 4.6), Vector3(-0.65, 1.25, -3.4)],
	[Vector3(-3.7, 1.7, -3.55), Vector3(1.0, 1.15, 3.25)],
	[Vector3(-3.8, 1.75, -1.5), Vector3(-16, 1.1, -1.5)]
]
var shot_index := 0
var pixel_sizes := [Vector2i(640, 360), Vector2i(480, 270), Vector2i(960, 540)]
var pixel_index := 0
var hud_visible := true
var web_callback: JavaScriptObject
var touch_move := Vector2.ZERO
var fan_rotors: Array[Node3D] = []
var scripted := false

func _ready() -> void:
	_initialize_static_batches()
	for node in $View/SubViewport/Room.find_children("Rotor", "Node3D", true, false):
		if node.get_meta("animated_rotor",false): fan_rotors.append(node)
	viewport.size = pixel_sizes[pixel_index]
	if scripted:
		$HUD.visible = false
		return
	_set_shot(0)
	_update_status()
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i].begins_with("--shot="):
			_set_shot(clampi(int(args[i].get_slice("=", 1)), 0, SHOTS.size() - 1))
		if args[i] == "--capture" and i + 1 < args.size():
			_capture_after_frames(args[i + 1])
		if args[i] == "--no-hud":
			$HUD.visible = false
	if OS.has_feature("web"):
		$HUD.visible = false
		web_callback = JavaScriptBridge.create_callback(_web_control)
		var window := JavaScriptBridge.get_interface("window")
		window.classroomCommand = web_callback
		window.classroomReady = false
		_publish_web_state()
		_finish_web_startup()

func _initialize_static_batches() -> void:
	var batches := get_node_or_null("View/SubViewport/Room/StaticBatches")
	if batches == null: return
	for node in batches.get_children():
		if node is MultiMeshInstance3D and node.has_meta("instance_transforms"):
			var transforms: Array = node.get_meta("instance_transforms")
			for i in transforms.size(): node.multimesh.set_instance_transform(i,transforms[i])

func _finish_web_startup() -> void:
	# A running JS bridge doesn't establish that WebGL drew any room pixels.
	# Check the actual first frame before the HTML hides the loading screen.
	for i in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var window := JavaScriptBridge.get_interface("window")
	if _has_scene_pixels(viewport.get_texture().get_image()):
		window.classroomReady = true
	else:
		window.classroomRenderError = "ฉากสามมิติยังวาดไม่สำเร็จ กรุณาโหลดหน้าใหม่"

func _has_scene_pixels(frame: Image) -> bool:
	if frame == null or frame.is_empty(): return false
	var reference := frame.get_pixel(0,0)
	var changed := 0
	for y in 9:
		for x in 16:
			var pixel := frame.get_pixel(int((x+0.5)*frame.get_width()/16.0),int((y+0.5)*frame.get_height()/9.0))
			if absf(pixel.r-reference.r)+absf(pixel.g-reference.g)+absf(pixel.b-reference.b) > 0.08:
				changed += 1
	return changed >= 6

func _web_control(args: Array) -> void:
	if args.is_empty(): return
	match str(args[0]):
		"view": _set_shot(clampi(int(args[1]), 0, SHOTS.size() - 1))
		"pixel":
			pixel_index = (pixel_index + 1) % pixel_sizes.size()
			viewport.size = pixel_sizes[pixel_index]
			_update_status()
		"move": touch_move = Vector2(float(args[1]), float(args[2]))
		"look": _look(Vector2(float(args[1]), float(args[2])))

func _look(relative: Vector2) -> void:
	camera.rotation.y -= relative.x * 0.004
	camera.rotation.x = clampf(camera.rotation.x - relative.y * 0.004, -1.1, 1.1)

func _publish_web_state() -> void:
	if not OS.has_feature("web"): return
	var window := JavaScriptBridge.get_interface("window")
	window.classroomPixelWidth = pixel_sizes[pixel_index].x
	window.classroomPixelHeight = pixel_sizes[pixel_index].y
	window.classroomView = shot_index
	JavaScriptBridge.eval("window.dispatchEvent(new Event('classroom-state'))", true)

func _set_shot(index: int) -> void:
	shot_index = index
	camera.position = SHOTS[index][0]
	camera.look_at(SHOTS[index][1])
	_update_status()

func _update_status() -> void:
	if is_instance_valid(status):
		status.text = "3D CLASSROOM  /  %d × %d  /  VIEW %d\n1–4 camera · P pixels · RMB look · WASD move · H hide" % [pixel_sizes[pixel_index].x, pixel_sizes[pixel_index].y, shot_index + 1]
	_publish_web_state()

func _unhandled_input(event: InputEvent) -> void:
	if scripted:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _set_shot(0)
			KEY_2: _set_shot(1)
			KEY_3: _set_shot(2)
			KEY_4: _set_shot(3)
			KEY_P:
				pixel_index = (pixel_index + 1) % pixel_sizes.size()
				viewport.size = pixel_sizes[pixel_index]
				_update_status()
			KEY_H:
				hud_visible = not hud_visible
				$HUD.visible = hud_visible
			KEY_F12:
				_save_frame("user://classroom-view-%d.png" % (shot_index + 1))
	# Web input comes through the pointer bridge; don't rotate twice if the
	# browser also synthesizes mouse/touch events for Godot.
	if not OS.has_feature("web"):
		if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_look(event.relative * 0.75)
		if event is InputEventScreenDrag:
			_look(event.relative)

func _animate_fans(delta: float) -> void:
	for rotor in fan_rotors:
		rotor.rotation.y = fposmod(rotor.rotation.y + float(rotor.get_meta("speed"))*delta,TAU)

func _process(delta: float) -> void:
	_animate_fans(delta)
	if scripted:
		return
	var move := Vector3(touch_move.x, 0, touch_move.y)
	if Input.is_physical_key_pressed(KEY_W): move.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S): move.z += 1.0
	if Input.is_physical_key_pressed(KEY_A): move.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): move.x += 1.0
	if Input.is_physical_key_pressed(KEY_Q): move.y -= 1.0
	if Input.is_physical_key_pressed(KEY_E): move.y += 1.0
	if move.length_squared() > 0.0:
		camera.position += camera.global_basis * move.normalized() * delta * 2.2
		camera.position.x = clampf(camera.position.x, -4.7, 4.7)
		camera.position.y = clampf(camera.position.y, 0.55, 3.1)
		camera.position.z = clampf(camera.position.z, -5.4, 5.8)

func _capture_after_frames(path: String) -> void:
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save_frame(path)
	get_tree().quit()

func _save_frame(path: String) -> void:
	var frame := viewport.get_texture().get_image()
	frame.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
	var result := frame.save_png(path)
	print("CLASSROOM_CAPTURE ", path, " result=", result)
