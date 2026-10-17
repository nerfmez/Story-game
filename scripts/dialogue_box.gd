class_name DialogueBox
extends Control
## กล่องข้อความแบบ visual novel: ป้ายชื่อ + ข้อความพิมพ์ทีละตัว
## คลิกซ้าย / Space / Enter: ถ้ายังพิมพ์อยู่จะแสดงทั้งบรรทัด ถ้าพิมพ์จบแล้วจะไปบรรทัดถัดไป
## ข้อความไม่ตัดขอบ (clip_contents = false ใน dialogue_box.tscn): วรรณยุกต์ที่ซ้อนบนสระบน (นี้ ที่) สูงเกินบรรทัดแรก เดิมโดนตัดหาย

signal line_started(line: Dictionary)
signal finished

## จำนวนตัวอักษรที่แสดงต่อวินาที
@export var chars_per_second := 30.0

@onready var _name_tag: PanelContainer = %NameTag
@onready var _name_label: Label = %NameLabel
@onready var _text: RichTextLabel = %Text
@onready var _next_icon: Label = %NextIcon

var _lines: Array = []
var _index := -1
var _typing := false
var _shown := 0.0
var _time := 0.0


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
	_name_tag.visible = speaker != ""
	_name_label.text = speaker
	_text.text = str(line.get("text", ""))
	_text.visible_characters = 0
	_shown = 0.0
	_typing = true
	_next_icon.hide()
	line_started.emit(line)


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	_next_icon.show()


func _process(delta: float) -> void:
	if _typing:
		_shown += chars_per_second * delta
		_text.visible_characters = int(_shown)
		if _text.visible_characters >= _text.get_total_character_count():
			_finish_typing()
	else:
		_time += delta
		_next_icon.modulate.a = 0.55 + 0.45 * sin(_time * 5.0)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
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
