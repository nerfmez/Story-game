extends Node3D
## Seated, camera-direction sprites. Seats stay fixed while only the drawing changes.
var _camera: Camera3D
var _last_camera := Vector3.INF
var _students: Array[Sprite3D] = []

func _ready() -> void:
	_camera = get_parent().get_node("Camera3D")
	for child in get_children():
		_students.append(child as Sprite3D)
	_update_views()

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
