extends Camera3D
## กล้อง HD-2D: เลื่อนตามบท (camera_x เดียวกับฉาก 2D) และโยกตามเมาส์
## หันมองจุดกลางฉากเสมอ ฉากใกล้-ไกลจึงเลื่อนต่างกันเองแบบ 3D จริง

## แปลงค่า camera_x ในบท (หน่วยพิกเซลของฉาก 2D, กึ่งกลาง 320) เป็นเมตร
@export var pixels_per_meter := 25.0
@export var mouse_sway := 0.8
@export var follow_speed := 1.5
@export var min_x := -2.5
@export var max_x := 2.5
## จุดที่กล้องมอง (เลื่อนตามกล้องบางส่วน)
@export var look_at_point := Vector3(0, 1.5, -1.0)
@export_range(0.0, 1.0) var look_follow := 0.6

var _target_x := 0.0
var _time := 0.0
var _base_y := 0.0


func _ready() -> void:
	_base_y = position.y


func pan_to(x: float) -> void:
	_target_x = (x - 320.0) / pixels_per_meter


func _process(delta: float) -> void:
	_time += delta
	var root := get_tree().root
	var mouse := root.get_mouse_position().x / root.get_visible_rect().size.x
	var sway := (clampf(mouse, 0.0, 1.0) - 0.5) * 2.0 * mouse_sway
	var goal := clampf(_target_x + sway, min_x, max_x)
	position.x = lerpf(position.x, goal, 1.0 - exp(-follow_speed * delta))
	# Gentle handheld drift, like filming on a phone
	position.y = _base_y + sin(_time * 0.7) * 0.03
	var target := look_at_point + Vector3(position.x * look_follow, 0, 0)
	look_at(target)
