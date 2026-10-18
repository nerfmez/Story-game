class_name SchoolBuildingView
extends SubViewportContainer
## อาคารเรียน 2.5D (SchoolBuilding3D) กับลานหน้าอาคาร (SchoolCourtyard3D) เรนเดอร์ที่ความละเอียดเกม 640x360 แล้วขยายแบบ Nearest
## ให้เป็นพิกเซลเหมือนฉากอื่น (เหมือนฉาก HD-2D) พื้นหลังโปร่งใส วางซ้อนกับฉาก 2D ได้
## turn(องศา): มองอาคารเฉียงเล็กน้อย (0 = ภาพเหมือนต้นฉบับ) โดยเลื่อนกล้องไปข้างๆ แล้วเลื่อนเลนส์
## ให้หน้าอาคาร (z 0) อยู่ที่เดิมบนจอ ไม่หมุนตัวกล้อง: เส้นแนวนอนจึงตรงเสมอ (หมุนจริงแล้วเส้นเอียงเป็นขั้นบันไดพิกเซล)
## เห็นข้างเสาและความลึกของโถงเหมือนหมุน
## enter(0..1): กล้องเดินเข้าโถงชั้นล่างไปดูบันได: หน้าอาคาร -> จุดที่ผู้เขียนวาดโถง (ENTER_AT, เห็นโถง
## เหมือนในภาพ) -> เข้าไปในทางเดินจนเห็นบันไดผ่านช่องประตู ไม่หมุนกล้อง เลื่อนเลนส์มองตามเป้า

const SIZE := Vector2i(640, 360)
## กรอบภาพที่ระยะออกแบบ (เมตร): สูง 15m ศูนย์กลางที่ 5m (เห็นลานหน้าอาคารด้วย)
@export var frame_height := 15.0
@export var frame_centre_y := 5.0
## เป้าที่มองและความสูงภาพต่อระยะ 1 ม. ที่จุดในอาคาร (ภาพโถงเต็มจอ / ใกล้ช่องประตู)
const ENTER_AT := 0.7
const HALL_LOOK := Vector2(1040.0, 571.0)       # กลางภาพโถง (px ต้นฉบับ) ที่ระนาบปากทางเดิน
const HALL_FRAME := 0.66                        # ภาพโถงชั้นล่าง (px 496-645) เต็มจอพอดี
const INSIDE := Vector3(0.35, 1.1, -3.5)        # ยืนในทางเดิน หน้าช่องประตู
const INSIDE_FRAME := 1.1
const FADE := [0.35, 0.55]                      # ช่วงที่ภาพโถงนอกอาคารเปลี่ยนเป็นโถงจริง

var camera: Camera3D
var building: SchoolBuilding3D
var courtyard: SchoolCourtyard3D
var _viewport: SubViewport
var _yaw := 0.0
var _inside := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_viewport)
	building = SchoolBuilding3D.new()
	_viewport.add_child(building)
	courtyard = SchoolCourtyard3D.new()
	_viewport.add_child(courtyard)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_FRUSTUM
	camera.near = 0.05
	camera.far = 200.0
	_viewport.add_child(camera)
	turn(0.0)


func turn(yaw_degrees: float) -> void:
	_yaw = yaw_degrees
	_place()


func enter(amount: float) -> void:
	_inside = clampf(amount, 0.0, 1.0)
	_place()


func _place() -> void:
	var cam := SchoolBuilding3D.DESIGN_CAMERA
	var dx := cam.z * tan(deg_to_rad(_yaw))
	# จุดยืน, เป้าที่มอง, ความสูงภาพต่อระยะ 1 ม. ของแต่ละจุด
	# หน้าอาคาร: เลนส์เลื่อนให้หน้าอาคาร (z 0) อยู่กรอบเดิม ระนาบนั้นนิ่ง ชิ้นใกล้/ไกลเลื่อนออกจากกัน
	var keys := [
		[cam + Vector3(dx, 0, 0), Vector3(0, frame_centre_y, 0), frame_height / cam.z],
		[SchoolBuilding3D.HALL_CAMERA, SchoolBuilding3D.at(HALL_LOOK.x, HALL_LOOK.y, SchoolBuilding3D.HALL_PLANE),
				HALL_FRAME],
		[INSIDE, SchoolBuilding3D.at_hall(1071, 594, SchoolBuilding3D.Z_STAIRS), INSIDE_FRAME],
	]
	var a: Array = keys[0]
	var b: Array = keys[1]
	var t := _inside / ENTER_AT
	if _inside > ENTER_AT:
		a = keys[1]
		b = keys[2]
		t = (_inside - ENTER_AT) / (1.0 - ENTER_AT)
	t = smoothstep(0.0, 1.0, t)
	var pos: Vector3 = (a[0] as Vector3).lerp(b[0], t)
	var look: Vector3 = (a[1] as Vector3).lerp(b[1], t)
	var frame: float = lerpf(a[2], b[2], t)
	camera.position = pos
	camera.size = frame * camera.near
	camera.frustum_offset = Vector2(look.x - pos.x, look.y - pos.y) / (pos.z - look.z) * camera.near
	building.set_inside(clampf((_inside - FADE[0]) / (FADE[1] - FADE[0]), 0.0, 1.0))
