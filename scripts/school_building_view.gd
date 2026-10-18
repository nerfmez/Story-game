class_name SchoolBuildingView
extends SubViewportContainer
## อาคารเรียน 2.5D (SchoolBuilding3D) กับลานหน้าอาคาร (SchoolCourtyard3D) เรนเดอร์ที่ความละเอียดเกม 640x360 แล้วขยายแบบ Nearest
## ให้เป็นพิกเซลเหมือนฉากอื่น (เหมือนฉาก HD-2D) พื้นหลังโปร่งใส วางซ้อนกับฉาก 2D ได้
## turn(องศา): มองอาคารเฉียงเล็กน้อย (0 = ภาพเหมือนต้นฉบับ) โดยเลื่อนกล้องไปข้างๆ แล้วเลื่อนเลนส์
## ให้หน้าอาคาร (z 0) อยู่ที่เดิมบนจอ ไม่หมุนตัวกล้อง: เส้นแนวนอนจึงตรงเสมอ (หมุนจริงแล้วเส้นเอียงเป็นขั้นบันไดพิกเซล)
## เห็นข้างเสาและความลึกของโถงเหมือนหมุน

const SIZE := Vector2i(640, 360)
## กรอบภาพที่ระยะออกแบบ (เมตร): สูง 15m ศูนย์กลางที่ 5m (เห็นลานหน้าอาคารด้วย)
@export var frame_height := 15.0
@export var frame_centre_y := 5.0

var camera: Camera3D
var building: SchoolBuilding3D
var courtyard: SchoolCourtyard3D
var _viewport: SubViewport


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
	camera.near = 0.5
	camera.far = 200.0
	camera.size = frame_height * camera.near / SchoolBuilding3D.DESIGN_CAMERA.z
	_viewport.add_child(camera)
	turn(0.0)


func turn(yaw_degrees: float) -> void:
	var cam := SchoolBuilding3D.DESIGN_CAMERA
	var dx := cam.z * tan(deg_to_rad(yaw_degrees))
	camera.position = cam + Vector3(dx, 0.0, 0.0)
	# เลนส์เลื่อนกลับให้ภาพที่ระยะออกแบบ (z 0) อยู่กรอบเดิม: ระนาบนั้นนิ่ง ชิ้นที่ใกล้/ไกลกว่าเลื่อนออกจากกัน
	var k := camera.near / cam.z
	camera.frustum_offset = Vector2(-dx * k, (frame_centre_y - cam.y) * k)
