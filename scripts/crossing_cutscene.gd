class_name CrossingCutscene
extends Node
## ข้ามทางม้าลาย: ปุ่ม "ข้ามทางม้าลาย" แล้วตัดเป็นคัทซีนแบบหนัง
## แถบดำบน-ล่าง (จอกว้างแบบหนัง) กล้องค่อยๆ หมุนและดันเข้าหาทั้งคู่ ทั้งคู่เดินใต้ร่มเดียวกันเข้าหากล้อง
## (คลิปเดินคู่เดินเฉียงเข้าหากล้อง: assets/characters/pair_umbrella_walk.png 45 เฟรม 2 แถว 12 เฟรม/วินาที วนได้)
## ระหว่างนั้นบทขึ้นตามปกติ (prologue.gd เรียก play() แล้วเล่นบทเอง)

const PAIR := preload("res://assets/characters/pair_umbrella_walk.png")
const FONT := preload("res://assets/fonts/Sarabun-Regular.ttf")
const FRAMES := 45
const COLUMNS := 23
const FPS := 12.0
## เฟรมที่เท้าแตะพื้น (เสียงเท้า) 3 รอบก้าว รอบละ 15 เฟรม
const STEPS := [2, 9, 17, 24, 32, 39]

signal pressed

var hero: Node2D
var heroine: Node2D
var camera: Camera2D
var ui: Node                                   # CanvasLayer ของกล่องข้อความ (ปุ่มอยู่ชั้นเดียวกัน)

var _pair: Sprite2D
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


## เริ่มคัทซีน: แถบดำเลื่อนเข้า ซ่อนตัวละครปกติ ใส่ภาพเดินคู่แทนที่ตรงกลางระหว่างทั้งคู่ กล้องเริ่มหมุน/ดันเข้า
## seconds = ความยาวโดยประมาณ (การเคลื่อนกล้องและการเดินเข้าหากล้องกินเวลาเท่านี้ แล้วค้างไว้จน end())
func play(seconds: float) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 22                           # เหนือฉากและจอดำ (20) ใต้ภาพโทรศัพท์ (25) และกล่องข้อความ (30)
	add_child(layer)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.size = Vector2(640, 46)
		bar.position = Vector2(0, -46 if top else 360)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(bar)
		_bars.append(bar)
		var t := bar.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(bar, "position:y", 0.0 if top else 314.0, 1.0)

	# ภาพเดินคู่: จุดอ้างอิงที่เท้า (กลางล่าง) ขยายจากเท้าตอนเดินเข้าหากล้อง
	var feet := Vector2(hero.position.x + 10.0, hero.position.y + 121.0)
	_pair = Sprite2D.new()
	_pair.texture = PAIR
	_pair.hframes = COLUMNS
	_pair.vframes = 2
	_pair.centered = false
	_pair.offset = Vector2(-46, -140)
	_pair.position = feet
	var shadow := hero.get_node_or_null("Shadow") as Sprite2D
	if shadow:
		var s := Sprite2D.new()
		s.texture = shadow.texture
		s.centered = true
		s.scale = Vector2(1.8, 1.0)
		s.modulate.a = 0.8
		s.position = Vector2(0, -2)
		s.show_behind_parent = true
		_pair.add_child(s)
	hero.get_parent().add_child(_pair)
	hero.visible = false
	heroine.visible = false

	# กล้อง: เลิกตามพระเอก ล็อกที่ทั้งคู่ แล้วค่อยๆ หมุน + ดันเข้า + ลงตามที่เดินเข้าหากล้อง
	camera.follow = _pair
	camera.follow_offset = 0.0
	camera.mouse_sway = 0.0
	camera.pan_to(320.0)
	camera.ignore_rotation = false
	var cam := camera.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam.tween_property(camera, "zoom", Vector2(1.32, 1.32), seconds)
	cam.tween_property(camera, "rotation", deg_to_rad(-5.0), seconds)
	cam.tween_property(camera, "position:y", feet.y - 62.0 + 22.0, seconds)
	var walk := _pair.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	walk.tween_property(_pair, "position", feet + Vector2(-8, 22), seconds)
	walk.tween_property(_pair, "scale", Vector2(1.12, 1.12), seconds)


func _process(delta: float) -> void:
	if _pair == null:
		return
	_time += delta
	var frame := int(_time * FPS) % FRAMES
	_pair.frame = frame
	if frame != _last_frame and frame in STEPS and hero.step_sound:
		hero.step_sound.play()
	_last_frame = frame
