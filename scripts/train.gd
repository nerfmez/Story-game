class_name Train
extends Sprite2D
## รถไฟที่วิ่งผ่านฉากเป็นระยะ หรือเมื่อบทสั่งด้วย "event": "train"

@export var speed := 140.0
## วิ่งเองทุกกี่วินาที (0 = วิ่งเฉพาะตอนบทสั่ง)
@export var auto_interval := 14.0
@export var start_x := -320.0
@export var end_x := 900.0
## วิ่งผ่านจอ: เริ่มจากนอกจอด้านซ้าย หายไปเมื่อพ้นจอด้านขวา (ไม่ใช้ start_x / end_x)
## ใช้กับรางที่ยาวต่อเนื่อง (ไม่มีต้นไม้บังหัวท้าย)
@export var across_screen := false

var _running := false
var _idle_time := 0.0


func _ready() -> void:
	visible = false


func pass_by() -> void:
	position.x = start_x
	if across_screen:
		position.x += -texture.get_width() - 8.0 - _screen_x()
	visible = true
	_running = true
	_idle_time = 0.0


func _process(delta: float) -> void:
	if not _running:
		_idle_time += delta
		if auto_interval > 0.0 and _idle_time >= auto_interval:
			pass_by()
		return
	position.x += speed * delta
	var gone := _screen_x() > get_viewport_rect().size.x + 8.0 if across_screen else position.x > end_x
	if gone:
		_running = false
		visible = false


## ตำแหน่ง x บนจอ (หลังคิด parallax และกล้องแล้ว) ของขอบซ้ายรถไฟ
func _screen_x() -> float:
	return get_global_transform_with_canvas().origin.x
