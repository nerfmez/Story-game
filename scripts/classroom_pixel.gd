extends Control
## Independent Godot 4.3 classroom preview. No connection to the story flow.

@onready var viewport: SubViewport = $View/SubViewport
@onready var camera: Camera3D = $View/SubViewport/Room/Camera3D
@onready var status: Label = $HUD/Status

const SHOTS := [
	[Vector3(0.35, 1.82, 5.65), Vector3(0.25, 1.42, -4.8)],
	[Vector3(4.45, 2.05, 4.6), Vector3(-0.65, 1.25, -3.4)],
	[Vector3(-3.7, 1.7, -3.55), Vector3(1.0, 1.15, 3.25)]
]
var shot_index := 0
var pixel_sizes := [Vector2i(480, 270), Vector2i(640, 360), Vector2i(960, 540)]
var pixel_index := 0
var hud_visible := true

func _ready() -> void:
	_set_shot(0)
	viewport.size = pixel_sizes[pixel_index]
	_update_status()
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i].begins_with("--shot="):
			_set_shot(clampi(int(args[i].get_slice("=", 1)), 0, 2))
		if args[i] == "--capture" and i + 1 < args.size():
			_capture_after_frames(args[i + 1])
		if args[i] == "--no-hud":
			$HUD.visible = false

func _set_shot(index: int) -> void:
	shot_index = index
	camera.position = SHOTS[index][0]
	camera.look_at(SHOTS[index][1])
	_update_status()

func _update_status() -> void:
	if is_instance_valid(status):
		status.text = "3D CLASSROOM  /  %d × %d  /  VIEW %d\n1–3 camera · P pixels · RMB look · WASD move · H hide" % [pixel_sizes[pixel_index].x, pixel_sizes[pixel_index].y, shot_index + 1]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _set_shot(0)
			KEY_2: _set_shot(1)
			KEY_3: _set_shot(2)
			KEY_P:
				pixel_index = (pixel_index + 1) % pixel_sizes.size()
				viewport.size = pixel_sizes[pixel_index]
				_update_status()
			KEY_H:
				hud_visible = not hud_visible
				$HUD.visible = hud_visible
			KEY_F12:
				_save_frame("user://classroom-view-%d.png" % (shot_index + 1))
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera.rotation.y -= event.relative.x * 0.003
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.003, -1.1, 1.1)

func _process(delta: float) -> void:
	var move := Vector3.ZERO
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
	frame.resize(1440, 810, Image.INTERPOLATE_NEAREST)
	var result := frame.save_png(path)
	print("CLASSROOM_CAPTURE ", path, " result=", result)
