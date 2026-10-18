class_name SchoolWalk
extends Node
## ตอนที่1 ต่อจากข้ามทางม้าลาย (ต้นฉบับ: "ฝนก็ยังเทลงมาไม่หยุด..." ถึง "สรุปแล้ว... ยัยนี่เป็นใครกันแน่?")
## ทั้งคู่เดินใต้ร่มเดียวกันเลียบกำแพงโรงเรียน (มุมข้าง ขวาไปซ้ายเหมือนถนน ผู้เล่นเดินเอง สายฝนเดินข้างๆ)
## ความคิดขึ้นเองตามระยะ (บท "school" + "at") บรรทัด event "glance" = ตัดแคบหน้าเธอ (ซันแอบมอง) จนบรรทัดนั้นจบ
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
## ประตูเปิดอยู่ที่ x 593-829 (กลาง 711: compose_school.py) เดิน 1360px ~28 วินาที
const START_X := 2150.0
const STOP_X := 790.0
const GATE_X := 711.0
const UNDER := -18.0                            # สายฝนเดินข้างหน้าซันนิดเดียว ใต้ร่มเดียวกัน (เท่าตอนยืนรอไฟ)
## เดินช้ากว่าเดินคนเดียว (54) ให้ใกล้ความเร็วก้าวของเธอ (44): ท่าเดินซันเล่นช้าลงตามสัดส่วน เท้าไม่ไถล
const SPEED := 48.0
## แอบมอง: ซูมเท่านี้ หน้าเธอ (จากตำแหน่งตัว) อยู่ค่อนบนจอ เหนือกล่องข้อความ
const GLANCE_ZOOM := 3.2
const FACE := Vector2(15.0, 26.0)
const FACE_ON_SCREEN_Y := 120.0

var prologue: Node
var hero: Node2D
var heroine: Node2D
var camera: Camera2D
var dialogue_box: DialogueBox
var cards: Node

var _glance := false


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
		if _glance:
			camera.position = heroine.position + FACE + Vector2(0.0, (180.0 - FACE_ON_SCREEN_Y) / GLANCE_ZOOM)
		await get_tree().process_frame
	prologue._hide_hint()
	hero.controllable = false
	hero.touch_dir = 0.0
	prologue._set_touch(false)
	if dialogue_box.visible:
		await dialogue_box.finished
	_set_glance(false)
	await get_tree().create_timer(0.5).timeout


## แคบหน้าเธอ (ตามเธอไปขณะเดิน) / กลับมุมข้าง
func _set_glance(on: bool) -> void:
	if on == _glance:
		return
	_glance = on
	camera.set_process(not on)
	camera.zoom = Vector2.ONE * (GLANCE_ZOOM if on else 1.0)
	if not on:
		camera.position.y = 180.0


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
