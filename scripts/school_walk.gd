class_name SchoolWalk
extends Node
## ตอนที่1 ต่อจากข้ามทางม้าลาย (ต้นฉบับ: "ฝนก็ยังเทลงมาไม่หยุด..." ถึง "สรุปแล้ว... ยัยนี่เป็นใครกันแน่?")
## ทั้งคู่เดินใต้ร่มเดียวกันเลียบกำแพงโรงเรียน (มุมข้าง ขวาไปซ้ายเหมือนถนน ผู้เล่นเดินเอง สายฝนเดินข้างๆ)
## ความคิดขึ้นเองตามระยะ (บท "school" + "at") บรรทัด event "glance" = ภาพใกล้หน้าเธอ (ซันแอบมอง) จนบรรทัดนั้นจบ
## ถึงประตูโรงเรียน: บท "gate" (ซัน: "นี่..." event "leave" = เธอเดินเข้าประตูหายไป) แล้ว "gate_after"
## ฉากหลัง: tools/compose_school.py (ภาพหน้าโรงเรียนจากผู้เขียน กลับซ้ายขวา ต่อกำแพงให้ยาว)

signal left                                     # สายฝนเดินเข้าประตูหายไปแล้ว

const BG := preload("res://assets/bg/school/school_front.png")
const SMOOTH_PIXEL := preload("res://shaders/smooth_pixel.gdshader")
## ชั้นของฉากถนนที่ซ่อน (ฉากนี้ใช้ภาพหน้าโรงเรียนภาพเดียว ฝน/โทนสี/ตัวละครใช้ของเดิม)
const STREET := [^"Sky", ^"Wisps", ^"City", ^"HazeFar", ^"Birds", ^"Railway", ^"TrainLayer", ^"HazeNear",
		^"SunLight", ^"SkyReflection", ^"CityReflection", ^"RailReflection", ^"TrainReflectionLayer", ^"Road",
		^"Crosswalk", ^"Signal", ^"Foreground", ^"Dust"]
## ภาพกว้าง 2516: เริ่มทางขวา (จอยังไม่เลยขอบภาพ) หยุดเมื่อเธอ (ข้างหน้าซัน 18px) อยู่ข้างประตู
## ประตูเปิดอยู่ที่ x 593-774 (กลาง 684: compose_school.py) เดิน 1370px ~28 วินาที
const START_X := 2150.0
const STOP_X := 780.0
const GATE_X := 684.0
const UNDER := -5.0                             # สายฝนเดินเคียงข้างซัน (ไม่นำหน้า) ใต้ร่มเดียวกัน
## เธออยู่ฝั่งถนน: เท้าต่ำกว่าตำแหน่งเดิม (161 ใน main.tscn) 4px ใกล้กล้องกว่า
const ROAD_Y := 165.0
## เดินช้ากว่าเดินคนเดียว (54) ให้ใกล้ความเร็วก้าวของเธอ (44): ท่าเดินซันเล่นช้าลงตามสัดส่วน เท้าไม่ไถล
const SPEED := 48.0
## แอบมอง: ภาพใกล้หน้าเธอจากผู้เขียน (art_source/heroine_glance_rain.png ย่อเป็น 640x400) จางเข้าทับฉาก
## ค่อยๆ เลื่อนลงช้าๆ ระหว่างบรรทัด แล้วจางออก (ชั้น 25: ใต้กล่องข้อความ)
const GLANCE := preload("res://assets/characters/closeup/heroine_glance.png")
const GLANCE_FADE := 0.5
const GLANCE_DRIFT := 40.0

var prologue: Node
var hero: Node2D
var heroine: Node2D
var camera: Camera2D
var dialogue_box: DialogueBox
var cards: Node

var _glance := false
var _glance_layer: CanvasLayer
var _glance_image: TextureRect
var _glance_tween: Tween


## ใต้จอดำ: เปลี่ยนฉากเป็นหน้าโรงเรียน วางทั้งคู่ทางขวา
func setup() -> void:
	var main := prologue.get_parent()
	for path in STREET:
		var node := main.get_node_or_null(path)
		if node:
			node.visible = false
			node.process_mode = Node.PROCESS_MODE_DISABLED
	var bg := Sprite2D.new()
	bg.texture = BG
	bg.centered = false
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var smooth := ShaderMaterial.new()
	smooth.shader = SMOOTH_PIXEL
	bg.material = smooth
	main.add_child(bg)
	main.move_child(bg, hero.get_parent().get_index())       # หลังตัวละคร
	hero.speed = SPEED
	hero.walk_fps = hero.umbrella_walk_fps * SPEED / hero.umbrella_speed
	hero.position.x = START_X
	hero.min_x = STOP_X
	hero.max_x = START_X
	heroine.follow(hero, UNDER)
	# เธอเดินข้างขวาของซัน (ต้นฉบับ: เสียงดังมา "จากด้านขวา") = ฝั่งถนน ใกล้กล้องกว่า: วาดทับซัน ต่ำลงนิดหน่อย
	heroine.z_index = 1
	heroine.position.y = ROAD_Y
	camera.pan_to(320.0)
	dialogue_box.set_subtitles(false)
	dialogue_box.line_started.connect(_on_line)


func play() -> void:
	await cards.reveal_scene()
	await _walk_to_gate()
	await prologue._say("gate")
	if heroine.visible:
		await left
	await get_tree().create_timer(0.6).timeout
	await prologue._say("gate_after")
	await get_tree().create_timer(0.8).timeout
	dialogue_box.line_started.disconnect(_on_line)


func _walk_to_gate() -> void:
	hero.controllable = true
	prologue._set_touch(true)
	prologue._show_hint()
	var thoughts: Array = prologue._lines.get("school", []).duplicate()
	while hero.position.x > STOP_X + 0.5:
		var walked := (START_X - hero.position.x) / (START_X - STOP_X)
		if not dialogue_box.visible:
			_set_glance(false)
			for line in thoughts:
				if walked >= float(line.get("at", 0.0)):
					thoughts.erase(line)
					dialogue_box.start([line])
					break
		if absf(hero.position.x - START_X) > 40.0:
			prologue._hide_hint()
		await get_tree().process_frame
	prologue._hide_hint()
	hero.controllable = false
	hero.touch_dir = 0.0
	prologue._set_touch(false)
	if dialogue_box.visible:
		await dialogue_box.finished
	_set_glance(false)
	await get_tree().create_timer(0.5).timeout


## ภาพใกล้หน้าเธอจางเข้า (ซันแอบมอง ทั้งคู่ยังเดินต่อข้างหลัง) / จางออกกลับมุมข้าง
func _set_glance(on: bool) -> void:
	if on == _glance:
		return
	_glance = on
	if _glance_layer == null:
		_glance_layer = CanvasLayer.new()
		_glance_layer.layer = 25
		add_child(_glance_layer)
		_glance_image = TextureRect.new()
		_glance_image.texture = GLANCE
		_glance_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_glance_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glance_image.modulate.a = 0.0
		_glance_layer.add_child(_glance_image)
	if _glance_tween:
		_glance_tween.kill()
	_glance_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	if on:
		_glance_image.position = Vector2(0.0, -GLANCE_DRIFT)
		_glance_tween.tween_property(_glance_image, "modulate:a", 1.0, GLANCE_FADE)
		_glance_tween.tween_property(_glance_image, "position:y", 0.0, 6.0)
	else:
		_glance_tween.tween_property(_glance_image, "modulate:a", 0.0, GLANCE_FADE)


func _on_line(line: Dictionary) -> void:
	match str(line.get("event", "")):
		"glance":
			_set_glance(true)
		"leave":
			_leave()


## "นี่..." ยังไม่ทันพูดต่อ เธอเดินเข้าประตูไป: เดินไปตรงประตู แล้วเดินลึกเข้าไปพร้อมจางหาย
func _leave() -> void:
	heroine.stop_following()
	heroine.walk_to(GATE_X)
	await heroine.arrived
	heroine.walk_to(GATE_X - 24.0)
	var fade := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	fade.tween_property(heroine, "position:y", heroine.position.y - 10.0, 1.4)
	fade.tween_property(heroine, "modulate:a", 0.0, 1.4)
	await fade.finished
	heroine.visible = false
	left.emit()
