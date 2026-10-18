@tool
class_name SchoolCourtyard3D
extends Node3D
## ลานหน้าอาคารเรียน 2.5D: ลานคอนกรีต ทางเดินมีหลังคา แนวพุ่มไม้ สนามหญ้ากับทางเดิน ต้นไม้ ม้านั่ง
## ภาพและตำแหน่งจาก tools/make_courtyard.py (assets/bg/school/courtyard/courtyard.json)
## แต่ละชิ้นเป็นแผ่น/กล่องที่ความลึกจริง (เมตร) ระบายด้วยภาพของมันฉายจากกล้องออกแบบเดียวกับตัวอาคาร
## (shaders/projected_paint.gdshader): กล้องนิ่งได้ภาพตามที่วาด มองเฉียงแล้วชิ้นใกล้-ไกลเลื่อนต่างกัน

const DIR := "res://assets/bg/school/courtyard/"
const SHADER := preload("res://shaders/projected_paint.gdshader")
const SIDE_SHADE := Color(0.72, 0.74, 0.8)


func _ready() -> void:
	_build()


## จางเข้า/ออกแบบพิกเซล (0 ไม่เห็น, 1 เห็นเต็ม): ตอนกล้องเดินเข้าภาพทางเข้าระยะใกล้
func set_fade(amount: float) -> void:
	visible = amount > 0.0
	for mesh in get_children():
		var mat := (mesh as MeshInstance3D).material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("fade", amount)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "courtyard.json"))
	for layer: Dictionary in layout.layers:
		var front := SurfaceTool.new()
		var side := SurfaceTool.new()
		front.begin(Mesh.PRIMITIVE_TRIANGLES)
		side.begin(Mesh.PRIMITIVE_TRIANGLES)
		var sides := false
		for f: Dictionary in layer.faces:
			match str(f.type):
				"z":
					_quad(front, Vector3(f.x0, f.y1, f.z), Vector3(f.x1, f.y1, f.z),
							Vector3(f.x1, f.y0, f.z), Vector3(f.x0, f.y0, f.z))
				"y":
					_quad(front, Vector3(f.x0, f.y, f.z0), Vector3(f.x1, f.y, f.z0),
							Vector3(f.x1, f.y, f.z1), Vector3(f.x0, f.y, f.z1))
				"box":
					_quad(front, Vector3(f.x0, f.y1, f.zf), Vector3(f.x1, f.y1, f.zf),
							Vector3(f.x1, f.y0, f.zf), Vector3(f.x0, f.y0, f.zf))
					for x: float in [f.x0, f.x1]:
						_quad(side, Vector3(x, f.y1, f.zf), Vector3(x, f.y1, f.zb),
								Vector3(x, f.y0, f.zb), Vector3(x, f.y0, f.zf))
					sides = true
		var paint: Texture2D = load(DIR + str(layer.paint) + ".png")
		var origin := Vector2(layer.origin[0], layer.origin[1])
		_add(str(layer.paint), front, paint, origin, Color.WHITE)
		if sides:
			_add(str(layer.paint) + "_sides", side, paint, origin, SIDE_SHADE)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)


func _add(node_name: String, st: SurfaceTool, paint: Texture2D, origin: Vector2, tint: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = st.commit()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("paint", paint)
	mat.set_shader_parameter("design_camera", SchoolBuilding3D.DESIGN_CAMERA)
	mat.set_shader_parameter("origin_px", origin)
	mat.set_shader_parameter("px_per_m", SchoolBuilding3D.PX_PER_M * SchoolBuilding3D.PAINT_SCALE)
	mat.set_shader_parameter("tint", tint)
	mesh.material_override = mat
	add_child(mesh)
