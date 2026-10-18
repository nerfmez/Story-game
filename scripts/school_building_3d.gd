@tool
class_name SchoolBuilding3D
extends Node3D
## อาคารเรียน 3 ชั้นแบบ 2.5D จากภาพหน้าอาคารของผู้เขียน (art_source/school_building.png)
## ขึ้นรูปเป็นกล่องที่ความลึกจริง: เสา/ระเบียง (z 0) ผนังห้องเรียนและผนังบันได (z -2.5) ทางเดินในโถง (z -6)
## กันสาด เสากันสาด บันไดหน้า (ยื่นออกมา) หลังคาลาดไปถึงสันที่ z -5
## ทุกหน้าระบายด้วยภาพเดิมฉายจากกล้องออกแบบ (shaders/projected_paint.gdshader):
## มองจากจุด DESIGN_CAMERA ได้ภาพเหมือนต้นฉบับ ขยับ/หมุนกล้องเล็กน้อยแล้วชั้นต่างๆ เลื่อนซ้อนกันแบบ 3D
## ภาพแต่ละชั้นที่เติมส่วนที่ถูกบังไว้: tools/make_building_layers.py
## หน่วย: เมตร 50px = 1m, x 0 = กลางอาคาร (px 1083.5), y 0 = พื้น (px 668)

const PAINT := {
	"front": preload("res://assets/bg/school/building/front.png"),
	"mid": preload("res://assets/bg/school/building/mid.png"),
	"back": preload("res://assets/bg/school/building/back.png"),
	"props": preload("res://assets/bg/school/building/props.png"),
}
const SHADER := preload("res://shaders/projected_paint.gdshader")
const PX_PER_M := 50.0
const ORIGIN_PX := Vector2(1083.5, 668.0)
## จุดที่ภาพต้นฉบับ "ถูกมอง": ระดับสายตา 1.6m ห่างหน้าอาคาร 30m
const DESIGN_CAMERA := Vector3(0.0, 1.6, 30.0)
const SIDE_SHADE := Color(0.72, 0.74, 0.8)
const END_WALL := Color(0.36, 0.39, 0.47)       # ผนังหัวท้ายอาคาร (ภาพไม่มีด้านข้าง)

## ตำแหน่งในภาพ (px) ตรงกับ tools/make_building_layers.py
const PILLARS := [[73, 109], [372, 398], [650, 675], [921, 945], [1220, 1245], [1490, 1515],
		[1769, 1794], [2057, 2094]]
const HALL := [945, 1220]
const PASSAGE_END := 1122                        # โถง: ซ้ายเป็นทางเดินลึก ขวาเป็นผนังบันไดหันออกมา
const BENCH := [948, 1028, 602, 647]
const PARAPETS := [[271, 329], [435, 496]]
const CEILINGS := [157, 329, 496]
const LEFT := 73
const RIGHT := 2094
const EAVE := [141, 157]
const ROOF_TOP := 74
const ROOF := [13, 2155]
const CANOPY := [884, 1284, 463, 488]
const CANOPY_PILLARS := [[912, 942], [1225, 1252]]
const FLOOR := 645
const GROUND := 668

const Z_PILLAR := [0.15, -0.45]
const Z_WALL := -2.5
const Z_PASSAGE := -6.0
const Z_FLOOR_END := -0.6
const Z_BENCH := -1.2
const Z_EAVE := 1.0
const Z_RIDGE := -5.0
const Z_BACK := -10.0
const Z_CANOPY := 1.8
const Z_CANOPY_PILLAR := [1.55, 1.25]
const Z_STEPS := [1.9, 2.3]

var _tools := {}


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_tools.clear()
	# ผนังห้องเรียนหลังระเบียง ต่อไปถึงผนังบันไดฝั่งขวาของโถง (ช่องลม นาฬิกา บอร์ด ถังขยะ อยู่ระนาบเดียวกัน)
	# เว้นช่องทางเดินลึกฝั่งซ้ายของโถง
	_face_z("back", LEFT, HALL[0], CEILINGS[0], FLOOR, Z_WALL)
	_face_z("back", PASSAGE_END, RIGHT, CEILINGS[0], FLOOR, Z_WALL)
	# ทางเดินลึกเข้าไปในโถง (ภาพวาดเป็นมุมมองลึกอยู่แล้ว: ผนังหลังแผ่นเดียว) ผนังข้าง เพดาน
	_face_z("back", HALL[0], PASSAGE_END, CEILINGS[0], FLOOR, Z_PASSAGE)
	for x in [HALL[0], PASSAGE_END]:
		_face_x("back", x, CEILINGS[0], FLOOR, Z_WALL, Z_PASSAGE)
	for y in CEILINGS:
		_face_y("back", LEFT, RIGHT, y, Z_EAVE if y == CEILINGS[0] else 0.0, Z_WALL)
		_face_y("back", HALL[0], PASSAGE_END, y, Z_WALL, Z_PASSAGE)
	# พื้นทางเดินชั้นล่าง แค่ช่วงหน้า (ต่อจากนั้นผนังลงต่ำกว่าพื้น ของที่วางชิดผนังจึงไม่ถูกลากยืดบนพื้น)
	_face_y("back", LEFT, RIGHT, FLOOR, 0.0, Z_FLOOR_END)
	# ม้านั่งหน้าทางเดินโถง (แผ่นตั้งของมันเอง)
	_face_z("props", BENCH[0], BENCH[1], BENCH[2], BENCH[3], Z_BENCH)
	# เสา (คู่กลางหยุดที่หลังคากันสาด) ระเบียง ขอบพื้น
	for p in PILLARS:
		var hall_pillar: bool = p[1] == HALL[0] or p[0] == HALL[1]
		var bottom: int = CANOPY[2] if hall_pillar else GROUND
		_box("mid", p[0], p[1], CEILINGS[0], bottom, Z_PILLAR[0], Z_PILLAR[1])
	for r in PARAPETS:
		_face_z("mid", LEFT, RIGHT, r[0], r[1], 0.0)
	_face_z("mid", LEFT, RIGHT, FLOOR, GROUND, 0.0)
	# ชายคา หลังคา
	_face_z("front", ROOF[0], ROOF[1], EAVE[0], EAVE[1], Z_EAVE)
	_slope("front", ROOF[0], ROOF[1], EAVE[0], Z_EAVE, ROOF_TOP, Z_RIDGE)
	# กันสาดทางเข้า เสากันสาด บันไดหน้า
	_box("front", CANOPY[0], CANOPY[1], CANOPY[2], CANOPY[3], Z_CANOPY, 0.0)
	for p in CANOPY_PILLARS:
		_box("front", p[0], p[1], CANOPY[3], FLOOR, Z_CANOPY_PILLAR[0], Z_CANOPY_PILLAR[1])
	_box("front", 907, 1257, FLOOR, 656, Z_STEPS[0], 0.0)
	_box("front", 898, 1266, 656, GROUND, Z_STEPS[1], 0.0)
	# หัวท้ายอาคาร (สีเรียบ)
	for x in [LEFT, RIGHT]:
		var a := at(x, GROUND, Z_PILLAR[1])
		var top := my(EAVE[1])
		_quad("end", a, Vector3(a.x, a.y, Z_BACK), Vector3(a.x, top, Z_BACK), Vector3(a.x, top, a.z))
	_commit()


static func mx(px: float) -> float:
	return (px - ORIGIN_PX.x) / PX_PER_M


static func my(py: float) -> float:
	return (ORIGIN_PX.y - py) / PX_PER_M


func _tool(key: String) -> SurfaceTool:
	if not _tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[key] = st
	return _tools[key]


func _quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var st := _tool(key)
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)


## จุดบนเส้นจากกล้องออกแบบผ่านพิกเซล (px, py) ของภาพ ที่ความลึก z: วางหน้าไว้ตรงนี้
## มองจากกล้องออกแบบแล้วหน้านั้นทับพิกเซลเดิมพอดี (ชิ้นที่ลึกกว่าจึงใหญ่กว่านิดหน่อย)
static func at(px: float, py: float, z: float) -> Vector3:
	var k := (DESIGN_CAMERA.z - z) / DESIGN_CAMERA.z
	return Vector3(DESIGN_CAMERA.x + (mx(px) - DESIGN_CAMERA.x) * k,
			DESIGN_CAMERA.y + (my(py) - DESIGN_CAMERA.y) * k, z)


## หน้าตรง (หันหากล้อง) ที่ความลึก z
func _face_z(layer: String, x0: float, x1: float, y0: float, y1: float, z: float) -> void:
	_quad(layer, at(x0, y0, z), at(x1, y0, z), at(x1, y1, z), at(x0, y1, z))


## หน้าข้าง (ระนาบ x คงที่ = ขอบของหน้าตรงที่ z0) จาก z0 ถึง z1
func _face_x(layer: String, x: float, y0: float, y1: float, z0: float, z1: float) -> void:
	var a := at(x, y0, z0)
	var b := at(x, y1, z0)
	var c := at(x, y0, z1)
	var d := at(x, y1, z1)
	_quad(layer, a, Vector3(a.x, c.y, z1), Vector3(a.x, d.y, z1), b)


## หน้าแนวนอน (เพดาน/พื้น) ระดับเดียวกับขอบหน้าที่ z0 ยาวไปถึง z1
func _face_y(layer: String, x0: float, x1: float, y: float, z0: float, z1: float) -> void:
	var h := at(x0, y, z0).y
	var a := at(x0, y, z0)
	var b := at(x1, y, z0)
	var c := at(x1, y, z1)
	var d := at(x0, y, z1)
	_quad(layer, a, b, Vector3(c.x, h, z1), Vector3(d.x, h, z1))


## หลังคาลาด: ขอบชายคา (y0, z0) ขึ้นไปถึงสัน (y1, z1)
func _slope(layer: String, x0: float, x1: float, y0: float, z0: float, y1: float, z1: float) -> void:
	_quad(layer, at(x0, y0, z0), at(x1, y0, z0), at(x1, y1, z1), at(x0, y1, z1))


## กล่อง: หน้า + ข้างซ้ายขวา (มืดลงนิดหน่อย) + บนล่าง (ภาพวาดมีใต้กันสาด/บนขั้นบันไดอยู่แล้ว)
func _box(layer: String, x0: float, x1: float, y0: float, y1: float, zf: float, zb: float) -> void:
	_face_z(layer, x0, x1, y0, y1, zf)
	_face_x(layer + ":side", x0, y0, y1, zf, zb)
	_face_x(layer + ":side", x1, y0, y1, zf, zb)
	_face_y(layer, x0, x1, y0, zf, zb)
	_face_y(layer, x0, x1, y1, zf, zb)


func _commit() -> void:
	for key: String in _tools:
		var mesh := MeshInstance3D.new()
		mesh.name = key.replace(":", "_")
		mesh.mesh = (_tools[key] as SurfaceTool).commit()
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.material_override = _material(key)
		add_child(mesh)


func _material(key: String) -> Material:
	if key == "end":
		var flat := StandardMaterial3D.new()
		flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flat.albedo_color = END_WALL
		flat.cull_mode = BaseMaterial3D.CULL_DISABLED
		return flat
	var parts := key.split(":")
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("paint", PAINT[parts[0]])
	mat.set_shader_parameter("design_camera", DESIGN_CAMERA)
	mat.set_shader_parameter("origin_px", ORIGIN_PX)
	mat.set_shader_parameter("px_per_m", PX_PER_M)
	mat.set_shader_parameter("tint", SIDE_SHADE if parts.size() > 1 else Color.WHITE)
	return mat
