class_name Kitten
extends Node2D
## ลูกแมวตัวเปียกนั่งอยู่บนทางเท้าก่อนถึงทางม้าลาย หันมาทางซัน (ภาพจาก tools/make_kitten.py)
## ซันเดินมาใกล้ = noticed (prologue.gd หยุดเดิน ขึ้นปุ่ม "ทักลูกแมว") กดปุ่มหรือแตะที่ลูกแมว (tapped)
## แล้ว prologue ขึ้นความคิด "มาทำอะไรตรงนี้นะ" และ run_away(): ร้องแล้ววิ่งหนีไปทางซ้าย

signal noticed
## แตะที่ลูกแมวหลังซันเห็นมันแล้ว (ใช้แทนการกดปุ่มได้)
signal tapped

const SHEET := preload("res://assets/characters/kitten.png")
const MEOW := preload("res://assets/audio/meow.ogg")
const FRAMES := 10
## เฟรมนั่ง (ส่วนใหญ่นิ่ง หางกระดิก กะพริบตา) 2.5 เฟรม/วินาที, เฟรมวิ่ง 4-9 (ควบหนึ่งก้าว) 12 เฟรม/วินาที
const SIT := [0, 0, 1, 0, 3, 0, 0, 2]
const RUN_FPS := 12.0
## วิ่งเร็วเท่าก้าว: ควบหนึ่งรอบ (6 เฟรม = 0.5 วินาที) ไปได้ราว 1.8 เท่าความยาวตัว เท้าไม่ไถล
const RUN_SPEED := 110.0

var hero: Node2D
## ซันเข้ามาใกล้เท่านี้ (พิกเซล) แล้วสังเกตเห็นเอง ถ้ายังไม่ได้แตะ
var notice_distance := 70.0

var _sprite: Sprite2D
var _frame := Vector2.ZERO
var _time := 0.0
var _noticed := false
var _running := false
var _from := 0.0
var _meow: AudioStreamPlayer2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.hframes = FRAMES
	_sprite.centered = false
	_frame = Vector2(SHEET.get_width() / FRAMES, SHEET.get_height())
	_sprite.offset = Vector2(-_frame.x / 2.0, -_frame.y)      # จุดอ้างอิงที่เท้า (กลางล่าง)
	add_child(_sprite)
	_meow = AudioStreamPlayer2D.new()
	_meow.stream = MEOW
	_meow.volume_db = -6.0
	add_child(_meow)


func _process(delta: float) -> void:
	_time += delta
	if _running:
		position.x -= RUN_SPEED * delta
		_sprite.frame = 4 + int(_time * RUN_FPS) % 6
		if _from - position.x > 420.0:
			queue_free()
		return
	_sprite.frame = SIT[int(_time * 2.5) % SIT.size()]
	if not _noticed and hero and absf(hero.position.x + 10.0 - position.x) < notice_distance:
		_notice()


## แตะที่ลูกแมว (เมาส์หรือนิ้ว) หลังซันเห็นมันแล้ว
func _unhandled_input(event: InputEvent) -> void:
	if not _noticed or _running or not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var rect := Rect2(global_position + _sprite.offset, _frame).grow(10.0)
		var at := get_canvas_transform().affine_inverse() * (event as InputEventMouseButton).position   # จอ -> โลก
		if rect.has_point(at):
			get_viewport().set_input_as_handled()
			tapped.emit()


func _notice() -> void:
	_noticed = true
	noticed.emit()


func run_away() -> void:
	if _running:
		return
	_running = true
	_time = 0.0
	_from = position.x
	_sprite.flip_h = true                                    # ภาพหันขวา วิ่งหนีไปทางซ้าย
	_meow.play()
