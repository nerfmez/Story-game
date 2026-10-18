class_name CrossingCutscene
extends Node
## ข้ามทางม้าลาย: ปุ่ม "ข้ามทางม้าลาย" แล้วตัดเป็นคัทซีนแบบหนัง
## ตัดผ่านจอดำ แล้วเป็นจอกว้างแบบหนัง: ฉากค่อยๆ หมุน (shaders/scene_turn.gdshader) จนทางม้าลายเฉียงไปทางเดียวกับ
## ที่ทั้งคู่เดิน (เข้าหากล้องเยื้องซ้าย) พร้อมซูมเข้าหาทั้งคู่ แล้วทั้งคู่เดินข้ามไปตามทางม้าลาย กล้องถอยตามช้ากว่า
## ทั้งคู่จึงเดินเข้ามาใกล้ (ใหญ่ขึ้น เยื้องซ้าย) จริงๆ ไม่ใช่เดินอยู่กับที่ บทเป็นซับไตเติลในแถบล่าง
## (คลิปเดินคู่เดินเฉียงเข้าหากล้อง: assets/characters/pair_umbrella_walk.png 45 เฟรม 2 แถว 12 เฟรม/วินาที วนได้)
## ระหว่างนั้นบทขึ้นตามปกติ (prologue.gd เรียก play() แล้วเล่นบทเอง)

const PAIR := preload("res://assets/characters/pair_umbrella_walk.png")
const FONT := preload("res://assets/fonts/Sarabun-Regular.ttf")
const TURN := preload("res://shaders/scene_turn.gdshader")
const SMOOTH_PIXEL := preload("res://shaders/smooth_pixel.gdshader")
const FRAMES := 45
const COLUMNS := 23
const FPS := 12.0
## เฟรมที่เท้าแตะพื้น (เสียงเท้า) 3 รอบก้าว รอบละ 15 เฟรม
const STEPS := [2, 9, 17, 24, 32, 39]
## แถบดำบน-ล่าง (จอกว้างแบบหนัง) บทพูดขึ้นเป็นซับไตเติลในแถบล่าง
const BAR := 50.0
## แถวบนจอ (640x360) ที่เท้าของทั้งคู่อยู่ตลอดช็อต (= ขอบฟ้าบนจอ 163 + ระยะเท้าถึงขอบฟ้า 70 แบบในฉาก)
const FEET_ON_SCREEN := 233.0
## หมุนฉากถึงมุมนี้ (ลบ = ทางม้าลายเฉียงลงซ้าย ทางเดียวกับท่าเดินของทั้งคู่) ใช้เวลา TURN_TIME วินาที
const YAW_TO := -26.0
const TURN_TIME := 4.0
## ทั้งคู่เดินไปข้างหน้ากี่หน่วยความลึกต่อวินาที (ระยะแถบทางม้าลาย 1 รอบ = 0.55)
const WALK_DEPTH_PER_SECOND := 0.12
## กล้องถอยตามเท่านี้ของระยะที่ทั้งคู่เดิน (1 = ตามติด ทั้งคู่อยู่ที่เดิมบนจอ) ที่เหลือคือทั้งคู่เดินเข้ามาใกล้กล้อง
const CAMERA_FOLLOW := 0.5
## ซูมเข้าตอนหมุน (พร้อมการหมุน) เข้าหาจุดนี้บนจอ (นับจากกลางจอ: กลางตัวทั้งคู่ เผื่อที่ให้ร่มใต้แถบบน)
const ZOOM_TO := 1.35
const ZOOM_FOCUS := Vector2(0.0, -30.0)
## ค่าเดียวกับใน shader (หาตำแหน่งทั้งคู่บนจอด้วยกล้องเดียวกัน เท้าจึงติดพื้น)
const FOCAL := 500.0
const PIVOT_DEPTH := FOCAL / (93.0 - 23.0)    # ความลึกของเท้าทั้งคู่ตอนเริ่ม (focal / (แถวเท้า - ขอบฟ้า))
const OUT_HORIZON := -17.0
## กล้องเกมถอยออกตอนถ่ายฉากให้ shader (เห็นกว้างกว่าจอ ฉากที่หมุนแล้วไม่มีขอบโผล่)
const SRC_ZOOM := 0.58
## และเลื่อนไปทางซ้ายเท่านี้ตอนหมุนสุด (หมุนแล้วฝั่งซ้ายมองเห็นไกลกว่า ต้องมีภาพทางซ้ายมากกว่าขวา)
const SRC_SHIFT := -270.0

signal pressed

var hero: Node2D
var heroine: Node2D
var camera: Camera2D
var ui: Node                                   # CanvasLayer ของกล่องข้อความ (ปุ่มอยู่ชั้นเดียวกัน)

var _pair: Sprite2D
var _turn_mat: ShaderMaterial
var _turned := 0.0                              # 0 -> 1 หมุนและซูม
var _walked := 0.0                              # ทั้งคู่เดินไปกี่หน่วยความลึก
var _feet := Vector2.ZERO
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
## ฉากหมุนรอบแกนตั้งที่เท้าทั้งคู่ (พื้นและทางม้าลายเฉียงตามทิศเดิน เสายังตั้งตรง) แล้วทั้งคู่เดินไปตามทางม้าลาย
## กล้องตามหลัง ทั้งคู่จึงอยู่กลางจอที่เดิม (1 พิกเซลภาพ = 1 พิกเซลเกม ไม่ถูกบิด) พื้นไหลเข้าหากล้อง ฉากหลังไกลออก
## seconds = ความยาวโดยประมาณของคัทซีน
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
	# ก๊อปจอใหม่ตรงนี้: ไม่งั้น shader ได้ภาพที่ก๊อปไว้ตั้งแต่ชั้นเงาสะท้อน (ก่อนวาดถนน) พื้นเลยดำ
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	turn_layer.add_child(copy)
	var turn := ColorRect.new()
	turn.size = Vector2(640, 360)
	turn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var turn_mat := ShaderMaterial.new()
	turn_mat.shader = TURN
	turn_mat.set_shader_parameter("src_zoom", SRC_ZOOM)
	turn_mat.set_shader_parameter("src_shift", 0.0)
	turn_mat.set_shader_parameter("focus", ZOOM_FOCUS)
	turn.material = turn_mat
	_turn_mat = turn_mat
	turn_layer.add_child(turn)
	# ทั้งคู่อยู่เหนือภาพที่หมุนแล้ว (ไม่ถูกบิด) วางที่เท้าตามกล้องเดียวกับ shader ขยายตามซูมและระยะ (คมด้วย smooth_pixel)
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
	_pair.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var smooth := ShaderMaterial.new()
	smooth.shader = SMOOTH_PIXEL
	_pair.material = smooth
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

	# กล้องเลิกตามพระเอก: ตั้งกลางที่เท้าทั้งคู่ แถว 180 เท่าตอนเล่น ถอยออก (SRC_ZOOM) ให้ shader มีภาพพอหมุน
	camera.set_process(false)
	camera.position = Vector2(_feet.x, 180.0)
	camera.zoom = Vector2(SRC_ZOOM, SRC_ZOOM)
	var turn_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	turn_tween.tween_interval(0.8)
	turn_tween.tween_property(self, "_turned", 1.0, TURN_TIME)
	var walk := create_tween()
	walk.tween_property(self, "_walked", WALK_DEPTH_PER_SECOND * (seconds + 6.0), seconds + 6.0)
	_place()

	var open := black.create_tween()
	open.tween_interval(0.25)
	open.tween_property(black, "modulate:a", 0.0, 0.7)


## หมุน ซูม ถอยกล้อง แล้ววางทั้งคู่ที่จุดบนพื้นที่ทั้งคู่เดินถึง (คิดแบบเดียวกับ scene_turn.gdshader)
## กล้องโคจรรอบจุดเริ่มของทั้งคู่ (หมุน) และถอยตาม CAMERA_FOLLOW ของระยะที่เดิน ทั้งคู่เดินไปทาง -z (เข้าหากล้อง)
func _place() -> void:
	var yaw := deg_to_rad(YAW_TO * _turned)
	var zoom := lerpf(1.0, ZOOM_TO, _turned)
	var cam_walked := _walked * CAMERA_FOLLOW
	_turn_mat.set_shader_parameter("yaw", yaw)
	_turn_mat.set_shader_parameter("advance", cam_walked)
	_turn_mat.set_shader_parameter("zoom", zoom)
	# กล้องเกมเลื่อนซ้ายไปพร้อมการหมุน: ภาพต้นทางครอบทั้งด้านที่มองเห็นตลอด (ตอนตรงต้องครอบขวา ตอนหมุนต้องครอบซ้าย)
	_turn_mat.set_shader_parameter("src_shift", SRC_SHIFT * _turned)
	camera.position.x = _feet.x + SRC_SHIFT * _turned
	var c := cos(yaw)
	var s := sin(yaw)
	# ทั้งคู่เทียบกับกล้อง (กล้องอยู่ที่ (-zp s, 0, -zp c + zp - cam_walked) ทั้งคู่อยู่ที่ (0, 1, zp - walked))
	var rx := PIVOT_DEPTH * s
	var rz := PIVOT_DEPTH * c - (_walked - cam_walked)
	var dx := rx * c - rz * s
	var dz := rx * s + rz * c
	var on_screen := Vector2(FOCAL * dx / dz, FOCAL / dz + OUT_HORIZON)
	on_screen = ZOOM_FOCUS + (on_screen - ZOOM_FOCUS) * zoom
	_pair.position = Vector2(320.0, 180.0) + on_screen
	_pair.scale = Vector2.ONE * (zoom * PIVOT_DEPTH / dz)


func _process(delta: float) -> void:
	if _pair == null:
		return
	_place()
	_time += delta
	var frame := int(_time * FPS) % FRAMES
	_pair.frame = frame
	if frame != _last_frame and frame in STEPS and hero.step_sound:
		hero.step_sound.play()
	_last_frame = frame
