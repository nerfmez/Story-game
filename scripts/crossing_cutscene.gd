class_name CrossingCutscene
extends Node
## ข้ามทางม้าลาย: ปุ่ม "ข้ามทางม้าลาย" แล้วตัดเป็นคัทซีนแบบหนัง
## ตัดผ่านจอดำ แล้วเป็นจอกว้างแบบหนัง: ฉากค่อยๆ หมุนเป็นมุมเฉียง (shaders/scene_turn.gdshader) ทั้งคู่เดินใต้ร่มเดียวกัน
## เข้าหากล้อง กล้องถอยตาม บทเป็นซับไตเติลในแถบล่าง
## (คลิปเดินคู่เดินเฉียงเข้าหากล้อง: assets/characters/pair_umbrella_walk.png 45 เฟรม 2 แถว 12 เฟรม/วินาที วนได้)
## ระหว่างนั้นบทขึ้นตามปกติ (prologue.gd เรียก play() แล้วเล่นบทเอง)

const PAIR := preload("res://assets/characters/pair_umbrella_walk.png")
const FONT := preload("res://assets/fonts/Sarabun-Regular.ttf")
const TURN := preload("res://shaders/scene_turn.gdshader")
const FRAMES := 45
const COLUMNS := 23
const FPS := 12.0
## เฟรมที่เท้าแตะพื้น (เสียงเท้า) 3 รอบก้าว รอบละ 15 เฟรม
const STEPS := [2, 9, 17, 24, 32, 39]
## แถบดำบน-ล่าง (จอกว้างแบบหนัง) บทพูดขึ้นเป็นซับไตเติลในแถบล่าง
const BAR := 50.0
## กล้องเริ่มที่ซูมนี้แล้วค่อยๆ ถอยออกเป็น 1 (ฉากหลังไกลออก = ทั้งคู่เดินเข้าหากล้อง)
const ZOOM_FROM := 1.25
## แถวบนจอ (640x360) ที่เท้าของทั้งคู่อยู่ตลอดช็อต
const FEET_ON_SCREEN := 300.0
## หมุนฉากเป็นมุมเฉียงทีละน้อยจนถึงมุมนี้ (ฝั่งขวาไกลออก) ให้เข้ากับท่าเดินเฉียงเข้าหากล้องของทั้งคู่
const YAW_TO := 24.0
## ขยายภาพฉากตอนหมุนสุด (กันขอบภาพโผล่ด้านที่ไกลออก)
const TURN_ZOOM := 1.34

signal pressed

var hero: Node2D
var heroine: Node2D
var camera: Camera2D
var ui: Node                                   # CanvasLayer ของกล่องข้อความ (ปุ่มอยู่ชั้นเดียวกัน)

var _pair: Sprite2D
var _feet := Vector2.ZERO
var _cam_x := 0.0
var _time := 0.0
var _last_frame := -1
var _bars: Array[ColorRect] = []
var _button: Button
var _pulse: Tween


## ปุ่ม "ข้ามทางม้าลาย" กลางล่างจอ กะพริบเบาๆ กดแล้วหายไป (คลิก แตะ หรือ Enter/Space)
func ask() -> void:
	_button = Button.new()
	_button.text = "ข้ามทางม้าลาย  ▶"
	_button.add_theme_font_override("font", FONT)
	_button.add_theme_font_size_override("font_size", 15)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.08, 0.16, 0.9) if state != "hover" else Color(0.12, 0.15, 0.28, 0.95)
		style.border_color = Color(0.85, 0.9, 1.0, 0.85)
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 4
		style.content_margin_bottom = 6
		_button.add_theme_stylebox_override(state, style)
	_button.add_theme_color_override("font_color", Color(0.93, 0.95, 1.0))
	_button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	ui.add_child(_button)
	await get_tree().process_frame
	_button.position = Vector2((640.0 - _button.size.x) / 2.0, 292.0)
	_button.modulate.a = 0.0
	var show := _button.create_tween()
	show.tween_property(_button, "modulate:a", 1.0, 0.5)
	_button.grab_focus()
	_button.pressed.connect(func(): pressed.emit(), CONNECT_ONE_SHOT)
	await pressed
	var hide := _button.create_tween()
	hide.tween_property(_button, "modulate:a", 0.0, 0.25)
	hide.tween_callback(_button.queue_free)


## เริ่มคัทซีน: ตัดผ่านจอดำสั้นๆ (ซ่อนการสลับตัวละคร) แล้วเปิดเป็นจอกว้างแบบหนัง
## ช็อตถอยกล้อง (dolly back): ทั้งคู่เดินเข้าหากล้อง กล้องถอยไปพร้อมกัน ตัวละครจึงอยู่ที่เดิมบนจอ ขนาดคงที่
## (1 พิกเซลภาพ = 1 พิกเซลเกมตลอด ตัวละครไม่ถูกบิด) ส่วนฉากหลังค่อยๆ หมุนเป็นมุมเฉียง ไกลออก (ซูมออก) และเลื่อนข้างเล็กน้อย
## พื้นใต้เท้าจึงไหลถอยห่างตามทิศที่เดิน เท้าไม่ไถล
## seconds = ความยาวของการเคลื่อนกล้อง
func play(seconds: float) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 22                           # เหนือฉากและจอดำ (20) ใต้ภาพโทรศัพท์ (25) และกล่องข้อความ (30)
	add_child(layer)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = Vector2(640, 360)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.modulate.a = 0.0
	layer.add_child(black)
	var cut := black.create_tween()
	cut.tween_property(black, "modulate:a", 1.0, 0.35)
	await cut.finished

	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.size = Vector2(640, BAR)
		bar.position = Vector2(0, 0 if top else 360 - BAR)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(bar)
		_bars.append(bar)
	layer.move_child(black, -1)

	# ฉากที่วาดเสร็จทั้งหมด (ชั้นฉาก + ฝน/โทนสี) ถูกหมุนเป็นมุมเฉียงด้วย shader ชั้นนี้
	var turn_layer := CanvasLayer.new()
	turn_layer.layer = 2
	add_child(turn_layer)
	var turn := ColorRect.new()
	turn.size = Vector2(640, 360)
	turn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var turn_mat := ShaderMaterial.new()
	turn_mat.shader = TURN
	turn_mat.set_shader_parameter("pivot_y", FEET_ON_SCREEN / 180.0 - 1.0)
	turn.material = turn_mat
	turn_layer.add_child(turn)
	# ทั้งคู่อยู่เหนือภาพที่หมุนแล้ว (ไม่ถูกบิด) คม 1 พิกเซลภาพ = 1 พิกเซลเกม ตรงกลางจอที่แถวเท้า
	var pair_layer := CanvasLayer.new()
	pair_layer.layer = 3
	add_child(pair_layer)

	_feet = Vector2(hero.position.x + 10.0, hero.position.y + 121.0)
	_pair = Sprite2D.new()
	_pair.texture = PAIR
	_pair.hframes = COLUMNS
	_pair.vframes = 2
	_pair.centered = false
	_pair.offset = Vector2(-46, -140)          # จุดอ้างอิงที่เท้า (กลางล่าง)
	_pair.position = Vector2(320.0, FEET_ON_SCREEN)
	_pair.modulate = (hero.get_parent() as CanvasItem).modulate   # แสงครึ้มเดียวกับตัวละครในฉาก
	var shadow := hero.get_node_or_null("Shadow") as Sprite2D
	if shadow:
		var s := Sprite2D.new()
		s.texture = shadow.texture
		s.scale = Vector2(1.8, 1.0)
		s.modulate.a = 0.8
		s.position = Vector2(0, -2)
		s.show_behind_parent = true
		_pair.add_child(s)
	pair_layer.add_child(_pair)
	hero.visible = false
	heroine.visible = false

	# กล้องเลิกตามพระเอก: ขยับเองด้วย tween (ปิดสคริปต์กล้องชั่วคราว)
	camera.set_process(false)
	camera.zoom = Vector2(ZOOM_FROM, ZOOM_FROM)
	_cam_x = _feet.x + 18.0
	camera.position = _camera_for(_cam_x, ZOOM_FROM)
	var move := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	move.tween_method(func(z: float): camera.zoom = Vector2(z, z), ZOOM_FROM, 1.0, seconds)
	move.tween_property(self, "_cam_x", _feet.x - 22.0, seconds)
	move.tween_method(func(t: float):
		turn_mat.set_shader_parameter("yaw", deg_to_rad(YAW_TO) * t)
		turn_mat.set_shader_parameter("zoom", lerpf(1.0, TURN_ZOOM, t)), 0.0, 1.0, seconds)
	_update_shot()

	var open := black.create_tween()
	open.tween_interval(0.25)
	open.tween_property(black, "modulate:a", 0.0, 0.7)


## จุดกลางกล้องที่ทำให้พื้นใต้เท้า (_feet) อยู่ที่แถว FEET_ON_SCREEN ตอนซูมเริ่ม แล้วค่อยๆ ไกลออกตามการซูมออก
func _camera_for(x: float, z: float) -> Vector2:
	return Vector2(x, _feet.y - (FEET_ON_SCREEN - 180.0) / ZOOM_FROM)


func _update_shot() -> void:
	camera.position = _camera_for(_cam_x, camera.zoom.x)


func _process(delta: float) -> void:
	if _pair == null:
		return
	_time += delta
	_update_shot()
	var frame := int(_time * FPS) % FRAMES
	_pair.frame = frame
	if frame != _last_frame and frame in STEPS and hero.step_sound:
		hero.step_sound.play()
	_last_frame = frame
