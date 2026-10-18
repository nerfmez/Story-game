extends Node3D
## รถไฟ 3D: ตู้สามตู้ที่มีหน้าต่างเรืองแสง วิ่งผ่านบนคันทางรถไฟ

@export var speed := 9.0
## วิ่งเองทุกกี่วินาที (0 = วิ่งเฉพาะตอนบทสั่ง)
@export var auto_interval := 14.0
@export var start_x := -45.0
@export var end_x := 45.0

var _running := false
var _idle_time := 0.0


func _ready() -> void:
	_build()
	visible = false


func _build() -> void:
	var body := StandardMaterial3D.new()
	body.albedo_color = Color(0.4, 0.42, 0.6)
	var window := StandardMaterial3D.new()
	window.albedo_color = Color(1.0, 0.85, 0.55)
	window.emission_enabled = true
	window.emission = window.albedo_color
	window.emission_energy_multiplier = 2.5
	for car in 3:
		var x := car * 6.4
		_add_box(Vector3(6.0, 2.4, 2.6), Vector3(x, 1.2, 0), body)
		for w in 5:
			_add_box(Vector3(0.7, 0.6, 0.05), Vector3(x - 2.2 + w * 1.1, 1.6, 1.31), window)


func _add_box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


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
