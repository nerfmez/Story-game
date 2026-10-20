class_name ClassroomScene
extends Node
## ตอนที่1 ห้อง 4/5 (ต้นฉบับ: "...4/5 ห้องนี้สินะ" ถึง "ว่าแต่จะไม่มีใครทักท้วงเรื่องชุดของยัยนี่กันเลยรึไง")
## ห้องเรียน 3D (scenes/classroom_3d_pixel.tscn) วางเหนือฉากเดิน (ฝนกับโทนสีของถนนไม่ทับในห้อง) กล้องเล่าเรื่องเอง
## ผู้เล่นแตะทีละบรรทัด:
##   ยืนที่ประตู มองไปรอบห้อง -> เห็นเธอนั่งริมหน้าต่างหลังสุด (ซูมเข้า) -> เดินเข้าไปนั่งโต๊ะตรงหน้าเธอ (มุมสายตาซัน)
##   -> คุยเรื่องการเดินทางข้ามเวลา -> อาจารย์เข้ามา โฮมรูม แนะนำตัว -> สายฝนถามเรื่องชมรมไทม์แมชชีน
## บรรทัดที่มี "shot" = เปลี่ยนมุมกล้อง (มี "move" = เลื่อนไปช้าๆ กี่วินาที ไม่มี = ตัดภาพ)
## ที่นั่งตามผู้เขียน (เปลี่ยนจากต้นฉบับ): สายฝนโต๊ะ 25 หลังสุดริมหน้าต่าง ซันโต๊ะ 19 ตรงหน้าเธอ
## ยังไม่มีภาพอาจารย์ / ท่ายืน / ท่าหันมา: ใช้มุมกล้องเล่าไปก่อน (ภาพจะเปลี่ยนทีหลัง)

const ROOM := preload("res://scenes/classroom_3d_pixel.tscn")
const LAYER := 2                                # เหนือฉากถนนและชั้นฝน/โทนสี (1) ใต้จอดำ (20) และกล่องข้อความ (30)
## มุมกล้อง: ตำแหน่ง, จุดที่มอง, fov (พิกัดห้อง: กระดานอยู่ -z หน้าต่างบานเลื่อนอยู่ -x ประตูอยู่ผนัง +x ด้านหน้า)
const SHOTS := {
	"door": [Vector3(4.55, 1.62, -4.25), Vector3(0.0, 1.1, 1.0), 62.0],
	"sweep": [Vector3(4.45, 1.62, -4.1), Vector3(-3.0, 1.0, 3.8), 62.0],
	"notice": [Vector3(4.3, 1.62, -3.9), Vector3(-4.05, 1.15, 3.35), 24.0],
	"two": [Vector3(-4.85, 1.8, 0.1), Vector3(-3.95, 0.95, 2.7), 56.0],
	"her": [Vector3(-3.3, 1.3, 2.3), Vector3(-4.05, 1.2, 3.4), 46.0],
	"sun": [Vector3(-3.3, 1.3, 0.8), Vector3(-4.05, 1.15, 1.95), 46.0],
	"front": [Vector3(0.35, 1.82, 5.65), Vector3(0.25, 1.42, -4.8), 55.0],
	"class": [Vector3(-0.3, 1.9, -5.2), Vector3(-0.8, 0.9, 3.0), 60.0],
}
## เดินจากประตูไปที่นั่ง (มุมสายตาซัน): หน้าห้อง -> ทางเดินกลางซ้าย -> ระหว่างแถว 4 กับ 5 -> นั่งลง
const WALK := [Vector3(3.6, 1.62, -4.1), Vector3(-1.75, 1.62, -4.0), Vector3(-1.75, 1.62, 2.25),
		Vector3(-3.35, 1.62, 2.25)]
const SEAT_EYE := Vector3(-4.05, 1.18, 1.95)
const WALK_SPEED := 1.3                         # ม./วินาที
const STEP_BOB := 0.025

var prologue: Node
var dialogue_box: DialogueBox
var cards: Node

var _layer: CanvasLayer
var _room: Control
var _camera: Camera3D
var _sun: Node3D
var _look := Vector3.ZERO
var _move: Tween
var _seated := false

signal seated


## ใต้จอดำ: วางห้องเหนือฉากเดิน ซันยังไม่อยู่ที่นั่ง (ยังยืนที่ประตู)
func setup() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)
	_room = ROOM.instantiate()
	_room.scripted = true
	_layer.add_child(_room)
	_camera = _room.get_node("View/SubViewport/Room/Camera3D")
	_sun = _room.get_node("View/SubViewport/Room/SeatedStudents/Seat19_sun")
	_sun.visible = false
	_shot("door", 0.0)
	dialogue_box.line_started.connect(_on_line)


func play() -> void:
	await cards.reveal_scene()
	await prologue._say("class_arrive")
	_walk_to_seat()                              # เดินไปพร้อมความคิดบรรทัดนี้
	await prologue._say("class_seat")
	if not _seated:
		await seated
	await prologue._say("class_talk")
	await prologue._say("class_homeroom")
	await get_tree().create_timer(0.8).timeout
	dialogue_box.line_started.disconnect(_on_line)


func _on_line(line: Dictionary) -> void:
	if line.has("shot"):
		_shot(str(line["shot"]), float(line.get("move", 0.0)))


## มุมกล้องตามชื่อ: seconds 0 = ตัดภาพ, มากกว่านั้น = เลื่อนกล้องไปช้าๆ
func _shot(name: String, seconds: float) -> void:
	var shot: Array = SHOTS[name]
	if _move:
		_move.kill()
	if seconds <= 0.0:
		_place(shot[0], shot[1])
		_camera.fov = shot[2]
		return
	_move = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move.tween_method(_place_from.bind(_camera.position, _look, shot[0], shot[1]), 0.0, 1.0, seconds)
	_move.tween_property(_camera, "fov", shot[2], seconds)


func _place(at: Vector3, look: Vector3) -> void:
	_look = look
	_camera.position = at
	_camera.look_at(look)


func _place_from(t: float, at0: Vector3, look0: Vector3, at1: Vector3, look1: Vector3) -> void:
	_place(at0.lerp(at1, t), look0.lerp(look1, t))


## มุมสายตาซันเดินจากประตูไปตามทางเดินจนถึงโต๊ะ 19 แล้วนั่งลง (มองไปข้างหน้าเสมอ ศีรษะขึ้นลงตามก้าว)
func _walk_to_seat() -> void:
	if _move:
		_move.kill()
	_camera.fov = 62.0
	var from := _camera.position
	var heading := _look
	for point: Vector3 in WALK:
		var seconds := from.distance_to(point) / WALK_SPEED
		var ahead := point + (point - from).normalized() * 3.0
		ahead.y = 1.3
		_move = create_tween()
		_move.tween_method(func(t: float) -> void:
			var at := from.lerp(point, t)
			at.y += absf(sin(t * seconds * 4.5)) * STEP_BOB
			_place(at, heading.lerp(ahead, minf(t * 2.0, 1.0))), 0.0, 1.0, seconds)
		await _move.finished
		from = point
		heading = ahead
	# หันไปทางกระดานแล้วนั่ง
	_move = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move.tween_method(_place_from.bind(from, heading, SEAT_EYE, SEAT_EYE + Vector3(0.2, -0.1, -5.0)), 0.0, 1.0, 1.4)
	await _move.finished
	_sun.visible = true                          # นั่งแล้ว: มุมถัดไปเห็นซันที่โต๊ะ
	_seated = true
	seated.emit()
