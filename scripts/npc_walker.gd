extends Node2D
## ตัวละครที่เดินเอง (นางเอก): ยืนรอจนเริ่มเกม (begin) แล้วเดินเข้ามาจากนอกจอทางขวา
## ไปทางซ้ายจนถึงข้างพระเอก แล้วยืนรอ
## ภาพท่าเดินหันไปทางซ้าย ภาพยืนหันหน้าเข้าหาผู้เล่น
## ฉากฝน (set_wet) ใช้ภาพตัวเปียก + แว่นขึ้นฝ้า

@export var idle_texture: Texture2D
@export var idle_wet_texture: Texture2D
@export var idle_frames := 50
## เฟรมต่อวินาที: 100 เฟรมวิดีโอ (24fps) -> 50 เฟรม = 12
@export var idle_fps := 12.0
@export var walk_texture: Texture2D
@export var walk_wet_texture: Texture2D
@export var walk_frames := 18
## 35 เฟรมวิดีโอ (24fps) -> 18 เฟรม = 12.34 เฟรม/วินาที
@export var walk_fps := 12.34
## เท้าที่วางบนพื้นในภาพเดินเลื่อน ~3.6 พิกเซล/เฟรม x 12.34 เฟรม/วินาที
@export var speed := 44.0
## ภาพเดินกว้างกว่าภาพยืน เลื่อนให้ลำตัวตรงกัน (ลำตัวภาพยืนอยู่ x~17, ภาพเดิน x~26)
@export var walk_offset := Vector2(-9, 0)
## begin(x): เริ่มเดินที่ x + start_offset (นอกจอทางขวา) หยุดที่ x + stop_offset
@export var start_offset := 430.0
@export var stop_offset := 90.0
var stop_x := 0.0

var _wet := false
var _walking := false
var _time := 0.0

@onready var _body: Sprite2D = $Body


func _ready() -> void:
	_body.centered = false
	stop_x = position.x
	_apply()


## เริ่มเดินเข้าฉาก (x = ตำแหน่งพระเอก)
func begin(x: float) -> void:
	position.x = x + start_offset
	stop_x = x + stop_offset
	_walking = true
	_time = 0.0
	_apply()


func set_wet(on: bool) -> void:
	_wet = on
	_apply()


func _apply() -> void:
	if _walking:
		_body.texture = walk_wet_texture if _wet and walk_wet_texture else walk_texture
		_body.hframes = walk_frames
		_body.offset = walk_offset
	else:
		_body.texture = idle_wet_texture if _wet and idle_wet_texture else idle_texture
		_body.hframes = idle_frames
		_body.offset = Vector2.ZERO
	_body.frame = 0


func _process(delta: float) -> void:
	_time += delta
	if _walking:
		position.x -= speed * delta
		if position.x <= stop_x:
			position.x = stop_x
			_walking = false
			_time = 0.0
			_apply()
			return
		_body.frame = int(_time * walk_fps) % walk_frames
	else:
		_body.frame = int(_time * idle_fps) % idle_frames
