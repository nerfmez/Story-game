@tool
class_name SchoolEntrance3D
extends Node3D
## ทางเข้าอาคารเรียนระยะใกล้ 2.5D จากภาพของผู้เขียน (art_source/school_entrance_close.png)
## วัดมุมมองจากภาพ: เส้นขอบฟ้า y 520, จุดลับตา x 897 → กล้องอยู่หน้าเสากันสาด 8 ม. สูง 1.08 ม.
## เลนส์ 1160 px (ตรวจกับบันได: 9 ขั้น ลูกตั้ง 0.17 ขั้นบนตกที่ y 454 ตรงกับภาพ)
## ขึ้นรูปตามระยะที่วัดได้: เสากันสาด z 0 ลึก 0.6, ม้านั่ง -1.4, ผนังบอร์ด/ถังขยะ -1.2,
## ผนังซ้ายโถงถึง -3.6, บันไดเริ่ม -3.5 ถึง -5.2, เสาทางเดินมีหลังคา +2.4, พุ่มไม้ +3.4
## ทุกหน้าระบายด้วยภาพฉายจากกล้องของภาพ (shaders/projected_paint.gdshader แบบ pinhole):
## ยืนที่ CAMERA ได้ภาพเหมือนต้นฉบับ เดินเข้าไปแล้วชิ้นใกล้-ไกลเลื่อนต่างกันเหมือนสถานที่จริง
## ภาพแต่ละชั้น: tools/make_entrance_layers.py (ย่อเป็นพิกเซล 640 กว้าง)
## หน่วยเมตร พิกัดเดียวกับ SchoolBuilding3D (แนวเสาหน้าอาคาร z 0, กลางโถง x 0, พื้นลาน y 0)

const PAINT := {
	"full": preload("res://assets/bg/school/entrance/full.png"),
	"back": preload("res://assets/bg/school/entrance/back.png"),
	"cutout": preload("res://assets/bg/school/entrance/cutout.png"),
}
const SHADER := preload("res://shaders/projected_paint.gdshader")
const CAMERA := Vector3(0.57, 1.08, 8.0)
const FOCAL := 1160.0                           # px ของภาพต้นฉบับ (1672x941)
const PRINCIPAL := Vector2(897.0, 520.0)
const SCALE := 640.0 / 1672.0                   # ภาพที่ใช้ระบายย่อเหลือ 640 กว้าง
const SIZE := Vector2(1672.0, 941.0)
const SIDE_SHADE := Color(0.78, 0.8, 0.86)

const HALL_FLOOR := 0.287
const CEILING := 2.92
const STEP_RISE := 0.17
const STEP_RUN := 0.21
const STAIR_Z := -3.5
const STAIR_X := [-2.27, -0.24]

var _tools := {}
var _materials: Array[ShaderMaterial] = []


func _ready() -> void:
	_build()


## จุดบนเส้นจากกล้องของภาพผ่านพิกเซล (px, py) ที่ความลึก z
static func at(px: float, py: float, z: float) -> Vector3:
	var d := CAMERA.z - z
	return Vector3(CAMERA.x + (px - PRINCIPAL.x) * d / FOCAL, CAMERA.y - (py - PRINCIPAL.y) * d / FOCAL, z)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_tools.clear()
	_materials.clear()
	# ลาน (พื้นเปียกสะท้อนแสง) ผนังอาคารสองข้าง แถบชั้น 2 เหนือกันสาด
	_flat_y("back", -14.0, 14.0, 0.0, -1.4, 9.5)
	_front("back", 0, 0, 1672, 196, -0.6)
	_front_to_ground("back", 0, 196, 328, -1.4)
	_front_to_ground("back", 1306, 196, 1672, -1.4)
	# โถง: พื้น เพดาน ผนังซ้าย ผนังข้างช่องบันได คานเหนือบันได ผนังลึกหลังบันได ผนังบอร์ด
	var left := -2.75
	_flat_y("back", left, 2.76, HALL_FLOOR, 0.0, STAIR_Z)
	_flat_y("back", left, 2.76, CEILING, 0.0, -3.6)
	_side("back", left, HALL_FLOOR, CEILING, -0.6, -3.6)
	_front("back", 567, 255, 610, 600, -3.6)
	_front("back", 567, 322, 790, 400, -3.6)
	# หลังบันไดขึ้นไป (ชานพัก ช่วงสองชิดผนังหลัง ชั้นบน) อยู่ใน SchoolInterior3D
	_front("back", 930, 255, 1215, 620, -1.2)
	_stairs()
	# กันสาด เสากันสาด บันไดหน้าทางเข้า (ภาพเต็ม: ไม่มีอะไรบังหน้า)
	_box_front("full", 252, 128, 1398, 182, 1.6, 0.0)
	_flat_y("full", at(252, 182, 1.6).x, at(1398, 182, 1.6).x, at(0, 182, 1.6).y, 1.6, 0.0)
	_box_front("full", 328, 196, 416, 634, 0.0, -0.6)
	_box_front("full", 1214, 196, 1306, 634, 0.0, -0.6)
	_box_front("full", 290, 665, 1340, 692, 0.72, 0.46)
	_box_front("full", 315, 642, 1318, 665, 0.46, 0.0)
	# ของที่ตั้งอยู่: ม้านั่ง ถังขยะ กระถาง พุ่มไม้ ปลายทางเดินมีหลังคา (แผ่นของมันเอง)
	_front("cutout", 446, 508, 640, 622, -1.39)
	_front("cutout", 974, 512, 1192, 623, -1.05)
	_front("cutout", 232, 486, 324, 648, -1.25)
	_front("cutout", 1462, 496, 1554, 645, -1.25)
	_front("cutout", 424, 8, 508, 134, -0.55)
	_front("cutout", 0, 545, 218, 802, 3.44)
	_front("cutout", 1346, 168, 1672, 750, 2.43)
	_commit()


## บันไดตรงขึ้นไปข้างหลัง 9 ขั้น ระหว่างผนังเตี้ยสองข้าง (ราวบนผนัง)
func _stairs() -> void:
	for i in 9:
		var y0 := HALL_FLOOR + STEP_RISE * i
		var z0 := STAIR_Z - STEP_RUN * i
		var st := _tool("back")
		_quad(st, Vector3(STAIR_X[0], y0 + STEP_RISE, z0), Vector3(STAIR_X[1], y0 + STEP_RISE, z0),
				Vector3(STAIR_X[1], y0, z0), Vector3(STAIR_X[0], y0, z0))
		_flat_y("back", STAIR_X[0], STAIR_X[1], y0 + STEP_RISE, z0, z0 - STEP_RUN)
	# ผนังเตี้ยข้างบันได: หน้าตรง ข้างใน ข้างนอก บนเอียงตามบันได
	var z1 := STAIR_Z - STEP_RUN * 8
	for wall: Array in [[-2.62, STAIR_X[0]], [STAIR_X[1], 0.1]]:
		var top0 := at(0, 470, STAIR_Z).y
		var top1 := at(0, 395, z1).y
		var st := _tool("back")
		_quad(st, Vector3(wall[0], top0, STAIR_Z), Vector3(wall[1], top0, STAIR_Z),
				Vector3(wall[1], HALL_FLOOR, STAIR_Z), Vector3(wall[0], HALL_FLOOR, STAIR_Z))
		_quad(st, Vector3(wall[0], top0, STAIR_Z), Vector3(wall[1], top0, STAIR_Z),
				Vector3(wall[1], top1, z1), Vector3(wall[0], top1, z1))
		var sides := _tool("back:side")
		for x: float in wall:
			_quad(sides, Vector3(x, top0, STAIR_Z), Vector3(x, top1, z1),
					Vector3(x, HALL_FLOOR, z1), Vector3(x, HALL_FLOOR, STAIR_Z))


func _tool(key: String) -> SurfaceTool:
	if not _tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[key] = st
	return _tools[key]


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)


## แผ่นหน้าตรงที่ความลึก z ครอบพิกเซล (x0, y0)-(x1, y1) ของภาพพอดี
func _front(key: String, x0: float, y0: float, x1: float, y1: float, z: float) -> void:
	var a := at(x0, y0, z)
	var b := at(x1, y1, z)
	_quad(_tool(key), Vector3(a.x, a.y, z), Vector3(b.x, a.y, z), Vector3(b.x, b.y, z), Vector3(a.x, b.y, z))


## ผนังหน้าตรงลงถึงพื้นลาน
func _front_to_ground(key: String, x0: float, y0: float, x1: float, z: float) -> void:
	var a := at(x0, y0, z)
	var b := at(x1, y0, z)
	_quad(_tool(key), Vector3(a.x, a.y, z), Vector3(b.x, a.y, z), Vector3(b.x, 0.0, z), Vector3(a.x, 0.0, z))


## กล่อง: หน้าตรงครอบพิกเซล ลึกจาก zf ถึง zb ข้างซ้ายขวา บนล่าง
func _box_front(key: String, x0: float, y0: float, x1: float, y1: float, zf: float, zb: float) -> void:
	_front(key, x0, y0, x1, y1, zf)
	var a := at(x0, y0, zf)
	var b := at(x1, y1, zf)
	var sides := _tool(key + ":side")
	for x in [a.x, b.x]:
		_quad(sides, Vector3(x, a.y, zf), Vector3(x, a.y, zb), Vector3(x, b.y, zb), Vector3(x, b.y, zf))
	for y in [a.y, b.y]:
		_quad(_tool(key), Vector3(a.x, y, zf), Vector3(b.x, y, zf), Vector3(b.x, y, zb), Vector3(a.x, y, zb))


func _flat_y(key: String, x0: float, x1: float, y: float, z0: float, z1: float) -> void:
	_quad(_tool(key), Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1))


func _side(key: String, x: float, y0: float, y1: float, z0: float, z1: float) -> void:
	_quad(_tool(key), Vector3(x, y1, z0), Vector3(x, y1, z1), Vector3(x, y0, z1), Vector3(x, y0, z0))


## จางเข้า/ออกแบบพิกเซล (0 ไม่เห็น, 1 เห็นเต็ม)
func set_fade(amount: float) -> void:
	visible = amount > 0.0
	for mat in _materials:
		mat.set_shader_parameter("fade", amount)


func _commit() -> void:
	for key: String in _tools:
		var mesh := MeshInstance3D.new()
		mesh.name = key.replace(":", "_")
		mesh.mesh = (_tools[key] as SurfaceTool).commit()
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var parts := key.split(":")
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("paint", PAINT[parts[0]])
		mat.set_shader_parameter("pinhole", true)
		mat.set_shader_parameter("design_camera", CAMERA)
		mat.set_shader_parameter("principal", PRINCIPAL * SCALE)
		mat.set_shader_parameter("focal", FOCAL * SCALE)
		mat.set_shader_parameter("tint", SIDE_SHADE if parts.size() > 1 else Color.WHITE)
		mesh.material_override = mat
		_materials.append(mat)
		add_child(mesh)
