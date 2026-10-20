extends Node3D
## Seated, camera-direction sprites. Seats stay fixed while only the drawing changes.
## Classmates are background: drawn without eyes, a shadow over the eye line like extras in anime
## (students/mob/, tools/mob_faces.py), and muted (less colour and contrast, a touch of the room's cool
## light) so Sun and Saifon, in full colour, are the ones the eye goes to.
const LEADS := ["sun", "saifon"]
const EXTRA_BRIGHTNESS := 0.96
const EXTRA_CONTRAST := 0.78
const EXTRA_SATURATION := 0.5
const EXTRA_TINT := Color(0.88, 0.91, 0.97)
var _camera: Camera3D
var _last_camera := Vector3.INF
var _students: Array[Sprite3D] = []

func _ready() -> void:
	_camera = get_parent().get_node("Camera3D")
	var muted := {}
	for child in get_children():
		var student := child as Sprite3D
		_students.append(student)
		if str(student.get_meta("character", "")) in LEADS:
			continue
		if not muted.has(student.texture):
			muted[student.texture] = _muted(student.texture)
		student.texture = muted[student.texture]
		student.modulate = EXTRA_TINT
	_update_views()

func _muted(texture: Texture2D) -> Texture2D:
	var path := texture.resource_path
	var mob := path.get_base_dir().path_join("mob").path_join(path.get_file())
	if ResourceLoader.exists(mob):
		texture = load(mob)
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	image.adjust_bcs(EXTRA_BRIGHTNESS, EXTRA_CONTRAST, EXTRA_SATURATION)
	return ImageTexture.create_from_image(image)

func _process(_delta: float) -> void:
	if _camera.global_position.distance_squared_to(_last_camera) > 0.0001:
		_update_views()

func _update_views() -> void:
	_last_camera = _camera.global_position
	for student in _students:
		# Front is towards the blackboard (-Z), independent of camera rotation.
		var direction := student.global_basis.inverse() * (_last_camera - student.global_position)
		var angle := atan2(direction.x, -direction.z)
		var sector := posmod(int(round(angle / (PI / 2.0))), 4)
		var frame: int = [0, 3, 1, 2][sector]
		# Hysteresis avoids flickering between drawings near a diagonal.
		var old_sector: int = [0, 2, 3, 1][student.frame]
		if absf(angle_difference(old_sector * PI / 2.0, angle)) < PI / 4.0 + 0.08:
			continue
		student.frame = frame
		student.flip_h = student.get_meta("mirror_left", false) and frame == 2
