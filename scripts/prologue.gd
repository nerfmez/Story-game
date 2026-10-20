extends Node
## ตอนที่1 [15 เซนติเมตร] (บทจากต้นฉบับ: data/prologue.json) ลำดับตามต้นฉบับ:
## การ์ดชื่อตอน -> ซันที่บ้าน (เล่าบนจอดำ) -> ออกมาบนถนน -> ผู้เล่นเดินไปทางม้าลาย (ขวาไปซ้าย) -> รอไฟ ดูเวลา
## ควักโทรศัพท์ดูเวลา (ภาพตัดใกล้จอ 7:35) -> ถือโทรศัพท์ยืนรอ สายฝนเดินตากฝนมาจากทางซ้ายเงียบๆ จนชิดใต้ร่ม
## -> "ฉันเกลียดฤดูฝน" ซันสะดุ้งเก็บโทรศัพท์
## -> ไฟเขียว -> ปุ่ม "ข้ามทางม้าลาย" -> คัทซีนแบบหนัง: ทั้งคู่เดินข้ามใต้ร่มเดียวกันพร้อมเสียงเล่า "end" -> จอดำ
## -> เดินใต้ร่มเดียวกันเลียบกำแพงโรงเรียนจนถึงประตู เธอเดินเข้าอาคารไปก่อน (scripts/school_walk.gd) -> จอดำ
## -> ห้อง 4/5: นั่งตรงหน้าเธอ คุยเรื่องไทม์แมชชีน โฮมรูม (scripts/classroom_scene.gd) -> จอดำ -> ปุ่ม "ออก"
## ผู้เล่นบังคับเดินได้ช่วงเดินไปทางม้าลายและช่วงเดินไปโรงเรียน ที่เหลือเล่นเอง (แตะเพื่อไปบรรทัดถัดไป)

@export_file("*.json") var script_file := "res://data/prologue.json"
@export var hero: Node2D
@export var heroine: Node2D
@export var crossing_signal: Node2D
@export var camera: Node
@export var dialogue_box: DialogueBox
@export var touch_controls: Control
@export var cards: Node
## ตำแหน่งที่ซันยืนรอที่ขอบทางม้าลาย (พิกัดโลก) และขอบขวาที่เดินถอยไปได้
## ซันเริ่มที่ x = 1730 (main.tscn): เดินไปทางม้าลาย 1900px ที่ 54px/วินาที ประมาณ 35 วินาที (เว้นช่วงเงียบระหว่างเหตุการณ์ระหว่างทาง)
@export var wait_x := -170.0
@export var start_limit := 1850.0
## สายฝนเริ่มเดินจากซ้ายนอกจอ เดินเข้ามาจนชิดใต้ร่มข้างซันเลย แล้วค่อยพูด (เทียบตำแหน่งซัน)
@export var heroine_from := -330.0
@export var heroine_under := -18.0

## ช็อตแคบที่ไฟสัญญาณตอนไฟเขียว: ซูมเท่านี้ กลางจอ = จุดนี้เทียบเสา (ดวงไฟรถ + ไฟคนข้ามอยู่เหนือกล่องข้อความ)
const SIGNAL_ZOOM := 3.0
const SIGNAL_LOOK := Vector2(16.0, 54.0)

## ลูกแมวนั่งอยู่บนทางเท้าตรงนี้ (เท้า) ก่อนถึงทางม้าลาย
const KITTEN_AT := Vector2(100.0, 273.0)

var _lines := {}
var _car: CrossingCar
var _kitten: Kitten
var _kitten_noticed := false
var _walk_holds := 0                            # หยุดเดินชั่วคราว (รถผ่าน / ทักลูกแมว) นับซ้อนกันได้
var _camera_before = null                     # ตำแหน่ง/ซูมกล้องก่อนตัดเข้าแคบที่ไฟสัญญาณ (null = ไม่ได้แคบอยู่)
var _closeup: PhoneCloseup
var _bubble: Node2D
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
	_closeup = PhoneCloseup.new()
	add_child(_closeup)
	_bubble = _make_bubble()
	heroine.add_child(_bubble)


func _set_touch(on: bool) -> void:
	if touch_controls and touch_controls.has_method("set_active"):
		touch_controls.set_active(on)


## เล่นบทหนึ่งช่วงจนจบ (ผู้เล่นแตะทีละบรรทัด)
func _say(part: String) -> void:
	var lines: Array = _lines.get(part, [])
	if lines.is_empty():                       # ช่วงนี้ไม่มีบท (เช่น "home": วิดีโอเปิดเรื่องเล่าไปแล้ว)
		return
	dialogue_box.start(lines)
	await dialogue_box.finished


func begin() -> void:
	dialogue_box.line_started.connect(_on_line)
	await cards.show_chapter()
	var caption := str(_lines.get("caption", ""))
	if caption != "":                          # บอกเวลาบนจอดำ (ตอนนี้ว่าง: วิดีโอเปิดเรื่องเล่าไปแล้ว)
		cards.caption(caption)
		await get_tree().create_timer(2.5).timeout
	await _say("home")                         # ที่บ้าน: เสียงในใจบนจอดำ (มีแต่เสียงฝน)
	if caption != "":
		cards.clear_caption()
	cards.reveal_scene()
	await get_tree().create_timer(2.0).timeout
	await _say("street")
	_add_walk_props()
	await _walk_to_crossing()
	camera.pan_to(230.0)                       # เลื่อนกล้องไปทางซ้าย: เห็นทางที่เธอเดินมา
	await _heroine_arrives()
	camera.pan_to(296.0)                       # ทั้งคู่อยู่กลางจอ
	await _say("meet")
	await _crossing()


## ไฟเขียว: ปุ่มข้ามทางม้าลาย แล้วตัดเป็นคัทซีนแบบหนัง ทั้งคู่เดินข้ามใต้ร่มเดียวกันพร้อมบทตอนจบ
func _crossing() -> void:
	var cross := CrossingCutscene.new()
	cross.hero = hero
	cross.heroine = heroine
	cross.camera = camera
	cross.crossing_signal = crossing_signal
	cross.ui = dialogue_box.get_parent()
	add_child(cross)
	await cross.ask()
	await cross.play()
	dialogue_box.set_subtitles(true, CrossingCutscene.BAR)
	await get_tree().create_timer(0.8).timeout  # ซับไตเติลทั้ง 2 บรรทัดจบก่อนคัทซีน 16 วินาทีมืดลง
	await _say("end")
	await get_tree().create_timer(1.2).timeout
	await cards.fade_to_black()
	cross.restore()                            # ตัวละคร ฝน เสาไฟ กลับเข้าฉาก (ฉากต่อไปใช้ต่อ)
	cross.queue_free()                         # จอดำของคัทซีน (ชั้น 22) บังจอดำมีฝนกับ "แตะเพื่อเล่นอีกครั้ง" (ชั้น 20)
	await _school()
	await _classroom()
	await _finish()


## เดินใต้ร่มเดียวกันไปจนถึงประตูโรงเรียน (เริ่มใต้จอดำ จบที่จอดำ)
func _school() -> void:
	var school := SchoolWalk.new()
	school.prologue = self
	school.hero = hero
	school.heroine = heroine
	school.camera = camera
	school.dialogue_box = dialogue_box
	school.cards = cards
	add_child(school)
	school.setup()
	await school.play()
	await cards.fade_to_black()
	school.queue_free()                        # ตึก 3D ของฉากเดินไม่ต้องเรนเดอร์ต่อในห้องเรียน


## ห้อง 4/5 (เริ่มใต้จอดำ จบที่จอดำ)
func _classroom() -> void:
	var room := ClassroomScene.new()
	room.prologue = self
	room.dialogue_box = dialogue_box
	room.cards = cards
	add_child(room)
	room.setup()
	await room.play()
	await cards.fade_to_black()


func _finish() -> void:
	await PromptButton.open(dialogue_box.get_parent(), "ออก").chosen
	_leave_fullscreen()
	await cards.wait_restart()


## ปุ่ม "ออก" ตอนจบ: บนเว็บออกจากเต็มจอ (ที่เปิดไว้ตอนวิดีโอเปิดเรื่อง) ปลดล็อกแนวนอน, นอกเว็บกลับเป็นหน้าต่าง
func _leave_fullscreen() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
(function () {
	if (screen.orientation && screen.orientation.unlock) { try { screen.orientation.unlock(); } catch (e) {} }
	var exit = document.exitFullscreen || document.webkitExitFullscreen;
	if (exit && (document.fullscreenElement || document.webkitFullscreenElement)) {
		var p = exit.call(document);
		if (p && p.catch) p.catch(function () {});
	}
})();
""")
	elif DisplayServer.window_get_mode() >= DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## ทางลัดสำหรับทดสอบ (เปิดเกมด้วย #cross ท้ายลิงก์): ข้ามไปที่ทั้งคู่ยืนใต้ร่มตอนไฟเขียว แล้วเล่นช่วงข้ามทางม้าลาย
func debug_crossing() -> void:
	dialogue_box.line_started.connect(_on_line)
	hero.position.x = wait_x
	heroine.enter(hero.position.x + heroine_under, hero.position.x + heroine_under)
	crossing_signal.go_green()
	camera.pan_to(296.0)
	cards.reveal_scene()
	await get_tree().create_timer(1.5).timeout
	await _crossing()


## ทางลัดสำหรับทดสอบ (เปิดเกมด้วย #school ท้ายลิงก์): เริ่มที่ช่วงเดินไปโรงเรียนเลย
func debug_school() -> void:
	dialogue_box.line_started.connect(_on_line)
	await _school()
	await _classroom()
	await _finish()


## ทางลัดสำหรับทดสอบ (#class): เริ่มที่ห้องเรียนเลย
func debug_class() -> void:
	dialogue_box.line_started.connect(_on_line)
	heroine.visible = false
	await _classroom()
	await _finish()


## สิ่งที่เกิดในฉากตอนบรรทัดที่มี "event" ขึ้นมา
func _on_line(line: Dictionary) -> void:
	# บรรทัดที่เธอพูด (ชื่อผู้พูด "???") = ฟองคำพูดเด้งขึ้นเหนือหัวเธอ เสียงในใจซันและที่ซันพูด ("ซัน") ไม่มี
	var speaker := str(line.get("speaker", ""))
	_show_bubble(speaker != "" and speaker != "ซัน")
	match str(line.get("event", "")):
		"jolt":                                 # ซันสะดุ้งเล็กน้อย แล้วเก็บโทรศัพท์
			hero.put_away_phone()
			_flinch()
		"car":                                  # ซันหยุดเดิน รถวิ่งผ่านเลนใกล้กล้อง น้ำกระเด็น ซันสะดุ้งตอนรถผ่าน (บรรทัดนี้มี pause)
			if _car:
				_hold_walk(true)
				dialogue_box.finished.connect(_hold_walk.bind(false), CONNECT_ONE_SHOT)   # คิดจบแล้วเดินต่อ
				_car.drive_by(hero.position.x)
		"kitten":                               # ซันพูดกับลูกแมว แล้วมันร้องวิ่งหนีไป คิดจบแล้วเดินต่อ
			if _kitten:
				get_tree().create_timer(1.2).timeout.connect(_kitten.run_away)
				dialogue_box.finished.connect(_hold_walk.bind(false), CONNECT_ONE_SHOT)
		"green":
			crossing_signal.go_green()
		"signal_closeup":                       # ตัดเข้าแคบที่ไฟสัญญาณ ไฟเปลี่ยนเป็นเขียว (บรรทัดนี้มี pause ให้เห็นไฟเปลี่ยนก่อนข้อความ)
			_signal_closeup(true)
			crossing_signal.go_green()
		_:
			_signal_closeup(false)              # บรรทัดถัดไป: ตัดกลับมุมเดิม


func _flinch() -> void:
	var y: float = hero.position.y
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(hero, "position:y", y - 2.0, 0.07)
	t.tween_property(hero, "position:y", y, 0.12)


## ของระหว่างทางไปทางม้าลาย: รถที่วิ่งผ่านเลนใกล้กล้อง และลูกแมวบนทางเท้า
func _add_walk_props() -> void:
	_car = CrossingCar.new()
	_car.camera = camera
	_car.passing.connect(_flinch)
	get_parent().add_child(_car)
	_kitten = Kitten.new()
	_kitten.hero = hero
	_kitten.position = KITTEN_AT
	_kitten.noticed.connect(_greet_kitten)
	get_parent().add_child(_kitten)
	# ลำดับการวาด (ไกล -> ใกล้กล้อง): ตัวละคร ลูกแมว (ทางเท้า) รถ (เลนใกล้) แล้วเสาไฟ (ตีนเสาอยู่ขอบล่างจอ)
	# ลูกแมวกับรถผ่านหลังเสาไม่ทะลุ แต่รถอยู่หน้าตัวละคร
	get_parent().move_child(_kitten, crossing_signal.get_index())
	get_parent().move_child(_car, crossing_signal.get_index())


## เดินมาถึงลูกแมว: หยุดเดิน ขึ้นปุ่ม "ทักลูกแมว" (หรือแตะที่ลูกแมว) กดแล้วบรรทัด "when": "kitten" จึงขึ้น
func _greet_kitten() -> void:
	_hold_walk(true)
	var button := PromptButton.open(dialogue_box.get_parent(), "ทักลูกแมว  ▶")
	_kitten.tapped.connect(button.choose, CONNECT_ONE_SHOT)
	await button.chosen
	if _kitten.tapped.is_connected(button.choose):
		_kitten.tapped.disconnect(button.choose)
	_kitten_noticed = true


## หยุด/ให้เดินต่อ (นับซ้อน: เดินได้เมื่อไม่มีอะไรให้หยุดแล้ว) ระหว่างเดินไปทางม้าลาย
func _hold_walk(on: bool) -> void:
	_walk_holds = maxi(_walk_holds + (1 if on else -1), 0)
	var free := _walk_holds == 0
	hero.controllable = free
	if not free:
		hero.touch_dir = 0.0
	_set_touch(free)


## ตัดฉับเข้าแคบที่ดวงไฟสัญญาณ (ไฟรถบน ไฟคนข้ามล่าง) หรือกลับมุมเดิม
func _signal_closeup(on: bool) -> void:
	if on == (_camera_before != null):
		return
	if on:
		_camera_before = {"position": camera.position, "zoom": camera.zoom}
		camera.set_process(false)
		camera.zoom = Vector2.ONE * SIGNAL_ZOOM
		camera.position = crossing_signal.position + SIGNAL_LOOK
	else:
		camera.position = _camera_before["position"]
		camera.zoom = _camera_before["zoom"]
		camera.set_process(true)
		_camera_before = null


func _walk_to_crossing() -> void:
	hero.min_x = wait_x
	hero.max_x = start_limit
	hero.controllable = true
	_set_touch(true)
	_show_hint()
	var start := hero.position.x
	# ความคิดระหว่างเดิน (บท "walk"): แต่ละบรรทัดขึ้นเองเมื่อเดินมาถึงสัดส่วน "at" ของทาง ไม่ต้องหยุดมาแตะ
	# บรรทัดที่มี "when": "kitten" ขึ้นเมื่อแตะลูกแมวหรือเดินมาใกล้มัน (ทีละบรรทัด เมื่อกล่องข้อความว่าง)
	var thoughts: Array = _lines.get("walk", []).duplicate()
	while hero.position.x > wait_x + 0.5:
		var walked := (start - hero.position.x) / maxf(start - wait_x, 1.0)
		if not dialogue_box.visible:
			for line in thoughts:
				var due := _kitten_noticed if str(line.get("when", "")) == "kitten" \
						else walked >= float(line.get("at", 0.0))
				if due:
					thoughts.erase(line)
					dialogue_box.start([line])
					break
		if _hint and absf(hero.position.x - start) > 40.0:
			_hide_hint()
		await get_tree().process_frame
	_hide_hint()
	hero.controllable = false
	hero.touch_dir = 0.0
	_set_touch(false)
	if dialogue_box.visible:                   # ความคิดบรรทัดสุดท้ายยังขึ้นอยู่: ให้จบก่อนควักโทรศัพท์
		await dialogue_box.finished
	await get_tree().create_timer(0.6).timeout


## รอไฟ: ควักโทรศัพท์ขึ้นมาดูเวลา ภาพตัดใกล้จอ (7:35) พร้อมบท "arrive" แล้วถือโทรศัพท์ยืนรอ
## ระหว่างนั้นสายฝนเดินตากฝนมาจากทางซ้ายเงียบๆ จนชิดใต้ร่มข้างซัน
func _heroine_arrives() -> void:
	hero.take_out_phone()
	await hero.phone_out
	await get_tree().create_timer(0.3).timeout
	await _closeup.show_phone()
	await _say("arrive")
	await _closeup.hide_phone()
	heroine.enter(hero.position.x + heroine_from, hero.position.x + heroine_under)
	await heroine.arrived
	await get_tree().create_timer(0.8).timeout


## ฟองคำพูดพิกเซลเล็กๆ เหนือหัวเธอ (บอกว่าบรรทัดนี้เธอพูด)
func _make_bubble() -> Node2D:
	var root := Node2D.new()
	root.position = Vector2(19, 3)              # เหนือหัวเธอ (ภาพเธอสูง 113 หัวเริ่มราวแถว 12)
	root.z_index = 50
	root.visible = false
	var ink := Color(0.16, 0.18, 0.28)
	var paper := Color(0.94, 0.95, 0.99)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = paper
	style.border_color = ink
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = -3
	style.content_margin_bottom = -2
	panel.add_theme_stylebox_override("panel", style)
	var dots := Label.new()
	dots.text = "..."
	dots.add_theme_font_size_override("font_size", 10)
	dots.add_theme_color_override("font_color", ink)
	panel.add_child(dots)
	root.add_child(panel)
	var tail := Polygon2D.new()                 # หางชี้ลงไปที่หัวเธอ
	tail.polygon = PackedVector2Array([Vector2(-3, -1.5), Vector2(2, -1.5), Vector2(-2, 3)])
	tail.color = paper
	root.add_child(tail)
	var edge := Line2D.new()
	edge.points = PackedVector2Array([Vector2(-3, -0.5), Vector2(-2, 3), Vector2(2, -0.5)])
	edge.width = 1.0
	edge.default_color = ink
	root.add_child(edge)
	panel.resized.connect(func(): panel.position = Vector2(-panel.size.x / 2.0, -panel.size.y + 0.5))
	return root


func _show_bubble(on: bool) -> void:
	if on == _bubble.visible:
		return
	_bubble.visible = on
	if on:
		_bubble.scale = Vector2(0.4, 0.4)
		var t := _bubble.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(_bubble, "scale", Vector2.ONE, 0.25)


func _show_hint(text := "◀  เดินไปโรงเรียน") -> void:
	_hint = Label.new()
	_hint.text = text
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
