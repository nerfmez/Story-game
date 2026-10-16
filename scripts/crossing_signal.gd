extends Node2D
## เสาไฟสัญญาณที่ทางม้าลาย (ภาพจาก tools/compose_crossing.py): ไฟรถ + ไฟคนข้าม
## ไฟที่ติดมีแสงฟุ้งรอบดวง (additive) และเงาสะท้อนยาวบนถนนเปียก ระยิบตามระลอกน้ำ
## รอ (wait): รถไฟเขียว คนข้ามไฟแดง  go_green(): รถเหลือง -> แดง แล้วคนข้ามไฟเขียว (คนเดินสลับท่า)

signal walk_lit

const POLE := preload("res://assets/props/signal_pole.png")
const GLOW := preload("res://assets/props/glow.png")
const STREAK := preload("res://assets/props/streak.png")
## ตำแหน่งดวงไฟในภาพเสา (มุมซ้ายบนของดวง / หน้าต่าง) ตาม compose_crossing.py
const CAR_LAMPS := [Vector2(21, 3), Vector2(21, 12), Vector2(21, 21)]
const PED_LAMPS := [Vector2(3, 55), Vector2(3, 67)]
const COLOURS := {
	"car_red": Color(1.0, 0.33, 0.27), "car_yellow": Color(1.0, 0.77, 0.27), "car_green": Color(0.27, 0.92, 0.67),
	"ped_red": Color(1.0, 0.31, 0.25), "ped_green": Color(0.35, 1.0, 0.67),
}
## เงาสะท้อนเริ่มที่ถนน (y ในพิกัดโลก) ใต้เสา
@export var street_y := 290.0
@export var base_y := 283.0

var _lamps := {}
var _time := 0.0
var _green_walk := false


func _ready() -> void:
	var pole := Sprite2D.new()
	pole.texture = POLE
	pole.centered = false
	add_child(pole)
	for kind in ["car_red", "car_yellow", "car_green", "ped_red", "ped_green_a", "ped_green_b"]:
		var lamp := Sprite2D.new()
		lamp.texture = load("res://assets/props/lamp_%s.png" % kind)
		lamp.centered = false
		lamp.visible = false
		add_child(lamp)
		_lamps[kind] = lamp
	set_state("wait")


func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


var _glows: Array = []


## แสงฟุ้งรอบดวงไฟ + เงาสะท้อนบนถนน ของไฟที่ติดอยู่
func _light(centre: Vector2, colour: Color, size: float, reflect: float) -> void:
	var glow := Sprite2D.new()
	glow.texture = GLOW
	glow.material = _additive()
	glow.position = centre
	glow.scale = Vector2.ONE * size / 48.0
	glow.modulate = Color(colour, 0.55)
	add_child(glow)
	_glows.append(glow)
	if reflect > 0.0:
		var streak := Sprite2D.new()
		streak.texture = STREAK
		streak.material = _additive()
		streak.centered = false
		# ห่างจากโคนเสาลงมาเท่าดวงไฟสูงจากโคน (ภาพสะท้อนกลับหัว) ยืดตามมุมที่มองลงถนน
		var mirror_y := street_y + (base_y - centre.y - position.y) * 0.1
		streak.position = Vector2(centre.x - 5, mirror_y - position.y)
		streak.scale = Vector2(1.0, 1.0)
		streak.modulate = Color(colour, reflect)
		streak.set_meta("base_alpha", reflect)
		add_child(streak)
		_glows.append(streak)


func set_state(state: String) -> void:
	for glow in _glows:
		glow.queue_free()
	_glows.clear()
	for lamp in _lamps.values():
		lamp.visible = false
	_green_walk = false
	var car: String = {"wait": "car_green", "yellow": "car_yellow", "red": "car_red", "walk": "car_red"}[state]
	var ped := "ped_green_a" if state == "walk" else "ped_red"
	_lamps[car].visible = true
	_lamps[ped].visible = true
	var car_i := ["car_red", "car_yellow", "car_green"].find(car)
	_light(CAR_LAMPS[car_i] + Vector2(2.5, 2.5), COLOURS[car], 22.0, 0.0)
	var ped_colour: Color = COLOURS["ped_green"] if state == "walk" else COLOURS["ped_red"]
	var ped_lamp: Vector2 = PED_LAMPS[1] if state == "walk" else PED_LAMPS[0]
	_light(ped_lamp + Vector2(4.5, 5.0), ped_colour, 30.0, 0.32)
	_green_walk = state == "walk"


## ไฟรถเหลือง -> แดง แล้วไฟคนข้ามเขียว
func go_green() -> void:
	set_state("yellow")
	await get_tree().create_timer(1.4).timeout
	set_state("red")
	await get_tree().create_timer(0.9).timeout
	set_state("walk")
	walk_lit.emit()


func _process(delta: float) -> void:
	_time += delta
	if _green_walk:
		# คนเดินในไฟเขียวสลับท่าทีละครึ่งวินาที
		var step := int(_time * 2.0) % 2 == 0
		_lamps["ped_green_a"].visible = step
		_lamps["ped_green_b"].visible = not step
	for glow in _glows:
		if glow.has_meta("base_alpha"):
			# เงาสะท้อนระยิบตามระลอกน้ำฝน
			var a: float = glow.get_meta("base_alpha")
			var flicker := 0.75 + 0.25 * sin(_time * 7.3 + glow.position.x) * sin(_time * 3.1)
			glow.modulate.a = a * flicker
			glow.scale.x = 1.0 + 0.15 * sin(_time * 5.0)
