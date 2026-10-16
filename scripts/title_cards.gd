extends CanvasLayer
## ฉากเปิด (คำโปรย + ชื่อเรื่อง) และการ์ดจบตอน บนจอดำที่มีฝนตก
## play_opening(): คำโปรยทีละบรรทัด (ตัวอักษรค่อยๆ จางเข้าเป็นคลื่น + ลอยขึ้นช้าๆ) แล้วชื่อเรื่อง
##   (ตัวอักษรค่อยๆ ชิดกันเข้ามาพร้อมจางเข้า เส้นบางๆ ใต้ชื่อยืดออก) แตะเมื่อไรก็ได้: ข้ามไปชื่อเรื่อง /
##   แตะตอนชื่อเรื่องขึ้นแล้ว = เริ่ม (ส่ง start_pressed: เบราว์เซอร์เปิดเสียงได้หลังผู้เล่นแตะเท่านั้น)
## reveal_scene(): จอดำค่อยๆ จางออกเผยฉาก
## play_ending(): จอค่อยๆ ดำ การ์ดชื่อตอน แตะเพื่อเริ่มใหม่ (ส่ง restart_pressed)

signal start_pressed
signal restart_pressed

const FONT := preload("res://assets/fonts/Sarabun-Regular.ttf")
const RAIN := preload("res://shaders/rain.gdshader")

@export var tagline: Array[String] = [
	"เช้าวันฝนตกวันนั้น เด็กสาวคนหนึ่งเดินเข้ามาใต้ร่มของผม",
	"ราวกับรู้จักผมมานาน... ทั้งที่ผมไม่เคยเห็นหน้าเธอมาก่อนเลย",
]
@export var title := "ถ้าหากโลกนี้ไม่มีฤดูฝน"
@export var chapter_label := "ตอนที่ 1"
@export var chapter_title := "15 เซนติเมตร"

var _black: ColorRect
var _rain: ColorRect
var _items: Array = []
var _waiting := ""          # "", "skip" (แตะเพื่อข้าม), "start", "restart"
var _skip := false


func _ready() -> void:
	layer = 20
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	_rain = ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = RAIN
	m.set_shader_parameter("colour", Color(0.62, 0.68, 0.82, 0.9))
	_rain.material = m
	_rain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rain)


func _input(event: InputEvent) -> void:
	if _waiting == "":
		return
	var tap: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo)
	if not tap:
		return
	get_viewport().set_input_as_handled()
	match _waiting:
		"skip":
			_skip = true
		"start":
			_waiting = ""
			start_pressed.emit()
		"restart":
			_waiting = ""
			restart_pressed.emit()


## รอเป็นวินาที (ข้ามได้ถ้าผู้เล่นแตะข้ามคำโปรย)
func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time()


func _text(bbcode: String, size: int, y: float, colour: Color) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.install_effect(RevealFx.new())
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("normal_font", FONT)
	label.add_theme_font_size_override("normal_font_size", size)
	label.add_theme_color_override("default_color", colour)
	label.position = Vector2(0, y)
	label.size = Vector2(640, size * 2)
	label.text = "[center]" + bbcode + "[/center]"
	add_child(label)
	_items.append(label)
	return label


func _fade_out_items(seconds: float) -> void:
	var items := _items.duplicate()
	_items.clear()
	for item in items:
		var tween: Tween = item.create_tween()
		tween.tween_property(item, "modulate:a", 0.0, seconds)
		tween.tween_callback(item.queue_free)


## ชื่อเรื่อง/ชื่อตอน: ตัวอักษรห่างกันแล้วค่อยๆ ชิดเข้ามาพร้อมจางเข้า เส้นใต้ยืดออกจากกลาง
func _title(text: String, size: int, y: float, seconds: float) -> void:
	var font := FontVariation.new()
	font.base_font = FONT
	font.variation_embolden = 0.35
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0))
	label.position = Vector2(0, y)
	label.size = Vector2(640, size * 1.6)
	label.modulate.a = 0.0
	add_child(label)
	_items.append(label)
	var line := ColorRect.new()
	line.color = Color(0.75, 0.82, 0.95, 0.6)
	line.size = Vector2(200, 1)
	line.position = Vector2(220, y + size * 1.55)
	line.pivot_offset = Vector2(100, 0)
	line.scale.x = 0.0
	add_child(line)
	_items.append(line)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, seconds)
	tween.tween_method(func(v: float): font.spacing_glyph = int(round(v)), 14.0, 2.0, seconds * 1.2)
	tween.tween_property(label, "position:y", y, seconds).from(y + 8.0)
	tween.tween_property(line, "scale:x", 1.0, seconds * 1.1).set_delay(seconds * 0.4)


func _prompt(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	label.position = Vector2(0, 300)
	label.size = Vector2(640, 24)
	label.modulate.a = 0.0
	add_child(label)
	_items.append(label)
	var tween := label.create_tween().set_loops()
	tween.tween_property(label, "modulate:a", 0.85, 1.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "modulate:a", 0.25, 1.1).set_trans(Tween.TRANS_SINE)


func play_opening() -> void:
	_black.modulate.a = 1.0
	_rain.modulate.a = 0.0
	create_tween().tween_property(_rain, "modulate:a", 1.0, 2.0)
	_waiting = "skip"
	_skip = false
	await _wait(1.2)
	var y := 140.0
	for line in tagline:
		if _skip:
			break
		var label := _text("[reveal speed=18 span=10]%s[/reveal]" % line, 17, y, Color(0.86, 0.89, 0.96))
		create_tween().tween_property(label, "position:y", y - 4.0, 4.0).from(y + 6.0).set_trans(Tween.TRANS_SINE)
		await _wait(line.length() / 18.0 + 1.6)
		y += 34.0
	await _wait(1.6)
	_fade_out_items(0.4 if _skip else 1.0)
	await get_tree().create_timer(0.4 if _skip else 1.1).timeout
	_skip = false
	_waiting = ""
	_title(title, 30, 130.0, 2.4)
	await get_tree().create_timer(2.0).timeout
	_prompt("แตะเพื่อเริ่ม")
	_waiting = "start"
	await start_pressed


func reveal_scene() -> void:
	_fade_out_items(0.6)
	await get_tree().create_timer(0.5).timeout
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_black, "modulate:a", 0.0, 2.2)
	tween.tween_property(_rain, "modulate:a", 0.0, 1.2)
	await tween.finished


func play_ending() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_black, "modulate:a", 1.0, 2.0)
	tween.parallel().tween_property(_rain, "modulate:a", 1.0, 2.5)
	await tween.finished
	await get_tree().create_timer(0.8).timeout
	_text("[reveal speed=10 span=6]%s[/reveal]" % chapter_label, 15, 118.0, Color(0.7, 0.76, 0.88))
	await get_tree().create_timer(1.0).timeout
	_title(chapter_title, 30, 140.0, 2.2)
	await get_tree().create_timer(3.0).timeout
	_prompt("แตะเพื่อเล่นอีกครั้ง")
	_waiting = "restart"
	await restart_pressed
