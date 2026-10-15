extends Camera2D
## กล้องที่ขยับช้าๆ ตามเมาส์ และเลื่อนไปยังจุดที่บทสั่ง
## ชั้น Parallax2D แต่ละชั้นจะเลื่อนตามกล้องด้วยความเร็วต่างกัน จึงเห็นภาพมีมิติ

## ระยะที่กล้องโยกตามเมาส์ (พิกเซล)
@export var mouse_sway := 20.0
## ความไวในการเลื่อนกล้อง (ยิ่งมากยิ่งเร็ว)
@export var follow_speed := 2.5
## ถ้าตั้งไว้ กล้องจะตามโหนดนี้ (ตัวละครที่เดินได้) และไม่จำกัดขอบเขต
@export var follow: Node2D
## ระยะจากตำแหน่งของ follow ถึงกึ่งกลางจอ
@export var follow_offset := 0.0
## ขอบเขตกล้องแนวนอนเมื่อไม่ได้ตามใคร (ภาพพื้นหลังกว้าง 800px เริ่มที่ x = -80)
@export var min_x := 260.0
@export var max_x := 380.0

var _target_x := 320.0
## ระยะเลื่อนกล้องออกจากตัวละคร (ค่อยๆ เลื่อน) ตอนตาม follow
var _extra := 0.0
var _x := 0.0


func _ready() -> void:
	_x = position.x


func pan_to(x: float) -> void:
	_target_x = x


func _process(delta: float) -> void:
	var viewport_width := get_viewport_rect().size.x
	var mouse_x := get_viewport().get_mouse_position().x
	var sway := clampf(mouse_x / viewport_width - 0.5, -0.5, 0.5) * 2.0 * mouse_sway
	var t := 1.0 - exp(-follow_speed * delta)
	if follow:
		# ล็อกกล้องกับตัวละครตรงๆ (ตัวละครไม่สั่นบนจอตอนเดิน) ส่วนที่ค่อยๆ เลื่อนคือระยะเยื้อง:
		# camera_x ในบทกลายเป็นการเลื่อนกล้องออกจากตัวละคร (320 = ตรงกลาง)
		_extra = lerpf(_extra, follow_offset + (_target_x - 320.0) + sway, t)
		position.x = follow.position.x + roundf(_extra)
	else:
		_x = lerpf(_x, clampf(_target_x + sway, min_x, max_x), t)
		# ปัดเป็นพิกเซลเต็ม ภาพพิกเซลจึงคมไม่สั่น
		position.x = roundf(_x)
