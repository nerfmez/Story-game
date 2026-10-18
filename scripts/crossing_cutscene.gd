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
## ภาพเดินคู่: คลิปจัดเฟรมด้วยเท้า ช่วงบน (ร่ม ผม) เลยกระโดดขึ้นลง 4-5 px ไม่สม่ำเสมอ และพุ่งไปข้างหน้าแล้วถูกดึงกลับทุกก้าว
## (เลื่อนข้าง ~6 px ใหญ่/เล็กลง ~5%) ขยายในคัทซีนแล้วเห็นเป็นกระเด้ง/ขยับหน้าหลัง แต่ละเฟรมจึงขยาย SIZE_FIX เท่ารอบเท้า
## เลื่อนข้าง SWAY_FIX และเลื่อนลง BOB_FIX (พิกเซลภาพ): ช่วงบนอยู่นิ่งที่เดิม ขึ้นลงเรียบๆ ทีละก้าวนิดเดียว
## จาก tools/measure_bob.py (--steps 6 --keep 0.3)
const SIZE_FIX := [0.986, 0.996, 1.014, 1.021, 1.003, 1.003, 0.993, 0.996, 0.999, 1.003, 1.006, 1.006, 1.014, 0.986,
		0.976, 0.982, 1.010, 1.025, 1.014, 1.021, 1.010, 1.003, 0.999, 0.993, 0.986, 0.999, 0.993, 1.003, 0.982, 0.972,
		0.982, 0.993, 1.025, 1.014, 1.021, 1.007, 1.010, 0.999, 0.999, 1.003, 0.993, 0.996, 1.014, 0.986, 0.972]
const SWAY_FIX := [2.3, 1.5, -0.1, -2.9, -2.5, -2.4, -1.2, 1.9, 3.1, 0.5, -1.2, -1.3, -1.2, 0.9, 2.2, 2.3, 1.0, -0.4,
		-1.7, -2.3, -2.6, 0.1, 2.3, 3.1, 2.0, -0.5, -1.3, -1.1, 1.3, 1.9, 2.5, 1.5, 0.1, -2.6, -2.9, -3.1, -2.3, 1.2, 2.6,
		0.9, -1.2, -1.5, -1.0, 0.0, 1.9]
const BOB_FIX := [-0.1, 0.2, -0.3, 1.4, -0.5, -1.2, -1.2, 0.1, 1.0, -1.8, -0.1, 1.0, 1.0, 0.5, -1.1, -0.2, 0.5, 2.0,
		0.2, 0.6, 0.6, 0.8, -0.2, 0.2, -0.9, -0.9, -1.3, 0.7, -0.6, -1.9, 0.1, -0.3, 2.0, 0.6, 0.9, -0.1, 0.3, 0.2, 0.7,
		-0.1, -1.1, -0.2, 1.0, -0.8, -1.5]
## แถบดำบน-ล่าง (จอกว้างแบบหนัง) บทพูดขึ้นเป็นซับไตเติลในแถบล่าง
const BAR := 50.0
## แถวบนจอ (640x360) ที่เท้าของทั้งคู่อยู่ตลอดช็อต (= ขอบฟ้าบนจอ 163 + ระยะเท้าถึงขอบฟ้า 70 แบบในฉาก)
const FEET_ON_SCREEN := 233.0
## หมุนฉากถึงมุมนี้ (ลบ = ทางม้าลายเฉียงลงซ้าย ทางเดียวกับท่าเดินของทั้งคู่) ใช้เวลา TURN_TIME วินาที
const YAW_TO := -26.0
const TURN_TIME := 4.0
## ทั้งคู่เดินไปข้างหน้ากี่หน่วยความลึกต่อวินาที (ระยะแถบทางม้าลาย 1 รอบ = 0.55) ตรงกับก้าวในคลิป:
## เท้าที่แตะพื้นเลื่อนข้าง ~18 px/วินาที = ด้านข้างของทิศเดินเฉียง 26° → ~0.6-0.7 หน่วย/วินาที พื้นจึงไหลเท่าก้าว ไม่ใช่เดินอยู่กับที่
const WALK_DEPTH_PER_SECOND := 0.68
## กล้องถอยตามเท่านี้ของระยะที่ทั้งคู่เดิน (1 = ตามติด ทั้งคู่อยู่ที่เดิมบนจอ) ที่เหลือคือทั้งคู่เดินเข้ามาใกล้กล้อง (ตัวใหญ่ขึ้น)
const CAMERA_FOLLOW := 0.92
## กำแพงและฉากหลังถอยไปกับกล้องเท่านี้ (ฉากหลังอยู่ไกลกว่าที่วาด: ไกลออกช้า ซูมเข้าชดเชย ฉากหลังจึงไม่หดเหมือนซูมออก)
const WALL_FOLLOW := 0.75
## คัทซีนยาวเท่านี้ (วินาทีนับจากตัดเข้า) รวมช่วงจางเป็นจอดำ FADE_OUT วินาทีสุดท้าย
const SHOT_TIME := 16.0
const FADE_OUT := 1.2
## ช่วงแรกเร่งจากยืนเป็นเดิน (วินาที)
const WALK_START := 0.6
## ฉากเริ่มหมุนที่ TURN_AT วินาที ทั้งคู่ยืนนิ่ง (ภาพเดินคู่เฟรม STAND_FRAME: เท้าแตะพื้นทั้งสองข้าง) แล้วเริ่มเดินหลังจากนั้น WALK_DELAY วินาที
## ท่าเดินเริ่มจากเฟรมยืนนั้น ไม่กระโดด
const TURN_AT := 0.8
const WALK_DELAY := 2.0
const STAND_FRAME := 0
## ซูมเข้าตอนหมุน (พร้อมการหมุน) เข้าหาจุดนี้บนจอ (นับจากกลางจอ: กลางตัวทั้งคู่ เผื่อที่ให้ร่มใต้แถบบน)
const ZOOM_TO := 1.25
const ZOOM_FOCUS := Vector2(0.0, -30.0)
## หมุนเสร็จแล้วค่อยๆ ซูมเข้าต่อจนจบช็อต (คูณ) ทั้งคู่ใหญ่ขึ้นเรื่อยๆ ร่มไม่ชนแถบบน
const PUSH_TO := 1.15
## เสาไฟสัญญาณ: จุดโคนเสาในภาพเสา (signal_pole.png 30x200) วาดแยกเป็นวัตถุตั้งที่ความลึกจริงของมัน (ริมทางเท้า)
## ไม่ใช่ส่วนของกำแพง: หมุนแล้วจึงยังอยู่ข้างที่ทั้งคู่ยืนตอนแรก แล้วอยู่ข้างหลังเมื่อเดินผ่านไป
const POLE_FOOT := Vector2(16.0, 200.0)
## ระหว่างเดินตัดเข้าช็อตแคบหน้า (ตัดฉับแบบหนัง) ที่วินาทีนี้ กล้องตามหน้าทั้งคู่ไปขณะเดิน แช่ไว้จนจอดำ
const CLOSE_FROM := 8.5
## ขยายเพิ่มจากช็อตกว้างเท่านี้ หน้าทั้งคู่ (จุดกลางระหว่างสองหน้าในภาพเดินคู่ เทียบจุดเท้า) อยู่ที่จุดนี้บนจอ (นับจากกลางจอ)
const CLOSE_K := 2.4
const FACES := Vector2(-8.0, -100.0)
const CLOSE_AT := Vector2(0.0, -15.0)
## ค่าเดียวกับใน shader (หาตำแหน่งทั้งคู่บนจอด้วยกล้องเดียวกัน เท้าจึงติดพื้น)
const FOCAL := 500.0
const PIVOT_DEPTH := FOCAL / (93.0 - 23.0)    # ความลึกของเท้าทั้งคู่ตอนเริ่ม (focal / (แถวเท้า - ขอบฟ้า))
const OUT_HORIZON := -17.0
const WALL_DEPTH := FOCAL / (70.0 - 23.0)     # ความลึกฐานกำแพง (focal / (แถวฐานกำแพง - ขอบฟ้า))
## กล้องเกมถอยออกตอนถ่ายฉากให้ shader (เห็นกว้างกว่าจอ ฉากที่หมุนแล้วไม่มีขอบโผล่)
const SRC_ZOOM := 0.58
## และเลื่อนไปทางซ้ายเท่านี้ตอนหมุนสุด (หมุนแล้วฝั่งซ้ายมองเห็นไกลกว่า ต้องมีภาพทางซ้ายมากกว่าขวา)
const SRC_SHIFT := -270.0

signal pressed

var hero: Node2D
var heroine: Node2D
var camera: Camera2D
var ui: Node                                   # CanvasLayer ของกล่องข้อความ (ปุ่มอยู่ชั้นเดียวกัน)
var crossing_signal: Node2D                    # เสาไฟสัญญาณในฉาก (ย้ายออกจากฉากมาวาดเองตอนหมุน)

var _pair: Sprite2D
var _turn_mat: ShaderMaterial
var _turned := 0.0                              # 0 -> 1 หมุนและซูม
var _walked := 0.0                              # ทั้งคู่เดินไปกี่หน่วยความลึก
var _feet := Vector2.ZERO
var _pole_x := 0.0                              # ตำแหน่งโคนเสาไฟบนพื้น (หน่วยแบบ shader: ข้าง, ความลึก)
var _pole_z := 0.0
var _close_k := 1.0                             # ช็อตแคบหน้า: ขยายเพิ่ม (1 = ช็อตกว้าง)
var _close_from := Vector2.ZERO
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
## ทั้งคู่เดินไปเรื่อยๆ จนจบคัทซีน (ซับไตเติลขึ้นเองตามเวลา prologue.gd จางจอดำเอง) ไม่มีช่วงหยุดเดินอยู่กับที่
func play() -> void:
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
	turn_mat.set_shader_parameter("wall_follow", WALL_FOLLOW)
	turn.material = turn_mat
	_turn_mat = turn_mat
	turn_layer.add_child(turn)
	# ทั้งคู่อยู่เหนือภาพที่หมุนแล้ว (ไม่ถูกบิด) วางที่เท้าตามกล้องเดียวกับ shader ขยายตามซูมและระยะ (คมด้วย smooth_pixel)
	var pair_layer := CanvasLayer.new()
	pair_layer.layer = 3
	add_child(pair_layer)
	# ฝน (ทั้งจอ) ย้ายขึ้นเหนือภาพที่หมุนแล้วและทั้งคู่: ไม่งั้นถูกถ่ายลงภาพต้นทางแล้วยืดไปบนพื้นเป็นรอยขีด
	var rain := get_tree().current_scene.get_node_or_null("Grade/Rain") as CanvasItem
	if rain and rain.visible:
		var rain_layer := CanvasLayer.new()
		rain_layer.layer = 4
		add_child(rain_layer)
		rain.reparent(rain_layer, false)

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
	if crossing_signal:
		var foot := crossing_signal.position + POLE_FOOT
		_pole_z = FOCAL / (foot.y - 180.0 - 23.0)
		_pole_x = (foot.x - _feet.x) * _pole_z / FOCAL
		crossing_signal.reparent(pair_layer, false)
		crossing_signal.modulate = _pair.modulate
	pair_layer.add_child(_pair)
	hero.visible = false
	heroine.visible = false

	# กล้องเลิกตามพระเอก: ตั้งกลางที่เท้าทั้งคู่ แถว 180 เท่าตอนเล่น ถอยออก (SRC_ZOOM) ให้ shader มีภาพพอหมุน
	camera.set_process(false)
	camera.position = Vector2(_feet.x, 180.0)
	camera.zoom = Vector2(SRC_ZOOM, SRC_ZOOM)
	var turn_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	turn_tween.tween_interval(TURN_AT)
	turn_tween.tween_property(self, "_turned", 1.0, TURN_TIME)
	_place()

	var open := black.create_tween()
	open.tween_interval(0.25)
	open.tween_property(black, "modulate:a", 0.0, 0.7)
	open.tween_interval(SHOT_TIME - 0.95 - FADE_OUT)
	open.tween_property(black, "modulate:a", 1.0, FADE_OUT)


## จุดบนพื้น (x ข้าง, z ความลึก แบบ shader) -> ตำแหน่งบนจอ (นับจากกลางจอ ก่อนซูม) และความลึกจากกล้อง
## กล้องโคจรรอบจุดเริ่มของทั้งคู่ (หมุน) อยู่ที่ (-zp s, 0, -zp c + zp - cam_walked) พื้นอยู่ต่ำกว่ากล้อง 1 หน่วย
func _project(x: float, z: float, cam_walked: float, c: float, s: float) -> Vector3:
	var rx := x + PIVOT_DEPTH * s
	var rz := z + PIVOT_DEPTH * c - PIVOT_DEPTH + cam_walked
	var dx := rx * c - rz * s
	var dz := rx * s + rz * c
	return Vector3(FOCAL * dx / dz, FOCAL / dz + OUT_HORIZON, dz)


## หมุน ซูม ถอยกล้อง แล้ววางทั้งคู่ (เดินไปทาง -z เข้าหากล้อง) และเสาไฟ (อยู่กับที่) ด้วยกล้องเดียวกับ scene_turn.gdshader
func _place() -> void:
	var yaw := deg_to_rad(YAW_TO * _turned)
	var push := smoothstep(0.0, 1.0, (_time - TURN_AT - TURN_TIME) / (SHOT_TIME - TURN_AT - TURN_TIME))
	var zoom := lerpf(1.0, ZOOM_TO, _turned) * lerpf(1.0, PUSH_TO, push)
	var cam_walked := _walked * CAMERA_FOLLOW
	var close := _time >= CLOSE_FROM
	_turn_mat.set_shader_parameter("yaw", yaw)
	_turn_mat.set_shader_parameter("advance", cam_walked)
	_turn_mat.set_shader_parameter("zoom", zoom)
	# กล้องเกมเลื่อนซ้ายไปพร้อมการหมุน: ภาพต้นทางครอบทั้งด้านที่มองเห็นตลอด (ตอนตรงต้องครอบขวา ตอนหมุนต้องครอบซ้าย)
	_turn_mat.set_shader_parameter("src_shift", SRC_SHIFT * _turned)
	camera.position.x = _feet.x + SRC_SHIFT * _turned
	var c := cos(yaw)
	var s := sin(yaw)
	var pair := _project(0.0, PIVOT_DEPTH - _walked, cam_walked, c, s)
	var pair_scale := zoom * PIVOT_DEPTH / pair.z
	var pair_at := _on_screen(pair, zoom)
	# ช็อตแคบหน้า: ขยายทั้งภาพ (ฉากใน shader + ทั้งคู่ + เสา) อีก CLOSE_K เท่ารอบหน้าทั้งคู่ ให้หน้าอยู่ที่ CLOSE_AT
	_close_k = CLOSE_K if close else 1.0
	_close_from = pair_at + FACES * pair_scale - Vector2(320.0, 180.0)
	_turn_mat.set_shader_parameter("close_k", _close_k)
	_turn_mat.set_shader_parameter("close_from", _close_from if close else CLOSE_AT)
	_turn_mat.set_shader_parameter("close_to", CLOSE_AT)
	_pair.position = _closer(pair_at)
	_pair.scale = Vector2.ONE * pair_scale * _close_k * SIZE_FIX[_pair.frame]
	if crossing_signal:
		var pole := _project(_pole_x, _pole_z, cam_walked, c, s)
		var k := zoom * _pole_z / pole.z * _close_k
		crossing_signal.scale = Vector2.ONE * k
		crossing_signal.position = _closer(_on_screen(pole, zoom)) - POLE_FOOT * k
		crossing_signal.z_index = 1 if pole.z < pair.z else 0   # ใกล้กล้องกว่าทั้งคู่ = วาดทับ
		# ฉากหลังถอยตามกล้องช้ากว่าที่ทั้งคู่ทิ้งเสาไว้ข้างหลัง: ก่อนเสาจะเลยไปอยู่หลังกำแพง เสาจางหายไปในม่านฝน
		var gap := (WALL_DEPTH - cam_walked * WALL_FOLLOW) - _pole_z
		crossing_signal.modulate.a = smoothstep(0.3, 2.0, gap)


## จุดบนจอช็อตกว้าง -> บนจอจริง (ช็อตแคบหน้า: ขยายรอบหน้าทั้งคู่ ไม่งั้นเหมือนเดิม)
func _closer(at: Vector2) -> Vector2:
	if _close_k == 1.0:
		return at
	return Vector2(320.0, 180.0) + CLOSE_AT + (at - Vector2(320.0, 180.0) - _close_from) * _close_k


func _on_screen(p: Vector3, zoom: float) -> Vector2:
	return Vector2(320.0, 180.0) + ZOOM_FOCUS + (Vector2(p.x, p.y) - ZOOM_FOCUS) * zoom


func _process(delta: float) -> void:
	if _pair == null:
		return
	_time += delta
	# ยืนนิ่งจนฉากหมุนไปแล้ว WALK_DELAY วินาที แล้วเร่งจากยืนเป็นเดินใน WALK_START วินาที จากนั้นเดินเท่าก้าวไปตลอด
	var walking := _time - TURN_AT - WALK_DELAY
	var frame := STAND_FRAME
	if walking > 0.0:
		_walked += WALK_DEPTH_PER_SECOND * minf(walking / WALK_START, 1.0) * delta
		frame = (STAND_FRAME + int(walking * FPS)) % FRAMES
	_pair.frame = frame
	_pair.offset = Vector2(-46.0 + SWAY_FIX[frame], -140.0 + BOB_FIX[frame])
	_place()
	if frame != _last_frame and frame in STEPS and hero.step_sound:
		hero.step_sound.play()
	_last_frame = frame
