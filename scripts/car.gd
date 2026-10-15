extends Node2D
## รถยนต์ขับผ่านถนนเลนหน้าเป็นครั้งคราว สุ่มสี (เฟรมใน car.png) และทิศทาง
## ตำแหน่งของโหนดนี้ = จุดที่ล้อแตะถนน (Body วาดขึ้นไปด้านบน, Reflection เงาสะท้อนลงด้านล่าง)
## เสียงดังตามส่วนที่เห็นบนจอแบบเดียวกับรถไฟ และเสียงสูงขึ้นนิดตอนวิ่งเข้าหา ต่ำลงตอนผ่านไปแล้ว

## ขับผ่านทุกๆ กี่วินาที (สุ่มในช่วงนี้)
@export var interval := Vector2(15.0, 35.0)
## ความเร็ว (พิกเซล/วินาที สุ่มในช่วงนี้)
@export var speed_range := Vector2(230.0, 300.0)
@export var sound: AudioStreamPlayer
@export var near_db := -6.0
@export var edge_db := -20.0
## เสียงสูง/ต่ำสุดตอนเข้าหา/ผ่านไป (ดอปเพลอร์)
@export var doppler := 0.06

@onready var _body: Sprite2D = $Body
@onready var _reflection: Sprite2D = $Reflection

var _running := false
var _wait := 0.0
var _dir := 1.0
var _speed := 260.0


func _ready() -> void:
	visible = false
	_wait = randf_range(interval.x, interval.y)


func drive_by() -> void:
	_dir = 1.0 if randf() < 0.5 else -1.0
	_speed = randf_range(speed_range.x, speed_range.y)
	var paint := randi() % _body.hframes
	for sprite in [_body, _reflection]:
		sprite.frame = paint
		sprite.flip_h = _dir < 0.0          # ภาพหันขวา: วิ่งซ้ายพลิกภาพ
	# เริ่มนอกจอด้านที่วิ่งเข้ามา
	var start := -_width() - 8.0 if _dir > 0.0 else get_viewport_rect().size.x + 8.0
	position.x += start - _screen_x()
	visible = true
	_running = true
	if sound:
		sound.volume_db = -80.0
		sound.play()


func _process(delta: float) -> void:
	if not _running:
		_wait -= delta
		if _wait <= 0.0:
			drive_by()
		return
	position.x += _dir * _speed * delta
	if sound:
		_update_sound()
	var left := _screen_x()
	var gone := left > get_viewport_rect().size.x + 8.0 if _dir > 0.0 else left + _width() < -8.0
	if gone:
		_running = false
		visible = false
		_wait = randf_range(interval.x, interval.y)
		if sound:
			sound.stop()


func _width() -> float:
	return _body.texture.get_width() / float(_body.hframes)


## ขอบซ้ายของรถบนจอ (หลังคิดกล้องแล้ว)
func _screen_x() -> float:
	return get_global_transform_with_canvas().origin.x + _body.position.x


func _update_sound() -> void:
	var view_w := get_viewport_rect().size.x
	var left := _screen_x()
	var right := left + _width()
	var shown := minf(right, view_w) - maxf(left, 0.0)
	if shown <= 0.0:
		sound.volume_db = -80.0
		return
	var centre := view_w * 0.5
	var dist := 0.0 if left <= centre and centre <= right else minf(absf(left - centre), absf(right - centre))
	var db := lerpf(near_db, edge_db, clampf(dist / centre, 0.0, 1.0))
	sound.volume_db = db + linear_to_db(clampf(shown / 120.0, 0.02, 1.0))
	# ดอปเพลอร์: ยังไม่ถึงกลางจอ = กำลังเข้าหา เสียงสูง, ผ่านไปแล้ว = เสียงต่ำ
	var ahead := -_dir * ((left + right) * 0.5 - centre)
	sound.pitch_scale = 1.0 + doppler * tanh(ahead / 150.0)
