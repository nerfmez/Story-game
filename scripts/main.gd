extends Node2D
## ฉากหลัก: โหลดบทพูดจาก JSON แล้วสั่งกล่องข้อความ กล้อง และรถไฟตามบท

@export_file("*.json") var dialogue_file := "res://data/chapter1.json"

@onready var camera: Camera2D = $Camera2D
@onready var dialogue_box: DialogueBox = $UI/DialogueBox
@onready var train: Train = $TrainLayer/Train


func _ready() -> void:
	dialogue_box.line_started.connect(_on_line_started)
	dialogue_box.finished.connect(_on_finished)
	dialogue_box.start(load_lines(dialogue_file))


static func load_lines(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("เปิดไฟล์บทไม่ได้: %s" % path)
		return []
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or not data.has("lines"):
		push_error("รูปแบบไฟล์บทไม่ถูกต้อง: %s" % path)
		return []
	return data["lines"]


func _on_line_started(line: Dictionary) -> void:
	# คำสั่งเสริมในแต่ละบรรทัดของบท (ไม่ใส่ก็ได้)
	if line.has("camera_x"):
		camera.pan_to(float(line["camera_x"]))
	if line.get("event", "") == "train":
		train.pass_by()


func _on_finished() -> void:
	# ฉากตัวอย่าง: จบแล้ววนกลับไปเริ่มใหม่
	await get_tree().create_timer(1.0).timeout
	dialogue_box.start(load_lines(dialogue_file))
