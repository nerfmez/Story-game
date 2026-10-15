extends Node2D
## ตัวละครเดินซ้าย-ขวา (ลูกศร หรือ A/D) ฉากหลังวนซ้ำไม่สิ้นสุดด้วย Parallax2D.repeat_size
## ยืนนิ่ง = ภาพ idle, เดิน = เล่นแผ่นภาพท่าเดิน (หลายเฟรมเรียงแนวนอน)
## ภาพท่าเดินต้นฉบับหันไปทางซ้าย เวลาเดินขวาจึงพลิกภาพ

@export var idle_texture: Texture2D
@export var walk_texture: Texture2D
@export var walk_frames := 8
## เฟรมต่อวินาทีของท่าเดิน (8 เฟรมต่อรอบ ≈ 1.25 วินาที ตามวิดีโอต้นฉบับ)
@export var walk_fps := 6.4
## ความเร็วเดิน (พิกเซล/วินาที) ตั้งให้พอดีกับก้าวเท้า เท้าจะไม่ไถลบนถนน
@export var speed := 45.0
## ภาพท่าเดินกว้างกว่าภาพยืน เลื่อนให้ลำตัวตรงกับภาพยืน (ตอนหันซ้าย / ตอนพลิกหันขวา)
@export var walk_offset := Vector2(-20, 0)
@export var walk_offset_flipped := Vector2(-6, 0)

@onready var _body: Sprite2D = $Body
@onready var _reflection: Sprite2D = $Reflection

var _anim_time := 0.0
## ตำแหน่งจริงแบบทศนิยม ตำแหน่งที่วาด (position) ปัดเป็นพิกเซลเต็มเสมอ ภาพจึงไม่สั่น/ไม่เบลอ
var _x := 0.0
## ทิศจากปุ่มบนจอ (-1 ซ้าย, 0 หยุด, 1 ขวา) ตั้งโดย touch_controls.gd
var touch_dir := 0.0


func _ready() -> void:
	_x = position.x
	_set_pose(false, false)


func _process(delta: float) -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	if dir == 0.0:
		dir = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	if dir == 0.0:
		dir = touch_dir
	_x += dir * speed * delta
	position.x = roundf(_x)
	if dir != 0.0:
		_anim_time += delta
		_set_pose(true, dir > 0.0)
	else:
		_anim_time = 0.0
		_set_pose(false, false)


func _set_pose(walking: bool, facing_right: bool) -> void:
	for sprite in [_body, _reflection]:
		if walking and walk_texture:
			sprite.texture = walk_texture
			sprite.hframes = walk_frames
			sprite.frame = int(_anim_time * walk_fps) % walk_frames
			sprite.offset.x = walk_offset_flipped.x if facing_right else walk_offset.x
			sprite.flip_h = facing_right
			# ภาพท่าเดินสูงกว่าภาพยืน: ให้เท้าอยู่แถวเดียวกัน (เงาสะท้อนวาดกลับหัวจากเท้า จึงไม่ต้องเลื่อน)
			if sprite == _body and idle_texture:
				sprite.offset.y = idle_texture.get_height() - walk_texture.get_height()
		elif idle_texture:
			sprite.texture = idle_texture
			sprite.hframes = 1
			sprite.frame = 0
			sprite.offset = Vector2.ZERO
			sprite.flip_h = false
