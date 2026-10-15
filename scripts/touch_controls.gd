extends Control
## ปุ่มเดินซ้าย-ขวาบนจอ สำหรับมือถือ/แท็บเล็ต (กดค้าง = เดิน, ปล่อย = หยุด)
## แสดงอัตโนมัติเมื่อเครื่องมีจอสัมผัส

@export var walker: Node
## แสดงตลอด (ใช้ทดสอบบนคอม)
@export var always_visible := false

@onready var _left: BaseButton = $Left
@onready var _right: BaseButton = $Right


func _ready() -> void:
	visible = always_visible or DisplayServer.is_touchscreen_available() \
		or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	_left.button_down.connect(_set_dir.bind(-1.0))
	_right.button_down.connect(_set_dir.bind(1.0))
	_left.button_up.connect(_release.bind(-1.0))
	_right.button_up.connect(_release.bind(1.0))


func _set_dir(dir: float) -> void:
	if walker:
		walker.touch_dir = dir


func _release(dir: float) -> void:
	if walker and walker.touch_dir == dir:
		walker.touch_dir = 0.0
