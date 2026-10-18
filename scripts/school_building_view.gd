class_name SchoolBuildingView
extends SubViewportContainer
## อาคารเรียน 2.5D (SchoolBuilding3D) กับลานหน้าอาคาร (SchoolCourtyard3D) เรนเดอร์ที่ความละเอียดเกม 640x360 แล้วขยายแบบ Nearest
## ให้เป็นพิกเซลเหมือนฉากอื่น (เหมือนฉาก HD-2D) พื้นหลังโปร่งใส วางซ้อนกับฉาก 2D ได้
## turn(องศา): มองอาคารเฉียงเล็กน้อย (0 = ภาพเหมือนต้นฉบับ) โดยเลื่อนกล้องไปข้างๆ แล้วเลื่อนเลนส์
## ให้หน้าอาคาร (z 0) อยู่ที่เดิมบนจอ ไม่หมุนตัวกล้อง: เส้นแนวนอนจึงตรงเสมอ (หมุนจริงแล้วเส้นเอียงเป็นขั้นบันไดพิกเซล)
## เห็นข้างเสาและความลึกของโถงเหมือนหมุน
## enter(0..1): กล้องเดินเข้าไปดูบันได: หน้าอาคาร -> จุดยืนของภาพทางเข้าระยะใกล้ (ENTER_AT: เห็นเหมือนภาพ
## ของผู้เขียน, SchoolEntrance3D จางเข้าแทนตัวอาคารกับลานระหว่างทาง) -> เข้าโถงไปหน้าบันได
## ไม่หมุนกล้อง เลื่อนเลนส์มองตามเป้า

const SIZE := Vector2i(640, 360)
## กรอบภาพที่ระยะออกแบบ (เมตร): สูง 15m ศูนย์กลางที่ 5m (เห็นลานหน้าอาคารด้วย)
@export var frame_height := 15.0
@export var frame_centre_y := 5.0
## จุดยืน เป้าที่มอง ความสูงภาพต่อระยะ 1 ม. ของภาพทางเข้า (ทั้งภาพเต็มจอ) และหน้าบันได
const ENTER_AT := 0.6
const CLOSE_FRAME := 941.0 / 1160.0
const INSIDE := Vector3(-1.15, 1.25, -1.7)      # ในโถง หน้าบันได
const INSIDE_LOOK := Vector3(-1.25, 1.45, -4.4)
const INSIDE_FRAME := 0.95
const FADE := [0.3, 0.5]                        # ช่วงที่ตัวอาคาร/ลานเปลี่ยนเป็นภาพทางเข้า

var camera: Camera3D
var building: SchoolBuilding3D
var courtyard: SchoolCourtyard3D
var entrance: SchoolEntrance3D
var interior: SchoolInterior3D
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
	entrance = SchoolEntrance3D.new()
	_viewport.add_child(entrance)
	interior = SchoolInterior3D.new()
	_viewport.add_child(interior)
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
		[SchoolEntrance3D.CAMERA, SchoolEntrance3D.at(836.0, 470.5, 0.0), CLOSE_FRAME],
		[INSIDE, INSIDE_LOOK, INSIDE_FRAME],
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
	var f := clampf((_inside - FADE[0]) / (FADE[1] - FADE[0]), 0.0, 1.0)
	building.set_fade(1.0 - f)
	courtyard.set_fade(1.0 - f)
	entrance.set_fade(f)
	interior.set_fade(f)
