@tool
class_name SchoolModel3D
extends Node3D
## โรงเรียนทั้งหลังเป็นโมเดลเดียว เดินไปมาได้ทุกที่: อาคารเรียน 3 ชั้น ทางเดินหน้าห้องทุกชั้น
## ช่องบันไดเดียวขึ้นลงได้ครบ 3 ชั้น ทางเข้า (กันสาด ม้านั่ง บอร์ด ถังขยะ) ลาน ทางเดินมีหลังคา พุ่มไม้ สนามหญ้า
## ไม่ฉายภาพจากจุดมองใด: ทุกหน้าระบายด้วยสีของมันเองตามขนาดจริง (shaders/tiled_paint.gdshader)
##   หน้าตรงของอาคาร (ผนังห้องเรียน เสา ระเบียง กันสาด ชายคา หลังคา) = ภาพหน้าอาคารของผู้เขียน 50 px/ม.
##   วางทับตำแหน่งจริง (tools/make_building_layers.py ทางเข้าคือภาพทางเข้าระยะใกล้ของผู้เขียน)
##   พื้น เพดาน ข้างเสา ช่องบันได หัวท้าย ด้านหลัง ลาน = ชิ้นลายจากภาพของผู้เขียน (tools/make_school_tiles.py)
## หน่วยเมตร: x ตามแนวอาคาร (0 = กลางโถงบันได), y ขึ้น (0 = พื้นลาน), z ออกมาทางลาน (0 = แนวระเบียง)

const DIR := "res://assets/bg/school/model/"
const SHADER := preload("res://shaders/tiled_paint.gdshader")

## ภาพหน้าอาคาร 50 px/ม. (px 1083.5 = x 0, px 668 = พื้นลาน)
const PPM := 50.0
const FACADE_ORIGIN := Vector2(-1083.5 / PPM, 668.0 / PPM)

## ชั้น: พื้น / ใต้เพดาน (จากภาพ: พื้นชั้นล่าง px 645, เพดาน 496 / 329 / 157, ระเบียง 435 / 271)
const FLOORS := [0.46, 3.76, 7.04]
const CEILS := [3.44, 6.78, 10.22]
const PARAPET_TOPS := [0.0, 4.66, 7.94]
const LEFT := -20.21
const RIGHT := 20.21
const Z_FRONT := 0.15                         # หน้าระเบียง
const Z_WALL := -2.5                          # ผนังห้องเรียน
const Z_BACK := -9.5                          # ผนังหลังอาคาร
const EAVE := [10.22, 10.54, 1.0]             # ชายคา ใต้ / บน / ยื่น z
const RIDGE := [11.88, -4.25]                 # สันหลังคา y z
const BACK_EAVE := -10.5
## เสาระเบียง (px) คู่กลางคือเสาโถงบันได เริ่มเหนือกันสาด
const PILLARS := [[73, 109], [372, 398], [650, 675], [921, 945], [1220, 1245], [1490, 1515],
		[1769, 1794], [2057, 2094]]
const HALL_PILLARS := [3, 4]

## ช่องบันได: ทางเดินลึกฝั่งซ้ายของโถง (px 945-1122) ลึกเข้าไปหลังแนวผนังห้องเรียน
## บันไดสองช่วงหักกลับ (dog-leg) ชั้นละ 20 ลูกตั้ง: ช่วงแรกขึ้นไปข้างหลัง ชานพัก ช่วงสองย้อนกลับขึ้นมาข้างหน้า
## กลางสองช่วงมีผนังกั้น (แบบบันไดโรงเรียนไทย)
const CORE := [-2.77, 0.77, Z_WALL, -7.2]     # x0 x1 z0 z1
const STAIR_FRONT := -3.0
const TREAD := 0.28
const FLIGHT_A := [-2.62, -1.0]
const FLIGHT_B := [-0.85, 0.62]
const DIVIDER := [-1.0, -0.85]

## ทางเข้า (px ภาพหน้าอาคาร)
const CANOPY := [884, 1284, 471, 490]
const CANOPY_Z := [2.4, 0.3]
const CANOPY_PILLARS := [[912, 943], [1210, 1242]]
const CANOPY_PILLAR_Z := [1.9, 1.3]
const BENCH := [950, 1023, 602, 646]          # การ์ดม้านั่ง (props.png)

## ลาน
const WALK := [3.9, 6.9, 2.65, 3.0]           # ทางเดินมีหลังคา z0 z1 ใต้หลังคา บนหลังคา
const WALK_X := 24.0
const HEDGE := [7.3, 7.95, 0.85, 1.95, 24.0]  # z0 z1 สูง ช่องทางเดิน ปลาย
const PATH := 1.6
const BENCHES := [Vector2(-5.6, 10.6), Vector2(6.2, 11.4)]

## สี: ไฟล์, px/ม. (ตามแนว, ลง), จุดเริ่ม, แสงพื้น, แสงไฟ, สีคูณ, ตัดขอบ
var MATERIALS := {
	"facade_front": ["front", Vector2(PPM, PPM), FACADE_ORIGIN, 1.0, 0.0, Color.WHITE, true],
	"facade_mid": ["mid", Vector2(PPM, PPM), FACADE_ORIGIN, 1.0, 0.0, Color.WHITE, false],
	"facade_back": ["back", Vector2(PPM, PPM), FACADE_ORIGIN, 1.0, 0.0, Color.WHITE, false],
	# หลังคา: แถบหลังคาในภาพ (px 74-141) แผ่ตามความลึกจริง หน้า (ชายคา -> สัน) และหลัง (สัน -> ชายคาหลัง)
	"roof_front": ["front", Vector2(PPM, 67.0 / (EAVE[2] - RIDGE[1])), Vector2(FACADE_ORIGIN.x, RIDGE[1] - 74.0 / (67.0 / (EAVE[2] - RIDGE[1]))), 1.0, 0.0, Color.WHITE, false],
	"roof_back": ["front", Vector2(PPM, -67.0 / (RIDGE[1] - BACK_EAVE)), Vector2(FACADE_ORIGIN.x, RIDGE[1] + 74.0 / (67.0 / (RIDGE[1] - BACK_EAVE))), 0.85, 0.0, Color.WHITE, false],
	"plaster": ["plaster", Vector2(50, 50), Vector2.ZERO, 1.0, 0.0, Color.WHITE, false],
	"plaster_shade": ["plaster", Vector2(50, 50), Vector2.ZERO, 0.8, 0.0, Color(0.85, 0.87, 0.93), false],
	"back_bay": ["back_bay", Vector2(50, 50), Vector2(LEFT, CEILS[0]), 0.9, 0.0, Color.WHITE, false],
	"back_bay2": ["back_bay", Vector2(50, 50), Vector2(LEFT, CEILS[1]), 0.9, 0.0, Color.WHITE, false],
	"back_bay3": ["back_bay", Vector2(50, 50), Vector2(LEFT, CEILS[2]), 0.9, 0.0, Color.WHITE, false],
	"floor": ["tread", Vector2(50, 50), Vector2.ZERO, 0.9, 0.35, Color.WHITE, false],
	"ceiling": ["ceiling", Vector2(46, 46), Vector2.ZERO, 0.85, 0.35, Color.WHITE, false],
	"hall_wall": ["hall_wall", Vector2(50, 50), Vector2(0.0, CEILS[2]), 0.85, 0.35, Color.WHITE, false],
	"riser": ["riser", Vector2(100, 100), Vector2.ZERO, 0.85, 0.35, Color.WHITE, false],
	"tread": ["tread", Vector2(50, 50), Vector2.ZERO, 0.95, 0.35, Color.WHITE, false],
	"low_wall": ["parapet", Vector2(50, 50), Vector2.ZERO, 0.9, 0.35, Color.WHITE, false],
	"lamp": ["tread", Vector2(50, 50), Vector2.ZERO, 2.4, 0.0, Color.WHITE, false],
	"bench": ["props", Vector2(PPM, PPM), FACADE_ORIGIN, 1.0, 0.0, Color.WHITE, true],
	"concrete": ["concrete", Vector2(48, 48), Vector2.ZERO, 1.0, 0.0, Color.WHITE, false],
	"cement": ["concrete", Vector2(48, 48), Vector2.ZERO, 0.85, 0.0, Color(0.9, 0.92, 0.98), false],
	"paver": ["paver", Vector2(48, 48), Vector2(PATH, 0.0), 1.0, 0.0, Color.WHITE, false],
	"lawn": ["lawn", Vector2(32, 32), Vector2.ZERO, 1.0, 0.0, Color.WHITE, false],
	"hedge": ["hedge", Vector2(90, 90), Vector2.ZERO, 1.0, 0.0, Color.WHITE, false],
	"hedge_top": ["hedge", Vector2(90, 90), Vector2.ZERO, 1.15, 0.0, Color.WHITE, false],
	"sheet": ["sheet", Vector2(40, 40), Vector2.ZERO, 1.0, 0.0, Color.WHITE, false],
	"steel": ["steel", Vector2(40, 40), Vector2.ZERO, 1.0, 0.0, Color.WHITE, false],
	"steel_dark": ["steel", Vector2(40, 40), Vector2.ZERO, 0.55, 0.0, Color.WHITE, false],
}

var _tools := {}
var _lamps := PackedVector3Array()


func _ready() -> void:
	_build()


static func fx(px: float) -> float:
	return px / PPM + FACADE_ORIGIN.x


static func fy(py: float) -> float:
	return FACADE_ORIGIN.y - py / PPM


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_tools.clear()
	_lamps.clear()
	_block()
	_core()
	for k in 2:
		_stairs(k)
	_entrance()
	_courtyard()
	_commit()


# ---------------------------------------------------------------- อาคาร

func _block() -> void:
	var z_core := [CORE[0], CORE[1]]
	# ผนังห้องเรียนหลังระเบียง (เว้นช่องบันได) ภาพหน้าอาคารวางตรงที่
	_face_z("facade_back", LEFT, z_core[0], 0.0, CEILS[2], Z_WALL, true)
	_face_z("facade_back", z_core[1], RIGHT, 0.0, CEILS[2], Z_WALL, true)
	# พื้นชั้นล่าง (ฐาน) พื้นชั้น 2 3 ระเบียง
	_box({"all": "plaster_shade", "front": "facade_mid", "top": "floor"}, LEFT, RIGHT, 0.0, FLOORS[0], 0.3, Z_WALL)
	for k in [1, 2]:
		var under: float = CEILS[k - 1]
		_box({"all": "plaster_shade", "top": "floor", "bottom": "ceiling"}, LEFT, RIGHT, under, FLOORS[k],
				Z_FRONT, Z_WALL)
		# ระเบียง: หน้า = ภาพ, ด้านใน ด้านบน = ปูน
		_box({"all": "plaster", "front": "facade_mid"}, LEFT, RIGHT, under, PARAPET_TOPS[k], Z_FRONT, 0.0)
		for x in [LEFT, RIGHT]:
			_box({"all": "plaster"}, x - 0.15 if x > 0 else x, x if x > 0 else x + 0.15, FLOORS[k], PARAPET_TOPS[k],
					0.0, Z_WALL)
	# เพดานชั้น 3 ชายคา
	_box({"all": "plaster_shade", "front": "facade_front", "bottom": "ceiling"}, LEFT - 0.8, RIGHT + 0.8,
			EAVE[0], EAVE[1], EAVE[2], Z_BACK - 1.0)
	# เสาระเบียง
	for i in PILLARS.size():
		var p: Array = PILLARS[i]
		var y0 := fy(CANOPY[2]) if i in HALL_PILLARS else 0.0
		_box({"all": "plaster_shade", "front": "facade_mid"}, fx(p[0]), fx(p[1]), y0, EAVE[0], 0.3, -0.3)
	# หัวท้ายอาคาร หลังอาคาร (หน้าต่างห้องเรียนจากภาพ) แถบพื้นระหว่างชั้น
	for x in [LEFT, RIGHT]:
		_box({"all": "plaster"}, x - 0.2 if x < 0 else x, x if x < 0 else x + 0.2, 0.0, EAVE[0], Z_WALL, Z_BACK)
	for k in 3:
		_face_z("back_bay" if k == 0 else "back_bay%d" % (k + 1), LEFT, RIGHT, FLOORS[k], CEILS[k], Z_BACK, false)
		if k > 0:
			_face_z("plaster", LEFT, RIGHT, CEILS[k - 1], FLOORS[k], Z_BACK, false)
	_face_z("plaster", LEFT, RIGHT, 0.0, FLOORS[0], Z_BACK, false)
	# หลังคา: ลาดหน้า ลาดหลัง หน้าจั่ว
	var e0 := Vector3(0, EAVE[1], EAVE[2])
	var r := Vector3(0, RIDGE[0], RIDGE[1])
	var e1 := Vector3(0, EAVE[1], BACK_EAVE)
	for slope: Array in [["roof_front", e0, r], ["roof_back", r, e1]]:
		var a: Vector3 = slope[1]
		var b: Vector3 = slope[2]
		var n := Vector3(0, b.z - a.z, -(b.y - a.y)).normalized()
		if n.y < 0:
			n = -n
		_quad(slope[0], n, Vector3(LEFT - 0.8, a.y, a.z), Vector3(RIGHT + 0.8, a.y, a.z),
				Vector3(RIGHT + 0.8, b.y, b.z), Vector3(LEFT - 0.8, b.y, b.z))
	for x in [LEFT - 0.8, RIGHT + 0.8]:
		var n := Vector3.LEFT if x < 0 else Vector3.RIGHT
		_tri("plaster_shade", n, Vector3(x, EAVE[1], EAVE[2]), Vector3(x, RIDGE[0], RIDGE[1]), Vector3(x, EAVE[1], BACK_EAVE))
	# ไฟเพดานทางเดิน
	for k in 3:
		for i in PILLARS.size() - 1:
			var mid := (fx(PILLARS[i][1]) + fx(PILLARS[i + 1][0])) / 2.0
			_lamp(Vector3(mid, CEILS[k] - 0.04, -1.25), false)


# ---------------------------------------------------------------- ช่องบันได

func _core() -> void:
	var y0: float = 0.0
	var top: float = CEILS[2]
	_box({"all": "hall_wall"}, CORE[0] - 0.2, CORE[0], y0, top, CORE[2], CORE[3])
	_box({"all": "hall_wall"}, CORE[1], CORE[1] + 0.2, y0, top, CORE[2], CORE[3])
	_box({"all": "hall_wall"}, CORE[0], CORE[1], y0, top, CORE[3], CORE[3] - 0.2)
	_box({"all": "hall_wall"}, DIVIDER[0], DIVIDER[1], FLOORS[0], top, STAIR_FRONT, STAIR_FRONT - TREAD * 9)
	_box({"all": "floor"}, CORE[0], CORE[1], 0.0, FLOORS[0], CORE[2], CORE[3])
	_box({"all": "ceiling"}, CORE[0], CORE[1], top, top + 0.1, CORE[2], CORE[3])
	# ชั้น 3 ไม่มีบันไดขึ้นต่อ: ผนังเตี้ยกั้นขอบช่องบันได
	_box({"all": "low_wall"}, CORE[0], DIVIDER[0], FLOORS[2], FLOORS[2] + 1.0, STAIR_FRONT + 0.1, STAIR_FRONT)
	for k in 3:
		_lamp(Vector3(-1.0, CEILS[k] - 0.04, -2.75), true)


## บันไดจากชั้น k ขึ้นชั้น k+1
func _stairs(k: int) -> void:
	var y0: float = FLOORS[k]
	var y1: float = FLOORS[k + 1]
	var rise := (y1 - y0) / 20.0
	var landing_z := STAIR_FRONT - TREAD * 9
	var landing := y0 + rise * 10
	for i in 9:
		var top := y0 + rise * (i + 1)
		var z0 := STAIR_FRONT - TREAD * i
		var bottom := y0 if k == 0 else top - rise - 0.3
		_box({"all": "riser", "top": "tread"}, FLIGHT_A[0], FLIGHT_A[1], bottom, top, z0, z0 - TREAD)
	_box({"all": "riser", "top": "tread", "bottom": "ceiling"}, CORE[0], CORE[1], landing - 0.3, landing,
			landing_z, CORE[3])
	for j in 9:
		var top := landing + rise * (j + 1)
		var z0 := landing_z + TREAD * j
		_box({"all": "riser", "top": "tread", "bottom": "ceiling"}, FLIGHT_B[0], FLIGHT_B[1], top - rise - 0.3, top,
				z0, z0 + TREAD)
	# ชานหน้าบันไดชั้นบน (ระหว่างผนังห้องเรียนกับขั้นแรก)
	_box({"all": "plaster_shade", "top": "floor", "bottom": "ceiling"}, CORE[0], CORE[1], y1 - 0.32, y1,
			CORE[2], STAIR_FRONT)
	_lamp(Vector3(-0.2, landing + 2.5, landing_z - 0.8), true)


# ---------------------------------------------------------------- ทางเข้า

func _entrance() -> void:
	var cx0 := fx(CANOPY[0])
	var cx1 := fx(CANOPY[1])
	_box({"all": "plaster_shade", "front": "facade_front", "bottom": "ceiling", "top": "cement"}, cx0, cx1,
			fy(CANOPY[3]), fy(CANOPY[2]), CANOPY_Z[0], CANOPY_Z[1])
	for p: Array in CANOPY_PILLARS:
		_box({"all": "plaster_shade", "front": "facade_front"}, fx(p[0]), fx(p[1]), 0.0, fy(CANOPY[3]),
				CANOPY_PILLAR_Z[0], CANOPY_PILLAR_Z[1])
	# บันไดหน้าทางเข้า 3 ขั้น
	for i in 3:
		var w := 0.18 * i
		_box({"all": "cement", "top": "concrete"}, cx0 + 0.25 + w, cx1 - 0.25 - w, 0.0, FLOORS[0] / 3.0 * (i + 1),
				2.6 - 0.3 * i, 0.3)
	_lamp(Vector3(0.0, fy(CANOPY[3]) - 0.04, 1.3), false)
	# ม้านั่งในโถง (การ์ดจากภาพ)
	_card("bench", fx(BENCH[0]), fx(BENCH[1]), FLOORS[0], FLOORS[0] + (BENCH[3] - BENCH[2]) / PPM, -1.6,
			Vector2(FACADE_ORIGIN.x, FLOORS[0] + BENCH[3] / PPM))


# ---------------------------------------------------------------- ลาน

func _courtyard() -> void:
	_quad("lawn", Vector3.UP, Vector3(-45, -0.01, -30), Vector3(45, -0.01, -30), Vector3(45, -0.01, 40), Vector3(-45, -0.01, 40))
	_flat("concrete", -45, 45, 0.0, 0.3, WALK[0])
	_flat("cement", -WALK_X, WALK_X, 0.0, WALK[0], WALK[1])
	_flat("concrete", -WALK_X, WALK_X, 0.005, WALK[1], WALK[1] + 0.25)
	_flat("paver", -PATH, PATH, 0.0, WALK[1] + 0.25, 40.0)
	# ทางเดินมีหลังคา: เสาเหล็ก หลังคาเมทัลชีท
	var x := 2.3
	while x < WALK_X:
		for s in [-1.0, 1.0]:
			_box({"all": "steel"}, s * x - 0.08, s * x + 0.08, 0.0, WALK[2], 6.3 + 0.08, 6.3 - 0.08)
		x += 3.7
	_box({"all": "steel", "top": "sheet", "bottom": "steel_dark"}, -WALK_X, WALK_X, WALK[2], WALK[3], WALK[1], WALK[0])
	# พุ่มไม้ตัดแต่ง
	for s in [-1.0, 1.0]:
		var a: float = HEDGE[3] * s
		var b: float = HEDGE[4] * s
		_box({"all": "hedge", "top": "hedge_top"}, minf(a, b), maxf(a, b), 0.0, HEDGE[2], HEDGE[1], HEDGE[0])
	# ม้านั่งบนสนาม
	for p in BENCHES:
		var w := (BENCH[1] - BENCH[0]) / PPM * 1.2
		_card("bench", p.x - w / 2, p.x + w / 2, 0.0, (BENCH[3] - BENCH[2]) / PPM * 1.2, p.y,
				Vector2(p.x - w / 2 - BENCH[0] / PPM * 1.2, (BENCH[3]) / PPM * 1.2), 1.0 / 1.2)


# ---------------------------------------------------------------- เครื่องมือ

func _tool(mat: String) -> SurfaceTool:
	if not _tools.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[mat] = st
	return _tools[mat]


func _quad(mat: String, n: Vector3, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var st := _tool(mat)
	for v in [a, b, c, a, c, d]:
		st.set_normal(n)
		st.add_vertex(v)


func _tri(mat: String, n: Vector3, a: Vector3, b: Vector3, c: Vector3) -> void:
	var st := _tool(mat)
	for v in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(v)


## หน้าตรงที่ z (หันออกมาทางลานถ้า toward_front)
func _face_z(mat: String, x0: float, x1: float, y0: float, y1: float, z: float, toward_front: bool) -> void:
	var n := Vector3.BACK if toward_front else Vector3.FORWARD
	_quad(mat, n, Vector3(x0, y1, z), Vector3(x1, y1, z), Vector3(x1, y0, z), Vector3(x0, y0, z))


func _flat(mat: String, x0: float, x1: float, y: float, z0: float, z1: float) -> void:
	_quad(mat, Vector3.UP, Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1))


## กล่อง: mats = {"all", "front" (+z), "back", "top", "bottom", "sides"} ; hole = ช่องบนด้านบน/ล่าง [x0 x1 z0 z1]
func _box(mats: Dictionary, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, hole := []) -> void:
	var lo := Vector3(minf(x0, x1), minf(y0, y1), minf(z0, z1))
	var hi := Vector3(maxf(x0, x1), maxf(y0, y1), maxf(z0, z1))
	var m := func(face: String) -> String: return mats.get(face, mats.get("sides" if face in ["left", "right"] else "", mats["all"]))
	_quad(m.call("front"), Vector3.BACK, Vector3(lo.x, hi.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z))
	_quad(m.call("back"), Vector3.FORWARD, Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z))
	_quad(m.call("left"), Vector3.LEFT, Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, lo.y, lo.z))
	_quad(m.call("right"), Vector3.RIGHT, Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z))
	for face in ["top", "bottom"]:
		var y := hi.y if face == "top" else lo.y
		var n := Vector3.UP if face == "top" else Vector3.DOWN
		var parts := [[lo.x, hi.x, lo.z, hi.z]]
		if not hole.is_empty():
			var hx0: float = hole[0]
			var hx1: float = hole[1]
			var hz0: float = minf(hole[2], hole[3])
			var hz1: float = maxf(hole[2], hole[3])
			parts = [[lo.x, hx0, lo.z, hi.z], [hx1, hi.x, lo.z, hi.z], [hx0, hx1, hz1, hi.z], [hx0, hx1, lo.z, hz0]]
		for p: Array in parts:
			if p[1] - p[0] > 0.001 and p[3] - p[2] > 0.001:
				_quad(m.call(face), n, Vector3(p[0], y, p[2]), Vector3(p[1], y, p[2]), Vector3(p[1], y, p[3]), Vector3(p[0], y, p[3]))


## การ์ดตั้ง (หันมาทางลาน) ระบายด้วยภาพที่มีขอบโปร่ง; origin = มุมซ้ายบนของภาพในโลก
func _card(mat: String, x0: float, x1: float, y0: float, y1: float, z: float, origin: Vector2, scale := 1.0) -> void:
	var key := "%s@%s,%s,%s" % [mat, origin.x, origin.y, scale]
	if not MATERIALS.has(key):
		var base: Array = MATERIALS[mat].duplicate()
		base[1] = Vector2(PPM, PPM) * scale
		base[2] = origin
		MATERIALS[key] = base
	_face_z(key, x0, x1, y0, y1, z, true)


func _lamp(p: Vector3, inside: bool) -> void:
	if inside:
		_lamps.append(p)
	_box({"all": "lamp"}, p.x - 0.6, p.x + 0.6, p.y - 0.04, p.y + 0.03, p.z + 0.08, p.z - 0.08)


func _commit() -> void:
	var lamps := _lamps.slice(0, 8)
	for key: String in _tools:
		var spec: Array = MATERIALS[key]
		var mesh := MeshInstance3D.new()
		mesh.name = key.validate_node_name()
		mesh.mesh = (_tools[key] as SurfaceTool).commit()
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("tile", load(DIR + str(spec[0]) + ".png"))
		mat.set_shader_parameter("density", spec[1])
		mat.set_shader_parameter("origin", spec[2])
		mat.set_shader_parameter("ambient", spec[3])
		mat.set_shader_parameter("lamp_light", spec[4])
		mat.set_shader_parameter("tint", spec[5])
		mat.set_shader_parameter("cutout", spec[6])
		mat.set_shader_parameter("lamps", lamps)
		mat.set_shader_parameter("lamp_count", lamps.size())
		mesh.material_override = mat
		add_child(mesh)
