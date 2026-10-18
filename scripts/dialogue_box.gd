class_name DialogueBox
extends Control
## กล่องข้อความแบบ visual novel: ป้ายชื่อ + ข้อความพิมพ์ทีละตัว
## คลิกซ้าย / Space / Enter: ถ้ายังพิมพ์อยู่จะแสดงทั้งบรรทัด ถ้าพิมพ์จบแล้วจะไปบรรทัดถัดไป
## บรรทัดที่มี "pause" (วินาที): เงียบก่อน (กล่องข้อความหายไป แตะไม่ได้) แล้วค่อยพิมพ์ ("event" ของบรรทัดเกิดตั้งแต่เริ่มเงียบ)
## บรรทัดที่มี "auto": true ขึ้นเองไม่ต้องกดเหมือนซับไตเติล (ความคิดระหว่างเดิน ไม่ต้องหยุดเดินมาแตะ)
## ซับไตเติล (คัทซีน) ขึ้นเองไม่ต้องกด: พิมพ์จบแล้วค้างไว้ให้อ่านทัน (subtitle_hold + ตามความยาว) แล้วไปบรรทัดถัดไปเอง
## ข้อความไม่ตัดขอบ (clip_contents = false ใน dialogue_box.tscn): วรรณยุกต์ที่ซ้อนบนสระบน (นี้ ที่) สูงเกินบรรทัดแรก เดิมโดนตัดหาย

signal line_started(line: Dictionary)
signal finished

## จำนวนตัวอักษรที่แสดงต่อวินาที
@export var chars_per_second := 30.0
## ซับไตเติล: ค้างไว้หลังพิมพ์จบ subtitle_hold วินาที บวกเวลาอ่าน (ตัวอักษรต่อวินาที)
@export var subtitle_hold := 1.0
@export var subtitle_read_chars_per_second := 36.0

@onready var _name_tag: PanelContainer = %NameTag
@onready var _name_label: Label = %NameLabel
@onready var _text: RichTextLabel = %Text
@onready var _next_icon: Label = %NextIcon

var _lines: Array = []
var _index := -1
var _typing := false
var _shown := 0.0
var _time := 0.0
## ซับไตเติล (คัทซีน): ไม่มีกล่อง ตัวหนังสือกลางแถบดำล่าง ไม่มีป้ายชื่อ
var _subtitles := false
var _hold := 0.0
var _pause := 0.0
var _auto := false                              # บรรทัดนี้ขึ้นเอง (ซับไตเติล หรือ "auto")
var _box_style: StyleBox


## สลับเป็นซับไตเติลแบบหนัง (ข้อความกลางแถบดำล่าง สูง band_height) หรือกลับเป็นกล่องข้อความปกติ
func set_subtitles(on: bool, band_height := 44.0) -> void:
	_subtitles = on
	var box := $Box as PanelContainer
	if _box_style == null:
		_box_style = box.get_theme_stylebox("panel")
	if on:
		box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		box.offset_top = -band_height
		box.offset_bottom = 0.0
		box.offset_left = 24.0
		box.offset_right = -24.0
		_text.add_theme_font_size_override("normal_font_size", 12)
	else:
		box.add_theme_stylebox_override("panel", _box_style)
		box.offset_top = -82.0
		box.offset_bottom = -8.0
		box.offset_left = 10.0
		box.offset_right = -10.0
		_text.add_theme_font_size_override("normal_font_size", 15)


func start(lines: Array) -> void:
	_lines = lines
	_index = -1
	show()
	_next()


func _next() -> void:
	_index += 1
	if _index >= _lines.size():
		hide()
		finished.emit()
		return
	var line: Dictionary = _lines[_index]
	var speaker := str(line.get("speaker", ""))
	_name_tag.visible = speaker != "" and not _subtitles
	_name_label.text = speaker
	var words := str(line.get("text", ""))
	if _subtitles:                             # ซับไตเติล: ขึ้นบรรทัดใหม่ตรงช่องว่างคู่ในบท (ไม่ตัดคำกลางประโยค)
		words = "[center]%s[/center]" % words.replace("  ", "\n")
	_text.text = words
	_text.visible_characters = 0
	_shown = 0.0
	_pause = float(line.get("pause", 0.0))
	_auto = _subtitles or bool(line.get("auto", false))
	_typing = _pause <= 0.0
	modulate.a = 0.0 if _pause > 0.0 else 1.0
	_next_icon.hide()
	line_started.emit(line)


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	_next_icon.visible = not _auto             # ขึ้นเอง: ไม่มีลูกศรให้แตะ
	_hold = subtitle_hold + _text.get_total_character_count() / subtitle_read_chars_per_second


func _process(delta: float) -> void:
	if not visible:                            # จบบทแล้ว (ซ่อน): ไม่นับเวลาบรรทัดขึ้นเองต่อ ไม่งั้น finished ซ้ำทุกเฟรม
		return
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			modulate.a = 1.0
			_typing = true
	elif _typing:
		_shown += chars_per_second * delta
		_text.visible_characters = int(_shown)
		if _text.visible_characters >= _text.get_total_character_count():
			_finish_typing()
	elif _auto:
		_hold -= delta
		if _hold <= 0.0:
			_next()
	else:
		_time += delta
		_next_icon.modulate.a = 0.55 + 0.45 * sin(_time * 5.0)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _subtitles or _pause > 0.0:   # ซับไตเติลขึ้นเอง / ช่วงเงียบ: แตะแล้วไม่ข้าม
		return
	var pressed: bool = event.is_action_pressed("ui_accept") or (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _typing:
		_finish_typing()
	else:
		_next()
