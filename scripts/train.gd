class_name Train
extends Sprite2D
## รถไฟที่วิ่งผ่านฉากเป็นระยะ หรือเมื่อบทสั่งด้วย "event": "train"

@export var speed := 140.0
## วิ่งเองทุกกี่วินาที (0 = วิ่งเฉพาะตอนบทสั่ง)
@export var auto_interval := 14.0
@export var start_x := -320.0
@export var end_x := 900.0

var _running := false
var _idle_time := 0.0


func _ready() -> void:
	visible = false


func pass_by() -> void:
	position.x = start_x
	visible = true
	_running = true
	_idle_time = 0.0


func _process(delta: float) -> void:
	if not _running:
		_idle_time += delta
		if auto_interval > 0.0 and _idle_time >= auto_interval:
			pass_by()
		return
	position.x += speed * delta
	if position.x > end_x:
		_running = false
		visible = false
