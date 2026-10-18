class_name PhoneCloseup
extends CanvasLayer
## ภาพตัดใกล้ดูจอโทรศัพท์ (assets/ui/phone_closeup.png จาก tools/make_phone_closeup.py)
## ภาพละเอียดกว่าฉาก: 1 พิกเซลของภาพ = 2/3 พิกเซลเกม (ย่อ 2/3: จอ 3 เท่า = 2 พิกเซลจอพอดี) ยังเป็นพิกเซลแต่คมกว่าฉาก
## อยู่เหนือฉากและจอดำ (20) ใต้กล่องข้อความ (30): บทพูดขึ้นทับมือได้ จอโทรศัพท์อยู่เหนือกล่องข้อความ
## show_phone(): ยกขึ้นมาจากขอบล่าง  hide_phone(): ลดลงไป

const TEXTURE := preload("res://assets/ui/phone_closeup.png")

## มุมซ้ายบนของภาพ (พิกัดจอ 640x360) ตอนยกขึ้นมาแล้ว
@export var shown_at := Vector2(110, 22)
## ภาพในเงาครึ้มของฉากฝน (แสงเดียวกับตัวละคร)
@export var tint := Color(0.88, 0.9, 0.98)

var _dim: ColorRect
var _phone: Sprite2D


func _ready() -> void:
	layer = 25
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.03, 0.06, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.modulate.a = 0.0
	add_child(_dim)
	_phone = Sprite2D.new()
	_phone.texture = TEXTURE
	_phone.centered = false
	_phone.scale = Vector2(2.0, 2.0) / 3.0
	_phone.modulate = Color(tint, 0.0)
	_phone.position = shown_at + Vector2(0, 70)
	add_child(_phone)
	visible = false


func show_phone() -> void:
	visible = true
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_dim, "modulate:a", 1.0, 0.4)
	tween.tween_property(_phone, "modulate:a", 1.0, 0.3)
	tween.tween_property(_phone, "position", shown_at, 0.45)
	await tween.finished


func hide_phone() -> void:
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_dim, "modulate:a", 0.0, 0.4)
	tween.tween_property(_phone, "modulate:a", 0.0, 0.35)
	tween.tween_property(_phone, "position", shown_at + Vector2(0, 70), 0.4)
	await tween.finished
	visible = false
