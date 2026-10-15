extends Node
## ฉากหลัก: โหลดบทพูดจาก JSON แล้วสั่งกล่องข้อความ กล้อง และรถไฟตามบท
## ใช้ได้ทั้งฉาก 2D (main.tscn) และ HD-2D (main_3d.tscn)

@export_file("*.json") var dialogue_file := "res://data/chapter1.json"
## กล้องที่มีฟังก์ชัน pan_to(x)
@export var camera: Node
## รถไฟที่มีฟังก์ชัน pass_by()
@export var train: Node
## กด Tab เพื่อสลับไปฉากนี้ (เว้นว่าง = ปิด)
@export_file("*.tscn") var other_scene := ""

@onready var dialogue_box: DialogueBox = $UI/DialogueBox


func _ready() -> void:
	# บนมือถือ/เบราว์เซอร์ ให้ภาพขยายเต็มจอแบบไม่ต้องเป็นจำนวนเท่าเต็ม (ไม่งั้นภาพเล็กมีขอบดำหนา)
	if OS.has_feature("web") or OS.has_feature("mobile"):
		get_tree().root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
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


func _unhandled_key_input(event: InputEvent) -> void:
	if other_scene != "" and event.is_pressed() and event is InputEventKey and event.keycode == KEY_TAB:
		get_tree().change_scene_to_file(other_scene)


func _on_finished() -> void:
	# ฉากตัวอย่าง: จบแล้ววนกลับไปเริ่มใหม่
	await get_tree().create_timer(1.0).timeout
	dialogue_box.start(load_lines(dialogue_file))
