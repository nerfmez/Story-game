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
## เสียงรถไฟ (วนซ้ำ) ได้ยินเฉพาะตอนเห็นขบวนบนจอ: ค่อยๆ ดังขึ้นตอนโผล่เข้าจอ
## ดังสุดตอนอยู่กลางจอ แล้วเบาลงจนเงียบตอนพ้นจอ
@export var sound: AudioStreamPlayer
## ระดับเสียงเมื่ออยู่กลางจอ / เมื่อเพิ่งโผล่ที่ขอบจอ (dB)
@export var near_db := -4.0
@export var edge_db := -16.0

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
	if sound:
		sound.volume_db = -80.0
		sound.play()


func _process(delta: float) -> void:
	if not _running:
		_idle_time += delta
		if auto_interval > 0.0 and _idle_time >= auto_interval:
			pass_by()
		return
	position.x += speed * delta
	if sound:
		_update_sound()
	var gone := _screen_x() > get_viewport_rect().size.x + 8.0 if across_screen else position.x > end_x
	if gone:
		_running = false
		visible = false
		if sound:
			sound.stop()


## ตำแหน่ง x บนจอ (หลังคิด parallax และกล้องแล้ว) ของขอบซ้ายรถไฟ
func _screen_x() -> float:
	return get_global_transform_with_canvas().origin.x


func _update_sound() -> void:
	var view_w := get_viewport_rect().size.x
	var left := _screen_x()
	var right := left + texture.get_width()
	# ส่วนของขบวนที่เห็นบนจอ (พิกเซล): 0 = ยังไม่โผล่/พ้นจอแล้ว -> เงียบ
	var shown := minf(right, view_w) - maxf(left, 0.0)
	if shown <= 0.0:
		sound.volume_db = -80.0
		return
	# ระยะจากกลางจอถึงส่วนที่ใกล้ที่สุดของขบวน
	var centre := view_w * 0.5
	var dist := 0.0 if left <= centre and centre <= right else minf(absf(left - centre), absf(right - centre))
	var db := lerpf(near_db, edge_db, clampf(dist / centre, 0.0, 1.0))
	# ค่อยๆ ดังขึ้นในช่วง 120 พิกเซลแรกที่โผล่เข้ามา (และค่อยๆ เงียบตอนออก)
	sound.volume_db = db + linear_to_db(clampf(shown / 120.0, 0.02, 1.0))
