extends Node3D
## Orbit camera around the diorama, with no on-screen controls.
## Mouse: left drag turns, right/middle drag (or Shift + left) pans, wheel zooms.
## Touch: one finger turns, two fingers pinch to zoom and drag to pan.
## Keys: arrows turn, WASD pans, Q/E or +/- zoom, R returns to the opening view.
## Moves are eased so the model glides like a collectible on a turntable.

const PITCH_LIMITS := Vector2(5.0, 85.0)
const DISTANCE_LIMITS := Vector2(3.5, 42.0)
const PAN_LIMIT := 8.5

var camera: Camera3D
var target := Vector3.ZERO
var yaw := 0.0
var pitch := 30.0
var distance := 24.0
var _goal_target := Vector3.ZERO
var _goal_yaw := 0.0
var _goal_pitch := 30.0
var _goal_distance := 24.0
var _home: Array = []
var _touches := {}
var _pinch_distance := 0.0
var _pinch_center := Vector2.ZERO

func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 36.0
	camera.near = 0.05
	camera.far = 200.0
	add_child(camera)
	camera.current = true
	_place()

## Jumps (or glides, when instant is false) to a view: look-at point, yaw and pitch in degrees, distance.
func set_view(look_at_point: Vector3, yaw_deg: float, pitch_deg: float, dist: float, instant := true) -> void:
	_goal_target = look_at_point
	_goal_yaw = yaw_deg
	_goal_pitch = pitch_deg
	_goal_distance = dist
	if _home.is_empty():
		_home = [look_at_point, yaw_deg, pitch_deg, dist]
	if instant:
		target = _goal_target
		yaw = _goal_yaw
		pitch = _goal_pitch
		distance = _goal_distance
		_place()

func orbit(relative: Vector2) -> void:
	_goal_yaw -= relative.x * 0.3
	_goal_pitch = clampf(_goal_pitch + relative.y * 0.25, PITCH_LIMITS.x, PITCH_LIMITS.y)

func pan(relative: Vector2) -> void:
	var y := deg_to_rad(_goal_yaw)
	var right := Vector3(cos(y), 0, -sin(y))
	var forward := Vector3(-sin(y), 0, -cos(y))
	var scale := _goal_distance * 0.0016
	_goal_target += (-right * relative.x + forward * relative.y) * scale
	_goal_target.x = clampf(_goal_target.x, -PAN_LIMIT, PAN_LIMIT)
	_goal_target.z = clampf(_goal_target.z, -PAN_LIMIT, PAN_LIMIT)

func zoom(factor: float) -> void:
	_goal_distance = clampf(_goal_distance * factor, DISTANCE_LIMITS.x, DISTANCE_LIMITS.y)

func _unhandled_input(event: InputEvent) -> void:
	# Touch is handled below; skip the mouse events Godot copies from it.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1.0 / 0.9)
	elif event is InputEventMouseMotion:
		var left: bool = event.button_mask & MOUSE_BUTTON_MASK_LEFT != 0
		var other: bool = event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE) != 0
		if other or (left and event.shift_pressed):
			pan(event.relative)
		elif left:
			orbit(event.relative)
	elif event is InputEventMagnifyGesture:
		zoom(1.0 / event.factor)
	elif event is InputEventPanGesture:
		zoom(1.0 + event.delta.y * 0.04)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_reset_pinch()
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			orbit(event.relative)
		elif _touches.size() >= 2:
			var points: Array = _touches.values()
			var a: Vector2 = points[0]
			var b: Vector2 = points[1]
			var spread := a.distance_to(b)
			var center := (a + b) * 0.5
			if _pinch_distance > 1.0 and spread > 1.0:
				zoom(_pinch_distance / spread)
			pan(center - _pinch_center)
			_pinch_distance = spread
			_pinch_center = center
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R and not _home.is_empty():
		set_view(_home[0], _home[1], _home[2], _home[3], false)

func _reset_pinch() -> void:
	if _touches.size() >= 2:
		var points: Array = _touches.values()
		_pinch_distance = (points[0] as Vector2).distance_to(points[1])
		_pinch_center = ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5

func _process(delta: float) -> void:
	var turn := Vector2.ZERO
	var move := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_LEFT): turn.x -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT): turn.x += 1.0
	if Input.is_physical_key_pressed(KEY_UP): turn.y -= 1.0
	if Input.is_physical_key_pressed(KEY_DOWN): turn.y += 1.0
	if Input.is_physical_key_pressed(KEY_A): move.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): move.x += 1.0
	if Input.is_physical_key_pressed(KEY_W): move.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): move.y += 1.0
	if turn != Vector2.ZERO: orbit(turn * delta * 300.0)
	if move != Vector2.ZERO: pan(-move * delta * 500.0)
	if Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_EQUAL) or Input.is_physical_key_pressed(KEY_KP_ADD):
		zoom(1.0 - delta * 1.2)
	if Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_MINUS) or Input.is_physical_key_pressed(KEY_KP_SUBTRACT):
		zoom(1.0 + delta * 1.2)
	var ease := 1.0 - exp(-delta * 9.0)
	target = target.lerp(_goal_target, ease)
	yaw = lerpf(yaw, _goal_yaw, ease)
	pitch = lerpf(pitch, _goal_pitch, ease)
	distance = lerpf(distance, _goal_distance, ease)
	_place()

func _place() -> void:
	if camera == null:
		return
	var y := deg_to_rad(yaw)
	var p := deg_to_rad(pitch)
	camera.position = target + Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p)) * distance
	camera.look_at(target)
