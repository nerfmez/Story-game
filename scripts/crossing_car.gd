class_name CrossingCar
extends Node2D
## รถที่วิ่งผ่านเลนใกล้กล้อง (ระหว่างกล้องกับซัน) ตอนเดินไปทางม้าลาย: อยู่ใกล้กล้องจึงเป็นเงาดำเบลอขนาดใหญ่
## เห็นแค่หลังคา กระจก และขอบบนตัวรถ (ที่เหลือล้นขอบล่างจอ) ไฟหน้า/ไฟท้ายฟุ้ง น้ำกระเด็นจากล้อขึ้นไปทางทางเท้า
## ภาพจาก tools/make_car.py เสียงจาก tools/make_audio.py (car_pass.ogg)

## หน้ารถผ่านตำแหน่ง drive_by(target_x) (ซันสะดุ้ง)
signal passing

const CAR := preload("res://assets/props/car_silhouette.png")
const GLOW := preload("res://assets/props/glow.png")
const SOUND := preload("res://assets/audio/car_pass.ogg")
const SPEED := 620.0
## แถวในโลก (= บนจอ: กล้องอยู่แถว 180) ที่หลังคารถอยู่ ตัวรถที่เหลือล้นขอบล่างจอ
const TOP_Y := 262.0
## ไฟหน้า / ไฟท้าย และล้อ ในภาพรถ (300x112)
const HEADLIGHT := Vector2(296, 65)
const TAIL_LIGHT := Vector2(9, 65)
const WHEELS := [Vector2(60, 88), Vector2(240, 88)]

var camera: Node2D

var _target := 0.0
var _running := false
var _passed := false
var _sprays: Array[CPUParticles2D] = []
var _sound: AudioStreamPlayer2D


func _ready() -> void:
	visible = false
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for w in WHEELS:
		var spray := CPUParticles2D.new()
		spray.position = w
		spray.emitting = false
		spray.amount = 80
		spray.lifetime = 0.75
		spray.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		spray.emission_rect_extents = Vector2(26, 2)
		spray.direction = Vector2(-0.35, -1.0)
		spray.spread = 18.0
		spray.initial_velocity_min = 260.0
		spray.initial_velocity_max = 420.0
		spray.gravity = Vector2(0, 760)
		spray.scale_amount_min = 1.5
		spray.scale_amount_max = 2.5
		spray.color = Color(0.8, 0.86, 0.97, 0.6)
		spray.show_behind_parent = true                # น้ำอยู่หลังตัวรถ (ฝั่งทางเท้า) เห็นแค่ที่พุ่งเหนือหลังคา
		add_child(spray)
		_sprays.append(spray)
	var body := Sprite2D.new()
	body.texture = CAR
	body.centered = false
	add_child(body)
	for light in [[HEADLIGHT, Color(1.0, 0.92, 0.75, 0.75), 3.2], [TAIL_LIGHT, Color(1.0, 0.25, 0.22, 0.6), 1.6]]:
		var glow := Sprite2D.new()
		glow.texture = GLOW
		glow.material = add
		glow.position = light[0]
		glow.modulate = light[1]
		glow.scale = Vector2(light[2] * 1.6, light[2])
		add_child(glow)
	_sound = AudioStreamPlayer2D.new()
	_sound.stream = SOUND
	_sound.volume_db = -3.0
	_sound.max_distance = 2000.0
	add_child(_sound)


## วิ่งผ่านจากซ้ายไปขวาทั้งจอ ส่ง passing ตอนหน้ารถผ่าน target_x
func drive_by(target_x: float) -> void:
	_target = target_x
	position = Vector2(camera.position.x - 320.0 - CAR.get_width() - 20.0, TOP_Y)   # เพิ่งพ้นขอบซ้ายจอ
	visible = true
	_running = true
	_passed = false
	for spray in _sprays:
		spray.emitting = true
	_sound.play()


func _process(delta: float) -> void:
	if not _running:
		return
	position.x += SPEED * delta
	if not _passed and position.x + HEADLIGHT.x >= _target:
		_passed = true
		passing.emit()
	if position.x > camera.position.x + 320.0 + 40.0:
		_running = false
		for spray in _sprays:
			spray.emitting = false
		await get_tree().create_timer(1.0).timeout   # น้ำที่กระเด็นแล้วตกลงให้หมดก่อน
		visible = false
