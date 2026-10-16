extends Node
## ฉากเปิดเรื่อง (data/prologue.json): เช้าวันฝนตก ซันเดินไปโรงเรียน (ขวาไปซ้าย) ถึงทางม้าลายแล้วรอไฟ
## สายฝนเดินตากฝนมาจากทางซ้าย เข้ามายืนใต้ร่มชิดตัว คุยกัน ซันขยับหนีครึ่งก้าว เธอขยับตาม
## ไฟคนข้ามเขียว จบด้วยการ์ดชื่อตอน
## ผู้เล่นบังคับเดินได้เฉพาะช่วงเดินไปทางม้าลาย ที่เหลือเป็นฉากที่เล่นเอง (แตะเพื่อไปบรรทัดถัดไป)

@export_file("*.json") var script_file := "res://data/prologue.json"
@export var hero: Node2D
@export var heroine: Node2D
@export var crossing_signal: Node2D
@export var camera: Node
@export var dialogue_box: DialogueBox
@export var touch_controls: Control
@export var cards: Node
## ตำแหน่งที่ซันยืนรอที่ขอบทางม้าลาย (พิกัดโลก) และขอบขวาที่เดินถอยไปได้
@export var wait_x := -170.0
@export var start_limit := 410.0
## สายฝนเริ่มเดินจากซ้ายนอกจอ แล้วหยุดชิดซ้ายของซัน (เทียบตำแหน่งซัน)
@export var heroine_from := -330.0
@export var heroine_stop := -18.0
## ระยะที่ซันขยับหนี (และเธอขยับตาม) กับระยะที่เธอเบียดเข้ามาอีก
@export var step_aside := 8.0
@export var lean := 3.0

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
	await get_tree().create_timer(1.6).timeout
	await _say("intro")
	await _walk_to_crossing()
	camera.pan_to(220.0)                       # เลื่อนกล้องไปทางซ้าย: เห็นทางที่เธอจะเดินมา
	await _say("red_light")
	await _heroine_arrives()
	camera.pan_to(296.0)                       # ทั้งคู่อยู่กลางจอ
	await _say("under")
	await _shuffle(step_aside)
	await _say("step_aside")
	await _lean_in()
	crossing_signal.go_green()
	await crossing_signal.walk_lit
	await get_tree().create_timer(0.8).timeout
	await _say("green")
	await cards.play_ending()


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


## สายฝนเดินเข้ามา (มีเสียงเล่าระหว่างทาง) รอทั้งคู่: เธอเดินถึง และผู้เล่นอ่านบรรทัดจบ
func _heroine_arrives() -> void:
	var state := {"walked": false, "read": false}
	heroine.enter(hero.position.x + heroine_from, hero.position.x + heroine_stop)
	heroine.arrived.connect(func(): state.walked = true, CONNECT_ONE_SHOT)
	await get_tree().create_timer(2.5).timeout
	dialogue_box.start(_lines.get("approach", []))
	dialogue_box.finished.connect(func(): state.read = true, CONNECT_ONE_SHOT)
	while not (state.walked and state.read):
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout


## ซันขยับหนีครึ่งก้าว แล้วเธอขยับตาม (ระยะเท่าเดิม)
func _shuffle(dx: float) -> void:
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(hero, "position:x", hero.position.x + dx, 0.35)
	t.tween_interval(0.35)
	t.tween_property(heroine, "position:x", heroine.position.x + dx, 0.3)
	await t.finished
	await get_tree().create_timer(0.3).timeout


## เธอเบียดเข้ามาชิดอีกนิด
func _lean_in() -> void:
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(heroine, "position:x", heroine.position.x + lean, 0.5)
	await t.finished


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
