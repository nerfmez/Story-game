extends Node2D
## ตัวละครเดินซ้าย-ขวา (ลูกศร หรือ A/D) ฉากหลังวนซ้ำไม่สิ้นสุดด้วย Parallax2D.repeat_size
## ตอนนี้ยังไม่มีภาพท่าเดิน จึงใช้การเด้งขึ้นลงเล็กน้อยแทนจังหวะก้าวเท้า
## ถ้ามีภาพท่าเดินภายหลัง ให้เปลี่ยน Body เป็น AnimatedSprite2D แล้วเล่นอนิเมชันใน _process

@export var speed := 70.0
## ความสูงที่เด้งต่อก้าว (พิกเซล)
@export var bob_height := 2.0
@export var steps_per_second := 3.5

@onready var _body: Sprite2D = $Body
@onready var _reflection: Sprite2D = $Reflection

var _walk_time := 0.0


func _process(delta: float) -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	if dir == 0.0:
		dir = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	position.x += dir * speed * delta
	if dir != 0.0:
		_walk_time += delta
		var bob := roundf(absf(sin(_walk_time * steps_per_second * PI)) * bob_height)
		_body.offset.y = -bob
		_reflection.offset.y = bob
		_body.flip_h = dir < 0.0
		_reflection.flip_h = dir < 0.0
	else:
		_walk_time = 0.0
		_body.offset.y = 0.0
		_reflection.offset.y = 0.0
