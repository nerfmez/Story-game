extends Node2D
## ตัวละครเดินซ้าย-ขวา (ลูกศร หรือ A/D) ฉากหลังวนซ้ำไม่สิ้นสุดด้วย Parallax2D.repeat_size
## ยืนนิ่ง = ภาพ idle, เดิน = เล่นแผ่นภาพท่าเดิน (หลายเฟรมเรียงแนวนอน)
## ภาพท่าเดินต้นฉบับหันไปทางซ้าย เวลาเดินขวาจึงพลิกภาพ

## ภาพยืน: 8 เฟรมจาก tools/make_idle_anim.py (4 ท่าหายใจ + 4 ท่าเดียวกันแบบหลับตา)
## หรือภาพเดียวก็ได้ (idle_frames = 1)
@export var idle_texture: Texture2D
@export var idle_frames := 8
## จังหวะหายใจ: (ท่า, วินาที) 0 ปกติ, 1 ไหล่ลง, 2 หัวตามลง (ผมค้าง), 3 ลงสุด ผมตกตาม
@export var breath_steps: Array[Vector2] = [Vector2(0, 1.0), Vector2(1, 0.18), Vector2(2, 0.18), Vector2(3, 0.9), Vector2(2, 0.16), Vector2(1, 0.16)]
## กะพริบตาทุกๆ กี่วินาที (สุ่มในช่วงนี้) และนานเท่าไร
@export var blink_every := Vector2(2.2, 5.0)
@export var blink_time := 0.13
@export var walk_texture: Texture2D
@export var walk_frames := 15
## เฟรมต่อวินาทีของท่าเดิน (15 เฟรมต่อรอบ = 1.25 วินาที เท่าวิดีโอต้นฉบับ)
## 24 เฟรม/วินาทีลื่นเกินไปสำหรับภาพพิกเซล 12 ดูเป็นแอนิเมชันมากกว่า
@export var walk_fps := 12.0
## ความเร็วเดิน (พิกเซล/วินาที) = เท้าที่วางบนพื้นในภาพเลื่อน ~5.9 พิกเซล/เฟรม x 12 เฟรม/วินาที
## ต้องเท่ากันพอดี ไม่งั้นเท้าไถลบนถนนและดูกระตุกทุกก้าว
@export var speed := 71.0
## เฟรมที่เท้าแตะพื้น (เล่นเสียงเท้า)
@export var step_frames: Array[int] = [4, 11]
## เสียงเท้า (AudioStreamRandomizer ที่สุ่มเสียง/ระดับเสียงให้ไม่ซ้ำ)
@export var step_sound: AudioStreamPlayer
## ภาพท่าเดินกว้างกว่าภาพยืน เลื่อนให้ลำตัวตรงกับภาพยืน (ตอนหันซ้าย / ตอนพลิกหันขวา)
@export var walk_offset := Vector2(-20, 0)
@export var walk_offset_flipped := Vector2(-5, 0)
## ภาพยืนตอนพลิกหันขวา เลื่อนให้ลำตัวอยู่ที่เดิม
@export var idle_offset_flipped := Vector2(1, 0)

@onready var _body: Sprite2D = $Body
@onready var _reflection: Sprite2D = $Reflection

var _anim_time := 0.0
## ทิศจากปุ่มบนจอ (-1 ซ้าย, 0 หยุด, 1 ขวา) ตั้งโดย touch_controls.gd
var touch_dir := 0.0
## หันขวาอยู่หรือไม่ (หยุดเดินแล้วท่ายืนหันไปทางที่เดินล่าสุด)
var _facing_right := false
var _last_frame := -1
var _idle_time := 0.0
var _blink_wait := 3.0
var _blink_left := 0.0


func _ready() -> void:
	_set_pose(false, false)


func _process(delta: float) -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	if dir == 0.0:
		dir = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	if dir == 0.0:
		dir = touch_dir
	position.x += dir * speed * delta
	if dir != 0.0:
		_facing_right = dir > 0.0
		_anim_time += delta
		_set_pose(true, _facing_right)
		var frame := int(_anim_time * walk_fps) % walk_frames
		if frame != _last_frame and frame in step_frames and step_sound:
			step_sound.play()
		_last_frame = frame
	else:
		_anim_time = 0.0
		_last_frame = -1
		_idle_time += delta
		_blink_wait -= delta
		if _blink_wait <= 0.0:
			_blink_left = blink_time
			_blink_wait = randf_range(blink_every.x, blink_every.y)
		_blink_left -= delta
		_set_pose(false, _facing_right)


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
			sprite.hframes = idle_frames
			sprite.frame = _idle_frame()
			# ภาพยืนต้นฉบับหันซ้ายเหมือนท่าเดิน
			sprite.offset = idle_offset_flipped if facing_right else Vector2.ZERO
			sprite.flip_h = facing_right


## เฟรมของท่ายืนตอนนี้: ท่าหายใจตามเวลา (+4 ถ้ากำลังกะพริบตา)
func _idle_frame() -> int:
	if idle_frames < 8:
		return 0
	var total := 0.0
	for step in breath_steps:
		total += step.y
	var t := fmod(_idle_time, total)
	var pose := 0
	for step in breath_steps:
		if t < step.y:
			pose = int(step.x)
			break
		t -= step.y
	return pose + (4 if _blink_left > 0.0 else 0)
