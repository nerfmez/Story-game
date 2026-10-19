@tool
class_name SchoolModel3D
extends Node3D
## โรงเรียนทั้งหลังเป็นโมเดล 3D เดียว เดินไปมาได้ทุกที่ ปั้นเป็นรูปทรงจริง แสงจริง (ไม่ใช่ภาพแปะ)
## อาคารเรียน 3 ชั้นตามภาพของผู้เขียน: หน้าตรงของอาคาร (ผนังห้องเรียน เสา ระเบียง ชายคา หลังคา กันสาด
## โถงทางเข้ากับบอร์ด ถังขยะ) แปะภาพของผู้เขียนตรงตำแหน่งจริง ส่วนอื่นปั้นจริง: ทางเดินทุกชั้น
## ช่องบันไดเดียวขึ้นลงครบ 3 ชั้น (สองช่วงหักกลับ ผนังกั้นกลาง ราวจับ) ด้านหลังมีหน้าต่างห้องเรียน
## ม้านั่ง ลาน ทางเดินมีหลังคา พุ่มไม้ สนามหญ้า
## สีจากภาพอาคารของผู้เขียน (ผนังครีม เสาขาว หลังคากับกันสาดฟ้า) แสง: SchoolBuildingView
## หน่วยเมตร: x ตามแนวอาคาร (0 = กลางโถงบันได), y ขึ้น (0 = พื้นลาน), z ออกมาทางลาน (0 = แนวระเบียง)

const FLOORS := [0.46, 3.76, 7.04]
const CEILS := [3.44, 6.78, 10.22]
const LEFT := -20.21
const RIGHT := 20.21
const Z_WALL := -2.5                          # ผนังห้องเรียนด้านทางเดิน
const Z_BACK := -9.5                          # ผนังหลังอาคาร
const WALL_T := 0.2
const PARAPET_H := 0.9
const EAVE := 10.54
const RIDGE := [11.9, -4.25]
const OVERHANG := 1.0
## เสา: กึ่งกลางกับความกว้างตามภาพ (px 73-109, 372-398, 650-675, 921-945, 1220-1245, 1490-1515, 1769-1794,
## 2057-2094) ลายเสาที่แปะจึงตรงกับตัวเสา คู่กลางคือเสาโถงบันได
const PILLAR_X := [-19.85, -13.97, -8.42, -3.01, 2.98, 8.38, 13.96, 19.84]
const PILLAR_WS := [0.72, 0.52, 0.5, 0.48, 0.5, 0.5, 0.5, 0.74]
## เสากันสาด (px 912-943, 1210-1242)
const CANOPY_PILLARS := [[-3.43, -2.81], [2.53, 3.17]]
## ช่องบันได ทางเดินลึกฝั่งซ้ายของโถง
const CORE := [-2.77, 0.77, Z_WALL, -7.2]
const HALL_RIGHT := 2.47                      # ผนังบอร์ดในโถง (ถึงเสาโถงขวา)
const STAIR_FRONT := -3.0
const TREAD := 0.28
const FLIGHT_A := [-2.62, -1.0]
const FLIGHT_B := [-0.85, 0.62]
const DIVIDER := [-1.0, -0.85]
const CANOPY := [-3.97, 4.03, 3.56, 3.94, 2.4]   # x0 x1 ใต้ บน ยื่นถึง z
const WALK := [3.9, 6.9, 2.65, 2.85]
const WALK_X := 24.0
const HEDGE := [7.3, 7.95, 0.85, 1.95, 24.0]
const PATH := 1.6
const FOLIAGE := preload("res://assets/bg/school/paint/foliage.png")
# UV regions from the author's unchanged foliage painting (2172 x 724).
const LEAF_REGIONS := [Rect2(691, 402, 67, 113), Rect2(1507, 430, 68, 88), Rect2(2068, 452, 72, 66)]

const COLOURS := {
	"wall": Color("d9d3c4"), "pillar": Color("e9edf2"), "parapet": Color("e6e6e2"),
	"trim": Color("c3ccd8"), "groove": Color("9aa4b3"), "skirt": Color("8a93a3"),
	"roof": Color("4471c2"), "fascia": Color("2f528f"), "canopy": Color("4277d6"),
	"glass": Color("27405e"), "frame": Color("31476a"), "curtain": Color("c9cdd3"), "room": Color("1b2433"),
	
	"ceiling": Color("d2d6dc"), "floor": Color("a9afba"), "tread": Color("b5bbc5"), "nosing": Color("dfe3e8"),
	"riser": Color("9aa1ad"), "core": Color("d3d1c9"), "rail": Color("c9d1dd"),
	"lamp": Color("f4f8ff"), 
	"wood": Color("a9632d"), "iron": Color("2b3240"), "vent": Color("c8c9c4"),
	"concrete": Color("a8adb6"), "cement": Color("9aa1ad"), "paver": Color("8e94a2"), "edging": Color("b8bdc6"),
	"grass": Color("4a7a52"), "hedge": Color("3c6c47"), "steel": Color("c4ccd8"), "sheet": Color("3f68b4"),
	"pot": Color("2f3e5c"), "plant": Color("3f7a44"), "drain": Color("4a505c"), "soil": Color("344b46"),
}
const GLOSS := {"glass": 0.12, "floor": 0.35, "tread": 0.45, "concrete": 0.55, "cement": 0.5, "paver": 0.55,
	"rail": 0.3, "steel": 0.35, "roof": 0.45, "canopy": 0.5}
## เนื้อวัสดุจริง (texture CC0 จาก ambientCG: tools/make_school_textures.py): ความสว่างของผิวคูณสีของอาคาร
## ชื่อ texture, เมตรต่อหนึ่งรอบลาย, ความสว่างเฉลี่ยของ texture (ชดเชยให้สีเท่าเดิม), แรงนูนของ normal map
const TEX_DIR := "res://assets/bg/school/tex/"
const SURFACE := {
	"wall": ["plaster", 2.0, 0.98, 0.6], "core": ["plaster", 2.0, 0.98, 0.6], "parapet": ["plaster", 2.0, 0.98, 0.6],
	"ceiling": ["plaster", 2.0, 0.98, 0.3], "pillar": ["smooth", 2.0, 0.96, 0.4], "trim": ["smooth", 2.0, 0.96, 0.3],
	"floor": ["terrazzo", 0.6, 0.93, 0.2], "tread": ["terrazzo", 0.6, 0.93, 0.2], "riser": ["terrazzo", 0.6, 0.93, 0.2],
	"nosing": ["smooth", 1.0, 0.96, 0.2], "concrete": ["concrete", 2.0, 0.82, 0.8], "cement": ["concrete", 2.0, 0.82, 0.8],
	"edging": ["concrete", 1.0, 0.82, 0.6], "paver": ["paving", 1.5, 0.74, 1.0], "grass": ["grass", 1.5, 0.74, 1.0],
	"hedge": ["grass", 0.8, 0.74, 1.2], "wood": ["wood", 1.0, 0.72, 0.6], "roof": ["corrugated", 1.0, 0.84, 1.0],
	"sheet": ["corrugated", 1.0, 0.84, 1.0], "canopy": ["smooth", 2.0, 0.96, 0.3], "fascia": ["metal", 1.0, 0.78, 0.4],
	"steel": ["metal", 1.0, 0.78, 0.4], "rail": ["metal", 1.0, 0.78, 0.3],
	"vent": ["concrete", 1.0, 0.82, 0.5],
}

## ภาพหน้าอาคารของผู้เขียน (ทางเข้าคือภาพทางเข้าระยะใกล้ของผู้เขียนย่อลงวาง: tools/make_building_layers.py)
## แปะตรงบนหน้าตรงของโมเดลตามขนาดจริง 50 px/ม. (px 1083.5 = x 0, px 668 = พื้นลาน)
const PAINT_DIR := "res://assets/bg/school/paint/"
const WALL_REPAIR_ART := preload("res://assets/bg/school/paint/back_repair.png")
const PAINT_SIZE := Vector2(2168, 725)
const PPM := 50.0
const PAINT_ORIGIN := Vector2(-1083.5 / PPM, 668.0 / PPM)

var _tools := {}
var lamps: Array[Vector3] = []                # ตำแหน่งหลอดนีออน (SchoolBuildingView ใส่ไฟจริง)


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_tools.clear()
	lamps.clear()
	_block()
	_core()
	for k in 2:
		_stairs(k)
	_entrance()
	_courtyard()
	_commit()


# ---------------------------------------------------------------- อาคาร

func _block() -> void:
	# ฐานกับพื้นทางเดินชั้นล่าง
	_box("parapet", LEFT, RIGHT, 0.0, FLOORS[0] - 0.01, 0.3, Z_BACK)
	_box("floor", LEFT, RIGHT, FLOORS[0] - 0.01, FLOORS[0], 0.3, Z_WALL)
	_box("skirt", LEFT, RIGHT, 0.0, 0.08, 0.31, 0.29)
	for k in [1, 2]:
		var under: float = CEILS[k - 1]
		_box("ceiling", LEFT, RIGHT, under, FLOORS[k] - 0.02, 0.15, Z_WALL)
		_box("floor", LEFT, RIGHT, FLOORS[k] - 0.02, FLOORS[k], 0.15, Z_WALL)
		_box("ceiling", LEFT, RIGHT, under, FLOORS[k], Z_WALL - WALL_T, Z_BACK + WALL_T)    # พื้นห้องเรียน
		_parapet(FLOORS[k], under)
	# หลังคาชั้น 3 ชายคา หลังคา
	_box("ceiling", LEFT - OVERHANG, RIGHT + OVERHANG, CEILS[2], EAVE - 0.1, OVERHANG, Z_BACK - OVERHANG)
	_box("fascia", LEFT - OVERHANG, RIGHT + OVERHANG, EAVE - 0.32, EAVE, OVERHANG, OVERHANG - 0.08)
	_box("fascia", LEFT - OVERHANG, RIGHT + OVERHANG, EAVE - 0.32, EAVE, Z_BACK - OVERHANG + 0.08, Z_BACK - OVERHANG)
	_roof()
	# ผนังห้องเรียนสองด้าน (หน้าต่าง ประตู) ทุกชั้น เว้นโถงบันได
	for k in 3:
		var y0: float = FLOORS[k]
		var y1: float = CEILS[k]
		for i in PILLAR_X.size() - 1:
			var x0: float = PILLAR_X[i] + PILLAR_WS[i] / 2.0
			var x1: float = PILLAR_X[i + 1] - PILLAR_WS[i + 1] / 2.0
			if i == 3:                                   # โถงบันได: ผนังบอร์ดฝั่งขวาของโถง
				_box("wall", CORE[1], x1, y0, y1, Z_WALL, Z_WALL - WALL_T)
				_window_wall(x0, x1, y0, y1, Z_BACK, 0.25, 0.75)
			else:
				_box("wall", x0, x1, y0, y1, Z_WALL, Z_WALL - WALL_T)
				_window_wall(x0, x1, y0, y1, Z_BACK, 0.12, 0.88)
			_tube((PILLAR_X[i] + PILLAR_X[i + 1]) / 2.0, y1, -1.25)
	for k in [1, 2]:
		_box("trim", LEFT, RIGHT, CEILS[k - 1], FLOORS[k], Z_BACK, Z_BACK - 0.05)
	# ภาพหน้าอาคาร: ผนังห้องเรียน (หน้าต่าง ประตู ป้าย ตามภาพ) ฐาน ชายคา
	_paint("back", LEFT, CORE[0], 0.0, CEILS[2], Z_WALL + 0.003)
	_paint("back", CORE[1], RIGHT, 0.0, CEILS[2], Z_WALL + 0.003)
	_paint("mid", LEFT, RIGHT, 0.0, FLOORS[0], 0.315)
	_paint("front", LEFT - OVERHANG, RIGHT + OVERHANG, EAVE - 0.32, EAVE, OVERHANG + 0.003)
	# เสา (คู่กลางเริ่มเหนือกันสาด)
	for i in PILLAR_X.size():
		var x: float = PILLAR_X[i]
		var y0: float = CANOPY[3] if i in [3, 4] else 0.0
		var w: float = PILLAR_WS[i] / 2.0
		_box("pillar", x - w, x + w, y0, EAVE - 0.32, 0.3, -0.3)
		_paint("mid", x - w, x + w, y0, EAVE - 0.32, 0.303)
	# หัวท้ายอาคาร
	for x in [LEFT, RIGHT]:
		var a: float = x - WALL_T if x < 0 else x
		_box("wall", a, a + WALL_T, 0.0, CEILS[2], Z_WALL, Z_BACK)
		for k in 3:
			_box("trim", a - 0.01, a + WALL_T + 0.01, CEILS[k] - 0.05, CEILS[k] + (0.3 if k < 2 else 0.0), Z_WALL, Z_BACK)


## ระเบียง: ผนังทึบ 0.9 ม. คิ้วบน ร่องเส้นกลาง แถบพื้นด้านหน้า
func _parapet(floor_y: float, under: float) -> void:
	_box("parapet", LEFT, RIGHT, under, floor_y + PARAPET_H, 0.15, 0.0)
	_paint("mid", LEFT, RIGHT, under, floor_y + PARAPET_H + 0.05, 0.195)
	_box("trim", LEFT, RIGHT, floor_y + PARAPET_H, floor_y + PARAPET_H + 0.05, 0.19, -0.04)
	_box("groove", LEFT, RIGHT, floor_y + 0.62, floor_y + 0.64, 0.155, 0.14)
	_box("trim", LEFT, RIGHT, under, floor_y, 0.17, 0.15)
	_box("skirt", LEFT, RIGHT, floor_y, floor_y + 0.08, 0.0, -0.01)
	for x in [LEFT, RIGHT]:
		var a: float = x if x < 0 else x - 0.12
		_box("parapet", a, a + 0.12, floor_y, floor_y + PARAPET_H, 0.0, Z_WALL)


func _roof() -> void:
	var x0 := LEFT - OVERHANG
	var x1 := RIGHT + OVERHANG
	var e0 := Vector3(0, EAVE, OVERHANG)
	var r := Vector3(0, RIDGE[0], RIDGE[1])
	var e1 := Vector3(0, EAVE, Z_BACK - OVERHANG)
	var slope := 0
	for s: Array in [[e0, r], [r, e1]]:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var n := (b - a).cross(Vector3.RIGHT).normalized()
		if n.y < 0:
			n = -n
		# Clockwise from above, matching the upward-facing roof normal.
		_quad("roof", n, Vector3(x0, a.y, a.z), Vector3(x0, b.y, b.z), Vector3(x1, b.y, b.z), Vector3(x1, a.y, a.z))
		# The front painting already contains ribs; duplicate raised geometry
		# intersected that painting and caused a checkerboard at a distance.
		if slope == 1:
			var x := x0 + 0.3
			while x < x1:
				_beam("roof", Vector3(x, a.y + 0.03, a.z), Vector3(x, b.y + 0.03, b.z), 0.05)
				x += 0.6
		slope += 1
	_box("fascia", x0, x1, RIDGE[0] - 0.05, RIDGE[0] + 0.1, RIDGE[1] + 0.15, RIDGE[1] - 0.15)
	# ลาดหน้าทาด้วยแถบหลังคาในภาพ (px 74 ที่สัน ถึง 141 ที่ชายคา)
	var st := _tool("paint_front")
	var lift := Vector3(0, 0.06, 0)
	var corners := [[Vector3(x0, EAVE, OVERHANG), 141.0], [Vector3(x1, EAVE, OVERHANG), 141.0],
			[Vector3(x1, RIDGE[0], RIDGE[1]), 74.0], [Vector3(x0, RIDGE[0], RIDGE[1]), 74.0]]
	for i: int in [0, 2, 1, 0, 3, 2]:
		var v: Vector3 = corners[i][0]
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(((v.x - PAINT_ORIGIN.x) * PPM) / PAINT_SIZE.x, float(corners[i][1]) / PAINT_SIZE.y))
		st.add_vertex(v + lift)
	for x in [x0 + 0.3, x1 - 0.3]:
		var n := Vector3.LEFT if x < 0 else Vector3.RIGHT
		_tri("wall", n, Vector3(x, EAVE - 0.1, OVERHANG - 0.6), Vector3(x, RIDGE[0], RIDGE[1]),
				Vector3(x, EAVE - 0.1, Z_BACK - OVERHANG + 0.6))


## ผนังหลังอาคาร: หน้าต่างแถวยาว (ช่วง f0..f1 ของช่อง)
func _window_wall(x0: float, x1: float, y0: float, y1: float, z: float, f0: float, f1: float) -> void:
	var sill := y0 + 0.95
	var head := y0 + 2.35
	var wx0 := lerpf(x0, x1, f0)
	var wx1 := lerpf(x0, x1, f1)
	_box("wall", x0, x1, head, y1, z, z + WALL_T)
	_box("wall", x0, x1, y0, sill, z, z + WALL_T)
	_box("wall", x0, wx0, sill, head, z, z + WALL_T)
	_box("wall", wx1, x1, sill, head, z, z + WALL_T)
	_window(wx0, wx1, sill, head, z, false)


## หน้าต่าง: ขอบปูนล่าง กระจก ลูกฟักตั้งทุก ~0.75 ม. ลูกฟักนอนแบ่งช่องแสงบน ม่านด้านใน ห้องมืดด้านหลัง
func _window(x0: float, x1: float, y0: float, y1: float, z: float, facing_front: bool) -> void:
	var s := 1.0 if facing_front else -1.0
	var g := z - 0.08 * s
	_box("trim", x0 - 0.06, x1 + 0.06, y0 - 0.07, y0, z + 0.07 * s, z - 0.02 * s)
	_box("glass", x0, x1, y0, y1, g, g - 0.02 * s)
	_box("room", x0, x1, y0, y1, g - 0.7 * s, g - 0.72 * s)
	var n := maxi(2, int(round((x1 - x0) / 0.75)))
	var f0 := g + 0.03 * s
	var f1 := g - 0.01 * s
	for i in n + 1:
		var x := lerpf(x0, x1, float(i) / n)
		_box("frame", x - 0.03, x + 0.03, y0, y1, f0, f1)
	for y: float in [y0, y1 - 0.42, y1]:
		_box("frame", x0, x1, y - 0.03, y + 0.03, f0, f1)
	for i in n:
		if (i * 7 + int(absf(x0) * 3.0)) % 3 == 0:
			var a := lerpf(x0, x1, float(i) / n) + 0.04
			var b := lerpf(x0, x1, float(i + 1) / n) - 0.04
			_box("curtain", a, lerpf(a, b, 0.55), y0 + 0.05, y1 - 0.45, g - 0.12 * s, g - 0.14 * s)


## หลอดนีออนใต้เพดาน
func _tube(x: float, ceil_y: float, z: float) -> void:
	_box("trim", x - 0.65, x + 0.65, ceil_y - 0.07, ceil_y, z + 0.1, z - 0.1)
	_box("lamp", x - 0.6, x + 0.6, ceil_y - 0.1, ceil_y - 0.07, z + 0.05, z - 0.05)
	lamps.append(Vector3(x, ceil_y - 0.15, z))


# ---------------------------------------------------------------- ช่องบันได

func _core() -> void:
	var top: float = CEILS[2]
	_box("core", CORE[0] - WALL_T, CORE[0], 0.0, top, CORE[2], CORE[3])
	_box("core", CORE[1], CORE[1] + WALL_T, 0.0, top, CORE[2], CORE[3])
	_box("core", DIVIDER[0], DIVIDER[1], FLOORS[0], top, STAIR_FRONT, STAIR_FRONT - TREAD * 9)
	_box("floor", CORE[0], CORE[1], FLOORS[0] - 0.01, FLOORS[0], CORE[2], CORE[3])
	_box("ceiling", CORE[0], CORE[1], top, top + 0.1, CORE[2], CORE[3])
	# ผนังหลังช่องบันได: ช่องลมบล็อกเหนือชานพักทุกชั้น (แสงฟ้าลอดเข้ามา)
	var z: float = CORE[3]
	var y := 0.0
	for k in 2:
		var landing: float = FLOORS[k] + (FLOORS[k + 1] - FLOORS[k]) / 2.0
		var v0 := landing + 1.2
		var v1 := landing + 2.2
		_box("core", CORE[0], CORE[1], y, v0, z, z - WALL_T)
		_box("core", CORE[0], -2.1, v0, v1, z, z - WALL_T)
		_box("core", -0.1, CORE[1], v0, v1, z, z - WALL_T)
		_vent(-2.1, -0.1, v0, v1, z)
		y = v1
	_box("core", CORE[0], CORE[1], y, top, z, z - WALL_T)
	# ผนังเตี้ยกันตกขอบช่องบันไดชั้น 3 พร้อมราว
	_box("core", CORE[0], DIVIDER[0], FLOORS[2], FLOORS[2] + 1.0, STAIR_FRONT + 0.1, STAIR_FRONT)
	_beam("rail", Vector3(CORE[0], FLOORS[2] + 1.03, STAIR_FRONT + 0.05),
			Vector3(DIVIDER[0], FLOORS[2] + 1.03, STAIR_FRONT + 0.05), 0.05)
	for k in 3:
		_tube(-1.0, CEILS[k], -2.75)


## ช่องลมบล็อก: ตารางบล็อกปูนกลวง
func _vent(x0: float, x1: float, y0: float, y1: float, z: float) -> void:
	var cell := 0.2
	var nx := int(round((x1 - x0) / cell))
	var ny := int(round((y1 - y0) / cell))
	for i in nx + 1:
		var x := x0 + (x1 - x0) * i / nx
		_box("vent", x - 0.025, x + 0.025, y0, y1, z, z - WALL_T)
	for j in ny + 1:
		var y := y0 + (y1 - y0) * j / ny
		_box("vent", x0, x1, y - 0.025, y + 0.025, z, z - WALL_T)


## บันไดจากชั้น k ขึ้นชั้น k+1 (20 ลูกตั้ง ช่วงละ 10)
func _stairs(k: int) -> void:
	var y0: float = FLOORS[k]
	var y1: float = FLOORS[k + 1]
	var rise := (y1 - y0) / 20.0
	var landing_z := STAIR_FRONT - TREAD * 9
	var landing := y0 + rise * 10
	for i in 9:
		var top := y0 + rise * (i + 1)
		var z0 := STAIR_FRONT - TREAD * i
		_box("riser", FLIGHT_A[0], FLIGHT_A[1], y0 if k == 0 else top - rise - 0.25, top - 0.02, z0, z0 - TREAD)
		_box("tread", FLIGHT_A[0], FLIGHT_A[1], top - 0.02, top, z0 + 0.02, z0 - TREAD)
		_box("nosing", FLIGHT_A[0], FLIGHT_A[1], top - 0.03, top + 0.003, z0 + 0.025, z0 - 0.03)
	_box("riser", CORE[0], CORE[1], landing - 0.25, landing - 0.02, landing_z, CORE[3])
	_box("tread", CORE[0], CORE[1], landing - 0.02, landing, landing_z, CORE[3])
	for j in 9:
		var top := landing + rise * (j + 1)
		var z0 := landing_z + TREAD * j
		_box("riser", FLIGHT_B[0], FLIGHT_B[1], top - rise - 0.25, top - 0.02, z0, z0 + TREAD)
		_box("tread", FLIGHT_B[0], FLIGHT_B[1], top - 0.02, top, z0 - 0.02, z0 + TREAD)
		_box("nosing", FLIGHT_B[0], FLIGHT_B[1], top - 0.03, top + 0.003, z0 + TREAD - 0.025, z0 + TREAD + 0.03)
	_box("ceiling", CORE[0], CORE[1], y1 - 0.3, y1 - 0.02, CORE[2], STAIR_FRONT)
	_box("floor", CORE[0], CORE[1], y1 - 0.02, y1, CORE[2], STAIR_FRONT)
	# ราวจับทั้งสองข้างของทั้งสองช่วง ต่อรอบชานพัก
	var h := 0.9
	for x: float in [CORE[0] + 0.07, DIVIDER[0] - 0.07]:
		_handrail(Vector3(x, y0 + rise * 0.5 + h, STAIR_FRONT + 0.15), Vector3(x, landing + h, landing_z - 0.05), x < -1.5)
	for x: float in [DIVIDER[1] + 0.07, CORE[1] - 0.07]:
		_handrail(Vector3(x, landing + h, landing_z + 0.05), Vector3(x, y1 - rise * 0.5 + h, STAIR_FRONT - 0.05), x < 0.0)
	var c0 := Vector3(CORE[0] + 0.07, landing + h, CORE[3] + 0.07)
	var c1 := Vector3(CORE[1] - 0.07, landing + h, CORE[3] + 0.07)
	_handrail(Vector3(c0.x, c0.y, landing_z - 0.05), c0, true)
	_handrail(c0, c1, false)
	_handrail(c1, Vector3(c1.x, c1.y, landing_z + 0.05), false)
	_tube(-1.0, landing + 2.6, landing_z - 0.8)


## ท่อเหลี่ยมเล็กจาก a ถึง b (หน้าตัด w)
func _beam(mat: String, a: Vector3, b: Vector3, w: float) -> void:
	var d := (b - a).normalized()
	var side := d.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized() * w / 2.0
	var up := side.cross(d).normalized() * w / 2.0
	var c := [side + up, -side + up, -side - up, side - up]
	for i in 4:
		var p: Vector3 = c[i]
		var q: Vector3 = c[(i + 1) % 4]
		_quad(mat, (p + q).normalized(), a + p, a + q, b + q, b + p)


## ราวจับติดผนัง: ท่อตามแนว ขายึดถึงผนังทุก ~1 ม.
func _handrail(a: Vector3, b: Vector3, wall_left: bool) -> void:
	_beam("rail", a, b, 0.045)
	var off := Vector3(-0.07 if wall_left else 0.07, -0.06, 0)
	if absf(a.x - b.x) > 0.5:
		off = Vector3(0, -0.06, -0.07)
	var n := maxi(1, int(a.distance_to(b) / 1.0))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		_beam("rail", p, p + off, 0.02)


# ---------------------------------------------------------------- ทางเข้า

func _entrance() -> void:
	var x0: float = CANOPY[0]
	var x1: float = CANOPY[1]
	# กันสาด: แผ่นฟ้า ใต้ขาว ไฟใต้กันสาด เสาขาวสองต้น
	_box("canopy", x0, x1, CANOPY[3] - 0.22, CANOPY[3], CANOPY[4], 0.3)
	_box("ceiling", x0 + 0.05, x1 - 0.05, CANOPY[2], CANOPY[3] - 0.22, CANOPY[4] - 0.05, 0.3)
	for p: Array in CANOPY_PILLARS:
		_box("pillar", p[0], p[1], 0.0, CANOPY[2], 1.9, 1.3)
	_tube(0.0, CANOPY[2], 1.5)
	# บันไดหน้า 3 ขั้น
	for i in 3:
		var inset := 0.18 * i
		var top: float = FLOORS[0] / 3.0 * (i + 1)
		_box("cement", x0 + 0.25 + inset, x1 - 0.25 - inset, 0.0, top, 2.6 - 0.3 * i, 0.3)
		_box("nosing", x0 + 0.25 + inset, x1 - 0.25 - inset, top - 0.02, top + 0.003, 2.62 - 0.3 * i, 2.57 - 0.3 * i)
	# บอร์ด ถังขยะ ช่องลม กระถาง อยู่ในภาพทางเข้าของผู้เขียนบนผนังโถงแล้ว
	_paint("front", x0, x1, CANOPY[2], CANOPY[3], CANOPY[4] + 0.003)
	for p: Array in CANOPY_PILLARS:
		_paint("front", p[0], p[1], 0.0, CANOPY[2], 1.903)


## ม้านั่งไม้ระแนง ขาเหล็ก
func _bench(base: Vector3, w: float) -> void:
	var x0 := base.x - w / 2.0
	var x1 := base.x + w / 2.0
	var y := base.y
	var z := base.z
	for i in 3:
		_box("wood", x0, x1, y + 0.47 + 0.11 * i, y + 0.55 + 0.11 * i, z - 0.18, z - 0.22)
	for i in 2:
		_box("wood", x0, x1, y + 0.4, y + 0.44, z + 0.12 - 0.17 * i, z - 0.03 - 0.17 * i)
	for x: float in [x0 + 0.1, x1 - 0.14]:
		_box("iron", x, x + 0.04, y, y + 0.42, z + 0.12, z + 0.08)
		_box("iron", x, x + 0.04, y, y + 0.8, z - 0.18, z - 0.24)
		_box("iron", x, x + 0.04, y + 0.36, y + 0.4, z + 0.14, z - 0.22)


# ---------------------------------------------------------------- ลาน

func _courtyard() -> void:
	_quad("grass", Vector3.UP, Vector3(-60, -0.01, -40), Vector3(60, -0.01, -40), Vector3(60, -0.01, 50), Vector3(-60, -0.01, 50))
	_box("concrete", LEFT - 3.0, RIGHT + 3.0, -0.01, 0.0, WALK[0], Z_BACK - 3.0)
	_box("drain", LEFT, RIGHT, 0.0, 0.005, 0.65, 0.3)
	var x := LEFT - 3.0
	while x < RIGHT + 3.0:                              # รอยต่อแผ่นคอนกรีต
		_box("cement", x - 0.015, x + 0.015, 0.0, 0.003, WALK[0], 0.65)
		x += 1.5
	_box("cement", -WALK_X, WALK_X, -0.01, 0.002, WALK[1], WALK[0])
	_box("edging", -WALK_X, WALK_X, 0.0, 0.08, WALK[1] + 0.2, WALK[1])
	_box("paver", -PATH, PATH, -0.01, 0.004, 40.0, WALK[1] + 0.2)
	for s in [-1.0, 1.0]:
		_box("edging", s * PATH - 0.06, s * PATH + 0.06, 0.0, 0.06, 40.0, WALK[1] + 0.2)
	var z := WALK[1] + 0.7
	while z < 40.0:
		_box("cement", -PATH, PATH, 0.004, 0.006, z + 0.015, z - 0.015)
		z += 0.5
	# Keep the central entrance open; the covered walk serves the right wing.
	x = 5.0
	while x < WALK_X:
		_box("steel", x - 0.06, x + 0.06, 0.0, WALK[2], 6.36, 6.24)
		_box("cement", x - 0.15, x + 0.15, 0.0, 0.15, 6.45, 6.15)
		x += 3.7
	_box("steel", 4.8, WALK_X, WALK[2] - 0.12, WALK[2], 6.36, 6.24)
	_box("sheet", 4.8, WALK_X, WALK[2], WALK[3], WALK[1], WALK[0])
	_box("fascia", 4.8, WALK_X, WALK[2] - 0.05, WALK[3] + 0.02, WALK[1] + 0.06, WALK[1])
	for side in [-1.0, 1.0]:
		var a: float = HEDGE[3] * side
		var b: float = HEDGE[4] * side
		_box("hedge", minf(a, b), maxf(a, b), 0.0, 0.42, HEDGE[1], HEDGE[0])
		_box("edging", minf(a, b) - 0.06, maxf(a, b) + 0.06, 0.0, 0.12, HEDGE[1] + 0.08, HEDGE[1])
		var leaf_x := minf(a, b) + 1.65
		var variant := 0
		while leaf_x < maxf(a, b) - 0.7:
			_foliage_cards(Vector3(leaf_x, 0.12, 7.63), 3.4, 0.95 + (variant % 3) * 0.04, Rect2(1120, 150, 395, 155), 0.62)
			leaf_x += 0.85
			variant += 1
	for pad: Vector2 in [Vector2(-5.6, 10.6), Vector2(6.2, 11.4)]:
		_box("concrete", pad.x - 1.25, pad.x + 1.25, -0.01, 0.004, pad.y + 0.62, pad.y - 0.58)
	_bench(Vector3(-5.6, 0.0, 10.6), 1.8)
	_bench(Vector3(6.2, 0.0, 11.4), 1.8)
	_potted_plant(Vector3(-4.35, 0.0, 2.1), 0)
	_potted_plant(Vector3(4.4, 0.0, 2.1), 1)
	_potted_plant(Vector3(20.9, 0.0, 2.2), 2)


func _foliage_cards(base: Vector3, width: float, height: float, region: Rect2, depth: float) -> void:
	var image_size := Vector2(2172, 724)
	var uv := [region.position / image_size, (region.position + Vector2(region.size.x, 0)) / image_size,
		(region.position + region.size) / image_size, (region.position + Vector2(0, region.size.y)) / image_size]
	var st := _tool("foliage")
	for axis in 2:
		var basis := Basis(Vector3.UP, axis * PI / 2.0)
		var span := width if axis == 0 else depth
		var points := [Vector3(-span / 2, height, 0), Vector3(span / 2, height, 0), Vector3(span / 2, 0, 0), Vector3(-span / 2, 0, 0)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_normal(basis * Vector3.BACK)
			st.set_uv(uv[i])
			st.add_vertex(base + basis * points[i])


func _potted_plant(base: Vector3, variant: int) -> void:
	var height := 0.42
	for i in 16:
		var a := TAU * i / 16.0
		var b := TAU * (i + 1) / 16.0
		var p := Vector3(cos(a), 0, sin(a))
		var q := Vector3(cos(b), 0, sin(b))
		_quad("pot", (p + q).normalized(), base + p * 0.19, base + q * 0.19,
			base + q * 0.28 + Vector3.UP * height, base + p * 0.28 + Vector3.UP * height)
		_quad("pot", Vector3.UP, base + p * 0.29 + Vector3.UP * height, base + q * 0.29 + Vector3.UP * height,
			base + q * 0.24 + Vector3.UP * height, base + p * 0.24 + Vector3.UP * height)
		_tri("soil", Vector3.UP, base + p * 0.24 + Vector3.UP * 0.40, base + q * 0.24 + Vector3.UP * 0.40, base + Vector3.UP * 0.40)
	_foliage_cards(base + Vector3.UP * 0.40, 0.70, 1.10, LEAF_REGIONS[variant], 0.70)


# ---------------------------------------------------------------- เครื่องมือ

func _tool(mat: String) -> SurfaceTool:
	if not _tools.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[mat] = st
	return _tools[mat]


## หน้าตรงหันออกลาน ทาด้วยภาพหน้าอาคารชั้น layer ตรงตำแหน่งจริงของมันในภาพ
func _paint(layer: String, x0: float, x1: float, y0: float, y1: float, z: float) -> void:
	var st := _tool("paint_" + layer)
	var vs := [Vector3(x0, y1, z), Vector3(x1, y1, z), Vector3(x1, y0, z), Vector3(x0, y0, z)]
	for i: int in [0, 1, 2, 0, 2, 3]:
		var v: Vector3 = vs[i]
		st.set_normal(Vector3.BACK)
		st.set_uv(Vector2((v.x - PAINT_ORIGIN.x) * PPM / PAINT_SIZE.x, (PAINT_ORIGIN.y - v.y) * PPM / PAINT_SIZE.y))
		st.add_vertex(v)


func _quad(mat: String, n: Vector3, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var st := _tool(mat)
	for v in [a, b, c, a, c, d]:
		st.set_normal(n)
		st.set_uv(_uv(v, n))
		st.add_vertex(v)


func _tri(mat: String, n: Vector3, a: Vector3, b: Vector3, c: Vector3) -> void:
	var st := _tool(mat)
	for v in [a, b, c]:
		st.set_normal(n)
		st.set_uv(_uv(v, n))
		st.add_vertex(v)


## UV ตามขนาดจริง (0.5 ม. ต่อรอบ) บนระนาบที่หน้านั้นหัน
static func _uv(v: Vector3, n: Vector3) -> Vector2:
	var a := n.abs()
	if a.y > a.x and a.y > a.z:
		return Vector2(v.x, v.z) * 0.25
	if a.x > a.z:
		return Vector2(v.z, -v.y) * 0.25
	return Vector2(v.x, -v.y) * 0.25


func _box(mat: String, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> void:
	var lo := Vector3(minf(x0, x1), minf(y0, y1), minf(z0, z1))
	var hi := Vector3(maxf(x0, x1), maxf(y0, y1), maxf(z0, z1))
	_quad(mat, Vector3.BACK, Vector3(lo.x, hi.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z))
	_quad(mat, Vector3.FORWARD, Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z))
	_quad(mat, Vector3.UP, Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z))
	_quad(mat, Vector3.DOWN, Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z), Vector3(lo.x, lo.y, lo.z))
	_quad(mat, Vector3.LEFT, Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, lo.y, lo.z))
	_quad(mat, Vector3.RIGHT, Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z))


func _commit() -> void:
	for key: String in _tools:
		var mesh := MeshInstance3D.new()
		mesh.name = key
		var st: SurfaceTool = _tools[key]
		if SURFACE.has(key):
			st.generate_tangents()                      # normal map ต้องมี tangent
		mesh.mesh = st.commit()
		mesh.material_override = _material(key)
		if key in ["lamp", "room", "drain", "grass", "foliage"] or key.begins_with("paint_"):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)


func _material(key: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if key == "foliage":
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = FOLIAGE
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m
	if key.begins_with("paint_"):
		# ภาพของผู้เขียนมีแสงฝนของมันอยู่แล้ว: ไม่ลงแสงซ้ำ
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# The rear wall needs complete doors/windows behind the foreground
		# pillars and parapets. The old generated back.png is kept as source
		# evidence, but its stretched fills must not be used for this surface.
		m.albedo_texture = WALL_REPAIR_ART if key == "paint_back" else load(PAINT_DIR + key.substr(6) + ".png")
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		return m
	m.albedo_color = COLOURS[key]
	m.roughness = GLOSS.get(key, 0.85)
	if key == "lamp":
		m.emission_enabled = true
		m.emission = Color("eef4ff")
		m.emission_energy_multiplier = 2.5
	if key == "room":
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if SURFACE.has(key):
		var spec: Array = SURFACE[key]
		var c: Color = COLOURS[key]
		var mean: float = spec[2]
		m.albedo_color = Color(c.r / mean, c.g / mean, c.b / mean)
		m.albedo_texture = load(TEX_DIR + str(spec[0]) + "_detail.png")
		m.normal_enabled = true
		m.normal_texture = load(TEX_DIR + str(spec[0]) + "_normal.png")
		m.normal_scale = float(spec[3]) * 0.22
		var repeat: float = 4.0 / float(spec[1])         # UV = 0.25 ต่อเมตร
		m.uv1_scale = Vector3(repeat, repeat, 1.0)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m
