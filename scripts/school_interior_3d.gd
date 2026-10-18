@tool
class_name SchoolInterior3D
extends Node3D
## ภายในอาคารเรียนต่อจากภาพทางเข้า (SchoolEntrance3D): บันไดขึ้นได้ครบ 3 ชั้น และทางเดินหน้าห้องชั้น 2-3
## บันไดตามที่เห็นในภาพทางเข้าของผู้เขียน: ช่วงแรกตรงขึ้นไปข้างหลังถึงชานพัก ช่วงสองเลี้ยวขวาขึ้นชิดผนังหลัง
## ถึงชั้นบน (ชั้น 2 -> 3 ซ้อนแบบเดียวกัน) ลูกตั้ง 0.17 ม. 9 ขั้นต่อช่วง ชั้นละ 3.06 ม.
## ส่วนที่ไม่มีภาพไหนเห็นจากตรงนั้น ปูด้วยชิ้นลายจากภาพของผู้เขียนเอง (tools/make_interior_tiles.py,
## shaders/tiled_paint.gdshader): ผนังโถง ผนังเตี้ยข้างบันได ขั้นบันได จากภาพทางเข้า; ผนังห้องเรียน
## หน้าต่าง ประตู ระเบียง เสา จากภาพตัวอาคาร
## หน่วยเมตร พิกัดเดียวกับ SchoolEntrance3D (แนวเสาหน้าอาคาร z 0, กลางโถง x 0, พื้นลาน y 0)

const DIR := "res://assets/bg/school/interior/"
const SHADER := preload("res://shaders/tiled_paint.gdshader")

const FLOORS := [0.287, 3.347, 6.407]           # ชั้นล่าง (พื้นโถงในภาพทางเข้า) ชั้น 2 ชั้น 3
const ROOF := 9.4                               # เพดานชั้น 3
const SLAB := 0.427                             # พื้นชั้นบนหนา (ใต้พื้นชั้น 2 = เพดานโถงในภาพ 2.92)
const RISE := 0.17
const STEPS := 9
const RUN_BACK := 0.21                          # ช่วงแรก (ขึ้นไปข้างหลัง) ตามภาพ
const RUN_SIDE := 0.26                          # ช่วงสอง (ชิดผนังหลัง ขึ้นไปทางขวา)
const FLIGHT_BACK_X := [-2.27, -0.24]           # ช่วงแรก กว้างตามภาพ
const FLIGHT_START_Z := -3.5
const LANDING_Z := -5.18                        # ปลายช่วงแรก = ชานพัก
const FLIGHT_SIDE_Z := [-5.4, -6.9]             # ช่วงสอง
const FLIGHT_SIDE_X := 0.1
const BACK := -6.9                              # ผนังหลังช่องบันได
const LEFT := -2.75
const RIGHT := 3.4
const CORRIDOR := [0.0, -2.5]                   # ทางเดินหน้าห้อง (ระเบียง z 0, ผนังห้องเรียน z -2.5)
## เสาระเบียงตามภาพตัวอาคาร (px 50/m กลางอาคาร 1083.5) และช่องห้องเรียนระหว่างเสา
const PILLARS := [[-14.23, -13.71], [-8.67, -8.17], [8.13, 8.63], [13.71, 14.23]]
const BAYS := [[-13.71, -8.67], [-8.17, LEFT], [RIGHT, 8.13], [8.63, 13.71]]
const ENDS := [-14.23, 14.23]

## ลาย: ไฟล์, พิกเซลต่อเมตร
const TILES := {
	"wall": ["hall_wall", 50.0], "parapet": ["parapet", 50.0], "riser": ["riser", 100.0],
	"tread": ["tread", 50.0], "ceiling": ["ceiling", 46.0], "bay": ["bay", 46.0],
	"cpar": ["corridor_parapet", 46.0], "pillar": ["pillar", 46.0],
}

var _tools := {}                                # key -> [SurfaceTool, tile, origin]
var _materials: Array[ShaderMaterial] = []
var _lamps := PackedVector3Array()


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_tools.clear()
	_materials.clear()
	_lamps.clear()
	for k in 3:
		_storey(k)
	for k in 2:
		_flights(k)
	_core()
	for k in [1, 2]:
		_corridor(k)
	_commit()


func _ceiling_of(k: int) -> float:
	return ROOF if k == 2 else FLOORS[k + 1] - SLAB


## พื้นชั้นบน: ช่วงหน้าโถง + ฝั่งขวาของช่องบันได + ชานบนสุดของช่วงสอง (เว้นช่องเหนือบันไดช่วงแรก)
func _storey(k: int) -> void:
	var y: float = FLOORS[k]
	var c := _ceiling_of(k)
	var top_x := FLIGHT_SIDE_X + RUN_SIDE * (STEPS - 1)
	if k > 0:
		var under := y - SLAB + 0.02                # ใต้พื้นชั้น 2 ยกเหนือเพดานโถงในภาพทางเข้านิดหนึ่ง
		_box("tread", "", LEFT, RIGHT, under, y, 0.0, FLIGHT_START_Z)
		_box("tread", "", FLIGHT_SIDE_X, RIGHT, under, y, FLIGHT_START_Z, FLIGHT_SIDE_Z[0])
		_box("tread", "", top_x, RIGHT, under, y, FLIGHT_SIDE_Z[0], BACK)
		# ผนังเตี้ยกั้นช่องบันไดตรงขอบพื้น (ข้างจุดเริ่มบันไดขึ้น)
		_box("parapet", "", LEFT, FLIGHT_BACK_X[0], y, y + 1.0, FLIGHT_START_Z + 0.1, FLIGHT_START_Z)
		_box("parapet", "", FLIGHT_BACK_X[1], FLIGHT_SIDE_X, y, y + 1.0, FLIGHT_START_Z + 0.1, FLIGHT_START_Z)
	else:
		# ใต้บันไดช่วงสองกับฝั่งขวา (หลังผนังบอร์ด): ก้อนผนังทึบ
		_box("wall", "", 0.83, RIGHT, y, c, -1.25, FLIGHT_SIDE_Z[0])
		_box("tread", "", LEFT, RIGHT, y - 0.1, y, FLIGHT_START_Z, BACK)
	# เพดานชั้นนี้ในโถงกับช่องบันได (ชั้น 3 = หลังคา; ชั้นล่าง/2 เพดานคือใต้พื้นชั้นบนที่สร้างด้านบน)
	if k == 2:
		_box("ceiling", "", LEFT, RIGHT, ROOF, ROOF + 0.1, 0.0, BACK)
	var lamp := Vector3(-1.0, c - 0.05, -1.6) if k > 0 else Vector3(-1.0, c - 0.05, -2.2)
	_lamp(lamp)


## บันไดชั้น k ขึ้นชั้น k+1: ช่วงแรกตรงไปข้างหลัง (ชั้นล่างวาดไว้ในภาพทางเข้าแล้ว) ชานพัก ช่วงสองชิดผนังหลัง
func _flights(k: int) -> void:
	var y0: float = FLOORS[k]
	var landing := y0 + RISE * STEPS
	if k > 0:
		for i in STEPS - 1:
			var z := FLIGHT_START_Z - RUN_BACK * i
			_box("riser", "", FLIGHT_BACK_X[0], FLIGHT_BACK_X[1], y0 + RISE * i - 0.35, y0 + RISE * (i + 1) - 0.02,
					z, z - RUN_BACK)
			_box("tread", "", FLIGHT_BACK_X[0], FLIGHT_BACK_X[1], y0 + RISE * (i + 1) - 0.02, y0 + RISE * (i + 1),
					z, z - RUN_BACK)
		# ผนังเตี้ยสองข้าง บนเอียงตามบันได
		for wall: Array in [[-2.62, FLIGHT_BACK_X[0]], [FLIGHT_BACK_X[1], FLIGHT_SIDE_X]]:
			_sloped("parapet", wall[0], wall[1], y0, FLIGHT_START_Z, LANDING_Z, 1.0, true)
	# ชานพัก
	_box("tread", "", LEFT, FLIGHT_SIDE_X, landing - 0.3, landing, LANDING_Z, BACK)
	# ช่วงสอง: ขึ้นไปทางขวา ใต้ขั้นเป็นท้องบันไดหนา 0.35 (ใต้นั้นคือที่ว่างเหนือหัวของบันไดชั้นล่าง)
	for j in STEPS - 1:
		var x := FLIGHT_SIDE_X + RUN_SIDE * j
		var top := landing + RISE * (j + 1)
		_box("riser", "", x, x + RUN_SIDE, top - RISE - 0.35, top - 0.02, FLIGHT_SIDE_Z[0], FLIGHT_SIDE_Z[1])
		_box("tread", "", x, x + RUN_SIDE, top - 0.02, top, FLIGHT_SIDE_Z[0], FLIGHT_SIDE_Z[1])
	# ผนังเตี้ยด้านในของช่วงสอง (กั้นช่องเหนือบันไดช่วงแรก)
	_sloped("parapet", FLIGHT_SIDE_X, FLIGHT_SIDE_X + RUN_SIDE * (STEPS - 1), landing,
			LANDING_Z, FLIGHT_SIDE_Z[0], 1.0, false)
	_lamp(Vector3(-1.2, landing + 2.4, -6.6))


## ผนังช่องบันได: ซ้าย หลัง ขวา สูงตลอด 3 ชั้น
func _core() -> void:
	var y: float = FLOORS[0]
	_box("wall", "", LEFT - 0.2, LEFT, y, ROOF, -3.6, BACK)
	_box("wall", "", LEFT, RIGHT, y, ROOF, BACK, BACK - 0.2)
	_box("wall", "", RIGHT, RIGHT + 0.2, y, ROOF, CORRIDOR[1], BACK)
	_box("wall", "", LEFT - 0.2, LEFT, FLOORS[1] - SLAB, ROOF, CORRIDOR[1], -3.6)


## ผนังเตี้ยเอียงตามบันได: ช่วง a..b (แกน z ถ้า along_z ไม่งั้นแกน x) จากพื้น y0 สูง h เหนือจมูกบันได
func _sloped(tile: String, a0: float, a1: float, y0: float, b0: float, b1: float, h: float, along_z: bool) -> void:
	var st := _tool(tile, "")
	var rise := RISE * STEPS
	var lo := y0 - 0.3
	if along_z:
		# a = x0..x1, b = z0 (ล่าง)..z1 (บน)
		for x: float in [a0, a1]:
			var n := Vector3.LEFT if x == a0 else Vector3.RIGHT
			_quad(st, n, Vector3(x, y0 + h, b0), Vector3(x, y0 + rise + h, b1), Vector3(x, lo, b1), Vector3(x, lo, b0))
		_quad(st, Vector3.UP, Vector3(a0, y0 + h, b0), Vector3(a1, y0 + h, b0), Vector3(a1, y0 + rise + h, b1),
				Vector3(a0, y0 + rise + h, b1))
		_quad(st, Vector3.BACK, Vector3(a0, y0 + h, b0), Vector3(a1, y0 + h, b0), Vector3(a1, lo, b0), Vector3(a0, lo, b0))
	else:
		# a = x0 (ล่าง)..x1 (บน), b = z0..z1
		for z: float in [b0, b1]:
			var n := Vector3.BACK if z == b0 else Vector3.FORWARD
			_quad(st, n, Vector3(a0, y0 + h, z), Vector3(a1, y0 + rise + h, z), Vector3(a1, lo, z), Vector3(a0, lo, z))
		_quad(st, Vector3.UP, Vector3(a0, y0 + h, b0), Vector3(a1, y0 + rise + h, b0), Vector3(a1, y0 + rise + h, b1),
				Vector3(a0, y0 + h, b1))


## ทางเดินหน้าห้องชั้น k: พื้น เพดาน ระเบียง เสา ผนังห้องเรียนเป็นช่องๆ ตามภาพตัวอาคาร
func _corridor(k: int) -> void:
	var y: float = FLOORS[k]
	var c := _ceiling_of(k)
	var z0: float = CORRIDOR[0]
	var z1: float = CORRIDOR[1]
	_box("tread", "", ENDS[0], ENDS[1], y - SLAB, y, z0 + 0.15, z1)
	_box("ceiling", "", ENDS[0], ENDS[1], c, c + 0.1, z0 + 0.15, z1)
	_box("cpar", "%d" % k, ENDS[0], ENDS[1], y, y + 1.0, z0 + 0.15, z0, Vector2(ENDS[0], y + 1.0))
	for p: Array in PILLARS:
		_box("pillar", "", p[0], p[1], y, c, z0 + 0.15, z0 - 0.45, Vector2(p[0], c))
	for b: Array in BAYS:
		_box("bay", "%d:%s" % [k, b[0]], b[0], b[1], y, c, z1, z1 - 0.2, Vector2(b[0], c))
	for x: float in ENDS:
		_box("wall", "", x - 0.2 if x > 0 else x, x if x > 0 else x + 0.2, y, c, z0 + 0.15, z1)
	for b: Array in BAYS:
		_lamp(Vector3((b[0] + b[1]) / 2.0, c - 0.05, -1.25))


func _lamp(p: Vector3) -> void:
	_lamps.append(p)
	_box("lamp", "", p.x - 0.6, p.x + 0.6, p.y - 0.04, p.y + 0.04, p.z + 0.08, p.z - 0.08)


func _tool(tile: String, variant: String, origin := Vector2.ZERO) -> SurfaceTool:
	var key := tile + "|" + variant
	if not _tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[key] = [st, tile, origin]
	return _tools[key][0]


func _quad(st: SurfaceTool, n: Vector3, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.set_normal(n)
		st.add_vertex(v)


func _box(tile: String, variant: String, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float,
		origin := Vector2.ZERO) -> void:
	var lo := Vector3(minf(x0, x1), minf(y0, y1), minf(z0, z1))
	var hi := Vector3(maxf(x0, x1), maxf(y0, y1), maxf(z0, z1))
	var st := _tool(tile, variant, origin)
	_quad(st, Vector3.BACK, Vector3(lo.x, hi.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z))
	_quad(st, Vector3.FORWARD, Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z))
	_quad(st, Vector3.UP, Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z))
	_quad(st, Vector3.DOWN, Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z), Vector3(lo.x, lo.y, lo.z))
	_quad(st, Vector3.LEFT, Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, lo.y, lo.z))
	_quad(st, Vector3.RIGHT, Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z))


## จางเข้า/ออกแบบพิกเซลพร้อมภาพทางเข้า
func set_fade(amount: float) -> void:
	visible = amount > 0.0
	for mat in _materials:
		mat.set_shader_parameter("fade", amount)


func _commit() -> void:
	var lamps := _lamps.slice(0, 8)
	for key: String in _tools:
		var entry: Array = _tools[key]
		var mesh := MeshInstance3D.new()
		mesh.name = key.replace("|", "_").replace(":", "_").replace(".", "_")
		mesh.mesh = (entry[0] as SurfaceTool).commit()
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		if entry[1] == "lamp":
			mat.set_shader_parameter("tile", load(DIR + "tread.png"))
			mat.set_shader_parameter("tint", Color(2.6, 2.7, 2.8))
		else:
			var tile: Array = TILES[entry[1]]
			mat.set_shader_parameter("tile", load(DIR + str(tile[0]) + ".png"))
			mat.set_shader_parameter("density", tile[1])
			var origin: Vector2 = entry[2]
			if entry[1] == "riser":
				origin = Vector2(0.0, FLOORS[0] + RISE)
			mat.set_shader_parameter("origin", origin)
			if entry[1] == "cpar":
				mat.set_shader_parameter("tint", Color(0.72, 0.74, 0.8))   # ด้านในระเบียง ไม่โดนแสงข้างนอก
			mat.set_shader_parameter("lamps", lamps)
			mat.set_shader_parameter("lamp_count", lamps.size())
		mesh.material_override = mat
		_materials.append(mat)
		add_child(mesh)
