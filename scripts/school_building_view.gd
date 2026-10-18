class_name SchoolBuildingView
extends SubViewportContainer
## โรงเรียน (SchoolModel3D) เรนเดอร์ที่ความละเอียดเกม 640x360 แล้วขยายแบบ Nearest ให้เป็นพิกเซลเหมือนฉากอื่น
## กล้องเลื่อนไปที่ไหนก็ได้ (camera): โมเดลเดียวทั้งหลัง ไม่มีจุดมองตายตัว
## look(ตำแหน่ง, เป้า): วางกล้องแบบคนยืนมอง (ไม่เอียงซ้ายขวา)

const SIZE := Vector2i(640, 360)

var camera: Camera3D
var school: SchoolModel3D
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
	school = SchoolModel3D.new()
	_viewport.add_child(school)
	camera = Camera3D.new()
	camera.fov = 60.0
	camera.near = 0.05
	camera.far = 200.0
	_viewport.add_child(camera)
	look(Vector3(0.0, 1.6, 30.0), Vector3(0.0, 5.0, 0.0))


func look(from: Vector3, at: Vector3) -> void:
	camera.position = from
	camera.look_at(at, Vector3.UP)
