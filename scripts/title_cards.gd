extends CanvasLayer
## จอดำมีฝนตก: คำโปรย + ชื่อเรื่อง, การ์ดชื่อตอน, เปิด/ปิดฉาก (บทพูดบนจอดำใช้กล่องข้อความ ซึ่งอยู่ชั้นบนกว่านี้)
## play_opening(): "แตะเพื่อเริ่ม" ก่อน (เปิดเสียงได้) แล้วคำโปรยทีละบรรทัดพร้อมเสียงพากย์ (ตัวอักษรค่อยๆ
##   จางเข้าเป็นคลื่นทันเสียงพูด + ลอยขึ้นช้าๆ) แล้วชื่อเรื่อง (ตัวอักษรค่อยๆ ชิดกันเข้ามาพร้อมจางเข้า
##   เส้นบางๆ ใต้ชื่อยืดออก) แตะระหว่างคำโปรย: ข้ามไปชื่อเรื่อง / แตะตอนชื่อเรื่องขึ้นแล้ว = ไปต่อ (ส่ง start_pressed)
## show_chapter(): ชื่อตอนขึ้นแล้วจางออก จอยังดำ
## reveal_scene(): จอดำค่อยๆ จางออกเผยฉาก  fade_to_black(): กลับเป็นจอดำ
## wait_restart(): แตะเพื่อเล่นอีกครั้ง (ส่ง restart_pressed)

## แตะครั้งแรก (ก่อนคำโปรย): เบราว์เซอร์เปิดเสียงได้หลังผู้เล่นแตะเท่านั้น เสียงพากย์คำโปรยจึงเริ่มหลังแตะนี้
signal begin_pressed
signal start_pressed
## ขึ้น "แตะเพื่อเริ่ม" แล้ว (การแตะครั้งถัดไปคือการเริ่ม: main.gd ใช้เปิดวิดีโอเปิดเรื่องในจังหวะแตะนั้น)
signal start_ready
signal restart_pressed

const FONT := preload("res://assets/fonts/Sarabun-Regular.ttf")
const RAIN := preload("res://shaders/rain.gdshader")

## คำโปรย: ประโยคจากบทนำของต้นฉบับ (ตรงตามต้นฉบับ ผู้เขียนเลือกช่วง) ทีละหน้า หน้าละไม่เกิน 3 บรรทัด
## แบ่งบรรทัดตรงช่องว่าง/จุดไข่ปลาเดิม แต่ละหน้าเป็นเสียงพากย์ของผู้เขียนทีละไฟล์ (assets/audio/voice/,
## tools/prepare_voice.py) ไฟล์หนึ่งมีได้หลายบรรทัด: [ข้อความ, วินาทีที่เสียงเริ่มพูดบรรทัดนั้นในไฟล์]
@export var tagline: Array = [
	[
		{"voice": "opening_01", "lines": [["ชีวิตมีทางเลือกเสมอ ในทุกๆทางเลือกย่อมที่จะส่งผลแตกต่างกันไป", 0.0]]},
		{"voice": "opening_02", "lines": [["แต่ไม่ว่าจะเลือกทางไหน ผลที่ได้มันจะดีหรือร้าย", 0.0], ["ก็ไม่สามารถย้อนกลับไปเลือกใหม่ได้", 3.9]]},
	],
	[{"voice": "opening_03", "lines": [["ก็มีบ่อยใช่มั้ยล่ะ? รู้งี้ทำแบบนั้นดีกว่า เลือกแบบนั้นดีกว่า?", 0.0]]}],
	[
		{"voice": "opening_04", "lines": [["ถ้าจำไม่ผิด เรื่องราวมันเริ่มตอนเดือนสิงหาคมในปีนั้น", 0.0]]},
		{"voice": "opening_05", "lines": [["ปีแห่งการเริ่มต้นของชีวิตวัยรุ่น", 0.0]]},
	],
	[
		{"voice": "opening_06", "lines": [["เกือบทุกประสบการณ์ครั้งแรกมักจะเกิดขึ้นก็ตอนนี้", 0.0]]},
		{"voice": "opening_07", "lines": [["ช่วงเวลานั้นมีทางแยกมากมายในชีวิต ความเป็นไปได้ไม่มีสิ้นสุด", 0.0]]},
		{"voice": "opening_08", "lines": [["ในโลกที่เวลาเดินไปข้างหน้าอย่างไม่ถอยกลับ", 0.0]]},
	],
	[{"voice": "opening_09", "lines": [["ความจริงแล้ว ผมก็เหมือนๆกับเด็กหนุ่มทั่วไป", 0.0], ["ที่อยากจะใช้ชีวิตเรื่อยเปื่อย แล้วปล่อยให้เวลาไหลผ่านไป", 3.7]]}],
	[{"voice": "opening_10", "lines": [["ก็นะ...ชีวิตวัยรุ่นของผมมันก็ควรจะเป็นอย่างที่ว่ามา.....", 0.0], ["ถ้าในวันนั้นผมไม่ได้เจอกับ 'เธอคนนั้น' ในวันธรรมดาที่ฝนตก", 4.2]]}],
]
@export var title := "ถ้าหากโลกนี้ไม่มีฤดูฝน"
@export var chapter_label := "ตอนที่1"
@export var chapter_title := "15 เซนติเมตร"

var _black: ColorRect
var _rain: ColorRect
var _items: Array = []
var _waiting := ""          # "", "begin" (แตะครั้งแรก), "skip" (แตะเพื่อข้าม), "start", "restart"
var _skip := false
var _voice: AudioStreamPlayer


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
	_voice = AudioStreamPlayer.new()
	_voice.volume_db = -3.0                  # ไฟล์โมโน -19.5 LUFS ออกสองลำโพงดังขึ้น 3 dB: ลดให้เท่าเสียงฝน/วิดีโอ
	add_child(_voice)


func _input(event: InputEvent) -> void:
	if _waiting == "":
		return
	var tap: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo)
	if not tap:
		return
	get_viewport().set_input_as_handled()
	match _waiting:
		"begin":
			_waiting = ""
			begin_pressed.emit()
		"skip":
			_skip = true
			_voice.stop()
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
	label.clip_contents = false              # วรรณยุกต์บนสระบน (นี้ ที่) สูงเกินบรรทัด: ไม่ตัดทิ้ง
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
	var streams := {}
	for page in tagline:
		for clip in page:
			streams[clip.voice] = load("res://assets/audio/voice/%s.ogg" % clip.voice)
			if OS.has_feature("web") and not AudioServer.is_stream_registered_as_sample(streams[clip.voice]):
				AudioServer.register_stream_as_sample(streams[clip.voice])   # เตรียมไว้ก่อน เสียงแรกไม่ดีเลย์
	await get_tree().create_timer(1.0).timeout
	_prompt("แตะเพื่อเริ่ม  (เปิดเสียง)")
	_waiting = "begin"
	await begin_pressed
	clear_now()
	_waiting = "skip"
	_skip = false
	await _wait(1.0)
	for page in tagline:
		if _skip:
			break
		var count := 0
		for clip in page:
			count += clip.lines.size()
		var y: float = 180.0 - count * 17.0
		for clip in page:
			if _skip:
				break
			var stream: AudioStream = streams[clip.voice]
			_voice.stream = stream
			_voice.play()
			var t := 0.0
			for i in clip.lines.size():
				var line: String = clip.lines[i][0]
				var at: float = clip.lines[i][1]
				await _wait(at - t)
				t = at
				if _skip:
					break
				# ตัวอักษรค่อยๆ ขึ้นทันเสียงพูดบรรทัดนั้น (ไม่ช้ากว่า 9 หรือเร็วกว่า 18 ตัว/วินาที)
				var speaking: float = (clip.lines[i + 1][1] if i + 1 < clip.lines.size() else stream.get_length()) - at
				var speed := clampf(line.length() / maxf(speaking - 0.4, 0.5), 9.0, 18.0)
				var label := _text("[reveal speed=%.1f span=10]%s[/reveal]" % [speed, line], 17, y, Color(0.86, 0.89, 0.96))
				create_tween().tween_property(label, "position:y", y - 4.0, 4.0).from(y + 6.0).set_trans(Tween.TRANS_SINE)
				y += 34.0
			await _wait(stream.get_length() - t + 0.2)
		await _wait(0.6)
		_fade_out_items(0.4 if _skip else 0.6)
		await get_tree().create_timer(0.4 if _skip else 0.7).timeout
	_voice.stop()
	_skip = false
	_waiting = ""
	_title(title, 30, 130.0, 2.4)
	await get_tree().create_timer(2.0).timeout
	_prompt("แตะเพื่อไปต่อ")
	_waiting = "start"
	start_ready.emit()
	await start_pressed


func reveal_scene() -> void:
	_fade_out_items(0.6)
	await get_tree().create_timer(0.5).timeout
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_black, "modulate:a", 0.0, 2.2)
	tween.tween_property(_rain, "modulate:a", 0.0, 1.2)
	await tween.finished


## ข้อความบอกเวลา/สถานที่บนจอดำ (เหนือกล่องข้อความ) จางออกเองด้วย clear_caption()
func caption(text: String) -> void:
	_text("[reveal speed=16 span=8]%s[/reveal]" % text, 15, 150.0, Color(0.78, 0.83, 0.94))


func clear_caption() -> void:
	_fade_out_items(0.8)


## ลบข้อความบนจอทันที (ตอนวิดีโอเปิดเรื่องขึ้นมาทับ: จบวิดีโอแล้วจะได้ไม่เห็นชื่อเรื่องค้าง)
func clear_now() -> void:
	for item in _items:
		item.queue_free()
	_items.clear()


func show_chapter() -> void:
	if _items.is_empty():                    # ชื่อเรื่องถูกลบไปแล้ว (มีวิดีโอเปิดเรื่อง): ขึ้นชื่อตอนเลย
		await get_tree().create_timer(0.3).timeout
	else:
		_fade_out_items(0.8)                 # ชื่อเรื่องกับ "แตะเพื่อเริ่ม" จางออกก่อน
		await get_tree().create_timer(1.4).timeout
	_text("[reveal speed=10 span=6]%s[/reveal]" % chapter_label, 15, 118.0, Color(0.7, 0.76, 0.88))
	await get_tree().create_timer(0.9).timeout
	_title(chapter_title, 30, 140.0, 2.2)
	await get_tree().create_timer(3.4).timeout
	_fade_out_items(1.0)
	await get_tree().create_timer(1.2).timeout


func fade_to_black() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_black, "modulate:a", 1.0, 2.0)
	tween.parallel().tween_property(_rain, "modulate:a", 1.0, 2.5)
	await tween.finished


func wait_restart() -> void:
	_prompt("แตะเพื่อเล่นอีกครั้ง")
	_waiting = "restart"
	await restart_pressed
