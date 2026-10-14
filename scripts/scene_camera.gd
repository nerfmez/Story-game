extends Camera2D
## กล้องที่ขยับช้าๆ ตามเมาส์ และเลื่อนไปยังจุดที่บทสั่ง
## ชั้น Parallax2D แต่ละชั้นจะเลื่อนตามกล้องด้วยความเร็วต่างกัน จึงเห็นภาพมีมิติ

## ระยะที่กล้องโยกตามเมาส์ (พิกเซล)
@export var mouse_sway := 20.0
## ความไวในการเลื่อนกล้อง (ยิ่งมากยิ่งเร็ว)
@export var follow_speed := 2.5
## ขอบเขตกล้องแนวนอน (ภาพพื้นหลังกว้าง 800px เริ่มที่ x = -80)
@export var min_x := 260.0
@export var max_x := 380.0

var _target_x := 320.0


func pan_to(x: float) -> void:
	_target_x = x


func _process(delta: float) -> void:
	var viewport_width := get_viewport_rect().size.x
	var mouse_x := get_viewport().get_mouse_position().x
	var sway := clampf(mouse_x / viewport_width - 0.5, -0.5, 0.5) * 2.0 * mouse_sway
	var goal := clampf(_target_x + sway, min_x, max_x)
	position.x = lerpf(position.x, goal, 1.0 - exp(-follow_speed * delta))
