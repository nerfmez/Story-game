extends Node
## ตอนที่1 [15 เซนติเมตร] (บทจากต้นฉบับ: data/prologue.json) ลำดับตามต้นฉบับ:
## การ์ดชื่อตอน -> ซันที่บ้าน (เล่าบนจอดำ) -> ออกมาบนถนน -> ผู้เล่นเดินไปทางม้าลาย (ขวาไปซ้าย) -> รอไฟ ดูเวลา
## (ระหว่างนั้นสายฝนเดินตากฝนมาจากทางซ้ายเงียบๆ) -> "ฉันเกลียดฤดูฝน" ซันสะดุ้ง -> เธอเบียดเข้าใต้ร่ม
## -> ไฟเขียว -> ตัดสินใจเดินต่อ (จอดำ) -> บรรทัดสุดท้ายบนจอดำ -> แตะเพื่อเล่นอีกครั้ง
## ผู้เล่นบังคับเดินได้เฉพาะช่วงเดินไปทางม้าลาย ที่เหลือเล่นเอง (แตะเพื่อไปบรรทัดถัดไป)

@export_file("*.json") var script_file := "res://data/prologue.json"
@export var hero: Node2D
@export var heroine: Node2D
@export var crossing_signal: Node2D
@export var camera: Node
@export var dialogue_box: DialogueBox
@export var touch_controls: Control
@export var cards: Node
## ตำแหน่งที่ซันยืนรอที่ขอบทางม้าลาย (พิกัดโลก) และขอบขวาที่เดินถอยไปได้
## ซันเริ่มที่ x = 1020 (main.tscn): เดินไปทางม้าลาย 1190px ที่ 54px/วินาที ประมาณ 22 วินาที
@export var wait_x := -170.0
@export var start_limit := 1140.0
## สายฝนเริ่มเดินจากซ้ายนอกจอ หยุดข้างซันที่ขอบร่ม แล้ว (ตามบท) เบียดเข้ามาใต้ร่มชิดตัว (เทียบตำแหน่งซัน)
@export var heroine_from := -330.0
@export var heroine_stop := -40.0
@export var heroine_under := -18.0

var _lines := {}
var _hint: Label
var _hint_pulse: Tween


func _ready() -> void:
	var file := FileAccess.open(script_file, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text()) if file else null
	if typeof(data) == TYPE_DICTIONARY:
		_lines = data
	else:
		push_error("อ่านบทไม่ได้: %s" % script_file)
	hero.controllable = false
	_set_touch(false)


func _set_touch(on: bool) -> void:
	if touch_controls and touch_controls.has_method("set_active"):
		touch_controls.set_active(on)


## เล่นบทหนึ่งช่วงจนจบ (ผู้เล่นแตะทีละบรรทัด)
func _say(part: String) -> void:
	dialogue_box.start(_lines.get(part, []))
	await dialogue_box.finished


func begin() -> void:
	dialogue_box.line_started.connect(_on_line)
	await cards.show_chapter()
	await _say("home")                         # ที่บ้าน: เล่าบนจอดำ
	cards.reveal_scene()
	await get_tree().create_timer(2.0).timeout
	await _say("street")
	await _walk_to_crossing()
	camera.pan_to(230.0)                       # เลื่อนกล้องไปทางซ้าย: เห็นทางที่เธอเดินมา
	await _heroine_arrives()
	camera.pan_to(296.0)                       # ทั้งคู่อยู่กลางจอ
	await _say("meet")
	await cards.fade_to_black()
	await _say("end")
	await cards.wait_restart()


## สิ่งที่เกิดในฉากตอนบรรทัดที่มี "event" ขึ้นมา
func _on_line(line: Dictionary) -> void:
	match str(line.get("event", "")):
		"jolt":                                 # ซันสะดุ้งเล็กน้อย
			var t := create_tween().set_trans(Tween.TRANS_SINE)
			t.tween_property(hero, "position:y", hero.position.y - 2.0, 0.07)
			t.tween_property(hero, "position:y", hero.position.y, 0.12)
		"squeeze":                              # เธอเบียดเข้ามาใต้ร่ม
			var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			t.tween_property(heroine, "position:x", hero.position.x + heroine_under, 0.6).set_delay(1.2)
		"green":
			crossing_signal.go_green()


func _walk_to_crossing() -> void:
	hero.min_x = wait_x
	hero.max_x = start_limit
	hero.controllable = true
	_set_touch(true)
	_show_hint()
	var start := hero.position.x
	while hero.position.x > wait_x + 0.5:
		if _hint and absf(hero.position.x - start) > 40.0:
			_hide_hint()
		await get_tree().process_frame
	_hide_hint()
	hero.controllable = false
	hero.touch_dir = 0.0
	_set_touch(false)
	await get_tree().create_timer(0.6).timeout


## รอไฟ ดูเวลา (บท "arrive") ระหว่างนั้นสายฝนเดินตากฝนมาจากทางซ้ายเงียบๆ จนยืนข้างซัน
## รอทั้งคู่: เธอเดินถึง และผู้เล่นอ่านจบ
func _heroine_arrives() -> void:
	var state := {"walked": false, "read": false}
	heroine.enter(hero.position.x + heroine_from, hero.position.x + heroine_stop)
	heroine.arrived.connect(func(): state.walked = true, CONNECT_ONE_SHOT)
	dialogue_box.start(_lines.get("arrive", []))
	dialogue_box.finished.connect(func(): state.read = true, CONNECT_ONE_SHOT)
	while not (state.walked and state.read):
		await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout


func _show_hint() -> void:
	_hint = Label.new()
	_hint.text = "◀  เดินไปโรงเรียน"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0))
	_hint.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.15))
	_hint.add_theme_constant_override("outline_size", 5)
	_hint.position = Vector2(0, 312)
	_hint.size = Vector2(640, 24)
	_hint.modulate.a = 0.0
	dialogue_box.get_parent().add_child(_hint)
	_hint_pulse = _hint.create_tween().set_loops()
	_hint_pulse.tween_property(_hint, "modulate:a", 0.95, 0.9).set_trans(Tween.TRANS_SINE)
	_hint_pulse.tween_property(_hint, "modulate:a", 0.4, 0.9).set_trans(Tween.TRANS_SINE)


func _hide_hint() -> void:
	if _hint == null:
		return
	var hint := _hint
	_hint = null
	_hint_pulse.kill()
	var tween := hint.create_tween()
	tween.tween_property(hint, "modulate:a", 0.0, 0.5)
	tween.tween_callback(hint.queue_free)
