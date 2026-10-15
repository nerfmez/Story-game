extends Node
## ฉากหลัก: โหลดบทพูดจาก JSON แล้วสั่งกล่องข้อความ กล้อง และรถไฟตามบท
## ใช้ได้ทั้งฉาก 2D (main.tscn) และ HD-2D (main_3d.tscn)

@export_file("*.json") var dialogue_file := "res://data/chapter1.json"
## บทของฉากตอนเช้า (เว้นว่าง = ใช้บทเดียวกัน)
@export_file("*.json") var dialogue_file_morning := "res://data/chapter1_morning.json"
## ข้อความภารกิจมุมจอ (เย็น / เช้า)
@export var mission_text := "ถ่ายวิดีโอหลังเลิกเรียน"
## แสดงกล่องข้อความและเล่นบทหรือไม่ (ปิดไว้ก่อน: เดินเล่นในฉากเฉยๆ รถไฟยังวิ่งผ่านเองตามเวลา)
@export var show_dialogue := false
@export var mission_text_morning := "ถ่ายวิดีโอก่อนเข้าเรียน"
## กล้องที่มีฟังก์ชัน pan_to(x)
@export var camera: Node
## รถไฟที่มีฟังก์ชัน pass_by()
@export var train: Node
## กด Tab เพื่อสลับไปฉากนี้ (เว้นว่าง = ปิด)
@export_file("*.tscn") var other_scene := ""

@onready var dialogue_box: DialogueBox = $UI/DialogueBox

const SMOOTH_PIXEL := preload("res://shaders/smooth_pixel.gdshader")

## ช่วงเวลาของฉาก: ภาพเย็นอยู่ใน assets/bg/sunset/ ภาพเช้าชื่อเดียวกันอยู่ใน assets/bg/morning/
## (tools/compose_morning_scene.py) ตอนเช้าเปลี่ยนภาพทุกชั้นที่มีเวอร์ชันเช้า ซ่อนแสงอาทิตย์ตก
## เปลี่ยนโทนสีทั้งจอ ฝุ่นในแสง และเสียงบรรยากาศ บนเว็บเลือกที่หน้าเริ่ม, บนเครื่องกด T สลับ
@export var morning := false
## ชั้นที่มีเฉพาะตอนเย็น (แสงอาทิตย์ แสงเรืองหน้าต่างรถไฟ เมฆเส้นสีส้ม)
@export var evening_only: Array[NodePath] = [^"SunLight", ^"Wisps", ^"TrainLayer/Train/Glow"]
## ตอนเช้าถนนแห้ง (ไม่มีน้ำ): ซ่อนเงาสะท้อนที่วาดอยู่บนถนน (เงาสะท้อนชั้นอื่นอยู่ใต้ถนนทึบอยู่แล้ว)
## (เงาสะท้อนตัวละครปิดไว้ทั้งเช้าและเย็น: Characters/Hero/Reflection visible = false ในฉาก)
@export var wet_only: Array[NodePath] = []
const MORNING_AMBIENCE := "res://assets/audio/ambience_morning.ogg"


func _ready() -> void:
	# บนมือถือ/เบราว์เซอร์ ให้ภาพขยายเต็มจอแบบไม่ต้องเป็นจำนวนเท่าเต็ม (ไม่งั้นภาพเล็กมีขอบดำหนา)
	if OS.has_feature("web") or OS.has_feature("mobile"):
		get_tree().root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	# ฉากและตัวละคร: คมแบบพิกเซลแต่เลื่อนทีละเศษพิกเซลได้ (ชั้นไกลที่เลื่อนช้าจะไม่กระตุก)
	var smooth := ShaderMaterial.new()
	smooth.shader = SMOOTH_PIXEL
	_use_smooth_pixels(self, smooth)
	_evening_ambience = ($Ambience as AudioStreamPlayer).stream if has_node("Ambience") else null
	set_morning(morning)
	dialogue_box.line_started.connect(_on_line_started)
	dialogue_box.finished.connect(_on_finished)
	if OS.has_feature("web"):
		_prepare_sounds(self)
		# เบราว์เซอร์ไม่ให้เล่นเสียงจนกว่าผู้เล่นจะแตะ/คลิก: ให้แตะเริ่มก่อน แล้วค่อยเปิดเสียงและบท
		var ambience := get_node_or_null("Ambience") as AudioStreamPlayer
		if ambience:
			ambience.stop()
		dialogue_box.hide()
		_show_start_screen()
	else:
		_begin_dialogue()


## เตรียมเสียงทุกไฟล์ไว้ล่วงหน้า (บนเว็บ Godot จะเตรียมตอนเล่นครั้งแรก ทำให้เสียงแรกช้า)
func _prepare_sounds(node: Node) -> void:
	for child in node.get_children():
		if child is AudioStreamPlayer and child.stream:
			var stream: AudioStream = child.stream
			var streams: Array = [stream]
			if stream is AudioStreamRandomizer:
				streams = []
				for i in stream.streams_count:
					streams.append(stream.get_stream(i))
			for st in streams:
				if st and not AudioServer.is_stream_registered_as_sample(st):
					AudioServer.register_stream_as_sample(st)
		_prepare_sounds(child)


var _start_layer: CanvasLayer


func _show_start_screen() -> void:
	_start_layer = CanvasLayer.new()
	_start_layer.layer = 10
	add_child(_start_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.03, 0.12, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_start_layer.add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	_start_layer.add_child(box)
	var label := Label.new()
	label.text = "เลือกช่วงเวลาเพื่อเริ่ม\n(เปิดเสียงด้วยนะ)"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.15))
	label.add_theme_constant_override("outline_size", 6)
	box.add_child(label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	for choice in [["เช้า", true, Color(0.36, 0.62, 0.9)], ["เย็น", false, Color(0.86, 0.46, 0.42)]]:
		var button := Button.new()
		button.text = choice[0]
		button.custom_minimum_size = Vector2(110, 44)
		button.add_theme_font_size_override("font_size", 20)
		var style := StyleBoxFlat.new()
		style.bg_color = choice[2]
		style.set_corner_radius_all(10)
		style.set_border_width_all(2)
		style.border_color = Color(1, 1, 1, 0.8)
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, style)
		# ตอบตอนกดลง (แบบปุ่มเดินบนจอ): บนมือถือการแตะแล้วปล่อยไม่ถึงปุ่มที่รอตอนปล่อย
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.pressed.connect(_start.bind(choice[1]))
		row.add_child(button)
	var tween := label.create_tween().set_loops()  # ผูกกับ label: หยุดเองเมื่อ label ถูกลบ
	tween.tween_property(label, "modulate:a", 0.55, 0.8)
	tween.tween_property(label, "modulate:a", 1.0, 0.8)


func _input(event: InputEvent) -> void:
	# หน้าเริ่ม: กดปุ่มบนจอเพื่อเลือก, คีย์บอร์ด: M = เช้า, ปุ่มอื่น = ช่วงเวลาที่ตั้งไว้
	if _start_layer == null or not (event is InputEventKey and event.pressed):
		return
	get_viewport().set_input_as_handled()
	_start(true if event.keycode == KEY_M else morning)


func _start(is_morning: bool) -> void:
	if _start_layer == null:
		return
	_start_layer.queue_free()
	_start_layer = null
	set_morning(is_morning)
	var ambience := get_node_or_null("Ambience") as AudioStreamPlayer
	if ambience:
		ambience.play()
	_begin_dialogue()


var _evening_ambience: AudioStream


func _begin_dialogue() -> void:
	if show_dialogue:
		dialogue_box.start(load_lines(_dialogue_path()))
	else:
		dialogue_box.hide()


func _dialogue_path() -> String:
	return dialogue_file_morning if morning and dialogue_file_morning != "" else dialogue_file


## สลับฉากเช้า/เย็น
func set_morning(on: bool) -> void:
	morning = on
	var mission := get_node_or_null("UI/Mission/Row/Label") as Label
	if mission:
		mission.text = mission_text_morning if on else mission_text
	_swap_textures(self, on)
	for path in evening_only + wet_only:
		var node := get_node_or_null(path) as CanvasItem
		if node:
			node.visible = not on
	var grade := get_node_or_null("Grade/Screen") as ColorRect
	if grade and grade.material is ShaderMaterial:
		var m := grade.material as ShaderMaterial
		if on:   # เช้า: เงาฟ้าอ่อนๆ ไฮไลต์อุ่นนิดหน่อย ขอบจอมืดน้อยลง
			m.set_shader_parameter("shadow_tint", Vector3(0.0, 0.03, 0.07))
			m.set_shader_parameter("highlight_tint", Vector3(0.03, 0.02, 0.0))
			m.set_shader_parameter("tint_amount", 0.3)
			m.set_shader_parameter("vignette", 0.15)
		else:    # ค่าเดิมของ shader (เย็น)
			for param in ["shadow_tint", "highlight_tint", "tint_amount", "vignette"]:
				m.set_shader_parameter(param, null)
	var dust := get_node_or_null("Dust") as CPUParticles2D
	if dust:
		dust.modulate = Color(1.0, 1.25, 1.35, 0.7) if on else Color.WHITE   # ฝุ่นในแสงเช้า: ขาวอมฟ้า
	var ambience := get_node_or_null("Ambience") as AudioStreamPlayer
	if ambience and _evening_ambience:
		var want: AudioStream = load(MORNING_AMBIENCE) if on else _evening_ambience
		if ambience.stream != want:
			var was_playing := ambience.playing
			ambience.stream = want
			if OS.has_feature("web") and not AudioServer.is_stream_registered_as_sample(want):
				AudioServer.register_stream_as_sample(want)
			if was_playing:
				ambience.play()


## เปลี่ยนภาพของทุก Sprite2D ที่มีเวอร์ชันเช้า (ชื่อไฟล์เดียวกันในโฟลเดอร์ morning)
func _swap_textures(node: Node, on: bool) -> void:
	for child in node.get_children():
		if child is Sprite2D and child.texture:
			if not child.has_meta("evening_texture"):
				child.set_meta("evening_texture", child.texture)
			var evening: Texture2D = child.get_meta("evening_texture")
			var path := evening.resource_path
			var morning_path := path.replace("/bg/sunset/", "/bg/morning/")
			if on and morning_path != path and ResourceLoader.exists(morning_path):
				child.texture = load(morning_path)
			else:
				child.texture = evening
		if not child is CanvasLayer:
			_swap_textures(child, on)


func _use_smooth_pixels(node: Node, smooth: ShaderMaterial) -> void:
	for child in node.get_children():
		if child is Sprite2D and child.material == null:
			child.material = smooth
			child.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if not child is CanvasLayer:  # UI อยู่ใน CanvasLayer: ไม่ต้องเปลี่ยน
			_use_smooth_pixels(child, smooth)


static func load_lines(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("เปิดไฟล์บทไม่ได้: %s" % path)
		return []
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or not data.has("lines"):
		push_error("รูปแบบไฟล์บทไม่ถูกต้อง: %s" % path)
		return []
	return data["lines"]


func _on_line_started(line: Dictionary) -> void:
	# คำสั่งเสริมในแต่ละบรรทัดของบท (ไม่ใส่ก็ได้)
	if line.has("camera_x"):
		camera.pan_to(float(line["camera_x"]))
	if line.get("event", "") == "train":
		train.pass_by()


func _unhandled_key_input(event: InputEvent) -> void:
	if other_scene != "" and event.is_pressed() and event is InputEventKey and event.keycode == KEY_TAB:
		get_tree().change_scene_to_file(other_scene)
	if event.is_pressed() and event is InputEventKey and event.keycode == KEY_T:
		set_morning(not morning)


func _on_finished() -> void:
	# ฉากตัวอย่าง: จบแล้ววนกลับไปเริ่มใหม่
	await get_tree().create_timer(1.0).timeout
	dialogue_box.start(load_lines(_dialogue_path()))
