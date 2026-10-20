class_name SchoolWalk
extends Node
## ตอนที่1 ต่อจากข้ามทางม้าลาย (ต้นฉบับ: "ฝนก็ยังเทลงมาไม่หยุด..." ถึง "สรุปแล้ว... ยัยนี่เป็นใครกันแน่?")
## ทั้งคู่เดินใต้ร่มเดียวกันเลียบกำแพงโรงเรียน (มุมข้าง ผู้เล่นเดินเอง สายฝนเดินข้างๆ) ข้ามถนนมาแล้วเดินต่อไปข้างหน้า
## มองจากอีกฝั่งถนนจึงเดินซ้ายไปขวา ซันชิดกำแพง สายฝนฝั่งถนน
## ความคิดขึ้นเองตามระยะ (บท "school" + "at") บรรทัด event "glance" = ภาพใกล้หน้าเธอ (ซันแอบมอง) จนบรรทัดนั้นจบ
## ถึงประตูโรงเรียน: บท "gate" แล้วตัดภาพไปหน้าอาคาร (โมเดล 3D มุมข้างตามขนาดตัวละคร): ทั้งคู่เดินใต้ร่มมาถึงหลังคา
## ทางเข้า บท "entrance" (ซัน: "นี่..." event "leave" = เธอไม่ต้องพึ่งร่มแล้ว เดินขึ้นบันไดเข้าอาคารหายไปก่อน) แล้ว "gate_after"
## ฉากหลัง: tools/compose_school.py (ภาพหน้าโรงเรียนจากผู้เขียน กลับซ้ายขวา ต่อกำแพงให้ยาว)
## ตัวตึกหลังกำแพงคือโมเดล 3D (SchoolModel3D ผ่าน SchoolBuildingView) วางใต้ชั้นต้นไม้+กำแพง (tools/cut_school_wall.py)
## กล้อง 3D เลื่อนตามกล้องเกม: ตึกอยู่ไกลกว่ากำแพงจึงเลื่อนช้ากว่า มองผ่านประตูเห็นทางเข้าอาคาร

signal left                                     # สายฝนเดินเข้าอาคารหายไปแล้ว

const BG := preload("res://assets/bg/school/school_wall.png")
const SMOOTH_PIXEL := preload("res://shaders/smooth_pixel.gdshader")
## ชั้นของฉากถนนที่ซ่อน (ฉากนี้ใช้ภาพหน้าโรงเรียนภาพเดียว ฝน/โทนสี/ตัวละครใช้ของเดิม)
const STREET := [^"Sky", ^"Wisps", ^"City", ^"HazeFar", ^"Birds", ^"Railway", ^"TrainLayer", ^"HazeNear",
		^"SunLight", ^"SkyReflection", ^"CityReflection", ^"RailReflection", ^"TrainReflectionLayer", ^"Road",
		^"Crosswalk", ^"Signal", ^"Foreground", ^"Dust"]
## ภาพกว้าง 2516: เริ่มทางซ้าย (จอยังไม่เลยขอบภาพ) หยุดเมื่อทั้งคู่อยู่ข้างประตูทางขวา
## ประตูเปิดอยู่ที่ x 1741-1922 (กลาง 1832: compose_school.py) เดิน 1370px ~28 วินาที
const START_X := 360.0
const STOP_X := 1730.0
const GATE_X := 1832.0
## ตึก 3D: ขนาด 15 px/ม. ตรงตึก (ชั้นละ ~50px หลังคาพ้นขอบจอ) โคนตึกอยู่แถว 200 (หลังกำแพง แถว 129-255)
## ตัวละครสูง 1.72 ม. = 120px: กล้องเกมเลื่อน 70px = กล้อง 3D เลื่อน 1 ม.
## ประตูโรงเรียนอยู่ตรงแนวทางเดินเข้าอาคาร (x 0 ของโมเดล): ยืนตรงประตูก็มองเห็นทางเดินตรงเข้าไปถึงทางเข้า
const BUILDING_PPM := 15.0
const GROUND_ROW := 200.0
const HERO_PPM := 70.0
## หน้าอาคาร: ทางเข้า (x 0 ของโมเดล) อยู่ที่ x 2D นี้ ทั้งคู่เดินเลียบหน้าอาคารบนลานปูน (z ENTRANCE_Z หน้าบันได
## ทางเข้า) ตัวละครอยู่ที่ระยะนั้นพอดี: 70px/ม. เท้าแถว 273 (กล้องกว้างขึ้นให้อยู่หน้าแนวพุ่มไม้ z 7.3: ไม่บังจอ)
const ENTRANCE_X := 1000.0
const ENTRANCE_Z := 3.3
const ENTRANCE_FOV := 66.0
const FEET_ROW := 273.0
const ENTRANCE_START := ENTRANCE_X - 520.0
const ENTRANCE_STOP := ENTRANCE_X - 100.0
## เธอเดินถึงกลางทางเข้า แล้วขึ้นบันไดลึกเข้าไปในโถง (สูงขึ้นบนจอ) พร้อมจางหาย
const STEP_UP := 26.0
## ฝนหนักหน้าโรงเรียน: ตึกจมหมอกสีเดียวกับฟ้าของฉาก (ฟ้าฝน 8494aa ของ draw_school_building.py) มืดลงกว่าตอนมองใกล้
const RAIN_SKY := Color("8494aa")
const RAIN_FOG := 0.03
const RAIN_EXPOSURE := 0.85
const UNDER := -5.0                             # สายฝนเดินเคียงข้างซัน ใต้ร่มเดียวกัน
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

var _view: SchoolBuildingView
var _bg: Sprite2D
var _entrance := false
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
	_bg = bg
	bg.texture = BG
	bg.centered = false
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var smooth := ShaderMaterial.new()
	smooth.shader = SMOOTH_PIXEL
	bg.material = smooth
	main.add_child(bg)
	main.move_child(bg, hero.get_parent().get_index())       # หลังตัวละคร
	var back := CanvasLayer.new()
	back.layer = -1                                          # ใต้ฉากเกมทั้งหมด
	add_child(back)
	_view = SchoolBuildingView.new()
	back.add_child(_view)
	var env := _view.environment
	env.fog_light_color = RAIN_SKY
	env.fog_density = RAIN_FOG
	env.tonemap_exposure = RAIN_EXPOSURE
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color = RAIN_SKY
	sky.sky_horizon_color = RAIN_SKY.lightened(0.08)
	_follow_camera()
	hero.speed = SPEED
	hero.walk_fps = hero.umbrella_walk_fps * SPEED / hero.umbrella_speed
	hero.position.x = START_X
	hero.min_x = START_X
	hero.max_x = STOP_X
	heroine.follow(hero, UNDER)
	# เธอเดินข้างขวาของซัน (ต้นฉบับ: เสียงดังมา "จากด้านขวา") = ฝั่งถนน ใกล้กล้องกว่า: วาดทับซัน ต่ำลงนิดหน่อย
	heroine.z_index = 1
	heroine.position.y = ROAD_Y
	camera.pan_to(320.0)
	dialogue_box.set_subtitles(false)
	dialogue_box.line_started.connect(_on_line)


func _process(_delta: float) -> void:
	if _view:
		_follow_camera()


## กล้อง 3D มองตรงไปที่หน้าตึก ห่างพอให้ได้ BUILDING_PPM สูงพอให้โคนตึกอยู่ที่ GROUND_ROW
## หน้าอาคาร: ห่างจากแนวเดินพอให้ได้ HERO_PPM เท้าตัวละครอยู่บนพื้นที่ FEET_ROW
func _follow_camera() -> void:
	var cam := _view.camera
	var half_h := 180.0
	if _entrance:
		var near := half_h / (HERO_PPM * tan(deg_to_rad(cam.fov * 0.5)))
		var at := camera.get_screen_center_position().x
		cam.position = Vector3((at - ENTRANCE_X) / HERO_PPM, (FEET_ROW - half_h) / HERO_PPM, ENTRANCE_Z + near)
		cam.rotation = Vector3.ZERO
		return
	var distance := half_h / (BUILDING_PPM * tan(deg_to_rad(cam.fov * 0.5)))
	var centre := camera.get_screen_center_position().x
	var x := (centre - GATE_X) / HERO_PPM
	var y := (GROUND_ROW - half_h) / BUILDING_PPM
	cam.position = Vector3(x, y, distance)
	cam.rotation = Vector3.ZERO


func play() -> void:
	await cards.reveal_scene()
	await _walk_to_gate()
	await prologue._say("gate")
	await cards.fade_to_black()
	_to_entrance()
	await cards.reveal_scene()
	hero.walk_to(ENTRANCE_STOP)
	await hero.arrived
	await get_tree().create_timer(0.5).timeout
	await prologue._say("entrance")
	if heroine.visible:
		await left
	await get_tree().create_timer(0.6).timeout
	await prologue._say("gate_after")
	await get_tree().create_timer(0.8).timeout
	dialogue_box.line_started.disconnect(_on_line)


## ใต้จอดำ: ไปหน้าอาคาร (ไม่มีกำแพง) ทั้งคู่ยืนทางซ้ายของทางเข้า
func _to_entrance() -> void:
	_entrance = true
	_bg.visible = false
	_view.camera.fov = ENTRANCE_FOV
	hero.min_x = ENTRANCE_START
	hero.max_x = ENTRANCE_STOP
	hero.position.x = ENTRANCE_START
	heroine.position.x = ENTRANCE_START + UNDER
	heroine.follow(hero, UNDER)
	_follow_camera()


func _walk_to_gate() -> void:
	hero.controllable = true
	prologue._set_touch(true)
	prologue._show_hint("เดินไปโรงเรียน  ▶")
	var thoughts: Array = prologue._lines.get("school", []).duplicate()
	while hero.position.x < STOP_X - 0.5:
		var walked := (hero.position.x - START_X) / (STOP_X - START_X)
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


## "นี่..." ยังไม่ทันพูดต่อ เธอออกจากร่มไปใต้หลังคาทางเข้า (ไม่ต้องพึ่งร่มแล้ว) เดินขึ้นบันไดลึกเข้าโถงพร้อมจางหาย
func _leave() -> void:
	heroine.stop_following()
	heroine.walk_to(ENTRANCE_X)
	await heroine.arrived
	heroine.walk_to(ENTRANCE_X + 20.0)
	var fade := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	fade.tween_property(heroine, "position:y", heroine.position.y - STEP_UP, 1.6)
	fade.tween_property(heroine, "modulate:a", 0.0, 1.6)
	await fade.finished
	heroine.visible = false
	left.emit()
