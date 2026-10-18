class_name PromptButton
extends Button
## ปุ่มกลางล่างจอให้ผู้เล่นกดก่อนเรื่องจะไปต่อ ("ข้ามทางม้าลาย ▶", "ทักลูกแมว ▶"): ค่อยๆ ขึ้นมา กดแล้วจางหายไป
## คลิก แตะ หรือ Enter/Space (ปุ่มรับโฟกัส) ใช้: var b := PromptButton.open(ui, "ข้อความ"); await b.chosen

## กดแล้ว (หรือ choose() จากที่อื่น เช่นแตะที่ลูกแมว)
signal chosen

const FONT := preload("res://assets/fonts/Sarabun-Regular.ttf")
const ROW_Y := 292.0

var _done := false


static func open(ui: Node, label: String) -> PromptButton:
	var b := PromptButton.new()
	b.text = label
	ui.add_child(b)
	return b


func _ready() -> void:
	add_theme_font_override("font", FONT)
	add_theme_font_size_override("font_size", 15)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.08, 0.16, 0.9) if state != "hover" else Color(0.12, 0.15, 0.28, 0.95)
		style.border_color = Color(0.85, 0.9, 1.0, 0.85)
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 4
		style.content_margin_bottom = 6
		add_theme_stylebox_override(state, style)
	add_theme_color_override("font_color", Color(0.93, 0.95, 1.0))
	add_theme_color_override("font_hover_color", Color(1, 1, 1))
	modulate.a = 0.0
	pressed.connect(choose)
	await get_tree().process_frame               # รู้ขนาดปุ่มแล้วค่อยวางกลางจอ
	position = Vector2((640.0 - size.x) / 2.0, ROW_Y)
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)
	grab_focus()


func choose() -> void:
	if _done:
		return
	_done = true
	disabled = true
	chosen.emit()
	var hide := create_tween()
	hide.tween_property(self, "modulate:a", 0.0, 0.25)
	hide.tween_callback(queue_free)
