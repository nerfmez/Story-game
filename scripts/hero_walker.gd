extends Node2D
## ตัวละครเดินซ้าย-ขวา (ลูกศร หรือ A/D) ฉากหลังวนซ้ำไม่สิ้นสุดด้วย Parallax2D.repeat_size
## ยืนนิ่ง = ภาพ idle, เดิน = เล่นแผ่นภาพท่าเดิน (หลายเฟรมเรียงแนวนอน)
## ภาพท่าเดินต้นฉบับหันไปทางซ้าย เวลาเดินขวาจึงพลิกภาพ

## ภาพยืน มี 2 แบบ:
## - วิดีโอ (idle_fps > 0): แผ่นภาพจาก tools/import_idle_video.py เล่นวนทุกเฟรมที่ idle_fps
## - สร้างจากภาพนิ่ง (idle_fps = 0): 6 เฟรมจาก tools/make_idle_anim.py (หายใจ 3 ท่า + หลับตา)
## หรือภาพเดียวก็ได้ (idle_frames = 1)
@export var idle_texture: Texture2D
@export var idle_frames := 32
@export var idle_fps := 12.0
## เลื่อนภาพยืนให้ลำตัวตรงกับท่าเดิน (หันซ้าย / พลิกหันขวา)
@export var idle_offset := Vector2(0, 0)
## แถวของพื้นที่เท้าแตะ นับจากตำแหน่งตัวละคร (ภาพยืนและท่าเดินวางเท้าแถวนี้)
@export var ground_row := 121
## จังหวะหายใจ: (ท่า, วินาที) 0 ปกติ, 1 ไหล่และแขนลง 1px, 2 หัวตามลง
@export var breath_steps: Array[Vector2] = [
	Vector2(0, 1.3), Vector2(1, 0.22), Vector2(2, 1.1), Vector2(1, 0.22),
]
## กะพริบตาทุกๆ กี่วินาที (สุ่มในช่วงนี้) และนานเท่าไร
@export var blink_every := Vector2(2.2, 5.0)
@export var blink_time := 0.13
@export var walk_texture: Texture2D
@export var walk_frames := 18
## เฟรมต่อวินาทีของท่าเดิน (18 เฟรมต่อรอบ = 1.5 วินาที เท่าวิดีโอต้นฉบับ 36 เฟรมที่ 24fps)
## 24 เฟรม/วินาทีลื่นเกินไปสำหรับภาพพิกเซล 12 ดูเป็นแอนิเมชันมากกว่า
@export var walk_fps := 12.0
## ความเร็วเดิน (พิกเซล/วินาที) = เท้าที่วางบนพื้นในภาพเลื่อน ~4.5 พิกเซล/เฟรม x walk_fps (12)
## ต้องเท่ากันพอดี ไม่งั้นเท้าไถลบนถนนและดูกระตุกทุกก้าว
@export var speed := 54.0
## เฟรมที่เท้าแตะพื้น (เล่นเสียงเท้า)
@export var step_frames: Array[int] = [0, 9]
## เสียงเท้า (AudioStreamRandomizer ที่สุ่มเสียง/ระดับเสียงให้ไม่ซ้ำ)
@export var step_sound: AudioStreamPlayer
## ภาพท่าเดินกว้างกว่าภาพยืน เลื่อนให้ลำตัวตรงกับภาพยืน (ตอนหันซ้าย / ตอนพลิกหันขวา)
@export var walk_offset := Vector2(-18, 0)
@export var walk_offset_flipped := Vector2(-11, 0)
## ภาพยืนตอนพลิกหันขวา เลื่อนให้ลำตัวอยู่ที่เดิม
@export var idle_offset_flipped := Vector2(-1, 0)

## ยืนนานๆ แล้วหยิบโทรศัพท์ขึ้นมาดู (แผ่นภาพจาก tools/import_idle_video.py --match)
## เฟรม 0..phone_take_out-1 = หยิบออกมา, ที่เหลือ = ถือดู (เล่นไป-กลับวน ไม่มีรอยต่อ)
## พอกดเดิน เล่นท่าหยิบย้อนกลับเร็วๆ (เก็บโทรศัพท์) แล้วค่อยเดิน
@export var phone_texture: Texture2D
@export var phone_frames := 62
@export var phone_take_out := 22
@export var phone_fps := 12.0
## ยืนกี่วินาทีถึงหยิบโทรศัพท์ (สุ่มในช่วงนี้)
@export var phone_after := Vector2(5.0, 8.0)
## เฟรมของท่ายืนที่ตรงกับเฟรมแรกของท่าโทรศัพท์ (สลับตรงนี้ภาพจึงไม่กระโดด)
@export var phone_from_idle_frame := 5
## เก็บโทรศัพท์: เล่นท่าหยิบย้อนกลับที่ phone_fps แต่ข้ามทีละกี่เฟรม (2 = เร็วกว่าตอนหยิบ 2 เท่า
## โดยยังเปลี่ยนภาพ 12 ครั้ง/วินาทีเท่าตอนหยิบ ไม่ลื่นเกินไปแบบเล่นทุกเฟรม 24 ครั้ง/วินาที)
@export var phone_put_away_step := 2
@export var phone_offset := Vector2(-9, 0)
@export var phone_offset_flipped := Vector2(-2, 0)

## ถือร่ม (ตอนฝนตก main.gd เปิดให้): ใช้ภาพยืน/เดินถือร่มแทน (tools/import_char_video.py)
## มีจำนวนเฟรม ตำแหน่ง ความเร็วเดิน และจังหวะเสียงเท้าของตัวเอง ไม่หยิบโทรศัพท์ (มือถือร่มอยู่)
@export var umbrella_idle_texture: Texture2D
@export var umbrella_idle_frames := 23
## ท่ายืนถือร่มขยับเร็วในวิดีโอ จึงเล่นช้ากว่าวิดีโอ (12)
@export var umbrella_idle_fps := 8.0
@export var umbrella_idle_offset := Vector2(-28, 0)
@export var umbrella_idle_offset_flipped := Vector2(-15, 0)
@export var umbrella_walk_texture: Texture2D
@export var umbrella_walk_frames := 15
@export var umbrella_walk_fps := 10.8
@export var umbrella_walk_offset := Vector2(-25, 0)
@export var umbrella_walk_offset_flipped := Vector2(-10, 0)
## เดินเร็วเท่าตอนไม่ถือร่ม (54): เท้าที่วางบนพื้นในภาพเดินถือร่มเลื่อน ~5 พิกเซล/เฟรม
## จึงต้องเล่น 54 / 5 = 10.8 เฟรม/วินาที (umbrella_walk_fps) เท้าถึงไม่ไถล
@export var umbrella_speed := 54.0
@export var umbrella_step_frames: Array[int] = [2, 9]
var umbrella := false
var _plain := {}

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
enum Phone { NONE, TAKING_OUT, HOLDING, PUTTING_AWAY }
var _phone := Phone.NONE
var _phone_time := 0.0
var _phone_wait := 6.0
## ยืนนิ่งมากี่วินาทีแล้ว (เริ่มนับใหม่ทุกครั้งที่เดินหรือเก็บโทรศัพท์)
var _still_time := 0.0
## เฟรมที่เริ่มเก็บโทรศัพท์ (ย้อนจากเฟรมนี้ลงไปถึง 0)
var _put_away_from := 0


## ถือร่ม/ไม่ถือร่ม: สลับชุดภาพยืนและเดิน (เก็บชุดปกติไว้คืนตอนเลิกถือ)
func set_umbrella(on: bool) -> void:
	if _plain.is_empty():
		for key in ["idle_texture", "idle_frames", "idle_fps", "idle_offset", "idle_offset_flipped", "walk_texture",
				"walk_frames", "walk_fps", "walk_offset", "walk_offset_flipped", "speed", "step_frames"]:
			_plain[key] = get(key)
	if on and not (umbrella_idle_texture and umbrella_walk_texture):
		on = false
	umbrella = on
	if on:
		idle_texture = umbrella_idle_texture
		idle_frames = umbrella_idle_frames
		idle_fps = umbrella_idle_fps
		idle_offset = umbrella_idle_offset
		idle_offset_flipped = umbrella_idle_offset_flipped
		walk_texture = umbrella_walk_texture
		walk_frames = umbrella_walk_frames
		walk_fps = umbrella_walk_fps
		walk_offset = umbrella_walk_offset
		walk_offset_flipped = umbrella_walk_offset_flipped
		speed = umbrella_speed
		step_frames = umbrella_step_frames
		_phone = Phone.NONE                    # มือถือร่มอยู่: เก็บโทรศัพท์ทันที
	else:
		for key in _plain:
			set(key, _plain[key])
	_still_time = 0.0
	_last_frame = -1
	if is_inside_tree():
		_set_pose(false, _facing_right)


func _ready() -> void:
	_phone_wait = randf_range(phone_after.x, phone_after.y)
	_set_pose(false, false)


func _process(delta: float) -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	if dir == 0.0:
		dir = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	if dir == 0.0:
		dir = touch_dir
	if _phone != Phone.NONE and _update_phone(delta, dir):
		return
	position.x += dir * speed * delta
	if dir != 0.0:
		_facing_right = dir > 0.0
		_still_time = 0.0
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
		_still_time += delta
		_blink_wait -= delta
		if _blink_wait <= 0.0:
			_blink_left = blink_time
			_blink_wait = randf_range(blink_every.x, blink_every.y)
		_blink_left -= delta
		# ยืนนานพอแล้ว: รอให้ท่ายืนวนมาถึงเฟรมที่ตรงกับท่าโทรศัพท์ แล้วเริ่มหยิบ
		if phone_texture and not umbrella and _still_time >= _phone_wait and _idle_frame() == phone_from_idle_frame:
			_phone = Phone.TAKING_OUT
			_phone_time = 0.0
			_set_phone_pose(0)
			return
		_set_pose(false, _facing_right)


## เล่นท่าโทรศัพท์ คืน true ถ้ายังอยู่ในท่านี้ (ตัวละครยังไม่เดิน)
func _update_phone(delta: float, dir: float) -> bool:
	_phone_time += delta
	var frame := 0
	if _phone != Phone.PUTTING_AWAY and dir != 0.0:
		_put_away_from = _phone_frame()
		if _put_away_from >= phone_take_out:
			_put_away_from = phone_take_out - 1      # ท่าถือทุกเฟรมใกล้กับเฟรมสุดท้ายของท่าหยิบ
		_phone = Phone.PUTTING_AWAY
		_phone_time = 0.0
	if _phone == Phone.PUTTING_AWAY:
		frame = _put_away_from - int(_phone_time * phone_fps) * phone_put_away_step
		if frame < 0:
			# เก็บเสร็จ: กลับเป็นท่ายืนที่เฟรมเดียวกับที่สลับเข้ามา แล้วเริ่มนับใหม่
			_phone = Phone.NONE
			_idle_time = (phone_from_idle_frame + 0.5) / idle_fps if idle_fps > 0.0 else 0.0
			_still_time = 0.0
			_phone_wait = randf_range(phone_after.x, phone_after.y)
			return false
	else:
		frame = _phone_frame()
		if _phone == Phone.TAKING_OUT and frame >= phone_take_out:
			_phone = Phone.HOLDING
	_set_phone_pose(frame)
	return true


## เฟรมของท่าโทรศัพท์ตอนหยิบ/ถือ: หยิบเล่นครั้งเดียว ถือเล่นไป-กลับวน
func _phone_frame() -> int:
	var f := int(_phone_time * phone_fps)
	if f < phone_take_out:
		return f
	var span := phone_frames - 1 - phone_take_out
	if span <= 0:
		return phone_frames - 1
	var k := (f - phone_take_out) % (2 * span)
	return phone_take_out + (k if k <= span else 2 * span - k)


func _set_phone_pose(frame: int) -> void:
	for sprite in [_body, _reflection]:
		sprite.texture = phone_texture
		sprite.hframes = phone_frames
		sprite.frame = clampi(frame, 0, phone_frames - 1)
		sprite.offset = phone_offset_flipped if _facing_right else phone_offset
		if sprite == _body:
			sprite.offset.y += ground_row - (phone_texture.get_height() - 1)
		sprite.flip_h = _facing_right


func _set_pose(walking: bool, facing_right: bool) -> void:
	for sprite in [_body, _reflection]:
		if walking and walk_texture:
			sprite.texture = walk_texture
			sprite.hframes = walk_frames
			sprite.frame = int(_anim_time * walk_fps) % walk_frames
			sprite.offset.x = walk_offset_flipped.x if facing_right else walk_offset.x
			sprite.flip_h = facing_right
			# ให้เท้าอยู่แถว ground_row (เงาสะท้อนวาดกลับหัวจากเท้า จึงไม่ต้องเลื่อน)
			if sprite == _body:
				sprite.offset.y = ground_row - (walk_texture.get_height() - 1)
		elif idle_texture:
			sprite.texture = idle_texture
			sprite.hframes = idle_frames
			sprite.frame = _idle_frame()
			# ภาพยืนต้นฉบับหันซ้ายเหมือนท่าเดิน
			sprite.offset = idle_offset_flipped if facing_right else idle_offset
			if sprite == _body:
				sprite.offset.y += ground_row - (idle_texture.get_height() - 1)
			sprite.flip_h = facing_right


## เฟรมของท่ายืนตอนนี้: ท่าหายใจตามเวลา (+3 ถ้ากำลังกะพริบตา)
func _idle_frame() -> int:
	if idle_fps > 0.0:
		return int(_idle_time * idle_fps) % idle_frames
	if idle_frames < 6:
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
	return pose + (3 if _blink_left > 0.0 else 0)
