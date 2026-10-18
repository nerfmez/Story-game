extends Node2D
## ตัวละครที่เดินตามบท (นางเอก): ซ่อนอยู่จนบทสั่ง enter() แล้วเดินจากจุดหนึ่งไปอีกจุด ถึงแล้วยืนรอ
## ภาพท่าเดินหันไปทางซ้าย (เดินไปทางขวาจะพลิกภาพ) ภาพยืนพลิกให้หันซ้ายทางเดียวกับพระเอก
## ฉากฝน (set_wet) ใช้ภาพตัวเปียก + แว่นขึ้นฝ้า

signal arrived

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
## ภาพเดินกว้างกว่าภาพยืน เลื่อนให้ลำตัวตรงกัน (ลำตัวภาพยืนอยู่ x~17, ภาพเดิน x~26 / พลิกแล้ว x~23)
@export var walk_offset := Vector2(-9, 0)
@export var walk_offset_flipped := Vector2(-6, 0)
## ภาพยืนต้นฉบับหันไปทางขวา: พลิกให้หันซ้ายทางเดียวกับพระเอก (ท่ายืนถือร่มของเขาหันซ้าย)
## ลำตัวพลิกแล้วอยู่ x~18 (เดิม 17) จึงเลื่อน -1
@export var idle_flip := true
@export var idle_offset_flipped := Vector2(-1, 0)

var _wet := false
var _walking := false
var _right := false
var _target := 0.0
var _time := 0.0
var _follow: Node2D                              # เดินข้างๆ ตัวละครนี้ (follow())
var _follow_offset := 0.0
var _stride := 0.0                               # ระยะที่เดินตามมาแล้ว: นับเฟรมเดินตามระยะ เท้าจึงไม่ไถลไม่ว่าจะเดินเร็วแค่ไหน

@onready var _body: Sprite2D = $Body


func _ready() -> void:
	_body.centered = false
	visible = false
	_apply()


## ปรากฏที่ from_x แล้วเดินไป to_x (ถึงแล้วส่ง arrived)
func enter(from_x: float, to_x: float) -> void:
	position.x = from_x
	visible = true
	walk_to(to_x)


func walk_to(x: float) -> void:
	_target = x
	_right = x > position.x
	_walking = true
	_time = 0.0
	_apply()


## เดินข้างๆ target ห่าง offset (ใต้ร่มเดียวกัน): ขยับตาม target ทุกเฟรม เดินเมื่อมันเดิน ยืนเมื่อมันหยุด
## ท่าเดินเล่นตามระยะที่ขยับ (ก้าวละ speed / walk_fps พิกเซล) จึงเข้ากับความเร็วของ target เสมอ
func follow(target: Node2D, offset: float) -> void:
	_follow = target
	_follow_offset = offset
	position.x = target.position.x + offset
	visible = true
	_walking = false
	_apply()


func stop_following() -> void:
	_follow = null
	_walking = false
	_apply()


func set_wet(on: bool) -> void:
	_wet = on
	_apply()


func _apply() -> void:
	if _walking:
		_body.texture = walk_wet_texture if _wet and walk_wet_texture else walk_texture
		_body.hframes = walk_frames
		_body.flip_h = _right
		_body.offset = walk_offset_flipped if _right else walk_offset
	else:
		_body.texture = idle_wet_texture if _wet and idle_wet_texture else idle_texture
		_body.hframes = idle_frames
		# เดินข้างซันแล้วหยุด: ยืนหันทางที่เดินมา (ไปทางขวาแล้วไม่หันกลับ) ไม่งั้นหันซ้ายทางเดียวกับพระเอก
		var flip := idle_flip and not (_follow and _right)
		_body.flip_h = flip
		_body.offset = idle_offset_flipped if flip else Vector2.ZERO
	_body.frame = 0


func _process(delta: float) -> void:
	_time += delta
	if _follow:
		var moved := _follow.position.x + _follow_offset - position.x
		position.x += moved
		var walking := absf(moved) > 0.01
		if walking != _walking or (walking and (moved > 0.0) != _right):
			_walking = walking
			_right = moved > 0.0 if walking else _right
			_time = 0.0
			_apply()
		if _walking:
			_stride += absf(moved)
			_body.frame = int(_stride / (speed / walk_fps)) % walk_frames
		else:
			_body.frame = int(_time * idle_fps) % idle_frames
		return
	if _walking:
		var step := speed * delta
		if absf(_target - position.x) <= step:
			position.x = _target
			_walking = false
			_time = 0.0
			_apply()
			arrived.emit()
			return
		position.x += step if _right else -step
		_body.frame = int(_time * walk_fps) % walk_frames
	else:
		_body.frame = int(_time * idle_fps) % idle_frames
