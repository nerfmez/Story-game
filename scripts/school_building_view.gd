class_name SchoolBuildingView
extends SubViewportContainer
## อาคารเรียน 2.5D (SchoolBuilding3D) เรนเดอร์ที่ความละเอียดเกม 640x360 แล้วขยายแบบ Nearest
## ให้เป็นพิกเซลเหมือนฉากอื่น (เหมือนฉาก HD-2D) พื้นหลังโปร่งใส วางซ้อนกับฉาก 2D ได้
## turn(องศา): หมุนกล้องรอบอาคารเล็กน้อย (0 = ภาพเหมือนต้นฉบับ)

const SIZE := Vector2i(640, 360)
## กรอบภาพที่ระยะออกแบบ (เมตร): สูง 15m ศูนย์กลางที่ 6.4m
@export var frame_height := 15.0
@export var frame_centre_y := 6.4
## จุดหมุน (ระดับสายตา กลางระเบียง)
@export var pivot := Vector3(0.0, 1.6, -2.0)

var camera: Camera3D
var building: SchoolBuilding3D
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
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_FRUSTUM
	camera.near = 0.5
	camera.far = 200.0
	var distance := SchoolBuilding3D.DESIGN_CAMERA.z
	camera.size = frame_height * camera.near / distance
	camera.frustum_offset = Vector2(0.0, (frame_centre_y - SchoolBuilding3D.DESIGN_CAMERA.y) * camera.near / distance)
	_viewport.add_child(camera)
	turn(0.0)


func turn(yaw_degrees: float) -> void:
	var yaw := deg_to_rad(yaw_degrees)
	camera.position = pivot + (SchoolBuilding3D.DESIGN_CAMERA - pivot).rotated(Vector3.UP, yaw)
	camera.rotation = Vector3(0.0, yaw, 0.0)
