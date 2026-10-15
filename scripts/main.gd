extends Node
## ฉากหลัก: โหลดบทพูดจาก JSON แล้วสั่งกล่องข้อความ กล้อง และรถไฟตามบท
## ใช้ได้ทั้งฉาก 2D (main.tscn) และ HD-2D (main_3d.tscn)

@export_file("*.json") var dialogue_file := "res://data/chapter1.json"
## กล้องที่มีฟังก์ชัน pan_to(x)
@export var camera: Node
## รถไฟที่มีฟังก์ชัน pass_by()
@export var train: Node
## กด Tab เพื่อสลับไปฉากนี้ (เว้นว่าง = ปิด)
@export_file("*.tscn") var other_scene := ""

@onready var dialogue_box: DialogueBox = $UI/DialogueBox

const SMOOTH_PIXEL := preload("res://shaders/smooth_pixel.gdshader")


func _ready() -> void:
	# บนมือถือ/เบราว์เซอร์ ให้ภาพขยายเต็มจอแบบไม่ต้องเป็นจำนวนเท่าเต็ม (ไม่งั้นภาพเล็กมีขอบดำหนา)
	if OS.has_feature("web") or OS.has_feature("mobile"):
		get_tree().root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	# ฉากและตัวละคร: คมแบบพิกเซลแต่เลื่อนทีละเศษพิกเซลได้ (ชั้นไกลที่เลื่อนช้าจะไม่กระตุก)
	var smooth := ShaderMaterial.new()
	smooth.shader = SMOOTH_PIXEL
	_use_smooth_pixels(self, smooth)
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
		dialogue_box.start(load_lines(dialogue_file))


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
	var label := Label.new()
	label.text = "แตะเพื่อเริ่ม\n(เปิดเสียงด้วยนะ)"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.15))
	label.add_theme_constant_override("outline_size", 6)
	_start_layer.add_child(label)
	var tween := label.create_tween().set_loops()  # ผูกกับ label: หยุดเองเมื่อ label ถูกลบ
	tween.tween_property(label, "modulate:a", 0.45, 0.8)
	tween.tween_property(label, "modulate:a", 1.0, 0.8)


func _input(event: InputEvent) -> void:
	if _start_layer == null:
		return
	var tapped: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventKey and event.pressed)
	if not tapped:
		return
	get_viewport().set_input_as_handled()
	_start_layer.queue_free()
	_start_layer = null
	var ambience := get_node_or_null("Ambience") as AudioStreamPlayer
	if ambience:
		ambience.play()
	dialogue_box.start(load_lines(dialogue_file))


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


func _on_finished() -> void:
	# ฉากตัวอย่าง: จบแล้ววนกลับไปเริ่มใหม่
	await get_tree().create_timer(1.0).timeout
	dialogue_box.start(load_lines(dialogue_file))
